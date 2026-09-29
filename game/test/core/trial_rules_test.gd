extends GdUnitTestSuite

const ROOT := "user://test-pip-trial"

var session: ShardrunSession


func before_test() -> void:
	if DirAccess.dir_exists_absolute(ROOT):
		for file_name in DirAccess.get_files_at(ROOT):
			DirAccess.remove_absolute(ROOT.path_join(file_name))
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	session = ShardrunSession.new(catalog, SaveStore.new(ROOT), "program", "trial")
	session.start(SandboxJob.JAVASCRIPT, "beginner", "pip-trial-v1")


func after_test() -> void:
	Background.finish_all()


func test_trial_starts_on_its_fixed_map_and_advances_from_real_events() -> void:
	assert_str(session.state.status).is_equal("map")
	assert_int((session.state.map.nodes as Array).size()).is_equal(4)
	assert_str(session.state.trial.step_id).is_equal("hello")
	await session.command({"type": "trial-next"})
	assert_str(session.state.trial.step_id).is_equal("map")
	var entered: Dictionary = await session.command({"type": "enter", "node_id": "l0-r0-c0"})
	assert_bool(entered.ok).is_true()
	assert_str(session.state.trial.step_id).is_equal("hand")
	assert_str(session.state.battle.foes[0].id).is_equal("tally-wisp")
	assert_array(session.state.battle.hand).contains(["fire-constant"])
	var hand: Array = session.state.battle.hand.duplicate()
	hand.erase("fire-constant")
	var placed: Dictionary = await session.command(
		{"type": "compose", "spells": [{"id": "spell-1", "shards": ["fire-constant"]}], "hand": hand, "held": []}
	)
	assert_bool(placed.ok).is_true()
	assert_str(session.state.trial.step_id).is_equal("code")
	await session.command({"type": "trial-next"})
	assert_str(session.state.trial.step_id).is_equal("run")
	var cast: Dictionary = await session.command({"type": "cast", "spell_id": "spell-1"})
	assert_bool(cast.ok).is_true()
	assert_str(session.state.trial.step_id).is_equal("walk")
	assert_int(int(session.state.stats.casts)).is_equal(1)
	assert_array(session.saves.load_history()).is_empty()


func test_lost_trial_fight_rewinds_with_a_hint() -> void:
	await session.command({"type": "trial-next"})
	await session.command({"type": "enter", "node_id": "l0-r0-c0"})
	session.state.integrity = 1
	var ended: Dictionary = await session.command({"type": "end-turn"})
	assert_bool(ended.ok).is_true()
	assert_str(session.state.status).is_equal("battle")
	assert_int(session.state.trial.failures).is_equal(1)
	assert_str(session.state.trial.step_id).is_equal("hand")
	assert_str(session.state.trial.hint).is_not_empty()
	assert_array(session.saves.load_history()).is_empty()


func test_a_scripted_player_finishes_the_whole_trial_without_run_history() -> void:
	Game.reset(ROOT)
	assert_bool(Game.boot()).is_true()
	assert_bool(Game.start_trial()).is_true()
	session = Game.trial_session
	var commands: Array[String] = []
	for attempt in 110:
		if session.state.trial.done:
			break
		var step := TrialRules.current(session.state, session.trial_content)
		var event := String(step.event)
		var result: Dictionary = {}
		match event:
			"coach-next":
				result = await session.command({"type": "trial-next"})
			"enter":
				var rooms := ShardrunMap.next_rooms(session.state.map, session.state.position)
				result = await session.command({"type": "enter", "node_id": rooms[0].id})
			"compose":
				result = await _place_one_card()
			"cast":
				result = await session.command({"type": "cast", "spell_id": "spell-1"})
			"battle-won":
				if session.state.status == "battle":
					result = await _play_one_turn()
				else:
					fail("The win event was not retained for %s" % step.id)
					break
			"claim-relic":
				result = await session.command({"type": "claim-relic", "relic_id": session.state.reward.relics[0]})
			"forge":
				result = await session.command({"type": "forge", "shard_id": "fib-surge"})
			"rest":
				result = await session.command({"type": "rest"})
			_:
				fail("Unknown Trial event: %s" % event)
				break
		commands.append(event)
		assert_bool(result.get("ok", false)).is_true()
	assert_bool(session.state.trial.done).is_true()
	assert_bool(Game.profile.tutorial.trial_done).is_true()
	assert_str(session.state.status).is_equal("won")
	assert_array(session.saves.load_history()).is_empty()
	assert_bool(commands.has("forge")).is_true()
	assert_bool(commands.has("rest")).is_true()
	assert_bool(commands.has("battle-won")).is_true()


func test_scripted_reading_and_actions_fit_twelve_minutes() -> void:
	var content: Dictionary = session.trial_content
	var words := 0
	var action_seconds := 0
	for chapter: Dictionary in content.chapters:
		words += String(chapter.title).split(" ", false).size()
		words += String(chapter.scene).split(" ", false).size()
	for step: Dictionary in content.steps:
		words += String(step.say).split(" ", false).size()
		words += String(step.code).split(" ", false).size()
		action_seconds += int(step.action_seconds)
	var total_seconds := roundi(words * 60.0 / 200.0) + action_seconds
	prints("Pip's Trial timing:", words, "words / 200 wpm +", action_seconds, "action seconds =", total_seconds)
	assert_int(total_seconds).is_between(600, 900)


func _place_one_card() -> Dictionary:
	var hand: Array = session.state.battle.hand.duplicate()
	if hand.is_empty():
		return await session.command({"type": "end-turn"})
	var chosen := "fire-constant" if "fire-constant" in hand else String(hand[0])
	hand.erase(chosen)
	return await session.command(
		{"type": "compose", "spells": [{"id": "spell-1", "shards": [chosen]}], "hand": hand, "held": []}
	)


func _play_one_turn() -> Dictionary:
	if (session.state.spells[0].shards as Array).is_empty():
		var placed := await _place_one_card()
		if not placed.ok or session.state.status != "battle":
			return placed
	return await session.command({"type": "cast", "spell_id": "spell-1"})
