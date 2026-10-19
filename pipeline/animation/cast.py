#!/usr/bin/env python3
"""Lanternroot's cast as sprite sheets (ADR-0063): townspeople built as a Blender
blockout on one shared body, turned to the front, the left and the back, restyled by ComfyUI, and cut to frames that
share one camera. Every view and every character has the same proportions, the same scale and the same feet line.

  turns    Blender renders each character's turns into pipeline/cache/animation/cast/<id>/ (ComfyUI down).
  restyle  ComfyUI img2img on each turn, cached in pipeline/cache/art/cast-<id>-<view>/ (ComfyUI up).
  sheets   for each view, keeps the candidate whose outline best matches its turn, holds it inside that outline, and cuts
           every frame the same way: the camera's frame is the sprite's frame, so nothing is cropped or scaled per frame.
           Writes game/assets/overworld/cast/<id>.png and cast.json, and review sheets in Concept/v0.3/animation/cast/.
  check    which characters' sheets no longer match their looks in the content (those fall back to parts in the game).

  uv run --project pipeline python pipeline/animation/cast.py turns|restyle|sheets|check [--only ids] [--force]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "art"))
sys.path.insert(0, str(ROOT / "pipeline" / "pixel"))
import generate as gen  # noqa: E402 (ensure_raws, read_raws, resize_premultiplied, palette, outline, locked, breathe)
from held import grow, guarded, iou, pick, read_jsonc  # noqa: E402,F401 (shared with pipeline/world)
import pixelkit  # noqa: E402 (the overworld's palette)

HERE = Path(__file__).resolve().parent
CONFIG = HERE / "cast.json"
SCALE = ROOT / "game" / "content" / "packs" / "core" / "overworld" / "scale.jsonc"
CONTENT = ROOT / "game" / "content" / "packs" / "core" / "overworld"
TURNS = ROOT / "pipeline" / "cache" / "animation" / "cast"
GAME_OUT = ROOT / "game" / "assets" / "overworld" / "cast"
REVIEW_OUT = ROOT / "Concept" / "v0.3" / "animation" / "cast"
BLENDER_SCRIPT = HERE / "blender_cast.py"
SLOTS = ("skin", "hair", "main", "second", "accent", "metal", "eyes")
PART_SLOTS = ("outfit", "hair", "hat", "face", "item")
INK = "#2a1d2b"


# ---------------------------------------------------------------------------------------------------------------------
# The cast, from the game's content


def characters(config: dict, townsfolk: dict, looks: dict) -> dict[str, dict]:
    """id -> {look, who}: the characters cast.json names (the player's look is the creator's start look), then any
    townsperson it does not name, so a new one in the content still gets a sheet."""
    out: dict[str, dict] = {}
    for cid, entry in config["cast"].items():
        if entry.get("look") == "start":
            look = looks["start"]
        elif cid in townsfolk:
            look = townsfolk[cid].get("look", {})
        else:
            raise KeyError(f"{cid} in cast.json is not in townsfolk.jsonc and is not the start look")
        out[cid] = {"look": look, "who": entry.get("who", "a villager"), "entry": entry}
    for cid, person in townsfolk.items():
        out.setdefault(cid, {"look": person.get("look", {}), "who": "a villager", "entry": {}})
    return out


def parts_of(look: dict) -> dict[str, str]:
    parts = {slot: str(look.get(slot, "")) for slot in PART_SLOTS}
    parts["outfit"] = parts["outfit"] or "outfit/tunic"
    return parts


def slot_ramps(look: dict, palette: pixelkit.Palette) -> dict[str, str]:
    """Each colour slot's ramp: the look's choice, or the slot's default (palette.json `slots`)."""
    colours = look.get("colours", {})
    return {slot: str(colours.get(slot, palette.slots[slot])) for slot in SLOTS}


def hex_of(rgb: tuple[int, int, int]) -> str:
    return "#%02x%02x%02x" % tuple(rgb)


def spec_colours(look: dict, palette: pixelkit.Palette, config: dict) -> dict[str, str]:
    """The hex colour of every material the blockout uses: the look's slots (their middle shade) and the fixed ones."""
    shade = config["colours"]["shade"]
    out = {slot: hex_of(palette.shade(ramp, shade)) for slot, ramp in slot_ramps(look, palette).items()}
    out.update({name: hex_of(palette.resolve(ref)) for name, ref in config["colours"]["fixed"].items()})
    return out


