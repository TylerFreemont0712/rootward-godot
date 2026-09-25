extends GdUnitTestSuite
## The Shardrun's programs (ADR-0012): the draft, work by complexity class, foe tempo, the budget, and the resolver.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _step(state: Dictionary, command: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	assert_bool(result.ok).override_failure_message(str(result.get("error", ""))).is_true()
	return result.state if result.ok else state


func _start(seed := "program-test") -> Dictionary:
	var options := {"seed": seed, "language": "python", "difficulty": "beginner", "playstyle": "program"}
	return Shardrun.start(catalog, options)


func _drafted(seed := "program-test") -> Dictionary:
	var state := _step(_start(seed), {"type": "pick-paradigm", "paradigm_id": _start(seed).draft.offers[0]})
	while state.status == "draft":
		state = _step(state, {"type": "draft-card", "card_id": state.draft.pack[0]})
	return state


## A fight against two known foes: a quick imp (tempo 16) at the front and a slow golem (tempo 256) behind it.
func _fight() -> Dictionary:
	var state := _drafted()
	var fights := ShardrunMap.next_rooms(state.map, state.position).filter(
		func(node: Dictionary) -> bool: return node.kind == "fight"
	)
	state = _step(state, {"type": "enter", "node_id": (fights[0] as Dictionary).id})
	var battle: Dictionary = state.battle
	var template: Dictionary = battle.foes[0]
	var foes: Array = []
	for pair: Array in [["race-condition-imp", 20], ["deadlock-golem", 30]]:
		var foe := template.duplicate(true)
		foe.id = pair[0]
		foe.uid = "f-%s" % pair[0]
		foe.name = pair[0]
		foe.hp = pair[1]
		foe.max = pair[1]
		foe.weak = []
		foe.resist = []
		foe.erase("trait")
		foe.intents = [{"kind": "strike", "power": 5}]
		foe.intent_index = 0
		foes.append(foe)
	battle.foes = foes
	battle.mana = 9
	battle.block = 0
	return state


func _cast(state: Dictionary, cards: Array, bolts: Array, work: Array) -> Dictionary:
	var next := state.duplicate(true)
	next.spells[0].shards = cards
	var outcome := {"ok": true, "bolts": bolts, "work": work}
	return _step(next, {"type": "cast", "spell_id": next.spells[0].id, "outcome": outcome})


func _kinds(state: Dictionary) -> Array:
	return (state.log as Array).map(func(entry: Dictionary) -> String: return entry.kind)


func test_work_follows_the_complexity_class() -> void:
	assert_int(ProgramRules.work_units("constant", 50)).is_equal(1)
	assert_int(ProgramRules.work_units("logarithmic", 7)).is_equal(3)
	assert_int(ProgramRules.work_units("linear", 8)).is_equal(8)
	assert_int(ProgramRules.work_units("linearithmic", 8)).is_equal(26)
	assert_int(ProgramRules.work_units("quadratic", 8)).is_equal(64)
	assert_int(ProgramRules.work_units("exponential", 8)).is_equal(256)
	assert_int(ProgramRules.work_units("exponential", 40, 12)).is_equal(4096)
	assert_int(ProgramRules.work_units("exponential", 40)).is_equal(ProgramRules.WORK_CAP)
	assert_int(ProgramRules.work_units("pseudo", 5, 0, 40)).is_equal(200)


func test_a_stage_is_as_big_as_the_larger_of_its_input_and_output() -> void:
	var state := _fight()
	var trace := [{"shard": "salvo", "given": 1, "returned": 7}, {"shard": "merge-sort", "given": 7, "returned": 7}]
	var stages := ProgramRules.stages(state, trace, catalog)
	assert_int(stages[0].n).is_equal(7)
	assert_int(stages[0].work).is_equal(7)
	assert_int(stages[1].work).is_equal(ProgramRules.work_units("linearithmic", 7))
	assert_str(ProgramRules.speed_label(["salvo", "merge-sort"], catalog)).is_equal("O(n log n)")


func test_the_draft_offers_paradigms_then_packs_from_the_seed() -> void:
	var state := _start()
	assert_str(state.status).is_equal("draft")
	assert_str(state.playstyle).is_equal("program")
	assert_int((state.draft.offers as Array).size()).is_equal(3)
	assert_array(state.deck).is_equal(ProgramRules.config_of(catalog).basics)
	assert_array(_start().draft.offers).is_equal(state.draft.offers)
	var refused := Shardrun.step(state, {"type": "pick-paradigm", "paradigm_id": "nowhere"}, catalog)
	assert_bool(refused.ok).is_false()
	var paradigm_id: String = state.draft.offers[0]
	state = _step(state, {"type": "pick-paradigm", "paradigm_id": paradigm_id})
	var signature: Array = ProgramDraft.paradigm_of(catalog, paradigm_id).signature
	for card_id: String in signature:
		assert_array(state.deck).contains([card_id])
	assert_int((state.draft.pack as Array).size()).is_equal(3)
	var drafted := _drafted()
	assert_str(drafted.status).is_equal("map")
	assert_bool(drafted.has("draft")).is_false()
	assert_int((drafted.deck as Array).size()).is_equal(8 + signature.size() + 5)


