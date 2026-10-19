extends GdUnitTestSuite
## Brisk's drills judge (task drills, Concept/v0.4/05, 2.3): the right drills pass for each of the three functions, each
## reason is given when it should be, a drill that catches the bug is enough, and the judge gives one verdict per case
## through TaskJudges.judge.


func _reason(verdict: Dictionary) -> String:
	return String(verdict.get("reason", ""))


func _assert_right(verdict: Dictionary) -> void:
	assert_bool(bool(verdict.get("ok", false))).is_true()
	assert_str(_reason(verdict)).is_equal("right")


func _assert_fails(verdict: Dictionary, reason: String) -> void:
	assert_bool(bool(verdict.get("ok", true))).is_false()
	assert_str(_reason(verdict)).is_equal(reason)


# --- the right drills pass -----------------------------------------------------------------------------------------


func test_right_double_drills_pass() -> void:
	_assert_right(DrillsJudges.judge_one("double", [[3, 6], [0, 0]]))


func test_right_total_drills_pass() -> void:
	_assert_right(DrillsJudges.judge_one("total", [[[1, 2, 3], 6], [[5], 5]]))


func test_right_first_drills_pass() -> void:
	_assert_right(DrillsJudges.judge_one("first", [[[7, 8], 7], [[], null]]))


func test_one_catching_drill_is_enough() -> void:
	# [2, 4] is right, but Brisk's double gives 4 for 2 too, so it does not catch the bug. [3, 6] does.
	_assert_right(DrillsJudges.judge_one("double", [[2, 4], [3, 6]]))


func test_ten_drills_are_the_most() -> void:
	var ten: Array = []
	for n in 10:
		ten.append([n + 3, (n + 3) * 2])
	_assert_right(DrillsJudges.judge_one("double", ten))


func test_a_crash_on_an_empty_list_catches_the_first_bug() -> void:
	# Brisk's first crashes on []. The right answer is null, so the drill passes and catches it.
	_assert_right(DrillsJudges.judge_one("first", [[[], null]]))


func test_total_catches_by_leaving_out_the_last_number() -> void:
	# [5] alone: Brisk's total gives 0 for it, not 5.
	_assert_right(DrillsJudges.judge_one("total", [[[5], 5]]))


# --- not-list ------------------------------------------------------------------------------------------------------


func test_not_list_when_nothing_is_given() -> void:
	var verdict := DrillsJudges.judge_one("double", null)
	_assert_fails(verdict, "not-list")
	assert_str(String(verdict.name)).is_equal("double")


func test_not_list_when_a_single_number_is_given() -> void:
	_assert_fails(DrillsJudges.judge_one("total", 6), "not-list")


# --- count ---------------------------------------------------------------------------------------------------------


func test_count_when_the_list_is_empty() -> void:
	var verdict := DrillsJudges.judge_one("first", [])
	_assert_fails(verdict, "count")
	assert_int(int(verdict.got)).is_equal(0)


func test_count_when_there_are_more_than_ten() -> void:
	var eleven: Array = []
	for n in 11:
		eleven.append([n + 3, (n + 3) * 2])
	var verdict := DrillsJudges.judge_one("double", eleven)
	_assert_fails(verdict, "count")
	assert_int(int(verdict.got)).is_equal(11)


# --- not-drill -----------------------------------------------------------------------------------------------------


func test_not_drill_when_a_drill_is_not_a_pair() -> void:
	var verdict := DrillsJudges.judge_one("double", [[3, 6], [3]])
	_assert_fails(verdict, "not-drill")
	assert_int(int(verdict.index)).is_equal(1)


func test_not_drill_when_a_drill_is_a_number() -> void:
	_assert_fails(DrillsJudges.judge_one("double", [6]), "not-drill")


func test_not_drill_when_double_is_given_text() -> void:
	# double takes a whole number, so a drill with a word for an input is not a proper drill.
	_assert_fails(DrillsJudges.judge_one("double", [["three", 6]]), "not-drill")


