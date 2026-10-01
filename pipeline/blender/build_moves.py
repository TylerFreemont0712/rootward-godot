"""Build the game's move library: every clip of `pipeline/moves/clips/` keyed onto a VRM skeleton and exported as one
animation-only glTF that Godot plays on every VRM skin (ADR-0028).

  ~/blender/blender --background --python pipeline/blender/build_moves.py

(Not `--factory-startup`: that turns off the VRM extension the base model is read with.)

- **The skeleton** is a VRoid base from `pipeline/moves/rig.json`, its humanoid bones renamed to Godot's humanoid
  profile names (`Hips`, `LeftUpperArm`, ...). Godot imports the file as an AnimationLibrary retargeted through that
  profile (`humanoid_bone_map.tres`), exactly as godot-vrm imports a skin, so the rest poses agree.
- **The motion** is `pipeline/moves/motion.py`: readable parameters per bone, sampled every frame. This file only
  turns a parameter set into a rotation. Each rotation `D` is written in the armature's axes as they are at rest (X her
  left, -Y her front, Z up) and applied at the bone's head, carried by its parent: `basis = R^-1 D R`, R the bone's
  rest orientation. The right side mirrors the left.
- **Writes** `game/characters/moves/rootward.glb` and `moves.json` (length, loop, release, casting hand and where
  the palm is at the release, in hip heights, for placing the sigil).
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import addon_utils
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "moves"))

import motion

OUT = ROOT / "game" / "characters" / "moves"
MIRROR = Matrix.Diagonal((-1.0, 1.0, 1.0))
TORSO = {"Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"}
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Little")
SEGMENTS = {"Thumb": ("Metacarpal", "Proximal", "Distal"), "Other": ("Proximal", "Intermediate", "Distal")}
# How far each segment bends at `curl` 1 (a fist), and how far each finger fans at `spread` (a share of it).
CURL = {"Thumb": (25.0, 30.0, 40.0), "Other": (75.0, 95.0, 60.0)}
FAN = {"Thumb": 0.6, "Index": 1.0, "Middle": 0.25, "Ring": -0.45, "Little": -1.0}
# At rest (VRM T-pose) every palm faces down and every thumb points to the front.
PALM = Vector((0.0, 0.0, -1.0))
FRONT = Vector((0.0, -1.0, 0.0))


def log(*args: object) -> None:
    print("[moves]", *args, flush=True)


def rot(axis: str, degrees: float) -> Matrix:
    return Matrix.Rotation(math.radians(degrees), 3, axis)


def about(axis: Vector, degrees: float) -> Matrix:
    return Quaternion(axis.normalized(), math.radians(degrees)).to_matrix()


# VRM 0 names the thumb's three bones one segment further out than VRM 1 and Godot do.
VRM0_THUMB = {"ThumbProximal": "ThumbMetacarpal", "ThumbIntermediate": "ThumbProximal"}


def profile_name(vrm_name: str, vrm0: bool) -> str:
    """VRM humanoid name -> Godot humanoid profile name: `leftUpperArm` -> `LeftUpperArm`."""
    if vrm0:
        for old, new in VRM0_THUMB.items():
            if vrm_name.endswith(old):
                vrm_name = vrm_name[: -len(old)] + new
                break
    return vrm_name[0].upper() + vrm_name[1:]


def load_rig() -> bpy.types.Object:
    rig = json.loads((ROOT / "pipeline" / "moves" / "rig.json").read_text())
    addon_utils.enable("bl_ext.blender_org.vrm", default_set=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    bpy.ops.import_scene.vrm(filepath=str(ROOT / rig["base"]))
    armature = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    extension = armature.data.vrm_addon_extension
    vrm0 = extension.spec_version == "0.0"
    if vrm0:
        pairs = [(b.bone, b.node.bone_name) for b in extension.vrm0.humanoid.human_bones]
    else:
        humans = extension.vrm1.humanoid.human_bones
        pairs = [(name, bone.node.bone_name) for name, bone in humans.human_bone_name_to_human_bone().items()]
    renames = {bone: profile_name(name, vrm0) for name, bone in pairs if bone}
    for bone in armature.data.bones:
        if bone.name == "Root":
            bone.name = "VRoidRoot"  # keep Godot's profile `Root` free (godot-vrm does the same)
    for bone in armature.data.bones:
        if bone.name in renames:
            bone.name = renames[bone.name]
    # LEARN: Blender ignores the location of a bone connected to its parent, and VRoid connects the hips to its root:
    # every Hips lift, crouch and lunge keyed on it moved nothing. Disconnected, the hips can travel.
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    armature.data.edit_bones["Hips"].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    log(f"base {rig['base']}: {len(renames)} humanoid bones renamed")
    armature.name = "Moves"
    return armature


def side_of(bone: str) -> tuple[str, str]:
    for side in ("Left", "Right"):
        if bone.startswith(side):
            return side, bone[len(side) :]
    return "", bone


def limb_rotation(part: str, p: dict[str, float]) -> Matrix | None:
    """The left side's rotation for a limb bone, in armature axes at rest (the right mirrors it)."""
    g = p.get
    if part == "Shoulder":
        return rot("Z", -g("forward", 0.0)) @ rot("Y", -g("raise", 0.0))
    if part == "UpperArm":
        return rot("Z", -g("forward", 0.0)) @ rot("Y", -g("raise", 0.0)) @ rot("X", -g("twist", 0.0))
    if part == "LowerArm":
        return rot("Z", -g("bend", 0.0)) @ rot("X", -g("twist", 0.0))
    if part == "Hand":
        return rot("Z", -g("side", 0.0)) @ rot("Y", g("bend", 0.0)) @ rot("X", -g("twist", 0.0))
    if part == "UpperLeg":
        return rot("Z", g("twist", 0.0)) @ rot("Y", -g("spread", 0.0)) @ rot("X", -g("lift", 0.0))
    if part == "LowerLeg":
        return rot("X", g("bend", 0.0))
    if part in ("Foot", "Toes"):
        return rot("X", g("point", g("bend", 0.0)))
    return None


