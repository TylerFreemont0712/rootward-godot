"""Lanternroot's background objects (ADR-0064, pipeline/world/README.md): buildings, landmarks, trees, props and
furniture, each made from a short spec written in tiles, the way the cast is made (ADR-0063).

A spec (objects/<id>.jsonc) says what the thing is, its footprint on the map, and the colour ramps of its parts. The
pipeline turns it into a blockout of simple shapes, draws the blockout in the town's 3/4 view with Blender, restyles it
with ComfyUI, keeps the candidate that holds the blockout's outline best, cuts it on the blockout's frame (one tile is
always OverworldScale.TILE pixels) and locks it to the palette. Sizes in pixels are never written by hand.

  new       scripts/world.sh new <id> --kind building --footprint 5x5 --what "a cosy cottage"   (a spec to edit)
  adopt     scripts/world.sh adopt <render id> --as <id>   (a spec that re-cuts an existing ComfyUI render)
  check     every spec read and checked (fields, colours, the maps that place it); also run by every stage
  blockout  Blender draws each blockout into pipeline/cache/world/<id>/ (ComfyUI down)
  restyle   ComfyUI img2img on each blockout, cached in pipeline/cache/art/world-<id>/ (ComfyUI up)
  cut       the pictures in game/assets/overworld/world/, world.json, and reviews in Concept/v0.3/world/ (no GPU)

  uv run --project pipeline python pipeline/world/world.py <stage> [--only ids] [--force]
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "art"))
sys.path.insert(0, str(ROOT / "pipeline" / "pixel"))
import generate as gen  # noqa: E402 (ensure_raws, read_raws, resize_premultiplied, palette_of, outline, locked)
import pixelkit  # noqa: E402 (the overworld's palette and lint)
from held import guarded, pick, read_jsonc  # noqa: E402 (shared with the cast)

HERE = Path(__file__).resolve().parent
STYLE = HERE / "style.json"
OBJECTS = HERE / "objects"
BLENDER_SCRIPT = HERE / "blender_world.py"
CONTENT = ROOT / "game" / "content" / "packs" / "core" / "overworld"
SCALE = CONTENT / "scale.jsonc"
CACHE = ROOT / "pipeline" / "cache" / "world"
GAME_OUT = ROOT / "game" / "assets" / "overworld" / "world"
REVIEW_OUT = ROOT / "Concept" / "v0.3" / "world"
PERSON = ROOT / "game" / "assets" / "overworld" / "cast" / "player.png"
INK = "#2a1d2b"
ID = re.compile(r"^[a-z][a-z0-9_-]*$")
KINDS = ("building", "landmark", "tree", "prop", "furniture")
SHAPES = ("box", "cylinder", "ball", "cone", "gable", "hip")
ROOFS = ("gable", "hip", "flat")
COMMON = {
    "id", "kind", "what", "footprint", "ramps", "parts", "source", "pad", "above", "seed", "pick", "denoise", "unlit", "restyle", "swing"
}
FIELDS = {
    "building": {"walls", "roof", "door", "windows"},
    "landmark": set(),
    "tree": {"trunk", "canopy", "shape"},
    "prop": set(),
    "furniture": set(),
}
PART_KEYS = {"shape", "at", "size", "ramp", "shade"}


class SpecError(ValueError):
    """A spec that cannot be made, with every reason and how to fix it."""


# ---------------------------------------------------------------------------------------------------------------------
# Reading and checking specs (pure; tested in test_world.py)


def load_style() -> dict:
    return json.loads(STYLE.read_text())


def load_scale() -> dict:
    return read_jsonc(SCALE.read_text())


def suggest(word: str, choices: list[str] | tuple[str, ...]) -> str:
    close = difflib.get_close_matches(word, list(choices), n=3, cutoff=0.5)
    return f" (did you mean {', '.join(close)}?)" if close else ""


def is_pair(value: object) -> bool:
    return isinstance(value, list) and len(value) == 2 and all(isinstance(v, (int, float)) for v in value)


def is_triple(value: object) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(isinstance(v, (int, float)) for v in value)


def ramp_of(ref: str, spec: dict) -> str:
    """A part's ramp: a role the spec names in `ramps` ("roof"), else a palette ramp by name ("wood")."""
    return spec.get("ramps", {}).get(ref, ref)


def check_spec(spec: dict, file_id: str, palette: pixelkit.Palette, style: dict) -> list[str]:
    """Every problem with a spec, each saying how to fix it. An empty list means it can be made."""
    problems: list[str] = []
    ramps = sorted(palette.ramps)
    if spec.get("id") != file_id:
        problems.append(f'"id" is {spec.get("id")!r} but the file is {file_id}.jsonc: make them the same')
    if not ID.match(file_id):
        problems.append(
            f"the id {file_id!r} must be lowercase letters, digits, dashes and underscores, starting with a letter"
        )
    kind = spec.get("kind")
    if kind not in KINDS:
        problems.append(f'"kind" is {kind!r}: use one of {", ".join(KINDS)}' + suggest(str(kind), KINDS))
        return problems
    allowed = COMMON | FIELDS[kind]
    if not isinstance(spec.get("restyle", True), bool):
        problems.append('"restyle" must be true or false: false cuts the Blender geometry directly for exact modular joins')
    for key in spec:
        if key not in allowed and not key.startswith("_"):
            problems.append(f'unknown field "{key}" for a {kind}' + suggest(key, sorted(allowed)))
    what = spec.get("what")
    if not isinstance(what, str) or len(what.split()) < 3:
        problems.append('"what" must say what it is in a few words, e.g. "a cosy cottage with a thatched roof"')
    elif len(what) > 160:
        problems.append('"what" is longer than 160 characters: keep it to one short line')
    footprint = spec.get("footprint")
    if not (is_pair(footprint) and all(isinstance(v, int) and 1 <= v <= 16 for v in footprint)):
        problems.append('"footprint" must be [width, height] in whole tiles from 1 to 16, as the map\'s "size"')
        return problems
    roles = spec.get("ramps", {})
    if not isinstance(roles, dict):
        problems.append('"ramps" must map a role to a palette ramp, e.g. {"roof": "thatch"}')
        roles = {}
    problems += check_unlit(spec, roles, palette)
    if "swing" in spec:
        swing = spec["swing"]
        if not isinstance(swing, dict) or swing.get("axis") not in ("horizontal", "vertical"):
            problems.append('"swing.axis" must be horizontal or vertical')
        elif swing.get("material", "wood") not in ("wood", "steel"):
            problems.append('"swing.material" must be wood or steel')
    for role, ramp in roles.items():
        if ramp not in palette.ramps:
            problems.append(f'ramp "{ramp}" for "{role}" is not in pipeline/pixel/palette.json' + suggest(ramp, ramps))
    source = spec.get("source", "blockout")
    if source != "blockout":
        problems += check_source(source)
        if isinstance(source, dict) and "images" in source and spec.get("unlit"):
            problems.append('use source.images for authored states or unlit for lamp recolours, not both')
        for key in ("pad", "above"):
            value = spec.get(key, 0)
            if not isinstance(value, (int, float)) or value < 0 or value * 2 != int(value * 2):
                problems.append(f'"{key}" must be 0 or more, in half tiles (0, 0.5, 1, ...)')
        if not roles:
            problems.append('"ramps" must name at least one palette ramp: the picture is locked to those colours')
        return problems
    for role in style["kinds"][kind]["roles"]:
        if role not in roles and kind in ("building", "tree"):
            problems.append(f'a {kind} needs a ramp for "{role}" in "ramps"')
    if kind == "building":
        problems += check_building(spec, style)
    if kind == "tree":
        problems += check_tree(spec)
    parts = spec.get("parts", [])
    if kind in ("prop", "furniture", "landmark") and not parts:
        problems.append(f'a {kind} is made of "parts": add at least one, e.g. {example_part()}')
    if not isinstance(parts, list):
        problems.append('"parts" must be a list of shapes')
        return problems
    for i, part in enumerate(parts):
        problems += check_part(part, i, spec, palette)
    return problems


