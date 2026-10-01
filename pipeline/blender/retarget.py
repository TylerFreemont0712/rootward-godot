"""Motion capture retargeted onto the move library's skeleton (ADR-0030).

A source (`pipeline/moves/sources.json`) is a glTF of clips on its own skeleton. Both skeletons are first matched in a
T-pose: the source at a reference frame where it stands in one, ours at its rest (a VRM rests in a T-pose). From then
on each bone copies the source bone's turn *away from its T-pose*, in world space:

    ours(t) = theirs(t) · theirs(T-pose)⁻¹ · ours(T-pose)

so it does not matter that the two skeletons' bones point along different local axes. The hips also copy the source
pelvis's travel, scaled by the ratio of the two hip heights. The result is each bone's pose (basis) relative to its
rest, which build_moves.py then layers its own keys on, plants the feet under and keys.
"""

from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / "pipeline" / "moves" / "sources.json"


def load_all(target: bpy.types.Object, names: set[str]) -> dict[str, "Source"]:
    facts = json.loads(SOURCES.read_text())
    return {name: Source(name, facts[name], target) for name in names}


class Source:
    def __init__(self, name: str, facts: dict, target: bpy.types.Object) -> None:
        self.name = name
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT / facts["file"]))
        made = [o for o in bpy.data.objects if o not in before]
        self.armature = next(o for o in made if o.type == "ARMATURE")
        for obj in made:
            if obj is not self.armature:
                bpy.data.objects.remove(obj)
        self.armature.name = f"Source_{name}"
        # LEARN: the importer turns a clip's seconds into frames with the scene's frame rate at the moment of import,
        # so that rate (not the file's) is what turns a time back into a frame.
        scene = bpy.context.scene
        self.fps = scene.render.fps / scene.render.fps_base
        self.map: dict[str, str] = {ours: theirs for ours, theirs in facts["map"].items() if theirs in self.armature.pose.bones}
        self.hips = facts["hips"]
        self.target = target
        reference = facts["reference"]
        self._pose_at(reference["action"], float(reference.get("time", 0.0)))
        self.reference_inverse = {ours: self._turn(theirs).inverted() for ours, theirs in self.map.items()}
        self.reference_hips = self._place(self.hips)
        world = target.matrix_world
        self.target_turn_inverse = world.to_3x3().normalized().inverted()
        self.rest_world = {
            b.name: (world @ b.matrix_local).to_3x3().normalized() for b in target.data.bones if b.name in self.map
        }
        target_hips = (world @ target.data.bones["Hips"].matrix_local).translation.z
        self.scale = target_hips / max(self.reference_hips.z, 1e-4)
        self.order = sorted(target.data.bones, key=lambda b: len(b.parent_recursive))

    def _pose_at(self, action: str, seconds: float) -> None:
        act = bpy.data.actions[action]
        data = self.armature.animation_data_create()
        data.action = act
        if getattr(act, "slots", None):
            data.action_slot = act.slots[0]
        frame = seconds * self.fps
        bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))

    def _turn(self, bone: str) -> Matrix:
        return (self.armature.matrix_world @ self.armature.pose.bones[bone].matrix).to_3x3().normalized()

    def _place(self, bone: str) -> Vector:
        return (self.armature.matrix_world @ self.armature.pose.bones[bone].matrix).translation.copy()

    def length(self, action: str) -> float:
        start, end = bpy.data.actions[action].frame_range
        return (end - start) / self.fps

    def basis(self, action: str, seconds: float) -> dict[str, tuple[Quaternion, Vector]]:
        """Each of our bones' pose relative to its rest (rotation, and the hips' travel), at `seconds` into `action`."""
        self._pose_at(action, seconds)
        turns = {ours: self._turn(theirs) for ours, theirs in self.map.items()}
        hips = self._place(self.hips)
        poses: dict[str, Matrix] = {}
        out: dict[str, tuple[Quaternion, Vector]] = {}
        for bone in self.order:
            rest = bone.matrix_local
            if bone.parent is not None:
                carried = poses[bone.parent.name] @ bone.parent.matrix_local.inverted() @ rest
            else:
                carried = rest.copy()
            if bone.name not in turns:
                poses[bone.name] = carried
                continue
            world = turns[bone.name] @ self.reference_inverse[bone.name] @ self.rest_world[bone.name]
            posed = Matrix.Translation(carried.translation) @ (self.target_turn_inverse @ world).to_4x4()
            if bone.name == "Hips":
                travel = self.target_turn_inverse @ ((hips - self.reference_hips) * self.scale)
                posed.translation = rest.translation + travel
            basis = carried.inverted() @ posed
            out[bone.name] = (basis.to_quaternion(), basis.translation.copy())
            poses[bone.name] = posed
        return out


def blend(poses: list[tuple[dict[str, tuple[Quaternion, Vector]], float]]) -> dict[str, tuple[Quaternion, Vector]]:
    """Several takes' poses mixed by their weights (which add up to 1): turns slerped, travel mixed."""
    out: dict[str, tuple[Quaternion, Vector]] = {}
    total = 0.0
    for pose, weight in poses:
        if weight <= 0.0:
            continue
        total += weight
        share = weight / total
        for bone, (turn, travel) in pose.items():
            if bone not in out:
                out[bone] = (turn.copy(), travel.copy())
                continue
            before, moved = out[bone]
            out[bone] = (before.slerp(turn, share), moved.lerp(travel, share))
    return out
