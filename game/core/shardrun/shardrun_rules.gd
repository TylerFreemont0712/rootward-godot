class_name ShardrunRules
extends RefCounted
## The Shardrun numbers the engine, the views and the code view share (old ADR-0012 to ADR-0016): what relics add, what
## a cast costs, what a shard's bolts are allowed to be. Pure functions of a state and a catalog.
##
## A catalog is {config, shards: {id: shard}, foes: {id: foe}, relics: {id: relic}, balance} with content in its
## file shape (snake_case, schema defaults applied); see ShardrunCatalog for loading one.

const ELEMENTS: Array[String] = ["none", "fire", "frost", "spark"]
const TARGETS: Array[String] = ["front", "back", "weakest", "strongest", "all"]
const SHARD_RARITIES: Array[String] = ["common", "uncommon", "rare"]
const RELIC_RARITIES: Array[String] = ["common", "uncommon", "rare", "boss"]
## Cheapest first: the smaller index always wins, so two ledgers never stack.
const WORK_CURVES: Array[String] = ["log", "sqrt", "linear"]
const BOLT_KEYS: Array[String] = ["power", "element", "target", "pierce", "ward", "mult"]


static func difficulty_of(catalog: Dictionary, id: String) -> Dictionary:
	var difficulties: Array = catalog.config.difficulties
	for difficulty: Dictionary in difficulties:
		if difficulty.id == id:
			return difficulty
	return difficulties[0]


static func layer_of(state: Dictionary, catalog: Dictionary) -> Dictionary:
	var layers: Array = catalog.config.layers
	var index := int(state.layer)
	return layers[index] if index < layers.size() else layers[-1]


## Run-wide changes from the relics held, summed in the order they were claimed.
static func relic_modifiers(state: Dictionary, catalog: Dictionary) -> Dictionary:
	var m := {
		"conditional_mult": [],
		"retain_block": 0.0,
		"cast_block": 0,
		"cast_burn": 0,
		"turn_burn": 0,
		"cost_tax": 0,
		"bolt_power": 0.0,
		"bolt_mult": 0.0,
		"bolt_mult_factor": 1.0,
		"mult_per_cast": 0.0,
		"damage_multiplier": 1.0,
		"weak_bonus": 0.0,
		"mana_per_turn": 0,
		"first_cast_discount": 0,
		"turn_block": 0,
		"heal_after_fight": 0,
		"bolt_cap": 0,
		"work_curve": catalog.balance.work_billing.curve,
		"hand_size": 0,
		"hold": 0,
		"opening_draw": 0,
		"draw_on_cast": [],
		"reshuffle_block": 0,
		"small_deck_power": [],
	}
	for relic_id: String in state.relics:
		var relic: Dictionary = catalog.relics.get(relic_id, {})
		for effect: Dictionary in relic.get("effects", []):
			_apply_effect(m, effect)
	return m


static func _apply_effect(m: Dictionary, effect: Dictionary) -> void:
	match effect.kind:
		"conditional-mult":
			(m.conditional_mult as Array).append(effect)
		"retain-block":
			m.retain_block = maxf(m.retain_block, effect.fraction)
		"cast-block", "cast-burn", "turn-burn", "cost-tax", "first-cast-discount", "turn-block", "heal-after-fight":
			var key: String = (effect.kind as String).replace("-", "_")
			m[key] += int(effect.amount)
		"reshuffle-block":
			m.reshuffle_block += int(effect.amount)
		"bolt-power", "bolt-mult", "mult-per-cast", "weak-bonus":
			var key: String = (effect.kind as String).replace("-", "_")
			m[key] += float(effect.add)
		"mana-per-turn", "bolt-cap", "hand-size", "hold", "opening-draw":
			var key: String = (effect.kind as String).replace("-", "_")
			m[key] += int(effect.add)
		"bolt-mult-factor":
			m.bolt_mult_factor *= float(effect.factor)
		"damage-multiplier":
			m.damage_multiplier *= float(effect.factor)
		"work-billing":
			if WORK_CURVES.find(effect.curve) < WORK_CURVES.find(m.work_curve):
				m.work_curve = effect.curve
		"draw-on-cast":
			(m.draw_on_cast as Array).append({"min_cards": int(effect.min_cards), "draw": int(effect.draw)})
		"small-deck-power":
			(m.small_deck_power as Array).append({"below": int(effect.below), "per_card": int(effect.per_card)})
		_:
			pass  # spell-capacity, max-integrity, spell-slot, add-cards: applied once, when the relic is claimed.


