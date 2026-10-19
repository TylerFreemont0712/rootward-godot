extends GdUnitTestSuite
## Lanternroot's quest tracker (v0.4, Concept/v0.4/01 section 9.1): the bar when the player's `progress` is built and the
## pips when it is not, the direction line (the arrow's eight ways, the distance, the place, a pin on another map), the
## tracked quest, and H hiding the whole tracker with the minimap. The tracker is made on its own with stand-in parts.

const QUESTS := {
	"keys":
	{
		"order": 1,
		"title": "A key for every door",
		"giver": "innkeeper",
		"steps":
		[
			{"text": "One.", "done": {"flag": "a"}},
			{"text": "Two.", "done": {"flag": "b"}, "at": {"map": "town", "at": [10, 5]}},
			{"text": "Three.", "done": {"flag": "c"}},
			{"text": "Four.", "done": {"flag": "d"}},
		],
	},
	"other": {"order": 2, "title": "Another quest", "giver": "hotaru", "steps": [{"text": "Go.", "done": {"flag": "z"}}]},
}
const CATALOG := {
	"townsfolk": {"innkeeper": {"name": "Marta", "portrait": "innkeeper"}},
	"maps": {"town": {"name": "Lanternroot"}, "home": {"name": "Your house", "interior": true}},
}

var tracker: QuestTracker


func before_test() -> void:
	tracker = QuestTracker.new()
	add_child(tracker)
	tracker.setup(CATALOG)


func after_test() -> void:
	Sound.silence()
	tracker.free()
	Text.setup("en")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _percent_of_steps(done: int, total: int) -> int:
	return done * 100 / maxi(total, 1)


func _place(map_id: String, cell: Vector2i) -> String:
	return "Market" if map_id == "town" and cell.y <= 6 else ""


func test_without_progress_the_card_shows_pips() -> void:
	tracker.follow(QUESTS, {"a": true})
	assert_bool(tracker.pips_showing()).is_true()
	assert_int(tracker.bar_percent()).is_equal(-1)
	assert_str(tracker.steps_text()).is_equal("1 / 4")
	assert_str(tracker.title_text()).is_equal("A key for every door")


func test_a_mounted_tracker_rebuilds_its_japanese_copy_when_the_reading_changes() -> void:
	Text.setup("ja", "hiragana")
	var key := "The town is glad you came."
	tracker.set("_wanted", {"id": "reading", "step": 0, "title": key, "text": key, "done": 0, "total": 1})
	tracker.call("_draw_now")
	var kana_step := tracker.step_text()
	assert_str(kana_step).is_equal(Text.t(key))
	Text.setup("ja", "kanji")
	assert_str(tracker.step_text()).is_equal(Text.t(key))
	assert_str(tracker.step_text()).is_not_equal(kana_step)


func test_a_progress_that_is_not_built_gives_minus_one_and_the_pips_stay() -> void:
	tracker.set_parts(func(_done: int, _total: int) -> int: return -1, Callable())
	tracker.follow(QUESTS, {"a": true})
	assert_bool(tracker.pips_showing()).is_true()
	assert_int(tracker.bar_percent()).is_equal(-1)


func test_with_progress_built_the_card_shows_a_bar_with_the_players_percent() -> void:
	tracker.set_parts(_percent_of_steps, Callable())
	tracker.follow(QUESTS, {"a": true})
	assert_int(tracker.bar_percent()).is_equal(25)
	assert_bool(tracker.pips_showing()).is_false()
	assert_str((tracker.get("_percent") as Label).text).is_equal("25%")


func test_the_bar_moves_to_a_new_value_when_the_progress_changes() -> void:
	tracker.set_parts(_percent_of_steps, Callable())
	tracker.follow(QUESTS, {"a": true})
	tracker.set_shown(true)
	await _frames(30)
	tracker.follow(QUESTS, {"a": true, "b": true})
	await get_tree().create_timer(2.5).timeout
	assert_int(tracker.bar_percent()).is_equal(50)
	assert_float(float(tracker.get("_bar_value"))).is_equal_approx(0.5, 0.001)


func test_building_progress_later_turns_the_pips_into_a_bar() -> void:
	tracker.follow(QUESTS, {"a": true})
	assert_bool(tracker.pips_showing()).is_true()
	tracker.set_parts(_percent_of_steps, Callable())
	assert_int(tracker.bar_percent()).is_equal(25)


func test_the_arrow_points_one_of_eight_ways() -> void:
	var here := Vector2i(20, 20)
	var ways := {
		Vector2i(5, 0): "e",
		Vector2i(5, 5): "se",
		Vector2i(0, 5): "s",
		Vector2i(-5, 5): "sw",
		Vector2i(-5, 0): "w",
		Vector2i(-5, -5): "nw",
		Vector2i(0, -5): "n",
		Vector2i(5, -5): "ne",
		# Between two ways it takes the nearer one.
		Vector2i(10, 2): "e",
		Vector2i(10, 6): "se",
		Vector2i(-2, -10): "n",
	}
	for delta: Vector2i in ways:
		assert_str(QuestTracker.arrow_of(here, here + delta)).override_failure_message("delta %s" % delta).is_equal(ways[delta])
	assert_str(QuestTracker.arrow_of(here, here)).is_equal("")


