extends GdUnitTestSuite


func test_js_round_takes_halves_up() -> void:
	assert_int(JsMath.js_round(2.5)).is_equal(3)
	assert_int(JsMath.js_round(-2.5)).is_equal(-2)
	assert_int(JsMath.js_round(-2.6)).is_equal(-3)
	assert_int(JsMath.js_round(0.49999999999999994)).is_equal(0)
	assert_int(JsMath.js_round(-0.5)).is_equal(0)


func test_log2_is_exact_at_powers_of_two() -> void:
	for exponent in 20:
		assert_float(JsMath.log2_whole(1 << exponent)).is_equal(float(exponent))
	assert_float(JsMath.log2_whole(3)).is_equal_approx(1.584962500721156, 1e-15)


func test_text_prints_as_javascript() -> void:
	assert_str(JsMath.text(null)).is_equal("null")
	assert_str(JsMath.text(3.0)).is_equal("3")
	assert_str(JsMath.text(1.5)).is_equal("1.5")
	assert_str(JsMath.text("l0-r1-c2")).is_equal("l0-r1-c2")
