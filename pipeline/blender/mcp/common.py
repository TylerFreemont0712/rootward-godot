"""Paths, constants and small helpers every tool shares."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[3]
SCENE = "RW_Author"  # the scene the tools author in; the player's own scenes are never touched
RIG = "Moves"  # the standard armature's object name (build_moves.py names it the same)
FPS = 30  # the game's clip rate (pipeline/moves/motion.py FPS); the glTF exporter turns frames into seconds with it
MOVES = ROOT / "game" / "characters" / "moves"
AUTHORED_GLB = MOVES / "authored.glb"
AUTHORED_META = MOVES / "moves-authored.json"
PROFILE = ROOT / "pipeline" / "moves" / "profile_bones.json"
FEET = ("LeftFoot", "RightFoot")
LEGS = {"LeftFoot": ("LeftUpperLeg", "LeftLowerLeg"), "RightFoot": ("RightUpperLeg", "RightLowerLeg")}

# build_moves.py, motion.py and retarget.py are importable by the tools that want the JSON clips' maths.
for _path in (ROOT / "pipeline" / "blender", ROOT / "pipeline" / "moves"):
    if str(_path) not in sys.path:
        sys.path.append(str(_path))


def say(*args: object) -> None:
    print("[rw]", *args, flush=True)


def profile_bones() -> set[str]:
    """Godot's humanoid profile bone names the game keeps (anything else on a rig is dropped by the importer)."""
    return set(json.loads(PROFILE.read_text()))


def ensure_vrm() -> None:
    """Turns the VRM extension on (it is installed as an extension but off in a fresh GUI session). It must be enabled
    with `default_set=True`: the importer reads the add-on's preferences, which only exist then (a trap: without it
    the import dies with "No add-on preferences for bl_ext.blender_org.vrm"). Blender saves that choice with its
    preferences, which is what the player wants anyway."""
    import addon_utils

    if "bl_ext.blender_org.vrm" not in bpy.context.preferences.addons:
        addon_utils.enable("bl_ext.blender_org.vrm", default_set=True)


def author_scene(create: bool = True) -> bpy.types.Scene | None:
    """The `RW_Author` scene (made on demand), at the game's frame rate."""
    scene = bpy.data.scenes.get(SCENE)
    if scene is None and create:
        scene = bpy.data.scenes.new(SCENE)
    if scene is not None:
        scene.render.fps = FPS
        scene.render.fps_base = 1.0
    return scene


def switch_to(scene: bpy.types.Scene) -> None:
    """Shows `scene` in the window (a no-op in a background Blender)."""
    window = getattr(bpy.context, "window", None)
    if window is None and bpy.context.window_manager.windows:
        window = bpy.context.window_manager.windows[0]
    if window is not None:
        window.scene = scene


def find_rig(name: str | None = None) -> bpy.types.Object:
    """The standard rig: the object called `name`, else `Moves` in the author scene, else the only armature there."""
    scene = bpy.data.scenes.get(SCENE) or bpy.context.scene
    if name:
        obj = bpy.data.objects.get(name)
        if obj is None or obj.type != "ARMATURE":
            raise RuntimeError(f"no armature called {name!r}; armatures: {[o.name for o in bpy.data.objects if o.type == 'ARMATURE']}")
        return obj
    rigs = [o for o in scene.objects if o.type == "ARMATURE"]
    for obj in rigs:
        if obj.name == RIG or obj.name.startswith(RIG + "."):
            return obj
    if len(rigs) == 1:
        return rigs[0]
    raise RuntimeError(f"which armature? run rig.load_standard() first (found {[o.name for o in rigs]})")


def in_mode(obj: bpy.types.Object, mode: str) -> None:
    """Makes `obj` active and switches to `mode` (OBJECT, POSE, EDIT) when it is not there."""
    view_layer = bpy.context.view_layer
    if view_layer.objects.active is not obj:
        view_layer.objects.active = obj
    if obj.mode != mode:
        bpy.ops.object.mode_set(mode=mode)


def channelbag(rig: bpy.types.Object, action: bpy.types.Action):
    """The F-curve container of `action` for `rig`'s slot (Blender 5 layered actions: no `action.fcurves`)."""
    from bpy_extras import anim_utils

    slot = None
    data = rig.animation_data
    if data is not None and data.action is action:
        slot = data.action_slot
    if slot is None:
        slot = anim_utils.action_get_first_suitable_slot(rig, action) if hasattr(anim_utils, "action_get_first_suitable_slot") else None
    if slot is None and action.slots:
        slot = action.slots[0]
    return anim_utils.action_get_channelbag_for_slot(action, slot) if slot is not None else None


def fcurves(rig: bpy.types.Object, action: bpy.types.Action) -> list:
    bag = channelbag(rig, action)
    return list(bag.fcurves) if bag is not None else []


def bone_of(fcurve) -> str | None:
    path = fcurve.data_path
    if path.startswith('pose.bones["'):
        return path[len('pose.bones["') : path.index('"]')]
    return None


def frame_range(action: bpy.types.Action) -> tuple[int, int]:
    """The action's keyed range (or its manual range when `use_frame_range`), whole frames."""
    start, end = action.frame_range
    return int(round(start)), int(round(end))
