extends GdUnitTestSuite
## The run screen driven like a player would: into a fight, casting, ending turns, through rewards and rooms, with the
## stage's animations skipped. It catches what the rules' tests cannot: a screen that breaks on a state it draws.

const ROOT := "user://test-screen-saves"

var screen: ShardrunScreen


func before_test() -> void:
	BattleStage.instant = true
	Settings.code_speed = "off"
	Game.reset(ROOT)
	Game.boot()
	Game.use("spellbook")
	Game.session.saves.delete_run("spellbook")
	Game.session.start(SandboxJob.JAVASCRIPT, "beginner", "screen-test")


func after_test() -> void:
	Background.finish_all()
	if is_instance_valid(screen):
		screen.queue_free()
	BattleStage.instant = false
	Game.session.saves.delete_run("spellbook")
	Game.session.saves.delete_run("deck")
	Game.reset()


func _open() -> ShardrunScreen:
	screen = (load(Game.SHARDRUN) as PackedScene).instantiate() as ShardrunScreen
	add_child(screen)
	await get_tree().process_frame
	return screen


func test_the_screen_plays_a_run_through_its_rooms() -> void:
	var run_screen := await _open()
	var session := Game.session
	var bot := ShardrunBot.new(session)
	var seen := {}
	for i in 120:
		if not session.in_progress():
			break
		seen[session.state.status] = true
		var command: Dictionary = await bot.next_command()
		if command.is_empty():
			break
		var revision: int = session.state.revision
		await run_screen.send(command)
		assert_int(session.state.revision).override_failure_message("refused: %s" % [command]).is_equal(revision + 1)
	assert_bool(seen.has("battle")).is_true()
	assert_bool(seen.has("reward")).is_true()
	assert_int(run_screen.get_child_count()).is_greater(0)


func test_a_shardrun_is_played_card_by_card_through_the_screen() -> void:
	Game.use("deck")
	Game.session.saves.delete_run("deck")
	Game.session.start(SandboxJob.JAVASCRIPT, "beginner", "screen-deck")
	var run_screen := await _open()
	var session := Game.session
	var bot := ShardrunBot.new(session)
	var seen := {}
	for i in 90:
		if not session.in_progress():
			break
		seen[session.state.status] = true
		var command: Dictionary = await bot.next_command()
		if command.is_empty():
			break
		seen["command:" + String(command.type)] = true
		var revision: int = session.state.revision
		await run_screen.send(command)
		assert_int(session.state.revision).override_failure_message("refused: %s" % [command]).is_equal(revision + 1)
	assert_bool(seen.has("command:compose")).is_true()
	assert_bool(seen.has("command:cast")).is_true()
	assert_bool(seen.has("reward")).is_true()
	# The table is on screen with a hand while the fight goes on, and the deck panel between rooms.
	var tables := run_screen.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is DeckTable)
	var decks := run_screen.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is DeckPanel)
	assert_int(tables.size() + decks.size()).is_greater(0)


func test_a_cast_with_its_code_playing_reaches_the_stage() -> void:
	Settings.code_speed = "fast"
	var run_screen := await _open()
	var session := Game.session
	var bot := ShardrunBot.new(session)
	await bot.play_until("battle")
	run_screen.free()
	run_screen = await _open()
	var before: int = session.state.battle.mana
	run_screen.send({"type": "cast", "spell_id": "spell-1"})
	# The code view plays at "fast"; it is skipped as a player would skip it.
	await get_tree().create_timer(0.3).timeout
	var views := run_screen.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is CodeView)
	assert_int(views.size()).is_equal(1)
	(views[0] as CodeView).call("_finish")
	while run_screen.is_busy():
		await get_tree().process_frame
	assert_int(session.state.battle.mana if session.state.has("battle") else 0).is_less(before)


func test_every_between_room_draws() -> void:
	var session := Game.session
	var catalog := session.catalog
	for status: String in ["rest", "forge"]:
		var state := session.state.duplicate(true)
		state.status = status
		session.state = state
		var run_screen := await _open()
		assert_int(_rooms(run_screen)).is_equal(1)
		run_screen.free()
	var chest := session.state.duplicate(true)
	chest.status = "reward"
	chest.reward = {
		"chest": {"curse_chance": 0.25}, "relics": ["arcane-seal"], "spell": {"name": "Volley", "capacity": 4}
	}
	session.state = chest
	var run_screen := await _open()
	assert_int(_rooms(run_screen)).is_equal(1)
	assert_bool(catalog.relics.has("arcane-seal")).is_true()


func test_a_dev_spawn_replaces_the_foes_on_the_stage() -> void:
	Game.session.start(SandboxJob.JAVASCRIPT, "beginner", "dev-spawn", true)
	var run_screen := await _open()
	await run_screen.send({"type": "dev-spawn", "kind": "fight", "foes": ["tally-wisp"]})
	assert_str(Game.session.state.status).is_equal("battle")
	await run_screen.send({"type": "dev-spawn", "kind": "elite", "foes": ["null-wraith", "null-wraith"]})
	var stages := run_screen.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is BattleStage)
	assert_int(stages.size()).is_equal(1)
	var shown: Array = (stages[0] as BattleStage).foes.values()
	assert_int(shown.size()).is_equal(2)
	assert_str((shown[0] as FoeView).foe.id).is_equal("null-wraith")
	# The previews arrive (a frame after their thread ends) and redraw the foes' tags; the nodes they replaced, and the
	# old fight's, are freed at the end of the frame after.
	Background.finish_all()
	for i in 3:
		await get_tree().process_frame


static func _rooms(root: Node) -> int:
	return root.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomPanel).size()
