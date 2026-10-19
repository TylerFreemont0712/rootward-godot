"""Lanternroot's base character, built in code in Blender and rendered for the sprite cut (base_sprites.py).

  blender --background --factory-startup --python pipeline/animation/blender_base.py -- \
      --detail standard --out render.png [--blend model.blend]

The figure is the start look (short brown hair, a teal tunic over bare legs, cream trim, an orange sash, brown boots),
built from lathe-turned shapes and primitives. Every part is a named object, so the .blend is an editable model. It
stands facing -Y (the camera), arms and feet apart, so a sprite cut from it keeps its limbs separate for animation.

--detail sets how much is modelled: low (fewer segments, no smoothing pass, no trims, blush or buttons), standard
(trims, blush, a sash knot, hair strands, buttons, one smoothing pass), detailed (more segments, two smoothing passes, and
the fine level: eyebrows, a hair clip, a pocket, boot laces). The render is always 1200 px tall: the sprite cut takes it
down, so the render is never the limit.
"""

from __future__ import annotations

import argparse
import math
import sys

import bmesh
import bpy
from mathutils import Vector

DETAIL = {
    "low": {"segments": 10, "subsurf": 0, "extras": False, "fine": False, "samples": 48},
    "standard": {"segments": 16, "subsurf": 1, "extras": True, "fine": False, "samples": 64},
    "detailed": {"segments": 24, "subsurf": 2, "extras": True, "fine": True, "samples": 96},
}

# The palette's shades (pipeline/pixel/palette.json), the middle one of each ramp, so the palette lock keeps them.
COLOURS = {
    "skin": "#eeab8a",
    "hair": "#7a5038",
    "tunic": "#3ea0a0",
    "tunic_dark": "#2a6872",
    "trim": "#dcc092",
    "sash": "#d97a3c",
    "boot": "#8e5c3c",
    "blush": "#e58aa8",
    "eye": "#35263a",
    "shine": "#fbf7ee",
    "gold": "#e0b448",
    "ink": "#2a1d2b",
}


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--detail", choices=sorted(DETAIL), default="standard")
    parser.add_argument("--out", required=True)
    parser.add_argument("--blend", default=None, help="also save the model here")
    parser.add_argument("--yaw", type=float, default=0.0, help="turn the figure about Z, in degrees")
    return parser.parse_args(argv)


