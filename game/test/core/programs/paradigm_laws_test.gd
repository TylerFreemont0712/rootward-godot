extends GdUnitTestSuite
## Laws are measured through the same pure play used by the preview and the cast.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramCatalogs.without_initiative(ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog))


func _fight(effects: Array) -> Dictionary:
	catalog = catalog.duplicate(true)
	catalog.relics["test-law"] = {"effects": effects}
	var state := Shardrun.start(
		catalog, {"seed": "laws", "playstyle": "program", "language": "javascript", "difficulty": "beginner"}
	)
	state.relics = ["test-law"]
	var foes := ShardrunBattle.foe_states(state, ["race-condition-imp", "tally-wisp"], "laws", catalog)
	for foe: Dictionary in foes:
		foe.hp = 20
		foe.max = 20
		foe.shield = 0
		foe.weak = []
		foe.resist = []
		foe.erase("trait")
		foe.intents = [{"kind": "strike", "power": 1, "tempo": 10000}]
	ShardrunBattle.start_with(state, "fight", foes, catalog)
	state.battle.mana = 20
	state.spells[0].shards = ["amplify"]
	return state


func _play(state: Dictionary, bolts: Array, work: Array = []) -> Dictionary:
	return ProgramRules.play(
		state, state.battle, state.spells[0], {"ok": true, "bolts": bolts, "work": work}, catalog, true
	)


func test_greedy_kills_pay_only_with_initiative_and_cap_per_turn() -> void:
	var state := _fight([{"kind": "kill-initiative-mana", "amount": 1, "max": 2}])
	_play(state, [{"power": 20, "element": "none"}])
	assert_int(int(state.battle.bonus_mana)).is_equal(1)
	state.battle.foes[0].hp = 20
	state.battle.foes[0].intents[0].tempo = 1
	_play(state, [{"power": 20, "element": "none"}], [{"shard": "amplify", "given": 8, "returned": 8}])
	assert_int(int(state.battle.bonus_mana)).is_equal(1)


func test_sprint_discounts_the_total_work_of_at_most_three_cards() -> void:
	var state := _fight([{"kind": "small-program-work", "max_cards": 3, "factor": 0.75}])
	var trace := [{"shard": "amplify", "given": 5}, {"shard": "amplify", "given": 5}]
	assert_int(ProgramRules.total_work(ProgramRules.stages(state, trace, catalog))).is_equal(7)
	trace.append_array(trace.duplicate(true))
	assert_int(ProgramRules.total_work(ProgramRules.stages(state, trace, catalog))).is_equal(20)


func test_hardware_rewards_complete_groups_of_work_and_never_a_timeout() -> void:
	var state := _fight([{"kind": "work-power", "every": 256, "add": 1}])
	var played := _play(state, [{"power": 3, "element": "none"}], [{"shard": "amplify", "given": 512}])
	assert_int(int(played.landed.dealt)).is_equal(5)
	var timed := _play(state, [{"power": 999, "element": "none"}], [{"shard": "amplify", "given": 5000}])
	assert_dict(timed.landed).is_empty()


func test_scheduler_requires_all_living_foes_and_does_not_boost_block() -> void:
	var state := _fight([{"kind": "full-spread-power", "add": 1}])
	var played := _play(
		state,
		[
			{"power": 3, "element": "none", "foe": 0},
			{"power": 3, "element": "none", "foe": 1},
			{"power": 3, "element": "none", "block": true}
		]
	)
	assert_int(int(played.landed.dealt)).is_equal(8)
	assert_int(int(played.landed.block)).is_equal(3)


func test_free_imports_are_in_force_at_the_first_turn() -> void:
	var state := _fight([{"kind": "fight-import", "module": "heapq"}])
	assert_array(ProgramDeck.modules(state, catalog)).contains(["heapq"])
	assert_int(ProgramRelics.cost(state, ["amplify"], catalog)).is_equal(1)


