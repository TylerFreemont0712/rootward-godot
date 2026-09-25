class_name ProgramRules
extends RefCounted
## The Shardrun's programs (ADR-0012): what a cast costs, how much work it does, who acts before it lands, and what
## its bolts do. Pure functions over plain data, like the rest of the rules.
##
## A program is a spell whose shards are program cards (catalog.programs.cards, which a program run's catalog serves
## as `shards`). It starts from the seed volley; each card is a real function run in the sandbox, taking the volley and
## the battle and returning a new one. The rules never trust a number the code computed as damage: they read each
## bolt ({power, element, foe?, block?}), clamp it, and resolve it here.
##
## Work: every stage's complexity applied to the size of the volley it handled (the larger of what it was given and
## what it returned, both measured by the harness). A foe whose tempo is below the program's work acts before the
## program lands. Work above the budget is a timeout: nothing lands.

const TIER_LABELS := {
	"constant": "O(1)",
	"logarithmic": "O(log n)",
	"linear": "O(n)",
	"linearithmic": "O(n log n)",
	"quadratic": "O(n²)",
	"exponential": "O(2ⁿ)",
	"pseudo": "O(n·H)",
}
## Slowest last: a program is as slow as its slowest stage's class.
const TIER_ORDER: Array[String] = [
	"constant", "logarithmic", "linear", "linearithmic", "pseudo", "quadratic", "exponential"
]
## Work never counts past this (an exponential stage on a big volley): far past any budget.
const WORK_CAP := 1 << 30


## A program run's catalog: the program cards served as `shards`, one Program for the deck's spells, the basics as
## its cards, and only the relics that work on programs. Everything else (foes, layers, balance) is the Shardrun's.
static func catalog_for(catalog: Dictionary) -> Dictionary:
	var programs: Dictionary = catalog.programs
	var config: Dictionary = (catalog.config as Dictionary).duplicate()
	var shape: Dictionary = programs.config.program
	config.deck = {
		"spells": [{"name": shape.name, "capacity": int(shape.capacity)}],
		"cards": (programs.config.basics as Array).duplicate(),
	}
	var relics := {}
	for relic_id: String in programs.config.relics:
		if catalog.relics.has(relic_id):
			relics[relic_id] = catalog.relics[relic_id]
	var derived := catalog.duplicate()
	derived.playstyle = "program"
	derived.config = config
	derived.shards = programs.cards
	derived.relics = relics
	return derived


static func config_of(catalog: Dictionary) -> Dictionary:
	return catalog.programs.config


## Work units for a stage of `complexity` over a volley of `n` bolts. `cap_n` caps n (an algorithm that gives up past
## a size); `height` is the H of an O(n·H) table.
static func work_units(complexity: String, n: int, cap_n := 0, height := 1) -> int:
	var size := maxi(0, n)
	if cap_n > 0:
		size = mini(size, cap_n)
	match complexity:
		"constant":
			return 1
		"logarithmic":
			return ceili(JsMath.log2_whole(size + 1))
		"linearithmic":
			return ceili(size * JsMath.log2_whole(size + 1))
		"quadratic":
			return mini(WORK_CAP, size * size)
		"exponential":
			return WORK_CAP if size >= 30 else mini(WORK_CAP, 1 << size)
		"pseudo":
			return mini(WORK_CAP, size * maxi(1, height))
	return size


## Each stage's work from a run's trace ([{shard, given, returned}]): [{card, n, work}], in order.
static func stages(state: Dictionary, trace: Array, catalog: Dictionary) -> Array[Dictionary]:
	var height := front_need(state)
	var out: Array[Dictionary] = []
	for step: Dictionary in trace:
		var card: Dictionary = catalog.shards.get(step.shard, {})
		# LEARN: n is the larger of the volley in and the volley out. A card that turns 7 bolts into 21 pairs did 21
		# pieces of work even though it was handed 7; counting only its input would make growing cards free.
		var n := maxi(int(step.given), int(step.get("returned", step.given)))
		var work := work_units(card.get("complexity", "linear"), n, int(card.get("cap_n", 0)), height)
		out.append({"card": step.shard, "n": n, "given": int(step.given), "work": work})
	return out


