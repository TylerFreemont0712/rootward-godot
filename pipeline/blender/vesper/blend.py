"""Small Blender helpers: numpy meshes into objects, materials, collections."""

from __future__ import annotations

import bpy
import numpy as np


def collection(name: str) -> bpy.types.Collection:
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def object_from_mesh(name: str, verts: np.ndarray, faces, col: str = "Vesper", smooth: bool = True) -> bpy.types.Object:
    """A mesh object from vertices and polygons (quads as an (N, 4) array, or a list of index lists)."""
    me = bpy.data.meshes.new(name)
    faces = [list(map(int, f)) for f in faces]
    me.from_pydata([tuple(map(float, v)) for v in verts], [], faces)
    me.validate(clean_customdata=False)
    me.update()
    if smooth:
        me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    collection(col).objects.link(ob)
    return ob


def material(name: str, colour, shadow=None, emission: float = 0.0) -> bpy.types.Material:
    """A flat colour material. The preview look (toon ramp, outline) is added by shading.py; this carries the base colour."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*srgb_to_linear(colour), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.7
    mat.diffuse_color = (*srgb_to_linear(colour), 1.0)
    mat["vesper_colour"] = list(colour)
    return mat


def srgb_to_linear(c):
    c = np.asarray(c[:3], dtype=np.float64)
    if c.max() > 1.0:
        c = c / 255.0
    return tuple(np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4))


def hex_colour(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def assign_by_vertex(ob: bpy.types.Object, mats: list[bpy.types.Material], labels: np.ndarray) -> None:
    """Give each face the material its vertices vote for (labels index into mats)."""
    me = ob.data
    me.materials.clear()
    for m in mats:
        me.materials.append(m)
    loops = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", loops)
    starts = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_start", starts)
    counts = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_total", counts)
    votes = np.zeros((len(me.polygons), len(mats)))
    face_of_loop = np.repeat(np.arange(len(me.polygons)), counts)
    np.add.at(votes, (face_of_loop, labels[loops]), 1)
    me.polygons.foreach_set("material_index", np.argmax(votes, axis=1).astype(np.int32))
    me.update()


def vertices(ob: bpy.types.Object) -> np.ndarray:
    me = ob.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def set_vertices(ob: bpy.types.Object, co: np.ndarray) -> None:
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()


def decimate(ob: bpy.types.Object, ratio: float) -> None:
    """Reduce to `ratio` of the faces, keeping the edges between materials (a trim band's border) where they are."""
    mod = ob.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = ratio
    # Only borders between materials are held; an open edge left dense would fan into long triangles whose normals
    # swing along it, and the thickness added later would follow them unevenly.
    border = material_border_vertices(ob) & ~boundary_vertices(ob)
    if border.any():
        g = ob.vertex_groups.new(name="_border")
        g.add(np.nonzero(border)[0].tolist(), 1.0, "REPLACE")
        mod.vertex_group = g.name
        mod.vertex_group_factor = 50.0
        mod.invert_vertex_group = True
    apply_modifier(ob, mod)
    group = ob.vertex_groups.get("_border")
    if group is not None:
        ob.vertex_groups.remove(group)


def material_border_vertices(ob: bpy.types.Object) -> np.ndarray:
    """Vertices shared by faces of different materials."""
    me = ob.data
    n = len(me.vertices)
    if len(me.materials) < 2:
        return np.zeros(n, dtype=bool)
    loops = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", loops)
    counts = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("loop_total", counts)
    mats = np.empty(len(me.polygons), dtype=np.int64)
    me.polygons.foreach_get("material_index", mats)
    per_loop = np.repeat(mats, counts)
    lo = np.full(n, 1 << 30)
    hi = np.full(n, -1)
    np.minimum.at(lo, loops, per_loop)
    np.maximum.at(hi, loops, per_loop)
    return hi > lo


def apply_modifier(ob: bpy.types.Object, mod) -> None:
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob]):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth_vertices(ob: bpy.types.Object, factor: float = 0.5, repeat: int = 2) -> None:
    mod = ob.modifiers.new("Smooth", "SMOOTH")
    mod.factor = factor
    mod.iterations = repeat
    apply_modifier(ob, mod)


