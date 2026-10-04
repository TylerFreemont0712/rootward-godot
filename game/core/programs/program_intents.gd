class_name ProgramIntents
extends RefCounted
## The public input contract calls all damaging intents 'attack'; damage is per hit, hits is the repetition count.


static func describe(foe: Dictionary, state: Dictionary, catalog: Dictionary) -> Dictionary:
	var intents: Array = foe.get("intents", [])
	var intent: Dictionary = intents[int(foe.get("intent_index", 0)) % intents.size()] if not intents.is_empty() else {}
	var kind := String(intent.get("kind", "idle"))
	var attack := kind in ["strike", "multi", "loop", "count", "throw", "reprint"]
	var damage := int(intent.get("power", 0)) if attack else 0
	var hits := 1 if attack else 0
	var foe_trait: Dictionary = foe.get("trait", {})
	match kind:
		"strike":
			damage *= 2 if foe.get("stoked", false) else 1
		"multi":
			hits = int(intent.get("times", 1))
		"loop":
			hits = int(foe.get("loop", intent.get("start", 1)))
		"count":
			damage *= 1 << int(foe.get("counted", 0))
			if damage >= int(intent.get("wrap", 256)):
				damage = 0
		"throw":
			damage += int(foe.get("trace", 0))
		"reprint":
			hits = mini(int(foe.get("echo", {}).get("bolts", 0)), int(intent.get("max", 0)))
	if kind in ["strike", "multi"] and foe.get("enraged", false):
		damage = floori(damage * float(foe_trait.get("enrage", 1.0)))
	if foe.get("stunned", false) or foe.get("recompiling", false):
		damage = 0
	if foe_trait.get("kind", "") == ProgramGuardians.PAGED and not foe.get("resident", false) and kind != "reprint":
		damage = 0
	return {
		"kind": "attack" if attack else kind,
		"damage": damage,
		"hits": hits,
		"tempo": ProgramRules.tempo_of(foe, state, catalog)
	}
