class_name ProgramRelics
extends RefCounted
## What a program run's relics do to its programs. The Shardrun's own kinds (block every turn, mana, healing, maximum
## Integrity, a program slot, curses) are applied by the shared rules as they always were; the kinds here are the
## program's: the input a program starts from, what its cards cost and how much work they do, how long foes wait, the
## budget, and what the volley does when it lands. ProgramRules asks for them at each step, the same in a preview as in
## a cast, so a relic never makes the cast differ from what its preview said. An import is a relic for the rest of its
## fight (ADR-0018): its effects count from the program whose top it is written at.


## Every program relic effect the run holds, summed into one Dictionary. Pure: the state and the catalog in, numbers
## out.
static func modifiers(state: Dictionary, catalog: Dictionary) -> Dictionary:
	var m := {
		"seed_bolts": [],
		"seed_power": 0,
		"first_turn_mana": 0,
		"element_power": 0,
		"free_first_work": false,
		"work_factor": 1.0,
		"role_complexity": {},
		"role_cost": {},
		"duplicate_free": false,
		"cron": 0,
		"tempo": 0,
		"budget": 0,
		"budget_factor": 1.0,
		"sorted_landing": 0,
		"mono_element": 1.0,
		"wasted_to_block": 0.0,
		"overkill_flows": false,
		"small_program": [],
		"full_program": 1.0,
		"fast_program": [],
		"jit": false,
		"initiative": 1.0,
		"kill_mana": 0,
		"kill_mana_max": 0,
		"kill_heal": 0,
		"block_per_card": 0,
		"strongest_mult": 1.0,
		"echo": false,
		"all_elements": false,
		"card_cost": {},
		"hooks": [],
		"globals": [],
		"kill_initiative_mana": 0,
		"kill_initiative_max": 0,
		"small_program_work": [],
		"fight_imports": [],
		"full_spread_power": 0,
		"work_power": [],
		"source_power": [],
		"max_bolts": 0,
		"prune_not_timeout": false,
		"timeout_integrity": 0,
		"table": false,
		"table_from": 3,
		"table_divisor": 4,
		"exact_kill_factor": 1,
		"exact_kill_block": 0,
		"index": false,
		"index_size": 8,
		"index_seed": 1,
		"weak_flat_bonus": 0,
		"sorted_strike_power": 0,
		"recurse_depth": 0,
		"rejoin_power": 0,
		"pivot_factor": 1.0,
		"table_best_divisor": 0,
		"index_keep": 0,
		"belt_extra": 0,
		"script_refund": false,
		"shop_discount": 0.0,
		"shop_cards": 0,
		"shop_relics": 0,
		"script_discount": 0.0,
		"kill_cycles": 0,
		"registry_toll": 0,
		"free_refactor": false,
		"sale_free": false,
		"lockfile": false,
		"interest": 0.0,
		"interest_max": 0,
		"deck_mana": [],
		"deck_draw": [],
		"snapshot": false,
		"waive_stakes": false,
		"reward_shift": 0.0,
		"reward_focus": 0.0,
		"table_monotone": false,
		"index_seed_power": 0,
		"timeout_refund": false,
		"first_role_free": [],
		"split_next_work": 1.0,
		"volley_bonus": [],
		"first_program_discount": 0,
		"rest_purge": false,
		"debt_mana": [],
	}
	var shed: bool = (state.get("battle", {}) as Dictionary).get("no_curses", false)
	for relic_id: String in state.get("relics", []):
		var relic: Dictionary = catalog.relics.get(relic_id, {})
		if shed and relic.get("cursed", false):
			continue
		for effect: Dictionary in relic.get("effects", []):
			_apply(m, effect)
	for card_id: String in ProgramDeck.imports(state, catalog):
		for effect: Dictionary in (catalog.shards.get(card_id, {}) as Dictionary).get("effects", []):
			_apply(m, effect, card_id)
	return m


