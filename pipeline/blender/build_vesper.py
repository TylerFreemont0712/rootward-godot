"""Build Vesper, the Star-Script Witch, from her concept sheets: body, face, hair, clothes, hat and props as meshes, a
Mixamo-named skeleton with full hands, and weights; saved as the rigged .blend the character pipeline exports.

  ~/blender/blender --background --factory-startup --python pipeline/blender/build_vesper.py -- [--only a,b] [--fresh]

`--only` remeshes just those parts (the rest come from the mesh cache); `--fresh` remeshes everything. The design
numbers live in pipeline/blender/vesper/ (anatomy.py for proportions, one module per costume piece); see
pipeline/characters/vesper/README.md.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

from vesper import blend, book, covered, hair, head, palette, rig, sdf  # noqa: E402
from vesper.parts import PARTS  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / "pipeline" / "cache" / "characters" / "vesper"
CACHE = OUT / "parts"


def log(*args: object) -> None:
    print("[vesper]", *args, flush=True)


def args() -> dict:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    only = set()
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    return {"only": only, "fresh": "--fresh" in argv, "no_rig": "--no-rig" in argv}


def meshed(part, remesh: bool) -> tuple[np.ndarray, np.ndarray]:
    path = CACHE / f"{part.name}.npz"
    if path.exists() and not remesh:
        data = np.load(path)
        return data["verts"], data["quads"]
    t = time.time()
    verts, quads, blocks = sdf.mesh(part.make(), part.voxel)
    CACHE.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(path, verts=verts.astype(np.float32), quads=quads.astype(np.int32))
    log(f"meshed {part.name}: {len(quads)} quads from {blocks} blocks in {time.time() - t:.1f}s")
    return verts, quads


def materials(skin_rgb) -> dict[str, bpy.types.Material]:
    mats = {name: blend.material(name.replace("_", " ").title(), palette.colour(name)) for name in palette.PALETTE}
    mats["skin"] = blend.material("Skin", skin_rgb)
    return mats


def build_parts(opts: dict) -> dict[str, bpy.types.Object]:
    face_img, skin = head.face_texture(ROOT, OUT / "face.png")
    mats = materials(skin)
    mats["face"] = blend.textured_material("Face", face_img, "Face")
    hair_img = blend.image_from_array(
        "VesperHair", hair.hair_texture("#9a5fc0", "#3a2152", "#d7b0ea", "#6e44a0"), OUT / "hair.png"
    )
    mats["hair"] = blend.textured_material("Hair", hair_img, "Hair", "REPEAT")
    pieces: dict[str, list[bpy.types.Object]] = {}
    for part in PARTS:
        remesh = opts["fresh"] or part.name in opts["only"]
        if part.sheet is not None:
            ob = sheet_object(part, mats, remesh)
        else:
            ob = solid_object(part, mats, remesh)
        v = blend.vertices(ob)
        if part.extra.get("face"):
            blend.set_uv(ob, "Face", head.face_uv(v))
        if part.name == "hair":
            blend.set_uv_loops(ob, "Hair", hair.hair_uv(v), wrap_u=True)
        ob.data.shade_smooth()
        ob["part"] = part.name
        pieces.setdefault(part.obj, []).append(ob)
        log(f"{part.name}: {len(ob.data.polygons)} faces -> {part.obj}")
    objects = {}
    for name, obs in pieces.items():
        objects[name] = join(name, obs)
    face_normals(objects["Body"])
    # LEARN: toon shading cuts light from shadow at one threshold, so every small bump in a surface becomes a blotch.
    # Smoothed custom normals keep the silhouette exactly as modelled but let the light follow only the big shapes.
    for name, iterations in (("Mantle", 14), ("Hat", 10), ("Hair", 5), ("Clothes", 4)):
        if name in objects:
            blend.set_custom_normals(objects[name], blend.smoothed_normals(objects[name], iterations))
    return objects


def solid_object(part, mats, remesh: bool) -> bpy.types.Object:
    verts, quads = meshed(part, remesh)
    ob = blend.object_from_mesh(part.name, verts, quads)
    # Materials go on while the mesh is exactly on its surface: which side of a shell a vertex lies on is only certain
    # before smoothing and decimation move it. Face materials survive both.
    if part.label is not None:
        blend.assign_by_vertex(ob, [mats[m] for m in part.materials], part.label(np.asarray(verts, dtype=np.float64)))
    else:
        ob.data.materials.append(mats[part.materials[0]])
    if part.smooth:
        blend.smooth_vertices(ob, 0.5, part.smooth)
    blend.decimate(ob, min(1.0, part.tris / (2.0 * len(quads))))
    return ob


def sheet_object(part, mats, remesh: bool) -> bpy.types.Object:
    """Cloth: the solid's outer face only (the cuts' caps dropped), trim bands as materials, then thickened."""
    sheet = part.sheet()
    part.make = sheet.solid
    verts, quads = meshed(part, remesh)
    verts = np.asarray(verts, dtype=np.float64)
    centres = verts[quads].mean(axis=1)
    keep = sheet.keep(centres)
    # A shape that outgrows its box is closed off by the box's walls; those faces are never cloth.
    margin = 2.0 * part.voxel
    inside_box = np.all((centres > sheet.lo - 0.01 + margin) & (centres < sheet.hi + 0.01 - margin), axis=1)
    if (~inside_box & keep).any():
        log(
            f"{part.name}: dropped {int((~inside_box & keep).sum())} faces on the sampling box's walls (box too small?)"
        )
    keep &= inside_box
    quads, labels = quads[keep], sheet.label(centres[keep])
    used, quads = np.unique(quads, return_inverse=True)
    quads = quads.reshape(-1, 4)
    ob = blend.object_from_mesh(part.name, verts[used], quads)
    for m in part.materials:
        ob.data.materials.append(mats[m])
    ob.data.polygons.foreach_set("material_index", labels.astype(np.int32))
    if part.smooth:
        blend.smooth_interior(ob, 0.5, part.smooth)
    blend.decimate(ob, min(1.0, part.tris / (2.0 * len(quads))))
    blend.thicken(ob, sheet.thickness, sheet.slots)
    return ob


def join(name: str, obs: list[bpy.types.Object]) -> bpy.types.Object:
    """One object from several: a single mesh with the parts' materials, UVs where they had them."""
    target = obs[0]
    if len(obs) > 1:
        # UV maps must match by name to survive a join; parts without the face UV get a zero one.
        uv_names = {uv.name for ob in obs for uv in ob.data.uv_layers}
        for ob in obs:
            for uv in uv_names:
                if uv not in ob.data.uv_layers:
                    ob.data.uv_layers.new(name=uv)
        with bpy.context.temp_override(active_object=target, selected_editable_objects=obs, object=target):
            bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