def finger_rotations(side: str, hand: dict[str, float], rest: dict[str, Matrix]) -> dict[str, Matrix]:
    """Each finger segment's rotation from the hand's `curl`, `spread`, `point`, `vee` and `thumb`."""
    out: dict[str, Matrix] = {}
    curl = hand.get("curl", 0.0)
    for finger in FINGERS:
        kind = "Thumb" if finger == "Thumb" else "Other"
        amount = curl
        if finger == "Thumb":
            amount = hand.get("thumb", curl)
        elif finger == "Index":
            amount = curl * (1.0 - max(hand.get("point", 0.0), hand.get("vee", 0.0)))
        elif finger == "Middle":
            amount = curl * (1.0 - hand.get("vee", 0.0))
        spread = hand.get("spread", 0.0) * FAN[finger]
        if hand.get("vee", 0.0) and finger in ("Index", "Middle"):
            spread += hand["vee"] * (10.0 if finger == "Index" else -10.0)
        for i, segment in enumerate(SEGMENTS[kind]):
            name = f"{side}{finger}{segment}"
            if name not in rest:
                continue
            direction = rest[name] @ Vector((0.0, 1.0, 0.0))
            turn = about(direction.cross(PALM), CURL[kind][i] * amount)
            if i == 0 and spread:
                turn = about(direction.cross(FRONT), spread) @ turn
            out[name] = turn
    return out


def apply_pose(armature: bpy.types.Object, pose: motion.Pose, rest: dict[str, Matrix]) -> None:
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_quaternion = Quaternion()
        pose_bone.location = Vector()
    rotations: dict[str, Matrix] = {}
    for bone, params in pose.items():
        side, part = side_of(bone)
        if bone in TORSO:
            rotations[bone] = rot("Z", params.get("turn", 0.0)) @ rot("Y", params.get("lean", 0.0)) @ rot(
                "X", params.get("bend", 0.0)
            )
        elif side:
            left = limb_rotation(part, params)
            if left is not None:
                rotations[bone] = MIRROR @ left @ MIRROR if side == "Right" else left
            if part == "Hand":
                rotations.update(finger_rotations(side, params, rest))
    for bone, turn in rotations.items():
        if bone not in armature.pose.bones:
            continue
        r = rest[bone]
        armature.pose.bones[bone].rotation_quaternion = (r.inverted() @ turn @ r).to_quaternion()
    hips = pose.get("Hips", {})
    offset = Vector((hips.get("side", 0.0), -hips.get("forward", 0.0), hips.get("lift", 0.0)))
    armature.pose.bones["Hips"].location = rest["Hips"].inverted() @ offset


LEGS = {"LeftFoot": ("LeftUpperLeg", "LeftLowerLeg"), "RightFoot": ("RightUpperLeg", "RightLowerLeg")}


