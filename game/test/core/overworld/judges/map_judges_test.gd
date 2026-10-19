extends GdUnitTestSuite
## The judges of the map (map_colour: map_colours; place_of: place_of) and of the credits (credits): every reason each
## can give, and the passing answer of each (Concept/v0.4/01 sections 5.7 and 5.10, 02 section 5).

const GROUNDS: Array[String] = [
	"grass", "flowers", "path", "brick_path", "stone_path", "wood_path", "cobble", "bridge", "floor", "rug", "water", "hedge", "wall", "void", "building", "tree",
	"thing", "root_floor", "fern_moss", "glow_moss",
]


# --- map colours ---------------------------------------------------------------------------------------------------


func test_map_colours_passes_a_colour_for_every_ground() -> void:
	var verdicts := MapJudges.map_colours(_ground_cases(), _colour_results({}))
	assert_array(_reasons(verdicts)).is_equal(_all_reasons("right", GROUNDS.size()))


func test_map_colours_names_a_ground_that_gives_no_colour() -> void:
	var verdicts := MapJudges.map_colours(_ground_cases(), _colour_results({"water": "teal"}))
	assert_str(_reason_at(verdicts, "water")).is_equal("not-colour")
	assert_str(String(verdicts[_index_of("water")].get("name", ""))).is_equal("water")
	assert_str(String(verdicts[_index_of("water")].get("got", ""))).is_equal("teal")
	# Only the case that shows the problem is wrong.
	assert_int(_failing_count(verdicts)).is_equal(1)


func test_map_colours_counts_nothing_as_no_colour() -> void:
	var verdicts := MapJudges.map_colours(_ground_cases(), _colour_results({"tree": null}))
	assert_str(_reason_at(verdicts, "tree")).is_equal("not-colour")
	assert_bool(verdicts[_index_of("tree")].get("got") == null).is_true()


func test_map_colours_compares_colours_without_case() -> void:
	# " GREEN " is the colour "green" (Parts.colour_of strips and lowers), so water is grass's colour.
	var verdicts := MapJudges.map_colours(_ground_cases(), _colour_results({"grass": "Green", "water": " GREEN "}))
	assert_str(_reason_at(verdicts, "water")).is_equal("same-water")


func test_map_colours_water_as_grass_is_same_water() -> void:
	var verdicts := MapJudges.map_colours(_ground_cases(), _colour_results({"water": "green"}))
	assert_str(_reason_at(verdicts, "water")).is_equal("same-water")
	assert_str(_reason_at(verdicts, "grass")).is_equal("right")
	assert_int(_failing_count(verdicts)).is_equal(1)


func test_every_paved_path_as_grass_is_same_path() -> void:
	for kind: String in ["path", "brick_path", "stone_path", "wood_path", "cobble"]:
		var verdicts := MapJudges.map_colours(_ground_cases(), _colour_results({kind: "green"}))
		assert_str(_reason_at(verdicts, kind)).is_equal("same-path")
		assert_int(_failing_count(verdicts)).is_equal(1)


func test_map_colours_building_as_grass_or_path_is_same_building() -> void:
	var as_grass := MapJudges.map_colours(_ground_cases(), _colour_results({"building": "green"}))
	assert_str(_reason_at(as_grass, "building")).is_equal("same-building")
	assert_int(_failing_count(as_grass)).is_equal(1)
	var as_path := MapJudges.map_colours(_ground_cases(), _colour_results({"building": "tan"}))
	assert_str(_reason_at(as_path, "building")).is_equal("same-building")
	assert_int(_failing_count(as_path)).is_equal(1)


func test_map_colours_leaves_the_players_taste_alone() -> void:
	# Flowers, bridges and trees may match anything; a building may match the walls' colour.
	var verdicts := MapJudges.map_colours(
		_ground_cases(), _colour_results({"flowers": "green", "tree": "green", "bridge": "tan", "building": "dark grey"})
	)
	assert_array(_reasons(verdicts)).is_equal(_all_reasons("right", GROUNDS.size()))


# --- where a cell is ----------------------------------------------------------------------------------------------


func test_place_of_passes_the_right_place_or_nothing() -> void:
	var verdicts := _place_verdicts(["Pond", "", ""], ["Pond", "", null])
	assert_array(_reasons(verdicts)).is_equal(["right", "right", "right"])


func test_place_of_gives_wrong_with_want_and_got() -> void:
	var verdicts := _place_verdicts(["Pond", "Pond"], ["Mill", "Pond"])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("wrong")
	assert_str(String(verdicts[0].get("want", ""))).is_equal("Pond")
	assert_str(String(verdicts[0].get("got", ""))).is_equal("Mill")
	assert_str(String(verdicts[1].get("reason", ""))).is_equal("right")


func test_place_of_wrong_when_a_place_is_wanted_and_nothing_comes() -> void:
	var verdicts := _place_verdicts(["Pond"], [null])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("wrong")
	assert_bool(verdicts[0].get("got") == null).is_true()


func test_place_of_wrong_when_a_name_is_given_for_no_place() -> void:
	var verdicts := _place_verdicts([""], ["Pond"])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("wrong")


func test_place_of_not_text_for_an_answer_that_is_not_a_name() -> void:
	var verdicts := _place_verdicts(["Pond", ""], [3, 0])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("not-text")
	assert_str(str(verdicts[0].get("got"))).is_equal("3")
	# Zero is not nothing either.
	assert_str(String(verdicts[1].get("reason", ""))).is_equal("not-text")


