extends GdUnitTestSuite
## Rng must match the TypeScript engine bit for bit: saved seeds, maps and fights depend on it.

var fixture: Dictionary


func before() -> void:
	fixture = Fixtures.load_json("rng")


func test_hash_string_matches() -> void:
	for case: Dictionary in fixture.hash:
		assert_int(Rng.hash_string(case.text)).override_failure_message(case.text).is_equal(int(case.value))


func test_mix32_matches() -> void:
	for case: Dictionary in fixture.mix:
		assert_int(Rng.mix32(int(case.value))).is_equal(int(case.mixed))


func test_random_for_matches() -> void:
	for case: Dictionary in fixture.randomFor:
		var got := Rng.random_for(case.seed, case.stream, int(case.index))
		assert_int(Fixtures.word(got)).is_equal(Fixtures.word(case.value))


func test_sfc32_sequences_match() -> void:
	for case: Dictionary in fixture.sequences:
		var rng := Rng.create(case.seed, case.stream)
		for expected: float in case.values:
			assert_int(Fixtures.word(rng.next())).is_equal(Fixtures.word(expected))


func test_shuffles_match() -> void:
	for case: Dictionary in fixture.shuffles:
		var got := Rng.create(case.seed, "shuffle").shuffled(case.items)
		assert_array(got).is_equal(case.result)


func test_pick_weighted_matches() -> void:
	for case: Dictionary in fixture.weighted:
		var weights: Array[float] = []
		for weight: float in case.weights:
			weights.append(weight)
		assert_int(Rng.pick_weighted(weights, case.roll)).is_equal(int(case.index))


func test_pick_weighted_empty_is_minus_one() -> void:
	assert_int(Rng.pick_weighted([0.0, -1.0], 0.5)).is_equal(-1)
