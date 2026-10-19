extends GdUnitTestSuite


func _rebase(base: StudioDoc, draft: StudioDoc, current: StudioDoc) -> Dictionary:
	return StudioRebase.rebase(base, draft, current)
func _doc(path_text: String, data: Dictionary, header_text: String = "// source\n") -> StudioDoc:
	var text := JsoncWriter.map_text(header_text, data)
	var parsed := StudioDoc.parse(path_text, "map", text)
	return parsed["doc"]


func _map(objects: Array, name_text: String = "Town", ground_rows: Array = ["....", "...."]) -> Dictionary:
	return {
		"id": "test-map",
		"name": name_text,
		"ground": ground_rows,
		"objects": objects,
		"legend": {".": "grass", "w": "water"},
		"start": [0, 0],
	}


func _barrel(x: int, y: int, extra: Dictionary = {}) -> Dictionary:
	var object := {"kind": "prop", "art": "barrel", "at": [x, y]}
	for key: Variant in extra:
		object[key] = extra[key]
	return object


func test_non_overlapping_object_map_and_ground_edits_are_merged() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1, {"text": "Old", "solid": false})]))
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Draft text"
	draft.data["name"] = "Draft name"
	draft.data["ground"][0] = "p..."
	var current := base.copy()
	current.data["objects"][0]["solid"] = true
	current.data["start"] = [2, 1]
	current.data["ground"][0] = "...w"
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_true()
	assert_array(result["conflicts"]).is_empty()
	var rebased: StudioDoc = result["doc"]
	assert_str(rebased.data["name"]).is_equal("Draft name")
	assert_array(rebased.data["start"]).is_equal([2, 1])
	assert_dict(rebased.data["objects"][0]).is_equal(
		_barrel(1, 1, {"text": "Draft text", "solid": true})
	)
	assert_array(rebased.data["ground"]).is_equal(["p..w", "...."])


func test_nearest_match_keeps_a_draft_edit_on_a_moved_anonymous_object() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1), _barrel(8, 1)]))
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Keep this barrel"
	var current := base.copy()
	current.data["objects"] = [_barrel(9, 1), _barrel(2, 1)]
	current.sids = [2, 1]
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_true()
	assert_array(result["conflicts"]).is_empty()
	var rebased: StudioDoc = result["doc"]
	assert_dict(rebased.data["objects"][0]).is_equal(_barrel(9, 1))
	assert_dict(rebased.data["objects"][1]).is_equal(_barrel(2, 1, {"text": "Keep this barrel"}))
	assert_array(rebased.sids).is_equal([2, 1])


func test_external_reorder_addition_and_deletion_are_retained() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1), _barrel(2, 1), {"kind": "sign", "art": "post", "at": [3, 1]}]))
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Draft edit"
	draft.data["objects"].remove_at(1)
	draft.sids.remove_at(1)
	var current := base.copy()
	current.data["objects"] = [
		{"kind": "prop", "art": "oak", "at": [4, 1]},
		_barrel(2, 1),
		_barrel(1, 1),
	]
	current.sids = [4, 2, 1]
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_true()
	assert_array(result["conflicts"]).is_empty()
	var rebased: StudioDoc = result["doc"]
	assert_array(rebased.data["objects"]).is_equal(
		[
			{"kind": "prop", "art": "oak", "at": [4, 1]},
			_barrel(1, 1, {"text": "Draft edit"}),
		]
	)
	assert_int(rebased.data["objects"].size()).is_equal(rebased.sids.size())


func test_same_field_edits_report_a_conflict_and_keep_current_value() -> void:
	var base := _doc("res://maps/town.jsonc", _map([], "Base"))
	var draft := base.copy()
	draft.data["name"] = "Draft"
	var current := base.copy()
	current.data["name"] = "Disk"
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_false()
	assert_str(result["doc"].data["name"]).is_equal("Disk")
	assert_int(result["conflicts"].size()).is_equal(1)
	assert_str(result["conflicts"][0]["file"]).is_equal(current.path)
	assert_bool(result["conflicts"][0]["sid"] == null).is_true()
	assert_str(result["conflicts"][0]["field"]).is_equal("name")
	assert_str(result["conflicts"][0]["base"]).is_equal("Base")
	assert_str(result["conflicts"][0]["draft"]).is_equal("Draft")
	assert_str(result["conflicts"][0]["current"]).is_equal("Disk")


