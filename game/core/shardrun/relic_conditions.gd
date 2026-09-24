class_name RelicConditions
extends RefCounted
## A relic's predicate is content, not a check for one special relic id. Read before any bolts resolve.


static func matches(when: Dictionary, bolt: Dictionary, volley: Array, state: Dictionary) -> bool:
	var battle: Dictionary = state.get("battle", {})
	match when.kind:
		"volley-size":
			return volley.size() >= int(when.min) and volley.size() <= int(when.max)
		"elements":
			var seen := {}
			for other: Dictionary in volley:
				if other.element != "none":
					seen[other.element] = true
			return seen.size() >= int(when.count)
		"element":
			return bolt.element == when.element
		"ward":
			return bolt.ward == when.value
		"pierce":
			return bolt.pierce
		"target":
			return bolt.target == when.target
		"turn":
			return int(battle.get("turn", 0)) >= int(when.min)
		"hurt":
			return float(state.integrity) <= float(state.integrity_max) * float(when.fraction)
		"block":
			return int(battle.get("block", 0)) >= int(when.min)
		"after-ward":
			return not bolt.ward and battle.get("last_cast_ward", false) == true
		"mixed-roles":
			return (
				volley.any(func(b: Dictionary) -> bool: return b.ward)
				and volley.any(func(b: Dictionary) -> bool: return not b.ward)
			)
	return false
