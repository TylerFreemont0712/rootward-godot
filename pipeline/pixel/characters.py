"""Characters from parts: the layer order, the sheet layout the game reads, and a look's colours.

A sheet is three rows (facing down, up, left) of three frames (standing, step a, step b), each 16 x 24. The game
mirrors the left row for right. A part without its own step frame uses its standing frame (hair, hats).
`python pipeline/pixel/characters.py --preview shots/pixel/look.png` draws a few looks, big, to judge by eye.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

import pixelkit
from pixelkit import Palette, Sprite

FRAME_W = 16
FRAME_H = 24
FACINGS = ("down", "up", "left")
POSES = ("stand", "step_a", "step_b")
## Parts in drawing order: what comes later covers what came before.
LAYERS = ("body", "outfit", "face", "hair", "hat", "item")


def frame_of(sprite: Sprite, facing: str, pose: str) -> np.ndarray:
    for label in (f"{facing}.{pose}", facing):
        if label in sprite.frames:
            return sprite.frames[label]
    return pixelkit.blank(sprite.width, sprite.height)


def sheet_of(sprite: Sprite) -> np.ndarray:
    """One part as a sheet: rows by facing, columns by pose."""
    sheet = pixelkit.blank(FRAME_W * len(POSES), FRAME_H * len(FACINGS))
    for row, facing in enumerate(FACINGS):
        for col, pose in enumerate(POSES):
            frame = frame_of(sprite, facing, pose)
            sheet[row * FRAME_H : (row + 1) * FRAME_H, col * FRAME_W : (col + 1) * FRAME_W] = frame
    return sheet


def recolour(image: np.ndarray, palette: Palette, look: dict[str, str]) -> np.ndarray:
    """A part drawn in the slots' default ramps, in the ramps a look chooses (`{"hair": "hair_blonde"}`)."""
    out = image.copy()
    for slot, ramp in look.items():
        default = palette.slots.get(slot)
        if default is None or default == ramp:
            continue
        for shade, colour in enumerate(palette.ramps[default][:3]):
            target = palette.shade(ramp, shade)
            match = np.all(image[..., :3] == colour, axis=2) & (image[..., 3] > 0)
            out[match, :3] = target
    return out


def compose(parts: list[np.ndarray]) -> np.ndarray:
    out = parts[0].copy()
    for part in parts[1:]:
        out = pixelkit.over(out, part)
    return out


def load_parts(folder: Path, palette: Palette) -> dict[str, Sprite]:
    sprites: dict[str, Sprite] = {}
    for path in pixelkit.sprite_files(folder):
        for name, sprite in pixelkit.load(path, palette).items():
            if name in sprites:
                raise pixelkit.SpriteError(f"{path}: {name} is drawn in two files")
            sprites[name] = sprite
    return sprites


def look_sheet(parts: dict[str, Sprite], palette: Palette, look: dict) -> np.ndarray:
    layers = [sheet_of(parts[look[layer]]) for layer in LAYERS if look.get(layer)]
    colours = {slot: ramp for slot, ramp in look.get("colours", {}).items()}
    return recolour(compose(layers), palette, colours)


SAMPLE_LOOKS = [
    {"body": "body/base", "outfit": "outfit/tunic", "hair": "hair/short"},
    {
        "body": "body/base",
        "outfit": "outfit/tunic",
        "hair": "hair/short",
        "colours": {"skin": "skin_tan", "hair": "hair_blonde", "main": "cloth_green", "accent": "cloth_yellow"},
    },
    {
        "body": "body/base",
        "outfit": "outfit/tunic",
        "hair": "hair/short",
        "colours": {"skin": "skin_brown", "hair": "hair_black", "main": "cloth_red", "second": "cloth_white"},
    },
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--scale", type=int, default=6)
    args = parser.parse_args()
    palette = Palette.load()
    parts = load_parts(pixelkit.HERE / "sprites", palette)
    sheets = [("look", look_sheet(parts, palette, look)) for look in SAMPLE_LOOKS]
    pixelkit.preview(sheets, args.scale, "#7cb854").save(args.preview)
    print(args.preview)


if __name__ == "__main__":
    main()