static func _apply(m: Dictionary, effect: Dictionary, source := "") -> void:
	match effect.kind:
		"kill-initiative-mana":
			m.kill_initiative_mana += int(effect.amount)
			m.kill_initiative_max += int(effect.max)
		"small-program-work":
			(m.small_program_work as Array).append(effect)
		"fight-import":
			(m.fight_imports as Array).append(effect.module)
		"full-spread-power", "weak-flat-bonus", "sorted-strike-power", "rejoin-power":
			m[String(effect.kind).replace("-", "_")] += int(effect.add)
		"work-power", "source-power":
			(m[String(effect.kind).replace("-", "_")] as Array).append(effect)
		"max-bolts":
			m.max_bolts = maxi(int(m.max_bolts), int(effect.count))
		"prune-not-timeout":
			m.prune_not_timeout = true
		"timeout-integrity":
			m.timeout_integrity += int(effect.amount)
		"table":
			m.table = true
			m.table_from = int(effect.from)
			m.table_divisor = int(effect.divisor)
		"table-from":
			m.table_from = int(effect.turn)
		"table-divisor":
			m.table_divisor = int(effect.divisor)
		"exact-kill-table":
			m.exact_kill_factor = int(effect.factor)
			m.exact_kill_block += int(effect.block)
		"index":
			m.index = true
			m.index_size = int(effect.size)
			m.index_seed = int(effect.seed)
		"index-size":
			m.index_size = int(effect.size)
		"index-seed":
			m.index_seed = int(effect.count)
		"recurse-depth":
			m.recurse_depth = maxi(int(m.recurse_depth), int(effect.depth))
		"pivot-mark":
			m.pivot_factor *= float(effect.factor)
		"table-best-seed":
			m.table_best_divisor = int(effect.divisor)
		"index-open":
			m.index = true
		"index-size-add":
			m.index_size += int(effect.size)
		"index-keep":
			m.index_keep = maxi(int(m.index_keep), int(effect.count))
		"shop-discount", "script-discount", "reward-share-shift":
			var key: String = String(effect.kind).replace("-", "_")
			m[key if effect.kind != "reward-share-shift" else "reward_shift"] += float(
				effect.get("fraction", effect.get("to_other", 0.0))
			)
		"shop-stock":
			m.shop_cards += int(effect.cards)
			m.shop_relics += int(effect.relics)
		"kill-cycles", "registry-toll", "belt-extra", "first-program-discount", "index-seed-power":
			var key2: String = String(effect.kind).replace("-", "_")
			m[key2 if effect.kind != "belt-extra" else "belt_extra"] += int(effect.get("amount", effect.get("add", 0)))
		"free-refactor", "sale-free", "lockfile", "snapshot", "waive-stakes", "table-monotone", "timeout-refund", "rest-purge", "script-refund":
			m[String(effect.kind).replace("-", "_")] = true
		"interest":
			m.interest = float(effect.fraction)
			m.interest_max = int(effect.max)
		"deck-mana", "deck-draw", "first-role-free", "volley-bonus", "debt-mana":
			(m[String(effect.kind).replace("-", "_")] as Array).append(effect)
		"reward-focus":
			m.reward_focus = maxf(float(m.reward_focus), float(effect.weight))
		"split-next-work":
			m.split_next_work *= float(effect.factor)
		"seed-bolts":
			(m.seed_bolts as Array).append({"count": int(effect.count), "power": int(effect.power)})
		"seed-power", "first-turn-mana", "element-power", "sorted-landing", "block-per-card", "kill-heal":
			var key: String = (effect.kind as String).replace("-", "_")
			m[key] += int(effect.get("add", effect.get("amount", 0)))
		"tempo", "budget":
			m[effect.kind] += int(effect.add)
		"free-first-work", "duplicate-free", "overkill-flows", "jit", "echo", "all-elements":
			m[(effect.kind as String).replace("-", "_")] = true
		"work-factor", "budget-factor", "mono-element", "full-program", "initiative", "strongest-mult":
			var key: String = (effect.kind as String).replace("-", "_")
			m[key] *= float(effect.factor)
		"role-complexity":
			m.role_complexity[effect.role] = effect.complexity
		"role-cost":
			m.role_cost[effect.role] = int(effect.cost)
		"cron":
			m.cron = int(effect.every) if int(m.cron) == 0 else mini(int(m.cron), int(effect.every))
		"wasted-to-block":
			m.wasted_to_block = maxf(float(m.wasted_to_block), float(effect.fraction))
		"small-program":
			(m.small_program as Array).append({"max_cards": int(effect.max_cards), "factor": float(effect.factor)})
		"fast-program":
			(m.fast_program as Array).append({"complexity": effect.complexity, "factor": float(effect.factor)})
		"kill-mana":
			m.kill_mana += int(effect.amount)
			m.kill_mana_max += int(effect.max)
		"card-cost":
			for id: String in effect.cards:
				m.card_cost[id] = int(m.card_cost.get(id, 0)) + int(effect.add)
		"hook-before", "hook-after":
			var when: String = "before" if effect.kind == "hook-before" else "after"
			(m.hooks as Array).append({"card": source, "when": when, "role": effect.role})
		"global":
			if not effect.name in m.globals:
				(m.globals as Array).append(effect.name)


# --- Before the program runs ------------------------------------------------------------------------------------------


