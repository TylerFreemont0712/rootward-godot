extends GdUnitTestSuite
## Body slots and stage modifiers execute real cards in all three sandbox languages.

var cards: Dictionary


func before() -> void:
	cards = ContentLoader.load_shardrun().catalog.programs.cards


func _bolts(powers: Array) -> Array:
	return powers.map(func(power: int) -> Dictionary: return {"power": power, "element": "none"})


func _run(language: String, ids: Array, powers: Array, execution: Dictionary) -> Dictionary:
	var list: Array[Dictionary] = []
	for id: String in ids:
		var card: Dictionary = cards[id].duplicate(true)
		# Reverse serves as a small splitter here, without changing the content or its C++ registry.
		if id == "reverse":
			card.splits = true
		list.append(card)
	var input := {
		"bolts": _bolts(powers),
		"battle": {"turn": 1, "me": {"hp": 30, "max": 30, "block": 0, "mana": 9}, "foes": []},
		"limit": 192,
		"trace_limit": 192,
		"count": true,
		"module": "program",
		"execution": execution,
	}
	var spells: Array[Dictionary] = [{"id": "p", "shards": list}]
	var run: Dictionary = SpellHarness.run(language, spells, input).p
	assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
	return run


func _powers(run: Dictionary) -> Array:
	return (run.bolts as Array).map(func(bolt: Dictionary) -> int: return int(bolt.power))


func test_body_runs_on_unequal_halves_and_merger_adds_after_rejoining() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var run := _run(language, ["reverse", "reduce"], [1, 2, 3, 4, 5], {"body": {"kind": "split", "depth": 1}})
		assert_array(_powers(run)).override_failure_message(language).is_equal([13, 3])
		assert_int((run.trace as Array).size()).is_equal(3)
		assert_int(int(run.trace[1].given)).is_equal(3)
		assert_int(int(run.trace[2].given)).is_equal(2)
		assert_int(int(run.trace[1].slot)).is_equal(1)
		assert_int(int(run.trace[1].body)).is_equal(0)
		var merged := _run(
			language, ["reverse", "reduce"], [1, 2, 3, 4, 5], {"body": {"kind": "split", "depth": 1}, "rejoin_power": 1}
		)
		assert_array(_powers(merged)).is_equal([14, 4])
		var joined: Dictionary = merged.trace[-1]
		assert_array(_powers({"bolts": joined.joined})).is_equal([14, 4])
		assert_int(int(joined.joined_returned)).is_equal(2)
		assert_int(int(joined.joined_power)).is_equal(18)
		assert_int((joined.joined_elements as Dictionary).size()).is_equal(1)
		assert_int(int(joined.joined_elements.none)).is_equal(2)


func test_deep_body_runs_four_quarters_and_empty_pieces_are_real_calls() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var run := _run(language, ["reverse", "reduce"], [1, 2, 3, 4, 5], {"body": {"kind": "split", "depth": 2}})
		assert_array(_powers(run)).override_failure_message(language).is_equal([9, 3, 2, 1])
		assert_int((run.trace as Array).size()).is_equal(5)
		var tiny := _run(language, ["reverse", "amplify"], [1], {"body": {"kind": "split", "depth": 2}})
		assert_array(_powers(tiny)).is_equal([4])
		assert_int((tiny.trace as Array).size()).is_equal(5)


func test_trailing_splitter_and_runs_without_recurse_keep_the_normal_pipeline() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var trailing := _run(language, ["reverse"], [1, 2, 3], {"body": {"kind": "split", "depth": 1}})
		assert_array(_powers(trailing)).is_equal([3, 2, 1])
		assert_int((trailing.trace as Array).size()).is_equal(1)
		var plain := _run(language, ["reverse", "reduce"], [1, 2, 3, 4, 5], {})
		assert_array(_powers(plain)).is_equal([16])


