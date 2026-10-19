extends GdUnitTestSuite
## The two code editors at their compact size (ADR-0061): the boots' and the lessons'. A Scribe can open a glossary beside
## the code with a Hints button, which does not change the panel's size and leaves the code most of the width; a
## Builder has no such button. Each mode shows many more lines of code than before (about 12). The editors are instanced
## on their own, in a temporary save folder, and given a couple of frames to lay themselves out.

const ROOT := "user://test-code-editors"
## The most lines the code once showed was about 12; every mode shows at least double that now.
const MIN_LINES := 24
## The code keeps at least this much of the body's width with the hints open.
const CODE_SHARE := 0.7


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	CodeHints.remembered_open = false


func after_test() -> void:
	CodeHints.remembered_open = false
	Sound.silence()
	Game.reset()


# --- the boots editor --------------------------------------------------------------------------------------------------


func test_boots_scribe_hints_open_and_close_without_changing_the_panel() -> void:
	var boots := await _boots(OverworldState.SCRIBE)
	var typed := boots.get("_typed") as BootsCodePanel
	var panel := boots.get("_panel") as PanelContainer
	var body := typed.get_parent() as Control
	assert_object(typed.hints).override_failure_message("Scribe's code has hints").is_not_null()
	assert_bool(typed.hints.visible).override_failure_message("the hints start shut").is_false()
	var shut_panel := panel.size
	var shut_code := typed.editor.size.x
	typed.hints.toggle.button_pressed = true
	await _frames(3)
	assert_bool(typed.hints.visible).override_failure_message("the toggle opens the hints").is_true()
	assert_vector(panel.size).override_failure_message("the panel keeps its size").is_equal(shut_panel)
	assert_float(typed.editor.size.x).is_less(shut_code)
	(
		assert_float(typed.editor.size.x / body.size.x)
		. override_failure_message("the code keeps most of the width")
		. is_greater_equal(CODE_SHARE)
	)
	(
		assert_bool(typed.hints.get_global_rect().position.x >= typed.editor.get_global_rect().end.x)
		. override_failure_message("the hints sit to the right of the code")
		. is_true()
	)
	typed.hints.toggle.button_pressed = false
	await _frames(3)
	assert_bool(typed.hints.visible).override_failure_message("the toggle shuts the hints").is_false()
	assert_vector(panel.size).is_equal(shut_panel)
	assert_float(typed.editor.size.x).is_equal(shut_code)


func test_the_hints_button_leaves_the_code_editor_its_focus() -> void:
	var boots := await _boots(OverworldState.SCRIBE)
	var typed := boots.get("_typed") as BootsCodePanel
	assert_int(typed.hints.toggle.focus_mode).is_equal(Control.FOCUS_NONE)
	typed.editor.grab_focus()
	typed.hints.toggle.button_pressed = true
	await _frames(2)
	assert_bool(typed.editor.has_focus()).override_failure_message("the code keeps the focus").is_true()


func test_open_or_closed_is_remembered_for_the_run() -> void:
	var first := await _boots(OverworldState.SCRIBE)
	(first.get("_typed") as BootsCodePanel).hints.toggle.button_pressed = true
	var second := await _boots(OverworldState.SCRIBE)
	(
		assert_bool((second.get("_typed") as BootsCodePanel).hints.visible)
		. override_failure_message("a new editor opens as the last was left")
		. is_true()
	)


func test_the_hints_follow_the_language() -> void:
	var boots := await _boots(OverworldState.SCRIBE)
	var typed := boots.get("_typed") as BootsCodePanel
	assert_bool(_has_text(typed.hints, "on_key(key, player)")).is_true()
	boots.call("_pick_language", BootsCode.JAVASCRIPT)
	await _frames(2)
	assert_bool(_has_text(typed.hints, "onKey(key, player)")).override_failure_message("JavaScript's name").is_true()
	assert_bool(_has_text(typed.hints, "on_key(key, player)")).is_false()


func test_boots_builder_has_no_hints() -> void:
	var boots := await _boots(OverworldState.BUILDER)
	(
		assert_object((boots.get("_preview") as BootsCodePanel).hints)
		. override_failure_message("the code a Builder reads")
		. is_null()
	)
	assert_bool((boots.get("_typed") as BootsCodePanel).visible).is_false()
	assert_bool(_visible_hints_buttons(boots)).override_failure_message("no visible Hints button").is_false()


