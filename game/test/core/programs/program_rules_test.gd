extends GdUnitTestSuite
## The Shardrun's programs (ADR-0012): the draft, work by complexity class, foe tempo, the budget, and the resolver.

var catalog: Dictionary
## The content's own, Initiative included.
var content: Dictionary


func before() -> void:
	content = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	catalog = ProgramCatalogs.without_initiative(content)


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


func test_the_four_ring_looks_preserve_layer_ids_and_full_routes() -> void:
	var base: Dictionary = ContentLoader.load_shardrun().catalog
	var rings: Array = content.config.layers
	assert_int(rings.size()).is_equal(4)
	assert_array(rings.map(func(layer: Dictionary) -> int: return layer.ring)).is_equal([3, 2, 1, 0])
	(
		assert_array(rings.map(func(layer: Dictionary) -> String: return layer.id))
		. is_equal(["salvage", "heap", "kernel", "root"])
	)
	for index in (base.config.layers as Array).size():
		assert_int(rings[index].rows).is_equal(base.config.layers[index].rows)
		assert_int(rings[index].paths).is_equal(base.config.layers[index].paths)
	assert_str(rings[2].name).is_equal("The Interrupt Foundry")
	assert_int(base.config.layers[2].ring).is_equal(0)
	assert_str(base.config.layers[2].backdrop).is_equal("arena-ring-0-kernel")
	assert_str(base.config.layers[2].id).is_equal("kernel")


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
	var work := [{"shard": "salvo", "given": 1, "returned": 40}]
	var cast := _cast(state, ["salvo"], [{"power": 4, "element": "none"}], work)
	var kinds := _kinds(cast)
	assert_int(kinds.find("tempo")).is_less(kinds.find("cast"))
	# The cast ends the turn: the golem strikes after the bolts land, the imp does not strike again.
	assert_int(kinds.rfind("enemy")).is_greater(kinds.find("cast"))
	assert_int(kinds.count("enemy")).is_equal(2)
	assert_int(cast.integrity).is_equal(int(state.integrity) - 10)
	assert_bool(kinds.has("turn")).is_true()
	assert_int(cast.battle.turn).is_equal(int(state.battle.turn) + 1)
	assert_array(cast.battle.acted).is_empty()


func test_a_fast_program_lands_before_anyone_moves() -> void:
	var state := _fight()
	var work := [{"shard": "salvo", "given": 1, "returned": 6}]
	var cast := _cast(state, ["salvo"], [{"power": 20, "element": "none"}], work)
	assert_bool(_kinds(cast).has("tempo")).is_false()
	# The imp falls before it can act; only the golem strikes when the turn ends.
	assert_int(cast.battle.foes[0].hp).is_equal(0)
	assert_int(cast.integrity).is_equal(int(state.integrity) - 5)


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
	# The ward's 4 block takes the golem's end-of-turn strike.
	var strikes := (cast.log as Array).filter(func(entry: Dictionary) -> bool: return entry.kind == "enemy")
	assert_int(int(strikes[0].get("blocked", 0))).is_equal(4)
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


func test_a_foe_the_program_lands_before_takes_initiatives_bonus() -> void:
	var state := _fight()
	# 40 linear work: the imp (16) moves first and takes the bolt plainly; the golem (256) is caught before it moves.
	var bolts := [{"power": 8, "element": "none", "foe": 0}, {"power": 8, "element": "none", "foe": 1}]
	var outcome := {"ok": true, "bolts": bolts, "work": [{"shard": "salvo", "given": 1, "returned": 40}]}
	var next := state.duplicate(true)
	next.spells[0].shards = ["salvo"]
	var cast := Shardrun.step(next, {"type": "cast", "spell_id": next.spells[0].id, "outcome": outcome}, content)
	var bonus := float(ProgramRules.config_of(content).initiative)
	assert_float(bonus).is_greater(0.0)
	assert_int(int(cast.state.battle.foes[0].hp)).is_equal(20 - 8)
	assert_int(int(cast.state.battle.foes[1].hp)).is_equal(30 - floori(8 * (1.0 + bonus)))
	var hits := (cast.state.log as Array).filter(func(entry: Dictionary) -> bool: return entry.kind == "hit")
	assert_bool(hits[0].has("initiative")).is_false()
	assert_bool(hits[1].get("initiative", false)).is_true()


