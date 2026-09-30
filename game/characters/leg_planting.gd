class_name LegPlanting
extends RefCounted
## Feet on the floor for any humanoid skin (ADR-0029). The moves were keyed on one skeleton, so on a skin with other
## leg lengths a planted foot would hover or sink. Each leg gets a TwoBoneIK3D whose target is where the clip plants
## that foot (moves.json `feet`, in hip heights, so scaled to this skin) on this skin's own floor, and whose influence
## follows the clip's plant weight frame by frame (`plant`): 1 while the foot stands, 0 while it jumps or kicks.

const FEET := {"LeftFoot": ["LeftUpperLeg", "LeftLowerLeg"], "RightFoot": ["RightUpperLeg", "RightLowerLeg"]}

var skeleton: Skeleton3D
var _iks := {}
var _height := 1.0
var _floor := {}


static func attach(on: Skeleton3D) -> LegPlanting:
	var legs := LegPlanting.new()
	legs.skeleton = on
	var hips := on.find_bone("Hips")
	legs._height = on.get_bone_global_rest(hips).origin.y if hips >= 0 else 1.0
	for foot: String in FEET:
		var bones: Array = FEET[foot]
		if on.find_bone(foot) < 0 or on.find_bone(bones[0]) < 0 or on.find_bone(bones[1]) < 0:
			return null
		legs._floor[foot] = on.get_bone_global_rest(on.find_bone(foot)).origin.y
		var ik := TwoBoneIK3D.new()
		ik.name = foot + "IK"
		ik.setting_count = 1
		ik.set_root_bone_name(0, bones[0])
		ik.set_middle_bone_name(0, bones[1])
		ik.set_end_bone_name(0, foot)
		var target := Marker3D.new()
		target.name = "Target"
		ik.add_child(target)
		var pole := Marker3D.new()
		pole.name = "Pole"
		ik.add_child(pole)
		ik.set_target_node(0, NodePath("Target"))
		ik.set_pole_node(0, NodePath("Pole"))
		ik.influence = 0.0
		on.add_child(ik)
		legs._iks[foot] = ik
	return legs


## Places the targets and weights for `clip` at `time` (seconds), from its moves.json facts.
func update(facts: Dictionary, time: float) -> void:
	var feet: Dictionary = facts.get("feet", {})
	var plant: Dictionary = facts.get("plant", {})
	for foot: String in _iks:
		var ik: TwoBoneIK3D = _iks[foot]
		var spot: Array = feet.get(foot, [])
		var weights: Array = plant.get(foot, [])
		if spot.size() != 3 or weights.is_empty():
			ik.influence = 0.0
			continue
		var frame := clampi(int(round(time * 30.0)), 0, weights.size() - 1)
		ik.influence = float(weights[frame])
		var local := Vector3(float(spot[0]) * _height, _floor[foot], float(spot[2]) * _height)
		var target: Marker3D = ik.get_node("Target")
		target.global_position = skeleton.global_transform * local
		# The knee bends forward: the pole stands in front of it, at knee height.
		var pole: Marker3D = ik.get_node("Pole")
		pole.global_position = skeleton.global_transform * (local + Vector3(0.0, _height * 0.5, _height * 0.6))
