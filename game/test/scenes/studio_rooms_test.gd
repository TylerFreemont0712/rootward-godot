extends GdUnitTestSuite
## People, doors and rooms in the mounted Studio (Concept/v0.3/10, 7.9 and S6). The acceptance: a room made for Pell's
## cottage, furnished from the Furniture category, walked out of and into again on Play draft, published, and the new
## map file is there with both links. Then: undo leaves the room unlinked and Revert throws a new room away; Link door
## by clicking a cell of another map and choosing the facing; a door's handle slides along its row and the room's way
## out follows; someone placed from another map is asked about, moved, and put back by undo; the start flag; the picker.
## Content, drafts and saves are isolated copies.

const TEST_ROOT := "user://studio_test/rooms"
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
	# This story moves a static Pell between maps. Scheduled Pell has a separate acceptance case below.
	var schedules_path := StudioMode.content_dir.path_join("packs/core/overworld/schedules.jsonc")
	var schedules: Dictionary = Jsonc.parse(StudioFiles.read_text(schedules_path)).value
	schedules.erase("pell")
	assert_bool(StudioFiles.write_content(schedules_path, JsoncWriter.schedules_text("", schedules))).is_true()
	OS.set_environment("ROOTWARD_STUDIO", "1")
	Game.reset(_root.path_join("saves"))
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()
	StudioAssets.reload()
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Rooms fixture\n", _fixture()))).is_true()
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
	studio.set_overlay("doors", true)
	studio.set_editing(true)
	await _frames(2)
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


