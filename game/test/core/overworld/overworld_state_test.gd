extends GdUnitTestSuite
## The town's save as rules (ADR-0061, OverworldState): a new player's boots start with one rule they can see, an older
## save still loads with what it lacks filled in, changing the boots keeps the code typed in the other language, and
## the boots run what their mode says.


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
