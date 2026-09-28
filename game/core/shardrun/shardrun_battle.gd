class_name ShardrunBattle
extends RefCounted
## Fights in Shardrun (old ADR-0012 to ADR-0016, ADR-0020): casting, resolving bolts, foes' turns, the deck's piles,
## and what a won fight leaves behind. Every function mutates the state it is given; Shardrun.step hands them a copy.


static func start(state: Dictionary, node: Dictionary, kind: String, catalog: Dictionary) -> void:
	var layer := ShardrunRules.layer_of(state, catalog)
	var foes := foe_states(state, ShardrunRules.encounter_for(state.seed, node, layer), node.id, catalog)
	start_with(state, kind, foes, catalog)


## The fighting state of a list of foes, scaled by the layer and the difficulty. A foe the content no longer has is
## skipped, so an edited pack still loads an old run. The prefix keeps uids apart between encounters.
static func foe_states(state: Dictionary, foe_ids: Array, prefix: String, catalog: Dictionary) -> Array:
	var layer := ShardrunRules.layer_of(state, catalog)
	var difficulty := ShardrunRules.difficulty_of(catalog, state.difficulty)
	var foes: Array = []
	for index in foe_ids.size():
		var def: Dictionary = catalog.foes.get(foe_ids[index], {})
		if def.is_empty():
			continue
		var raw := float(def.hp) * float(layer.get("foe_hp", 1.0)) * float(difficulty.foe_hp)
		var hp := ShardrunRules.foe_hp(raw, catalog.balance)
		var intents: Array = def.intents
		var foe := {
			"uid": "%s-%d" % [prefix, index],
			"id": def.id,
			"name": def.name,
			"sprite": def.sprite,
			"hp": hp,
			"max": hp,
			"shield": 0,
			"weak": (def.get("weak", []) as Array).duplicate(),
			"resist": (def.get("resist", []) as Array).duplicate(),
		}
		if def.has("trait"):
			foe.trait = (def.trait as Dictionary).duplicate(true)
		foe.intents = intents.duplicate(true)
		# Two of the same foe start on different steps of their pattern, so they do not act in lockstep.
		foe.intent_index = index % intents.size()
		foe.stoked = false
		foe.nullified = false
		foe.flavor = def.flavor
		foes.append(foe)
	return foes


static func start_with(state: Dictionary, kind: String, foes: Array, catalog: Dictionary) -> void:
	if foes.is_empty():
		Shardrun.after_room(state, catalog)
		return
	var battle := new_battle(state, kind, foes, catalog)
	if state.get("playstyle", "") == "program":
		ProgramDeck.on_battle_start(battle)
		ProgramRelics.on_battle_start(state, battle, catalog)
	begin_turn(battle)
	state.battle = battle
	state.status = "battle"
	deal(state, battle, catalog)
	state.stats.fights += 1
	Shardrun.record(state, {"kind": "enter", "text": entrance(foes)})


static func new_battle(state: Dictionary, kind: String, foes: Array, catalog: Dictionary) -> Dictionary:
	return {
		"kind": kind,
		"turn": 1,
		"mana": ShardrunRules.mana_per_turn(state, catalog),
		"block": int(ShardrunRules.relic_modifiers(state, catalog).turn_block),
		"foes": foes,
		"cast": [],
		"casts": 0,
		"draw": [],
		"hand": [],
		"discard": [],
		"held": [],
	}


static func entrance(foes: Array) -> String:
	var names := " and ".join(foes.map(func(foe: Dictionary) -> String: return foe.name))
	return "%s %s the way." % [names, "blocks" if foes.size() == 1 else "block"]


