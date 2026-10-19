"""Ground tiles for Lanternroot's overworld: textures that repeat without seams, and the edges where two grounds meet.
Drawn at the world's tile (game/content/packs/core/overworld/scale.jsonc, 40 px since ADR-0064).

Every map cell is one ground (grass, path, cobble, water, floor). Grass (or floor, indoors) is drawn under everything;
each other ground is drawn on top as a "dual grid": its tiles sit half a tile off the map's grid, so each one covers
the corners of four cells, and which of its 16 shapes it takes depends on which of those four cells are that ground
(top-left 1, top-right 2, bottom-left 4, bottom-right 8). Sixteen shapes per ground cover every case, with rounded
corners, and no hand-placed edge pieces.

LEARN: the shape of an edge is a smooth field: each corner of the tile carries 1 (that ground) or 0, the field is the
blend of the four, and the edge is where it crosses one half. Along a tile's border the field depends only on the two
corners on that border, which the neighbouring tile shares, so edges always line up.

LEARN: every texture here is periodic: a stone, a tuft or a patch that runs over one edge comes back on the opposite
one (`put` wraps, `periodic_noise` interpolates on a wrapped grid), so a field of tiles shows no seams.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

import pixelkit
from pixelkit import Palette

SCALE = Path(__file__).resolve().parents[2] / "game" / "content" / "packs" / "core" / "overworld" / "scale.jsonc"


def _tile_size() -> int:
    text = re.sub(r"//[^\n]*", "", SCALE.read_text())
    return int(json.loads(text)["tile"])


TILE = _tile_size()
HALF = TILE // 2
# Pixel measures scale with the tile, as a share of 40 px: a 2 px rim at 40, 1 at 16.
UNIT = max(1, round(TILE / 20))
ROOT = Path(__file__).resolve().parents[2]
MEADOW_VARIANTS_ATLAS = ROOT / "Concept" / "v0.3" / "Update" / "art-source" / "lanternroot-meadow-variants-chatgpt-imagegen-2026-10-19.png"
MEADOW_GRASS_ONLY_VARIANTS = {0, 3, 4}
MEADOW_FLOWERLESS_ATLAS = MEADOW_VARIANTS_ATLAS.with_name("lanternroot-meadow-flowerless-chatgpt-imagegen-2026-10-19.png")
PATH_CONTINUOUS_SOURCE = MEADOW_VARIANTS_ATLAS.with_name("lanternroot-path-continuous-chatgpt-imagegen-2026-10-19.png")

# Each 4x4 atlas row is a ground and its four columns are deliberate pattern layouts. A second seeded surface detail
# pass turns those four authored patterns into eight repeatable map variants without changing a ground's identity.
VARIATION_ATLASES = {
    "nature": ROOT / "Concept" / "v0.3" / "Update" / "art-source" / "lanternroot-ground-variants-nature-chatgpt-imagegen-2026-10-19.png",
    "earth": ROOT / "Concept" / "v0.3" / "Update" / "art-source" / "lanternroot-ground-variants-earth-chatgpt-imagegen-2026-10-19.png",
    "stone_water": ROOT / "Concept" / "v0.3" / "Update" / "art-source" / "lanternroot-ground-variants-stone-water-chatgpt-imagegen-2026-10-19.png",
    "pathways": ROOT / "Concept" / "v0.3" / "Update" / "art-source" / "lanternroot-pathways-imagegen-2026-10-19.png",
    "fantasy_ground": ROOT / "Concept" / "v0.3" / "Update" / "art-source" / "lanternroot-fantasy-ground-imagegen-2026-10-19.png",
}
VARIATION_CELLS = {
    "grass": ("nature", 0),
    "dry_grass": ("nature", 1),
    "forest_floor": ("nature", 2),
    "moss": ("nature", 3),
    "flowers": ("earth", 0),
    "soil": ("earth", 1),
    "tilled_soil": ("earth", 2),
    "path": ("earth", 3),
    "sand": ("stone_water", 0),
    "gravel": ("stone_water", 1),
    "cobble": ("stone_water", 2),
    "water": ("stone_water", 3),
}
VARIATION_ROW_GROUPS = {
    "brick_path": ("pathways", (0, 3)),
    "stone_path": ("pathways", (1,)),
    "wood_path": ("pathways", (2,)),
    "root_floor": ("fantasy_ground", (0,)),
    "fern_moss": ("fantasy_ground", (1,)),
    "glow_moss": ("fantasy_ground", (2, 3)),
}
LAND_RAMPS = {
    "grass": ("grass", "leaf"),
    "meadow": ("grass", "leaf", "pine", "cloth_white", "cloth_yellow", "cloth_pink", "cloth_blue"),
    "dry_grass": ("cloth_olive", "grass", "leaf", "dirt"),
    "forest_floor": ("leaf", "pine", "wood", "dirt"),
    "moss": ("pine", "leaf", "grass", "stone", "wood"),
    "flowers": ("grass", "leaf", "pine", "cloth_white", "cloth_yellow", "cloth_pink", "cloth_blue"),
    "path": ("dirt", "stone", "cobble", "wood", "cloth_brown"),
    "soil": ("cloth_brown", "wood", "stone", "leaf"),
    "tilled_soil": ("cloth_brown", "wood", "dirt", "leaf"),
    "sand": ("cloth_cream", "dirt", "stone", "water"),
    "gravel": ("stone", "cobble", "dirt", "cloth_brown"),
    "cobble": ("cobble", "stone", "dirt", "cloth_brown"),
    "water": ("water", "stone", "leaf", "grass", "pine"),
    "brick_path": ("cloth_orange", "cloth_maroon", "dirt", "cobble", "stone", "leaf"),
    "stone_path": ("stone", "cobble", "cloth_grey", "leaf", "pine"),
    "wood_path": ("wood", "cloth_brown", "cloth_olive", "dirt"),
    "root_floor": ("wood", "dirt", "cloth_brown", "leaf", "pine"),
    "fern_moss": ("leaf", "pine", "grass", "cloth_olive", "stone"),
    "glow_moss": ("pine", "leaf", "glow", "firefly", "cloth_yellow", "stone"),
}


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


@lru_cache(maxsize=3)
def _variation_source(atlas_name: str) -> Image.Image:
    path = VARIATION_ATLASES[atlas_name]
    if not path.is_file():
        raise FileNotFoundError(f"missing authored variation atlas: {path}")
    return Image.open(path).convert("RGB")


@lru_cache(maxsize=2)
def _meadow_variants_source(flowerless: bool = False) -> Image.Image:
    path = MEADOW_FLOWERLESS_ATLAS if flowerless else MEADOW_VARIANTS_ATLAS
    return Image.open(path).convert("RGB")


@lru_cache(maxsize=8)
def _meadow_variant_pixels(variant: int) -> np.ndarray:
    """Read matching flowered or flowerless turf from the authored 4x2 sheets, removing painted separators."""
    source = _meadow_variants_source(variant % 8 in MEADOW_GRASS_ONLY_VARIANTS)
    row, column = divmod(variant % 8, 4)
    left, right = round(column * source.width / 4), round((column + 1) * source.width / 4)
    top, bottom = round(row * source.height / 2), round((row + 1) * source.height / 2)
    cell = source.crop((left, top, right, bottom))
    inset = round(min(cell.size) * 0.025)
    cell = cell.crop((inset, inset, cell.width - inset, cell.height - inset))
    crop = cell.resize((TILE, TILE), Image.Resampling.BOX)
    return np.asarray(crop, dtype=np.uint8).copy()


@lru_cache(maxsize=256)
def _imagegen_land_pixels(kind: str, seed: int) -> np.ndarray:
    """A deterministic tile-size swatch from the authored ground atlases."""
    if kind == "meadow":
        return _meadow_variant_pixels(seed % 8).copy()
    if kind == "path":
        # Sample one uninterrupted material, rather than eight individually framed pictures of dirt.
        source = _path_source()
        row, column = divmod(seed % 8, 4)
        return np.asarray(source.crop((column * TILE, row * TILE, (column + 1) * TILE, (row + 1) * TILE))).copy()
    if kind in VARIATION_ROW_GROUPS:
        atlas_name, rows = VARIATION_ROW_GROUPS[kind]
        row = rows[(seed // 4) % len(rows)]
    else:
        atlas_name, row = VARIATION_CELLS[kind]
    source = _variation_source(atlas_name)
    column = seed % 4
    left, right = round(column * source.width / 4), round((column + 1) * source.width / 4)
    top, bottom = round(row * source.height / 4), round((row + 1) * source.height / 4)
    cell = source.crop((left, top, right, bottom))
    if kind == "wood_path" and column % 2 == 1:
        # The source atlas alternates broad plank directions; align them so a mixed-variant walk stays coherent.
        cell = cell.transpose(Image.Transpose.ROTATE_90)
    # A generated sheet can be slightly wider than square. Center-crop each cell to preserve top-down proportions,
    # then remove the generator's visible separators before reducing it to a ground tile.
    square = min(cell.size)
    square_left, square_top = (cell.width - square) // 2, (cell.height - square) // 2
    cell = cell.crop((square_left, square_top, square_left + square, square_top + square))
    inset = round(square * 0.025)
    cell = cell.crop((inset, inset, square - inset, square - inset))
    crop = cell.resize((TILE, TILE), Image.Resampling.BOX)
    return np.asarray(crop, dtype=np.uint8).copy()


@lru_cache(maxsize=1)
def _path_source() -> Image.Image:
    return Image.open(PATH_CONTINUOUS_SOURCE).convert("RGB").resize((TILE * 4, TILE * 4), Image.Resampling.BOX)


def _match_wrapped_edges(rgb: np.ndarray, colours: list[tuple[int, int, int]]) -> np.ndarray:
    """Make opposite tile edges agree after palette locking, so every texture remains safe to repeat."""
    for x in range(TILE):
        pair = ((rgb[0, x].astype(np.uint16) + rgb[-1, x].astype(np.uint16)) // 2).reshape(1, 1, 3)
        edge = pixelkit.nearest(pair, colours)[0, 0]
        rgb[0, x] = edge
        rgb[-1, x] = edge
    for y in range(TILE):
        pair = ((rgb[y, 0].astype(np.uint16) + rgb[y, -1].astype(np.uint16)) // 2).reshape(1, 1, 3)
        edge = pixelkit.nearest(pair, colours)[0, 0]
        rgb[y, 0] = edge
        rgb[y, -1] = edge
    corner = rgb[[0, 0, -1, -1], [0, -1, 0, -1]].astype(np.uint16).mean(axis=0).astype(np.uint8).reshape(1, 1, 3)
    corner = pixelkit.nearest(corner, colours)[0, 0]
    rgb[0, 0] = rgb[0, -1] = rgb[-1, 0] = rgb[-1, -1] = corner
    return rgb


def authored_land(palette: Palette, kind: str, seed: int) -> np.ndarray:
    """Turn one rich authored swatch into a crisp, seamless, shared-palette ground tile."""
    source_seed = seed // 3 if kind == "water" else seed
    rgb = _imagegen_land_pixels(kind, source_seed).copy()
    if kind == "grass":
        # Keep large grass fields calm without making them flat: the seeded dithered patches and sparse tufts carry
        # most of the texture, with a hint of the authored pattern so tile-to-tile variation does not form a grid.
        authored = grass(palette, seed, tufts=6)[..., :3].astype(np.float32)
        rgb = np.round(rgb.astype(np.float32) * 0.12 + authored * 0.88).astype(np.uint8)
    colours = sorted(
        {
            palette.shade(ramp, shade)
            for ramp in LAND_RAMPS[kind]
            for shade in range(len(palette.ramps[ramp]))
        }
        | {palette.resolve("ink"), palette.resolve("ink_soft")}
    )
    rgb = pixelkit.nearest(rgb, colours)
    rgb = _match_wrapped_edges(rgb, colours)
    tile = pixelkit.blank(TILE, TILE)
    tile[..., :3] = rgb
    tile[..., 3] = 255
    if kind == "water":
        # Three frame seeds create a restrained travelling glint over the richer authored pond texture.
        rng = _rng(9017 + seed * 31)
        for ripple in range(3):
            x, y = map(int, rng.integers(5, TILE - 6, 2))
            length = int(rng.integers(3, 8))
            colour = palette.shade("water", 0 if ripple == 0 else 1)
            for dx in range(length):
                put(tile, x + dx, y + (dx // 4), colour)
    return tile


# Procedural contribution to the authored swatch: calm meadow flowers stay prominent, while soil, gravel and litter
# get enough seeded marks to make neighboring map cells feel like different patches of the same ground.
DETAIL_MIX = {
    "meadow": 0.12,
    "dry_grass": 0.30,
    "forest_floor": 0.52,
    "moss": 0.28,
    "flowers": 0.32,
    "soil": 0.30,
    "tilled_soil": 0.28,
    "path": 0.12,
    "gravel": 0.30,
    "sand": 0.26,
    "cobble": 0.17,
    "water": 0.20,
    "brick_path": 0.12,
    "stone_path": 0.12,
    "wood_path": 0.12,
    "root_floor": 0.28,
    "fern_moss": 0.18,
    "glow_moss": 0.16,
}

PATHS = {"path", "brick_path", "stone_path", "wood_path"}


def varied_land(
    palette: Palette, kind: str, seed: int, make: Callable[[Palette, int], np.ndarray]
) -> np.ndarray:
    """Blend each authored surface with its seeded pixel motifs, then quantize back to that surface's palette ramps."""
    authored = authored_land(palette, kind, seed)
    detail = make(palette, seed)
    weight = DETAIL_MIX[kind]
    rgb = np.round(
        authored[..., :3].astype(np.float32) * (1 - weight) + detail[..., :3].astype(np.float32) * weight
    ).astype(np.uint8)
    colours = sorted(
        {
            palette.shade(ramp, shade)
            for ramp in LAND_RAMPS[kind]
            for shade in range(len(palette.ramps[ramp]))
        }
        | {palette.resolve("ink"), palette.resolve("ink_soft")}
    )
    rgb = pixelkit.nearest(rgb, colours)
    rgb = _match_wrapped_edges(rgb, colours)
    if kind in ("meadow", *PATHS, "root_floor", "fern_moss", "glow_moss"):
        reference = authored_land(palette, kind, 0)[..., :3].astype(np.float32)
        reference = np.round(reference * (1 - weight) + make(palette, 0)[..., :3] * weight).astype(np.uint8)
        reference = pixelkit.nearest(reference, colours)
        collar = 5 if kind in ("meadow", "root_floor", "fern_moss", "glow_moss") else 8
        rgb = joined_texture(rgb, reference, colours, collar)
    tile = pixelkit.blank(TILE, TILE)
    tile[..., :3] = rgb
    tile[..., 3] = 255
    if kind == "cobble":
        broken_stone_marks(tile, palette, seed)
    return tile


