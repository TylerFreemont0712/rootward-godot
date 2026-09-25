"""Build a front-facing, skeletal 2.5D Tamamo-no-Mae character from the T-pose concept.

Run this script through Blender MCP while the source image is in the project. It keeps the painted front-view art
as the color source, converts the silhouette to a real skinned mesh, creates a detailed 2D-plane armature, and
authors game-ready actions. The foxfire spell art remains a separate Godot effect.
"""

from collections import deque
import math

import bpy
from mathutils import Vector


ROOT = "/home/joejin/personal-project/Rootward"
CONCEPT = ROOT + "/pipeline/characters/tamamo_no_mae/concept-tpose.png"
BLEND_OUT = ROOT + "/pipeline/cache/characters/tamamo_no_mae/rigged.blend"
GLB_OUT = ROOT + "/game/characters/tamamo_no_mae/tamamo_no_mae.glb"

IMAGE_W, IMAGE_H = 1024, 1536
GRID_W, GRID_H = 193, 289
MODEL_H = 1.75
MODEL_W = MODEL_H * IMAGE_W / IMAGE_H


def image_rgb(image, pixels, x, y):
    px = round(x * (IMAGE_W - 1) / (GRID_W - 1))
    py = round(y * (IMAGE_H - 1) / (GRID_H - 1))
    index = ((IMAGE_H - 1 - py) * IMAGE_W + px) * 4
    return (pixels[index], pixels[index + 1], pixels[index + 2])


def coord(u, v):
    return Vector(((u - 0.5) * MODEL_W, 0.0, v * MODEL_H))


def add_bone(edit_bones, name, start, end, parent=None):
    bone = edit_bones.new(name)
    bone.head = coord(start[0], start[1])
    bone.tail = coord(end[0], end[1])
    if (bone.tail - bone.head).length < 0.012:
        bone.tail.z += 0.012
    if parent:
        bone.parent = edit_bones[parent]
    bone.use_connect = False
    bone.align_roll(Vector((0.0, 1.0, 0.0)))
    return bone


def quadratic_points(start, control, end, steps=6):
    points = []
    for index in range(steps + 1):
        t = index / steps
        one = 1.0 - t
        u = one * one * start[0] + 2.0 * one * t * control[0] + t * t * end[0]
        v = one * one * start[1] + 2.0 * one * t * control[1] + t * t * end[1]
        points.append((u, v))
    return points


def nearest_chain(u, v, paths):
    best_chain = 0
    best_t = 0.0
    best_distance = 1e9
    for chain_index, points in enumerate(paths):
        for segment_index in range(len(points) - 1):
            ax, ay = points[segment_index]
            bx, by = points[segment_index + 1]
            dx, dy = bx - ax, by - ay
            length2 = dx * dx + dy * dy
            t = 0.0 if length2 == 0.0 else max(0.0, min(1.0, ((u - ax) * dx + (v - ay) * dy) / length2))
            qx, qy = ax + t * dx, ay + t * dy
            distance = (u - qx) ** 2 + (v - qy) ** 2
            if distance < best_distance:
                best_chain = chain_index
                best_t = (segment_index + t) / (len(points) - 1)
                best_distance = distance
    return best_chain, best_t


def create_action(rig, name, keyed_poses, looping=False):
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
    pose.update(
        {
            "LeftArm": arms[0],
            "RightArm": arms[1],
            "LeftForeArm": forearms[0],
            "RightForeArm": forearms[1],
            "Chest": math.sin(phase) * 0.018,
            "Head": math.sin(phase + 0.55) * 0.028,
            "Neck": math.sin(phase + 0.2) * 0.012,
        }
    )
    for side, offset in (("L", 0.0), ("R", 0.8)):
        for segment in range(1, 5):
            pose["Hair%s_%02d" % (side, segment)] = math.sin(phase + offset + segment * 0.31) * segment * 0.012
        for segment in range(1, 4):
            pose["Ear%s_%02d" % (side, segment)] = math.sin(phase + offset + segment * 0.4) * 0.012
    return pose


def keyed_pose(base, changes):
    pose = dict(base)
    pose.update(changes)
    return pose


# A new scene keeps the earlier independent foxfire-effect source scene intact.
scene = bpy.data.scenes.new("Tamamo • 2.5D Rig")
bpy.context.window.scene = scene