## A grass town 20 x 48: a barrel, Pell's cottage (no room yet), the player's house whose room (home.jsonc, from the
## content copy) leads back to (13, 45), and Pell outside.
func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {"id": TOWN, "name": "Rooms test", "legend": {".": "grass"}, "ground": rows, "start": [2, 2], "facing": "down", "objects": [
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


func _publisher() -> StudioPublish:
	var publisher := StudioPublish.new()
	publisher.content_root = StudioMode.content_dir
	publisher.drafts_dir = StudioMode.drafts_dir
	publisher.backups_dir = _root.path_join("backups")
	return publisher


func test_a_room_for_pells_cottage_is_furnished_walked_in_and_out_of_and_published() -> void:
	var pell := _pell_sid()
	assert_bool(studio.make_interior(pell)).is_true()
	await _frames(2)
	# The new room is shown, to furnish: 11 x 8, a room, its doormat's warp leading out below Pell's door.
	assert_str(_map_id()).is_equal(ROOM)
	var room := studio.current_map()
	assert_bool(bool(room.interior)).is_true()
	assert_vector(Vector2(OverworldMap.size_of(room))).is_equal(Vector2(11, 8))
	assert_str(String(room.name)).is_equal("Pell's cottage")
	var out := OverworldMap.warp_at(room, Vector2i(5, 7))
	assert_str(String(out.map)).is_equal(TOWN)
	assert_vector(Vector2(out.at)).is_equal(Vector2(PELL_FRONT))
	assert_str(String(out.facing)).is_equal("down")
	assert_bool(studio.work.is_new_map(ROOM)).is_true()
	assert_array(_top().map_labels).contains(["Pell's cottage  (room, new)"])
	var town: StudioSession = studio.work.sessions()[TOWN]
	var door: Dictionary = town.doc().object_of_sid(pell)
	assert_str(JSON.stringify(door.to)).is_equal(JSON.stringify({"map": ROOM, "at": [5, 6], "facing": "up"}))
	assert_str(town.history.labels().back()).is_equal("Make a room for Pell's cottage")
	# Furnished from the Furniture category.
	assert_str(String(StudioAssets.entry_of("bed").get("category", ""))).is_equal("furniture")
	assert_bool(bool(studio.work.place(StudioAssets.template("bed"), Vector2i(1, 3)).ok)).is_true()
	assert_bool(bool(studio.work.place(StudioAssets.template("bookshelf"), Vector2i(4, 2)).ok)).is_true()
	# Play draft: out through the doormat into the drafted town, and in again through Pell's door.
	studio.set_play_draft(true)
	studio.set_editing(false)
	await _frames(2)
	var store := studio.parts().store as OverworldStore
	assert_str(store.root).override_failure_message("a play-test never writes the real save").is_equal(StudioMode.playtest_dir)
	screen.call("_on_arrived", Vector2i(5, 7))
	await _until_on(TOWN)
	assert_str(String(screen.state.map)).is_equal(TOWN)
	assert_vector(Vector2(OverworldState.cell(screen.state))).is_equal(Vector2(PELL_FRONT))
	screen.call("_on_arrived", PELL_DOOR)
	await _until_on(ROOM)
	assert_str(String(screen.state.map)).override_failure_message("Pell's door leads into the room").is_equal(ROOM)
	assert_vector(Vector2(OverworldState.cell(screen.state))).is_equal(Vector2(5, 6))
	# Publish: the town's file has the door's link, and the room's new file has the way out and the furniture.
	studio.set_editing(true)
	await _frames(1)
	studio.set_play_draft(false)
	await _frames(1)
	assert_bool(studio.work.flush()).is_true()
	assert_bool(StudioFiles.exists(_path(ROOM))).override_failure_message("no file before Publish").is_false()
	var result := _publisher().publish(studio.work.sessions(), true)
	assert_bool(result.ok).override_failure_message("publish: %s" % str(result.get("error", "")) + " " + str(result.get("problems", []))).is_true()
	assert_array(result.files).contains([_path(TOWN), _path(ROOM)])
	var written := StudioFiles.read_text(_path(ROOM))
	assert_str(written).starts_with("// A map of Lanternroot's overworld")
	assert_str(written).contains('"interior": true')
	assert_str(written).contains('{"kind": "warp", "at": [5, 7], "to": {"map": "lanternroot", "at": [5, 25], "facing": "down"}}')
	assert_str(written).contains('"art": "doormat"')
	assert_str(written).contains('"art": "bed", "at": [1, 2]')
	assert_str(StudioFiles.read_text(_path(TOWN))).contains('"art": "cottage-pell", "at": [3, 20], "size": [5, 5], "door": [2, 4], "to": {"map": "cottage-pell", "at": [5, 6], "facing": "up"}')
	assert_bool(studio.work.is_new_map(ROOM)).override_failure_message("published, the room is a map like the others").is_false()
	var loaded := OverworldContent.load_world(StudioMode.content_dir)
	assert_bool((loaded.catalog.maps as Dictionary).has(ROOM)).is_true()
	for diagnostic: Dictionary in loaded.diagnostics:
		assert_str(String(diagnostic.get("file", ""))).override_failure_message(ContentLoader.describe(diagnostic)).not_contains(ROOM)


func test_undo_unlinks_the_room_and_revert_throws_a_new_room_away() -> void:
	var pell := _pell_sid()
	assert_bool(studio.make_interior(pell)).is_true()
	var linked_impact := studio.work.revert_impact(studio.work.session())
	assert_bool(bool(linked_impact.get("can_revert", false))).override_failure_message(
		"a new room cannot be reverted while its building door still points into it"
	).is_false()
	assert_str(String(linked_impact.get("message", ""))).contains("cottage-pell")
	assert_bool(studio.go_to_map(TOWN)).is_true()
	await _frames(1)
	assert_str(_map_id()).is_equal(TOWN)
	assert_bool(studio.work.undo()).is_true()
	assert_bool(_raw(pell).has("to")).override_failure_message("undo takes the link away").is_false()
	assert_bool(studio.catalog().maps.has(ROOM)).override_failure_message("the room is kept, never lost").is_true()
	assert_array(_top().map_labels).contains(["Pell's cottage  (room, new, unlinked room draft)"])
	assert_bool(studio.work.revert_impact(studio.work.sessions()[ROOM]).can_revert).override_failure_message(
		"after undo, the room remains a discardable but recoverable draft"
	).is_true()
	assert_bool(studio.work.flush()).is_true()
	var report := _publisher().review(studio.work.sessions())
	var unreached: Array = (report.problems as Array).filter(func(problem: Dictionary) -> bool: return String(problem.message).contains("no door or warp leads into"))
	assert_int(unreached.size()).override_failure_message("Publish warns about the unlinked room").is_equal(1)
	assert_bool(studio.work.redo()).is_true()
	assert_str(String((_raw(pell).to as Dictionary).map)).is_equal(ROOM)
	# An active door reference must be removed before Revert can discard the new room.
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_bool(studio.work.unlink(pell)).is_true()
	# Revert now returns to the retained room's outside door using its own way-out warp.
	assert_bool(studio.go_to_map(ROOM)).is_true()
	await _frames(1)
	# An edit not saved yet (the draft is written two seconds later) must not bring the room back after Revert.
	assert_bool(bool(studio.work.place(StudioAssets.template("bed"), Vector2i(2, 3)).ok)).is_true()
	assert_bool(studio.work.session().unsaved).is_true()
	studio.publish_tools.request_revert()
	var reverted := studio.publish_tools.confirm_revert()
	await _frames(1)
	assert_bool(bool(reverted.get("removed", false))).override_failure_message(str(reverted)).is_true()
	assert_str(_map_id()).is_equal(TOWN)
	assert_bool(studio.catalog().maps.has(ROOM)).is_false()
	assert_bool(studio.work.sessions().has(ROOM)).is_false()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(_path(ROOM), StudioMode.drafts_dir))).is_false()
	assert_bool(studio.work.flush()).is_true()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(_path(ROOM), StudioMode.drafts_dir))).override_failure_message("no later save writes it back").is_false()
	assert_array(_top().map_ids).not_contains([ROOM])


