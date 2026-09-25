"""The preview look: the game's toon shader (game/characters/toon.gdshader) rebuilt in Eevee, and its ink outline.

Two-tone cel shading from a light fixed in view space (upper left, a little in front), a cool purple shadow tint, a rim
light on the lit side, and an inverted-hull outline. The model's own materials stay plain Principled BSDFs (what the
glTF exporter understands); `toon_everything` swaps in toon copies for a render and `restore` puts the originals back.
"""

from __future__ import annotations

import bpy

LIGHT = (-0.55, 0.65, 0.5)
THRESHOLD, SOFTNESS = 0.1, 0.04
SHADOW_TINT = (0.62, 0.55, 0.78)
RIM = (1.0, 0.86, 0.7)
RIM_STRENGTH, RIM_WIDTH = 0.35, 0.22
INK = (0.13, 0.08, 0.14)


def _srgb(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def _base_colour_socket_source(mat: bpy.types.Material):
    """The Principled BSDF's base colour: either a constant or the node that feeds it (a texture)."""
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    sock = bsdf.inputs["Base Color"]
    if sock.is_linked:
        return sock.links[0].from_socket, None
    return None, tuple(sock.default_value)


def toon_copy(mat: bpy.types.Material) -> bpy.types.Material:
    name = mat.name + " (toon)"
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    toon = mat.copy()
    toon.name = name
    nt = toon.node_tree
    link = nt.links.new
    src, const = _base_colour_socket_source(toon)
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    to_view = nt.nodes.new("ShaderNodeVectorTransform")
    to_view.vector_type = "NORMAL"
    to_view.convert_from = "WORLD"
    to_view.convert_to = "CAMERA"
    link(geo.outputs["Normal"], to_view.inputs["Vector"])
    light = nt.nodes.new("ShaderNodeCombineXYZ")
    # The Vector Transform node's camera space has +z pointing away from the viewer (Godot's view space has it toward
    # the viewer), so the light's z flips.
    for i, v in enumerate((LIGHT[0], LIGHT[1], -LIGHT[2])):
        light.inputs[i].default_value = v
    norm_light = nt.nodes.new("ShaderNodeVectorMath")
    norm_light.operation = "NORMALIZE"
    link(light.outputs[0], norm_light.inputs[0])
    norm_n = nt.nodes.new("ShaderNodeVectorMath")
    norm_n.operation = "NORMALIZE"
    link(to_view.outputs[0], norm_n.inputs[0])
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    link(norm_n.outputs[0], dot.inputs[0])
    link(norm_light.outputs[0], dot.inputs[1])
    lit = nt.nodes.new("ShaderNodeMapRange")
    lit.interpolation_type = "SMOOTHSTEP"
    lit.inputs["From Min"].default_value = THRESHOLD - SOFTNESS
    lit.inputs["From Max"].default_value = THRESHOLD + SOFTNESS
    link(dot.outputs["Value"], lit.inputs["Value"])
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.inputs["A"].default_value = (*_srgb(SHADOW_TINT), 1.0)
    tint.inputs["B"].default_value = (1, 1, 1, 1)
    link(lit.outputs["Result"], tint.inputs["Factor"])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    if src is not None:
        link(src, mul.inputs["A"])
    else:
        mul.inputs["A"].default_value = const
    link(tint.outputs["Result"], mul.inputs["B"])
    # Rim: 1 - (N . V) near the silhouette, only on the lit side.
    facing = nt.nodes.new("ShaderNodeLayerWeight")
    facing.inputs["Blend"].default_value = 0.5
    rim = nt.nodes.new("ShaderNodeMapRange")
    rim.interpolation_type = "SMOOTHSTEP"
    rim.inputs["From Min"].default_value = 1.0 - RIM_WIDTH
    rim.inputs["From Max"].default_value = 1.0
    one_minus = nt.nodes.new("ShaderNodeMath")
    one_minus.operation = "SUBTRACT"
    one_minus.inputs[0].default_value = 1.0
    # Layer Weight's Facing output is 1 - |N.V| already.
    link(facing.outputs["Facing"], rim.inputs["Value"])
    rim_lit = nt.nodes.new("ShaderNodeMath")
    rim_lit.operation = "MULTIPLY"
    link(rim.outputs["Result"], rim_lit.inputs[0])
    link(lit.outputs["Result"], rim_lit.inputs[1])
    rim_amt = nt.nodes.new("ShaderNodeMath")
    rim_amt.operation = "MULTIPLY"
    rim_amt.inputs[1].default_value = RIM_STRENGTH
    link(rim_lit.outputs[0], rim_amt.inputs[0])
    add = nt.nodes.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs["B"].default_value = (*_srgb(RIM), 1.0)
    link(rim_amt.outputs[0], add.inputs["Factor"])
    link(mul.outputs["Result"], add.inputs["A"])
    emit = nt.nodes.new("ShaderNodeEmission")
    link(add.outputs["Result"], emit.inputs["Color"])
    link(emit.outputs["Emission"], out.inputs["Surface"])
    nt.nodes.remove(one_minus)
    return toon


def ink_material() -> bpy.types.Material:
    mat = bpy.data.materials.get("Ink (toon)")
    if mat is None:
        mat = bpy.data.materials.new("Ink (toon)")
        mat.use_nodes = True
        nt = mat.node_tree
        for n in list(nt.nodes):
            if n.type != "OUTPUT_MATERIAL":
                nt.nodes.remove(n)
        emit = nt.nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = (*_srgb(INK), 1.0)
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        nt.links.new(emit.outputs[0], out.inputs["Surface"])
        mat.use_backface_culling = True
    return mat


def toon_everything(objects, outline: float = 0.0022) -> dict:
    """Toon materials and an outline shell on each mesh; returns what `restore` needs."""
    saved = {}
    ink = ink_material()
    for ob in objects:
        if ob.type != "MESH" or not ob.data.materials:
            continue
        saved[ob.name] = [m for m in ob.data.materials]
        for i, m in enumerate(ob.data.materials):
            if m is not None:
                ob.data.materials[i] = toon_copy(m)
        if outline > 0 and not ob.get("no_outline"):
            ob.data.materials.append(ink)
            mod = ob.modifiers.new("Outline", "SOLIDIFY")
            mod.thickness = -outline * float(ob.get("outline_scale", 1.0))
            mod.offset = 1.0
            mod.use_flip_normals = True
            mod.use_rim = False
            mod.material_offset = len(ob.data.materials) - 1
            mod.use_quality_normals = True
    return saved


def restore(objects, saved: dict) -> None:
    for ob in objects:
        if ob.name not in saved:
            continue
        mod = ob.modifiers.get("Outline")
        if mod is not None:
            ob.modifiers.remove(mod)
        # LEARN: slots are put back in place; clearing the list would reset every face's material index to slot 0.
        originals = saved[ob.name]
        while len(ob.data.materials) > len(originals):
            ob.data.materials.pop(index=len(ob.data.materials) - 1)
        for i, m in enumerate(originals):
            ob.data.materials[i] = m
