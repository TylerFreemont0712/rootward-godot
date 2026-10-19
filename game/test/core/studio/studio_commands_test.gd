extends GdUnitTestSuite

const HOME := "res://content/packs/core/overworld/maps/home.jsonc"
const TINY := """// A tiny map for the command tests.
{
 "id": "tiny",
 "name": "Tiny",
 "ground": ["ff", "ff"],
 "legend": {"f": "floor"},
 "start": [0, 0],
 "facing": "down",
 "objects": [
  {"kind": "prop", "art": "barrel", "at": [1, 1]},
  {"kind": "prop", "art": "oak", "at": [0, 1], "solid": true}
 ]
}
"""


func _home() -> StudioDoc:
	var parsed := StudioDoc.parse(HOME, "map", FileAccess.get_file_as_string(HOME))
	return parsed["doc"]


func _tiny() -> StudioDoc:
	var parsed := StudioDoc.parse("res://test/tiny.jsonc", "map", TINY)
	return parsed["doc"]


## The data (as JSON text, so key order counts) and the sids of a doc.
func _state(doc: StudioDoc) -> String:
	return "%s %s" % [JSON.stringify(doc.data), str(doc.sids)]


func _barrel() -> Dictionary:
	return {"kind": "prop", "art": "barrel", "at": [5, 5]}


## Three changes in one batch: move the bed, make it solid, remove the bookshelf (sids 1 and 2 in both test maps).
func _tidy() -> Dictionary:
	return {
		"type": "batch",
		"name": "Tidy",
		"commands":
		[
			{"type": "move", "sids": [1], "by": [1, 1]},
			{"type": "set", "sid": 1, "key": "solid", "value": true},
			{"type": "remove", "sid": 2},
		],
	}


## Applies the command, then the undo it reports: the doc must come back as it was, data and sids alike, and the
## command must not have changed the doc it was given.
func _assert_round_trip(doc: StudioDoc, command: Dictionary) -> void:
	var before := _state(doc)
	var applied := StudioCommands.apply(doc, command)
	assert_bool(applied["ok"]).is_true()
	assert_str(_state(doc)).is_equal(before)
	var edited: StudioDoc = applied["doc"]
	var back := StudioCommands.apply(edited, applied["undo"])
	assert_bool(back["ok"]).is_true()
	assert_str(_state(back["doc"])).is_equal(before)


func test_every_command_type_undoes_back_on_the_home_map() -> void:
	var doc := _home()
	_assert_round_trip(doc, {"type": "add", "object": _barrel()})
	_assert_round_trip(doc, {"type": "add", "object": _barrel(), "index": 0})
	_assert_round_trip(doc, {"type": "remove", "sid": 3})
	_assert_round_trip(doc, {"type": "move", "sids": [1, 2], "by": [1, 0]})
	_assert_round_trip(doc, {"type": "set", "sid": 4, "key": "solid", "value": null})
	_assert_round_trip(doc, {"type": "set", "sid": 1, "key": "solid", "value": true})
	_assert_round_trip(doc, {"type": "set_map", "key": "start", "value": [5, 5]})
	_assert_round_trip(doc, {"type": "set_map", "key": "name", "value": null})
	_assert_round_trip(doc, _tidy())


func test_every_command_type_undoes_back_on_a_tiny_map() -> void:
	var doc := _tiny()
	_assert_round_trip(doc, {"type": "add", "object": _barrel(), "index": 0})
	_assert_round_trip(doc, {"type": "remove", "sid": 2})
	_assert_round_trip(doc, {"type": "move", "sids": [1, 2], "by": [0, -1]})
	_assert_round_trip(doc, {"type": "set", "sid": 2, "key": "solid", "value": null})
	_assert_round_trip(doc, {"type": "set_map", "key": "facing", "value": null})
	_assert_round_trip(doc, {"type": "set_map", "key": "legend", "value": {"f": "grass"}})
	_assert_round_trip(doc, _tidy())


