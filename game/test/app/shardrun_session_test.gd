extends GdUnitTestSuite
## The session between the screens and the rules: saves after every command, runs spells in the sandbox, and casts
## exactly what the preview said.

const ROOT := "user://test-saves"

var catalog: Dictionary


func before() -> void:
	catalog = ContentLoader.load_shardrun().catalog


func before_test() -> void:
	_clear(ROOT)


func after_test() -> void:
	# A command starts the next turn's spells in the background; they finish here, not in another suite's test.
	Background.finish_all()


func after() -> void:
	_clear(ROOT)


func _session(playstyle := "spellbook") -> ShardrunSession:
	return ShardrunSession.new(catalog, SaveStore.new(ROOT), playstyle)


func _first_fight(session: ShardrunSession) -> Dictionary:
	for node: Dictionary in ShardrunMap.next_rooms(session.state.map, session.state.position):
		if node.kind == "fight":
			return node
	return {}


func test_a_new_run_is_saved_and_loads_back_the_same() -> void:
	var session := _session()
	session.start(SandboxJob.JAVASCRIPT, "beginner", "save-me")
	var node := _first_fight(session)
	var entered: Dictionary = await session.command({"type": "enter", "node_id": node.id})
	assert_bool(entered.ok).is_true()
	var again := _session()
	again.load_saved()
	assert_str(JsJson.stringify(again.state)).is_equal(JsJson.stringify(session.state))
	assert_int(typeof(again.state.integrity)).is_equal(TYPE_INT)


func test_the_cast_lands_what_its_preview_said() -> void:
	var session := _session()
	session.start(SandboxJob.JAVASCRIPT, "beginner", "preview-is-the-cast")
	var node := _first_fight(session)
	await session.command({"type": "enter", "node_id": node.id})
	var previews: Dictionary = await session.previews()
	var view: Dictionary = previews.spells["spell-1"]
	assert_bool(view.has("result")).is_true()
	assert_int((view.steps as Array).size()).is_equal(1)
	var cast: Dictionary = await session.command({"type": "cast", "spell_id": "spell-1"})
	assert_bool(cast.ok).is_true()
	assert_dict(cast.replay.run.result).is_equal(view.result)
	var dealt := 0
	for entry: Dictionary in cast.state.log:
		if entry.kind == "hit":
			dealt += int(entry.amount)
	assert_int(dealt).is_equal(int(view.result.damage))
	assert_int(cast.before.battle.mana - cast.state.battle.mana).is_equal(int(view.cost))


func test_a_refused_command_leaves_the_run_as_it_was() -> void:
	var session := _session()
	session.start(SandboxJob.JAVASCRIPT, "beginner", "refusals")
	await session.command({"type": "enter", "node_id": _first_fight(session).id})
	await session.command({"type": "cast", "spell_id": "spell-1"})
	var revision: int = session.state.revision
	var again: Dictionary = await session.command({"type": "cast", "spell_id": "spell-1"})
	assert_bool(again.ok).is_false()
	assert_str(again.error.code).is_equal("already-cast")
	assert_int(session.state.revision).is_equal(revision)
	var nowhere: Dictionary = await session.command({"type": "enter", "node_id": "l0-boss"})
	assert_str(nowhere.error.code).is_equal("not-on-map")


func test_programmer_difficulty_hides_the_numbers_but_not_the_cost() -> void:
	var session := _session()
	session.start(SandboxJob.JAVASCRIPT, "programmer", "no-peeking")
	await session.command({"type": "enter", "node_id": _first_fight(session).id})
	var previews: Dictionary = await session.previews()
	var view: Dictionary = previews.spells["spell-1"]
	assert_bool(view.has("result")).is_false()
	assert_array(view.steps).is_empty()
	assert_int(view.cost).is_greater(0)


func test_a_broken_save_is_set_aside_not_deleted() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var file := FileAccess.open(ROOT.path_join("spellbook.json"), FileAccess.WRITE)
	file.store_string('{"version": 1, "status": "map"}')
	file.close()
	var session := _session()
	session.load_saved()
	assert_bool(session.has_run()).is_false()
	assert_str(session.saves.problem).contains("version 1")
	var kept := Array(DirAccess.get_files_at(ROOT)).filter(func(n: String) -> bool: return n.contains("unreadable"))
	assert_int(kept.size()).is_equal(1)


func test_a_whole_run_plays_to_its_end_without_a_refusal() -> void:
	var session := _session()
	session.start(SandboxJob.JAVASCRIPT, "beginner", "bot-plays-it-through")
	var bot := ShardrunBot.new(session)
	var report: Dictionary = await bot.play(1500)
	prints("bot:", report.steps, "commands,", report.status, "on layer", session.state.layer + 1)
	assert_array(report.refusals).is_empty()
	assert_array(["won", "lost", "abandoned"]).contains([report.status])
	var saved := _session()
	saved.load_saved()
	assert_str(saved.state.status).is_equal(report.status)


func test_python_runs_a_fight_too() -> void:
	var session := _session()
	session.start(SandboxJob.PYTHON, "beginner", "python-fight")
	var bot := ShardrunBot.new(session)
	await bot.play_until("reward", 60)
	assert_array(bot.refusals).is_empty()
	assert_array(["reward", "lost", "map"]).contains([session.state.status])


static func _clear(root: String) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for name in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(name))
