extends GdUnitTestSuite
## The town's save as rules (ADR-0061, OverworldState): a new player's boots start with one rule they can see, an older
## save still loads with what it lacks filled in, changing the boots keeps the code typed in the other language, the
## boots run what their mode says, and a saved cell that is blocked on its map moves the player to the start.

## A small town: a wall down x = 3 on the first two rows, and a gate on (1, 2) that is solid until its code opens it.
const TERRAIN := {"grass": {"walk": true}, "wall": {"walk": false}}
const TOWN := {
	"id": "test-town",
	"legend": {".": "grass", "#": "wall"},
	"ground": ["...#.", "...#.", "....."],
	"start": [0, 0],
	"objects":
	[
		{
			"kind": "prop",
			"id": "gate",
			"solid_unless": "open",
			"at": [1, 2],
			"program": {"hook": "on_use", "fields": {"open": {"type": "bool", "default": false}}, "raises": []},
		},
	],
}


func _town() -> Dictionary:
	var built := OverworldMap.build(TOWN, TERRAIN)
	assert_array(built.errors).is_empty()
	return built.map


func _saved_at(cell: Array, things: Dictionary = {}) -> Dictionary:
	return {"map": "test-town", "cell": cell, "things": things}


func _fresh() -> Dictionary:
	return OverworldState.fresh("home", Vector2i(2, 3), "down", BootsCode.PYTHON)


## A player who typed code in both languages and switched to Code.
func _typed() -> Dictionary:
	var state := OverworldState.with_code(_fresh(), "# python\ndef on_key(key, player):\n    pass\n")
	state.language = BootsCode.JAVASCRIPT
	return OverworldState.with_code(state, "// javascript\nfunction onKey(key, player) {}\n")


func test_a_fresh_town_carries_one_rule_right_x_plus_one() -> void:
	var state := _fresh()
	assert_array(state.boots.blocks).override_failure_message("the first rule").is_equal(
		[BootsCode.rule("right", "x", 1)]
	)
	assert_str(String(state.boots.mode)).is_equal(OverworldState.BLOCKS)
	assert_str(OverworldState.boots_source(state)).contains('if key == "right":').contains("player.x += 1")


func test_normalized_keeps_the_saved_blocks_and_fills_what_is_missing() -> void:
	var saved := {
		"map": "lanternroot",
		"cell": [3, 4],
		"flags": {"woke": true},
		"boots": {"blocks": [BootsCode.rule("up", "y", -1)]},
	}
	var state := OverworldState.normalized(saved, _fresh())
	assert_str(String(state.map)).is_equal("lanternroot")
	assert_that(OverworldState.cell(state)).is_equal(Vector2i(3, 4))
	assert_bool(bool(state.flags.woke)).is_true()
	assert_array(state.boots.blocks).is_equal([BootsCode.rule("up", "y", -1)])
	assert_str(String(state.boots.mode)).is_equal(OverworldState.BLOCKS)
	assert_dict(state.boots.code).is_empty()
	assert_dict(state.look).is_empty()
	assert_str(String(state.facing)).is_equal("down")
	assert_str(String(state.language)).is_equal(BootsCode.PYTHON)
	assert_int(int(state.version)).is_equal(OverworldState.VERSION)


func test_an_older_save_with_no_boots_gets_the_new_players_boots() -> void:
	var state := OverworldState.normalized({"map": "home"}, _fresh())
	assert_array(state.boots.blocks).is_equal(_fresh().boots.blocks)
	assert_str(String(state.boots.mode)).is_equal(OverworldState.BLOCKS)


