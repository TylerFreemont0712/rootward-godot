"""The standard rig: load it, check it, pose it. Everything lives in the `RW_Author` scene."""

from __future__ import annotations

import json

import bpy

from . import common
from .common import say


def load_standard(vrm: str | None = None, name: str = common.RIG) -> bpy.types.Object:
    """Imports the game's move-library skeleton (pipeline/moves/rig.json: a CC0 VRoid sample, T-pose, VRM 0) into the
    `RW_Author` scene with its humanoid bones renamed to Godot's profile names, quaternion bones, the hips free to
    travel, and the scene at the game's 30 fps. The skin's meshes come along so the viewport shows a body; they are
    never exported. Idempotent: a second call returns the rig already there.

    `vrm`: another VRM (repo-relative or absolute) to author on instead, e.g. a restyled skin. Its bone *names* are
    all that matters to Godot, but a T-pose rest is required (see validate.rest_pose)."""
    scene = common.author_scene()
    common.switch_to(scene)
    existing = [o for o in scene.objects if o.type == "ARMATURE" and (o.name == name or o.name.startswith(name + "."))]
    if existing:
        say(f"rig {existing[0].name} already in {scene.name}")
        return existing[0]
    common.ensure_vrm()
    import build_moves  # pipeline/blender/build_moves.py: the same renaming the headless build uses

    path = common.ROOT / (vrm or json.loads((common.ROOT / "pipeline/moves/rig.json").read_text())["base"])
    if not path.exists() and vrm is None:
        raise RuntimeError(f"{path} is missing: run scripts/fetch-moves-refs.sh")
    before = set(bpy.data.objects)
    collection = bpy.data.collections.new("RW_Rig")
    scene.collection.children.link(collection)
    layer = bpy.context.view_layer
    layer.active_layer_collection = layer.layer_collection.children[collection.name]
    bpy.ops.import_scene.vrm(filepath=str(path))
    made = [o for o in bpy.data.objects if o not in before]
    armature = next(o for o in made if o.type == "ARMATURE")
    count = build_moves.rename_to_profile(armature)
    armature.name = name
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
    for obj in made:
        if obj.type == "EMPTY":
            obj.hide_viewport = True  # the VRM's spring-bone collider empties clutter the viewport
    armature.show_in_front = True
    armature.data.display_type = "OCTAHEDRAL"
    scene.render.fps = common.FPS
    say(f"loaded {path.name}: {count} humanoid bones renamed, {len(made)} objects, scene at {common.FPS} fps")
    return armature


def bone_report(rig: bpy.types.Object | None = None) -> dict:
    """Which bones the game keeps. Godot's importer drops every bone outside the humanoid profile (hair, skirt, cloth
    chains): the skin's spring bones move those at runtime, so they must not be keyed."""
    rig = rig or common.find_rig()
    profile = common.profile_bones()
    names = [b.name for b in rig.data.bones]
    humanoid = [n for n in names if n in profile]
    out = {
        "rig": rig.name,
        "bones": len(names),
        "humanoid": len(humanoid),
        "missing_required": [n for n in ("Hips", "Spine", "Head", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "LeftFoot", "RightFoot") if n not in names],
        "secondary": [n for n in names if n not in profile],
    }
    say(f"{rig.name}: {out['humanoid']}/{out['bones']} humanoid bones, {len(out['secondary'])} secondary (spring)")
    return out


def reset_pose(rig: bpy.types.Object | None = None) -> None:
    """Every pose bone back to rest (no keys touched)."""
    rig = rig or common.find_rig()
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def rest_matrices(rig: bpy.types.Object) -> dict:
    profile = common.profile_bones()
    return {b.name: b.matrix_local.to_3x3() for b in rig.data.bones if b.name in profile}


def pose_from_library(rig: bpy.types.Object | None, pose: str | dict) -> None:
    """Sets the rig to a named pose of pipeline/moves/poses.json (`"stance"`) or to inline readable parameters
    (`{"LeftUpperArm": {"raise": 60, "forward": 20}}`), the JSON clips' own pose language: a quick way to block a pose
    before refining it by hand. Parameters are degrees, 0 = the T-pose (pipeline/moves/README.md). Not keyed."""
    import motion
    import build_moves

    rig = rig or common.find_rig()
    resolved = motion.resolve(pose, motion.load_library())
    build_moves.apply_pose(rig, resolved, rest_matrices(rig))
    bpy.context.view_layer.update()


def set_expression(rig: bpy.types.Object | None, expression: str, weight: float = 1.0) -> bool:
    """Previews a VRM expression (`happy`, `angry`, `blink`...) on the skin in the viewport; False if the skin has none
    by that name. The game plays the real ones from the clip's `face` events."""
    rig = rig or common.find_rig()
    ext = rig.data.vrm_addon_extension
    if ext.spec_version == "0.0":
        preset = {"happy": "JOY", "sad": "SORROW", "angry": "ANGRY", "relaxed": "FUN", "blink": "BLINK", "surprised": "A"}.get(expression, expression.upper())
        for group in ext.vrm0.blend_shape_master.blend_shape_groups:
            if group.preset_name.upper() == preset or group.name.lower() == expression.lower():
                group.preview = weight
                return True
        return False
    preset = getattr(ext.vrm1.expressions.preset, expression, None)
    if preset is None:
        return False
    preset.preview = weight
    return True


def find_skin_meshes(rig: bpy.types.Object | None = None) -> list[bpy.types.Object]:
    rig = rig or common.find_rig()
    return [o for o in bpy.data.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object is rig for m in o.modifiers)]


def remove_author_scene() -> None:
    """Deletes the `RW_Author` scene with everything only it holds (objects, actions made there, orphan data), then
    the player's previous scene is shown again. Use it to start over or to leave a session as it was."""
    scene = bpy.data.scenes.get(common.SCENE)
    if scene is None:
        return
    others = [s for s in bpy.data.scenes if s is not scene]
    if others:
        common.switch_to(others[0])
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj)
    for collection in [c for c in bpy.data.collections if c.name.startswith("RW_")]:
        bpy.data.collections.remove(collection)
    if others:
        bpy.data.scenes.remove(scene)
    for action in [a for a in bpy.data.actions if a.users == 0 and not a.use_fake_user]:
        bpy.data.actions.remove(action)
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.images):
        for item in [i for i in block if i.users == 0]:
            block.remove(item)
    say("author scene removed")