def lock_ramps(look: dict, palette: pixelkit.Palette, config: dict) -> list[str]:
    """The ramps a character's frames may use: its own slots' and the fixed colours'."""
    fixed = [ref.partition(".")[0] for ref in config["colours"]["fixed"].values()]
    return list(dict.fromkeys([*slot_ramps(look, palette).values(), *fixed]))


def colour_word(ramp: str, words: dict[str, str]) -> str:
    if ramp in words:
        return words[ramp]
    for prefix in ("cloth_", "hair_", "skin_", "eyes_"):
        if ramp.startswith(prefix):
            return ramp[len(prefix) :].replace("_", " ")
    return ramp.replace("_", " ")


def prompt_for(character: dict, view: str, palette: pixelkit.Palette, config: dict) -> tuple[str, str]:
    """The restyle's prompt and negative for one view: who they are, each part in words with its colours, the view."""
    words_config = config["prompt"]
    words = {
        slot: colour_word(ramp, words_config["words"]) for slot, ramp in slot_ramps(character["look"], palette).items()
    }
    phrases = []
    for part in parts_of(character["look"]).values():
        if not part:
            continue
        if part not in words_config["parts"]:
            raise KeyError(f"no prompt words for {part}: add them to pipeline/animation/cast.json")
        phrases.append(words_config["parts"][part].format(**words))
    outfit = parts_of(character["look"])["outfit"]
    boots = words_config["boots"].get(outfit, words_config["boots"]["default"]).format(**words)
    view_words = words_config["views"][view]
    text = words_config["body"].format(who=character["who"], parts=", ".join(phrases), boots=boots, view=view_words)
    return text, f"{words_config['negative']}, {words_config['view_negative'][view]}"


def turn_path(cid: str, view: str) -> Path:
    return TURNS / cid / f"{view}.png"


def comfy_job(cid: str, view: str, character: dict, palette: pixelkit.Palette, config: dict) -> dict:
    """A job for pipeline/art/generate.py: img2img from the turn, cached under its id."""
    comfy = config["comfy"]
    text, negative = prompt_for(character, view, palette, config)
    job_id = f"cast-{cid}-{view}"
    seeds = character["entry"].get("seeds", {})
    width, height = config["camera"]["render"]
    return {
        "id": job_id,
        "checkpoint": comfy["checkpoint"],
        "lora": comfy["lora"],
        "lora_strength": comfy["lora_strength"],
        "prefix": config["prompt"]["prefix"],
        "prompt": text,
        "suffix": config["prompt"]["suffix"],
        "negative": negative,
        "width": width,
        "height": height,
        "steps": comfy["steps"],
        "cfg": comfy["cfg"],
        "sampler": comfy["sampler"],
        "scheduler": comfy["scheduler"],
        "rmbg": comfy["rmbg"],
        "candidates": comfy["candidates"],
        "seed": int(seeds.get(view, int(hashlib.sha256(job_id.encode()).hexdigest()[:8], 16))),
        "init": {"image": str(turn_path(cid, view).relative_to(ROOT)), "denoise": comfy["denoise"], "matte": "#ffffff"},
    }


# ---------------------------------------------------------------------------------------------------------------------
# Frames: cut and assemble (pure; tested in test_cast.py). Picking and guarding are in pipeline/art/held.py.


def registered_cut(
    frames: list[np.ndarray], size: list[int], colors: int, alpha_cut: float, ramps: list[str]
) -> list[Image.Image]:
    """Every frame of a character cut the same way: the whole camera frame down to `size` (no crop, no per-frame fit),
    one shared set of colours, an ink outline, then locked to the character's ramps.

    LEARN: fitting each frame to its own bounding box makes every view fill the cell, so a narrow side view is drawn as
    tall as the front even when its hair is lower, and a figure with a hat shrinks. Cutting the camera's frame instead keeps
    the model's measurements: the same scale for every view and every character, and the feet always on one row."""
    width, height = size
    small = [gen.resize_premultiplied(frame, (width, height)) for frame in frames]
    opaque = [frame[..., 3] > alpha_cut for frame in small]
    rgb = [np.round(frame[..., :3] * 255) for frame in small]
    solid = np.concatenate([colour[mask] for colour, mask in zip(rgb, opaque, strict=True)])
    if len(solid) == 0:
        raise ValueError("every frame is empty after the alpha cut")
    shared = gen.palette_of(solid, colors)
    images = []
    for colour, mask in zip(rgb, opaque, strict=True):
        quantized = gen.apply_palette(colour, shared)
        canvas = np.zeros((height, width, 4), np.uint8)
        canvas[mask, :3] = quantized[mask]
        canvas[mask, 3] = 255
        images.append(Image.fromarray(gen.outline(canvas, INK), "RGBA"))
    locked = gen.locked([(str(i), image) for i, image in enumerate(images)], {"lock": True, "lock_ramps": ramps})
    return [image for _, image in locked]


