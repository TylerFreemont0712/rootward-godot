extends GdUnitTestSuite
## Scripts (ProgramScripts): the belt, the drops, and what each of the sixteen commands does to a fight.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramCatalogs.without_initiative(ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog))


func _fight(foes := ["tally-wisp", "null-wraith"], hp := 30) -> Dictionary:
	var options := {"seed": "scripts", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.erase("draft")
	state.paradigm = "greedy"
	state.deck = ["salvo", "salvo", "fork", "amplify", "ward", "ward", "round-robin", "kindle", "sweep", "take-max"]
	var states := ShardrunBattle.foe_states(state, foes, "scripts", catalog)
	for foe: Dictionary in states:
		foe.hp = hp
		foe.max = hp
		foe.shield = 0
	ShardrunBattle.start_with(state, "fight", states, catalog)
	state.battle.mana = 20
	return state


func _use(state: Dictionary, id: String, target := "") -> Dictionary:
	state.belt = [id]
	var result := ProgramScripts.use(state, 0, target, catalog)
	assert_bool(result.is_empty()).override_failure_message("%s: %s" % [id, result]).is_true()
	return state


func test_the_belt_holds_three_and_a_script_can_be_dropped() -> void:
	var state := _fight()
	for id: String in ["touch", "print", "ulimit"]:
		assert_bool(ProgramScripts.give(state, id, catalog)).is_true()
	assert_bool(ProgramScripts.give(state, "sudo", catalog)).is_false()
	assert_bool(ProgramScripts.drop_at(state, 1)).is_true()
	assert_array(state.belt).is_equal(["touch", "ulimit"])


func test_every_script_in_the_content_is_known_to_the_rules() -> void:
	var state := _fight()
	state.integrity = 20
	for id: String in catalog.programs.scripts:
		var script: Dictionary = catalog.programs.scripts[id]
		var foe := String(state.battle.foes[0].uid) if script.target == "foe" else ""
		var copy := state.duplicate(true)
		copy.belt = [id]
		var result := ProgramScripts.use(copy, 0, foe, catalog)
		assert_bool(result.is_empty()).override_failure_message("%s: %s" % [id, result]).is_true()
		assert_array(copy.belt).is_empty()


func test_hotfix_heals_in_or_out_of_a_fight() -> void:
	var state := _fight()
	state.integrity = 20
	_use(state, "hotfix-sh")
	assert_int(int(state.integrity)).is_equal(30)
	state.erase("battle")
	state.status = "map"
	state.belt = ["hotfix-sh"]
	assert_bool(ProgramScripts.use(state, 0, "", catalog).is_empty()).is_true()
	assert_int(int(state.integrity)).is_equal(40)


func test_a_fight_script_is_refused_on_the_map() -> void:
	var state := _fight()
	state.erase("battle")
	state.status = "map"
	state.belt = ["sudo"]
	assert_str(ProgramScripts.use(state, 0, "", catalog).code).is_equal("not-in-battle")
	assert_array(state.belt).is_equal(["sudo"])


func test_touch_puts_a_free_literal_in_hand() -> void:
	var state := _use(_fight(), "touch")
	assert_array(state.battle.hand).contains(["literal"])
	assert_int(ProgramRelics.cost(state, ["literal"], catalog)).is_equal(0)
	assert_int(ProgramRelics.cost(state, ["literal", "literal"], catalog)).is_equal(1)


func test_cache_warm_draws_three_cards() -> void:
	var state := _fight()
	var before := (state.battle.hand as Array).size()
	_use(state, "cache-warm")
	assert_int((state.battle.hand as Array).size()).is_equal(before + 3)


func test_ulimit_halves_the_targets_next_attack_once() -> void:
	var state := _fight(["tally-wisp"])
	var foe: Dictionary = state.battle.foes[0]
	_use(state, "ulimit", foe.uid)
	state.battle.block = 0
	var before := int(state.integrity)
	ShardrunBattle.hit_maintainer(state, state.battle, foe, 10)
	assert_int(before - int(state.integrity)).is_equal(5)
	foe.erase("ulimit")
	ShardrunBattle.hit_maintainer(state, state.battle, foe, 10)
	assert_int(before - int(state.integrity)).is_equal(15)


func test_kill_9_deals_25_straight_to_one_foe_and_can_win_the_fight() -> void:
	var state := _fight(["tally-wisp"], 20)
	var foe: Dictionary = state.battle.foes[0]
	foe.shield = 50
	_use(state, "kill-9", foe.uid)
	assert_str(state.status).is_equal("reward")


func test_strace_switches_a_trait_off_until_the_next_turn() -> void:
	var state := _fight(["regex-sphinx"])
	var foe: Dictionary = state.battle.foes[0]
	assert_bool(foe.has("trait")).is_true()
	_use(state, "strace", foe.uid)
	assert_bool(foe.has("trait")).is_false()
	ProgramScripts.new_turn(state.battle)
	assert_bool(foe.has("trait")).is_true()


func test_sudo_doubles_the_next_program_and_only_the_next() -> void:
	var state := _fight(["tally-wisp"], 100)
	state.spells[0].shards = ["amplify"]
	var outcome := {"ok": true, "bolts": [{"power": 10, "element": "none"}], "work": [{"shard": "amplify", "given": 1}]}
	var plain := ProgramRules.play(
		state.duplicate(true), state.duplicate(true).battle, state.spells[0], outcome, catalog, true
	)
	_use(state, "sudo")
	assert_bool(state.battle.double_next).is_true()
	var doubled := ProgramRules.play(state, state.battle, state.spells[0], outcome, catalog, true)
	assert_int(int(doubled.landed.dealt)).is_greater(int(plain.landed.dealt))
	assert_bool(state.battle.has("double_next")).is_false()


func test_nice_counts_the_program_as_no_work_and_wears_off() -> void:
	var state := _fight()
	var trace := [{"shard": "amplify", "given": 50}]
	var normal := ProgramRules.total_work(ProgramRules.stages(state, trace, catalog))
	assert_int(normal).is_greater(0)
	_use(state, "nice")
	assert_int(ProgramRules.total_work(ProgramRules.stages(state, trace, catalog))).is_equal(0)
	ProgramScripts.new_turn(state.battle)
	assert_int(ProgramRules.total_work(ProgramRules.stages(state, trace, catalog))).is_equal(normal)


func test_make_divides_this_turns_work_by_four() -> void:
	var state := _fight()
	var trace := [{"shard": "amplify", "given": 80}]
	var normal := ProgramRules.total_work(ProgramRules.stages(state, trace, catalog))
	_use(state, "make-j8")
	assert_int(ProgramRules.total_work(ProgramRules.stages(state, trace, catalog))).is_equal(normal / 4)


func test_chmod_makes_the_next_program_free() -> void:
	var state := _fight()
	assert_int(ProgramRelics.cost(state, ["fork", "fork"], catalog)).is_greater(0)
	_use(state, "chmod-x")
	assert_int(ProgramRelics.cost(state, ["fork", "fork"], catalog)).is_equal(0)


func test_git_stash_sets_the_hand_aside_and_it_returns_on_top() -> void:
	var state := _fight()
	var hand: Array = (state.battle.hand as Array).duplicate()
	_use(state, "git-stash")
	assert_array(state.battle.hand).is_empty()
	state.battle.hand = ["salvo"]
	ProgramScripts.restore_hand(state.battle)
	assert_array(state.battle.hand).is_equal(hand + ["salvo"])


func test_git_revert_undoes_last_turns_damage_up_to_fifteen() -> void:
	var state := _fight()
	state.battle.hurt_turn = 22
	ProgramScripts.new_turn(state.battle)
	state.integrity = 10
	_use(state, "git-revert")
	assert_int(int(state.integrity)).is_equal(25)


func test_gc_collect_depends_on_the_paradigm() -> void:
	var other := _fight()
	_use(other, "gc-collect")
	assert_int(int(other.battle.block)).is_equal(10)
	var search := _fight()
	search.paradigm = "search-index"
	search.battle.index = [{"power": 4, "element": "none"}, {"power": 9, "element": "none"}]
	_use(search, "gc-collect")
	assert_array(search.battle.index).is_empty()
	assert_int((search.battle.gc_seed as Array).size()).is_equal(2)
	var dynamic := _fight()
	dynamic.paradigm = "dynamic"
	dynamic.battle.dp = [12, 30, 18]
	_use(dynamic, "gc-collect")
	assert_array(dynamic.battle.dp).is_equal([12, 30, 18, 30])


func test_rm_rf_sets_curses_aside_for_the_fight() -> void:
	var state := _fight()
	state.relics = ["blood-contract"]
	assert_bool(ProgramRelics.modifiers(state, catalog) != {}).is_true()
	var base := ShardrunRules.relic_modifiers(state, catalog)
	_use(state, "rm-rf-build")
	assert_bool(state.battle.no_curses).is_true()
	assert_int(int(ProgramRelics.modifiers(state, catalog).seed_power)).is_equal(0)
	assert_dict(base).is_not_empty()


func test_pip_install_adds_a_free_card_of_your_paradigm() -> void:
	var state := _use(_fight(), "pip-install")
	var added: String = (state.battle.hand as Array).back()
	assert_str(catalog.shards[added].paradigm).is_equal("greedy")
	assert_int(ProgramRelics.cost(state, [added], catalog)).is_equal(0)


func test_print_writes_each_foes_next_two_moves_in_the_log() -> void:
	var state := _fight()
	state.log = []
	_use(state, "print")
	assert_int((state.log as Array).size()).is_greater_equal(3)


func test_a_guardian_always_leaves_a_script_and_an_elite_usually_does() -> void:
	var state := _fight()
	assert_str(ProgramScripts.fight_drop(state, "boss", catalog)).is_not_empty()
	var elites := 0
	for n in 100:
		state.seed = "drop-%d" % n
		if ProgramScripts.fight_drop(state, "elite", catalog) != "":
			elites += 1
	assert_int(elites).is_between(40, 80)


func test_fights_drop_a_script_about_three_times_in_ten_and_pity_makes_the_next_likelier() -> void:
	var state := _fight()
	var drops := 0
	for n in 300:
		state.seed = "fight-%d" % n
		state.script_pity = 0.0
		if ProgramScripts.fight_drop(state, "fight", catalog) != "":
			drops += 1
	assert_int(drops).is_between(60, 130)
	state.script_pity = 0.0
	var seed := "pity"
	for n in 200:
		state.seed = "%s-%d" % [seed, n]
		if ProgramScripts.fight_drop(state, "fight", catalog) == "":
			assert_float(float(state.script_pity)).is_greater(0.0)
			return
	fail("every fight dropped a script")