func test_unlinked_room_draft_can_be_reconnected_from_people_and_doors() -> void:
	var pell := _pell_sid()
	assert_bool(studio.make_interior(pell)).is_true()
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_bool(studio.work.undo()).is_true()
	var panel := studio.people_panel()
	studio.set_tab("people")
	panel.choose_view("entrances")
	var card := panel.find_child("RoomDraft_" + ROOM, true, false) as Control
	assert_object(card).override_failure_message("the retained room draft is visible in Entrances").is_not_null()
	var reconnect := card.find_child("RoomDraftReconnect_" + ROOM, true, false) as Button
	assert_object(reconnect).override_failure_message("the unique matching building enables Reconnect").is_not_null()
	assert_bool(reconnect.disabled).is_false()
	reconnect.pressed.emit()
	await _frames(1)
	assert_str(_map_id()).is_equal(ROOM)
	assert_str(studio.tab).is_equal("objects")
	var town: StudioSession = studio.work.sessions()[TOWN]
	assert_str(String(town.doc().object_of_sid(pell).to.map)).is_equal(ROOM)
	assert_array(_top().map_labels).not_contains(["Pell's cottage  (room, new, unlinked room draft)"])
	assert_bool(bool(studio.work.place(StudioAssets.template("bed"), Vector2i(2, 3)).ok)).override_failure_message(
		"the reconnect action leaves Objects ready to furnish the room"
	).is_true()
	assert_bool(studio.go_to_map(TOWN)).is_true()
	await _frames(1)
	panel.choose_view("entrances")
	var entrance := panel.find_child("Entrance_1", true, false) as Control
	assert_object(entrance).override_failure_message("Pell's linked cottage appears in Entrances").is_not_null()
	var furnish := entrance.find_child("EntranceGo_1", true, false) as Button
	assert_object(furnish).override_failure_message("the linked cottage has a room action").is_not_null()
	assert_str(furnish.text).is_equal("Furnish room")
	furnish.pressed.emit()
	await _frames(1)
	assert_str(_map_id()).is_equal(ROOM)
	assert_str(studio.tab).is_equal("objects")


func test_reverting_an_unlinked_room_returns_to_its_saved_outside_door() -> void:
	assert_bool(studio.make_interior(_pell_sid())).is_true()
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.go_to_map(ROOM)).is_true()
	assert_bool(bool(studio.work.place(StudioAssets.template("bed"), Vector2i(2, 3)).ok)).is_true()
	studio.publish_tools.request_revert()
	var result := studio.publish_tools.confirm_revert()
	assert_bool(bool(result.get("removed", false))).is_true()
	assert_str(_map_id()).is_equal(TOWN)
	assert_bool(studio.work.sessions().has(ROOM)).override_failure_message("the reverted room is forgotten").is_false()


func test_link_door_clicks_a_cell_in_another_map_and_asks_the_facing() -> void:
	var pell := _pell_sid()
	studio.link_door(pell)
	assert_bool(studio.link.active).is_true()
	assert_bool(studio.go_to_map("home")).is_true()
	await _frames(1)
	assert_bool(studio.link.active).override_failure_message("the link waits while another map is shown").is_true()
	assert_bool(bool(studio.link.check(Vector2i(0, 0)).ok)).override_failure_message("a wall").is_false()
	assert_bool(bool(studio.link.check(Vector2i(5, 7)).ok)).override_failure_message("the doormat's warp").is_false()
	studio.link.click(Vector2i(2, 4), Vector2(400, 300))
	assert_bool(studio.link.menu_open()).is_true()
	studio.link.face("up")
	await _frames(1)
	assert_bool(studio.link.active).is_false()
	assert_str(_map_id()).override_failure_message("back to the door's map").is_equal(TOWN)
	assert_str(JSON.stringify(_raw(pell).to)).is_equal(JSON.stringify({"map": "home", "at": [2, 4], "facing": "up"}))
	assert_str(studio.work.session().history.labels().back()).is_equal("Link cottage-pell to home")
	assert_array(studio.selected_sids()).is_equal([pell])
	# Esc lets go of a link: back to the door, nothing changed.
	studio.link_door(pell)
	studio.go_to_map("home")
	await _frames(1)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_tree().root.push_input(esc)
	await _frames(1)
	assert_bool(studio.link.active).is_false()
	assert_str(_map_id()).is_equal(TOWN)
	assert_vector(Vector2(OverworldMap.cell_of((_raw(pell).to as Dictionary).at))).is_equal(Vector2(2, 4))


