extends GdUnitTestSuite
## Construction follows measured call slots, reuses its circle at release, and keeps the existing cast optional.

var _instant := false
var _code_speed := "off"


func before_test() -> void:
	_instant = BattleStage.instant
	_code_speed = Settings.code_speed
	BattleStage.instant = false


func after_test() -> void:
	Background.finish_all()
	SaveStore.new("user://test-construction-playback").delete_run("program")
	BattleStage.instant = _instant
	Settings.code_speed = _code_speed


func _stage(light := "shard-weave", heavy := "grand-push") -> BattleStage:
	var stage: BattleStage = auto_free(BattleStage.new())
	stage.size = Vector2(1200, 700)
	stage.hero.set_preview_skin("vesper")
	stage.hero.preview_loadout = {"cast_light": light, "cast_heavy": heavy}
	add_child(stage)
	return stage


func _entries(power := 4, cost := 2) -> Array:
	return [{"kind": "cast", "spell": "spell", "amount": cost}, {"kind": "ward", "amount": power}]


func test_construction_is_selected_by_the_actual_cast_weight() -> void:
	var stage := _stage()
	var player := LogPlayer.new(stage, {})
	assert_bool(player.uses_construction(_entries())).is_true()
	assert_bool(player.uses_construction(_entries(30))).is_false()
	stage.hero.preview_loadout = {"cast_heavy": "shard-weave"}
	assert_bool(player.uses_construction(_entries())).is_false()
	assert_bool(player.uses_construction(_entries(30))).is_true()
	assert_bool(player.uses_construction([{"kind": "timeout", "cost": 2}])).is_false()


func test_code_resolutions_add_exact_slots_and_release_reuses_the_partial_circle() -> void:
	var stage := _stage()
	var player := LogPlayer.new(stage, {"battle": {"mana": 9}})
	player.cast_cards["spell"] = CircleLayers.demo_cards(3)
	player.begin_construction("spell", "none")
	var circle: MagicCircle = player.get("_circle")
	assert_bool(circle.external_construction).is_true()
	var arrived: Array[int] = []
	circle.layer_added.connect(func(index: int) -> void: arrived.append(index))
	circle._process(10.0)
	assert_array(arrived).is_empty()
	player.resolve_shard(1)
	assert_array(arrived).is_empty()
	player.resolve_shard(0)
	player.resolve_shard(0)
	assert_array(arrived).is_equal([0])
	# A failed later call leaves a partial circle. Playback seals it without replacing it or inventing layers.
	stage.fast = true
	await player.play(_entries())
	assert_array(arrived).is_equal([0])
	assert_bool(circle.is_inside_tree()).is_true()
	assert_int(stage._fx.get_children().filter(func(node: Node) -> bool: return node is MagicCircle).size()).is_equal(1)
	assert_int(int(player.shown.mana)).is_equal(7)
	assert_int(int(player.shown.block)).is_equal(4)


func _code_view(steps: int, failed := false) -> CodeView:
	var measured: Array[Dictionary] = []
	for index in steps:
		measured.append({"work": 1, "bolts": [], "outcome": {}})
	var run := {"base": {"bolts": []}, "steps": measured}
	if failed:
		run.misfire = {"shard": "repeat", "reason": "failed"}
	else:
		run.result = {}
	return auto_free(
		CodeView.create(
			"python", {"name": "Test", "shards": ["repeat", "repeat", "repeat"]}, {}, 4, run, "cast", "fast"
		)
	)


func test_spellforge_reports_each_completed_call_including_repeated_shards() -> void:
	var view := _code_view(3)
	var resolved: Array[int] = []
	view.shard_resolved.connect(func(index: int) -> void: resolved.append(index))
	for index in view.played.size():
		if view.played[index].get("mark", "") == "step":
			view._show(index)
	assert_array(resolved).is_equal([0, 1, 2])
	view.skip()
	assert_array(resolved).is_equal([0, 1, 2])


