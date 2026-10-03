"""Make a hand-keyed action safe to export: bake, clean, close loops, mix mocap in."""

from __future__ import annotations

import bpy

from . import common
from .common import say


def bake_visual(rig: bpy.types.Object, action_name: str, start: int, end: int, source: bpy.types.Action | None = None) -> bpy.types.Action:
    """Bakes what the rig *looks like* (IK, constraints, drivers, NLA mixes, Rigify controls) onto plain keys on the
    humanoid bones, frame by frame, into a new action `action_name`. Use it before export whenever the pose comes from
    anything but direct keys. Needs a pose-capable armature; the source action stays untouched."""
    from bpy_extras import anim_utils

    profile = common.profile_bones()
    previous = bpy.context.view_layer.objects.active
    common.in_mode(rig, "POSE")
    for pb in rig.pose.bones:
        pb.select = pb.name in profile
    options = anim_utils.BakeOptions(
        only_selected=True,
        do_pose=True,
        do_object=False,
        do_visual_keying=True,
        do_constraint_clear=False,
        do_parents_clear=False,
        do_clean=False,
        do_location=True,
        do_rotation=True,
        do_scale=False,
        do_bbone=False,
        do_custom_props=False,
    )
    baked = anim_utils.bake_action(rig, action=None, frames=range(start, end + 1), bake_options=options)
    common.in_mode(rig, "OBJECT")
    if previous is not None:
        bpy.context.view_layer.objects.active = previous
    baked.name = action_name
    baked.use_fake_user = True
    if source is not None:
        for key in source.keys():
            baked[key] = source[key]
    say(f"baked {action_name}: frames {start}..{end}")
    return baked


def to_quaternion(rig: bpy.types.Object, action: bpy.types.Action) -> int:
    """If any humanoid bone was keyed with Euler rotation, re-keys it as quaternions (what the game's clips use) by
    sampling every frame. Returns how many bones were converted."""
    from . import actions

    euler = {common.bone_of(fc) for fc in common.fcurves(rig, action) if fc.data_path.endswith("rotation_euler")}
    euler.discard(None)
    if not euler:
        return 0
    start, end = common.frame_range(action)
    actions.use(rig, action.name)
    scene = common.author_scene()
    samples = {}
    for f in range(start, end + 1):
        scene.frame_set(f)
        samples[f] = {b: rig.pose.bones[b].rotation_euler.to_quaternion() for b in euler}
    for fc in [fc for fc in common.fcurves(rig, action) if fc.data_path.endswith("rotation_euler")]:
        common.channelbag(rig, action).fcurves.remove(fc)
    for b in euler:
        rig.pose.bones[b].rotation_mode = "QUATERNION"
    for f, per_bone in samples.items():
        for b, q in per_bone.items():
            rig.pose.bones[b].rotation_quaternion = q
            rig.pose.bones[b].keyframe_insert("rotation_quaternion", frame=f)
    say(f"converted {len(euler)} bone(s) from Euler to quaternion keys")
    return len(euler)


def fix_quaternion_signs(rig: bpy.types.Object, action: bpy.types.Action) -> int:
    """Flips a quaternion key to the same hemisphere as the one before it (q and -q are the same turn, but an
    interpolation across the flip spins the long way round). Returns the keys flipped."""
    flipped = 0
    by_bone: dict[str, dict[int, object]] = {}
    for fc in common.fcurves(rig, action):
        if fc.data_path.endswith("rotation_quaternion"):
            by_bone.setdefault(common.bone_of(fc), {})[fc.array_index] = fc
    for channels in by_bone.values():
        if len(channels) != 4:
            continue
        count = len(channels[0].keyframe_points)
        previous = None
        for i in range(count):
            q = [channels[c].keyframe_points[i].co.y for c in range(4)]
            if previous is not None and sum(a * b for a, b in zip(q, previous)) < 0.0:
                for c in range(4):
                    channels[c].keyframe_points[i].co.y = -q[c]
                    channels[c].keyframe_points[i].handle_left.y *= -1.0
                    channels[c].keyframe_points[i].handle_right.y *= -1.0
                q = [-v for v in q]
                flipped += 1
            previous = q
        for fc in channels.values():
            fc.update()
    return flipped


def clean(rig: bpy.types.Object, action: bpy.types.Action, rotation: float = 0.0005, location: float = 0.0002) -> int:
    """Removes keys that linear interpolation of their neighbours reproduces within a tolerance (quaternion components
    and metres): the cheap 'clean channels' for a baked action. Never removes the first or last key. Returns the number removed."""
    removed = 0
    for fc in common.fcurves(rig, action):
        tol = rotation if fc.data_path.endswith("rotation_quaternion") else location
        points = fc.keyframe_points
        i = 1
        while i < len(points) - 1:
            a, b, c = points[i - 1].co, points[i].co, points[i + 1].co
            t = (b.x - a.x) / (c.x - a.x) if c.x != a.x else 0.0
            if abs(a.y + (c.y - a.y) * t - b.y) <= tol:
                points.remove(points[i])
                removed += 1
            else:
                i += 1
        fc.update()
    say(f"clean {action.name}: {removed} keys removed")
    return removed


