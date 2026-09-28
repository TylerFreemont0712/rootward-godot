extends GdUnitTestSuite
## Rng against its recorded draws (game/test/fixtures/rng.json): saved seeds, maps and fights depend on it drawing the
## same numbers every time. Draws in [0, 1) compare as the 32-bit words they came from (Fixtures.word).

var fixture: Dictionary


func before() -> void:
	fixture = Fixtures.load_json("rng")


func after() -> void:
	if Fixtures.updating():
		Fixtures.save_json("rng", fixture)


## A draw's case: the recorded value against `got` as 32-bit words, or `got` recorded in its place.
func _expect_draw(case: Dictionary, key: String, got: float) -> void:
	if Fixtures.updating():
		case[key] = got
		return
	assert_int(Fixtures.word(got)).is_equal(Fixtures.word(case[key]))


func _expect(case: Dictionary, key: String, got: Variant, what: String) -> void:
	var difference := Fixtures.expect(case, key, got, what)
	assert_str(difference).override_failure_message(difference).is_empty()


func test_hash_string_matches() -> void:
	for case: Dictionary in fixture.hash:
		_expect(case, "value", Rng.hash_string(case.text), case.text)


func test_mix32_matches() -> void:
	for case: Dictionary in fixture.mix:
		_expect(case, "mixed", Rng.mix32(int(case.value)), "mix %s" % case.value)


func test_random_for_matches() -> void:
	for case: Dictionary in fixture.randomFor:
		_expect_draw(case, "value", Rng.random_for(case.seed, case.stream, int(case.index)))


func test_sfc32_sequences_match() -> void:
	for case: Dictionary in fixture.sequences:
		var rng := Rng.create(case.seed, case.stream)
		var values: Array = case.values
		if Fixtures.updating():
			case.values = values.map(func(_value: Variant) -> float: return rng.next())
			continue
		for expected: float in values:
			assert_int(Fixtures.word(rng.next())).is_equal(Fixtures.word(expected))


func test_shuffles_match() -> void:
	for case: Dictionary in fixture.shuffles:
		_expect(case, "result", Rng.create(case.seed, "shuffle").shuffled(case.items), "shuffle %s" % case.seed)


func test_pick_weighted_matches() -> void:
	for case: Dictionary in fixture.weighted:
		var weights: Array[float] = []
		for weight: float in case.weights:
			weights.append(weight)
		_expect(case, "index", Rng.pick_weighted(weights, case.roll), "weighted %s" % [case.weights])


func test_pick_weighted_empty_is_minus_one() -> void:
	assert_int(Rng.pick_weighted([0.0, -1.0], 0.5)).is_equal(-1)