func test_not_drill_when_total_is_given_a_number_not_a_list() -> void:
	_assert_fails(DrillsJudges.judge_one("total", [[5, 5]]), "not-drill")


func test_not_drill_when_total_has_a_word_in_its_list() -> void:
	_assert_fails(DrillsJudges.judge_one("total", [[["a", 2], 2]]), "not-drill")


# --- wrong-expect --------------------------------------------------------------------------------------------------


func test_wrong_expect_double_gives_the_right_answer_and_the_input() -> void:
	var verdict := DrillsJudges.judge_one("double", [[3, 5]])
	_assert_fails(verdict, "wrong-expect")
	assert_int(int(verdict.index)).is_equal(0)
	assert_float(float(verdict.want)).is_equal(6.0)
	assert_float(float(verdict.got)).is_equal(5.0)
	assert_float(float((verdict.args as Array)[0])).is_equal(3.0)


func test_wrong_expect_total_gives_the_right_sum() -> void:
	var verdict := DrillsJudges.judge_one("total", [[[1, 2, 3], 5]])
	_assert_fails(verdict, "wrong-expect")
	assert_float(float(verdict.want)).is_equal(6.0)


func test_wrong_expect_first_gives_the_right_item() -> void:
	var verdict := DrillsJudges.judge_one("first", [[[7, 8], 8]])
	_assert_fails(verdict, "wrong-expect")
	assert_float(float(verdict.want)).is_equal(7.0)


func test_wrong_expect_first_on_an_empty_list_wants_nothing() -> void:
	var verdict := DrillsJudges.judge_one("first", [[[], 0]])
	_assert_fails(verdict, "wrong-expect")
	assert_bool(verdict.want == null).is_true()


func test_wrong_expect_names_the_first_wrong_drill() -> void:
	var verdict := DrillsJudges.judge_one("double", [[3, 6], [4, 7]])
	_assert_fails(verdict, "wrong-expect")
	assert_int(int(verdict.index)).is_equal(1)
	assert_float(float(verdict.want)).is_equal(8.0)


# --- no-catch ------------------------------------------------------------------------------------------------------


func test_no_catch_when_every_drill_passes_the_bug_too() -> void:
	# 2 gives 4 both ways for double: no drill with only 2 catches Brisk's bug.
	var verdict := DrillsJudges.judge_one("double", [[2, 4]])
	_assert_fails(verdict, "no-catch")
	assert_str(String(verdict.name)).is_equal("double")


func test_no_catch_for_total_on_an_empty_list() -> void:
	# Brisk's total gives 0 for [] too, so nothing catches him.
	_assert_fails(DrillsJudges.judge_one("total", [[[], 0]]), "no-catch")


func test_no_catch_for_first_on_a_list_with_an_item() -> void:
	_assert_fails(DrillsJudges.judge_one("first", [[[7, 8], 7]]), "no-catch")


# --- the reasons' order and unknown names --------------------------------------------------------------------------


func test_not_drill_is_found_before_a_wrong_expect() -> void:
	var verdict := DrillsJudges.judge_one("double", [[3, 5], [4]])
	_assert_fails(verdict, "not-drill")


func test_an_unknown_function_fails() -> void:
	_assert_fails(DrillsJudges.judge_one("halve", [[3, 6]]), "unknown-function")


# --- through the dispatch, one verdict per case --------------------------------------------------------------------


func test_drills_gives_one_verdict_per_case() -> void:
	var cases := [
		{"args": [], "function": "double"},
		{"args": [], "function": "first"},
	]
	var results := [
		{"ok": true, "value": [[3, 6]]},
		{"ok": true, "value": [[[7, 8], 8]]},
	]
	var verdicts := TaskJudges.judge("drills", cases, results)
	assert_int(verdicts.size()).is_equal(2)
	_assert_right(verdicts[0])
	_assert_fails(verdicts[1], "wrong-expect")


func test_a_failed_call_is_not_a_list() -> void:
	var verdicts := TaskJudges.judge("drills", [{"args": [], "function": "total"}], [{"ok": false, "kind": "missing"}])
	_assert_fails(verdicts[0], "not-list")
