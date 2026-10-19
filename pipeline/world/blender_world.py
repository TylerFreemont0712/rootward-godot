"""One background object's blockout, drawn in the town's 3/4 view (pipeline/world/world.py, ADR-0064).

  blender --background --factory-startup --python pipeline/world/blender_world.py -- pipeline/cache/world/<id>/job.json

The job lists shapes, each filling a box in tiles (x right, y back from the footprint's front edge, z up): box,
cylinder, cone, ball, and gable or hip roofs with their ridge along x. world.py decides every shape and the frame; this
script only builds them, shears them into the 3/4 view and renders them through a camera straight on.

LEARN: a top-down RPG draws an object's height in full and its depth squashed, and the ground as if seen from above:
an oblique projection, which no real camera makes. Shearing the model instead (every point lifted by depth_scale times
how far back it stands) and filming it straight on gives exactly that picture, with one tile across always the same
number of pixels, so the cut lands on the map's grid.
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "animation"))
import blender_base as base  # noqa: E402 (material)

SEGMENTS = 32


def mesh_object(name: str, mesh: bmesh.types.BMesh, material: bpy.types.Material, smooth: bool) -> bpy.types.Object:
    data = bpy.data.meshes.new(name)
    mesh.to_mesh(data)
    mesh.free()
    for polygon in data.polygons:
        polygon.use_smooth = smooth
    data.materials.append(material)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return obj


def roof_mesh(box: list[float], hip: bool) -> bmesh.types.BMesh:
    """A roof filling the box: eaves along the front and back at the bottom, the ridge along x at the top. A hip roof
    slopes at the ends too."""
    x0, y0, z0, x1, y1, z1 = box
    middle = (y0 + y1) / 2
    inset = min((y1 - y0) / 2, (x1 - x0) / 2 - 0.01) if hip else 0.0
    mesh = bmesh.new()
    points = [
        (x0, y0, z0),
        (x1, y0, z0),
        (x1, y1, z0),
        (x0, y1, z0),
        (x0 + inset, middle, z1),
        (x1 - inset, middle, z1),
    ]
    verts = [mesh.verts.new(p) for p in points]
    for face in ((0, 3, 2, 1), (0, 1, 5, 4), (2, 3, 4, 5), (3, 0, 4), (1, 2, 5)):
        mesh.faces.new([verts[i] for i in face])
    bmesh.ops.recalc_face_normals(mesh, faces=mesh.faces[:])
    return mesh


def solid(item: dict) -> tuple[bmesh.types.BMesh, bool]:
    """The shape's mesh, built in a unit box and fitted to the item's box; and whether it is shaded smooth."""
    x0, y0, z0, x1, y1, z1 = item["box"]
    kind = item["shape"]
    if kind in ("gable", "hip"):
        return roof_mesh(item["box"], kind == "hip"), False
    mesh = bmesh.new()
    if kind == "box":
        bmesh.ops.create_cube(mesh, size=1.0)
        smooth = False
    elif kind == "ball":
        bmesh.ops.create_uvsphere(mesh, u_segments=SEGMENTS, v_segments=SEGMENTS // 2, radius=0.5)
        smooth = True
    else:
        tip = 0.0 if kind == "cone" else 0.5
        bmesh.ops.create_cone(mesh, cap_ends=True, segments=SEGMENTS, radius1=0.5, radius2=tip, depth=1.0)
        smooth = True
    fit = Matrix.Translation(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)) @ Matrix.Diagonal(
        (x1 - x0, y1 - y0, z1 - z0, 1.0)
    )
    bmesh.ops.transform(mesh, matrix=fit, verts=mesh.verts[:])
    return mesh, smooth


def set_up(job: dict) -> None:
    """Cycles on the CPU, a transparent film, a camera straight on framing exactly the job's frame, a key light from the
    upper left and in front, and a soft world fill."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = int(job["samples"])
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x, scene.render.resolution_y = job["size"]
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    frame = job["frame"]
    width = job["footprint"][0]
    camera_data = bpy.data.cameras.new("Camera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(frame["width"], frame["height"])
    camera = bpy.data.objects.new("Camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (width / 2, -50.0, frame["height"] / 2)
    camera.rotation_euler = (math.radians(90), 0.0, 0.0)
    scene.camera = camera

    sun_data = bpy.data.lights.new("Key", "SUN")
    sun_data.energy = 3.2
    sun = bpy.data.objects.new("Key", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_mode = "QUATERNION"
    sun.rotation_quaternion = Vector((0.55, 0.6, -0.65)).normalized().to_track_quat("-Z", "Y")

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    background = next(node for node in world.node_tree.nodes if node.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.92, 0.92, 0.96, 1.0)
    background.inputs["Strength"].default_value = 0.85
    scene.world = world


def main() -> None:
    job_path = Path(sys.argv[sys.argv.index("--") + 1])
    job = json.loads(job_path.read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True)

    materials: dict[str, bpy.types.Material] = {}
    shear = Matrix.Identity(4)
    shear[2][1] = float(job["depth_scale"])  # z' = z + depth_scale * y
    for item in job["shapes"]:
        colour = item["colour"]
        if colour not in materials:
            materials[colour] = base.material(f"m{len(materials)}", colour)
        mesh, smooth = solid(item)
        bmesh.ops.transform(mesh, matrix=shear, verts=mesh.verts[:])
        mesh_object(item["name"], mesh, materials[colour], smooth)

    set_up(job)
    bpy.context.scene.render.filepath = job["out"]
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=job["blend"])


main()
