"""Builds Lanternroot's overworld pictures into game/assets/overworld/ and checks every one is crisp.

    uv run --project pipeline python pipeline/pixel/build.py            # build, lint, write review sheets
    uv run --project pipeline python pipeline/pixel/build.py --lint     # only check what is there

What it writes (the game reads these through OverworldArt):
    palette.json                    the palette, for the game's colour swaps
    tiles/terrain.png, terrain.json ground tiles (terrain.py)
    characters/<part>.png           each character part as a 3 x 3 sheet (characters.py), parts.json lists them
    hotaru.png                      the fairy, 2 x 3 frames of 32 x 32
    hotaru-notice.png               her notice mark, a 7 x 15 "!" (sprites/hotaru.sprite, frame notice)
    props/<id>.png                  small props drawn by hand (sprites/props.sprite)
    portraits/<id>.png              the townspeople's portraits, copied from the player's set
Buildings, landmarks, trees and larger props come from ComfyUI (`scripts/pixel.sh --comfy`, manifest.json) and land in
the same folders; the lint covers them too.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import characters
import pixelkit
import terrain
import landmarks
from pixelkit import Palette

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "overworld"
SHOTS = ROOT / "shots" / "pixel"
PORTRAITS = ROOT / "Concept" / "v0.3" / "Townspeople"
# Pictures not held to the palette: the portraits are painted, at their own resolution.
UNLOCKED = ("portraits/",)


def build_characters(palette: Palette) -> list[str]:
    parts = characters.load_parts(pixelkit.HERE / "sprites", palette)
    names = []
    for name, sprite in sorted(parts.items()):
        if name == "hotaru" or not name.split("/")[0] in ("body", "outfit", "hair", "hat", "face", "item"):
            continue
        pixelkit.save(characters.sheet_of(sprite), OUT / "characters" / f"{name.replace('/', '-')}.png")
        names.append(name)
    (OUT / "characters" / "parts.json").write_text(
        json.dumps(
            {
                "frame": [characters.FRAME_W, characters.FRAME_H],
                "parts": names,
                "depth_by_facing": {"item": {"up": -1}},
                "attachments": {"item": "hand"},
            },
            indent=1,
        )
        + "\n"
    )
    return names


def build_hotaru(palette: Palette) -> None:
    sprite = pixelkit.load(pixelkit.HERE / "sprites" / "hotaru.sprite", palette)["hotaru"]
    frame = sprite.width
    sheet = pixelkit.blank(frame * 2, frame * 3)
    for row, facing in enumerate(("down", "up", "left")):
        for col, wing in enumerate(("up", "down")):
            sheet[row * frame : (row + 1) * frame, col * frame : (col + 1) * frame] = sprite.frames[f"{facing}.{wing}"]
    pixelkit.save(sheet, OUT / "hotaru.png")
    # The notice mark is drawn in the frame at its top left: cut out its 7 x 15 box.
    pixelkit.save(np.ascontiguousarray(sprite.frames["notice"][:15, :7]), OUT / "hotaru-notice.png")


def build_props(palette: Palette) -> list[str]:
    path = pixelkit.HERE / "sprites" / "props.sprite"
    if not path.exists():
        return []
    names = []
    sizes = {}
    for name, sprite in pixelkit.load(path, palette).items():
        frames = list(sprite.frames.values())
        strip = np.concatenate(frames, axis=1) if len(frames) > 1 else frames[0]
        pixelkit.save(strip, OUT / "props" / f"{name}.png")
        sizes[name] = {"size": [sprite.width, sprite.height], "frames": len(frames)}
        names.append(name)
    (OUT / "props" / "props.json").write_text(json.dumps(sizes, indent=1, sort_keys=True) + "\n")
    return names


def build_terrain(palette: Palette) -> None:
    sheet, layout = terrain.atlas(palette)
    pixelkit.save(sheet, OUT / "tiles" / "terrain.png")
    (OUT / "tiles" / "terrain.json").write_text(json.dumps(layout, indent=1) + "\n")


def copy_portraits() -> int:
    if not PORTRAITS.exists():
        return 0
    count = 0
    for source in sorted(PORTRAITS.glob("*.png")):
        target = OUT / "portraits" / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists() or target.read_bytes() != source.read_bytes():
            shutil.copyfile(source, target)
        count += 1
    return count


def review(palette: Palette, output_dir: Path) -> None:
    """A big sheet of every character part on a grass ground, to look at after a change."""
    parts = characters.load_parts(pixelkit.HERE / "sprites", palette)
    sheets = [(n, characters.sheet_of(s)) for n, s in sorted(parts.items()) if "/" in n]
    output_dir.mkdir(parents=True, exist_ok=True)
    pixelkit.preview(sheets, 4, "#86c45a").save(output_dir / "parts.png")


def validate_manifest(
    path: Path = pixelkit.HERE / "manifest.json",
    candidates_dir: Path = pixelkit.HERE / "candidates",
) -> dict[str, tuple[str, Path, str | None]]:
    """Validate the Comfy manifest and any explicitly approved imagegen overrides.

    The returned mapping is asset id -> (manifest output, validated candidate path, named correction). A missing or
    null ``approved_imagegen_candidate`` leaves the ComfyUI source unchanged.
    """
    manifest = json.loads(path.read_text())
    styles = manifest.get("styles")
    assets = manifest.get("assets")
    if not isinstance(styles, dict) or not isinstance(assets, list):
        raise ValueError(f"{path}: expected a styles object and an assets list")

    by_id: dict[str, dict] = {}
    outputs: set[str] = set()
    approved: dict[str, tuple[str, Path, str | None]] = {}
    candidate_paths: set[Path] = set()
    if candidates_dir.is_symlink():
        raise ValueError(f"imagegen candidate directory must not be a symlink: {candidates_dir}")
    candidate_root = candidates_dir.resolve()
    palette = Palette.load()
    for index, asset in enumerate(assets):
        label = f"{path}: assets[{index}]"
        if not isinstance(asset, dict):
            raise ValueError(f"{label}: expected an asset object")
        asset_id = asset.get("id")
        output = asset.get("out")
        style_name = asset.get("style")
        if not isinstance(asset_id, str) or not asset_id:
            raise ValueError(f"{label}: missing id")
        if asset_id in by_id:
            raise ValueError(f"{label}: duplicate id {asset_id!r}")
        if not isinstance(output, str) or "\\" in output:
            raise ValueError(f"{asset_id}: output must be a relative path under overworld/")
        output_parts = output.split("/")
        if (
            len(output_parts) < 2
            or output_parts[0] != "overworld"
            or any(part in ("", ".", "..") for part in output_parts)
        ):
            raise ValueError(f"{asset_id}: output must stay under overworld/ assets")
        if output in outputs:
            raise ValueError(f"{asset_id}: duplicate output path {output!r}")
        if not isinstance(style_name, str) or not isinstance(styles.get(style_name), dict):
            raise ValueError(f"{asset_id}: unknown style {style_name!r}")

        style = styles[style_name]
        candidates = asset.get("candidates", style.get("candidates", 1))
        pick = asset.get("pick", 0)
        if type(asset.get("seed")) is not int:
            raise ValueError(f"{asset_id}: set an explicit integer seed")
        if type(candidates) is not int or candidates < 1:
            raise ValueError(f"{asset_id}: candidates must be a positive integer")
        if type(pick) is not int or not 0 <= pick < candidates:
            raise ValueError(f"{asset_id}: pick {pick!r} is outside {candidates} candidate(s)")

        candidate = asset.get("approved_imagegen_candidate")
        if candidate is not None:
            if not isinstance(candidate, dict):
                raise ValueError(f"{asset_id}: approved_imagegen_candidate must be an object or null")
            for key in ("path", "source", "method", "approval"):
                value = candidate.get(key)
                if not isinstance(value, str) or not value.strip():
                    raise ValueError(f"{asset_id}: approved_imagegen_candidate.{key} must be a non-empty string")

            candidate_ref = candidate["path"]
            candidate_parts = candidate_ref.split("/")
            if (
                "\\" in candidate_ref
                or candidate_ref.startswith("/")
                or any(part in ("", ".", "..") for part in candidate_parts)
                or candidate_parts[0] != "candidates"
                or len(candidate_parts) < 2
                or not candidate_ref.endswith(".png")
            ):
                raise ValueError(
                    f"{asset_id}: candidate path must be a .png relative path under pipeline/pixel/candidates/"
                )
            try:
                candidate_path = (candidate_root.parent / candidate_ref).resolve(strict=True)
                candidate_path.relative_to(candidate_root)
            except (OSError, ValueError):
                raise ValueError(
                    f"{asset_id}: candidate {candidate_ref!r} is missing or resolves outside {candidate_root}"
                ) from None
            if not candidate_path.is_file():
                raise ValueError(f"{asset_id}: candidate {candidate_ref!r} is not a file")
            if candidate_path in candidate_paths:
                raise ValueError(f"{asset_id}: candidate {candidate_ref!r} is assigned to more than one asset")

            correction = candidate.get("correction")
            if correction is not None:
                if correction != "rootgate_lattice_clasp_v1" or asset_id != "ow-landmark-rootgate":
                    raise ValueError(f"{asset_id}: unknown or unsupported candidate correction {correction!r}")

            style_post = style.get("post", {})
            asset_post = asset.get("post", {})
            if not isinstance(style_post, dict) or not isinstance(asset_post, dict):
                raise ValueError(f"{asset_id}: sprite post settings must be objects")
            post = {**style_post, **asset_post}
            size = post.get("size")
            if post.get("kind") != "sprite" or not isinstance(size, list) or len(size) != 2 or any(
                type(dimension) is not int or dimension <= 0 for dimension in size
            ):
                raise ValueError(
                    f"{asset_id}: approved imagegen candidates require a sprite post with positive [width, height]"
                )
            try:
                with Image.open(candidate_path) as opened:
                    if opened.format != "PNG":
                        raise ValueError(f"{asset_id}: approved candidate {candidate_ref!r} is not a PNG file")
                    image = opened.convert("RGBA")
            except OSError as error:
                raise ValueError(f"{asset_id}: cannot read candidate {candidate_ref!r}: {error}") from None
            if image.size != tuple(size):
                raise ValueError(
                    f"{asset_id}: candidate {candidate_ref!r} is {image.width}x{image.height}; "
                    f"manifest declares {size[0]}x{size[1]}"
                )
            problems = pixelkit.problems(np.asarray(image, dtype=np.uint8), palette, candidate_ref)
            if problems:
                raise ValueError(
                    f"{asset_id}: approved candidate fails shared-palette/alpha lint: " + "; ".join(problems)
                )
            if correction == "rootgate_lattice_clasp_v1":
                image = landmarks.rootgate_lattice_clasp_v1(image, palette)
                problems = pixelkit.problems(
                    np.asarray(image, dtype=np.uint8), palette, f"{candidate_ref} + {correction}"
                )
                if problems:
                    raise ValueError(
                        f"{asset_id}: corrected candidate fails shared-palette/alpha lint: " + "; ".join(problems)
                    )
            candidate_paths.add(candidate_path)
            approved[asset_id] = (output, candidate_path, correction)

        by_id[asset_id] = asset
        outputs.add(output)

    order = {asset_id: index for index, asset_id in enumerate(by_id)}
    for asset_id, asset in by_id.items():
        if "raw_from" not in asset:
            continue
        source_id = asset["raw_from"]
        if not isinstance(source_id, str) or not source_id:
            raise ValueError(f"{asset_id}: raw_from must name a source asset")
        if source_id == asset_id:
            raise ValueError(f"{asset_id}: raw_from cannot refer to itself")
        source = by_id.get(source_id)
        if source is None:
            raise ValueError(f"{asset_id}: raw_from source {source_id!r} is not in the manifest")
        if order[source_id] > order[asset_id]:
            raise ValueError(f"{asset_id}: raw_from source {source_id!r} must appear first")
        if source.get("raw_from"):
            raise ValueError(f"{asset_id}: raw_from source {source_id!r} does not own a raw render")
        source_style = styles[source["style"]]
        source_candidates = source.get("candidates", source_style.get("candidates", 1))
        asset_style = styles[asset["style"]]
        candidates = asset.get("candidates", asset_style.get("candidates", 1))
        if candidates > source_candidates:
            raise ValueError(
                f"{asset_id}: asks for {candidates} candidates from {source_id!r}, which has {source_candidates}"
            )

    return approved


def promote_approved_candidates(
    approved: dict[str, tuple[str, Path, str | None]], output_root: Path = OUT
) -> None:
    """Copy approved candidates to their normal manifest outputs after generated corrections are applied."""
    root = output_root.resolve()
    palette = Palette.load()
    for asset_id, (output, source, correction) in approved.items():
        relative = Path(*Path(output).parts[1:])
        relative = relative.with_name(relative.name + ".png")
        target = output_root / relative
        if target.is_symlink():
            raise ValueError(f"{asset_id}: refusing to promote through output symlink {target}")
        if not target.resolve().is_relative_to(root):
            raise ValueError(f"{asset_id}: promotion target resolves outside {root}")
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.resolve().is_relative_to(root):
            raise ValueError(f"{asset_id}: promotion target resolves outside {root}")
        if correction:
            with Image.open(source) as opened:
                image = landmarks.rootgate_lattice_clasp_v1(opened, palette)
            image.save(target, optimize=True)
        else:
            shutil.copyfile(source, target)
        try:
            shown_source = source.relative_to(pixelkit.HERE)
        except ValueError:
            shown_source = source
        print(f"promoted approved imagegen candidate: {asset_id} <- {shown_source}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--lint", action="store_true", help="only check the pictures already built")
    parser.add_argument(
        "--review-dir", type=Path, default=SHOTS, help="where to write the character-parts review sheet"
    )
    parser.add_argument("--only", choices=["hotaru", "terrain"], help="build only this picture (the others stay as they are)")
    args = parser.parse_args()
    if args.only == "hotaru":
        build_hotaru(Palette.load())
        problems = pixelkit.lint(OUT, Palette.load(), UNLOCKED)
        hers = [p for p in problems if "hotaru" in p]
        for problem in hers:
            print(f"  not crisp: {problem}")
        print("lint: clean" if not hers else f"lint: {len(hers)} problem(s)")
        return 1 if hers else 0
    if args.only == "terrain":
        palette = Palette.load()
        build_terrain(palette)
        with Image.open(OUT / "tiles" / "terrain.png") as image:
            problems = pixelkit.problems(np.asarray(image.convert("RGBA")), palette, "terrain")
        for problem in problems:
            print(f"  not crisp: {problem}")
        print("terrain built; lint: clean" if not problems else f"lint: {len(problems)} problem(s)")
        return 1 if problems else 0
    approved_candidates = validate_manifest()
    palette = Palette.load()
    if not args.lint:
        OUT.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(pixelkit.PALETTE_FILE, OUT / "palette.json")
        build_terrain(palette)
        parts = build_characters(palette)
        build_hotaru(palette)
        props = build_props(palette)
        landmarks.seal_rootgate(OUT / "buildings" / "rootgate.png", palette)
        promote_approved_candidates(approved_candidates)
        portraits = copy_portraits()
        review(palette, args.review_dir)
        print(f"built {len(parts)} character parts, {len(props)} props, {portraits} portraits, terrain, hotaru")
    problems = pixelkit.lint(OUT, palette, UNLOCKED)
    for problem in problems:
        print(f"  not crisp: {problem}")
    print("lint: clean" if not problems else f"lint: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