func test_the_door_handle_slides_along_the_bottom_row_and_the_rooms_way_out_follows() -> void:
	var house := _sid_of(func(object: Dictionary) -> bool: return String(object.get("art", "")) == "home")
	studio.select_sids([house])
	await _frames(1)
	var handle := StudioOverlay.door_rect(Vector2i(13, 44)).get_center()
	assert_str(String(studio.handle_at(handle).get("kind", ""))).is_equal("door")
	await _mouse_at(handle, null)
	await _mouse_at(handle, true)
	await _mouse_at(_centre(Vector2i(11, 44)), null)
	await _mouse_at(_centre(Vector2i(11, 44)), false)
	assert_array(_raw(house).door).override_failure_message("the door is two cells left on the bottom row").is_equal([1, 5])
	var room: StudioSession = studio.work.sessions()["home"]
	assert_str(_json(room.doc().data)).override_failure_message("the room's way out follows the door").contains('"at":[11,45]')
	assert_str(studio.work.session().history.labels().back()).is_equal("Move the door of home")
	assert_bool(studio.work.undo()).is_true()
	assert_array(_raw(house).door).is_equal([3, 5])
	assert_str(_json(room.doc().data)).contains('"at":[13,45]')
	assert_bool(studio.work.redo()).is_true()
	assert_str(_json(room.doc().data)).contains('"at":[11,45]')


func test_someone_from_another_map_is_asked_about_moved_here_and_put_back_by_undo() -> void:
	assert_bool(studio.go_to_map("home")).is_true()
	await _frames(1)
	var template := {"kind": "person", "id": "pell", "facing": "down"}
	var placed := studio.work.place(template, Vector2i(3, 4))
	assert_bool(bool(placed.get("needs_confirm", false))).is_true()
	assert_str(String(placed.map)).is_equal(TOWN)
	studio.after_place(template, placed)
	var ask := studio.get_node("Chrome/MovePerson") as ConfirmationDialog
	assert_bool(ask.visible).is_true()
	assert_str(ask.dialog_text).contains("Pell")
	ask.confirmed.emit()
	await _frames(1)
	var town: StudioSession = studio.work.sessions()[TOWN]
	assert_str(_json(studio.work.doc().data)).contains('"id":"pell","at":[3,4]')
	assert_str(_json(town.doc().data)).override_failure_message("Pell left the town").not_contains('"id":"pell"')
	assert_int((studio.catalog().maps[TOWN].people as Array).size()).is_equal(0)
	assert_bool(studio.work.undo()).is_true()
	assert_str(_json(studio.work.doc().data)).not_contains('"id":"pell"')
	assert_str(_json(town.doc().data)).override_failure_message("undo puts Pell back in the town").contains('"id":"pell","at":[9,10]')
	assert_bool(studio.work.redo()).is_true()
	assert_str(_json(studio.work.doc().data)).contains('"id":"pell","at":[3,4]')
	assert_str(_json(town.doc().data)).override_failure_message("redo takes Pell out of the town again").not_contains('"id":"pell"')
	assert_bool(studio.work.undo()).is_true()
	# On their own map, a person just moves.
	assert_bool(studio.go_to_map(TOWN)).is_true()
	await _frames(1)
	var moved := studio.work.place(template, Vector2i(8, 12))
	assert_bool(bool(moved.ok)).is_true()
	assert_str(_json(studio.work.doc().data)).contains('"id":"pell","at":[8,12]')
	assert_str(studio.work.session().history.labels().back()).is_equal("Move person pell")


func test_the_start_flag_moves_and_will_not_go_on_a_wall() -> void:
	assert_bool(studio.go_to_map("home")).is_true()
	await _frames(1)
	var flag := StudioOverlay.flag_rect(Vector2i(2, 3)).get_center()
	assert_str(String(studio.handle_at(flag).get("kind", ""))).is_equal("start")
	assert_bool(bool(studio.work.set_start(Vector2i(0, 0)).ok)).override_failure_message("a wall").is_false()
	await _mouse_at(flag, null)
	await _mouse_at(flag, true)
	await _mouse_at(_centre(Vector2i(8, 4)), null)
	await _mouse_at(_centre(Vector2i(8, 4)), false)
	assert_array(studio.work.doc().data.start).is_equal([8, 4])
	assert_bool(studio.work.set_map_field("facing", "left")).is_true()
	assert_str(String(studio.current_map().facing)).is_equal("left")
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_array(studio.work.doc().data.start).is_equal([2, 3])


func test_a_new_warp_goes_straight_on_to_linking() -> void:
	studio.arrange.start_placing({"kind": "warp"}, "marker-warp")
	await _mouse_at(_centre(Vector2i(4, 30)), null)
	await _mouse_at(_centre(Vector2i(4, 30)), true)
	await _mouse_at(_centre(Vector2i(4, 30)), false)
	assert_bool(studio.arrange.placing.is_empty()).override_failure_message("a warp is placed once").is_true()
	assert_bool(studio.link.active).is_true()
	var warp := studio.selected_sids()[0]
	assert_str(String(_raw(warp).kind)).is_equal("warp")
	assert_str(String((_raw(warp).to as Dictionary).map)).override_failure_message("until linked it leads to the start").is_equal(TOWN)
	studio.link.cancel()