def foot_targets(armature: bpy.types.Object) -> dict[str, tuple[Vector, Quaternion]]:
    """Where each foot stands for a clip: its ankle where the first pose puts it, dropped to the rest pose's height
    (the floor), and the foot flat, turned only about the vertical as that pose turns it."""
    out = {}
    for foot in LEGS:
        posed = armature.pose.bones[foot]
        rest_bone = armature.data.bones[foot]
        ankle = posed.head.copy()
        ankle.z = rest_bone.head_local.z
        forward = posed.matrix.to_3x3() @ Vector((0.0, 1.0, 0.0))
        rest_forward = rest_bone.matrix_local.to_3x3() @ Vector((0.0, 1.0, 0.0))
        yaw = math.atan2(forward.y, forward.x) - math.atan2(rest_forward.y, rest_forward.x)
        out[foot] = (ankle, Quaternion((0.0, 0.0, 1.0), yaw) @ rest_bone.matrix_local.to_quaternion())
    return out


def aim(bone: bpy.types.PoseBone, target: Vector, weight: float) -> None:
    """Turns a bone about its head so its tail points at `target` (by `weight`: 0 leaves it, 1 aims it)."""
    head = bone.head.copy()
    turn = (bone.tail - head).normalized().rotation_difference((target - head).normalized())
    turn = Quaternion().slerp(turn, weight)
    bone.matrix = Matrix.Translation(head) @ (turn.to_matrix() @ bone.matrix.to_3x3()).to_4x4()
    bpy.context.view_layer.update()


# LEARN: two-bone IK by the law of cosines. With the thigh a, the shin b and the hip-to-target distance d, the thigh
# leaves the hip at angle acos((a² + d² - b²) / 2ad) from the line to the target, bent toward where the knee already
# points (so a knee never flips backwards); the shin then aims at the target. A straight leg is bent forward.
def plant(armature: bpy.types.Object, targets: dict[str, tuple[Vector, Quaternion]], weights: dict) -> None:
    """Keeps each planted foot on its spot, flat, whatever the hips do: the legs are solved to reach it."""
    for foot, (ankle, flat) in targets.items():
        weight = float(weights.get(foot, 0.0))
        if weight <= 0.0:
            continue
        upper, lower = (armature.pose.bones[name] for name in LEGS[foot])
        hip, knee, now = upper.head.copy(), lower.head.copy(), armature.pose.bones[foot].head.copy()
        a, b = (knee - hip).length, (now - knee).length
        reach = ankle - hip
        d = min(max(reach.length, 1e-4), a + b - 1e-4)
        toward = reach.normalized()
        bend = math.acos(max(-1.0, min(1.0, (a * a + d * d - b * b) / (2.0 * a * d))))
        axis = toward.cross(knee - hip)
        if axis.length < 1e-6:
            axis = toward.cross(FRONT)
        aim(upper, hip + (Quaternion(axis.normalized(), bend) @ toward) * a, weight)
        aim(lower, hip + toward * d, weight)
        posed = armature.pose.bones[foot]
        turned = posed.matrix.to_quaternion().slerp(flat, weight)
        posed.matrix = Matrix.Translation(posed.head) @ turned.to_matrix().to_4x4()
        bpy.context.view_layer.update()


def keep_above_floor(armature: bpy.types.Object) -> None:
    """A foot off the ground may not sink through it: an ankle below its rest height is lifted back onto the floor
    (the leg solved to reach there), so a falling body's feet slide along the ground instead."""
    for foot, (upper_name, lower_name) in LEGS.items():
        floor = armature.data.bones[foot].head_local.z
        ankle = armature.pose.bones[foot].head.copy()
        if ankle.z >= floor - 0.005:
            continue
        upper, lower = armature.pose.bones[upper_name], armature.pose.bones[lower_name]
        target = Vector((ankle.x, ankle.y, floor))
        hip, knee = upper.head.copy(), lower.head.copy()
        a, b = (knee - hip).length, (ankle - knee).length
        d = min(max((target - hip).length, 1e-4), a + b - 1e-4)
        toward = (target - hip).normalized()
        bend = math.acos(max(-1.0, min(1.0, (a * a + d * d - b * b) / (2.0 * a * d))))
        axis = toward.cross(knee - hip)
        if axis.length < 1e-6:
            axis = toward.cross(FRONT)
        aim(upper, hip + (Quaternion(axis.normalized(), bend) @ toward) * a, 1.0)
        aim(lower, hip + toward * d, 1.0)


