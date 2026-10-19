class_name TaskEditor
extends Control
## Where the player writes a part of the game (Concept/v0.4): the one editor every task opens in. Its giver's portrait
## and the stage's goal are at the top, with the current hint under them. A Builder fills in the task's real lines
## with chips and switches (TaskBlocks) and reads the live code they make beside them; a Scribe types the code, with
## the Hints column (CodeHints). "Try it" runs the code in the sandbox on every case of this stage and those before
## it (TaskResults lists them), and Hotaru says what to look at (TaskWords). When every case works the stage has
## passed, and Done closes the editor.
##
##   editor.open(task, stage, Parts.record(state, id), state)   # stage is 0-based; the screen counts from 1
##   passed(stage, record)    # every case works: the record carries `source` and `language` (and passed)
##   closed(record)           # the record as it was left: blocks, the code typed per language, the mode
##
## The panel is LessonEditor's size and look, so it shows as many lines of code. The record is a task's record
## ({language, mode: "blocks" | "code", blocks: {slots, toggles}, code: {python, javascript}}); it may be empty.

signal passed(stage: int, record: Dictionary)
signal closed(record: Dictionary)

const HINT_COLOUR := Color("#d6f57a")
const WIDTH := 1660.0
const HEIGHT := 1090.0
const BODY_HEIGHT := 300.0
const BLOCKS_WIDTH := 800.0
const RESULTS_HEIGHT := 196.0
const PORTRAIT := 72.0

var task: Dictionary = {}
var stage := 0
var record: Dictionary = {}

var _catalog: Dictionary = {}
var _language := Tasks.PYTHON
var _scribe := false
var _running := false
var _open := false
var _passed_now := false
var _hints_shown := 1
var _motion: Tween

var _panel: PanelContainer
var _title: Label
var _stage_label: Label
var _giver: Control
var _giver_id := ""
var _goal: Label
var _hint: Label
var _hint_count: Label
var _next_hint: Button
var _style_buttons: Dictionary = {}
var _language_label: Label
var _body: HBoxContainer
var _blocks_side: Control
var _blocks: TaskBlocks
var _code: LessonCode
var _results: TaskResults
var _advice: Label
var _status: Label
var _try: Button
var _done: Button
var _help: Label
var _hotaru: Control


## Gives the editor the town's content (the givers' faces come from `catalog.townsfolk`). Without it the editor takes
## the world's content, loaded the first time it opens.
func setup(catalog: Dictionary) -> void:
	_catalog = catalog


