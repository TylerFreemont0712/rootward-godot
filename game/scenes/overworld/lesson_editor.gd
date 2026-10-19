class_name LessonEditor
extends Control
## Where the player writes a lesson's function (ADR-0061): lesson 2's save(player) and lesson 3's light_all(lamps).
## A Builder ticks blocks on the left and reads the live code they make on the right; a Scribe types the code. Hotaru's
## hint is at the top. "Try it" runs the code in the sandbox (LessonRun) on three cases and lists what each one gave
## back; when every case works the lesson is passed, and Done closes it.
##
##   editor.open(Lessons.MEMORY, state)   # the lesson's record (Lessons.record) is what the player edits
##   passed(record)                       # every case worked: the record with its source, language and passed
##   closed(record)                       # the record as it was left (blocks ticked, code typed)

signal passed(record: Dictionary)
signal closed(record: Dictionary)

const HINT_COLOUR := Color("#d6f57a")
## The panel's size in the design's units (the canvas is about 2180 x 1230): the code takes whatever the rest leaves.
const WIDTH := 1660.0
const HEIGHT := 1090.0
const BODY_HEIGHT := 300.0

var lesson := ""
var record: Dictionary = {}

var _language := Lessons.PYTHON
var _scribe := false
var _player_name := ""
var _running := false
var _open := false
var _motion: Tween

var _panel: PanelContainer
var _title: Label
var _portrait: TextureRect
var _hint: Label
var _blocks_side: VBoxContainer
var _blocks: Control
var _body: HBoxContainer
var _code: LessonCode
var _results: LessonResults
var _status: Label
var _try: Button
var _done: Button
var _help: Label


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
	var close := Ui.button(Text.t("Close"), close_editor)
	_portrait = TextureRect.new()
	_portrait.texture = OverworldArt.portrait("hotaru")
	_portrait.custom_minimum_size = Vector2(48, 48)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hint = Ui.label("", "", true)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.add_theme_color_override("font_color", HINT_COLOUR)
	_hint.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var hotaru := Ui.hbox([_portrait, _hint], 12)
	_blocks_side = Ui.vbox([], 6)
	_blocks_side.custom_minimum_size.x = 460
	_body = Ui.hbox([_blocks_side], 18)
	_body.custom_minimum_size.y = BODY_HEIGHT
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results = LessonResults.new()
	_status = Ui.label("", "", true)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_done = Ui.button(Text.t("Done"), _finish, "PrimaryButton")
	_try = Ui.button(Text.t("Try it  ▶"), try_it, "PrimaryButton")
	for button: Button in [_done, _try, close]:
		button.custom_minimum_size = Vector2(150, 42)
		button.focus_entered.connect(_on_focus)
	_help = _small("")
	_help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := (
		Ui
		. vbox(
			[
				Ui.hbox([_title, Ui.spacer(), _help, Ui.spacer(10, 0), close], 10),
				hotaru,
				_body,
				_line(),
				_results,
				Ui.hbox([_status, _done, _try], 10),
			],
			8
		)
	)
	_panel.add_child(column)


## Opens lesson `id` over the town, from the lesson's record in `state`.
func open(id: String, state: Dictionary) -> void:
	lesson = id
	record = Lessons.record(state, id)
	var language := String(state.get("language", Lessons.PYTHON))
	_language = Lessons.JAVASCRIPT if language == Lessons.JAVASCRIPT else Lessons.PYTHON
	_scribe = (
		String((state.get("boots", {}) as Dictionary).get("style", OverworldState.BUILDER)) == OverworldState.SCRIBE
	)
	_player_name = String(state.get("name", ""))
	_title.text = LessonWords.title(id)
	_say(LessonWords.advice(id, "passed", _language) if record.passed else LessonWords.intro(id, _scribe))
	_build_body()
	_results.wait(LessonWords.waiting(id))
	_status.text = ""
	_done.visible = bool(record.passed)
	_try.theme_type_variation = "" if record.passed else "PrimaryButton"
	_help.text = (
		Text.t("Ctrl+Enter: try it   Esc: close")
		if _scribe
		else Text.t("Arrows: move   Enter: tick a block   Esc: close")
	)
	_open = true
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _panel)
	_focus_first.call_deferred()


func is_open() -> bool:
	return _open


## Close, or Esc: the record is handed back as it was left.
func close_editor() -> void:
	if not _open:
		return
	Sound.play("sfx-whiff", 0.3)
	_leave()


## "Try it": the code runs in the sandbox on the lesson's three cases, on a thread, and the results are listed.
func try_it() -> void:
	if _running or not _open:
		return
	_running = true
	Sound.play("sfx-card-place-1", 0.4)
	_keep_typed()
	var id := lesson
	var language := _language
	var source := _source()
	var given := Lessons.cases(id, _player_name)
	_status.text = Text.t("Hotaru is trying it…")
	_status.add_theme_color_override("font_color", OverworldStyle.MUTED)
	_try.disabled = true
	var ran: Dictionary = await Background.run(func() -> Dictionary: return LessonRun.run(id, language, source, given))
	_running = false
	_try.disabled = false
	if not _open or id != lesson:
		return
	_show_check(given, Lessons.check(id, given, ran), ran, source)


