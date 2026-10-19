extends GdUnitTestSuite
## B01 mounted construction, isolated content/drafts/saves and actual world gestures.

const TEST_ROOT := "user://studio_test/build"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}
const WIDTH := 32
const HEIGHT := 24
var screen: OverworldScreen
var studio: StudioMode
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_env := ""
var _old_catalog: Dictionary = {}
var _old_recent: Array[String] = []


func before_test() -> void:
	_old_recent = StudioPlacePanel.recent.duplicate()
	StudioPlacePanel.recent = []
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
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Build fixture\n", _fixture()))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Builder"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
	studio.set_tab("build")
	await _frames(2)
	await _frames(2)
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
	StudioPlacePanel.recent = _old_recent
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {"id": TOWN, "name": "Build test", "legend": {".": "grass"}, "ground": rows,
		"start": [2, 2], "facing": "down", "objects": []}


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


func test_build_groups_scope_recent_on_map_and_reset_without_changing_documents() -> void:
	var build := studio.build_panel()
	var catalog := build.catalog
	var before := studio.work.doc().to_text()
	var source := StudioFiles.read_text(_path(TOWN))
	for group: String in StudioBuildCatalog.GROUPS:
		(build.find_child("BuildGroup_" + group, true, false) as Button).pressed.emit()
		assert_array(catalog.matching_ids()).is_not_empty()
		for id: String in catalog.matching_ids():
			assert_str(StudioBuildCatalog.group(StudioAssets.entry_of(id))).is_equal(group)
	build.choose_group("building")
	catalog.note_used("oak")
	catalog.note_used("cottage")
	catalog.set_filters({"view": "recent"})
	assert_array(catalog.matching_ids()).is_equal(["cottage"])
	catalog.set_placed(["oak", "cottage", "rug"])
	catalog.set_filters({"view": "placed"})
	assert_array(catalog.matching_ids()).is_equal(["cottage"])
	catalog.search_for("oak")
	assert_array(catalog.matching_ids()).is_empty()
	catalog.reset_filters()
	for id: String in catalog.matching_ids():
		assert_str(String(StudioAssets.entry_of(id).kind)).is_equal("building")
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_str(StudioFiles.read_text(_path(TOWN))).is_equal(source)


func test_objects_and_build_preserve_independent_search_and_scroll_with_two_complete_rows() -> void:
	var build := studio.build_panel()
	var objects := studio._place_panel
	objects.search_for("tree")
	build.choose_group("boundary")
	var catalog := build.catalog
	await _frames(4)
	var scroll := catalog.find_child("Cards", true, false) as ScrollContainer
	assert_float(scroll.size.y).override_failure_message("two full construction card rows").is_greater_equal(StudioCatalogCard.HEIGHT * 2 + 4)
	scroll.scroll_vertical = 100
	await _frames(2)
	var scroll_before := scroll.scroll_vertical
	assert_int(scroll_before).is_greater(0)
	studio.set_tab("objects")
	assert_str(objects.filters().text).is_equal("tree")
	studio.set_tab("land")
	studio.set_tab("people")
	studio.set_tab("build")
	await _frames(3)
	assert_int(scroll.scroll_vertical).is_equal(scroll_before)
	assert_str(build.group).is_equal("boundary")
	catalog.search_for("brick")
	studio.set_tab("objects")
	assert_str(objects.filters().text).is_equal("tree")
	studio.set_tab("build")
	assert_str(catalog.filters().text).is_equal("brick")
	assert_bool(objects.visible).is_false()
	assert_bool(studio._land_panel.visible).is_false()
	assert_bool(studio.people_panel().visible).is_false()
	assert_bool(build.visible).is_true()
	assert_int(studio._bottom()).is_equal(StudioStyle.BOTTOM + StudioStyle.PLACE)


func test_build_card_places_canonical_building_and_map_history_undo_redo_retains_sid() -> void:
	var catalog := studio.build_panel().catalog
	var card := catalog.find_child("Card_cottage", true, false) as StudioCatalogCard
	card.picked.emit("cottage")
	assert_str(String(studio.arrange.placing.art)).is_equal("cottage")
	assert_dict(studio.arrange.placing).is_equal(StudioAssets.template("cottage"))
	await _click_world(Vector2i(10, 8))
	assert_int((studio.work.doc().data.objects as Array).size()).is_equal(1)
	assert_str(String(studio.work.raw(0).art)).is_equal("cottage")
	var sid := studio.work.sid_at(0)
	studio.start_select()
	studio._top.undo_pressed.emit()
	assert_int((studio.work.doc().data.objects as Array).size()).is_equal(0)
	studio._top.redo_pressed.emit()
	assert_int(studio.work.sid_at(0)).is_equal(sid)
	assert_str(String(studio.work.raw(0).art)).is_equal("cottage")
	assert_array(catalog.matching_ids()).contains(["cottage"])


