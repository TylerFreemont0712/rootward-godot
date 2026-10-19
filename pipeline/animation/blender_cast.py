"""Lanternroot's cast as Blender blockouts, for ComfyUI to restyle (cast.py, ADR-0063).

  blender --background --factory-startup --python pipeline/animation/blender_cast.py -- --spec spec.json

cast.py writes the spec: a character's parts (outfit, hair, hat, face, item, named as the game's looks name them), the
hex colour of every slot, the camera, the views and where to write them. This script builds the figure once and renders
each view to <out_dir>/<view>.png (and the model to `blend`, when the spec names one).

Every character stands on the same body (legs, arms, head, face), so proportions match across the cast and across the
views; a part only adds shapes on top. The shapes are blockouts, not finished models: they set the silhouette and the
colours, and ComfyUI draws the detail. A part with no blockout here is an error, not a silent gap.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections.abc import Callable
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import blender_base as base  # noqa: E402 (lathe, ellipsoid, cylinder, box, material, set_up_scene)

Obj = bpy.types.Object
SIDES = (("l", -1.0), ("r", 1.0))
# Metal is a little glossy; everything else is matte cloth, skin and hair.
ROUGHNESS = {"metal": 0.4, "glass": 0.3}


class Kit:
    """The materials by slot and the segment count that every part is built with."""

    def __init__(self, colours: dict[str, str], segments: int) -> None:
        self.mats = {
            slot: base.material(slot, hex_colour, ROUGHNESS.get(slot, 0.8)) for slot, hex_colour in colours.items()
        }
        self.seg = segments

    def __getitem__(self, slot: str) -> bpy.types.Material:
        return self.mats[slot]


def ell(
    kit: Kit,
    name: str,
    radius: float,
    slot: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> Obj:
    return base.ellipsoid(name, radius, kit[slot], location, scale, kit.seg, rotation)


def cyl(kit: Kit, name: str, radius: float, z0: float, z1: float, slot: str, at: tuple[float, float]) -> Obj:
    return base.cylinder(name, radius, z0, z1, kit[slot], (at[0], at[1], 0.0), kit.seg)


def turned(
    kit: Kit,
    name: str,
    profile: list[tuple[float, float]],
    slot: str,
    location: tuple[float, float, float] = (0.0, 0.0, 0.0),
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> Obj:
    return base.lathe(name, profile, kit.seg, kit[slot], location, scale, rotation)


def band(kit: Kit, name: str, radius: float, z0: float, z1: float, slot: str, depth: float = 0.8) -> Obj:
    """A ring around the body (a belt, a hem, a collar): an open tube, flattened front to back like the clothes."""
    profile = [(radius - 0.02, z0), (radius, z0), (radius, z1), (radius - 0.02, z1)]
    return turned(kit, name, profile, slot, scale=(1.0, depth, 1.0))


def dome(
    kit: Kit,
    name: str,
    radius: float,
    slot: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
) -> Obj:
    """The upper half of an ellipsoid with a flat bottom: a helmet that leaves the face below it open."""
    upper = [(r, z) for z, r in base.ellipsoid_profile(radius, max(4, kit.seg // 2)) if z >= -1e-9]
    return turned(kit, name, [(0.0, 0.0), *upper], slot, location, scale)


def pointing(direction: tuple[float, float, float]) -> tuple[float, float, float]:
    """The rotation that turns a part's +Z (a cone's tip) to `direction`."""
    euler = Vector(direction).normalized().to_track_quat("Z", "Y").to_euler()
    return (euler.x, euler.y, euler.z)


# ---------------------------------------------------------------------------------------------------------------------
# The body every character shares


def body(kit: Kit, legs: str, boots: str) -> list[Obj]:
    """Legs (in `legs`, or none under a long skirt), boots, bare arms and hands, the head and the face. The figure faces
    -Y, toward the camera."""
    parts = []
    for side, s in SIDES:
        x = 0.18 * s
        if legs:
            parts.append(cyl(kit, f"leg_{side}", 0.075, 0.36, 0.74, legs, (x, 0.0)))
        parts.append(cyl(kit, f"boot_{side}", 0.12, 0.0, 0.42, boots, (x, 0.0)))
        parts.append(ell(kit, f"foot_{side}", 0.15, boots, (x, -0.06, 0.1), (1.0, 1.5, 0.7)))
        parts.append(cyl(kit, f"arm_{side}", 0.07, 0.8, 1.2, "skin", (0.41 * s, 0.0)))
        parts.append(ell(kit, f"hand_{side}", 0.085, "skin", (0.43 * s, -0.01, 0.76), (1.0, 1.0, 1.1)))
        parts.append(ell(kit, f"eye_{side}", 0.075, "eyes", (0.165 * s, -0.42, 1.88), (0.85, 0.45, 1.15)))
        parts.append(ell(kit, f"eye_shine_{side}", 0.03, "shine", (0.165 * s + 0.03, -0.45, 1.93), (1.0, 0.5, 1.0)))
        parts.append(ell(kit, f"blush_{side}", 0.06, "blush", (0.28 * s, -0.4, 1.75), (1.0, 0.3, 0.6)))
    parts.append(cyl(kit, "neck", 0.12, 1.4, 1.62, "skin", (0.0, 0.0)))
    parts.append(ell(kit, "head", 0.45, "skin", (0.0, 0.0, 1.9), (1.0, 0.98, 1.05)))
    parts.append(ell(kit, "mouth", 0.03, "ink", (0.0, -0.43, 1.74), (1.6, 0.4, 0.5)))
    return parts


# ---------------------------------------------------------------------------------------------------------------------
# Outfits: main is the cloth, second the trim or the shirt beneath, accent the belt, sash or buttons


def _bell(lower: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """A garment's profile from the hem to the neck: its own lower part, then the chest and shoulders all clothes share."""
    return [*lower, (0.31, 1.1), (0.33, 1.28), (0.28, 1.44), (0.2, 1.5)]


