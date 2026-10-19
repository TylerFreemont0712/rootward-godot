extends GdUnitTestSuite
## Chapter 2's acceptance (Concept/v0.4/01, section 15): every part built from its reference program (the test
## fixtures, never shown in the game) answers the game as the part should, through the real sandbox: the shortcut and
## the menu, the volume knob, the bag's add and remove, the map's colours and places, Pip's bar, the clock, the music
## box and the credits. PartsRuntime is what the overworld asks.

const WAIT_MS := 20000

var _catalog: Dictionary = {}
var _state: Dictionary = {}
var _parts: PartsRuntime


func before() -> void:
	_catalog = OverworldContent.load_world().catalog


func before_test() -> void:
	_state = OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
	_state.name = "Kai"
	for id: String in Parts.IDS:
		var task: Dictionary = _catalog.tasks.get(id, {})
		if task.is_empty():
			continue
		var source := TaskCheck.reference_of(id, "python")
		_state = Parts.with_record(_state, id, Parts.passed_record({}, Tasks.stage_count(task) - 1, source, "python"))
	_parts = auto_free(PartsRuntime.new())
	add_child(_parts)
	_parts.setup(_catalog, func() -> Dictionary: return _state)
	_parts.refresh()


## Every table this test started finishes before the next (a thread left running at exit outlives the engine).
func after_test() -> void:
	Background.finish_all()
	Text.setup("en")


## Waits until `part`'s tables are in (or the time runs out).
func _until_ready(part: String) -> void:
	var waited := 0
	while not _parts.has_tables(part) and waited < WAIT_MS:
		await get_tree().process_frame
		waited += 16
	assert_bool(_parts.has_tables(part)).override_failure_message("%s's tables never landed" % part).is_true()


## What the reference program itself answers for one call, as the oracle.
func _reference(part: String, stage: int, args: Array) -> Variant:
	var task: Dictionary = _catalog.tasks[part]
	var table := TaskRun.table(task, stage, "python", TaskCheck.reference_of(part, "python"), [args])
	return table.values[0]


func test_every_part_exists_in_content() -> void:
	for id: String in Parts.IDS:
		assert_bool(_catalog.tasks.has(id)).override_failure_message("no task " + id).is_true()


func test_esc_opens_the_menu_the_player_listed() -> void:
	await _until_ready(Parts.SHORTCUTS)
	assert_str(_parts.shortcut("escape")).is_equal("menu")
	assert_str(_parts.shortcut("i")).is_equal("bag")
	assert_str(_parts.shortcut("m")).is_equal("map")
	assert_str(_parts.shortcut("w")).is_equal("")
	assert_bool(_parts.escape_opens_menu()).is_true()
	var waited := 0
	while not _parts.menu_is_players() and waited < WAIT_MS:
		await get_tree().process_frame
		waited += 16
	var items := _parts.menu_items()
	assert_array(items).is_equal(_reference(Parts.MENU, 0, [Parts.menu_built(_state)]))
	assert_str(items[0]).is_equal("continue")
	assert_str(items[-1]).is_equal("quit")


func test_the_options_page_and_its_knob_follow_the_player_s_code() -> void:
	await _until_ready(Parts.OPTIONS)
	await _until_ready(Parts.VOLUME)
	var settings: Array[String] = []
	for row: Dictionary in _parts.options_rows():
		settings.append(String(row.setting))
	assert_array(settings).contains(["music", "sound"])
	assert_float(_parts.volume_at(5)).is_equal_approx(float(_reference(Parts.VOLUME, 0, [5])), 0.0001)
	assert_float(_parts.volume_at(0)).is_equal_approx(0.0, 0.0001)
	assert_float(_parts.volume_at(14)).is_equal_approx(1.0, 0.0001)
	assert_int(_parts.volume_curve().size()).is_equal(11)


func test_the_bag_takes_and_gives_with_the_player_s_add_and_remove() -> void:
	var added: Dictionary = await _parts.bag_add("apple")
	assert_bool(bool(added.ok)).override_failure_message(str(added)).is_true()
	assert_int(Bag.count(added.bag, "apple")).is_equal(1)
	_state.bag = [{"item": "cabbage", "count": 3}, {"item": "apple", "count": 1}]
	var taken: Dictionary = await _parts.bag_remove("cabbage", 3)
	assert_bool(bool(taken.ok)).override_failure_message(str(taken)).is_true()
	assert_int(Bag.count(taken.bag, "cabbage")).is_equal(0)
	assert_int(Bag.count(taken.bag, "apple")).is_equal(1)
	var facts := Parts.facts(_state)
	assert_bool(Talk.holds({"has": "cabbage", "at_least": 3}, facts)).is_true()


