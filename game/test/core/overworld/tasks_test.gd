extends GdUnitTestSuite
## Tasks, the parts' pure rules (Concept/v0.4/02): stages and their calls, a check judged stage by stage, the advice,
## the source a Builder's blocks make, and comparing and showing answers.

const TASK := {
	"id": "demo",
	"entry": {"python": "double", "javascript": "double"},
	"params": [{"name": "n", "meaning": "a number"}],
	"blocks": {
		"lines": {
			"python": ["def double(n):", "[times]    n = n {op} {by}", "    return n"],
			"javascript": ["function double(n) {", "[times]  n = n {op} {by};", "  return n;", "}"],
		},
		"slots": {"op": {"choices": ["+", "*"]}, "by": {"choices": ["1", "2"], "stage": 1}},
		"toggles": {"times": {"label": "Change n"}},
		"start": {"slots": {"op": 0}, "toggles": []},
	},
	"stages": [
		{"flag": "doubled", "cases": [{"args": [2], "want": 4, "say": "two"}, {"args": [0], "want": 0, "edge": true}]},
		{
			"flag": "halved",
			"unlocked_by": {"flag": "doubled"},
			"entry": {"python": "half", "javascript": "half"},
			"params": [{"name": "m", "meaning": "a number"}],
			"cases": [{"args": [4], "want": 2}],
		},
	],
	"advice": {"wrong": "{say}: gave {got}, wanted {want}."},
}


func _ok(values: Array) -> Dictionary:
	var results: Array = []
	for value: Variant in values:
		results.append({"ok": true, "value": value})
	return {"status": "ok", "results": results}


func test_a_stage_check_runs_every_case_up_to_it_with_each_stage_s_function() -> void:
	var calls := Tasks.check_calls(TASK, 1, "javascript")
	assert_int(calls.size()).is_equal(3)
	assert_array(calls[0].entries).contains_exactly(["double"])
	assert_array(calls[2].entries).contains_exactly(["half"])
	assert_str(String(calls[2].signature)).is_equal("half(m)")
	assert_str(Tasks.signature(TASK, 0, "python")).is_equal("double(n)")


func test_a_check_judges_each_stage_and_says_which_passed() -> void:
	var checked := Tasks.check(TASK, 1, _ok([4, 0, 3]))
	assert_bool(bool(checked.ok)).is_false()
	assert_array(checked.stage_ok).contains_exactly([true, false])
	assert_str(String(checked.cases[2].reason)).is_equal("wrong")
	assert_bool(bool(Tasks.check(TASK, 1, _ok([4, 0.0, 2.0])).ok)).is_true()


func test_a_failed_call_is_an_error_or_missing_and_a_broken_run_is_a_problem() -> void:
	var run := {"status": "ok", "results": [
		{"ok": false, "kind": "ZeroDivisionError", "message": "x", "line": 3},
		{"ok": true, "value": 0},
		{"ok": false, "kind": "missing", "message": "there is no function half(m)"},
	]}
	var checked := Tasks.check(TASK, 1, run)
	assert_str(String(checked.cases[0].reason)).is_equal("error")
	assert_int(int(checked.cases[0].line)).is_equal(3)
	assert_str(String(checked.cases[2].reason)).is_equal("no-function")
	var broken := Tasks.check(TASK, 0, {"status": "broken", "kind": "SyntaxError", "message": "bad", "line": 1})
	assert_str(String(broken.problem.reason)).is_equal("broken")
	assert_str(String(Tasks.advice(TASK, 0, broken).reason)).is_equal("broken")


func test_advice_fills_the_task_s_words_and_names_an_edge() -> void:
	var said := Tasks.advice(TASK, 0, Tasks.check(TASK, 0, _ok([5, 0])), "python")
	assert_str(String(said.reason)).is_equal("wrong")
	assert_str(String(said.text)).is_equal("two: gave 5, wanted 4.")
	var edge := Tasks.advice(TASK, 0, Tasks.check(TASK, 0, _ok([4, 1])))
	assert_str(String(edge.reason)).is_equal("edge")
	assert_str(String(Tasks.advice(TASK, 0, Tasks.check(TASK, 0, _ok([4, 0]))).reason)).is_equal("passed")


