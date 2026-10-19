extends GdUnitTestSuite
## A thing's code in the real sandbox (ADR-0061, ThingRun), in both languages: the value comes back, both entry names
## work, an error reports its line, a missing function is broken, endless code times out, a memory bomb is out of
## memory, too much printing is cut off, and code that sets the player's position changes nothing in the answer.

const LANGUAGES: Array[String] = ["python", "javascript"]
const PLAYER := {"x": 4, "y": 1, "map": "test-town", "facing": "right", "name": "Tinker"}
const GATE := {
	"kind": "prop",
	"id": "root-gate",
	"solid_unless": "open",
	"program": {"hook": "on_use", "fields": {"open": {"type": "bool", "default": false}}, "raises": []},
}
const FOUR: Array[String] = ["right", "down", "up", "left"]
const THREE: Array[String] = ["right", "down", "up"]
const NONE: Array[String] = []


func _args() -> Dictionary:
	return _args_with(FOUR, "")


## The request for the gate: these keys the boots know, and this default text (thing.keys and thing.text in the code).
func _args_with(keys: Array[String], text: String) -> Dictionary:
	return TownThings.use_input(GATE, {"open": false}, PLAYER, keys, text)


func _line(language: String, python: String, javascript: String) -> String:
	return python if language == "python" else javascript


## The same answer as a function named `name` in `language`: sets the gate open and says it creaks.
func _answer(language: String, name: String) -> String:
	return _line(
		language,
		'def %s(thing, player):\n    return {"set": {"open": True}, "say": "Creak."}\n' % name,
		'function %s(thing, player) {\n  return {set: {open: true}, say: "Creak."};\n}\n' % name,
	)


func test_the_value_comes_back_in_both_languages() -> void:
	for language in LANGUAGES:
		var record := ThingRun.run(language, _answer(language, "on_use"), _args())
		assert_str(String(record.status)).override_failure_message("%s: %s" % [language, record]).is_equal("ok")
		assert_bool(bool(record.ok)).override_failure_message(language).is_true()
		assert_dict(record.value).override_failure_message(language).is_equal({"set": {"open": true}, "say": "Creak."})


func test_both_entry_names_work_in_both_languages() -> void:
	for language in LANGUAGES:
		for name: String in ["on_use", "onUse"]:
			var record := ThingRun.run(language, _answer(language, name), _args())
			assert_str(String(record.status)).override_failure_message("%s %s" % [language, name]).is_equal("ok")
			assert_dict(record.value).override_failure_message("%s %s" % [language, name]).is_not_empty()


func test_an_error_reports_its_line_three_in_both_languages() -> void:
	var source := {
		"python": 'def on_use(thing, player):\n    say = "Hi"\n    return {"say": missing_name}\n',
		"javascript": "function on_use(thing, player) {\n  var say = 'Hi';\n  return {say: missingName};\n}\n",
	}
	for language in LANGUAGES:
		var record := ThingRun.run(language, source[language], _args())
		assert_str(String(record.status)).override_failure_message("%s: %s" % [language, record]).is_equal("ok")
		assert_bool(bool(record.ok)).is_false()
		assert_int(int(record.line)).override_failure_message("%s: %s" % [language, record]).is_equal(3)
		assert_str(String(record.kind)).is_equal("NameError" if language == "python" else "ReferenceError")


func test_code_that_cannot_load_is_broken_and_says_where() -> void:
	var broken := ThingRun.run("python", "def on_use(thing, player)\n    return {}\n", _args())
	assert_str(String(broken.status)).is_equal("broken")
	assert_str(String(broken.kind)).is_equal("SyntaxError")
	assert_int(int(broken.line)).is_equal(1)
	var javascript := ThingRun.run("javascript", "function on_use(thing, player) {\n  return {;\n}\n", _args())
	assert_str(String(javascript.status)).is_equal("broken")


func test_a_missing_function_is_broken_in_both_languages() -> void:
	var source := {
		"python": "def other(thing, player):\n    return {}\n",
		"javascript": "function other(thing, player) { return {}; }\n",
	}
	for language in LANGUAGES:
		var record := ThingRun.run(language, source[language], _args())
		assert_str(String(record.status)).override_failure_message(language).is_equal("broken")
		assert_str(String(record.kind)).override_failure_message(language).is_equal("missing")
		assert_str(String(record.message)).contains("on_use")


func test_endless_code_times_out_within_about_a_second() -> void:
	var source := {
		"python": "def on_use(thing, player):\n    while True:\n        pass\n",
		"javascript": "function on_use(thing, player) {\n  while (true) {}\n}\n",
	}
	for language in LANGUAGES:
		var started := Time.get_ticks_msec()
		var record := ThingRun.run(language, source[language], _args())
		var elapsed := Time.get_ticks_msec() - started
		assert_str(String(record.status)).override_failure_message("%s: %s" % [language, record]).is_equal("timeout")
		assert_bool(bool(record.ok)).is_false()
		# The code gets one second; starting the interpreter is on top of that, and the wall-clock limit is three.
		assert_int(elapsed).override_failure_message("%s took %d ms" % [language, elapsed]).is_less(2500)


