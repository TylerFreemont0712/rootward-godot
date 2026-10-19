extends GdUnitTestSuite
## The tidy judge (task tidy, stage 2, Concept/v0.4/05 2.10): the right answers pass, each reason is given when it should
## be, every case gets its own verdict, and a live call (args only, no want) is judged the same way.


func _judge(bag: Array, answer: Variant) -> Dictionary:
	return TidyJudges.tidy_sorted([{"args": [bag]}], _results([answer]))[0]


## What the harness hands a judge: one {ok: true, value} per answer.
func _results(values: Array) -> Array:
	var out: Array = []
	for value: Variant in values:
		out.append({"ok": true, "value": value})
	return out


func _stack(item: String, count: Variant) -> Dictionary:
	return {"item": item, "count": count}


func _reason(verdict: Dictionary) -> String:
	return String(verdict.get("reason", ""))


func _assert_right(verdict: Dictionary) -> void:
	assert_bool(bool(verdict.get("ok", false))).is_true()
	assert_str(_reason(verdict)).is_equal("right")


func _assert_fails(verdict: Dictionary, reason: String) -> void:
	assert_bool(bool(verdict.get("ok", true))).is_false()
	assert_str(_reason(verdict)).is_equal(reason)


func test_right_answers_pass() -> void:
	var cases := [
		{"args": [[_stack("cabbage", 3), _stack("apple", 2), _stack("carrot", 1)]]},
		{"args": [[_stack("apple", 2), _stack("carrot", 1)]]},
		{"args": [[]]},
	]
	var answers := [
		[_stack("apple", 2), _stack("cabbage", 3), _stack("carrot", 1)],
		[_stack("apple", 2), _stack("carrot", 1)],
		[],
	]
	var verdicts := TidyJudges.tidy_sorted(cases, _results(answers))
	assert_int(verdicts.size()).is_equal(3)
	for verdict: Dictionary in verdicts:
		_assert_right(verdict)


func test_whole_counts_given_as_decimals_are_whole() -> void:
	# JSON gives every number as a float: 2.0 is a whole 2.
	_assert_right(_judge([_stack("pear", 2.0)], [_stack("pear", 2.0)]))


func test_not_list() -> void:
	_assert_fails(_judge([_stack("apple", 2)], null), "not-list")
	var verdict := _judge([_stack("apple", 2)], 3)
	_assert_fails(verdict, "not-list")
	assert_int(int(verdict.get("got", -1))).is_equal(3)


func test_not_stack_when_the_item_is_not_text() -> void:
	var verdict := _judge([_stack("apple", 2)], [_stack("apple", 2), {"item": 3, "count": 1}])
	_assert_fails(verdict, "not-stack")
	assert_int(int(verdict.get("index", -1))).is_equal(1)


func test_not_stack_when_the_count_is_not_whole_or_missing() -> void:
	_assert_fails(_judge([_stack("apple", 2)], [_stack("apple", 1.5)]), "not-stack")
	_assert_fails(_judge([_stack("apple", 2)], [_stack("apple", "2")]), "not-stack")
	_assert_fails(_judge([_stack("apple", 2)], [{"item": "apple"}]), "not-stack")
	_assert_fails(_judge([_stack("apple", 2)], ["apple"]), "not-stack")


func test_lost_when_a_stack_is_missing() -> void:
	var verdict := _judge([_stack("apple", 2), _stack("cabbage", 3)], [_stack("apple", 2)])
	_assert_fails(verdict, "lost")
	assert_str(String(verdict.get("name", ""))).is_equal("cabbage")
	assert_int(int(verdict.get("want", -1))).is_equal(3)
	assert_int(int(verdict.get("got", -1))).is_equal(0)


func test_lost_when_a_count_changed() -> void:
	var verdict := _judge([_stack("apple", 2)], [_stack("apple", 1)])
	_assert_fails(verdict, "lost")
	assert_str(String(verdict.get("name", ""))).is_equal("apple")
	assert_int(int(verdict.get("want", -1))).is_equal(2)
	assert_int(int(verdict.get("got", -1))).is_equal(1)


func test_lost_names_the_first_stack_of_the_bag_that_is_wrong() -> void:
	# The apple is missing and so is the cabbage's count, but the apple comes first in the bag.
	var verdict := _judge([_stack("apple", 2), _stack("cabbage", 3)], [_stack("cabbage", 1)])
	_assert_fails(verdict, "lost")
	assert_str(String(verdict.get("name", ""))).is_equal("apple")


func test_invented_when_an_extra_stack_is_there() -> void:
	var verdict := _judge([_stack("apple", 2)], [_stack("apple", 2), _stack("pear", 1)])
	_assert_fails(verdict, "invented")
	assert_str(String(verdict.get("name", ""))).is_equal("pear")
	assert_int(int(verdict.get("got", -1))).is_equal(1)


func test_not_sorted_when_a_stack_comes_before_one_it_should_follow() -> void:
	var verdict := _judge([_stack("cabbage", 3), _stack("apple", 2)], [_stack("cabbage", 3), _stack("apple", 2)])
	_assert_fails(verdict, "not-sorted")
	assert_str(String(verdict.get("name", ""))).is_equal("apple")
	assert_int(int(verdict.get("index", -1))).is_equal(1)


func test_each_case_gets_its_own_verdict() -> void:
	var cases := [{"args": [[_stack("cabbage", 3), _stack("apple", 2)]]}, {"args": [[_stack("apple", 2)]]}]
	var verdicts := TidyJudges.tidy_sorted(cases, _results([[_stack("apple", 2), _stack("cabbage", 3)], []]))
	_assert_right(verdicts[0])
	_assert_fails(verdicts[1], "lost")


func test_a_case_with_no_bag_is_judged_against_an_empty_bag() -> void:
	_assert_right(TidyJudges.tidy_sorted([{}], _results([[]]))[0])
	_assert_fails(TidyJudges.tidy_sorted([{}], _results([[_stack("apple", 1)]]))[0], "invented")
