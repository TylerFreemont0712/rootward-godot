class_name Shardrun
extends RefCounted
## The rules of Shardrun (old ADR-0012 to ADR-0016, ADR-0020, ADR-0025) as pure functions over plain data. A spell's
## shards run in the sandbox first; what comes back is only a list of candidate bolts, which these rules validate, pay
## for, and resolve. No number a shard computes is trusted as damage.
##
##   var state := Shardrun.start(catalog, {seed, language, difficulty, playstyle?, sandbox?})
##   var result := Shardrun.step(state, {"type": "enter", "node_id": "l0-r0-c1"}, catalog)
##   if result.ok: state = result.state   else: result.error is {code, message}
##
## A state is a snapshot, saved whole after every command (see docs/shardrun-state.md for its shape); `step` never
## changes the state it is given, so a refused command leaves it exactly as it was.

const VERSION := 2
const ARRANGEABLE: Array[String] = ["map", "reward", "rest", "forge"]
const ENDED: Array[String] = ["won", "lost", "abandoned"]


static func start(catalog: Dictionary, options: Dictionary) -> Dictionary:
	var config: Dictionary = catalog.config
	var balance: Dictionary = catalog.balance
	var layers: Array = config.layers
	var first_layer: Dictionary = layers[0]
	var playstyle: String = options.get("playstyle", "spellbook")
	var deck: Dictionary = config.get("deck", {})
	assert(playstyle != "deck" or not deck.is_empty(), "this Shardrun config has no deck playstyle")
	var seed: String = options.seed
	var templates: Array = deck.spells if playstyle == "deck" else config.start.spells
	var spells: Array = []
	for index in templates.size():
		var template: Dictionary = templates[index]
		var shards: Array = [] if playstyle == "deck" else (template.shards as Array).duplicate()
		spells.append(
			{
				"id": "spell-%d" % (index + 1),
				"name": template.name,
				"capacity": int(template.capacity),
				"shards": shards
			}
		)
	var integrity := int(balance.integrity_start)
	var state := {
		"version": VERSION,
		"seed": seed,
		"language": options.language,
		"difficulty": ShardrunRules.difficulty_of(catalog, options.difficulty).id,
		"status": "map",
		"integrity": integrity,
		"integrity_max": integrity,
		"layer": 0,
		"map": ShardrunMap.generate(seed, 0, first_layer),
		"position": null,
		"visited": [],
		"playstyle": playstyle,
		"spells": spells,
		"inventory": [] if playstyle == "deck" else (config.start.get("inventory", []) as Array).duplicate(),
		"deck": (deck.cards as Array).duplicate() if playstyle == "deck" else [],
		"relics": [],
		"revision": 0,
		"sandbox": options.get("sandbox", false),
		"log": [],
		"stats": new_stats(),
	}
	for relic_id: String in config.start.get("relics", []):
		var relic: Dictionary = catalog.relics.get(relic_id, {})
		if not relic.is_empty():
			gain_relic(state, relic, catalog)
	state.log = [{"kind": "layer", "text": "%s. %s" % [first_layer.name, first_layer.flavor]}]
	return state


static func new_stats() -> Dictionary:
	return {
		"fights": 0,
		"turns": 0,
		"casts": 0,
		"damage": 0,
		"shards": 0,
		"relics": 0,
		"layers": 0,
		"mana_spent": 0,
		"bolts": 0,
		"fizzled": 0,
		"damage_by_spell": {},
		"best_cast": 0,
	}


