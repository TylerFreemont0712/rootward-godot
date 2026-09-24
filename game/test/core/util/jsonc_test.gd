extends GdUnitTestSuite


func test_comments_and_trailing_commas() -> void:
	var text := '{\n  // a note\n  "a": 1, /* inline */ "b": [1, 2,],\n  "c": "not // a comment",\n}\n'
	var parsed := Jsonc.parse(text)
	assert_bool(parsed.ok).is_true()
	assert_str(JsJson.stringify(parsed.value)).is_equal('{"a":1,"b":[1,2],"c":"not // a comment"}')


func test_escaped_quotes_in_strings() -> void:
	var parsed := Jsonc.parse('{"a": "say \\"hi\\" // not a comment", }')
	assert_str(parsed.value.a).is_equal('say "hi" // not a comment')


func test_errors_keep_their_line() -> void:
	var parsed := Jsonc.parse('{\n  // one\n  // two\n  "a": nope\n}')
	assert_bool(parsed.ok).is_false()
	assert_int(parsed.line).is_equal(4)


func test_unicode_survives() -> void:
	var parsed := Jsonc.parse('[{"en": "Adapt", "to": "適応"}] // 日本語')
	assert_str(parsed.value[0].to).is_equal("適応")