## The seed with the relics' input added: stronger seed bolts, and more of them.
static func seed(base: Array, state: Dictionary, catalog: Dictionary) -> Array:
	var m := modifiers(state, catalog)
	var bolts: Array = []
	for bolt: Dictionary in base:
		bolts.append(dict_with(bolt, "power", int(bolt.power) + int(m.seed_power)))
	for extra: Dictionary in m.seed_bolts:
		for i in int(extra.count):
			bolts.append({"power": int(extra.power) + int(m.seed_power), "element": "none"})
	var battle: Dictionary = state.get("battle", {})
	var rows: Array = battle.get("dp", [])
	if m.table and int(battle.get("turn", 1)) >= int(m.table_from) and not rows.is_empty():
		var previous := int(rows.back())
		var before := int(rows[-2]) if rows.size() >= 2 else 0
		bolts.append({"power": (previous + before) / int(m.table_divisor), "element": "none"})
	for kept: Dictionary in battle.get("gc_seed", []):
		bolts.append({"power": int(kept.power), "element": kept.element})
	if int(m.table_best_divisor) > 0 and not rows.is_empty():
		var best := 0
		for row: int in rows:
			best = maxi(best, row)
		if best / int(m.table_best_divisor) > 0:
			bolts.append({"power": best / int(m.table_best_divisor), "element": "none"})
	if m.index:
		var bank: Array = battle.get("index", [])
		for i in mini(int(m.index_seed), bank.size()):
			var kept_bolt: Dictionary = (bank[bank.size() - 1 - i] as Dictionary).duplicate()
			kept_bolt.power = int(kept_bolt.power) + int(m.index_seed_power)
			bolts.append(kept_bolt)
	return bolts


## Mana and cards a big or a small deck brings (Monorepo, Microservices), by the deck's size now.
static func deck_mana(state: Dictionary, m: Dictionary) -> int:
	var total := 0
	for rule: Dictionary in m.deck_mana:
		if (state.get("deck", []) as Array).size() >= int(rule.min_cards):
			total += int(rule.amount)
	return total


static func deck_draw(state: Dictionary, m: Dictionary) -> int:
	var total := 0
	for rule: Dictionary in m.deck_draw:
		if (state.get("deck", []) as Array).size() <= int(rule.max_cards):
			total += int(rule.amount)
	return total


## What a card costs in this program: its own cost, a role's price set by a relic, a second copy made free, or nothing
## at all on a relic's scheduled turn.
static func cost(state: Dictionary, card_ids: Array, catalog: Dictionary) -> int:
	var m := modifiers(state, catalog)
	var turn := int((state.get("battle", {}) as Dictionary).get("turn", 1))
	if int(m.cron) > 0 and turn % int(m.cron) == 0:
		return 0
	var battle: Dictionary = state.get("battle", {})
	if battle.get("free_program", false):
		return 0
	var free: Array = (battle.get("free_cards", []) as Array).duplicate()
	var total := 0
	var seen := {}
	for id: String in card_ids:
		var card: Dictionary = catalog.shards.get(id, {})
		var price := maxi(0, int(card.get("cost", 0)) + int((m.card_cost as Dictionary).get(id, 0)))
		if (m.role_cost as Dictionary).has(card.get("role", "")):
			price = mini(price, int(m.role_cost[card.role]))
		if m.duplicate_free and seen.has(id):
			price = 0
		if id in free:
			free.erase(id)
			price = 0
		seen[id] = true
		total += price
	if (
		int(m.first_program_discount) > 0
		and int(battle.get("turn", 1)) == 1
		and (battle.get("cast", []) as Array).is_empty()
	):
		total = maxi(0, total - int(m.first_program_discount))
	return total


## A card's complexity class in this run: its own, a relic's for its role, or its worst case on the input it gets.
static func complexity(card: Dictionary, input_order: String, m: Dictionary) -> String:
	var worst: Dictionary = card.get("worst_case", {})
	var own: String = card.get("complexity", "linear")
	if not worst.is_empty() and worst.input == input_order:
		own = worst.complexity
	return (m.role_complexity as Dictionary).get(card.get("role", ""), own)


# --- When it lands ----------------------------------------------------------------------------------------------------


