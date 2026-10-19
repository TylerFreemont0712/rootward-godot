extends GdUnitTestSuite
## Brannoc's forge judge (forge_pure, Concept/v0.4/05, 2.5): each reason it gives, and the answers that pass.


## Three cases, as a stage gives them: two orders of one pair, and the edge of no materials at all.
func cases() -> Array:
	return [
		{"args": [["iron", "wood"]], "want": "hammer", "say": "iron and wood"},
		{"args": [["wood", "iron"]], "want": "hammer", "say": "wood and iron, the other way round"},
		{"args": [[]], "want": "nothing", "say": "no materials at all", "edge": true},
	]


## One result, the way a run gives it: the answer, and the arguments as the function left them.
func run_of(value: Variant, left_as: Variant) -> Dictionary:
	return {"ok": true, "value": value, "args_after": left_as}


func reason_at(verdicts: Array, index: int) -> String:
	return String((verdicts[index] as Dictionary).get("reason", ""))


func all_right(verdicts: Array) -> bool:
	for verdict: Variant in verdicts:
		if not bool((verdict as Dictionary).get("ok", false)):
			return false
	return true


func test_right_answers_that_leave_the_list_as_it_was_pass() -> void:
	var results := [
		run_of("hammer", [["iron", "wood"]]),
		run_of("hammer", [["wood", "iron"]]),
		run_of("nothing", [[]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_int(verdicts.size()).is_equal(3)
	assert_bool(all_right(verdicts)).is_true()


func test_a_sort_in_place_is_changed_input() -> void:
	# list.sort() gives the right tool, but it puts the list the forge was given in order: that is the changed input.
	var results := [
		run_of("hammer", [["iron", "wood"]]),
		run_of("hammer", [["iron", "wood"]]),
		run_of("nothing", [[]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_str(reason_at(verdicts, 1)).is_equal("changed-input")
	assert_bool(bool((verdicts[1] as Dictionary).get("ok", true))).is_false()
	assert_str(String((verdicts[1] as Dictionary).get("got"))).is_equal("hammer")
	# The same list (already in order) is not a change, and the others pass.
	assert_bool(bool((verdicts[0] as Dictionary).get("ok", false))).is_true()
	assert_bool(bool((verdicts[2] as Dictionary).get("ok", false))).is_true()


func test_a_wrong_answer_is_wrong_with_what_it_should_be() -> void:
	var results := [
		run_of("gear", [["iron", "wood"]]),
		run_of("hammer", [["wood", "iron"]]),
		run_of("nothing", [[]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_str(reason_at(verdicts, 0)).is_equal("wrong")
	assert_str(String((verdicts[0] as Dictionary).get("want"))).is_equal("hammer")
	assert_str(String((verdicts[0] as Dictionary).get("got"))).is_equal("gear")


func test_a_wrong_answer_is_judged_before_a_changed_list() -> void:
	# Both faults: the answer is wrong and the list was changed. The answer is what the player hears about first.
	var results := [
		run_of("gear", [["iron", "wood"]]),
		run_of("gear", [["iron", "wood"]]),
		run_of("nothing", [[]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_str(reason_at(verdicts, 1)).is_equal("wrong")


func test_no_answer_at_all_is_nothing() -> void:
	var results := [
		run_of(null, [["iron", "wood"]]),
		run_of("hammer", [["wood", "iron"]]),
		run_of("nothing", [[]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_str(reason_at(verdicts, 0)).is_equal("nothing")


func test_an_answer_of_the_wrong_kind_is_wrong_type() -> void:
	var results := [
		run_of(3, [["iron", "wood"]]),
		run_of("hammer", [["wood", "iron"]]),
		run_of("nothing", [[]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_str(reason_at(verdicts, 0)).is_equal("wrong-type")


func test_a_run_that_does_not_say_what_the_list_became_is_not_checked() -> void:
	# A stage with "args_after" always gets the arguments back. Without them the purity cannot be seen, so it says so.
	var results := [
		{"ok": true, "value": "hammer"},
		run_of("hammer", [["wood", "iron"]]),
		run_of("nothing", [[]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_str(reason_at(verdicts, 0)).is_equal("not-checked")


func test_an_empty_list_left_empty_passes_the_edge() -> void:
	var verdicts := ForgeJudges.forge_pure([{"args": [[]], "want": "nothing", "say": "no materials", "edge": true}], [run_of("nothing", [[]])])
	assert_bool(all_right(verdicts)).is_true()


func test_one_verdict_per_case() -> void:
	var results := [
		run_of("hammer", [["iron", "wood"]]),
		run_of("gear", [["wood", "iron"]]),
	]
	var verdicts := ForgeJudges.forge_pure(cases(), results)
	assert_int(verdicts.size()).is_equal(3)
	assert_str(reason_at(verdicts, 2)).is_equal("nothing")