func test_add_appends_with_a_new_sid_when_no_index_is_given() -> void:
	var doc := _home()
	# Counted from the home as it is (its objects are sids 1 to n), so the room may gain furniture.
	var n: int = (doc.data["objects"] as Array).size()
	var result := StudioCommands.apply(doc, {"type": "add", "object": _barrel()})
	assert_bool(result["ok"]).is_true()
	var edited: StudioDoc = result["doc"]
	var objects: Array = edited.data["objects"]
	assert_int(objects.size()).is_equal(n + 1)
	assert_dict(objects[n]).is_equal(_barrel())
	assert_int(edited.sids[n]).is_equal(n + 1)
	assert_int(edited.next_sid).is_equal(n + 2)
	assert_dict(result["undo"]).is_equal({"type": "remove", "sid": n + 1})
	assert_int(result["done"]["sid"]).is_equal(n + 1)


func test_add_at_index_zero_inserts_first() -> void:
	var doc := _tiny()
	var result := StudioCommands.apply(doc, {"type": "add", "object": _barrel(), "index": 0})
	var edited: StudioDoc = result["doc"]
	var objects: Array = edited.data["objects"]
	assert_dict(objects[0]).is_equal(_barrel())
	assert_array(edited.sids).is_equal([3, 1, 2])
	assert_int(edited.next_sid).is_equal(4)


func test_add_with_a_sid_of_its_own_reuses_it_and_moves_next_sid_past_it() -> void:
	var doc := _home()
	var n: int = (doc.data["objects"] as Array).size()
	var result := StudioCommands.apply(doc, {"type": "add", "object": _barrel(), "sid": 40})
	var edited: StudioDoc = result["doc"]
	assert_int(edited.index_of_sid(40)).is_equal(n)
	assert_int(edited.next_sid).is_equal(41)
	var again: StudioDoc = StudioCommands.apply(edited, {"type": "add", "object": _barrel()})["doc"]
	assert_int(again.sids.back()).is_equal(41)


func test_add_refuses_a_sid_already_in_use() -> void:
	var result := StudioCommands.apply(_tiny(), {"type": "add", "object": _barrel(), "sid": 1})
	assert_bool(result["ok"]).is_false()
	assert_bool(String(result["error"]).contains("already in use")).is_true()


func test_remove_then_its_undo_restores_the_object_at_its_index_and_sid() -> void:
	var doc := _home()
	var n: int = (doc.data["objects"] as Array).size()
	var original: Dictionary = doc.object_of_sid(3)
	var result := StudioCommands.apply(doc, {"type": "remove", "sid": 3})
	var edited: StudioDoc = result["doc"]
	assert_int(edited.index_of_sid(3)).is_equal(-1)
	var objects: Array = edited.data["objects"]
	assert_int(objects.size()).is_equal(n - 1)
	var back: StudioDoc = StudioCommands.apply(edited, result["undo"])["doc"]
	assert_int(back.index_of_sid(3)).is_equal(2)
	assert_dict(back.object_of_sid(3)).is_equal(original)
	assert_str(_state(back)).is_equal(_state(doc))


func test_move_of_two_sids_moves_both_and_leaves_the_rest() -> void:
	var doc := _home()
	var result := StudioCommands.apply(doc, {"type": "move", "sids": [1, 2], "by": [1, 0]})
	var edited: StudioDoc = result["doc"]
	assert_array(edited.object_of_sid(1)["at"]).is_equal([2, 2])
	assert_array(edited.object_of_sid(2)["at"]).is_equal([4, 2])
	assert_array(edited.object_of_sid(3)["at"]).is_equal([7, 2])
	assert_array(result["undo"]["by"]).is_equal([-1, 0])


func test_a_command_read_back_from_json_with_whole_floats_still_works() -> void:
	var command: Dictionary = JSON.parse_string('{"type": "move", "sids": [1.0], "by": [2.0, 0.0]}')
	var edited: StudioDoc = StudioCommands.apply(_home(), command)["doc"]
	assert_array(edited.object_of_sid(1)["at"]).is_equal([3, 2])
	assert_int(typeof(edited.object_of_sid(1)["at"][0])).is_equal(TYPE_INT)
	var removed: StudioDoc = StudioCommands.apply(_home(), {"type": "remove", "sid": 3.0})["doc"]
	assert_int(removed.index_of_sid(3)).is_equal(-1)


func test_set_changes_one_field_and_its_undo_restores_it() -> void:
	var doc := _home()
	var result := StudioCommands.apply(doc, {"type": "set", "sid": 1, "key": "text", "value": "Changed."})
	var edited: StudioDoc = result["doc"]
	assert_str(edited.object_of_sid(1)["text"]).is_equal("Changed.")
	assert_str(doc.object_of_sid(1)["text"]).is_equal("Your bed. Still warm.")
	assert_str(result["undo"]["value"]).is_equal("Your bed. Still warm.")
	var back: StudioDoc = StudioCommands.apply(edited, result["undo"])["doc"]
	assert_str(_state(back)).is_equal(_state(doc))


