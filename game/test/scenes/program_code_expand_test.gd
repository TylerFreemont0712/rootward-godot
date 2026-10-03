extends GdUnitTestSuite
## The Program's Expand button: the panel stretches upward over the stage so the whole program can be read, and folds
## back by itself when a command starts, so the animations are seen.

var _old_motion := false


func before_test() -> void:
	_old_motion = Settings.reduced_motion
	Settings.reduced_motion = true


func after_test() -> void:
	Settings.reduced_motion = _old_motion


func _fight() -> FightView:
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog).duplicate(true)
	var session := ShardrunSession.new(catalog, SaveStore.new("user://test-program-expand"), "program")
	session.state = Shardrun.start(
		catalog, {"seed": "expand", "language": "javascript", "playstyle": "program", "difficulty": "beginner"}
	)
	var foes := ShardrunBattle.foe_states(session.state, ["tally-wisp"], "expand", catalog)
	ShardrunBattle.start_with(session.state, "fight", foes, catalog)
	var fight: FightView = auto_free(FightView.create(session))
	fight.size = Vector2(1920, 1080)
	add_child(fight)
	return fight


func test_expanding_lifts_only_the_panels_top_edge_about_a_share_of_the_screen() -> void:
	var fight := _fight()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: ProgramCode = fight._program
	var home := panel.get_global_rect()
	var row_before: float = fight._bottom.size.y
	panel.set_expanded(true)
	assert_float(panel.get_global_rect().position.y).is_equal_approx(
		home.position.y - panel.get_viewport_rect().size.y * ProgramCode.EXPAND_SHARE, 1.0
	)
	assert_float(panel.get_global_rect().end.y).is_equal_approx(home.end.y, 1.0)
	# Nothing else in the row moves: the stage keeps its size.
	assert_float(fight._bottom.size.y).is_equal(row_before)
	panel.set_expanded(false)
	assert_float(panel.get_global_rect().position.y).is_equal_approx(home.position.y, 1.0)


func test_a_command_folds_it_and_the_button_waits_until_it_is_done() -> void:
	var fight := _fight()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: ProgramCode = fight._program
	panel.set_expanded(true)
	fight.set_busy(true)
	assert_bool(panel.expanded).is_false()
	assert_float(panel.offset_top).is_equal(0.0)
	assert_bool(panel._expand.disabled).is_true()
	fight.set_busy(false)
	assert_bool(panel._expand.disabled).is_false()
	assert_str(panel._expand.text).is_equal("Expand")
