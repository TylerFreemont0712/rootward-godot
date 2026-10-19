extends GdUnitTestSuite
## Real build-menu edits use isolated content, drafts and saves. The generation bridge is queued but never run;
## these tests cannot write production specs or start a GPU service.

const TEST_ROOT := "user://studio_test/asset_editing"
const TOWN := "lanternroot"
const ROOM := "asset-editing-room"
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
var _old_stand_ins: Dictionary = {}
var _old_recent: Array[String] = []


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
	_old_clipboard = StudioWork.clipboard
	_old_stand_ins = OverworldArt.stand_ins.duplicate(true)
	_old_recent = StudioPlacePanel.recent.duplicate()
	StudioWork.clipboard = []
	StudioPlacePanel.recent = []
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
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Asset editing fixture\n", _fixture()))).is_true()
	var room := StudioDoors.room_template(ROOM, "Asset editing room", {"map": TOWN, "at": [4, 6], "facing": "down"})
	assert_bool(StudioFiles.write_content(_path(ROOM), JsoncWriter.map_text("// Asset editing room\n", room))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var map: Dictionary = OverworldScreen.catalog_of().maps[TOWN]
	var state := OverworldState.fresh(TOWN, map.start, "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Asset editor"
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
	OverworldArt.stand_ins = _old_stand_ins
	StudioPlacePanel.recent = _old_recent
	StudioAssets.reload()
	StudioThumbs.clear()
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in 14:
		rows.append("....................")
	return {"id": TOWN, "name": "Asset editing test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "building", "art": "inn", "at": [2, 2], "size": [4, 4], "door": [2, 3], "solid_rows": [1, 2, 3], "name": "The Fox", "text": "Welcome!", "to": {"map": ROOM, "at": [5, 6], "facing": "up"}},
		{"kind": "prop", "art": "barrel", "at": [10, 3]},
		{"kind": "prop", "art": "crate", "at": [12, 3]},
		{"kind": "prop", "art": "gate", "at": [14, 4], "solid": false},
	]}


func _sid(art: String) -> int:
	for index: int in (studio.work.doc().data.objects as Array).size():
		if String(studio.work.raw(index).get("art", "")) == art:
			return studio.work.sid_at(index)
	return -1


func _raw(art: String) -> Dictionary:
	return studio.work.raw(studio.work.index_of(_sid(art)))


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _sprites_of(index: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for node: Node2D in studio.map_view().nodes_of(index):
		for child: Node in node.get_children():
			if child is Sprite2D:
				out.append(child as Sprite2D)
	return out


func _return_cell() -> Vector2i:
	var room: Dictionary = studio.catalog().maps[ROOM]
	var target: Dictionary = room.warps[Vector2i(5, 7)]
	return OverworldMap.cell_of(target.at)


func _assert_ghost_matches_picture(art: String) -> void:
	var index := studio.work.index_of(_sid(art))
	var built := studio.object_at(index)
	var parts := StudioGhost.parts(built)
	assert_int(parts.size()).is_equal(1)
	assert_that(parts[0].rect).is_equal(studio.pick().picture_rect(index))
	assert_that(StudioPick.footprint(built)).is_equal(Rect2i(built.at, built.size))
	assert_bool(index in studio.pick().objects_at_cell(built.at + built.size - Vector2i.ONE)).is_true()


func test_adopted_building_resizes_immediately_with_collision_render_and_one_step_undo() -> void:
	var sid := _sid("inn")
	var before := studio.work.doc().to_text()
	var file_before := StudioFiles.read_text(_path(TOWN))
	var index := studio.work.index_of(sid)
	var scale_before := _sprites_of(index)[0].scale
	var rect_before := studio.pick().picture_rect(index)
	var result := studio.work.resize_object(sid, Vector2i(6, 5))
	assert_bool(result.ok).is_true()
	var object := _raw("inn")
	assert_str(object.art).is_equal("inn")
	assert_array(object.size).is_equal([6, 5])
	assert_array(object.art_size).is_equal([4, 4])
	assert_array(object.door).is_equal([3, 4])
	assert_array(object.solid_rows).is_equal([1, 2, 3, 4])
	assert_str(object.name).is_equal("The Fox")
	assert_str(object.text).is_equal("Welcome!")
	assert_str(object.to.map).is_equal(ROOM)
	var map := studio.current_map()
	assert_bool(map.solid.has(Vector2i(2, 2))).is_false()
	assert_bool(map.solid.has(Vector2i(2, 3))).is_true()
	assert_bool(map.solid.has(Vector2i(5, 6))).is_false()
	assert_bool(map.warps.has(Vector2i(5, 6))).is_true()
	var sprite := _sprites_of(index)[0]
	assert_float(sprite.scale.x / scale_before.x).is_equal_approx(1.5, 0.001)
	assert_float(sprite.scale.y / scale_before.y).is_equal_approx(1.25, 0.001)
	assert_float(studio.pick().picture_rect(index).size.x / rect_before.size.x).is_equal_approx(1.5, 0.001)
	_assert_ghost_matches_picture("inn")
	assert_int(studio.work.session().history.labels().size()).is_equal(1)
	assert_array(studio.remaking.waiting()).is_empty()
	assert_str(StudioFiles.read_text(_path(TOWN))).is_equal(file_before)
	var edited := studio.work.doc().to_text()
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_that(_sprites_of(index)[0].scale).is_equal(scale_before)
	assert_bool(studio.work.redo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(edited)
	_assert_ghost_matches_picture("inn")


func test_shrinking_building_and_undo_redo_move_its_linked_interior_return_warp() -> void:
	assert_that(_return_cell()).is_equal(Vector2i(4, 6))
	assert_bool(studio.work.resize_object(_sid("inn"), Vector2i(2, 2)).ok).is_true()
	assert_array(_raw("inn").door).is_equal([1, 1])
	assert_array(_raw("inn").solid_rows).is_equal([0, 1])
	assert_that(_return_cell()).is_equal(Vector2i(3, 4))
	assert_str((studio.catalog().maps[ROOM].warps[Vector2i(5, 7)] as Dictionary).map).is_equal(TOWN)
	assert_bool(studio.work.undo()).is_true()
	assert_that(_return_cell()).is_equal(Vector2i(4, 6))
	assert_bool(studio.work.redo()).is_true()
	assert_that(_return_cell()).is_equal(Vector2i(3, 4))
	assert_str(StudioFiles.read_text(_path(ROOM))).contains('"at": [4, 6]')


func test_rejected_sizes_stale_target_and_noop_do_not_change_the_draft_or_history() -> void:
	var before := studio.work.doc().to_text()
	for size: Vector2i in [Vector2i(3, 1), Vector2i(11, 1), Vector2i(0, 1), Vector2i.ONE]:
		var result := studio.work.resize_object(_sid("barrel"), size)
		assert_bool(result.ok).is_false()
		assert_str(result.reason).is_not_empty()
		assert_str(studio.work.doc().to_text()).is_equal(before)
		assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_bool(studio.work.resize_object(-999, Vector2i(2, 2)).ok).is_false()
	assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_bool(studio.work.resize_object(_sid("barrel"), Vector2i(3, 1), true).ok).is_true()
	assert_array(_raw("barrel").size).is_equal([3, 1])
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_manual_door_edit_survives_later_sizes_reset_and_undo_with_return_links() -> void:
	var sid := _sid("inn")
	var original_rows: Array = _raw("inn").solid_rows.duplicate()
	assert_bool(studio.work.resize_object(sid, Vector2i(6, 6)).ok).is_true()
	assert_bool(studio.work.slide_door(sid, Vector2i(0, 5))).is_true()
	assert_array(_raw("inn").art_shape.door).is_equal([0, 5])
	assert_array(_raw("inn").art_shape.door_size).is_equal([6, 6])
	assert_that(_return_cell()).is_equal(Vector2i(2, 8))
	var edited := studio.work.doc().to_text()
	assert_bool(studio.work.resize_object(sid, Vector2i(5, 5)).ok).is_true()
	assert_array(_raw("inn").door).is_equal([0, 4])
	assert_that(_return_cell()).is_equal(Vector2i(2, 7))
	assert_bool(studio.work.resize_object(sid, Vector2i(4, 4)).ok).is_true()
	assert_array(_raw("inn").door).is_equal([0, 3])
	assert_array(_raw("inn").solid_rows).is_equal(original_rows)
	assert_bool(_raw("inn").has("art_shape")).is_false()
	assert_bool(_raw("inn").has("art_size")).is_false()
	assert_that(_return_cell()).is_equal(Vector2i(2, 6))
	assert_bool(studio.work.undo()).is_true()
	assert_array(_raw("inn").door).is_equal([0, 4])
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(edited)
	assert_that(_return_cell()).is_equal(Vector2i(2, 8))
	assert_bool(studio.work.undo()).is_true()
	assert_array(_raw("inn").door).is_equal([3, 5])
	assert_bool(_raw("inn").art_shape.has("door_size")).is_false()
	assert_that(_return_cell()).is_equal(Vector2i(5, 8))


func test_inspector_width_depth_apply_and_reset_edit_the_selected_instance() -> void:
	studio.select_sids([_sid("inn")])
	var inspector := studio.inspector()
	var width := inspector.find_child("ObjectWidth", true, false) as SpinBox
	var depth := inspector.find_child("ObjectDepth", true, false) as SpinBox
	var apply := inspector.find_child("ApplyObjectSize", true, false) as Button
	var reset := inspector.find_child("ResetObjectSize", true, false) as Button
	assert_bool(width.is_visible_in_tree()).is_true()
	assert_float(width.value).is_equal(4.0)
	assert_float(depth.value).is_equal(4.0)
	width.value = 5
	depth.value = 3
	apply.pressed.emit()
	assert_array(_raw("inn").size).is_equal([5, 3])
	assert_int(studio.work.session().history.labels().size()).is_equal(1)
	assert_array(_raw("inn").art_size).is_equal([4, 4])
	reset.pressed.emit()
	assert_array(_raw("inn").size).is_equal([4, 4])
	assert_bool(_raw("inn").has("art_size")).is_false()
	assert_bool(_raw("inn").has("art_shape")).is_false()
	assert_bool(studio.work.undo()).is_true()
	assert_array(_raw("inn").size).is_equal([5, 3])


func test_resized_object_draft_reloads_with_its_picture_and_shape_baseline() -> void:
	assert_bool(studio.work.resize_object(_sid("inn"), Vector2i(5, 3)).ok).is_true()
	assert_bool(studio.work.flush()).is_true()
	var reopened := StudioSession.open(TOWN, StudioMode.drafts_dir, StudioMode.content_dir)
	assert_object(reopened).is_not_null()
	assert_str(reopened.doc().to_text()).is_equal(studio.work.doc().to_text())
	var built := StudioSession.build_data(reopened.doc().data, _path(TOWN), studio.catalog().terrain)
	assert_bool(built.ok).is_true()
	assert_array(built.errors).is_empty()
	assert_array(built.map.objects[0].art_size).is_equal([4, 4])
	assert_dict(built.map.objects[0].art_shape).is_equal({"door": [2, 3], "solid_rows": [1, 2, 3]})


func test_swapping_a_resized_object_to_a_native_variant_clears_the_scale_override() -> void:
	var sid := _sid("barrel")
	assert_bool(studio.work.resize_object(sid, Vector2i(2, 2)).ok).is_true()
	var before := studio.work.doc().to_text()
	assert_int(studio.work.swap_variant([sid], 1)).is_equal(1)
	var object := studio.work.raw(studio.work.index_of(sid))
	assert_str(object.art).is_not_equal("barrel")
	assert_bool(object.has("art_size")).is_false()
	assert_bool(object.has("art_shape")).is_false()
	assert_that(_sprites_of(studio.work.index_of(sid))[0].scale).is_equal(Vector2.ONE)
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_animated_gate_resize_preserves_its_sheet_and_matches_pick_and_ghost() -> void:
	var index := studio.work.index_of(_sid("gate"))
	var before := _sprites_of(index)[0]
	var texture := before.texture
	var frame_width := before.region_rect.size.x
	assert_bool(studio.work.resize_object(_sid("gate"), Vector2i(3, 2)).ok).is_true()
	var drawn := _sprites_of(index)
	assert_int(drawn.size()).is_equal(1)
	assert_bool(is_same(drawn[0].texture, texture)).is_true()
	assert_bool(drawn[0].region_enabled).is_true()
	assert_float(drawn[0].region_rect.size.x).is_equal(frame_width)
	assert_that(drawn[0].scale).is_equal(Vector2(3, 2))
	assert_bool(_raw("gate").solid).is_false()
	_assert_ghost_matches_picture("gate")
	var gate := studio.map_view().nodes_of(index)[0] as TownGate
	assert_that(gate.footprint).is_equal(Rect2i(14, 4, 3, 2))
	gate.update_occupancy({Vector2i(16, 5): true})
	assert_bool(gate.opened).is_true()


func test_catalog_right_click_flags_once_and_updates_filter_persists_across_maps() -> void:
	var reviews := studio.asset_reviews
	assert_str(reviews.path).is_equal(_root.path_join("asset_updates.json"))
	var panel := studio.place_panel()
	panel.set_filters({"view": "all", "text": "inn"})
	var card := panel.find_child("Card_inn", true, false) as StudioCatalogCard
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = Vector2(40, 40)
	card.gui_input.emit(click)
	assert_bool(reviews.menu.visible).is_true()
	assert_bool(studio.arrange.placing.is_empty()).is_true()
	reviews.menu.id_pressed.emit(StudioAssetReviews.Action.FLAG)
	assert_array(reviews.pending()).is_equal(["inn"])
	assert_bool(reviews.flag("inn")).is_true()
	assert_int(reviews.records.size()).is_equal(1)
	assert_bool(studio.work.session().history.can_undo()).is_false()
	panel.set_filters({"view": "updates", "text": ""})
	assert_array(panel.matching_ids()).is_equal(["inn"])
	assert_str((card.find_child("Badge", true, false) as Label).text).is_equal("Update")
	assert_bool(studio.go_to_map(ROOM)).is_true()
	assert_array(reviews.pending()).is_equal(["inn"])
	reviews.records = {}
	reviews.load_reviews()
	assert_array(reviews.pending()).is_equal(["inn"])
	assert_bool(reviews.resolve("inn")).is_true()
	assert_array(reviews.pending()).is_empty()
	assert_array(panel.matching_ids()).is_empty()
	reviews.records = {}
	reviews.load_reviews()
	assert_str(reviews.records.inn.state).is_equal("reviewed")


func test_imported_art_retains_its_saved_brief_and_refuses_fake_regeneration() -> void:
	var reviews := studio.asset_reviews
	assert_bool(reviews.flag("inn")).is_true()
	reviews.open_reviews("inn")
	var notes := reviews.find_child("ReviewNotes", true, false) as TextEdit
	var prompt := reviews.find_child("ReplacementPrompt", true, false) as LineEdit
	notes.text = "Roof looks too modern; use timber and warm plaster."
	prompt.text = "a cozy timber inn with a warm tiled roof"
	(reviews.find_child("SaveReview", true, false) as Button).pressed.emit()
	assert_str(reviews.records.inn.notes).is_equal(notes.text)
	assert_str(reviews.records.inn.prompt).is_equal(prompt.text)
	assert_bool((reviews.find_child("QueueReplacement", true, false) as Button).disabled).is_true()
	var result := reviews.queue_replacement("inn", prompt.text)
	assert_bool(result.ok).is_false()
	assert_str(result.error).is_not_empty()
	assert_array(reviews.pending()).is_equal(["inn"])
	assert_array(studio.remaking.waiting()).is_empty()
	assert_bool(studio.remaking.remakes.running).is_false()
	reviews.dismiss()
	reviews.records = {}
	reviews.load_reviews()
	assert_str(reviews.records.inn.notes).contains("timber")
	assert_str(reviews.records.inn.prompt).is_equal(prompt.text)


func test_review_window_escape_closes_from_real_window_input_without_town_edits() -> void:
	var reviews := studio.asset_reviews
	assert_bool(reviews.flag("inn")).is_true()
	var before := studio.work.doc().to_text()
	reviews.open_reviews("inn")
	await _frames(2)
	var notes := reviews.find_child("ReviewNotes", true, false) as TextEdit
	notes.grab_focus()
	notes.text = "Unsaved note while inspecting the roof."
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	# The root forwards native input to its embedded Window. Calling that Window's Viewport.push_input directly
	# skips its window_input signal and would not exercise the input path a keyboard uses.
	get_tree().root.push_input(escape, true)
	await _frames(1)
	assert_bool(reviews.dialog.visible).is_false()
	assert_bool(reviews.modal_open()).is_false()
	assert_bool(studio.editing).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_array(reviews.pending()).is_equal(["inn"])


func test_prompt_replacement_queues_a_new_variant_without_touching_source_or_placed_art() -> void:
	var reviews := studio.asset_reviews
	var source_path := StudioFiles.world_objects_dir().path_join("barrel.jsonc")
	var source_before := StudioFiles.read_text(source_path)
	var map_before := studio.work.doc().to_text()
	var prompt := 'an oak barrel with brass hoops and a painted "fox" emblem $(touch ignored)'
	assert_bool(reviews.flag("barrel")).is_true()
	var result := reviews.queue_replacement("barrel", prompt)
	assert_bool(result.ok).is_true()
	var id := String(result.id)
	assert_str(id).starts_with("barrel-update-")
	assert_array(studio.remaking.waiting()).is_equal([id])
	var queued: Dictionary = studio.remaking.remakes.queue[0]
	assert_str(queued.source).is_equal("barrel")
	var parsed := Jsonc.parse(String(queued.spec))
	assert_bool(parsed.ok).is_true()
	assert_str(parsed.value.id).is_equal(id)
	assert_str(parsed.value.what).is_equal(prompt)
	assert_array(parsed.value.parts).is_equal(StudioRemaking.spec_of("barrel").parts)
	assert_array(studio.remaking.catalog.entry(id).size).is_equal([1, 1])
	assert_str(String(studio.remaking.catalog.entry(id).family)).is_equal("barrel")
	assert_str(reviews.records.barrel.replacement).is_equal(id)
	assert_str(StudioFiles.read_text(source_path)).is_equal(source_before)
	assert_bool(FileAccess.file_exists(StudioFiles.world_objects_dir().path_join(id + ".jsonc"))).is_false()
	assert_bool(studio.remaking.remakes.running).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(map_before)
	assert_bool(studio.work.session().history.can_undo()).is_false()
	assert_array(reviews.pending()).is_equal(["barrel"])
	assert_bool(reviews.queue_replacement("barrel", prompt).ok).is_true()
	assert_int(studio.remaking.remakes.queue.size()).is_equal(1)


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