func test_the_picker_lists_the_rooms_and_goes_there_and_leaving_a_new_room_plays_its_draft() -> void:
	assert_str(_top().map_labels[0]).override_failure_message("the town first").is_equal("Rooms test")
	assert_array(_top().map_labels).contains(["Your house  (room)"])
	_top().map_chosen.emit("home")
	await _frames(1)
	assert_str(_map_id()).is_equal("home")
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_bool(studio.make_interior(_pell_sid())).is_true()
	await _frames(1)
	assert_bool(studio.play_draft).is_false()
	studio.set_editing(false)
	await _frames(1)
	assert_bool(studio.play_draft).override_failure_message("a room that is only a draft is played as the draft").is_true()
	assert_str((studio.parts().store as OverworldStore).root).is_equal(StudioMode.playtest_dir)


func test_a_save_on_a_map_that_is_gone_goes_home_and_keeps_what_was_done() -> void:
	screen.queue_free()
	await _frames(2)
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Rooms tester"
	state.flags = BEATS.duplicate(true)
	state.flags["met-innkeeper"] = true
	state = OverworldState.moved(state, "a-room-reverted-away", Vector2i(5, 6), "up")
	OverworldStore.for_profile().save_state(state)
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	assert_str(String(screen.state.map)).is_equal(OverworldScreen.START_MAP)
	assert_bool(bool(screen.state.flags.get("met-innkeeper", false))).override_failure_message("progress is kept").is_true()
	assert_str(String(screen.state.name)).is_equal("Rooms tester")


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


func test_same_map_person_move_preserves_sid_and_groups_facing_with_position() -> void:
	var person := _sid_of(func(object: Dictionary) -> bool: return object.get("id") == "pell")
	var before := _raw(person)
	var count := studio.work.session().history.labels().size()
	var result := studio.work.place_person("pell", Vector2i(7, 12), "left")
	assert_bool(result.ok).override_failure_message(str(result)).is_true()
	assert_int(result.sid).is_equal(person)
	assert_array(_raw(person).at).is_equal([7, 12])
	assert_str(_raw(person).facing).is_equal("left")
	assert_int(studio.work.session().history.labels().size()).is_equal(count + 1)
	assert_bool(studio.work.undo()).is_true()
	assert_dict(_raw(person)).is_equal(before)
	assert_bool(studio.work.redo()).is_true()
	assert_int(studio.work.doc().sids.count(person)).is_equal(1)
	assert_bool(studio.work.place_person("unknown-person", Vector2i(2, 3)).ok).is_false()


func test_cross_map_move_cancel_and_stale_confirmation_change_neither_map() -> void:
	assert_bool(studio.go_to_map("home")).is_true()
	var before := studio.work.doc().to_text()
	var pending := studio.work.place_person("pell", Vector2i(3, 4))
	assert_bool(pending.get("needs_confirm", false)).is_true()
	studio.after_place({"kind": "person", "id": "pell", "facing": "down"}, pending)
	(studio.get_node("Chrome/MovePerson") as ConfirmationDialog).canceled.emit()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_bool(studio.go_to_map(TOWN)).is_true()
	var person := _sid_of(func(object: Dictionary) -> bool: return object.get("id") == "pell")
	assert_bool(studio.work.command({"type": "move", "sids": [person], "by": [1, 0]}).ok).is_true()
	var town_before := studio.work.doc().to_text()
	assert_bool(studio.go_to_map("home")).is_true()
	var stale := studio.work.place_person("pell", Vector2i(3, 4), "down", false, true, pending.source, TOWN)
	assert_bool(stale.ok).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_str((studio.work.sessions()[TOWN] as StudioSession).doc().to_text()).is_equal(town_before)


func test_cross_map_move_rolls_back_every_injected_durability_failure() -> void:
	assert_bool(studio.go_to_map("home")).is_true()
	var pending := studio.work.place_person("pell", Vector2i(3, 4))
	assert_bool(pending.get("needs_confirm", false)).is_true()
	assert_bool(studio.work.flush()).is_true()
	var source: StudioSession = studio.work.sessions()[TOWN]
	var dest := studio.work.session()
	var before_source := source.doc().to_text()
	var before_dest := dest.doc().to_text()
	for point: String in ["after_manifest_prepared", "after_first_storage_write", "before_commit_manifest", "after_history_commit"]:
		StudioWorldTransaction.failure_at = point
		var result := studio.work.place_person("pell", Vector2i(3, 4), "down", false, true, pending.source, TOWN)
		StudioWorldTransaction.failure_at = ""
		assert_bool(result.ok).override_failure_message(point).is_false()
		assert_str(source.doc().to_text()).is_equal(before_source)
		assert_str(dest.doc().to_text()).is_equal(before_dest)
		assert_bool(source.history.can_undo()).is_false()
		assert_bool(dest.history.can_undo()).is_false()
		assert_bool(FileAccess.file_exists(StudioFiles.world_transaction_manifest_path(StudioMode.drafts_dir))).is_false()
		var reopened_source := StudioSession.open(TOWN, StudioMode.drafts_dir, StudioMode.content_dir)
		var reopened_dest := StudioSession.open("home", StudioMode.drafts_dir, StudioMode.content_dir)
		assert_str(reopened_source.doc().to_text()).is_equal(before_source)
		assert_str(reopened_dest.doc().to_text()).is_equal(before_dest)
	# A bad candidate build is rejected before either participant is applied.
	assert_bool(studio.work.command({"type": "set_map", "key": "ground", "value": ["?"]}).ok).is_true()
	var invalid_before := studio.work.doc().to_text()
	var refused := studio.work.place_person("pell", Vector2i(3, 4), "down", false, true, pending.source, TOWN)
	assert_bool(refused.ok).is_false()
	assert_str(source.doc().to_text()).is_equal(before_source)
	assert_str(studio.work.doc().to_text()).is_equal(invalid_before)


