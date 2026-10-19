extends GdUnitTestSuite
## The volume knob's judges (Concept/v0.4/01, 5.4: volume_curve, volume_clamp) and Pip's progress judge (5.8): each
## reason each of them gives, and the answers that pass.


## The eleven notches 0 to 10, each a case with its words.
func notch_cases() -> Array:
	var cases: Array = []
	for notch in range(11):
		cases.append({"args": [notch], "say": "notch %d" % notch})
	return cases


## A straight rise from silent to full: each notch's loudness is a tenth more than the one before.
func linear() -> Array:
	return [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]


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


# --- volume_curve ---------------------------------------------------------------------------------------------------


func test_volume_curve_passes_a_rise_from_silent_to_full() -> void:
	assert_bool(all_right(VolumeJudges.volume_curve(notch_cases(), answers(linear())))).is_true()
	# A curve that bends, such as a square, passes too: silent at 0, full at 10, never quieter going up.
	var squared: Array = []
	for notch in range(11):
		squared.append(pow(notch / 10.0, 2))
	assert_bool(all_right(VolumeJudges.volume_curve(notch_cases(), answers(squared)))).is_true()


func test_volume_curve_gives_not_number_for_an_answer_that_is_not_a_number() -> void:
	var values := linear()
	values[5] = "halfway"
	values[3] = null
	var verdicts := VolumeJudges.volume_curve(notch_cases(), answers(values))
	assert_str(reason_at(verdicts, 5)).is_equal("not-number")
	assert_str(reason_at(verdicts, 3)).is_equal("not-number")
	assert_str(String((verdicts[5] as Dictionary).get("got"))).is_equal("halfway")
	assert_bool(bool((verdicts[4] as Dictionary).get("ok", false))).is_true()


func test_volume_curve_gives_silent_end_when_notch_zero_is_not_silent() -> void:
	var values := linear()
	values[0] = 0.5
	var verdicts := VolumeJudges.volume_curve(notch_cases(), answers(values))
	assert_str(reason_at(verdicts, 0)).is_equal("silent-end")
	assert_float(float((verdicts[0] as Dictionary).get("got"))).is_equal(0.5)
	# Within 0.01 of 0.0 is silent enough.
	values[0] = 0.005
	assert_bool(all_right(VolumeJudges.volume_curve(notch_cases(), answers(values)))).is_true()


func test_volume_curve_gives_full_end_when_notch_ten_is_not_full() -> void:
	var values := linear()
	values[10] = 0.9
	var verdicts := VolumeJudges.volume_curve(notch_cases(), answers(values))
	assert_str(reason_at(verdicts, 10)).is_equal("full-end")
	# Within 0.01 of 1.0 is full enough.
	values[10] = 0.995
	assert_bool(all_right(VolumeJudges.volume_curve(notch_cases(), answers(values)))).is_true()


func test_volume_curve_gives_out_for_a_loudness_below_zero_or_above_one() -> void:
	var values := linear()
	values[5] = 1.5
	var verdicts := VolumeJudges.volume_curve(notch_cases(), answers(values))
	assert_str(reason_at(verdicts, 5)).is_equal("out")
	assert_int(int((verdicts[5] as Dictionary).get("notch"))).is_equal(5)
	assert_float(float((verdicts[5] as Dictionary).get("got"))).is_equal(1.5)
	# Below 0 is out too, and the notch that is out keeps "out" even though it is also quieter than the one before.
	values[5] = -0.2
	verdicts = VolumeJudges.volume_curve(notch_cases(), answers(values))
	assert_str(reason_at(verdicts, 5)).is_equal("out")


func test_volume_curve_gives_goes_down_to_the_quieter_notch() -> void:
	var values := linear()
	values[7] = 0.5
	var verdicts := VolumeJudges.volume_curve(notch_cases(), answers(values))
	assert_str(reason_at(verdicts, 7)).is_equal("goes-down")
	assert_int(int((verdicts[7] as Dictionary).get("notch"))).is_equal(7)
	# The notches either side are not blamed.
	assert_bool(bool((verdicts[6] as Dictionary).get("ok", false))).is_true()
	assert_bool(bool((verdicts[8] as Dictionary).get("ok", false))).is_true()


func test_volume_curve_lets_a_notch_be_as_loud_as_the_one_before() -> void:
	var values := linear()
	values[7] = 0.6
	assert_bool(all_right(VolumeJudges.volume_curve(notch_cases(), answers(values)))).is_true()


func test_volume_curve_ignores_notches_outside_the_knob() -> void:
	var cases := [{"args": [-3]}, {"args": [14]}]
	var verdicts := VolumeJudges.volume_curve(cases, answers(["anything", 7]))
	assert_bool(all_right(verdicts)).is_true()


# --- volume_clamp --------------------------------------------------------------------------------------------------


func past_the_ends_cases() -> Array:
	return [
		{"args": [-3], "say": "dragged past the bottom"},
		{"args": [-1], "say": "nudged a little past the bottom"},
		{"args": [11], "say": "nudged a little past the top"},
		{"args": [14], "say": "dragged past the top"},
	]


func test_volume_clamp_passes_the_ends_at_their_ends() -> void:
	var verdicts := VolumeJudges.volume_clamp(past_the_ends_cases(), answers([0.0, 0.0, 1.0, 1.0]))
	assert_bool(all_right(verdicts)).is_true()
	# Within 0.01 is close enough at each end.
	verdicts = VolumeJudges.volume_clamp(past_the_ends_cases(), answers([0.005, -0.005, 0.995, 1.004]))
	assert_bool(all_right(verdicts)).is_true()