func _show_check(given: Array, checked: Dictionary, ran: Dictionary, source: String) -> void:
	_results.show_run(lesson, given, checked, ran, _language)
	_say(LessonWords.advice(lesson, Lessons.advice(lesson, checked), _language))
	var problem: Dictionary = checked.get("problem", {})
	var judged: Array = checked.get("cases", [])
	var worked := judged.filter(func(c: Dictionary) -> bool: return bool(c.ok)).size()
	_code.mark_error(_error_line(checked))
	if bool(checked.ok):
		_status.text = LessonWords.tally(worked, judged.size())
		_status.add_theme_color_override("font_color", UiTheme.PASS)
		record.passed = true
		record.source = source
		record.language = _language
		Sound.play("sfx-pass", 0.45)
		_cheer()
		_done.visible = true
		_try.theme_type_variation = ""
		_done.grab_focus.call_deferred()
		passed.emit(record.duplicate(true))
		return
	var signature := "%s(%s)" % [Lessons.entry(lesson, _language), "lamps" if lesson == Lessons.LAMPS else "player"]
	var words := LessonWords.problem(problem, signature) if not problem.is_empty() else ""
	_status.text = words if words != "" else LessonWords.tally(worked, judged.size())
	_status.add_theme_color_override("font_color", Color("#f08a7e"))
	Sound.play("sfx-glitch", 0.3)


## The line the code tripped on: the run's own, or the first case that raised an error.
static func _error_line(checked: Dictionary) -> int:
	var problem: Dictionary = checked.get("problem", {})
	if not problem.is_empty():
		return int(problem.get("line", 0))
	for case_check: Dictionary in checked.get("cases", []):
		if String(case_check.get("reason", "")) == "error":
			return int(case_check.get("line", 0))
	return 0


# --- the page --------------------------------------------------------------------------------------------------------


## The blocks and the code (a Builder) or the code alone (a Scribe), from the record.
func _build_body() -> void:
	if _code != null:
		_body.remove_child(_code)
		_code.queue_free()
	Ui.clear(_blocks_side)
	_blocks = null
	_blocks_side.visible = not _scribe
	if not _scribe:
		_blocks = (
			LessonBlocks.lamps(record.blocks, _language, _on_lamp_block)
			if lesson == Lessons.LAMPS
			else LessonBlocks.memory(record.blocks, _language, _on_field)
		)
		_blocks_side.add_child(_blocks)
	_code = LessonCode.new(_scribe)
	var caption := (
		Text.t("Type here. The town calls your function.") if _scribe else Text.t("The code your blocks make")
	)
	if _scribe:
		_code.enable_hints(lesson, _language)
	_code.set_language(_language, caption)
	_body.add_child(_code)
	_code.show_code(_shown_code())
	if _scribe:
		_code.editor.text_changed.connect(_keep_typed)


## The code on screen: what the blocks make, or what the Scribe typed (their starter if nothing yet).
func _shown_code() -> String:
	if not _scribe:
		return Lessons.source(lesson, record.blocks, _language)
	var typed := String((record.code as Dictionary).get(_language, ""))
	# The starter's comments in the player's language (CodeComments); the code is the same.
	return typed if typed.strip_edges() != "" else CodeComments.localized(Lessons.starter(lesson, _language))


## The code Try it runs: the code on screen.
func _source() -> String:
	return _code.editor.text if _scribe else Lessons.source(lesson, record.blocks, _language)


## What the Scribe typed goes into the record as they type. Their starter, untouched, is kept as nothing typed.
func _keep_typed() -> void:
	if not _scribe or _code == null:
		return
	var text := _code.editor.text
	var untouched := text.strip_edges() == CodeComments.localized(Lessons.starter(lesson, _language)).strip_edges()
	(record.code as Dictionary)[_language] = "" if untouched else text


func _on_field(field: String, on: bool) -> void:
	var fields: Array = record.blocks
	if on and not field in fields:
		fields.append(field)
	elif not on:
		fields.erase(field)
	_after_block(on)


func _on_lamp_block(id: String, on: bool) -> void:
	var blocks: Dictionary = record.blocks
	blocks[id] = on
	var toggles := LessonBlocks.toggles(_blocks)
	if id == "loop" and toggles.has("inside"):
		LessonBlocks.set_enabled(toggles.inside as Button, on)
	_after_block(on)


## A block was ticked or unticked: the code follows at once, with the changed lines glowing.
func _after_block(on: bool) -> void:
	Sound.play("sfx-card-place-1" if on else "sfx-card-flick-1", 0.35)
	_code.show_code(_shown_code(), true)
	_status.text = ""


func _say(text: String) -> void:
	_hint.text = text


## Hotaru hops for joy.
func _cheer() -> void:
	var hop := create_tween()
	hop.tween_property(_portrait, "position:y", _portrait.position.y - 14.0, 0.1)
	hop.tween_property(_portrait, "position:y", _portrait.position.y, 0.14)


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
	var first: Control = _code.editor if _scribe else LessonBlocks.first(_blocks)
	if bool(record.passed):
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