func _restart_studio() -> void:
	screen.queue_free()
	await _frames(6)
	Background.finish_all()
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
	await _frames(2)


func test_cross_map_transaction_restores_after_restart_and_invalidates_shared_redo() -> void:
	assert_bool(studio.go_to_map("home")).is_true()
	assert_bool(studio.work.place_person("pell", Vector2i(3, 4), "left", false, true).ok).is_true()
	await _restart_studio()
	assert_bool(studio.go_to_map("home")).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_bool(studio.work.redo()).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(3, 4)).ok).is_true()
	assert_bool(studio.go_to_map("home")).is_true()
	assert_bool(studio.work.session().history.can_redo()).is_false()
	assert_bool(studio.work.redo()).is_false()


func test_scheduled_person_moves_work_anchor_with_history_and_retains_home_and_inn() -> void:
	var path := StudioMode.content_dir.path_join("packs/core/overworld/schedules.jsonc")
	var schedule := {"home": [8, 10], "work": [9, 10], "inn": [10, 10]}
	var schedules := {"pell": schedule.duplicate(true)}
	assert_bool(StudioFiles.write_content(path, JsoncWriter.schedules_text("", schedules))).is_true()
	studio.catalog()["schedules"] = schedules
	var person := _sid_of(func(object: Dictionary) -> bool: return object.get("id") == "pell")
	var authored := studio.work.doc().to_text()
	assert_bool(studio.work.delete([person], true).ok).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(authored)
	var result := studio.work.place_person("pell", Vector2i(7, 12), "left")
	assert_bool(result.ok).override_failure_message(str(result)).is_true()
	assert_int(result.sid).is_equal(person)
	assert_array(studio.catalog().schedules.pell.work).is_equal([7, 12])
	assert_array(studio.catalog().schedules.pell.home).is_equal(schedule.home)
	assert_array(studio.catalog().schedules.pell.inn).is_equal(schedule.inn)
	assert_bool(studio.work.undo()).is_true()
	assert_dict(studio.catalog().schedules.pell).is_equal(schedule)
	assert_bool(studio.work.redo()).is_true()
	await _restart_studio()
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_dict(studio.catalog().schedules.pell).is_equal(schedule)
	assert_bool(studio.go_to_map("home")).is_true()
	var before := studio.work.doc().to_text()
	assert_bool(studio.work.place_person("pell", Vector2i(3, 4), "up", true, true).ok).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_start_position_and_facing_are_one_action_and_leave_character_save_unchanged() -> void:
	var before := OverworldStore.for_profile().load_state()
	assert_bool(studio.work.set_start(Vector2i(4, 4), false, "left").ok).is_true()
	assert_array(studio.work.doc().data.start).is_equal([4, 4])
	assert_str(studio.work.doc().data.facing).is_equal("left")
	assert_bool(studio.work.undo()).is_true()
	assert_array(studio.work.doc().data.start).is_equal([2, 2])
	assert_str(studio.work.doc().data.facing).is_equal("down")
	assert_dict(OverworldStore.for_profile().load_state()).is_equal(before)
	assert_bool(studio.work.set_start(PELL_DOOR, true).ok).is_false()


