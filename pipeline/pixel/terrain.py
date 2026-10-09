"""Ground tiles for Lanternroot's overworld: textures that repeat without seams, and the edges where two grounds meet.

Every map cell is one ground (grass, path, cobble, water, floor). Grass (or floor, indoors) is drawn under everything;
each other ground is drawn on top as a "dual grid": its tiles sit half a tile off the map's grid, so each one covers
the corners of four cells, and which of its 16 shapes it takes depends on which of those four cells are that ground
(top-left 1, top-right 2, bottom-left 4, bottom-right 8). Sixteen shapes per ground cover every case, with rounded
corners, and no hand-placed edge pieces.

LEARN: the shape of an edge is a smooth field: each corner of the tile carries 1 (that ground) or 0, the field is the
blend of the four, and the edge is where it crosses one half. Along a tile's border the field depends only on the two
corners on that border, which the neighbouring tile shares, so edges always line up.
"""

from __future__ import annotations

import numpy as np

import pixelkit
from pixelkit import Palette

TILE = 16
HALF = TILE // 2


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def fill(palette: Palette, ramp: str, shade: int) -> np.ndarray:
    tile = pixelkit.blank(TILE, TILE)
    tile[..., :3] = palette.shade(ramp, shade)
    tile[..., 3] = 255
    return tile


def put(tile: np.ndarray, x: int, y: int, colour: tuple[int, int, int]) -> None:
    tile[y % TILE, x % TILE, :3] = colour
    tile[y % TILE, x % TILE, 3] = 255


def grass(palette: Palette, seed: int, flowers: int = 0, tufts: int = 7) -> np.ndarray:
    """Grass: a light ground with blades in two greens; a few tiles carry flowers or clover."""
    rng = _rng(seed)
    tile = fill(palette, "grass", 1)
    hi, mid, dark = palette.shade("grass", 0), palette.shade("grass", 2), palette.shade("grass", 3)
    for _ in range(tufts):
        x, y = int(rng.integers(TILE)), int(rng.integers(TILE))
        # A blade: a dark root, a mid stem, a bright tip; tufts lean a pixel now and then.
        put(tile, x, y + 1, dark)
        put(tile, x, y, mid)
        put(tile, x + (1 if rng.random() < 0.4 else 0), y - 1, hi)
        if rng.random() < 0.5:
            put(tile, x + 2, y + 1, mid)
            put(tile, x + 2, y, hi)
    for _ in range(int(rng.integers(2, 5))):
        put(tile, int(rng.integers(TILE)), int(rng.integers(TILE)), mid)
    colours = ["cloth_white", "cloth_yellow", "cloth_pink", "cloth_blue"]
    for i in range(flowers):
        x, y = int(rng.integers(1, TILE - 1)), int(rng.integers(1, TILE - 1))
        petal = palette.shade(colours[(seed + i) % len(colours)], 0)
        centre = palette.shade("cloth_yellow", 1)
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            put(tile, x + dx, y + dy, petal)
        put(tile, x, y, centre)
        put(tile, x, y + 2, mid)
    return tile


def dirt(palette: Palette, seed: int) -> np.ndarray:
    rng = _rng(seed)
    tile = fill(palette, "dirt", 1)
    hi, mid, dark = palette.shade("dirt", 0), palette.shade("dirt", 2), palette.shade("dirt", 3)
    for _ in range(6):
        x, y = int(rng.integers(TILE)), int(rng.integers(TILE))
        put(tile, x, y, mid)
        if rng.random() < 0.5:
            put(tile, x + 1, y, mid)
    for _ in range(3):
        # A pebble: lit on top, shadowed below.
        x, y = int(rng.integers(TILE)), int(rng.integers(TILE))
        put(tile, x, y, hi)
        put(tile, x, y + 1, dark)
    return tile


