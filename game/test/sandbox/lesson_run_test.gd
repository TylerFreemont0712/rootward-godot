extends GdUnitTestSuite
## The lessons in the real sandbox (ADR-0061), in both languages: a good save and a good light_all pass, a wrong one
## fails with a reason the screen can put into words, and code that cannot load reports its line.

const LANGUAGES: Array[String] = ["python", "javascript"]


func _check(lesson: String, language: String, source: String) -> Dictionary:
	var given := Lessons.cases(lesson, "Mio")
	return Lessons.check(lesson, given, LessonRun.run(lesson, language, source, given))


func test_the_save_blocks_make_a_save_that_passes() -> void:
	for language in LANGUAGES:
		var source := Lessons.save_source(["x", "y", "map", "facing"], language)
		var checked := _check(Lessons.MEMORY, language, source)
		assert_bool(checked.ok).override_failure_message("%s: %s" % [language, checked]).is_true()
		assert_array(checked.cases[0].kept).contains_exactly(["x", "y", "map", "facing"])


func test_a_save_that_forgets_the_map_fails_and_says_so() -> void:
	for language in LANGUAGES:
		var checked := _check(Lessons.MEMORY, language, Lessons.save_source(["x", "y"], language))
		assert_bool(checked.ok).is_false()
		assert_str(String(checked.cases[0].reason)).is_equal("forgot")
		assert_str(String(checked.cases[0].field)).is_equal("map")


func test_a_save_that_keeps_the_wrong_value_says_which() -> void:
	var source := {
		"python": 'def save(player):\n    return {"x": player["y"], "y": player["y"], "map": player["map"]}\n',
		"javascript": "function save(player) {\n  return {x: String(player.x), y: player.y, map: player.map};\n}\n",
	}
	var python := _check(Lessons.MEMORY, "python", source.python)
	assert_str(String(python.cases[0].reason)).is_equal("wrong")
	assert_str(String(python.cases[0].field)).is_equal("x")
	var javascript := _check(Lessons.MEMORY, "javascript", source.javascript)
	assert_str(String(javascript.cases[0].got)).is_equal('"2"')


func test_a_save_without_return_gives_back_nothing() -> void:
	var source := {
		"python": 'def save(player):\n    keep = {"x": player["x"]}\n',
		"javascript": "function save(player) {\n  const keep = {x: player.x};\n}\n",
	}
	for language in LANGUAGES:
		var checked := _check(Lessons.MEMORY, language, source[language])
		assert_str(String(checked.cases[0].reason)).override_failure_message(language).is_equal("nothing")


func test_a_save_that_cannot_load_reports_its_line() -> void:
	var source := {
		"python": 'def save(player):\n    return {"x": player["x"]\n',
		"javascript": "function save(player) {\n  return {x: player.x;\n}\n",
	}
	for language in LANGUAGES:
		var ran := LessonRun.run(Lessons.MEMORY, language, source[language], Lessons.players())
		assert_str(String(ran.status)).override_failure_message("%s: %s" % [language, ran]).is_equal("broken")
		assert_int(int(ran.line)).override_failure_message("%s: %s" % [language, ran]).is_between(1, 3)
		var checked := Lessons.check(Lessons.MEMORY, Lessons.players(), ran)
		assert_str(String(checked.problem.reason)).is_equal("broken")


func test_an_error_inside_save_is_kept_with_its_line() -> void:
	var source := {
		"python": "def save(player):\n    return {\n        'x': player['where'],\n    }\n",
		"javascript": "function save(player) {\n  const at = player.where.x;\n  return {x: at};\n}\n",
	}
	for language in LANGUAGES:
		var checked := _check(Lessons.MEMORY, language, source[language])
		var first: Dictionary = checked.cases[0]
		assert_str(String(first.reason)).override_failure_message("%s: %s" % [language, first]).is_equal("error")
		assert_int(int(first.line)).override_failure_message("%s: %s" % [language, first]).is_equal(
			3 if language == "python" else 2
		)