def _short_sleeves(kit: Kit, slot: str) -> list[Obj]:
    return [ell(kit, f"sleeve_{side}", 0.135, slot, (0.37 * s, 0.0, 1.2), (1.0, 1.0, 0.9)) for side, s in SIDES]


def _long_sleeves(kit: Kit, slot: str) -> list[Obj]:
    parts = []
    for side, s in SIDES:
        parts.append(ell(kit, f"shoulder_{side}", 0.13, slot, (0.37 * s, 0.0, 1.2), (1.0, 1.0, 0.9)))
        parts.append(cyl(kit, f"sleeve_{side}", 0.09, 0.84, 1.2, slot, (0.41 * s, 0.0)))
    return parts


def tunic(kit: Kit) -> list[Obj]:
    return [
        turned(
            kit, "tunic", _bell([(0.34, 0.44), (0.37, 0.56), (0.31, 0.86), (0.29, 0.96)]), "main", scale=(1, 0.78, 1)
        ),
        band(kit, "hem", 0.385, 0.44, 0.5, "second", 0.78),
        band(kit, "collar", 0.29, 1.4, 1.48, "second", 0.85),
        band(kit, "sash", 0.335, 0.9, 0.98, "accent"),
        base.box("sash_strap", kit["accent"], (0.01, -0.265, 1.17), (0.07, 0.025, 0.33), rotation_y=math.radians(140)),
        *_short_sleeves(kit, "main"),
    ]


def dress(kit: Kit) -> list[Obj]:
    return [
        turned(kit, "dress", _bell([(0.42, 0.1), (0.41, 0.3), (0.35, 0.66), (0.29, 0.96)]), "main", scale=(1, 0.8, 1)),
        ell(kit, "apron", 1.0, "second", (0.0, -0.27, 0.6), (0.2, 0.08, 0.38)),
        band(kit, "collar", 0.29, 1.4, 1.48, "second", 0.85),
        band(kit, "waist", 0.32, 0.92, 0.99, "accent"),
        *_long_sleeves(kit, "main"),
    ]


def robe(kit: Kit) -> list[Obj]:
    parts = [
        turned(kit, "robe", _bell([(0.44, 0.06), (0.43, 0.3), (0.36, 0.7), (0.31, 0.96)]), "main", scale=(1, 0.82, 1)),
        band(kit, "hem", 0.455, 0.06, 0.16, "second", 0.82),
        band(kit, "collar", 0.29, 1.4, 1.48, "second", 0.85),
        band(kit, "sash", 0.34, 0.9, 0.98, "accent"),
    ]
    for side, s in SIDES:
        sleeve = [(0.1, 1.24), (0.12, 1.12), (0.17, 0.88), (0.18, 0.8)]
        cuff = [(0.17, 0.8), (0.19, 0.8), (0.19, 0.86), (0.175, 0.86)]
        parts.append(ell(kit, f"shoulder_{side}", 0.14, "main", (0.37 * s, 0.0, 1.2), (1.0, 1.0, 0.9)))
        parts.append(turned(kit, f"sleeve_{side}", sleeve, "main", (0.42 * s, 0.0, 0.0)))
        parts.append(turned(kit, f"cuff_{side}", cuff, "second", (0.42 * s, 0.0, 0.0)))
    return parts