func test_set_to_null_erases_the_key_and_its_undo_puts_it_back_in_place() -> void:
	var doc := _home()
	var result := StudioCommands.apply(doc, {"type": "set", "sid": 4, "key": "solid", "value": null})
	var edited: StudioDoc = result["doc"]
	assert_bool(edited.object_of_sid(4).has("solid")).is_false()
	var back: StudioDoc = StudioCommands.apply(edited, result["undo"])["doc"]
	assert_bool(back.object_of_sid(4).has("solid")).is_true()
	assert_str(_state(back)).is_equal(_state(doc))


func test_set_map_changes_a_top_level_field_and_its_undo_restores_it() -> void:
	var doc := _home()
	var result := StudioCommands.apply(doc, {"type": "set_map", "key": "start", "value": [5, 5]})
	var edited: StudioDoc = result["doc"]
	assert_array(edited.data["start"]).is_equal([5, 5])
	assert_array(doc.data["start"]).is_equal([2, 3])
	var back: StudioDoc = StudioCommands.apply(edited, result["undo"])["doc"]
	assert_str(_state(back)).is_equal(_state(doc))


func test_set_map_refuses_to_replace_the_objects() -> void:
	var result := StudioCommands.apply(_home(), {"type": "set_map", "key": "objects", "value": []})
	assert_bool(result["ok"]).is_false()


func test_a_batch_of_three_undoes_in_one_step() -> void:
	var doc := _home()
	var batch := {
		"type": "batch",
		"name": "Tidy",
		"commands":
		[
			{"type": "add", "object": _barrel()},
			{"type": "set", "sid": 1, "key": "solid", "value": true},
			{"type": "remove", "sid": 2},
		],
	}
	var result := StudioCommands.apply(doc, batch)
	assert_bool(result["ok"]).is_true()
	var edited: StudioDoc = result["doc"]
	# One added and one removed: as many objects as before.
	assert_int(edited.sids.size()).is_equal(doc.sids.size())
	assert_str(result["undo"]["type"]).is_equal("batch")
	assert_str(result["undo"]["name"]).is_equal("Tidy")
	assert_int(result["undo"]["commands"].size()).is_equal(3)
	var back: StudioDoc = StudioCommands.apply(edited, result["undo"])["doc"]
	assert_str(_state(back)).is_equal(_state(doc))


func test_a_batch_with_a_bad_sid_fails_and_changes_nothing() -> void:
	var doc := _home()
	var before := _state(doc)
	var result := (
		StudioCommands
		. apply(
			doc,
			{
				"type": "batch",
				"name": "Oops",
				"commands":
				[
					{"type": "set", "sid": 1, "key": "solid", "value": true},
					{"type": "remove", "sid": 99},
				],
			}
		)
	)
	assert_bool(result["ok"]).is_false()
	assert_bool(result.has("doc")).is_false()
	assert_bool(String(result["error"]).contains("99")).is_true()
	assert_str(_state(doc)).is_equal(before)


func test_a_refused_command_says_why_and_changes_nothing() -> void:
	var doc := _home()
	var before := _state(doc)
	var cases: Array[Dictionary] = [
		{"type": "paint"},
		{"sid": 1},
		{"type": "remove", "sid": 99},
		{"type": "remove"},
		{"type": "set", "sid": 1, "value": true},
		{"type": "add"},
		{"type": "add", "object": _barrel(), "index": 50},
		{"type": "move", "sids": [1, 1], "by": [1, 0]},
		{"type": "move", "sids": [1], "by": [1]},
		{"type": "set_map", "key": "objects", "value": []},
	]
	for command: Dictionary in cases:
		var result := StudioCommands.apply(doc, command)
		assert_bool(result["ok"]).is_false()
		assert_bool(String(result["error"]).is_empty()).is_false()
		assert_bool(result.has("doc")).is_false()
	assert_str(_state(doc)).is_equal(before)