def assemble(stops: dict[str, Image.Image], sheet_config: dict) -> Image.Image:
    """The sheet: one row per facing, one column per pose. Idle is the stop frame breathed (the body settles a pixel)."""
    width, height = next(iter(stops.values())).size
    rows, columns, idle = sheet_config["rows"], sheet_config["columns"], sheet_config["idle"]
    sheet = Image.new("RGBA", (width * len(columns), height * len(rows)), (0, 0, 0, 0))
    for r, row in enumerate(rows):
        stop = stops[row["view"]]
        if row.get("mirror"):
            stop = stop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        poses = {
            "stop": stop,
            "idle": Image.fromarray(gen.breathe(np.asarray(stop), idle["drop"], idle["waist"]), "RGBA"),
        }
        for c, column in enumerate(columns):
            if column not in poses:
                raise KeyError(f"no pose {column!r} (stop or idle)")
            sheet.paste(poses[column], (c * width, r * height))
    return sheet


def ground_row(camera: dict, height: int) -> int:
    """The row of a frame that the ground (z = 0) falls on: where the game puts a character's feet."""
    top = camera["center_z"] + camera["height"] / 2
    return round(top / camera["height"] * height)


def index_entry(cid: str, look: dict) -> dict:
    return {"file": f"{cid}.png", "look": look}


def stale(index: dict, cast: dict[str, dict]) -> list[str]:
    """The characters whose sheet is missing or was made from a different look than the content has now."""
    sheets = index.get("sheets", {})
    return [cid for cid, character in cast.items() if sheets.get(cid, {}).get("look") != character["look"]]


# ---------------------------------------------------------------------------------------------------------------------
# Stages


def blockout_digest() -> str:
    """A digest of the Blender code that builds and renders a blockout, so a turn made by older code is not reused."""
    digest = hashlib.sha256()
    for script in (BLENDER_SCRIPT, HERE / "blender_base.py"):
        digest.update(script.read_bytes())
    return digest.hexdigest()[:16]


def load_cast(config: dict, only: str | None) -> dict[str, dict]:
    townsfolk = read_jsonc((CONTENT / "townsfolk.jsonc").read_text())
    looks = read_jsonc((CONTENT / "looks.jsonc").read_text())
    cast = characters(config, townsfolk, looks)
    if only:
        wanted = [token.strip() for token in only.split(",") if token.strip()]
        missing = [cid for cid in wanted if cid not in cast]
        if missing:
            sys.exit(f"--only names no character: {', '.join(missing)}")
        cast = {cid: cast[cid] for cid in wanted}
    return cast


def authored_sheet(cid: str, character: dict) -> Path | None:
    """Reviewed replacements have their own source importer; a cast rebuild must preserve them."""
    if not character["entry"].get("authored_sheet", False):
        return None
    path = GAME_OUT / f"{cid}.png"
    if not path.exists():
        sys.exit(f"missing authored sheet {path}: run game/tools/import_player_sheets.gd first")
    return path