func test_skipping_spellforge_reports_only_measured_calls_before_a_failure() -> void:
	var view := _code_view(1, true)
	var resolved: Array[int] = []
	view.shard_resolved.connect(func(index: int) -> void: resolved.append(index))
	var button := view.find_children("*", "Button", true, false)[0] as Button
	assert_str(button.text).is_equal("Skip")
	button.pressed.emit()
	view.skip()
	assert_array(resolved).is_equal([0])


func test_without_code_playback_every_shard_constructs_before_the_volley() -> void:
	var stage := _stage()
	# A rehearsal clock can be advanced by hand, keeping this test quick and deterministic.
	stage.local_clock = true
	var player := LogPlayer.new(stage, {"battle": {"mana": 9}})
	player.cast_cards["spell"] = CircleLayers.demo_cards(3)
	var finished: Array[bool] = [false]
	_play(player, _entries(), finished)
	var circle: MagicCircle = player.get("_circle")
	assert_object(circle).is_not_null()
	assert_bool(circle.external_construction).is_true()
	assert_int(circle._arrived).is_equal(1)
	var arrived: Array[int] = [0]
	circle.layer_added.connect(func(index: int) -> void: arrived.append(index))
	for index in 120:
		stage.advance(1.0 / 30.0)
		await get_tree().process_frame
		if arrived.size() == 3:
			break
	assert_array(arrived).is_equal([0, 1, 2])
	stage.fast = true
	for index in 120:
		await get_tree().process_frame
		if finished[0]:
			break
	assert_bool(finished[0]).is_true()
	assert_int(int(player.shown.block)).is_equal(4)


func test_code_off_fallback_keeps_the_replays_completed_call_count() -> void:
	var stage := _stage()
	stage.local_clock = true
	var player := LogPlayer.new(stage, {})
	player.cast_cards["spell"] = CircleLayers.demo_cards(3)
	player.cast_steps["spell"] = 1
	var finished: Array[bool] = [false]
	_play(player, _entries(), finished)
	var circle: MagicCircle = player.get("_circle")
	assert_object(circle).is_not_null()
	assert_int(circle._arrived).is_equal(1)
	stage.fast = true
	for index in 120:
		await get_tree().process_frame
		if finished[0]:
			break
	assert_bool(finished[0]).is_true()
	assert_int(circle._arrived).is_equal(1)


func test_skipping_the_program_reports_duplicate_slots_but_no_unvisited_calls() -> void:
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	var session := ShardrunSession.new(catalog, SaveStore.new("user://test-construction-playback"), "program")
	session.state = Shardrun.start(
		catalog,
		{"seed": "construction-playback", "language": "javascript", "playstyle": "program", "difficulty": "beginner"}
	)
	session.state.spells[0].shards = ["salvo", "salvo", "fork"]
	var panel: ProgramCode = auto_free(ProgramCode.create(session))
	add_child(panel)
	var steps: Array[Dictionary] = []
	for index in 2:
		steps.append({"shard": "salvo", "work": 1, "n": 1, "returned": 1})
	var view := {"program": true, "base": {"bolts": []}, "steps": steps, "work": 2, "budget": 4096}
	panel.show_program(session.state, view)
	var resolved: Array[int] = []
	panel.shard_resolved.connect(func(index: int) -> void: resolved.append(index))
	panel.skip.call_deferred()
	await panel.play_cast(view, "fast")
	assert_array(resolved).is_equal([0, 1])