func test_pruning_discards_a_crossing_result_and_continues_from_its_input() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var run := _run(language, ["amplify", "pairwise", "reduce"], [1, 2, 3], {"prune": true, "budget": 6})
		assert_array(_powers(run)).override_failure_message(language).is_equal([16])
		assert_bool(run.trace[1].pruned).is_true()
		assert_int(int(run.trace[2].given)).is_equal(3)
		assert_bool((run.trace[0] as Dictionary).get("pruned", false)).is_false()
		var discounted := _run(
			language, ["amplify", "pairwise"], [1, 2, 3], {"prune": true, "budget": 6, "work_factor": 0.5}
		)
		assert_bool((discounted.trace[1] as Dictionary).get("pruned", false)).is_false()
		assert_array(_powers(discounted)).is_equal([9, 10, 11])


func test_stage_power_checks_paradigm_and_the_actual_sorted_strike_input() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var enumeration := _run(
			language, ["pairwise"], [1, 2, 3], {"source_power": [{"paradigm": "brute-force", "add": 1}]}
		)
		assert_array(_powers(enumeration)).override_failure_message(language).is_equal([4, 5, 6])
		var other := _run(language, ["pairwise"], [1, 2, 3], {"source_power": [{"paradigm": "greedy", "add": 9}]})
		assert_array(_powers(other)).is_equal([3, 4, 5])
		var sorted := _run(language, ["round-robin"], [1, 2, 3], {"sorted_strike_power": 1})
		assert_array(_powers(sorted)).is_equal([2, 3, 4])
		assert_bool(sorted.trace[0].input_sorted).is_true()
		var unsorted := _run(language, ["round-robin"], [3, 1, 2], {"sorted_strike_power": 1})
		assert_array(_powers(unsorted)).is_equal([3, 1, 2])
		assert_bool(unsorted.trace[0].input_sorted).is_false()


func test_consecutive_splitters_nest_only_with_deep_recursion() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var shallow := _run(
			language, ["reverse", "reverse", "reduce"], [1, 2, 3, 4, 5], {"body": {"kind": "split", "depth": 1}}
		)
		assert_array(_powers(shallow)).is_equal([16])
		assert_int((shallow.trace as Array).size()).is_equal(4)
		var deep := _run(
			language, ["reverse", "reverse", "reduce"], [1, 2, 3, 4, 5], {"body": {"kind": "split", "depth": 2}}
		)
		assert_array(_powers(deep)).override_failure_message(language).is_equal([7, 5, 1, 2])
		assert_int((deep.trace as Array).size()).is_equal(7)
		assert_array(_powers({"bolts": deep.trace[-1].joined})).is_equal([7, 5, 1, 2])


func _fight(language: String, ids: Array, foe_ids: Array = ["race-condition-imp"]) -> Dictionary:
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog).duplicate(true)
	catalog.shards.reverse.splits = true
	catalog.relics["test-body"] = {"effects": [{"kind": "recurse-depth", "depth": 1}]}
	var state := Shardrun.start(
		catalog, {"seed": "body-regression", "language": language, "playstyle": "program", "difficulty": "beginner"}
	)
	state.relics = ["test-body"]
	var foes := ShardrunBattle.foe_states(state, foe_ids, "body-regression", catalog)
	ShardrunBattle.start_with(state, "fight", foes, catalog)
	state.battle.mana = 30
	state.spells[0].shards = ids
	return {"state": state, "catalog": catalog}


func test_the_mutators_real_mutant_runs_in_every_body_piece() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var fixture := _fight(language, ["reverse", "dedupe"], ["mutator"])
		var state: Dictionary = fixture.state
		state.battle.mutants = {"dedupe": {"op": 14}}
		var runner := SpellRuns.new(fixture.catalog)
		var runs := await runner.runs_for(state, state.spells)
		var run: Dictionary = runs[state.spells[0].id]
		assert_bool(run.ok).override_failure_message("%s: %s" % [language, run.get("reason")]).is_true()
		assert_array(_powers(run)).is_equal([1, 1])
		assert_int((run.trace as Array).size()).is_equal(3)


