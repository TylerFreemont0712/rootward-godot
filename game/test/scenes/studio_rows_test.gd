extends GdUnitTestSuite
## Shift-drag in place mode lays a row as one undo step. The mouse reaches the real world Control; content, drafts and
## saves are isolated copies.

const TEST_ROOT := "user://studio_test/rows"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}

var screen: OverworldScreen
var studio: StudioMode
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
	assert_bool(StudioFiles.write_content(_path(), JsoncWriter.map_text("// Rows fixture\n", _fixture()))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var map: Dictionary = OverworldScreen.catalog_of().maps[TOWN]
	var state := OverworldState.fresh(TOWN, map.start, "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Context tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
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
	StudioWork.clipboard = _old_clipboard
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path() -> String:
	return StudioSession.path_of(TOWN, StudioMode.content_dir)


func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in 14:
		rows.append("....................")
	return {"id": TOWN, "name": "Rows test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "prop", "art": "barrel", "at": [6, 6]},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


## A cell's middle in the root viewport's canvas coordinates.
func _cell_point(cell: Vector2) -> Vector2:
	var view := studio.pixel_view()
	return view.get_global_transform() * view.to_screen((cell + Vector2(0.5, 0.5)) * OverworldScale.TILE)


func _motion(cell: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _cell_point(cell)
	event.global_position = event.position
	event.relative = Vector2(8, 0)
	get_tree().root.push_input(event, true)
	await get_tree().process_frame


func _button(cell: Vector2, pressed: bool, shift: bool, alt := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = _cell_point(cell)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
	event.alt_pressed = alt
	get_tree().root.push_input(event, true)
	await get_tree().process_frame


## Shift down at `from`, the cursor to `to`, the button up (with Alt when `alt`).
func _drag_row(from: Vector2, to: Vector2, alt := false) -> void:
	await _frames(2)
	await _motion(from)
	await _button(from, true, true)
	await _motion(to)
	await _button(to, false, true, alt)
	await _frames(2)


func _count(art: String) -> int:
	var count := 0
	for index: int in (studio.work.doc().data.objects as Array).size():
		if _matches_art(studio.work.raw(index), art):
			count += 1
	return count


func _xs_of(art: String) -> Array[int]:
	var out: Array[int] = []
	for index: int in (studio.work.doc().data.objects as Array).size():
		var object := studio.work.raw(index)
		if _matches_art(object, art):
			out.append(int((object.at as Array)[0]))
	return out


## Connected timber strokes include posts and directional ends, while the selected catalog family stays "fence".
func _matches_art(object: Dictionary, art: String) -> bool:
	if art == "fence":
		return StudioBoundary.is_fence(object, StudioAssets.entries()) \
			and StudioBoundary.group(object, StudioAssets.entries()) == "fence"
	return String(object.get("art", "")) == art


func _history_size() -> int:
	return studio.work.session().history.labels().size()


func test_ten_fences_in_one_shift_drag_are_one_undo_step() -> void:
	var before := studio.work.doc().to_text()
	var file_before := StudioFiles.read_text(_path())
	var steps := _history_size()
	studio.start_place("fence")
	await _frames(2)
	await _motion(Vector2(2, 9))
	await _button(Vector2(2, 9), true, true)
	await _motion(Vector2(11, 9))
	assert_int(studio.overlay().ghosts.size()).is_equal(10)
	assert_int(_count("fence")).is_equal(0)
	await _button(Vector2(11, 9), false, true)
	await _frames(2)
	assert_int(_count("fence")).is_equal(10)
	assert_array(_xs_of("fence")).is_equal([2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
	for index: int in (studio.work.doc().data.objects as Array).size():
		var object := studio.work.raw(index)
		if _matches_art(object, "fence"):
			assert_int(int((object.at as Array)[1])).is_equal(9)
	assert_int(_history_size()).is_equal(steps + 1)
	assert_bool(studio.arrange.placing.is_empty()).is_false()
	assert_str(studio.arrange.mode).is_equal("")
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_bool(studio.work.redo()).is_true()
	assert_int(_count("fence")).is_equal(10)
	assert_str(StudioFiles.read_text(_path())).is_equal(file_before)


func test_a_row_through_an_obstacle_skips_the_piece_that_does_not_fit() -> void:
	studio.start_place("fence")
	await _drag_row(Vector2(2, 6), Vector2(11, 6))
	assert_int(_count("fence")).is_equal(9)
	assert_bool(_xs_of("fence").has(6)).is_false()
	assert_str(studio.status_bar().message_text).contains("9 of 10")
	assert_bool(studio.work.undo()).is_true()
	assert_int(_count("fence")).is_equal(0)
	await _drag_row(Vector2(2, 6), Vector2(11, 6), true)
	assert_int(_count("fence")).is_equal(10)
	assert_bool(studio.work.undo()).is_true()
	assert_int(_count("fence")).is_equal(0)


func test_ghosts_are_red_only_for_the_piece_that_does_not_fit() -> void:
	studio.start_place("fence")
	await _frames(2)
	await _motion(Vector2(2, 6))
	await _button(Vector2(2, 6), true, true)
	await _motion(Vector2(11, 6))
	var ghosts: Array[Dictionary] = studio.overlay().ghosts
	assert_int(ghosts.size()).is_equal(10)
	var red := 0
	for ghost: Dictionary in ghosts:
		red += 0 if bool(ghost.ok) else 1
	assert_int(red).is_equal(1)
	var blocked := Rect2(Vector2(6, 6) * OverworldScale.TILE, Vector2.ONE * OverworldScale.TILE)
	var rejected := ghosts.filter(func(ghost: Dictionary) -> bool: return ghost.footprint == blocked)
	assert_int(rejected.size()).is_equal(1)
	assert_bool(bool(rejected[0].ok)).is_false()


func test_shift_click_without_drag_places_one() -> void:
	var steps := _history_size()
	studio.start_place("fence")
	await _frames(2)
	await _motion(Vector2(4, 11))
	await _button(Vector2(4, 11), true, true)
	assert_int(_count("fence")).is_equal(0)
	await _button(Vector2(4, 11), false, true)
	await _frames(2)
	assert_int(_count("fence")).is_equal(1)
	assert_array(_xs_of("fence")).is_equal([4])
	assert_int(_history_size()).is_equal(steps + 1)
	assert_bool(studio.arrange.placing.is_empty()).is_false()


## The catalog follows the Studio: the card being placed is marked, a piece put down goes first in Recent (a row
## counts once), and On this map lists what stands on the map as the doc changes.
func test_catalog_marks_the_card_being_placed_and_keeps_recent_and_placed() -> void:
	var old_recent := StudioPlacePanel.recent.duplicate()
	StudioPlacePanel.recent = []
	var panel := studio.place_panel()
	panel.set_filters({"view": "placed"})
	assert_array(panel.matching_ids()).is_equal(["barrel"])
	studio.start_place("fence")
	await _frames(2)
	var card := panel.find_child("Card_fence", true, false) as StudioCatalogCard
	assert_bool(card.is_placing()).is_true()
	assert_array(StudioPlacePanel.recent).is_empty()
	await _drag_row(Vector2(2, 11), Vector2(5, 11))
	assert_array(StudioPlacePanel.recent).is_equal(["fence"])
	assert_array(panel.matching_ids()).contains_exactly_in_any_order(["barrel", "fence", "fence-end-e", "fence-end-w"])
	studio.start_select()
	assert_bool(card.is_placing()).is_false()
	assert_bool(studio.work.undo()).is_true()
	assert_array(panel.matching_ids()).is_equal(["barrel"])
	StudioPlacePanel.recent = old_recent


func test_a_boundary_click_places_on_release() -> void:
	studio.start_place("fence")
	await _frames(2)
	await _motion(Vector2(4, 11))
	await _button(Vector2(4, 11), true, false)
	assert_int(_count("fence")).is_equal(0)
	await _button(Vector2(4, 11), false, false)
	assert_int(_count("fence")).is_equal(1)


func test_plain_drag_turns_wall_pieces_and_commits_once_on_release() -> void:
	var steps := _history_size()
	studio.start_place("expand-fieldstone_wall")
	await _motion(Vector2(4, 10))
	await _button(Vector2(4, 10), true, false)
	await _motion(Vector2(4, 7))
	assert_int(studio.overlay().ghosts.size()).is_equal(4)
	assert_int(_count("expand-fieldstone_wall_v")).is_equal(0)
	await _button(Vector2(4, 7), false, false)
	assert_int(_count("expand-fieldstone_wall_v")).is_equal(4)
	assert_int(_count("expand-fieldstone_wall")).is_equal(0)
	assert_int(_history_size()).is_equal(steps + 1)
	assert_bool(studio.work.undo()).is_true()
	assert_int(_count("expand-fieldstone_wall_v")).is_equal(0)
	assert_bool(studio.work.redo()).is_true()
	assert_int(_count("expand-fieldstone_wall_v")).is_equal(4)


func test_ordinary_prop_click_still_places_at_the_press_and_shift_drag_repeats() -> void:
	studio.start_place("barrel")
	await _motion(Vector2(4, 11))
	await _button(Vector2(4, 11), true, false)
	assert_int(_count("barrel")).is_equal(2)
	await _button(Vector2(4, 11), false, false)
	await _drag_row(Vector2(2, 9), Vector2(5, 9))
	assert_int(_count("barrel")).is_equal(6)


func test_variant_key_chooses_gate_direction_before_placement() -> void:
	studio.start_place("gate")
	var key := InputEventKey.new()
	key.keycode = KEY_BRACKETRIGHT
	key.physical_keycode = KEY_BRACKETRIGHT
	key.pressed = true
	studio._unhandled_input(key)
	assert_str(studio.arrange.placing.art).is_equal("gate_v")
	await _motion(Vector2(4, 11))
	await _button(Vector2(4, 11), true, false)
	await _button(Vector2(4, 11), false, false)
	assert_int(_count("gate_v")).is_equal(1)


func test_changing_variant_during_a_drag_keeps_the_pending_row() -> void:
	studio.start_place("gate")
	await _motion(Vector2(2, 11))
	await _button(Vector2(2, 11), true, false)
	await _motion(Vector2(5, 11))
	studio.arrange.cycle_variant(1)
	assert_str(studio.arrange.mode).is_equal("row")
	assert_int(studio.overlay().ghosts.size()).is_equal(4)
	assert_int(_count("gate")).is_equal(0)
	await _button(Vector2(5, 11), false, false)
	assert_int(_count("gate")).is_equal(4)
	assert_int(_count("gate_v")).is_equal(0)


func test_escape_during_a_row_places_nothing() -> void:
	var before := studio.work.doc().to_text()
	studio.start_place("fence")
	await _frames(2)
	await _motion(Vector2(2, 9))
	await _button(Vector2(2, 9), true, true)
	await _motion(Vector2(8, 9))
	assert_int(studio.overlay().ghosts.size()).is_equal(7)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	studio._unhandled_input(key)
	await _frames(1)
	assert_array(studio.overlay().ghosts).is_empty()
	await _button(Vector2(8, 9), false, true)
	await _frames(2)
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_str(studio.arrange.mode).is_equal("")


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