func test_a_broken_entry_is_replaced_with_working_defaults() -> void:
	var saved := {"boots": "oops", "flags": 3, "look": [], "cell": [1, 1]}
	var state := OverworldState.normalized(saved, _fresh())
	assert_str(String(state.boots.mode)).override_failure_message("broken boots come back in blocks").is_equal(
		OverworldState.BLOCKS
	)
	(
		assert_array(state.boots.blocks)
		. override_failure_message("broken boots come back with the new player's one rule")
		. is_equal([BootsCode.rule("right", "x", 1)])
	)
	assert_str(String(state.language)).override_failure_message("the default language is python").is_equal(
		BootsCode.PYTHON
	)
	assert_dict(state.boots.code).is_empty()
	assert_dict(state.flags).is_empty()
	assert_dict(state.look).is_empty()
	assert_that(OverworldState.cell(state)).is_equal(Vector2i(1, 1))


func test_with_blocks_sets_the_blocks_mode_and_keeps_both_codes() -> void:
	var typed := _typed()
	var rule := BootsCode.rule("left", "x", -1)
	var out := OverworldState.with_blocks(typed, [rule])
	assert_str(String(out.boots.mode)).is_equal(OverworldState.BLOCKS)
	assert_array(out.boots.blocks).is_equal([rule])
	assert_str(String(out.boots.code.python)).is_equal(String(typed.boots.code.python))
	assert_str(String(out.boots.code.javascript)).is_equal(String(typed.boots.code.javascript))
	assert_str(String(typed.boots.mode)).is_equal(OverworldState.CODE)


func test_with_code_sets_the_code_mode_and_keeps_the_other_language() -> void:
	var state := OverworldState.with_blocks(_fresh(), [BootsCode.rule("up", "y", -1)])
	var python := OverworldState.with_code(state, "def on_key(key, player):\n    pass\n")
	assert_str(String(python.boots.mode)).is_equal(OverworldState.CODE)
	assert_array(python.boots.blocks).is_equal([BootsCode.rule("up", "y", -1)])
	python.language = BootsCode.JAVASCRIPT
	var both := OverworldState.with_code(python, "function onKey(key, player) {}\n")
	assert_str(String(both.boots.code.python)).is_equal("def on_key(key, player):\n    pass\n")
	assert_str(String(both.boots.code.javascript)).is_equal("function onKey(key, player) {}\n")
	assert_str(OverworldState.boots_source(both)).is_equal("function onKey(key, player) {}\n")


func test_the_boots_run_what_their_mode_says() -> void:
	var blocks := [BootsCode.rule("down", "y", 1)]
	var as_blocks := OverworldState.with_blocks(_fresh(), blocks)
	assert_str(OverworldState.boots_source(as_blocks)).is_equal(BootsCode.source(blocks, BootsCode.PYTHON))
	var typed := OverworldState.with_code(_fresh(), "def on_key(key, player):\n    player.y += 2\n")
	assert_str(OverworldState.boots_source(typed)).is_equal("def on_key(key, player):\n    player.y += 2\n")
	var empty := OverworldState.with_code(_fresh(), "   ")
	assert_str(OverworldState.boots_source(empty)).is_equal(BootsCode.starter(BootsCode.PYTHON))


func test_moving_and_flagging_return_new_states() -> void:
	var state := _fresh()
	var moved := OverworldState.moved(state, "lanternroot", Vector2i(6, 23), "up")
	var flagged := OverworldState.flagged(state, {"woke": true})
	assert_str(String(state.map)).is_equal("home")
	assert_that(OverworldState.cell(state)).is_equal(Vector2i(2, 3))
	assert_dict(state.flags).is_empty()
	assert_that(OverworldState.cell(moved)).is_equal(Vector2i(6, 23))
	assert_str(String(moved.facing)).is_equal("up")
	assert_bool(bool(flagged.flags.woke)).is_true()


