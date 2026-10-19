extends GdUnitTestSuite

const LANTERNROOT := "res://content/packs/core/overworld/maps/lanternroot.jsonc"


func _lanternroot() -> StudioDoc:
	var parsed := StudioDoc.parse(LANTERNROOT, "map", FileAccess.get_file_as_string(LANTERNROOT))
	return parsed["doc"]


func test_parse_of_lanternroot_gives_a_sid_per_object_and_no_change() -> void:
	var text := FileAccess.get_file_as_string(LANTERNROOT)
	var parsed := StudioDoc.parse(LANTERNROOT, "map", text)
	assert_bool(parsed["ok"]).is_true()
	var doc: StudioDoc = parsed["doc"]
	var objects: Array = doc.data["objects"]
	var count := objects.size()
	assert_int(count).is_greater(0)
	assert_int(doc.sids.size()).is_equal(count)
	assert_int(doc.sids[0]).is_equal(1)
	assert_int(doc.sids[count - 1]).is_equal(count)
	assert_int(doc.next_sid).is_equal(count + 1)
	assert_str(doc.header).is_equal(JsoncWriter.header_of(text))
	assert_str(doc.to_text()).is_equal(text)
	assert_bool(doc.changed()).is_false()


func test_a_map_without_objects_has_no_sids() -> void:
	var parsed := StudioDoc.parse("res://test/home.jsonc", "map", '{"id": "t", "ground": []}')
	var doc: StudioDoc = parsed["doc"]
	assert_bool(parsed["ok"]).is_true()
	assert_int(doc.sids.size()).is_equal(0)
	assert_int(doc.next_sid).is_equal(1)


func test_changed_is_true_after_an_edit() -> void:
	var doc := _lanternroot()
	assert_bool(doc.changed()).is_false()
	doc.data["objects"][0]["at"] = [1, 1]
	assert_bool(doc.changed()).is_true()


func test_copy_is_deep() -> void:
	var text := FileAccess.get_file_as_string(LANTERNROOT)
	var doc := _lanternroot()
	var edited := doc.copy()
	edited.data["objects"][0]["at"] = [9, 9]
	edited.data["id"] = "changed"
	edited.sids[0] = 99
	edited.next_sid = 100
	assert_str(doc.to_text()).is_equal(text)
	assert_int(doc.sids[0]).is_equal(1)
	assert_int(doc.next_sid).is_equal(doc.sids.size() + 1)
	assert_bool(doc.changed()).is_false()
	assert_bool(edited.changed()).is_true()


func test_index_and_object_of_sid_find_and_miss() -> void:
	var doc := _lanternroot()
	var last := doc.sids.size()
	assert_int(doc.index_of_sid(1)).is_equal(0)
	assert_int(doc.index_of_sid(last)).is_equal(last - 1)
	assert_int(doc.index_of_sid(0)).is_equal(-1)
	assert_int(doc.index_of_sid(last + 1)).is_equal(-1)
	var objects: Array = doc.data["objects"]
	assert_dict(doc.object_of_sid(2)).is_equal(objects[1])
	assert_dict(doc.object_of_sid(last + 1)).is_empty()


func test_a_broken_text_gives_an_error_with_its_line() -> void:
	var parsed := StudioDoc.parse("res://test/broken.jsonc", "map", '{\n "id": "x",\n "name": }\n')
	assert_bool(parsed["ok"]).is_false()
	assert_int(parsed["line"]).is_equal(3)
	assert_bool(parsed.has("doc")).is_false()


func test_an_unknown_kind_is_refused() -> void:
	var parsed := StudioDoc.parse("res://test/x.jsonc", "dialogue", '{"id": "x"}')
	assert_bool(parsed["ok"]).is_false()


const QUESTS := "res://content/packs/core/overworld/quests.jsonc"
const PELL := "res://content/packs/core/overworld/talk/pell.jsonc"


func test_quests_and_talk_are_kinds() -> void:
	assert_bool(StudioDoc.KINDS.has("quests")).is_true()
	assert_bool(StudioDoc.KINDS.has("talk")).is_true()


func test_a_quests_file_parses_as_quests_and_writes_back_unchanged() -> void:
	var text := FileAccess.get_file_as_string(QUESTS)
	var parsed := StudioDoc.parse(QUESTS, "quests", text)
	assert_bool(parsed["ok"]).is_true()
	var doc: StudioDoc = parsed["doc"]
	assert_str(doc.to_text()).is_equal(text)
	assert_int(doc.sids.size()).is_equal(0)
	assert_bool(doc.changed()).is_false()


func test_a_talk_file_parses_as_talk_and_writes_back_unchanged() -> void:
	var text := FileAccess.get_file_as_string(PELL)
	var parsed := StudioDoc.parse(PELL, "talk", text)
	assert_bool(parsed["ok"]).is_true()
	var doc: StudioDoc = parsed["doc"]
	assert_str(doc.to_text()).is_equal(text)
	assert_int(doc.sids.size()).is_equal(0)
	assert_bool(doc.changed()).is_false()


func test_an_edit_to_a_quests_doc_changes_its_text_through_the_kind_writer() -> void:
	var text := FileAccess.get_file_as_string(QUESTS)
	var parsed := StudioDoc.parse(QUESTS, "quests", text)
	var doc: StudioDoc = parsed["doc"]
	doc.data["lamps"]["order"] = 99
	assert_str(doc.to_text()).is_equal(text.replace('"order": 5,', '"order": 99,'))
	assert_bool(doc.changed()).is_true()
