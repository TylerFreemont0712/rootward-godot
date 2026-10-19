extends GdUnitTestSuite
## The music box's next_track and the clock's clock_text (MusicJudges, Concept/v0.4/01 sections 5.5 and 5.9): the
## answers they accept, and every reason they can give ("not-whole", "no-wrap", "wrong", "not-text", "no-zero").


## One result per answer: each {ok: true, value} as the harness gives them.
func _answers(values: Array) -> Array:
	var out: Array = []
	for value: Variant in values:
		out.append({"ok": true, "value": value})
	return out


func test_next_track_accepts_every_right_track() -> void:
	var cases := [
		{"args": [0, 3], "want": 1},
		{"args": [1, 3], "want": 2},
		{"args": [2, 3], "want": 0},
		{"args": [0, 1], "want": 0},
		{"args": [4, 5], "want": 0},
	]
	var verdicts := MusicJudges.next_track(cases, _answers([1, 2, 0, 0, 0]))
	assert_int(verdicts.size()).is_equal(5)
	for verdict: Dictionary in verdicts:
		assert_bool(bool(verdict.ok)).is_true()
		assert_str(String(verdict.reason)).is_equal("right")


func test_next_track_accepts_a_whole_number_written_as_a_float() -> void:
	var verdicts := MusicJudges.next_track([{"args": [0, 3], "want": 1}], _answers([1.0]))
	assert_bool(bool(verdicts[0].ok)).is_true()


func test_next_track_wrong_track_is_wrong() -> void:
	var verdicts := MusicJudges.next_track([{"args": [0, 3], "want": 1}], _answers([2]))
	var verdict: Dictionary = verdicts[0]
	assert_bool(bool(verdict.ok)).is_false()
	assert_str(String(verdict.reason)).is_equal("wrong")
	assert_int(int(verdict.want)).is_equal(1)
	assert_int(int(verdict.got)).is_equal(2)


func test_next_track_wrong_on_the_last_track_is_no_wrap() -> void:
	var verdicts := MusicJudges.next_track(
		[{"args": [2, 3], "want": 0}, {"args": [0, 1], "want": 0}], _answers([3, 1])
	)
	var last: Dictionary = verdicts[0]
	assert_str(String(last.reason)).is_equal("no-wrap")
	assert_int(int(last.want)).is_equal(0)
	assert_int(int(last.got)).is_equal(3)
	assert_str(String(verdicts[1].reason)).is_equal("no-wrap")


func test_next_track_a_fraction_or_nothing_is_not_whole() -> void:
	var verdicts := MusicJudges.next_track(
		[{"args": [0, 3], "want": 1}, {"args": [1, 3], "want": 2}, {"args": [2, 3], "want": 0}],
		[{"ok": true, "value": 1.5}, {"ok": true, "value": null}, {"ok": true, "value": "0"}]
	)
	for verdict: Dictionary in verdicts:
		assert_bool(bool(verdict.ok)).is_false()
		assert_str(String(verdict.reason)).is_equal("not-whole")
	assert_float(float(verdicts[0].got)).is_equal(1.5)


func test_next_track_dispatches_by_name() -> void:
	var verdicts := TaskJudges.judge("next_track", [{"args": [0, 3], "want": 1}], _answers([1]))
	assert_bool(bool(verdicts[0].ok)).is_true()


func test_clock_text_accepts_the_times_and_a_leading_zero_on_the_hour() -> void:
	var cases := [
		{"args": [0], "want": "0:00"},
		{"args": [65], "want": "1:05"},
		{"args": [600], "want": "10:00"},
		{"args": [1119], "want": "18:39"},
		{"args": [1439], "want": "23:59"},
	]
	var verdicts := MusicJudges.clock_text(cases, _answers(["0:00", "1:05", "10:00", "18:39", "23:59"]))
	for verdict: Dictionary in verdicts:
		assert_bool(bool(verdict.ok)).is_true()
	var padded := MusicJudges.clock_text([{"args": [65], "want": "1:05"}], _answers(["01:05"]))
	assert_bool(bool(padded[0].ok)).is_true()


func test_clock_text_not_text_is_a_number_or_nothing() -> void:
	var verdicts := MusicJudges.clock_text(
		[{"args": [65], "want": "1:05"}, {"args": [0], "want": "0:00"}],
		[{"ok": true, "value": 65}, {"ok": true, "value": null}]
	)
	assert_str(String(verdicts[0].reason)).is_equal("not-text")
	assert_int(int(verdicts[0].got)).is_equal(65)
	assert_str(String(verdicts[1].reason)).is_equal("not-text")


func test_clock_text_one_digit_minutes_is_no_zero() -> void:
	var verdicts := MusicJudges.clock_text(
		[{"args": [65], "want": "1:05"}, {"args": [600], "want": "10:00"}], _answers(["1:5", "10:0"])
	)
	var first: Dictionary = verdicts[0]
	assert_bool(bool(first.ok)).is_false()
	assert_str(String(first.reason)).is_equal("no-zero")
	assert_str(String(first.want)).is_equal("1:05")
	assert_str(String(first.got)).is_equal("1:5")
	assert_str(String(verdicts[1].reason)).is_equal("no-zero")


func test_clock_text_any_other_wrong_text_is_wrong() -> void:
	var verdicts := MusicJudges.clock_text(
		[{"args": [1119], "want": "18:39"}, {"args": [1119], "want": "18:39"}, {"args": [65], "want": "1:05"}],
		_answers(["18:9", "18:40", "2:05"])
	)
	var nine: Dictionary = verdicts[0]
	assert_str(String(nine.reason)).is_equal("wrong")
	assert_str(String(nine.want)).is_equal("18:39")
	assert_str(String(nine.got)).is_equal("18:9")
	assert_str(String(verdicts[1].reason)).is_equal("wrong")
	assert_str(String(verdicts[2].reason)).is_equal("wrong")
