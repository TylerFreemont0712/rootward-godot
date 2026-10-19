extends GdUnitTestSuite
## P06 delivery walkthrough A through mounted buttons, keyboard/world input and fixture Publish.
## The one integration story owns content, drafts, backups, settings and saves; the existing People/Rooms suites
## retain the negative matrix. Runtime door arrivals call the same callback used by the walking animation.

const TEST_ROOT := "user://studio_test/people-acceptance"
const OVERWORLD := "res://scenes/overworld/overworld.tscn"
const TOWN := "lanternroot"
const ROOM := "cottage-pell"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}
const WIDTH := 20
const HEIGHT := 48
## Pell's cottage: 5 x 5 at (3, 20), its door at (2, 4), so the door is the cell (5, 24) and its front (5, 25).
const PELL_AT := Vector2i(3, 20)
const PELL_DOOR := Vector2i(5, 24)
const PELL_FRONT := Vector2i(5, 25)

var screen: OverworldScreen
var studio: StudioMode
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_env := ""
var _old_catalog: Dictionary = {}
var _old_settings_path := ""
var _old_saves_env := ""
var _real_town_before := ""


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
	_old_settings_path = Settings.path
	_old_saves_env = OS.get_environment(Game.SAVES_ENV)
	_real_town_before = StudioFiles.read_text(StudioSession.path_of(TOWN))
	StudioMode.drafts_dir = _root.path_join("drafts")
	StudioMode.playtest_dir = _root.path_join("playtest")
	StudioMode.content_dir = _root.path_join("content")
	_copy_tree(ContentLoader.ROOT, StudioMode.content_dir)
	for file: String in ["pickups.jsonc", "places.jsonc"]:
		DirAccess.remove_absolute(StudioMode.content_dir.path_join("packs/core/overworld").path_join(file))
	# This small authored map has no real town's scheduled destinations; scheduled relocation has its own suite.
	var schedules_path := StudioMode.content_dir.path_join("packs/core/overworld/schedules.jsonc")
	assert_bool(StudioFiles.write_content(schedules_path, JsoncWriter.schedules_text("", {}))).is_true()
	OS.set_environment("ROOTWARD_STUDIO", "1")
	Game.reset(_root.path_join("saves"))
	Game.boot()
	Settings.path = _root.path_join("settings.json")
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()
	StudioAssets.reload()
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Rooms fixture\n", _fixture()))).is_true()
	var talk_path := StudioMode.content_dir.path_join("packs/core/overworld/talk/pell.jsonc")
	assert_bool(StudioFiles.write_content(talk_path, JSON.stringify({"id": "pell", "start": [{"goto": "hello"}], "nodes": {"hello": {"lines": [{"text": "P06 original greeting"}]}}}))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Rooms tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.publish_tools.publisher.backups_dir = _root.path_join("backups")
	studio.set_overlay("doors", true)
	await _tap(KEY_F2)
	assert_bool(studio.editing).is_true()
	await _frames(2)


func after_test() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	Sound.silence()
	await _frames(6)
	Background.finish_all()
	assert_str(StudioFiles.read_text(StudioSession.path_of(TOWN))).override_failure_message("real town remains untouched").is_equal(_real_town_before)
	Game.reset()
	Settings.path = _old_settings_path
	OS.set_environment(Game.SAVES_ENV, _old_saves_env)
	StudioMode.drafts_dir = _old_drafts
	StudioMode.playtest_dir = _old_playtest
	StudioMode.content_dir = _old_content
	OverworldScreen._catalog_cache = _old_catalog
	StudioAssets.reload()
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


## A grass town 20 x 48: a barrel, Pell's cottage (no room yet), the player's house whose room (home.jsonc, from the
## content copy) leads back to (13, 45), and Pell outside.
func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	rows[0] = "~" + ".".repeat(WIDTH - 1)
	return {"id": TOWN, "name": "Rooms test", "legend": {".": "grass", "~": "water"}, "ground": rows, "start": [2, 2], "facing": "down", "objects": [
		{"kind": "prop", "art": "barrel", "at": [5, 11]},
		{"kind": "building", "art": "cottage-pell", "at": [PELL_AT.x, PELL_AT.y], "size": [5, 5], "door": [2, 4]},
		{"kind": "building", "art": "home", "at": [10, 39], "size": [6, 6], "door": [3, 5], "to": {"map": "home", "at": [5, 6], "facing": "up"}},
		{"kind": "person", "id": "pell", "at": [9, 10], "facing": "right"},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


## The sid of the first object of the shown map's draft for which `match` is true.
func _sid_of(match: Callable) -> int:
	var objects: Array = studio.work.doc().data.objects
	for index: int in objects.size():
		if match.call(objects[index]):
			return studio.work.sid_at(index)
	return -1


func _pell_sid() -> int:
	return _sid_of(func(object: Dictionary) -> bool: return String(object.get("art", "")) == "cottage-pell")


func _raw(sid: int) -> Dictionary:
	return studio.work.raw(studio.work.index_of(sid))


func _map_id() -> String:
	return String(studio.current_map().get("id", ""))


func _top() -> StudioTopBar:
	return studio.get_node("Chrome/TopBar") as StudioTopBar


## A world point in the root viewport's canvas coordinates.
func _canvas(world: Vector2) -> Vector2:
	var view := studio.pixel_view()
	return view.get_global_transform() * view.to_screen(world)


func _mouse_at(world: Vector2, pressed: Variant) -> void:
	var event: InputEvent
	if pressed == null:
		var motion := InputEventMouseMotion.new()
		motion.position = _canvas(world)
		motion.global_position = motion.position
		event = motion
	else:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = bool(pressed)
		click.position = _canvas(world)
		click.global_position = click.position
		event = click
	get_tree().root.push_input(event, true)
	await get_tree().process_frame


func _centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE


## Waits (at most `frames` frames) until the player is on `map`, through a door's fade.
func _until_on(map: String, frames := 90) -> void:
	for frame: int in frames:
		if String(screen.state.map) == map and not bool(screen.get("_busy")):
			return
		await get_tree().process_frame


## JSON in the data's own key order (JSON.stringify sorts by default).
func _json(value: Variant) -> String:
	return JSON.stringify(value, "", false)


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


func _tap(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_tree().root.push_input(event, true)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	get_tree().root.push_input(event, true)
	await get_tree().process_frame


func _press(parent: Node, button_name: String) -> void:
	var button := parent.find_child(button_name, true, false) as Button
	assert_object(button).override_failure_message("mounted button %s" % button_name).is_not_null()
	if button == null:
		return
	assert_bool(button.disabled).override_failure_message("enabled button %s" % button_name).is_false()
	button.pressed.emit()
	await _frames(2)


func _pick_map(id: String) -> void:
	var picker := _top().find_child("MapPicker", true, false) as OptionButton
	for index: int in picker.item_count:
		if _top().map_ids[index] == id:
			picker.select(index)
			picker.item_selected.emit(index)
			await _frames(2)
			assert_str(_map_id()).is_equal(id)
			return
	assert_bool(false).override_failure_message("map picker contains %s" % id).is_true()


func _pick_link_map(id: String) -> void:
	var picker := studio.link.panel().find_child("LinkDestination", true, false) as OptionButton
	for index: int in picker.item_count:
		if String(picker.get_item_metadata(index)) == id:
			picker.select(index)
			picker.item_selected.emit(index)
			await _frames(2)
			assert_str(_map_id()).is_equal(id)
			return
	assert_bool(false).override_failure_message("link picker contains %s" % id).is_true()


func _click_cell(cell: Vector2i) -> void:
	studio.focus(_centre(cell))
	await _frames(2)
	await _mouse_at(_centre(cell), null)
	await _mouse_at(_centre(cell), true)
	await _mouse_at(_centre(cell), false)


func _people() -> Array:
	return studio.work.doc().data.objects.filter(func(object: Dictionary) -> bool: return object.get("id") == "pell")


func _restart() -> void:
	assert_bool(studio.work.flush()).is_true()
	screen.queue_free()
	await _frames(6)
	Background.finish_all()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.publish_tools.publisher.backups_dir = _root.path_join("backups")
	await _tap(KEY_F2)
	assert_bool(studio.editing).is_true()
	await _frames(2)


func test_delivery_a_people_room_dialogue_publish_and_draft_free_reload() -> void:
	# F2 and the mounted shelf locate the static authored placement.
	await _press(_top(), "Tab_people")
	await _press(studio.people_panel(), "Locate_pell_" + TOWN)
	assert_str(String(studio.selected_object().id)).is_equal("pell")
	assert_array(studio.work.raw(studio.selected_indexes()[0]).at).is_equal([9, 10])
	var person_sid := studio.selected_sids()[0]
	var before := studio.work.doc().to_text()
	var history_count := studio.work.session().history.labels().size()
	await _press(studio.people_panel(), "Place_pell")
	await _tap(KEY_R)
	assert_str(String(studio.arrange.placing.facing)).is_equal("left")
	await _click_cell(Vector2i(7, 12))
	assert_array(_people()).has_size(1)
	assert_array(_people()[0].at).is_equal([7, 12])
	assert_str(String(_people()[0].facing)).is_equal("left")
	assert_int(studio.selected_sids()[0]).is_equal(person_sid)
	assert_int(studio.work.session().history.labels().size()).is_equal(history_count + 1)
	_top().undo_pressed.emit()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	_top().redo_pressed.emit()
	var town_moved := studio.work.doc().to_text()

	# The same mounted Place here gesture confirms a coordinated move only after acceptance.
	await _pick_map("home")
	var home_before := studio.work.doc().to_text()
	await _press(studio.people_panel(), "Place_pell")
	await _click_cell(Vector2i(3, 4))
	var confirm := studio.get_node("Chrome/MovePerson") as ConfirmationDialog
	assert_bool(confirm.visible).is_true()
	confirm.canceled.emit()
	assert_str(studio.work.doc().to_text()).is_equal(home_before)
	assert_str((studio.work.sessions()[TOWN] as StudioSession).doc().to_text()).is_equal(town_moved)
	await _press(studio.people_panel(), "Place_pell")
	await _tap(KEY_R)
	await _click_cell(Vector2i(3, 4))
	assert_bool(confirm.visible).is_true()
	confirm.confirmed.emit()
	await _frames(2)
	assert_array(_people()).has_size(1)
	assert_array(_people()[0].at).is_equal([3, 4])
	assert_str((studio.work.sessions()[TOWN] as StudioSession).doc().to_text()).not_contains('"id": "pell"')
	_top().undo_pressed.emit()
	assert_str(studio.work.doc().to_text()).is_equal(home_before)
	assert_str((studio.work.sessions()[TOWN] as StudioSession).doc().to_text()).is_equal(town_moved)
	# Persist the undo, restart, and exercise the shared redo and undo from its source map.
	await _restart()
	await _pick_map(TOWN)
	assert_str(studio.work.doc().to_text()).is_equal(town_moved)
	_top().redo_pressed.emit()
	assert_array(_people()).is_empty()
	await _pick_map("home")
	assert_array(_people()).has_size(1)
	_top().undo_pressed.emit()
	assert_str(studio.work.doc().to_text()).is_equal(home_before)
	await _pick_map(TOWN)
	assert_str(studio.work.doc().to_text()).is_equal(town_moved)

	# Make interior from the entrance card, then furnish it through the mounted Objects catalog.
	await _press(_top(), "Tab_people")
	await _press(studio.people_panel(), "View_entrances")
	await _press(studio.people_panel(), "EntranceRoom_1")
	assert_str(_map_id()).is_equal(ROOM)
	assert_array(_top().map_labels).contains(["Pell's cottage  (room, new)"])
	assert_bool(studio.work.is_new_map(ROOM)).is_true()
	await _pick_map(TOWN)
	await _press(studio.people_panel(), "EntranceGo_1")
	assert_str(studio.tab).is_equal("objects")
	assert_str(_map_id()).is_equal(ROOM)
	var bed := studio.place_panel().find_child("Card_bed", true, false) as StudioCatalogCard
	assert_object(bed).is_not_null()
	bed.picked.emit("bed")
	await _click_cell(Vector2i(1, 3))
	await _tap(KEY_ESCAPE)
	var furniture: Array = studio.work.doc().data.objects.filter(func(object: Dictionary) -> bool: return object.get("art") == "bed")
	assert_array(furniture).has_size(1)

	# A link rejects the wall, furniture, transition, water and off-map cells, then accepts a custom facing.
	await _pick_map(TOWN)
	await _press(_top(), "Tab_people")
	await _press(studio.people_panel(), "EntranceLink_1")
	await _pick_link_map(ROOM)
	var room_before := studio.work.doc().to_text()
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(1, 2), Vector2i(5, 7), Vector2i(-1, 3)]:
		assert_bool(studio.link.check(cell).ok).override_failure_message("invalid arrival %s" % cell).is_false()
		studio.link.click(cell, Vector2(500, 300))
		assert_str(studio.link.stage).is_equal("choose_target_cell")
	assert_str(studio.work.doc().to_text()).is_equal(room_before)
	await _pick_link_map(TOWN)
	assert_bool(studio.link.check(Vector2i.ZERO).ok).is_false()
	await _pick_link_map(ROOM)
	await _click_cell(Vector2i(3, 4))
	assert_str(studio.link.stage).is_equal("choose_facing")
	(studio.link.get_node("Facing") as PopupMenu).id_pressed.emit(3)
	await _frames(2)
	assert_bool(studio.link.active).is_false()
	assert_str(_map_id()).is_equal(TOWN)
	var target: Dictionary = studio.work.raw(1).to
	assert_dict(target).is_equal({"map": ROOM, "at": [3, 4], "facing": "right"})
	var linked_town := studio.work.doc().to_text()
	await _press(studio.people_panel(), "EntranceLink_1")
	await _pick_link_map("home")
	await _press(studio.link.panel(), "CancelLink")
	assert_str(_map_id()).is_equal(TOWN)
	assert_str(studio.work.doc().to_text()).is_equal(linked_town)
	assert_int(studio.selected_sids()[0]).is_equal(_pell_sid())

	# Play the two actual runtime transitions with the chosen facing and isolated save store.
	_top().play_draft_toggled.emit(true)
	await _tap(KEY_F1)
	assert_bool(studio.editing).is_false()
	assert_str((studio.parts().store as OverworldStore).root).is_equal(StudioMode.playtest_dir)
	screen.call("_on_arrived", PELL_DOOR)
	await _until_on(ROOM)
	assert_str(String(screen.state.map)).is_equal(ROOM)
	assert_vector(Vector2(OverworldState.cell(screen.state))).is_equal(Vector2(3, 4))
	assert_str(String(screen.state.facing)).is_equal("right")
	screen.call("_on_arrived", Vector2i(5, 7))
	await _until_on(TOWN)
	assert_str(String(screen.state.map)).is_equal(TOWN)
	assert_vector(Vector2(OverworldState.cell(screen.state))).is_equal(Vector2(PELL_FRONT))
	assert_str(String(screen.state.facing)).is_equal("down")

	# The talk edit settles on Back to person; each topbar Undo follows the visible document.
	await _tap(KEY_F2)
	await _press(_top(), "Tab_people")
	await _press(studio.people_panel(), "View_people")
	await _press(studio.people_panel(), "Locate_pell_" + TOWN)
	await _press(studio.inspector(), "OpenTalk")
	assert_str(studio.tab).is_equal("quests")
	var editor := studio.quest_panel.talk_editor
	var line := StudioQuestUi.find(editor, "line.0.text") as TextEdit
	assert_object(line).is_not_null()
	line.grab_focus()
	line.text = "P06 fixture greeting after editing"
	await _press(studio.quest_panel, "ReturnToPerson")
	assert_str(String(studio.selected_object().id)).is_equal("pell")
	assert_str(String(studio.quests.data("talk/pell").nodes.hello.lines[0].text)).is_equal("P06 fixture greeting after editing")
	await _press(studio.inspector(), "OpenTalk")
	_top().undo_pressed.emit()
	await _frames(2)
	assert_str(String(studio.quests.data("talk/pell").nodes.hello.lines[0].text)).is_equal("P06 original greeting")
	assert_str((studio.work.sessions()[TOWN] as StudioSession).doc().to_text()).is_equal(linked_town)
	_top().redo_pressed.emit()
	await _press(studio.quest_panel, "ReturnToPerson")
	_top().undo_pressed.emit()
	assert_bool(studio.work.raw(1).get("to", {}).get("at") != [3, 4]).is_true()
	assert_str(String(studio.quests.data("talk/pell").nodes.hello.lines[0].text)).is_equal("P06 fixture greeting after editing")
	_top().redo_pressed.emit()
	assert_dict(studio.work.raw(1).to).is_equal(target)
	await _tap(KEY_F1)
	screen.call("_open_talk", studio.catalog().talk.pell, {"name": "Pell"})
	var dialogue := screen.get("_talk") as DialogueBox
	assert_bool(dialogue.busy).is_true()
	assert_str(String((dialogue.get("_lines") as Array)[0].text)).is_equal("P06 fixture greeting after editing")
	dialogue.advance()
	dialogue.advance()
	await _frames(3)

	# The author reviews and confirms Publish, then the next app uses a completely empty draft directory.
	await _tap(KEY_F2)
	_top().publish_pressed.emit()
	await _frames(2)
	var tools := studio.publish_tools
	assert_bool(tools.dialog.visible).is_true()
	assert_int(int(tools.dialog.report.error_count)).override_failure_message(str(tools.dialog.report.problems)).is_equal(0)
	tools.dialog.warnings_checkbox.button_pressed = true
	assert_bool(tools.dialog.publish_button.disabled).is_false()
	tools.dialog.publish_button.pressed.emit()
	await _frames(2)
	assert_bool(tools.last_result.ok).override_failure_message(str(tools.last_result)).is_true()
	assert_array(tools.last_result.files).contains([_path(TOWN), _path(ROOM), studio.quests.path_of("talk/pell")])
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(_path(TOWN), StudioMode.drafts_dir))).is_false()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(_path(ROOM), StudioMode.drafts_dir))).is_false()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(studio.quests.path_of("talk/pell"), StudioMode.drafts_dir))).is_false()
	print("P06 fixture published: %s" % str(tools.last_result.files))
	StudioMode.drafts_dir = _root.path_join("empty-drafts-after-publish")
	await _restart()
	await _pick_map(TOWN)
	assert_array(_people()).has_size(1)
	assert_array(_people()[0].at).is_equal([7, 12])
	assert_dict(studio.work.raw(1).to).is_equal(target)
	await _pick_map(ROOM)
	assert_bool(studio.work.is_new_map(ROOM)).is_false()
	assert_int(studio.work.session().changes()).is_equal(0)
	assert_array(studio.work.doc().data.objects.filter(func(object: Dictionary) -> bool: return object.get("art") == "bed")).has_size(1)
	assert_str(String(studio.quests.data("talk/pell").nodes.hello.lines[0].text)).is_equal("P06 fixture greeting after editing")
	assert_str(StudioFiles.read_text(StudioSession.path_of(TOWN))).is_equal(_real_town_before)


