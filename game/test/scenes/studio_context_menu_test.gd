extends GdUnitTestSuite
## Placed-instance context actions use isolated content, drafts and saves. Right clicks reach the real world Control;
## menu actions and Delete confirmation retain their original map and session identities.

const TEST_ROOT := "user://studio_test/context"
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
	assert_bool(StudioFiles.write_content(_path(), JsoncWriter.map_text("// Context menu fixture\n", _fixture()))).is_true()
	# This fixture covers ordinary protected deletion; scheduled NPC ownership has its own acceptance cases.
	var schedules_path := StudioMode.content_dir.path_join("packs/core/overworld/schedules.jsonc")
	var schedules: Dictionary = Jsonc.parse(StudioFiles.read_text(schedules_path)).value
	schedules.erase("pip")
	assert_bool(StudioFiles.write_content(schedules_path, JsoncWriter.schedules_text("", schedules))).is_true()
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
	return {"id": TOWN, "name": "Context test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "prop", "art": "barrel", "at": [3, 4]},
		{"kind": "prop", "art": "crate", "at": [6, 4]},
		{"kind": "prop", "art": "bench", "at": [10, 4], "size": [2, 1]},
		{"kind": "prop", "art": "oak", "at": [15, 4]},
		{"kind": "person", "id": "pip", "at": [6, 9], "facing": "down"},
		{"kind": "prop", "art": "sign", "id": "named-instance", "at": [10, 9], "text": "A named thing"},
		{"kind": "building", "art": "cottage", "at": [15, 8], "size": [3, 3], "door": [1, 2]},
	]}


func _sid(art: String) -> int:
	for index: int in (studio.work.doc().data.objects as Array).size():
		var object := studio.work.raw(index)
		if String(object.get("art", "")) == art or String(object.get("id", "")) == art:
			return studio.work.sid_at(index)
	return -1


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


## Root-level mouse input is transformed by Godot into the catcher's local coordinates.
func _right_click(cell: Vector2) -> void:
	await _frames(2)
	var point := _cell_point(cell)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	get_tree().root.push_input(event, true)
	await get_tree().process_frame
	event.pressed = false
	get_tree().root.push_input(event, true)
	await get_tree().process_frame


## A cell's middle in the root viewport's canvas coordinates.
func _cell_point(cell: Vector2) -> Vector2:
	var view := studio.pixel_view()
	return view.get_global_transform() * view.to_screen((cell + Vector2(0.5, 0.5)) * OverworldScale.TILE)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	studio._unhandled_input(event)
	event.pressed = false
	studio._unhandled_input(event)


func _activate(action: int) -> void:
	studio.context_menu.id_pressed.emit(action)


func test_inspector_delete_is_hidden_without_selection_and_enabled_for_multiple() -> void:
	var button := studio.inspector().delete_button
	assert_bool(button.visible).is_false()
	assert_bool(button.disabled).is_true()
	var barrel := _sid("barrel")
	var crate := _sid("crate")
	studio.select_sids([barrel, crate])
	assert_bool(button.visible).is_true()
	assert_bool(button.disabled).is_false()
	var before := studio.work.doc().to_text()
	button.pressed.emit()
	assert_int(studio.work.index_of(barrel)).is_equal(-1)
	assert_int(studio.work.index_of(crate)).is_equal(-1)
	assert_bool(button.visible).is_false()
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_right_click_picks_unselected_instance_and_preserves_multi_selection() -> void:
	var barrel := _sid("barrel")
	var crate := _sid("crate")
	studio.select_sids([_sid("bench")])
	await _right_click(Vector2(3, 4))
	assert_bool(studio.context_menu.visible).is_true()
	assert_array(studio.selected_sids()).is_equal([barrel])
	studio.context_menu.dismiss()
	studio.select_sids([barrel, crate])
	await _right_click(Vector2(6, 4))
	assert_array(studio.selected_sids()).is_equal([barrel, crate])
	_activate(StudioContextMenu.Action.COPY)
	assert_int(StudioWork.clipboard.size()).is_equal(2)
	assert_bool(studio.context_menu.visible).is_false()


## The window stretches (content scale 0.88 here), so a menu placed through the viewport's screen transform opened
## away from the cursor. The embedded popup's corner is the clicked point itself.
func test_menu_opens_at_the_cursor_under_the_stretched_window() -> void:
	assert_float(get_tree().root.content_scale_factor).is_not_equal(1.0)
	await _right_click(Vector2(3, 4))
	var menu := studio.context_menu
	assert_bool(menu.visible).is_true()
	var expected := Vector2i(_cell_point(Vector2(3, 4)))
	assert_int(absi(menu.position.x - expected.x)).is_less_equal(1)
	assert_int(absi(menu.position.y - expected.y)).is_less_equal(1)


