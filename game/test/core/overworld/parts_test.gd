extends GdUnitTestSuite
## Parts and Bag (Concept/v0.4): what is built, what the menu is offered, the facts conditions see, the tables'
## inputs, and the bag's counting and pickups.


func _built(state: Dictionary, id: String, passed := 1) -> Dictionary:
	return Parts.with_record(state, id, Parts.passed_record({}, passed - 1, "def f():\n    pass\n", "python"))


func test_a_part_is_built_once_its_first_stage_passed_with_a_program() -> void:
	var state := OverworldState.fresh("home", Vector2i(2, 3), "down", "python")
	assert_bool(Parts.built(state, "menu")).is_false()
	state = _built(state, "menu")
	assert_bool(Parts.built(state, "menu")).is_true()
	assert_int(Parts.passed(state, "menu")).is_equal(1)
	assert_str(String(Parts.program(state, "menu").language)).is_equal("python")
	var kept := Parts.passed_record(Parts.record(state, "menu"), 0, "x", "javascript")
	assert_int(int(kept.passed)).is_equal(1)


func test_the_menu_is_offered_what_the_town_has_built() -> void:
	var state := OverworldState.fresh("home", Vector2i(2, 3), "down", "python")
	assert_array(Parts.menu_built(state)).contains_exactly(["quests", "workbench", "save", "settings", "characters", "title"])
	state = _built(_built(state, "bag"), "options")
	assert_array(Parts.menu_built(state)).contains_exactly(["quests", "workbench", "bag", "options", "save", "settings", "characters", "title"])
	var town := Parts.town_menu(Parts.menu_built(state))
	assert_str(town[0]).is_equal("continue")
	assert_str(town[-1]).is_equal("quit")


func test_conditions_see_the_bag_as_facts_that_are_never_saved() -> void:
	var state := OverworldState.fresh("home", Vector2i(2, 3), "down", "python")
	state.bag = [{"item": "cabbage", "count": 2}, {"item": "apple", "count": 1}, {"item": "cabbage", "count": 1}]
	state.flags = {"woke": true}
	var facts := Parts.facts(state)
	assert_int(int(facts["bag:cabbage"])).is_equal(3)
	assert_bool(Talk.holds({"has": "cabbage", "at_least": 3}, facts)).is_true()
	assert_bool(Talk.holds({"has": "apple", "at_least": 2}, facts)).is_false()
	assert_dict(Parts.without_facts(facts)).is_equal({"woke": true})
	var saved := OverworldState.normalized({"flags": facts}, state)
	assert_dict(saved.flags).is_equal({"woke": true})


func test_old_saves_get_the_parts_fields() -> void:
	var fresh := OverworldState.fresh("home", Vector2i(2, 3), "down", "python")
	var old := {"map": "home", "cell": [2, 3], "flags": {}, "bag": "broken", "clock": 1500}
	var state := OverworldState.normalized(old, fresh)
	assert_array(state.bag).is_empty()
	assert_dict(state.tasks).is_empty()
	assert_int(int(state.clock)).is_equal(60)
	assert_str(String(state.tracked)).is_equal("")


func test_each_part_s_table_asks_every_input_the_game_can() -> void:
	var catalog := {"terrain": {"grass": {}, "water": {}}}
	assert_int(Parts.domain("shortcuts", 0, catalog).size()).is_equal(Parts.SHORTCUT_KEYS.size())
	assert_int(Parts.domain("volume", 0, catalog).size()).is_equal(Parts.NOTCH_HIGH - Parts.NOTCH_LOW + 1)
	assert_int(Parts.domain("progress", 0, catalog).size()).is_equal(91)
	assert_int(Parts.domain("clock", 1, catalog).size()).is_equal(1440)
	assert_array(Parts.domain("map", 0, catalog)).contains_exactly([["grass"], ["water"], ["building"], ["tree"], ["thing"]])
	assert_int(Parts.domain("music", 1, catalog).size()).is_equal(32 * 33 / 2)
	assert_array(Parts.domain("menu", 0, catalog)).is_empty()
	for key in Parts.SHORTCUT_KEYS:
		assert_bool(key in Parts.RESERVED_KEYS).is_false()


func test_colour_names_are_the_palette_s() -> void:
	assert_object(Parts.colour_of("Blue")).is_equal(Parts.MAP_COLOURS["blue"])
	assert_object(Parts.colour_of(" dark green ")).is_equal(Parts.MAP_COLOURS["dark green"])
	assert_object(Parts.colour_of("chartreuse")).is_null()
	assert_object(Parts.colour_of(3)).is_null()


func test_a_pickup_regrows_after_its_time_and_marks_its_item() -> void:
	var pickups := {"lanternroot": [{"at": [12, 30], "item": "apple", "regrow": 60.0}]}
	var found := Bag.pickup_at(pickups, "lanternroot", Rect2i(11, 29, 3, 2))
	assert_str(String(found.item)).is_equal("apple")
	assert_dict(Bag.pickup_at(pickups, "lanternroot", Rect2i(0, 0, 3, 2))).is_empty()
	var state := OverworldState.fresh("lanternroot", Vector2i(12, 31), "up", "python")
	state.played_seconds = 100.0
	assert_bool(Bag.ripe(state, "lanternroot", Vector2i(12, 30), 60.0)).is_true()
	state = Bag.picked(state, "lanternroot", Vector2i(12, 30), "apple")
	assert_bool(bool(state.flags["picked-apple"])).is_true()
	assert_bool(Bag.ripe(state, "lanternroot", Vector2i(12, 30), 60.0)).is_false()
	state.played_seconds = 161.0
	assert_bool(Bag.ripe(state, "lanternroot", Vector2i(12, 30), 60.0)).is_true()
	assert_bool(Bag.ripe(state, "lanternroot", Vector2i(12, 30), -1.0)).is_false()


func test_the_bag_counts_and_cleans_its_stacks() -> void:
	var bag := [{"item": "apple", "count": 2.0}, {"item": "", "count": 1}, {"item": "pear", "count": 0}, "junk"]
	assert_dict(Bag.counts(bag)).is_equal({"apple": 2, "pear": 0})
	assert_int(Bag.count(bag, "apple")).is_equal(2)
	assert_array(Bag.cleaned(bag)).contains_exactly([{"item": "apple", "count": 2}])


func test_the_town_s_pickups_and_places_all_fit_its_maps() -> void:
	var loaded := OverworldContent.load_world()
	var found: Array[String] = []
	for diagnostic: Dictionary in loaded.diagnostics:
		if String(diagnostic.get("code", "")) in ["pickups", "places", "tracks", "task"]:
			found.append(ContentLoader.describe(diagnostic))
	assert_array(found).override_failure_message("\n".join(found)).is_empty()
	assert_bool((loaded.catalog.pickups as Dictionary).has("lanternroot")).is_true()
	assert_int((loaded.catalog.places.lanternroot as Array).size()).is_equal(7)
