"""Build the motion dummy: a plain jointed mannequin on the exact skeleton the move library is keyed on, written as a
normalised skin (`game/characters/dummy/`), so the clips are judged on a body with nothing to hide behind before they
go onto the anime skins (ADR-0030).

  ~/blender/blender --background --python pipeline/blender/build_dummy.py

(Not `--factory-startup`: the base skeleton is read with the VRM extension.)

Every part is a primitive weighted wholly to one bone: tapered limbs between ball joints, a three-piece torso that
shows each spine bend, segmented fingers (the hand poses read), a head with a visor so its facing reads, and the
casting (left) hand in the accent colour. It is written as `dummy.glb` beside a `skin.json` and flat colour textures,
which AnimeSkin dresses in the game's toon shader and ink like any other skin. Its `.import` keeps
`fix_silhouette` off, as the move library's does (the same T-pose skeleton; on, it tips the feet toes-up).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline" / "blender"))

import build_moves  # noqa: E402  (its load_rig names the bones as the move library does)

OUT = ROOT / "game" / "characters" / "dummy"
# name: (lit colour, shade colour), sRGB.
COLOURS = {
    "DummyBody": ((0.86, 0.88, 0.9), (0.5, 0.55, 0.68)),
    "DummyJoint": ((0.3, 0.33, 0.4), (0.62, 0.62, 0.75)),
    "DummyAccent": ((0.36, 0.78, 0.72), (0.45, 0.62, 0.78)),
}
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Little")


def segments(finger: str) -> tuple[str, str, str]:
    return ("Metacarpal", "Proximal", "Distal") if finger == "Thumb" else ("Proximal", "Intermediate", "Distal")


class Parts:
    """Primitives collected into one bmesh, each face tagged with its material and each vertex with its bone."""

    def __init__(self) -> None:
        self.bm = bmesh.new()
        self.groups: list[str] = []
        self.materials = list(COLOURS)
        self.weights = self.bm.verts.layers.int.new("bone")

    def _adopt(self, before: set, bone: str, material: str) -> None:
        """Tags every face made since `before` (a set of the faces there were) and its vertices."""
        if bone not in self.groups:
            self.groups.append(bone)
        index = self.groups.index(bone)
        for f in set(self.bm.faces) - before:
            f.material_index = self.materials.index(material)
            f.smooth = True
            for v in f.verts:
                v[self.weights] = index

    def ball(self, bone: str, at: Vector, radius: float, material: str, scale: Vector | None = None) -> None:
        matrix = Matrix.Translation(at) @ Matrix.Diagonal((*(scale or Vector((1, 1, 1))), 1.0))
        before = set(self.bm.faces)
        bmesh.ops.create_uvsphere(self.bm, u_segments=20, v_segments=12, radius=radius, matrix=matrix, calc_uvs=True)
        self._adopt(before, bone, material)

    def limb(self, bone: str, a: Vector, b: Vector, r1: float, r2: float, material: str = "DummyBody") -> None:
        """A tapered capsule from a to b."""
        axis = b - a
        turn = axis.to_track_quat("Z", "Y").to_matrix().to_4x4()
        matrix = Matrix.Translation((a + b) * 0.5) @ turn
        before = set(self.bm.faces)
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=16, radius1=r1, radius2=r2,
                              depth=axis.length, matrix=matrix, calc_uvs=True)
        self._adopt(before, bone, material)
        self.ball(bone, a, r1, material)
        self.ball(bone, b, r2, material)

    def block(self, bone: str, centre: Vector, x: Vector, y: Vector, z: Vector, material: str) -> None:
        """A box with half-extent vectors x, y, z (any orientation), its edges bevelled soft."""
        matrix = Matrix((
            (x.x, y.x, z.x, centre.x),
            (x.y, y.y, z.y, centre.y),
            (x.z, y.z, z.z, centre.z),
            (0, 0, 0, 1),
        ))
        before = set(self.bm.faces)
        made = bmesh.ops.create_cube(self.bm, size=2.0, matrix=matrix, calc_uvs=True)
        edges = list({e for v in made["verts"] for e in v.link_edges})
        bmesh.ops.bevel(self.bm, geom=list(made["verts"]) + edges, offset=0.3, offset_type="PERCENT", segments=3,
                        affect="EDGES", profile=0.5)
        self._adopt(before, bone, material)


def head_of(armature: bpy.types.Object, bone: str) -> Vector:
    return armature.data.bones[bone].head_local.copy()


def build(armature: bpy.types.Object) -> Parts:
    p = Parts()
    h = lambda bone: head_of(armature, bone)  # noqa: E731
    bones = armature.data.bones
    up = Vector((0, 0, 1))
    # The torso: a pelvis, a waist and a ribcage, each on its own bone, so every bend of the spine shows.
    hips, spine, chest, upper, neck, head = h("Hips"), h("Spine"), h("Chest"), h("UpperChest"), h("Neck"), h("Head")
    legs = (h("LeftUpperLeg") - h("RightUpperLeg")).length
    p.ball("Hips", (hips + spine) * 0.5 + Vector((0, 0, -0.03)), 1.0, "DummyBody", Vector((legs * 0.78, 0.1, 0.1)))
    p.ball("Spine", (spine + chest) * 0.5, 1.0, "DummyJoint", Vector((legs * 0.55, 0.085, 0.07)))
    p.ball("Chest", (chest + upper) * 0.5 + Vector((0, 0, 0.02)), 1.0, "DummyBody",
           Vector((legs * 0.72, 0.1, 0.09)))
    shoulders = (h("LeftUpperArm") - h("RightUpperArm")).length
    p.ball("UpperChest", (upper + neck) * 0.5 + Vector((0, 0.005, -0.01)), 1.0, "DummyBody",
           Vector((shoulders * 0.5, 0.105, 0.085)))
    p.limb("Neck", neck, head, 0.035, 0.035, "DummyJoint")
    # The head: an egg, with a visor across where the eyes are, so its facing reads from any angle.
    tall = 0.24
    p.ball("Head", head + Vector((0, 0.0, tall * 0.45)), 1.0, "DummyBody", Vector((0.092, 0.105, tall * 0.55)))
    p.ball("Head", head + Vector((0, -0.07, tall * 0.42)), 1.0, "DummyAccent", Vector((0.075, 0.045, 0.026)))
    for side in ("Left", "Right"):
        s = side
        p.limb(s + "Shoulder", h(s + "Shoulder"), h(s + "UpperArm"), 0.045, 0.05)
        p.limb(s + "UpperArm", h(s + "UpperArm"), h(s + "LowerArm"), 0.048, 0.04)
        p.ball(s + "LowerArm", h(s + "LowerArm"), 0.043, "DummyJoint")
        p.limb(s + "LowerArm", h(s + "LowerArm"), h(s + "Hand"), 0.038, 0.03)
        hand_colour = "DummyAccent" if side == "Left" else "DummyBody"
        wrist, knuckles = h(s + "Hand"), h(s + "MiddleProximal")
        along = (knuckles - wrist) * 0.5
        palm_normal = Vector((0, 0, -1))
        across = along.cross(palm_normal).normalized() * 0.038
        p.block(s + "Hand", wrist + along * 1.05, along * 1.05, across, palm_normal * 0.014, hand_colour)
        for finger in FINGERS:
            names = [s + finger + part for part in segments(finger)]
            points = [h(n) for n in names]
            last = bones[names[-1]]
            tip = last.tail_local.copy()
            if (tip - points[-1]).length < 0.005:
                tip = points[-1] + (points[-1] - points[-2]) * 0.8
            points.append(tip)
            radius = 0.011 if finger == "Thumb" else 0.009
            for name, a, b in zip(names, points, points[1:]):
                p.limb(name, a, b, radius, radius * 0.9, hand_colour)
        p.limb(s + "UpperLeg", h(s + "UpperLeg"), h(s + "LowerLeg"), 0.075, 0.052)
        p.ball(s + "LowerLeg", h(s + "LowerLeg"), 0.054, "DummyJoint")
        p.limb(s + "LowerLeg", h(s + "LowerLeg"), h(s + "Foot"), 0.05, 0.036)
        # The foot stands on the floor (the skin's sole is at 0; the skeleton's toe joint sits at ankle height above
        # the ball of the foot): a sole from the heel to the ball, an instep from the ankle down to it, toes beyond.
        ankle, ball = h(s + "Foot"), h(s + "Toes")
        forward = Vector((ball.x - ankle.x, ball.y - ankle.y, 0.0)).normalized()
        width = forward.cross(up).normalized()
        heel = Vector((ankle.x, ankle.y, 0.0)) - forward * 0.05
        front = Vector((ball.x, ball.y, 0.0)) + forward * 0.01
        sole = (front - heel) * 0.5
        p.block(s + "Foot", heel + sole + Vector((0, 0, 0.022)), sole, width * 0.042, Vector((0, 0, 0.022)), "DummyBody")
        p.limb(s + "Foot", ankle, Vector((ball.x, ball.y, 0.045)) - forward * 0.02, 0.036, 0.03)
        p.ball(s + "Foot", Vector((heel.x, heel.y, 0.04)) + forward * 0.02, 0.038, "DummyBody")
        toe_tip = front + forward * 0.05
        toe = (toe_tip - front) * 0.5
        p.block(s + "Toes", front + toe + Vector((0, 0, 0.017)), toe, width * 0.04, Vector((0, 0, 0.017)), "DummyJoint")
    return p


def write_texture(name: str, colour: tuple[float, float, float]) -> str:
    image = bpy.data.images.new(name, 4, 4, alpha=True)
    image.colorspace_settings.name = "sRGB"
    image.pixels = [*colour, 1.0] * 16
    path = OUT / "textures" / f"{name.lower()}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    return path.name


def main() -> None:
    armature = build_moves.load_rig()
    for obj in [o for o in bpy.data.objects if o is not armature]:
        bpy.data.objects.remove(obj)
    armature.name = "Skin"
    parts = build(armature)
    mesh = bpy.data.meshes.new("Dummy")
    parts.bm.to_mesh(mesh)
    body = bpy.data.objects.new("Dummy", mesh)
    bpy.context.scene.collection.objects.link(body)
    for name in parts.materials:
        material = bpy.data.materials.new(name)
        material.diffuse_color = (*COLOURS[name][0], 1.0)
        mesh.materials.append(material)
    groups = [body.vertex_groups.new(name=bone) for bone in parts.groups]
    index = mesh.attributes["bone"]
    for vertex, value in zip(mesh.vertices, index.data):
        groups[value.value].add([vertex.index], 1.0, "REPLACE")
    mesh.attributes.remove(mesh.attributes["bone"])
    body.parent = armature
    body.matrix_parent_inverse = armature.matrix_world.inverted()
    body.modifiers.new("Armature", "ARMATURE").object = armature
    for obj in bpy.data.objects:
        obj.select_set(obj in (armature, body))
    bpy.context.view_layer.objects.active = armature
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / "dummy.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_def_bones=False,
        export_leaf_bone=False,
        export_materials="EXPORT",
    )
    skin = {
        "_about": "The motion dummy (pipeline/blender/build_dummy.py): flat colours in the anime toon shader.",
        "model": "dummy.glb",
        "materials": {
            name: {
                "shader": "main",
                "textures": {"diffuse": write_texture(name, lit)},
                "params": {"ShadowColor1": [*shade, 1.0]},
            }
            for name, (lit, shade) in COLOURS.items()
        },
        "style": {"edge": 0.18, "rim": 0.25, "ink_width": 1.4, "ink_tint": [0.08, 0.1, 0.16]},
        "chains": [],
    }
    (OUT / "skin.json").write_text(json.dumps(skin, indent=2) + "\n")
    build_moves.log(f"wrote {out.relative_to(ROOT)} ({len(mesh.vertices)} vertices, {len(parts.groups)} bones)")


if __name__ == "__main__":
    main()