func test_overclock_timeout_costs_integrity_in_preview_and_cast() -> void:
	var state := _fight([{"kind": "budget-factor", "factor": 1.5}, {"kind": "timeout-integrity", "amount": 5}])
	assert_int(ProgramRules.budget(state, catalog)).is_equal(6144)
	var before_hp := int(state.integrity)
	_play(state, [], [{"shard": "amplify", "given": 6145}])
	assert_int(int(state.integrity)).is_equal(before_hp - 5)


func test_table_records_landed_damage_and_seed_uses_previous_rows() -> void:
	var state := _fight([{"kind": "table", "from": 3, "divisor": 4}])
	_play(state, [{"power": 12, "element": "none"}])
	assert_array(state.battle.dp).is_equal([12])
	state.battle.dp = [12, 18]
	state.battle.turn = 2
	assert_int(ProgramRules.seed(state, catalog).size()).is_equal(3)
	state.battle.turn = 3
	assert_int(int(ProgramRules.seed(state, catalog).back().power)).is_equal(7)


func test_index_banks_overkill_and_stash_sorted_and_spends_seed_only_on_cast() -> void:
	var state := _fight([{"kind": "index", "size": 8, "seed": 1}])
	_play(state, [{"power": 25, "element": "fire"}, {"power": 7, "element": "frost", "stash": true}])
	assert_array((state.battle.index as Array).map(func(b: Dictionary) -> int: return int(b.power))).is_equal([5, 7])
	assert_int(int(ProgramRules.seed(state, catalog).back().power)).is_equal(7)
	assert_int((state.battle.index as Array).size()).is_equal(2)
	_play(state, [])
	assert_int((state.battle.index as Array).size()).is_equal(1)


func test_exact_kills_double_only_their_table_damage_and_grant_block() -> void:
	var state := _fight(
		[{"kind": "table", "from": 3, "divisor": 4}, {"kind": "exact-kill-table", "factor": 2, "block": 2}]
	)
	var played := _play(state, [{"power": 20, "element": "none"}])
	assert_array(state.battle.dp).is_equal([40])
	assert_int(int(played.gained)).is_equal(2)


func test_preview_reads_memory_without_mutating_the_run() -> void:
	var state := _fight([{"kind": "index", "size": 8, "seed": 1}])
	state.battle.index = [{"power": 9, "element": "fire"}]
	var before_state := state.duplicate(true)
	var outcome := {"ok": true, "bolts": [{"power": 9, "element": "fire"}], "work": []}
	var preview := ProgramRules.preview(state, state.spells[0].id, outcome, catalog)
	var played := _play(state.duplicate(true), outcome.bolts)
	assert_int(int(preview.damage)).is_equal(int(played.landed.dealt))
	assert_dict(state).is_equal(before_state)


func test_overflow_kills_count_for_initiative_and_exact_table_rows() -> void:
	var state := _fight(
		[
			{"kind": "kill-initiative-mana", "amount": 1, "max": 2},
			{"kind": "overkill-flows"},
			{"kind": "exact-kill-table", "factor": 2, "block": 2}
		]
	)
	var played := _play(state, [{"power": 40, "element": "none"}])
	assert_int(int(state.battle.bonus_mana)).is_equal(2)
	assert_array(state.battle.dp).is_equal([60])
	assert_int(int(played.gained)).is_equal(2)
	assert_int(int(state.battle.hits[state.battle.foes[1].uid])).is_equal(1)


func test_stash_does_not_complete_scheduler_target_coverage() -> void:
	var state := _fight([{"kind": "full-spread-power", "add": 1}])
	var played := _play(
		state, [{"power": 3, "element": "none", "foe": 0}, {"power": 4, "element": "fire", "foe": 1, "stash": true}]
	)
	assert_int(int(played.landed.dealt)).is_equal(3)
	assert_int(int(state.battle.index[0].power)).is_equal(4)