func test_describe_names_each_kind_of_change() -> void:
	var home := _home()
	var three := {"type": "move", "sids": [1, 2, 3], "by": [1, 0]}
	var lantern := {"type": "set", "sid": 4, "key": "solid", "value": true}
	var start := {"type": "set_map", "key": "start", "value": [1, 1]}
	var named := {"type": "batch", "name": "Tidy the room", "commands": []}
	var unnamed := {"type": "batch", "commands": [{}, {}]}
	assert_str(StudioCommands.describe(home, {"type": "add", "object": _barrel()})).is_equal("Add barrel")
	assert_str(StudioCommands.describe(home, {"type": "remove", "sid": 2})).is_equal("Remove bookshelf")
	assert_str(StudioCommands.describe(_tiny(), {"type": "remove", "sid": 2})).is_equal("Remove oak")
	assert_str(StudioCommands.describe(home, three)).is_equal("Move 3 things")
	assert_str(StudioCommands.describe(home, {"type": "move", "sids": [4], "by": [1, 0]})).is_equal("Move lantern")
	assert_str(StudioCommands.describe(home, lantern)).is_equal("Set solid of lantern")
	assert_str(StudioCommands.describe(home, start)).is_equal("Set the map's start")
	assert_str(StudioCommands.describe(home, named)).is_equal("Tidy the room")
	assert_str(StudioCommands.describe(home, unnamed)).is_equal("2 changes")


# --- the catalog's entries (set_entry) -----------------------------------------------------------------------------


func _catalog_doc() -> StudioDoc:
	var text := '// head\n{\n  "categories": [],\n  "assets": {\n    "barrel": {"name": "Barrel", "size": [1, 1]},\n    "oak": {"name": "Oak"}\n  }\n}\n'
	return StudioDoc.parse("res://test/catalog.jsonc", "catalog", text).doc


func test_set_entry_adds_an_entry_at_the_end_and_undo_takes_it_away() -> void:
	var doc := _catalog_doc()
	var result := StudioCommands.apply(doc, {"type": "set_entry", "id": "barrel-2x1", "value": {"name": "Barrel", "size": [2.0, 1.0]}})
	assert_bool(result.ok).is_true()
	var edited: StudioDoc = result.doc
	assert_array((edited.data.assets as Dictionary).keys()).is_equal(["barrel", "oak", "barrel-2x1"])
	assert_array(edited.data.assets["barrel-2x1"].size).is_equal([2, 1])
	assert_str(StudioCommands.apply(edited, result.undo).doc.to_text()).is_equal(doc.to_text())
	assert_str(StudioCommands.describe(doc, {"type": "set_entry", "id": "barrel-2x1", "value": {}})).is_equal("Set the catalog's barrel-2x1")


func test_set_entry_replaces_and_removes_in_place_and_undo_restores_the_order() -> void:
	var doc := _catalog_doc()
	var replaced := StudioCommands.apply(doc, {"type": "set_entry", "id": "barrel", "value": {"name": "Barrel", "family": "barrel"}})
	assert_array((replaced.doc.data.assets as Dictionary).keys()).is_equal(["barrel", "oak"])
	assert_str(replaced.doc.data.assets.barrel.family).is_equal("barrel")
	assert_str(StudioCommands.apply(replaced.doc, replaced.undo).doc.to_text()).is_equal(doc.to_text())
	var removed := StudioCommands.apply(doc, {"type": "set_entry", "id": "barrel", "value": null})
	assert_array((removed.doc.data.assets as Dictionary).keys()).is_equal(["oak"])
	assert_str(StudioCommands.apply(removed.doc, removed.undo).doc.to_text()).is_equal(doc.to_text())


func test_set_entry_refuses_a_bad_id_or_value_and_a_map() -> void:
	var doc := _catalog_doc()
	assert_bool(StudioCommands.apply(doc, {"type": "set_entry", "id": "", "value": {}}).ok).is_false()
	assert_bool(StudioCommands.apply(doc, {"type": "set_entry", "id": "x", "value": 3}).ok).is_false()
	var map: StudioDoc = StudioDoc.parse("res://test/m.jsonc", "map", '{"id": "m", "objects": []}').doc
	assert_bool(StudioCommands.apply(map, {"type": "set_entry", "id": "x", "value": {}}).ok).is_false()


# --- the ground's rows (set_rows) and a batch's shift --------------------------------------------------------------


