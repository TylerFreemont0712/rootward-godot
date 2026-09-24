extends GdUnitTestSuite
## A spell as one function, and the playback that walks it (ported from the old client's source.ts).

var shards: Dictionary


func before() -> void:
	shards = ContentLoader.load_shardrun().catalog.shards


func _texts(source: SpellSource) -> Array[String]:
	var texts: Array[String] = []
	for line in source.lines:
		texts.append(line.text)
	return texts


func test_a_python_spell_reads_as_one_program() -> void:
	var source := SpellSource.compose("python", "Big Bolt", ["amplify", "fork", "amplify"], shards, 4)
	var texts := _texts(source)
	assert_str(texts[0]).is_equal("# Big Bolt: Amplify → Fork → Amplify")
	assert_str(texts[2]).is_equal("def cast_big_bolt(battle):")
	assert_str(texts[source.start_line - 1]).contains('"power": 4')
	assert_int(source.calls.size()).is_equal(3)
	assert_str(texts[source.calls[1].line - 1]).is_equal("    bolts = fork(bolts, battle)")
	assert_str(texts[source.return_line - 1]).is_equal("    return bolts")
	# Each shard's function appears once, however many slots call it.
	assert_int(texts.count("def amplify(bolts, battle):")).is_equal(1)
	var fork: Dictionary = source.functions.fork
	assert_str(texts[fork.def_line - 1]).is_equal("def fork(bolts, battle):")
	# The comment inside fork is not a line the cursor stops on.
	for line: int in fork.body:
		assert_bool(texts[line - 1].strip_edges().begins_with("#")).is_false()
	assert_int((fork.body as Array).size()).is_equal(5)


func test_a_javascript_spell_has_its_braces() -> void:
	var source := SpellSource.compose("javascript", "Bolt", ["amplify"], shards, 4)
	var texts := _texts(source)
	assert_str(texts[0]).is_equal("// Bolt: Amplify")
	assert_str(texts[2]).is_equal("function castBolt(battle) {")
	assert_str(texts[source.calls[0].line - 1]).is_equal("  bolts = amplify(bolts, battle);")
	assert_str(texts[source.return_line]).is_equal("}")
	assert_array(source.functions.amplify.body).is_equal([source.functions.amplify.def_line + 1])


func test_an_empty_spell_is_one_plain_bolt() -> void:
	var source := SpellSource.compose("python", "Ward", [], shards, 4)
	assert_str(source.lines[0].text).is_equal("# Ward: one plain bolt")
	assert_array(source.calls).is_empty()


func test_playback_shows_values_only_where_they_were_measured() -> void:
	var source := SpellSource.compose("python", "Bolt", ["amplify"], shards, 4)
	var run := {
		"base": {"bolts": [{"power": 4}], "outcome": {"damage": 4}},
		"steps": [{"bolts": [{"power": 7}], "outcome": {"damage": 7}}],
		"result": {"damage": 7},
	}
	var played := SpellSource.frames(source, run, "normal")
	var marks: Array = played.map(func(frame: Dictionary) -> String: return frame.get("mark", ""))
	assert_array(marks).is_equal(["start", "", "", "step", "result"])
	assert_int(played[3].line).is_equal(source.calls[0].line)
	assert_dict(played[3].outcome).is_equal({"damage": 7})
	assert_float(played[1].at).is_equal(380.0)
	assert_float(SpellSource.length_ms(played, "normal")).is_greater(float(played[-1].at))


func test_a_misfire_stops_on_the_line_that_raised() -> void:
	var source := SpellSource.compose("python", "Bolt", ["fork"], shards, 4)
	var fork: Dictionary = source.functions.fork
	var run := {"base": {"bolts": []}, "steps": [], "misfire": {"reason": "boom", "shard": "fork", "line": 5}}
	var played := SpellSource.frames(source, run, "fast")
	assert_str(played[-1].mark).is_equal("error")
	assert_int(played[-1].line).is_equal(int(fork.def_line) + 4)


func test_a_timeout_stops_where_the_cast_began() -> void:
	var source := SpellSource.compose("python", "Bolt", ["fork"], shards, 4)
	var played := SpellSource.frames(source, {"base": {"bolts": []}, "misfire": {"reason": "slow"}}, "fast")
	assert_int(played.size()).is_equal(2)
	assert_int(played[1].line).is_equal(source.start_line)


func test_names_become_function_names() -> void:
	assert_str(SpellSource.snake_case("  Big  Bolt!2 ")).is_equal("big_bolt_2")
	assert_str(SpellSource.pascal_case("big bolt")).is_equal("BigBolt")
	assert_str(SpellSource.snake_case("!!!")).is_equal("spell")
