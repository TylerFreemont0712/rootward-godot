class_name ShardrunDev
extends RefCounted
## The dev commands of a sandbox run (old ADR-0013): the ordinary rules plus commands that grant and set things.
## Shardrun.step only reaches these for a run started with `sandbox: true`.
##
## dev-grant-shard {shard_id}, dev-remove-shard {shard_id}, dev-grant-relic {relic_id}, dev-remove-relic {relic_id},
## dev-grant-spell {name, capacity}, dev-set {integrity?, mana?}, dev-spawn {kind, foes}, dev-end-battle {outcome},
## dev-goto-layer {layer}.


static func apply(state: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	match command.type:
		"dev-grant-shard":
			var shard: Dictionary = catalog.shards.get(command.shard_id, {})
			if shard.is_empty():
				return _no("unknown-shard", "No such shard.")
			if state.playstyle == "deck":
				# Into the deck, and straight into the hand during a fight, so a granted card can be tried at once.
				(state.deck as Array).append(shard.id)
				if state.has("battle"):
					(state.battle.hand as Array).append(shard.id)
			else:
				(state.inventory as Array).append(shard.id)
			_note(state, "granted %s" % shard.name)
		"dev-remove-shard":
			return _remove_shard(state, command.shard_id, catalog)
		"dev-grant-relic":
			var relic: Dictionary = catalog.relics.get(command.relic_id, {})
			if relic.is_empty():
				return _no("unknown-relic", "No such relic.")
			if relic.id in state.relics:
				return _no("already-held", "%s is already held." % relic.name)
			Shardrun.gain_relic(state, relic, catalog)
		"dev-remove-relic":
			var index := (state.relics as Array).find(command.relic_id)
			if index < 0:
				return _no("not-owned", "That relic is not in this run.")
			(state.relics as Array).remove_at(index)
			_note(
				state,
				"removed %s" % (catalog.relics.get(command.relic_id, {}) as Dictionary).get("name", command.relic_id)
			)
		"dev-grant-spell":
			var id := "spell-%d" % ((state.spells as Array).size() + 1)
			(state.spells as Array).append(
				{"id": id, "name": command.name, "capacity": int(command.capacity), "shards": []}
			)
			_note(state, "added the spell %s" % command.name)
		"dev-set":
			if command.has("integrity") and command.integrity != null:
				state.integrity = maxi(0, mini(int(state.integrity_max), int(command.integrity)))
				_note(state, "Integrity set to %d" % state.integrity)
			if command.has("mana") and command.mana != null and state.has("battle"):
				state.battle.mana = maxi(0, int(command.mana))
				_note(state, "mana set to %d" % state.battle.mana)
		"dev-spawn":
			return _spawn(state, command, catalog)
		"dev-end-battle":
			if not state.has("battle"):
				return _no("not-in-battle", "There is no fight to end.")
			var battle: Dictionary = state.battle
			if command.outcome == "lose":
				state.integrity = 0
				ShardrunBattle.lose(state)
				return {}
			for foe: Dictionary in battle.foes:
				foe.hp = 0
			_note(state, "won the fight")
			ShardrunBattle.win(state, battle, catalog)
		"dev-goto-layer":
			var layers: Array = catalog.config.layers
			var index := int(command.layer)
			if index < 0 or index >= layers.size():
				return _no("unknown-layer", "No such layer.")
			var layer: Dictionary = layers[index]
			state.layer = index
			state.map = ShardrunMap.generate(state.seed, index, layer)
			state.position = null
			state.visited = []
			state.erase("battle")
			state.erase("reward")
			ShardrunBattle.clear_spells(state)
			state.status = "map"
			_note(state, "jumped to %s" % layer.name)
		_:
			return _no("unknown-command", "That is not a dev command.")
	return {}


static func _no(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message}


static func _note(state: Dictionary, text: String) -> void:
	Shardrun.record(state, {"kind": "note", "text": "[dev] %s" % text})


static func _remove_shard(state: Dictionary, shard_id: String, catalog: Dictionary) -> Dictionary:
	var name: String = (catalog.shards.get(shard_id, {}) as Dictionary).get("name", shard_id)
	if state.playstyle == "deck":
		var card := (state.deck as Array).find(shard_id)
		if card < 0:
			return _no("not-owned", "That card is not in this deck.")
		(state.deck as Array).remove_at(card)
		if state.has("battle"):
			# The copy leaves the fight too: from the hand first, then the piles, then a spell.
			var battle: Dictionary = state.battle
			var holders: Array = [battle.hand, battle.held, battle.draw, battle.discard]
			for spell: Dictionary in state.spells:
				holders.append(spell.shards)
			for holder: Array in holders:
				if shard_id in holder:
					holder.remove_at(holder.find(shard_id))
					break
		_note(state, "removed %s" % name)
		return {}
	var spare := (state.inventory as Array).find(shard_id)
	if spare >= 0:
		(state.inventory as Array).remove_at(spare)
	else:
		var holder := {}
		for spell: Dictionary in state.spells:
			if shard_id in spell.shards:
				holder = spell
				break
		if holder.is_empty():
			return _no("not-owned", "That shard is not in this run.")
		(holder.shards as Array).remove_at((holder.shards as Array).find(shard_id))
	_note(state, "removed %s" % name)
	return {}


static func _spawn(state: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var foes := ShardrunBattle.foe_states(state, command.foes, "dev-%d" % state.revision, catalog)
	if foes.is_empty():
		return _no("unknown-foe", "No such foes.")
	state.erase("reward")
	var battle := ShardrunBattle.new_battle(state, command.kind, foes, catalog)
	ShardrunBattle.begin_turn(battle)
	state.battle = battle
	state.status = "battle"
	ShardrunBattle.deal(state, battle, catalog)
	var names := " and ".join(foes.map(func(foe: Dictionary) -> String: return foe.name))
	_note(state, "spawned %s" % names)
	# Logged exactly as a room's fight is, so a spawned guardian makes its entrance on the stage (old ADR-0019).
	Shardrun.record(state, {"kind": "enter", "text": ShardrunBattle.entrance(foes)})
	return {}
