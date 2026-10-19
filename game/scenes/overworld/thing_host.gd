class_name ThingHost
extends Control
## The things in Lanternroot that take code (ADR-0061, TownThings): Space runs a thing's code once, and X opens that
## code in an editor (ThingEditor). A run goes to the sandbox on a thread (Background.run, ThingRun.run), and
## TownThings judges the answer. The answer lands in the town through three signals: state_changed (the town's next
## state), spoke (what Hotaru says) and first_answer (Hotaru's line for a thing's first answer). The town's state is
## read when it is needed, through the Callable setup() gives, and never kept: a step can land while the sandbox runs.
##
##   host.setup(files, func() -> Dictionary: return state)   # the things' content, and how to read the town's state
##   host.use(thing, keys)                                   # Space: the thing's code runs once
##   host.edit(thing, keys)                                  # X: the thing's code opens in the editor
##   ThingHost.applied(state, id, verdict)                   # the state after an answer: its changes and flags

## The town's state changed (an answer, or code kept): the next state, which the town keeps and draws.
signal state_changed(next: Dictionary)
## What Hotaru says: `bubble` is her words for the answer, `reading` the thing's own text when its code said nothing or
## went wrong. Either may be "".
signal spoke(bubble: String, reading: String)
## A thing's first answer: Hotaru's line about it may be said now.
signal first_answer
## A thing's code ran (Space, or the editor's Run): its id, what it was given, what the sandbox gave back, the verdict
## and the microseconds it took, for the developer inspector's event log (Studio S7).
signal ran(thing_id: String, input: Dictionary, run: Dictionary, verdict: Dictionary, usec: int)
## A run's answer has landed in the town: the thing, its verdict, and how many links led to it (0: the player's own
## use or step). The town follows the thing's links from here (ThingTown, Studio S8).
signal answered(thing: Dictionary, verdict: Dictionary, depth: int)

var _files: Dictionary = {}
var _state_now: Callable
var _editor: ThingEditor
var _running := false
## The thing the code is for (Space's, or the editor's), and the keys the boots know, which the editor's Run uses.
var _thing: Dictionary = {}
var _keys: Array[String] = []
## A first answer came while the editor was open: Hotaru's line about it waits until the editor closes.
var _beat_waiting := false
## Runs that wait for the one on its way (a link's on_change, a step's on_step): {thing, keys, hook, source, depth}.
var _queue: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_editor = ThingEditor.new()
	_editor.run_asked.connect(_on_run_asked)
	_editor.closed.connect(_on_closed)
	add_child(_editor)


## The things' content by id (name, hints, starters), and how to read the town's state as it is now.
func setup(files: Dictionary, state_now: Callable) -> void:
	_files = files
	_state_now = state_now


## True while the editor is open: the town is paused behind it.
func editing() -> bool:
	return _editor.visible


## True while the editor is open or a run is in the sandbox: the town does not walk or act.
func busy() -> bool:
	return _editor.visible or _running


## Runs the thing's code once (the code it keeps, else its starter) on a thread, and lands the answer. `keys` are the
## keys the boots know: the starters read thing.keys. A run already on its way is not started twice.
func use(thing: Dictionary, keys: Array[String]) -> void:
	run_hook(thing, keys, TownThings.HOOK)


## Runs the thing's code for `hook` (on_use, on_step, on_change; Studio S8) and lands the answer. `source` is what a
## linked thing changed (on_change), `depth` how many links led here. While a run is on its way a player's second
## Space is dropped, and a link's or a step's run waits its turn.
func run_hook(thing: Dictionary, keys: Array[String], hook := TownThings.HOOK, source := {}, depth := 0) -> void:
	if _running:
		if hook != TownThings.HOOK or depth > 0:
			_queue.append({"thing": thing, "keys": keys, "hook": hook, "source": source, "depth": depth})
		return
	_running = true
	_thing = thing
	var before: Dictionary = _state_now.call()
	var id := String(thing.get("id", ""))
	var file: Dictionary = _files.get(id, {})
	var language := String(before.get("language", BootsCode.PYTHON))
	var code := source_of(before, id, language, file)
	var fields := TownThings.fields_of(thing, _saved_fields(before, id))
	var args := TownThings.use_input(thing, fields, Lessons.player_of(before), keys, String(thing.get("text", "")))
	if not source.is_empty():
		(args.thing as Dictionary)["source"] = source.duplicate(true)
	var standing := covers(thing, OverworldState.cell(before))
	var started := Time.get_ticks_usec()
	var run: Dictionary = await Background.run(func() -> Dictionary: return ThingRun.run(language, code, args, hook))
	_running = false
	var verdict := TownThings.judge_use(thing, run, standing)
	ran.emit(id, args, run, verdict, Time.get_ticks_usec() - started)
	_landed(id, verdict, trouble_of(file, run, verdict))
	answered.emit(thing, verdict, depth)
	if not _running and not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		run_hook(next.thing, next.keys, String(next.hook), next.source, int(next.depth))