func test_each_intent_has_its_own_speed() -> void:
	var state := _fight()
	var imp: Dictionary = state.battle.foes[0]
	# A Shardrun foe's speeds are in programs.jsonc, one for each intent, in order.
	var speeds: Array = ProgramRules.config_of(catalog).tempo[imp.id]
	for at in speeds.size():
		imp.intent_index = at
		assert_int(ProgramRules.tempo_of(imp, state, catalog)).is_equal(int(speeds[at]))
	# A program foe's intent carries its own.
	imp.intents = [{"kind": "strike", "power": 4, "tempo": 7}]
	imp.intent_index = 0
	assert_int(ProgramRules.tempo_of(imp, state, catalog)).is_equal(7)


func test_the_budget_shrinks_with_each_layer() -> void:
	var state := _fight()
	var by_layer: Array = ProgramRules.config_of(catalog).budget
	for layer in by_layer.size() + 2:
		state.layer = layer
		assert_int(ProgramRules.budget(state, catalog)).is_equal(int(by_layer[mini(layer, by_layer.size() - 1)]))
	assert_int(int(by_layer[-1])).is_less(int(by_layer[0]))


## The test fight's two foes as the halves of a deadlock: each holds the lock the other needs.
func _deadlocked() -> Dictionary:
	var state := _fight()
	var foes: Array = state.battle.foes
	foes[0].trait = {"kind": "deadlock", "partner": foes[1].id}
	foes[1].trait = {"kind": "deadlock", "partner": foes[0].id}
	return state


func test_a_deadlock_holds_unless_one_program_hits_both_halves() -> void:
	var state := _deadlocked()
	var work := [{"shard": "salvo", "given": 1, "returned": 2}]
	# Everything at the first half: its twin was never touched, so the lock holds and nothing lands.
	var one_sided := _cast(state, ["salvo"], [{"power": 9, "foe": 0}, {"power": 9, "foe": 0}], work)
	assert_int(int(one_sided.battle.foes[0].hp)).is_equal(20)
	assert_int(_kinds(one_sided).count("locked")).is_equal(2)
	# One bolt at each: both locks are taken in the same program, and both halves are hurt.
	var both := _cast(state, ["salvo"], [{"power": 9, "foe": 0}, {"power": 9, "foe": 1}], work)
	assert_int(int(both.battle.foes[0].hp)).is_equal(20 - 9)
	assert_int(int(both.battle.foes[1].hp)).is_equal(30 - 9)
	assert_bool(_kinds(both).has("locked")).is_false()


func test_a_broken_half_frees_its_twin() -> void:
	var state := _deadlocked()
	state.battle.foes[1].hp = 0
	var cast := _cast(state, ["salvo"], [{"power": 9, "foe": 0}], [{"shard": "salvo", "given": 1, "returned": 1}])
	assert_int(int(cast.battle.foes[0].hp)).is_equal(20 - 9)


func test_the_preview_counts_the_bolts_a_lock_holds() -> void:
	var state := _deadlocked()
	var outcome := {
		"ok": true, "bolts": [{"power": 5, "foe": 1}], "work": [{"shard": "salvo", "given": 1, "returned": 1}]
	}
	state.spells[0].shards = ["salvo"]
	var preview := ShardrunBattle.preview_cast(state, state.spells[0].id, outcome, catalog)
	assert_int(int(preview.locked)).is_equal(1)
	assert_int(int(preview.damage)).is_equal(0)


func test_a_program_run_meets_the_golem_as_two_locks() -> void:
	# The Golem, as two locks, is one of the Heap's pool of five (ADR-0026).
	assert_array(_heap(catalog).encounters.boss).contains([["deadlock-lock-a", "deadlock-lock-b"]])
	# Spellforge's Heap keeps its one-bodied Golem.
	assert_array(_heap(ContentLoader.load_shardrun().catalog).encounters.boss).is_equal([["deadlock-golem"]])
	for id: String in ["deadlock-lock-a", "deadlock-lock-b"]:
		assert_str(String(catalog.foes[id].trait.kind)).is_equal("deadlock")


static func _heap(from: Dictionary) -> Dictionary:
	for layer: Dictionary in from.config.layers:
		if layer.id == "heap":
			return layer
	return {}


