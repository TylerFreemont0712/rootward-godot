"""Review renders of Vesper's rigged model: a turnaround, close-ups, the skeleton, and pose tests that bend every joint
the game will (fists, a pointing hand, a cast, arms overhead, a stride, a crouch).

  ~/blender/blender --background pipeline/cache/characters/vesper/rigged.blend \
      --python pipeline/blender/render_vesper.py -- [out_dir] [--only name,name]

Writes PNGs into out_dir (default shots/vesper/). Nothing is saved back to the .blend.
"""

from __future__ import annotations

import math
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from vesper import anatomy as A  # noqa: E402
from vesper import preview, shading  # noqa: E402

ROOT = HERE.parents[1]
P = "mixamorig:"


def argv() -> tuple[Path, set[str]]:
    a = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    only = set()
    if "--only" in a:
        only = set(a[a.index("--only") + 1].split(","))
        a = a[: a.index("--only")] + a[a.index("--only") + 2 :]
    out = Path(a[0]) if a else ROOT / "shots" / "vesper"
    return out, only


def meshes() -> list[bpy.types.Object]:
    return [o for o in bpy.data.objects if o.type == "MESH" and not o.name.startswith("BoneViz")]


def the_rig() -> bpy.types.Object:
    return next(o for o in bpy.data.objects if o.type == "ARMATURE")


# ---------------------------------------------------------------- posing


def reset(rig: bpy.types.Object) -> None:
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def turn(rig: bpy.types.Object, bone: str, axis, degrees: float) -> None:
    """Rotate a bone (and everything below it) about an axis given in the armature's space, around its head."""
    pb = rig.pose.bones[bone]
    head = pb.head.copy()
    r = Matrix.Rotation(math.radians(degrees), 4, Vector(axis).normalized())
    pb.matrix = Matrix.Translation(head) @ r @ Matrix.Translation(-head) @ pb.matrix
    bpy.context.view_layer.update()


def curl(rig: bpy.types.Object, bone: str, degrees: float) -> None:
    """Bend a bone about its own X axis (its roll puts X across the joint): negative curls a finger into the palm."""
    pb = rig.pose.bones[bone]
    pb.rotation_mode = "XYZ"
    pb.rotation_euler.x += math.radians(degrees)
    bpy.context.view_layer.update()


def fist(rig, side: str, amount: float = 1.0) -> None:
    for f in ("Index", "Middle", "Ring", "Pinky"):
        for k, deg in enumerate((-78, -98, -62)):
            curl(rig, f"{P}{side}Hand{f}{k + 1}", deg * amount)
    for k, deg in enumerate((-18, -38, -48)):
        curl(rig, f"{P}{side}HandThumb{k + 1}", deg * amount)


def point(rig, side: str) -> None:
    for f in ("Middle", "Ring", "Pinky"):
        for k, deg in enumerate((-80, -100, -60)):
            curl(rig, f"{P}{side}Hand{f}{k + 1}", deg)
    for k, deg in enumerate((-15, -30, -30)):
        curl(rig, f"{P}{side}HandThumb{k + 1}", deg)
    for k in range(3):
        curl(rig, f"{P}{side}HandIndex{k + 1}", 8)


def spread(rig, side: str) -> None:
    for f in ("Index", "Middle", "Ring", "Pinky"):
        for k in range(3):
            curl(rig, f"{P}{side}Hand{f}{k + 1}", 6)


# Directions in the armature's space: x to her left, -y her front, z up. A bone turned about +x by a negative angle
# swings forward (arms raise in front, thighs lift, elbows fold); about +x by a positive angle it swings back (knees).


def pose_cast(rig) -> None:
    """Her right hand thrust out in front, palm open toward the foe; the left drawn back to her side in a fist."""
    turn(rig, P + "RightArm", (1, 0, 0), -78)
    turn(rig, P + "RightArm", (0, 0, 1), -18)
    turn(rig, P + "RightForeArm", (1, 0, 0), -12)
    turn(rig, P + "RightHand", (1, 0, 0), -50)
    spread(rig, "Right")
    turn(rig, P + "LeftArm", (1, 0, 0), 22)
    turn(rig, P + "LeftForeArm", (1, 0, 0), -85)
    fist(rig, "Left")
    turn(rig, P + "Spine1", (0, 0, 1), 12)
    turn(rig, P + "Head", (0, 0, 1), 10)
    turn(rig, P + "RightUpLeg", (1, 0, 0), -16)
    turn(rig, P + "RightLeg", (1, 0, 0), 12)
    turn(rig, P + "LeftUpLeg", (1, 0, 0), 12)