func test_link_workspace_stages_cancel_and_input_isolation() -> void:
	var source := _pell_sid()
	var original := studio.work.doc().to_text()
	studio.set_tab("people")
	studio.link_door(source)
	assert_str(studio.link.stage).is_equal("choose_target_map")
	assert_bool(studio.link.panel().visible).is_true()
	assert_bool(studio.people_panel().visible).is_false()
	assert_bool(studio.inspector().visible).is_false()
	assert_vector(Vector2(studio.overlay().link_source)).is_equal(Vector2(PELL_DOOR))
	assert_bool(studio.link.choose_map("home")).is_true()
	assert_str(studio.link.stage).is_equal("choose_target_cell")
	studio.link.click(Vector2i(0, 0), Vector2(500, 300))
	assert_str(studio.link.stage).is_equal("choose_target_cell")
	assert_bool(studio.link.active).is_true()
	assert_bool(studio.link.choose_map("missing-map")).is_false()
	studio.link.click(Vector2i(3, 4), Vector2(500, 300))
	assert_str(studio.link.stage).is_equal("choose_facing")
	assert_vector(Vector2(studio.overlay().link_arrival)).is_equal(Vector2(3, 4))
	assert_bool(studio.link.choose_map(TOWN)).is_true()
	await _frames(2)
	assert_str(studio.link.stage).is_equal("choose_target_cell")
	assert_bool(studio.link.menu_open()).is_false()
	for code: Key in [KEY_Q, KEY_DELETE, KEY_R, KEY_E]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		assert_bool((studio.get("_keys") as StudioKeys).handle(key)).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(original)
	assert_bool(studio.arrange.area_select).is_false()
	assert_bool(studio.link.choose_map("home")).is_true()
	(studio.link.panel().find_child("CancelLink", true, false) as Button).pressed.emit()
	assert_bool(studio.link.active).is_false()
	assert_str(_map_id()).is_equal(TOWN)
	assert_array(studio.selected_sids()).is_equal([source])
	assert_bool(studio.people_panel().visible).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(original)


func test_link_revalidates_target_and_source_and_navigation_marks_arrival_read_only() -> void:
	var source := _pell_sid()
	studio.link_door(source)
	studio.link.choose_map("home")
	studio.link.click(Vector2i(3, 4), Vector2(500, 300))
	# A destination edit between preview and choosing facing must reject the link.
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(3, 4)).ok).is_true()
	studio.link.face("right")
	assert_bool(studio.link.active).is_true()
	assert_str(studio.link.stage).is_equal("choose_target_cell")
	studio.link.click(Vector2i(2, 4), Vector2(500, 300))
	var town: StudioSession = studio.work.sessions()[TOWN]
	assert_bool(town.do({"type": "remove", "sid": source}).ok).is_true()
	studio.link.face("up")
	assert_bool(studio.link.active).is_false()
	assert_str(_map_id()).is_equal(TOWN)
	assert_bool(studio.work.index_of(source) < 0).is_true()
	var original := studio.work.doc().to_text()
	assert_bool(studio.go_to_arrival("home", Vector2i(5, 7), "up")).is_false()
	assert_str(_map_id()).is_equal(TOWN)
	assert_bool(studio.go_to_arrival("home", Vector2i(2, 4), "right")).is_true()
	assert_vector(Vector2(studio.overlay().link_arrival)).is_equal(Vector2(2, 4))
	assert_str(studio.overlay().link_facing).is_equal("right")
	assert_str(town.doc().to_text()).is_equal(original)
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_vector(Vector2(studio.overlay().link_arrival)).is_equal(Vector2(-1, -1))


func test_changed_link_keeps_facing_unlinks_without_removing_room_and_plays_after_publish() -> void:
	var house := _sid_of(func(object: Dictionary) -> bool: return object.get("art") == "home")
	studio.link_door(house)
	assert_str(studio.link.current_facing).is_equal("up")
	studio.link.choose_map("home")
	studio.link.click(Vector2i(2, 4), Vector2(500, 300))
	assert_str(studio.overlay().link_facing).is_equal("up")
	studio.link.face("right")
	assert_bool(studio.link.active).is_false()
	assert_bool(studio.work.flush()).is_true()
	var published := _publisher().publish(studio.work.sessions(), true)
	assert_bool(published.ok).override_failure_message(str(published)).is_true()
	var loaded := OverworldContent.load_world(StudioMode.content_dir)
	var target := OverworldMap.warp_at(loaded.catalog.maps[TOWN], Vector2i(13, 44))
	assert_str(target.facing).is_equal("right")
	assert_vector(Vector2(target.at)).is_equal(Vector2(2, 4))
	studio.set_play_draft(true)
	studio.set_editing(false)
	screen.call("_on_arrived", Vector2i(13, 44))
	await _until_on("home")
	assert_str(screen.state.map).is_equal("home")
	assert_vector(Vector2(OverworldState.cell(screen.state))).is_equal(Vector2(2, 4))
	assert_str(screen.state.facing).is_equal("right")
	studio.set_editing(true)
	studio.go_to_map(TOWN)
	var room_before := StudioFiles.read_text(_path("home"))
	assert_bool(studio.work.unlink(house)).is_true()
	assert_str(StudioFiles.read_text(_path("home"))).is_equal(room_before)
	assert_bool(studio.catalog().maps.has("home")).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_str(_raw(house).to.facing).is_equal("right")


