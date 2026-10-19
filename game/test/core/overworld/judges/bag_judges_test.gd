extends GdUnitTestSuite
## The bag's judges (task bag, Concept/v0.4/01 5.6): the right answers pass, each reason of add and of remove is given
## when it should be, a judge gives its verdict per case, and the live calls Bag.valid_add and Bag.valid_remove are
## judged the same way with no `want`.


func _add(before: Array, item: String, after: Variant) -> Dictionary:
	return BagJudges.bag_add([{"args": [before, item]}], _results([after]))[0]


func _remove(before: Array, item: String, after: Variant) -> Dictionary:
	return BagJudges.bag_remove([{"args": [before, item]}], _results([after]))[0]


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


# --- add -----------------------------------------------------------------------------------------------------------


func test_add_right_answers_pass() -> void:
	var cases := [
		{"args": [[], "apple"]},
		{"args": [[_stack("apple", 1)], "apple"]},
		{"args": [[_stack("apple", 2)], "cabbage"]},
		{"args": [[_stack("apple", 1), _stack("cabbage", 2), _stack("carrot", 1)], "cabbage"]},
	]
	var answers := [
		[_stack("apple", 1)],
		[_stack("apple", 2)],
		[_stack("apple", 2), _stack("cabbage", 1)],
		[_stack("apple", 1), _stack("cabbage", 3), _stack("carrot", 1)],
	]
	var verdicts := BagJudges.bag_add(cases, _results(answers))
	assert_int(verdicts.size()).is_equal(4)
	for verdict: Dictionary in verdicts:
		_assert_right(verdict)


func test_add_whole_counts_given_as_decimals_are_whole() -> void:
	# JSON gives every number as a float: 2.0 is a whole 2.
	_assert_right(_add([_stack("apple", 1.0)], "apple", [_stack("apple", 2.0)]))


func test_add_not_list() -> void:
	_assert_fails(_add([], "apple", "apple"), "not-list")
	_assert_fails(_add([], "apple", null), "not-list")


func test_add_not_stack_when_the_item_is_not_text() -> void:
	var verdict := _add([], "apple", [{"item": 3, "count": 1}])
	_assert_fails(verdict, "not-stack")
	assert_int(int(verdict.get("index", -1))).is_equal(0)


func test_add_not_stack_when_the_count_is_not_whole() -> void:
	_assert_fails(_add([], "apple", [_stack("apple", 1.5)]), "not-stack")
	_assert_fails(_add([], "apple", [_stack("apple", "1")]), "not-stack")
	_assert_fails(_add([], "apple", [{"item": "apple"}]), "not-stack")


func test_add_bad_count_below_one() -> void:
	var verdict := _add([], "apple", [_stack("apple", 0)])
	_assert_fails(verdict, "bad-count")
	assert_str(String(verdict.get("name", ""))).is_equal("apple")
	assert_int(int(verdict.get("got", 9))).is_equal(0)


func test_add_two_stacks_of_one_item() -> void:
	var verdict := _add([_stack("apple", 1)], "apple", [_stack("apple", 1), _stack("apple", 1)])
	_assert_fails(verdict, "two-stacks")
	assert_str(String(verdict.get("name", ""))).is_equal("apple")


func test_add_no_more_when_the_total_did_not_go_up_by_one() -> void:
	var nothing := _add([], "apple", [])
	_assert_fails(nothing, "no-more")
	assert_int(int(nothing.get("want", -1))).is_equal(1)
	assert_int(int(nothing.get("got", -1))).is_equal(0)
	var two_more := _add([_stack("apple", 1)], "apple", [_stack("apple", 3)])
	_assert_fails(two_more, "no-more")
	assert_int(int(two_more.get("want", -1))).is_equal(2)
	assert_int(int(two_more.get("got", -1))).is_equal(3)


func test_add_changed_other_when_another_count_changed() -> void:
	var verdict := _add([_stack("cabbage", 2)], "apple", [_stack("cabbage", 1), _stack("apple", 1)])
	_assert_fails(verdict, "changed-other")
	assert_str(String(verdict.get("name", ""))).is_equal("cabbage")
	assert_int(int(verdict.get("want", -1))).is_equal(2)
	assert_int(int(verdict.get("got", -1))).is_equal(1)


func test_add_changed_other_when_another_stack_went_missing() -> void:
	var verdict := _add([_stack("apple", 1), _stack("cabbage", 3)], "apple", [_stack("apple", 2)])
	_assert_fails(verdict, "changed-other")
	assert_str(String(verdict.get("name", ""))).is_equal("cabbage")
	assert_int(int(verdict.get("got", -1))).is_equal(0)