func test_a_step_with_a_pin_shows_its_arrow_distance_and_place() -> void:
	tracker.set_parts(Callable(), _place)
	tracker.follow(QUESTS, {"a": true})
	assert_str(tracker.direction_text()).override_failure_message("not located yet: no line").is_empty()
	tracker.locate("town", Vector2i(10, 12))
	assert_str(tracker.direction_arrow()).is_equal("n")
	assert_str(tracker.direction_text()).is_equal("7 tiles · Market")
	assert_object(tracker.minimap()).is_not_null()
	tracker.locate("town", Vector2i(7, 3))
	assert_str(tracker.direction_arrow()).is_equal("se")
	assert_str(tracker.direction_text()).is_equal("5 tiles · Market")
	tracker.locate("town", Vector2i(10, 6))
	assert_str(tracker.direction_text()).is_equal("1 tile · Market")
	tracker.locate("town", Vector2i(10, 5))
	assert_str(tracker.direction_arrow()).is_equal("here")


func test_the_place_is_left_out_when_no_part_names_one() -> void:
	tracker.follow(QUESTS, {"a": true})
	tracker.locate("town", Vector2i(10, 12))
	assert_str(tracker.direction_text()).is_equal("7 tiles")


func test_a_pin_on_another_map_says_where() -> void:
	tracker.follow(QUESTS, {"a": true})
	tracker.locate("home", Vector2i(3, 3))
	assert_str(tracker.direction_arrow()).is_equal("away")
	assert_str(tracker.direction_text()).is_equal("In Lanternroot")
	var at_home := QUESTS.duplicate(true)
	at_home.keys.steps[1].at = {"map": "home", "at": [4, 4]}
	tracker.follow(at_home, {"a": true})
	tracker.locate("town", Vector2i(10, 12))
	assert_str(tracker.direction_text()).is_equal("At home")


func test_a_step_without_a_pin_has_no_line() -> void:
	tracker.locate("town", Vector2i(10, 12))
	tracker.follow(QUESTS, {"a": true, "b": true})
	assert_str(tracker.direction_text()).is_empty()
	assert_str(tracker.direction_arrow()).is_empty()


func test_a_counting_step_shows_its_count_under_the_step() -> void:
	var counting := QUESTS.duplicate(true)
	counting.keys.steps[0].done = {"count": "met-", "at_least": 6}
	tracker.follow(counting, {"met-pip": true, "met-guard": true, "met-orin": true})
	assert_str(tracker.count_text()).is_equal("3 / 6")


func test_a_step_that_does_not_count_has_no_count_line() -> void:
	tracker.follow(QUESTS, {"a": true})
	assert_str(tracker.count_text()).is_empty()


func test_the_tracked_quest_is_the_one_followed() -> void:
	tracker.set_tracked("other")
	tracker.follow(QUESTS, {})
	assert_str(tracker.title_text()).is_equal("Another quest")
	assert_str(tracker.step_text()).is_equal("Go.")


func test_h_hides_the_whole_tracker_and_the_town_cannot_show_it_again() -> void:
	tracker.follow(QUESTS, {"a": true})
	tracker.minimap().set_enabled(true)
	tracker.set_shown(true)
	await _frames(30)
	assert_bool(tracker.is_shown()).is_true()
	assert_bool(tracker.minimap().is_showing()).is_true()
	tracker.toggle_hidden()
	assert_bool(tracker.is_hidden()).is_true()
	assert_bool(tracker.is_shown()).is_false()
	assert_bool(tracker.minimap().is_showing()).is_false()
	await _frames(30)
	assert_bool((tracker.get("_card") as Control).visible).is_false()
	assert_bool(tracker.minimap().visible).is_false()
	# A menu opening and closing does not bring it back.
	tracker.set_shown(false)
	tracker.set_shown(true)
	assert_bool(tracker.is_shown()).is_false()
	tracker.toggle_hidden()
	assert_bool(tracker.is_shown()).is_true()
	await _frames(30)
	assert_bool((tracker.get("_card") as Control).visible).is_true()
	assert_bool(tracker.minimap().visible).is_true()


func test_the_minimap_hangs_under_the_card_at_its_right_edge() -> void:
	tracker.follow(QUESTS, {"a": true})
	tracker.minimap().set_enabled(true)
	tracker.set_shown(true)
	await _frames(10)
	var card := (tracker.get("_card") as Control).get_global_rect()
	var map := tracker.minimap().get_global_rect()
	assert_float(map.position.y).is_greater_equal(card.end.y)
	assert_float(map.end.x).is_equal_approx(card.end.x, 1.0)
	assert_float(card.size.x).is_equal_approx(QuestTracker.WIDTH, 1.0)


func test_later_progress_refreshes_the_count_and_bar_without_skipping_the_current_instruction() -> void:
	tracker.set_parts(func(done: int, total: int) -> int: return done * 100 / total, Callable())
	tracker.follow(QUESTS, {})
	tracker.set_shown(true)
	await _frames(30)
	tracker.follow(QUESTS, {"c": true, "d": true})
	assert_str(tracker.step_text()).is_equal("One.")
	assert_str((tracker.get("_steps") as Label).text).is_equal("2 / 4")
	assert_int(tracker.bar_percent()).is_equal(50)
	assert_str(tracker.pip_state(0)).is_equal("current")
	assert_str(tracker.pip_state(1)).is_equal("pending")
	assert_str(tracker.pip_state(2)).is_equal("done")
	assert_str(tracker.pip_state(3)).is_equal("done")
