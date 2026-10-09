"""Builds Lanternroot's overworld pictures into game/assets/overworld/ and checks every one is crisp.

    uv run --project pipeline python pipeline/pixel/build.py            # build, lint, write review sheets
    uv run --project pipeline python pipeline/pixel/build.py --lint     # only check what is there

What it writes (the game reads these through OverworldArt):
    palette.json                    the palette, for the game's colour swaps
    tiles/terrain.png, terrain.json ground tiles (terrain.py)
    characters/<part>.png           each character part as a 3 x 3 sheet (characters.py), parts.json lists them
    hotaru.png                      the firefly, 2 x 3 frames of 16 x 16
    hotaru-notice.png               the firefly's notice mark, a 5 x 7 "!" (sprites/hotaru.sprite, frame notice)
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

import characters
import pixelkit
import terrain
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
    (OUT / "characters" / "parts.json").write_text(json.dumps({"frame": [16, 24], "parts": names}, indent=1) + "\n")
    return names


def build_hotaru(palette: Palette) -> None:
    sprite = pixelkit.load(pixelkit.HERE / "sprites" / "hotaru.sprite", palette)["hotaru"]
    sheet = pixelkit.blank(32, 48)
    for row, facing in enumerate(("down", "up", "left")):
        for col, wing in enumerate(("up", "down")):
            sheet[row * 16 : (row + 1) * 16, col * 16 : (col + 1) * 16] = sprite.frames[f"{facing}.{wing}"]
    pixelkit.save(sheet, OUT / "hotaru.png")
    # The notice mark is drawn in a 16 x 16 frame at its top left: cut out its 5 x 7 box.
    pixelkit.save(np.ascontiguousarray(sprite.frames["notice"][:7, :5]), OUT / "hotaru-notice.png")


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


def review(palette: Palette) -> None:
    """A big sheet of every character part on a grass ground, to look at after a change."""
    parts = characters.load_parts(pixelkit.HERE / "sprites", palette)
    sheets = [(n, characters.sheet_of(s)) for n, s in sorted(parts.items()) if "/" in n]
    SHOTS.mkdir(parents=True, exist_ok=True)
    pixelkit.preview(sheets, 4, "#86c45a").save(SHOTS / "parts.png")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--lint", action="store_true", help="only check the pictures already built")
    args = parser.parse_args()
    palette = Palette.load()
    if not args.lint:
        OUT.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(pixelkit.PALETTE_FILE, OUT / "palette.json")
        build_terrain(palette)
        parts = build_characters(palette)
        build_hotaru(palette)
        props = build_props(palette)
        portraits = copy_portraits()
        review(palette)
        print(f"built {len(parts)} character parts, {len(props)} props, {portraits} portraits, terrain, hotaru")
    problems = pixelkit.lint(OUT, palette, UNLOCKED)
    for problem in problems:
        print(f"  not crisp: {problem}")
    print("lint: clean" if not problems else f"lint: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