image = bpy.data.images.get("concept-tpose.png")
if image is None:
    bpy.ops.image.open(filepath=CONCEPT)
    image = bpy.data.images.get("concept-tpose.png")
if image is None:
    raise RuntimeError("The T-pose concept could not be loaded")

# Flood-fill only the light neutral background connected to the image edge. This keeps enclosed white cloth and fur.
pixels = image.pixels
corner_rgb = [image_rgb(image, pixels, x, y) for x, y in ((0, 0), (GRID_W - 1, 0), (0, GRID_H - 1), (GRID_W - 1, GRID_H - 1))]
background = tuple(sum(sample[channel] for sample in corner_rgb) / len(corner_rgb) for channel in range(3))
potential = [[False for _ in range(GRID_W)] for _ in range(GRID_H)]
for y in range(GRID_H):
    for x in range(GRID_W):
        rgb = image_rgb(image, pixels, x, y)
        spread = max(rgb) - min(rgb)
        distance = sum((rgb[channel] - background[channel]) ** 2 for channel in range(3)) ** 0.5
        potential[y][x] = min(rgb) > 0.82 and spread < 0.075 and distance < 0.14

background_mask = [[False for _ in range(GRID_W)] for _ in range(GRID_H)]
queued_mask = [[False for _ in range(GRID_W)] for _ in range(GRID_H)]
queue = deque()
for x in range(GRID_W):
    if potential[0][x]:
        queue.append((x, 0))
        queued_mask[0][x] = True
    if potential[GRID_H - 1][x]:
        queue.append((x, GRID_H - 1))
        queued_mask[GRID_H - 1][x] = True
for y in range(GRID_H):
    if potential[y][0]:
        queue.append((0, y))
        queued_mask[y][0] = True
    if potential[y][GRID_W - 1]:
        queue.append((GRID_W - 1, y))
        queued_mask[y][GRID_W - 1] = True
while queue:
    x, y = queue.popleft()
    if background_mask[y][x] or not potential[y][x]:
        continue
    background_mask[y][x] = True
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nx, ny = x + dx, y + dy
            if 0 <= nx < GRID_W and 0 <= ny < GRID_H and not queued_mask[ny][nx] and potential[ny][nx]:
                queued_mask[ny][nx] = True
                queue.append((nx, ny))

vertices = []
uvs = []
pixel_to_vertex = [[-1 for _ in range(GRID_W)] for _ in range(GRID_H)]
for y in range(GRID_H):
    for x in range(GRID_W):
        if background_mask[y][x]:
            continue
        u = x / (GRID_W - 1)
        top_v = y / (GRID_H - 1)
        vertex_index = len(vertices)
        pixel_to_vertex[y][x] = vertex_index
        vertices.append(((u - 0.5) * MODEL_W, 0.0, (1.0 - top_v) * MODEL_H))
        uvs.append((u, 1.0 - top_v))

faces = []
for y in range(GRID_H - 1):
    for x in range(GRID_W - 1):
        corners = (pixel_to_vertex[y][x], pixel_to_vertex[y][x + 1], pixel_to_vertex[y + 1][x + 1], pixel_to_vertex[y + 1][x])
        visible = [index for index in corners if index >= 0]
        if len(visible) == 4:
            faces.append(tuple(visible))
        elif len(visible) == 3:
            faces.append(tuple(visible))

mesh_data = bpy.data.meshes.new("Tamamo_2D_SkinnedSurface")
mesh_data.from_pydata(vertices, [], faces)
mesh_data.update()
uv_layer = mesh_data.uv_layers.new(name="UVMap")
for polygon in mesh_data.polygons:
    for loop_index in polygon.loop_indices:
        vertex_index = mesh_data.loops[loop_index].vertex_index
        uv_layer.data[loop_index].uv = uvs[vertex_index]
for polygon in mesh_data.polygons:
    polygon.use_smooth = True

body = bpy.data.objects.new("Tamamo • Ink Surface", mesh_data)
scene.collection.objects.link(body)
material = bpy.data.materials.new("Tamamo • Painted Cel Art")
material.use_nodes = True
nodes = material.node_tree.nodes
principled = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
principled.inputs["Roughness"].default_value = 0.92
principled.inputs["Metallic"].default_value = 0.0
texture = nodes.new("ShaderNodeTexImage")
texture.name = "T-Pose Concept Texture"
texture.image = image
texture.interpolation = "Linear"
uv_node = nodes.new("ShaderNodeUVMap")
uv_node.uv_map = "UVMap"
material.node_tree.links.new(uv_node.outputs["UV"], texture.inputs["Vector"])
material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
principled.inputs["Emission Color"].default_value = (1.0, 1.0, 1.0, 1.0)
principled.inputs["Emission Strength"].default_value = 0.55
material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Emission Color"])
body.data.materials.append(material)

