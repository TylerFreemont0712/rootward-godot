"""Turn any rigged character into a skin the move library can play: a clean humanoid skeleton in Godot's profile
names (plus the hair, cloth and accessory chains worth keeping for spring bones), weights folded onto it, and a glTF
with the meshes, their shape keys (expressions) and their textures written out beside it (ADR-0029).

  ~/blender/blender --background <source.blend> --python pipeline/blender/normalize_rig.py -- <map.json>

A production rig has hundreds of deform bones (twist bones, correctives, face bones) and control bones the glTF can
not carry. The map names, for each humanoid bone, the source deform bones whose weights it takes (the first one places
it); `secondary` keeps chains by pattern (`DEF-Hair*`) as they are. Every other weighted bone gives its weight to its
nearest kept ancestor, or failing that the nearest kept bone, so nothing is left unweighted.

The map (JSON): {"armature", "meshes", "out", "humanoid": {"Hips": ["DEF-Spine01"], ...}, "secondary": [...],
"shader": {material name: {"shader": "main" | "face", "textures": {...}}}}. Paths are relative to the repository.
"""

from __future__ import annotations

import fnmatch
import itertools
import json
import shutil
import sys
from pathlib import Path

import addon_utils
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
MAX_INFLUENCES = 4

# Godot's SkeletonProfileHumanoid hierarchy: each bone's parent (the fingers hang from their hand).
PARENT = {
    "Hips": None,
    "Spine": "Hips",
    "Chest": "Spine",
    "UpperChest": "Chest",
    "Neck": "UpperChest",
    "Head": "Neck",
    "LeftEye": "Head",
    "RightEye": "Head",
    "Jaw": "Head",
}
for _side in ("Left", "Right"):
    PARENT.update(
        {
            f"{_side}Shoulder": "UpperChest",
            f"{_side}UpperArm": f"{_side}Shoulder",
            f"{_side}LowerArm": f"{_side}UpperArm",
            f"{_side}Hand": f"{_side}LowerArm",
            f"{_side}UpperLeg": "Hips",
            f"{_side}LowerLeg": f"{_side}UpperLeg",
            f"{_side}Foot": f"{_side}LowerLeg",
            f"{_side}Toes": f"{_side}Foot",
        }
    )
    for _finger, _parts in (
        ("Thumb", ("Metacarpal", "Proximal", "Distal")),
        ("Index", ("Proximal", "Intermediate", "Distal")),
        ("Middle", ("Proximal", "Intermediate", "Distal")),
        ("Ring", ("Proximal", "Intermediate", "Distal")),
        ("Little", ("Proximal", "Intermediate", "Distal")),
    ):
        _previous = f"{_side}Hand"
        for _part in _parts:
            PARENT[f"{_side}{_finger}{_part}"] = _previous
            _previous = f"{_side}{_finger}{_part}"
# The child whose head a bone's tail reaches for (a chain, not a branch).
CHAIN_CHILD = {
    "Hips": "Spine",
    "Spine": "Chest",
    "Chest": "UpperChest",
    "UpperChest": "Neck",
    "Neck": "Head",
}
for _side in ("Left", "Right"):
    CHAIN_CHILD.update(
        {
            f"{_side}Shoulder": f"{_side}UpperArm",
            f"{_side}UpperArm": f"{_side}LowerArm",
            f"{_side}LowerArm": f"{_side}Hand",
            f"{_side}Hand": f"{_side}MiddleProximal",
            f"{_side}UpperLeg": f"{_side}LowerLeg",
            f"{_side}LowerLeg": f"{_side}Foot",
            f"{_side}Foot": f"{_side}Toes",
        }
    )
    for _finger, _parts in (
        ("Thumb", ("Metacarpal", "Proximal", "Distal")),
        ("Index", ("Proximal", "Intermediate", "Distal")),
        ("Middle", ("Proximal", "Intermediate", "Distal")),
        ("Ring", ("Proximal", "Intermediate", "Distal")),
        ("Little", ("Proximal", "Intermediate", "Distal")),
    ):
        for _a, _b in itertools.pairwise(_parts):
            CHAIN_CHILD[f"{_side}{_finger}{_a}"] = f"{_side}{_finger}{_b}"


def log(*args: object) -> None:
    print("[normalize]", *args, flush=True)