static func total_work(stage_list: Array[Dictionary]) -> int:
	var total := 0
	for stage in stage_list:
		total = mini(WORK_CAP, total + int(stage.work))
	return total


## The HP plus shield of the first living foe: the H of an O(n·H) table.
static func front_need(state: Dictionary) -> int:
	for foe: Dictionary in (state.get("battle", {}) as Dictionary).get("foes", []):
		if int(foe.hp) > 0:
			return int(foe.hp) + int(foe.shield)
	return 1


## The slowest complexity class among a program's cards, as its label ("O(n log n)").
static func speed_label(card_ids: Array, catalog: Dictionary) -> String:
	var slowest := 0
	for id: String in card_ids:
		var card: Dictionary = catalog.shards.get(id, {})
		slowest = maxi(slowest, TIER_ORDER.find(card.get("complexity", "linear")))
	return TIER_LABELS[TIER_ORDER[slowest]] if not card_ids.is_empty() else "O(1)"


static func big_o(card: Dictionary) -> String:
	return card.get("big_o", TIER_LABELS.get(card.get("complexity", "linear"), "O(n)"))


## The operations a foe waits before it acts (programs.jsonc `tempo`).
static func tempo_of(foe: Dictionary, catalog: Dictionary) -> int:
	var config := config_of(catalog)
	return int((config.tempo as Dictionary).get(foe.get("id", ""), config.tempo_default))


static func budget(catalog: Dictionary) -> int:
	return int(config_of(catalog).budget)


static func cost_of(spell: Dictionary, catalog: Dictionary) -> int:
	var total := 0
	for id: String in spell.shards:
		total += int((catalog.shards.get(id, {}) as Dictionary).get("cost", 0))
	return total


## The living foes that would act before a program of `work` lands: those whose tempo is below it and that have not
## acted this turn.
static func faster_foes(battle: Dictionary, work: int, catalog: Dictionary) -> Array[Dictionary]:
	var acted: Array = battle.get("acted", [])
	var out: Array[Dictionary] = []
	for foe: Dictionary in battle.foes:
		if int(foe.hp) > 0 and not foe.uid in acted and tempo_of(foe, catalog) < work:
			out.append(foe)
	return out


## What the code panel warns about, by card index: a card that needs a sorted volley after one that left it unsorted.
## The seed is one bolt, so it starts sorted. [{index, message}]
static func lint(card_ids: Array, catalog: Dictionary) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	var order := "sorted"
	var culprit := "the seed"
	for index in card_ids.size():
		var card: Dictionary = catalog.shards.get(card_ids[index], {})
		if card.get("needs", "") == "sorted" and order != "sorted":
			var message := "%s needs a sorted volley, and %s left it unsorted." % [card.get("name", "?"), culprit]
			warnings.append({"index": index, "message": message})
		if card.has("makes"):
			order = card.makes
			culprit = card.get("name", "?")
	return warnings


# --- Casting ----------------------------------------------------------------------------------------------------------