func test_a_memory_bomb_is_out_of_memory_in_both_languages() -> void:
	var source := {
		"python": 'def on_use(thing, player):\n    data = []\n    while True:\n        data.append("x" * 1000000)\n',
		"javascript":
		'function on_use(thing, player) {\n  var data = [];\n  while (true) data.push("x".repeat(1000000));\n}\n',
	}
	for language in LANGUAGES:
		var record := ThingRun.run(language, source[language], _args())
		assert_str(String(record.status)).override_failure_message("%s: %s" % [language, record]).is_equal("oom")
		assert_bool(bool(record.ok)).is_false()


func test_printing_more_than_sixteen_kilobytes_is_cut_off() -> void:
	var source := {
		"python": 'def on_use(thing, player):\n    for i in range(100):\n        print("x" * 1000)\n    return {}\n',
		"javascript":
		'function on_use(thing, player) {\n  for (var i = 0; i < 100; i++) console.log("x".repeat(1000));\n  return {};\n}\n',
	}
	for language in LANGUAGES:
		var record := ThingRun.run(language, source[language], _args())
		assert_str(String(record.status)).override_failure_message("%s: %s" % [language, record]).is_equal("failed")
		assert_str(String(record.message)).override_failure_message(language).contains("more than 16 KB")
		assert_bool(bool(record.ok)).is_false()


func test_a_hook_that_sets_the_player_changes_nothing_in_the_answer() -> void:
	var source := {
		"python": 'def on_use(thing, player):\n    player.x = 99\n    player.y = 99\n    return {"say": "Pushed."}\n',
		"javascript":
		'function on_use(thing, player) {\n  player.x = 99;\n  player.y = 99;\n  return {say: "Pushed."};\n}\n',
	}
	for language in LANGUAGES:
		var record := ThingRun.run(language, source[language], _args())
		assert_dict(record.value).override_failure_message(language).is_equal({"say": "Pushed."})
		var verdict := TownThings.judge_use(GATE, record, false)
		assert_dict(verdict.changes).override_failure_message(language).is_empty()
		assert_str(verdict.say).is_equal("Pushed.")


func test_a_printed_line_comes_back_and_does_not_break_the_answer() -> void:
	var source := {
		"python": 'def on_use(thing, player):\n    print("pressed", thing.id)\n    return {"say": "Ok."}\n',
		"javascript":
		'function on_use(thing, player) {\n  console.log("pressed", thing.id);\n  return {say: "Ok."};\n}\n',
	}
	for language in LANGUAGES:
		var record := ThingRun.run(language, source[language], _args())
		assert_str(String(record.status)).override_failure_message(language).is_equal("ok")
		assert_str(String(record.printed)).override_failure_message(language).starts_with("pressed root-gate")
		assert_dict(record.value).is_equal({"say": "Ok."})


func test_a_real_answer_is_judged_into_a_change_to_the_gate() -> void:
	for language in LANGUAGES:
		var record := ThingRun.run(language, _answer(language, "on_use"), _args())
		var verdict := TownThings.judge_use(GATE, record, false)
		assert_bool(bool(verdict.ok)).override_failure_message(language).is_true()
		assert_dict(verdict.changes).is_equal({"open": true})
		assert_str(String(verdict.say)).is_equal("Creak.")


## The code that says how many keys it was given, then which: "4:right,down,up,left". Its keys are read as a list.
func _keys_source(language: String) -> String:
	return _line(
		language,
		'def on_use(thing, player):\n    return {"say": "%d:" % len(thing.keys) + ",".join(thing.keys)}\n',
		'function on_use(thing, player) {\n  return {say: thing.keys.length + ":" + thing.keys.join(",")};\n}\n',
	)


func test_a_hook_is_given_the_keys_its_boots_know_as_a_list_of_the_length_given() -> void:
	for language in LANGUAGES:
		var four := ThingRun.run(language, _keys_source(language), _args_with(FOUR, ""))
		assert_str(String(four.status)).override_failure_message("%s: %s" % [language, four]).is_equal("ok")
		assert_dict(four.value).override_failure_message(language).is_equal({"say": "4:right,down,up,left"})
		var three := ThingRun.run(language, _keys_source(language), _args_with(THREE, ""))
		assert_dict(three.value).override_failure_message(language).is_equal({"say": "3:right,down,up"})
		var none := ThingRun.run(language, _keys_source(language), _args_with(NONE, ""))
		assert_dict(none.value).override_failure_message(language).is_equal({"say": "0:"})


func test_a_hook_is_given_the_words_its_prop_has_as_the_string_given() -> void:
	# Quotes and Japanese in the words: they must come through the request unchanged, as the code reads them.
	var words := 'The Archive. "Home" is past the lanterns: ひかり.'
	var source := {
		"python": 'def on_use(thing, player):\n    return {"say": thing.text}\n',
		"javascript": "function on_use(thing, player) {\n  return {say: thing.text};\n}\n",
	}
	for language in LANGUAGES:
		var record := ThingRun.run(language, source[language], _args_with(FOUR, words))
		assert_str(String(record.status)).override_failure_message("%s: %s" % [language, record]).is_equal("ok")
		assert_dict(record.value).override_failure_message(language).is_equal({"say": words})
		assert_str(TownThings.judge_use(GATE, record, false).say).override_failure_message(language).is_equal(words)