# Nine separated control chains plus a detailed humanoid, ear, hair, and finger skeleton.
armature = bpy.data.armatures.new("Tamamo_Anime_2D_Rig")
rig = bpy.data.objects.new("Tamamo_Rig", armature)
scene.collection.objects.link(rig)
rig.show_in_front = True
armature.display_type = "STICK"
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
edit = armature.edit_bones

add_bone(edit, "Root", (0.5, 0.0), (0.5, 0.08))
add_bone(edit, "Hips", (0.5, 0.43), (0.5, 0.52), "Root")
add_bone(edit, "Spine", (0.5, 0.47), (0.5, 0.57), "Hips")
add_bone(edit, "Chest", (0.5, 0.57), (0.5, 0.67), "Spine")
add_bone(edit, "UpperChest", (0.5, 0.67), (0.5, 0.73), "Chest")
add_bone(edit, "Neck", (0.5, 0.73), (0.5, 0.80), "UpperChest")
add_bone(edit, "Head", (0.5, 0.80), (0.5, 0.91), "Neck")
add_bone(edit, "Jaw", (0.5, 0.85), (0.5, 0.81), "Head")

for side, sign in (("L", 1.0), ("R", -1.0)):
    shoulder = 0.5 + sign * 0.105
    elbow = 0.5 + sign * 0.255
    wrist = 0.5 + sign * 0.415
    palm = 0.5 + sign * 0.475
    add_bone(edit, "Shoulder" + side, (0.5, 0.73), (shoulder, 0.73), "UpperChest")
    arm_name = "LeftArm" if side == "L" else "RightArm"
    forearm_name = "LeftForeArm" if side == "L" else "RightForeArm"
    add_bone(edit, arm_name, (shoulder, 0.73), (elbow, 0.73), "Shoulder" + side)
    add_bone(edit, forearm_name, (elbow, 0.73), (wrist, 0.73), arm_name)
    add_bone(edit, "Hand" + side, (wrist, 0.73), (palm, 0.73), forearm_name)
    finger_names = ("Thumb", "Index", "Middle", "Ring", "Little")
    for finger_index, finger_name in enumerate(finger_names):
        spread = (finger_index - 2) * 0.010
        direction = sign
        root = (palm - direction * 0.012, 0.73 + spread * 0.45)
        first = (palm + direction * 0.014, 0.73 + spread)
        second = (palm + direction * 0.029, 0.73 + spread * 1.55)
        tip = (palm + direction * 0.040, 0.73 + spread * 2.0)
        if finger_name == "Thumb":
            first = (palm + direction * 0.006, 0.73 - 0.025)
            second = (palm + direction * 0.023, 0.73 - 0.035)
            tip = (palm + direction * 0.037, 0.73 - 0.038)
        parent = "Hand" + side
        for segment, (start, end) in enumerate(((root, first), (first, second), (second, tip)), 1):
            name = "%s%s_%d" % (finger_name, side, segment)
            add_bone(edit, name, start, end, parent)
            parent = name

for side, sign in (("L", 1.0), ("R", -1.0)):
    hip_x = 0.5 + sign * 0.045
    knee_x = 0.5 + sign * 0.058
    ankle_x = 0.5 + sign * 0.055
    foot_x = 0.5 + sign * 0.105
    toe_x = 0.5 + sign * 0.13
    add_bone(edit, "UpLeg" + side, (hip_x, 0.47), (knee_x, 0.25), "Hips")
    add_bone(edit, "Leg" + side, (knee_x, 0.25), (ankle_x, 0.08), "UpLeg" + side)
    add_bone(edit, "Foot" + side, (ankle_x, 0.08), (foot_x, 0.045), "Leg" + side)
    add_bone(edit, "Toe" + side, (foot_x, 0.045), (toe_x, 0.04), "Foot" + side)