def check_unlit(spec: dict, roles: dict, palette: pixelkit.Palette) -> list[str]:
    """`unlit` makes a two-frame picture (a lamp's dark glass, then lit): each role named swaps to another ramp."""
    unlit = spec.get("unlit")
    if unlit is None:
        return []
    if not isinstance(unlit, dict) or not unlit:
        return ['"unlit" must map a role in "ramps" to the palette ramp it has when unlit, e.g. {"light": "steel"}']
    problems = []
    for role, ramp in unlit.items():
        if role not in roles:
            problems.append(f'"unlit" names the role "{role}", which is not in "ramps"' + suggest(role, list(roles)))
        elif ramp not in palette.ramps:
            problems.append(f'"unlit" ramp "{ramp}" is not in pipeline/pixel/palette.json' + suggest(ramp, sorted(palette.ramps)))
        elif len(palette.ramps[ramp]) != len(palette.ramps[roles[role]]):
            problems.append(f'"unlit" ramp "{ramp}" has a different number of shades from "{roles[role]}": pick another')
    return problems


def check_source(source: object) -> list[str]:
    if isinstance(source, dict) and not isinstance(source.get("registered", False), bool):
        return ['"registered" in "source" must be true or false']
    if isinstance(source, dict) and "images" in source:
        images = source["images"]
        if not isinstance(images, list) or not images or not all(isinstance(path, str) for path in images):
            return ['"images" in "source" must be a nonempty list of frame image paths']
        if "image" in source or "picture" in source:
            return ['"source" must use only one of image, images or picture']
        return [f"source image {path!r} does not exist" for path in images if not (ROOT / path).exists()]
    if isinstance(source, dict) and "picture" in source:
        folder = gen.CACHE_DIR / str(source["picture"])
        if not (folder / "rgb_0.png").exists():
            return [f"source picture {source['picture']!r} has no cached render in pipeline/cache/art/"]
        if not isinstance(source.get("pick", 0), int):
            return ['"pick" in "source" must be a candidate number (0, 1, ...)']
        return []
    if isinstance(source, dict) and "image" in source:
        if not (ROOT / str(source["image"])).exists():
            return [f"source image {source['image']!r} does not exist (paths are from the repository root)"]
        return []
    return ['"source" must be "blockout", {"picture": "<render id>"}, {"image": "<path>"} or {"images": ["<frame path>", ...]}']


def check_building(spec: dict, style: dict) -> list[str]:
    problems = []
    width, height = spec["footprint"]
    walls = spec.get("walls", style["kinds"]["building"]["fields"]["walls"])
    if not isinstance(walls, (int, float)) or not 1.5 <= walls <= height - 0.5:
        problems.append(f'"walls" must be from 1.5 tiles to the footprint\'s height less half a tile ({height - 0.5})')
    roof = spec.get("roof", "gable")
    if roof not in ROOFS:
        problems.append(f'"roof" must be one of {", ".join(ROOFS)}' + suggest(str(roof), ROOFS))
    door = spec.get("door")
    if door is not None and not (isinstance(door, int) and 0 <= door < width):
        problems.append(f'"door" is the door\'s column from the left, 0 to {width - 1}, or null for none')
    windows = spec.get("windows", [])
    if not (isinstance(windows, list) and all(isinstance(c, int) and 0 <= c < width for c in windows)):
        problems.append(f'"windows" is a list of columns from the left, each 0 to {width - 1}')
    elif door is not None and door in windows:
        problems.append(f"column {door} has both the door and a window: move the window")
    if not problems and building_depth(spec, style) < 0.6:
        problems.append('the walls leave too little room for a roof: lower "walls" or make the footprint taller')
    return problems


def check_tree(spec: dict) -> list[str]:
    problems = []
    if not isinstance(spec.get("trunk", 1.0), (int, float)) or not 0.3 <= spec.get("trunk", 1.0) <= 4:
        problems.append('"trunk" is the trunk\'s height in tiles, from 0.3 to 4')
    canopy = spec.get("canopy", [2.0, 2.0])
    if not (is_pair(canopy) and all(0.5 <= v <= 8 for v in canopy)):
        problems.append('"canopy" is [width, height] of the leaves in tiles, each from 0.5 to 8')
    if spec.get("shape", "round") not in ("round", "pine"):
        problems.append('"shape" of a tree is "round" or "pine"')
    return problems


def example_part() -> str:
    return '{"shape": "box", "at": [0.1, 0.1, 0], "size": [0.8, 0.8, 1.0], "ramp": "wood"}'