## Mana a turn gives: the base, more for every layer descended, and what relics add (old ADR-0015). A deck run has its
## own, smaller income (old ADR-0020).
static func mana_per_turn(state: Dictionary, catalog: Dictionary) -> int:
	var income: Dictionary = catalog.balance.deck.mana_per_turn if _is_deck(state) else catalog.balance.mana_per_turn
	var bonus: int = relic_modifiers(state, catalog).mana_per_turn
	return maxi(1, int(income.base) + int(income.per_layer) * int(state.layer) + bonus)


static func hand_size(state: Dictionary, catalog: Dictionary) -> int:
	return int(catalog.balance.deck.hand_size) + int(relic_modifiers(state, catalog).hand_size)


static func hold_limit(state: Dictionary, catalog: Dictionary) -> int:
	return int(catalog.balance.deck.hold) + int(relic_modifiers(state, catalog).hold)


## Power relics add to every bolt: flat bonuses, and in a deck run a bonus for every card the deck is short of a
## relic's size (a thin deck is a build, old ADR-0020).
static func bolt_power_bonus(state: Dictionary, catalog: Dictionary) -> float:
	var m := relic_modifiers(state, catalog)
	var thin := 0
	if _is_deck(state):
		for effect: Dictionary in m.small_deck_power:
			thin += int(effect.per_card) * maxi(0, int(effect.below) - (state.deck as Array).size())
	return m.bolt_power + thin


## Bolts that land after the last shard; the rest fizzle. It grows with the layer and relics (old ADR-0015).
static func bolt_cap(state: Dictionary, catalog: Dictionary) -> int:
	var cap: Dictionary = catalog.balance.bolt_cap
	var raw := int(cap.base) + int(cap.per_layer) * int(state.layer) + int(relic_modifiers(state, catalog).bolt_cap)
	return maxi(1, mini(int(cap.max), raw))


## Work units one step costs: its shard's complexity class applied to the bolts it was handed (old ADR-0015). This is
## the whole of the Big-O lesson, and it is charged rather than recited.
static func work_units(complexity: String, given: float) -> int:
	var n := maxi(0, floori(given))
	match complexity:
		"constant":
			return 1
		"linearithmic":
			return ceili(n * JsMath.log2_whole(n + 1))
		"quadratic":
			return n * n
	return n


## Everything a pipeline is billed for, in work units: each step's complexity, plus its shard's own cost priced as
## work. A shard the catalog no longer knows is billed as one pass and costs nothing.
static func pipeline_work(steps: Array, catalog: Dictionary) -> int:
	var per_mana := int(catalog.balance.work_billing.per_mana)
	var total := 0
	for step: Dictionary in steps:
		var shard: Dictionary = catalog.shards.get(step.shard, {})
		total += work_units(shard.get("complexity", "linear"), float(step.given))
		total += int(shard.get("cost", 0)) * per_mana
	return total


## Mana that much work costs: `linear` bills every unit, `sqrt` amortizes, and `log` (a relic) makes even a quadratic
## build payable.
static func bill_work(units: float, curve: String, balance: Dictionary) -> int:
	var billing: Dictionary = balance.work_billing
	var scaled := maxf(0.0, units) / float(billing.per_mana)
	match curve:
		"sqrt":
			return floori(sqrt(scaled))
		"log":
			return floori(log(scaled + 1.0) / log(float(billing.log_base)))
	return floori(scaled)


## Mana a spell costs before discounts: the base, and one bill for everything its shards did and cost.
static func spell_cost(state: Dictionary, work: Array, catalog: Dictionary) -> int:
	var curve: String = relic_modifiers(state, catalog).work_curve
	return int(catalog.balance.spell_base_cost) + bill_work(pipeline_work(work, catalog), curve, catalog.balance)


static func cast_cost(state: Dictionary, work: Array, catalog: Dictionary) -> int:
	return discounted(state, spell_cost(state, work, catalog), catalog)


static func discounted(state: Dictionary, cost: int, catalog: Dictionary) -> int:
	var battle: Dictionary = state.get("battle", {})
	var first: bool = (battle.get("cast", []) as Array).is_empty()
	var m := relic_modifiers(state, catalog)
	var discount: int = m.first_cast_discount if first else 0
	return maxi(0, cost + int(m.cost_tax) - discount)


