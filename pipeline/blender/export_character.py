"""Export a rigged character to glTF for Godot: one .glb with the mesh, the skeleton, and every clip as a named animation.

  ~/blender/blender --background pipeline/cache/characters/<id>/rigged.blend \
      --python pipeline/blender/export_character.py -- <id>

Reads `pipeline/characters/<id>/animation.json` (the clips, as ranges of the Mixamo takes on the rig) and writes
`game/characters/<id>/<id>.glb`. Godot imports it on its own; `game/characters/character.gd` puts it on the stage.

- **Clips, not takes.** Each clip (`idle-breathe`, `cast-light`, ...) is baked from its take's frames [first, last] into
  an action of its own, and the exporter slides every action to start at 0. Godot plays them at full frame rate and
  blends between them; the old sprite pipeline's steps and holds (drawings on twos) are not baked in.
- **Colour, packed.** The body's material mixes a base vertex colour with the concept drawing projected through the
  `concept` UV, by a `front` mask (clean.py in the old repo made them). glTF cannot carry a mix node, so the base colour
  goes out as a vertex colour with the mask in its alpha, the drawing as the base colour texture on that UV, and the
  toon shader in Godot mixes them exactly as Blender did. The face keeps the drawing's full resolution.
- **Bones as they are.** Mixamo's names, plus the tail and ears that Godot's spring bones move.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PACKED = "Color"


def log(*args: object) -> None:
    print("[export]", *args, flush=True)


def packed_colour(body: bpy.types.Object) -> None:
    """A point colour attribute: rgb from `base`, alpha from the `front` mask."""
    mesh = body.data
    n = len(mesh.vertices)
    base = np.empty(n * 4, dtype=np.float32)
    front = np.empty(n * 4, dtype=np.float32)
    mesh.attributes["base"].data.foreach_get("color", base)
    mesh.attributes["front"].data.foreach_get("color", front)
    base = base.reshape(-1, 4)
    base[:, 3] = front.reshape(-1, 4)[:, 0]
    if PACKED in mesh.color_attributes:
        mesh.color_attributes.remove(mesh.color_attributes[PACKED])
    packed = mesh.color_attributes.new(PACKED, "FLOAT_COLOR", "POINT")
    packed.data.foreach_set("color", base.ravel())
    mesh.color_attributes.active_color = packed
    log(f"packed colour: {n} vertices, mask mean {base[:, 3].mean():.3f}")


def export_material(body: bpy.types.Object) -> None:
    """A plain material the exporter understands: the drawing as base colour on the `concept` UV."""
    image = next(image for image in bpy.data.images if image.name == "front")
    material = bpy.data.materials.new("Body")
    tree = material.node_tree
    bsdf = next(node for node in tree.nodes if node.type == "BSDF_PRINCIPLED")
    texture = tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    uv = tree.nodes.new("ShaderNodeUVMap")
    uv.uv_map = "concept"
    tree.links.new(uv.outputs["UV"], texture.inputs["Vector"])
    tree.links.new(texture.outputs["Color"], bsdf.inputs["Base Color"])
    body.data.materials.clear()
    body.data.materials.append(material)
    body.data.uv_layers.active = body.data.uv_layers["concept"]


def bake_clips(rig: bpy.types.Object, clips: dict[str, dict]) -> list[str]:
    """One action per clip, baked from its take's frame range; the takes themselves are then dropped."""
    takes = {action.name: action for action in bpy.data.actions}
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    if rig.animation_data is None:
        rig.animation_data_create()
    names = []
    for name, clip in clips.items():
        take = takes.get(clip["take"])
        if take is None:
            raise SystemExit(f"clip {name}: no take {clip['take']} in the file")
        first, last = int(clip["frames"][0]), int(clip["frames"][1])
        rig.animation_data.action = take
        bpy.ops.object.mode_set(mode="POSE")
        bpy.ops.pose.select_all(action="SELECT")
        bpy.ops.nla.bake(
            frame_start=first,
            frame_end=last,
            step=1,
            only_selected=False,
            visual_keying=True,
            clear_constraints=False,
            use_current_action=False,
            bake_types={"POSE"},
        )
        bpy.ops.object.mode_set(mode="OBJECT")
        baked = rig.animation_data.action
        baked.name = name
        baked.use_fake_user = True
        names.append(name)
        log(f"clip {name}: {clip['take']} frames {first}..{last}")
    rig.animation_data.action = None
    for take in takes.values():
        bpy.data.actions.remove(take)
    return names


def main() -> None:
    character = sys.argv[sys.argv.index("--") + 1]
    folder = ROOT / "pipeline" / "characters" / character
    clips = json.loads((folder / "animation.json").read_text())["clips"]
    out = ROOT / "game" / "characters" / character / f"{character}.glb"
    out.parent.mkdir(parents=True, exist_ok=True)

    body = next(o for o in bpy.data.objects if o.type == "MESH")
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    packed_colour(body)
    export_material(body)
    names = bake_clips(rig, clips)

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_def_bones=False,
        export_leaf_bone=False,
        export_rest_position_armature=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_slide_to_zero=True,
        export_force_sampling=True,
        export_frame_step=1,
        export_optimize_animation_size=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_vertex_color="NAME",
        export_vertex_color_name=PACKED,
        export_all_vertex_colors=False,
    )
    log(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size / 1e6:.1f} MB) with clips: {', '.join(names)}")


main()