func test_the_lamp_blocks_light_every_lane_only_with_the_loop() -> void:
	for language in LANGUAGES:
		var good := _check(Lessons.LAMPS, language, Lessons.lamps_source({"loop": true, "inside": true}, language))
		assert_bool(good.ok).override_failure_message("%s: %s" % [language, good]).is_true()
		var first := _check(Lessons.LAMPS, language, Lessons.lamps_source({"first": true}, language))
		assert_bool(first.ok).is_false()
		# The empty lane has no first lamp; one lamp is lit; four of five stay dark.
		assert_str(String(first.cases[0].reason)).is_equal("error")
		assert_bool(first.cases[0].empty).is_true()
		assert_bool(first.cases[1].ok).is_true()
		assert_str(String(first.cases[2].reason)).is_equal("dark")
		assert_int(int(first.cases[2].dark)).is_equal(4)


func test_a_light_all_that_loses_a_lamp_or_says_yes_fails() -> void:
	var lose := {
		"python": "def light_all(lamps):\n    lamps.pop()\n    for lamp in lamps:\n        lamp['lit'] = True\n",
		"javascript": "function lightAll(lamps) {\n  lamps.pop();\n  lamps.forEach(l => { l.lit = true; });\n}\n",
	}
	for language in LANGUAGES:
		var checked := _check(Lessons.LAMPS, language, lose[language])
		assert_str(String(checked.cases[2].reason)).override_failure_message(language).is_equal("count")
	var yes := "def light_all(lamps):\n    for lamp in lamps:\n        lamp['lit'] = 'yes'\n"
	var said := _check(Lessons.LAMPS, "python", yes)
	assert_str(String(said.cases[1].reason)).is_equal("not-true")
	assert_str(String(said.cases[1].got)).is_equal('"yes"')


func test_javascript_takes_the_python_name_too() -> void:
	var source := "function light_all(lamps) {\n  for (const lamp of lamps) lamp.lit = true;\n}\n"
	assert_bool(_check(Lessons.LAMPS, "javascript", source).ok).is_true()
	var missing := LessonRun.run(Lessons.LAMPS, "javascript", "function light(lamps) {}\n", Lessons.lanes())
	assert_str(String(missing.status)).is_equal("broken")
	assert_str(String(missing.message)).contains("lightAll(lamps)")


func test_a_loop_that_never_ends_is_a_timeout() -> void:
	var source := "def light_all(lamps):\n    while True:\n        pass\n"
	var ran := LessonRun.run(Lessons.LAMPS, "python", source, Lessons.lanes())
	assert_str(String(ran.status)).is_equal("timeout")
	assert_str(String(Lessons.check(Lessons.LAMPS, Lessons.lanes(), ran).problem.reason)).is_equal("timeout")


func test_save_and_lamps_answer_for_one_case() -> void:
	var player := Lessons.player_at("lanternroot", Vector2i(5, 6), "up", "Mio")
	var saved := LessonRun.save("python", Lessons.save_source(Lessons.FIELDS, "python"), player)
	assert_bool(saved.ok).is_true()
	assert_int(int(saved.kept.x)).is_equal(5)
	assert_str(String(saved.kept.name)).is_equal("Mio")
	var lit := LessonRun.lamps(
		"javascript", Lessons.lamps_source({"loop": true, "inside": true}, "javascript"), Lessons.lane(3)
	)
	assert_bool(lit.ok).is_true()
	assert_bool(lit.lamps.all(func(lamp: Dictionary) -> bool: return bool(lamp.lit))).is_true()
	var broken := LessonRun.save("python", "def save(player)\n", player)
	assert_bool(broken.ok).is_false()
	assert_str(String(broken.message)).contains("SyntaxError")


func test_prints_come_back_short() -> void:
	var source := "function save(player) {\n  console.log('saving', player.name);\n  return {x: player.x};\n}\n"
	var ran := LessonRun.run(Lessons.MEMORY, "javascript", source, Lessons.players("Mio"))
	assert_str(String(ran.printed)).starts_with("saving Mio")
