extends GdUnitTestSuite
## The v0.4 task editor, its Builder blocks and its results (Concept/v0.4): opened on the shortcuts task, in a save
## folder of its own. The sandbox takes about 0.1 s per check, so a check is awaited with a generous timeout.

const ROOT := "user://test-task-editor"

var _task: Dictionary
var _catalog: Dictionary


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	_catalog = OverworldContent.load_world().catalog
	_task = _catalog.tasks.shortcuts
	CodeHints.remembered_open = false


func after_test() -> void:
	CodeHints.remembered_open = false
	Sound.silence()
	Game.reset()


func _state(style := OverworldState.BUILDER, language := "python") -> Dictionary:
	var state := OverworldState.fresh("lanternroot", Vector2i(18, 8), "right", language)
	state.name = "Tinker"
	state.boots.style = style
	return state


func _editor(stage := 0, record := {}, state := {}) -> TaskEditor:
	var editor := TaskEditor.new()
	add_child(editor)
	editor.setup(_catalog)
	editor.open(_task, stage, record, state if not state.is_empty() else _state())
	await await_idle_frame()
	await await_idle_frame()
	return editor


func _frames(count: int) -> void:
	for i in count:
		await await_idle_frame()


func test_builder_blocks_make_the_source() -> void:
	var editor := await _editor()
	var blocks := editor.get("_blocks") as TaskBlocks
	assert_object(blocks).is_not_null()
	assert_str(editor.source()).is_equal(Tasks.source(_task, blocks.blocks(), "python"))
	blocks.set_toggle("menu", true)
	blocks.choose("menu_key", 1)
	blocks.choose("menu_panel", 1)
	await _frames(2)
	assert_str(editor.source()).contains('if key == "escape":').contains('return "menu"')
	assert_str(editor.source()).is_equal(Tasks.source(_task, blocks.blocks(), "python"))
	assert_str(editor.lesson_id()).is_equal("shortcuts")
	assert_bool(editor.is_open()).is_true()


func test_builder_passes_with_the_switch_and_the_choices() -> void:
	var editor := await _editor()
	var blocks := editor.get("_blocks") as TaskBlocks
	var passes: Array[Dictionary] = []
	editor.passed.connect(func(stage: int, record: Dictionary) -> void: passes.append({"stage": stage, "record": record}))
	blocks.set_toggle("menu", true)
	blocks.choose("menu_key", 1)
	blocks.choose("menu_panel", 1)
	await editor.try_it()
	await _frames(2)
	assert_int(passes.size()).override_failure_message("passed was emitted").is_equal(1)
	assert_int(int(passes[0].stage)).is_equal(0)
	var record: Dictionary = passes[0].record
	assert_str(String(record.source)).contains('"escape"')
	assert_str(String(record.language)).is_equal("python")
	assert_int(int(record.passed)).is_equal(1)
	assert_str((editor.get("_done") as Button).text).contains("✓")


func test_scribe_with_the_starter_fails_and_says_why() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var passes := []
	editor.passed.connect(func(_s: int, _r: Dictionary) -> void: passes.append(1))
	assert_str(editor.source()).is_equal(String(_task.code.python))
	await editor.try_it()
	await _frames(2)
	assert_array(passes).is_empty()
	var advice := (editor.get("_advice") as Label).text
	assert_str(advice).is_not_empty()
	var results := editor.get("_results") as TaskResults
	assert_bool(results.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == 'shortcut("escape")')).is_true()


func test_a_failed_try_shows_the_next_hint() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var first := editor.hint_text()
	assert_str(first).is_equal(Tasks.hints(_task, 0)[0])
	await editor.try_it()
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[1])
	(editor.get("_next_hint") as Button).pressed.emit()
	assert_str(editor.hint_text()).is_equal(Tasks.hints(_task, 0)[2])


func test_closing_hands_back_the_record() -> void:
	var editor := await _editor(0, {}, _state(OverworldState.SCRIBE))
	var closed: Array[Dictionary] = []
	editor.closed.connect(func(record: Dictionary) -> void: closed.append(record))
	(editor.get("_code") as LessonCode).editor.text = "def shortcut(key):\n    return None  # mine\n"
	editor.close_editor()
	assert_int(closed.size()).is_equal(1)
	assert_str(String(closed[0].code.python)).contains("# mine")
	assert_str(String(closed[0].mode)).is_equal("code")
	assert_bool(editor.is_open()).is_false()


func test_blocks_hide_a_later_stage_at_stage_zero() -> void:
	var blocks := TaskBlocks.new()
	add_child(blocks)
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 0)
	assert_bool(blocks.is_slot_shown("menu_key")).is_true()
	assert_bool(blocks.is_slot_shown("bag_key")).is_false()
	assert_bool(blocks.is_toggle_shown("menu")).is_true()
	assert_bool(blocks.is_toggle_shown("bag")).is_false()
	var at_zero := blocks.lines_shown()
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 1)
	assert_bool(blocks.is_slot_shown("bag_key")).is_true()
	assert_bool(blocks.is_toggle_shown("bag")).is_true()
	assert_int(blocks.lines_shown()).is_greater(at_zero)


func test_a_switch_dims_its_lines() -> void:
	var blocks := TaskBlocks.new()
	add_child(blocks)
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 0)
	var lines := (blocks.get("_group_lines") as Dictionary)["menu"] as Control
	assert_float(lines.modulate.a).is_equal_approx(TaskBlocks.DIM, 0.001)
	blocks.set_toggle("menu", true)
	assert_float(lines.modulate.a).is_equal(1.0)


func test_the_chips_show_the_choice_labels() -> void:
	var blocks := TaskBlocks.new()
	add_child(blocks)
	blocks.setup(_task, Tasks.fresh_blocks(_task), "python", 0)
	var chip := blocks.chips["menu_panel"] as OptionButton
	var slot: Dictionary = _task.blocks.slots.menu_panel
	for i in chip.item_count:
		assert_str(chip.get_item_text(i)).is_equal(Tasks.choice_label(slot, i, "python"))


func test_glossary_for_a_task_has_three_sections() -> void:
	for language: String in ["python", "javascript"]:
		var sections := CodeGlossary.sections_for_task(_task, 0, language)
		assert_int(sections.size()).is_equal(3)
		assert_str(String(sections[0].entries[0].term)).is_equal(Tasks.signature(_task, 0, language))
		assert_bool((sections[2].entries as Array).is_empty()).is_false()
