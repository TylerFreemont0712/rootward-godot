extends GdUnitTestSuite

const TALK_DIR := "res://content/packs/core/overworld/talk"
const QUESTS := "res://content/packs/core/overworld/quests.jsonc"
## Talk files written with objects and short lists on one line. The canonical talk layout writes every object and list
## item on its own line, so these four parse back to the same data but do not round-trip byte for byte. Their
## differences: one-line objects in "lines", "start", "choices" and "all" lists, and one-line lists such as "set": ["x"].
const COMPACT_TALK: Array[String] = [
	"archivist.jsonc",
	"hotaru-first-action.jsonc",
	"noticeboard.jsonc",
	"oracle.jsonc",
]


func _talk_files() -> PackedStringArray:
	var names := PackedStringArray()
	for name: String in DirAccess.get_files_at(TALK_DIR):
		if name.ends_with(".jsonc"):
			names.append(name)
	names.sort()
	return names


func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	return {"text": text, "data": JsoncWriter.normalized(Jsonc.parse(text)["value"])}


func test_the_talk_directory_lists_the_talk_files() -> void:
	var names := _talk_files()
	assert_bool(names.has("pell.jsonc")).is_true()
	assert_bool(names.has("hotaru-wake.jsonc")).is_true()
	for name: String in COMPACT_TALK:
		assert_bool(names.has(name)).override_failure_message(name).is_true()


func test_talk_files_in_the_pretty_layout_round_trip_byte_for_byte() -> void:
	var missed := PackedStringArray()
	for name: String in _talk_files():
		if name in COMPACT_TALK:
			continue
		var file := _read(TALK_DIR + "/" + name)
		if JsoncWriter.talk_text(JsoncWriter.header_of(file["text"]), file["data"]) != file["text"]:
			missed.append(name)
	assert_array(missed).is_empty()


func test_the_compact_talk_files_write_back_to_the_same_data() -> void:
	for name: String in COMPACT_TALK:
		var file := _read(TALK_DIR + "/" + name)
		var written := JsoncWriter.talk_text(JsoncWriter.header_of(file["text"]), file["data"])
		var again: Dictionary = JsoncWriter.normalized(Jsonc.parse(written)["value"])
		assert_dict(again).override_failure_message(name).is_equal(file["data"])
		assert_bool(written != file["text"]).override_failure_message(name + " is canonical now; move it").is_true()


func test_talk_text_writes_empty_lists_and_objects_and_nested_lists_in_the_same_layout() -> void:
	var data := {"id": "t", "set": [], "extra": {}, "all": [[1, "a"]]}
	assert_str(JsoncWriter.talk_text("// head\n", data)).is_equal(
		'// head\n{\n  "id": "t",\n  "set": [],\n  "extra": {},\n  "all": [\n    [\n      1,\n      "a"\n    ]\n  ]\n}\n'
	)


func test_talk_text_puts_a_start_rule_one_key_to_a_line() -> void:
	var data := {"id": "t", "start": [{"goto": "a"}], "nodes": {}}
	assert_str(JsoncWriter.talk_text("", data)).is_equal(
		'{\n  "id": "t",\n  "start": [\n    {\n      "goto": "a"\n    }\n  ],\n  "nodes": {}\n}\n'
	)


func test_a_talk_line_changed_writes_the_same_layout_with_only_that_text_changed() -> void:
	var file := _read(TALK_DIR + "/pell.jsonc")
	var data: Dictionary = file["data"]
	var lines: Array = data["nodes"]["hello"]["lines"]
	lines[0]["text"] = "Hello, tinker! I make maps."
	var old_text := "Hi! You're new! I'm Pell. I make maps."
	var expected: String = file["text"].replace('"%s"' % old_text, '"Hello, tinker! I make maps."')
	assert_str(JsoncWriter.talk_text(JsoncWriter.header_of(file["text"]), data)).is_equal(expected)
	assert_bool(expected != file["text"]).is_true()


func test_quests_round_trips_byte_for_byte() -> void:
	var file := _read(QUESTS)
	assert_str(JsoncWriter.quests_text(JsoncWriter.header_of(file["text"]), file["data"])).is_equal(file["text"])


func test_a_new_quest_step_is_one_more_line_in_the_same_layout() -> void:
	var file := _read(QUESTS)
	var text: String = file["text"]
	var data: Dictionary = file["data"]
	var steps: Array = data["boots"]["steps"]
	steps.append({"text": "Ring the bell.", "done": {"flag": "bell"}})
	var last := '      {"text": "Walk out of your house.", "hint": "The door is at the bottom of the room.", "done": {"flag": "left-home"}}'
	var added := '      {"text": "Ring the bell.", "done": {"flag": "bell"}}'
	var expected := text.replace(last + "\n    ]", last + ",\n" + added + "\n    ]")
	assert_str(JsoncWriter.quests_text(JsoncWriter.header_of(text), data)).is_equal(expected)
	assert_bool(expected != text).is_true()


func test_quests_text_writes_empty_steps_and_lists_compact() -> void:
	var data := {"x": {"order": 1, "after": [], "steps": []}}
	assert_str(JsoncWriter.quests_text("", data)).is_equal('{\n  "x": {\n    "order": 1,\n    "after": [],\n    "steps": []\n  }\n}\n')


func test_quests_text_keeps_quest_order_and_puts_each_step_on_a_line() -> void:
	var data := {
		"b": {"order": 2, "steps": [{"text": "Two.", "done": {"flag": "two"}}]},
		"a": {"order": 1, "after": ["b"], "steps": [{"text": "One.", "done": {"count": "met-", "at_least": 6}}]},
	}
	var lines := PackedStringArray(
		[
			"// head",
			"{",
			'  "b": {',
			'    "order": 2,',
			'    "steps": [',
			'      {"text": "Two.", "done": {"flag": "two"}}',
			"    ]",
			"  },",
			'  "a": {',
			'    "order": 1,',
			'    "after": ["b"],',
			'    "steps": [',
			'      {"text": "One.", "done": {"count": "met-", "at_least": 6}}',
			"    ]",
			"  }",
			"}",
			"",
		]
	)
	assert_str(JsoncWriter.quests_text("// head\n", data)).is_equal("\n".join(lines))
