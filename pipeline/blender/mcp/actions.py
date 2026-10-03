"""Actions are the clips. One Blender action = one game clip, named like the clip (`cast-wave`), keyed at 30 fps from
frame 0, quaternion rotation on the humanoid bones and location on the Hips."""

from __future__ import annotations

import json

import bpy

from . import common
from .common import say

HUMANOID_KEYED = "humanoid"


def new(rig: bpy.types.Object, name: str, seconds: float, loop: bool = False, hand: str | None = None, plant: object = "all") -> bpy.types.Action:
    """A fresh action on `rig`, `seconds` long (frames 0..round(seconds*30)), kept alive with a fake user, and made the
    rig's active action. Clip facts the game needs live on the action as custom properties:
      rw_loop   True: the game loops it (idle-style); the last frame must equal the first (validate.loop_gap)
      rw_hand   the casting hand bone (`LeftHand`): with a `release` marker, the sigil is drawn at that palm
      rw_plant  "all" (feet stay planted, the game's leg IK holds them), "none" (airborne / free feet), or
                {"RightFoot": [[0, 0.6], [1.0, 1.3]]} windows in seconds where that foot is planted
    """
    if name in bpy.data.actions:
        raise RuntimeError(f"action {name!r} already exists; actions.use() it or actions.delete() it first")
    frames = max(1, round(seconds * common.FPS))
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = frames
    action.use_cyclic = bool(loop)
    action["rw_loop"] = bool(loop)
    if hand:
        action["rw_hand"] = hand
    action["rw_plant"] = plant if isinstance(plant, str) else json.dumps(plant)
    rig.animation_data_create().action = action
    scene = common.author_scene()
    scene.frame_start, scene.frame_end = 0, frames
    scene.frame_set(0)
    say(f"action {name}: {frames} frames = {frames / common.FPS:.2f} s, loop={loop}")
    return action


def use(rig: bpy.types.Object, name: str) -> bpy.types.Action:
    """Makes the named action the rig's active action (and sets the timeline to its range)."""
    action = bpy.data.actions[name]
    data = rig.animation_data_create()
    data.action = action
    if action.slots and data.action_slot is None:
        data.action_slot = action.slots[0]
    start, end = common.frame_range(action)
    scene = common.author_scene()
    scene.frame_start, scene.frame_end = start, end
    scene.frame_set(start)
    return action


def clip_actions() -> list[bpy.types.Action]:
    """Actions that count as clips: not the mocap sources, not orphan scraps."""
    return [a for a in bpy.data.actions if a.use_fake_user or a.users]


def listing() -> list[dict]:
    out = []
    for a in clip_actions():
        start, end = common.frame_range(a)
        out.append({"name": a.name, "frames": [start, end], "seconds": round((end - start) / common.FPS, 3), "loop": bool(a.get("rw_loop", False)), "markers": [(m.name, m.frame) for m in a.pose_markers]})
    return out


def rename(action: bpy.types.Action | str, name: str) -> bpy.types.Action:
    action = bpy.data.actions[action] if isinstance(action, str) else action
    action.name = name
    return action


def delete(name: str) -> None:
    action = bpy.data.actions.get(name)
    if action is not None:
        action.use_fake_user = False
        bpy.data.actions.remove(action)


def duplicate(name: str, new_name: str) -> bpy.types.Action:
    """A copy to experiment on (`cast-wave` -> `cast-wave-v2`), with its markers and properties."""
    copy = bpy.data.actions[name].copy()
    copy.name = new_name
    copy.use_fake_user = True
    return copy


def humanoid_bones(rig: bpy.types.Object) -> list[bpy.types.PoseBone]:
    profile = common.profile_bones()
    return [pb for pb in rig.pose.bones if pb.name in profile]


def key_pose(rig: bpy.types.Object, frame: int, bones: list[str] | None = None, location: bool | None = None) -> int:
    """Keys the rig's current pose at `frame` (rotation on every humanoid bone, or on `bones`; location on the Hips,
    or on any bone when `location` is True). Returns how many channels were keyed. Pose the bones first, then call
    this: e.g. `rig.pose_from_library(r, "stance")`, or set `pose.bones[...].rotation_quaternion` by hand."""
    chosen = [rig.pose.bones[b] for b in bones] if bones else humanoid_bones(rig)
    count = 0
    for pb in chosen:
        pb.rotation_mode = "QUATERNION"
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        count += 4
        if pb.name == "Hips" or location:
            pb.keyframe_insert("location", frame=frame)
            count += 3
    return count


def set_bone(rig: bpy.types.Object, bone: str, euler_deg: tuple | None = None, quat: tuple | None = None, location: tuple | None = None) -> None:
    """Sets a pose bone: `euler_deg` (x, y, z degrees about the BONE's own local axes, XYZ order; the quickest way to
    pose by script), `quat` (w, x, y, z) and/or `location` (the hips; bone-local metres). Does not key."""
    import math

    from mathutils import Euler

    pb = rig.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"
    if euler_deg is not None:
        pb.rotation_quaternion = Euler([math.radians(a) for a in euler_deg], "XYZ").to_quaternion()
    if quat is not None:
        pb.rotation_quaternion = quat
    if location is not None:
        pb.location = location


def shift_to_zero(rig: bpy.types.Object, action: bpy.types.Action) -> int:
    """Slides all keys (and markers) so the action starts at frame 0; returns the shift. The game's clips run from 0."""
    start, _ = common.frame_range(action)
    if start == 0:
        return 0
    for fc in common.fcurves(rig, action):
        for kp in fc.keyframe_points:
            kp.co.x -= start
            kp.handle_left.x -= start
            kp.handle_right.x -= start
        fc.update()
    for marker in action.pose_markers:
        marker.frame -= start
    if action.use_frame_range:
        action.frame_start -= start
        action.frame_end -= start
    return -start


def set_length(action: bpy.types.Action, seconds: float) -> None:
    """Fixes the clip's end (the exported length) without moving keys: the last frame is `round(seconds * 30)`."""
    action.use_frame_range = True
    action.frame_start = 0
    action.frame_end = max(1, round(seconds * common.FPS))
