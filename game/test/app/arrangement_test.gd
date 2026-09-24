extends GdUnitTestSuite
## Moving shards on the workbench: every move is an `arrange` command the rules accept.

var catalog: Dictionary
var state: Dictionary


func before() -> void:
	catalog = ContentLoader.load_shardrun().catalog


func before_test() -> void:
	state = Shardrun.start(catalog, {"seed": "arrange", "language": "python", "difficulty": "beginner"})
	# Bolt: [amplify], Ward: [ward], spares: [fork, kindle]


func _apply(move: Dictionary) -> Dictionary:
	assert_bool(move.ok).override_failure_message(str(move.get("message", ""))).is_true()
	var result := Shardrun.step(state, move.command, catalog)
	assert_bool(result.ok).override_failure_message(str(result.get("error", ""))).is_true()
	return result.state


func test_a_spare_goes_into_a_spell_before_a_shard() -> void:
	var move := Arrangement.move(state, {"spell": "", "index": 0}, {"spell": "spell-1", "index": 0})
	var next := _apply(move)
	assert_array(next.spells[0].shards).is_equal(["fork", "amplify"])
	assert_array(next.inventory).is_equal(["kindle"])


func test_moving_later_within_a_spell_counts_the_gap_it_leaves() -> void:
	state.spells[0].shards = ["amplify", "fork", "kindle"]
	state.inventory = []
	var move := Arrangement.move(state, {"spell": "spell-1", "index": 0}, {"spell": "spell-1", "index": 2})
	assert_array(_apply(move).spells[0].shards).is_equal(["fork", "amplify", "kindle"])
	var to_end := Arrangement.move(state, {"spell": "spell-1", "index": 0}, {"spell": "spell-1", "index": 99})
	assert_array(_apply(to_end).spells[0].shards).is_equal(["fork", "kindle", "amplify"])


func test_a_shard_can_go_back_to_the_spares() -> void:
	var move := Arrangement.move(state, {"spell": "spell-2", "index": 0}, {"spell": "", "index": 99})
	var next := _apply(move)
	assert_array(next.spells[1].shards).is_empty()
	assert_array(next.inventory).is_equal(["fork", "kindle", "ward"])


func test_a_full_spell_refuses_unless_dropped_onto_a_shard() -> void:
	state.spells[0].shards = ["amplify", "amplify", "amplify", "amplify"]
	var refused := Arrangement.move(state, {"spell": "", "index": 0}, {"spell": "spell-1", "index": 99})
	assert_bool(refused.ok).is_false()
	assert_str(refused.message).contains("at most 4")
	var swap := Arrangement.move(state, {"spell": "", "index": 0}, {"spell": "spell-1", "index": 1}, true)
	var next := _apply(swap)
	assert_array(next.spells[0].shards).is_equal(["amplify", "fork", "amplify", "amplify"])
	assert_array(next.inventory).is_equal(["amplify", "kindle"])


func test_nothing_to_move_is_refused() -> void:
	assert_bool(Arrangement.move(state, {"spell": "", "index": 5}, {"spell": "spell-1", "index": 0}).ok).is_false()
	assert_bool(Arrangement.move(state, {"spell": "", "index": 0}, {"spell": "spell-9", "index": 0}).ok).is_false()