func test_linked_building_door_and_resize_keep_return_history_exact_across_navigation_and_restart() -> void:
	# Existing home links both ways. Geometry commands must update that room's return in the same action.
	await _press(_top(), "Tab_objects")
	var house := _sid_of(func(object: Dictionary) -> bool: return object.get("art") == "home")
	var town_original := studio.work.doc().to_text()
	var source_original := StudioFiles.read_text(_path(TOWN))
	var home_original_source := StudioFiles.read_text(_path("home"))
	await _pick_map("home")
	var home_original := studio.work.doc().to_text()
	await _pick_map(TOWN)
	var history_count := studio.work.session().history.labels().size()
	assert_bool(studio.work.slide_door(house, Vector2i(1, 5))).is_true()
	var town_slid := studio.work.doc().to_text()
	await _pick_map("home")
	var home_slid := studio.work.doc().to_text()
	assert_that(OverworldMap.warp_at(studio.current_map(), Vector2i(5, 7)).at).is_equal(Vector2i(11, 45))
	await _pick_map(TOWN)
	var resized := studio.work.resize_object(house, Vector2i(7, 7))
	assert_bool(resized.ok).override_failure_message(str(resized)).is_true()
	assert_int(studio.work.session().history.labels().size()).is_equal(history_count + 2)
	assert_array(studio.work.raw(studio.work.index_of(house)).size).is_equal([7, 7])
	assert_array(studio.work.raw(studio.work.index_of(house)).door).is_equal([1, 6])
	assert_str(String(studio.work.raw(studio.work.index_of(house)).art)).is_equal("home")
	var town_resized := studio.work.doc().to_text()
	await _pick_map("home")
	var home_resized := studio.work.doc().to_text()
	assert_that(OverworldMap.warp_at(studio.current_map(), Vector2i(5, 7)).at).is_equal(Vector2i(11, 46))
	assert_bool(OverworldMap.blocked(studio.catalog().maps[TOWN], Vector2i(11, 46))).is_false()
	# Undo and redo from the source after visiting the room restore the exact paired snapshots.
	await _pick_map(TOWN)
	_top().undo_pressed.emit()
	assert_str(studio.work.doc().to_text()).is_equal(town_slid)
	await _pick_map("home")
	assert_str(studio.work.doc().to_text()).is_equal(home_slid)
	await _pick_map(TOWN)
	_top().undo_pressed.emit()
	assert_str(studio.work.doc().to_text()).is_equal(town_original)
	await _pick_map("home")
	assert_str(studio.work.doc().to_text()).is_equal(home_original)
	await _pick_map(TOWN)
	_top().redo_pressed.emit()
	_top().redo_pressed.emit()
	assert_str(studio.work.doc().to_text()).is_equal(town_resized)
	await _pick_map("home")
	assert_str(studio.work.doc().to_text()).is_equal(home_resized)
	# Persist both maps and check that restarting retains both sides of the geometry change.
	await _restart()
	await _pick_map(TOWN)
	assert_str(studio.work.doc().to_text()).is_equal(town_resized)
	await _pick_map("home")
	assert_str(studio.work.doc().to_text()).is_equal(home_resized)
	assert_str(StudioFiles.read_text(_path(TOWN))).is_equal(source_original)
	assert_str(StudioFiles.read_text(_path("home"))).is_equal(home_original_source)
