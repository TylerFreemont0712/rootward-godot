extends GdUnitTestSuite
## Mounted Publish and settings regressions. Content, drafts, backups, settings and game saves belong to this test.

const TEST_ROOT := "user://studio_test/publish-ui"
const TOWN := "lanternroot"
const OTHER := "studio-ui-other"
const LOOK := {
	"outfit": "outfit/tunic", "hair": "hair/short",
	"colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"},
}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}

var screen: OverworldScreen
var studio: StudioMode
var tools: StudioPublishTools
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_env := ""
var _old_saves_env := ""
var _old_settings_path := ""
var _old_studio := false
var _old_character := ""
var _old_language := ""
var _old_difficulty := ""
var _old_loadout: Dictionary = {}
var _old_catalog: Dictionary = {}


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_saves_env = OS.get_environment(Game.SAVES_ENV)
	_old_settings_path = Settings.path
	_old_studio = Settings.studio
	_old_character = Settings.character_skin
	_old_language = Settings.language
	_old_difficulty = Settings.difficulty
	_old_loadout = Settings.loadout.duplicate(true)
	_old_catalog = OverworldScreen._catalog_cache
	StudioMode.drafts_dir = _root.path_join("drafts")
	StudioMode.playtest_dir = _root.path_join("playtest")
	StudioMode.content_dir = _root.path_join("content")
	_copy_tree(ContentLoader.ROOT, StudioMode.content_dir)
	_fixture(TOWN, Vector2i(80, 56))
	_fixture(OTHER, Vector2i(10, 10))
	# The real town's pickups and places (v0.4) are cells of the real map, not of these fixtures: they go.
	for name: String in ["pickups.jsonc", "places.jsonc"]:
		DirAccess.remove_absolute(StudioMode.content_dir.path_join("packs/core/overworld").path_join(name))
	OS.set_environment("ROOTWARD_STUDIO", "1")
	Game.reset(_root.path_join("saves"))
	assert_bool(Game.boot()).is_true()
	# Game.boot reads the regular options. Every later settings write in this test points to its own file.
	Settings.path = _root.path_join("settings.json")
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()


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
	Settings.path = _old_settings_path
	Settings.studio = _old_studio
	Settings.character_skin = _old_character
	Settings.language = _old_language
	Settings.difficulty = _old_difficulty
	Settings.loadout = _old_loadout
	_restore_environment("ROOTWARD_STUDIO", _old_env)
	_restore_environment(Game.SAVES_ENV, _old_saves_env)
	_remove_tree(_root)
	screen = null
	studio = null
	tools = null


func test_topbar_review_confirm_reloads_temp_content_cache_and_history_and_blocks_modal_keys() -> void:
	await _open()
	var original := StudioFiles.read_text(_path(TOWN))
	var real_source := StudioFiles.read_text(StudioSession.path_of(TOWN))
	var cache := studio.catalog()
	var sid := studio.work.sid_at(0)
	assert_bool(studio.work.move([sid], Vector2i.RIGHT).ok).is_true()
	studio.select_sids([sid])
	var expected := studio.work.doc().to_text()
	tools.refresh_now()
	var publish := _button(_top(), StudioText.t("publish"))
	assert_bool(publish.disabled).is_false()
	publish.pressed.emit()
	await _frames(2)
	assert_bool(tools.dialog.visible).is_true()
	assert_array(tools.dialog.report.changes).has_size(1)
	assert_str(tools.dialog.report.changes[0].file).is_equal(_path(TOWN))
	assert_array(tools.dialog.report.changes[0].lines).is_equal(["Moved barrel from 3, 4 to 4, 4"])
	var state := screen.state.duplicate(true)
	await _tap(KEY_F1)
	await _tap(KEY_DELETE)
	assert_bool(studio.editing).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(expected)
	assert_dict(screen.state).is_equal(state)
	assert_bool(tools.dialog.publish_button.disabled).is_false()
	tools.dialog.publish_button.pressed.emit()
	await _frames(2)
	assert_bool(tools.last_result.ok).is_true()
	assert_array(tools.last_result.files).is_equal([_path(TOWN)])
	assert_bool(tools.dialog.visible).is_false()
	assert_str(StudioFiles.read_text(_path(TOWN))).is_equal(expected)
	assert_bool(is_same(cache, studio.catalog())).is_true()
	assert_bool(is_same(cache, OverworldScreen.catalog_of())).is_true()
	assert_that(studio.catalog().maps[TOWN].objects[0].at).is_equal(Vector2i(4, 4))
	assert_that(studio.current_map().objects[0].at).is_equal(Vector2i(4, 4))
	assert_int(studio.work.session().changes()).is_equal(0)
	assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(_path(TOWN), StudioMode.drafts_dir))).is_false()
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(_path(TOWN), tools.last_result.backup_stamp, tools.publisher.backups_dir))).is_equal(original)
	assert_str(StudioFiles.read_text(StudioSession.path_of(TOWN))).is_equal(real_source)