func test_set_rows_replaces_whole_rows_and_its_undo_puts_them_back() -> void:
	var doc := _tiny()
	_assert_round_trip(doc, {"type": "set_rows", "rows": {"1": "wf"}})
	var applied := StudioCommands.apply(doc, {"type": "set_rows", "rows": {"1": "wf"}})
	var edited: StudioDoc = applied["doc"]
	assert_array(edited.data["ground"]).is_equal(["ff", "wf"])
	assert_dict(applied["undo"]).is_equal({"type": "set_rows", "rows": {"1": "ff"}})
	var both: StudioDoc = StudioCommands.apply(doc, {"type": "set_rows", "rows": {"0": "ww", 1: "ww"}})["doc"]
	assert_array(both.data["ground"]).is_equal(["ww", "ww"])
	var whole: StudioDoc = StudioCommands.apply(doc, {"type": "set_rows", "rows": {1.0: "ww"}})["doc"]
	assert_array(whole.data["ground"]).is_equal(["ff", "ww"])


func test_set_rows_refuses_what_it_cannot_write_and_changes_nothing() -> void:
	var doc := _tiny()
	var before := _state(doc)
	var cases: Array[Dictionary] = [
		{"type": "set_rows", "rows": ["ww"]},
		{"type": "set_rows", "rows": {}},
		{"type": "set_rows"},
		{"type": "set_rows", "rows": {"x": "ww"}},
		{"type": "set_rows", "rows": {"1.5": "ww"}},
		{"type": "set_rows", "rows": {"2": "ww"}},
		{"type": "set_rows", "rows": {"-1": "ww"}},
		{"type": "set_rows", "rows": {"1": 3}},
		{"type": "set_rows", "rows": {"0": "ww", "5": "ww"}},
	]
	for command: Dictionary in cases:
		var result := StudioCommands.apply(doc, command)
		assert_bool(result["ok"]).is_false()
		assert_bool(String(result["error"]).is_empty()).is_false()
	assert_str(_state(doc)).is_equal(before)


func test_set_rows_is_described_as_painting_the_ground() -> void:
	assert_str(StudioCommands.describe(_tiny(), {"type": "set_rows", "rows": {"0": "ww"}})).is_equal("Paint the ground")


func test_a_batch_shift_is_carried_into_its_done_and_negated_in_its_undo() -> void:
	var command := {
		"type": "batch",
		"name": "Grow",
		"shift": [4.0, 0],
		"commands": [{"type": "set_map", "key": "name", "value": "Big"}],
	}
	var result := StudioCommands.apply(_home(), command)
	assert_bool(result["ok"]).is_true()
	assert_array(result["done"]["shift"]).is_equal([4, 0])
	assert_array(result["undo"]["shift"]).is_equal([-4, 0])
	var edited: StudioDoc = result["doc"]
	assert_str(edited.data["name"]).is_equal("Big")
	var back: StudioDoc = StudioCommands.apply(edited, result["undo"])["doc"]
	assert_str(_state(back)).is_equal(_state(_home()))


func test_a_batch_without_a_shift_carries_none() -> void:
	var result := StudioCommands.apply(_home(), _tidy())
	assert_bool(result["done"].has("shift")).is_false()
	assert_bool(result["undo"].has("shift")).is_false()


func test_a_batch_shift_that_is_not_two_whole_numbers_is_refused() -> void:
	for shift: Variant in [[1], "x", [1.5, 0]]:
		var command := {"type": "batch", "name": "Oops", "shift": shift, "commands": []}
		assert_bool(StudioCommands.apply(_home(), command)["ok"]).is_false()


# --- a batch's changes to other maps (S6) --------------------------------------------------------------------------


func test_a_batch_carries_its_changes_to_other_maps_and_its_undo_swaps_them() -> void:
	var there := [{"map": "town", "command": {"type": "remove", "sid": 7}}]
	var back := [{"map": "town", "command": {"type": "add", "object": {"kind": "person", "id": "pell", "at": [1, 1]}, "index": 3, "sid": 7}}]
	var command := {
		"type": "batch", "name": "Move pell here from town",
		"commands": [{"type": "add", "object": {"kind": "person", "id": "pell", "at": [0, 0], "facing": "down"}, "index": -1}],
		"elsewhere": there, "elsewhere_undo": back,
	}
	var result := StudioCommands.apply(_tiny(), command)
	assert_bool(result["ok"]).is_true()
	assert_array(result["done"]["elsewhere"]).is_equal(there)
	assert_array(result["done"]["elsewhere_undo"]).is_equal(back)
	assert_array(result["undo"]["elsewhere"]).override_failure_message("undoing it here takes it back there").is_equal(back)
	assert_array(result["undo"]["elsewhere_undo"]).is_equal(there)
	var edited: StudioDoc = result["doc"]
	var undone := StudioCommands.apply(edited, result["undo"])
	assert_str(_state(undone["doc"])).is_equal(_state(_tiny()))
	assert_array(undone["undo"]["elsewhere"]).override_failure_message("and redoing it does it there again").is_equal(there)