def check_part(part: object, index: int, spec: dict, palette: pixelkit.Palette) -> list[str]:
    where = f"part {index}"
    if not isinstance(part, dict):
        return [f"{where} must be an object like {example_part()}"]
    problems = [
        f'{where}: unknown field "{key}"' + suggest(key, sorted(PART_KEYS)) for key in part if key not in PART_KEYS
    ]
    if part.get("shape") not in SHAPES:
        problems.append(
            f'{where}: "shape" must be one of {", ".join(SHAPES)}' + suggest(str(part.get("shape")), SHAPES)
        )
    if not is_triple(part.get("at")) or not is_triple(part.get("size")):
        problems.append(f'{where}: "at" and "size" are [x, y, z] in tiles: x right, y back from the front edge, z up')
        return problems
    if any(v <= 0 for v in part["size"]):
        problems.append(f'{where}: every "size" must be more than 0')
    ramp = ramp_of(str(part.get("ramp", "")), spec)
    if ramp not in palette.ramps:
        problems.append(f'{where}: "ramp" {part.get("ramp")!r} is neither a role in "ramps" nor a palette ramp')
    elif "shade" in part and not (isinstance(part["shade"], int) and 0 <= part["shade"] < len(palette.ramps[ramp])):
        problems.append(f'{where}: "shade" is 0 (lightest) to {len(palette.ramps[ramp]) - 1} (darkest) of its ramp')
    width, height = spec["footprint"]
    x, y, z = part["at"]
    sx, sy, _ = part["size"]
    if x < -1 or x + sx > width + 1:
        problems.append(f"{where}: it reaches more than a tile past the footprint's sides (0 to {width})")
    if y < -0.1:
        problems.append(f"{where}: it stands in front of the footprint (y below 0): it would be cut off")
    if z < 0:
        problems.append(f"{where}: it is below the ground (z below 0)")
    return problems


def read_spec(path: Path) -> dict:
    try:
        spec = read_jsonc(path.read_text())
    except json.JSONDecodeError as error:
        raise SpecError(f"{path.name}: not valid JSONC ({error})") from error
    if not isinstance(spec, dict):
        raise SpecError(f"{path.name}: a spec is one JSON object")
    return spec


def load_specs(only: str | None, palette: pixelkit.Palette, style: dict) -> dict[str, dict]:
    """Every spec in objects/ (or the ones `only` names), checked; any problem stops everything, listed in full."""
    paths = sorted(OBJECTS.glob("*.jsonc"))
    wanted = [token.strip() for token in only.split(",")] if only else None
    if wanted:
        missing = [w for w in wanted if not (OBJECTS / f"{w}.jsonc").exists()]
        if missing:
            sys.exit(f"--only names no spec in pipeline/world/objects/: {', '.join(missing)}")
        paths = [OBJECTS / f"{w}.jsonc" for w in wanted]
    specs, failures = {}, []
    placed = placements()
    for path in paths:
        try:
            spec = read_spec(path)
        except SpecError as error:
            failures.append(str(error))
            continue
        problems = check_spec(spec, path.stem, palette, style) + check_maps(spec, placed)
        failures += [f"{path.name}: {p}" for p in problems]
        specs[path.stem] = spec
    if failures:
        sys.exit("cannot make these specs:\n  " + "\n  ".join(failures))
    return specs


def placements() -> dict[str, list[dict]]:
    """Every object the maps place, by its art: what the specs are checked against."""
    found: dict[str, list[dict]] = {}
    for path in sorted((CONTENT / "maps").glob("*.jsonc")):
        data = read_jsonc(path.read_text())
        for thing in data.get("objects", []):
            if "art" in thing:
                found.setdefault(str(thing["art"]), []).append({**thing, "_map": path.stem})
    return found


def check_maps(spec: dict, placed: dict[str, list[dict]]) -> list[str]:
    """A spec must fit every place a map puts it: the same footprint, and a building's door on its door cell."""
    problems = []
    footprint = spec.get("footprint")
    for thing in placed.get(spec.get("id", ""), []):
        # Programmed props can use a full-footprint authored sheet. Legacy one-tile art still repeats per cell.
        # Studio resizing keeps the native picture footprint explicitly; the placed size is a render transform.
        size = thing.get("art_size", thing.get("size", [1, 1]))
        if "program" in thing and footprint == [1, 1]:
            size = [1, 1]
        if footprint != size:
            problems.append(
                f'map {thing["_map"]} places it at {thing["at"]} with size {size}, but "footprint" is {footprint}: '
                "make them the same (or change the map)"
            )
        shape = thing.get("art_shape", {})
        shape = shape if isinstance(shape, dict) else {}
        # A manually positioned logical doorway has its own reference grid, independent of the source picture.
        door = None if "door_size" in shape else shape.get("door", thing.get("door"))
        if spec.get("kind") == "building" and door is not None and spec.get("source", "blockout") == "blockout":
            if spec.get("door") != door[0]:
                problems.append(f'map {thing["_map"]} has its door in column {door[0]}: set "door": {door[0]}')
    return problems


# ---------------------------------------------------------------------------------------------------------------------
# Blockouts: a spec as a list of shapes (pure; tested). In tiles: x right, y back from the front edge, z up.


def shape(name: str, kind: str, box: list[float], ramp: str, shade: int | None = None) -> dict:
    """One shape filling a box [x0, y0, z0, x1, y1, z1]: a box, a cylinder or a cone standing up, a ball, or a roof
    (gable or hip, its ridge along x). `shade` picks a shade of the ramp other than the style's (dark iron, say)."""
    made = {"name": name, "shape": kind, "box": [round(v, 4) for v in box], "ramp": ramp}
    if shade is not None:
        made["shade"] = shade
    return made


def building_depth(spec: dict, style: dict) -> float:
    """How deep a building stands, solved so its picture fills its footprint exactly.

    LEARN: the map's footprint is the whole picture (the hall is 9 x 8 tiles and its picture 9 x 8 tiles), as in the
    town since ADR-0061. In the 3/4 view a building's height on screen is its walls, then its roof: a roof as tall as
    the building is deep (a 45 degree pitch) reaches walls + depth * (1 + depth_scale / 2). Setting that to the
    footprint's height gives the depth, so a small model only chooses the walls and never the roof."""
    k = style["projection"]["depth_scale"]
    walls = spec.get("walls", style["kinds"]["building"]["fields"]["walls"])
    rows = spec["footprint"][1]
    if spec.get("roof", "gable") == "flat":
        return (rows - walls - 0.25) / k
    return (rows - walls) / (1 + k / 2)


