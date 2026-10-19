class_name TaskHost
extends Control
## Where the parts of the game get built (Concept/v0.4): a talk's "open": "task:<id>" (or the Workbench) opens the
## task's editor (TaskEditor) on its first stage not passed yet. A stage that passes keeps its program in the task's
## record (Parts.passed_record: the code the game runs from then on) and sets the stage's flag; when the editor closes,
## the banner says what the part does now. The overworld hears every change through state_changed and remakes the
## part's tables (PartsRuntime.refresh).
##
##   host.setup(catalog)
##   host.open_task("menu", state)
##   state_changed(state)          # the task's record and flags changed: keep them
##   built(id, stage)              # the editor closed after `stage` passed (the highest that did)

signal state_changed(state: Dictionary)
signal built(id: String, stage: int)

var catalog: Dictionary = {}
var _state: Dictionary = {}
var _id := ""
var _passed: Array[int] = []
var _editor: TaskEditor
var _banner: PartBanner


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_editor = TaskEditor.new()
	_editor.passed.connect(_on_passed)
	_editor.closed.connect(_on_closed)
	add_child(_editor)
	_banner = PartBanner.new()
	add_child(_banner)
	if not catalog.is_empty():
		_editor.setup(catalog)


func setup(world: Dictionary) -> void:
	catalog = world
	if _editor != null:
		_editor.setup(catalog)


## Opens task `id` over the town on Tasks.open_stage: the first stage not passed yet when it is unlocked, else the last
## one passed, to practise or change.
func open_task(id: String, state: Dictionary) -> void:
	var task: Dictionary = (catalog.get("tasks", {}) as Dictionary).get(id, {})
	if task.is_empty():
		push_warning("there is no task %s" % id)
		return
	_id = id
	_state = state.duplicate(true)
	_passed.clear()
	var record := Parts.record(_state, id)
	var stage := Tasks.open_stage(task, record, Parts.facts(_state))
	_editor.open(task, stage, record, _state)


## The task's editor is open: the town does not walk (and the coding music plays).
func busy() -> bool:
	return _editor.is_open()


func editing() -> bool:
	return _editor.is_open()


func open_id() -> String:
	return _id if _editor.is_open() else ""


func banner() -> PartBanner:
	return _banner


## A stage passed: its program becomes the one the game runs, and its flag is set.
func _on_passed(stage: int, record: Dictionary) -> void:
	var task: Dictionary = catalog.tasks.get(_id, {})
	var kept := _editing_of(Parts.record(_state, _id), record)
	kept = Parts.passed_record(kept, stage, String(record.get("source", "")), String(record.get("language", _state.get("language", Tasks.PYTHON))))
	# When the part was first built, in seconds played: the credits list the parts in the order they were built.
	if not kept.has("built_at"):
		kept.built_at = float(_state.get("played_seconds", 0.0))
	_state = Parts.with_record(_state, _id, kept)
	var flag := String(Tasks.stage(task, stage).get("flag", ""))
	if flag != "":
		var flags: Array[String] = [flag]
		_state = Lessons.with_flags(_state, flags)
	if not stage in _passed:
		_passed.append(stage)
	state_changed.emit(_state)


## The editor closed: what the player left in it (blocks, code, which way they built) is kept, and a stage that passed
## gets its banner.
func _on_closed(record: Dictionary) -> void:
	var kept := _editing_of(Parts.record(_state, _id), record)
	_state = Parts.with_record(_state, _id, kept)
	state_changed.emit(_state)
	if _passed.is_empty():
		return
	var task: Dictionary = catalog.tasks.get(_id, {})
	var top: int = _passed.max()
	var first := 0 in _passed
	var line := Text.t(String(task.get("built_line", ""))) if first else Text.f("Stage %d works now.", [top + 1])
	_banner.show_part(Text.t(String(task.get("name", _id))), line, not first)
	built.emit(_id, top)
	_passed.clear()


## A record with the editor's work in it (its language, Builder or Scribe, the blocks, the code typed), and what the
## game keeps of its own (the stages passed and the program that runs) untouched.
static func _editing_of(kept: Dictionary, editor: Dictionary) -> Dictionary:
	var out := kept.duplicate(true)
	for key: String in ["language", "mode", "blocks", "code"]:
		if editor.has(key):
			out[key] = editor[key]
	return out