func test_a_batch_without_other_maps_carries_none() -> void:
	var result := StudioCommands.apply(_home(), _tidy())
	assert_bool(result["done"].has("elsewhere")).is_false()
	assert_bool(result["undo"].has("elsewhere")).is_false()


func test_a_batch_whose_other_maps_are_not_map_and_command_is_refused() -> void:
	for value: Variant in ["town", [{"map": "town"}], [{"command": {}}], [{"map": 3, "command": {}}]]:
		var command := {"type": "batch", "name": "Oops", "elsewhere": value, "commands": []}
		assert_bool(StudioCommands.apply(_home(), command)["ok"]).override_failure_message(str(value)).is_false()


const QUESTS := "res://content/packs/core/overworld/quests.jsonc"
const PELL := "res://content/packs/core/overworld/talk/pell.jsonc"
const WRITE_LINE := '      {"text": "Write light_all: light every lamp on the lane.", "done": {"flag": "lamps-written"}},'


func _quests() -> StudioDoc:
	var parsed := StudioDoc.parse(QUESTS, "quests", FileAccess.get_file_as_string(QUESTS))
	return parsed["doc"]


func _pell() -> StudioDoc:
	var parsed := StudioDoc.parse(PELL, "talk", FileAccess.get_file_as_string(PELL))
	return parsed["doc"]


## Applies a command that must work: its text must be `expected`, the doc given must not change, and the undo must put
## the text back exactly. Returns the edited doc (the given one when the command was refused).
func _edit_text(doc: StudioDoc, command: Dictionary, expected: String) -> StudioDoc:
	var before := doc.to_text()
	var applied := StudioCommands.apply(doc, command)
	assert_bool(applied["ok"]).override_failure_message(str(applied.get("error", ""))).is_true()
	if not applied["ok"]:
		return doc
	var edited: StudioDoc = applied["doc"]
	assert_str(doc.to_text()).is_equal(before)
	assert_str(edited.to_text()).is_equal(expected)
	var back := StudioCommands.apply(edited, applied["undo"])
	assert_bool(back["ok"]).is_true()
	var restored: StudioDoc = back.get("doc", edited)
	assert_str(restored.to_text()).is_equal(before)
	return edited


func test_set_at_replaces_a_value_and_keeps_its_place() -> void:
	var doc := _quests()
	var text := doc.to_text()
	_edit_text(doc, {"type": "set_at", "path": ["boots", "order"], "value": 9}, text.replace('"order": 1,', '"order": 9,'))


func test_set_at_adds_a_missing_key_at_the_end_of_its_dictionary() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var path := ["hello", "steps", 2, "done", "flag"]
	_edit_text(doc, {"type": "set_at", "path": path, "value": "met-six"}, text.replace('"at_least": 6}}', '"at_least": 6, "flag": "met-six"}}'))


func test_set_at_null_erases_a_key_and_undo_puts_it_back_in_its_place() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var erased := '"hint": "B opens your boots.", '
	_edit_text(doc, {"type": "set_at", "path": ["boots", "steps", 0, "hint"], "value": null}, text.replace(erased, ""))


func test_set_at_changes_an_item_of_a_list_and_a_nested_key_under_it() -> void:
	var doc := _quests()
	var text := doc.to_text()
	_edit_text(doc, {"type": "set_at", "path": ["boots", "steps", 0, "text"], "value": "Press Try them."}, text.replace('"Press Try them, then walk right."', '"Press Try them."'))
	_edit_text(doc, {"type": "set_at", "path": ["memory", "steps", 1, "done", "flag"], "value": "wrote"}, text.replace('"flag": "memory-written"', '"flag": "wrote"'))