func test_the_unreachable_cut_cannot_run_a_dead_body() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var fixture := _fight(language, ["reverse", "reduce", "amplify"], ["unreachable"])
		var state: Dictionary = fixture.state
		state.battle.foes[0].return_at = 2
		var runner := SpellRuns.new(fixture.catalog)
		var runs := await runner.runs_for(state, state.spells)
		var run: Dictionary = runs[state.spells[0].id]
		assert_bool(run.ok).override_failure_message(language).is_true()
		assert_int((run.trace as Array).size()).is_equal(1)
		assert_array(_powers(run)).is_equal([3, 3, 3])
		state.battle.foes[0].return_at = 3
		runs = await runner.runs_for(state, state.spells)
		run = runs[state.spells[0].id]
		assert_int((run.trace as Array).size()).is_equal(3)
		assert_array(_powers(run)).is_equal([6, 3])


func test_a_split_program_preview_matches_cast_against_a_faster_imp() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var fixture := _fight(language, ["salvo", "reverse", "round-robin"], ["race-condition-imp", "tally-wisp"])
		var state: Dictionary = fixture.state
		state.battle.foes[0].intents = [{"kind": "strike", "power": 3, "tempo": 1}]
		state.battle.foes[1].intents = [{"kind": "strike", "power": 1, "tempo": 10000}]
		for foe: Dictionary in state.battle.foes:
			foe.hp = 1000
			foe.max = 1000
		var before_hp := int(state.integrity)
		var runner := SpellRuns.new(fixture.catalog)
		var runs := await runner.runs_for(state, state.spells)
		var run: Dictionary = runs[state.spells[0].id]
		assert_bool(run.ok).override_failure_message(language).is_true()
		var outcome := SpellRuns.to_outcome(run)
		var preview := ProgramRules.preview(state, state.spells[0].id, outcome, fixture.catalog)
		assert_array(preview.faster).contains(["Race Condition Imp"])
		assert_int(int(state.integrity)).is_equal(before_hp)
		var played := ProgramRules.play(state, state.battle, state.spells[0], outcome, fixture.catalog, true)
		assert_int(int(preview.damage)).is_equal(int(played.landed.dealt))
		assert_int(int(preview.block)).is_equal(int(played.gained))
		assert_int(int(state.integrity)).is_equal(before_hp - 3)


func test_pruner_and_sprint_bill_body_invocations_by_original_card_slots() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var fixture := _fight(language, ["reverse", "reduce", "amplify"])
		fixture.catalog.programs.config.budget = [6]
		(fixture.catalog.relics["test-body"].effects as Array).append_array(
			[{"kind": "prune-not-timeout"}, {"kind": "small-program-work", "max_cards": 3, "factor": 0.75}]
		)
		var state: Dictionary = fixture.state
		var runner := SpellRuns.new(fixture.catalog)
		var runs := await runner.runs_for(state, state.spells)
		var run: Dictionary = runs[state.spells[0].id]
		assert_bool(run.ok).override_failure_message(language).is_true()
		assert_array(_powers(run)).is_equal([9, 6])
		var outcome := SpellRuns.to_outcome(run)
		var stages := ProgramRules.stages(state, outcome.work, fixture.catalog)
		assert_int(ProgramRules.total_work(stages)).override_failure_message(language).is_equal(6)
		assert_bool(ProgramRules.preview(state, state.spells[0].id, outcome, fixture.catalog).timeout).is_false()


func test_pruned_sort_does_not_change_the_following_cards_work_class() -> void:
	for language: String in ["python", "javascript", "cpp"]:
		var fixture := _fight(language, ["reverse", "bubble-sort", "quick-sort"])
		fixture.catalog.programs.config.budget = [9]
		fixture.catalog.programs.config.seed = _bolts([1, 2, 3])
		fixture.catalog.relics["test-body"].effects = [{"kind": "prune-not-timeout"}]
		var state: Dictionary = fixture.state
		var runner := SpellRuns.new(fixture.catalog)
		var runs := await runner.runs_for(state, state.spells)
		var run: Dictionary = runs[state.spells[0].id]
		assert_bool(run.ok).override_failure_message(language).is_true()
		assert_array(_powers(run)).is_equal([1, 2, 3])
		assert_bool(run.trace[1].pruned).is_true()
		assert_bool((run.trace[2] as Dictionary).get("pruned", false)).is_false()
		var outcome := SpellRuns.to_outcome(run)
		var stages := ProgramRules.stages(state, outcome.work, fixture.catalog)
		assert_int(ProgramRules.total_work(stages)).override_failure_message(language).is_equal(9)