func test_same_object_field_edits_report_a_conflict_and_keep_current_value() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1, {"text": "Base"})]))
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Draft"
	var current := base.copy()
	current.data["objects"][0]["text"] = "Disk"
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_false()
	assert_str(result["doc"].data["objects"][0]["text"]).is_equal("Disk")
	assert_int(result["conflicts"].size()).is_equal(1)
	assert_int(result["conflicts"][0]["sid"]).is_equal(1)
	assert_str(result["conflicts"][0]["field"]).is_equal("text")


func test_draft_deletion_against_current_object_edit_conflicts_and_keeps_current() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1, {"solid": false})]))
	var draft := base.copy()
	draft.data["objects"].clear()
	draft.sids.clear()
	var current := base.copy()
	current.data["objects"][0]["solid"] = true
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_false()
	assert_array(result["doc"].data["objects"]).is_equal([_barrel(1, 1, {"solid": true})])
	assert_str(result["conflicts"][0]["field"]).is_equal("object")
	assert_int(result["conflicts"][0]["sid"]).is_equal(1)


func test_draft_edit_against_external_object_deletion_conflicts_and_keeps_deletion() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1, {"solid": false})]))
	var draft := base.copy()
	draft.data["objects"][0]["solid"] = true
	var current := base.copy()
	current.data["objects"].clear()
	current.sids.clear()
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_false()
	assert_array(result["doc"].data["objects"]).is_empty()
	assert_str(result["conflicts"][0]["field"]).is_equal("object")
	assert_int(result["conflicts"][0]["sid"]).is_equal(1)


func test_persistent_id_matches_across_kind_art_and_position_changes() -> void:
	var person := {"kind": "person", "id": "pip", "at": [1, 1], "facing": "down"}
	var base := _doc("res://maps/town.jsonc", _map([person]))
	var draft := base.copy()
	draft.data["objects"][0]["facing"] = "left"
	var current := base.copy()
	current.data["objects"][0] = {"kind": "person", "id": "pip", "at": [8, 6], "facing": "down"}
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_true()
	assert_array(result["conflicts"]).is_empty()
	assert_dict(result["doc"].data["objects"][0]).is_equal(
		{"kind": "person", "id": "pip", "at": [8, 6], "facing": "left"}
	)


func test_tied_nearest_candidates_report_ambiguity_and_preserve_current_objects() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(0, 0)]))
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Draft edit"
	var current := base.copy()
	current.data["objects"] = [_barrel(1, 0), _barrel(-1, 0)]
	current.sids = [1, 2]
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_false()
	assert_int(result["conflicts"].size()).is_equal(1)
	assert_str(result["conflicts"][0]["field"]).is_equal("identity")
	assert_array(result["doc"].data["objects"]).is_equal([_barrel(1, 0), _barrel(-1, 0)])


func test_a_current_object_equally_close_to_two_base_objects_is_ambiguous() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(0, 0), _barrel(10, 0)]))
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Draft edit"
	var current := base.copy()
	current.data["objects"] = [_barrel(5, 0)]
	current.sids = [1]
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_false()
	assert_int(result["conflicts"].size()).is_equal(1)
	assert_str(result["conflicts"][0]["field"]).is_equal("identity")
	assert_array(result["doc"].data["objects"]).is_equal([_barrel(5, 0)])


func test_map_dictionaries_merge_different_keys_and_conflict_on_the_same_key() -> void:
	var base := _doc("res://maps/town.jsonc", _map([]))
	var draft := base.copy()
	draft.data["legend"]["p"] = "path"
	var current := base.copy()
	current.data["legend"]["w"] = "deep-water"
	var first := _rebase(base, draft, current)
	assert_bool(first["ok"]).is_true()
	assert_dict(first["doc"].data["legend"]).is_equal({".": "grass", "w": "deep-water", "p": "path"})

	current.data["legend"]["p"] = "platform"
	var second := _rebase(base, draft, current)
	assert_bool(second["ok"]).is_false()
	assert_str(second["doc"].data["legend"]["p"]).is_equal("platform")
	assert_str(second["conflicts"][0]["field"]).is_equal("legend.p")