func test_publishing_another_map_preserves_external_changes_to_a_visited_clean_map() -> void:
	await _open()
	tools.jump(OTHER, Vector2i.ONE, -1)
	assert_bool(studio.work.move([studio.work.sid_at(0)], Vector2i.RIGHT).ok).is_true()
	assert_bool(studio.work.flush()).is_true()
	tools.jump(TOWN, Vector2i.ONE, -1)
	assert_int(studio.work.session().changes()).is_equal(0)
	var external := _doc(TOWN)
	external.data.name = "Edited outside Studio"
	external.data.objects[0].at = [7, 4]
	var text := external.to_text()
	assert_bool(StudioFiles.write_content(_path(TOWN), text)).is_true()
	_top().publish_pressed.emit()
	assert_array(tools.dialog.report.changes).has_size(1)
	assert_str(tools.dialog.report.changes[0].map_id).is_equal(OTHER)
	tools.dialog.publish_button.pressed.emit()
	await _frames(2)
	assert_bool(tools.last_result.ok).is_true()
	assert_array(tools.last_result.files).is_equal([_path(OTHER)])
	assert_str(StudioFiles.read_text(_path(TOWN))).is_equal(text)
	assert_str(studio.work.doc().data.name).is_equal("Edited outside Studio")
	assert_array(studio.work.doc().data.objects[0].at).is_equal([7, 4])
	assert_str(studio.current_map().name).is_equal("Edited outside Studio")
	assert_that(studio.current_map().objects[0].at).is_equal(Vector2i(7, 4))
	assert_that(OverworldScreen.catalog_of().maps[OTHER].objects[0].at).is_equal(Vector2i(4, 4))


func test_an_unvisited_saved_draft_enables_publish_after_entering_edit() -> void:
	var unvisited := StudioSession.open(OTHER, StudioMode.drafts_dir, StudioMode.content_dir)
	assert_object(unvisited).is_not_null()
	assert_bool(unvisited.do({"type": "move", "sids": [unvisited.doc().sids[0]], "by": [1, 0]}).ok).is_true()
	assert_bool(unvisited.save()).is_true()
	await _open()
	await get_tree().create_timer(0.3).timeout
	assert_bool(studio.work.sessions().has(OTHER)).is_false()
	var publish := _button(_top(), StudioText.t("publish"))
	assert_bool(publish.disabled).is_false()
	publish.pressed.emit()
	assert_bool(tools.dialog.visible).is_true()
	assert_array(tools.dialog.report.changes).has_size(1)
	assert_str(tools.dialog.report.changes[0].map_id).is_equal(OTHER)
	assert_int(studio.work.session().changes()).is_equal(0)
	tools.cancel_modal()
	assert_bool(StudioFiles.load_draft(_path(OTHER), StudioMode.drafts_dir).ok).is_true()


func test_errors_update_status_and_problem_rows_jump_to_an_unvisited_draft_object() -> void:
	var unvisited := StudioSession.open(OTHER, StudioMode.drafts_dir, StudioMode.content_dir)
	assert_bool(unvisited.do({"type": "add", "object": {
		"kind": "warp", "at": [5, 8], "to": {"map": "missing-map", "at": [0, 0]},
	}}).ok).is_true()
	assert_bool(unvisited.save()).is_true()
	await _open()
	await get_tree().create_timer(0.3).timeout
	assert_int(studio.status_bar().error_count).is_greater(0)
	studio.status_bar().problems_pressed.emit()
	var window := tools.problems_panel.get_parent() as Window
	assert_bool(window.visible).is_true()
	var found: Dictionary = {}
	for problem: Dictionary in tools.problems_panel.problems:
		if String(problem.map_id) == OTHER and int(problem.sid) > 0:
			found = problem
			break
	assert_dict(found).is_not_empty()
	var row := _button_containing(tools.problems_panel, String(found.message))
	assert_object(row).is_not_null()
	row.pressed.emit()
	await _frames(2)
	assert_bool(window.visible).is_false()
	assert_str(studio.current_map().id).is_equal(OTHER)
	assert_array(studio.selected_sids()).contains([int(found.sid)])
	assert_that(studio.studio_camera().centre).is_equal((Vector2(found.cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE)
	tools.open_publish()
	assert_bool(tools.dialog.publish_button.disabled).is_true()
	assert_int(int(tools.dialog.report.error_count)).is_greater(0)
	tools.cancel_modal()


func test_revert_requires_confirmation_preserves_cancel_and_blocks_modal_keys() -> void:
	await _open()
	var original := StudioFiles.read_text(_path(TOWN))
	var sid := studio.work.sid_at(0)
	assert_bool(studio.work.move([sid], Vector2i.RIGHT).ok).is_true()
	assert_bool(studio.work.flush()).is_true()
	studio.select_sids([sid])
	var changed := studio.work.doc().to_text()
	_top().revert_pressed.emit()
	var prompt := _confirmation()
	assert_bool(prompt.visible).is_true()
	var state := screen.state.duplicate(true)
	await _tap(KEY_F1)
	await _tap(KEY_DELETE)
	assert_bool(studio.editing).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(changed)
	assert_dict(screen.state).is_equal(state)
	tools.cancel_modal()
	assert_bool(prompt.visible).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(changed)
	assert_bool(StudioFiles.load_draft(_path(TOWN), StudioMode.drafts_dir).ok).is_true()
	_top().revert_pressed.emit()
	prompt.confirmed.emit()
	await _frames(2)
	assert_bool(tools.last_result.ok).is_true()
	assert_bool(prompt.visible).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(original)
	assert_that(studio.current_map().objects[0].at).is_equal(Vector2i(3, 4))
	assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(_path(TOWN), StudioMode.drafts_dir))).is_false()
	assert_str(StudioFiles.read_text(_path(TOWN))).is_equal(original)


