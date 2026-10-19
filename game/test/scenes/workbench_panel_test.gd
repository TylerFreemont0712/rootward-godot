extends GdUnitTestSuite
## The Workbench (Concept/v0.4, section 7) and the part-built banner: which cards there are, what they say, and that
## two banners queue.

const ROOT := "user://test-workbench"

var _catalog: Dictionary


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	_catalog = OverworldContent.load_world().catalog


func after_test() -> void:
	Sound.silence()
	Game.reset()


func _state() -> Dictionary:
	var state := OverworldState.fresh("lanternroot", Vector2i(18, 8), "right", "python")
	state.name = "Tinker"
	return state


func _panel(state: Dictionary) -> WorkbenchPanel:
	var panel := WorkbenchPanel.new()
	add_child(panel)
	panel.open(_catalog, state)
	await await_idle_frame()
	await await_idle_frame()
	return panel


func test_lists_the_lessons_then_the_tasks() -> void:
	var panel := await _panel(_state())
	var ids := panel.part_ids()
	assert_array(ids.slice(0, 3)).is_equal(["boots", "save", "lamps"])
	var expected: Array[String] = []
	for id in Parts.IDS:
		if _catalog.tasks.has(id):
			expected.append(id)
	assert_array(ids.slice(3)).is_equal(expected)
	assert_bool("shortcuts" in ids).is_true()
	assert_int(panel.cards.size()).is_equal(ids.size())
	assert_bool(panel.is_open()).is_true()


func test_engine_wraps_every_gear_inside_wide_and_narrow_viewports() -> void:
	var widths: Array[float] = [1280.0, 1920.0]
	for width: float in widths:
		var layout := WorkbenchPanel.engine_layout(width, 24)
		var centers: Array = layout.centers
		assert_int(centers.size()).is_equal(24)
		assert_int(int(layout.rows)).is_equal(ceili(24.0 / float(layout.columns)))
		for center: Vector2 in centers:
			assert_bool(center.x >= 54.0 and center.x <= width - 54.0).is_true()
	assert_int(int(WorkbenchPanel.engine_layout(1280.0, 24).columns)).is_less(24)
	assert_int(int(WorkbenchPanel.engine_layout(1920.0, 24).columns)).is_less_equal(18)


func test_an_unbuilt_part_says_who_to_ask() -> void:
	var panel := await _panel(_state())
	assert_str(panel.status_of("shortcuts")).starts_with("Not yet: ask ")
	assert_str(panel.status_of("save")).starts_with("Not yet: ask ")


func test_a_built_task_says_built() -> void:
	var state := _state()
	state.tasks = {"shortcuts": {"passed": 1, "source": "def shortcut(key):\n    return None\n", "source_language": "python"}}
	state.flags = {"all-ways": true}
	var panel := await _panel(state)
	assert_str(panel.status_of("shortcuts")).starts_with("Built")
	assert_str(panel.status_of("shortcuts")).contains("Stage 2")
	assert_str(panel.status_of("boots")).is_equal("Built")
	assert_bool(bool(panel.entry_of("shortcuts").built)).is_true()
	panel.choose("shortcuts")
	assert_str(panel.shown_id()).is_equal("shortcuts")
	assert_str(String(panel.entry_of("shortcuts").source)).contains("def shortcut")


func test_open_emits_the_chosen_part_and_esc_closes() -> void:
	var panel := await _panel(_state())
	var opened: Array[String] = []
	panel.open_part.connect(func(id: String) -> void: opened.append(id))
	panel.choose("shortcuts")
	(panel.get("_open_button") as Button).pressed.emit()
	assert_array(opened).is_equal(["shortcuts"])
	var closed := []
	panel.closed.connect(func() -> void: closed.append(1))
	panel.close_panel()
	assert_int(closed.size()).is_equal(1)
	assert_bool(panel.is_open()).is_false()


func test_the_banner_queues_two_calls() -> void:
	var banner := PartBanner.new()
	add_child(banner)
	await await_idle_frame()
	assert_bool(banner.busy()).is_false()
	banner.show_part("The Menu", "Esc opens your menu now.")
	banner.show_part("The Bag", "Your bag holds things now.", true)
	assert_bool(banner.busy()).is_true()
	await await_idle_frame()
	await await_idle_frame()
	assert_int(banner.waiting()).override_failure_message("the second waits").is_equal(1)
	assert_str((banner.get("_name") as Label).text).is_equal("The Menu")
	assert_str((banner.get("_kicker") as Label).text).is_equal("NEW PART")


## A stub for the live comparison: lines 2 and 3 differ, whatever the versions are.
func _stub_changed(_old_lines: Array, _new_lines: Array) -> Array[int]:
	await get_tree().process_frame
	var out: Array[int] = [2, 3]
	return out


func _two_versions_state(versions: Array) -> Dictionary:
	var source: String = versions[-1]
	return Parts.with_record(_state(), "shortcuts", {"passed": 1, "source": source, "source_language": "python", "versions": versions})


func test_a_task_with_two_versions_says_what_changed_and_emits_history_viewed() -> void:
	var first := "def shortcut(key):\n    return None\n"
	var second := "def shortcut(key):\n    if key == 'esc':\n        return 'menu'\n    return None\n"
	var panel := await _panel(_two_versions_state([first, second]))
	panel.set_history(_stub_changed)
	var viewed: Array[String] = []
	panel.history_viewed.connect(func(id: String) -> void: viewed.append(id))
	panel.choose("shortcuts")
	await await_idle_frame()
	await await_idle_frame()
	assert_array(viewed).is_equal(["shortcuts"])
	assert_str(panel.history_text()).is_equal("Changed since the version before: lines 2, 3")
	assert_str(panel.history_button_text()).is_equal("Before")
	(panel.get("_history_button") as Button).pressed.emit()
	assert_str(panel.history_button_text()).is_equal("Now")


func test_one_version_or_no_comparison_shows_no_history() -> void:
	var second := "def shortcut(key):\n    return None\n"
	var panel := await _panel(_two_versions_state([second]))
	panel.set_history(_stub_changed)
	panel.choose("shortcuts")
	await await_idle_frame()
	assert_str(panel.history_text()).is_equal("")
	assert_str(panel.history_button_text()).is_equal("")
	panel.close_panel()
	var two := await _panel(_two_versions_state([second, second + "\n"]))
	two.choose("shortcuts")
	await await_idle_frame()
	assert_str(two.history_text()).is_equal("")


func test_check_again_runs_every_passed_stage_on_the_program_that_runs() -> void:
	var state := _state()
	var record := Parts.passed_record({}, 0, TaskCheck.reference_of("shortcuts", "python"), "python")
	state = Parts.with_record(state, "shortcuts", record)
	var panel: WorkbenchPanel = await _panel(state)
	panel.choose("shortcuts")
	await panel.check_shown()
	assert_str(panel.check_text()).contains("Every check still passes")
	# A program that no longer opens the menu on Esc is caught, in the game's words.
	state = Parts.with_record(state, "shortcuts", Parts.passed_record({}, 0, "def shortcut(key):\n    return None\n", "python"))
	panel.open(_catalog, state)
	panel.choose("shortcuts")
	await panel.check_shown()
	assert_bool(panel.check_text().contains("Every check still passes")).is_false()
	assert_str(panel.check_text()).is_not_empty()
