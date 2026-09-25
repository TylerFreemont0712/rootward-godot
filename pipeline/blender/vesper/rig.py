"""Vesper's skeleton and skin weights.

The bones use Mixamo's names (`mixamorig:Hips`, `mixamorig:LeftHandIndex1`, ...), as Emberfox's rig does, so the
same takes can be retargeted onto her. Unlike Emberfox she has whole hands: three bones in every finger and the thumb,
plus an end bone for each tip. Extra bones carry what should swing on its own: the hat's cone and star, four hair
locks, and the book at her hip.

Rolls are set so each limb bends about its own X axis: fingers curl toward the palm, elbows and knees fold, the
spine leans forward. Every bone's local Z points at her back of hand, her front, or up, as noted below.

Weights: the body gets Blender's bone-heat weights from the deforming Mixamo bones. Clothes copy the body's weights
from the nearest surface, the hair and the hat follow the head (and their own bones toward their ends), the book
follows its bone.
"""

from __future__ import annotations

import bpy
import numpy as np
from mathutils import Vector

from . import anatomy as A
from . import hat as Ht
from .sdf import normalize

P = "mixamorig:"
MIRROR = np.array([-1.0, 1.0, 1.0])


def _bones() -> list[tuple]:
    """(name, head, tail, parent, z hint, deform)."""
    S = A.SPINE
    fwd = np.array([0.0, -1.0, 0.0])
    up = np.array([0.0, 0.0, 1.0])
    bones = [
        ("Hips", S["hips"], S["spine"], None, fwd, True),
        ("Spine", S["spine"], S["spine1"], "Hips", fwd, True),
        ("Spine1", S["spine1"], S["spine2"], "Spine", fwd, True),
        ("Spine2", S["spine2"], S["neck"], "Spine1", fwd, True),
        ("Neck", S["neck"], S["head"], "Spine2", fwd, True),
        ("Head", S["head"], S["head_top"], "Neck", fwd, True),
        ("HeadTop_End", S["head_top"], S["head_top"] + up * 0.05, "Head", fwd, False),
    ]
    for side, pre in ((1.0, "Left"), (-1.0, "Right")):
        m = MIRROR if side < 0 else np.ones(3)
        arm = {k: v * m for k, v in A.ARM.items()}
        wrist, along, thumb, palm = A.hand_frame(side)
        back = -palm  # the back of the hand: every arm and finger bone's Z points this way
        mid_knuckle = A.finger_joints("Middle", side)[0]
        bones += [
            (f"{pre}Shoulder", arm["clavicle"], arm["shoulder"], "Spine2", up, True),
            (f"{pre}Arm", arm["shoulder"], arm["elbow"], f"{pre}Shoulder", back, True),
            (f"{pre}ForeArm", arm["elbow"], arm["wrist"], f"{pre}Arm", back, True),
            (f"{pre}Hand", arm["wrist"], mid_knuckle, f"{pre}ForeArm", back, True),
        ]
        t = A.thumb_joints(side)
        # The thumb lies turned toward the fingers: its nail faces out to the side, so its Z (and its bend) do too.
        nail = normalize(thumb * 0.75 - palm * 0.65)
        for k in range(3):
            bones.append(
                (f"{pre}HandThumb{k + 1}", t[k], t[k + 1], f"{pre}Hand" if k == 0 else f"{pre}HandThumb{k}", nail, True)
            )
        tip = t[3] + normalize(t[3] - t[2]) * 0.012
        bones.append((f"{pre}HandThumb4", t[3], tip, f"{pre}HandThumb3", nail, False))
        for finger in A.FINGERS:
            j = A.finger_joints(finger, side)
            for k in range(3):
                parent = f"{pre}Hand" if k == 0 else f"{pre}Hand{finger}{k}"
                bones.append((f"{pre}Hand{finger}{k + 1}", j[k], j[k + 1], parent, back, True))
            tip = j[3] + normalize(j[3] - j[2]) * 0.010
            bones.append((f"{pre}Hand{finger}4", j[3], tip, f"{pre}Hand{finger}3", back, False))
        leg = {k: v * m for k, v in A.LEG.items()}
        bones += [
            (f"{pre}UpLeg", leg["hip"], leg["knee"], "Hips", fwd, True),
            (f"{pre}Leg", leg["knee"], leg["ankle"], f"{pre}UpLeg", fwd, True),
            (f"{pre}Foot", leg["ankle"], leg["ball"], f"{pre}Leg", up, True),
            (f"{pre}ToeBase", leg["ball"], leg["toe"], f"{pre}Foot", up, True),
            (f"{pre}Toe_End", leg["toe"], leg["toe"] + np.array([0, -0.025, 0]), f"{pre}ToeBase", up, False),
        ]
    return [(P + n, h, t, (P + par) if par else None, z, d) for n, h, t, par, z, d in bones]