def build_skeleton(source: bpy.types.Object, spec: dict) -> tuple[bpy.types.Object, dict[str, str]]:
    """A new armature with the humanoid bones and the kept secondary chains; returns it and source bone -> new bone."""
    world = source.matrix_world
    bones = {b.name: b for b in source.data.bones}
    humanoid: dict[str, list[str]] = spec["humanoid"]
    owner: dict[str, str] = {}
    for target, sources in humanoid.items():
        for name in sources:
            if name not in bones:
                raise SystemExit(f"map: no source bone {name} (for {target})")
            owner[name] = target
    secondary = [b.name for b in source.data.bones if any(fnmatch.fnmatch(b.name, p) for p in spec.get("secondary", []))]
    for name in secondary:
        owner.setdefault(name, name)

    def kept_ancestor(bone: bpy.types.Bone) -> str | None:
        parent = bone.parent
        while parent is not None:
            if parent.name in owner:
                return owner[parent.name]
            parent = parent.parent
        return None

    data = bpy.data.armatures.new("Skin")
    skin = bpy.data.objects.new("Skin", data)
    bpy.context.scene.collection.objects.link(skin)
    bpy.context.view_layer.objects.active = skin
    bpy.ops.object.mode_set(mode="EDIT")
    edit = data.edit_bones
    heads = {t: world @ bones[s[0]].head_local for t, s in humanoid.items()}
    for target, sources in humanoid.items():
        bone = edit.new(target)
        bone.head = heads[target]
        child = CHAIN_CHILD.get(target)
        bone.tail = heads[child] if child in heads else world @ bones[sources[0]].tail_local
        if (bone.tail - bone.head).length < 1e-4:
            bone.tail = bone.head + Vector((0.0, 0.0, 0.02))
    for target in humanoid:
        parent = PARENT.get(target)
        while parent is not None and parent not in humanoid:
            parent = PARENT.get(parent)
        if parent is not None:
            edit[target].parent = edit[parent]
    for name in secondary:
        bone = edit.new(name)
        bone.head = world @ bones[name].head_local
        bone.tail = world @ bones[name].tail_local
    for name in secondary:
        parent = kept_ancestor(bones[name])
        edit[name].parent = edit[parent] if parent else edit["Hips"]
    bpy.ops.object.mode_set(mode="OBJECT")
    log(f"skeleton: {len(humanoid)} humanoid bones, {len(secondary)} secondary")

    # Every other source bone gives its weight to its nearest kept ancestor, or the nearest kept bone.
    heads_new = {b.name: b.head_local for b in data.bones}
    for bone in source.data.bones:
        if bone.name in owner:
            continue
        ancestor = kept_ancestor(bone)
        if ancestor is None:
            here = world @ bone.head_local
            ancestor = min(heads_new, key=lambda n: (heads_new[n] - here).length)
        owner[bone.name] = ancestor
    return skin, owner


def fold_weights(mesh: bpy.types.Object, owner: dict[str, str], skin: bpy.types.Object) -> None:
    groups = {g.index: g.name for g in mesh.vertex_groups}
    folded: list[dict[str, float]] = []
    for vertex in mesh.data.vertices:
        weights: dict[str, float] = {}
        for g in vertex.groups:
            target = owner.get(groups[g.group])
            if target is not None and g.weight > 0.0:
                weights[target] = weights.get(target, 0.0) + g.weight
        top = sorted(weights.items(), key=lambda kv: -kv[1])[:MAX_INFLUENCES]
        total = sum(w for _, w in top)
        folded.append({n: w / total for n, w in top} if total > 0 else {})
    mesh.vertex_groups.clear()
    new = {b.name: mesh.vertex_groups.new(name=b.name) for b in skin.data.bones}
    for index, weights in enumerate(folded):
        for name, weight in weights.items():
            new[name].add([index], weight, "REPLACE")
    empty = sum(1 for w in folded if not w)
    log(f"{mesh.name}: {len(folded)} vertices folded onto {len(new)} bones ({empty} unweighted)")


def write_textures(spec: dict, out_dir: Path) -> dict:
    """Saves each material's images for the game's shader and returns what the shader needs to know."""
    out_dir.mkdir(parents=True, exist_ok=True)
    facts: dict[str, dict] = {}
    for material_name, material_spec in spec.get("shader", {}).items():
        material = bpy.data.materials[material_name]
        entry: dict = {"shader": material_spec["shader"], "textures": {}, "params": {}}
        for role, image_name in material_spec.get("textures", {}).items():
            image = bpy.data.images[image_name]
            path = out_dir / f"{Path(image_name).stem.split('.png')[0]}.png"
            source = Path(bpy.path.abspath(image.filepath)) if image.filepath else None
            if image.packed_file is None and source is not None and source.exists():
                # A file-backed image has no pixels until drawn: copy its file (and point the image at the copy).
                if source.resolve() != path.resolve():
                    shutil.copyfile(source, path)
                image.filepath = str(path)
            else:
                image.filepath_raw = str(path)
                image.file_format = "PNG"
                image.save()
            entry["textures"][role] = path.name
            entry.setdefault("colour", {})[role] = image.colorspace_settings.name == "sRGB"
        for node in material.node_tree.nodes:
            if node.type == "GROUP":
                for socket in node.inputs:
                    if not socket.is_linked and hasattr(socket, "default_value"):
                        value = socket.default_value
                        entry["params"][socket.name] = list(value) if hasattr(value, "__len__") else value
        facts[material_name] = entry
    return facts


def simple_materials(meshes: list[bpy.types.Object], facts: dict) -> None:
    """glTF cannot carry the node shaders: each material becomes its base colour texture (the game re-dresses it)."""
    for mesh in meshes:
        for slot in mesh.material_slots:
            material = slot.material
            texture = facts.get(material.name, {}).get("textures", {}).get("diffuse")
            if texture is None:
                continue
            image = next(i for i in bpy.data.images if i.filepath_raw.endswith(texture))
            material.node_tree.nodes.clear()
            bsdf = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            out = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
            node = material.node_tree.nodes.new("ShaderNodeTexImage")
            node.image = image
            material.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
            material.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])