def srgb_to_linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def material(name: str, hex_colour: str, roughness: float = 0.8) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    digits = hex_colour.lstrip("#")
    rgb = [srgb_to_linear(int(digits[i : i + 2], 16) / 255) for i in (0, 2, 4)]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def lathe(
    name: str,
    profile: list[tuple[float, float]],
    segments: int,
    mat: bpy.types.Material,
    location: tuple[float, float, float] = (0.0, 0.0, 0.0),
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    """A solid of revolution about Z. `profile` is (radius, height) pairs from bottom to top; a radius of 0 is a pole,
    so a closed solid starts and ends on one. Without poles the ends stay open (a sleeve, a hem). `rotation` (Euler,
    radians) turns the finished solid, for a spike or a lens that does not stand upright."""
    verts: list[tuple[float, float, float]] = []
    rings: list[list[int]] = []
    for radius, height in profile:
        if radius <= 1e-6:
            verts.append((0.0, 0.0, height))
            rings.append([len(verts) - 1])
            continue
        start = len(verts)
        for k in range(segments):
            angle = 2 * math.pi * k / segments
            verts.append((radius * math.cos(angle), radius * math.sin(angle), height))
        rings.append(list(range(start, start + segments)))

    # LEARN: a closed solid ends in a pole (one vertex, a fan of triangles); an open tube ends in a ring. Both use the
    # same profile list, so the body, skirt and trims share one helper (docs/LEARNING_LOG.md, 2026-10-13).
    faces: list[tuple[int, ...]] = []
    for lower, upper in zip(rings, rings[1:], strict=False):
        if len(lower) == 1 and len(upper) == 1:
            continue
        if len(lower) == 1 or len(upper) == 1:
            pole, ring = (lower[0], upper) if len(lower) == 1 else (upper[0], lower)
            for k in range(segments):
                faces.append((pole, ring[k], ring[(k + 1) % segments]))
            continue
        for k in range(segments):
            k2 = (k + 1) % segments
            faces.append((lower[k], lower[k2], upper[k2], upper[k]))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.scale = scale
    obj.rotation_euler = rotation
    obj.data.materials.append(mat)
    return obj


def ellipsoid_profile(radius: float, steps: int) -> list[tuple[float, float]]:
    """(height, radius) pairs of a sphere centred on the origin, from the bottom pole up to the top pole."""
    angles = [-math.pi / 2 + math.pi * i / steps for i in range(steps + 1)]
    return [(radius * math.sin(a), radius * math.cos(a)) for a in angles]


def ellipsoid(
    name: str,
    radius: float,
    mat: bpy.types.Material,
    location: tuple[float, float, float],
    scale: tuple[float, float, float] = (1.0, 1.0, 1.0),
    segments: int = 16,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    profile = [(r, z) for z, r in ellipsoid_profile(radius, max(4, segments // 2))]
    return lathe(name, profile, segments, mat, location, scale, rotation)


def cylinder(
    name: str,
    radius: float,
    z0: float,
    z1: float,
    mat: bpy.types.Material,
    location: tuple[float, float, float],
    segments: int = 16,
) -> bpy.types.Object:
    return lathe(name, [(0.0, z0), (radius, z0), (radius, z1), (0.0, z1)], segments, mat, location)


def box(
    name: str,
    mat: bpy.types.Material,
    location: tuple[float, float, float],
    size: tuple[float, float, float],
    rotation_y: float = 0.0,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler = (0.0, rotation_y, 0.0)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.materials.append(mat)
    return obj


def build_figure(detail: dict, mats: dict[str, bpy.types.Material]) -> list[bpy.types.Object]:
    seg = detail["segments"]
    extras = detail["extras"]
    parts: list[bpy.types.Object] = []

    # Legs and boots: the feet point to -Y, the way the figure faces.
    for side, x in (("l", -0.18), ("r", 0.18)):
        parts.append(cylinder(f"leg_{side}", 0.075, 0.36, 0.7, mats["skin"], (x, 0.0, 0.0), seg))
        parts.append(cylinder(f"boot_shaft_{side}", 0.12, 0.0, 0.44, mats["boot"], (x, 0.0, 0.0), seg))
        parts.append(ellipsoid(f"boot_foot_{side}", 0.15, mats["boot"], (x, -0.06, 0.1), (1.0, 1.5, 0.7), seg))
        if extras:
            parts.append(cylinder(f"boot_cuff_{side}", 0.13, 0.36, 0.44, mats["trim"], (x, 0.0, 0.0), seg))

    # The tunic: a flared bell, flattened front to back, open at the hem and the neck.
    tunic = [
        (0.34, 0.44),
        (0.37, 0.56),
        (0.31, 0.86),
        (0.29, 0.96),
        (0.31, 1.1),
        (0.33, 1.28),
        (0.28, 1.44),
        (0.2, 1.5),
    ]
    parts.append(lathe("tunic", tunic, seg, mats["tunic"], scale=(1.0, 0.78, 1.0)))
    if extras:
        parts.append(
            lathe(
                "tunic_hem",
                [(0.355, 0.44), (0.385, 0.46), (0.385, 0.5), (0.355, 0.5)],
                seg,
                mats["trim"],
                scale=(1.0, 0.78, 1.0),
            )
        )
        parts.append(
            lathe(
                "collar",
                [(0.27, 1.4), (0.29, 1.43), (0.29, 1.47), (0.27, 1.5)],
                seg,
                mats["trim"],
                scale=(1.0, 0.85, 1.0),
            )
        )
    parts.append(
        lathe(
            "sash_band",
            [(0.305, 0.9), (0.335, 0.9), (0.335, 0.98), (0.305, 0.98)],
            seg,
            mats["sash"],
            scale=(1.0, 0.8, 1.0),
        )
    )
    # The diagonal strap from the left shoulder to the right hip, laid on the tunic's front.
    parts.append(
        box("sash_strap", mats["sash"], (0.01, -0.265, 1.17), (0.07, 0.025, 0.33), rotation_y=math.radians(140))
    )
    if extras:
        parts.append(ellipsoid("sash_knot", 0.07, mats["sash"], (0.22, -0.28, 0.9), (1.0, 0.8, 1.2), seg))

    # Arms, short sleeves and hands, hanging a little away from the body.
    for side, x in (("l", -1.0), ("r", 1.0)):
        ax = 0.41 * x
        parts.append(cylinder(f"arm_{side}", 0.07, 0.8, 1.16, mats["skin"], (ax, 0.0, 0.0), seg))
        parts.append(ellipsoid(f"sleeve_{side}", 0.135, mats["tunic"], (0.37 * x, 0.0, 1.2), (1.0, 1.0, 0.9), seg))
        parts.append(ellipsoid(f"hand_{side}", 0.085, mats["skin"], (ax + 0.02 * x, -0.01, 0.76), (1.0, 1.0, 1.1), seg))

    # Head: an egg, a little wider than deep. Bangs and bob hair sit on it; the face is kept clear.
    parts.append(ellipsoid("head", 0.45, mats["skin"], (0.0, 0.0, 1.9), (1.0, 0.98, 1.05), seg))
    # The hair is a sphere set back and up, so its front edge makes a clean hairline across the forehead.
    parts.append(ellipsoid("hair_cap", 0.46, mats["hair"], (0.0, 0.05, 2.02), (1.05, 1.0, 0.92), seg))
    parts.append(ellipsoid("hair_bangs", 0.3, mats["hair"], (0.0, -0.36, 2.12), (1.0, 0.42, 0.24), seg))
    for side, x in (("l", -1.0), ("r", 1.0)):
        parts.append(ellipsoid(f"hair_side_{side}", 0.2, mats["hair"], (0.43 * x, 0.02, 1.78), (0.5, 0.8, 1.3), seg))
    if extras:
        for i, x in enumerate((-0.2, 0.0, 0.2)):
            parts.append(ellipsoid(f"hair_strand_{i}", 0.09, mats["hair"], (x, -0.4, 2.02), (1.0, 0.6, 0.6), seg))

    # Face: eyes with a shine, a small mouth, and blush.
    for side, x in (("l", -0.165), ("r", 0.165)):
        parts.append(ellipsoid(f"eye_{side}", 0.075, mats["eye"], (x, -0.42, 1.88), (0.85, 0.45, 1.15), seg))
        if extras:
            parts.append(
                ellipsoid(f"eye_shine_{side}", 0.03, mats["shine"], (x + 0.03, -0.45, 1.93), (1.0, 0.5, 1.0), seg)
            )
            parts.append(
                ellipsoid(
                    f"blush_{side}",
                    0.06,
                    mats["blush"],
                    (0.28 * (1 if x > 0 else -1), -0.4, 1.75),
                    (1.0, 0.3, 0.6),
                    seg,
                )
            )
    parts.append(ellipsoid("mouth", 0.03, mats["ink"], (0.0, -0.43, 1.74), (1.6, 0.4, 0.5), seg))

    if extras:
        for i, z in enumerate((1.18, 1.06)):
            parts.append(ellipsoid(f"button_{i}", 0.025, mats["gold"], (0.0, -0.26, z), (1.0, 0.6, 1.0), seg))
    if detail["fine"]:
        # The finest level: eyebrows, a hair clip, a pocket, and laces on the boots.
        for side, x in (("l", -0.165), ("r", 0.165)):
            parts.append(ellipsoid(f"brow_{side}", 0.035, mats["eye"], (x, -0.43, 2.0), (1.8, 0.5, 0.4), seg))
        parts.append(ellipsoid("hair_clip", 0.05, mats["blush"], (0.3, -0.4, 2.2), (1.1, 0.6, 1.0), seg))
        parts.append(box("pocket", mats["tunic_dark"], (0.13, -0.245, 0.7), (0.12, 0.02, 0.1)))
        for side, x in (("l", -0.18), ("r", 0.18)):
            parts.append(box(f"lace_{side}", mats["trim"], (x, -0.135, 0.27), (0.12, 0.02, 0.02)))
    return parts


def smooth_pass(parts: list[bpy.types.Object], levels: int) -> None:
    if levels <= 0:
        return
    for obj in parts:
        modifier = obj.modifiers.new("Smooth", "SUBSURF")
        modifier.levels = levels
        modifier.render_levels = levels


def set_up_scene(height: int, samples: int, ortho_scale: float = 2.7, camera_z: float = 1.2) -> None:
    """Cycles on the CPU, a transparent film, an orthographic camera straight on (`ortho_scale` units tall, centred at
    `camera_z`), a key light from the upper left and a soft world fill."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = round(height * 2 / 3)
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    # A plain camera straight on, orthographic, so the figure's height is the same in every pixel count.
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = ortho_scale
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (0.0, -10.0, camera_z)
    camera.rotation_euler = (math.radians(90), 0.0, 0.0)
    scene.camera = camera

    # Key light from upper left and in front (the sprite's lit side), and a soft world fill.
    sun_data = bpy.data.lights.new("Key", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("Key", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_mode = "QUATERNION"
    sun.rotation_quaternion = Vector((0.5, 0.5, -0.7)).normalized().to_track_quat("-Z", "Y")

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    background = next(node for node in world.node_tree.nodes if node.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.9, 0.9, 0.95, 1.0)
    background.inputs["Strength"].default_value = 0.8
    scene.world = world


def main() -> None:
    args = parse_args()
    detail = DETAIL[args.detail]
    bpy.ops.wm.read_factory_settings(use_empty=True)

    mats = {name: material(name, colour) for name, colour in COLOURS.items()}
    parts = build_figure(detail, mats)
    smooth_pass(parts, detail["subsurf"])
    # The figure turns about Z as one piece: 0 faces the camera, -90 faces screen left, 180 faces away.
    root = bpy.data.objects.new("Figure", None)
    bpy.context.collection.objects.link(root)
    for part in parts:
        part.parent = root
    root.rotation_euler = (0.0, 0.0, math.radians(args.yaw))

    set_up_scene(1200, detail["samples"])
    bpy.context.scene.render.filepath = args.out
    bpy.ops.render.render(write_still=True)
    print(f"[blender] wrote {args.out} ({args.detail}, yaw {args.yaw:g}, {len(parts)} parts)")

    if args.blend:
        # No name.blend1 backup beside a model that is rebuilt in place.
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=args.blend)
        print(f"[blender] saved {args.blend}")


if __name__ == "__main__":
    main()
