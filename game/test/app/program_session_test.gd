extends GdUnitTestSuite
## A program run through the session (ADR-0012): drafted, fought in the real sandbox, and cast exactly as previewed.

const ROOT := "user://test-program-saves"

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func before_test() -> void:
	_clear(ROOT)


func after_test() -> void:
	Background.finish_all()


func after() -> void:
	_clear(ROOT)


func _session() -> ShardrunSession:
	return ShardrunSession.new(catalog, SaveStore.new(ROOT), "program")


func test_the_cast_lands_what_its_preview_said() -> void:
	var session := _session()
	session.start(SandboxJob.JAVASCRIPT, "beginner", "program-preview")
	var bot := ShardrunBot.new(session)
	await bot.play_until("battle", 40)
	assert_array(bot.refusals).is_empty()
	assert_str(session.state.playstyle).is_equal("program")
	await session.command(bot._deal_hand(session.state))
	var previews: Dictionary = await session.previews()
	var view: Dictionary = previews.spells["spell-1"]
	assert_bool(view.program).is_true()
	assert_int((view.steps as Array).size()).is_equal((session.state.spells[0].shards as Array).size())
	var cast: Dictionary = await session.command({"type": "cast", "spell_id": "spell-1"})
	assert_bool(cast.ok).is_true()
	assert_int(cast.replay.run.work).is_equal(int(view.work))
	var kinds: Array = cast.state.log.map(func(entry: Dictionary) -> String: return entry.kind)
	if view.timeout:
		assert_bool(kinds.has("timeout")).is_true()
		return
	var dealt := 0
	for entry: Dictionary in cast.state.log:
		if entry.kind == "hit":
			dealt += int(entry.amount)
	var first := (view.race as Array).filter(func(entry: Dictionary) -> bool: return entry.first)
	# A foe that acts first can shield itself before the bolts land; without one, the preview is exact.
	if first.is_empty():
		assert_int(dealt).is_equal(int(view.result.damage))
	assert_int(kinds.count("tempo")).is_equal(first.size())
	var paid: Array = cast.state.log.filter(func(entry: Dictionary) -> bool: return entry.kind == "cast")
	assert_int(int(paid[0].amount)).is_equal(int(view.cost))


func test_a_whole_program_run_plays_to_its_end_without_a_refusal() -> void:
	var session := _session()
	session.start(SandboxJob.JAVASCRIPT, "beginner", "program-bot")
	var bot := ShardrunBot.new(session)
	var report: Dictionary = await bot.play(1500)
	prints("program bot:", report.steps, "commands,", report.status, "on layer", session.state.layer + 1)
	assert_array(report.refusals).is_empty()
	assert_array(["won", "lost", "abandoned"]).contains([report.status])


func test_python_plays_a_program_fight_too() -> void:
	var session := _session()
	session.start(SandboxJob.PYTHON, "beginner", "program-python")
	var bot := ShardrunBot.new(session)
	bot.paradigm = "divide-conquer"
	await bot.play_until("reward", 80)
	assert_array(bot.refusals).is_empty()
	assert_array(["reward", "lost", "map"]).contains([session.state.status])


static func _clear(root: String) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for name in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(name))