## The damage factor for the whole program: small ones, full ones, fast ones and one-element volleys.
static func program_factor(bolts: Array, context: Dictionary, m: Dictionary) -> float:
	var factor := 1.0
	var cards: int = (context.get("cards", []) as Array).size()
	for rule: Dictionary in m.small_program:
		if cards >= 1 and cards <= int(rule.max_cards):
			factor *= float(rule.factor)
	if cards > 0 and cards >= int(context.get("capacity", 0)):
		factor *= float(m.full_program)
	var slowest := ProgramRules.TIER_ORDER.find(String(context.get("speed", "linear")))
	for rule: Dictionary in m.fast_program:
		if slowest <= ProgramRules.TIER_ORDER.find(String(rule.complexity)):
			factor *= float(rule.factor)
	var attacks := bolts.filter(func(bolt: Dictionary) -> bool: return not bolt.get("block", false))
	if not attacks.is_empty():
		var element: String = attacks[0].element
		if element != "none" and attacks.all(func(bolt: Dictionary) -> bool: return bolt.element == element):
			factor *= float(m.mono_element)
	return factor


## The bolts as they land: elemental ones and a sorted volley grow; with a relic that echoes, the volley lands twice.
static func landing(bolts: Array[Dictionary], m: Dictionary) -> Array[Dictionary]:
	var attacks := bolts.filter(func(bolt: Dictionary) -> bool: return not bolt.get("block", false))
	var sorted := true
	for i in range(1, attacks.size()):
		if int(attacks[i].power) < int(attacks[i - 1].power):
			sorted = false
	var out: Array[Dictionary] = []
	for bolt in bolts:
		var power := int(bolt.power)
		if bolt.element != "none":
			power += int(m.element_power)
		if sorted and not bolt.get("block", false):
			power += int(m.sorted_landing)
		out.append(dict_with(bolt, "power", power))
	if m.echo:
		var again: Array[Dictionary] = []
		for bolt in out:
			again.append(bolt.duplicate())
		out.append_array(again)
	return out


## The index of the strongest attacking bolt (the first of equals), or -1: a relic can make that one hit harder.
static func strongest(bolts: Array[Dictionary]) -> int:
	var best := -1
	for i in bolts.size():
		if not bolts[i].get("block", false) and (best < 0 or int(bolts[i].power) > int(bolts[best].power)):
			best = i
	return best


## After a program lands: mana back next turn and Integrity for each foe it broke, block for each card it ran, and the
## cards it ran remembered (a JIT compiler makes them free of work from then on).
static func after_cast(state: Dictionary, battle: Dictionary, card_ids: Array, kills: int, catalog: Dictionary) -> void:
	var m := modifiers(state, catalog)
	if kills > 0 and int(m.kill_mana) > 0:
		var bonus := mini(int(m.kill_mana_max), int(battle.get("bonus_mana", 0)) + kills * int(m.kill_mana))
		battle.bonus_mana = bonus
		var text := "Freed references: %d more mana next turn." % bonus
		Shardrun.record(state, {"kind": "note", "amount": bonus, "text": text})
	if kills > 0 and int(m.kill_heal) > 0:
		var healed := mini(int(state.integrity_max) - int(state.integrity), kills * int(m.kill_heal))
		if healed > 0:
			state.integrity += healed
			Shardrun.record(state, {"kind": "heal", "amount": healed, "text": "Collected: you recover %d." % healed})
	if int(m.block_per_card) > 0 and not card_ids.is_empty():
		var gained := int(m.block_per_card) * card_ids.size()
		battle.block += gained
		Shardrun.record(state, {"kind": "ward", "amount": gained, "text": "Every line ran: %d block." % gained})
	if m.jit:
		var ran: Array = battle.get("ran", [])
		for id: String in card_ids:
			if not id in ran:
				ran.append(id)
		battle.ran = ran


## A fight begins: a relic's extra mana on the first turn.
static func on_battle_start(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> void:
	ProgramCycles.on_battle_start(state, battle)
	ProgramIssues.on_battle_start(state, battle)
	var held := modifiers(state, catalog)
	battle.mana += deck_mana(state, held)
	battle.bonus_draw_now = int(battle.get("bonus_draw_now", 0)) + deck_draw(state, held)
	for debt: Dictionary in held.debt_mana:
		if (int(state.stats.fights) + 1) % int(debt.every) == 0:
			battle.mana = maxi(0, int(battle.mana) - int(debt.amount))
	battle.turn_start_integrity = int(state.integrity)
	# What a B-Tree kept of the last fight's Index starts this one's (ProgramMemory.carry_over).
	var kept: Array = state.get("kept_index", [])
	if not kept.is_empty():
		battle.index = kept.duplicate(true)
		state.kept_index = []
	var m := modifiers(state, catalog)
	var extra := int(m.first_turn_mana)
	if extra > 0:
		battle.mana += extra
	for module: String in m.fight_imports:
		for card: Dictionary in catalog.shards.values():
			if card.get("role") == "import" and card.get("module") == module:
				(battle.imports as Array).append(card.id)
				break


static func dict_with(item: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := item.duplicate()
	copy[key] = value
	return copy