func test_build_group_and_tab_changes_cancel_pending_gestures_and_text_focus_owns_keys() -> void:
	var build := studio.build_panel()
	build.choose_group("boundary")
	(build.catalog.find_child("Card_fence", true, false) as StudioCatalogCard).picked.emit("fence")
	var before := studio.work.doc().to_text()
	var start := _world_point(Vector2i(10, 8))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	studio._world_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = _world_point(Vector2i(15, 8))
	studio._world_input(motion)
	build.choose_group("gate")
	assert_bool(studio.arrange.placing.is_empty()).is_true()
	assert_str(studio.arrange.mode).is_equal("")
	assert_str(studio.work.doc().to_text()).is_equal(before)
	var search := build.catalog.find_child("Search", true, false) as LineEdit
	search.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_DELETE
	key.pressed = true
	assert_bool(StudioKeys.new(studio).handle(key)).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	studio.set_tab("people")
	assert_bool(studio.text_editor_focused()).is_false()
	assert_bool(build.visible).is_false()


func test_floor_action_opens_existing_land_brush_while_rug_stays_a_ground_object() -> void:
	var build := studio.build_panel()
	build.choose_group("furniture")
	var paint := build.find_child("PaintFloor", true, false) as Button
	assert_bool(paint.visible).is_true()
	assert_bool(paint.disabled).is_true()
	assert_bool(studio.go_to_map("home")).is_true()
	await _frames(2)
	assert_str(studio.tab).is_equal("build")
	assert_bool(paint.disabled).is_false()
	var before := studio.work.doc().to_text()
	(build.catalog.find_child("Card_rug", true, false) as StudioCatalogCard).picked.emit("rug")
	assert_str(String(studio.arrange.placing.draw_layer)).is_equal("ground")
	assert_bool(bool(studio.arrange.placing.solid)).is_false()
	paint.pressed.emit()
	assert_str(studio.tab).is_equal("land")
	assert_str(studio.land.kind).is_equal("floor")
	assert_str(studio.land.tool).is_equal("brush")
	assert_bool(studio.arrange.placing.is_empty()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_build_clears_unsupported_area_tool_and_tab_keeps_objects_catalog_preference() -> void:
	studio.set_tab("objects")
	studio.set_place_list(true)
	studio.start_area_select()
	studio.set_area_filter("trees")
	assert_bool(studio.arrange.area_select).is_true()
	studio.set_tab("build")
	assert_bool(studio.arrange.area_select).is_false()
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	studio._stack.clear()
	assert_bool(StudioKeys.new(studio).handle(key)).is_true()
	assert_bool(studio.place_list_shown()).is_true()
	studio.set_tab("objects")
	assert_bool(studio._place_panel.visible).is_true()


func test_passive_shared_catalog_updates_retain_hidden_panel_scroll() -> void:
	var catalog := studio.build_panel().catalog
	studio.build_panel().choose_group("boundary")
	var ids := catalog.matching_ids()
	catalog.set_filters({"view": "placed"})
	catalog.set_placed(ids)
	await _frames(3)
	var scroll := catalog.find_child("Cards", true, false) as ScrollContainer
	scroll.scroll_vertical = 90
	await _frames(2)
	var before := scroll.scroll_vertical
	assert_int(before).is_greater(0)
	studio.set_tab("objects")
	catalog.set_placed(ids)
	studio.note_placed("cottage")
	studio.set_tab("build")
	await _frames(3)
	assert_int(scroll.scroll_vertical).is_equal(before)


func _world_point(cell: Vector2i) -> Vector2:
	var point := (Vector2(cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE
	var view := studio.pixel_view()
	return studio._catcher.get_global_transform().affine_inverse() * (view.get_global_transform() * view.to_screen(point))


func _click_world(cell: Vector2i) -> void:
	studio.focus((Vector2(cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE)
	await _frames(2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = _world_point(cell)
	click.pressed = true
	studio._world_input(click)
	click.pressed = false
	studio._world_input(click)
	await _frames(2)