def close_loop(rig: bpy.types.Object, action: bpy.types.Action) -> None:
    """Makes the last frame equal the first on every channel, so a looping clip does not pop (the game plays frame 0
    right after the last frame). Only for actions with rw_loop; the final key is overwritten."""
    start, end = common.frame_range(action)
    for fc in common.fcurves(rig, action):
        first = fc.evaluate(start)
        points = fc.keyframe_points
        if not points or points[-1].co.x < end:
            points.insert(end, first)
        else:
            points[-1].co.y = first
        fc.update()
    say(f"{action.name}: last frame now equals the first")


def set_interpolation(rig: bpy.types.Object, action: bpy.types.Action, kind: str = "BEZIER") -> None:
    """Sets every key's interpolation (BEZIER smooth, LINEAR, CONSTANT for stepped holds). The exporter samples every
    frame, so what you see in Blender is what the game plays."""
    for fc in common.fcurves(rig, action):
        for kp in fc.keyframe_points:
            kp.interpolation = kind


def retime(rig: bpy.types.Object, action: bpy.types.Action, factor: float) -> None:
    """Scales time by `factor` (2.0 = twice as slow), markers and the clip length with it."""
    for fc in common.fcurves(rig, action):
        for kp in fc.keyframe_points:
            for p in (kp.co, kp.handle_left, kp.handle_right):
                p.x *= factor
        fc.update()
    for m in action.pose_markers:
        m.frame = round(m.frame * factor)
    if action.use_frame_range:
        action.frame_end = round(action.frame_end * factor)


def smooth(rig: bpy.types.Object, action: bpy.types.Action, bones: list[str] | None = None, passes: int = 1) -> None:
    """A light 3-tap smoothing of every key value (1-2-1 weights) on the chosen bones, to take jitter out of mocap or
    a rough pass. The first and last keys stay. Runs on keyed frames; bake or key every frame for a real effect."""
    for fc in common.fcurves(rig, action):
        if bones is not None and common.bone_of(fc) not in bones:
            continue
        for _ in range(passes):
            ys = [kp.co.y for kp in fc.keyframe_points]
            for i in range(1, len(ys) - 1):
                fc.keyframe_points[i].co.y = 0.25 * ys[i - 1] + 0.5 * ys[i] + 0.25 * ys[i + 1]
        fc.update()


def from_mocap(rig: bpy.types.Object, source: str, take: str, name: str, start: float = 0.0, end: float | None = None) -> bpy.types.Action:
    """Starts a clip from the CC0 capture library: retargets take `take` of `source` (a key of
    pipeline/moves/sources.json, e.g. `quaternius`, take `Spell_Simple_Shoot`) onto the rig, with the same retargeter
    the JSON clips use (pipeline/blender/retarget.py), and keys it as an ordinary action `name` for you to pull about
    by hand. `start`/`end` in seconds of the take. Slow (it loads the capture file): a few seconds."""
    import retarget
    from mathutils import Quaternion, Vector

    before_actions = set(bpy.data.actions)
    before_objects = set(bpy.data.objects)
    rig.animation_data_create().action = None
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    src = retarget.load_all(rig, {source})[source]
    try:
        end = end if end is not None else src.length(take)
        frames = range(round(start * common.FPS), round(end * common.FPS) + 1)
        solved = []
        for f in frames:
            basis = src.basis(take, f / common.FPS)
            solved.append(basis)
    finally:
        bpy.data.objects.remove(src.armature)
        for obj in [o for o in bpy.data.objects if o not in before_objects]:
            bpy.data.objects.remove(obj)
        for act in [a for a in bpy.data.actions if a not in before_actions]:
            bpy.data.actions.remove(act)
    humanoid = [pb for pb in rig.pose.bones if pb.name in common.profile_bones()]
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for index, basis in enumerate(solved):
        for pb in humanoid:
            if pb.name in basis:
                pb.rotation_quaternion = basis[pb.name][0]
                pb.keyframe_insert("rotation_quaternion", frame=index)
        if "Hips" in basis:
            rig.pose.bones["Hips"].location = basis["Hips"][1]
            rig.pose.bones["Hips"].keyframe_insert("location", frame=index)
    action.use_frame_range = True
    action.frame_start, action.frame_end = 0, len(solved) - 1
    action["rw_loop"] = False
    action["rw_plant"] = "all"
    fix_quaternion_signs(rig, action)
    scene = common.author_scene()
    scene.frame_start, scene.frame_end = 0, len(solved) - 1
    say(f"{source}:{take} -> {name}: {len(solved)} frames at {common.FPS} fps")
    return action