def stage_turns(cast: dict, palette: pixelkit.Palette, config: dict, force: bool) -> None:
    for cid, character in cast.items():
        if authored_sheet(cid, character):
            print(f"  keep authored sheet {cid}")
            continue
        blender = os.environ.get("BLENDER") or shutil.which("blender")
        if not blender:
            sys.exit("no blender on PATH (set BLENDER=/path/to/blender)")
        folder = TURNS / cid
        spec = {
            "id": cid,
            "parts": parts_of(character["look"]),
            "colours": spec_colours(character["look"], palette, config),
            "camera": config["camera"],
            "views": config["views"],
            **config["blockout"],
            "out_dir": str(folder),
            "blend": str(folder / "model.blend"),
            # A change to the blockout code renders the turns again, as a change to the look does.
            "code": blockout_digest(),
        }
        if character.get("masks"):
            # Optional diagnostic masks are useful when inspecting the cast blockout's component coverage.
            spec["masks"] = character["masks"]
        text = json.dumps(spec, indent=1, sort_keys=True)
        spec_path = folder / "spec.json"
        rendered = all(turn_path(cid, view).exists() for view in config["views"])
        if rendered and spec_path.exists() and spec_path.read_text() == text and not force:
            print(f"  have {cid}")
            continue
        folder.mkdir(parents=True, exist_ok=True)
        for view in config["views"]:
            turn_path(cid, view).unlink(missing_ok=True)
        spec_path.write_text(text)
        command = [
            blender,
            "--background",
            "--factory-startup",
            "--python",
            str(BLENDER_SCRIPT),
            "--",
            "--spec",
            str(spec_path),
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0 or not all(turn_path(cid, view).exists() for view in config["views"]):
            print(result.stdout[-3000:], result.stderr[-3000:])
            sys.exit(f"blender failed for {cid}")
        print(f"  turned {cid} ({', '.join(config['views'])})", flush=True)


def stage_restyle(cast: dict, palette: pixelkit.Palette, config: dict, force: bool) -> None:
    url = config["comfy"]["url"]
    for cid, character in cast.items():
        if authored_sheet(cid, character):
            print(f"  keep authored sheet {cid}")
            continue
        for view in config["views"]:
            if not turn_path(cid, view).exists():
                sys.exit(f"no turn for {cid} {view}: run the turns stage first")
            gen.ensure_raws(url, comfy_job(cid, view, character, palette, config), force, False)


def load_alpha(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)[..., 3] / 255


def character_frames(
    cid: str, character: dict, palette: pixelkit.Palette, config: dict
) -> tuple[dict[str, np.ndarray], dict]:
    """Each view's chosen restyle, held inside its turn's outline; with what was chosen and why."""
    url = config["comfy"]["url"]
    overrides = character["entry"].get("picks", {})
    frames, report = {}, {}
    for view in config["views"]:
        raws = gen.ensure_raws(url, comfy_job(cid, view, character, palette, config), False, True)
        if raws is None:
            sys.exit(f"no cached restyle for {cid} {view}: run the restyle stage first")
        turn_alpha = load_alpha(turn_path(cid, view))
        chosen, scores = pick(raws, turn_alpha, overrides.get(view))
        frames[view] = guarded(raws[chosen], turn_alpha, config["sheet"]["guard"])
        report[view] = {"pick": chosen, "iou": [round(s, 3) for s in scores], "override": view in overrides}
    return frames, report


def stops_at(frames: dict[str, np.ndarray], size: list[int], ramps: list[str], config: dict) -> dict[str, Image.Image]:
    views = list(frames)
    sheet = config["sheet"]
    cut = registered_cut([frames[v] for v in views], size, sheet["colors"], sheet["alpha_cut"], ramps)
    return dict(zip(views, cut, strict=True))


def review(sheet: Image.Image, frame: tuple[int, int], label: str, path: Path, config: dict) -> None:
    """The sheet larger, on the town's grass, with its rows and columns named."""
    scale = max(1, round(216 / frame[1]))
    big = sheet.resize((sheet.width * scale, sheet.height * scale), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (big.width + 60, big.height + 40), (134, 196, 90, 255))
    canvas.alpha_composite(big, (52, 30))
    draw = ImageDraw.Draw(canvas)
    draw.text((4, 4), label, fill=(40, 30, 40, 255))
    for c, column in enumerate(config["sheet"]["columns"]):
        draw.text((52 + c * frame[0] * scale + 4, 16), column, fill=(40, 30, 40, 255))
    for r, row in enumerate(config["sheet"]["rows"]):
        draw.text((4, 30 + r * frame[1] * scale + frame[1] * scale // 2), row["facing"], fill=(40, 30, 40, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def overview(sheets: dict[str, Image.Image], frame: tuple[int, int], path: Path) -> None:
    """Every character's four standing frames, side by side, at twice size: the cast at a glance."""
    scale, columns = 2, 6
    cell_w, cell_h = frame[0] * 4 * scale + 12, frame[1] * scale + 22
    rows = (len(sheets) + columns - 1) // columns
    canvas = Image.new("RGBA", (cell_w * columns, cell_h * rows), (134, 196, 90, 255))
    draw = ImageDraw.Draw(canvas)
    for i, (cid, sheet) in enumerate(sheets.items()):
        x, y = (i % columns) * cell_w + 6, (i // columns) * cell_h + 4
        for r in range(4):
            stop = sheet.crop((0, r * frame[1], frame[0], (r + 1) * frame[1]))
            canvas.alpha_composite(
                stop.resize((frame[0] * scale, frame[1] * scale), Image.Resampling.NEAREST),
                (x + r * frame[0] * scale, y),
            )
        draw.text((x, y + frame[1] * scale + 4), cid, fill=(40, 30, 40, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def world_scale() -> dict:
    """The overworld's one scale (ADR-0064): the tile and the person frame, shared with OverworldScale."""
    return read_jsonc(SCALE.read_text())


def stage_sheets(cast: dict, palette: pixelkit.Palette, config: dict) -> None:
    sheet_config = config["sheet"]
    scale = world_scale()
    size = scale["person"]
    index_path = GAME_OUT / "cast.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}
    layout = {
        "frame": size,
        "tile": scale["tile"],
        "ground": ground_row(config["camera"], size[1]),
        "rows": [row["facing"] for row in sheet_config["rows"]],
        "columns": sheet_config["columns"],
    }
    if any(index.get(key) != value for key, value in layout.items()):
        index = {}  # a new layout: every sheet in the old index was cut for another one
    index = {
        "_doc": "Made by pipeline/animation/cast.py (ADR-0063); do not edit. A look with a sheet here draws from it.",
        **layout,
        "sheets": index.get("sheets", {}),
    }
    picks: dict[str, dict] = {}
    made: dict[str, Image.Image] = {}
    for cid, character in cast.items():
        authored = authored_sheet(cid, character)
        if authored:
            made[cid] = Image.open(authored).convert("RGBA")
            index["sheets"][cid] = index_entry(cid, character["look"])
            print(f"  keep authored sheet {cid}")
            continue
        frames, picks[cid] = character_frames(cid, character, palette, config)
        ramps = lock_ramps(character["look"], palette, config)
        sheet = assemble(stops_at(frames, size, ramps, config), sheet_config)
        GAME_OUT.mkdir(parents=True, exist_ok=True)
        sheet.save(GAME_OUT / f"{cid}.png", optimize=True)
        index["sheets"][cid] = index_entry(cid, character["look"])
        made[cid] = sheet
        for review_size in [size, *sheet_config["review_sizes"]]:
            big = sheet if review_size == size else assemble(stops_at(frames, review_size, ramps, config), sheet_config)
            label = f"{cid} {review_size[0]}x{review_size[1]}"
            review(
                big, tuple(review_size), label, REVIEW_OUT / f"{review_size[0]}x{review_size[1]}" / f"{cid}.png", config
            )
        print(
            f"  sheet {cid}: picks "
            + ", ".join(f"{v} {r['pick']} ({max(r['iou']):.2f})" for v, r in picks[cid].items()),
            flush=True,
        )
    index_path.write_text(json.dumps(index, indent=1, sort_keys=True) + "\n")
    picks_path = REVIEW_OUT / "picks.json"
    old_picks = json.loads(picks_path.read_text()) if picks_path.exists() else {}
    picks_path.parent.mkdir(parents=True, exist_ok=True)
    picks_path.write_text(json.dumps({**old_picks, **picks}, indent=1, sort_keys=True) + "\n")
    every = {cid: Image.open(GAME_OUT / entry["file"]).convert("RGBA") for cid, entry in index["sheets"].items()}
    overview(every, tuple(size), REVIEW_OUT / "overview.png")
    print(f"  wrote {len(made)} sheet(s) to {GAME_OUT.relative_to(ROOT)}, index {index_path.relative_to(ROOT)}")


def stage_check(cast: dict) -> None:
    index_path = GAME_OUT / "cast.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}
    behind = stale(index, cast)
    if behind:
        print("no sheet for the current look (drawn from parts until made): " + ", ".join(behind))
    else:
        print(f"every look in the cast has its sheet ({len(cast)})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("stage", choices=["turns", "restyle", "sheets", "check"])
    parser.add_argument("--only", help="comma-separated character ids")
    parser.add_argument("--force", action="store_true", help="render again even when a cached render matches")
    args = parser.parse_args()

    config = json.loads(CONFIG.read_text())
    palette = pixelkit.Palette.load()
    cast = load_cast(config, args.only)
    if args.stage == "turns":
        stage_turns(cast, palette, config, args.force)
    elif args.stage == "restyle":
        stage_restyle(cast, palette, config, args.force)
    elif args.stage == "sheets":
        stage_sheets(cast, palette, config)
    else:
        stage_check(cast)


if __name__ == "__main__":
    main()