def building_shapes(spec: dict, style: dict) -> list[dict]:
    width = spec["footprint"][0]
    walls = spec.get("walls", style["kinds"]["building"]["fields"]["walls"])
    depth = building_depth(spec, style)
    roof = spec.get("roof", "gable")
    eave, inset = 0.25, 0.3
    shapes = [
        shape("walls", "box", [inset, 0.0, 0.0, width - inset, depth, walls], "walls"),
        shape("base", "box", [inset - 0.05, -0.04, 0.0, width - inset + 0.05, depth, 0.3], "base"),
        shape("eaves", "box", [inset, -0.03, walls - 0.18, width - inset, depth, walls], "trim"),
        shape("post_left", "box", [inset, -0.04, 0.0, inset + 0.16, 0.12, walls], "trim"),
        shape("post_right", "box", [width - inset - 0.16, -0.04, 0.0, width - inset, 0.12, walls], "trim"),
    ]
    if roof == "flat":
        shapes.append(
            shape("roof", "box", [inset - 0.1, -0.1, walls, width - inset + 0.1, depth + 0.1, walls + 0.25], "roof")
        )
    else:
        rise = depth
        shapes.append(shape("roof", roof, [0.0, -eave, walls, float(width), depth + eave, walls + rise], "roof"))
    door = spec.get("door")
    if door is not None:
        top = min(2.15, walls - 0.3)
        shapes.append(shape("door", "box", [door + 0.14, -0.06, 0.0, door + 0.86, 0.02, top], "door"))
        shapes.append(shape("door_frame", "box", [door + 0.06, -0.05, 0.0, door + 0.94, 0.01, top + 0.1], "trim"))
    for i, column in enumerate(spec.get("windows", [])):
        low = max(0.7, walls * 0.4)
        shapes.append(shape(f"window_{i}", "box", [column + 0.2, -0.06, low, column + 0.8, 0.02, low + 0.65], "window"))
        shapes.append(shape(f"sill_{i}", "box", [column + 0.12, -0.1, low - 0.1, column + 0.88, 0.02, low], "trim"))
    return shapes


def tree_shapes(spec: dict) -> list[dict]:
    width, rows = spec["footprint"]
    trunk = spec.get("trunk", 1.0)
    canopy_w, canopy_h = spec.get("canopy", [2.0, 2.0])
    cx, cy = width / 2, min(rows, 1) / 2
    stem = max(0.2, min(0.5, width * 0.35))
    shapes = [
        shape(
            "trunk", "cylinder", [cx - stem / 2, cy - stem / 2, 0.0, cx + stem / 2, cy + stem / 2, trunk + 0.4], "trunk"
        )
    ]
    depth = min(canopy_w, 1.6)
    low = trunk
    if spec.get("shape", "round") == "pine":
        tiers = 3
        for i in range(tiers):
            tier_w = canopy_w * (1 - i * 0.25)
            z0 = low + canopy_h * i / (tiers + 1)
            z1 = z0 + canopy_h / tiers * 1.6
            shapes.append(
                shape(
                    f"leaves_{i}",
                    "cone",
                    [cx - tier_w / 2, cy - depth / 2, z0, cx + tier_w / 2, cy + depth / 2, min(z1, low + canopy_h)],
                    "leaves",
                )
            )
    else:
        shapes.append(
            shape(
                "leaves",
                "ball",
                [cx - canopy_w / 2, cy - depth / 2, low, cx + canopy_w / 2, cy + depth / 2, low + canopy_h],
                "leaves",
            )
        )
        shapes.append(
            shape(
                "leaves_top",
                "ball",
                [
                    cx - canopy_w * 0.32,
                    cy - depth * 0.3,
                    low + canopy_h * 0.45,
                    cx + canopy_w * 0.32,
                    cy + depth * 0.3,
                    low + canopy_h * 1.02,
                ],
                "leaves",
            )
        )
    return shapes


def part_shapes(spec: dict) -> list[dict]:
    out = []
    for i, part in enumerate(spec.get("parts", [])):
        x, y, z = part["at"]
        sx, sy, sz = part["size"]
        box = [x, y, z, x + sx, y + sy, z + sz]
        out.append(shape(f"part_{i}", part["shape"], box, str(part["ramp"]), part.get("shade")))
    return out


def shapes_of(spec: dict, style: dict) -> list[dict]:
    """The whole blockout: the kind's own shapes (a building's walls, roof, door and windows; a tree's trunk and
    leaves), then the spec's parts."""
    kind = spec["kind"]
    own = building_shapes(spec, style) if kind == "building" else tree_shapes(spec) if kind == "tree" else []
    return own + part_shapes(spec)


def top_of(item: dict, k: float) -> float:
    """How high on the picture (in tiles above the footprint's front edge) a shape reaches in the 3/4 view."""
    x0, y0, z0, x1, y1, z1 = item["box"]
    cy, cz, ry, rz = (y0 + y1) / 2, (z0 + z1) / 2, (y1 - y0) / 2, (z1 - z0) / 2
    kind = item["shape"]
    if kind == "ball":
        return cy * k + cz + math.hypot(ry * k, rz)
    if kind == "cone":
        return max(cy * k + z1, y1 * k + z0)
    if kind in ("gable", "hip"):
        return max(cy * k + z1, y1 * k + z0)
    return y1 * k + z1


def half_up(value: float) -> float:
    return math.ceil(value * 2 - 1e-6) / 2


def frame_of(spec: dict, style: dict) -> dict:
    """The picture's frame in tiles: `pad` past each side of the footprint and `height` up from its front edge. A
    blockout's frame holds all of its shapes; a building's is its footprint exactly. Always whole half tiles."""
    width, rows = spec["footprint"]
    if spec.get("source", "blockout") != "blockout":
        return {
            "pad": float(spec.get("pad", 0)),
            "width": width + 2 * float(spec.get("pad", 0)),
            "height": rows + float(spec.get("above", 0)),
        }
    k = style["projection"]["depth_scale"]
    shapes = shapes_of(spec, style)
    left = min(item["box"][0] for item in shapes)
    right = max(item["box"][3] for item in shapes)
    pad = half_up(max(0.0, -left, right - width))
    top = max(top_of(item, k) for item in shapes)
    height = float(rows) if spec["kind"] == "building" else max(float(rows), half_up(top + 0.05))
    return {"pad": pad, "width": width + 2 * pad, "height": height}