func test_coordinated_move_revert_protects_dependencies_and_publish_cleans_the_group() -> void:
	assert_bool(studio.go_to_map("home")).is_true()
	assert_bool(studio.work.place_person("pell", Vector2i(3, 4), "left", false, true).ok).is_true()
	assert_bool(studio.work.revert_impact(studio.work.session()).can_revert).is_true()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), Vector2i(2, 4)).ok).is_true()
	assert_bool(studio.work.revert_impact(studio.work.session()).can_revert).is_false()
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.work.revert_coordinated_action(studio.work.session()).ok).is_true()
	var town: StudioSession = studio.work.sessions()[TOWN]
	assert_str(_json(town.doc().data)).contains('"id":"pell"')
	assert_str(_json(studio.work.doc().data)).not_contains('"id":"pell"')
	assert_bool(studio.work.place_person("pell", Vector2i(3, 4), "left", false, true).ok).is_true()
	studio.publish_tools.publisher.backups_dir = _root.path_join("backups")
	var published := studio.publish_tools.confirm_publish(true, [])
	assert_bool(published.ok).override_failure_message(str(published)).is_true()
	assert_array(published.files).contains([_path(TOWN), _path("home")])
	assert_bool(FileAccess.file_exists(StudioFiles.world_groups_path(StudioMode.drafts_dir))).is_false()
	var loaded := OverworldContent.load_world(StudioMode.content_dir)
	var locations := StudioDoors.standing(loaded.catalog.maps, "pell")
	assert_int(locations.size()).is_equal(1)
	assert_str(locations[0].map).is_equal("home")


func test_cancelling_provisional_transition_cannot_resurrect_it_with_redo() -> void:
	var before := studio.work.doc().to_text()
	var count := studio.work.session().history.labels().size()
	var template := {"kind": "warp"}
	var placed := studio.work.place(template, Vector2i(3, 4))
	assert_bool(placed.ok).is_true()
	studio.after_place(template, placed)
	assert_bool(studio.link.provisional).is_true()
	studio.link.choose_map("home")
	studio.link.cancel()
	assert_str(_map_id()).is_equal(TOWN)
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_int(studio.work.session().history.labels().size()).is_equal(count)
	assert_bool(studio.work.redo()).is_false()
	assert_bool(studio.work.flush()).is_true()
	var reopened := StudioSession.open(TOWN, StudioMode.drafts_dir, StudioMode.content_dir)
	assert_str(reopened.doc().to_text()).is_equal(before)


func test_escape_cancels_link_from_map_cell_and_facing_stages() -> void:
	var source := _pell_sid()
	var before := studio.work.doc().to_text()
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	for step: int in 3:
		studio.link_door(source)
		if step > 0:
			studio.link.choose_map("home")
		if step == 2:
			studio.link.click(Vector2i(3, 4), Vector2(500, 300))
			var menu := studio.link.get_node("Facing") as PopupMenu
			menu.window_input.emit(key)
		else:
			(studio.get("_keys") as StudioKeys).handle(key)
		await _frames(2)
		assert_bool(studio.link.active).is_false()
		assert_str(_map_id()).is_equal(TOWN)
		assert_array(studio.selected_sids()).is_equal([source])
		assert_str(studio.work.doc().to_text()).is_equal(before)


func test_scheduled_work_anchor_publish_writes_both_documents_and_cleans_hidden_history() -> void:
	var path := StudioMode.content_dir.path_join("packs/core/overworld/schedules.jsonc")
	var schedules := {"pell": {"home": [8, 10], "work": [9, 10], "inn": [10, 10]}}
	assert_bool(StudioFiles.write_content(path, JsoncWriter.schedules_text("", schedules))).is_true()
	studio.catalog()["schedules"] = schedules
	assert_bool(studio.work.place_person("pell", Vector2i(7, 12), "left").ok).is_true()
	studio.publish_tools.publisher.backups_dir = _root.path_join("backups")
	var published := studio.publish_tools.confirm_publish(true, [])
	assert_bool(published.ok).override_failure_message(str(published)).is_true()
	assert_array(published.files).contains([_path(TOWN), path])
	assert_bool(FileAccess.file_exists(StudioFiles.world_groups_path(StudioMode.drafts_dir))).is_false()
	var loaded := OverworldContent.load_world(StudioMode.content_dir)
	assert_array(loaded.catalog.schedules.pell.work).is_equal([7, 12])
	assert_array(loaded.catalog.schedules.pell.home).is_equal([8, 10])
	assert_array(loaded.catalog.schedules.pell.inn).is_equal([10, 10])
	assert_bool(studio.work.undo()).is_false()


func test_japanese_link_source_formats_the_asset_name_in_both_reading_editions() -> void:
	var source := _pell_sid()
	for reading: String in ["hiragana", "kanji"]:
		Text.setup("ja", reading)
		studio.link_door(source)
		var label := studio.link.get("_source_label") as Label
		assert_str(label.text).contains(StudioAssets.name_of("cottage-pell"))
		assert_str(label.text).not_contains("{1}")
		assert_str(label.text).not_contains("%s")
		assert_str(label.text).contains("入口")
		studio.link.cancel()
	Text.setup("en")
