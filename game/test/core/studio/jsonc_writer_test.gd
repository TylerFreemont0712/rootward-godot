extends GdUnitTestSuite

const LANTERNROOT := "res://content/packs/core/overworld/maps/lanternroot.jsonc"
const HOME := "res://content/packs/core/overworld/maps/home.jsonc"


func test_lanternroot_round_trips_byte_for_byte() -> void:
	var text := FileAccess.get_file_as_string(LANTERNROOT)
	var data: Dictionary = JsoncWriter.normalized(Jsonc.parse(text)["value"])
	assert_str(JsoncWriter.map_text(JsoncWriter.header_of(text), data)).is_equal(text)


func test_home_canonical_text_parses_back_and_writes_the_same_again() -> void:
	var source := FileAccess.get_file_as_string(HOME)
	var data: Dictionary = JsoncWriter.normalized(Jsonc.parse(source)["value"])
	var canonical := JsoncWriter.map_text(JsoncWriter.header_of(source), data)
	var again: Dictionary = JsoncWriter.normalized(Jsonc.parse(canonical)["value"])
	assert_dict(again).is_equal(data)
	assert_str(JsoncWriter.map_text(JsoncWriter.header_of(canonical), again)).is_equal(canonical)


func test_normalized_turns_whole_floats_into_ints_and_keeps_fractions() -> void:
	var value: Dictionary = JsoncWriter.normalized({"a": 13.0, "list": [45.0, 0.5, {"n": -7.0}], "big": 1e20})
	assert_int(typeof(value["a"])).is_equal(TYPE_INT)
	assert_int(value["a"]).is_equal(13)
	assert_int(typeof(value["list"][0])).is_equal(TYPE_INT)
	assert_int(value["list"][0]).is_equal(45)
	assert_int(typeof(value["list"][1])).is_equal(TYPE_FLOAT)
	assert_float(value["list"][1]).is_equal(0.5)
	assert_int(typeof(value["list"][2]["n"])).is_equal(TYPE_INT)
	assert_int(value["list"][2]["n"]).is_equal(-7)
	assert_int(typeof(value["big"])).is_equal(TYPE_FLOAT)
	assert_array(value.keys()).is_equal(["a", "list", "big"])


func test_compact_writes_nested_values_on_one_line() -> void:
	var value := {"id": "x", "at": [3, 4.0], "half": 0.5, "nest": {"ok": true, "none": null, "empty": {}, "list": []}}
	assert_str(JsoncWriter.compact(value)).is_equal(
		'{"id": "x", "at": [3, 4], "half": 0.5, "nest": {"ok": true, "none": null, "empty": {}, "list": []}}'
	)
	assert_str(JsoncWriter.compact({"q": 'a "b"'})).is_equal('{"q": "a \\"b\\""}')


func test_map_text_puts_rows_and_objects_one_to_a_line() -> void:
	var data := {
		"id": "t",
		"legend": {".": "grass"},
		"ground": ["..", ".."],
		"objects": [{"kind": "prop", "at": [1.0, 0]}],
		"start": [0, 0],
	}
	var lines := PackedStringArray(
		[
			"// head",
			"{",
			' "id": "t",',
			' "legend": {".": "grass"},',
			' "ground": [',
			'  "..",',
			'  ".."',
			" ],",
			' "objects": [',
			'  {"kind": "prop", "at": [1, 0]}',
			" ],",
			' "start": [0, 0]',
			"}",
			"",
		]
	)
	assert_str(JsoncWriter.map_text("// head\n", data)).is_equal("\n".join(lines))


func test_map_text_writes_an_empty_objects_list_on_one_line() -> void:
	assert_str(JsoncWriter.map_text("", {"id": "t", "objects": []})).is_equal('{\n "id": "t",\n "objects": []\n}\n')


func test_header_of_keeps_the_comment_lines_before_the_brace() -> void:
	assert_str(JsoncWriter.header_of("// one\n// a {b}\n{\n}\n")).is_equal("// one\n// a {b}\n")
	assert_str(JsoncWriter.header_of("{}")).is_equal("")


const CATALOG := "res://content/packs/core/overworld/catalog.jsonc"


func test_catalog_round_trips_byte_for_byte() -> void:
	var text := FileAccess.get_file_as_string(CATALOG)
	var data: Dictionary = JsoncWriter.normalized(Jsonc.parse(text)["value"])
	assert_str(JsoncWriter.catalog_text(JsoncWriter.header_of(text), data)).is_equal(text)


func test_catalog_text_writes_one_category_and_one_asset_to_a_line() -> void:
	var data := {"categories": [{"id": "a", "name": "A"}], "assets": {"oak": {"name": "Oak", "size": [1.0, 1.0]}}}
	assert_str(JsoncWriter.catalog_text("// head\n", data)).is_equal(
		'// head\n{\n  "categories": [\n    {"id": "a", "name": "A"}\n  ],\n  "assets": {\n    "oak": {"name": "Oak", "size": [1, 1]}\n  }\n}\n'
	)


func test_catalog_doc_parses_and_writes_back_unchanged() -> void:
	var text := FileAccess.get_file_as_string(CATALOG)
	var parsed := StudioDoc.parse(CATALOG, "catalog", text)
	assert_bool(parsed.ok).is_true()
	var doc: StudioDoc = parsed.doc
	assert_str(doc.to_text()).is_equal(text)
	assert_bool(doc.data.assets.has("barrel")).is_true()