def joined_texture(
    rgb: np.ndarray, reference: np.ndarray, colours: list[tuple[int, int, int]], collar: int
) -> np.ndarray:
    """Fade variants into one textured collar in the dual grid's actual phase, rather than a hard border stripe."""
    # LEARN: dual-grid tiles are offset by half a cell, so their seams run through the source texture's middle.
    phased = np.roll(rgb, (-HALF, -HALF), axis=(0, 1))
    common = _match_wrapped_edges(np.roll(reference, (-HALF, -HALF), axis=(0, 1)).copy(), colours)
    distance = np.minimum(np.arange(TILE), np.arange(TILE)[::-1])
    weight = np.minimum(distance[:, None], distance[None, :]) / collar
    weight = np.clip(weight, 0, 1)
    weight = (weight * weight * (3 - 2 * weight))[..., None]
    blended = np.round(phased * weight + common * (1 - weight)).astype(np.uint8)
    blended = pixelkit.nearest(blended, colours)
    return np.roll(blended, (HALF, HALF), axis=(0, 1))


def fill(palette: Palette, ramp: str, shade: int) -> np.ndarray:
    tile = pixelkit.blank(TILE, TILE)
    tile[..., :3] = palette.shade(ramp, shade)
    tile[..., 3] = 255
    return tile