## Casts a program: pay its cards' mana, let faster foes act, then land its bolts (or time out). Returns a refusal
## ({code, message}) or {}.
static func cast(
	state: Dictionary, battle: Dictionary, spell: Dictionary, outcome: Dictionary, catalog: Dictionary
) -> Dictionary:
	var cost := cost_of(spell, catalog)
	if cost > int(battle.mana):
		return {
			"code": "not-enough-mana", "message": "%s needs %d mana and you have %d." % [spell.name, cost, battle.mana]
		}
	if not battle.has("acted"):
		battle.acted = []
	var stage_list := stages(state, outcome.get("work", []), catalog) if outcome.ok else ([] as Array[Dictionary])
	var work := total_work(stage_list)
	battle.mana -= cost
	(battle.cast as Array).append(spell.id)
	battle.casts += 1
	state.stats.casts += 1
	state.stats.mana_spent += cost
	# Faster foes first: each acts once, now, and not again at the end of the turn.
	for foe in faster_foes(battle, work, catalog):
		var text := "%s moves first: %d ops is faster than your %d." % [foe.name, tempo_of(foe, catalog), work]
		Shardrun.record(state, {"kind": "tempo", "foe": foe.uid, "amount": tempo_of(foe, catalog), "text": text})
		(battle.acted as Array).append(foe.uid)
		ShardrunBattle.foe_act(state, battle, foe)
		if int(state.integrity) <= 0:
			ShardrunBattle.lose(state)
			return {}
	if not outcome.ok:
		var crashed := "%s crashes: %s" % [spell.name, outcome.reason]
		Shardrun.record(state, {"kind": "fizzle", "spell": spell.id, "amount": cost, "text": crashed})
		return {}
	var limit := budget(catalog)
	if work > limit:
		var text := "%s runs out of time: %d ops against a budget of %d." % [spell.name, work, limit]
		Shardrun.record(state, {"kind": "timeout", "spell": spell.id, "amount": work, "cost": cost, "text": text})
		return {}
	var bolts := normalize(outcome.bolts, catalog)
	state.stats.bolts += bolts.size()
	var noun := "bolt" if bolts.size() == 1 else "bolts"
	var cast_text := "%s: %d %s, %d ops, %d mana." % [spell.name, bolts.size(), noun, work, cost]
	Shardrun.record(state, {"kind": "cast", "spell": spell.id, "amount": cost, "work": work, "text": cast_text})
	var curse := int(ShardrunRules.relic_modifiers(state, catalog).cast_burn)
	if curse > 0:
		state.integrity = maxi(0, int(state.integrity) - curse)
		Shardrun.record(state, {"kind": "curse", "amount": curse, "text": "The cast burns %d Integrity." % curse})
	var landed := resolve(state, battle, bolts, catalog)
	ShardrunBattle.cast_defense(state, battle, catalog)
	state.stats.damage += int(landed.dealt)
	var by_spell: Dictionary = state.stats.damage_by_spell
	by_spell[spell.id] = int(by_spell.get(spell.id, 0)) + int(landed.dealt)
	state.stats.best_cast = maxi(int(state.stats.best_cast), int(landed.dealt) + int(landed.wasted))
	if int(state.integrity) <= 0:
		ShardrunBattle.lose(state)
	elif (battle.foes as Array).all(func(foe: Dictionary) -> bool: return int(foe.hp) == 0):
		ShardrunBattle.win(state, battle, catalog)
	return {}


## Program output as bolts the rules accept: {power (whole, 0..max_power), element, foe?, block?}, at most max_bolts.
static func normalize(raw: Array, catalog: Dictionary) -> Array[Dictionary]:
	var config := config_of(catalog)
	var out: Array[Dictionary] = []
	for candidate: Variant in raw.slice(0, int(config.max_bolts)):
		if not candidate is Dictionary:
			continue
		var bolt: Dictionary = candidate
		var power: Variant = bolt.get("power", 0)
		var element: Variant = bolt.get("element", "none")
		var clean := {
			"power": clampi(int(power) if (power is int or power is float) else 0, 0, int(config.max_power)),
			"element": element if element in ShardrunSchemas.ELEMENTS else "none",
		}
		var foe: Variant = bolt.get("foe")
		if (foe is int or foe is float) and int(foe) >= 0:
			clean.foe = int(foe)
		if bolt.get("block", false) == true:
			clean.block = true
		out.append(clean)
	return out