func test_boots_show_many_lines_in_both_styles() -> void:
	for style: String in [OverworldState.BUILDER, OverworldState.SCRIBE]:
		var boots := await _boots(style)
		var panel := (
			boots.get("_typed") as BootsCodePanel if style == OverworldState.SCRIBE else boots.get("_preview")
			as BootsCodePanel
		)
		(
			assert_int(panel.editor.get_visible_line_count())
			. override_failure_message("boots %s lines" % style)
			. is_greater_equal(MIN_LINES)
		)
		var box := (boots.get("_panel") as PanelContainer).size
		assert_vector(box).override_failure_message("the panel is the compact size").is_equal(BootsEditor.PANEL_SIZE)


func test_boots_esc_still_closes_with_the_hints_open() -> void:
	var boots := await _boots(OverworldState.SCRIBE)
	(boots.get("_typed") as BootsCodePanel).hints.toggle.button_pressed = true
	await _frames(2)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	assert_bool(boots.visible).override_failure_message("Esc closes the editor").is_false()


# --- the lesson editor -------------------------------------------------------------------------------------------------


func test_lesson_scribe_hints_open_and_close_without_changing_the_panel() -> void:
	for lesson in Lessons.IDS:
		CodeHints.remembered_open = false
		var editor := await _lesson(lesson, true, Lessons.PYTHON)
		var code := editor.get("_code") as LessonCode
		var panel := editor.get("_panel") as PanelContainer
		var body := editor.get("_body") as Control
		assert_object(code.hints).override_failure_message("%s: Scribe's code has hints" % lesson).is_not_null()
		assert_bool(code.hints.visible).is_false()
		var shut_panel := panel.size
		code.hints.toggle.button_pressed = true
		await _frames(3)
		assert_bool(code.hints.visible).is_true()
		assert_vector(panel.size).override_failure_message("%s: the panel keeps its size" % lesson).is_equal(shut_panel)
		(
			assert_float(code.editor.size.x / body.size.x)
			. override_failure_message("%s: code share" % lesson)
			. is_greater_equal(CODE_SHARE)
		)
		code.hints.toggle.button_pressed = false
		await _frames(3)
		assert_bool(code.hints.visible).is_false()
		assert_vector(panel.size).is_equal(shut_panel)
		assert_float(code.editor.size.x / body.size.x).is_greater(0.95)


func test_lesson_builder_has_no_hints() -> void:
	for lesson in Lessons.IDS:
		var editor := await _lesson(lesson, false, Lessons.PYTHON)
		assert_object((editor.get("_code") as LessonCode).hints).override_failure_message(lesson).is_null()
		(
			assert_bool(_visible_hints_buttons(editor))
			. override_failure_message("no visible Hints button in " + lesson)
			. is_false()
		)


func test_lessons_show_many_lines_in_both_styles() -> void:
	for lesson in Lessons.IDS:
		for scribe: bool in [false, true]:
			var editor := await _lesson(lesson, scribe, Lessons.PYTHON)
			var code := editor.get("_code") as LessonCode
			(
				assert_int(code.editor.get_visible_line_count())
				. override_failure_message("%s (%s) lines" % [lesson, "Scribe" if scribe else "Builder"])
				. is_greater_equal(MIN_LINES)
			)
			assert_float((editor.get("_panel") as PanelContainer).size.x).is_equal(LessonEditor.WIDTH)


# --- helpers -----------------------------------------------------------------------------------------------------------


func _boots(style: String) -> BootsEditor:
	var state := OverworldState.fresh("home", Vector2i(2, 3), "down", "python")
	state.boots.style = style
	var editor := BootsEditor.new()
	add_child(editor)
	auto_free(editor)
	editor.open(state, "Try the keys.")
	await _frames(4)
	return editor


func _lesson(id: String, scribe: bool, language: String) -> LessonEditor:
	var state := OverworldState.fresh("lanternroot", Vector2i(18, 8), "right", language)
	state.boots.style = OverworldState.SCRIBE if scribe else OverworldState.BUILDER
	state.name = "Tinker"
	var editor := LessonEditor.new()
	add_child(editor)
	auto_free(editor)
	editor.open(id, state)
	await _frames(4)
	return editor


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Whether a Label or Button under `root` shows `text`.
func _has_text(root: Node, text: String) -> bool:
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text or (node as Label).text.begins_with(text):
			return true
	return false


## Whether a Button reading "Hints" is showing anywhere under `root`.
func _visible_hints_buttons(root: Node) -> bool:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == Text.t("Hints") and button.is_visible_in_tree():
			return true
	return false