def put(tile: np.ndarray, x: int, y: int, colour: tuple[int, int, int]) -> None:
    tile[y % TILE, x % TILE, :3] = colour
    tile[y % TILE, x % TILE, 3] = 255


def broken_stone_marks(tile: np.ndarray, palette: Palette, seed: int) -> None:
    """Add one or two small, seeded chips to stone interiors while leaving their shared tile borders intact."""
    rng = _rng(18013 + seed * 139)
    if rng.random() > 0.78:
        return
    cracks = 1 + int(rng.random() < 0.18)
    joint_colours = {
        palette.shade("cobble", 3),
        palette.shade("stone", 3),
        palette.resolve("ink_soft"),
    }
    for _ in range(cracks):
        x = y = 0
        for _attempt in range(24):
            x, y = map(int, rng.integers(4, TILE - 5, 2))
            if tuple(tile[y, x, :3]) not in joint_colours:
                break
        direction = -1 if rng.random() < 0.5 else 1
        crack = ((0, 0), (direction, 1), (direction, 2), (direction * 2, 3))
        for dx, dy in crack:
            put(tile, x + dx, y + dy, palette.resolve("ink_soft"))
        # A pale fracture lip and a warm missing chip make the split read as a damaged paving stone.
        put(tile, x - direction, y, palette.shade("stone", 0))
        if rng.random() < 0.7:
            put(tile, x + direction * 2, y + 2, palette.shade("dirt", 1))


