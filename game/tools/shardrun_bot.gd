class_name ShardrunBot
extends RefCounted
## A simple player that plays a run through a ShardrunSession, for tests and tools: it walks the map, slots what it
## finds, casts whatever it can afford, and takes the first thing offered. It is not clever, only thorough: every
## command it sends should be accepted, and every run it plays should end.
##
##   var bot := ShardrunBot.new(session)
##   var report: Dictionary = await bot.play(400)    # {steps, refusals: [..], status}

const ROOM_ORDER: Array[String] = ["fight", "rest", "forge", "treasure", "elite", "boss"]
## A fight still going after this many turns is one the bot cannot win (a thick hide its bolts glance off, a ward that
## blocks everything): it abandons the run, as a player would.
const STALEMATE_TURNS := 50

var session: ShardrunSession
## A kind of room to walk into whenever one is open (a tool heading for a forge, say); "" for the usual order.
var prefer := ""
var refusals: Array[Dictionary] = []
var steps := 0


func _init(run_session: ShardrunSession) -> void:
	session = run_session


## Plays until the run ends, the session goes idle, or `limit` commands have been sent.
func play(limit := 1000) -> Dictionary:
	while steps < limit and session.in_progress():
		var command := await next_command()
		if command.is_empty():
			break
		await send(command)
	return {"steps": steps, "refusals": refusals, "status": session.state.get("status", "")}


## Plays until the state's status is `status` (or the run ends); for tools that want a particular screen.
func play_until(status: String, limit := 200) -> void:
	while steps < limit and session.in_progress() and session.state.status != status:
		var command := await next_command()
		if command.is_empty():
			return
		await send(command)


func send(command: Dictionary) -> Dictionary:
	steps += 1
	var result: Dictionary = await session.command(command)
	if not result.ok:
		refusals.append({"command": command, "error": result.error, "status": session.state.status})
	return result


func next_command() -> Dictionary:
	var state := session.state
	var catalog := session.catalog
	match state.status:
		"map":
			var better := _arrangement(state)
			if not better.is_empty():
				return better
			return _pick_room(state)
		"battle":
			return await _battle_move(state)
		"reward":
			return _reward_move(state)
		"rest":
			var cursed := ShardrunViews.cursed_relics(state, catalog)
			if not cursed.is_empty() and int(state.integrity) * 2 > int(state.integrity_max):
				return {"type": "cleanse-relic", "relic_id": cursed[0].id}
			return {"type": "rest"}
		"forge":
			var options := ShardrunViews.forge_options(state, catalog)
			if not (options.shards as Array).is_empty():
				return {"type": "forge", "shard_id": options.shards[0]}
			if not (options.bind as Dictionary).is_empty():
				return {"type": "bind"}
			if not (options.spells as Array).is_empty():
				return {"type": "widen", "spell_id": options.spells[0]}
			return {"type": "forge", "shard_id": null}
	return {}


func _pick_room(state: Dictionary) -> Dictionary:
	var rooms := ShardrunMap.next_rooms(state.map, state.position)
	if rooms.is_empty():
		return {}
	rooms.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if (a.kind == prefer) != (b.kind == prefer):
				return a.kind == prefer
			return ROOM_ORDER.find(a.kind) < ROOM_ORDER.find(b.kind)
	)
	return {"type": "enter", "node_id": rooms[0].id}


func _battle_move(state: Dictionary) -> Dictionary:
	var battle: Dictionary = state.battle
	if int(battle.turn) > STALEMATE_TURNS:
		return {"type": "abandon"}
	var previews: Dictionary = await session.previews()
	for spell: Dictionary in state.spells:
		var view: Dictionary = previews.spells.get(spell.id, {})
		if not spell.id in battle.cast and view.get("affordable", false):
			return {"type": "cast", "spell_id": spell.id}
	return {"type": "end-turn"}


func _reward_move(state: Dictionary) -> Dictionary:
	var reward: Dictionary = state.get("reward", {})
	if reward.has("chest"):
		return {"type": "open-chest"}
	if reward.has("spell"):
		return {"type": "claim-spell"}
	if reward.has("relics") and not (reward.relics as Array).is_empty():
		return {"type": "claim-relic", "relic_id": reward.relics[0]}
	if reward.has("shards") and not (reward.shards as Array).is_empty():
		return {"type": "take", "shard_id": reward.shards[0]}
	return {"type": "leave"}


## Spare shards slotted into spells with room, as an `arrange` command; {} when there is nothing to move.
func _arrangement(state: Dictionary) -> Dictionary:
	var spare: Array = (state.inventory as Array).duplicate()
	if spare.is_empty():
		return {}
	var spells: Array = []
	var moved := false
	for spell: Dictionary in state.spells:
		var shards: Array = (spell.shards as Array).duplicate()
		while shards.size() < int(spell.capacity) and not spare.is_empty():
			shards.append(spare.pop_front())
			moved = true
		spells.append({"id": spell.id, "shards": shards})
	return {"type": "arrange", "spells": spells, "inventory": spare} if moved else {}