func test_place_of_a_case_without_want_passes() -> void:
	var verdicts := MapJudges.place_of([{"args": [1, 1, []], "say": "any"}], [{"ok": true, "value": "anything"}])
	assert_array(_reasons(verdicts)).is_equal(["right"])


# --- credits -------------------------------------------------------------------------------------------------------


func test_credits_passes_lines_with_the_maker_and_every_part() -> void:
	var verdicts := MapJudges.credits(
		[{"args": ["Kai", ["Boots", "Save"]]}], [{"ok": true, "value": ["Made by Kai", "Built: Boots", "Built: Save"]}]
	)
	assert_array(_reasons(verdicts)).is_equal(["right"])


func test_credits_finds_the_maker_without_case() -> void:
	var verdicts := MapJudges.credits([{"args": ["Mina", ["Bag"]]}], [{"ok": true, "value": ["made by mina", "bag"]}])
	assert_array(_reasons(verdicts)).is_equal(["right"])


func test_credits_not_list_for_an_answer_that_is_not_a_list() -> void:
	var verdicts := MapJudges.credits([{"args": ["Kai", []]}], [{"ok": true, "value": "Made by Kai"}])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("not-list")
	assert_str(String(verdicts[0].get("got", ""))).is_equal("Made by Kai")


func test_credits_not_text_names_the_index() -> void:
	var verdicts := MapJudges.credits([{"args": ["Kai", []]}], [{"ok": true, "value": ["Made by Kai", 4]}])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("not-text")
	assert_int(int(verdicts[0].get("index", -1))).is_equal(1)


func test_credits_no_maker_names_the_maker() -> void:
	var verdicts := MapJudges.credits([{"args": ["Kai", ["Boots"]]}], [{"ok": true, "value": ["Built: Boots"]}])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("no-maker")
	assert_str(String(verdicts[0].get("name", ""))).is_equal("Kai")


func test_credits_missing_part_names_the_first_part_on_no_line() -> void:
	var verdicts := MapJudges.credits(
		[{"args": ["Kai", ["Boots", "Save", "Lamps"]]}], [{"ok": true, "value": ["Made by Kai", "Built: Boots", "Built: Lamps"]}]
	)
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("missing-part")
	assert_str(String(verdicts[0].get("name", ""))).is_equal("Save")


func test_credits_too_long_for_more_than_forty_lines() -> void:
	var lines: Array = ["Made by Kai"]
	for _i in 40:
		lines.append("Built: Boots")
	var verdicts := MapJudges.credits([{"args": ["Kai", ["Boots"]]}], [{"ok": true, "value": lines}])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("too-long")


func test_credits_too_long_for_a_line_over_sixty_characters() -> void:
	var long_line := "Made by Kai " + _filler(50)
	var verdicts := MapJudges.credits([{"args": ["Kai", []]}], [{"ok": true, "value": [long_line]}])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("too-long")
	# Exactly sixty characters is fine.
	var sixty := "Made by Kai " + _filler(48)
	verdicts = MapJudges.credits([{"args": ["Kai", []]}], [{"ok": true, "value": [sixty]}])
	assert_str(String(verdicts[0].get("reason", ""))).is_equal("right")


# --- helpers -------------------------------------------------------------------------------------------------------


func _ground_cases() -> Array:
	var out: Array = []
	for ground in GROUNDS:
		out.append({"args": [ground], "say": ground})
	return out


## The answers for every ground, in GROUNDS' order: a good map, with `changed` (ground -> answer) laid over it.
func _colour_results(changed: Dictionary) -> Array:
	var answers := {
		"grass": "green", "flowers": "light green", "path": "tan", "brick_path": "brown", "stone_path": "grey", "wood_path": "red",
		"root_floor": "brown", "fern_moss": "dark green", "glow_moss": "blue", "cobble": "grey", "bridge": "brown", "floor": "brown",
		"rug": "red", "water": "blue", "hedge": "dark green", "wall": "dark grey", "void": "black", "building": "orange",
		"tree": "dark green", "thing": "purple",
	}
	for ground: String in changed:
		answers[ground] = changed[ground]
	var out: Array = []
	for ground in GROUNDS:
		out.append({"ok": true, "value": answers[ground]})
	return out


func _reasons(verdicts: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for verdict: Dictionary in verdicts:
		out.append(String(verdict.get("reason", "")))
	return out


func _all_reasons(reason: String, count: int) -> Array[String]:
	var out: Array[String] = []
	for _i in count:
		out.append(reason)
	return out


## One answer per want: each case is a cell on a 0,0 origin with no places, so only the answer is judged.
func _place_verdicts(wants: Array, answers: Array) -> Array[Dictionary]:
	var cases: Array = []
	var results: Array = []
	for i in wants.size():
		cases.append({"args": [0, 0, []], "want": wants[i]})
		results.append({"ok": true, "value": answers[i]})
	return MapJudges.place_of(cases, results)


func _filler(count: int) -> String:
	var out := ""
	for _i in count:
		out += "x"
	return out


func _index_of(ground: String) -> int:
	return GROUNDS.find(ground)


func _reason_at(verdicts: Array[Dictionary], ground: String) -> String:
	return String(verdicts[_index_of(ground)].get("reason", ""))


func _failing_count(verdicts: Array[Dictionary]) -> int:
	var count := 0
	for verdict: Dictionary in verdicts:
		if not bool(verdict.get("ok", false)):
			count += 1
	return count