def periodic_noise(rng: np.random.Generator, cells: int) -> np.ndarray:
    """Smooth noise in -1..1 over one tile that wraps at its edges: random values on a cells x cells grid, blended
    bilinearly with the grid wrapped around, so the tile's last column leads smoothly into its first."""
    grid = rng.uniform(-1, 1, (cells, cells))
    position = (np.arange(TILE) + 0.5) / TILE * cells - 0.5
    low = np.floor(position).astype(int)
    t = position - low
    t = t * t * (3 - 2 * t)
    a, b = low % cells, (low + 1) % cells
    rows = grid[a][:, a] * (1 - t)[None, :] + grid[a][:, b] * t[None, :]
    rows_next = grid[b][:, a] * (1 - t)[None, :] + grid[b][:, b] * t[None, :]
    return rows * (1 - t)[:, None] + rows_next * t[:, None]


def patches(
    tile: np.ndarray,
    palette: Palette,
    ramp: str,
    rng: np.random.Generator,
    light: float,
    dark: float,
    light_shade: int = 0,
    dark_shade: int = 2,
) -> None:
    """Soft patches of the ramp's lighter and darker shade, broken up by a checker where they fade, so a field of the
    ground has the slow variation of real turf or earth without reading as a pattern."""
    noise = periodic_noise(rng, 3) * 0.7 + periodic_noise(rng, 5) * 0.3
    checker = (np.add.outer(np.arange(TILE), np.arange(TILE)) % 2) == 0
    sparse = checker & (np.arange(TILE)[:, None] % 2 == 0)
    # LEARN: a texture that repeats every tile shows any large shape as a grid, so the slow variation is only ever a
    # dither: it lightens an area without drawing an outline the eye can follow from tile to tile.
    lighter = (noise > light) & checker
    # The darker shade only ever as a sparse dither: dark blots read as holes in the ground.
    darker = (noise < -dark) & sparse
    tile[lighter, :3] = palette.shade(ramp, light_shade)
    tile[darker, :3] = palette.shade(ramp, dark_shade)


def grass(palette: Palette, seed: int, flowers: int = 0, tufts: int = 7) -> np.ndarray:
    """Grass: a calm base with soft lighter and darker patches, tufts of blades (a dark root, a mid stem, a bright tip,
    some leaning), a few loose specks, and flowers clustered in their own tiles."""
    rng = _rng(seed)
    tile = fill(palette, "grass", 2)
    # Keep most pixels on the deeper grass shade; dither mid-green light and dark patches instead of lime highlights.
    patches(tile, palette, "grass", rng, 0.48, 0.48, light_shade=1, dark_shade=3)
    hi, mid, dark = palette.shade("grass", 1), palette.shade("grass", 2), palette.shade("grass", 3)
    for _ in range(round(tufts * (TILE / 40) ** 2)):
        x, y = int(rng.integers(TILE)), int(rng.integers(TILE))
        for blade in range(int(rng.integers(2, 4))):
            bx = x + blade * 2 - 1
            height = int(rng.integers(2, 2 + UNIT * 2))
            lean = 1 if rng.random() < 0.35 else 0
            put(tile, bx, y + 1, dark if blade == 0 else mid)
            for step in range(height):
                put(tile, bx + (lean if step >= height - 1 else 0), y - step, mid if step < height - 1 else hi)
    for _ in range(round(6 * (TILE / 40) ** 2)):
        put(tile, int(rng.integers(TILE)), int(rng.integers(TILE)), mid)
    colours = ["cloth_white", "cloth_yellow", "cloth_pink", "cloth_blue"]
    for i in range(flowers):
        x, y = int(rng.integers(2, TILE - 2)), int(rng.integers(2, TILE - 2))
        petal = palette.shade(colours[(seed + i) % len(colours)], 0)
        shadow = palette.shade(colours[(seed + i) % len(colours)], 1)
        centre = palette.shade("cloth_yellow", 1)
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1), (-1, -1), (1, -1)):
            put(tile, x + dx, y + dy, petal)
        for dx, dy in ((-1, 1), (1, 1)):
            put(tile, x + dx, y + dy, shadow)
        put(tile, x, y, centre)
        put(tile, x, y + 2, mid)
        put(tile, x, y + 3, dark)
    return tile