func test_copy_is_read_only_and_uses_targets_captured_before_selection_changes() -> void:
	var doc_before := studio.work.doc().to_text()
	var file_before := StudioFiles.read_text(_path())
	await _right_click(Vector2(3, 4))
	studio.select_sids([_sid("crate")])
	_activate(StudioContextMenu.Action.COPY)
	assert_int(StudioWork.clipboard.size()).is_equal(1)
	assert_str(StudioWork.clipboard[0].art).is_equal("barrel")
	assert_str(studio.work.doc().to_text()).is_equal(doc_before)
	assert_str(StudioFiles.read_text(_path())).is_equal(file_before)
	assert_bool(studio.work.session().history.can_undo()).is_false()


func test_native_popup_row_click_copies_captured_instance_and_closes_once() -> void:
	var before := studio.work.doc().to_text()
	await _right_click(Vector2(3, 4))
	var menu := studio.context_menu
	assert_bool(menu.hide_on_item_selection).is_false()
	studio.select_sids([_sid("crate")])
	var choices: Array[int] = []
	var closed: Array[bool] = []
	menu.id_pressed.connect(func(action: int) -> void: choices.append(action))
	menu.popup_hide.connect(func() -> void: closed.append(true))
	var panel := menu.get_theme_stylebox("panel")
	var row_height := menu.get_theme_font("font").get_height(menu.get_theme_font_size("font_size")) + menu.get_theme_constant("v_separation")
	var row := Vector2(menu.position) + Vector2(menu.size.x / 2.0, panel.get_content_margin(SIDE_TOP) + row_height / 2.0)
	var motion := InputEventMouseMotion.new()
	motion.position = row
	motion.global_position = row
	motion.relative = Vector2(20, 20)
	# LEARN: the popup is an embedded subwindow, so the root viewport's push_input forwards to it in the popup's own
	# coordinates. Emitting window_input only calls the signal's listeners; PopupMenu never sees that event.
	get_tree().root.push_input(motion, true)
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.position = row
	click.global_position = row
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	get_tree().root.push_input(click, true)
	await get_tree().process_frame
	click.pressed = false
	get_tree().root.push_input(click, true)
	await get_tree().process_frame
	assert_array(choices).is_equal([StudioContextMenu.Action.COPY])
	assert_int(closed.size()).is_equal(1)
	assert_bool(menu.visible).is_false()
	assert_int(StudioWork.clipboard.size()).is_equal(1)
	if not StudioWork.clipboard.is_empty():
		assert_str(StudioWork.clipboard[0].art).is_equal("barrel")
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_bool(menu.activate(StudioContextMenu.Action.DELETE)).is_false()


func test_duplicate_and_delete_use_captured_instances_and_undo_exactly() -> void:
	var before := studio.work.doc().to_text()
	var barrel := _sid("barrel")
	var crate := _sid("crate")
	await _right_click(Vector2(3, 4))
	studio.select_sids([crate])
	_activate(StudioContextMenu.Action.DUPLICATE)
	assert_int(studio.work.doc().data.objects.size()).is_equal(8)
	assert_str(studio.selected_object().art).is_equal("barrel")
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	await _right_click(Vector2(3, 4))
	studio.select_sids([crate])
	_activate(StudioContextMenu.Action.DELETE)
	assert_int(studio.work.index_of(barrel)).is_equal(-1)
	assert_int(studio.work.index_of(crate)).is_greater_equal(0)
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_str(StudioFiles.read_text(_path())).is_equal(before)


func test_protected_delete_confirmation_cancels_and_keeps_original_targets() -> void:
	var pip := _sid("pip")
	var named := _sid("named-instance")
	await _right_click(Vector2(6, 9))
	_activate(StudioContextMenu.Action.DELETE)
	var confirm := studio.get("_confirm") as ConfirmationDialog
	assert_bool(confirm.visible).is_true()
	confirm.canceled.emit()
	assert_int(studio.work.index_of(pip)).is_greater_equal(0)
	await _right_click(Vector2(10, 9))
	_activate(StudioContextMenu.Action.DELETE)
	assert_bool(confirm.visible).is_true()
	studio.select_sids([pip])
	confirm.confirmed.emit()
	assert_int(studio.work.index_of(named)).is_equal(-1)
	assert_int(studio.work.index_of(pip)).is_greater_equal(0)
	assert_bool(studio.work.undo()).is_true()
	assert_int(studio.work.index_of(named)).is_greater_equal(0)