def textured_material(name: str, image: bpy.types.Image, uv_map: str, extension: str = "EXTEND") -> bpy.types.Material:
    """A material whose base colour is `image` on the UV map `uv_map`."""
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.7
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.extension = extension
    uv = nt.nodes.new("ShaderNodeUVMap")
    uv.uv_map = uv_map
    nt.links.new(uv.outputs["UV"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def set_uv(ob: bpy.types.Object, name: str, uv_per_vertex: np.ndarray) -> None:
    """A UV map from one (u, v) per vertex (a projection)."""
    me = ob.data
    layer = me.uv_layers.get(name) or me.uv_layers.new(name=name)
    loops = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", loops)
    layer.data.foreach_set("uv", uv_per_vertex[loops].astype(np.float32).ravel())


def vertex_normals(ob: bpy.types.Object) -> np.ndarray:
    me = ob.data
    n = np.empty(len(me.vertices) * 3)
    me.vertex_normals.foreach_get("vector", n)
    return n.reshape(-1, 3)


def set_custom_normals(ob: bpy.types.Object, normals: np.ndarray) -> None:
    ob.data.normals_split_custom_set_from_vertices([tuple(map(float, n)) for n in normals])


def image_from_array(name: str, rgb: np.ndarray, path) -> bpy.types.Image:
    """A Blender image from an (H, W, 3) sRGB array (row 0 at the bottom), saved as PNG at `path`."""
    h, w = rgb.shape[:2]
    img = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=False)
    img.scale(w, h)
    rgba = np.concatenate([rgb, np.ones((h, w, 1))], axis=-1).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    return img


def set_uv_loops(ob: bpy.types.Object, name: str, uv_per_vertex: np.ndarray, wrap_u: bool = False) -> None:
    """A UV map from one (u, v) per vertex; with `wrap_u`, faces straddling u = 0/1 are mended so none is smeared."""
    me = ob.data
    layer = me.uv_layers.get(name) or me.uv_layers.new(name=name)
    loops = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", loops)
    uv = uv_per_vertex[loops].astype(np.float64)
    if wrap_u:
        starts = np.empty(len(me.polygons), dtype=np.int64)
        counts = np.empty(len(me.polygons), dtype=np.int64)
        me.polygons.foreach_get("loop_start", starts)
        me.polygons.foreach_get("loop_total", counts)
        for s, c in zip(starts, counts):
            us = uv[s : s + c, 0]
            if us.max() - us.min() > 0.5:
                uv[s : s + c, 0] = np.where(us < 0.5, us + 1.0, us)
    layer.data.foreach_set("uv", uv.astype(np.float32).ravel())


def smoothed_normals(ob: bpy.types.Object, iterations: int, cos_limit: float = 0.5) -> np.ndarray:
    """Vertex normals averaged with their neighbours', `iterations` times, never across an edge sharper than
    acos(cos_limit) (a cloth's rim stays crisp). For toon shading: the light's edge follows the big shapes, not every
    small bump of the surface."""
    me = ob.data
    n = vertex_normals(ob)
    edges = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", edges)
    a, b = edges[0::2], edges[1::2]
    for _ in range(iterations):
        ok = (np.einsum("ij,ij->i", n[a], n[b]) > cos_limit)[:, None]
        acc = n.copy()
        np.add.at(acc, a, n[b] * ok)
        np.add.at(acc, b, n[a] * ok)
        n = acc / np.linalg.norm(acc, axis=1, keepdims=True)
    return n


def boundary_vertices(ob: bpy.types.Object) -> np.ndarray:
    """Vertices on an open edge (an edge with one face)."""
    me = ob.data
    counts = np.zeros(len(me.edges), dtype=np.int64)
    edge_index = {tuple(sorted(e.vertices)): e.index for e in me.edges}
    for poly in me.polygons:
        for k in poly.edge_keys:
            counts[edge_index[k]] += 1
    ev = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", ev)
    ev = ev.reshape(-1, 2)[counts == 1]
    mask = np.zeros(len(me.vertices), dtype=bool)
    mask[ev.ravel()] = True
    return mask


def smooth_edges(ob: bpy.types.Object, repeat: int = 10) -> None:
    """Smooth a sheet's open edges along themselves: the voxel staircase of a cut hem becomes a clean line, without
    the hem moving in or out."""
    me = ob.data
    edge_index = {tuple(sorted(e.vertices)): e.index for e in me.edges}
    counts = np.zeros(len(me.edges), dtype=np.int64)
    for poly in me.polygons:
        for k in poly.edge_keys:
            counts[edge_index[k]] += 1
    ev = np.empty(len(me.edges) * 2, dtype=np.int64)
    me.edges.foreach_get("vertices", ev)
    ev = ev.reshape(-1, 2)[counts == 1]
    if not len(ev):
        return
    co = vertices(ob)
    n = len(co)
    for _ in range(repeat):
        acc = np.zeros_like(co)
        deg = np.zeros(n)
        np.add.at(acc, ev[:, 0], co[ev[:, 1]])
        np.add.at(acc, ev[:, 1], co[ev[:, 0]])
        np.add.at(deg, ev[:, 0], 1)
        np.add.at(deg, ev[:, 1], 1)
        on = deg == 2  # plain edge-loop vertices; corners (more neighbours) stay put
        co[on] = 0.5 * co[on] + 0.5 * acc[on] / 2.0
    set_vertices(ob, co)


def smooth_interior(ob: bpy.types.Object, factor: float, repeat: int) -> None:
    """Smooth a sheet without pulling its edges in (the hem stays where it was cut)."""
    smooth_edges(ob)
    inner = ~boundary_vertices(ob)
    g = ob.vertex_groups.new(name="_interior")
    g.add(np.nonzero(inner)[0].tolist(), 1.0, "REPLACE")
    mod = ob.modifiers.new("Smooth", "SMOOTH")
    mod.factor = factor
    mod.iterations = repeat
    mod.vertex_group = g.name
    apply_modifier(ob, mod)
    group = ob.vertex_groups.get("_interior")
    if group is not None:
        ob.vertex_groups.remove(group)


def thicken(ob: bpy.types.Object, thickness: float, slots: int) -> None:
    """Give a sheet its thickness behind its outer face: the inside takes the lining's slots, the edge its own.

    Done by hand rather than with Solidify: the lining is the sheet moved back along smoothed normals, so vertices on
    an open edge move exactly like their neighbours (Solidify's simple mode tilts them along one-sided normals and folds
    the lining out past the hem; its complex mode throws spikes on a reduced mesh). Each open edge gets one rim quad.
    """
    me = ob.data
    co = vertices(ob)
    n = smoothed_normals(ob, 8, cos_limit=-2.0)
    count = len(co)
    polys = [list(p.vertices) for p in me.polygons]
    mats = [p.material_index for p in me.polygons]
    faces = polys + [[k + count for k in reversed(p)] for p in polys]
    face_mats = mats + [m + slots for m in mats]
    directed = [(p[k], p[(k + 1) % len(p)]) for p in polys for k in range(len(p))]
    uses: dict[tuple[int, int], int] = {}
    for a, b in directed:
        key = (a, b) if a < b else (b, a)
        uses[key] = uses.get(key, 0) + 1
    for a, b in directed:
        if uses[(a, b) if a < b else (b, a)] == 1:
            faces.append([b, a, a + count, b + count])
            face_mats.append(2 * slots)
    materials = list(me.materials)
    new = bpy.data.meshes.new(me.name)
    new.from_pydata([tuple(v) for v in np.concatenate([co, co - n * thickness])], [], faces)
    new.update()
    for m in materials:
        new.materials.append(m)
    new.polygons.foreach_set("material_index", np.array(face_mats, dtype=np.int32))
    new.shade_smooth()
    ob.data = new
    bpy.data.meshes.remove(me)