func test_fight_constructs_during_the_code_walk_and_keeps_that_circle_after_a_faster_foe() -> void:
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	var session := ShardrunSession.new(catalog, SaveStore.new("user://test-construction-playback"), "program")
	session.state = Shardrun.start(
		catalog,
		{"seed": "construction-fight", "language": "javascript", "playstyle": "program", "difficulty": "beginner"}
	)
	var foes := ShardrunBattle.foe_states(session.state, ["tally-wisp"], "construction", catalog)
	ShardrunBattle.start_with(session.state, "fight", foes, catalog)
	session.state.spells[0].shards = ["salvo", "salvo"]
	var fight: FightView = auto_free(FightView.create(session))
	fight.size = Vector2(1920, 1080)
	fight.stage.hero.preview_loadout = {"cast_light": "shard-weave"}
	fight.stage.hero.set_preview_skin("vesper")
	add_child(fight)
	await get_tree().process_frame
	Settings.code_speed = "fast"
	var spell_id: String = session.state.spells[0].id
	var steps: Array[Dictionary] = []
	for index in 2:
		steps.append({"shard": "salvo", "work": 1, "n": 1, "returned": 1})
	var replay := {"program": true, "base": {"bolts": []}, "steps": steps, "work": 2, "budget": 4096}
	var after := session.state.duplicate(true)
	after.log = [
		{"kind": "tempo", "foe": foes[0].uid, "amount": 1},
		{"kind": "enemy", "foe": foes[0].uid, "amount": 1},
		{"kind": "cast", "spell": spell_id, "amount": 2},
		{"kind": "ward", "amount": 4},
	]
	var circles: Array[MagicCircle] = []
	fight.stage._fx.child_entered_tree.connect(
		func(node: Node) -> void:
			if node is MagicCircle:
				circles.append(node as MagicCircle)
	)
	var finished: Array[bool] = [false]
	_present(
		fight, {"before": session.state, "state": after, "replay": {"spell_id": spell_id, "run": replay}}, finished
	)
	assert_int(circles.size()).is_equal(1)
	var circle := circles[0]
	assert_int(circle._arrived).is_equal(0)
	var anchor := circle.position
	var deadline := Time.get_ticks_msec() + 5000
	while circle._arrived == 0 and not finished[0] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_int(circle._arrived).is_equal(1)
	assert_str(fight._program._title.text).contains("running")
	assert_vector(circle.position).is_equal(anchor)
	# Skipping the remainder must not recreate the circle when the preceding enemy entries finish.
	fight._program.skip()
	fight.stage.fast = true
	while not finished[0] and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(finished[0]).is_true()
	assert_int(circles.size()).is_equal(1)
	assert_int(circle._arrived).is_equal(2)


func _present(fight: FightView, result: Dictionary, finished: Array[bool]) -> void:
	await fight.present(result)
	finished[0] = true


func _program_session(shards: Array) -> ShardrunSession:
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog).duplicate(true)
	var session := ShardrunSession.new(catalog, SaveStore.new("user://test-construction-playback"), "program")
	session.state = Shardrun.start(
		catalog,
		{"seed": "construction-imports", "language": "javascript", "playstyle": "program", "difficulty": "beginner"}
	)
	var foes := ShardrunBattle.foe_states(session.state, ["tally-wisp"], "construction", catalog)
	ShardrunBattle.start_with(session.state, "fight", foes, catalog)
	session.state.spells[0].shards = shards.duplicate()
	return session


func test_program_imports_follow_source_order_and_match_held_upgrades_by_module() -> void:
	var session := _program_session(["salvo", "import-heapq-plus", "fork"])
	# An unrelated import must not make a layer, and heapq's held upgrade is represented by its old import line.
	session.state.battle.imports = ["import-math", "import-heapq"]
	var spell_id: String = session.state.spells[0].id
	var stage := _stage()
	var player := LogPlayer.new(stage, {})
	player.cast_cards[spell_id] = []
	for id: String in session.state.spells[0].shards:
		(player.cast_cards[spell_id] as Array).append(session.catalog.shards[id])
	var view := {
		"program": true,
		"base": {"bolts": []},
		"steps": [{"shard": "salvo", "work": 1, "n": 1, "returned": 1}],
		"work": 1,
		"budget": 4096,
	}
	var entries := [{"kind": "cast", "spell": spell_id, "amount": 0}, {"kind": "ward", "amount": 1}]
	player.configure_replay(session.state, {"spell_id": spell_id, "run": view}, session.catalog, entries)
	player.begin_construction(spell_id, "none")
	var circle: MagicCircle = player.get("_circle")
	(
		assert_array(circle.layers.map(func(layer: Dictionary) -> String: return layer.id))
		. is_equal(["import-heapq-plus", "salvo", "fork"])
	)
	var arrived: Array[String] = []
	circle.layer_added.connect(func(index: int) -> void: arrived.append(String(circle.layers[index].id)))
	var panel: ProgramCode = auto_free(ProgramCode.create(session))
	add_child(panel)
	panel.show_program(session.state, view)
	panel.import_resolved.connect(player.resolve_import)
	panel.shard_resolved.connect(player.resolve_shard)
	panel.skip.call_deferred()
	await panel.play_cast(view, "fast", true)
	assert_array(arrived).is_equal(["import-heapq-plus", "salvo"])
	player.resolve_shard(0)
	assert_array(arrived).is_equal(["import-heapq-plus", "salvo"])
	# With code off, the same measured prefix/call count constructs, and the unvisited fork stays absent.
	var fallback := LogPlayer.new(stage, {})
	fallback.cast_cards = player.cast_cards
	fallback.configure_replay(session.state, {"spell_id": spell_id, "run": view}, session.catalog, entries)
	stage.local_clock = true
	var finished: Array[bool] = [false]
	_play(fallback, entries, finished)
	var paced: MagicCircle = fallback.get("_circle")
	var paced_ids: Array[String] = [String(paced.layers[0].id)]
	paced.layer_added.connect(func(index: int) -> void: paced_ids.append(String(paced.layers[index].id)))
	for index in 60:
		stage.advance(1.0 / 30.0)
		await get_tree().process_frame
		if paced_ids.size() == 2:
			break
	stage.fast = true
	for index in 120:
		await get_tree().process_frame
		if finished[0]:
			break
	assert_bool(finished[0]).is_true()
	assert_array(paced_ids).is_equal(["import-heapq-plus", "salvo"])


