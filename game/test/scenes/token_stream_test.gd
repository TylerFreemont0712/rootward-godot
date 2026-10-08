extends GdUnitTestSuite
## Token Stream (ADR-0058): the names a call line runs, the curve a token flies on, and the circle that wears it.


func test_a_call_line_gives_the_function_it_runs() -> void:
	assert_str(ProgramCode.call_name_of("bolts = salvo(bolts, battle)")).is_equal("salvo")
	assert_str(ProgramCode.call_name_of("bolts = activity_selection(bolts, battle)")).is_equal("activity_selection")
	assert_str(ProgramCode.call_name_of("return bolts")).is_equal("")


func test_a_token_flies_from_its_call_to_the_circle() -> void:
	var parent := auto_free(Control.new()) as Control
	add_child(parent)
	var from := Vector2(120, 340)
	var to := Vector2(640, 160)
	var flight := TokenFlight.launch(parent, "salvo", from, to, Color.WHITE)
	assert_bool(flight.point_at(0.0).is_equal_approx(from)).is_true()
	assert_bool(flight.point_at(1.0).is_equal_approx(to)).is_true()
	# Off the straight line: the token lifts, so its middle leaves the chord.
	var middle := flight.point_at(0.5)
	assert_float(middle.distance_to(from.lerp(to, 0.5))).is_greater(10.0)


func test_a_landed_token_dissolves_and_frees_itself() -> void:
	var parent := auto_free(Control.new()) as Control
	add_child(parent)
	var flight := TokenFlight.launch(parent, "fork", Vector2(10, 10), Vector2(200, 80), Color.WHITE)
	await get_tree().create_timer(TokenFlight.TRAVEL + 0.05).timeout
	flight.land()
	await get_tree().create_timer(TokenFlight.LAND + 0.3).timeout
	assert_bool(is_instance_valid(flight)).is_false()


func test_token_stream_is_a_worn_circle() -> void:
	var option := CosmeticRules.option(Cosmetics.catalog(), "circle", "token-stream")
	assert_str(String(option.get("id", ""))).is_equal("token-stream")
	assert_str(String(option.get("style", ""))).is_equal("codex")
	assert_bool(String(option.get("name", "")).is_empty()).is_false()