for side, center in (("L", 0.565), ("R", 0.435)):
    add_bone(edit, "Ear%s_01" % side, (center, 0.91), (center + (0.035 if side == "L" else -0.035), 0.96), "Head")
    add_bone(edit, "Ear%s_02" % side, (center + (0.035 if side == "L" else -0.035), 0.96), (center + (0.052 if side == "L" else -0.052), 0.99), "Ear%s_01" % side)
    add_bone(edit, "Ear%s_03" % side, (center + (0.052 if side == "L" else -0.052), 0.99), (center + (0.060 if side == "L" else -0.060), 1.015), "Ear%s_02" % side)
    hair_points = quadratic_points((0.5 + (0.055 if side == "L" else -0.055), 0.86), (center, 0.62), (center, 0.43), 4)
    parent = "Head"
    for segment in range(1, 5):
        bone_name = "Hair%s_%02d" % (side, segment)
        add_bone(edit, bone_name, hair_points[segment - 1], hair_points[segment], parent)
        parent = bone_name
    add_bone(edit, "Sleeve%s" % side, (0.5 + (0.10 if side == "L" else -0.10), 0.73), (0.5 + (0.18 if side == "L" else -0.18), 0.72), "Shoulder" + side)

tail_endpoints = [
    (0.08, 0.88), (0.035, 0.75), (0.025, 0.61), (0.055, 0.45), (0.50, 0.30),
    (0.945, 0.45), (0.975, 0.61), (0.965, 0.75), (0.92, 0.88),
]
tail_paths = []
for tail_index, endpoint in enumerate(tail_endpoints, 1):
    side = -1.0 if endpoint[0] < 0.5 else (1.0 if endpoint[0] > 0.5 else 0.0)
    control = ((0.5 + endpoint[0]) * 0.5 + side * 0.07, 0.63 if endpoint[1] > 0.6 else 0.47)
    path = quadratic_points((0.5, 0.48), control, endpoint, 6)
    tail_paths.append(path)
    parent = "Hips"
    for segment in range(1, 7):
        name = "Tail%02d_%02d" % (tail_index, segment)
        add_bone(edit, name, path[segment - 1], path[segment], parent)
        parent = name

bpy.ops.object.mode_set(mode="OBJECT")

# A purpose-built 2D weight map: face, arms, legs, hair, ears, and all nine tail fans deform independently.
groups = {bone.name: body.vertex_groups.new(name=bone.name) for bone in armature.bones if bone.use_deform}
weighted_vertices = {name: [] for name in groups}
for vertex_index, vertex_uv in enumerate(uvs):
    u, v = vertex_uv
    bone_name = "Hips"
    in_arm_band = 0.675 < v < 0.79 and (u < 0.39 or u > 0.61)
    if in_arm_band:
        if u > 0.5:
            bone_name = "HandL" if u > 0.91 else "LeftForeArm" if u > 0.75 else "LeftArm" if u > 0.63 else "ShoulderL"
        else:
            bone_name = "HandR" if u < 0.09 else "RightForeArm" if u < 0.25 else "RightArm" if u < 0.37 else "ShoulderR"
    elif abs(u - 0.5) > 0.28 and 0.30 < v < 0.94:
        tail_index, along = nearest_chain(u, v, tail_paths)
        segment = max(1, min(6, int(along * 6.0) + 1))
        bone_name = "Tail%02d_%02d" % (tail_index + 1, segment)
    elif v > 0.92 and (0.39 < u < 0.47 or 0.53 < u < 0.61):
        bone_name = "EarR_01" if u < 0.5 else "EarL_01"
    elif 0.43 < v < 0.87 and (0.35 < u < 0.45 or 0.55 < u < 0.65):
        side = "R" if u < 0.5 else "L"
        segment = max(1, min(4, int((0.87 - v) / 0.11) + 1))
        bone_name = "Hair%s_%02d" % (side, segment)
    elif v > 0.80 and 0.40 < u < 0.60:
        bone_name = "Head"
    elif v < 0.46 and (u < 0.44 or u > 0.56):
        side = "L" if u > 0.5 else "R"
        bone_name = "Foot" + side if v < 0.095 else "Leg" + side if v < 0.25 else "UpLeg" + side
    elif v > 0.64:
        bone_name = "Chest"
    elif v > 0.52:
        bone_name = "Spine"
    weighted_vertices[bone_name].append(vertex_index)