func test_insert_at_puts_an_item_into_a_list_and_undo_takes_it_out() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var first := '      {"text": "Meet Vell at the Archive.", "done": {"flag": "memory-asked"}},'
	var added := '{"text": "Go on.", "done": {"flag": "go"}}'
	var command := {"type": "insert_at", "path": ["memory", "steps"], "index": 1, "value": {"text": "Go on.", "done": {"flag": "go"}}}
	_edit_text(doc, command, text.replace(first + "\n", first + "\n      " + added + ",\n"))


func test_insert_at_with_index_minus_one_appends_to_the_list() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var last := '      {"text": "Watch the lane light up.", "done": {"flag": "lamps-lit"}}'
	var added := '{"text": "Light the bridge too.", "done": {"flag": "bridge"}}'
	var command := {"type": "insert_at", "path": ["lamps", "steps"], "index": -1, "value": {"text": "Light the bridge too.", "done": {"flag": "bridge"}}}
	_edit_text(doc, command, text.replace(last + "\n    ]", last + ",\n      " + added + "\n    ]"))


func test_remove_at_takes_an_item_out_and_undo_puts_it_back() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var first := '      {"text": "Ask Lumen about the dark lane.", "done": {"flag": "lamps-asked"}},\n'
	_edit_text(doc, {"type": "remove_at", "path": ["lamps", "steps"], "index": 0}, text.replace(first, ""))


func test_removing_the_last_item_takes_the_comma_off_the_one_before() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var last := '      {"text": "Watch the lane light up.", "done": {"flag": "lamps-lit"}}'
	_edit_text(doc, {"type": "remove_at", "path": ["lamps", "steps"], "index": 2}, text.replace(WRITE_LINE + "\n" + last, WRITE_LINE.trim_suffix(",")))


func test_a_refused_path_command_changes_nothing() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var refused: Array[Dictionary] = [
		{"type": "set_at", "path": ["boots", "nope", "x"], "value": 1},
		{"type": "set_at", "path": ["boots", "order", "x"], "value": 1},
		{"type": "set_at", "path": ["boots", "steps", 9, "text"], "value": "x"},
		{"type": "set_at", "path": ["boots", "steps", "0", "text"], "value": "x"},
		{"type": "set_at", "path": ["boots", "steps", 0.5, "text"], "value": "x"},
		{"type": "set_at", "path": ["boots", "nothing"], "value": null},
		{"type": "set_at", "path": [], "value": 1},
		{"type": "set_at", "path": "boots", "value": 1},
		{"type": "set_at", "path": ["boots", "order"]},
		{"type": "insert_at", "path": ["boots"], "value": 1},
		{"type": "insert_at", "path": ["boots", "steps"], "index": 99, "value": 1},
		{"type": "insert_at", "path": ["boots", "steps"], "index": -2, "value": 1},
		{"type": "insert_at", "path": ["boots", "steps"], "index": 0.5, "value": 1},
		{"type": "insert_at", "path": ["boots", "steps"]},
		{"type": "remove_at", "path": ["boots", "steps"], "index": 5},
		{"type": "remove_at", "path": ["boots", "steps"], "index": -1},
		{"type": "remove_at", "path": ["boots", "steps"]},
		{"type": "remove_at", "path": ["boots", "order"], "index": 0},
	]
	for command: Dictionary in refused:
		var result := StudioCommands.apply(doc, command)
		assert_bool(result["ok"]).override_failure_message(str(command)).is_false()
		assert_bool(String(result.get("error", "")).is_empty()).is_false()
		assert_str(doc.to_text()).is_equal(text)


func test_whole_floats_work_as_path_steps_and_indexes() -> void:
	var doc := _quests()
	var set_result := StudioCommands.apply(doc, {"type": "set_at", "path": ["boots", "steps", 0.0, "text"], "value": "Press Try them."})
	assert_bool(set_result["ok"]).is_true()
	assert_array(set_result["done"]["path"]).is_equal(["boots", "steps", 0, "text"])
	var insert_result := StudioCommands.apply(doc, {"type": "insert_at", "path": ["memory", "steps"], "index": 1.0, "value": {"text": "Go on."}})
	assert_bool(insert_result["ok"]).is_true()
	assert_dict(insert_result["undo"]).is_equal({"type": "remove_at", "path": ["memory", "steps"], "index": 1})


