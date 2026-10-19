extends GdUnitTestSuite
## The Land tab (Concept/v0.3/10, 7.8 and S5), driven with real mouse events on the mounted Studio: a 5-wide cobble road
## dragged through grass shows on the ground as the brush moves and is one undo step; Shift-drag paints a line, the
## rectangle and the fill paint what they cover, and water under a barrel is a warning; growing the map by 4 columns on
## the left moves every thing 4 cells right, the door of the house's room follows, undo and redo carry it back and
## forth, and the published files show it. Content, drafts and saves are isolated copies.

const TEST_ROOT := "user://studio_test/land"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}
const WIDTH := 20
const HEIGHT := 48

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
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Land fixture\n", _fixture()))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Land tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
	await _frames(2)
	await _frames(2)
	studio.set_tab("land")
	await _frames(1)


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


## A grass town 20 x 48 with the house whose room (home.jsonc, from the content copy) leads back to [13, 45].
func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {"id": TOWN, "name": "Land test", "legend": {".": "grass"}, "ground": rows, "start": [2, 2], "facing": "down", "objects": [
		{"kind": "prop", "art": "barrel", "at": [5, 11]},
		{"kind": "prop", "art": "oak", "at": [12, 6]},
		{"kind": "building", "art": "home", "at": [10, 39], "size": [6, 6], "door": [3, 5], "to": {"map": "home", "at": [5, 6], "facing": "up"}},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


## A world point in the root viewport's canvas coordinates.
func _canvas(world: Vector2) -> Vector2:
	var view := studio.pixel_view()
	return view.get_global_transform() * view.to_screen(world)


func _centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE


func _mouse(cell: Vector2i, pressed: Variant, shift := false) -> void:
	var event: InputEvent
	if pressed == null:
		var motion := InputEventMouseMotion.new()
		motion.position = _canvas(_centre(cell))
		motion.global_position = motion.position
		motion.shift_pressed = shift
		event = motion
	else:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = bool(pressed)
		click.shift_pressed = shift
		click.position = _canvas(_centre(cell))
		click.global_position = click.position
		event = click
	get_tree().root.push_input(event, true)
	await get_tree().process_frame


## The ground the town draws now at `cell` (the ground layer's map: a stroke under way shows there first).
func _drawn(cell: Vector2i) -> String:
	var shown: Dictionary = studio.map_view().ground.map
	return (shown.ground as PackedStringArray)[cell.y * int(shown.width) + cell.x]


func _rows() -> Array:
	return studio.work.doc().data.ground


func _char(kind: String) -> String:
	return StudioLand.char_for(studio.work.doc().data.legend, kind)


func _assert_ground_is_a_whole_bake() -> void:
	var layer := studio.map_view().ground
	var whole := GroundLayer.new()
	add_child(whole)
	whole.show_map(studio.current_map())
	assert_bool(layer.baked_picture(0).get_data() == whole.baked_picture(0).get_data()).override_failure_message(
		"the repainted ground is what a whole bake of the map gives"
	).is_true()
	whole.free()


func test_a_five_wide_cobble_road_shows_as_the_brush_moves_and_is_one_undo_step() -> void:
	studio.set_ground("cobble")
	studio.set_brush(5)
	var before := studio.work.session().history.labels().size()
	await _mouse(Vector2i(0, 20), null)
	await _mouse(Vector2i(0, 20), true)
	for x: int in range(2, WIDTH, 3):
		await _mouse(Vector2i(x, 20), null)
		# One frame after the brush moved, the ground under it is drawn as cobble: the road redraws live.
		assert_str(_drawn(Vector2i(x, 20))).override_failure_message("cobble under the brush at %d" % x).is_equal("cobble")
		assert_str(_drawn(Vector2i(x, 22))).is_equal("cobble")
		assert_str(_drawn(Vector2i(x, 23))).override_failure_message("the brush is 5 wide").is_equal("grass")
	await _mouse(Vector2i(WIDTH - 1, 20), false)
	var labels := studio.work.session().history.labels()
	assert_int(labels.size()).override_failure_message("the whole stroke is one change").is_equal(before + 1)
	assert_str(labels.back()).is_equal("Paint cobble")
	var cobble := _char("cobble")
	assert_str(cobble).override_failure_message("the legend grew a character for cobble").is_not_empty()
	for y: int in range(18, 23):
		assert_str(String(_rows()[y])).is_equal(cobble.repeat(WIDTH))
	assert_str(String(_rows()[17])).is_equal(".".repeat(WIDTH))
	_assert_ground_is_a_whole_bake()
	assert_bool(studio.work.undo()).is_true()
	await _frames(1)
	assert_str(String(_rows()[20])).is_equal(".".repeat(WIDTH))
	assert_str(_drawn(Vector2i(8, 20))).override_failure_message("undo takes the road off the ground too").is_equal("grass")
	_assert_ground_is_a_whole_bake()


func test_a_line_a_rectangle_of_water_under_a_barrel_and_a_fill() -> void:
	studio.set_ground("path")
	studio.set_brush(1)
	await _mouse(Vector2i(2, 3), null)
	await _mouse(Vector2i(2, 3), true, true)
	await _mouse(Vector2i(6, 3), null, true)
	await _mouse(Vector2i(10, 3), null, true)
	await _mouse(Vector2i(10, 3), false, true)
	var path := _char("path")
	assert_str(String(_rows()[3]).substr(2, 9)).override_failure_message("Shift-drag paints the line").is_equal(path.repeat(9))
	assert_str(studio.work.session().history.labels().back()).is_equal("Paint a line of path")
	studio.set_land_tool("rect")
	studio.set_ground("water")
	await _mouse(Vector2i(3, 10), null)
	await _mouse(Vector2i(3, 10), true)
	await _mouse(Vector2i(6, 12), null)
	await _mouse(Vector2i(6, 12), false)
	var water := _char("water")
	for y: int in range(10, 13):
		assert_str(String(_rows()[y]).substr(3, 4)).is_equal(water.repeat(4))
	var status := studio.status_bar()
	assert_str(status.message_text).override_failure_message("water under the barrel is said").contains("water under 1 thing")
	_assert_ground_is_a_whole_bake()
	studio.set_land_tool("fill")
	studio.set_ground("flowers")
	await _mouse(Vector2i(0, 0), null)
	await _mouse(Vector2i(0, 0), true)
	await _mouse(Vector2i(0, 0), false)
	var flowers := _char("flowers")
	assert_str(String(_rows()[0])).is_equal(flowers.repeat(WIDTH))
	assert_str(String(_rows()[3]).substr(2, 9)).override_failure_message("the fill stops at the path").is_equal(path.repeat(9))
	assert_str(String(_rows()[11]).substr(3, 4)).override_failure_message("and at the water").is_equal(water.repeat(4))
	assert_str(studio.work.session().history.labels().back()).is_equal("Fill with flowers")


func test_esc_mid_stroke_puts_the_ground_back() -> void:
	studio.set_ground("cobble")
	studio.set_brush(3)
	await _mouse(Vector2i(4, 4), null)
	await _mouse(Vector2i(4, 4), true)
	await _mouse(Vector2i(8, 4), null)
	assert_str(_drawn(Vector2i(6, 4))).is_equal("cobble")
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	get_tree().root.push_input(key)
	await _frames(1)
	assert_str(_drawn(Vector2i(6, 4))).is_equal("grass")
	await _mouse(Vector2i(8, 4), false)
	assert_str(String(_rows()[4])).is_equal(".".repeat(WIDTH))
	assert_bool(studio.editing).override_failure_message("Esc stopped the stroke, not Edit").is_true()


func test_the_expanded_ground_palette_paints_new_surfaces_and_saves_their_legends() -> void:
	var expected: Array[String] = ["grass", "meadow", "dry_grass", "forest_floor", "moss", "root_floor", "fern_moss", "glow_moss", "flowers", "path", "brick_path", "stone_path", "wood_path", "soil", "tilled_soil", "sand", "gravel", "cobble", "water"]
	assert_array(studio.land.grounds()).is_equal(expected)
	assert_str((studio.find_child("Ground_path", true, false) as Button).text).is_equal("Dirt path")
	var before: Array = _rows().duplicate()
	for index in range(1, expected.size()):
		var kind := expected[index]
		var button := studio.find_child("Ground_" + kind, true, false) as Button
		assert_object(button).is_not_null()
		assert_object(button.icon).override_failure_message("%s has its own terrain swatch" % kind).is_not_null()
		button.pressed.emit()
		assert_str(studio.land.kind).is_equal(kind)
		var cell := Vector2i(index, 20)
		await _mouse(cell, null)
		await _mouse(cell, true)
		await _mouse(cell, false)
		assert_str(_drawn(cell)).is_equal(kind)
		assert_str(StudioLand.char_for(studio.work.doc().data.legend, kind)).is_not_empty()
	_assert_ground_is_a_whole_bake()
	assert_bool(studio.work.flush()).is_true()
	var saved := StudioDoc.parse(_path(TOWN), "map", studio.work.doc().to_text())
	assert_bool(saved.ok).is_true()
	var built := StudioSession.build_data(saved.doc.data, _path(TOWN), studio.catalog().terrain)
	assert_array(built.errors).is_empty()
	for index in range(1, expected.size()):
		assert_str(OverworldMap.terrain_at(built.map, Vector2i(index, 20))).is_equal(expected[index])
	for index in range(1, expected.size()):
		assert_bool(studio.work.undo()).is_true()
	assert_array(_rows()).is_equal(before)
	_assert_ground_is_a_whole_bake()


func test_growing_the_map_four_columns_on_the_left_moves_every_thing_and_the_files_show_it() -> void:
	var before: Array = (studio.work.doc().data.objects as Array).duplicate(true)
	var walker := studio.player()
	var walker_cell := walker.cell
	studio.open_map_size()
	await _frames(1)
	studio.map_size.set_edge("left", 4)
	assert_str(studio.map_size.summary()).contains("New size: 24 x 48")
	assert_str(studio.map_size.summary()).contains("1 doors from other maps lead here")
	studio.map_size.confirmed.emit()
	studio.map_size.hide()
	await _frames(2)
	var after: Array = studio.work.doc().data.objects
	assert_int(after.size()).is_equal(before.size())
	for index: int in before.size():
		var was := OverworldMap.cell_of((before[index] as Dictionary).at)
		assert_vector(Vector2(OverworldMap.cell_of((after[index] as Dictionary).at))).is_equal(Vector2(was + Vector2i(4, 0)))
	assert_str(String(_rows()[0])).is_equal(".".repeat(24))
	assert_array(studio.work.doc().data.start).is_equal([6, 2])
	assert_int(int(studio.current_map().width)).is_equal(24)
	assert_vector(Vector2(walker.cell)).override_failure_message("the player stands where they stood").is_equal(Vector2(walker_cell + Vector2i(4, 0)))
	var home: StudioSession = studio.work.sessions()["home"]
	assert_str(JSON.stringify(home.doc().data)).override_failure_message("the room's door follows").contains('"at":[17,45]')
	assert_str(JSON.stringify(home.doc().data)).not_contains('"at":[13,45]')
	assert_str(studio.work.session().history.labels().back()).is_equal("Resize the map to 24 x 48")
	# Undo and redo carry the door in the other map back and forth with the town.
	assert_bool(studio.work.undo()).is_true()
	await _frames(1)
	assert_int(int(studio.current_map().width)).is_equal(20)
	assert_str(JSON.stringify(home.doc().data)).contains('"at":[13,45]')
	assert_vector(Vector2(walker.cell)).is_equal(Vector2(walker_cell))
	assert_bool(studio.work.redo()).is_true()
	await _frames(1)
	assert_int(int(studio.current_map().width)).is_equal(24)
	assert_str(JSON.stringify(home.doc().data)).contains('"at":[17,45]')
	# Publish writes both files.
	assert_bool(studio.work.flush()).is_true()
	var publisher := StudioPublish.new()
	publisher.content_root = StudioMode.content_dir
	publisher.drafts_dir = StudioMode.drafts_dir
	publisher.backups_dir = _root.path_join("backups")
	var result := publisher.publish(studio.work.sessions(), true)
	assert_bool(result.ok).override_failure_message("publish: %s" % str(result)).is_true()
	var town := StudioFiles.read_text(_path(TOWN))
	assert_str(town).contains('"art": "barrel", "at": [9, 11]')
	assert_str(town).contains('"art": "home", "at": [14, 39]')
	assert_str(town).contains('"' + ".".repeat(24) + '"')


func test_map_size_dialog_allows_more_than_64_added_tiles() -> void:
	studio.open_map_size()
	await _frames(1)
	var right := studio.map_size.find_child("Edge_right", true, false) as SpinBox
	assert_float(right.max_value).is_equal_approx(float(StudioLand.MAX_DIMENSION - WIDTH), 0.001)
	studio.map_size.set_edge("right", 100)
	assert_str(studio.map_size.summary()).contains("New size: 120 x 48")
	studio.map_size.confirmed.emit()
	studio.map_size.hide()
	await _frames(2)
	assert_int(int(studio.current_map().width)).is_equal(120)
	assert_int(int(studio.current_map().height)).is_equal(48)


func test_new_area_button_makes_a_named_draft_switches_to_it_and_lists_it_for_publish() -> void:
	var button := studio.find_child("NewArea", true, false) as Button
	assert_object(button).is_not_null()
	studio.set_tab("objects")
	button.pressed.emit()
	var dialog := studio.area_dialog
	assert_bool(dialog.visible).is_true()
	assert_int(dialog.size.y).is_less_equal(420)
	var name_field := dialog.find_child("AreaName", true, false) as LineEdit
	var id_field := dialog.find_child("AreaId", true, false) as LineEdit
	name_field.clear()
	name_field.insert_text_at_caret("Mossback Grove")
	name_field.text_changed.emit(name_field.text)
	assert_str(name_field.text).override_failure_message("the title text should replace its default").is_equal("Mossback Grove")
	assert_str(id_field.text).override_failure_message("name='%s', auto=%s" % [name_field.text, str(dialog.get("_auto_id"))]).is_equal("mossback-grove")
	id_field.clear()
	id_field.insert_text_at_caret("mossback.grove")
	id_field.text_changed.emit(id_field.text)
	(dialog.find_child("AreaWidth", true, false) as SpinBox).value = 24
	(dialog.find_child("AreaHeight", true, false) as SpinBox).value = 18
	(dialog.find_child("AreaStartX", true, false) as SpinBox).value = 3
	(dialog.find_child("AreaStartY", true, false) as SpinBox).value = 4
	var facing := dialog.find_child("AreaFacing", true, false) as OptionButton
	facing.select(2)
	facing.item_selected.emit(2)
	assert_str(id_field.text).is_equal("mossback.grove")
	assert_bool(dialog.get_ok_button().disabled).is_false()
	dialog.confirmed.emit()
	await _frames(3)
	assert_str(String(studio.current_map().id)).is_equal("mossback.grove")
	assert_str(String(studio.current_map().name)).is_equal("Mossback Grove")
	assert_int(int(studio.current_map().width)).is_equal(24)
	assert_int(int(studio.current_map().height)).is_equal(18)
	assert_vector(Vector2(OverworldMap.cell_of(studio.current_map().start))).is_equal(Vector2(3, 4))
	assert_str(String(studio.current_map().facing)).is_equal("left")
	assert_str(studio.tab).is_equal("land")
	assert_bool(studio.work.session().is_new).is_true()
	assert_bool(OverworldMap.blocked(studio.current_map(), Vector2i(3, 4))).is_false()
	assert_array(studio.work.doc().data.objects).is_empty()
	assert_bool(studio.map_list().any(func(item: Dictionary) -> bool: return String(item.id) == "mossback.grove")).is_true()
	assert_bool(StudioFiles.exists(_path("mossback.grove"))).is_false()
	assert_bool(studio.work.flush()).is_true()
	var publisher := StudioPublish.new()
	publisher.content_root = StudioMode.content_dir
	publisher.drafts_dir = StudioMode.drafts_dir
	var report := publisher.review(studio.work.sessions())
	var changes: Array[String] = []
	for change: Dictionary in report.changes:
		changes.append(String(change.file))
	assert_array(changes).contains([_path("mossback.grove")])
	assert_str(StudioFiles.read_text(_path("home"))).contains('"at": [13, 45]')
	var loaded: Dictionary = OverworldContent.load_world(StudioMode.content_dir).catalog.maps[TOWN]
	assert_int(int(loaded.width)).override_failure_message("the published town remains unchanged").is_equal(WIDTH)


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