def coat(kit: Kit) -> list[Obj]:
    parts = [
        turned(kit, "coat", _bell([(0.37, 0.4), (0.36, 0.52), (0.32, 0.86), (0.3, 0.96)]), "main", scale=(1, 0.8, 1)),
        ell(kit, "shirt", 1.0, "second", (0.0, -0.235, 1.18), (0.1, 0.06, 0.24)),
        turned(kit, "collar", [(0.25, 1.36), (0.32, 1.4), (0.32, 1.5), (0.24, 1.56)], "second", scale=(1, 0.85, 1)),
        band(kit, "belt", 0.325, 0.92, 0.98, "accent"),
        *_long_sleeves(kit, "main"),
    ]
    for i, (z, y) in enumerate(((0.84, -0.27), (0.7, -0.285), (0.56, -0.3))):
        parts.append(ell(kit, f"button_{i}", 0.03, "accent", (0.07, y, z), (1.0, 0.6, 1.0)))
    return parts


def vest(kit: Kit) -> list[Obj]:
    return [
        turned(kit, "shirt", _bell([(0.3, 0.7), (0.31, 0.86), (0.29, 0.96)]), "second", scale=(1, 0.78, 1)),
        turned(kit, "vest", [(0.315, 0.82), (0.33, 1.0), (0.345, 1.28), (0.3, 1.42)], "main", scale=(1, 0.8, 1)),
        ell(kit, "shirt_front", 1.0, "second", (0.0, -0.265, 1.12), (0.07, 0.04, 0.26)),
        band(kit, "belt", 0.325, 0.76, 0.84, "accent"),
        turned(
            kit,
            "trousers",
            [(0.0, 0.62), (0.3, 0.62), (0.31, 0.72), (0.3, 0.8), (0.0, 0.8)],
            "accent",
            scale=(1, 0.8, 1),
        ),
        *_long_sleeves(kit, "second"),
    ]


def armor(kit: Kit) -> list[Obj]:
    parts = [
        turned(kit, "armor", _bell([(0.33, 0.72), (0.345, 0.86), (0.33, 0.96)]), "main", scale=(1, 0.82, 1)),
        turned(kit, "tassets", [(0.38, 0.44), (0.36, 0.56), (0.33, 0.74)], "main", scale=(1, 0.82, 1)),
        band(kit, "belt", 0.34, 0.74, 0.82, "accent", 0.82),
        ell(kit, "emblem", 0.08, "accent", (0.0, -0.285, 1.16), (1.0, 0.3, 1.2)),
    ]
    for side, s in SIDES:
        parts.append(ell(kit, f"pauldron_{side}", 0.17, "metal", (0.36 * s, 0.0, 1.27), (1.0, 1.0, 0.8)))
        parts.append(cyl(kit, f"vambrace_{side}", 0.085, 0.82, 1.02, "metal", (0.41 * s, 0.0)))
    return parts


# Each outfit and what shows below it: the legs' slot ("" under a long skirt) and the boots' slot.
def undersuit(kit: Kit) -> list[Obj]:
    """The plain fitted top and shorts under the cast outfits give every complete figure a consistent base."""
    return [
        turned(kit, "undersuit", _bell([(0.3, 0.6), (0.31, 0.74), (0.29, 0.9)]), "second", scale=(1, 0.78, 1)),
        *[ell(kit, f"undersleeve_{side}", 0.12, "second", (0.37 * s, 0.0, 1.22), (1.0, 1.0, 0.8)) for side, s in SIDES],
    ]


OUTFITS: dict[str, tuple[Callable[[Kit], list[Obj]], str, str]] = {
    "outfit/undersuit": (undersuit, "skin", "boot"),
    "outfit/tunic": (tunic, "skin", "boot"),
    "outfit/dress": (dress, "", "boot"),
    "outfit/robe": (robe, "", "boot"),
    "outfit/coat": (coat, "accent", "boot"),
    "outfit/vest": (vest, "accent", "boot"),
    "outfit/armor": (armor, "metal", "metal"),
}