def key_clip(armature: bpy.types.Object, clip: motion.Clip, rest: dict[str, Matrix], ground: dict) -> bpy.types.Action:
    """Poses every frame (keys, then planted feet) with no action assigned, then keys them all: while an action is
    assigned, each update would re-evaluate it and undo the solved legs."""
    armature.animation_data_create().action = None
    bones = [b for b in armature.pose.bones if b.name in rest]
    frames = []
    targets = None
    for frame in range(clip.frames):
        pose = clip.sample(frame)
        apply_pose(armature, pose, rest)
        bpy.context.view_layer.update()
        if targets is None:
            targets = foot_targets(armature)
            height = armature.data.bones["Hips"].head_local.z
            # Where each planted foot stands, in Godot's axes (the model faces +Z) and hip heights, so a skin of any
            # size can plant its own feet there (StageCharacter's leg IK).
            ground["feet"] = {
                foot: [round(v.x / height, 4), round(v.z / height, 4), round(-v.y / height, 4)]
                for foot, (v, _flat) in targets.items()
            }
        plant(armature, targets, pose.get(motion.PLANT, {}))
        keep_above_floor(armature)
        for foot in LEGS:
            ground.setdefault("plant", {}).setdefault(foot, []).append(round(float(pose[motion.PLANT][foot]), 2))
        frames.append(({b.name: b.rotation_quaternion.copy() for b in bones}, armature.pose.bones["Hips"].location.copy()))
    action = bpy.data.actions.new(clip.id)
    action.use_fake_user = True
    armature.animation_data.action = action
    hips = armature.pose.bones["Hips"]
    for frame, (rotations, location) in enumerate(frames):
        for pose_bone in bones:
            pose_bone.rotation_quaternion = rotations[pose_bone.name]
            pose_bone.keyframe_insert("rotation_quaternion", frame=frame)
        hips.location = location
        hips.keyframe_insert("location", frame=frame)
    return action


def release_point(armature: bpy.types.Object, clip: motion.Clip, rest: dict[str, Matrix], hips_height: float) -> list:
    """Where the casting palm is at the release, in Godot's axes (the model faces +Z) and hip heights."""
    release = clip.data.get("events", {}).get("release")
    hand = clip.data.get("hand")
    if release is None or hand is None:
        return []
    # LEARN: with the clip's action assigned, any update re-evaluates the action at the scene's frame and overwrites a
    # pose set by hand, so the palm is read by moving the scene to the release frame of the keyed action instead.
    bpy.context.scene.frame_set(round(float(release) * motion.FPS))
    bone = armature.pose.bones[hand]
    palm = (bone.head + bone.tail) * 0.5
    return [round(palm.x / hips_height, 4), round(palm.z / hips_height, 4), round(-palm.y / hips_height, 4)]


def main() -> None:
    armature = load_rig()
    # Only the skeleton is keyed; without the meshes every update (the leg solver makes many) is quick.
    for obj in [o for o in bpy.data.objects if o is not armature]:
        bpy.data.objects.remove(obj)
    # LEARN: the glTF exporter turns frame numbers into seconds with the scene's frame rate (Blender's default is
    # 24), so a 30 fps clip keyed on a 24 fps scene plays 1.25 times too slow and misses its release.
    bpy.context.scene.render.fps = motion.FPS
    bpy.context.scene.render.fps_base = 1.0
    bpy.context.view_layer.objects.active = armature
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"
    humanoid = set(json.loads((ROOT / "pipeline" / "moves" / "profile_bones.json").read_text()))
    rest = {b.name: b.matrix_local.to_3x3() for b in armature.data.bones if b.name in humanoid}
    hips_height = armature.data.bones["Hips"].head_local.z
    library = motion.load_library()
    meta_path = OUT / "moves.json"
    meta: dict = {"clips": {}}
    for clip_id in motion.clip_ids():
        clip = motion.load_clip(clip_id, library)
        ground: dict = {}
        key_clip(armature, clip, rest, ground)
        meta["clips"][clip_id] = {
            "length": clip.length,
            "loop": clip.loop,
            "release": clip.data.get("events", {}).get("release"),
            "charge": clip.data.get("events", {}).get("charge"),
            "hand": clip.data.get("hand"),
            "release_point": release_point(armature, clip, rest, hips_height),
            "face": clip.data.get("face", []),
            "feet": ground["feet"],
            "plant": ground["plant"],
        }
        log(f"clip {clip_id}: {clip.frames} frames")
    armature.animation_data.action = None
    apply_pose(armature, {}, rest)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / "rootward.glb"
    armature.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_slide_to_zero=True,
        export_force_sampling=True,
        export_frame_step=1,
        export_rest_position_armature=True,
        export_def_bones=False,
        export_leaf_bone=False,
    )
    meta["fps"] = motion.FPS
    meta["base"] = json.loads((ROOT / "pipeline" / "moves" / "rig.json").read_text())["base"]
    meta_path.write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
    log(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size / 1e6:.1f} MB) and {meta_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
