class_name ProgramCycles
extends RefCounted
## Cycles, a program run's money (Paradigm Update, B5): earned for what you kill, by how hard the kill was, and spent at
## the Registry. A kill pays by the kind of fight, the layer and the difficulty; an exact kill, a kill that lands
## before the foe could act, a fight taking no damage and a fight won in one program each add a little. Pure: the
## numbers are data (programs.jsonc `cycles`), and a won fight leaves its itemised receipt (a profiler's `time` output)
## for the reward screen.


## The fight's counters a run needs to price it: set when a program run's fight begins.
static func on_battle_start(state: Dictionary, battle: Dictionary) -> void:
	battle.integrity_start = int(state.integrity)
	battle.kills = {}


## A foe a program broke: `how` is "exact" (no overkill on the killing bolt) or "initiative" (it fell before it acted).
static func mark(battle: Dictionary, uid: String, how: String) -> void:
	var kills: Dictionary = battle.get("kills", {})
	var entry: Dictionary = kills.get(uid, {})
	entry[how] = true
	kills[uid] = entry
	battle.kills = kills


## What a won fight pays: {lines: [{label, amount}], total}. Credits the run (state.cycles).
static func settle(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> Dictionary:
	var rules := _rules(catalog)
	var layer_factors: Array = rules.layer
	var layer_factor := float(layer_factors[mini(int(state.layer), layer_factors.size() - 1)])
	var difficulty_factor := float((rules.difficulty as Dictionary).get(state.difficulty, 1.0))
	var kind := String(battle.kind)
	var foes: Array = battle.foes
	var bodies := foes.filter(func(foe: Dictionary) -> bool: return String(foe.get("owner", "")) == "").size()
	var lines: Array[Dictionary] = []
	var kills: Dictionary = battle.get("kills", {})
	for foe: Dictionary in foes:
		if int(foe.hp) > 0:
			continue
		var summoned := String(foe.get("owner", "")) != ""
		var base := (
			float(rules.base.summoned) if summoned else float(rules.base[kind]) / (bodies if kind == "boss" else 1)
		)
		var worth := maxi(1, floori(ceilf(base) * (1.0 if summoned else layer_factor * difficulty_factor)))
		lines.append({"label": String(foe.name), "kind": "kill", "amount": worth})
		var how: Dictionary = kills.get(foe.uid, {})
		if how.get("exact", false) and not summoned:
			lines.append({"label": "exact", "kind": "bonus", "amount": int(rules.exact)})
		if how.get("initiative", false) and not summoned:
			lines.append({"label": "Initiative", "kind": "bonus", "amount": int(rules.initiative)})
	if int(state.integrity) >= int(battle.get("integrity_start", state.integrity)) and kind != "boss":
		lines.append({"label": "clean build", "kind": "bonus", "amount": int(rules.clean)})
	if int(battle.get("casts", 0)) == 1 and kind != "boss":
		lines.append({"label": "one-liner", "kind": "bonus", "amount": int(rules.one_liner)})
	var kill_pay := int(ProgramRelics.modifiers(state, catalog).kill_cycles)
	if kill_pay > 0:
		var killed := (
			foes
			. filter(func(foe: Dictionary) -> bool: return int(foe.hp) <= 0 and String(foe.get("owner", "")) == "")
			. size()
		)
		if killed > 0:
			lines.append({"label": "Bug Bounty Program", "kind": "bonus", "amount": kill_pay * killed})
	var bounty: Dictionary = battle.get("bounty", {})
	if not bounty.is_empty():
		var met: bool = (
			int(battle.get("casts", 0)) == 1 if bounty.kind == "one-program" else int(battle.get("max_work", 0)) < 512
		)
		if met:
			lines.append({"label": "bounty", "kind": "bonus", "amount": int(bounty.reward)})
	var total := 0
	for line in lines:
		total += int(line.amount)
	earn(state, total)
	return {"lines": lines, "total": total}


## A treasure's cycles, by the layer: `treasure` times the layer's number.
static func treasure(state: Dictionary, catalog: Dictionary) -> int:
	return int(_rules(catalog).treasure) * (int(state.layer) + 1)


## What skipping a card reward pays, by the layer.
static func skip_pay(state: Dictionary, catalog: Dictionary) -> int:
	return int(ProgramRules.config_of(catalog).rewards.skip_cycles) * (int(state.layer) + 1)


static func earn(state: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	state.cycles = int(state.get("cycles", 0)) + amount
	state.cycles_earned = int(state.get("cycles_earned", 0)) + amount


## Spends `amount`; false (and nothing changes) when the run cannot afford it.
static func spend(state: Dictionary, amount: int) -> bool:
	if int(state.get("cycles", 0)) < amount:
		return false
	state.cycles = int(state.cycles) - amount
	state.cycles_spent = int(state.get("cycles_spent", 0)) + amount
	return true


static func _rules(catalog: Dictionary) -> Dictionary:
	return ProgramRules.config_of(catalog).cycles