# ---------------------------------------------------------------------------------------------------------------------
# Hair, in the hair slot. Under a hat that covers the crown the cap and fringe are left out, so nothing pokes through.
# Every style keeps the nape: the back of the head down to the neck, under a hat too.


def _crown(kit: Kit, covered: bool, size: float = 1.0) -> list[Obj]:
    if covered:
        return [_nape(kit)]
    return [
        ell(kit, "hair_cap", 0.46 * size, "hair", (0.0, 0.05, 2.02), (1.05, 1.0, 0.92)),
        ell(kit, "hair_bangs", 0.3 * size, "hair", (0.0, -0.36, 2.12), (1.0, 0.42, 0.24)),
        _nape(kit),
    ]


def _nape(kit: Kit) -> Obj:
    """The hair over the back of the head. LEARN: the cap alone covers only the crown, so a back view showed a big oval of
    bare skin, and the restyle drew a face or a bald head there. This sits behind the face (its front is inside the head),
    so the front view does not change."""
    return ell(kit, "hair_nape", 0.42, "hair", (0.0, 0.12, 1.8), (1.06, 0.9, 0.86))


def _short_sides(kit: Kit) -> list[Obj]:
    return [ell(kit, f"hair_side_{side}", 0.16, "hair", (0.43 * s, 0.02, 1.86), (0.5, 0.8, 0.95)) for side, s in SIDES]


def hair_short(kit: Kit, covered: bool) -> list[Obj]:
    return [*_crown(kit, covered), *_short_sides(kit)]


def hair_bun(kit: Kit, covered: bool) -> list[Obj]:
    bun = [] if covered else [ell(kit, "hair_bun", 0.19, "hair", (0.0, 0.3, 2.3))]
    return [*_crown(kit, covered), *_short_sides(kit), *bun]


def hair_fluffy(kit: Kit, covered: bool) -> list[Obj]:
    parts = [*_crown(kit, covered, 1.1), *_short_sides(kit)]
    if not covered:
        for i in range(6):
            angle = 2 * math.pi * i / 6
            at = (0.47 * math.cos(angle), 0.05 + 0.45 * math.sin(angle), 2.12)
            parts.append(ell(kit, f"hair_tuft_{i}", 0.15, "hair", at))
    return parts


def hair_long(kit: Kit, covered: bool) -> list[Obj]:
    return [
        *_crown(kit, covered),
        ell(kit, "hair_back", 0.4, "hair", (0.0, 0.22, 1.55), (1.1, 0.5, 1.6)),
        *[ell(kit, f"hair_side_{side}", 0.18, "hair", (0.44 * s, 0.0, 1.6), (0.5, 0.7, 2.0)) for side, s in SIDES],
    ]


def hair_braid(kit: Kit, covered: bool) -> list[Obj]:
    parts = [*_crown(kit, covered), *_short_sides(kit)]
    for i in range(6):
        t = i / 5
        parts.append(ell(kit, f"hair_braid_{i}", 0.085, "hair", (0.3 - 0.02 * t, -0.05 - 0.2 * t, 1.66 - 0.6 * t)))
    parts.append(ell(kit, "hair_tie", 0.06, "accent", (0.28, -0.26, 0.98)))
    return parts


def hair_spiky(kit: Kit, covered: bool) -> list[Obj]:
    """Short tufts all round the crown, leaning outward. LEARN: tall cones read as antennae from the side and as one
    lone spike from behind, so every view's restyle drew a different top; short, wide tufts spread evenly round the head
    look alike from every side."""
    parts = [*_crown(kit, covered), *_short_sides(kit)]
    if covered:
        return parts
    for i in range(10):
        angle = 2 * math.pi * (i + 0.5) / 10
        direction = (math.cos(angle) * 0.8, math.sin(angle) * 0.8, 0.75)
        unit = Vector(direction).normalized()
        at = Vector((0.0, 0.05, 2.0)) + unit * 0.4
        cone = [(0.0, 0.0), (0.15, 0.0), (0.0, 0.2)]
        parts.append(turned(kit, f"hair_spike_{i}", cone, "hair", tuple(at), rotation=pointing(direction)))
    return parts


HAIRS: dict[str, Callable[[Kit, bool], list[Obj]]] = {
    "": lambda kit, covered: [],
    "hair/short": hair_short,
    "hair/bun": hair_bun,
    "hair/fluffy": hair_fluffy,
    "hair/long": hair_long,
    "hair/braid": hair_braid,
    "hair/spiky": hair_spiky,
}