func _ready() -> void:
	theme = OverworldStyle.editor_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.05, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", OverworldStyle.panel_box())
	_panel.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	centre.add_child(_panel)
	_title = Ui.label("", "Heading")
	_stage_label = Ui.label("", "Muted")
	_stage_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage_label.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	var styles := _switch(
		[
			_switch_button(OverworldState.BUILDER, Text.t("Builder"), Text.t("Build with blocks, and see the code they make.")),
			_switch_button(OverworldState.SCRIBE, Text.t("Scribe"), Text.t("Type the code yourself.")),
		]
	)
	_language_label = Ui.label("", "Muted")
	_language_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close := Ui.button(Text.t("Close"), close_editor)
	_help = _small("")
	_help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var header := Ui.hbox([_title, _stage_label, Ui.spacer(), _help, Ui.spacer(10, 0), styles, _language_label, close], 12)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	# The giver and what they ask.
	_giver = Control.new()
	_giver.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_giver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_giver.draw.connect(func() -> void: QuestTracker.draw_face(_giver, _giver.size / 2.0, PORTRAIT / 2.0 - 2.0, _giver_id, _giver_id))
	_goal = Ui.label("", "", true)
	_goal.add_theme_font_override("font", OverworldStyle.body_font(600))
	_goal.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT + 2)
	_goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint = Ui.label("", "", true)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_color_override("font_color", HINT_COLOUR)
	_hint.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	_hint_count = _small("")
	_hint_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_hint = Ui.button(Text.t("Next hint"), _reveal_hint)
	_next_hint.custom_minimum_size = Vector2(120, 0)
	_next_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_hint.focus_mode = Control.FOCUS_NONE
	var asks := Ui.vbox([_goal, Ui.hbox([_hint, _hint_count, _next_hint], 12)], 4)
	asks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	asks.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := Ui.hbox([_giver, asks], 14)
	# The body, the results and Hotaru's advice.
	_body = Ui.hbox([], 18)
	_body.custom_minimum_size.y = BODY_HEIGHT
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results = TaskResults.new()
	var results_scroll := Ui.scroll(_results)
	results_scroll.custom_minimum_size.y = RESULTS_HEIGHT
	_hotaru = Control.new()
	_hotaru.custom_minimum_size = Vector2(44, 44)
	_hotaru.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hotaru.draw.connect(func() -> void: QuestTracker.draw_face(_hotaru, _hotaru.size / 2.0, 20.0, "hotaru", "Hotaru"))
	_advice = Ui.label("", "", true)
	_advice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advice.custom_minimum_size.y = 52
	_advice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_advice.add_theme_color_override("font_color", HINT_COLOUR)
	_advice.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	var advice_row := Ui.hbox([_hotaru, _advice], 12)
	_status = Ui.label("", "", true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done = Ui.button(Text.t("Done"), _finish, "PrimaryButton")
	_try = Ui.button(Text.t("Try it  ▶"), try_it, "PrimaryButton")
	for button: Button in [_done, _try, close]:
		button.custom_minimum_size = Vector2(150, 42)
		button.focus_entered.connect(_on_focus)
	_panel.add_child(
		Ui.vbox([header, top, _body, _line(), results_scroll, advice_row, Ui.hbox([_status, _done, _try], 10)], 8)
	)


## Opens `task` at `stage` (0-based) over the town, from its `record` (which may be empty). The language is
## `state.language`, the style `state.boots.style`, and the player's name `state.name`.
func open(a_task: Dictionary, a_stage: int, a_record: Dictionary, state: Dictionary) -> void:
	task = a_task
	stage = clampi(a_stage, 0, maxi(Tasks.stage_count(task) - 1, 0))
	_language = Tasks.JAVASCRIPT if String(state.get("language", Tasks.PYTHON)) == Tasks.JAVASCRIPT else Tasks.PYTHON
	var style := String((state.get("boots", {}) as Dictionary).get("style", OverworldState.BUILDER))
	record = _normal_record(a_record, style == OverworldState.SCRIBE)
	_scribe = String(record.mode) == OverworldState.CODE
	_passed_now = false
	_hints_shown = 1
	_running = false
	if _catalog.is_empty():
		_catalog = OverworldContent.load_world().catalog
	var person: Dictionary = (_catalog.get("townsfolk", {}) as Dictionary).get(String(task.get("giver", "")), {})
	_giver_id = String(person.get("portrait", task.get("giver", "")))
	_giver.queue_redraw()
	_hotaru.queue_redraw()
	_title.text = Text.t(String(task.get("title", "")))
	var count := Tasks.stage_count(task)
	_stage_label.text = Text.f("Stage %d of %d", [stage + 1, count]) if count > 1 else ""
	_goal.text = Text.t(String(Tasks.stage(task, stage).get("goal", "")))
	_language_label.text = Text.t("Python") if _language == Tasks.PYTHON else Text.t("JavaScript")
	_show_hint()
	_build_body()
	_results.wait(task, stage, _language)
	_advice.text = ""
	_hotaru.visible = false
	_status.text = ""
	_done.text = Text.t("Done")
	_try.theme_type_variation = "PrimaryButton"
	_sync_style()
	_open = true
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _panel)
	_focus_first.call_deferred()


func is_open() -> bool:
	return _open


## The task's id.
func lesson_id() -> String:
	return String(task.get("id", ""))


## Close, or Esc: the record is handed back as it was left.
func close_editor() -> void:
	if not _open:
		return
	Sound.play("sfx-whiff", 0.3)
	_leave()


## The code Try it would run now: the code on screen.
func source() -> String:
	if _code == null:
		return ""
	return _code.editor.text if _scribe else Tasks.source(task, record.blocks, _language)


## "Try it": the code runs in the sandbox on every case of the stage and those before it, on a thread, and the cases
## are listed. Awaiting it waits for the check.
func try_it() -> void:
	if _running or not _open:
		return
	_running = true
	Sound.play("sfx-card-place-1", 0.4)
	_keep_typed()
	var id := lesson_id()
	var given_task := task
	var given_stage := stage
	var language := _language
	var code := source()
	_status.text = TaskWords.trying()
	_status.add_theme_color_override("font_color", OverworldStyle.MUTED)
	_try.disabled = true
	var checked: Dictionary = await Background.run(
		func() -> Dictionary: return run_check(given_task, given_stage, language, code)
	)
	_running = false
	_try.disabled = false
	if not _open or id != lesson_id() or given_stage != stage:
		return
	_show_check(checked, code)


## A check of `source` for stage `index`: TaskRun.run over Tasks.check_calls, judged by Tasks.check, with the harness's
## answers (`results`) and what the code printed kept beside the verdicts. Safe on a thread.
static func run_check(a_task: Dictionary, index: int, language: String, code: String) -> Dictionary:
	var ran := TaskRun.run(language, code, Tasks.check_calls(a_task, index, language))
	var checked := Tasks.check(a_task, index, ran)
	checked.results = ran.get("results", [])
	checked.printed = String(ran.get("printed", ""))
	return checked


