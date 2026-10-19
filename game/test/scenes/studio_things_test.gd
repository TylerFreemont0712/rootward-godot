extends GdUnitTestSuite
## Things that take code, made in the Studio (Concept/v0.3/10, S8). The acceptance: a barrel made a thing whose code
## answers when used, unlocked by met-innkeeper: before meeting Marta it is a plain barrel (no prompt, nothing runs),
## after it answers; Publish writes its map, its file and its two starters, and the world loads them. Then: an id that
## is taken or not an id is refused in the dialog; a thing whose prop was undone is a warning; a thing file made meanwhile
## is a conflict. Content, drafts and saves are isolated copies.

const TEST_ROOT := "user://studio_test/things"
const OVERWORLD := "res://scenes/overworld/overworld.tscn"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true, "first-action": true}
const WIDTH := 20
const HEIGHT := 48
const BARREL := Vector2i(5, 11)
const SAYS := "Hello from the barrel"

var screen: OverworldScreen
var studio: StudioMode
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_env := ""
var _old_catalog: Dictionary = {}


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
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
	StudioAssets.reload()
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Things fixture\n", _fixture()))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Things tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
	await _frames(2)


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
	StudioAssets.reload()
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


## A grass town: a barrel with nothing to say, Marta beside it, and the player's house.
func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {"id": TOWN, "name": "Things test", "legend": {".": "grass"}, "ground": rows, "start": [2, 2], "facing": "down", "objects": [
		{"kind": "prop", "art": "barrel", "at": [BARREL.x, BARREL.y]},
		{"kind": "person", "id": "innkeeper", "at": [9, 11], "facing": "left"},
		{"kind": "building", "art": "home", "at": [10, 39], "size": [6, 6], "door": [3, 5], "to": {"map": "home", "at": [5, 6], "facing": "up"}},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _barrel_sid() -> int:
	var objects: Array = studio.work.doc().data.objects
	for index: int in objects.size():
		if String((objects[index] as Dictionary).get("art", "")) == "barrel":
			return studio.work.sid_at(index)
	return -1


func _publisher() -> StudioPublish:
	var publisher := StudioPublish.new()
	publisher.content_root = StudioMode.content_dir
	publisher.drafts_dir = StudioMode.drafts_dir
	publisher.backups_dir = _root.path_join("backups")
	return publisher


func _thing_path(name: String) -> String:
	return StudioMode.content_dir.path_join("packs/core/overworld/things").path_join(name)


## The dialog filled in as the player would, and OK pressed.
func _make(id: String, unlock: String) -> StudioThingDialog:
	var dialog := studio.thing_dialog
	dialog.open(_barrel_sid())
	dialog.set_part("id", id)
	dialog.set_part("unlock", unlock)
	dialog.set_part("python", 'def on_use(thing, player):\n    return {"say": "%s"}\n' % SAYS)
	dialog.set_part("javascript", 'function onUse(thing, player) {\n  return {say: "%s"};\n}\n' % SAYS)
	dialog.confirmed.emit()
	return dialog


func _thing_runs() -> Array[Dictionary]:
	return DebugLog.latest(studio.debug.book, DebugLog.LIMIT, ["thing"] as Array[String])


func test_a_barrel_unlocked_by_meeting_marta_is_silent_before_and_answers_after_and_publishes() -> void:
	studio.select_sids([_barrel_sid()])
	await _frames(1)
	assert_bool((studio.inspector().find_child("MakeThing", true, false) as Button).visible).is_true()
	var dialog := _make("talking-barrel", "met-innkeeper")
	assert_str(dialog.problem).is_empty()
	assert_bool(dialog.visible).is_false()
	var barrel := studio.work.raw(studio.work.index_of(_barrel_sid()))
	assert_str(String(barrel.id)).is_equal("talking-barrel")
	assert_str(JSON.stringify((barrel.program as Dictionary).unlocked_by)).is_equal(JSON.stringify({"flag": "met-innkeeper"}))
	# Play the draft, standing below the barrel and facing it.
	studio.set_play_draft(true)
	studio.set_editing(false)
	await _frames(2)
	var player := screen.get("_player") as Walker
	player.place(BARREL + Vector2i.DOWN, "up")
	screen.state = OverworldState.moved(screen.state, TOWN, BARREL + Vector2i.DOWN, "up")
	screen.call("_update_prompt")
	assert_str((screen.get("_prompt") as Label).text).override_failure_message("locked: a plain barrel, no prompt").is_empty()
	screen.call("_interact")
	await _frames(30)
	assert_array(_thing_runs()).override_failure_message("locked: its code does not run").is_empty()
	# Meeting Marta unlocks it.
	assert_bool(studio.debug.set_flag("met-innkeeper")).is_true()
	await _frames(1)
	screen.call("_update_prompt")
	assert_str((screen.get("_prompt") as Label).text).is_equal("Space: use it   X: its code")
	screen.call("_interact")
	for frame: int in 600:
		if not _thing_runs().is_empty():
			break
		await get_tree().process_frame
	var runs := _thing_runs()
	assert_array(runs).has_size(1)
	assert_str(String(((runs[0].data as Dictionary).verdict as Dictionary).get("say", ""))).is_equal(SAYS)
	# Publish: the map, the thing's file and its starters, and the world loads them.
	studio.set_play_draft(false)
	await _frames(1)
	assert_bool(studio.work.flush()).is_true()
	var result := _publisher().publish(studio.work.sessions(), true)
	assert_bool(result.ok).override_failure_message("publish: %s %s" % [str(result.get("error", "")), str(result.get("problems", []))]).is_true()
	for name: String in ["talking-barrel.jsonc", "talking-barrel.starter.py", "talking-barrel.starter.js"]:
		assert_bool(StudioFiles.exists(_thing_path(name))).override_failure_message(name).is_true()
	assert_str(StudioFiles.read_text(_thing_path("talking-barrel.starter.py"))).contains(SAYS)
	assert_str(StudioFiles.read_text(_path(TOWN))).contains('"id": "talking-barrel"')
	assert_str(StudioFiles.read_text(_path(TOWN))).contains('"unlocked_by": {"flag": "met-innkeeper"}')
	assert_dict(StudioFiles.load_file_drafts(StudioMode.drafts_dir)).override_failure_message("the file drafts are gone once written").is_empty()
	var loaded := OverworldContent.load_world(StudioMode.content_dir)
	assert_bool((loaded.catalog.things as Dictionary).has("talking-barrel")).is_true()
	for diagnostic: Dictionary in loaded.diagnostics:
		assert_str(String(diagnostic.get("file", ""))).override_failure_message(ContentLoader.describe(diagnostic)).not_contains("talking-barrel")


func test_the_dialog_refuses_an_id_that_is_taken_or_not_an_id() -> void:
	var dialog := _make("cabbage-gate", "")
	assert_str(dialog.problem).contains("there already")
	assert_bool(dialog.visible).override_failure_message("it stays open").is_true()
	dialog.set_part("id", "Not An Id")
	dialog.confirmed.emit()
	assert_str(dialog.problem).contains("lower case")
	dialog.set_part("id", "fine-barrel")
	dialog.set_part("fields", "[1, 2]")
	dialog.confirmed.emit()
	assert_str(dialog.problem).contains("not a JSON object")
	assert_bool(studio.work.raw(studio.work.index_of(_barrel_sid())).has("program")).is_false()


func test_a_thing_whose_prop_was_undone_is_a_warning_and_a_file_made_meanwhile_a_conflict() -> void:
	_make("talking-barrel", "")
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.work.flush()).is_true()
	var report := _publisher().review(studio.work.sessions())
	var unused: Array = (report.problems as Array).filter(func(problem: Dictionary) -> bool: return String(problem.message).contains("no prop of any map takes"))
	assert_int(unused.size()).is_equal(1)
	assert_bool(StudioFiles.write_content(_thing_path("talking-barrel.starter.py"), "# somebody's\n")).is_true()
	report = _publisher().review(studio.work.sessions())
	var conflicted: Array = (report.conflicts as Array).filter(func(conflict: Dictionary) -> bool: return String(conflict.file).ends_with("talking-barrel.starter.py"))
	assert_int(conflicted.size()).override_failure_message("a file made since the draft began").is_equal(1)


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