func test_the_map_is_drawn_in_the_player_s_colours_and_knows_its_places() -> void:
	await _until_ready(Parts.MAP)
	var colours := _parts.map_colours()
	assert_object(colours["water"]).is_equal(Parts.colour_of(_reference(Parts.MAP, 0, ["water"])))
	assert_bool(colours["water"] != colours["grass"]).is_true()
	var places: Array = (_catalog.get("places", {}) as Dictionary).get("lanternroot", [])
	if places.is_empty():
		return
	var first: Dictionary = places[0]
	var inside := Vector2i(int(first.x), int(first.y))
	assert_str(_parts.place_at("lanternroot", inside)).is_equal("")
	var waited := 0
	while _parts.place_at("lanternroot", inside) == "" and waited < WAIT_MS:
		await get_tree().process_frame
		waited += 16
	assert_str(_parts.place_at("lanternroot", inside)).is_equal(String(first.name))


func test_cached_place_caption_rebuilds_when_the_live_reading_changes() -> void:
	await _until_ready(Parts.MAP)
	var places: Array = (_catalog.get("places", {}) as Dictionary).get("lanternroot", [])
	var first: Dictionary = places[0]
	var original_name := String(first.name)
	first.name = "The Guardian"
	var inside := Vector2i(int(first.x), int(first.y))
	Text.setup("ja", "hiragana")
	_parts.place_at("lanternroot", inside)
	var waited := 0
	while _parts.place_at("lanternroot", inside) != "ばんにん" and waited < WAIT_MS:
		await get_tree().process_frame
		waited += 16
	assert_str(_parts.place_at("lanternroot", inside)).is_equal("ばんにん")
	Text.setup("ja", "kanji")
	_parts.place_at("lanternroot", inside)
	waited = 0
	while _parts.place_at("lanternroot", inside) != "番人（ばんにん）" and waited < WAIT_MS:
		await get_tree().process_frame
		waited += 16
	assert_str(_parts.place_at("lanternroot", inside)).is_equal("番人（ばんにん）")
	first.name = original_name


func test_pip_s_bar_and_the_clock_follow_the_player_s_code() -> void:
	await _until_ready(Parts.PROGRESS)
	await _until_ready(Parts.CLOCK)
	assert_int(_parts.progress_of(2, 4)).is_equal(50)
	assert_int(_parts.progress_of(0, 0)).is_equal(0)
	assert_str(_parts.phase_at(1200)).is_equal("evening")
	assert_str(_parts.phase_at(100)).is_equal("night")
	assert_str(_parts.clock_text_at(65).replace("01:", "1:")).is_equal("1:05")


func test_the_music_box_lists_and_steps_by_the_player_s_code() -> void:
	await _until_ready(Parts.MUSIC)
	var titles: Array[String] = await _parts.titles()
	assert_int(titles.size()).is_equal(_parts.track_list().size())
	assert_int(_parts.next_index(2, 3)).is_equal(0)
	assert_int(_parts.next_index(0, 3)).is_equal(1)


func test_the_credits_roll_the_player_s_lines() -> void:
	var names: Array[String] = ["Boots", "Save", "Menu"]
	var lines: Array[String] = await _parts.credits_lines("Kai", names)
	assert_bool(lines.is_empty()).is_false()
	assert_bool(lines.any(func(line: String) -> bool: return line.contains("Kai"))).is_true()


func test_a_part_not_built_answers_with_its_stand_in() -> void:
	_state = OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
	_parts.refresh()
	assert_str(_parts.shortcut("escape")).is_equal("")
	assert_bool(_parts.escape_opens_menu()).is_false()
	assert_float(_parts.volume_at(5)).is_equal(-1.0)
	assert_int(_parts.progress_of(1, 2)).is_equal(-1)
	assert_str(_parts.phase_at(1200)).is_equal("")
	assert_array(_parts.menu_items()).is_equal(Parts.town_menu(Parts.menu_built(_state)))
	var added: Dictionary = await _parts.bag_add("apple")
	assert_bool(bool(added.ok)).is_false()
