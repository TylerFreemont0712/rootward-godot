extends GdUnitTestSuite
## Hotaru's glow judge (task glow, Concept/v0.4/05, 2.2): glow_pattern. Each reason it gives, and the answers that pass.


## The sixty seconds, each a case with its words, as the glow task has them.
func second_cases() -> Array:
	var cases: Array = []
	for second in range(60):
		cases.append({"args": [second], "say": "second %d" % second})
	return cases


## A blink: even seconds dark, odd seconds bright, the way `t % 2` gives them.
func blinking() -> Array:
	var values: Array = []
	for second in range(60):
		values.append(second % 2)
	return values


## One result per answer, the way a run gives them (ok, with its value).
func answers(values: Array) -> Array:
	var results: Array = []
	for value: Variant in values:
		results.append({"ok": true, "value": value})
	return results


func reason_at(verdicts: Array, index: int) -> String:
	return String((verdicts[index] as Dictionary).get("reason", ""))


func all_right(verdicts: Array) -> bool:
	for verdict: Variant in verdicts:
		if not bool((verdict as Dictionary).get("ok", false)):
			return false
	return true


func test_glow_pattern_passes_a_blink() -> void:
	assert_bool(all_right(GlowJudges.glow_pattern(second_cases(), answers(blinking())))).is_true()
	# Dim at 0.3 and bright at 0.7 are the edges, and both count.
	var soft: Array = []
	for second in range(60):
		soft.append(0.3 if second % 2 == 0 else 0.7)
	assert_bool(all_right(GlowJudges.glow_pattern(second_cases(), answers(soft)))).is_true()


func test_glow_pattern_passes_a_blink_with_more_than_two_levels() -> void:
	var values: Array = []
	for second in range(60):
		values.append(float(second % 4) / 3.0)
	assert_bool(all_right(GlowJudges.glow_pattern(second_cases(), answers(values)))).is_true()


func test_glow_pattern_gives_not_number_on_the_first_answer_that_is_not_a_number() -> void:
	var values := blinking()
	values[5] = "bright"
	values[3] = null
	var verdicts := GlowJudges.glow_pattern(second_cases(), answers(values))
	# The first one, at second 3, is the one that shows the problem; the later one gets its own ok.
	assert_str(reason_at(verdicts, 3)).is_equal("not-number")
	assert_bool(bool((verdicts[3] as Dictionary).get("got") == null)).is_true()
	assert_bool(bool((verdicts[4] as Dictionary).get("ok", false))).is_true()
	assert_bool(bool((verdicts[5] as Dictionary).get("ok", false))).is_true()


func test_glow_pattern_gives_out_on_each_number_below_zero_or_above_one() -> void:
	var values := blinking()
	values[10] = 1.5
	values[11] = -0.25
	var verdicts := GlowJudges.glow_pattern(second_cases(), answers(values))
	assert_str(reason_at(verdicts, 10)).is_equal("out")
	assert_float(float((verdicts[10] as Dictionary).get("got"))).is_equal(1.5)
	assert_str(reason_at(verdicts, 11)).is_equal("out")
	assert_float(float((verdicts[11] as Dictionary).get("got"))).is_equal(-0.25)
	assert_bool(bool((verdicts[12] as Dictionary).get("ok", false))).is_true()


func test_glow_pattern_gives_no_blink_on_the_first_case_when_nothing_is_dim() -> void:
	var values: Array = []
	for second in range(60):
		values.append(0.5)
	var verdicts := GlowJudges.glow_pattern(second_cases(), answers(values))
	assert_str(reason_at(verdicts, 0)).is_equal("no-blink")
	assert_bool(bool((verdicts[1] as Dictionary).get("ok", false))).is_true()


func test_glow_pattern_gives_no_blink_when_nothing_is_bright() -> void:
	var values: Array = []
	for second in range(60):
		values.append(0.0)
	var verdicts := GlowJudges.glow_pattern(second_cases(), answers(values))
	assert_str(reason_at(verdicts, 0)).is_equal("no-blink")
	assert_bool(bool((verdicts[59] as Dictionary).get("ok", false))).is_true()


func test_glow_pattern_gives_no_blink_when_nothing_is_dim() -> void:
	var values: Array = []
	for second in range(60):
		values.append(1.0)
	var verdicts := GlowJudges.glow_pattern(second_cases(), answers(values))
	assert_str(reason_at(verdicts, 0)).is_equal("no-blink")


func test_glow_pattern_keeps_the_first_case_its_own_reason() -> void:
	# The first case is not a number, so it keeps "not-number" rather than "no-blink".
	var values: Array = []
	for second in range(60):
		values.append(0.5)
	values[0] = "dark"
	var verdicts := GlowJudges.glow_pattern(second_cases(), answers(values))
	assert_str(reason_at(verdicts, 0)).is_equal("not-number")


func test_glow_pattern_skips_a_call_that_failed() -> void:
	var values := blinking()
	var results := answers(values)
	results[3] = {"ok": false, "kind": "NameError", "message": "name 'x' is not defined", "line": 2}
	var verdicts := GlowJudges.glow_pattern(second_cases(), results)
	# The failed call is not an answer, so it is not "not-number"; Tasks judges it as an error.
	assert_str(reason_at(verdicts, 3)).is_equal("right")
	assert_bool(all_right(verdicts)).is_true()


func test_glow_pattern_has_nothing_to_judge_without_cases() -> void:
	assert_bool(GlowJudges.glow_pattern([], []).is_empty()).is_true()
