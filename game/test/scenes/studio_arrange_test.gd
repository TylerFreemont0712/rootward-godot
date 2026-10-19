extends GdUnitTestSuite
## Arrange exercises the live Studio against temporary content copies and its own drafts and saves. It never writes
## res:// or reads the player's drafts. The first case is S1's acceptance walk through on the full town.

const TEST_ROOT := "user://studio_test/arrange"
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
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _open(full_town := false) -> void:
	if not full_town:
		assert_bool(StudioFiles.write_content(_path(), JsoncWriter.map_text("// Studio Arrange fixture\n", _fixture()))).is_true()
		# The tiny fixture exercises ordinary person deletion, not town schedule ownership.
		var path := StudioMode.content_dir.path_join("packs/core/overworld/schedules.jsonc")
		var schedules: Dictionary = Jsonc.parse(StudioFiles.read_text(path)).value
		schedules.erase("pip")
		assert_bool(StudioFiles.write_content(path, JsoncWriter.schedules_text("", schedules))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var map: Dictionary = OverworldScreen.catalog_of().maps[TOWN]
	var state := OverworldState.fresh(TOWN, map.start, "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Studio tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	await _mount()


func _mount() -> void:
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	assert_object(studio).is_not_null()
	studio.set_editing(true)
	await _frames(2)
	assert_object(studio.work.session()).is_not_null()


func _path() -> String:
	return StudioSession.path_of(TOWN, StudioMode.content_dir)


func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in 14:
		rows.append("..................")
	return {"id": TOWN, "name": "Arrange test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "prop", "art": "noticeboard", "at": [3, 4], "talk": "noticeboard"},
		{"kind": "prop", "art": "bench", "at": [8, 4], "size": [2, 1]},
		{"kind": "prop", "art": "oak", "at": [12, 4]},
		{"kind": "prop", "art": "barrel", "at": [3, 8]},
		{"kind": "person", "id": "pip", "at": [8, 8], "facing": "down"},
		{"kind": "prop", "art": "sign", "id": "test-thing", "at": [12, 8], "text": "A named thing"},
		{"kind": "prop", "art": "rug", "at": [3, 8], "size": [2, 1], "solid": false, "draw_layer": "ground"},
		{"kind": "building", "art": "cottage", "at": [14, 1], "size": [3, 3], "door": [1, 2], "name": "Test house"},
	]}


func _sid(art: String) -> int:
	for index: int in (studio.work.doc().data.objects as Array).size():
		var object := studio.work.raw(index)
		if String(object.get("art", "")) == art or String(object.get("id", "")) == art:
			return studio.work.sid_at(index)
	assert_bool(false).override_failure_message("fixture is missing " + art).is_true()
	return -1


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _key(code: Key, shift := false, control := false, alt := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = control
	event.alt_pressed = alt
	studio._unhandled_input(event)
	event.pressed = false
	studio._unhandled_input(event)


func _cursor(point: Vector2) -> Vector2:
	var catcher := studio.get_node("Chrome/World") as Control
	var view := studio.pixel_view()
	var on_view := view.to_screen(point)
	var here := catcher.get_global_transform().affine_inverse() * (view.get_global_transform() * on_view)
	studio._set_cursor(here)
	return here


func _click(point: Vector2, down: bool, alt := false, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = _cursor(point)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.alt_pressed = alt
	event.shift_pressed = shift
	studio._world_input(event)


func _open_cell() -> Vector2i:
	var map := studio.current_map()
	for y: int in range(2, int(map.height) - 2):
		for x: int in range(2, int(map.width) - 2):
			var cell := Vector2i(x, y)
			if not OverworldMap.blocked(map, cell) and studio.pick().objects_at_cell(cell).is_empty():
				return cell
	return Vector2i.ONE


func test_arrange_acceptance_undo_redo_restart_and_content_bytes() -> void:
	await _open(true)
	var source := StudioFiles.read_text(_path())
	var real_source := StudioFiles.read_text(StudioSession.path_of(TOWN))
	var original := studio.work.doc().copy()
	var noticeboard := _sid("noticeboard")
	var bench := _sid("bench")
	var tree := _sid("oak")
	assert_bool(studio.work.move([noticeboard], Vector2i(3, 0)).ok).is_true()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), _open_cell()).ok).is_true()
	assert_bool(studio.work.place(StudioAssets.template("barrel"), _open_cell()).ok).is_true()
	assert_bool(studio.work.delete([bench]).ok).is_true()
	assert_int(studio.work.flip([tree])).is_equal(1)
	var changed := studio.work.doc().copy()
	assert_array(changed.object_of_sid(noticeboard).at).is_equal([46, 20])
	assert_int(changed.data.objects.size()).is_equal(original.data.objects.size() + 1)
	assert_bool(changed.object_of_sid(tree).flip).is_true()
	assert_int(studio.work.session().history.labels().size()).is_equal(5)
	for step: int in 5:
		assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(original.to_text())
	assert_array(studio.work.doc().sids).is_equal(original.sids)
	for step: int in 5:
		assert_bool(studio.work.redo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(changed.to_text())
	assert_array(studio.work.doc().sids).is_equal(changed.sids)
	studio.set_play_draft(true)
	studio.set_editing(false)
	assert_that(studio.current_map().objects[studio.work.index_of(noticeboard)].at).is_equal(Vector2i(46, 20))
	assert_bool(studio.get_node("DraftTag").visible).is_true()
	assert_str(StudioFiles.read_text(_path())).is_equal(source)
	assert_str(StudioFiles.read_text(StudioSession.path_of(TOWN))).is_equal(real_source)
	screen.queue_free()
	await _frames(6)
	Background.finish_all()
	await _mount()
	assert_str(studio.work.doc().to_text()).is_equal(changed.to_text())
	assert_array(studio.work.doc().sids).is_equal(changed.sids)
	assert_str(StudioFiles.read_text(_path())).is_equal(source)


func test_drag_ghost_snaps_refuses_red_and_alt_keeps_problem() -> void:
	await _open()
	var tile := float(OverworldScale.TILE)
	var sid := _sid("noticeboard")
	_click(Vector2(3.5, 4.5) * tile, true)
	_cursor(Vector2(5.6, 5.8) * tile)
	assert_that(studio.arrange.delta).is_equal(Vector2i(2, 1))
	assert_bool(studio.arrange.fits).is_true()
	assert_that(studio.overlay().ghosts[0].footprint.position).is_equal(Vector2(5, 5) * tile)
	assert_array(studio.work.doc().object_of_sid(sid).at).is_equal([3, 4])
	_click(Vector2(5.6, 5.8) * tile, false)
	assert_array(studio.work.doc().object_of_sid(sid).at).is_equal([5, 5])
	_click(Vector2(5.5, 5.5) * tile, true)
	_cursor(Vector2(8.5, 4.5) * tile)
	assert_bool(studio.arrange.fits).is_false()
	assert_bool(studio.overlay().ghosts[0].ok).is_false()
	assert_str(studio.status_bar().message_text).contains("overlaps")
	_click(Vector2(8.5, 4.5) * tile, false)
	assert_array(studio.work.doc().object_of_sid(sid).at).is_equal([5, 5])
	_click(Vector2(5.5, 5.5) * tile, true)
	_click(Vector2(8.5, 4.5) * tile, false, true)
	assert_array(studio.work.doc().object_of_sid(sid).at).is_equal([8, 4])
	assert_array(studio.work.session().build(studio.catalog().terrain).problems).is_not_empty()
	assert_bool(studio.work.undo()).is_true()
	assert_array(studio.overlay().ghosts).is_empty()


func test_arrows_nudge_one_cell_and_shift_nudges_four_with_exact_history() -> void:
	await _open()
	var sid := _sid("noticeboard")
	studio.select_sids([sid])
	_key(KEY_RIGHT)
	_key(KEY_DOWN, true)
	assert_array(studio.work.doc().object_of_sid(sid).at).is_equal([4, 8])
	assert_array(studio.selected_sids()).is_equal([sid])
	assert_int((studio.get_node("Chrome/Tools") as StudioTools).history.lines.size()).is_equal(2)
	_key(KEY_Z, false, true)
	_key(KEY_Z, false, true)
	assert_array(studio.work.doc().object_of_sid(sid).at).is_equal([3, 4])
	_key(KEY_Y, false, true)
	_key(KEY_Z, true, true)
	assert_array(studio.work.doc().object_of_sid(sid).at).is_equal([4, 8])


func test_box_shift_selection_and_tab_cycle_use_session_ids() -> void:
	await _open()
	var tile := float(OverworldScale.TILE)
	_click(Vector2(1.5, 6.5) * tile, true)
	_cursor(Vector2(10.5, 10.5) * tile)
	_click(Vector2(10.5, 10.5) * tile, false)
	assert_array(studio.selected_sids()).contains([_sid("barrel"), _sid("pip"), _sid("rug")])
	studio.toggle_selected(studio.work.index_of(_sid("pip")))
	assert_bool(_sid("pip") in studio.selected_sids()).is_false()
	_cursor(Vector2(3.5, 8.5) * tile)
	studio.select(studio.stack()[0])
	var first := studio.selection
	_key(KEY_TAB)
	assert_int(studio.selection).is_not_equal(first)
	_key(KEY_TAB)
	assert_int(studio.selection).is_equal(first)
	_cursor(Vector2(1.5, 1.5) * tile)
	var list_before := studio.place_list_shown()
	_key(KEY_TAB)
	assert_bool(studio.place_list_shown()).is_equal(not list_before)


func test_area_tool_starts_on_trees_previews_filters_and_deletes_in_one_undo() -> void:
	await _open()
	assert_bool(studio.work.place(StudioAssets.template("oak2"), Vector2i(10, 4)).ok).is_true()
	var before := studio.work.doc().copy()
	var steps := studio.work.session().history.labels().size()
	var oak := _sid("oak")
	var oak2 := _sid("oak2")
	var barrel := _sid("barrel")
	studio.select_sids([barrel])
	_key(KEY_Q)
	assert_bool(studio.arrange.area_select).is_true()
	var tools := studio.get_node("Chrome/Tools") as StudioTools
	var filter := tools.find_child("AreaFilter", true, false) as OptionButton
	filter.select(2)
	filter.item_selected.emit(2)
	assert_str(studio.arrange.area_filter).is_equal("trees")
	var tile := float(OverworldScale.TILE)
	_click(Vector2(12.5, 4.5) * tile, true)
	assert_str(studio.arrange.mode).is_equal("box")
	_cursor(Vector2(8.5, 4.5) * tile)
	assert_that(studio.overlay().box).is_equal(Rect2(Vector2(8, 4) * tile, Vector2(5, 1) * tile))
	assert_int(studio.overlay().box_count).is_equal(2)
	assert_int(studio.overlay().area_footprints.size()).is_equal(2)
	assert_array(studio.overlay().ghosts).is_empty()
	assert_array(studio.selected_sids()).is_equal([barrel])
	_key(KEY_DELETE)
	_key(KEY_RIGHT)
	assert_str(studio.work.doc().to_text()).is_equal(before.to_text())
	_click(Vector2(8.5, 4.5) * tile, false)
	assert_int(studio.selected_sids().size()).is_equal(2)
	assert_array(studio.selected_sids()).contains([oak, oak2])
	assert_int(studio.overlay().box_count).is_equal(-1)
	assert_array(studio.overlay().area_footprints).is_empty()
	_key(KEY_DELETE)
	assert_int(studio.work.index_of(oak)).is_equal(-1)
	assert_int(studio.work.index_of(oak2)).is_equal(-1)
	assert_int(studio.work.index_of(barrel)).is_greater_equal(0)
	assert_int(studio.work.index_of(_sid("bench"))).is_greater_equal(0)
	assert_int(studio.work.session().history.labels().size()).is_equal(steps + 1)
	var deleted := studio.work.doc().to_text()
	_key(KEY_Z, false, true)
	assert_str(studio.work.doc().to_text()).is_equal(before.to_text())
	assert_array(studio.work.doc().sids).is_equal(before.sids)
	_key(KEY_Y, false, true)
	assert_str(studio.work.doc().to_text()).is_equal(deleted)
	_key(KEY_Z, false, true)
	assert_str(studio.work.doc().to_text()).is_equal(before.to_text())


func test_area_shift_add_click_cell_and_escape_preserve_objects_and_prior_selection() -> void:
	await _open()
	var before := studio.work.doc().to_text()
	var barrel := _sid("barrel")
	var oak := _sid("oak")
	var tools := studio.get_node("Chrome/Tools") as StudioTools
	(tools.find_child("SelectArea", true, false) as Button).pressed.emit()
	studio.set_area_filter("trees")
	studio.select_sids([barrel])
	var tile := float(OverworldScale.TILE)
	_click(Vector2(12.5, 4.5) * tile, true, false, true)
	_click(Vector2(12.5, 4.5) * tile, false, false, true)
	assert_array(studio.selected_sids()).is_equal([barrel, oak])
	_click(Vector2(12.5, 4.5) * tile, true)
	_cursor(Vector2(1.5, 1.5) * tile)
	_key(KEY_ESCAPE)
	assert_str(studio.arrange.mode).is_empty()
	assert_bool(studio.arrange.area_select).is_true()
	assert_array(studio.selected_sids()).is_equal([barrel, oak])
	assert_array(studio.overlay().area_footprints).is_empty()
	_click(Vector2(1.5, 1.5) * tile, false)
	assert_array(studio.selected_sids()).is_equal([barrel, oak])
	assert_str(studio.work.doc().to_text()).is_equal(before)
	_key(KEY_ESCAPE)
	assert_bool(studio.arrange.area_select).is_false()
	assert_array(studio.selected_sids()).is_equal([barrel, oak])
	assert_bool(studio.editing).is_true()
	assert_bool(studio.work.session().history.can_undo()).is_false()


func test_area_filters_use_footprints_and_named_targets_keep_delete_confirmation() -> void:
	await _open()
	var tile := float(OverworldScale.TILE)
	var area := Rect2(Vector2(0, 0), Vector2(18, 14) * tile)
	var all := studio.sids_in_area(area)
	var props := studio.sids_in_area(area, "props")
	var trees := studio.sids_in_area(area, "trees")
	assert_int(all.size()).is_equal(8)
	assert_int(props.size()).is_equal(6)
	assert_array(trees).is_equal([_sid("oak")])
	assert_array(studio.sids_in_area(Rect2(Vector2(12, 1) * tile, Vector2(1, 1) * tile), "trees")).is_empty()
	assert_array(studio.sids_in_area(Rect2(Vector2(-1000, -1000) * tile, Vector2(2000, 2000) * tile))).is_equal(all)
	_key(KEY_Q)
	_click(Vector2(7.5, 8.5) * tile, true)
	_click(Vector2(8.5, 8.5) * tile, false)
	assert_array(studio.selected_sids()).is_equal([_sid("pip")])
	_key(KEY_DELETE)
	assert_bool((studio.get("_confirm") as ConfirmationDialog).visible).is_true()
	assert_int(studio.work.index_of(_sid("pip"))).is_greater_equal(0)
	_key(KEY_ESCAPE)
	assert_bool((studio.get("_confirm") as ConfirmationDialog).visible).is_false()
	assert_bool(studio.work.session().history.can_undo()).is_false()


func test_duplicate_copy_paste_strip_identity_and_keep_relative_cells() -> void:
	await _open()
	var original := studio.work.doc().copy()
	var bench := _sid("bench")
	studio.select_sids([bench])
	_key(KEY_D, false, true)
	assert_int(studio.selected_sids().size()).is_equal(1)
	assert_bool(studio.selected_sids()[0] != bench).is_true()
	assert_str(studio.selected_object().art).is_equal("bench")
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(original.to_text())
	var named := _sid("test-thing")
	assert_int(studio.work.copy([bench, named, _sid("pip")])).is_equal(2)
	var pasted := studio.work.paste(Vector2i(7, 12))
	assert_int(pasted.size()).is_equal(2)
	for sid: int in pasted:
		var raw := studio.work.doc().object_of_sid(sid)
		assert_bool(raw.has("id")).is_false()
		assert_bool(raw.has("program")).is_false()
	assert_that(OverworldMap.cell_of(studio.work.doc().object_of_sid(pasted[1]).at) - OverworldMap.cell_of(studio.work.doc().object_of_sid(pasted[0]).at)).is_equal(Vector2i(4, 4))
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(original.to_text())


func test_delete_people_and_named_things_confirm_without_reusing_canceled_selection() -> void:
	await _open()
	var pip := _sid("pip")
	var named := _sid("test-thing")
	assert_bool(studio.work.delete([pip]).needs_confirm).is_true()
	assert_bool(studio.work.delete([named]).needs_confirm).is_true()
	studio.select_sids([pip])
	studio.request_delete()
	var dialog := studio.get("_confirm") as ConfirmationDialog
	dialog.canceled.emit()
	dialog.hide()
	studio.select_sids([named])
	studio.request_delete()
	dialog.confirmed.emit()
	dialog.hide()
	assert_int(studio.work.index_of(named)).is_equal(-1)
	assert_int(studio.work.index_of(pip)).is_greater_equal(0)
	assert_bool(studio.work.undo()).is_true()
	assert_int(studio.work.index_of(named)).is_greater_equal(0)


func test_inspector_fields_flip_and_person_facing_are_undoable() -> void:
	await _open()
	var original := studio.work.doc().to_text()
	var bench := _sid("bench")
	studio.select_sids([bench])
	var inspector := studio.inspector()
	inspector.field_changed.emit(bench, "text", "A quiet seat")
	inspector.field_changed.emit(bench, "solid", false)
	inspector.field_changed.emit(bench, "sink", 3)
	inspector.field_changed.emit(bench, "draw_layer", "ground")
	assert_dict(studio.work.doc().object_of_sid(bench)).contains_key_value("text", "A quiet seat")
	assert_bool(studio.selected_object().solid).is_false()
	assert_int(studio.selected_object().sink).is_equal(3)
	assert_str(inspector.raw_json).contains('"draw_layer": "ground"')
	var house := _sid("cottage")
	inspector.field_changed.emit(house, "name", "New name")
	var pip := _sid("pip")
	studio.select_sids([pip])
	_key(KEY_R)
	assert_str(studio.work.doc().object_of_sid(pip).facing).is_equal("left")
	var tree := _sid("oak")
	studio.select_sids([tree])
	_key(KEY_F)
	assert_bool(studio.work.doc().object_of_sid(tree).flip).is_true()
	assert_int(studio.work.flip([house, pip])).is_equal(0)
	for step: int in 7:
		assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(original)


func test_draft_save_debounces_then_flushes_on_leaving_edit() -> void:
	await _open()
	var path := StudioFiles.draft_path(_path(), StudioMode.drafts_dir)
	assert_bool(FileAccess.file_exists(path)).is_false()
	assert_bool(studio.work.move([_sid("noticeboard")], Vector2i.RIGHT).ok).is_true()
	studio.work.tick(1.0)
	assert_bool(FileAccess.file_exists(path)).is_false()
	assert_bool(studio.work.move([_sid("noticeboard")], Vector2i.RIGHT).ok).is_true()
	studio.work.tick(1.1)
	assert_bool(FileAccess.file_exists(path)).is_false()
	studio.work.tick(1.0)
	assert_bool(FileAccess.file_exists(path)).is_true()
	assert_bool(studio.work.session().unsaved).is_false()
	assert_str(studio.work.session().saved_at).is_not_empty()
	assert_bool(studio.work.move([_sid("noticeboard")], Vector2i.RIGHT).ok).is_true()
	studio.set_editing(false)
	var reopened := StudioSession.open(TOWN, StudioMode.drafts_dir, StudioMode.content_dir)
	assert_array(reopened.doc().object_of_sid(_sid("noticeboard")).at).is_equal([6, 4])
	assert_that(studio.current_map().objects[0].at).is_equal(Vector2i(3, 4))


func test_place_list_eyedropper_and_select_tool_preserve_template_fields() -> void:
	await _open()
	var panel := studio.get_node("Chrome/PlacePanel") as StudioPlacePanel
	panel.search_for("barr")
	# The barrel first (by name, then id), and its remakes after it (barrel-2x1).
	assert_int(panel.shown.size()).is_greater_equal(1)
	assert_str(panel.shown[0]).contains("barrel   1 x 1")
	studio.start_place("barrel")
	_cursor(Vector2(6.5, 11.5) * OverworldScale.TILE)
	assert_bool(studio.arrange.fits).is_true()
	_click(Vector2(6.5, 11.5) * OverworldScale.TILE, true)
	_click(Vector2(6.5, 11.5) * OverworldScale.TILE, false)
	assert_bool(studio.arrange.placing.is_empty()).is_false()
	_key(KEY_S)
	assert_bool(studio.arrange.placing.is_empty()).is_true()
	_cursor(Vector2(3.5, 8.5) * OverworldScale.TILE)
	_key(KEY_E)
	assert_str(studio.arrange.placing.art).is_equal("barrel")
	_key(KEY_ESCAPE)
	assert_bool(studio.arrange.placing.is_empty()).is_true()
	assert_bool(studio.editing).is_true()


func test_fit_rejects_blocked_doors_and_collisions_between_pasted_items() -> void:
	await _open()
	var door := StudioFit.check(studio.current_map(), studio.pick(), [{"kind": "prop", "art": "barrel", "at": Vector2i(15, 4), "size": Vector2i.ONE}])
	assert_bool(door.ok).is_false()
	assert_str(door.reason).contains("door")
	var overlap := StudioFit.check(studio.current_map(), studio.pick(), [
		{"kind": "prop", "art": "barrel", "at": Vector2i(1, 12), "size": Vector2i.ONE},
		{"kind": "prop", "art": "crate", "at": Vector2i(1, 12), "size": Vector2i.ONE},
	])
	assert_bool(overlap.ok).is_false()
	assert_str(overlap.reason).contains("overlaps")


func test_play_draft_restores_original_state_and_keeps_real_save_bytes() -> void:
	await _open()
	assert_bool(studio.work.move([_sid("noticeboard")], Vector2i.RIGHT).ok).is_true()
	var state_before := screen.state.duplicate(true)
	var store := screen.get("_store") as OverworldStore
	var root_before := store.root
	var save_path := store.path_of(OverworldStore.playing())
	var save_before := FileAccess.get_file_as_bytes(save_path)
	var player_before := studio.player().cell
	studio.set_play_draft(true)
	assert_str(store.root).is_equal(StudioMode.playtest_dir)
	assert_bool(is_same(screen.state, state_before)).is_false()
	studio.set_editing(false)
	assert_that(studio.current_map().objects[0].at).is_equal(Vector2i(4, 4))
	screen.state.flags["draft-only"] = true
	screen.state.things["test-thing"] = {"fields": {"used": true}}
	screen.state.boots.blocks = []
	screen.state.cell = [6, 12]
	screen.call("_save")
	assert_bool(FileAccess.file_exists(store.path_of(OverworldStore.playing()))).is_true()
	assert_that(FileAccess.get_file_as_bytes(save_path)).is_equal(save_before)
	studio.set_play_draft(false)
	assert_dict(screen.state).is_equal(state_before)
	assert_str(store.root).is_equal(root_before)
	assert_that(studio.player().cell).is_equal(player_before)
	assert_that(studio.current_map().objects[0].at).is_equal(Vector2i(3, 4))
	assert_that(FileAccess.get_file_as_bytes(save_path)).is_equal(save_before)
	screen.queue_free()
	await _frames(4)
	var saved: Dictionary = JsJson.parse(FileAccess.get_file_as_string(save_path))
	assert_bool(saved.flags.has("draft-only")).is_false()
	assert_dict(saved.things).is_equal(state_before.things)
	assert_dict(saved.boots).is_equal(state_before.boots)


func test_exiting_draft_play_restores_the_original_state_before_exit_save() -> void:
	await _open()
	var store := screen.get("_store") as OverworldStore
	var save_path := store.path_of(OverworldStore.playing())
	var real := screen.state.duplicate(true)
	studio.set_play_draft(true)
	studio.set_editing(false)
	screen.state.flags["exit-draft-only"] = true
	screen.state.boots.blocks = []
	screen.queue_free()
	await _frames(5)
	var saved: Dictionary = JsJson.parse(FileAccess.get_file_as_string(save_path))
	assert_bool(saved.flags.has("exit-draft-only")).is_false()
	assert_dict(saved.boots).is_equal(real.boots)


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