## Whatever a pipeline returned, as bolts the rules accept: malformed ones and ones past `cap` fizzle, and power and
## multiplier are rounded and clamped. Nothing a shard writes into a bolt can exceed what the balance allows.
static func normalize_bolts(raw: Array, balance: Dictionary, cap: int) -> Dictionary:
	var bolts: Array = []
	var fizzled := 0
	for candidate: Variant in raw:
		var bolt := parse_bolt(candidate)
		if bolt.is_empty() or bolts.size() >= cap:
			fizzled += 1
			continue
		bolt.power = clamp_power(bolt.power, balance)
		bolt.mult = clamp_mult(bolt.mult, balance)
		bolts.append(bolt)
	return {"bolts": bolts, "fizzled": fizzled}


## A bolt exactly as the old schema accepted one (a strict object: no other keys, every field of its type, `mult`
## defaulting to 1), or {} when it is not one.
static func parse_bolt(candidate: Variant) -> Dictionary:
	if not candidate is Dictionary:
		return {}
	var raw: Dictionary = candidate
	for key: Variant in raw:
		if not key in BOLT_KEYS:
			return {}
	if not _is_number(raw.get("power")) or not raw.get("element") in ELEMENTS or not raw.get("target") in TARGETS:
		return {}
	if not raw.get("pierce") is bool or not raw.get("ward") is bool:
		return {}
	var mult: Variant = raw.get("mult", 1.0)
	if not _is_number(mult):
		return {}
	var power: float = raw.power
	return {
		"power": power,
		"element": raw.element,
		"target": raw.target,
		"pierce": raw.pierce,
		"ward": raw.ward,
		"mult": float(mult)
	}


static func base_bolt(balance: Dictionary) -> Dictionary:
	var power := int(balance.base_bolt_power)
	return {"power": power, "element": "none", "target": "front", "pierce": false, "ward": false, "mult": 1}


## The battle as shard code sees it: only living foes, and only what a player could read off the screen.
static func shard_battle(state: Dictionary, battle: Dictionary) -> Dictionary:
	var foes: Array = []
	for foe: Dictionary in battle.foes:
		if int(foe.hp) > 0:
			var seen := {"name": foe.name, "hp": foe.hp, "max": foe.max, "shield": foe.shield}
			seen.weak = (foe.weak as Array).duplicate()
			seen.resist = (foe.resist as Array).duplicate()
			foes.append(seen)
	var me := {"hp": state.integrity, "max": state.integrity_max, "block": battle.block, "mana": battle.mana}
	return {"turn": battle.turn, "me": me, "foes": foes}


## The foes waiting in a battle room, fixed by the run's seed so the map can show them before the room is entered.
static func encounter_for(seed: String, node: Dictionary, layer: Dictionary) -> Array:
	if not node.kind in ["fight", "elite", "boss"]:
		return []
	var groups: Array = layer.encounters[node.kind]
	var index := floori(Rng.random_for(seed, "encounter:%s" % node.id, 0) * groups.size())
	if index < groups.size():
		return groups[index]
	return groups[0] if not groups.is_empty() else []


## The spell a forge could bind right now: the first name of the run's pool that no spell already carries, while the
## spellbook has room. {} when there is none.
static func bindable_spell(state: Dictionary, catalog: Dictionary, ignore_cap := false) -> Dictionary:
	var slots: Dictionary = catalog.config.get("spell_slots", {})
	var spells: Array = state.spells
	if slots.is_empty() or (not ignore_cap and spells.size() >= int(catalog.balance.max_spells)):
		return {}
	var taken := spells.map(func(spell: Dictionary) -> String: return spell.name)
	for name: String in slots.names:
		if not name in taken:
			return {"name": name, "capacity": int(slots.capacity)}
	return {}


## A foe's Integrity, clamped (old ADR-0016): bound the HP and every damage number stays an exact integer.
static func foe_hp(raw: float, balance: Dictionary) -> int:
	if is_nan(raw) or is_inf(raw):
		return int(balance.max_foe_hp)
	return maxi(1, mini(int(balance.max_foe_hp), JsMath.js_round(raw)))


static func clamp_power(power: float, balance: Dictionary) -> int:
	return maxi(0, mini(int(balance.max_bolt_power), JsMath.js_round(power)))


## The multiplier axis, clamped like power. Infinity is not a number the rules will carry, so it becomes 0.
static func clamp_mult(mult: float, balance: Dictionary) -> float:
	if is_nan(mult) or is_inf(mult):
		return 0.0
	return maxf(0.0, minf(float(balance.max_bolt_mult), mult))


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and not (value is float and (is_nan(value) or is_inf(value)))


static func _is_deck(state: Dictionary) -> bool:
	return state.get("playstyle", "spellbook") == "deck"