func test_a_slow_program_lets_faster_foes_act_first_and_only_once() -> void:
	var state := _fight()
	# 40 linear work: the imp (16) is faster, the golem (256) is not.
	var cast := _cast(
		state, ["salvo"], [{"power": 4, "element": "none"}], [{"shard": "salvo", "given": 1, "returned": 40}]
	)
	var kinds := _kinds(cast)
	assert_int(kinds.find("tempo")).is_less(kinds.find("cast"))
	assert_int(cast.integrity).is_equal(int(state.integrity) - 5)
	assert_array(cast.battle.acted).is_equal(["f-race-condition-imp"])
	var ended := _step(cast, {"type": "end-turn"})
	# The golem strikes at the end of the turn; the imp does not strike again.
	assert_int(ended.integrity).is_equal(int(state.integrity) - 10)
	assert_array(ended.battle.acted).is_empty()


func test_a_fast_program_lands_before_anyone_moves() -> void:
	var state := _fight()
	var cast := _cast(
		state, ["salvo"], [{"power": 20, "element": "none"}], [{"shard": "salvo", "given": 1, "returned": 6}]
	)
	assert_bool(_kinds(cast).has("tempo")).is_false()
	assert_int(cast.integrity).is_equal(int(state.integrity))
	assert_int(cast.battle.foes[0].hp).is_equal(0)


func test_a_program_over_budget_times_out() -> void:
	var state := _fight()
	var work := [{"shard": "pairwise", "given": 128, "returned": 128}]
	var cast := _cast(state, ["pairwise"], [{"power": 99, "element": "none"}], work)
	assert_bool(_kinds(cast).has("timeout")).is_true()
	assert_int(cast.battle.foes[0].hp).is_equal(20)
	assert_int(cast.battle.foes[1].hp).is_equal(30)


func test_bolts_fly_where_they_are_aimed_and_overkill_is_wasted() -> void:
	var state := _fight()
	var bolts := [
		{"power": 25, "element": "none", "foe": 0},
		{"power": 10, "element": "none", "foe": 1},
		{"power": 3, "element": "none", "foe": 0},
		{"power": 4, "element": "none", "block": true},
	]
	var cast := _cast(state, ["round-robin"], bolts, [{"shard": "round-robin", "given": 4, "returned": 4}])
	assert_int(cast.battle.foes[0].hp).is_equal(0)
	assert_int(cast.battle.foes[1].hp).is_equal(20)
	assert_int(cast.battle.block).is_equal(4)
	var kinds := _kinds(cast)
	assert_bool(kinds.has("wasted")).is_true()
	assert_int(cast.stats.damage).is_equal(30)


func test_the_preview_is_what_the_cast_does() -> void:
	var state := _fight()
	var bolts := [{"power": 12, "element": "none", "foe": 1}, {"power": 30, "element": "none"}]
	var outcome := {"ok": true, "bolts": bolts, "work": [{"shard": "salvo", "given": 1, "returned": 2}]}
	state.spells[0].shards = ["salvo"]
	var preview := ShardrunBattle.preview_cast(state, state.spells[0].id, outcome, catalog)
	var cast := _cast(state, ["salvo"], bolts, outcome.work)
	var dealt := 50 - int(cast.battle.foes[0].hp) - int(cast.battle.foes[1].hp)
	assert_int(preview.damage).is_equal(dealt)
	assert_int(preview.kills).is_equal(1)
	assert_int(preview.wasted).is_equal(10)
	assert_int(preview.cost).is_equal(int(catalog.shards.salvo.cost))


func test_lint_warns_when_a_sorted_card_follows_an_unsorted_one() -> void:
	assert_array(ProgramRules.lint(["salvo", "merge-sort", "binary-execute"], catalog)).is_empty()
	var warnings := ProgramRules.lint(["salvo", "binary-execute"], catalog)
	assert_int(warnings.size()).is_equal(1)
	assert_int(warnings[0].index).is_equal(1)


func test_a_program_run_never_binds_a_second_program() -> void:
	var state := _drafted()
	assert_bool(ShardrunRules.bindable_spell(state, catalog, true).is_empty()).is_true()
