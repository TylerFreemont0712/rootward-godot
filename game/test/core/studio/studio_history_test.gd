extends GdUnitTestSuite

const HOME := "res://content/packs/core/overworld/maps/home.jsonc"


func _home() -> StudioDoc:
	var parsed := StudioDoc.parse(HOME, "map", FileAccess.get_file_as_string(HOME))
	return parsed["doc"]


func _state(doc: StudioDoc) -> String:
	return "%s %s" % [JSON.stringify(doc.data), str(doc.sids)]


func _barrel() -> Dictionary:
	return {"kind": "prop", "art": "barrel", "at": [5, 5]}


func test_do_undo_and_redo_walk_through_three_changes() -> void:
	var history := StudioHistory.new(_home())
	var start := _state(history.doc)
	assert_bool(history.can_undo()).is_false()
	assert_bool(history.can_redo()).is_false()
	assert_bool(history.undo()).is_false()
	assert_bool(history.redo()).is_false()

	assert_bool(history.do({"type": "add", "object": _barrel()})["ok"]).is_true()
	history.do({"type": "set", "sid": 1, "key": "text", "value": "Changed."})
	var after_two := _state(history.doc)
	history.do({"type": "remove", "sid": 2})
	assert_bool(history.can_undo()).is_true()
	assert_bool(history.can_redo()).is_false()
	assert_array(history.labels()).is_equal(["Add barrel", "Set text of bed", "Remove bookshelf"])

	assert_bool(history.undo()).is_true()
	assert_bool(history.undo()).is_true()
	assert_bool(history.can_undo()).is_true()
	assert_bool(history.can_redo()).is_true()
	assert_array(history.labels()).is_equal(["Add barrel"])

	assert_bool(history.redo()).is_true()
	assert_str(_state(history.doc)).is_equal(after_two)
	assert_bool(history.can_redo()).is_true()
	assert_array(history.labels()).is_equal(["Add barrel", "Set text of bed"])

	assert_bool(history.undo()).is_true()
	assert_bool(history.undo()).is_true()
	assert_str(_state(history.doc)).is_equal(start)
	assert_bool(history.can_undo()).is_false()
	assert_array(history.labels()).is_empty()


func test_a_new_change_after_an_undo_clears_the_redo_stack() -> void:
	var history := StudioHistory.new(_home())
	history.do({"type": "remove", "sid": 2})
	history.do({"type": "remove", "sid": 3})
	assert_bool(history.undo()).is_true()
	assert_bool(history.can_redo()).is_true()
	history.do({"type": "move", "sids": [1], "by": [1, 0]})
	assert_bool(history.can_redo()).is_false()
	assert_bool(history.redo()).is_false()
	assert_array(history.labels()).is_equal(["Remove bookshelf", "Move bed"])


func test_a_refused_command_is_not_recorded() -> void:
	var history := StudioHistory.new(_home())
	history.do({"type": "remove", "sid": 2})
	var result := history.do({"type": "remove", "sid": 99})
	assert_bool(result["ok"]).is_false()
	assert_array(history.labels()).is_equal(["Remove bookshelf"])
	assert_bool(history.undo()).is_true()
	assert_bool(history.can_undo()).is_false()


func test_redo_puts_an_added_object_back_with_the_same_sid() -> void:
	var history := StudioHistory.new(_home())
	# Counted from the home as it is: its objects are sids 1 to n.
	var n := history.doc.sids.size()
	history.do({"type": "add", "object": _barrel()})
	assert_int(history.doc.sids.back()).is_equal(n + 1)
	assert_bool(history.undo()).is_true()
	assert_int(history.doc.sids.size()).is_equal(n)
	assert_bool(history.redo()).is_true()
	assert_int(history.doc.sids.back()).is_equal(n + 1)


func test_do_returns_the_apply_result_with_the_doc_moved_on() -> void:
	var history := StudioHistory.new(_home())
	var result := history.do({"type": "set_map", "key": "start", "value": [5, 5]})
	assert_bool(result["ok"]).is_true()
	assert_array(history.doc.data["start"]).is_equal([5, 5])
	assert_str(result["undo"]["key"]).is_equal("start")


func test_peek_shows_what_undo_and_redo_would_apply_and_changes_nothing() -> void:
	var history := StudioHistory.new(_home())
	assert_dict(history.peek_undo()).is_empty()
	assert_dict(history.peek_redo()).is_empty()
	history.do({"type": "remove", "sid": 2})
	var before := _state(history.doc)
	assert_str(history.peek_undo()["type"]).is_equal("add")
	assert_int(history.peek_undo()["sid"]).is_equal(2)
	assert_dict(history.peek_redo()).is_empty()
	assert_str(_state(history.doc)).is_equal(before)
	assert_bool(history.undo()).is_true()
	assert_dict(history.peek_undo()).is_empty()
	assert_str(history.peek_redo()["type"]).is_equal("remove")
	assert_int(history.peek_redo()["sid"]).is_equal(2)
	assert_bool(history.can_redo()).is_true()
	assert_bool(history.redo()).is_true()
	assert_int(history.doc.index_of_sid(2)).is_equal(-1)