## Casts `spell` with what its shards produced. Returns a refusal {code, message}, or {} when the cast happened.
static func cast_spell(
	state: Dictionary, battle: Dictionary, spell: Dictionary, outcome: Dictionary, catalog: Dictionary
) -> Dictionary:
	if state.playstyle == "program":
		return ProgramRules.cast(state, battle, spell, outcome, catalog)
	var balance: Dictionary = catalog.balance
	if not outcome.ok:
		var fizzle_cost := ShardrunRules.discounted(state, int(balance.spell_base_cost), catalog)
		if fizzle_cost > int(battle.mana):
			return {"code": "not-enough-mana", "message": "%s needs mana you do not have." % spell.name}
		battle.mana -= fizzle_cost
		(battle.cast as Array).append(spell.id)
		battle.casts += 1
		state.stats.casts += 1
		state.stats.mana_spent += fizzle_cost
		var text := "%s fizzles: %s" % [spell.name, outcome.reason]
		Shardrun.record(state, {"kind": "fizzle", "spell": spell.id, "amount": fizzle_cost, "text": text})
		return {}
	var cost := ShardrunRules.cast_cost(state, outcome.work, catalog)
	if cost > int(battle.mana):
		return {
			"code": "not-enough-mana", "message": "%s needs %d mana and you have %d." % [spell.name, cost, battle.mana]
		}
	battle.mana -= cost
	(battle.cast as Array).append(spell.id)
	state.stats.casts += 1
	state.stats.mana_spent += cost

	var normalized := ShardrunRules.normalize_bolts(outcome.bolts, balance, ShardrunRules.bolt_cap(state, catalog))
	var bolts := empower(normalized.bolts, state, catalog)
	# Counted once its bolts are made: a per-cast relic counts the spells *already* cast, as its preview does.
	battle.casts += 1
	state.stats.bolts += bolts.size()
	state.stats.fizzled += normalized.fizzled
	var noun := "bolt" if bolts.size() == 1 else "bolts"
	var cast_text := "%s: %d %s for %d mana." % [spell.name, bolts.size(), noun, cost]
	Shardrun.record(state, {"kind": "cast", "spell": spell.id, "amount": cost, "text": cast_text})
	var fizzled: int = normalized.fizzled
	if fizzled > 0:
		var fizzle_text := "%d %s fizzled." % [fizzled, "bolt" if fizzled == 1 else "bolts"]
		Shardrun.record(state, {"kind": "fizzle", "spell": spell.id, "amount": fizzled, "text": fizzle_text})

	var curse := int(ShardrunRules.relic_modifiers(state, catalog).cast_burn)
	for id: String in spell.shards:
		var shard: Dictionary = catalog.shards.get(id, {})
		curse += int((shard.get("curse", {}) as Dictionary).get("integrity", 0))
	if curse > 0:
		state.integrity = maxi(0, int(state.integrity) - curse)
		Shardrun.record(state, {"kind": "curse", "amount": curse, "text": "The cast burns %d Integrity." % curse})

	var potential := potential_of(state, bolts, catalog)
	var dealt := resolve_bolts(state, battle, bolts, catalog)
	cast_defense(state, battle, catalog)
	battle.last_cast_ward = not bolts.is_empty() and bolts.all(func(bolt: Dictionary) -> bool: return bolt.ward)
	state.stats.damage += dealt
	var by_spell: Dictionary = state.stats.damage_by_spell
	by_spell[spell.id] = int(by_spell.get(spell.id, 0)) + dealt
	# The run's record is the potential, not the dealt: "how big did your function get" is the number worth beating.
	state.stats.best_cast = maxi(int(state.stats.best_cast), potential)
	if int(state.integrity) <= 0:
		lose(state)
	elif (battle.foes as Array).all(func(foe: Dictionary) -> bool: return int(foe.hp) == 0):
		win(state, battle, catalog)
	return {}