def render_size(frame: dict, style: dict) -> tuple[int, int, int]:
    """Render pixels per tile (a multiple of 16, so half tiles land on whole multiples of 8) and the render's size."""
    long_side = style["projection"]["long_side"]
    per_tile = max(16, int(long_side / max(frame["width"], frame["height"]) // 16 * 16))
    return per_tile, round(frame["width"] * per_tile), round(frame["height"] * per_tile)


def canvas_of(width: int, height: int, min_side: int) -> tuple[int, int, int, int]:
    """ComfyUI draws poorly below about 512 pixels a side: a small render is centred on a larger canvas (multiples of 8)
    and cut back out after. Returns the canvas size and where the render sits on it."""
    canvas_w = max(width, (min_side + 7) // 8 * 8)
    canvas_h = max(height, (min_side + 7) // 8 * 8)
    return canvas_w, canvas_h, (canvas_w - width) // 2, (canvas_h - height) // 2


def ramp_word(ramp: str, style: dict) -> str:
    return style.get("ramp_words", {}).get(ramp, ramp.replace("cloth_", "").replace("_", " "))


def prompt_for(spec: dict, style: dict) -> tuple[str, str]:
    """The restyle's prompt: what it is, the kind, and each coloured role in words ("thatch roof, plaster walls")."""
    kind = style["kinds"][spec["kind"]]
    roles = ", ".join(f"{ramp_word(ramp, style)} {role}" for role, ramp in spec.get("ramps", {}).items())
    body = f"{spec['what']}, {kind['words']}" + (f", {roles}" if roles else "")
    words = style["prompt"]
    return words["prefix"] + body + words["suffix"], words["negative"]


def lock_ramps(spec: dict, style: dict) -> list[str]:
    ramps = list(dict.fromkeys([*spec.get("ramps", {}).values(), *(p["ramp"] for p in spec.get("parts", []))]))
    return [ramp_of(r, spec) for r in ramps] + style["always_lock"]


def digest(spec: dict, style: dict) -> str:
    """What a picture was made from: its spec and the style. A picture whose digest differs is stale."""
    text = json.dumps({"spec": spec, "style": style}, sort_keys=True)
    return hashlib.sha256(text.encode()).hexdigest()[:16]


# ---------------------------------------------------------------------------------------------------------------------
# Cutting a picture (pure; tested)


def finish(rgba: np.ndarray, size: tuple[int, int], colors: int, ramps: list[str]) -> Image.Image:
    """A frame cut to `size` (premultiplied box filter: every render pixel counts, no edge halo), hard alpha, its few
    colours, an ink outline, then every colour locked to the spec's ramps."""
    small = gen.resize_premultiplied(rgba, size)
    solid = small[..., 3] > 0.5
    if not solid.any():
        raise ValueError("the picture is empty after the cut")
    rgb = np.round(small[..., :3] * 255)
    shared = gen.palette_of(rgb[solid], colors)
    canvas = np.zeros((size[1], size[0], 4), np.uint8)
    canvas[solid, :3] = gen.apply_palette(rgb, shared)[solid]
    canvas[solid, 3] = 255
    image = Image.fromarray(gen.outline(canvas, INK), "RGBA")
    return gen.locked([("picture", image)], {"lock": True, "lock_ramps": ramps})[0][1]


def unlit_picture(picture: Image.Image, spec: dict, palette: pixelkit.Palette) -> Image.Image:
    """The picture as two frames side by side, for a lamp: frame 0 with each shade of every `unlit` role's ramp swapped
    for the same shade of the ramp it names (the dark glass), frame 1 as cut (lit). The game shows the last frame lit.

    LEARN: the cut has already snapped every pixel onto the palette, so a colour is exactly one shade of one ramp and
    swapping ramps is a lookup, not a guess: no new colours, and the lint still passes."""
    rgba = np.asarray(picture.convert("RGBA")).copy()
    dark = rgba.copy()
    for role, to_ramp in spec["unlit"].items():
        shades = palette.ramps[ramp_of(role, spec)]
        for shade, target in zip(shades, palette.ramps[to_ramp], strict=True):
            same = (rgba[..., :3] == np.array(shade, np.uint8)).all(axis=-1) & (rgba[..., 3] > 0)
            dark[same, :3] = target
    sheet = Image.new("RGBA", (picture.width * 2, picture.height), (0, 0, 0, 0))
    sheet.paste(Image.fromarray(dark, "RGBA"), (0, 0))
    sheet.paste(Image.fromarray(rgba, "RGBA"), (picture.width, 0))
    return sheet


def fitted(raw: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    """A picture with no blockout (an adopted render): its subject scaled to fit `size` keeping its shape, standing on
    the bottom edge, centred. Returned at four times `size` so the cut still averages many pixels into each."""
    solid = raw[..., 3] > 0.5
    if not solid.any():
        raise ValueError("the source picture is empty")
    rows, columns = np.nonzero(solid.any(axis=1))[0], np.nonzero(solid.any(axis=0))[0]
    subject = raw[rows[0] : rows[-1] + 1, columns[0] : columns[-1] + 1]
    big = (size[0] * 4, size[1] * 4)
    scale = min(big[0] / subject.shape[1], big[1] / subject.shape[0])
    shape_ = (max(1, round(subject.shape[1] * scale)), max(1, round(subject.shape[0] * scale)))
    scaled = gen.resize_premultiplied(subject, shape_) if scale < 1 else resize_up(subject, shape_)
    out = np.zeros((big[1], big[0], 4), np.float32)
    x0 = (big[0] - shape_[0]) // 2
    out[big[1] - shape_[1] :, x0 : x0 + shape_[0]] = scaled
    return out


def resize_up(rgba: np.ndarray, size: tuple[int, int]) -> np.ndarray:
    channels = [
        np.asarray(Image.fromarray(np.ascontiguousarray(rgba[..., c])).resize(size, Image.Resampling.BILINEAR))
        for c in range(4)
    ]
    return np.clip(np.stack(channels, axis=-1), 0, 1)


def coverage(image: Image.Image, spec: dict, tile: int, pad: float) -> float:
    """How much of the footprint's bottom row the picture covers: a building or prop should stand on its whole base."""
    alpha = np.asarray(image)[..., 3] > 0
    width = spec["footprint"][0]
    x0 = round(pad * tile)
    row = alpha[-tile // 2 :, x0 : x0 + width * tile]
    return float(row.any(axis=0).mean()) if row.size else 0.0


# ---------------------------------------------------------------------------------------------------------------------
# Stages


def code_digest() -> str:
    hashed = hashlib.sha256()
    for script in (BLENDER_SCRIPT, ROOT / "pipeline" / "animation" / "blender_base.py"):
        hashed.update(script.read_bytes())
    return hashed.hexdigest()[:16]


def blockout_path(oid: str) -> Path:
    return CACHE / oid / "blockout.png"


def blender_binary() -> str:
    found = os.environ.get("BLENDER") or shutil.which("blender") or str(Path.home() / "blender" / "blender")
    if not Path(found).exists() and not shutil.which(found):
        sys.exit("Blender not found: set BLENDER to its path")
    return found


def stage_blockout(specs: dict, palette: pixelkit.Palette, style: dict, force: bool) -> None:
    for oid, spec in specs.items():
        if spec.get("source", "blockout") != "blockout":
            continue
        frame = frame_of(spec, style)
        per_tile, width, height = render_size(frame, style)
        job = {
            "id": oid,
            "shapes": [
                {
                    **item,
                    "colour": "#%02x%02x%02x"
                    % palette.shade(ramp_of(item["ramp"], spec), item.get("shade", style["shade"])),
                }
                for item in shapes_of(spec, style)
            ],
            "frame": frame,
            "footprint": spec["footprint"],
            "depth_scale": style["projection"]["depth_scale"],
            "size": [width, height],
            "samples": style["projection"]["samples"],
            "out": str(blockout_path(oid)),
            "blend": str(CACHE / oid / "blockout.blend"),
            "code": code_digest(),
        }
        folder = CACHE / oid
        text = json.dumps(job, indent=1, sort_keys=True)
        job_path = folder / "job.json"
        if blockout_path(oid).exists() and job_path.exists() and job_path.read_text() == text and not force:
            print(f"  have {oid}")
            continue
        folder.mkdir(parents=True, exist_ok=True)
        blockout_path(oid).unlink(missing_ok=True)
        job_path.write_text(text)
        command = [
            blender_binary(),
            "--background",
            "--factory-startup",
            "--python",
            str(BLENDER_SCRIPT),
            "--",
            str(job_path),
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0 or not blockout_path(oid).exists():
            print(result.stdout[-3000:], result.stderr[-3000:])
            sys.exit(f"blender failed for {oid}")
        print(f"  blockout {oid}: {frame['width']:g} x {frame['height']:g} tiles, {width} x {height} px", flush=True)


def comfy_job(oid: str, spec: dict, style: dict) -> dict:
    """The ComfyUI img2img job for one blockout: the blockout centred on a canvas ComfyUI draws well at."""
    frame = frame_of(spec, style)
    _, width, height = render_size(frame, style)
    canvas_w, canvas_h, ox, oy = canvas_of(width, height, style["projection"]["min_side"])
    init = CACHE / oid / "init.png"
    blockout = Image.open(blockout_path(oid)).convert("RGBA")
    sheet = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    sheet.alpha_composite(blockout, (ox, oy))
    sheet.save(init)
    comfy, kind = style["comfy"], style["kinds"][spec["kind"]]
    text, negative = prompt_for(spec, style)
    job_id = f"world-{oid}"
    return {
        "id": job_id,
        "checkpoint": comfy["checkpoint"],
        "lora": comfy["lora"],
        "lora_strength": comfy["lora_strength"],
        "prefix": "",
        "prompt": text,
        "suffix": "",
        "negative": negative,
        "width": canvas_w,
        "height": canvas_h,
        "steps": comfy["steps"],
        "cfg": comfy["cfg"],
        "sampler": comfy["sampler"],
        "scheduler": comfy["scheduler"],
        "rmbg": comfy["rmbg"],
        "candidates": comfy["candidates"],
        "seed": int(spec.get("seed", int(hashlib.sha256(job_id.encode()).hexdigest()[:8], 16))),
        "init": {
            "image": str(init.relative_to(ROOT)),
            "denoise": spec.get("denoise", kind["denoise"]),
            "matte": "#ffffff",
        },
    }


def stage_restyle(specs: dict, style: dict, force: bool) -> None:
    for oid, spec in specs.items():
        if spec.get("source", "blockout") != "blockout" or not spec.get("restyle", True):
            continue
        if not blockout_path(oid).exists():
            sys.exit(f"no blockout for {oid}: run scripts/world.sh blockout --only {oid} first (ComfyUI down)")
        gen.ensure_raws(style["comfy"]["url"], comfy_job(oid, spec, style), force, False)


def restyled_frame(oid: str, spec: dict, style: dict) -> tuple[np.ndarray, dict]:
    """The chosen restyle, cut back out of its canvas and held to the blockout's outline; with the scores."""
    if not spec.get("restyle", True):
        blockout = np.asarray(Image.open(blockout_path(oid)).convert("RGBA"), dtype=np.float32) / 255
        return blockout, {"pick": 0, "iou": [1.0], "candidates": [blockout], "blockout": blockout}
    job = comfy_job(oid, spec, style)
    raws = gen.ensure_raws(style["comfy"]["url"], job, False, True)
    if raws is None:
        sys.exit(f"no restyle for {oid}: run scripts/world.sh restyle --only {oid} (ComfyUI up)")
    blockout = np.asarray(Image.open(blockout_path(oid)).convert("RGBA"), dtype=np.float32) / 255
    height, width = blockout.shape[:2]
    _, _, ox, oy = canvas_of(width, height, style["projection"]["min_side"])
    cut = [raw[oy : oy + height, ox : ox + width] for raw in raws]
    chosen, scores = pick(cut, blockout[..., 3], spec.get("pick"))
    held = guarded(cut[chosen], blockout[..., 3], style["kinds"][spec["kind"]]["guard"])
    return held, {"pick": chosen, "iou": [round(s, 3) for s in scores], "candidates": cut, "blockout": blockout}


def source_frame(spec: dict, size: tuple[int, int], frame: int = 0) -> np.ndarray:
    source = spec["source"]
    if "picture" in source:
        number = int(source.get("pick", 0))
        raw = gen.read_raws(gen.CACHE_DIR / source["picture"], number + 1)[number]
    else:
        path = source["images"][frame] if "images" in source else source["image"]
        raw = np.asarray(Image.open(ROOT / path).convert("RGBA"), dtype=np.float32) / 255
    if source.get("registered", False):
        # LEARN: transparent margins are part of a registered tile's geometry. Cropping them moves rail joins and
        # rescales an open gate differently from its closed frame. Resize the whole canvas on one shared frame.
        return gen.resize_premultiplied(raw, (size[0] * 4, size[1] * 4))
    return fitted(raw, size)


def stage_cut(specs: dict, palette: pixelkit.Palette, style: dict) -> None:
    tile = int(load_scale()["tile"])
    index_path = GAME_OUT / "world.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}
    GAME_OUT.mkdir(parents=True, exist_ok=True)
    for oid, spec in specs.items():
        frame = frame_of(spec, style)
        size = (round(frame["width"] * tile), round(frame["height"] * tile))
        kind = style["kinds"][spec["kind"]]
        report: dict = {}
        if spec.get("source", "blockout") == "blockout":
            if not blockout_path(oid).exists():
                sys.exit(f"no blockout for {oid}: run scripts/world.sh blockout --only {oid} first")
            held, report = restyled_frame(oid, spec, style)
        else:
            held = source_frame(spec, size)
        picture = finish(held, size, kind["colors"], lock_ramps(spec, style))
        sources = spec.get("source", {})
        images = sources.get("images", []) if isinstance(sources, dict) else []
        frames = len(images) if images else (2 if spec.get("unlit") else 1)
        if images:
            sheet = Image.new("RGBA", (size[0] * frames, size[1]))
            for number in range(frames):
                part = picture if number == 0 else finish(
                    source_frame(spec, size, number), size, kind["colors"], lock_ramps(spec, style)
                )
                sheet.paste(part, (number * size[0], 0))
        else:
            sheet = unlit_picture(picture, spec, palette) if frames == 2 else picture
        problems = pixelkit.problems(np.asarray(sheet), palette, oid)
        if problems:
            sys.exit("the cut failed the pixel lint:\n  " + "\n  ".join(problems))
        sheet.save(GAME_OUT / f"{oid}.png", optimize=True)
        index[oid] = {
            "kind": spec["kind"],
            "size": [sheet.width, sheet.height],
            "footprint": spec["footprint"],
            "frames": frames,
            "tile": tile,
            "made_from": digest(spec, style),
        }
        if "swing" in spec:
            index[oid]["swing"] = spec["swing"]
        covered = coverage(picture, spec, tile, frame["pad"])
        review(oid, spec, sheet, frame, tile, report, covered, palette, frames)
        scores = f", picked {report['pick']} of iou {report['iou']}" if report else ""
        thin = spec["kind"] == "building" and covered < 0.8
        warn = "  (covers only {:.0%} of its base: check the review)".format(covered) if thin else ""
        print(f"  cut {oid}: {size[0]} x {size[1]} px{scores}{warn}", flush=True)
    index_path.write_text(json.dumps(dict(sorted(index.items())), indent=1, sort_keys=True) + "\n")
    print(f"  wrote {len(specs)} picture(s) to {GAME_OUT.relative_to(ROOT)}; review in {REVIEW_OUT.relative_to(ROOT)}")


def review(
    oid: str,
    spec: dict,
    picture: Image.Image,
    frame: dict,
    tile: int,
    report: dict,
    covered: float,
    palette: pixelkit.Palette,
    frames: int = 1,
) -> None:
    """The picture on the town's grass at 2x, its footprint marked, beside a person (the player's start look) on
    the cell in front of its door or to its right; above it, the blockout and every candidate with its score."""
    grass = palette.shade("grass", 1)
    cols = math.ceil(frame["width"]) + 3
    rows = math.ceil(frame["height"]) + 3
    ground = Image.new("RGBA", (cols * tile, rows * tile), (*grass, 255))
    draw = ImageDraw.Draw(ground)
    for c in range(cols + 1):
        draw.line([(c * tile, 0), (c * tile, rows * tile)], fill=(*[max(0, v - 18) for v in grass], 255))
    for r in range(rows + 1):
        draw.line([(0, r * tile), (cols * tile, r * tile)], fill=(*[max(0, v - 18) for v in grass], 255))
    left = 1 + math.ceil(frame["pad"])
    base_row = rows - 2
    width, footprint_rows = spec["footprint"]
    box = [left * tile, (base_row - footprint_rows) * tile, (left + width) * tile, base_row * tile]
    draw.rectangle(box, outline=(255, 236, 140, 255), width=2)
    x = round((left - frame["pad"]) * tile)
    # A two-frame sheet (a lamp): the last frame stands on the footprint, the first (unlit) in the cell to its left.
    drawn = picture.crop((picture.width // frames * (frames - 1), 0, picture.width, picture.height))
    ground.alpha_composite(drawn, (x, base_row * tile - picture.height))
    if frames > 1 and x >= drawn.width:
        ground.alpha_composite(picture.crop((0, 0, drawn.width, picture.height)), (x - drawn.width, base_row * tile - picture.height))
    cast = PERSON.parent / "cast.json"
    if PERSON.exists() and cast.exists():
        layout = json.loads(cast.read_text())
        frame_w, frame_h = layout["frame"]
        person = Image.open(PERSON).convert("RGBA").crop((0, 0, frame_w, frame_h))
        door = spec.get("door")
        column = left + door if isinstance(door, int) else left + width
        row = base_row + 1 if isinstance(door, int) else base_row
        feet = row * tile - 1
        ground.alpha_composite(person, (column * tile + tile // 2 - frame_w // 2, feet - int(layout["ground"])))
    big = ground.resize((ground.width * 2, ground.height * 2), Image.Resampling.NEAREST)
    strip = review_strip(report, big.width)
    canvas = Image.new("RGBA", (big.width, big.height + strip.height + 24), (40, 34, 48, 255))
    canvas.alpha_composite(strip, (0, 0))
    canvas.alpha_composite(big, (0, strip.height))
    size = f"{drawn.width} x {drawn.height} px" + (f", {frames} frames" if frames > 1 else "")
    label = f"{oid}: {spec['kind']}, footprint {width} x {footprint_rows}, {size}, base covered {covered:.0%}"
    ImageDraw.Draw(canvas).text((6, canvas.height - 18), label, fill=(240, 232, 220, 255))
    REVIEW_OUT.mkdir(parents=True, exist_ok=True)
    canvas.save(REVIEW_OUT / f"{oid}.png")


def review_strip(report: dict, width: int) -> Image.Image:
    if not report:
        return Image.new("RGBA", (width, 0))
    tiles = [("blockout", report["blockout"])] + [
        (f"{i}: iou {score}{' (kept)' if i == report['pick'] else ''}", raw)
        for i, (raw, score) in enumerate(zip(report["candidates"], report["iou"], strict=True))
    ]
    height = 260
    out = Image.new("RGBA", (width, height + 20), (40, 34, 48, 255))
    x = 6
    for label, raw in tiles:
        image = Image.fromarray(np.round(np.clip(raw, 0, 1) * 255).astype(np.uint8), "RGBA")
        scale = height / image.height
        image = image.resize((max(1, round(image.width * scale)), height), Image.Resampling.LANCZOS)
        backed = Image.new("RGBA", image.size, (255, 255, 255, 255))
        backed.alpha_composite(image)
        if x + backed.width > width:
            break
        out.alpha_composite(backed, (x, 0))
        ImageDraw.Draw(out).text((x + 2, height + 4), label, fill=(240, 232, 220, 255))
        x += backed.width + 8
    return out


def stage_new(oid: str, kind: str, footprint: str, what: str, style: dict) -> None:
    """A spec to start from, with the kind's fields at their defaults and a comment on each."""
    path = OBJECTS / f"{oid}.jsonc"
    if path.exists():
        sys.exit(f"{path.relative_to(ROOT)} exists: edit it instead")
    if not ID.match(oid):
        sys.exit("the id must be lowercase letters, digits, dashes and underscores, starting with a letter")
    if kind not in KINDS:
        sys.exit(f"--kind must be one of {', '.join(KINDS)}")
    match = re.fullmatch(r"(\d+)x(\d+)", footprint)
    if not match:
        sys.exit("--footprint is WIDTHxHEIGHT in tiles, e.g. 5x5")
    width, rows = int(match[1]), int(match[2])
    defaults = style["kinds"][kind]
    lines = [
        f"// {what} (pipeline/world/README.md). Sizes are in tiles; make it with scripts/world.sh make --only {oid}.",
        "{",
        f' "id": "{oid}",',
        f' "kind": "{kind}",',
        f' "what": {json.dumps(what)},',
        " // As the map's \"size\": [width, height] in tiles. A building's picture fills it exactly.",
        f' "footprint": [{width}, {rows}],',
        " // Each role's colour, a ramp of pipeline/pixel/palette.json.",
        f' "ramps": {json.dumps(defaults["roles"])},',
    ]
    if kind == "building":
        door = width // 2
        lines += [
            " // Wall height in tiles: a person is 2 tiles tall, so 2.4 gives a door they fit through.",
            f' "walls": {defaults["fields"]["walls"]},',
            ' // "gable", "hip" or "flat".',
            ' "roof": "gable",',
            " // The door's column from the left (the map's door), and the window columns.",
            f' "door": {door},',
            f' "windows": {json.dumps([c for c in (1, width - 2) if c != door and 0 <= c < width])},',
        ]
    elif kind == "tree":
        lines += [
            ' "trunk": 1.0,',
            ' // The leaves\' [width, height] in tiles; "round" or "pine".',
            ' "canopy": [2.0, 2.0],',
            ' "shape": "round",',
        ]
    else:
        lines += [
            " // Shapes in tiles from the footprint's front-left corner: x right, y back, z up. box, cylinder, ball,",
            ' // cone, gable or hip (a roof with its ridge along x). "ramp" is a role above or a palette ramp.',
            f' "parts": [{example_part()}],',
        ]
    lines[-1] = lines[-1].rstrip(",")
    lines.append("}")
    OBJECTS.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")
    print(f"wrote {path.relative_to(ROOT)}: edit it, then scripts/world.sh check --only {oid}")


def stage_adopt(render: str, oid: str) -> None:
    """A spec that re-cuts an existing ComfyUI render (pipeline/pixel/manifest.json) at this world's scale, with the
    footprint the maps give it and the ramps the old asset was locked to."""
    manifest = json.loads((ROOT / "pipeline" / "pixel" / "manifest.json").read_text())
    asset = next((a for a in manifest["assets"] if a["id"] == render), None)
    if asset is None:
        sys.exit(f"{render} is not in pipeline/pixel/manifest.json")
    placed = placements().get(oid, [])
    old_tile = int(load_scale()["old_tile"])
    old_w, old_h = asset["post"]["size"]
    footprint = (
        placed[0].get("size", [1, 1]) if placed else [max(1, round(old_w / old_tile)), max(1, round(old_h / old_tile))]
    )
    pad = max(0.0, half_up((old_w / old_tile - footprint[0]) / 2))
    above = max(0.0, half_up(old_h / old_tile - footprint[1]))
    kind = (
        "building"
        if "building" in render
        else "landmark"
        if "landmark" in render
        else "tree"
        if "tree" in render
        else "prop"
    )
    source: dict = {"picture": asset.get("raw_from", render), "pick": int(asset.get("pick", 0))}
    approved = asset.get("approved_imagegen_candidate") or {}
    if asset.get("source") or approved.get("source"):
        source = {"image": approved.get("source") or asset["source"]}
    # An asset locked to the whole palette is locked to every world ramp (four shades), not the characters' skin and
    # hair.
    named = asset["post"].get("lock_ramps") or world_ramps(pixelkit.Palette.load())
    ramps = {ramp: ramp for ramp in named}
    spec = {
        "id": oid,
        "kind": kind,
        "what": asset.get("prompt", oid).split(",")[0][:150],
        "footprint": footprint,
        "pad": pad,
        "above": above,
        "ramps": ramps,
        "source": source,
    }
    path = OBJECTS / f"{oid}.jsonc"
    OBJECTS.mkdir(parents=True, exist_ok=True)
    header = f"// Adopted from {render} (pipeline/pixel/manifest.json): its render re-cut at this world's scale.\n"
    path.write_text(header + json.dumps(spec, indent=1) + "\n")
    print(f"wrote {path.relative_to(ROOT)}: footprint {footprint}, pad {pad:g}, above {above:g}")


def world_ramps(palette: pixelkit.Palette) -> list[str]:
    """The ramps the town's things are painted from: the four-shade ones (skin, hair and eyes have three)."""
    return [name for name, shades in palette.ramps.items() if len(shades) == 4]


def stage_check(specs: dict, style: dict) -> None:
    """Every spec is fine (load_specs stopped otherwise); report pictures missing or made from an older spec."""
    index_path = GAME_OUT / "world.json"
    index = json.loads(index_path.read_text()) if index_path.exists() else {}
    stale = [oid for oid, spec in specs.items() if index.get(oid, {}).get("made_from") != digest(spec, style)]
    for oid in specs:
        frame = frame_of(specs[oid], style)
        state = "stale or not made" if oid in stale else "made"
        print(f"  {oid}: {specs[oid]['kind']}, {frame['width']:g} x {frame['height']:g} tiles, {state}")
    if stale:
        print(f"not made from the current spec: {', '.join(stale)} (scripts/world.sh make --only {','.join(stale)})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("stage", choices=["new", "adopt", "check", "blockout", "restyle", "cut"])
    parser.add_argument("name", nargs="?", help="new: the id; adopt: the render id")
    parser.add_argument("--only", help="comma-separated ids")
    parser.add_argument("--force", action="store_true", help="render again even when a cached render matches")
    parser.add_argument("--kind", default="prop")
    parser.add_argument("--footprint", default="1x1")
    parser.add_argument("--what", default="")
    parser.add_argument("--as", dest="as_id")
    args = parser.parse_args()
    style = load_style()
    if args.stage == "new":
        if not args.name or not args.what:
            sys.exit('usage: world.py new <id> --kind building --footprint 5x5 --what "a cosy cottage"')
        stage_new(args.name, args.kind, args.footprint, args.what, style)
        return
    if args.stage == "adopt":
        if not args.name or not args.as_id:
            sys.exit("usage: world.py adopt <render id> --as <id>")
        stage_adopt(args.name, args.as_id)
        return
    palette = pixelkit.Palette.load()
    specs = load_specs(args.only, palette, style)
    if args.stage == "check":
        stage_check(specs, style)
    elif args.stage == "blockout":
        stage_blockout(specs, palette, style, args.force)
    elif args.stage == "restyle":
        stage_restyle(specs, style, args.force)
    else:
        stage_cut(specs, palette, style)


if __name__ == "__main__":
    main()