def face_normals(body_ob: bpy.types.Object) -> None:
    """Custom normals: the face bent toward an ellipsoid's (clean toon light), everything else as modelled."""
    v = blend.vertices(body_ob)
    n = blend.vertex_normals(body_ob)
    near_head = (v[:, 2] > 1.30) & (np.abs(v[:, 0]) < 0.12)
    n2 = n.copy()
    n2[near_head] = head.face_normals(v[near_head], n[near_head])
    blend.set_custom_normals(body_ob, n2)


def rig_up(objects: dict[str, bpy.types.Object]) -> bpy.types.Object:
    t = time.time()
    arm = rig.build_armature()
    origin, axes = book.frame()
    rig.book_bone(arm, origin + axes[:, 1] * (book.H + 0.035) - axes[:, 2] * book.THICK, origin)
    body = objects["Body"]
    rig.heat_weights(body, arm)
    log(f"heat weights: {len(body.vertex_groups)} groups in {time.time() - t:.0f}s")
    for name, smooth in (("Clothes", 1), ("Mantle", 4)):
        if name in objects:
            rig.transfer_weights(body, objects[name], arm, smooth)
    if "Hair" in objects:
        rig.hair_weights(objects["Hair"])
    if "Hat" in objects:
        rig.hat_weights(objects["Hat"], arm)
    if "Book" in objects:
        rig.rigid(objects["Book"], "Book")
    for ob in objects.values():
        rig.limit_and_normalize(ob)
        rig.bind(ob, arm)
    unweighted = {name: _unweighted(ob) for name, ob in objects.items()}
    log(f"rigged in {time.time() - t:.0f}s; vertices without weights: {unweighted}")
    return arm


def hide_covered(body: bpy.types.Object) -> None:
    """Delete the skin that clothes cover for good (after weighting, so the clothes copied weights from all of it)."""
    import bmesh

    v = blend.vertices(body)
    hidden = covered.covered(v)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in np.nonzero(hidden)[0]], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    log(f"hid {int(hidden.sum())} covered body vertices of {len(v)}")


def _unweighted(ob: bpy.types.Object) -> int:
    return sum(1 for v in ob.data.vertices if not any(g.weight > 0 for g in v.groups))


def main() -> None:
    opts = args()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    t = time.time()
    objects = build_parts(opts)
    if not opts["no_rig"]:
        rig_up(objects)
    hide_covered(objects["Body"])
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / ("rigged.blend" if not opts["no_rig"] else "model.blend")
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True)
    log(f"saved {path.relative_to(ROOT)} in {time.time() - t:.0f}s: {', '.join(objects)}")


main()