## The arguments a run of the thing would get now (its fields, the player, the keys, its text), for the developer
## inspector to show and change before a re-run.
func input_of(thing: Dictionary, keys: Array[String]) -> Dictionary:
	var state: Dictionary = _state_now.call()
	var id := String(thing.get("id", ""))
	var fields := TownThings.fields_of(thing, _saved_fields(state, id))
	return TownThings.use_input(thing, fields, Lessons.player_of(state), keys, String(thing.get("text", "")))


## Runs the thing's code with `args` (chosen in the developer inspector) and gives back {run, verdict, usec} without
## changing the town: a look at what the code does with those inputs. {} when a run is already on its way.
func try_with(thing: Dictionary, args: Dictionary) -> Dictionary:
	if _running:
		return {}
	_running = true
	var state: Dictionary = _state_now.call()
	var id := String(thing.get("id", ""))
	var language := String(state.get("language", BootsCode.PYTHON))
	var source := source_of(state, id, language, _files.get(id, {}))
	var started := Time.get_ticks_usec()
	var program: Variant = thing.get("program")
	var hook := String((program as Dictionary).get("hook", TownThings.HOOK)) if program is Dictionary else TownThings.HOOK
	var run: Dictionary = await Background.run(func() -> Dictionary: return ThingRun.run(language, source, args, hook))
	_running = false
	var verdict := TownThings.judge_use(thing, run, covers(thing, OverworldState.cell(state)))
	return {"run": run, "verdict": verdict, "usec": Time.get_ticks_usec() - started}


## X on a thing: its code (the one kept, else the starter) opens in the editor, with the town paused behind it.
func edit(thing: Dictionary, keys: Array[String]) -> void:
	_thing = thing
	_keys = keys.duplicate()
	var state: Dictionary = _state_now.call()
	var id := String(thing.get("id", ""))
	var file: Dictionary = _files.get(id, {})
	var language := String(state.get("language", BootsCode.PYTHON))
	var hints: Array = file.get("hints", [])
	var hint := Text.t(String(hints[0])) if not hints.is_empty() else ""
	var names := PackedStringArray(TownThings.specs_of(thing).keys())
	var caption := Text.t("It may change nothing. It may say words.")
	if not names.is_empty():
		caption = Text.f("It may change: %s. It may say words.", [", ".join(names)])
	var title := Text.t(String(file.get("name", id)))
	_editor.open(title, hint, caption, source_of(state, id, language, file), language)


## An answer came back: the town takes its changes and flags, and hears what Hotaru says. In the editor the words go
## there instead, and a first answer's line waits until the editor closes.
func _landed(id: String, verdict: Dictionary, trouble: String) -> void:
	var before: Dictionary = _state_now.call()
	var first := not bool((before.get("flags", {}) as Dictionary).get("first-action", false))
	state_changed.emit(applied(before, id, verdict))
	var said := String(verdict.get("say", ""))
	if _editor.visible:
		_show_in_editor(said, trouble)
	else:
		_speak(said, trouble)
	if first and bool(verdict.get("ok", false)):
		if _editor.visible:
			_beat_waiting = true
		else:
			first_answer.emit()


## Hotaru's words for an answer: what the code says and what went wrong. The thing's own text is read when its code gave
## no words, or when it went wrong.
func _speak(said: String, trouble: String) -> void:
	var words := PackedStringArray()
	for line: String in [said, trouble]:
		if line != "":
			words.append(line)
	var reading := String(_thing.get("text", "")) if trouble != "" or words.is_empty() else ""
	spoke.emit(" ".join(words), reading)


## What the answer leaves in the editor: what the code said and what went wrong, in green when nothing did.
func _show_in_editor(said: String, trouble: String) -> void:
	var lines := PackedStringArray()
	for line: String in [said, trouble]:
		if line != "":
			lines.append(line)
	var text := "\n".join(lines) if not lines.is_empty() else Text.t("It ran. Nothing was said.")
	_editor.report(text, trouble == "")


## The code the editor holds is kept as the thing's code, in the town's language.
func _keep(source: String) -> void:
	var before: Dictionary = _state_now.call()
	var language := String(before.get("language", BootsCode.PYTHON))
	state_changed.emit(with_code(before, String(_thing.get("id", "")), language, source))


## Run: the code is kept, then runs as its hook runs it (Space's on_use, a plate's on_step, a door's on_change).
func _on_run_asked(source: String) -> void:
	_keep(source)
	var program: Variant = _thing.get("program")
	var hook := String((program as Dictionary).get("hook", TownThings.HOOK)) if program is Dictionary else TownThings.HOOK
	run_hook(_thing, _keys, hook)


## Close: the code is kept, and a first answer's line that waited for the editor is said now.
func _on_closed(source: String) -> void:
	_keep(source)
	if _beat_waiting:
		_beat_waiting = false
		first_answer.emit()


## Whether a thing takes code: a prop with a program (TownThings.problems checks the rest).
static func takes_code(thing: Dictionary) -> bool:
	return thing.has("program")