func _show_check(checked: Dictionary, code: String) -> void:
	_results.show_run(task, stage, _language, checked)
	var advised := Tasks.advice(task, stage, checked, _language)
	_advice.text = TaskWords.advice(task, stage, advised, _language)
	_hotaru.visible = true
	var problem: Dictionary = checked.get("problem", {})
	var judged: Array = checked.get("cases", [])
	var worked := judged.filter(func(c: Dictionary) -> bool: return bool(c.ok)).size()
	_code.mark_error(_error_line(checked))
	if bool(checked.get("ok", false)):
		_status.text = TaskWords.tally(worked, judged.size())
		_status.add_theme_color_override("font_color", UiTheme.PASS)
		record = Parts.passed_record(record, stage, code, _language)
		record.language = _language
		_passed_now = true
		_done.text = Text.t("Done ✓")
		_try.theme_type_variation = ""
		Sound.play("sfx-pass", 0.45)
		_cheer()
		_done.grab_focus.call_deferred()
		passed.emit(stage, record.duplicate(true))
		return
	_status.text = (
		Text.t("It didn't run yet.") if not problem.is_empty() else TaskWords.tally(worked, judged.size())
	)
	_status.add_theme_color_override("font_color", Color("#f08a7e"))
	Sound.play("sfx-glitch", 0.3)
	# A failed try is a step closer to the next hint.
	if _hints_shown < Tasks.hints(task, stage).size():
		_hints_shown += 1
		_show_hint()


## The line the code tripped on: the run's own, or the first case that raised an error.
static func _error_line(checked: Dictionary) -> int:
	var problem: Dictionary = checked.get("problem", {})
	if not problem.is_empty():
		return int(problem.get("line", 0))
	for verdict: Dictionary in checked.get("cases", []):
		if String(verdict.get("reason", "")) == "error":
			return int(verdict.get("line", 0))
	return 0


# --- hints ------------------------------------------------------------------------------------------------------------


## The newest hint the player has earned: the first at the start, one more after each failed try or Next hint.
func _show_hint() -> void:
	var hints := Tasks.hints(task, stage)
	_hints_shown = clampi(_hints_shown, 1, maxi(hints.size(), 1))
	_hint.text = Text.t(hints[_hints_shown - 1]) if not hints.is_empty() else ""
	_hint_count.text = Text.f("Hint %d of %d", [_hints_shown, hints.size()]) if hints.size() > 1 else ""
	_next_hint.visible = hints.size() > 1
	_next_hint.disabled = _hints_shown >= hints.size()


func _reveal_hint() -> void:
	if not _open or _hints_shown >= Tasks.hints(task, stage).size():
		return
	_hints_shown += 1
	_show_hint()
	Sound.play("sfx-card-flick-1", 0.3)


## The hint on screen, for tests and screenshots.
func hint_text() -> String:
	return _hint.text


# --- the page ---------------------------------------------------------------------------------------------------------


## `from` made whole: the language, a mode (the player's style when the record has none), the blocks (the task's fresh
## ones when none) and the code typed in each language.
func _normal_record(from: Dictionary, scribe_style: bool) -> Dictionary:
	var out: Dictionary = from.duplicate(true)
	out.language = _language
	var mode := String(out.get("mode", ""))
	if not mode in [OverworldState.BLOCKS, OverworldState.CODE]:
		out.mode = OverworldState.CODE if scribe_style else OverworldState.BLOCKS
	var blocks: Variant = out.get("blocks", {})
	out.blocks = TaskBlocks.normalized(task, blocks if blocks is Dictionary else {})
	var code := {Tasks.PYTHON: "", Tasks.JAVASCRIPT: ""}
	var typed: Variant = out.get("code", {})
	if typed is Dictionary:
		for language: String in code:
			code[language] = String((typed as Dictionary).get(language, ""))
	out.code = code
	return out


## The blocks and the code they make (a Builder) or the code alone (a Scribe).
func _build_body() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_blocks = null
	_blocks_side = null
	_code = LessonCode.new(_scribe)
	if not _scribe:
		_blocks = TaskBlocks.new()
		_blocks.setup(task, record.blocks, _language, stage)
		_blocks.changed.connect(_on_blocks)
		var scroll := Ui.scroll(_blocks)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var well := PanelContainer.new()
		well.add_theme_stylebox_override("panel", OverworldStyle.well_box(Vector2(8, 8), 12))
		well.custom_minimum_size.x = BLOCKS_WIDTH
		well.add_child(scroll)
		_blocks_side = well
		_body.add_child(well)
	var caption := Text.t("Type here. The game calls your function.") if _scribe else Text.t("The code your blocks make")
	if _scribe:
		_code.enable_task_hints(task, stage, _language)
	_code.set_language(_language, caption)
	_body.add_child(_code)
	_code.show_code(_shown_code())
	if _scribe:
		_code.editor.text_changed.connect(_keep_typed)
	_help.text = (
		Text.t("Ctrl+Enter: try it   Esc: close")
		if _scribe
		else Text.t("Arrows: move   Enter: choose or switch   Esc: close")
	)