def _extra_bones() -> list[tuple]:
    """Bones that are Vesper's own: hat, hair locks, book. Not Mixamo's, so no prefix."""
    fwd = np.array([0.0, -1.0, 0.0])
    head = P + "Head"
    spine = Ht.cone_spine()
    # The cone's chain: from the band up and over to the tip, four bones.
    idx = np.linspace(12, len(spine) - 1, 5).astype(int)
    bones = [("Hat", Ht.BRIM_ORIGIN, Ht.BRIM_ORIGIN + np.array([0, 0, 0.06]), head, fwd, True)]
    for k in range(4):
        a, b = spine[idx[k], :3], spine[idx[k + 1], :3]
        bones.append((f"HatCone{k + 1}", a, b, "Hat" if k == 0 else f"HatCone{k}", fwd, True))
    tip = spine[-1, :3]
    bones.append(("HatStar", tip, tip + np.array([0.004, 0.0, -0.05]), "HatCone4", fwd, True))
    bones += [
        ("HairFront", np.array([0.0, -0.075, 1.53]), np.array([0.0, -0.098, 1.452]), head, fwd, True),
        ("HairSide.L", np.array([0.095, -0.02, 1.48]), np.array([0.118, -0.03, 1.31]), head, fwd, True),
        ("HairSide.R", np.array([-0.095, -0.02, 1.48]), np.array([-0.118, -0.03, 1.31]), head, fwd, True),
        ("HairBack", np.array([0.0, 0.10, 1.48]), np.array([0.0, 0.125, 1.32]), head, fwd, True),
    ]
    return bones


def build_armature() -> bpy.types.Object:
    arm = bpy.data.armatures.new("Vesper_Rig")
    ob = bpy.data.objects.new("Vesper_Rig", arm)
    bpy.context.scene.collection.objects.link(ob)
    arm.display_type = "OCTAHEDRAL"
    ob.show_in_front = True
    with bpy.context.temp_override(active_object=ob, object=ob, selected_objects=[ob]):
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode="EDIT")
        eb = arm.edit_bones
        for name, head, tail, parent, zhint, deform in _bones() + _extra_bones():
            b = eb.new(name)
            b.head = Vector(tuple(head))
            b.tail = Vector(tuple(tail))
            b.align_roll(Vector(tuple(zhint)))
            b.use_deform = deform
            if parent:
                b.parent = eb[parent]
                b.use_connect = (b.head - eb[parent].tail).length < 1e-5
        bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def mixamo_deform_names(rig: bpy.types.Object) -> list[str]:
    return [b.name for b in rig.data.bones if b.use_deform and b.name.startswith(P)]


def bind(ob: bpy.types.Object, rig: bpy.types.Object) -> None:
    ob.parent = rig
    mod = ob.modifiers.get("Armature") or ob.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    # The outline shell (previews only) must come after the armature.
    while ob.modifiers.find("Armature") > 0:
        with bpy.context.temp_override(object=ob):
            bpy.ops.object.modifier_move_up(modifier="Armature")


def heat_weights(body: bpy.types.Object, rig: bpy.types.Object) -> None:
    """Bone-heat weights from the Mixamo deform bones only (the hat, hair and book bones stay out of the body)."""
    own = [b for b in rig.data.bones if not b.name.startswith(P)]
    saved = {b.name: b.use_deform for b in own}
    for b in own:
        b.use_deform = False
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for b in own:
        b.use_deform = saved[b.name]


def transfer_weights(src: bpy.types.Object, dst: bpy.types.Object, rig: bpy.types.Object, smooth: int = 0) -> None:
    """Copy the body's weights onto clothing from the nearest point of the body's surface."""
    for g in src.vertex_groups:
        if g.name not in dst.vertex_groups:
            dst.vertex_groups.new(name=g.name)
    mod = dst.modifiers.new("Weights", "DATA_TRANSFER")
    mod.object = src
    mod.use_vert_data = True
    mod.data_types_verts = {"VGROUP_WEIGHTS"}
    mod.vert_mapping = "POLYINTERP_NEAREST"
    mod.layers_vgroup_select_src = "ALL"
    mod.layers_vgroup_select_dst = "NAME"
    with bpy.context.temp_override(object=dst, active_object=dst):
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        smooth_weights(dst, smooth)


