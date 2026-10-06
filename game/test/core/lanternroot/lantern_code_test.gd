extends GdUnitTestSuite
## What Lanternroot reads from source without running it: imports between the player's modules, defined functions,
## and JavaScript's spelling of a name. Advice for failed tests is checked here too.


func test_python_imports_of_the_players_own_modules_become_bridges() -> void:
	var source := "import math\nfrom bakery import loaves_for\nimport lamps, post as p\n# from mill import x\n"
	var found := LanternCode.imports("python", source, ["bakery", "lamps", "post", "mill", "market"], "market")
	assert_array(found).contains_exactly(["bakery", "lamps", "post"])


func test_javascript_requires_of_relative_files_become_bridges() -> void:
	var source := 'const { loavesFor } = require("./bakery");\nconst fs = require("fs");\nrequire(\'./lamps.js\');\n'
	assert_array(LanternCode.imports("javascript", source, ["bakery", "lamps"])).contains_exactly(["bakery", "lamps"])


func test_a_module_never_bridges_to_itself() -> void:
	assert_array(LanternCode.imports("python", "from bakery import x", ["bakery"], "bakery")).is_empty()


func test_defined_functions_are_found_in_both_languages() -> void:
	assert_bool(LanternCode.defines("python", "x = 1\n\ndef total(prices):\n    pass\n", "total")).is_true()
	assert_bool(LanternCode.defines("python", "def totals(p):\n    pass\n", "total")).is_false()
	assert_bool(LanternCode.defines("javascript", "function total(p) {}", "total")).is_true()
	assert_bool(LanternCode.defines("javascript", "const total = (p) => 0;", "total")).is_true()


func test_snake_case_becomes_camel_case_for_javascript() -> void:
	assert_str(LanternCode.camel("loaves_for")).is_equal("loavesFor")
	assert_str(LanternCode.camel("guests_by_day")).is_equal("guestsByDay")
	assert_str(LanternCode.camel("total")).is_equal("total")


func test_a_starter_is_appended_with_each_languages_spacing() -> void:
	assert_str(LanternCode.append("python", "def a():\n    pass\n\n", "def b():")).is_equal(
		"def a():\n    pass\n\n\ndef b():"
	)
	assert_str(LanternCode.append("javascript", "", "function b() {}")).is_equal("function b() {}")


func test_advice_points_at_the_usual_mistakes() -> void:
	var printed := {"status": "fail", "actual": "None", "expected": "6", "printed": "6\n"}
	assert_str(LanternAdvice.nudge(printed, "python")).contains("printed")
	assert_str(LanternAdvice.nudge({"status": "fail", "actual": "2", "expected": "3"}, "python")).contains("Off by one")
	assert_str(LanternAdvice.nudge({"status": "fail", "actual": "2.25", "expected": "3"}, "python")).contains(
		"fraction"
	)
	assert_str(LanternAdvice.nudge({"status": "error", "error": "NameError"}, "python")).contains("not defined")
	assert_str(LanternAdvice.nudge({"status": "timeout"}, "javascript")).contains("never finished")
	assert_str(LanternAdvice.nudge({"status": "pass"}, "python")).is_empty()
