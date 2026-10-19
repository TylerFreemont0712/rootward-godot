class_name ThingTown
extends RefCounted
## The town's side of the things that take code (ADR-0061): the screen's part, split out of the screen for its length.
## ThingHost runs a thing's code and judges the answer; this puts the answer into the town: the state (kept, saved and
## drawn), Hotaru's bubble, the thing's own text in the talk box, and Hotaru's line for a thing's first answer. It reads
## the screen's state and speaks through the screen's own bubble and talk, so it calls the screen's methods.
##
##   var things := ThingTown.new(self)     # in the screen's _build, then add_child(things.host)
##   things.use_if_code(thing)             # Space on the thing ahead: its code runs once, when it takes code
##   things.edit_ahead()                   # X on the thing ahead: its code opens in the editor
##   things.step_on(cell)                  # the player arrived on a cell: the plates there answer on_step
## A thing's answer that changed its fields reaches the things it links to, each answering on_change (TownWires), at
## most TownWires.MAX_CHAIN links from the player's own action and each thing once.

var host: ThingHost
var _screen: OverworldScreen
## The things this chain of links has run, so a loop of links stops.
var _visited: Dictionary = {}


func _init(screen: OverworldScreen) -> void:
	_screen = screen
	host = ThingHost.new()
	host.setup(screen.catalog.things, func() -> Dictionary: return screen.state)
	host.state_changed.connect(_on_state_changed)
	host.spoke.connect(_on_spoke)
	host.first_answer.connect(_on_first_answer)
	host.answered.connect(_on_answered)


## Space on a thing: its code runs once.
func use(thing: Dictionary) -> void:
	host.use(thing, BootsRules.taught(_screen.table))


## X on a thing: its code opens in the editor. Only a thing with a program takes code, once it is unlocked.
func edit(thing: Dictionary) -> void:
	if active(thing):
		host.edit(thing, BootsRules.taught(_screen.table))
	else:
		_screen._hotaru_says(Text.t("Face a thing that takes code, then press X."))


## Space on the thing the player faces, when it takes code: its code runs once. False, and nothing runs, for any other
## (a thing still locked is any other: a plain prop; so is a plate or a door that answers only its links).
func use_if_code(thing: Dictionary) -> bool:
	if not active(thing) or TownWires.hook_of(thing) != TownThings.HOOK:
		return false
	use(thing)
	return true


## Whether a thing takes code now: it has a program, and its `unlocked_by` holds (TownThings.unlocked).
func active(thing: Dictionary) -> bool:
	return ThingHost.takes_code(thing) and TownThings.unlocked(thing, _screen.state.get("flags", {}))


## The player arrived on `cell`: each unlocked thing there that answers on_step runs (a plate).
func step_on(cell: Vector2i) -> void:
	for thing: Dictionary in TownWires.step_targets(_screen._current().get("objects", []), cell):
		if TownThings.unlocked(thing, _screen.state.get("flags", {})):
			host.run_hook(thing, BootsRules.taught(_screen.table), "on_step")


## An answer landed: when it changed the thing's fields, the things it links to answer on_change, each once a chain.
func _on_answered(thing: Dictionary, verdict: Dictionary, depth: int) -> void:
	var id := String(thing.get("id", ""))
	if depth == 0:
		_visited = {}
	_visited[id] = true
	var changes: Dictionary = verdict.get("changes", {}) if verdict.get("changes", {}) is Dictionary else {}
	if changes.is_empty() or depth >= TownWires.MAX_CHAIN:
		return
	var saved: Dictionary = (_screen.state.get("things", {}) as Dictionary).get(id, {})
	var fields := TownThings.fields_of(thing, saved.get("fields", {}) if saved.get("fields", {}) is Dictionary else {})
	var source := TownWires.source_of(id, fields, changes)
	var flags: Dictionary = _screen.state.get("flags", {})
	for target: Dictionary in TownWires.change_targets(_screen._current().get("objects", []), id, _visited):
		_visited[String(target.get("id", ""))] = true
		if TownThings.unlocked(target, flags):
			host.run_hook(target, BootsRules.taught(_screen.table), "on_change", source, depth + 1)


## X on the thing the player faces (see edit; a thing with no code makes Hotaru say so).
func edit_ahead() -> void:
	edit(thing_ahead())


## The thing the player faces, or {} while they walk (the editor is not opened mid-step).
func thing_ahead() -> Dictionary:
	if _screen._player.moving:
		return {}
	return OverworldMap.thing_at(_screen._current(), OverworldMap.ahead(_screen._player.cell, _screen._player.facing))


## True while the editor is open or a run is in the sandbox.
func busy() -> bool:
	return host.busy()


## The town's state after an answer, or a kept code: kept, saved, and drawn as it now is.
func _on_state_changed(next: Dictionary) -> void:
	_screen.state = next
	_screen._save()
	_screen._draw_map()


## Hotaru's words, and the thing's own text in the talk box.
func _on_spoke(bubble: String, reading: String) -> void:
	if bubble != "":
		_screen._hotaru_says(bubble)
	if reading != "":
		_screen._talk.say([{"text": reading, "speaker": "", "mood": ""}], {"name": ""}, _screen.state.flags)


## Hotaru's line for a thing's first answer. Her talk picks its line from the flags, so it is said once.
func _on_first_answer() -> void:
	var talk: Dictionary = _screen.catalog.talk.get("hotaru-first-action", {})
	if Talk.opening(talk, _screen.state.flags) != "":
		_screen._hotaru_talk("hotaru-first-action")