for bone_name, indices in weighted_vertices.items():
    if indices:
        groups[bone_name].add(indices, 1.0, "REPLACE")

body.parent = rig
armature_modifier = body.modifiers.new("Tamamo • Deform Rig", "ARMATURE")
armature_modifier.object = rig
armature_modifier.use_vertex_groups = True

# Keyed, expressive 24 fps anime actions; no pose or effect is baked into the texture.
idle_poses = []
for frame, phase in ((1, 0.0), (13, math.pi * 0.5), (25, math.pi), (37, math.pi * 1.5), (49, math.pi * 2.0)):
    idle_poses.append((frame, torso_pose(phase)))
create_action(rig, "idle-breathe", idle_poses, looping=True)

fidget_base = torso_pose(0.0)
fidget = [
    (1, fidget_base),
    (9, keyed_pose(fidget_base, {"Head": 0.16, "Chest": -0.035, "LeftArm": 0.22, "LeftForeArm": 0.45})),
    (18, keyed_pose(fidget_base, {"Head": 0.12, "Chest": -0.02, "LeftArm": 0.08, "LeftForeArm": 0.32})),
    (27, keyed_pose(fidget_base, {"Head": -0.08, "RightArm": -0.24, "RightForeArm": -0.35})),
    (36, fidget_base),
]
create_action(rig, "idle-fidget", fidget)

cast_light = [
    (1, torso_pose(0.0)),
    (8, keyed_pose(torso_pose(0.0), {"Chest": -0.04, "Head": 0.07, "LeftArm": 0.18, "RightArm": -0.18, "LeftForeArm": -0.05, "RightForeArm": 0.05})),
    (17, keyed_pose(torso_pose(0.0), {"Chest": -0.08, "Head": 0.12, "LeftArm": -0.35, "RightArm": 0.45, "LeftForeArm": -0.45, "RightForeArm": 0.25})),
    (25, keyed_pose(torso_pose(0.0), {"Chest": 0.04, "Head": -0.04, "LeftArm": 0.18, "RightArm": -0.18, "LeftForeArm": 0.10, "RightForeArm": -0.10})),
    (32, torso_pose(0.0)),
]
create_action(rig, "cast-light", cast_light)

cast_heavy = [
    (1, torso_pose(0.0)),
    (10, keyed_pose(torso_pose(0.0), {"Chest": -0.12, "Head": 0.18, "LeftArm": -0.12, "RightArm": 0.12, "LeftForeArm": -0.28, "RightForeArm": 0.28})),
    (24, keyed_pose(torso_pose(0.0), {"Chest": -0.22, "Head": 0.24, "LeftArm": -0.78, "RightArm": 0.78, "LeftForeArm": -0.30, "RightForeArm": 0.30})),
    (34, keyed_pose(torso_pose(0.0), {"Chest": 0.10, "Head": -0.10, "LeftArm": -0.48, "RightArm": 0.48, "LeftForeArm": -0.12, "RightForeArm": 0.12})),
    (48, torso_pose(0.0)),
]
create_action(rig, "cast-heavy", cast_heavy)

channel = []
for frame, phase in ((1, 0.0), (12, math.pi * 0.5), (24, math.pi), (36, math.pi * 1.5), (48, math.pi * 2.0)):
    channel.append((frame, keyed_pose(torso_pose(phase), {"LeftArm": 0.12, "RightArm": -0.12, "LeftForeArm": -0.32, "RightForeArm": 0.32, "Chest": -0.04})))
create_action(rig, "channel", channel, looping=True)