def dirt(palette: Palette, seed: int) -> np.ndarray:
    """A beaten earth path: soft patches, specks, and pebbles lit on their upper left with a shadow below."""
    rng = _rng(seed)
    tile = fill(palette, "dirt", 1)
    patches(tile, palette, "dirt", rng, 0.45, 0.5)
    hi, mid, dark = palette.shade("dirt", 0), palette.shade("dirt", 2), palette.shade("dirt", 3)
    for _ in range(round(14 * (TILE / 40) ** 2)):
        x, y = int(rng.integers(TILE)), int(rng.integers(TILE))
        put(tile, x, y, mid)
        if rng.random() < 0.4:
            put(tile, x + 1, y, mid)
    for _ in range(round(5 * (TILE / 40) ** 2)):
        x, y = int(rng.integers(TILE)), int(rng.integers(TILE))
        size = int(rng.integers(1, UNIT + 2))
        for dy in range(size):
            for dx in range(size):
                put(tile, x + dx, y + dy, hi if dx + dy < size else palette.shade("stone", 1))
        for dx in range(size):
            put(tile, x + dx + 1, y + size, dark)
        put(tile, x + size, y + size - 1, mid)
    return tile


def cobble(palette: Palette, seed: int) -> np.ndarray:
    """Cobbles: rounded stones of uneven size (a Voronoi of jittered points on a wrapped grid), dark joints between
    them, each stone lit along its upper left and shaded along its lower right; about a third are a warmer grey, so a
    street does not read as a pattern."""
    rng = _rng(31 + seed * 149)
    columns, rows = 4, 4
    points = []
    for r in range(rows):
        for c in range(columns):
            offset = 0.5 if r % 2 else 0.0
            px = (c + offset + rng.uniform(0.25, 0.75)) / columns * TILE
            py = (r + rng.uniform(0.25, 0.75)) / rows * TILE
            points.append((px, py))
    points_arr = np.array(points)
    yy, xx = np.mgrid[0:TILE, 0:TILE] + 0.5
    dx = np.abs(xx[..., None] - points_arr[None, None, :, 0])
    dy = np.abs(yy[..., None] - points_arr[None, None, :, 1])
    dx, dy = np.minimum(dx, TILE - dx), np.minimum(dy, TILE - dy)
    distance = np.sqrt(dx * dx * 0.8 + dy * dy * 1.25)
    order = np.argsort(distance, axis=-1)
    nearest = order[..., 0]
    d1 = np.take_along_axis(distance, order[..., :1], -1)[..., 0]
    d2 = np.take_along_axis(distance, order[..., 1:2], -1)[..., 0]
    joint = (d2 - d1) < 1.1 * UNIT
    tile = fill(palette, "cobble", 3)
    # The joints continue through every variant. Move wear and stone colours, rather than cutting a new stone
    # pattern against the shared border (that creates a visible square seam).
    warm = _rng(seed + 47).random(len(points)) < 0.33
    for i in range(len(points)):
        ramp = "stone" if warm[i] else "cobble"
        stone = (nearest == i) & ~joint
        tile[stone, :3] = palette.shade(ramp, 1)
        # Light from the upper left: the stone's pixels just inside its upper-left border, and shade on the lower right.
        upper_left = stone & ~np.roll(stone, UNIT, axis=0) | stone & ~np.roll(stone, UNIT, axis=1)
        lower_right = stone & ~np.roll(stone, -UNIT, axis=0) | stone & ~np.roll(stone, -UNIT, axis=1)
        tile[lower_right, :3] = palette.shade(ramp, 2)
        tile[upper_left & ~lower_right, :3] = palette.shade(ramp, 0)
    return tile