func test_a_real_failed_program_constructs_only_visited_shards_then_cleans_up_with_code_on_or_off() -> void:
	var session := _program_session(["salvo", "import-heapq", "fork"])
	session.catalog.shards.fork.code.javascript = 'function fork(bolts, battle) { throw new Error("construction test"); }'
	var result: Dictionary = await session.command({"type": "cast", "spell_id": session.state.spells[0].id})
	assert_bool(result.ok).is_true()
	assert_bool((result.replay.run as Dictionary).has("misfire")).is_true()
	assert_int((result.replay.run.steps as Array).size()).is_equal(1)
	(
		assert_bool((result.state.log as Array).any(func(entry: Dictionary) -> bool: return entry.kind == "cast"))
		. is_false()
	)
	for code_speed: String in ["fast", "off"]:
		Settings.code_speed = code_speed
		var display := ShardrunSession.new(session.catalog, session.saves, "program")
		display.state = (result.before as Dictionary).duplicate(true)
		var fight: FightView = auto_free(FightView.create(display))
		fight.size = Vector2(1920, 1080)
		fight.stage.hero.preview_loadout = {"cast_light": "shard-weave"}
		fight.stage.hero.set_preview_skin("vesper")
		add_child(fight)
		await get_tree().process_frame
		var circles: Array[MagicCircle] = []
		var arrived: Array[String] = []
		var closed: Array[bool] = [false]
		fight.stage._fx.child_entered_tree.connect(
			func(node: Node) -> void:
				if node is MagicCircle:
					var circle := node as MagicCircle
					circles.append(circle)
					circle.layer_added.connect(
						func(index: int) -> void: arrived.append(String(circle.layers[index].id))
					)
					circle.tree_exiting.connect(func() -> void: closed[0] = circle._sealed and circle._closing >= 0.0)
		)
		var finished: Array[bool] = [false]
		_present(fight, result, finished)
		assert_int(circles.size()).is_equal(1)
		var deadline := Time.get_ticks_msec() + 10000
		while arrived.is_empty() and not finished[0] and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		assert_array(arrived).is_equal(["import-heapq"])
		if code_speed == "fast":
			assert_str(fight._program._title.text).contains("running")
		while not finished[0] and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		assert_bool(finished[0]).is_true()
		assert_array(arrived).is_equal(["import-heapq", "salvo"])
		assert_bool(closed[0]).is_true()
		assert_int(circles.size()).is_equal(1)
		fight.queue_free()
		await get_tree().process_frame


func _play(player: LogPlayer, entries: Array, finished: Array[bool]) -> void:
	await player.play(entries)
	finished[0] = true