# ---------------------------------------------------------------------------------------------------------------------
# Hats, and how much of the hair each covers: "top" leaves out the crown and fringe, "all" leaves out every hair


def hat_kettle(kit: Kit) -> list[Obj]:
    return [
        dome(kit, "helm", 0.5, "metal", (0.0, 0.02, 2.02), (1.06, 1.06, 0.9)),
        turned(kit, "helm_brim", [(0.0, 2.0), (0.74, 2.0), (0.74, 2.05), (0.0, 2.05)], "metal"),
    ]


def hat_hood(kit: Kit) -> list[Obj]:
    # Set back from the face, so the face shows in front of it and the hood frames it.
    cape = [(0.47, 1.16), (0.44, 1.3), (0.36, 1.44), (0.22, 1.56)]
    return [
        ell(kit, "hood", 0.56, "main", (0.0, 0.14, 1.98), (1.0, 1.0, 1.08)),
        turned(kit, "hood_cape", cape, "main", scale=(1.0, 0.85, 1.0)),
    ]


def hat_leaves(kit: Kit) -> list[Obj]:
    parts = []
    for i in range(7):
        angle = 2 * math.pi * i / 7
        at = (0.44 * math.cos(angle), 0.05 + 0.44 * math.sin(angle), 2.24)
        parts.append(ell(kit, f"leaf_{i}", 0.12, "leaf", at, (1.0, 0.45, 0.6), (0.0, 0.0, angle)))
    for side, s in SIDES:
        parts.append(
            ell(kit, f"sprig_{side}", 0.13, "leaf", (0.24 * s, -0.12, 2.46), (0.45, 0.4, 1.0), (0.0, 0.4 * s, 0.0))
        )
    return parts


def hat_goggles(kit: Kit) -> list[Obj]:
    parts = [
        turned(kit, "goggle_band", [(0.48, 2.1), (0.5, 2.1), (0.5, 2.18), (0.48, 2.18)], "second", (0.0, 0.04, 0.0))
    ]
    lens = [(0.0, -0.05), (0.1, -0.05), (0.1, 0.05), (0.0, 0.05)]
    glass = [(0.0, -0.06), (0.07, -0.06), (0.07, 0.06), (0.0, 0.06)]
    for side, s in SIDES:
        facing = (math.pi / 2, 0.0, 0.0)
        parts.append(turned(kit, f"goggle_{side}", lens, "metal", (0.15 * s, -0.5, 2.2), rotation=facing))
        parts.append(turned(kit, f"goggle_glass_{side}", glass, "glass", (0.15 * s, -0.51, 2.2), rotation=facing))
    return parts


def hat_wide(kit: Kit) -> list[Obj]:
    at = (0.0, 0.03, 0.0)
    return [
        turned(kit, "hat_brim", [(0.0, 2.12), (0.82, 2.12), (0.82, 2.17), (0.0, 2.17)], "accent", at),
        turned(kit, "hat_crown", [(0.0, 2.15), (0.37, 2.15), (0.36, 2.44), (0.3, 2.52), (0.0, 2.53)], "accent", at),
        turned(kit, "hat_band", [(0.37, 2.17), (0.38, 2.17), (0.38, 2.24), (0.37, 2.24)], "second", at),
    ]


def hat_visor(kit: Kit) -> list[Obj]:
    return [
        ell(kit, "helmet", 0.5, "metal", (0.0, 0.0, 1.95), (1.04, 1.04, 1.06)),
        base.box("visor", kit["accent"], (0.0, -0.53, 1.9), (0.44, 0.05, 0.07)),
        ell(kit, "crest", 0.09, "metal", (0.0, 0.02, 2.48), (0.5, 1.8, 0.8)),
    ]


HATS: dict[str, tuple[Callable[[Kit], list[Obj]], str]] = {
    "": (lambda kit: [], ""),
    "hat/kettle": (hat_kettle, "top"),
    "hat/hood": (hat_hood, ""),
    "hat/leaves": (hat_leaves, ""),
    "hat/goggles": (hat_goggles, ""),
    "hat/wide": (hat_wide, "top"),
    "hat/visor": (hat_visor, "all"),
}


# ---------------------------------------------------------------------------------------------------------------------
# Faces and items


