extends GdUnitTestSuite
## The player's boots in the real sandbox (ADR-0061), in both languages: blocks become code that walks, an error is
## reported with its line and kept per tile, code that cannot load says why, and code that remembers between calls
## is noticed.

const LANGUAGES: Array[String] = ["python", "javascript"]
const SIZE := Vector2i(6, 4)


func _at(table: Dictionary, key: String, cell: Vector2i) -> Vector2i:
	return BootsRules.answer(table, key, cell).to


func test_blocks_become_code_that_walks_in_both_languages() -> void:
	var blocks := [BootsCode.rule("right", "x", 1), BootsCode.rule("up", "y", -1)]
	for language in LANGUAGES:
		var table := BootsRun.run(language, BootsCode.source(blocks, language), SIZE)
		assert_str(table.status).override_failure_message("%s: %s" % [language, table.message]).is_equal("ok")
		assert_that(_at(table, "right", Vector2i(2, 2))).is_equal(Vector2i(3, 2))
		assert_that(_at(table, "up", Vector2i(2, 2))).is_equal(Vector2i(2, 1))
		assert_that(_at(table, "left", Vector2i(2, 2))).is_equal(Vector2i(2, 2))
		assert_array(BootsRules.taught(table)).contains_exactly_in_any_order(["right", "up"])
		assert_bool(table.remembers).is_false()


func test_code_can_depend_on_where_the_player_stands() -> void:
	var source := {
		"python": "def on_key(key, player):\n    if key == 'right' and player.x < 3:\n        player.x += 1\n",
		"javascript": "function onKey(key, player) {\n  if (key === 'right' && player.x < 3) player.x += 1;\n}\n",
	}
	for language in LANGUAGES:
		var table := BootsRun.run(language, source[language], SIZE)
		assert_that(_at(table, "right", Vector2i(1, 0))).is_equal(Vector2i(2, 0))
		assert_that(_at(table, "right", Vector2i(3, 0))).is_equal(Vector2i(3, 0))


func test_an_error_is_kept_with_its_line_for_the_key_that_raised_it() -> void:
	var source := {
		"python":
		"\n".join(
			[
				"def on_key(key, player):",
				"    if key == 'down':",
				"        player.y += speed",
				"    if key == 'right':",
				"        player.x += 1"
			]
		),
		"javascript":
		"\n".join(
			[
				"function onKey(key, player) {",
				"  if (key === 'down') {",
				"    player.y += speed;",
				"  }",
				"  if (key === 'right') player.x += 1;",
				"}"
			]
		),
	}
	for language in LANGUAGES:
		var table := BootsRun.run(language, source[language], SIZE)
		assert_str(table.status).is_equal("ok")
		var down := BootsRules.answer(table, "down", Vector2i(1, 1))
		assert_dict(down.error).override_failure_message(language).is_not_empty()
		assert_int(int(down.error.line)).override_failure_message("%s: %s" % [language, down.error]).is_equal(3)
		assert_str(String(down.error.kind)).is_equal("NameError" if language == "python" else "ReferenceError")
		assert_dict(BootsRules.answer(table, "right", Vector2i(1, 1)).error).is_empty()


func test_code_that_cannot_load_or_has_no_function_says_why() -> void:
	var broken := BootsRun.run("python", "def on_key(key, player)\n    pass\n", SIZE)
	assert_str(broken.status).is_equal("broken")
	assert_str(broken.message).contains("SyntaxError").contains("line 1")
	var missing := BootsRun.run("javascript", "function walk(key, player) {}\n", SIZE)
	assert_str(missing.status).is_equal("broken")
	assert_str(missing.message).contains("onKey")


func test_a_number_that_is_not_whole_is_an_error() -> void:
	var table := BootsRun.run("python", "def on_key(key, player):\n    player.x += 0.5\n", SIZE)
	var step := BootsRules.answer(table, "left", Vector2i(0, 0))
	assert_str(String(step.error.message)).contains("whole numbers")


func test_code_that_remembers_between_steps_is_noticed() -> void:
	var source := "steps = 0\ndef on_key(key, player):\n    global steps\n    steps += 1\n    player.x += steps % 2\n"
	var table := BootsRun.run("python", source, SIZE)
	assert_bool(table.remembers).is_true()


func test_prints_are_kept_short_and_out_of_the_answers() -> void:
	var table := BootsRun.run("javascript", "function onKey(key, player) {\n  console.log('pressed', key);\n}\n", SIZE)
	assert_str(table.status).is_equal("ok")
	assert_str(table.printed).starts_with("pressed up")
	assert_int(table.printed.length()).is_less_equal(600)


func test_a_loop_that_never_ends_is_a_timeout() -> void:
	var table := BootsRun.run("python", "def on_key(key, player):\n    while True:\n        pass\n", SIZE)
	assert_str(table.status).is_equal("timeout")
	assert_bool(BootsRules.ready(table)).is_false()