## Relics apply after the last shard, before the bolts fly, and stay inside the clamps. The multiplier takes its
## additions first and its factor second, so a relic that doubles it doubles everything that raised it.
static func empower(bolts: Array, state: Dictionary, catalog: Dictionary) -> Array:
	var m := ShardrunRules.relic_modifiers(state, catalog)
	var add := ShardrunRules.bolt_power_bonus(state, catalog)
	var battle: Dictionary = state.get("battle", {})
	var mult_add: float = m.bolt_mult + m.mult_per_cast * int(battle.get("casts", 0))
	var conditional: Array = m.conditional_mult
	if add == 0 and mult_add == 0 and m.bolt_mult_factor == 1.0 and conditional.is_empty():
		return bolts.duplicate(true)
	var result: Array = []
	for bolt: Dictionary in bolts:
		var factor := 1.0
		for effect: Dictionary in conditional:
			factor *= float(effect.factor) if RelicConditions.matches(effect.when, bolt, bolts, state) else 1.0
		var next := bolt.duplicate()
		next.power = ShardrunRules.clamp_power(bolt.power + add, catalog.balance)
		next.mult = ShardrunRules.clamp_mult((bolt.mult + mult_add) * m.bolt_mult_factor * factor, catalog.balance)
		result.append(next)
	return result