create_action(rig, "guard", [
    (1, torso_pose(0.0)),
    (8, keyed_pose(torso_pose(0.0), {"Chest": 0.06, "LeftArm": 0.85, "RightArm": -0.86, "LeftForeArm": -0.72, "RightForeArm": 0.72})),
    (24, keyed_pose(torso_pose(0.0), {"Chest": 0.04, "LeftArm": 0.68, "RightArm": -0.68, "LeftForeArm": -0.60, "RightForeArm": 0.60})),
])
create_action(rig, "hurt", [
    (1, torso_pose(0.0)),
    (5, keyed_pose(torso_pose(0.0), {"Chest": 0.20, "Head": -0.22, "LeftArm": -0.20, "RightArm": 0.24})),
    (12, keyed_pose(torso_pose(0.0), {"Chest": -0.06, "Head": 0.10, "LeftArm": 0.48, "RightArm": -0.46})),
    (20, torso_pose(0.0)),
])
create_action(rig, "victory", [
    (1, torso_pose(0.0)),
    (12, keyed_pose(torso_pose(0.0), {"Chest": -0.12, "Head": 0.08, "LeftArm": -0.70, "RightArm": 0.90, "LeftForeArm": -0.22, "RightForeArm": 0.10})),
    (30, keyed_pose(torso_pose(math.pi), {"Chest": -0.08, "Head": -0.04, "LeftArm": -0.62, "RightArm": 0.82})),
    (48, keyed_pose(torso_pose(0.0), {"Chest": -0.10, "Head": 0.04, "LeftArm": -0.70, "RightArm": 0.90})),
])
create_action(rig, "death", [
    (1, torso_pose(0.0)),
    (12, keyed_pose(torso_pose(0.0), {"Chest": 0.24, "Head": -0.35, "LeftArm": 0.75, "RightArm": -0.70})),
    (28, keyed_pose(torso_pose(math.pi), {"Chest": 0.32, "Head": -0.48, "LeftArm": 1.05, "RightArm": -1.0})),
    (40, keyed_pose(torso_pose(math.pi), {"Chest": 0.36, "Head": -0.52, "LeftArm": 1.10, "RightArm": -1.05})),
])

scene.render.resolution_x = 900
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 49
scene.camera = None
camera_data = bpy.data.cameras.new("Tamamo_Orthographic_Camera")
camera = bpy.data.objects.new("Tamamo_Orthographic_Camera", camera_data)
scene.collection.objects.link(camera)
camera.location = (0.0, 4.0, 0.92)
camera.rotation_euler = Vector((0.0, -1.0, 0.0)).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.05
scene.camera = camera

for name, location, energy, size in (
    ("Key Softbox", (-2.4, 2.5, 3.2), 950.0, 4.0),
    ("Fill Softbox", (2.8, 1.8, 1.4), 500.0, 3.0),
):
    light_data = bpy.data.lights.new(name, type="AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size
    light = bpy.data.objects.new(name, light_data)
    scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0.0, 0.0, 0.92)) - light.location).to_track_quat("-Z", "Y").to_euler()

image.pack()
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
scene.frame_set(1)

# NLA tracks keep this export scoped to the new rig even when the .blend also
# contains legacy Mixamo actions from another character scene.
action_names = (
    "idle-breathe", "idle-fidget", "cast-light", "cast-heavy", "channel",
    "guard", "hurt", "victory", "death",
)
anim_data = rig.animation_data_create()
anim_data.action = None
for action_name in action_names:
    action = bpy.data.actions[action_name]
    track = anim_data.nla_tracks.new()
    track.name = action_name
    strip = track.strips.new(action_name, 1, action)
    strip.action_slot = action.slots[0]
    track.mute = False

# Export only the skinned character, with every named action.
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=GLB_OUT,
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=False,
    export_skins=True,
    export_def_bones=False,
    export_leaf_bone=False,
    export_rest_position_armature=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_nla_strips=True,
    export_anim_slide_to_zero=True,
    export_force_sampling=True,
    export_frame_step=1,
    export_optimize_animation_size=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
)

# Keep the editable file in a clean source-art view with its detailed rig available in the Outliner.
for track in anim_data.nla_tracks:
    track.mute = True
anim_data.action = bpy.data.actions["idle-breathe"]
anim_data.action_slot = anim_data.action.slots[0]
rig.show_in_front = False
camera.hide_set(True)
for light_name in ("Key Softbox", "Fill Softbox"):
    bpy.data.objects[light_name].hide_set(True)
for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        space = area.spaces.active
        space.region_3d.view_location = Vector((0.0, 0.0, 0.92))
        space.region_3d.view_rotation = Vector((0.0, -1.0, 0.0)).to_track_quat("-Z", "Y")
        space.region_3d.view_distance = 2.8
        space.region_3d.view_perspective = "ORTHO"
        space.shading.type = "MATERIAL"
        space.overlay.show_bones = False
        space.overlay.show_relationship_lines = False

bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = None
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, copy=True, check_existing=False)

print("Built Tamamo 2.5D rig: %d mesh vertices, %d faces, %d bones, %d actions" % (
    len(mesh_data.vertices), len(mesh_data.polygons), len(armature.bones), len(bpy.data.actions)
))