func test_right_click_while_placing_cancels_ghost_without_adding_or_deleting() -> void:
	var before := studio.work.doc().to_text()
	studio.start_place("barrel")
	assert_bool(studio.arrange.placing.is_empty()).is_false()
	await _right_click(Vector2(6, 4))
	assert_bool(studio.arrange.placing.is_empty()).is_true()
	assert_array(studio.overlay().ghosts).is_empty()
	assert_bool(studio.context_menu.visible).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_bool(studio.work.session().history.can_undo()).is_false()


func test_popup_blocks_f1_delete_and_escape_only_dismisses_popup() -> void:
	var before := studio.work.doc().to_text()
	await _right_click(Vector2(3, 4))
	_key(KEY_F1)
	_key(KEY_DELETE)
	assert_bool(studio.editing).is_true()
	assert_bool(studio.context_menu.visible).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	_key(KEY_ESCAPE)
	assert_bool(studio.context_menu.visible).is_false()
	assert_bool(studio.editing).is_true()
	assert_array(studio.selected_sids()).is_equal([_sid("barrel")])
	assert_bool(studio.context_menu.activate(StudioContextMenu.Action.DELETE)).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_missing_instances_and_changed_history_epoch_refuse_old_actions() -> void:
	var barrel := _sid("barrel")
	await _right_click(Vector2(3, 4))
	assert_bool(studio.work.delete([barrel]).ok).is_true()
	var after_delete := studio.work.doc().to_text()
	assert_bool(studio.context_menu.activate(StudioContextMenu.Action.DUPLICATE)).is_false()
	assert_str(studio.work.doc().to_text()).is_equal(after_delete)
	assert_bool(studio.work.undo()).is_true()
	await _right_click(Vector2(3, 4))
	var session := studio.work.session()
	session.history = StudioHistory.new(session.doc().copy())
	assert_bool(studio.context_menu.activate(StudioContextMenu.Action.DELETE)).is_false()
	assert_int(studio.work.index_of(barrel)).is_greater_equal(0)


func test_changed_map_refuses_popup_and_pending_confirmation_targets() -> void:
	await _right_click(Vector2(3, 4))
	screen.state.map = "home"
	assert_bool(studio.context_menu.activate(StudioContextMenu.Action.DELETE)).is_false()
	screen.state.map = TOWN
	assert_int(studio.work.index_of(_sid("barrel"))).is_greater_equal(0)
	await _right_click(Vector2(6, 9))
	_activate(StudioContextMenu.Action.DELETE)
	var pip := _sid("pip")
	screen.state.map = "home"
	(studio.get("_confirm") as ConfirmationDialog).confirmed.emit()
	screen.state.map = TOWN
	assert_int(studio.work.index_of(pip)).is_greater_equal(0)


func test_flip_is_available_only_for_allowed_instances_and_menu_has_no_code() -> void:
	await _right_click(Vector2(3, 4))
	var menu := studio.context_menu
	assert_int(menu.get_item_index(StudioContextMenu.Action.FLIP)).is_greater_equal(0)
	var before := studio.work.doc().to_text()
	_activate(StudioContextMenu.Action.FLIP)
	assert_bool(studio.work.doc().object_of_sid(_sid("barrel")).flip).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)
	await _right_click(Vector2(6, 9))
	assert_int(menu.get_item_index(StudioContextMenu.Action.FLIP)).is_equal(-1)
	assert_bool(menu.is_item_disabled(menu.get_item_index(StudioContextMenu.Action.COPY))).is_true()
	for index: int in menu.item_count:
		assert_str(menu.get_item_text(index).to_lower()).not_contains("code")
		assert_bool(menu.get_item_submenu(index).is_empty()).is_true()


func test_empty_ground_paste_uses_captured_cell_and_clipboard_then_undo() -> void:
	studio.work.copy([_sid("barrel")])
	var before := studio.work.doc().to_text()
	await _right_click(Vector2(2, 11))
	assert_bool(studio.context_menu.visible).is_true()
	assert_int(studio.context_menu.get_item_index(StudioContextMenu.Action.PASTE)).is_greater_equal(0)
	studio.work.copy([_sid("crate")])
	_activate(StudioContextMenu.Action.PASTE)
	assert_str(studio.selected_object().art).is_equal("barrel")
	assert_that(studio.selected_object().at).is_equal(Vector2i(2, 11))
	assert_str(StudioWork.clipboard[0].art).is_equal("crate")
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


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