def smooth_weights(ob: bpy.types.Object, repeat: int, factor: float = 0.5) -> None:
    bpy.context.view_layer.objects.active = ob
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=factor, repeat=repeat)
        bpy.ops.object.mode_set(mode="OBJECT")


def set_weights(ob: bpy.types.Object, weights: dict[str, np.ndarray]) -> None:
    """Replace an object's weights with the given per-vertex arrays (one per bone)."""
    ob.vertex_groups.clear()
    for name, w in weights.items():
        g = ob.vertex_groups.new(name=name)
        for value in np.unique(np.round(w, 3)):
            if value <= 0.001:
                continue
            idx = np.nonzero(np.abs(np.round(w, 3) - value) < 1e-9)[0].tolist()
            g.add(idx, float(value), "REPLACE")


def _segment_weights(v: np.ndarray, segs: list[tuple[np.ndarray, np.ndarray]], falloff: float) -> np.ndarray:
    """Soft nearest-segment weights: each vertex leans on the bones whose segments are closest."""
    d = []
    for a, b in segs:
        ab = b - a
        t = np.clip(((v - a) @ ab) / (ab @ ab), 0, 1)
        d.append(np.linalg.norm(v - (a + np.outer(t, ab)), axis=1))
    d = np.stack(d, axis=1)
    w = np.exp(-(((d - d.min(axis=1, keepdims=True)) / falloff) ** 2))
    return w / w.sum(axis=1, keepdims=True)


def hat_weights(ob: bpy.types.Object, rig: bpy.types.Object) -> None:
    v = np.array([vert.co for vert in ob.data.vertices])
    bones = rig.data.bones
    chain = ["Hat", "HatCone1", "HatCone2", "HatCone3", "HatCone4", "HatStar"]
    segs = [(np.array(bones[n].head_local), np.array(bones[n].tail_local)) for n in chain]
    # The brim, band and crescent are all the hat's root; the cone blends up its chain.
    w = _segment_weights(v, segs, 0.03)
    q = (v - Ht.BRIM_ORIGIN) @ Ht.BRIM_AXES
    low = q[:, 2] < 0.05
    w[low] = 0
    w[low, 0] = 1
    set_weights(ob, dict(zip(chain, w.T)))


def hair_weights(ob: bpy.types.Object) -> None:
    """The hair follows the head, and its locks lean on their own bones more the further they hang."""
    v = np.array([vert.co for vert in ob.data.vertices])
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    hang = np.clip((1.48 - z) / 0.16, 0, 1) ** 1.3
    front = np.clip((-y - 0.04) / 0.04, 0, 1) * (np.abs(x) < 0.07) * np.clip((1.52 - z) / 0.06, 0, 1) ** 1.2
    side_l = hang * np.clip((x - 0.04) / 0.05, 0, 1) * np.clip((0.06 - y) / 0.06, 0, 1)
    side_r = hang * np.clip((-x - 0.04) / 0.05, 0, 1) * np.clip((0.06 - y) / 0.06, 0, 1)
    back = hang * np.clip((y - 0.02) / 0.05, 0, 1)
    own = np.stack([front, side_l, side_r, back], axis=1) * 0.6
    total = own.sum(axis=1)
    scale = np.where(total > 0.6, 0.6 / np.maximum(total, 1e-9), 1.0)
    own *= scale[:, None]
    head = 1.0 - own.sum(axis=1)
    set_weights(
        ob,
        {
            P + "Head": head,
            "HairFront": own[:, 0],
            "HairSide.L": own[:, 1],
            "HairSide.R": own[:, 2],
            "HairBack": own[:, 3],
        },
    )


def rigid(ob: bpy.types.Object, bone: str) -> None:
    ob.vertex_groups.clear()
    g = ob.vertex_groups.new(name=bone)
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")


def book_bone(rig: bpy.types.Object, top: np.ndarray, centre: np.ndarray) -> None:
    with bpy.context.temp_override(active_object=rig, object=rig):
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        b = rig.data.edit_bones.new("Book")
        b.head = Vector(tuple(top))
        b.tail = Vector(tuple(centre))
        b.align_roll(Vector((0.0, -1.0, 0.0)))
        b.parent = rig.data.edit_bones[P + "Hips"]
        bpy.ops.object.mode_set(mode="OBJECT")


def limit_and_normalize(ob: bpy.types.Object, limit: int = 4) -> None:
    """At most four bones per vertex (what glTF carries in one set), summing to one."""
    bpy.context.view_layer.objects.active = ob
    with bpy.context.temp_override(object=ob, active_object=ob):
        bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=limit)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