## Whether `cell` is one of the cells a thing stands on (its footprint).
static func covers(thing: Dictionary, cell: Vector2i) -> bool:
	var at := OverworldMap.cell_of(thing.get("at", [0, 0]))
	var footprint := OverworldMap.cell_of(thing.get("size", [1, 1]))
	return cell.x >= at.x and cell.y >= at.y and cell.x < at.x + footprint.x and cell.y < at.y + footprint.y


## The code a thing runs in `language`: the code the player kept for it, else its starter (the file's code).
static func source_of(state: Dictionary, thing_id: String, language: String, file: Dictionary) -> String:
	var kept := String(_code_of(state, thing_id).get(language, ""))
	if kept.strip_edges() != "":
		return kept
	return String((file.get("code", {}) as Dictionary).get(language, ""))


## The state with `source` kept as the thing's code in `language`. The thing's fields and the rest of the state stay.
static func with_code(state: Dictionary, thing_id: String, language: String, source: String) -> Dictionary:
	var out := state.duplicate(true)
	var things := _things_of(out)
	var entry := _entry_of(out, thing_id)
	var code := _code_of(out, thing_id)
	code[language] = source
	entry["code"] = code
	things[thing_id] = entry
	out["things"] = things
	return out


## The state after one answer: the fields the answer changed, and the flags it raised. A refused answer changes nothing.
## The first answer of any thing sets "first-action"; a gate that opens sets "<id>-open" (the quests wait for both).
static func applied(state: Dictionary, thing_id: String, verdict: Dictionary) -> Dictionary:
	if not bool(verdict.get("ok", false)):
		return state
	var changes: Dictionary = verdict.get("changes", {})
	var out := state.duplicate(true)
	if not changes.is_empty():
		out = TownThings.with_changes(out, thing_id, changes)
	var flags: Dictionary = (out.get("flags", {}) as Dictionary).duplicate()
	flags["first-action"] = true
	if bool(changes.get("open", false)):
		flags[thing_id + "-open"] = true
	for flag: String in verdict.get("raised", []):
		flags[flag] = true
	out["flags"] = flags
	return out


## The one line that says what went wrong with an answer, in a plain sentence (with its line, for an error), or "" when
## nothing did. In every case the thing keeps what it was.
static func trouble_of(file: Dictionary, run: Dictionary, verdict: Dictionary) -> String:
	var name := Text.t(String(file.get("name", "The thing")))
	var reason := String(verdict.get("reason", ""))
	if reason == "":
		var dropped := PackedStringArray(verdict.get("dropped", []))
		if dropped.is_empty():
			return ""
		return Text.f("%s may not change %s, so that stayed the same.", [name, ", ".join(dropped)])
	if reason == TownThings.OCCUPIED:
		return Text.f("You are standing in %s, so it stays as it was.", [name])
	if reason == TownThings.NOT_DICT:
		return Text.f("%s must give back words and settings, as a dictionary. Nothing changed.", [name])
	if reason == TownThings.TIMEOUT:
		return Text.f("%s took too long. Is there a loop that never ends? Nothing changed.", [name])
	if reason == TownThings.OOM:
		return Text.f("%s used too much memory. Nothing changed.", [name])
	if reason == TownThings.FAILED:
		return Text.f("%s did not answer: %s. Nothing changed.", [name, String(run.get("message", ""))])
	var sentence := sentence_of(String(run.get("kind", "")))
	var line := int(verdict.get("line", 0))
	if line > 0:
		return Text.f("%s tripped on line %d: %s. Nothing changed.", [name, line, sentence])
	return Text.f("%s stopped: %s. Nothing changed.", [name, sentence])


## The plain sentence for an error's kind: the errors a player meets most. Any other kind says the code stopped.
static func sentence_of(kind: String) -> String:
	match kind:
		"NameError", "ReferenceError":
			return Text.t("a name you used is not known here")
		"TypeError":
			return Text.t("a value is the wrong kind for what it does")
		"IndexError", "RangeError":
			return Text.t("a place in a list is past its end, and lists start at 0")
		"KeyError":
			return Text.t("that key is not in the dictionary")
		"SyntaxError":
			return Text.t("the code is not written the way the language reads it")
		"ZeroDivisionError":
			return Text.t("a number was divided by zero")
		"RecursionError":
			return Text.t("the code called itself too many times")
		"missing":
			return Text.t("there is no function named on_use or onUse to run")
	return Text.t("the code stopped with an error")


static func _things_of(state: Dictionary) -> Dictionary:
	var things: Variant = state.get("things", {})
	return things if things is Dictionary else {}


static func _entry_of(state: Dictionary, thing_id: String) -> Dictionary:
	var entry: Variant = _things_of(state).get(thing_id, {})
	return entry if entry is Dictionary else {}


static func _code_of(state: Dictionary, thing_id: String) -> Dictionary:
	var code: Variant = _entry_of(state, thing_id).get("code", {})
	return code if code is Dictionary else {}


static func _saved_fields(state: Dictionary, thing_id: String) -> Dictionary:
	var fields: Variant = _entry_of(state, thing_id).get("fields", {})
	return fields if fields is Dictionary else {}
