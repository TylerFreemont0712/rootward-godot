extends GdUnitTestSuite

const HOME := "res://content/packs/core/overworld/maps/home.jsonc"

## A two-by-two map with a barrel, for a resize that moves its cells.
const SMALL := """{
 "id": "small",
 "legend": {"f": "floor"},
 "ground": ["ff", "ff"],
 "start": [0, 0],
 "objects": [{"kind": "prop", "art": "barrel", "at": [1, 1]}]
}
"""


## The base: home.jsonc as the Studio loads it. Its objects in order, sids 1 to 11: 0 bed (1, 2), 1 bookshelf,
## 2 desk, 3 lantern (7, 2), 4 chair (6, 2), 5 plant (9, 2), 6 rug, 7 window (2, 1), 8 window, 9 doormat,
## 10 warp (5, 7).
func _home() -> StudioDoc:
	var parsed := StudioDoc.parse(HOME, "map", FileAccess.get_file_as_string(HOME))
	return parsed["doc"]


func test_no_change_gives_no_lines_and_no_changes_summary() -> void:
	var base := _home()
	var edited := base.copy()
	assert_array(StudioDiff.lines(base, edited)).is_empty()
	assert_str(StudioDiff.summary(base, edited)).is_equal("no changes")


func test_a_moved_object_gives_a_moved_line() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["objects"][0]["at"] = [1, 3]
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Moved bed from 1, 2 to 1, 3"])
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 moved")


func test_an_added_object_gives_an_added_line() -> void:
	var base := _home()
	var edited := base.copy()
	var objects: Array = edited.data["objects"]
	objects.append({"kind": "prop", "art": "oak", "at": [12, 40]})
	edited.sids.append(edited.next_sid)
	edited.next_sid += 1
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Added oak at 12, 40"])
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 added")


func test_a_removed_object_gives_a_removed_line() -> void:
	var base := _home()
	var edited := base.copy()
	var objects: Array = edited.data["objects"]
	objects.remove_at(5)
	edited.sids.remove_at(5)
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Removed plant at 9, 2"])
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 removed")


func test_a_changed_field_gives_a_changed_line_with_both_values() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["objects"][7]["solid"] = true
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Changed solid of window at 2, 1: false to true"])
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 changed")


func test_a_field_the_object_did_not_have_gives_a_set_to_line() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["objects"][4]["solid"] = true
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Changed solid of chair at 6, 2: set to true"])


func test_a_field_the_object_lost_gives_a_removed_line() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["objects"][3].erase("sink")
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Changed sink of lantern at 7, 2: removed"])


func test_a_dictionary_field_is_changed_without_its_values() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["objects"][10]["to"] = {"map": "lanternroot", "at": [14, 45], "facing": "down"}
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Changed to of warp to lanternroot at 5, 7"])


func test_a_moved_object_with_a_changed_field_gives_a_moved_line_and_a_changed_line() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["objects"][7]["at"] = [2, 2]
	edited.data["objects"][7]["solid"] = true
	(
		assert_array(StudioDiff.lines(base, edited))
		. is_equal(
			[
				"Moved window from 2, 1 to 2, 2",
				"Changed solid of window at 2, 2: false to true",
			]
		)
	)
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 moved, 1 changed")


func test_a_map_start_gives_a_map_line_with_both_cells() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["start"] = [3, 3]
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Map: start 2, 3 to 3, 3"])
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 map field")


func test_a_map_string_gives_a_map_line_with_quoted_strings() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["name"] = "My house"
	assert_array(StudioDiff.lines(base, edited)).is_equal(['Map: name "Your house" to "My house"'])


func test_a_map_field_that_was_not_there_gives_a_set_to_line() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["music"] = "lanternroot"
	assert_array(StudioDiff.lines(base, edited)).is_equal(['Map: music set to "lanternroot"'])


func test_a_map_dictionary_gives_a_changed_map_line() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["legend"]["x"] = "wall"
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Map: legend changed"])


func test_painted_ground_cells_are_counted() -> void:
	var base := _home()
	var edited := base.copy()
	var ground: Array = edited.data["ground"]
	ground[2] = "WWWWWWWWWWW"
	ground[3] = "WWWWWWWffff"
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Painted 18 ground cells"])
	assert_str(StudioDiff.summary(base, edited)).is_equal("18 ground cells")


func test_a_new_row_resizes_the_map_and_its_cells_are_not_counted_as_painted() -> void:
	var base := _home()
	var edited := base.copy()
	var ground: Array = edited.data["ground"]
	ground.append("fffffffffff")
	assert_array(StudioDiff.lines(base, edited)).is_equal(["Resized the map from 11 x 8 to 11 x 9"])
	assert_str(StudioDiff.summary(base, edited)).is_equal("map size changed")