## The code on screen: what the blocks make, or what the Scribe typed (the task's starter if nothing yet).
func _shown_code() -> String:
	if not _scribe:
		return Tasks.source(task, record.blocks, _language)
	var typed := String((record.code as Dictionary).get(_language, ""))
	return typed if typed.strip_edges() != "" else _starter()


## The task's starter, its comments in the player's language (CodeComments).
func _starter() -> String:
	return CodeComments.localized(String((task.get("code", {}) as Dictionary).get(_language, "")))


## What the Scribe typed goes into the record as they type. Their starter, untouched, is kept as nothing typed.
func _keep_typed() -> void:
	if not _scribe or _code == null:
		return
	var text := _code.editor.text
	var untouched := text.strip_edges() == _starter().strip_edges()
	(record.code as Dictionary)[_language] = "" if untouched else text


func _on_blocks(blocks: Dictionary) -> void:
	record.blocks = blocks
	_code.show_code(_shown_code(), true)
	_status.text = ""


## The player chose a style: the record's mode follows it, and the page is laid out again.
func _pick_style(style: String) -> void:
	if not _open:
		return
	var scribe := style == OverworldState.SCRIBE
	if scribe == _scribe:
		_sync_style()
		return
	_keep_typed()
	_scribe = scribe
	record.mode = OverworldState.CODE if scribe else OverworldState.BLOCKS
	_build_body()
	_sync_style()
	Sound.play("sfx-card-flick-1", 0.3)
	_focus_first.call_deferred()


func _sync_style() -> void:
	var chosen := OverworldState.SCRIBE if _scribe else OverworldState.BUILDER
	for id: String in _style_buttons:
		var button := _style_buttons[id] as Button
		button.set_pressed_no_signal(id == chosen)
		button.theme_type_variation = "PrimaryButton" if id == chosen else ""


## A pair of buttons in a sunken well, one of them chosen (amber): a switch.
static func _switch(buttons: Array) -> Control:
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", OverworldStyle.well_box(Vector2(4, 4), 10))
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.add_child(Ui.hbox(buttons, 3))
	return well


func _switch_button(id: String, text: String, tip: String) -> Button:
	var button := Ui.choice(text, false, _pick_style.bind(id))
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(100, 0)
	_style_buttons[id] = button
	return button


## Hotaru hops for joy.
func _cheer() -> void:
	var hop := create_tween()
	hop.tween_property(_hotaru, "position:y", _hotaru.position.y - 12.0, 0.1)
	hop.tween_property(_hotaru, "position:y", _hotaru.position.y, 0.14)


func _finish() -> void:
	if not _open:
		return
	Sound.play("sfx-card-place-1", 0.4)
	_leave()


func _leave() -> void:
	_keep_typed()
	_open = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.fade_out(self, func() -> void: visible = _open)
	closed.emit(record.duplicate(true))


func _focus_first() -> void:
	if not _open:
		return
	var first: Control = _code.editor if _scribe else _blocks.first_focus()
	if _passed_now:
		first = _done
	if first != null:
		first.grab_focus()


func _on_focus() -> void:
	if _open:
		Sound.play("sfx-card-flick-1", 0.25)


static func _small(text: String) -> Label:
	var line := Ui.label(text, "Muted")
	line.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_SMALL)
	line.add_theme_color_override("font_color", OverworldStyle.MUTED)
	return line


static func _line() -> Control:
	var line := ColorRect.new()
	line.color = Color(UiTheme.AMBER_DIM, 0.45)
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# --- input ------------------------------------------------------------------------------------------------------------


## Ctrl+Enter tries the code, even from inside the code editor (which would take Ctrl+Enter as a new line).
func _input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey or not event.is_pressed():
		return
	var key := event as InputEventKey
	if key.ctrl_pressed and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		try_it()


## Esc or the pad's B closes; no key press reaches the town while the editor is open (a release still does, so the town
## never thinks a key is held). A key with no focus to move (a click on the shade took it) gives the focus back.
## Esc inside the code editor or an open chip menu is theirs first: they handle it before it gets here.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		close_editor()
	elif get_viewport().gui_get_focus_owner() == null:
		_focus_first()