## Lands bolts in order. A bolt with `block` shields you; any other flies at the foe its `foe` names (an index into
## the foes alive when the program ran), or at the front foe. Bolts at a foe already down are wasted, as is damage
## past a foe's HP: aiming is what the strike cards are for. Returns {dealt, wasted, block}.
static func resolve(state: Dictionary, battle: Dictionary, bolts: Array[Dictionary], catalog: Dictionary) -> Dictionary:
	var balance: Dictionary = catalog.balance
	var m := ShardrunRules.relic_modifiers(state, catalog)
	var alive := (battle.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0)
	var dealt := 0
	var wasted := 0
	var gathered := 0
	for index in bolts.size():
		var bolt: Dictionary = bolts[index]
		var power := int(bolt.power)
		var shape := {"bolt": index, "target": "front"}
		if bolt.get("block", false):
			battle.block += power
			gathered += power
			var ward := {
				"kind": "ward", "amount": power, "element": bolt.element, "text": "A ward gathers %d block." % power
			}
			ward.merge(shape)
			Shardrun.record(state, ward)
			continue
		if alive.is_empty():
			break
		var at := int(bolt.get("foe", 0))
		var foe: Dictionary = alive[at] if at < alive.size() else alive[0]
		if int(foe.hp) == 0:
			wasted += power
			var gone := {"kind": "wasted", "foe": foe.uid, "amount": power, "element": bolt.element}
			gone.merge(shape)
			gone.text = "%d power flies at %s, already down." % [power, foe.name]
			Shardrun.record(state, gone)
			continue
		var foe_trait: Dictionary = foe.get("trait", {})
		if foe_trait.get("kind") == "nullify-first" and not foe.nullified:
			foe.nullified = true
			var absorb := {"kind": "absorb", "foe": foe.uid, "element": bolt.element}
			absorb.merge(shape)
			absorb.text = "%s swallows the first bolt whole." % foe.name
			Shardrun.record(state, absorb)
			continue
		if foe_trait.get("kind") == "thick-hide" and power < int(foe_trait.threshold):
			var glance := {"kind": "glance", "foe": foe.uid, "element": bolt.element}
			glance.merge(shape)
			glance.text = "A %d-power bolt glances off %s." % [power, foe.name]
			Shardrun.record(state, glance)
			continue
		var multiplier: float = m.damage_multiplier
		if foe_trait.get("kind") == "pattern-ward" and bolt.element != foe.get("pattern"):
			multiplier *= float(balance.pattern_off_multiplier)
		var weak: bool = bolt.element in foe.weak
		var resisted: bool = not weak and bolt.element in foe.resist
		if weak:
			multiplier *= float(balance.weak_multiplier) + m.weak_bonus
		elif resisted:
			multiplier *= float(balance.resist_multiplier)
		var damage := floori(power * multiplier)
		var blocked := mini(int(foe.shield), damage)
		foe.shield -= blocked
		damage -= blocked
		var landed := mini(damage, int(foe.hp))
		wasted += damage - landed
		foe.hp -= landed
		dealt += landed
		var hit := {"kind": "hit", "foe": foe.uid, "amount": landed, "element": bolt.element}
		hit.merge(shape)
		if weak:
			hit.affinity = "weak"
		elif resisted:
			hit.affinity = "resist"
		if blocked > 0:
			hit.blocked = blocked
		if damage > landed:
			hit.overkill = damage - landed
		var shield_note := " (%d into its shield)" % blocked if blocked > 0 else ""
		hit.text = "%s takes %d%s." % [foe.name, landed, shield_note]
		Shardrun.record(state, hit)
		if int(foe.hp) == 0:
			Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})
	return {"dealt": dealt, "wasted": wasted, "block": gathered}


## What casting would do, worked out on a copy of the state: {cost, affordable, work, budget, timeout, speed,
## faster: [foe names], bolts, damage, wasted, block, kills, misfire?}.
static func preview(state: Dictionary, spell_id: String, outcome: Dictionary, catalog: Dictionary) -> Dictionary:
	var battle: Dictionary = state.get("battle", {})
	var spell := Shardrun.spell_by_id(state, spell_id)
	if battle.is_empty() or spell.is_empty():
		return {}
	var cost := cost_of(spell, catalog)
	var stage_list := stages(state, outcome.get("work", []), catalog) if outcome.ok else ([] as Array[Dictionary])
	var work := total_work(stage_list)
	var view := {
		"cost": cost,
		"affordable": not spell.id in battle.cast and cost <= int(battle.mana),
		"work": work,
		"budget": budget(catalog),
		"timeout": work > budget(catalog),
		"speed": speed_label(spell.shards, catalog),
		"faster": faster_foes(battle, work, catalog).map(func(foe: Dictionary) -> String: return foe.name),
		"stages": stage_list,
		"bolts": 0,
		"damage": 0,
		"wasted": 0,
		"block": 0,
		"kills": 0,
	}
	if not outcome.ok:
		view.misfire = outcome.reason
		return view
	if view.timeout:
		return view
	var copy := state.duplicate(true)
	copy.log = []
	var shadow: Dictionary = copy.battle
	var bolts := normalize(outcome.bolts, catalog)
	var before := (shadow.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0).size()
	var landed := resolve(copy, shadow, bolts, catalog)
	view.bolts = bolts.size()
	view.damage = landed.dealt
	view.wasted = landed.wasted
	view.block = landed.block
	view.kills = before - (shadow.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0).size()
	return view
