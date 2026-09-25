#!/usr/bin/env python3
"""Spell sprites from the concept boards (Concept/spellAnimations/), redrawn by ComfyUI for the stage (ADR-0008).

  scripts/sprites.sh fx                 render what is not cached, then post-process everything into game/assets/fx/spell
  scripts/sprites.sh fx --only bolt-*   ids, or prefixes ending in *
  scripts/sprites.sh fx --force ...     render again even though a raw is cached
  scripts/sprites.sh fx --reprocess     post-process the cached raws only (no ComfyUI)

Each effect is one quadrant of a board, cleaned of the board's dark halo, redrawn at 1024 by NovaAnimeXL img2img with
the effect described (fx.json), then made a glow sprite: light on black, so its alpha is its brightness.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from comfy import Comfy, Graph  # noqa: E402

REPO = HERE.parents[1]
BOARDS = REPO / "Concept" / "spellAnimations"
CACHE = REPO / "pipeline" / "cache" / "sprites" / "fx"
QUADRANTS = {"tl": (0, 0), "tr": (1, 0), "bl": (0, 1), "br": (1, 1)}


def manifest() -> dict:
    return json.loads((HERE / "fx.json").read_text())


def source(effect: dict) -> Image.Image:
    """The effect's quadrant of its board, on pure black: the board's dark halo (a dim, saturated fill around each
    effect, drawn to separate it from the board) is pushed down to black so the redraw starts from light alone."""
    board = Image.open(BOARDS / effect["board"]).convert("RGB")
    column, row = QUADRANTS[effect["quadrant"]]
    w, h = board.width // 2, board.height // 2
    crop = board.crop((column * w, row * h, (column + 1) * w, (row + 1) * h))
    if effect.get("flip"):
        crop = crop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    rgb = np.asarray(crop, dtype=np.float32) / 255
    light = rgb.max(axis=2, keepdims=True)
    keep = np.clip((light - 0.28) / 0.3, 0, 1)
    rgb = rgb * keep
    if effect.get("recolor"):
        # A board drawn in one element's colours, redrawn as another: its light kept, its hue replaced, so img2img
        # starts from the right colours (it holds on to a source's hues at any denoise that keeps its shapes).
        hue = np.array([int(effect["recolor"].lstrip("#")[i : i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)
        value = rgb.max(axis=2, keepdims=True)
        rgb = np.clip(value * hue + np.clip(value - 0.75, 0, 1) * 1.6, 0, 1)
    return Image.fromarray(np.round(rgb * 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS)


def render(comfy: Comfy, effect: dict, style: dict) -> Image.Image:
    graph = Graph("fx_still")
    graph.set("rw:source", image=comfy.upload(source(effect), f"fx-{effect['id']}-source.png"))
    graph.set("rw:positive", text=style["prefix"] + effect["prompt"] + style["suffix"])
    graph.set("rw:negative", text=style["negative"])
    graph.set("rw:sampler", seed=int(effect["seed"]), denoise=float(effect.get("denoise", 0.5)), steps=28, cfg=6.0)
    graph.set("rw:detail", strength_model=0.3, strength_clip=0.3)
    graph.set("rw:save", filename_prefix=f"rootward/fx/{effect['id']}")
    return comfy.run(graph)["rw:save"][0].convert("RGB")


def glow(raw: Image.Image, size: int) -> Image.Image:
    """Light on black into a sprite whose alpha is its brightness, trimmed to the light and centred in `size` square.

    LEARN: light adds. Drawn additively, black contributes nothing, so a render on black already is the effect; making
    brightness the alpha (and dividing it back out of the colour) lets the same sprite also draw with ordinary blending."""
    rgb = np.asarray(raw, dtype=np.float32) / 255
    black = 0.06
    alpha = np.clip((rgb.max(axis=2) - black) / (1 - black), 0, 1) ** 0.85
    height, width = alpha.shape
    ys, xs = np.mgrid[0:height, 0:width]
    reach = np.sqrt(((xs - width / 2) / (width / 2)) ** 2 + ((ys - height / 2) / (height / 2)) ** 2)
    alpha *= np.clip((1.02 - reach) / 0.25, 0, 1)  # light running off the render fades out before the edge
    colour = np.where(alpha[..., None] > 1e-3, rgb / np.maximum(alpha[..., None], 1e-3), 0)
    rgba = np.dstack([np.clip(colour, 0, 1), alpha])
    ys, xs = np.nonzero(alpha > 0.04)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # Keep the effect centred on the render's centre (a bolt's head, a burst's core), so it scales from there.
    cx, cy = width / 2, height / 2
    half = max(cx - x0, x1 - cx, cy - y0, y1 - cy) * 1.04
    box = (round(cx - half), round(cy - half), round(cx + half), round(cy + half))
    image = Image.fromarray(np.round(rgba * 255).astype(np.uint8), "RGBA").crop(box)
    return image.resize((size, size), Image.LANCZOS)


def tileable_noise(size: int = 256, seed: int = 7) -> Image.Image:
    """Seamless fractal noise for the spell shader (dissolve, wobble, shimmer): three independent fields in r, g, b.

    Value noise: a random lattice per octave, read with smoothstep-weighted interpolation that wraps at the edges, so
    the result is smooth (no square cells) and tiles in both directions."""
    rng = np.random.default_rng(seed)
    coords = np.arange(size) / size
    channels = []
    for _ in range(3):
        field = np.zeros((size, size))
        amplitude, total = 1.0, 0.0
        for cells in (4, 8, 16, 32, 64):
            lattice = rng.random((cells, cells))
            u = coords * cells
            i0 = np.floor(u).astype(int) % cells
            i1 = (i0 + 1) % cells
            f = u - np.floor(u)
            w = f * f * (3 - 2 * f)
            rows0 = lattice[i0][:, i0] * (1 - w)[None, :] + lattice[i0][:, i1] * w[None, :]
            rows1 = lattice[i1][:, i0] * (1 - w)[None, :] + lattice[i1][:, i1] * w[None, :]
            field += (rows0 * (1 - w)[:, None] + rows1 * w[:, None]) * amplitude
            total += amplitude
            amplitude *= 0.55
        field /= total
        field = (field - field.min()) / (field.max() - field.min())
        channels.append(field)
    return Image.fromarray(np.round(np.dstack(channels) * 255).astype(np.uint8), "RGB")


ANIMATE_SIZE = 512
COLUMNS = 8


def animate(comfy: Comfy, effect: dict, style: dict) -> Image.Image:
    """The effect's picture set moving by the video model (Wan 2.1 VACE), as a grid of raw frames on black.

    The first frame is pinned to the picture (mask 0, "keep these pixels"); every other frame is grey with mask 1
    ("draw here"), steered only by the picture as a reference and the motion prompt. So a burst billows and fades, a
    flame flickers, lightning crackles: real drawn motion rather than a still picture scaled and rotated."""
    motion = effect["animate"]
    frames = int(motion.get("frames", 17))
    raw = Image.open(CACHE / f"{effect['id']}.png").convert("RGB").resize((ANIMATE_SIZE, ANIMATE_SIZE), Image.LANCZOS)
    rows = -(-frames // COLUMNS)
    control = Image.new("RGB", (COLUMNS * ANIMATE_SIZE, rows * ANIMATE_SIZE), (128, 128, 128))
    mask = Image.new("RGB", control.size, "white")
    control.paste(raw, (0, 0))
    mask.paste(Image.new("RGB", raw.size, "black"), (0, 0))
    if motion.get("loop"):
        # A loop ends where it began: the last frame is pinned to the picture too.
        row, column = divmod(frames - 1, COLUMNS)
        control.paste(raw, (column * ANIMATE_SIZE, row * ANIMATE_SIZE))
        mask.paste(Image.new("RGB", raw.size, "black"), (column * ANIMATE_SIZE, row * ANIMATE_SIZE))
    graph = Graph("animate_keys")
    graph.remove("rw:matte", "rw:sheet", "rw:save")
    graph.set("rw:poses", image=comfy.upload(control, f"fx-{effect['id']}-control.png"))
    graph.set("rw:mask-sheet", image=comfy.upload(mask, f"fx-{effect['id']}-mask.png"))
    graph.set("rw:frames", columns=COLUMNS, frames=frames)
    graph.set("rw:mask-frames", columns=COLUMNS, frames=frames)
    graph.set("rw:reference", image=comfy.upload(raw, f"fx-{effect['id']}-reference.png"))
    graph.set("rw:positive", text=f"{effect['prompt']}, {motion['motion']}, anime effect animation, smooth motion, "
              "static camera, pure black background")
    graph.set("rw:negative", text="camera movement, zoom, pan, cut, text, watermark, character, person, background "
              "scenery, grey background, white background, blurry, low quality, still image, static frame")
    graph.set("rw:vace", width=ANIMATE_SIZE, height=ANIMATE_SIZE, length=frames, strength=1.0)
    graph.set("rw:speed", strength_model=0.0)
    graph.set("rw:sampler", seed=int(effect["seed"]) + 11, steps=22, cfg=5.0)
    graph.set("rw:shift", shift=8.0)
    graph.set("rw:raw-sheet", columns=COLUMNS)
    graph.set("rw:save-raw", filename_prefix=f"rootward/fx/{effect['id']}-anim")
    return comfy.run(graph)["rw:save-raw"][0].convert("RGB")


def glow_sheet(raw: Image.Image, frames: int, size: int) -> tuple[Image.Image, int]:
    """Every frame of a raw sheet made a glow sprite, all cropped by one box (the union of the light), so the effect
    does not jump about; returns the sheet (COLUMNS wide) and the frame size."""
    rows = -(-frames // COLUMNS)
    w, h = raw.width // COLUMNS, raw.height // rows
    cells = [raw.crop(((i % COLUMNS) * w, (i // COLUMNS) * h, (i % COLUMNS + 1) * w, (i // COLUMNS + 1) * h)) for i in range(frames)]
    stack = np.stack([np.asarray(c, dtype=np.float32) / 255 for c in cells])
    light = stack.max(axis=3).max(axis=0)
    ys, xs = np.nonzero(light > 0.1)
    cx, cy = w / 2, h / 2
    half = max(cx - xs.min(), xs.max() + 1 - cx, cy - ys.min(), ys.max() + 1 - cy) * 1.04
    box = (round(cx - half), round(cy - half), round(cx + half), round(cy + half))
    sheet = Image.new("RGBA", (COLUMNS * size, rows * size), (0, 0, 0, 0))
    for index, cell in enumerate(cells):
        sprite = _glow_frame(cell).crop(box).resize((size, size), Image.LANCZOS)
        sheet.paste(sprite, ((index % COLUMNS) * size, (index // COLUMNS) * size))
    return sheet, size


def _glow_frame(frame: Image.Image) -> Image.Image:
    rgb = np.asarray(frame, dtype=np.float32) / 255
    black = 0.07
    alpha = np.clip((rgb.max(axis=2) - black) / (1 - black), 0, 1) ** 0.85
    h, w = alpha.shape
    ys, xs = np.mgrid[0:h, 0:w]
    reach = np.sqrt(((xs - w / 2) / (w / 2)) ** 2 + ((ys - h / 2) / (h / 2)) ** 2)
    alpha *= np.clip((1.02 - reach) / 0.25, 0, 1)
    colour = np.where(alpha[..., None] > 1e-3, rgb / np.maximum(alpha[..., None], 1e-3), 0)
    return Image.fromarray(np.round(np.dstack([np.clip(colour, 0, 1), alpha]) * 255).astype(np.uint8), "RGBA")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--comfy", default="http://127.0.0.1:8188")
    parser.add_argument("--only")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--reprocess", action="store_true")
    parser.add_argument("--animate", action="store_true", help="also render the effects that name an `animate` motion")
    args = parser.parse_args()
    data = manifest()
    effects = data["effects"]
    if args.only:
        wanted = [w.strip() for w in args.only.split(",")]
        effects = [e for e in effects if any(e["id"].startswith(w[:-1]) if w.endswith("*") else e["id"] == w for w in wanted)]
    out = REPO / data["out"]
    out.mkdir(parents=True, exist_ok=True)
    tileable_noise().save(out / "noise.png", optimize=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    comfy = Comfy(args.comfy)
    done = []
    for effect in effects:
        raw_path = CACHE / f"{effect['id']}.png"
        if args.force or not raw_path.exists():
            if args.reprocess:
                print(f"{effect['id']}: no cached raw, skipped")
                continue
            render(comfy, effect, data["style"]).save(raw_path)
            print(f"{effect['id']}: rendered", flush=True)
        raw = Image.open(raw_path).convert("RGB")
        if effect.get("desaturate"):
            # A sprite the game tints (the seal takes each element's colour) is kept as white light.
            grey = raw.convert("L").point(lambda v: min(255, round(v * 1.25)))
            raw = Image.merge("RGB", [grey, grey, grey])
        sprite = glow(raw, int(effect["size"]))
        sprite.save(out / f"{effect['id']}.png", optimize=True)
        done.append((effect["id"], sprite))
        if args.animate and "animate" in effect:
            anim_path = CACHE / f"{effect['id']}-anim.png"
            if args.force or not anim_path.exists():
                if args.reprocess:
                    continue
                animate(comfy, effect, data["style"]).save(anim_path)
                print(f"{effect['id']}: animated", flush=True)
            motion = effect["animate"]
            frames = int(motion.get("frames", 17))
            size = min(384, int(effect["size"]))
            sheet, _ = glow_sheet(Image.open(anim_path).convert("RGB"), frames, size)
            sheet.save(out / f"{effect['id']}-sheet.webp", quality=88, method=6)
            meta = {"frames": frames, "columns": COLUMNS, "size": size, "fps": float(motion.get("fps", 24)),
                    "loop": bool(motion.get("loop", False))}
            (out / f"{effect['id']}-sheet.json").write_text(json.dumps(meta) + "\n")
    if done:
        thumb = 200
        sheet = Image.new("RGB", (thumb * len(done), thumb + 20), (12, 12, 18))
        draw = ImageDraw.Draw(sheet)
        for index, (name, sprite) in enumerate(done):
            tile = Image.new("RGBA", (thumb, thumb), (12, 12, 18, 255))
            tile.alpha_composite(sprite.resize((thumb, thumb), Image.LANCZOS))
            sheet.paste(tile.convert("RGB"), (index * thumb, 20))
            draw.text((index * thumb + 4, 4), name, fill="white")
        sheet.save(CACHE / "contact.png")
        print(f"contact sheet {CACHE / 'contact.png'}")


if __name__ == "__main__":
    main()