def pose_arms_up(rig) -> None:
    turn(rig, P + "LeftArm", (0, 1, 0), -105)
    turn(rig, P + "RightArm", (0, 1, 0), 105)
    turn(rig, P + "LeftForeArm", (0, 1, 0), -20)
    turn(rig, P + "RightForeArm", (0, 1, 0), 20)
    spread(rig, "Left")
    spread(rig, "Right")
    turn(rig, P + "Head", (1, 0, 0), -12)


def pose_stride(rig) -> None:
    turn(rig, P + "LeftUpLeg", (1, 0, 0), -40)
    turn(rig, P + "LeftLeg", (1, 0, 0), 50)
    turn(rig, P + "LeftFoot", (1, 0, 0), -10)
    turn(rig, P + "RightUpLeg", (1, 0, 0), 22)
    turn(rig, P + "RightLeg", (1, 0, 0), 25)
    turn(rig, P + "Spine", (0, 0, 1), -10)
    turn(rig, P + "LeftArm", (1, 0, 0), 30)
    turn(rig, P + "RightArm", (1, 0, 0), -35)
    turn(rig, P + "RightForeArm", (1, 0, 0), -35)
    turn(rig, P + "LeftForeArm", (1, 0, 0), -15)
    turn(rig, P + "Neck", (0, 0, 1), 15)
    fist(rig, "Left", 0.5)
    fist(rig, "Right", 0.5)


def pose_crouch(rig) -> None:
    for side, s in (("Left", 1), ("Right", -1)):
        turn(rig, f"{P}{side}UpLeg", (1, 0, 0), -80)
        turn(rig, f"{P}{side}UpLeg", (0, 0, 1), 10 * s)
        turn(rig, f"{P}{side}Leg", (1, 0, 0), 125)
        turn(rig, f"{P}{side}Foot", (1, 0, 0), -42)
    turn(rig, P + "Spine", (1, 0, 0), 22)
    turn(rig, P + "Head", (1, 0, 0), -15)
    turn(rig, P + "LeftArm", (1, 0, 0), -45)
    turn(rig, P + "RightArm", (1, 0, 0), -45)
    turn(rig, P + "LeftForeArm", (1, 0, 0), -40)
    turn(rig, P + "RightForeArm", (1, 0, 0), -40)
    # Drop the hips so the soles stay on the floor.
    ev = bpy.context.evaluated_depsgraph_get()
    clothes = bpy.data.objects["Clothes"].evaluated_get(ev)
    low = min((clothes.matrix_world @ v.co).z for v in clothes.data.vertices)
    pb = rig.pose.bones[P + "Hips"]
    m = pb.matrix.copy()
    m.translation.z -= low
    pb.matrix = m
    bpy.context.view_layer.update()


POSES = {"cast": pose_cast, "arms_up": pose_arms_up, "stride": pose_stride, "crouch": pose_crouch}


# ---------------------------------------------------------------- the skeleton, drawn