def face_glasses(kit: Kit) -> list[Obj]:
    ring = [(0.07, -0.012), (0.09, -0.012), (0.09, 0.012), (0.07, 0.012)]
    parts = [
        turned(kit, f"glasses_{side}", ring, "ink", (0.165 * s, -0.47, 1.88), rotation=(math.pi / 2, 0.0, 0.0))
        for side, s in SIDES
    ]
    parts.append(base.box("glasses_bridge", kit["ink"], (0.0, -0.47, 1.9), (0.12, 0.015, 0.015)))
    return parts


def face_beard(kit: Kit) -> list[Obj]:
    return [
        ell(kit, "beard", 0.32, "hair", (0.0, -0.2, 1.6), (1.05, 0.78, 0.85)),
        ell(kit, "moustache", 0.12, "hair", (0.0, -0.44, 1.77), (1.5, 0.35, 0.35)),
    ]


def face_mask(kit: Kit) -> list[Obj]:
    return [
        ell(kit, "mask", 0.42, "second", (0.0, -0.08, 1.68), (1.02, 0.88, 0.48)),
        base.box("mask_glow", kit["accent"], (0.0, -0.46, 1.66), (0.3, 0.02, 0.02)),
    ]


FACES: dict[str, Callable[[Kit], list[Obj]]] = {
    "": lambda kit: [],
    "face/glasses": face_glasses,
    "face/beard": face_beard,
    "face/mask": face_mask,
}


def item_lantern(kit: Kit) -> list[Obj]:
    at = (0.46, -0.05)
    return [
        cyl(kit, "lantern_glass", 0.09, 0.5, 0.67, "glow", at),
        cyl(kit, "lantern_cap", 0.1, 0.67, 0.71, "metal", at),
        cyl(kit, "lantern_base", 0.1, 0.47, 0.5, "metal", at),
    ]


def item_book(kit: Kit) -> list[Obj]:
    """A thick book held against the hip, its cover facing out and reaching past the body's side, so it changes the
    outline: a restyle that leaves it out scores lower and is not kept. Its cover is a fixed teal, apart from any robe."""
    return [
        base.box("book", kit["cover"], (0.42, -0.31, 0.88), (0.34, 0.12, 0.42)),
        base.box("book_pages", kit["page"], (0.45, -0.31, 0.88), (0.32, 0.08, 0.38)),
        ell(kit, "book_hand", 0.09, "skin", (0.4, -0.38, 0.72), (1.0, 0.9, 1.0)),
    ]


def item_staff(kit: Kit) -> list[Obj]:
    """A tall staff gripped in the hand: the shaft runs through a fist at the hand, so it never floats beside it. Pale
    wood, so it stands apart from a brown or black robe."""
    at = (0.45, -0.06)
    return [
        cyl(kit, "staff", 0.045, 0.0, 2.36, "staff", at),
        ell(kit, "staff_fist", 0.1, "skin", (at[0], at[1], 0.82), (1.1, 1.1, 1.2)),
        ell(kit, "staff_top", 0.11, "accent", (at[0], at[1], 2.42)),
    ]


ITEMS: dict[str, Callable[[Kit], list[Obj]]] = {
    "": lambda kit: [],
    "item/lantern": item_lantern,
    "item/book": item_book,
    "item/staff": item_staff,
}


# ---------------------------------------------------------------------------------------------------------------------