func test_ground_changes_to_different_cells_merge() -> void:
	var base := _doc("res://maps/town.jsonc", _map([]))
	var draft := base.copy()
	draft.data["ground"][0] = "p..."
	var current := base.copy()
	current.data["ground"][0] = "...w"
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_true()
	assert_array(result["doc"].data["ground"]).is_equal(["p..w", "...."])


func test_ground_same_cell_edits_conflict_and_keep_current_cell() -> void:
	var base := _doc("res://maps/town.jsonc", _map([]))
	var draft := base.copy()
	draft.data["ground"][0] = "p..."
	var current := base.copy()
	current.data["ground"][0] = "w..."
	var result := _rebase(base, draft, current)

	assert_bool(result["ok"]).is_false()
	assert_array(result["doc"].data["ground"]).is_equal(["w...", "...."])
	assert_str(result["conflicts"][0]["field"]).is_equal("ground[0,0]")


func test_draft_and_external_additions_survive_with_distinct_aligned_sids() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1)]))
	var draft := base.copy()
	var draft_objects: Array = draft.data["objects"]
	draft_objects.append(_barrel(2, 1))
	draft.sids.append(2)
	draft.next_sid = 3
	var current := base.copy()
	var current_objects: Array = current.data["objects"]
	current_objects.append({"kind": "prop", "art": "oak", "at": [4, 1]})
	current.sids.append(2)
	current.next_sid = 3
	var result := _rebase(base, draft, current)
	var rebased: StudioDoc = result["doc"]
	var aligned_base: StudioDoc = result["base_doc"]

	assert_bool(result["ok"]).is_true()
	assert_array(rebased.data["objects"]).is_equal(
		[_barrel(1, 1), {"kind": "prop", "art": "oak", "at": [4, 1]}, _barrel(2, 1)]
	)
	assert_array(rebased.sids).is_equal([1, 3, 2])
	assert_array(aligned_base.sids).is_equal([1, 3])
	assert_array(StudioDiff.lines(aligned_base, rebased)).is_equal(["Added barrel at 2, 1"])


func test_result_uses_current_metadata_and_preserves_unique_draft_sids() -> void:
	var base := _doc("res://maps/old.jsonc", _map([_barrel(1, 1), _barrel(5, 1)]), "// base\n")
	base.sids = [40, 41]
	base.next_sid = 42
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Edited"
	var current := _doc("res://maps/new.jsonc", _map([_barrel(1, 1), _barrel(5, 1), _barrel(9, 1)]), "// current\n")
	current.data["objects"][0]["at"] = [1.0, 1.0]
	current.sids = [1, 2, 40]
	current.next_sid = 41
	var result := _rebase(base, draft, current)
	var rebased: StudioDoc = result["doc"]

	assert_bool(result["ok"]).is_true()
	assert_str(rebased.path).is_equal(current.path)
	assert_str(rebased.header).is_equal(current.header)
	assert_str(rebased.base_hash).is_equal(current.base_hash)
	assert_array(rebased.sids).is_equal([40, 41, 42])
	assert_int(rebased.next_sid).is_equal(43)
	assert_int(typeof(rebased.data["objects"][0]["at"][0])).is_equal(TYPE_INT)
	assert_str(rebased.to_text()).is_equal(JsoncWriter.map_text(current.header, rebased.data))
	assert_array(result["base_doc"].sids).is_equal(rebased.sids)
	assert_array(StudioDiff.lines(result["base_doc"], rebased)).is_equal(["Changed text of barrel at 1, 1: set to \"Edited\""])


func test_rebase_does_not_mutate_any_input_document() -> void:
	var base := _doc("res://maps/town.jsonc", _map([_barrel(1, 1)]))
	var draft := base.copy()
	draft.data["objects"][0]["text"] = "Draft"
	var current := base.copy()
	current.data["objects"][0]["solid"] = true
	var base_text := base.to_text()
	var draft_text := draft.to_text()
	var current_text := current.to_text()
	var base_sids := base.sids.duplicate()
	var draft_sids := draft.sids.duplicate()
	var current_sids := current.sids.duplicate()

	_rebase(base, draft, current)

	assert_str(base.to_text()).is_equal(base_text)
	assert_str(draft.to_text()).is_equal(draft_text)
	assert_str(current.to_text()).is_equal(current_text)
	assert_array(base.sids).is_equal(base_sids)
	assert_array(draft.sids).is_equal(draft_sids)
	assert_array(current.sids).is_equal(current_sids)
