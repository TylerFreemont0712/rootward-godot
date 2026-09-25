"""Finalize the live Tamamo rig scene after author_tamamo_actions.py."""

import bpy
from mathutils import Vector

ROOT = "/home/joejin/personal-project/Rootward"
BLEND_OUT = ROOT + "/pipeline/cache/characters/tamamo_no_mae/rigged.blend"
GLB_OUT = ROOT + "/game/characters/tamamo_no_mae/tamamo_no_mae.glb"

scene = bpy.context.scene
body = bpy.data.objects["Tamamo • Ink Surface"]
rig = bpy.data.objects["Tamamo_Rig"]
image = next(node.image for material in body.data.materials for node in material.node_tree.nodes if node.type == "TEX_IMAGE" and node.image)
image.pack()

scene.render.resolution_x = 900
scene.render.resolution_y = 1200
scene.render.resolution_percentage = 100
scene.render.fps = 24
scene.frame_start = 1
scene.frame_end = 49

camera = bpy.data.objects.get("Tamamo_Orthographic_Camera")
if camera is None:
    camera_data = bpy.data.cameras.new("Tamamo_Orthographic_Camera")
    camera = bpy.data.objects.new("Tamamo_Orthographic_Camera", camera_data)
    scene.collection.objects.link(camera)
camera.location = (0.0, 4.0, 0.92)
camera.rotation_euler = (Vector((0.0, 0.0, 0.92)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.05
scene.camera = camera

for name, location, energy, size in (
    ("Tamamo • Key Softbox", (-2.4, 2.5, 3.2), 950.0, 4.0),
    ("Tamamo • Fill Softbox", (2.8, 1.8, 1.4), 500.0, 3.0),
):
    light_data = bpy.data.lights.get(name)
    if light_data is None:
        light_data = bpy.data.lights.new(name, type="AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size
    light = bpy.data.objects.get(name)
    if light is None:
        light = bpy.data.objects.new(name, light_data)
        scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0.0, 0.0, 0.92)) - light.location).to_track_quat("-Z", "Y").to_euler()

scene.frame_set(1)

# Keep the source scene's NLA stack scoped to this rig. The .blend also retains
# the earlier project scene, whose Mixamo actions must not leak into this GLB.
anim_data = rig.animation_data_create()
for track in list(anim_data.nla_tracks):
    anim_data.nla_tracks.remove(track)
action_names = (
    "idle-breathe", "idle-fidget", "cast-light", "cast-heavy", "channel",
    "guard", "hurt", "victory", "death",
)
anim_data.action = None
for action_name in action_names:
    action = bpy.data.actions[action_name]
    track = anim_data.nla_tracks.new()
    track.name = action_name
    strip = track.strips.new(action_name, 1, action)
    strip.action_slot = action.slots[0]
    track.mute = False
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
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
export_result = bpy.ops.export_scene.gltf(
    filepath=GLB_OUT,
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=False,
    export_skins=True,
    export_def_bones=True,
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

# Leave the editable .blend in its clean idle pose with clip strips available
# to unmute in the NLA editor. The exported GLB already contains all nine clips.
for track in anim_data.nla_tracks:
    track.mute = True
anim_data.action = bpy.data.actions["idle-breathe"]
anim_data.action_slot = anim_data.action.slots[0]
rig.show_in_front = False
camera.hide_set(True)
for name in ("Tamamo • Key Softbox", "Tamamo • Fill Softbox"):
    bpy.data.objects[name].hide_set(True)
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = None
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, copy=True, check_existing=False)

print("Tamamo finalized | bones=%d | actions=%s | glTF=%s" % (
    len(rig.data.bones),
    sorted(action.name for action in bpy.data.actions if action.name in {
        "idle-breathe", "idle-fidget", "cast-light", "cast-heavy", "channel", "guard", "hurt", "victory", "death"
    }),
    export_result,
))
