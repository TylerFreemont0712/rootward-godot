"""Preview renders: orthographic views at the concept sheet's exact scale (so a render lays over the drawing pixel for
pixel), a three-quarter view, and close-ups. Eevee with the toon look from shading.py."""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

from . import shading

# The canonical front sheet: 1037 x 1517 pixels, 1.188 mm per pixel, her midline at x = 512, soles at y = 1490.
SHEET_W, SHEET_H = 1037, 1517
SHEET_SCALE = 0.001188
SHEET_MID_X, SHEET_SOLE_Y = 512, 1490
BACKGROUND = (0.93, 0.92, 0.95)


def scene_setup(width: int, height: int, background=BACKGROUND) -> bpy.types.Scene:
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.eevee.taa_render_samples = 16
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*shading._srgb(background), 1.0)
    bg.inputs["Strength"].default_value = 1.0
    return scene


def camera(name: str, location, rotation, ortho: float | None = None, lens: float = 85.0) -> bpy.types.Object:
    cam = bpy.data.objects.get(name)
    if cam is None:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        bpy.context.scene.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = rotation
    if ortho is not None:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = lens
    cam.data.clip_start, cam.data.clip_end = 0.01, 50
    return cam


def sheet_camera(view: str = "front") -> bpy.types.Object:
    """An orthographic camera framing exactly what the concept sheet frames, from the front, back, left or right."""
    cx = (SHEET_W / 2 - SHEET_MID_X) * SHEET_SCALE
    cz = (SHEET_SOLE_Y - SHEET_H / 2) * SHEET_SCALE
    ortho = max(SHEET_W, SHEET_H) * SHEET_SCALE
    d = 5.0
    if view == "front":
        return camera("Cam front", (cx, -d, cz), Euler((math.pi / 2, 0, 0)), ortho)
    if view == "back":
        return camera("Cam back", (-cx, d, cz), Euler((math.pi / 2, 0, math.pi)), ortho)
    if view == "left":  # her left side: the camera stands at +x looking toward -x, her nose to the image's left
        return camera("Cam left", (d, cx, cz), Euler((math.pi / 2, 0, math.pi / 2)), ortho)
    if view == "right":
        return camera("Cam right", (-d, -cx, cz), Euler((math.pi / 2, 0, -math.pi / 2)), ortho)
    raise ValueError(view)


def look_at(name: str, eye, target, lens: float = 85.0, ortho: float | None = None) -> bpy.types.Object:
    eye, target = Vector(eye), Vector(target)
    rot = (target - eye).to_track_quat("-Z", "Y").to_euler()
    return camera(name, eye, rot, ortho=ortho, lens=lens)


def render(cam: bpy.types.Object, path: Path, width: int | None = None, height: int | None = None) -> Path:
    scene = bpy.context.scene
    if width:
        scene.render.resolution_x = width
    if height:
        scene.render.resolution_y = height
    scene.camera = cam
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path


def toon_render(objects, shots: list[tuple[bpy.types.Object, Path, int, int]], outline: float = 0.0022) -> None:
    saved = shading.toon_everything(objects, outline)
    try:
        for cam, path, w, h in shots:
            render(cam, path, w, h)
    finally:
        shading.restore(objects, saved)
