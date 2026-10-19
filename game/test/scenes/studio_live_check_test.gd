extends GdUnitTestSuite
## The Studio's deferred work stays off the frame and stays exact: the live check runs on a worker thread over a snapshot
## and shows what a synchronous review shows; the draft is written on a worker thread and reads back as it was.
## Content, drafts and saves are isolated copies, removed after each test.

const TEST_ROOT := "user://studio_test/live-check"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}

var screen: OverworldScreen
var studio: StudioMode
var tools: StudioPublishTools
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_env := ""
var _old_catalog: Dictionary = {}
var _old_clipboard: Array[Dictionary] = []


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
	_old_clipboard = StudioWork.clipboard
	StudioWork.clipboard = []
	StudioMode.drafts_dir = _root.path_join("drafts")
	StudioMode.playtest_dir = _root.path_join("playtest")
	StudioMode.content_dir = _root.path_join("content")
	_copy_tree("res://content/packs/core/overworld", StudioMode.content_dir.path_join("packs/core/overworld"))
	OS.set_environment("ROOTWARD_STUDIO", "1")
	Game.reset(_root.path_join("saves"))
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()
	assert_bool(StudioFiles.write_content(_path(), JsoncWriter.map_text("// Live check fixture\n", _fixture()))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var map: Dictionary = OverworldScreen.catalog_of().maps[TOWN]
	var state := OverworldState.fresh(TOWN, map.start, "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Live checker"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
	await _frames(2)
	tools = studio.publish_tools
	await _idle()


func after_test() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	Sound.silence()
	await _frames(6)
	Background.finish_all()
	Game.reset()
	StudioMode.drafts_dir = _old_drafts
	StudioMode.playtest_dir = _old_playtest
	StudioMode.content_dir = _old_content
	OverworldScreen._catalog_cache = _old_catalog
	StudioWork.clipboard = _old_clipboard
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


# --- the live check ------------------------------------------------------------------------------------------------


func test_the_live_status_after_each_change_equals_a_synchronous_review() -> void:
	var seen_errors := 0
	var steps: Array[Callable] = [
		func() -> void: assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true(),
		func() -> void: assert_bool(studio.work.command({"type": "add", "object": {"kind": "prop", "art": "no-such-picture", "at": [9, 9]}, "index": -1}).ok).is_true(),
		func() -> void: assert_bool(studio.work.command({"type": "add", "object": {"kind": "warp", "at": [3, 8], "to": {"map": "no-such-map", "at": [0, 0]}}, "index": -1}).ok).is_true(),
		func() -> void: assert_bool(studio.work.move([studio.work.sid_at(0)], Vector2i(0, 1), true).ok).is_true(),
		func() -> void: assert_bool(studio.work.undo()).is_true(),
		func() -> void: assert_bool(studio.work.undo()).is_true(),
		func() -> void: assert_bool(studio.work.undo()).is_true(),
	]
	for step: Callable in steps:
		step.call()
		await _idle()
		var expected := _review()
		seen_errors = maxi(seen_errors, int(expected.error_count))
		assert_array(tools.review_data.problems).is_equal(expected.problems)
		assert_int(int(tools.review_data.error_count)).is_equal(int(expected.error_count))
		assert_int(int(tools.review_data.warning_count)).is_equal(int(expected.warning_count))
		assert_int(studio.status_bar().error_count).is_equal(int(expected.error_count))
		assert_int(studio.status_bar().warning_count).is_equal(int(expected.warning_count))
		assert_array(tools.problems_panel.problems).is_equal(expected.problems)
	assert_int(seen_errors).is_greater(0)


func test_a_check_snapshot_does_not_see_a_change_made_after_it_started() -> void:
	var session := studio.work.session()
	var check := StudioLiveCheck.new(_service())
	assert_bool(studio.work.command({"type": "add", "object": {"kind": "prop", "art": "no-such-picture", "at": [9, 9]}, "index": -1}).ok).is_true()
	var asked := _review()
	assert_bool(check.start(studio.work.sessions(), session.map_id)).is_true()
	assert_bool(check.start(studio.work.sessions(), session.map_id)).is_false()
	assert_bool(studio.work.undo()).is_true()
	var done := check.wait()
	assert_bool(check.busy()).is_false()
	assert_array(done.report.problems).is_equal(asked.problems)
	assert_int(int(done.report.error_count)).is_equal(int(asked.error_count))
	assert_int(int(done.current_changes)).is_equal(1)
	assert_bool(bool(done.fresh)).is_true()


func test_a_result_older_than_the_newest_change_is_dropped_and_never_shown() -> void:
	tools.set_process(false)
	var before := studio.status_bar().error_count
	assert_bool(studio.work.command({"type": "add", "object": {"kind": "prop", "art": "no-such-picture", "at": [9, 9]}, "index": -1}).ok).is_true()
	tools._process(0.3)
	assert_bool(tools._check.busy()).is_true()
	# The change that makes the running check old: the error goes away again.
	assert_bool(studio.work.undo()).is_true()
	while not WorkerThreadPool.is_task_completed(tools._check._job.task):
		OS.delay_msec(5)
	tools._process(0.0)
	assert_bool(tools._check.busy()).is_false()
	assert_int(studio.status_bar().error_count).is_equal(before)
	assert_bool(tools.idle()).is_false()
	tools._process(0.3)
	assert_bool(tools._check.busy()).is_true()
	while not WorkerThreadPool.is_task_completed(tools._check._job.task):
		OS.delay_msec(5)
	tools._process(0.0)
	assert_bool(tools.idle()).is_true()
	assert_int(studio.status_bar().error_count).is_equal(int(_review().error_count))
	assert_int(studio.status_bar().error_count).is_equal(before)


func test_a_synchronous_refresh_makes_a_running_check_old() -> void:
	tools.set_process(false)
	assert_bool(studio.work.command({"type": "add", "object": {"kind": "prop", "art": "no-such-picture", "at": [9, 9]}, "index": -1}).ok).is_true()
	tools._process(0.3)
	assert_bool(tools._check.busy()).is_true()
	assert_bool(studio.work.undo()).is_true()
	var report := tools.refresh_now()
	assert_int(int(report.error_count)).is_equal(int(_review().error_count))
	while not WorkerThreadPool.is_task_completed(tools._check._job.task):
		OS.delay_msec(5)
	var shown: Array[Dictionary] = []
	shown.assign(tools.review_data.problems)
	tools._process(0.0)
	assert_array(tools.review_data.problems).is_equal(shown)
	assert_bool(tools.idle()).is_true()


func test_a_snapshot_keeps_its_doc_while_the_session_goes_on_editing() -> void:
	var session := studio.work.session()
	var snapshot := session.snapshot()
	var text := snapshot.doc().to_text()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.work.place(StudioAssets.template("crate"), Vector2i(8, 6)).ok).is_true()
	assert_str(snapshot.doc().to_text()).is_equal(text)
	assert_str(session.doc().to_text()).is_not_equal(text)
	assert_int(snapshot.changes()).is_equal(0)
	assert_int(session.changes()).is_equal(1)


func test_the_count_of_changes_follows_the_doc() -> void:
	var session := studio.work.session()
	assert_int(session.changes()).is_equal(0)
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	assert_int(session.changes()).is_equal(1)
	assert_int(session.changes()).is_equal(StudioDiff.lines(session.base_doc, session.doc()).size())
	assert_bool(studio.work.undo()).is_true()
	assert_int(session.changes()).is_equal(0)


# --- the draft ---------------------------------------------------------------------------------------------------


func test_a_draft_written_in_the_background_reads_back_exactly() -> void:
	var session := studio.work.session()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	assert_bool(session.unsaved).is_true()
	assert_bool(session.save_later()).is_true()
	# Never two writes of one draft at once.
	assert_bool(session.save_later()).is_false()
	assert_bool(session.writing()).is_true()
	assert_bool(session.unsaved).is_true()
	assert_bool(session.settle()).is_true()
	assert_bool(session.writing()).is_false()
	assert_bool(session.unsaved).is_false()
	_assert_draft_is(session)
	# The same bytes a synchronous save writes (apart from the clock).
	var other := _root.path_join("other-drafts")
	assert_bool(StudioFiles.save_draft(session.doc(), session.base_text, other, session.base_doc.sids)).is_true()
	var written := _record(StudioFiles.draft_path(session.path, StudioMode.drafts_dir))
	var direct := _record(StudioFiles.draft_path(session.path, other))
	written.erase("saved_at")
	direct.erase("saved_at")
	assert_dict(written).is_equal(direct)


func test_a_change_made_while_the_write_runs_stays_unsaved_until_it_is_written() -> void:
	var session := studio.work.session()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	assert_bool(session.save_later()).is_true()
	var first := session.doc().to_text()
	assert_bool(studio.work.place(StudioAssets.template("crate"), Vector2i(8, 6)).ok).is_true()
	session.settle()
	assert_bool(session.unsaved).is_true()
	assert_str(_draft_text(session)).is_equal(first)
	assert_bool(studio.work.flush()).is_true()
	assert_bool(session.unsaved).is_false()
	_assert_draft_is(session)


func test_flush_finishes_the_latest_save_before_it_returns() -> void:
	var session := studio.work.session()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	assert_bool(session.save_later()).is_true()
	assert_bool(studio.work.place(StudioAssets.template("crate"), Vector2i(8, 6)).ok).is_true()
	assert_bool(studio.work.flush()).is_true()
	assert_bool(session.writing()).is_false()
	assert_bool(session.unsaved).is_false()
	_assert_draft_is(session)


func test_leaving_edit_keeps_the_newest_draft() -> void:
	var session := studio.work.session()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	assert_bool(session.save_later()).is_true()
	assert_bool(studio.work.place(StudioAssets.template("crate"), Vector2i(8, 6)).ok).is_true()
	studio.set_editing(false)
	await _frames(2)
	assert_bool(session.writing()).is_false()
	assert_bool(session.unsaved).is_false()
	_assert_draft_is(session)


func test_the_studio_writes_the_draft_by_itself_in_the_background() -> void:
	tools.set_process(false)
	var session := studio.work.session()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	tools._process(StudioPublishTools.DRAFT_AFTER + 0.1)
	assert_bool(session.writing() or not session.unsaved).is_true()
	while session.writing():
		OS.delay_msec(5)
		tools._process(0.0)
	assert_bool(session.unsaved).is_false()
	_assert_draft_is(session)


func test_a_revert_does_not_bring_back_a_draft_that_was_being_written() -> void:
	var session := studio.work.session()
	var original := session.base_doc.to_text()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(6, 6)).ok).is_true()
	assert_bool(session.save_later()).is_true()
	tools.request_revert()
	tools.confirm_revert()
	assert_bool(session.writing()).is_false()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(session.path, StudioMode.drafts_dir))).is_false()
	assert_str(session.doc().to_text()).is_equal(original)
	assert_int(session.changes()).is_equal(0)