func test_add_gives_each_case_its_own_verdict() -> void:
	var cases := [{"args": [[], "apple"]}, {"args": [[], "apple"]}]
	var verdicts := BagJudges.bag_add(cases, _results([[_stack("apple", 1)], []]))
	_assert_right(verdicts[0])
	_assert_fails(verdicts[1], "no-more")


# --- remove --------------------------------------------------------------------------------------------------------


func test_remove_right_answers_pass() -> void:
	var cases := [
		{"args": [[_stack("cabbage", 3)], "cabbage"]},
		{"args": [[_stack("cabbage", 1), _stack("apple", 2)], "cabbage"]},
		{"args": [[_stack("apple", 2)], "pumpkin"]},
		{"args": [[], "apple"]},
	]
	var answers := [
		[_stack("cabbage", 2)],
		[_stack("apple", 2)],
		[_stack("apple", 2)],
		[],
	]
	var verdicts := BagJudges.bag_remove(cases, _results(answers))
	assert_int(verdicts.size()).is_equal(4)
	for verdict: Dictionary in verdicts:
		_assert_right(verdict)


func test_remove_not_list() -> void:
	_assert_fails(_remove([_stack("cabbage", 3)], "cabbage", "cabbage"), "not-list")


func test_remove_not_stack() -> void:
	var verdict := _remove([_stack("cabbage", 3)], "cabbage", [{"item": "cabbage"}])
	_assert_fails(verdict, "not-stack")
	assert_int(int(verdict.get("index", -1))).is_equal(0)


func test_remove_zero_stack_left_at_zero_or_below() -> void:
	var at_zero := _remove([_stack("cabbage", 1)], "cabbage", [_stack("cabbage", 0)])
	_assert_fails(at_zero, "zero-stack")
	assert_str(String(at_zero.get("name", ""))).is_equal("cabbage")
	_assert_fails(_remove([_stack("cabbage", 0)], "cabbage", [_stack("cabbage", -1)]), "zero-stack")


func test_remove_no_less_when_the_total_did_not_go_down_by_one() -> void:
	var same := _remove([_stack("cabbage", 3)], "cabbage", [_stack("cabbage", 3)])
	_assert_fails(same, "no-less")
	assert_int(int(same.get("want", -1))).is_equal(2)
	assert_int(int(same.get("got", -1))).is_equal(3)
	var gone := _remove([_stack("cabbage", 3)], "cabbage", [])
	_assert_fails(gone, "no-less")
	assert_int(int(gone.get("got", -1))).is_equal(0)


func test_remove_changed_other_when_another_count_changed() -> void:
	var verdict := _remove(
		[_stack("cabbage", 3), _stack("apple", 2)],
		"cabbage",
		[_stack("cabbage", 2), _stack("apple", 1)]
	)
	_assert_fails(verdict, "changed-other")
	assert_str(String(verdict.get("name", ""))).is_equal("apple")
	assert_int(int(verdict.get("want", -1))).is_equal(2)
	assert_int(int(verdict.get("got", -1))).is_equal(1)


func test_remove_invented_when_the_item_was_not_there_and_now_is() -> void:
	var verdict := _remove([_stack("apple", 2)], "pumpkin", [_stack("apple", 2), _stack("pumpkin", 1)])
	_assert_fails(verdict, "invented")
	assert_str(String(verdict.get("name", ""))).is_equal("pumpkin")
	assert_int(int(verdict.get("want", -1))).is_equal(0)
	assert_int(int(verdict.get("got", -1))).is_equal(1)


func test_remove_invented_when_the_bag_changed_for_a_missing_item() -> void:
	var verdict := _remove([_stack("apple", 2)], "pumpkin", [_stack("apple", 1)])
	_assert_fails(verdict, "invented")
	assert_str(String(verdict.get("name", ""))).is_equal("apple")


func test_remove_edges_that_leave_the_bag_alone_pass() -> void:
	_assert_right(_remove([_stack("apple", 2)], "pumpkin", [_stack("apple", 2)]))
	_assert_right(_remove([], "apple", []))


# --- the live calls -------------------------------------------------------------------------------------------------


func test_live_add_and_remove_are_judged_without_a_want() -> void:
	var good_add := Bag.valid_add([], [_stack("apple", 1)], "apple")
	_assert_right(good_add)
	var bad_add := Bag.valid_add([], [_stack("apple", 2)], "apple")
	_assert_fails(bad_add, "no-more")
	var good_remove := Bag.valid_remove([_stack("cabbage", 3)], [_stack("cabbage", 2)], "cabbage")
	_assert_right(good_remove)
	var bad_remove := Bag.valid_remove([_stack("cabbage", 3)], [_stack("cabbage", 3)], "cabbage")
	_assert_fails(bad_remove, "no-less")