def water(palette: Palette, frame: int, seed: int = 7) -> np.ndarray:
    """Water: a mid blue, a faint lighter swell, and short bands of light that drift a little each frame; a sparkle."""
    rng = _rng(7 + seed * 101)
    tile = fill(palette, "water", 2)
    swell = periodic_noise(rng, 3)
    checker = (np.add.outer(np.arange(TILE), np.arange(TILE)) % 2) == 0
    light, hi = palette.shade("water", 1), palette.shade("water", 0)
    sparse = checker & (np.arange(TILE)[:, None] % 2 == 0)
    tile[(swell > 0.55) & sparse, :3] = light
    bands = rng.integers(0, TILE, (round(9 * (TILE / 40) ** 2), 2))
    for i, (x, y) in enumerate(bands):
        length = 2 + (i % 3) * UNIT
        drift = frame * UNIT * (1 if i % 2 else -1)
        for dx in range(length):
            put(tile, int(x) + dx + drift, int(y), light)
    for x, y in ((TILE // 5, TILE // 6), (TILE * 2 // 3, TILE * 3 // 5)):
        put(tile, x + frame * UNIT, y, hi)
        put(tile, x + frame * UNIT + 1, y, hi)
    detail = _rng(seed + 97)
    for _ in range(3):
        x, y = map(int, detail.integers(7, TILE - 9, 2))
        for dx in range(2 + seed % 3):
            put(tile, x + dx + frame, y, light)
    return tile


def turf(palette: Palette, seed: int, kind: str = "grass") -> np.ndarray:
    """Quiet turf with small, scattered plants rather than the same conspicuous tuft in every cell."""
    ramp = {"grass": "grass", "meadow": "leaf", "dry_grass": "cloth_olive", "moss": "pine"}[kind]
    rng = _rng(301 + seed * 71)
    tile = fill(palette, ramp, 1)
    high, low = palette.shade(ramp, 0), palette.shade(ramp, 2)
    # A handful of two-pixel marks keeps the field calm at world scale. Avoid the tile border, which is shared by
    # every variant, and do not wrap plants: cutting a tall tuft in half makes the tile grid much easier to see.
    count = 12 if kind == "moss" else 3 + seed % 3
    for _ in range(count):
        x, y = map(int, rng.integers(0 if kind == "moss" else 5, TILE if kind == "moss" else TILE - 5, 2))
        if kind == "moss":
            for dx, dy in ((0, 0), (1, 0), (0, 1), (2, 1)):
                put(tile, x + dx, y + dy, high if dy == 0 else low)
        else:
            for dx, dy in ((0, 0), (0, -1), (1, -2), (2, 0)):
                put(tile, x + dx, y + dy, high if dy < 0 else low)
    if kind in ("grass", "meadow") and seed % 4 == 2:
        # Tiny clover, not a large prop: fewer than twenty plant pixels in a 1,600-pixel tile.
        x, y = map(int, rng.integers(7, TILE - 7, 2))
        for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)):
            put(tile, x + dx, y + dy, palette.shade("leaf", 0))
        put(tile, x, y, palette.shade("leaf", 2))
    if kind in ("grass", "meadow") and seed % 8 == 5:
        x, y = map(int, rng.integers(7, TILE - 7, 2))
        put(tile, x, y, palette.shade("cloth_cream", 0))
        put(tile, x + 1, y, palette.shade("cloth_yellow", 0))
        put(tile, x, y + 1, low)
    return tile


def earth(palette: Palette, seed: int, tilled: bool = False) -> np.ndarray:
    """Dark garden soil and planted-bed furrows, distinct from the warm, pale beaten path."""
    rng = _rng(501 + seed * 73)
    tile = fill(palette, "cloth_brown", 1 if tilled else 2)
    if tilled:
        for y in range(3, TILE, 10):
            for x in range(TILE):
                put(tile, x, y, palette.shade("cloth_brown", 2))
                put(tile, x, y + 1, palette.shade("cloth_brown", 3))
                if x % 5 != 4:
                    put(tile, x, y - 1, palette.shade("wood", 1))
    for _ in range(19 if tilled else 26):
        x, y = map(int, rng.integers(4, TILE - 4, 2))
        put(tile, x, y, palette.shade("cloth_brown", 2 if tilled else 1))
        if rng.random() < 0.3:
            put(tile, x + 1, y, palette.shade("wood", 2))
    return tile


def forest_floor(palette: Palette, seed: int) -> np.ndarray:
    """Muted green leaf litter with small warm fragments and short twigs for the woodland edges."""
    rng = _rng(601 + seed * 79)
    tile = fill(palette, "leaf", 1)
    litter = ("leaf", "leaf", "pine", "cloth_olive", "wood", "dirt")
    for _ in range(16):
        x, y = map(int, rng.integers(0, TILE, 2))
        ramp = litter[int(rng.integers(len(litter)))]
        put(tile, x, y, palette.shade(ramp, 1 if ramp in ("leaf", "pine") else 2))
        put(tile, x + 1, y, palette.shade(ramp, 1 if ramp in ("leaf", "pine") else 2))
        put(tile, x + 2, y + 1, palette.shade("leaf" if ramp in ("leaf", "pine") else ramp, 2))
    if seed % 3 == 0:
        x, y = map(int, rng.integers(7, TILE - 7, 2))
        for step in range(5):
            put(tile, x + step, y + step // 2, palette.shade("wood", 2))
    return tile


def sand(palette: Palette, seed: int) -> np.ndarray:
    """Pale sand: sparse grains and short wind ripples, not a recoloured pebble path."""
    rng = _rng(701 + seed * 83)
    tile = fill(palette, "cloth_cream", 1)
    for _ in range(15):
        x, y = map(int, rng.integers(4, TILE - 4, 2))
        put(tile, x, y, palette.shade("dirt", 0 if rng.random() < 0.6 else 1))
    for _ in range(2):
        x, y = map(int, rng.integers(7, TILE - 9, 2))
        for step in range(int(rng.integers(4, 8))):
            put(tile, x + step, y + int(step > 4), palette.shade("dirt", 1))
            put(tile, x + step, y - 1 + int(step > 4), palette.shade("cloth_cream", 0))
    return tile


def gravel(palette: Palette, seed: int) -> np.ndarray:
    """Small loose angular stones, much finer than the fitted cobblestone street."""
    rng = _rng(801 + seed * 89)
    tile = fill(palette, "stone", 2)
    for _ in range(110):
        x, y = map(int, rng.integers(0, TILE, 2))
        ramp = "cobble" if rng.random() < 0.6 else "stone"
        put(tile, x, y, palette.shade(ramp, 1))
        if rng.random() < 0.55:
            put(tile, x + 1, y, palette.shade(ramp, 0))
            put(tile, x + 1, y + 1, palette.shade(ramp, 3))
    return tile


def shared_border(tile: np.ndarray, original: np.ndarray) -> np.ndarray:
    """Keep neighbouring variants compatible. Only the interior marks differ; shore silhouettes never change."""
    tile[:UNIT] = original[:UNIT]
    tile[-UNIT:] = original[-UNIT:]
    tile[:, :UNIT] = original[:, :UNIT]
    tile[:, -UNIT:] = original[:, -UNIT:]
    return tile


def flowers(palette: Palette, seed: int) -> np.ndarray:
    """Small white/yellow/pink blossoms over quiet turf, without the old repeating light-green patch."""
    rng = _rng(901 + seed * 97)
    tile = turf(palette, seed)
    for i in range(2 + seed % 3):
        x, y = map(int, rng.integers(5, TILE - 5, 2))
        ramp = ("cloth_cream", "cloth_yellow", "cloth_pink")[(seed + i) % 3]
        for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)):
            put(tile, x + dx, y + dy, palette.shade(ramp, 0))
        put(tile, x, y, palette.shade("cloth_yellow", 1))
        put(tile, x, y + 2, palette.shade("leaf", 2))
    return tile


