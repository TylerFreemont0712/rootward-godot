extends GdUnitTestSuite
## Chapter 3's acceptance (Concept/v0.4/05): every chapter 3 part built from its reference program (the test fixtures,
## never shown in the game) answers the town as the part should, through the real sandbox: Hotaru's glow, the weather,
## everyone's hours, Pip's count, Nym's prices, Mira's total and tidy, and Vell's history. PartsRuntime is what the
## overworld asks.

const WAIT_MS := 20000
const CHAPTER_3: Array[String] = [
	"count", "glow", "drills", "locks", "forge", "stones", "weather", "hours", "shop", "tidy", "history",
]

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


func test_every_chapter_3_part_is_a_task_with_its_quest() -> void:
	for id: String in CHAPTER_3:
		assert_bool(id in Parts.IDS).override_failure_message("%s is not a part" % id).is_true()
		assert_bool(_catalog.tasks.has(id)).override_failure_message("no task " + id).is_true()
		assert_bool(_catalog.quests.has(id)).override_failure_message("no quest " + id).is_true()


func test_hotaru_s_glow_follows_the_player_s_table_and_loops() -> void:
	await _until_ready(Parts.GLOW)
	var low := false
	var high := false
	for t in Parts.GLOW_SECONDS:
		var value := _parts.glow_at(t)
		assert_float(value).is_between(0.0, 1.0)
		low = low or value <= 0.3
		high = high or value >= 0.7
	assert_bool(low and high).override_failure_message("the glow never blinks").is_true()
	assert_float(_parts.glow_at(Parts.GLOW_SECONDS + 7)).is_equal(_parts.glow_at(7))
	assert_float(_parts.glow_at(5)).is_equal(float(_reference(Parts.GLOW, 0, [5])))


func test_the_weather_follows_the_player_s_days_and_repeats() -> void:
	await _until_ready(Parts.WEATHER)
	for day in Parts.WEATHER_DAYS:
		assert_array(["sun", "rain", "cloud"]).contains([_parts.weather_on(day)])
	assert_str(_parts.weather_on(Parts.WEATHER_DAYS + 3)).is_equal(_parts.weather_on(3))
	assert_str(_parts.weather_on(0)).is_equal(String(_reference(Parts.WEATHER, 0, [0])))


func test_everyone_keeps_the_player_s_hours() -> void:
	await _until_ready(Parts.HOURS)
	for person: String in _catalog.get("schedules", {}):
		assert_str(_parts.where_at(person, 3)).is_equal("home")
		assert_str(_parts.where_at(person, 10)).is_equal("work")
		assert_str(_parts.where_at(person, 20)).is_equal("inn")
	assert_bool((_catalog.get("schedules", {}) as Dictionary).size() >= 6).is_true()


func test_pip_s_board_counts_with_the_player_s_count() -> void:
	var lanterns := [{"name": "a", "lit": true}, {"name": "b", "lit": false}, {"name": "c", "lit": true}]
	assert_int(await _parts.count_lit(lanterns)).is_equal(2)
	assert_int(await _parts.count_lit([])).is_equal(0)


func test_nym_prices_and_sells_with_the_player_s_code() -> void:
	var buys: Dictionary = _catalog.shop.buys
	assert_int(await _parts.price_of(buys, "apple", 3)).is_equal(int(buys.apple) * 3)
	assert_int(await _parts.price_of(buys, "nothing-at-all", 2)).is_equal(0)
	assert_bool(await _parts.can_buy(12, 12)).is_true()
	assert_bool(await _parts.can_buy(4, 5)).is_false()


func test_mira_s_total_and_tidy_work_on_the_real_bag() -> void:
	var bag := [{"item": "pebble", "count": 2}, {"item": "apple", "count": 3}]
	assert_int(await _parts.total_of(bag)).is_equal(5)
	var tidied: Dictionary = await _parts.tidy_bag(bag)
	assert_bool(tidied.ok).is_true()
	assert_array(tidied.bag).is_equal([{"item": "apple", "count": 3}, {"item": "pebble", "count": 2}])


func test_vell_s_history_names_the_changed_lines() -> void:
	var lines: Array[int] = await _parts.changed_lines(["a", "b", "c"], ["a", "x", "c", "d"])
	assert_array(lines).is_equal([2, 4])


func test_a_chapter_3_part_not_built_answers_with_its_stand_in() -> void:
	_state = OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
	_parts.refresh()
	assert_float(_parts.glow_at(3)).is_equal(-1.0)
	assert_str(_parts.weather_on(3)).is_equal("")
	assert_str(_parts.where_at("pip", 10)).is_equal("")
	assert_int(await _parts.count_lit([{"name": "a", "lit": true}])).is_equal(-1)
	assert_int(await _parts.price_of({"apple": 2}, "apple", 1)).is_equal(-1)
	assert_int(await _parts.total_of([])).is_equal(-1)
	assert_bool(bool((await _parts.tidy_bag([])).ok)).is_false()
	assert_array(await _parts.changed_lines(["a"], ["b"])).is_empty()
