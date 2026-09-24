extends GdUnitTestSuite


func test_whole_numbers_have_no_fraction() -> void:
	assert_str(JsJson.stringify({"a": 4.0, "b": 4, "c": -0.0, "d": 1e12})).is_equal(
		'{"a":4,"b":4,"c":0,"d":1000000000000}'
	)


func test_fractions_and_specials() -> void:
	assert_str(JsJson.stringify([1.5, 0.1, NAN, INF])).is_equal("[1.5,0.1,null,null]")


func test_strings_and_nesting_keep_order() -> void:
	var value := {"z": 'a "q"\n', "a": [true, null, {"k": []}]}
	assert_str(JsJson.stringify(value)).is_equal('{"z":"a \\"q\\"\\n","a":[true,null,{"k":[]}]}')


func test_round_trips_parsed_json() -> void:
	var text := '{"power":4,"element":"fire","mult":1.5,"list":[1,2,3]}'
	assert_str(JsJson.stringify(JSON.parse_string(text))).is_equal(text)


func test_parse_keeps_whole_numbers_whole() -> void:
	var value: Dictionary = JsJson.parse('{"hp": 60, "mult": 1.5, "list": [4, 2.25, {"n": 0}], "big": 1e30}')
	assert_int(typeof(value.hp)).is_equal(TYPE_INT)
	assert_int(typeof(value.list[0])).is_equal(TYPE_INT)
	assert_int(typeof(value.list[2].n)).is_equal(TYPE_INT)
	assert_float(value.mult).is_equal(1.5)
	assert_int(typeof(value.big)).is_equal(TYPE_FLOAT)
	assert_object(JsJson.parse("{not json")).is_null()
