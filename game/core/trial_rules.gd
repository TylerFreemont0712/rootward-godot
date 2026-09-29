class_name TrialRules
extends RefCounted
## A tiny scripted route around the real program rules. Progress is data in the run snapshot, never scene state.


static func begin(state: Dictionary, content: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	var setup: Dictionary = content.setup
	next.status = "map"
	next.erase("draft")
	next.paradigm = setup.paradigm
	next.deck = (setup.deck as Array).duplicate()
	next.map = (setup.map as Dictionary).duplicate(true)
	var rows := 0
	var columns := 0
	for node: Dictionary in next.map.nodes:
		if node.kind != "boss":
			rows = maxi(rows, int(node.row) + 1)
			columns = maxi(columns, int(node.col) + 1)
	var room_foes := {}
	for room_id: String in setup.rooms:
		var foes: Array = setup.rooms[room_id].get("foes", [])
		if not foes.is_empty():
			room_foes[room_id] = String(foes[0].id)
	next.position = null
	next.visited = []
	next.trial = {
		"active": true,
		"done": false,
		"step_id": String(content.steps[0].id),
		"chapter_id": String(content.steps[0].chapter),
		"completed": [],
		"checkpoint": {},
		"failures": 0,
		"pending": [],
		"hint": "",
		"map_rows": rows,
		"map_columns": columns,
		"room_foes": room_foes,
	}
	return next


## Observe only an accepted session command. A failed fight restores the last real battle snapshot.
static func after_command(
	before: Dictionary, state: Dictionary, command: Dictionary, content: Dictionary, catalog: Dictionary
) -> Dictionary:
	var next := state
	if next.status == "lost":
		var saved: Dictionary = before.trial.get("checkpoint", {})
		if not saved.is_empty():
			next = saved.duplicate(true)
			next.trial.checkpoint = saved
			next.trial.failures = int(before.trial.get("failures", 0)) + 1
			next.trial.hint = String(content.get("loss_hint", "Read the preview and try again."))
			return next
	if command.type == "enter":
		_apply_room(next, String(command.node_id), content, catalog)
	var event := _command_event(before, next, command)
	_observe(next, event, content)
	if command.type == "enter" and next.status == "battle":
		var checkpoint := next.duplicate(true)
		checkpoint.trial.checkpoint = {}
		next.trial.checkpoint = checkpoint
	if before.status == "battle" and next.status != "battle" and next.status != "lost":
		var room := _room(next)
		var rooms: Dictionary = content.setup.get("rooms", {})
		var script: Dictionary = rooms.get(room, {})
		if script.has("reward"):
			next.reward = (script.reward as Dictionary).duplicate(true)
			next.status = "reward"
		_observe(next, {"type": "battle-won", "room": room}, content)
	return next


static func coach_next(state: Dictionary, content: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	_observe(next, {"type": "coach-next", "room": _room(next)}, content)
	return next


static func _command_event(before: Dictionary, state: Dictionary, command: Dictionary) -> Dictionary:
	var event := {"type": String(command.type), "room": _room(state), "cards": [], "log_kinds": []}
	for index in range((before.get("log", []) as Array).size(), (state.get("log", []) as Array).size()):
		(event.log_kinds as Array).append(String(state.log[index].kind))
	if command.type == "compose":
		for spell: Dictionary in command.get("spells", []):
			(event.cards as Array).append_array(spell.get("shards", []))
	elif command.type == "cast":
		var spell := Shardrun.spell_by_id(before, String(command.get("spell_id", "")))
		if not spell.is_empty():
			(event.cards as Array).append_array(spell.shards)
	return event


static func _room(state: Dictionary) -> String:
	return String(state.position) if state.get("position") != null else ""


static func current(state: Dictionary, content: Dictionary) -> Dictionary:
	return TrialContent.step(content, String((state.get("trial", {}) as Dictionary).get("step_id", "")))


## A short lesson needs a short score scale. The full-run completion bonus would dwarf its two fights.
static func score(state: Dictionary) -> Dictionary:
	var stats: Dictionary = state.stats
	var parts := {
		"progress": mini(30, int(stats.fights) * 15),
		"combat": mini(20, floori(float(stats.damage) / 5.0)),
		"build": mini(20, int(stats.relics) * 10 + (10 if "fib-memo" in state.deck else 0)),
		"survival": roundi(20.0 * float(state.integrity) / maxf(1.0, float(state.integrity_max))),
		"tempo": mini(10, roundi(20.0 / maxf(1.0, float(stats.turns)))),
	}
	var total := 0
	for value: int in parts.values():
		total += value
	return {"total": total, "breakdown": parts}


static func _apply_room(state: Dictionary, room: String, content: Dictionary, catalog: Dictionary) -> void:
	var script: Dictionary = content.setup.get("rooms", {}).get(room, {})
	if script.is_empty() or state.status != "battle":
		return
	if script.has("foes"):
		var ids: Array = (script.foes as Array).map(func(foe: Dictionary) -> String: return String(foe.id))
		var foes := ShardrunBattle.foe_states(state, ids, room, catalog)
		for index in mini(foes.size(), (script.foes as Array).size()):
			var hp := int(script.foes[index].get("hp", foes[index].hp))
			foes[index].hp = hp
			foes[index].max = hp
			if script.foes[index].has("tempo"):
				for intent: Dictionary in foes[index].intents:
					intent.tempo = int(script.foes[index].tempo)
		state.battle.foes = foes
	if script.has("hand"):
		state.battle.hand = (script.hand as Array).duplicate()
		state.battle.draw = (script.get("draw", []) as Array).duplicate()
		state.battle.discard = []


static func _observe(state: Dictionary, event: Dictionary, content: Dictionary) -> void:
	var step := current(state, content)
	if _matches(step, event):
		_advance(state, content)
	else:
		# A strong cast may finish a fight before Pip reaches its victory line. Hold that event for that room.
		if event.type == "battle-won":
			(state.trial.pending as Array).append(event)
	_drain_pending(state, content)


static func _matches(step: Dictionary, event: Dictionary) -> bool:
	if step.is_empty() or step.event != event.type or (step.has("room") and step.room != event.room):
		return false
	if step.has("required_card") and not step.required_card in event.get("cards", []):
		return false
	if step.has("ordered_cards"):
		var cards: Array = event.get("cards", [])
		var previous := -1
		for card: String in step.ordered_cards:
			var at := cards.find(card)
			if at <= previous:
				return false
			previous = at
	if step.has("log_kind") and not step.log_kind in event.get("log_kinds", []):
		return false
	if step.has("exclude_log_kind") and step.exclude_log_kind in event.get("log_kinds", []):
		return false
	return true


static func _drain_pending(state: Dictionary, content: Dictionary) -> void:
	var pending: Array = state.trial.pending
	for event: Dictionary in pending.duplicate():
		if _matches(current(state, content), event):
			pending.erase(event)
			_advance(state, content)


static func _advance(state: Dictionary, content: Dictionary) -> void:
	var steps: Array = content.steps
	var index := -1
	for i in steps.size():
		if steps[i].id == state.trial.step_id:
			index = i
			break
	if index < 0:
		return
	(state.trial.completed as Array).append(String(steps[index].id))
	if index + 1 >= steps.size():
		state.trial.done = true
		state.trial.active = false
		return
	var following: Dictionary = steps[index + 1]
	state.trial.step_id = String(following.id)
	state.trial.chapter_id = String(following.chapter)
	state.trial.hint = ""
	# LEARN: content can force a small setup change when a step begins; combat still uses the normal rules.
	for path: String in following.get("force", {}):
		var keys := path.split(".")
		var branch := state
		for key in keys.slice(0, keys.size() - 1):
			branch = branch[key]
		branch[keys[-1]] = following.force[path]