# --- helpers ------------------------------------------------------------------------------------------------------


func _service() -> StudioPublish:
	var service := StudioPublish.new()
	service.content_root = studio.content_root()
	service.drafts_dir = StudioMode.drafts_dir
	return service


## The synchronous answer for the same sessions: the one the live status has to equal.
func _review() -> Dictionary:
	return _service().review(studio.work.sessions())


func _path() -> String:
	return StudioSession.path_of(TOWN, StudioMode.content_dir)


func _record(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).is_true()
	return parsed as Dictionary


func _draft_text(session: StudioSession) -> String:
	var record := StudioFiles.load_draft(session.path, StudioMode.drafts_dir)
	assert_bool(bool(record.ok)).is_true()
	return (record.doc as StudioDoc).to_text()


func _assert_draft_is(session: StudioSession) -> void:
	var record := StudioFiles.load_draft(session.path, StudioMode.drafts_dir)
	assert_bool(bool(record.ok)).is_true()
	assert_str((record.doc as StudioDoc).to_text()).is_equal(session.doc().to_text())
	assert_array((record.doc as StudioDoc).sids).is_equal(session.doc().sids)
	assert_str(String(record.base_text)).is_equal(session.base_text)


## Frames until no check is waiting to start or running, so the status bar shows the newest answer.
func _idle() -> void:
	for frame: int in 600:
		if tools.idle():
			return
		await get_tree().process_frame
	assert_bool(tools.idle()).is_true()


func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in 14:
		rows.append("....................")
	return {"id": TOWN, "name": "Live check test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "prop", "art": "oak", "at": [2, 10]},
		{"kind": "prop", "art": "crate", "at": [5, 5], "flip": true},
		{"kind": "building", "art": "cottage", "at": [12, 2], "size": [3, 3], "door": [1, 2]},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _copy_tree(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)
	for directory: String in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), target.path_join(directory))
	for file: String in DirAccess.get_files_at(source):
		assert_int(DirAccess.copy_absolute(source.path_join(file), target.path_join(file))).is_equal(OK)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
