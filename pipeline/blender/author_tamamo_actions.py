"""Hand-keyed anime actions for the Tamamo 2.5D rig; execute in Blender after building the mesh and armature."""

import math
import bpy

rig = bpy.data.objects["Tamamo_Rig"]
ACTION_NAMES = ("idle-breathe", "idle-fidget", "cast-light", "cast-heavy", "channel", "guard", "hurt", "victory", "death")
for action_name in ACTION_NAMES:
    old_action = bpy.data.actions.get(action_name)
    if old_action is not None:
        bpy.data.actions.remove(old_action)


def create_action(name, keyed_poses):
    action = bpy.data.actions.new(name)
    slot = action.slots.new(id_type="OBJECT", name=rig.name)
    rig.animation_data_create()
    rig.animation_data.action = action
    rig.animation_data.action_slot = slot
    for bone in rig.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0.0, 0.0, 0.0)
    for frame, pose in keyed_poses:
        for bone_name, angle in pose.items():
            bone = rig.pose.bones.get(bone_name)
            if bone is None:
                continue
            bone.rotation_euler = (0.0, 0.0, angle)
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
    action.use_fake_user = True
    return action


def tail_pose(phase, strength=1.0):
    pose = {}
    for tail_index in range(1, 10):
        tail_phase = phase + (tail_index - 5) * 0.21
        for segment in range(1, 7):
            amount = (0.025 + segment * 0.008) * strength
            pose["Tail%02d_%02d" % (tail_index, segment)] = math.sin(tail_phase + segment * 0.34) * amount
    return pose


def torso_pose(phase, arms=(0.52, -0.52), forearms=(0.16, -0.16)):
    pose = tail_pose(phase)
    pose.update({
        "LeftArm": arms[0], "RightArm": arms[1],
        "LeftForeArm": forearms[0], "RightForeArm": forearms[1],
        "Chest": math.sin(phase) * 0.018,
        "Head": math.sin(phase + 0.55) * 0.028,
        "Neck": math.sin(phase + 0.2) * 0.012,
    })
    for side, offset in (("L", 0.0), ("R", 0.8)):
        for segment in range(1, 5):
            pose["Hair%s_%02d" % (side, segment)] = math.sin(phase + offset + segment * 0.31) * segment * 0.012
        for segment in range(1, 4):
            pose["Ear%s_%02d" % (side, segment)] = math.sin(phase + offset + segment * 0.4) * 0.012
    return pose


def with_changes(base, changes):
    pose = dict(base)
    pose.update(changes)
    return pose


idle = [(frame, torso_pose(phase)) for frame, phase in (
    (1, 0.0), (13, math.pi * 0.5), (25, math.pi), (37, math.pi * 1.5), (49, math.pi * 2.0)
)]
create_action("idle-breathe", idle)

fidget = torso_pose(0.0)
create_action("idle-fidget", [
    (1, fidget),
    (9, with_changes(fidget, {"Head": 0.16, "Chest": -0.035, "LeftArm": 0.22, "LeftForeArm": 0.45})),
    (18, with_changes(fidget, {"Head": 0.12, "Chest": -0.02, "LeftArm": 0.08, "LeftForeArm": 0.32})),
    (27, with_changes(fidget, {"Head": -0.08, "RightArm": -0.24, "RightForeArm": -0.35})),
    (36, fidget),
])

create_action("cast-light", [
    (1, torso_pose(0.0)),
    (8, with_changes(torso_pose(0.0), {"Chest": -0.04, "Head": 0.07, "LeftArm": 0.18, "RightArm": -0.18, "LeftForeArm": -0.05, "RightForeArm": 0.05})),
    (17, with_changes(torso_pose(0.0), {"Chest": -0.08, "Head": 0.12, "LeftArm": -0.35, "RightArm": 0.45, "LeftForeArm": -0.45, "RightForeArm": 0.25})),
    (25, with_changes(torso_pose(0.0), {"Chest": 0.04, "Head": -0.04, "LeftArm": 0.18, "RightArm": -0.18, "LeftForeArm": 0.10, "RightForeArm": -0.10})),
    (32, torso_pose(0.0)),
])

create_action("cast-heavy", [
    (1, torso_pose(0.0)),
    (10, with_changes(torso_pose(0.0), {"Chest": -0.12, "Head": 0.18, "LeftArm": -0.12, "RightArm": 0.12, "LeftForeArm": -0.28, "RightForeArm": 0.28})),
    (24, with_changes(torso_pose(0.0), {"Chest": -0.22, "Head": 0.24, "LeftArm": -0.78, "RightArm": 0.78, "LeftForeArm": -0.30, "RightForeArm": 0.30})),
    (34, with_changes(torso_pose(0.0), {"Chest": 0.10, "Head": -0.10, "LeftArm": -0.48, "RightArm": 0.48, "LeftForeArm": -0.12, "RightForeArm": 0.12})),
    (48, torso_pose(0.0)),
])

channel = [(frame, with_changes(torso_pose(phase), {
    "LeftArm": 0.12, "RightArm": -0.12, "LeftForeArm": -0.32, "RightForeArm": 0.32, "Chest": -0.04
})) for frame, phase in (
    (1, 0.0), (12, math.pi * 0.5), (24, math.pi), (36, math.pi * 1.5), (48, math.pi * 2.0)
)]
create_action("channel", channel)

create_action("guard", [
    (1, torso_pose(0.0)),
    (8, with_changes(torso_pose(0.0), {"Chest": 0.06, "LeftArm": 0.85, "RightArm": -0.86, "LeftForeArm": -0.72, "RightForeArm": 0.72})),
    (24, with_changes(torso_pose(0.0), {"Chest": 0.04, "LeftArm": 0.68, "RightArm": -0.68, "LeftForeArm": -0.60, "RightForeArm": 0.60})),
])

create_action("hurt", [
    (1, torso_pose(0.0)),
    (5, with_changes(torso_pose(0.0), {"Chest": 0.20, "Head": -0.22, "LeftArm": -0.20, "RightArm": 0.24})),
    (12, with_changes(torso_pose(0.0), {"Chest": -0.06, "Head": 0.10, "LeftArm": 0.48, "RightArm": -0.46})),
    (20, torso_pose(0.0)),
])

create_action("victory", [
    (1, torso_pose(0.0)),
    (12, with_changes(torso_pose(0.0), {"Chest": -0.12, "Head": 0.08, "LeftArm": -0.70, "RightArm": 0.90, "LeftForeArm": -0.22, "RightForeArm": 0.10})),
    (30, with_changes(torso_pose(math.pi), {"Chest": -0.08, "Head": -0.04, "LeftArm": -0.62, "RightArm": 0.82})),
    (48, with_changes(torso_pose(0.0), {"Chest": -0.10, "Head": 0.04, "LeftArm": -0.70, "RightArm": 0.90})),
])

create_action("death", [
    (1, torso_pose(0.0)),
    (12, with_changes(torso_pose(0.0), {"Chest": 0.24, "Head": -0.35, "LeftArm": 0.75, "RightArm": -0.70})),
    (28, with_changes(torso_pose(math.pi), {"Chest": 0.32, "Head": -0.48, "LeftArm": 1.05, "RightArm": -1.0})),
    (40, with_changes(torso_pose(math.pi), {"Chest": 0.36, "Head": -0.52, "LeftArm": 1.10, "RightArm": -1.05})),
])

rig.animation_data.action = bpy.data.actions.get("idle-breathe")
print("Tamamo actions ready:", [action.name for action in bpy.data.actions if action.name in ACTION_NAMES])
