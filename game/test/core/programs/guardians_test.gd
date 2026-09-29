extends GdUnitTestSuite
## The guardian pool (docs/NewEnemies.md, ADR-0026): every guardian's gimmick as a rule, on its real content, landed
## and acted through the same functions a fight uses.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramCatalogs.without_initiative(ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog))


## A program run in a fight against `ids` (the content's own foes), at full health, on turn 1, with no block.
func _against(ids: Array, seed := "guardians") -> Dictionary:
	var options := {"seed": seed, "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.status = "battle"
	var battle := ShardrunBattle.new_battle(state, "boss", ShardrunBattle.foe_states(state, ids, "g", catalog), catalog)
	battle.hand = ["amplify", "take-max", "merge-sort", "salvo", "fork"]
	battle.draw = ["kindle", "chill", "ward"]
	battle.block = 0
	battle.mana = 9
	ProgramDeck.on_battle_start(battle)
	ShardrunBattle.begin_turn(battle)
	state.battle = battle
	state.integrity = 60
	return state


func _bolts(powers: Array, at := 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for power: int in powers:
		out.append({"power": power, "element": "none", "foe": at})
	return out


func _land(state: Dictionary, bolts: Array[Dictionary], context := {}) -> Dictionary:
	return ProgramRules.resolve(state, state.battle, bolts, catalog, context)


func _foe(state: Dictionary, index := 0) -> Dictionary:
	return state.battle.foes[index]


func _act(state: Dictionary, foe: Dictionary, intent_index: int) -> void:
	foe.intent_index = intent_index
	ShardrunBattle.foe_act(state, state.battle, foe, catalog)


func _end_turn(state: Dictionary) -> void:
	ShardrunBattle.new_turn(state, state.battle, catalog)


# --- Stage 1 ---------------------------------------------------------------------------------------------------------


func test_ouroboros_breaks_on_a_volley_that_meets_its_guard() -> void:
	var state := _against(["ouroboros"])
	var snake := _foe(state)
	assert_dict(snake.guard).is_equal({"check": "count", "op": "==", "value": 3})
	var landed := _land(state, _bolts([4, 4, 4]))
	assert_int(int(landed.dealt)).is_equal(18)
	assert_bool(snake.stunned).is_true()
	var before := int(state.integrity)
	_act(state, snake, 2)
	assert_int(int(state.integrity)).override_failure_message("a stunned loop does nothing").is_equal(before)
	_end_turn(state)
	assert_int(int(snake.loop)).is_equal(2)


func test_an_unbroken_loop_goes_round_once_more() -> void:
	var state := _against(["ouroboros"])
	var snake := _foe(state)
	_land(state, _bolts([4, 4]))
	_end_turn(state)
	assert_int(int(snake.loop)).is_equal(3)
	var before := int(state.integrity)
	_act(state, snake, 2)
	assert_int(before - int(state.integrity)).is_equal(9)


func test_a_throw_caught_by_block_bounces_back_and_one_missed_grows_the_trace() -> void:
	var state := _against(["unhandled-exception"])
	var thrower := _foe(state)
	var hp := int(thrower.hp)
	state.battle.block = 12
	_act(state, thrower, 0)
	assert_int(int(state.battle.block)).is_equal(2)
	assert_int(int(state.integrity)).is_equal(60)
	assert_int(hp - int(thrower.hp)).is_equal(15)
	state.battle.block = 0
	_act(state, thrower, 0)
	assert_int(int(state.integrity)).is_equal(50)
	assert_int(int(thrower.trace)).is_equal(2)
	_act(state, thrower, 2)
	assert_int(int(state.integrity)).override_failure_message("13 and the trace's 2").is_equal(35)


func test_the_short_circuit_rewards_the_biggest_bolt_first() -> void:
	var weak_first := _against(["short-circuit"])
	assert_int(int(_foe(weak_first).guard)).is_equal(8)
	assert_int(int(_land(weak_first, _bolts([4, 9, 9])).dealt)).is_equal(4)
	var strong_first := _against(["short-circuit"])
	assert_int(int(_land(strong_first, _bolts([9, 4, 4])).dealt)).is_equal(26)


func test_the_unreachable_cuts_the_program_at_its_return() -> void:
	var state := _against(["unreachable"])
	assert_int(ProgramGuardians.dead_from(state.battle)).is_equal(4)
	state.battle.turn = 3
	ShardrunBattle.begin_turn(state.battle)
	assert_int(ProgramGuardians.dead_from(state.battle)).is_equal(2)
	var runs := SpellRuns.new(catalog)
	var input := runs.input_for(state)
	assert_int(int(input.dead_from)).is_equal(2)
	var spell := {"id": "s", "shards": ["amplify", "fork", "salvo", "kindle"]}
	assert_array(runs.call("_steps", spell, input)).is_equal(["amplify", "fork"])
	var notes := GuardianLanding.telegraph(state.battle, state.battle, spell.shards, [], catalog)
	assert_str(notes[0]).contains("2 of your cards are dead code")


# --- Stage 2 ---------------------------------------------------------------------------------------------------------


func test_the_cache_lich_ignores_a_power_it_already_knows() -> void:
	var state := _against(["cache-lich"])
	assert_int(int(_land(state, _bolts([3, 3, 3])).dealt)).is_equal(3)
	assert_array(_foe(state).cache).is_equal([3])
	assert_int(int(_land(state, _bolts([1, 2, 3, 4])).dealt)).is_equal(7)
	assert_array(_foe(state).cache).is_equal([4, 3, 2, 1])


func test_malloc_allocates_blocks_that_shield_her_and_runs_out_of_memory() -> void:
	var state := _against(["malloc-matron"])
	var malloc := _foe(state)
	_act(state, malloc, 0)
	assert_int((state.battle.foes as Array).size()).is_equal(2)
	assert_str(String(_foe(state, 1).id)).is_equal("heap-block")
	state.battle.turn = 2
	malloc.shield = 0
	ShardrunBattle.begin_turn(state.battle)
	assert_int(int(malloc.shield)).is_equal(3)
	for i in 4:
		_act(state, malloc, 0)
	assert_int(60 - int(state.integrity)).override_failure_message("Out of Memory: 6 per block").is_equal(30)
	assert_int(ProgramGuardians.minions_of(state.battle, malloc).size()).is_equal(0)


func test_freeing_a_block_gives_block_and_her_fall_frees_the_rest() -> void:
	var state := _against(["malloc-matron"])
	var malloc := _foe(state)
	_act(state, malloc, 0)
	_act(state, malloc, 0)
	var block := _foe(state, 1)
	_land(state, _bolts([int(block.hp) + 5], 1))
	assert_int(int(state.battle.block)).is_equal(3)
	malloc.hp = 1
	malloc.shield = 0
	_land(state, _bolts([5]))
	assert_bool((state.battle.foes as Array).all(func(foe: Dictionary) -> bool: return int(foe.hp) == 0)).is_true()


func test_a_bolt_at_a_page_swapped_out_is_a_page_fault() -> void:
	var state := _against(["page-fault-a", "page-fault-b", "page-fault-c"])
	var a := _foe(state, 0)
	var b := _foe(state, 1)
	assert_bool(a.resident).is_true()
	var hp := int(b.hp)
	var landed := _land(state, _bolts([5, 5], 1))
	assert_int(int(landed.dealt)).override_failure_message("the first faults, the second lands").is_equal(5)
	assert_int(hp - int(b.hp)).is_equal(5)
	assert_bool(b.resident).is_true()
	assert_bool(a.get("resident", false)).is_false()
	var before := int(state.integrity)
	_act(state, a, 0)
	assert_int(int(state.integrity)).override_failure_message("a swapped-out page cannot strike").is_equal(before)
	_end_turn(state)
	assert_bool(_foe(state, 2).resident).override_failure_message("the page out longest swaps in").is_true()


func test_the_thunk_defers_damage_until_a_big_bolt_forces_it() -> void:
	var state := _against(["thunk"])
	var thunk := _foe(state)
	var hp := int(thunk.hp)
	_land(state, _bolts([5, 5]))
	assert_int(int(thunk.hp)).is_equal(hp)
	assert_int(int(thunk.pending)).is_equal(10)
	var landed := _land(state, _bolts([6, 20]))
	assert_int(int(landed.dealt)).override_failure_message("(10 + 6 + 20) x 1.25").is_equal(45)
	assert_int(int(thunk.pending)).is_equal(0)
	_land(state, _bolts([9]))
	_end_turn(state)
	assert_int(int(thunk.pending)).is_equal(4)


# --- Stage 3 ---------------------------------------------------------------------------------------------------------


func test_the_call_stack_pops_only_its_top_frame_and_pushes_when_left_alone() -> void:
	var state := _against(["call-stack-colossus"])
	var stack := _foe(state)
	var frames: Array = stack.frames
	assert_int(frames.size()).is_equal(4)
	assert_int(int(stack.hp)).is_equal(ProgramGuardians.sum_of(frames))
	var top := int(frames[-1])
	var landed := _land(state, _bolts([top + 40]))
	assert_int(int(landed.dealt)).is_equal(top)
	assert_int(int(landed.wasted)).is_equal(40)
	assert_int((stack.frames as Array).size()).is_equal(3)
	_end_turn(state)
	assert_int((stack.frames as Array).size()).override_failure_message("a pop this turn: no push").is_equal(3)
	for i in 5:
		_end_turn(state)
	assert_int((stack.frames as Array).size()).override_failure_message("8 frames overflow to 4").is_equal(4)
	assert_int(60 - int(state.integrity)).is_equal(25)


func test_int_max_wraps_damage_past_a_signed_byte() -> void:
	var state := _against(["int-max"])
	var titan := _foe(state)
	titan.hp = int(titan.max) - 100
	var hp := int(titan.hp)
	assert_int(int(_land(state, _bolts([100])).dealt)).is_equal(100)
	_land(state, _bolts([200]))
	assert_int(int(titan.hp)).override_failure_message("200 wraps to -56: it heals").is_equal(hp - 100 + 56)


func test_int_max_counts_up_until_its_own_count_overflows() -> void:
	var state := _against(["int-max"])
	var titan := _foe(state)
	var hits: Array[int] = []
	for i in 4:
		var before := int(state.integrity)
		state.integrity = 200
		before = 200
		_act(state, titan, 0)
		hits.append(before - int(state.integrity))
	assert_array(hits).is_equal([16, 32, 64, 0])


func test_the_profiler_scales_damage_by_the_programs_slowest_class() -> void:
	var slow := _against(["profiler"])
	assert_int(int(_land(slow, _bolts([20]), {"speed": "quadratic"}).dealt)).is_equal(10)
	var quick := _against(["profiler"])
	assert_int(int(_land(quick, _bolts([20]), {"speed": "constant"}).dealt)).is_equal(30)


func test_the_livelock_twins_swap_on_every_hit() -> void:
	var state := _against(["livelock-a", "livelock-b"])
	var a := _foe(state, 0)
	var b := _foe(state, 1)
	var hp := int(a.hp)
	_land(state, _bolts([5, 5]))
	assert_int(hp - int(a.hp)).is_equal(5)
	assert_int(hp - int(b.hp)).override_failure_message("aim 0 hit the other twin after the swap").is_equal(5)
	b.hp = 3
	b.shield = 0
	_land(state, [{"power": 5, "element": "none", "foe": (state.battle.foes as Array).find(b)}] as Array[Dictionary])
	assert_bool(a.enraged).is_true()
	var before := int(state.integrity)
	_act(state, a, 0)
	assert_int(before - int(state.integrity)).is_equal(15)


# --- Stage 4 ---------------------------------------------------------------------------------------------------------


func test_the_mutator_mutates_cards_and_a_strong_program_kills_them() -> void:
	var state := _against(["mutator"])
	var mutator := _foe(state)
	_act(state, mutator, 1)
	var mutants: Dictionary = state.battle.mutants
	assert_int(mutants.size()).is_equal(2)
	var mutant: String = mutants.keys()[0]
	var card: Dictionary = catalog.shards[mutant]
	assert_str(ProgramGuardians.code_of(card, "python", state.battle)).is_not_equal(String(card.code.python))
	var hp := int(mutator.hp)
	_land(state, _bolts([30]), {"cards": [mutant], "speed": "linear"})
	assert_bool(mutants.has(mutant)).is_false()
	assert_int(hp - int(mutator.hp)).is_equal(40)


func test_karp_doubles_a_certificate_and_halves_a_volley_without_one() -> void:
	var state := _against(["karp"])
	var karp := _foe(state)
	assert_int(int(karp.target)).is_equal(23)
	assert_int(int(_land(state, _bolts([9, 14, 5])).dealt)).override_failure_message("(9 + 14) x 2 + 5").is_equal(51)
	assert_bool(karp.stunned).is_true()
	var none := _against(["karp"])
	assert_int(int(_land(none, _bolts([5, 5])).dealt)).is_equal(4)


func test_the_halting_oracle_reflects_a_program_it_predicted() -> void:
	var state := _against(["halting-oracle"])
	var oracle := _foe(state)
	assert_dict(oracle.prediction).is_equal({"check": "bolts-under", "value": 8})
	var hp := int(oracle.hp)
	var landed := _land(state, _bolts([10, 10, 10]), {"speed": "linear"})
	assert_int(int(landed.dealt)).is_equal(0)
	assert_int(int(oracle.hp)).is_equal(hp)
	assert_int(60 - int(state.integrity)).is_equal(15)
	var wrong := _against(["halting-oracle"])
	assert_int(int(_land(wrong, _bolts([2, 2, 2, 2, 2, 2, 2, 2])).dealt)).is_equal(16)


func test_the_root_compiler_compiles_the_guardians_this_run_beat() -> void:
	var options := {"seed": "finale", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.stats.guardians = [{"layer": 0, "foes": ["ouroboros"]}, {"layer": 1, "foes": ["cache-lich"]}]
	state.battle = ShardrunBattle.new_battle(state, "boss", [], catalog)
	var compiler: Dictionary = ShardrunBattle.foe_states(state, ["root-compiler"], "g", catalog)[0]
	state.battle.foes = [compiler]
	ShardrunBattle.begin_turn(state.battle)
	assert_str(String(compiler.trait.kind)).is_equal("loop-guard")
	assert_int(int(compiler.intents[0].power)).override_failure_message("Bite 7 x 1.5").is_equal(11)
	compiler.hp = floori(int(compiler.max) * 0.6)
	GuardianLanding.finish(state, state.battle, {"foes": {}, "dealt": {}, "reflected": {}}, {})
	assert_str(String(compiler.trait.kind)).is_equal("lru-cache")
	assert_bool(compiler.recompiling).is_true()
	compiler.hp = floori(int(compiler.max) * 0.3)
	GuardianLanding.finish(state, state.battle, {"foes": {}, "dealt": {}, "reflected": {}}, {})
	assert_dict(compiler.trait).is_empty()
	state.battle.last_work = 77
	compiler.intent_index = 0
	assert_int(ProgramRules.tempo_of(compiler, state, catalog)).override_failure_message("self-hosting").is_equal(77)


# --- The pool -------------------------------------------------------------------------------------------------------


func test_every_layer_has_a_pool_of_five_guardians_drawn_by_the_seed() -> void:
	var layers: Array = catalog.config.layers
	for layer: Dictionary in layers:
		var pool: Array = layer.encounters.boss
		assert_int(pool.size()).override_failure_message(layer.id).is_equal(5)
		for group: Array in pool:
			for id: String in group:
				assert_bool(catalog.foes.has(id)).override_failure_message(id).is_true()
	var met := {}
	for i in 60:
		var boss := {"id": ShardrunMap.boss_id(0), "kind": "boss"}
		met[str(ShardrunRules.encounter_for("seed-%d" % i, boss, layers[0]))] = true
	assert_int(met.size()).override_failure_message("different runs meet different guardians").is_equal(5)


func test_a_beaten_guardian_is_remembered_for_the_finale() -> void:
	var state := _against(["ouroboros"])
	_foe(state).hp = 1
	_land(state, _bolts([9]))
	ShardrunBattle.win(state, state.battle, catalog)
	assert_array(state.stats.guardians).is_equal([{"layer": 0, "foes": ["ouroboros"]}])


func test_a_mutant_changes_one_operator_of_a_cards_code() -> void:
	var code := "def f(bolts, battle):\n    # a > b in a comment stays\n    return [b for b in bolts if b > 3]\n"
	var mutant := ProgramMutants.mutate(code, "python", 2)
	assert_str(String(mutant.name)).is_equal("> becomes >=")
	assert_int(int(mutant.line)).is_equal(2)
	assert_str(String(mutant.after)).contains("b >= 3")
	assert_str(String(mutant.code)).contains("# a > b in a comment stays")
	assert_dict(ProgramMutants.mutate("def f(bolts):\n    return bolts\n", "python", 0)).is_empty()


func test_a_subset_that_sums_to_the_target_is_found_and_none_is_not_invented() -> void:
	var values: Array[int] = [9, 12, 16, 4]
	var picked := GuardianLanding.subset_sum(values, 37)
	var total := 0
	for at: int in picked:
		total += values[at]
	assert_int(total).is_equal(37)
	assert_array(GuardianLanding.subset_sum(values, 3)).is_empty()


func test_the_mutator_only_draws_mutants_the_census_found_to_run() -> void:
	var census: Dictionary = catalog.programs.mutants
	for language: String in ["python", "javascript"]:
		assert_bool(census.has(language)).override_failure_message(language).is_true()
		for id: String in census[language]:
			var code := String(catalog.shards[id].code[language])
			for op: int in census[language][id]:
				assert_int(int(ProgramMutants.mutate(code, language, op).op)).is_equal(op)
	var state := _against(["mutator"])
	_act(state, _foe(state), 1)
	for id: String in state.battle.mutants:
		assert_array(ProgramGuardians.safe_mutants(id, "python", catalog)).contains([state.battle.mutants[id].op])
