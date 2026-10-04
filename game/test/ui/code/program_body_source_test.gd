extends GdUnitTestSuite
## The listing represents the actual body calls, and invocation traces retain one UI slot per card.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func test_body_listing_calls_the_function_on_each_half_in_every_language() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var lines := ProgramSource.lines(language, ["split", "reduce"], catalog, [], [], [], {"depth": 1})
		var text := "\n".join(lines.map(func(line: Dictionary) -> String: return line.text))
		assert_str(text).contains("reduce(left, battle)")
		assert_str(text).contains("reduce(right, battle)")
		assert_int(lines.filter(func(line: Dictionary) -> bool: return line.kind == "call").size()).is_equal(2)
		assert_str(text).not_contains("bolts = reduce(bolts, battle)")


func test_deep_body_listing_uses_quarters_and_trailing_split_keeps_one_call() -> void:
	var lines := ProgramSource.lines("python", ["split", "reduce"], catalog, [], [], [], {"depth": 2})
	var text := "\n".join(lines.map(func(line: Dictionary) -> String: return line.text))
	assert_str(text).contains("reduce(left_left, battle)")
	assert_str(text).contains("reduce(right_right, battle)")
	var trailing := ProgramSource.lines("python", ["split"], catalog, [], [], [], {"depth": 1})
	assert_int(trailing.filter(func(line: Dictionary) -> bool: return line.kind == "call").size()).is_equal(1)


func test_body_invocations_merge_work_loops_and_joined_output_into_one_slot() -> void:
	var trace := [
		{"shard": "split", "slot": 0, "given": 3, "returned": 6, "bolts": []},
		{"shard": "reduce", "slot": 1, "given": 3, "returned": 1, "calls": 1, "loops": {"3": 3}, "bolts": []},
		{
			"shard": "reduce",
			"slot": 1,
			"given": 3,
			"returned": 1,
			"calls": 1,
			"loops": {"3": 3},
			"bolts": [],
			"joined": [{"power": 10, "element": "none"}, {"power": 8, "element": "fire"}],
			"joined_returned": 2,
			"joined_power": 18,
			"joined_elements": {"none": 1, "fire": 1}
		}
	]
	var stages := [{"work": 6}, {"work": 3}, {"work": 3}]
	var steps := ProgramViews.slot_steps(trace, stages, catalog)
	assert_int(steps.size()).is_equal(2)
	assert_int(int(steps[1].work)).is_equal(6)
	assert_int(int(steps[1].calls)).is_equal(2)
	assert_int(int(steps[1].loops["3"])).is_equal(6)
	assert_int(int(steps[1].returned)).is_equal(2)
	assert_int(int(steps[1].power)).is_equal(18)