func test_developer_settings_toggle_persists_to_the_isolated_settings_file() -> void:
	Settings.studio = false
	var panel := auto_free(FoundrySettingsPanel.make()) as FoundrySettingsPanel
	add_child(panel)
	var developer := _button(panel, StudioText.t("developer"))
	assert_object(developer).is_not_null()
	developer.pressed.emit()
	await _frames(2)
	var enable := _button(panel, FoundryUi.text("On", "オン"))
	assert_object(enable).is_not_null()
	enable.pressed.emit()
	await _frames(2)
	assert_bool(Settings.studio).is_true()
	assert_str(Settings.path).is_equal(_root.path_join("settings.json"))
	var saved: Dictionary = JSON.parse_string(StudioFiles.read_text(Settings.path))
	assert_bool(saved.studio).is_true()
	Settings.studio = false
	Settings.load_file(_root.path_join("settings.json"))
	assert_bool(Settings.studio).is_true()


func _open() -> void:
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var map: Dictionary = OverworldScreen.catalog_of().maps[TOWN]
	var state := OverworldState.fresh(TOWN, map.start, "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Publish UI tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	assert_object(studio).is_not_null()
	studio.set_editing(true)
	await _frames(2)
	tools = studio.publish_tools
	assert_object(tools).is_not_null()
	tools.publisher.backups_dir = _root.path_join("backups")


func _top() -> StudioTopBar:
	return studio.get_node("Chrome/TopBar") as StudioTopBar


func _confirmation() -> ConfirmationDialog:
	for child: Node in tools.get_children():
		if child is ConfirmationDialog:
			return child as ConfirmationDialog
	assert_bool(false).override_failure_message("Publish tools did not mount the Revert confirmation").is_true()
	return null


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


func _doc(id: String) -> StudioDoc:
	var parsed := StudioDoc.parse(_path(id), "map", StudioFiles.read_text(_path(id)))
	assert_bool(parsed.ok).is_true()
	return parsed.doc as StudioDoc


func _fixture(id: String, size: Vector2i) -> void:
	var rows: Array[String] = []
	for row: int in size.y:
		rows.append(".".repeat(size.x))
	var data := {
		"id": id, "name": "Publish UI test", "legend": {".": "grass"}, "ground": rows,
		"start": [1, 1], "facing": "down", "objects": [{"kind": "prop", "art": "barrel", "at": [3, 4]}],
	}
	assert_bool(StudioFiles.write_content(_path(id), JsoncWriter.map_text("// Publish UI fixture\n", data))).is_true()


func _tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_tree().root.push_input(event)
	await _frames(1)
	event.pressed = false
	get_tree().root.push_input(event)
	await _frames(1)


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text:
			return button
	return null


func _button_containing(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if text in button.text:
			return button
	return null


func _restore_environment(key: String, value: String) -> void:
	if value == "":
		OS.unset_environment(key)
	else:
		OS.set_environment(key, value)


func _copy_tree(source: String, target: String) -> void:
	assert_int(DirAccess.make_dir_recursive_absolute(target)).is_equal(OK)
	for folder: String in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(folder), target.path_join(folder))
	for file_name: String in DirAccess.get_files_at(source):
		assert_int(DirAccess.copy_absolute(source.path_join(file_name), target.path_join(file_name))).is_equal(OK)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for folder: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(folder))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