## The test fight's slow foe as a Quine (docs/NewEnemies.md) about to reprint: 2 per bolt, at most 12.
func _quined() -> Dictionary:
	var state := _fight()
	var quine: Dictionary = state.battle.foes[1]
	quine.trait = {"kind": "quine"}
	quine.intents = [{"kind": "reprint", "power": 2, "max": 12, "ward": 0.5}]
	return state


## A cast, then the turn made ready for another: its mana back and its Program castable again.
func _again(state: Dictionary, cards: Array, bolts: Array) -> Dictionary:
	var cast := _cast(state, cards, bolts, [{"shard": cards[0], "given": 1, "returned": bolts.size()}])
	cast.battle.cast = []
	cast.battle.mana = 9
	return cast


func test_the_quine_reprints_the_last_program_at_you() -> void:
	var state := _quined()
	var bolts := [{"power": 1, "foe": 0}, {"power": 1, "foe": 0}, {"power": 1, "foe": 0}, {"power": 8, "block": true}]
	var cast := _again(state, ["salvo"], bolts)
	var quine: Dictionary = cast.battle.foes[1]
	assert_dict(quine.echo).is_equal({"bolts": 3, "ward": 8})
	cast.battle.block = 0
	var before := int(cast.integrity)
	ShardrunBattle.foe_act(cast, cast.battle, quine)
	# Three attacking bolts come back as three hits of 2; the 8-point ward comes back as its 4-point shield.
	assert_int(before - int(cast.integrity)).is_equal(6)
	assert_int(int(quine.shield)).is_equal(4)


func test_the_quine_has_nothing_to_reprint_before_a_program_runs() -> void:
	var state := _quined()
	var before := int(state.integrity)
	ShardrunBattle.foe_act(state, state.battle, state.battle.foes[1])
	assert_int(int(state.integrity)).is_equal(before)
	assert_bool(_kinds(state).has("note")).is_true()


func test_the_same_program_twice_cannot_hurt_the_quine() -> void:
	var at_quine := [{"power": 5, "foe": 1}]
	var first := _again(_quined(), ["salvo"], at_quine)
	assert_int(int(first.battle.foes[1].hp)).is_equal(30 - 5)
	# The same cards in the same order: a fixed point, and nothing lands on it.
	var same := _again(first, ["salvo"], at_quine)
	assert_int(int(same.battle.foes[1].hp)).is_equal(30 - 5)
	assert_bool(_kinds(same).has("absorb")).is_true()
	# One more card changes the program, and it lands again.
	var changed := _again(same, ["salvo", "fork"], at_quine)
	assert_int(int(changed.battle.foes[1].hp)).is_equal(30 - 10)


func test_the_preview_warns_of_the_fixed_point_and_the_reprint() -> void:
	var first := _again(_quined(), ["salvo"], [{"power": 5, "foe": 1}])
	first.spells[0].shards = ["salvo"]
	var outcome := {
		"ok": true,
		"bolts": [{"power": 5, "foe": 1}, {"power": 5, "foe": 1}],
		"work": [{"shard": "salvo", "given": 1, "returned": 2}],
	}
	var preview := ShardrunBattle.preview_cast(first, first.spells[0].id, outcome, catalog)
	assert_int(int(preview.fixed)).is_equal(2)
	assert_int(int(preview.damage)).is_equal(0)
	# The Quine is slower than this program, so it reprints this one: two bolts, two hits of 2.
	assert_array(preview.reprints).is_equal([{"name": "deadlock-golem", "hits": 2, "power": 2}])


func test_a_program_run_goes_on_to_the_root() -> void:
	var layers: Array = catalog.config.layers
	assert_int(layers.size()).is_equal(4)
	var root: Dictionary = layers[3]
	assert_str(String(root.id)).is_equal("root")
	assert_array(root.encounters.boss).contains([["the-quine"], ["root-compiler"]])
	assert_float(float(root.foe_hp)).is_equal(5.4)
	assert_str(String(catalog.foes["the-quine"].trait.kind)).is_equal("quine")
	# Spellforge still ends at the Kernel.
	assert_int((ContentLoader.load_shardrun().catalog.config.layers as Array).size()).is_equal(3)