func test_remembered_adds_dialogue_progress_without_losing_events_since_the_dialogue_opened() -> void:
	var state := OverworldState.flagged(_fresh(), {"woke": true, "boots-expanded": true, "all-ways": true})
	var old_talk_flags := {"woke": true, "first-step": true}
	var after := OverworldState.remembered(state, old_talk_flags)
	assert_dict(after.flags).is_equal({
		"woke": true, "boots-expanded": true, "all-ways": true, "first-step": true,
	})
	assert_dict(state.flags).is_equal({"woke": true, "boots-expanded": true, "all-ways": true})
	assert_dict(old_talk_flags).is_equal({"woke": true, "first-step": true})
	assert_str(String(after.map)).is_equal(String(state.map))
	assert_array(after.cell).is_equal(state.cell)
	assert_dict(after.boots).is_equal(state.boots)


func test_remembered_does_not_clear_live_progress_with_stale_false_values() -> void:
	var state := OverworldState.flagged(_fresh(), {"all-ways": true, "unearned": false})
	var after := OverworldState.remembered(state, {"all-ways": false, "first-step": true, "unearned": false})
	assert_dict(after.flags).is_equal({"all-ways": true, "unearned": false, "first-step": true})


func test_remembered_strips_facts_from_both_the_live_state_and_the_observed_snapshot() -> void:
	var state := OverworldState.flagged(_fresh(), {"woke": true, "bag:cabbage": 1})
	var after := OverworldState.remembered(state, {"met-innkeeper": true, "bag:apple": 3})
	assert_dict(after.flags).is_equal({"woke": true, "met-innkeeper": true})


func test_remembered_can_merge_the_live_flags_into_an_older_lesson_state() -> void:
	var lesson := OverworldState.flagged(_fresh(), {"first-step": true, "memory-written": true})
	lesson["tasks"] = {"save": {"stage": 1}}
	var live_flags := {"first-step": true, "boots-expanded": true, "left-home": true}
	var after := OverworldState.remembered(lesson, live_flags)
	assert_dict(after.flags).is_equal({
		"first-step": true, "memory-written": true, "boots-expanded": true, "left-home": true,
	})
	assert_dict(after.tasks).is_equal(lesson.tasks)


func test_an_older_save_has_no_things_and_a_broken_one_is_emptied() -> void:
	var state := OverworldState.normalized({"map": "home"}, _fresh())
	assert_dict(state.things).is_empty()
	var kept := OverworldState.normalized({"things": {"gate": {"fields": {"open": true}}}}, _fresh())
	assert_bool(bool(kept.things["gate"]["fields"]["open"])).is_true()
	assert_dict(OverworldState.normalized({"things": 4}, _fresh()).things).is_empty()


func test_a_save_standing_in_a_wall_comes_back_at_the_start() -> void:
	var state := OverworldState.normalized(_saved_at([3, 0]), _fresh(), _town())
	assert_that(OverworldState.cell(state)).is_equal(Vector2i.ZERO)


func test_a_save_on_open_ground_stays_where_it_was() -> void:
	var state := OverworldState.normalized(_saved_at([4, 1]), _fresh(), _town())
	assert_that(OverworldState.cell(state)).is_equal(Vector2i(4, 1))


func test_a_save_on_a_closed_gate_comes_back_at_the_start() -> void:
	var state := OverworldState.normalized(_saved_at([1, 2]), _fresh(), _town())
	assert_that(OverworldState.cell(state)).is_equal(Vector2i.ZERO)


func test_a_save_on_a_gate_that_is_open_stays_put() -> void:
	var saved := _saved_at([1, 2], {"gate": {"fields": {"open": true}}})
	assert_that(OverworldState.cell(OverworldState.normalized(saved, _fresh(), _town()))).is_equal(Vector2i(1, 2))


func test_the_cell_is_checked_only_on_the_map_it_stands_on() -> void:
	var elsewhere := {"map": "elsewhere", "cell": [3, 0]}
	assert_that(OverworldState.cell(OverworldState.normalized(elsewhere, _fresh(), _town()))).is_equal(Vector2i(3, 0))
	# With no map given, nothing is checked and the cell is kept.
	assert_that(OverworldState.cell(OverworldState.normalized(_saved_at([3, 0]), _fresh()))).is_equal(Vector2i(3, 0))
