"""The pixel kit: the palette, the .sprite text format, and the checks every overworld picture passes.

A `.sprite` file draws pixel art as text, one character per pixel (pipeline/pixel/README.md):

    // a comment (`#` is a pixel: the outline)
    legend W wood.1            // this file's own characters, beside the palette's shared legend
    sprite barrel 16 16        // a picture, its size
    frame idle                 // one frame of it; `frame up from down` starts from another frame,
      ....######....           //   `at 2 3` pastes the rows from that corner, `shift 0 1` moves the result
      ...#WWWWWW#...

A `.` leaves a pixel as it was (empty in a new frame), `_` clears it; `replace` on a frame clears each row it draws
first (a step frame redrawing the legs of the stand frame). Rows may be shorter than the frame.
Stdlib plus numpy and Pillow; tests: `uv run --project pipeline python -m unittest discover pipeline/pixel`.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
PALETTE_FILE = HERE / "palette.json"
KEEP = "."
CLEAR = "_"


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


@dataclass
class Palette:
    ramps: dict[str, list[tuple[int, int, int]]]
    slots: dict[str, str]
    legend: dict[str, str]

    @classmethod
    def load(cls, path: Path = PALETTE_FILE) -> "Palette":
        data = json.loads(path.read_text())
        ramps = {name: [hex_rgb(c) for c in shades] for name, shades in data["ramps"].items()}
        return cls(ramps, dict(data["slots"]), dict(data["legend"]))

    def colours(self) -> set[tuple[int, int, int]]:
        return {c for shades in self.ramps.values() for c in shades}

    def resolve(self, ref: str) -> tuple[int, int, int]:
        """`ramp`, `ramp.2`, or a slot `@hair.1` (drawn in the slot's default ramp)."""
        name, _, shade = ref.partition(".")
        if name.startswith("@"):
            name = self.slots[name[1:]]
        ramp = self.ramps[name]
        index = int(shade) if shade else 0
        if index >= len(ramp):
            raise ValueError(f"{ref}: ramp {name} has {len(ramp)} shades")
        return ramp[index]

    def shade(self, ramp: str, index: int) -> tuple[int, int, int]:
        shades = self.ramps[ramp]
        return shades[min(index, len(shades) - 1)]


@dataclass
class Sprite:
    name: str
    width: int
    height: int
    frames: dict[str, np.ndarray] = field(default_factory=dict)  # label -> HxWx4 uint8


class SpriteError(ValueError):
    pass


def parse(text: str, palette: Palette, source: str = "<text>") -> dict[str, Sprite]:
    """Every sprite in a .sprite file, by name, each frame an RGBA array."""
    legend: dict[str, tuple[int, int, int]] = {ch: palette.resolve(ref) for ch, ref in palette.legend.items()}
    sprites: dict[str, Sprite] = {}
    sprite: Sprite | None = None
    frame: np.ndarray | None = None
    label = ""
    origin = [0, 0]
    row = 0
    replace = False
    placed = False

    def fail(line_no: int, message: str) -> SpriteError:
        return SpriteError(f"{source}:{line_no}: {message}")

    for line_no, raw in enumerate(text.splitlines(), 1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("//"):
            continue
        word, _, rest = stripped.partition(" ")
        rest = rest.split("//", 1)[0].strip()
        if word == "legend":
            parts = rest.split()
            if len(parts) != 2 or len(parts[0]) != 1:
                raise fail(line_no, "legend wants one character and a colour")
            try:
                legend[parts[0]] = palette.resolve(parts[1])
            except (KeyError, ValueError) as error:
                raise fail(line_no, f"unknown colour {parts[1]}: {error}") from None
        elif word == "sprite":
            parts = rest.split()
            if len(parts) != 3:
                raise fail(line_no, "sprite wants a name, a width and a height")
            sprite = Sprite(parts[0], int(parts[1]), int(parts[2]))
            if sprite.name in sprites:
                raise fail(line_no, f"sprite {sprite.name} drawn twice")
            sprites[sprite.name] = sprite
            frame = None
        elif word == "frame":
            if sprite is None:
                raise fail(line_no, "a frame before any sprite")
            tokens = rest.split()
            label = tokens[0]
            frame = np.zeros((sprite.height, sprite.width, 4), np.uint8)
            origin = [0, 0]
            row = 0
            replace = False
            placed = False
            i = 1
            while i < len(tokens):
                if tokens[i] == "from":
                    base = sprite.frames.get(tokens[i + 1])
                    if base is None:
                        raise fail(line_no, f"no frame {tokens[i + 1]} to start from")
                    frame = base.copy()
                    i += 2
                elif tokens[i] == "at":
                    origin = [int(tokens[i + 1]), int(tokens[i + 2])]
                    placed = True
                    i += 3
                elif tokens[i] == "replace":
                    replace = True
                    i += 1
                else:
                    raise fail(line_no, f"unknown frame option {tokens[i]}")
            if label in sprite.frames:
                raise fail(line_no, f"frame {label} drawn twice")
            sprite.frames[label] = frame
        elif word == "shift":
            if frame is None or sprite is None:
                raise fail(line_no, "shift outside a frame")
            dx, dy = (int(v) for v in rest.split())
            sprite.frames[label] = shifted(frame, dx, dy)
            frame = sprite.frames[label]
        else:
            if frame is None or sprite is None:
                raise fail(line_no, f"pixels outside a frame: {stripped!r}")
            y = origin[1] + row
            row += 1
            if y >= sprite.height:
                raise fail(line_no, f"row {y} is below the {sprite.height}-pixel frame")
            if not placed and len(stripped) != sprite.width:
                # A whole frame's rows must be its full width, or a miscounted row would shift silently.
                raise fail(line_no, f"row is {len(stripped)} wide, the frame is {sprite.width}")
            if replace:
                frame[y] = 0
            for dx, ch in enumerate(stripped):
                x = origin[0] + dx
                if ch == KEEP:
                    continue
                if x >= sprite.width:
                    raise fail(line_no, f"column {x} is past the {sprite.width}-pixel frame")
                if ch == CLEAR:
                    frame[y, x] = 0
                    continue
                if ch not in legend:
                    raise fail(line_no, f"no colour for {ch!r}")
                frame[y, x, :3] = legend[ch]
                frame[y, x, 3] = 255
    return sprites


def load(path: Path, palette: Palette) -> dict[str, Sprite]:
    return parse(path.read_text(), palette, str(path))


def shifted(image: np.ndarray, dx: int, dy: int) -> np.ndarray:
    out = np.zeros_like(image)
    h, w = image.shape[:2]
    ys = slice(max(dy, 0), h + min(dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    src_ys = slice(max(-dy, 0), h + min(-dy, 0))
    src_xs = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = image[src_ys, src_xs]
    return out


def over(below: np.ndarray, above: np.ndarray) -> np.ndarray:
    """`above` stacked on `below`; alpha is all or nothing, so this is a choice per pixel."""
    out = below.copy()
    solid = above[..., 3] > 0
    out[solid] = above[solid]
    return out


def blank(width: int, height: int) -> np.ndarray:
    return np.zeros((height, width, 4), np.uint8)


def save(image: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image, "RGBA").save(path, optimize=True)


def problems(image: np.ndarray, palette: Palette, name: str) -> list[str]:
    """Why a picture is not crisp: soft alpha, or colours from outside the palette."""
    found: list[str] = []
    alpha = image[..., 3]
    soft = np.count_nonzero((alpha > 0) & (alpha < 255))
    if soft:
        found.append(f"{name}: {soft} half-transparent pixels")
    colours = palette.colours()
    opaque = image[alpha == 255][:, :3]
    if len(opaque):
        unique = {tuple(int(v) for v in c) for c in np.unique(opaque, axis=0)}
        strays = sorted(unique - colours)
        if strays:
            sample = ", ".join("#%02x%02x%02x" % c for c in strays[:4])
            found.append(f"{name}: {len(strays)} colours outside the palette ({sample})")
    return found


def lint(folder: Path, palette: Palette, skip: tuple[str, ...] = ()) -> list[str]:
    found: list[str] = []
    for path in sorted(folder.rglob("*.png")):
        relative = path.relative_to(folder).as_posix()
        if relative.startswith(skip):
            continue
        image = np.asarray(Image.open(path).convert("RGBA"))
        found += problems(image, palette, relative)
    return found


def nearest(rgb: np.ndarray, colours: list[tuple[int, int, int]]) -> np.ndarray:
    """Each pixel snapped to the closest palette colour (a weighted distance that tracks how eyes see)."""
    table = np.array(colours, np.float32)
    flat = rgb.reshape(-1, 3).astype(np.float32)
    weights = np.array([0.3, 0.59, 0.11], np.float32) * 3
    distance = (((flat[:, None, :] - table[None, :, :]) ** 2) * weights).sum(axis=2)
    return table[np.argmin(distance, axis=1)].astype(np.uint8).reshape(rgb.shape)


def preview(images: list[tuple[str, np.ndarray]], scale: int = 4, background: str = "#3a3446") -> Image.Image:
    """A contact sheet: each picture scaled up with nearest-neighbour, on a dark ground, in a row that wraps."""
    pad = 6
    width = 1600
    x = y = pad
    row_height = 0
    placed: list[tuple[int, int, Image.Image]] = []
    for _, image in images:
        big = Image.fromarray(image, "RGBA").resize((image.shape[1] * scale, image.shape[0] * scale), Image.NEAREST)
        if x + big.width + pad > width:
            x = pad
            y += row_height + pad
            row_height = 0
        placed.append((x, y, big))
        x += big.width + pad
        row_height = max(row_height, big.height)
    sheet = Image.new("RGBA", (width, y + row_height + pad), background)
    for px, py, big in placed:
        sheet.alpha_composite(big, (px, py))
    return sheet


def sprite_files(folder: Path) -> list[Path]:
    return sorted(folder.glob("*.sprite"))


NAME = re.compile(r"^[a-z0-9_/\-]+$")