## Applies one command. Returns {ok: true, state} with a new state, or {ok: false, error: {code, message}}.
static func step(state: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	# LEARN: duplicate(true) deep-copies, so every rule below can change `next` freely; if a rule refuses halfway
	# through, the half-changed copy is simply thrown away.
	var next := state.duplicate(true)
	next.log = []
	if next.status in ENDED:
		return refuse("run-over", "This run is over. Start a new one.")
	var refusal := ShardrunCommands.apply(next, command, catalog)
	if not refusal.is_empty():
		return {"ok": false, "error": refusal}
	next.revision += 1
	return {"ok": true, "state": next}


static func refuse(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}


static func record(state: Dictionary, entry: Dictionary) -> void:
	(state.log as Array).append(entry)


static func spell_by_id(state: Dictionary, spell_id: String) -> Dictionary:
	for spell: Dictionary in state.spells:
		if spell.id == spell_id:
			return spell
	return {}


static func fits_playstyle(relic: Dictionary, state: Dictionary) -> bool:
	return not relic.has("playstyles") or state.playstyle in relic.playstyles


# --- Rooms -------------------------------------------------------------------------------------------------------


static func enter_room(state: Dictionary, node: Dictionary, catalog: Dictionary) -> void:
	match node.kind:
		"rest":
			state.status = "rest"
			record(state, {"kind": "enter", "text": "A quiet alcove. The hum of the Machine is almost soothing."})
		"forge":
			state.status = "forge"
			var text := "An abandoned forge, still warm. A shard can be reworked, or a spell widened."
			record(state, {"kind": "enter", "text": text})
		"treasure":
			record(state, {"kind": "enter", "text": "A sealed cache, left behind by an earlier Maintainer."})
			var chance := (
				float(catalog.balance.get("treasure_curse_chance", 0.0))
				if not curses_left(state, catalog).is_empty()
				else 0.0
			)
			state.reward = {"chest": {"curse_chance": chance}}
			state.status = "reward"
		"fight", "elite", "boss":
			ShardrunBattle.start(state, node, node.kind, catalog)


## Cursed relics this run could still find, ordered by id.
static func curses_left(state: Dictionary, catalog: Dictionary) -> Array:
	return ShardrunCatalog.sorted_values(catalog.relics).filter(
		func(relic: Dictionary) -> bool:
			return relic.get("cursed", false) and not relic.id in state.relics and fits_playstyle(relic, state)
	)


static func settle_reward(state: Dictionary, catalog: Dictionary) -> void:
	var reward: Dictionary = state.get("reward", {})
	for key: String in ["shards", "relics", "spell", "chest", "cursed_relic"]:
		if reward.has(key):
			return
	state.erase("reward")
	after_room(state, catalog)


static func after_room(state: Dictionary, catalog: Dictionary) -> void:
	var node := {}
	for candidate: Dictionary in state.map.nodes:
		if candidate.id == state.position:
			node = candidate
	if node.get("kind") != "boss":
		state.status = "map"
		return
	state.stats.layers += 1
	var next_index := int(state.layer) + 1
	var layers: Array = catalog.config.layers
	if next_index >= layers.size():
		state.status = "won"
		record(state, {"kind": "victory", "text": "The last guardian falls. The Salvage is yours."})
		return
	var next_layer: Dictionary = layers[next_index]
	state.layer = next_index
	state.map = ShardrunMap.generate(state.seed, next_index, next_layer)
	state.position = null
	state.visited = []
	var healed := _heal_amount(state, float(catalog.balance.layer_heal_fraction))
	state.integrity += healed
	state.status = "map"
	var text := "You descend into %s, recovering %d Integrity. %s" % [next_layer.name, healed, next_layer.flavor]
	record(state, {"kind": "layer", "amount": healed, "text": text})


static func _heal_amount(state: Dictionary, fraction: float) -> int:
	return mini(int(state.integrity_max) - int(state.integrity), ceili(int(state.integrity_max) * fraction))


static func heal_amount(state: Dictionary, fraction: float) -> int:
	return _heal_amount(state, fraction)


## Adds the bindable spell to the book, or nothing. A forge and a spell-slot relic both come here.
static func bind_spell(state: Dictionary, catalog: Dictionary, ignore_cap := false) -> Dictionary:
	var next := ShardrunRules.bindable_spell(state, catalog, ignore_cap)
	if next.is_empty():
		return {}
	var spell := {
		"id": "spell-%d" % ((state.spells as Array).size() + 1),
		"name": next.name,
		"capacity": next.capacity,
		"shards": []
	}
	(state.spells as Array).append(spell)
	return spell


static func gain_relic(state: Dictionary, relic: Dictionary, catalog: Dictionary) -> void:
	(state.relics as Array).append(relic.id)
	state.stats.relics += 1
	var balance: Dictionary = catalog.balance
	for effect: Dictionary in relic.effects:
		match effect.kind:
			"spell-capacity":
				for spell: Dictionary in state.spells:
					spell.capacity = mini(int(balance.max_spell_capacity), int(spell.capacity) + int(effect.add))
			"max-integrity":
				state.integrity_max += int(effect.add)
				state.integrity += int(effect.add)
			"spell-slot":
				# The deliberate exception to the two-spell cap. Forge binding still respects it.
				for i in int(effect.add):
					bind_spell(state, catalog, true)
			"add-cards":
				for card: String in effect.cards:
					if not catalog.shards.has(card):
						continue
					if state.playstyle == "deck":
						(state.deck as Array).append(card)
						# During a fight every card of the deck sits in a pile; a new one starts on the discard pile.
						if state.has("battle"):
							(state.battle.discard as Array).append(card)
					else:
						(state.inventory as Array).append(card)
	record(state, {"kind": "relic", "text": "You claim %s: %s" % [relic.name, relic.summary]})


static func same_list(a: Array, b: Array) -> bool:
	return a == b


static func same_multiset(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var counts := {}
	for item: Variant in a:
		counts[item] = int(counts.get(item, 0)) + 1
	for item: Variant in b:
		var left := int(counts.get(item, 0)) - 1
		if left < 0:
			return false
		counts[item] = left
	return true