def cobble(palette: Palette, seed: int) -> np.ndarray:
    """Cobbles: two rows of rounded stones with dark joints, every other row shifted half a stone."""
    rng = _rng(seed)
    tile = fill(palette, "cobble", 2)
    hi, light, dark = palette.shade("cobble", 0), palette.shade("cobble", 1), palette.shade("cobble", 3)
    for row in range(2):
        offset = 0 if row == 0 else 4
        for stone in range(2):
            x0 = (offset + stone * 8) % TILE
            y0 = row * 8
            for dy in range(1, 7):
                for dx in range(1, 7):
                    if (dx in (1, 6)) and (dy in (1, 6)):
                        continue
                    put(tile, x0 + dx, y0 + dy, light)
            put(tile, x0 + 2, y0 + 2, hi)
            put(tile, x0 + 3, y0 + 2, hi)
            put(tile, x0 + 2, y0 + 3, hi)
            for dx in range(2, 6):
                put(tile, x0 + dx, y0 + 6, dark if rng.random() < 0.6 else light)
    return tile


def water(palette: Palette, frame: int) -> np.ndarray:
    """Water: a mid blue with slow bands of light that drift one pixel a frame."""
    tile = fill(palette, "water", 2)
    light, hi = palette.shade("water", 1), palette.shade("water", 0)
    for y in range(TILE):
        for x in range(TILE):
            wave = (x + frame * 2 + (y // 4) * 5) % 16
            if wave in (0, 1) and y % 4 == 1:
                put(tile, x, y, light)
    for x, y in ((3, 2), (11, 10)):
        put(tile, x + frame, y, hi)
    return tile


def planks(palette: Palette, seed: int) -> np.ndarray:
    """A wooden floor: planks four pixels tall, joints staggered, a few knots."""
    rng = _rng(seed)
    tile = fill(palette, "wood", 1)
    hi, mid, dark = palette.shade("wood", 0), palette.shade("wood", 2), palette.shade("wood", 3)
    for row in range(4):
        y = row * 4
        for x in range(TILE):
            put(tile, x, y + 3, mid)
            put(tile, x, y, hi if (x + row) % 7 == 0 else palette.shade("wood", 1))
        joint = (row * 6 + 3) % TILE
        for dy in range(4):
            put(tile, joint, y + dy, dark)
        if rng.random() < 0.6:
            put(tile, int(rng.integers(TILE)), y + 1, mid)
    return tile


def wall(palette: Palette, seed: int) -> np.ndarray:
    """An inside wall seen from the front: plaster above a wooden skirting, a beam along the top."""
    tile = fill(palette, "plaster", 1)
    hi, shadow = palette.shade("plaster", 0), palette.shade("plaster", 2)
    for x in range(TILE):
        put(tile, x, 0, palette.shade("wood", 2))
        put(tile, x, 1, palette.shade("wood", 3))
        put(tile, x, 2, shadow)
        put(tile, x, 12, palette.shade("wood", 1))
        for y in (13, 14):
            put(tile, x, y, palette.shade("wood", 2))
        put(tile, x, 15, palette.shade("wood", 3))
    rng = _rng(seed)
    for _ in range(3):
        put(tile, int(rng.integers(TILE)), int(rng.integers(4, 11)), hi)
    return tile


def void(palette: Palette) -> np.ndarray:
    return fill(palette, "night", 0)


def field(mask: int, noise: np.ndarray, pad: int = 0) -> np.ndarray:
    """Which pixels of a dual-grid tile are the ground, for corner bits (tl 1, tr 2, bl 4, br 8). With `pad`, a ring
    of pixels from the neighbouring tiles too: the field there is the one those tiles compute, since along a border it
    depends only on the two corners the tiles share."""
    tl, tr, bl, br = (mask >> 0) & 1, (mask >> 1) & 1, (mask >> 2) & 1, (mask >> 3) & 1
    coords = (np.arange(-pad, TILE + pad) + 0.5 - HALF / 2) / HALF
    u = np.clip(coords, 0, 1)[None, :]
    v = np.clip(coords, 0, 1)[:, None]
    value = tl * (1 - u) * (1 - v) + tr * u * (1 - v) + bl * (1 - u) * v + br * u * v
    wobble = np.pad(noise, pad, mode="wrap") if pad else noise
    return (value + wobble) > 0.5


def edge_noise(seed: int, strength: float) -> np.ndarray:
    """A small wobble for edges, the same in every tile of a ground so neighbours agree."""
    rng = _rng(seed)
    coarse = rng.uniform(-strength, strength, (4, 4))
    return np.kron(coarse, np.ones((4, 4)))


def overlay(texture: np.ndarray, rim: tuple[int, int, int], mask: int, noise: np.ndarray, shade: tuple | None) -> np.ndarray:
    """One dual-grid tile of a ground: its texture where the field says, a rim inside its edge, and an optional
    shade on the outside of the edge (a shore's wet line, grass's shadow by a path)."""
    wide = field(mask, noise, pad=1)
    inside = wide[1:-1, 1:-1]
    # The texture repeats every 16 pixels from the map's corner, and this tile sits 8 pixels in.
    textured = np.roll(texture, (-HALF, -HALF), axis=(0, 1))
    out = pixelkit.blank(TILE, TILE)
    out[inside] = textured[inside]
    up, down = wide[:-2, 1:-1], wide[2:, 1:-1]
    left, right = wide[1:-1, :-2], wide[1:-1, 2:]
    edge = inside & ~(up & down & left & right)
    out[edge, :3] = rim
    out[edge, 3] = 255
    if shade is not None:
        # The ground's shadow falls on what is below and beside it, lit from the upper left.
        outside = ~inside & (up | left)
        out[outside, :3] = shade
        out[outside, 3] = 255
    return out


GROUNDS = {
    # ground: (texture maker, rim ramp and shade, outside shade or None, edge wobble seed)
    "path": (lambda p, s: dirt(p, s), ("dirt", 2), ("grass", 3), 11),
    "cobble": (lambda p, s: cobble(p, s), ("cobble", 3), ("grass", 3), 12),
    "water": (lambda p, s: water(p, s), ("water", 0), ("grass", 3), 13),
    "flowers": (lambda p, s: grass(p, 100 + s, flowers=3, tufts=4), ("grass", 1), None, 14),
}


def atlas(palette: Palette) -> tuple[np.ndarray, dict]:
    """Every ground tile in one picture, and where each one is: `base` rows (grass, floor) with variants, then each
    overlaid ground's 16 shapes (water three times, one per frame of its ripple)."""
    rows: list[list[np.ndarray]] = []
    layout: dict = {"tile": TILE, "base": {}, "overlay": {}}
    base_rows = {
        "grass": [grass(palette, s) for s in range(4)] + [grass(palette, 20 + s, flowers=1) for s in range(2)],
        "floor": [planks(palette, s) for s in range(2)],
        "wall": [wall(palette, s) for s in range(2)],
        "void": [void(palette)],
        "path": [dirt(palette, s) for s in range(2)],
        "cobble": [cobble(palette, s) for s in range(2)],
        "water": [water(palette, f) for f in range(3)],
    }
    for name, tiles in base_rows.items():
        layout["base"][name] = {"row": len(rows), "count": len(tiles)}
        rows.append(tiles)
    for name, (make, rim, shade, wobble) in GROUNDS.items():
        frames = 3 if name == "water" else 1
        layout["overlay"][name] = {"row": len(rows), "frames": frames}
        noise = edge_noise(wobble, 0.12)
        for f in range(frames):
            texture = make(palette, f if name == "water" else 0)
            rim_colour = palette.shade(*rim)
            shade_colour = palette.shade(*shade) if shade else None
            rows.append([overlay(texture, rim_colour, mask, noise, shade_colour) for mask in range(16)])
    width = max(len(r) for r in rows) * TILE
    sheet = pixelkit.blank(width, len(rows) * TILE)
    for r, tiles in enumerate(rows):
        for c, tile in enumerate(tiles):
            sheet[r * TILE : (r + 1) * TILE, c * TILE : (c + 1) * TILE] = tile
    return sheet, layout