func test_a_maps_objects_change_only_through_add_remove_and_move() -> void:
	var doc := _home()
	var refused: Array[Dictionary] = [
		{"type": "set_at", "path": ["objects"], "value": []},
		{"type": "set_at", "path": ["objects", 0], "value": 5},
		{"type": "insert_at", "path": ["objects"], "index": 0, "value": {"kind": "prop"}},
		{"type": "remove_at", "path": ["objects"], "index": 0},
	]
	for command: Dictionary in refused:
		assert_bool(StudioCommands.apply(doc, command)["ok"]).override_failure_message(str(command)).is_false()
	var text := doc.to_text()
	var applied := StudioCommands.apply(doc, {"type": "set_at", "path": ["objects", 0, "at"], "value": [9, 9]})
	assert_bool(applied["ok"]).is_true()
	var edited: StudioDoc = applied["doc"]
	assert_array(edited.object_of_sid(1)["at"]).is_equal([9, 9])
	assert_array(edited.sids).is_equal(doc.sids)
	var back: StudioDoc = StudioCommands.apply(edited, applied["undo"])["doc"]
	assert_str(back.to_text()).is_equal(text)
	var whole := StudioCommands.apply(doc, {"type": "set_at", "path": ["objects", 0], "value": {"kind": "prop", "art": "barrel", "at": [1, 1]}})
	assert_bool(whole["ok"]).is_true()
	assert_array(whole["doc"].sids).is_equal(doc.sids)
	assert_bool(StudioCommands.apply(doc, {"type": "set_at", "path": ["start"], "value": [5, 5]})["ok"]).is_true()


func test_a_batch_of_path_commands_is_one_undo_step() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var batch := {
		"type": "batch",
		"name": "Rework memory",
		"commands":
		[
			{"type": "set_at", "path": ["memory", "order"], "value": 7},
			{"type": "insert_at", "path": ["memory", "steps"], "index": -1, "value": {"text": "Extra.", "done": {"flag": "extra"}}},
			{"type": "remove_at", "path": ["memory", "steps"], "index": 0},
			{"type": "set_at", "path": ["memory", "steps", 0, "text"], "value": "Write your save."},
		],
	}
	var applied := StudioCommands.apply(doc, batch)
	assert_bool(applied["ok"]).is_true()
	var edited: StudioDoc = applied["doc"]
	var steps: Array = edited.data["memory"]["steps"]
	assert_int(steps.size()).is_equal(3)
	assert_str(String(steps[0]["text"])).is_equal("Write your save.")
	assert_str(String(steps[2]["text"])).is_equal("Extra.")
	assert_str(StudioCommands.describe(doc, batch)).is_equal("Rework memory")
	var back: StudioDoc = StudioCommands.apply(edited, applied["undo"])["doc"]
	assert_str(back.to_text()).is_equal(text)


func test_a_batch_with_a_bad_path_command_changes_nothing() -> void:
	var doc := _quests()
	var text := doc.to_text()
	var batch := {
		"type": "batch",
		"commands":
		[
			{"type": "set_at", "path": ["memory", "order"], "value": 7},
			{"type": "remove_at", "path": ["memory", "steps"], "index": 9},
		],
	}
	assert_bool(StudioCommands.apply(doc, batch)["ok"]).is_false()
	assert_str(doc.to_text()).is_equal(text)


func test_describe_names_the_path_commands() -> void:
	var doc := _quests()
	assert_str(StudioCommands.describe(doc, {"type": "set_at", "path": ["hello", "steps", 2, "done", "flag"], "value": "x"})).is_equal("Set flag of hello")
	assert_str(StudioCommands.describe(doc, {"type": "set_at", "path": ["boots", "steps", 0], "value": {}})).is_equal("Set item 1 of boots")
	assert_str(StudioCommands.describe(doc, {"type": "set_at", "path": ["boots"], "value": {}})).is_equal("Set boots")
	assert_str(StudioCommands.describe(doc, {"type": "insert_at", "path": ["memory", "steps"], "index": 0, "value": {}})).is_equal("Add to memory's steps")
	assert_str(StudioCommands.describe(doc, {"type": "remove_at", "path": ["memory", "steps"], "index": 0})).is_equal("Remove from memory's steps")


func test_a_talk_line_changes_by_path_and_its_undo_restores_it() -> void:
	var doc := _pell()
	var text := doc.to_text()
	var old := "Hi! You're new! I'm Pell. I make maps."
	_edit_text(doc, {"type": "set_at", "path": ["nodes", "hello", "lines", 0, "text"], "value": "Hello, tinker!"}, text.replace('"%s"' % old, '"Hello, tinker!"'))