func test_volume_clamp_gives_low_end_below_the_bottom_when_not_silent() -> void:
	var verdicts := VolumeJudges.volume_clamp(past_the_ends_cases(), answers([-0.3, -0.1, 1.0, 1.0]))
	assert_str(reason_at(verdicts, 0)).is_equal("low-end")
	assert_str(reason_at(verdicts, 1)).is_equal("low-end")
	assert_float(float((verdicts[1] as Dictionary).get("got"))).is_equal(-0.1)
	assert_bool(bool((verdicts[2] as Dictionary).get("ok", false))).is_true()


func test_volume_clamp_gives_high_end_above_the_top_when_not_full() -> void:
	var verdicts := VolumeJudges.volume_clamp(past_the_ends_cases(), answers([0.0, 0.0, 1.1, 1.4]))
	assert_str(reason_at(verdicts, 2)).is_equal("high-end")
	assert_str(reason_at(verdicts, 3)).is_equal("high-end")
	assert_int(int((verdicts[3] as Dictionary).get("notch"))).is_equal(14)


func test_volume_clamp_gives_not_number_past_the_ends_too() -> void:
	var verdicts := VolumeJudges.volume_clamp(past_the_ends_cases(), answers(["quiet", null, 1.0, 1.0]))
	assert_str(reason_at(verdicts, 0)).is_equal("not-number")
	assert_str(reason_at(verdicts, 1)).is_equal("not-number")


func test_volume_clamp_still_judges_the_curve_on_its_own_notches() -> void:
	var cases := notch_cases()
	cases.append({"args": [-3], "say": "dragged past the bottom"})
	var values := linear()
	values[0] = 0.5
	values.append(0.0)
	var verdicts := VolumeJudges.volume_clamp(cases, answers(values))
	assert_str(reason_at(verdicts, 0)).is_equal("silent-end")
	assert_bool(bool((verdicts[11] as Dictionary).get("ok", false))).is_true()


# --- progress ------------------------------------------------------------------------------------------------------


func progress_cases() -> Array:
	return [
		{"args": [0, 4], "want": 0},
		{"args": [2, 4], "want": 50},
		{"args": [4, 4], "want": 100},
		{"args": [1, 3], "want": 33},
		{"args": [2, 3], "any": [66, 67]},
		{"args": [0, 0], "want": 0, "edge": true},
	]


func test_progress_passes_whole_percents_rounded_either_way() -> void:
	var verdicts := VolumeJudges.progress(progress_cases(), answers([0, 50, 100, 33, 66, 0]))
	assert_bool(all_right(verdicts)).is_true()
	# Nearest is fine too, and a float that is whole (50.0) is the same answer.
	verdicts = VolumeJudges.progress(progress_cases(), answers([0.0, 50.0, 100.0, 33.0, 67.0, 0.0]))
	assert_bool(all_right(verdicts)).is_true()


func test_progress_gives_not_whole_for_bits_after_the_point() -> void:
	var verdicts := VolumeJudges.progress(progress_cases(), answers([0, 50, 100, 33.333, 66, 0]))
	assert_str(reason_at(verdicts, 3)).is_equal("not-whole")
	assert_float(float((verdicts[3] as Dictionary).get("got"))).is_equal_approx(33.333, 0.0001)


func test_progress_gives_fraction_for_a_part_of_one() -> void:
	var verdicts := VolumeJudges.progress(progress_cases(), answers([0, 0.5, 100, 33, 66, 0]))
	assert_str(reason_at(verdicts, 1)).is_equal("fraction")
	verdicts = VolumeJudges.progress(progress_cases(), answers([0, 50, 100, 0.333, 66, 0]))
	assert_str(reason_at(verdicts, 3)).is_equal("fraction")


func test_progress_gives_wrong_with_what_it_wanted_and_got() -> void:
	var verdicts := VolumeJudges.progress(progress_cases(), answers([0, 40, 100, 33, 66, 0]))
	assert_str(reason_at(verdicts, 1)).is_equal("wrong")
	assert_int(int((verdicts[1] as Dictionary).get("want"))).is_equal(50)
	assert_int(int((verdicts[1] as Dictionary).get("got"))).is_equal(40)
	# An answer that is no number at all is wrong, with the nearest percent it wanted.
	verdicts = VolumeJudges.progress(progress_cases(), answers([0, 50, 100, 33, null, 0]))
	assert_str(reason_at(verdicts, 4)).is_equal("wrong")
	assert_int(int((verdicts[4] as Dictionary).get("want"))).is_equal(67)


func test_progress_gives_zero_when_a_quest_has_no_steps_and_is_not_zero() -> void:
	var verdicts := VolumeJudges.progress(progress_cases(), answers([0, 50, 100, 33, 66, 1]))
	assert_str(reason_at(verdicts, 5)).is_equal("zero")
	verdicts = VolumeJudges.progress(progress_cases(), answers([0, 50, 100, 33, 66, null]))
	assert_str(reason_at(verdicts, 5)).is_equal("zero")
	verdicts = VolumeJudges.progress(progress_cases(), answers([0, 50, 100, 33, 66, 0.0]))
	assert_bool(bool((verdicts[5] as Dictionary).get("ok", false))).is_true()
