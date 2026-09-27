extends GdUnitTestSuite
## What program relics do (ProgramRelics), each effect on its own: a relic made for the test, held by a run in a fight
## against two known foes, and the rules' own cast and preview.

var base: Dictionary


func before() -> void:
	base = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


## The catalog with one more relic, `test`, doing `effects`.
func _with(effects: Array) -> Dictionary:
	var catalog := base.duplicate()
	catalog.relics = (base.relics as Dictionary).duplicate()
	catalog.relics["test"] = {"id": "test", "name": "Test", "tier": "common", "summary": "", "effects": effects}
	return catalog


func _step(state: Dictionary, command: Dictionary, catalog: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	assert_bool(result.ok).override_failure_message(str(result.get("error", ""))).is_true()
	return result.state if result.ok else state


## A fight against a quick imp (20 HP, tempo 16) and a slow golem (30 HP, tempo 256), holding the test relic.
func _fight(catalog: Dictionary) -> Dictionary:
	var state := Shardrun.start(
		catalog, {"seed": "relic-test", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	)
	state = _step(state, {"type": "pick-paradigm", "paradigm_id": state.draft.offers[0]}, catalog)
	while state.status == "draft":
		state = _step(state, {"type": "draft-card", "card_id": state.draft.pack[0]}, catalog)
	var fights := ShardrunMap.next_rooms(state.map, state.position).filter(
		func(node: Dictionary) -> bool: return node.kind == "fight"
	)
	state = _step(state, {"type": "enter", "node_id": (fights[0] as Dictionary).id}, catalog)
	var template: Dictionary = state.battle.foes[0]
	var foes: Array = []
	for pair: Array in [["race-condition-imp", 20], ["deadlock-golem", 30]]:
		var foe := template.duplicate(true)
		foe.id = pair[0]
		foe.uid = "f-%s" % pair[0]
		foe.name = pair[0]
		foe.hp = pair[1]
		foe.max = pair[1]
		foe.weak = ["frost"]
		foe.resist = []
		foe.erase("trait")
		foe.intents = [{"kind": "strike", "power": 5}]
		foe.intent_index = 0
		foes.append(foe)
	state.battle.foes = foes
	state.battle.mana = 9
	state.battle.block = 0
	state.relics = ["test"]
	return state


func _cast(state: Dictionary, cards: Array, bolts: Array, work: Array, catalog: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next.spells[0].shards = cards
	var outcome := {"ok": true, "bolts": bolts, "work": work}
	return _step(next, {"type": "cast", "spell_id": next.spells[0].id, "outcome": outcome}, catalog)


func _hp(state: Dictionary) -> Array:
	return (state.battle.foes as Array).map(func(foe: Dictionary) -> int: return int(foe.hp))


func _work(card: String, n := 3) -> Array:
	return [{"shard": card, "given": n, "returned": n}]


func test_seed_relics_feed_the_program_more_input() -> void:
	var catalog := _with([{"kind": "seed-bolts", "count": 2, "power": 5}, {"kind": "seed-power", "add": 1}])
	var seed := ProgramRules.seed(_fight(catalog), catalog)
	assert_array(seed.map(func(bolt: Dictionary) -> int: return int(bolt.power))).is_equal([4, 4, 4, 6, 6])


func test_the_first_turn_of_a_fight_can_start_with_more_mana() -> void:
	var catalog := _with([{"kind": "first-turn-mana", "add": 2}])
	var state := Shardrun.start(
		catalog, {"seed": "relic-test", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	)
	state = _step(state, {"type": "pick-paradigm", "paradigm_id": state.draft.offers[0]}, catalog)
	while state.status == "draft":
		state = _step(state, {"type": "draft-card", "card_id": state.draft.pack[0]}, catalog)
	state.relics = ["test"]
	var fights := ShardrunMap.next_rooms(state.map, state.position).filter(
		func(node: Dictionary) -> bool: return node.kind == "fight"
	)
	var fought := _step(state, {"type": "enter", "node_id": (fights[0] as Dictionary).id}, catalog)
	assert_int(int(fought.battle.mana)).is_equal(ShardrunRules.mana_per_turn(fought, catalog) + 2)


func test_costs_bend_to_roles_repeats_and_schedules() -> void:
	var state := _fight(base)
	var spell := {"shards": ["merge-sort", "salvo", "salvo"]}
	assert_int(ProgramRules.cost_of(state, spell, base)).is_equal(3)
	var free_order := _with([{"kind": "role-cost", "role": "order", "cost": 0}])
	assert_int(ProgramRules.cost_of(_fight(free_order), spell, free_order)).is_equal(2)
	var dry := _with([{"kind": "duplicate-free"}])
	assert_int(ProgramRules.cost_of(_fight(dry), spell, dry)).is_equal(2)
	var cron := _with([{"kind": "cron", "every": 3}])
	var third := _fight(cron)
	third.battle.turn = 3
	assert_int(ProgramRules.cost_of(third, spell, cron)).is_equal(0)
	third.battle.turn = 4
	assert_int(ProgramRules.cost_of(third, spell, cron)).is_equal(3)


func test_work_bends_to_relics_and_worst_cases() -> void:
	var trace := [{"shard": "merge-sort", "given": 8, "returned": 8}, {"shard": "pairwise", "given": 8, "returned": 8}]
	var plain := ProgramRules.stages(_fight(base), trace, base)
	assert_array(plain.map(func(stage: Dictionary) -> int: return int(stage.work))).is_equal([26, 64])
	var profiler := _with([{"kind": "free-first-work"}])
	var first_free := ProgramRules.stages(_fight(profiler), trace, profiler)
	assert_array(first_free.map(func(stage: Dictionary) -> int: return int(stage.work))).is_equal([0, 64])
	var halved := _with([{"kind": "work-factor", "factor": 0.5}])
	var half := ProgramRules.stages(_fight(halved), trace, halved)
	assert_array(half.map(func(stage: Dictionary) -> int: return int(stage.work))).is_equal([13, 32])
	var radix := _with([{"kind": "role-complexity", "role": "order", "complexity": "linear"}])
	assert_int(int(ProgramRules.stages(_fight(radix), trace, radix)[0].work)).is_equal(8)
	var jit := _with([{"kind": "jit"}])
	var compiled := _fight(jit)
	compiled.battle.ran = ["pairwise"]
	assert_int(int(ProgramRules.stages(compiled, trace, jit)[1].work)).is_equal(0)


func test_a_card_can_run_at_its_worst_case_on_the_input_it_is_given() -> void:
	var catalog := base.duplicate()
	catalog.shards = (base.shards as Dictionary).duplicate()
	var quick := (catalog.shards["merge-sort"] as Dictionary).duplicate()
	quick.worst_case = {"input": "sorted", "complexity": "quadratic"}
	catalog.shards["merge-sort"] = quick
	var state := _fight(catalog)
	# The seed is sorted: the first sort meets its worst case; after Salvo the volley is unsorted, and it does not.
	var on_seed := ProgramRules.stages(state, [{"shard": "merge-sort", "given": 8, "returned": 8}], catalog)
	assert_int(int(on_seed[0].work)).is_equal(64)
	var after := [{"shard": "salvo", "given": 3, "returned": 9}, {"shard": "merge-sort", "given": 9, "returned": 9}]
	var expected := ProgramRules.work_units("linearithmic", 9)
	assert_int(int(ProgramRules.stages(state, after, catalog)[1].work)).is_equal(expected)


func test_tempo_and_budget_bend_to_relics() -> void:
	var catalog := _with(
		[{"kind": "tempo", "add": 20}, {"kind": "budget", "add": 904}, {"kind": "budget-factor", "factor": 0.5}]
	)
	var state := _fight(catalog)
	var imp: Dictionary = state.battle.foes[0]
	assert_int(ProgramRules.tempo_of(imp, state, catalog)).is_equal(ProgramRules.tempo_of(imp, state, base) + 20)
	assert_int(ProgramRules.budget(state, catalog)).is_equal((4096 + 904) / 2)


func test_landing_relics_weigh_the_bolts() -> void:
	# Elemental bolts +2; a volley that lands sorted +1 each.
	var catalog := _with([{"kind": "element-power", "add": 2}, {"kind": "sorted-landing", "add": 1}])
	var bolts := [{"power": 3, "element": "none", "foe": 1}, {"power": 4, "element": "fire", "foe": 1}]
	var cast := _cast(_fight(catalog), ["salvo"], bolts, _work("salvo"), catalog)
	assert_int(_hp(cast)[1]).is_equal(30 - (3 + 1) - (4 + 2 + 1))


func test_an_echo_lands_the_volley_twice() -> void:
	var catalog := _with([{"kind": "echo"}])
	var cast := _cast(_fight(catalog), ["salvo"], [{"power": 5, "element": "none", "foe": 1}], _work("salvo"), catalog)
	assert_int(_hp(cast)[1]).is_equal(20)


func test_program_factors_reward_small_full_fast_and_single_element_programs() -> void:
	var bolts := [{"power": 10, "element": "none", "foe": 1}]
	var small := _with([{"kind": "small-program", "max_cards": 2, "factor": 2.0}])
	assert_int(_hp(_cast(_fight(small), ["salvo"], bolts, _work("salvo"), small))[1]).is_equal(10)
	var two_cards := ["salvo", "amplify", "fork"]
	var big_work := [{"shard": "salvo", "given": 3, "returned": 3}]
	big_work.append({"shard": "amplify", "given": 3, "returned": 3})
	big_work.append({"shard": "fork", "given": 3, "returned": 3})
	assert_int(_hp(_cast(_fight(small), two_cards, bolts, big_work, small))[1]).is_equal(20)
	var full := _with([{"kind": "full-program", "factor": 1.5}])
	var state := _fight(full)
	state.spells[0].capacity = 1
	assert_int(_hp(_cast(state, ["salvo"], bolts, _work("salvo"), full))[1]).is_equal(15)
	var fast := _with([{"kind": "fast-program", "complexity": "linear", "factor": 1.5}])
	assert_int(_hp(_cast(_fight(fast), ["salvo"], bolts, _work("salvo"), fast))[1]).is_equal(15)
	var sorted_work := [{"shard": "merge-sort", "given": 3, "returned": 3}]
	assert_int(_hp(_cast(_fight(fast), ["merge-sort"], bolts, sorted_work, fast))[1]).is_equal(20)
	var mono := _with([{"kind": "mono-element", "factor": 2.0}])
	var frost := [{"power": 5, "element": "fire", "foe": 1}, {"power": 5, "element": "fire", "foe": 1}]
	assert_int(_hp(_cast(_fight(mono), ["salvo"], frost, _work("salvo"), mono))[1]).is_equal(10)


func test_the_strongest_bolt_and_out_sped_foes_take_more() -> void:
	var hot := _with([{"kind": "strongest-mult", "factor": 2.0}])
	var bolts := [{"power": 4, "element": "none", "foe": 1}, {"power": 6, "element": "none", "foe": 1}]
	assert_int(_hp(_cast(_fight(hot), ["salvo"], bolts, _work("salvo"), hot))[1]).is_equal(30 - 4 - 12)
	# A 3-op program out-speeds both foes; a 64-op one is slower than the imp (tempo 16) but not the golem.
	var first := _with([{"kind": "initiative", "factor": 1.5}])
	var both := [{"power": 10, "element": "none", "foe": 0}, {"power": 10, "element": "none", "foe": 1}]
	assert_array(_hp(_cast(_fight(first), ["salvo"], both, _work("salvo"), first))).is_equal([5, 15])
	var slow := [{"shard": "pairwise", "given": 8, "returned": 8}]
	assert_array(_hp(_cast(_fight(first), ["pairwise"], both, slow, first))).is_equal([10, 15])


func test_every_bolt_can_count_as_each_foes_weakness() -> void:
	var catalog := _with([{"kind": "all-elements"}])
	var cast := _cast(_fight(catalog), ["salvo"], [{"power": 10, "element": "none", "foe": 1}], _work("salvo"), catalog)
	assert_int(_hp(cast)[1]).is_equal(15)


func test_overkill_can_flow_on_and_waste_can_become_block() -> void:
	var flows := _with([{"kind": "overkill-flows"}])
	var cast := _cast(_fight(flows), ["salvo"], [{"power": 26, "element": "none", "foe": 0}], _work("salvo"), flows)
	assert_array(_hp(cast)).is_equal([0, 24])
	assert_int(int(cast.stats.damage)).is_equal(26)
	var lazy := _with([{"kind": "wasted-to-block", "fraction": 1.0}])
	var wasted := _cast(_fight(lazy), ["salvo"], [{"power": 26, "element": "none", "foe": 0}], _work("salvo"), lazy)
	var wards := (wasted.log as Array).filter(func(entry: Dictionary) -> bool: return entry.kind == "ward")
	assert_int(int(wards[0].amount)).is_equal(6)


func test_after_a_cast_kills_pay_mana_and_integrity_and_lines_pay_block() -> void:
	var catalog := _with(
		[
			{"kind": "kill-mana", "amount": 1, "max": 2},
			{"kind": "kill-heal", "amount": 4},
			{"kind": "block-per-card", "amount": 2},
		]
	)
	var state := _fight(catalog)
	state.integrity = 40
	var cast := _cast(
		state, ["salvo", "amplify"], [{"power": 20, "element": "none", "foe": 0}], _work("salvo"), catalog
	)
	# The imp fell: 4 Integrity back (before the golem's strike of 5, into 4 block from two cards), 1 more mana next turn.
	assert_int(int(cast.integrity)).is_equal(40 + 4 - (5 - 4))
	assert_int(int(cast.battle.mana)).is_equal(ShardrunRules.mana_per_turn(cast, catalog) + 1)


func test_the_preview_says_what_a_relic_will_do() -> void:
	var catalog := _with([{"kind": "strongest-mult", "factor": 2.0}, {"kind": "overkill-flows"}])
	var state := _fight(catalog)
	var bolts := [{"power": 15, "element": "none", "foe": 0}, {"power": 4, "element": "none", "foe": 1}]
	var outcome := {"ok": true, "bolts": bolts, "work": _work("salvo")}
	state.spells[0].shards = ["salvo"]
	var preview := ShardrunBattle.preview_cast(state, state.spells[0].id, outcome, catalog)
	var cast := _cast(state, ["salvo"], bolts, outcome.work, catalog)
	assert_int(int(preview.damage)).is_equal(50 - _hp(cast)[0] - _hp(cast)[1])
	assert_int(int(preview.kills)).is_equal(1)