def bone_viz(rig: bpy.types.Object) -> bpy.types.Object:
    """Octahedral bones as a mesh (a render can't draw armatures): coloured by limb, fingers each their own colour."""
    verts, faces, cols = [], [], []
    palette = {
        "Thumb": (0.95, 0.45, 0.25),
        "Index": (0.95, 0.8, 0.2),
        "Middle": (0.35, 0.8, 0.35),
        "Ring": (0.25, 0.65, 0.95),
        "Pinky": (0.7, 0.4, 0.95),
    }
    for pb in rig.pose.bones:
        b = pb.bone
        h = rig.matrix_world @ pb.head
        t = rig.matrix_world @ pb.tail
        axis = t - h
        length = axis.length
        if length < 1e-5:
            continue
        y = axis.normalized()
        x = (rig.matrix_world.to_3x3() @ pb.matrix.to_3x3() @ Vector((1, 0, 0))).normalized()
        z = y.cross(x)
        w = max(0.12 * length, 0.0032)
        m = h + y * length * 0.1
        base = len(verts)
        verts += [h, m + x * w, m + z * w, m - x * w, m - z * w, t]
        for a, c in ((1, 2), (2, 3), (3, 4), (4, 1)):
            faces.append((base, base + a, base + c))
            faces.append((base + 5, base + c, base + a))
        colour = (0.9, 0.9, 0.9)
        name = b.name.replace(P, "")
        for k, c in palette.items():
            if k in name:
                colour = c
        if not any(k in name for k in palette):
            if name.startswith("Left"):
                colour = (0.3, 0.85, 0.75)
            elif name.startswith("Right"):
                colour = (0.95, 0.4, 0.55)
            elif not b.name.startswith(P):
                colour = (1.0, 0.6, 0.15)
            else:
                colour = (1.0, 0.9, 0.35)
        cols += [colour] * 8
    me = bpy.data.meshes.new("BoneViz")
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    attr = me.color_attributes.new("col", "FLOAT_COLOR", "CORNER")
    flat = []
    for c in cols:
        flat += [c[0], c[1], c[2], 1.0] * 3
    attr.data.foreach_set("color", flat[: len(attr.data) * 4])
    ob = bpy.data.objects.new("BoneViz", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("BoneViz")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = "col"
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    nt.links.new(ca.outputs["Color"], mix.inputs["A"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
    ramp.color_ramp.elements[1].color = (0.45, 0.45, 0.5, 1)
    nt.links.new(lw.outputs["Facing"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], mix.inputs["B"])
    mix.inputs["Factor"].default_value = 1.0
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(mix.outputs["Result"], em.inputs["Color"])
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    me.materials.append(mat)
    ob["no_outline"] = True
    return ob


def ghost(objects) -> dict:
    """Swap every material for a pale see-through one, so the skeleton shows through the body."""
    saved = {}
    mat = bpy.data.materials.get("Ghost") or bpy.data.materials.new("Ghost")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (0.55, 0.55, 0.62, 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = 0.16
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    try:
        mat.surface_render_method = "BLENDED"
    except AttributeError:
        mat.blend_method = "BLEND"
    mat.use_backface_culling = True
    for ob in objects:
        saved[ob.name] = list(ob.data.materials)
        for i in range(len(ob.data.materials)):
            ob.data.materials[i] = mat
    return saved


def unghost(objects, saved) -> None:
    for ob in objects:
        for i, m in enumerate(saved[ob.name]):
            ob.data.materials[i] = m


def weight_map(objects) -> dict:
    """Colour every vertex by the bone that owns most of it: each finger its own hue, darker toward the tip."""
    import colorsys

    finger_hue = {"Thumb": 0.04, "Index": 0.13, "Middle": 0.33, "Ring": 0.58, "Pinky": 0.78}
    saved = {}
    mat = bpy.data.materials.get("WeightMap") or bpy.data.materials.new("WeightMap")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        if n.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(n)
    ca = nt.nodes.new("ShaderNodeVertexColor")
    ca.layer_name = "owner"
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(ca.outputs["Color"], em.inputs["Color"])
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    for ob in objects:
        names = [g.name for g in ob.vertex_groups]
        colours = []
        for name in names:
            short = name.replace(P, "")
            seg = next((int(c) for c in short[-1:] if c.isdigit()), 0)
            hue = next((h for f, h in finger_hue.items() if f in short), None)
            if hue is not None:
                colours.append(colorsys.hsv_to_rgb(hue, 0.85, 1.0 - 0.22 * (seg - 1)))
            else:
                h = (zlib.crc32(short.encode()) % 997) / 997.0  # stable across runs, unlike hash()
                colours.append(colorsys.hsv_to_rgb(h, 0.35, 0.85))
        cols = np.zeros((len(ob.data.vertices), 3))
        for v in ob.data.vertices:
            if v.groups:
                g = max(v.groups, key=lambda e: e.weight)
                cols[v.index] = colours[g.group]
        attr = ob.data.color_attributes.get("owner") or ob.data.color_attributes.new("owner", "FLOAT_COLOR", "POINT")
        rgba = np.concatenate([np.array([shading._srgb(c) for c in cols]), np.ones((len(cols), 1))], axis=1)
        attr.data.foreach_set("color", rgba.astype(np.float32).ravel())
        saved[ob.name] = list(ob.data.materials)
        for i in range(len(ob.data.materials)):
            ob.data.materials[i] = mat
    return saved


# ---------------------------------------------------------------- shots


def main() -> None:
    out, only = argv()
    rig = the_rig()
    obs = meshes()

    def want(name):
        return not only or name in only

    preview.scene_setup(1200, 1600)
    reset(rig)
    shots = []
    if want("turnaround"):
        for name, eye in (
            ("front", (0.0, -4.2, 0.95)),
            ("three_quarter", (2.6, -3.3, 1.05)),
            ("side", (4.2, 0.0, 0.95)),
            ("back", (0.0, 4.2, 0.95)),
            ("three_quarter_back", (-2.7, 3.2, 1.05)),
        ):
            shots.append(
                (preview.look_at("cam_" + name, eye, (0, 0, 0.92), lens=72), out / f"vesper_{name}.png", 1200, 1600)
            )
    if shots:
        preview.toon_render(obs, shots)
    if want("face"):
        # The game draws its ink a fixed number of pixels wide; up close, a world-sized line would be too heavy.
        preview.toon_render(
            obs,
            [
                (
                    preview.look_at("cam_face", (0.12, -0.75, 1.47), (0.0, 0.0, 1.44), lens=85),
                    out / "vesper_face.png",
                    1200,
                    1200,
                ),
                (
                    preview.look_at("cam_face34", (0.5, -0.62, 1.5), (0.03, 0.0, 1.46), lens=85),
                    out / "vesper_face_34.png",
                    1200,
                    1200,
                ),
            ],
            outline=0.0005,
        )

    if want("hands"):
        reset(rig)
        fist(rig, "Left")
        point(rig, "Right")
        wl = A.hand_frame(1.0)[0]
        wr = A.hand_frame(-1.0)[0]
        preview.toon_render(
            obs,
            [
                (
                    preview.look_at(
                        "cam_hl", wl + np.array([0.12, -0.33, 0.05]), wl + np.array([0.03, 0.0, -0.05]), lens=85
                    ),
                    out / "vesper_hand_fist.png",
                    1000,
                    1000,
                ),
                (
                    preview.look_at(
                        "cam_hr", wr + np.array([-0.12, -0.33, 0.05]), wr + np.array([-0.03, 0.0, -0.05]), lens=85
                    ),
                    out / "vesper_hand_point.png",
                    1000,
                    1000,
                ),
            ],
            outline=0.0008,
        )
        reset(rig)
        spread(rig, "Left")
        preview.toon_render(
            obs,
            [
                (
                    preview.look_at(
                        "cam_hs", wl + np.array([0.3, -0.22, 0.02]), wl + np.array([0.04, 0.0, -0.06]), lens=85
                    ),
                    out / "vesper_hand_open.png",
                    1000,
                    1000,
                )
            ],
            outline=0.0008,
        )

    for name, fn in POSES.items():
        if not want(name):
            continue
        reset(rig)
        fn(rig)
        eye = (2.0, -3.6, 1.2) if name != "crouch" else (1.9, -3.3, 0.95)
        target = (0, 0, 0.95) if name == "arms_up" else (0, 0, 0.88 if name != "crouch" else 0.6)
        preview.toon_render(
            obs, [(preview.look_at("cam_pose", eye, target, lens=62), out / f"vesper_pose_{name}.png", 1200, 1600)]
        )

    if want("weights"):
        body = [bpy.data.objects["Body"], bpy.data.objects["Clothes"]]
        others = [o for o in obs if o.name not in ("Body", "Clothes")]
        hidden = {o.name: o.hide_render for o in others}
        for o in others:
            o.hide_render = True
        saved = weight_map(body)
        try:
            for pose_name, fn in (("rest", spread), ("fist", fist)):
                reset(rig)
                fn(rig, "Left")
                wl = A.hand_frame(1.0)[0]
                preview.render(
                    preview.look_at(
                        "cam_wh", wl + np.array([0.13, -0.32, 0.04]), wl + np.array([0.035, 0, -0.055]), lens=85
                    ),
                    out / f"vesper_weights_hand_{pose_name}.png",
                    1000,
                    1000,
                )
            reset(rig)
            preview.render(
                preview.look_at("cam_wb", (0.0, -4.2, 0.95), (0, 0, 0.92), lens=72),
                out / "vesper_weights_body.png",
                1200,
                1600,
            )
        finally:
            unghost(body, saved)
            for o in others:
                o.hide_render = hidden[o.name]

    if want("skeleton"):
        for pose_name, fn in (("rest", None), ("fists", lambda r: (fist(r, "Left"), point(r, "Right")))):
            reset(rig)
            if fn:
                fn(rig)
            viz = bone_viz(rig)
            saved = ghost(obs)
            try:
                if pose_name == "rest":
                    preview.render(
                        preview.look_at("cam_sk", (0, -4.2, 0.95), (0, 0, 0.92), lens=72),
                        out / "vesper_skeleton.png",
                        1200,
                        1600,
                    )
                    preview.render(
                        preview.look_at("cam_sk34", (2.4, -3.3, 1.1), (0, 0, 0.92), lens=72),
                        out / "vesper_skeleton_34.png",
                        1200,
                        1600,
                    )
                wl = A.hand_frame(1.0)[0]
                preview.render(
                    preview.look_at(
                        "cam_skh", wl + np.array([0.1, -0.36, 0.06]), wl + np.array([0.035, 0, -0.05]), lens=85
                    ),
                    out / f"vesper_skeleton_hand_{pose_name}.png",
                    1000,
                    1000,
                )
            finally:
                unghost(obs, saved)
                bpy.data.objects.remove(viz)
    reset(rig)
    print("[render] wrote", out, flush=True)


main()