static func cast_defense(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> void:
	var amount := int(ShardrunRules.relic_modifiers(state, catalog).cast_block)
	if amount <= 0:
		return
	battle.block += amount
	Shardrun.record(
		state, {"kind": "ward", "amount": amount, "text": "Your relics gather %d block after the cast." % amount}
	)


## Fires bolts in order and returns the Integrity removed. Logs every hit so the stage can play it.
static func resolve_bolts(state: Dictionary, battle: Dictionary, bolts: Array, catalog: Dictionary) -> int:
	var balance: Dictionary = catalog.balance
	var m := ShardrunRules.relic_modifiers(state, catalog)
	var dealt := 0
	for index in bolts.size():
		var bolt: Dictionary = bolts[index]
		if bolt.ward:
			var gathered := JsMath.js_round(bolt.power * bolt.mult)
			battle.block += gathered
			var ward := {"kind": "ward", "amount": gathered, "element": bolt.element}
			ward.merge(bolt_shape(index, bolt))
			ward.text = "A ward gathers %d block." % gathered
			Shardrun.record(state, ward)
			continue
		var alive := (battle.foes as Array).filter(func(foe: Dictionary) -> bool: return int(foe.hp) > 0)
		if alive.is_empty():
			break
		var share: float = float(balance.scatter_multiplier) if bolt.target == "all" else 1.0
		for foe: Dictionary in targets_of(bolt, alive):
			var power := floori(bolt.power * bolt.mult * share)
			var foe_trait: Dictionary = foe.get("trait", {})
			if foe_trait.get("kind") == "nullify-first" and not foe.nullified:
				foe.nullified = true
				var absorb := {"kind": "absorb", "foe": foe.uid, "element": bolt.element}
				absorb.merge(bolt_shape(index, bolt))
				absorb.text = "%s swallows the first bolt whole." % foe.name
				Shardrun.record(state, absorb)
				continue
			if foe_trait.get("kind") == "thick-hide" and power < int(foe_trait.threshold):
				var glance := {"kind": "glance", "foe": foe.uid, "element": bolt.element}
				glance.merge(bolt_shape(index, bolt))
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
			var blocked := 0
			if not bolt.pierce:
				blocked = mini(int(foe.shield), damage)
				foe.shield -= blocked
				damage -= blocked
			damage = mini(damage, int(foe.hp))
			foe.hp -= damage
			dealt += damage
			var hit := {"kind": "hit", "foe": foe.uid, "amount": damage, "element": bolt.element}
			hit.merge(bolt_shape(index, bolt))
			if weak:
				hit.affinity = "weak"
			elif resisted:
				hit.affinity = "resist"
			if blocked > 0:
				hit.blocked = blocked
			var shield_note := " (%d into its shield)" % blocked if blocked > 0 else ""
			hit.text = "%s takes %d%s." % [foe.name, damage, shield_note]
			Shardrun.record(state, hit)
			if int(foe.hp) == 0:
				Shardrun.record(state, {"kind": "defeat", "foe": foe.uid, "text": "%s breaks apart." % foe.name})
	return dealt


## What a volley is worth, whatever stood in front of it (old ADR-0016): the same rules against a copy of the battle
## whose foes have headroom enough that none can die. Adding headroom rather than flattening HP keeps the foes in the
## same order, so a bolt aimed at the weakest still picks the one it would have picked.
static func potential_of(state: Dictionary, bolts: Array, catalog: Dictionary) -> int:
	var copy := state.duplicate(true)
	if not copy.has("battle"):
		return 0
	var shadow: Dictionary = copy.battle
	var balance: Dictionary = catalog.balance
	var headroom := float(balance.bolt_cap.max) * float(balance.max_bolt_power) * float(balance.max_bolt_mult)
	for foe: Dictionary in shadow.foes:
		foe.hp = ShardrunRules.foe_hp(int(foe.hp) + headroom, balance)
	copy.log = []
	return resolve_bolts(copy, shadow, bolts, catalog)


## What the stage needs to draw a bolt as the bolt it is (old ADR-0019), sparse: only what sets it apart from a plain,
## single-target, unmultiplied bolt.
static func bolt_shape(index: int, bolt: Dictionary) -> Dictionary:
	var shape := {"bolt": index, "target": bolt.target}
	if bolt.pierce:
		shape.pierce = true
	if bolt.mult != 1:
		shape.mult = bolt.mult
	return shape


static func targets_of(bolt: Dictionary, alive: Array) -> Array:
	match bolt.target:
		"all":
			return alive.duplicate()
		"back":
			return alive.slice(-1)
		"weakest":
			return [_pick(alive, func(a: Dictionary, b: Dictionary) -> bool: return int(a.hp) < int(b.hp))]
		"strongest":
			return [_pick(alive, func(a: Dictionary, b: Dictionary) -> bool: return int(a.hp) > int(b.hp))]
	return alive.slice(0, 1)


static func _pick(alive: Array, better: Callable) -> Dictionary:
	var best: Dictionary = alive[0]
	for i in range(1, alive.size()):
		if better.call(alive[i], best):
			best = alive[i]
	return best


static func enemy_turn(state: Dictionary, battle: Dictionary) -> void:
	# A program run's faster foes may already have acted this turn, before the program landed (ADR-0012).
	var acted: Array = battle.get("acted", [])
	for foe: Dictionary in battle.foes:
		if int(foe.hp) == 0 or foe.uid in acted:
			continue
		foe_act(state, battle, foe)
		if int(state.integrity) <= 0:
			return


## One foe does what its intent says.
static func foe_act(state: Dictionary, battle: Dictionary, foe: Dictionary) -> void:
	# A shield raised last turn has done its job by the time its owner acts again.
	foe.shield = 0
	var intents: Array = foe.intents
	var intent: Dictionary = intents[int(foe.intent_index) % intents.size()]
	match intent.kind:
		"strike":
			var power := int(intent.power) * (2 if foe.stoked else 1)
			foe.stoked = false
			hit_maintainer(state, battle, foe, power)
		"multi":
			var i := 0
			while i < int(intent.times) and int(state.integrity) > 0:
				hit_maintainer(state, battle, foe, int(intent.power))
				i += 1
		"shield":
			var amount := int(intent.amount)
			foe.shield += amount
			var text := "%s raises a %d-point shield." % [foe.name, amount]
			Shardrun.record(state, {"kind": "shield", "foe": foe.uid, "amount": amount, "text": text})
		"stoke":
			foe.stoked = true
			var text := "%s stokes its fire. Its next strike hits twice as hard." % foe.name
			Shardrun.record(state, {"kind": "stoke", "foe": foe.uid, "text": text})
		"heal":
			var healed := mini(int(foe.max) - int(foe.hp), int(intent.amount))
			foe.hp += healed
			var text := "%s mends %d HP." % [foe.name, healed]
			Shardrun.record(state, {"kind": "heal", "foe": foe.uid, "amount": healed, "text": text})


static func hit_maintainer(state: Dictionary, battle: Dictionary, foe: Dictionary, power: int) -> void:
	var blocked := mini(int(battle.block), power)
	battle.block -= blocked
	var damage := power - blocked
	state.integrity = maxi(0, int(state.integrity) - damage)
	var entry := {"kind": "enemy", "foe": foe.uid, "amount": damage}
	if blocked > 0:
		entry.blocked = blocked
	var block_note := " (%d blocked)" % blocked if blocked > 0 else ""
	entry.text = "%s hits you for %d%s." % [foe.name, damage, block_note]
	Shardrun.record(state, entry)


static func new_turn(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> void:
	var m := ShardrunRules.relic_modifiers(state, catalog)
	battle.turn += 1
	# Mana a program earned last turn for the next (ProgramRelics); no other playstyle ever sets it.
	battle.mana = ShardrunRules.mana_per_turn(state, catalog) + int(battle.get("bonus_mana", 0))
	battle.erase("bonus_mana")
	battle.block = floori(int(battle.block) * float(m.retain_block)) + int(m.turn_block)
	battle.cast = []
	if battle.has("acted"):
		battle.acted = []
	var burn := int(m.turn_burn)
	if burn > 0:
		state.integrity = maxi(0, int(state.integrity) - burn)
		Shardrun.record(
			state, {"kind": "curse", "amount": burn, "text": "Your cursed relics burn %d Integrity." % burn}
		)
		if int(state.integrity) == 0:
			lose(state)
			return
	if ShardrunRules.is_deck(state):
		# What was not cast this turn is let go, the hand and anything still in a spell, except what was held: that
		# starts the new hand, and a full hand is drawn on top of it. A program run's keywords decide more (ADR-0018).
		if state.get("playstyle", "") == "program":
			ProgramDeck.end_turn(state, battle, catalog)
		else:
			var discard: Array = battle.discard
			discard.append_array(battle.hand)
			for spell: Dictionary in state.spells:
				discard.append_array(spell.shards)
			battle.hand = (battle.held as Array).duplicate()
			battle.held = []
			clear_spells(state)
		draw(state, battle, ShardrunRules.hand_size(state, catalog), catalog)
	for foe: Dictionary in battle.foes:
		foe.intent_index = (int(foe.intent_index) + 1) % (foe.intents as Array).size()
	begin_turn(battle)
	state.stats.turns += 1
	Shardrun.record(state, {"kind": "turn", "amount": battle.turn, "text": "Turn %d." % battle.turn})


## Per-turn traits: a shifting weakness moves on, a pattern ward changes its element, nullify is ready again.
static func begin_turn(battle: Dictionary) -> void:
	for foe: Dictionary in battle.foes:
		foe.nullified = false
		var foe_trait: Dictionary = foe.get("trait", {})
		if foe_trait.get("kind") == "shifting-weakness":
			foe.weak = _element_at(foe_trait.cycle, int(battle.turn))
		if foe_trait.get("kind") == "pattern-ward":
			var element := _element_at(foe_trait.pattern, int(battle.turn))
			if not element.is_empty():
				foe.pattern = element[0]


static func _element_at(cycle: Array, turn: int) -> Array:
	return [cycle[(turn - 1) % cycle.size()]] if not cycle.is_empty() else []


## A deck run's fight begins (old ADR-0020): every card of the deck, shuffled from the run's seed, becomes the draw
## pile, and the first hand is drawn. The spells start the fight blank.
static func deal(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> void:
	if not ShardrunRules.is_deck(state):
		return
	clear_spells(state)
	battle.draw = Rng.create(state.seed, "deck:%d" % state.revision).shuffled(state.deck)
	if state.get("playstyle", "") == "program":
		battle.draw = ProgramDeck.innate_first(battle.draw, catalog)
	battle.hand = []
	battle.discard = []
	battle.held = []
	var opening := (
		int(catalog.balance.deck.opening_draw) + int(ShardrunRules.relic_modifiers(state, catalog).opening_draw)
	)
	draw(state, battle, ShardrunRules.hand_size(state, catalog) + opening, catalog)


## Draws `count` cards from the top of the pile; when it runs out, the discard pile is shuffled into a new one.
## LEARN: the draw pile is a queue (cards leave from the front) and the discard pile a stack that becomes the next
## queue. The shuffle's stream names the command and the card being drawn, so the same state always draws the same.
static func draw(state: Dictionary, battle: Dictionary, count: int, catalog: Dictionary) -> void:
	for drawn in count:
		if (battle.draw as Array).is_empty():
			if (battle.discard as Array).is_empty():
				return
			var stream := "deck:%d:%d:%d" % [state.revision, battle.turn, drawn]
			battle.draw = Rng.create(state.seed, stream).shuffled(battle.discard)
			battle.discard = []
			var block := int(ShardrunRules.relic_modifiers(state, catalog).reshuffle_block)
			if block > 0:
				battle.block += block
				var text := "The discard pile is compacted into a new draw pile: %d block." % block
				Shardrun.record(state, {"kind": "note", "amount": block, "text": text})
		var card: String = (battle.draw as Array).pop_front()
		(battle.hand as Array).append(card)


## Empties a deck run's spells: between fights its cards are only the deck. A spellbook run's spells are left alone.
static func clear_spells(state: Dictionary) -> void:
	if not ShardrunRules.is_deck(state):
		return
	for spell: Dictionary in state.spells:
		spell.shards = []


static func win(state: Dictionary, battle: Dictionary, catalog: Dictionary) -> void:
	state.erase("battle")
	clear_spells(state)
	var balance: Dictionary = catalog.balance
	var heal := int(ShardrunRules.relic_modifiers(state, catalog).heal_after_fight)
	if heal > 0:
		var healed := mini(int(state.integrity_max) - int(state.integrity), heal)
		state.integrity += healed
		if healed > 0:
			var text := "Your patch kit restores %d Integrity." % healed
			Shardrun.record(state, {"kind": "heal", "amount": healed, "text": text})
	var boss: bool = battle.kind == "boss"
	var line := (
		"The guardian falls. The way down opens." if boss else "The way is clear. Shards scatter across the floor."
	)
	Shardrun.record(state, {"kind": "victory", "text": line})

	var reward := {}
	var shards := draft_shards(state, battle.kind, catalog)
	if not shards.is_empty():
		reward.shards = shards
	var relic_count := 0
	if boss:
		relic_count = int(balance.boss_relic_choices)
	elif battle.kind == "elite":
		relic_count = int(balance.elite_relic_choices)
	if relic_count > 0 and battle.kind != "fight":
		var relics := draft_relics(state, battle.kind, relic_count, catalog)
		if not relics.is_empty():
			reward.relics = relics
	var boss_spell: Dictionary = ShardrunRules.layer_of(state, catalog).get("boss_spell", {})
	var one_program: bool = state.playstyle == "program"
	if (
		boss
		and not one_program
		and not boss_spell.is_empty()
		and (state.spells as Array).size() < int(balance.max_spells)
	):
		reward.spell = {"name": boss_spell.name, "capacity": int(boss_spell.capacity)}
	if reward.is_empty():
		Shardrun.after_room(state, catalog)
		return
	state.reward = reward
	state.status = "reward"


static func lose(state: Dictionary) -> void:
	clear_spells(state)
	state.status = "lost"
	Shardrun.record(state, {"kind": "loss", "text": "Kernel panic. The Salvage keeps what you carried."})


## Distinct draftable shards for a reward, rarity by the fight's weights, drawn from the run's seed.
static func draft_shards(state: Dictionary, kind: String, catalog: Dictionary) -> Array:
	var weights_by: Dictionary = catalog.config.rewards.shards[kind]
	var rng := Rng.create(state.seed, "reward:%d:%d" % [state.layer, (state.visited as Array).size()])
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(shard: Dictionary) -> bool: return shard.get("draftable", true)
	)
	return _draft(pool, ShardrunRules.SHARD_RARITIES, weights_by, int(catalog.balance.reward_choices), rng)


## Distinct relics the run does not hold yet, rarity by where they are found, drawn from the run's seed.
static func draft_relics(state: Dictionary, where: String, count: int, catalog: Dictionary) -> Array:
	# A program run's relics are tiered, with loot tables of their own (ProgramLoot); the rest is the old engine's.
	if state.get("playstyle", "") == "program":
		return ProgramLoot.draft_relics(state, where, count, catalog)
	var weights_by: Dictionary = catalog.config.rewards.relics[where]
	var rng := Rng.create(state.seed, "relic:%s:%d:%d" % [where, state.layer, (state.visited as Array).size()])
	var pool := ShardrunCatalog.sorted_values(catalog.relics).filter(
		func(relic: Dictionary) -> bool:
			return (
				not relic.get("cursed", false)
				and not relic.id in state.relics
				and Shardrun.fits_playstyle(relic, state)
			)
	)
	return _draft(pool, ShardrunRules.RELIC_RARITIES, weights_by, count, rng)


static func _draft(pool: Array, rarities: Array[String], weights_by: Dictionary, count: int, rng: Rng) -> Array:
	var weights: Array[float] = []
	for rarity in rarities:
		weights.append(float(weights_by.get(rarity, 0.0)))
	var choices: Array = []
	var attempt := 0
	while choices.size() < count and attempt < 60:
		var index := Rng.pick_weighted(weights, rng.next())
		var rarity: String = rarities[index] if index >= 0 else ""
		var candidates := pool.filter(
			func(item: Dictionary) -> bool: return item.rarity == rarity and not item.id in choices
		)
		# LEARN: the draw happens even when there is nothing to pick, so the stream stays aligned with the old engine.
		var pick := floori(rng.next() * candidates.size())
		if pick < candidates.size():
			choices.append((candidates[pick] as Dictionary).id)
		attempt += 1
	return choices


## What casting a spell right now would do, worked out on a copy of the state. {} outside a battle.
static func preview_cast(state: Dictionary, spell_id: String, outcome: Dictionary, catalog: Dictionary) -> Dictionary:
	var battle: Dictionary = state.get("battle", {})
	var spell := Shardrun.spell_by_id(state, spell_id)
	if battle.is_empty() or spell.is_empty():
		return {}
	if state.playstyle == "program":
		return ProgramRules.preview(state, spell_id, outcome, catalog)
	var spent: bool = spell_id in battle.cast
	if not outcome.ok:
		var fizzle_cost := ShardrunRules.discounted(state, int(catalog.balance.spell_base_cost), catalog)
		return {
			"cost": fizzle_cost,
			"affordable": not spent and fizzle_cost <= int(battle.mana),
			"bolts": 0,
			"damage": 0,
			"potential": 0,
			"block": 0,
			"misfire": outcome.reason,
		}
	var cost := ShardrunRules.cast_cost(state, outcome.work, catalog)
	var preview := {"cost": cost, "affordable": not spent and cost <= int(battle.mana)}
	preview.merge(preview_bolts(state, outcome.bolts, catalog))
	return preview


## What a list of candidate bolts would do if a spell ended with them now. The code view uses it after every shard, so
## its numbers are the rules' own.
static func preview_bolts(state: Dictionary, raw: Array, catalog: Dictionary) -> Dictionary:
	var copy := state.duplicate(true)
	if not copy.has("battle"):
		return {"bolts": 0, "damage": 0, "potential": 0, "block": 0}
	var battle: Dictionary = copy.battle
	var block_before := int(battle.block)
	var cap := ShardrunRules.bolt_cap(copy, catalog)
	var bolts := empower(ShardrunRules.normalize_bolts(raw, catalog.balance, cap).bolts, copy, catalog)
	copy.log = []
	var potential := potential_of(state, bolts, catalog)
	var dealt := resolve_bolts(copy, battle, bolts, catalog)
	cast_defense(copy, battle, catalog)
	return {"bolts": bolts.size(), "damage": dealt, "potential": potential, "block": int(battle.block) - block_before}