func test_blocks_make_the_code_their_switches_and_choices_say() -> void:
	var fresh := Tasks.fresh_blocks(TASK)
	assert_str(Tasks.source(TASK, fresh, "python")).is_equal("def double(n):\n    return n\n")
	var on := {"slots": {"op": 1, "by": 1}, "toggles": ["times"]}
	assert_str(Tasks.source(TASK, on, "python")).is_equal("def double(n):\n    n = n * 2\n    return n\n")
	assert_str(Tasks.source(TASK, on, "javascript")).is_equal("function double(n) {\n  n = n * 2;\n  return n;\n}\n")
	assert_bool(Tasks.shows_at(TASK.blocks.slots.by, 0)).is_false()
	assert_bool(Tasks.shows_at(TASK.blocks.slots.by, 1)).is_true()


func test_a_choice_may_differ_by_language() -> void:
	var slot := {"choices": [{"label": "nothing", "python": "None", "javascript": "null"}, "\"menu\""]}
	assert_str(Tasks.choice_code(slot, 0, "python")).is_equal("None")
	assert_str(Tasks.choice_code(slot, 0, "javascript")).is_equal("null")
	assert_str(Tasks.choice_label(slot, 0, "python")).is_equal("nothing")
	assert_str(Tasks.choice_label(slot, 1, "javascript")).is_equal("\"menu\"")


func test_the_editor_opens_on_the_first_unpassed_unlocked_stage() -> void:
	assert_int(Tasks.open_stage(TASK, {}, {})).is_equal(0)
	assert_int(Tasks.open_stage(TASK, {"passed": 1}, {})).is_equal(0)
	assert_int(Tasks.open_stage(TASK, {"passed": 1}, {"doubled": true})).is_equal(1)
	assert_int(Tasks.open_stage(TASK, {"passed": 2}, {"doubled": true})).is_equal(1)


func test_answers_compare_as_values_and_show_as_the_language_writes_them() -> void:
	assert_bool(Tasks.same(5, 5.0)).is_true()
	assert_bool(Tasks.same([{"a": 1}], [{"a": 1.0}])).is_true()
	assert_bool(Tasks.same({"a": 1}, {"a": 1, "b": 2})).is_false()
	assert_bool(Tasks.same("1", 1)).is_false()
	assert_str(Tasks.shown(null, "python")).is_equal("None")
	assert_str(Tasks.shown(true, "javascript")).is_equal("true")
	assert_str(Tasks.shown([1.0, "a"], "python")).is_equal('[1, "a"]')
	assert_str(Tasks.shown({"item": "apple"}, "javascript")).is_equal('{item: "apple"}')


func test_content_problems_name_a_missing_toggle_and_a_bad_start() -> void:
	var bad := TASK.duplicate(true)
	bad.blocks.lines.python.append("[ghost]    pass")
	bad.blocks.start.slots.op = 9
	bad.stages[0].judge = "nobody"
	var found := Tasks.problems(bad)
	assert_bool(found.any(func(p: String) -> bool: return p.contains("ghost"))).is_true()
	assert_bool(found.any(func(p: String) -> bool: return p.contains("out of range"))).is_true()
	assert_bool(found.any(func(p: String) -> bool: return p.contains("nobody"))).is_true()
	assert_array(Tasks.problems(TASK)).is_empty()


func test_the_equals_judge_says_how_an_answer_is_wrong() -> void:
	assert_str(String(TaskJudges.equals_one({"want": [1, 2]}, [1, 3]).reason)).is_equal("wrong-item")
	assert_str(String(TaskJudges.equals_one({"want": [1, 2]}, [1]).reason)).is_equal("wrong-length")
	assert_str(String(TaskJudges.equals_one({"want": "a"}, null).reason)).is_equal("nothing")
	assert_str(String(TaskJudges.equals_one({"want": "a"}, 1).reason)).is_equal("wrong-type")
	assert_str(String(TaskJudges.equals_one({"any": [66, 67]}, 65).reason)).is_equal("not-any")
	assert_bool(bool(TaskJudges.equals_one({"any": [66, 67]}, 67.0).ok)).is_true()
	assert_bool(bool(TaskJudges.equals_one({}, "anything").ok)).is_true()


func test_the_shortcut_judge_knows_the_panels() -> void:
	var cases := [{"args": ["escape"], "want": "menu"}, {"args": ["p"]}, {"args": ["q"]}]
	var verdicts := TaskJudges.shortcut(cases, [{"ok": true, "value": "menu"}, {"ok": true, "value": "bagg"}, {"ok": true, "value": null}])
	assert_bool(bool(verdicts[0].ok)).is_true()
	assert_str(String(verdicts[1].reason)).is_equal("unknown-panel")
	assert_bool(bool(verdicts[2].ok)).is_true()
	var none := TaskJudges.shortcut([cases[0]], [{"ok": true, "value": ""}])
	assert_str(String(none[0].reason)).is_equal("nothing")
