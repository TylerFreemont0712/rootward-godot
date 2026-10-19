extends GdUnitTestSuite
## TaskRun and its harness (tasks.py, tasks.js): one job calls the player's function once per call, each call with its
## own function and copied arguments; a missing function is that call's problem; code that changes its argument and
## returns nothing answers with the argument (`mutates`); broken code and a loop that never ends are the run's.

const ADD_PY := """def add(bag, item):
    for stack in bag:
        if stack["item"] == item:
            stack["count"] += 1
            return
    bag.append({"item": item, "count": 1})
"""
const ADD_JS := """function add(bag, item) {
  for (const stack of bag) {
    if (stack.item === item) { stack.count += 1; return; }
  }
  bag.push({item: item, count: 1});
}
"""


func _call(entries: Array, args: Array, mutates := -1) -> Dictionary:
	return {"entries": entries, "signature": "%s(...)" % entries[0], "args": args, "mutates": mutates}


func test_each_call_gets_its_own_copy_and_whole_numbers_stay_whole() -> void:
	for language: String in ["python", "javascript"]:
		var source := "def f(n):\n    return [n, type(n).__name__]\n" if language == "python" else "function f(n) { return [n, typeof n]; }\n"
		var ran := TaskRun.run(language, source, [_call(["f"], [5]), _call(["f"], [2.5])])
		assert_str(String(ran.status)).is_equal("ok")
		assert_float(float(ran.results[0].value[0])).is_equal(5.0)
		if language == "python":
			assert_str(String(ran.results[0].value[1])).is_equal("int")
			assert_str(String(ran.results[1].value[1])).is_equal("float")


func test_mutates_takes_the_argument_when_nothing_is_given_back() -> void:
	for language: String in ["python", "javascript"]:
		var source := ADD_PY if language == "python" else ADD_JS
		var bag := [{"item": "apple", "count": 1}]
		var ran := TaskRun.run(language, source, [_call(["add"], [bag, "apple"], 0), _call(["add"], [bag, "pear"], 0)])
		assert_str(String(ran.status)).is_equal("ok")
		assert_bool(Tasks.same(ran.results[0].value, [{"item": "apple", "count": 2}])).override_failure_message(str(ran)).is_true()
		# The second call got the bag as it was given, not as the first call left it.
		assert_bool(Tasks.same(ran.results[1].value, [{"item": "apple", "count": 1}, {"item": "pear", "count": 1}])).is_true()
		assert_array(bag).contains_exactly([{"item": "apple", "count": 1}])


func test_a_missing_function_is_the_call_s_problem_and_broken_code_the_run_s() -> void:
	var ran := TaskRun.run("python", "def a():\n    return 1\n", [_call(["a"], []), _call(["b"], [])])
	assert_str(String(ran.status)).is_equal("ok")
	assert_bool(bool(ran.results[0].ok)).is_true()
	assert_str(String(ran.results[1].kind)).is_equal("missing")
	var js := TaskRun.run("javascript", "function a() { return 1; }", [_call(["b", "a"], [])])
	assert_float(float(js.results[0].value)).is_equal(1.0)
	var broken := TaskRun.run("python", "def a(:\n", [_call(["a"], [])])
	assert_str(String(broken.status)).is_equal("broken")
	assert_int(int(broken.line)).is_equal(1)


func test_an_error_names_its_line_and_a_loop_that_never_ends_times_out() -> void:
	var ran := TaskRun.run("python", "def f(n):\n    x = 1\n    return n / 0\n", [_call(["f"], [3])])
	assert_str(String(ran.results[0].kind)).is_equal("ZeroDivisionError")
	assert_int(int(ran.results[0].line)).is_equal(3)
	var forever := TaskRun.run("python", "def f():\n    while True:\n        pass\n", [_call(["f"], [])], 400)
	assert_str(String(forever.status)).is_equal("timeout")


func test_a_table_answers_every_argument_list_and_lists_the_calls_that_failed() -> void:
	var task := {"entry": {"python": "inv", "javascript": "inv"}, "params": [{"name": "n"}], "stages": [{"cases": [{"args": [1]}]}]}
	var table := TaskRun.table(task, 0, "python", "def inv(n):\n    return 10 // n\n", [[1], [0], [5]])
	assert_bool(bool(table.ok)).is_false()
	assert_array(table.values).contains_exactly([10.0, null, 2.0])
	assert_int(int(table.errors[0].index)).is_equal(1)