def import_source(spec: dict) -> None:
    """A map may name a model file to read instead of the .blend Blender opened: an MMD model (.pmx)."""
    pmx = spec.get("import", {}).get("pmx")
    if pmx is None:
        return
    addon_utils.enable("bl_ext.blender_org.mmd_tools", default_set=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj)
    scale = float(spec["import"].get("scale", 0.08))
    bpy.ops.mmd_tools.import_model(filepath=pmx, scale=scale, types={"MESH", "ARMATURE", "MORPHS"})
    log(f"imported {pmx} at scale {scale}")


# LEARN: Guilty Gear Xrd's rule for a drawn look under hard (cel) shading is "control the normals": a normal the
# modeller did not intend makes a blotch. Automated here: the head's normals point out from an ellipsoid round it (the
# face shades as one clean shape, lit or not, like an anime face), and everywhere else each normal is averaged with its
# neighbours' a few times, so small modelled details stop casting speckled shadow.
def anime_normals(mesh: bpy.types.Object, skin: bpy.types.Object, spec: dict) -> None:
    rule = spec.get("normals")
    if not rule:
        return
    data = mesh.data
    n = len(data.vertices)
    positions = np.empty(n * 3)
    data.vertices.foreach_get("co", positions)
    positions = positions.reshape(-1, 3)
    normals = np.empty(n * 3)
    data.vertices.foreach_get("normal", normals)
    normals = normals.reshape(-1, 3)
    edges = np.empty(len(data.edges) * 2, dtype=np.int64)
    data.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    for _ in range(int(rule.get("smooth", 4))):
        summed = normals.copy()
        np.add.at(summed, edges[:, 0], normals[edges[:, 1]])
        np.add.at(summed, edges[:, 1], normals[edges[:, 0]])
        normals = summed / np.maximum(np.linalg.norm(summed, axis=1, keepdims=True), 1e-9)
    head = skin.data.bones.get("Head")
    group = mesh.vertex_groups.get("Head")
    if head is not None and group is not None:
        # The ellipsoid sits on the head bone: centre a little above its head, stretched to the head's proportions.
        world = mesh.matrix_world.inverted() @ skin.matrix_world
        base = world @ head.head_local
        centre = base + Vector(rule.get("head_offset", (0.0, 0.0, 0.07)))
        radii = np.array(rule.get("head_radii", (0.09, 0.1, 0.11)))
        weights = np.zeros(n)
        for vertex in data.vertices:
            for g in vertex.groups:
                if g.group == group.index:
                    weights[vertex.index] = g.weight
        towards = (positions - np.array(centre)) / radii**2
        towards /= np.maximum(np.linalg.norm(towards, axis=1, keepdims=True), 1e-9)
        blend = np.clip((weights - 0.5) * 2.0, 0.0, 1.0)[:, None] * float(rule.get("head_blend", 0.85))
        normals = normals * (1.0 - blend) + towards * blend
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)
        log(f"{mesh.name}: {int((blend[:, 0] > 0).sum())} head vertices turned to the head's ellipsoid")
    data.normals_split_custom_set_from_vertices([tuple(v) for v in normals])
    log(f"{mesh.name}: normals smoothed {int(rule.get('smooth', 4))} times")


def main() -> None:
    spec_path = ROOT / sys.argv[sys.argv.index("--") + 1]
    spec = json.loads(spec_path.read_text())
    import_source(spec)
    source = bpy.data.objects[spec["armature"]]
    source.data.pose_position = "REST"
    bpy.context.view_layer.update()
    meshes = [bpy.data.objects[name] for name in spec["meshes"]]
    skin, owner = build_skeleton(source, spec)
    for mesh in meshes:
        for modifier in list(mesh.modifiers):
            if modifier.type != "ARMATURE":
                mesh.modifiers.remove(modifier)
        armature = next(m for m in mesh.modifiers if m.type == "ARMATURE")
        armature.object = skin
        fold_weights(mesh, owner, skin)
        anime_normals(mesh, skin, spec)
        world = mesh.matrix_world.copy()
        mesh.parent = skin
        mesh.matrix_world = world
    out = ROOT / spec["out"]
    facts = write_textures(spec, out.parent / "textures")
    simple_materials(meshes, facts)
    keep = set(meshes) | {skin}
    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in keep:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_morph=True,
        export_morph_normal=False,
        export_animations=False,
        export_rest_position_armature=True,
        export_def_bones=False,
        export_leaf_bone=False,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_yup=True,
    )
    chains = [b.name for b in skin.data.bones if b.name not in spec["humanoid"] and b.children and (
        b.parent is None or b.parent.name in spec["humanoid"])]
    (out.parent / "skin.json").write_text(
        json.dumps({"model": out.name, "materials": facts, "chains": chains, "rest": spec.get("rest", "A")}, indent=2)
        + "\n"
    )
    log(f"wrote {out.relative_to(ROOT)} ({out.stat().st_size / 1e6:.1f} MB), skin.json with {len(chains)} chains")


main()
