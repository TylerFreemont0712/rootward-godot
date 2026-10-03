"""An action's facts for the game: what `moves.json` holds per clip, computed from the Blender action itself
(length, loop, markers, the casting palm's position at the release, where the feet stand, when they are planted)."""

from __future__ import annotations

import json

import bpy

from . import common, events


def _plant_weights(rig_action: bpy.types.Action, frames: int, length: float) -> dict[str, list[float]]:
    """Per frame, how firmly each foot is held to the floor (1 planted, 0 free), as pipeline/moves/motion.py does."""
    spec = rig_action.get("rw_plant", "all")
    if isinstance(spec, str) and spec.strip().startswith("{"):
        spec = json.loads(spec)
    fade = 0.08
    out: dict[str, list[float]] = {}
    for foot in common.FEET:
        if spec == "all":
            out[foot] = [1.0] * frames
        elif spec == "none":
            out[foot] = [0.0] * frames
        else:
            windows = spec.get(foot)
            row = []
            for f in range(frames):
                t = f / common.FPS
                best = 0.0
                if windows is None:
                    best = 1.0
                for a, b in windows or []:
                    if a <= t <= b:
                        edge_in = 1.0 if a <= 0.0 else min(1.0, (t - a) / fade)
                        edge_out = 1.0 if b >= length else min(1.0, (b - t) / fade)
                        best = max(best, min(edge_in, edge_out))
                row.append(round(best, 2))
            out[foot] = row
    return out


def compute(rig: bpy.types.Object, action: bpy.types.Action) -> dict:
    """The moves.json entry for `action`. Leaves the rig on the action at its first frame."""
    from . import actions

    actions.use(rig, action.name)
    scene = common.author_scene()
    start, end = common.frame_range(action)
    frames = end - start + 1
    length = (end - start) / common.FPS
    ev = events.read(action)
    hips_height = rig.data.bones["Hips"].head_local.z
    hand = action.get("rw_hand")
    entry: dict = {
        "length": round(length, 4),
        "loop": bool(action.get("rw_loop", False)),
        "release": ev.get("release"),
        "charge": ev.get("charge"),
        "hand": hand,
        "release_point": [],
        "face": ev["face"],
    }
    scene.frame_set(start)
    feet = {}
    for foot in common.FEET:
        head = rig.pose.bones[foot].head  # armature space, metres, Z up, the model faces -Y
        feet[foot] = [round(head.x / hips_height, 4), round(rig.data.bones[foot].head_local.z / hips_height, 4), round(-head.y / hips_height, 4)]
    entry["feet"] = feet
    entry["plant"] = _plant_weights(action, frames, length)
    if ev.get("release") is not None and hand:
        scene.frame_set(start + round(ev["release"] * common.FPS))
        bone = rig.pose.bones[hand]
        palm = (bone.head + bone.tail) * 0.5
        entry["release_point"] = [round(palm.x / hips_height, 4), round(palm.z / hips_height, 4), round(-palm.y / hips_height, 4)]
    scene.frame_set(start)
    return entry
