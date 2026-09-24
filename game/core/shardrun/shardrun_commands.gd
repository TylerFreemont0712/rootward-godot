class_name ShardrunCommands
extends RefCounted
## Each Shardrun command against a copy of the state. `apply` returns {} when the command happened, or the refusal
## {code, message}; Shardrun.step then keeps or drops the copy.
##
## Commands: enter {node_id}, arrange {spells: [{id, shards}], inventory}, cast {spell_id, outcome}, compose {spells,
## hand, held}, end-turn, take {shard_id | null}, claim-relic {relic_id}, open-chest, cleanse-relic {relic_id},
## claim-spell, leave, rest, forge {shard_id | null}, widen {spell_id}, bind, purge {shard_id}, abandon, and the dev
## commands of a sandbox run (see ShardrunDev). A cast's outcome is what its shards did in the sandbox:
## {ok: true, bolts, work: [{shard, given}]} or {ok: false, reason}.


static func apply(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	match command.type:
		"enter":
			return _enter(next, command, catalog)
		"arrange":
			return _arrange(next, command)
		"cast":
			return _cast(next, command, catalog)
		"compose":
			return _compose(next, command, catalog)
		"end-turn":
			return _end_turn(next, catalog)
		"take":
			return _take(next, command, catalog)
		"open-chest":
			return _open_chest(next, catalog)
		"claim-relic":
			return _claim_relic(next, command, catalog)
		"claim-spell":
			return _claim_spell(next, catalog)
		"leave":
			if next.status != "reward":
				return _no("no-reward", "There is nothing to leave behind.")
			next.erase("reward")
			Shardrun.record(next, {"kind": "note", "text": "You leave the rest where it lies."})
			Shardrun.after_room(next, catalog)
			return {}
		"cleanse-relic":
			return _cleanse(next, command, catalog)
		"rest":
			if next.status != "rest":
				return _no("not-resting", "There is nowhere to rest here.")
			var healed := Shardrun.heal_amount(next, float(catalog.balance.rest_heal_fraction))
			next.integrity += healed
			Shardrun.record(
				next, {"kind": "rest", "amount": healed, "text": "You rest and recover %d Integrity." % healed}
			)
			Shardrun.after_room(next, catalog)
			return {}
		"forge":
			return _forge(next, command, catalog)
		"widen":
			return _widen(next, command, catalog)
		"bind":
			return _bind(next, catalog)
		"purge":
			return _purge(next, command, catalog)
		"abandon":
			next.status = "abandoned"
			Shardrun.record(
				next, {"kind": "loss", "text": "You climb back out of the Salvage. The shards stay behind."}
			)
			return {}
	if not next.sandbox:
		return _no("not-a-sandbox", "Dev commands only work in a sandbox run.")
	return ShardrunDev.apply(next, command, catalog)


static func _no(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}


static func _enter(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "map":
		return _no("not-on-map", "Finish the room you are in first.")
	var node := {}
	for candidate: Dictionary in ShardrunMap.next_rooms(next.map, next.position):
		if candidate.id == command.node_id:
			node = candidate
			break
	if node.is_empty():
		return _no("unreachable-node", "No path leads there from here.")
	next.position = node.id
	(next.visited as Array).append(node.id)
	Shardrun.enter_room(next, node, catalog)
	return {}


## Refuses unless every spell is listed exactly once (by count and id). Returns the spells by id, or {} after a refusal.
static func _spells_by_id(next: Dictionary, listed: Array) -> Dictionary:
	var by_id := {}
	for spell: Dictionary in next.spells:
		by_id[spell.id] = spell
	if listed.size() != (next.spells as Array).size():
		return {}
	for change: Dictionary in listed:
		if not by_id.has(change.id):
			return {}
	return by_id


static func _arrange(next: Dictionary, command: Dictionary) -> Dictionary:
	if next.playstyle == "deck":
		return _no("cannot-arrange", "A deck run fills its spells from the hand, during a fight.")
	if not next.status in Shardrun.ARRANGEABLE:
		return _no("cannot-arrange", "Spells can only be rearranged between fights.")
	var listed: Array = command.spells
	var by_id := _spells_by_id(next, listed)
	if by_id.is_empty():
		return _no("unknown-spell", "Every spell must be listed exactly once.")
	for change: Dictionary in listed:
		var spell: Dictionary = by_id[change.id]
		if (change.shards as Array).size() > int(spell.capacity):
			return _no("over-capacity", "%s holds at most %d shards." % [spell.name, spell.capacity])
	var before: Array = []
	for spell: Dictionary in next.spells:
		before.append_array(spell.shards)
	before.append_array(next.inventory)
	var after: Array = []
	for change: Dictionary in listed:
		after.append_array(change.shards)
	after.append_array(command.inventory)
	if not Shardrun.same_multiset(before, after):
		return _no("shards-changed", "Rearranging cannot create or destroy shards.")
	for change: Dictionary in listed:
		(by_id[change.id] as Dictionary).shards = (change.shards as Array).duplicate()
	next.inventory = (command.inventory as Array).duplicate()
	return {}


static func _cast(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "battle" or not next.has("battle"):
		return _no("not-in-battle", "There is nothing to cast at.")
	var battle: Dictionary = next.battle
	var spell := Shardrun.spell_by_id(next, command.spell_id)
	if spell.is_empty():
		return _no("unknown-spell", "No such spell.")
	if spell.id in battle.cast:
		return _no("already-cast", "%s is spent until your next turn." % spell.name)
	var refusal := ShardrunBattle.cast_spell(next, battle, spell, command.outcome, catalog)
	if not refusal.is_empty():
		return refusal
	# A deck run's cast cards are spent: onto the discard pile, leaving the spell blank for the next turn. A cast that
	# won the fight took the battle with it; one whose curse lost the run leaves nothing to draw for.
	if next.playstyle == "deck" and next.has("battle") and int(next.integrity) > 0:
		var played := (spell.shards as Array).size()
		(next.battle.discard as Array).append_array(spell.shards)
		spell.shards = []
		for effect: Dictionary in ShardrunRules.relic_modifiers(next, catalog).draw_on_cast:
			if played < int(effect.min_cards):
				continue
			ShardrunBattle.draw(next, next.battle, int(effect.draw), catalog)
			var text := "A %d-card cast draws %d more." % [played, effect.draw]
			Shardrun.record(next, {"kind": "note", "amount": effect.draw, "text": text})
	return {}


static func _compose(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.playstyle != "deck":
		return _no("not-a-deck-run", "Only a deck run plays cards from a hand.")
	if next.status != "battle" or not next.has("battle"):
		return _no("not-in-battle", "Cards are only played during a fight.")
	var battle: Dictionary = next.battle
	var listed: Array = command.spells
	var by_id := _spells_by_id(next, listed)
	if by_id.is_empty():
		return _no("unknown-spell", "Every spell must be listed exactly once.")
	for change: Dictionary in listed:
		var spell: Dictionary = by_id[change.id]
		if (change.shards as Array).size() > int(spell.capacity):
			return _no("over-capacity", "%s holds at most %d cards." % [spell.name, spell.capacity])
		if spell.id in battle.cast and not Shardrun.same_list(change.shards, spell.shards):
			return _no("already-cast", "%s is spent until your next turn." % spell.name)
	var limit := ShardrunRules.hold_limit(next, catalog)
	if (command.held as Array).size() > limit:
		var noun := "card" if limit == 1 else "cards"
		return _no("hold-full", "You can hold %d %s into the next turn." % [limit, noun])
	var before: Array = []
	for spell: Dictionary in next.spells:
		before.append_array(spell.shards)
	before.append_array(battle.hand)
	before.append_array(battle.held)
	var after: Array = []
	for change: Dictionary in listed:
		after.append_array(change.shards)
	after.append_array(command.hand)
	after.append_array(command.held)
	if not Shardrun.same_multiset(before, after):
		return _no("cards-changed", "Playing cards cannot create or destroy them.")
	for change: Dictionary in listed:
		(by_id[change.id] as Dictionary).shards = (change.shards as Array).duplicate()
	battle.hand = (command.hand as Array).duplicate()
	battle.held = (command.held as Array).duplicate()
	return {}


static func _end_turn(next: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "battle" or not next.has("battle"):
		return _no("not-in-battle", "There is no turn to end.")
	var battle: Dictionary = next.battle
	ShardrunBattle.enemy_turn(next, battle)
	if int(next.integrity) <= 0:
		ShardrunBattle.lose(next)
		return {}
	ShardrunBattle.new_turn(next, battle, catalog)
	return {}


static func _take(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var reward: Dictionary = next.get("reward", {})
	if next.status != "reward" or not reward.has("shards"):
		return _no("no-shards", "There are no shards to take.")
	var shard_id: Variant = command.get("shard_id")
	if shard_id != null:
		if not shard_id in reward.shards:
			return _no("not-offered", "That shard was not offered.")
		var name: String = (catalog.shards.get(shard_id, {}) as Dictionary).get("name", shard_id)
		next.stats.shards += 1
		if next.playstyle == "deck":
			(next.deck as Array).append(shard_id)
			Shardrun.record(next, {"kind": "reward", "text": "%s joins your deck." % name})
		else:
			(next.inventory as Array).append(shard_id)
			Shardrun.record(next, {"kind": "reward", "text": "You salvage %s." % name})
	reward.erase("shards")
	Shardrun.settle_reward(next, catalog)
	return {}


static func _open_chest(next: Dictionary, catalog: Dictionary) -> Dictionary:
	var reward: Dictionary = next.get("reward", {})
	if next.status != "reward" or not reward.has("chest"):
		return _no("no-chest", "There is no sealed chest to open.")
	var chest: Dictionary = reward.chest
	# LEARN: the stream belongs to the room, not the revision: reloading or rearranging cannot reroll it.
	var rng := Rng.create(next.seed, "cache:%d:%s" % [next.layer, JsMath.text(next.position)])
	var curses := Shardrun.curses_left(next, catalog)
	if rng.next() < float(chest.curse_chance) and not curses.is_empty():
		var curse: Dictionary = curses[floori(rng.next() * curses.size())]
		Shardrun.gain_relic(next, curse, catalog)
		next.reward = {"cursed_relic": curse.id}
		var text := "The seal breaks. A curse binds itself to your run; a rest can cleanse it instead of healing."
		Shardrun.record(next, {"kind": "note", "text": text})
	else:
		var relics := ShardrunBattle.draft_relics(
			next, "treasure", int(catalog.balance.treasure_relic_choices), catalog
		)
		next.reward = {"relics": relics} if not relics.is_empty() else {}
		var text := "The cache opens safely. Choose a relic." if not relics.is_empty() else "The cache is empty."
		Shardrun.record(next, {"kind": "note", "text": text})
		Shardrun.settle_reward(next, catalog)
	return {}


static func _claim_relic(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var reward: Dictionary = next.get("reward", {})
	if next.status != "reward" or not reward.has("relics"):
		return _no("no-relics", "There is no relic to claim.")
	var relic: Dictionary = catalog.relics.get(command.relic_id, {})
	if relic.is_empty() or not relic.id in reward.relics:
		return _no("not-offered", "That relic was not offered.")
	Shardrun.gain_relic(next, relic, catalog)
	reward.erase("relics")
	Shardrun.settle_reward(next, catalog)
	return {}


static func _claim_spell(next: Dictionary, catalog: Dictionary) -> Dictionary:
	var reward: Dictionary = next.get("reward", {})
	if next.status != "reward" or not reward.has("spell"):
		return _no("no-spell", "There is no new spell here.")
	if (next.spells as Array).size() >= int(catalog.balance.max_spells):
		return _no("too-many-spells", "Your spellbook is full.")
	var offered: Dictionary = reward.spell
	var id := "spell-%d" % ((next.spells as Array).size() + 1)
	var capacity := int(offered.capacity)
	(next.spells as Array).append({"id": id, "name": offered.name, "capacity": capacity, "shards": []})
	var text := "A new spell, %s, with %d empty slots." % [offered.name, capacity]
	Shardrun.record(next, {"kind": "spell", "spell": id, "text": text})
	reward.erase("spell")
	Shardrun.settle_reward(next, catalog)
	return {}


static func _cleanse(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "rest":
		return _no("not-resting", "Curses can only be cleansed at a rest.")
	var index := (next.relics as Array).find(command.relic_id)
	var relic: Dictionary = catalog.relics.get(command.relic_id, {})
	if index < 0 or not relic.get("cursed", false):
		return _no("not-cursed", "That is not a curse you carry.")
	(next.relics as Array).remove_at(index)
	Shardrun.record(next, {"kind": "rest", "text": "You cleanse %s instead of healing." % relic.name})
	Shardrun.after_room(next, catalog)
	return {}


static func _forge(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "forge":
		return _no("no-forge", "There is no forge here.")
	var shard_id: Variant = command.get("shard_id")
	if shard_id == null:
		Shardrun.record(next, {"kind": "note", "text": "You leave the forge as you found it."})
		Shardrun.after_room(next, catalog)
		return {}
	var shard: Dictionary = catalog.shards.get(shard_id, {})
	var forge: Dictionary = shard.get("forge", {})
	if shard.is_empty() or not forge.has("into"):
		return _no("cannot-forge", "That shard cannot be reworked.")
	var into: String = forge.into
	if next.playstyle == "deck":
		var card := (next.deck as Array).find(shard.id)
		if card < 0:
			return _no("not-owned", "That card is not in your deck.")
		next.deck[card] = into
	else:
		var holder := {}
		for spell: Dictionary in next.spells:
			if shard.id in spell.shards:
				holder = spell
				break
		var index := (next.inventory as Array).find(shard.id)
		if not holder.is_empty():
			holder.shards[(holder.shards as Array).find(shard.id)] = into
		elif index >= 0:
			next.inventory[index] = into
		else:
			return _no("not-owned", "You do not carry that shard.")
	var verb := "repair" if forge.get("verb") == "repair" else "upgrade"
	var into_name: String = (catalog.shards.get(into, {}) as Dictionary).get("name", into)
	Shardrun.record(next, {"kind": "forge", "text": "You %s %s into %s." % [verb, shard.name, into_name]})
	Shardrun.after_room(next, catalog)
	return {}


static func _widen(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "forge":
		return _no("no-forge", "There is no forge here.")
	var spell := Shardrun.spell_by_id(next, command.spell_id)
	if spell.is_empty():
		return _no("unknown-spell", "No such spell.")
	if int(spell.capacity) >= int(catalog.balance.max_spell_capacity):
		return _no("too-wide", "%s cannot hold more shards." % spell.name)
	spell.capacity += 1
	var text := "You widen %s to %d slots." % [spell.name, spell.capacity]
	Shardrun.record(next, {"kind": "forge", "spell": spell.id, "text": text})
	Shardrun.after_room(next, catalog)
	return {}


static func _bind(next: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "forge":
		return _no("no-forge", "There is no forge here.")
	var bound := Shardrun.bind_spell(next, catalog)
	if bound.is_empty():
		return _no("cannot-bind", "There is no room in your spellbook for another spell.")
	var text := "You bind a new spell, %s, with %d empty slots." % [bound.name, bound.capacity]
	Shardrun.record(next, {"kind": "spell", "spell": bound.id, "text": text})
	Shardrun.after_room(next, catalog)
	return {}


static func _purge(next: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	if next.status != "forge":
		return _no("no-forge", "There is no forge here.")
	if next.playstyle != "deck":
		return _no("not-a-deck-run", "Only a deck run has cards to melt down.")
	var index := (next.deck as Array).find(command.shard_id)
	if index < 0:
		return _no("not-owned", "That card is not in your deck.")
	var smallest := int(catalog.balance.deck.min_cards)
	if (next.deck as Array).size() <= smallest:
		return _no("deck-too-small", "A deck cannot be pruned below %d cards." % smallest)
	(next.deck as Array).remove_at(index)
	var name: String = (catalog.shards.get(command.shard_id, {}) as Dictionary).get("name", command.shard_id)
	var text := "You melt %s down. %d cards remain." % [name, (next.deck as Array).size()]
	Shardrun.record(next, {"kind": "forge", "text": text})
	Shardrun.after_room(next, catalog)
	return {}