def planks(palette: Palette, seed: int) -> np.ndarray:
    """A wooden floor: planks a fifth of a tile tall, lit along the top, shaded along the bottom, joints staggered,
    grain and a few knots."""
    rng = _rng(seed)
    tile = fill(palette, "wood", 1)
    hi, mid, dark = palette.shade("wood", 0), palette.shade("wood", 2), palette.shade("wood", 3)
    count = 5
    tall = TILE // count
    for row in range(count):
        y = row * tall
        for x in range(TILE):
            put(tile, x, y, hi)
            put(tile, x, y + tall - 1, dark)
        for _ in range(2):
            gx, gy, length = (
                int(rng.integers(TILE)),
                y + int(rng.integers(2, tall - 2)),
                int(rng.integers(4, TILE // 2)),
            )
            for dx in range(length):
                put(tile, gx + dx, gy, mid)
        joint = (row * TILE * 3 // 5 + int(rng.integers(0, TILE // 5))) % TILE
        for dy in range(tall):
            put(tile, joint, y + dy, dark)
        if rng.random() < 0.5:
            kx, ky = int(rng.integers(TILE)), y + tall // 2
            put(tile, kx, ky, dark)
            put(tile, kx + 1, ky, mid)
    return tile


def wall(palette: Palette, seed: int) -> np.ndarray:
    """An inside wall seen from the front: a beam along the top, plaster, a wooden skirting along the bottom."""
    rng = _rng(seed)
    tile = fill(palette, "plaster", 1)
    patches(tile, palette, "plaster", rng, 0.6, 0.65)
    beam, skirting = TILE // 8, TILE // 4
    for x in range(TILE):
        for y in range(beam):
            put(tile, x, y, palette.shade("wood", 2 if y < beam - 1 else 3))
        put(tile, x, beam, palette.shade("plaster", 2))
        for y in range(TILE - skirting, TILE):
            shade = 1 if y == TILE - skirting else 2 if y < TILE - 1 else 3
            put(tile, x, y, palette.shade("wood", shade))
    return tile


def void(palette: Palette) -> np.ndarray:
    """Beyond an interior's walls: pure black, as the rest of the screen around a room is (ADR-0064)."""
    return fill(palette, "black", 0)


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
    """A small smooth wobble for edges, the same in every tile of a ground and wrapping at its sides, so neighbours
    agree."""
    return periodic_noise(_rng(seed), 4) * strength


def shrink(mask: np.ndarray) -> np.ndarray:
    """The mask less its outermost pixel all round (a pixel stays only if its four neighbours are in)."""
    out = mask.copy()
    out[1:, :] &= mask[:-1, :]
    out[:-1, :] &= mask[1:, :]
    out[:, 1:] &= mask[:, :-1]
    out[:, :-1] &= mask[:, 1:]
    return out


def overlay(
    texture: np.ndarray, rim: tuple[int, int, int], mask: int, noise: np.ndarray, shade: tuple | None
) -> np.ndarray:
    """One dual-grid tile of a ground: its texture where the field says, a rim inside its edge, and an optional
    shade on the outside of the edge (a shore's wet line, grass's shadow by a path)."""
    pad = UNIT + 1
    wide = field(mask, noise, pad=pad)
    inside = wide[pad:-pad, pad:-pad]
    # The texture repeats every tile from the map's corner, and this tile sits half a tile in.
    textured = np.roll(texture, (-HALF, -HALF), axis=(0, 1))
    out = pixelkit.blank(TILE, TILE)
    out[inside] = textured[inside]
    core = wide
    for _ in range(UNIT):
        core = shrink(core)
    edge = inside & ~core[pad:-pad, pad:-pad]
    out[edge, :3] = rim
    out[edge, 3] = 255
    if shade is not None:
        # The ground's shadow falls on what is below and to the right of it, lit from the upper left.
        cast = np.zeros_like(wide)
        for step in range(1, UNIT + 1):
            cast[step:, :] |= wide[:-step, :]
            cast[:, step:] |= wide[:, :-step]
        outside = cast[pad:-pad, pad:-pad] & ~inside
        out[outside, :3] = shade
        out[outside, 3] = 255
    return out


def path_overlay(
    texture: np.ndarray, rim: tuple[int, int, int], mask: int, noise: np.ndarray, shade: tuple | None
) -> np.ndarray:
    """Dusty, worn margins follow exposed path edges; connected interiors never receive a tile-shaped rim."""
    out = overlay(texture, rim, mask, noise, shade)
    if mask in (0, 15):
        return out
    width = UNIT * 2
    pad = width + 1
    core = field(mask, noise, pad)
    inside = core[pad:-pad, pad:-pad]
    material = np.roll(texture, (-HALF, -HALF), axis=(0, 1))
    out[inside] = material[inside]
    # A fixed texture phase keeps the weathered margin continuous across different corner shapes.
    grain = periodic_noise(_rng(11019), 8)
    grain[0, :] = grain[-1, :] = (grain[0, :] + grain[-1, :]) / 2
    grain[:, 0] = grain[:, -1] = (grain[:, 0] + grain[:, -1]) / 2
    for depth in range(width):
        smaller = shrink(core)
        band = (core & ~smaller)[pad:-pad, pad:-pad]
        if depth == 0:
            out[band, :3] = rim
        elif depth < UNIT:
            out[band & (grain > -0.2), :3] = rim
        else:
            out[band & (grain > 0.45), :3] = rim
        core = smaller
    return out


GROUNDS = {
    # ground: (texture maker, rim ramp and shade, outside shade or None, edge wobble seed)
    "meadow": (lambda p, s: turf(p, s, "meadow"), ("leaf", 1), None, 21),
    "dry_grass": (lambda p, s: turf(p, s, "dry_grass"), ("cloth_olive", 1), None, 22),
    "forest_floor": (forest_floor, ("cloth_olive", 2), None, 23),
    "moss": (lambda p, s: turf(p, s, "moss"), ("pine", 1), None, 24),
    "flowers": (flowers, ("grass", 1), None, 14),
    "soil": (earth, ("cloth_brown", 2), None, 25),
    "tilled_soil": (lambda p, s: earth(p, s, True), ("cloth_brown", 2), None, 26),
    "path": (dirt, ("dirt", 2), None, 11),
    "brick_path": (dirt, ("cloth_maroon", 2), None, 29),
    "stone_path": (dirt, ("stone", 3), None, 30),
    "wood_path": (dirt, ("wood", 3), None, 31),
    "root_floor": (forest_floor, ("dirt", 2), None, 32),
    "fern_moss": (forest_floor, ("pine", 2), None, 33),
    "glow_moss": (forest_floor, ("pine", 2), None, 34),
    "gravel": (gravel, ("stone", 2), None, 27),
    "sand": (sand, ("cloth_cream", 1), None, 28),
    "cobble": (cobble, ("cobble", 3), None, 12),
    "water": (lambda p, s: water(p, s % 3, 7 + (s // 3) * 73), ("water", 0), ("grass", 3), 13),
}

VARIANTS = 8


def atlas(palette: Palette) -> tuple[np.ndarray, dict]:
    """Every ground tile in one picture, and where each one is: `base` rows (grass, floor) with variants, then each
    overlaid ground's 16 shapes (water three times, one per frame of its ripple)."""
    rows: list[list[np.ndarray]] = []
    layout: dict = {"tile": TILE, "base": {}, "overlay": {}, "order": list(GROUNDS)}
    turf_tiles = [authored_land(palette, "grass", s) for s in range(VARIANTS)]
    turf_tiles = [shared_border(tile, turf_tiles[0]) for tile in turf_tiles]
    base_rows = {
        "grass": turf_tiles,
        "floor": [planks(palette, s) for s in range(2)],
        "wall": [wall(palette, s) for s in range(2)],
        "void": [void(palette)],
    }
    for name in GROUNDS:
        make = GROUNDS[name][0]
        tiles = [varied_land(palette, name, s, make) for s in range(3 if name == "water" else VARIANTS)]
        base_rows[name] = [shared_border(tile, tiles[0]) for tile in tiles]
    for name, tiles in base_rows.items():
        layout["base"][name] = {"row": len(rows), "count": len(tiles)}
        rows.append(tiles)
    for name, (_make, rim, shade, wobble) in GROUNDS.items():
        frames = 3 if name == "water" else 1
        layout["overlay"][name] = {"row": len(rows), "frames": frames, "variants": VARIANTS}
        noise = edge_noise(wobble, 0.12)
        if name in PATHS:
            noise[0, :] = noise[-1, :] = (noise[0, :] + noise[-1, :]) / 2
            noise[:, 0] = noise[:, -1] = (noise[:, 0] + noise[:, -1]) / 2
        originals: list[list[np.ndarray]] = []
        for variant in range(VARIANTS):
            for f in range(frames):
                texture = varied_land(palette, name, variant * frames + f, _make)
                rim_colour = palette.shade(*rim)
                shade_colour = palette.shade(*shade) if shade else None
                render = path_overlay if name in PATHS else overlay
                tiles = [render(texture, rim_colour, mask, noise, shade_colour) for mask in range(16)]
                if variant == 0:
                    originals.append(tiles)
                else:
                    tiles = [shared_border(tile, originals[f][mask]) for mask, tile in enumerate(tiles)]
                rows.append(tiles)
    width = max(len(r) for r in rows) * TILE
    sheet = pixelkit.blank(width, len(rows) * TILE)
    for r, tiles in enumerate(rows):
        for c, tile in enumerate(tiles):
            sheet[r * TILE : (r + 1) * TILE, c * TILE : (c + 1) * TILE] = tile
    return sheet, layout