def blockout(parts: dict[str, str], kit: Kit) -> list[Obj]:
    """Every object of one character, from its parts. An unknown part is an error naming the part."""
    for slot, table in (("outfit", OUTFITS), ("hair", HAIRS), ("hat", HATS), ("face", FACES), ("item", ITEMS)):
        if parts.get(slot, "") not in table:
            raise KeyError(f"no blockout for {slot} {parts.get(slot)!r}: add one to pipeline/animation/blender_cast.py")
    build_outfit, legs, boots = OUTFITS[parts["outfit"]]
    build_hat, covers = HATS[parts.get("hat", "")]
    figure = body(kit, legs, boots)
    anatomy: dict[str, list[Obj]] = {key: [] for key in ("head", "torso", "arms", "legs", "face_base")}
    for obj in figure:
        if obj.name.startswith(("leg_", "boot_", "foot_")):
            anatomy["legs"].append(obj)
        elif obj.name.startswith(("arm_", "hand_")):
            anatomy["arms"].append(obj)
        elif obj.name.startswith(("eye_", "eye_shine_", "blush_")) or obj.name == "mouth":
            anatomy["face_base"].append(obj)
        else:
            anatomy["head"].append(obj)
    # Trousers and armoured boots come with the outfit, so in a player's layers they are the outfit's; the undersuit
    # is the body's own.
    worn = [
        o
        for o in figure
        if (o.name.startswith("leg_") and legs != "skin") or (o.name.startswith(("boot_", "foot_")) and boots != "boot")
    ]
    outfit = build_outfit(kit)
    if parts["outfit"] == "outfit/undersuit":
        for obj in outfit:
            anatomy["arms" if obj.name.startswith("undersleeve_") else "torso"].append(obj)
    layers = [
        ("legs", [o for o in anatomy["legs"] if o not in worn]),
        ("torso", anatomy["torso"]),
        ("outfit", worn + ([] if parts["outfit"] == "outfit/undersuit" else outfit)),
        ("arms", anatomy["arms"]),
        ("head", anatomy["head"]),
        ("face_base", anatomy["face_base"]),
        ("hat", build_hat(kit)),
    ]
    if covers != "all":
        layers.append(("hair", HAIRS[parts.get("hair", "")](kit, covers == "top")))
    layers += [("face", FACES[parts.get("face", "")](kit)), ("item", ITEMS[parts.get("item", "")](kit))]
    objects = []
    for layer, made in layers:
        for obj in made:
            # Keep each cast component named for the blockout's optional diagnostic masks.
            obj["layer"] = layer
        objects += made
    return objects


def holdout_material() -> bpy.types.Material:
    """A material that cuts a hole in the picture: what is behind it does not show, and it shows nothing itself."""
    mat = bpy.data.materials.new("holdout")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    hole = nodes.new("ShaderNodeHoldout")
    mat.node_tree.links.new(hole.outputs[0], output.inputs["Surface"])
    return mat


def render_masks(objects: list[Obj], layers: list[str], out_dir: Path, view: str) -> None:
    """For each layer, a picture whose alpha is where that layer shows in this view: every other object is a holdout,
    so it still hides what is behind it. LEARN: rendering the layer alone would show hair that the body hides; the
    holdout keeps the figure's own occlusion, so a layer cut by this mask is exactly what the full render drew of it."""
    scene = bpy.context.scene
    samples, denoise = scene.cycles.samples, scene.cycles.use_denoising
    scene.cycles.samples, scene.cycles.use_denoising = 1, False
    hole = holdout_material()
    originals = {obj.name: [slot.material for slot in obj.material_slots] for obj in objects}
    for layer in layers:
        for obj in objects:
            for i, slot in enumerate(obj.material_slots):
                slot.material = originals[obj.name][i] if obj.get("layer") == layer else hole
        scene.render.filepath = str(out_dir / f"{view}-mask-{layer}.png")
        bpy.ops.render.render(write_still=True)
    for obj in objects:
        for i, slot in enumerate(obj.material_slots):
            slot.material = originals[obj.name][i]
    scene.cycles.samples, scene.cycles.use_denoising = samples, denoise


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--spec", required=True)
    spec = json.loads(Path(parser.parse_args(argv).spec).read_text())

    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit = Kit(spec["colours"], spec["segments"])
    objects = blockout(spec["parts"], kit)
    # Smooth the turned shapes; a box would round into a blob, so the eight-vertex ones stay crisp.
    base.smooth_pass([obj for obj in objects if len(obj.data.vertices) > 8], spec["subsurf"])
    root = bpy.data.objects.new("Figure", None)
    bpy.context.collection.objects.link(root)
    for obj in objects:
        obj.parent = root

    camera = spec["camera"]
    base.set_up_scene(camera["render"][1], spec["samples"], camera["height"], camera["center_z"])
    out_dir = Path(spec["out_dir"])
    out_dir.mkdir(parents=True, exist_ok=True)
    for view, yaw in spec["views"].items():
        root.rotation_euler = (0.0, 0.0, math.radians(yaw))
        bpy.context.scene.render.filepath = str(out_dir / f"{view}.png")
        bpy.ops.render.render(write_still=True)
        print(f"[cast] {spec['id']} {view} -> {out_dir / f'{view}.png'}")
        if spec.get("masks"):
            render_masks(objects, spec["masks"], out_dir, view)
    if spec.get("blend"):
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=spec["blend"])


if __name__ == "__main__":
    main()
