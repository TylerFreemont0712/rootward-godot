extends GdUnitTestSuite
## Lanternroot's Night Watch in the real sandbox (ADR-0055), in both languages: every reference solution passes every
## test, every starter fails its letter, and a failure reports what the player needs (value, error line, prints).

const LANGUAGES: Array[String] = ["python", "javascript"]

var catalog: Dictionary


func before() -> void:
	catalog = LanternContent.load_town().catalog


func _statuses(report: Dictionary) -> Dictionary:
	var by_id := {}
	for result: Dictionary in report.results:
		by_id[result.id] = result.status
	return by_id


func test_the_reference_town_passes_every_test_in_both_languages() -> void:
	for language in LANGUAGES:
		var town := LanternReference.town(catalog, language)
		var cases := LanternRules.night_cases(catalog, town)
		var report := LanternWatch.run(language, town.files, cases)
		assert_str(report.status).override_failure_message(language).is_equal(SandboxResult.OK)
		var failing := (report.results as Array).filter(func(r: Dictionary) -> bool: return r.status != "pass")
		assert_array(failing).override_failure_message("%s: %s" % [language, failing]).is_empty()


func test_every_starter_fails_its_own_letter() -> void:
	for language in LANGUAGES:
		for id: String in catalog.order:
			var request: Dictionary = catalog.requests[id]
			if request.has("replaces"):
				continue
			var town := LanternReference.town(catalog, language, int(request.order) - 1)
			town = LanternRules.open_letter(catalog, town, id)
			var report := LanternWatch.run(language, town.files, LanternRules.letter_cases(catalog, id, language))
			var passed := (report.results as Array).all(func(r: Dictionary) -> bool: return r.status == "pass")
			assert_bool(passed).override_failure_message("%s %s arrives solved" % [language, id]).is_false()


func test_a_failure_reports_its_value_its_prints_and_its_line() -> void:
	var broken := {
		"python":
		"def loaves_for(guests):\n    print('baking', guests)\n    return guests // 4\n\n\ndef bad():\n    pass\n",
		"javascript":
		(
			"function loavesFor(guests) {\n  console.log('baking', guests);\n"
			+ "  return Math.floor(guests / 4);\n}\nmodule.exports.loavesFor = loavesFor;\n"
		),
	}
	for language in LANGUAGES:
		var cases := LanternRules.letter_cases(catalog, "loaves", language)
		var report := LanternWatch.run(language, {"bakery": broken[language]}, cases)
		var nine: Dictionary = report.results[2]
		assert_str(nine.status).is_equal("fail")
		assert_str(nine.actual).is_equal("2")
		assert_str(nine.expected).is_equal("3")
		assert_str(nine.printed).is_equal("baking 9\n")


func test_an_error_points_at_the_players_file_and_line() -> void:
	var town := {
		"python":
		{
			"bakery": "def loaves_for(guests):\n    x = None\n    return x.count\n",
			"market":
			"from bakery import loaves_for\n\n\ndef bread_order(days):\n    return sum(loaves_for(d) for d in days)\n"
		},
		"javascript":
		{
			"bakery":
			(
				"function loavesFor(guests) {\n  const x = null;\n  return x.count;\n}\n"
				+ "module.exports.loavesFor = loavesFor;\n"
			),
			"market":
			(
				'const { loavesFor } = require("./bakery");\nfunction breadOrder(days) {\n'
				+ "  return days.map(loavesFor).length;\n}\nmodule.exports.breadOrder = breadOrder;\n"
			)
		},
	}
	for language in LANGUAGES:
		var cases := LanternRules.letter_cases(catalog, "bread-order", language)
		var report := LanternWatch.run(language, town[language], cases)
		var first: Dictionary = report.results[0]
		assert_str(first.status).is_equal("error")
		assert_str(first.file).override_failure_message(str(first)).is_equal(LanternCode.file_name("bakery", language))
		assert_int(first.line).is_equal(3)


func test_a_missing_function_and_a_syntax_error_are_named() -> void:
	for language in LANGUAGES:
		var cases := LanternRules.letter_cases(catalog, "postage", language)
		var missing := LanternWatch.run(language, {"post": ""}, cases)
		assert_str(missing.results[0].status).is_equal("missing")
		var broken_source := (
			"def postage(grams)\n    return 2\n" if language == "python" else "function postage(grams) {\n  return 2;\n"
		)
		var broken := LanternWatch.run(language, {"post": broken_source}, cases)
		assert_str(broken.results[0].status).is_equal("error")
		assert_str(broken.results[0].error).is_equal("SyntaxError")


func test_a_loop_that_never_ends_costs_only_its_own_letter() -> void:
	var loops := {
		"python": "def greeting(name):\n    while True:\n        pass\n",
		"javascript": "function greeting(name) { while (true) {} }\nmodule.exports.greeting = greeting;\n",
	}
	for language in LANGUAGES:
		var town := LanternReference.town(catalog, language, 5)
		town.files.post = (
			loops[language]
			+ ("\n\n\n" if language == "python" else "\n")
			+ String(catalog.requests.postage.solution[language])
		)
		var cases := LanternRules.night_cases(catalog, town)
		var statuses := _statuses(LanternWatch.run(language, town.files, cases))
		assert_str(statuses["greeting#e1"]).is_equal("timeout")
		assert_str(statuses["greeting#e2"]).is_equal("unreached")
		assert_str(statuses["postage#e1"]).is_equal("pass")
		assert_str(statuses["market-total#c1"]).is_equal("pass")
