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
	next.position = null
	next.visited = []
	next.trial = {
		"active": true,
		"done": false,
		"step_id": String(content.steps[0].id),
		"chapter_id": String(content.steps[0].chapter),
		"checkpoint": {},
		"failures": 0,
		"pending": [],
		"hint": "",
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
			next.trial.hint = "Try a faster card or put a guard before the next hit. Read the preview again."
			return next
	if command.type == "enter":
		_apply_room(next, String(command.node_id), content, catalog)
	var event := {"type": String(command.type), "room": _room(next)}
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


static func _room(state: Dictionary) -> String:
	return String(state.position) if state.get("position") != null else ""


static func current(state: Dictionary, content: Dictionary) -> Dictionary:
	return TrialContent.step(content, String((state.get("trial", {}) as Dictionary).get("step_id", "")))


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
	return not step.is_empty() and step.event == event.type and (not step.has("room") or step.room == event.room)


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
	if index + 1 >= steps.size():
		state.trial.done = true
		state.trial.active = false
		return
	var following: Dictionary = steps[index + 1]
	state.trial.step_id = String(following.id)
	state.trial.chapter_id = String(following.chapter)
	state.trial.hint = ""
	# LEARN: content can force a small setup change when a step begins; combat still uses the normal rules.
	for key: String in following.get("force", {}):
		state[key] = following.force[key]
