extends GdUnitTestSuite
## Cycles, a program run's money (ProgramCycles): a kill pays by the fight's kind, the layer and the difficulty, plus
## small bonuses, and a won fight leaves its receipt.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramCatalogs.without_initiative(ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog))


## A run in a fight against `foes` (all already down), `kind`, on `layer` and `difficulty`.
func _won(foes: Array, kind := "fight", layer := 0, difficulty := "beginner") -> Dictionary:
	var options := {"seed": "cycles", "language": "python", "difficulty": difficulty, "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.layer = layer
	var states := ShardrunBattle.foe_states(state, foes, "cycles", catalog)
	var battle := ShardrunBattle.new_battle(state, kind, states, catalog)
	ProgramRelics.on_battle_start(state, battle, catalog)
	for foe: Dictionary in battle.foes:
		foe.hp = 0
	battle.casts = 2
	state.battle = battle
	return state


func _total(state: Dictionary) -> int:
	return int(ProgramCycles.settle(state, state.battle, catalog).total)


func test_an_ordinary_foe_pays_six_and_the_layer_and_difficulty_scale_it() -> void:
	var state := _won(["tally-wisp"])
	var receipt := ProgramCycles.settle(state, state.battle, catalog)
	assert_int(int(receipt.lines[0].amount)).is_equal(6)
	# A clean build on top: nothing hurt the run.
	assert_int(int(receipt.total)).is_equal(11)
	assert_int(int(state.cycles)).is_equal(11)
	var later := _won(["tally-wisp"], "fight", 1, "programmer")
	assert_int(int(ProgramCycles.settle(later, later.battle, catalog).lines[0].amount)).is_equal(9)


func test_an_elite_pays_more_and_a_guardian_shares_its_pay_among_its_bodies() -> void:
	var elite := _won(["null-wraith"], "elite")
	assert_int(int(ProgramCycles.settle(elite, elite.battle, catalog).lines[0].amount)).is_equal(16)
	var one := _won(["kiln-warden"], "boss")
	assert_int(int(ProgramCycles.settle(one, one.battle, catalog).lines[0].amount)).is_equal(45)
	var three := _won(["page-fault-a", "page-fault-b", "page-fault-c"], "boss", 1)
	var receipt := ProgramCycles.settle(three, three.battle, catalog)
	var kills: Array = receipt.lines.filter(func(line: Dictionary) -> bool: return line.kind == "kill")
	assert_int(kills.size()).is_equal(3)
	# 45 shared by three bodies, scaled by the Heap: floor(15 x 1.25).
	assert_int(int(kills[0].amount)).is_equal(18)


func test_a_summoned_foe_pays_one_flat() -> void:
	var state := _won(["tally-wisp", "tally-wisp"], "fight", 2, "programmer")
	state.battle.foes[1].owner = state.battle.foes[0].uid
	var receipt := ProgramCycles.settle(state, state.battle, catalog)
	assert_int(int(receipt.lines[0].amount)).is_equal(11)
	assert_int(int(receipt.lines[1].amount)).is_equal(1)


func test_exact_and_initiative_kills_add_one_each() -> void:
	var state := _won(["tally-wisp"])
	var uid: String = state.battle.foes[0].uid
	ProgramCycles.mark(state.battle, uid, "exact")
	ProgramCycles.mark(state.battle, uid, "initiative")
	var receipt := ProgramCycles.settle(state, state.battle, catalog)
	var bonuses: Array = receipt.lines.filter(func(line: Dictionary) -> bool: return line.kind == "bonus")
	assert_array(bonuses.map(func(line: Dictionary) -> String: return line.label)).contains(["exact", "Initiative"])
	assert_int(int(receipt.total)).is_equal(6 + 1 + 1 + 5)


func test_a_clean_build_needs_no_damage_and_a_one_liner_needs_one_program() -> void:
	var hurt := _won(["tally-wisp"])
	hurt.integrity -= 3
	assert_int(_total(hurt)).is_equal(6)
	var quick := _won(["tally-wisp"])
	quick.battle.casts = 1
	assert_int(_total(quick)).is_equal(6 + 5 + 3)


func test_cycles_are_spent_only_when_the_run_can_afford_them() -> void:
	var state := _won(["tally-wisp"])
	state.cycles = 30
	assert_bool(ProgramCycles.spend(state, 40)).is_false()
	assert_int(int(state.cycles)).is_equal(30)
	assert_bool(ProgramCycles.spend(state, 25)).is_true()
	assert_int(int(state.cycles)).is_equal(5)
	assert_int(int(state.cycles_spent)).is_equal(25)


func test_a_won_fight_leaves_its_receipt_and_the_cycles_in_the_wallet() -> void:
	var options := {
		"seed": "won", "language": "python", "difficulty": "beginner", "playstyle": "program", "sandbox": true
	}
	var state := Shardrun.start(catalog, options)
	state.paradigm = "greedy"
	state.status = "map"
	state.erase("draft")
	var result := Shardrun.step(state, {"type": "dev-spawn", "kind": "fight", "foes": ["tally-wisp"]}, catalog)
	assert_bool(result.ok).is_true()
	result = Shardrun.step(result.state, {"type": "dev-end-battle", "outcome": "win"}, catalog)
	assert_bool(result.ok).is_true()
	assert_int(int(result.state.reward.receipt.total)).is_greater(0)
	assert_int(int(result.state.cycles)).is_equal(int(result.state.reward.receipt.total))


func test_skipping_the_cards_pays_by_the_layer_and_a_treasure_pays_cycles() -> void:
	var state := _won(["tally-wisp"])
	state.layer = 1
	state.status = "reward"
	state.reward = {"shards": ["salvo"]}
	state.paradigm = "greedy"
	var result := Shardrun.step(state, {"type": "take", "shard_id": null}, catalog)
	assert_bool(result.ok).is_true()
	assert_int(int(result.state.cycles)).is_equal(20)
	var chest := _won(["tally-wisp"])
	chest.layer = 2
	assert_int(ProgramCycles.treasure(chest, catalog)).is_equal(60)