func test_a_resize_gives_one_resized_line_and_the_moves_not_a_painted_count() -> void:
	var base: StudioDoc = StudioDoc.parse("res://test/small.jsonc", "map", SMALL).doc
	var grown := StudioLand.resize(base.data, base.sids, {"left": 1}, "floor", "small")
	var edited: StudioDoc = StudioCommands.apply(base, grown["command"])["doc"]
	(
		assert_array(StudioDiff.lines(base, edited))
		. is_equal(
			[
				"Map: start 0, 0 to 1, 0",
				"Resized the map from 2 x 2 to 3 x 2",
				"Moved barrel from 1, 1 to 2, 1",
			]
		)
	)
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 moved, 1 map field, map size changed")


func test_several_changes_come_out_in_order_and_are_counted() -> void:
	var base := _home()
	var edited := base.copy()
	edited.data["start"] = [3, 3]
	var ground: Array = edited.data["ground"]
	ground[2] = "WWWWWWWWWWW"
	edited.data["objects"][0]["at"] = [1, 3]
	edited.data["objects"][7]["solid"] = true
	var objects: Array = edited.data["objects"]
	objects.append({"kind": "prop", "art": "oak", "at": [12, 40]})
	edited.sids.append(edited.next_sid)
	edited.next_sid += 1
	objects.remove_at(5)
	edited.sids.remove_at(5)
	(
		assert_array(StudioDiff.lines(base, edited))
		. is_equal(
			[
				"Map: start 2, 3 to 3, 3",
				"Painted 11 ground cells",
				"Removed plant at 9, 2",
				"Added oak at 12, 40",
				"Moved bed from 1, 2 to 1, 3",
				"Changed solid of window at 2, 1: false to true",
			]
		)
	)
	assert_str(StudioDiff.summary(base, edited)).is_equal(
		"1 moved, 1 added, 1 removed, 1 changed, 1 map field, 11 ground cells"
	)


func test_a_person_is_named_by_its_id() -> void:
	assert_str(StudioDiff.name_of({"kind": "person", "id": "pip", "at": [4, 4]})).is_equal("person pip")


func test_a_building_or_prop_is_named_by_its_art() -> void:
	assert_str(StudioDiff.name_of({"kind": "prop", "art": "barrel", "at": [39, 40]})).is_equal("barrel")


func test_a_warp_is_named_by_the_map_it_leads_to() -> void:
	var warp := {"kind": "warp", "at": [5, 7], "to": {"map": "lanternroot", "at": [13, 45]}}
	assert_str(StudioDiff.name_of(warp)).is_equal("warp to lanternroot")


func test_a_sign_is_named_sign() -> void:
	assert_str(StudioDiff.name_of({"kind": "sign", "art": "post", "at": [1, 1]})).is_equal("sign")


func test_catalog_lines_say_what_was_added_changed_and_removed() -> void:
	var text := '{\n  "categories": [],\n  "assets": {\n    "barrel": {"name": "Barrel", "size": [1, 1]},\n    "oak": {"name": "Oak"}\n  }\n}\n'
	var base: StudioDoc = StudioDoc.parse("res://c.jsonc", "catalog", text).doc
	var edited := base.copy()
	edited.data.assets["barrel"] = {"name": "Barrel", "size": [1, 1], "family": "barrel"}
	edited.data.assets["barrel-2x1"] = {"name": "Barrel", "size": [2, 1], "family": "barrel", "variant": "2 × 1"}
	(edited.data.assets as Dictionary).erase("oak")
	var lines := StudioDiff.lines(base, edited)
	assert_array(lines).contains_exactly_in_any_order([
		"added catalog entry barrel-2x1 (Barrel, 2 × 1)", "changed catalog entry barrel: family", "removed catalog entry oak",
	])
	assert_str(StudioDiff.summary(base, edited)).is_equal("1 entry added, 1 changed, 1 removed")
	assert_array(StudioDiff.lines(base, base.copy())).is_empty()


func test_a_map_made_in_the_studio_is_one_line_saying_so() -> void:
	var base := StudioDoc.new()
	base.path = "res://test/room.jsonc"
	base.kind = "map"
	var made := _home()
	var lines := StudioDiff.lines(base, made)
	var things := (made.data["objects"] as Array).size()
	assert_array(lines).contains_exactly(["New map Your house, 11 x 8, with %d things" % things])
	assert_str(StudioDiff.summary(base, made)).is_equal("new map")
