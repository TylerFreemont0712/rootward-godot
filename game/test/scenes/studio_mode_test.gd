extends GdUnitTestSuite
## Lanternroot Studio's shell (ADR-0066, phase S0): F2 edits and F1 plays, the keys of the game do not reach the town
## while editing, the mouse maps to the world and back, and a click picks the front-most thing. Driven as the overworld
## flow test drives the town: real key events to the root of the tree, the Studio forced on for the run.

const ROOT := "user://studio_test/mode"
const TOWN := "lanternroot"
const LOOK := {
	"outfit": "outfit/tunic",
	"hair": "hair/short",
	"colours":
	{
		"skin": "skin_peach",
		"hair": "hair_brown",
		"main": "cloth_teal",
		"second": "cloth_cream",
		"accent": "cloth_orange"
	},
}
## Every beat has played: Hotaru has said her piece, so nothing opens over the town.
const ALL_BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}

var screen: OverworldScreen
var studio: StudioMode
var small: TownMapView
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_catalog: Dictionary = {}
var _old_studio_env := ""
var _old_window_size := Vector2i.ZERO


func before_test() -> void:
	_root = ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_catalog = OverworldScreen._catalog_cache
	_old_window_size = get_window().size
	_old_studio_env = OS.get_environment("ROOTWARD_STUDIO")
	StudioMode.drafts_dir = _root.path_join("drafts")
	StudioMode.playtest_dir = _root.path_join("playtest")
	StudioMode.content_dir = _root.path_join("content")
	_copy_tree("res://content/packs/core/overworld", StudioMode.content_dir.path_join("packs/core/overworld"))
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	OS.set_environment("ROOTWARD_STUDIO", "1")
	Game.reset(_root.path_join("saves"))
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()


func after_test() -> void:
	if _old_window_size.x > 0 and _old_window_size.y > 0:
		get_window().size = _old_window_size
	if is_instance_valid(screen):
		screen.queue_free()
	if is_instance_valid(small):
		small.queue_free()
	Sound.silence()
	await _frames(6)
	Background.finish_all()
	OverworldStore.for_profile().delete_state()
	Game.reset()
	StudioMode.drafts_dir = _old_drafts
	StudioMode.playtest_dir = _old_playtest
	StudioMode.content_dir = _old_content
	OverworldScreen._catalog_cache = _old_catalog
	OS.set_environment("ROOTWARD_STUDIO", _old_studio_env)
	_remove_tree(_root)


## The overworld on Lanternroot, with the Studio mounted.
func _open() -> void:
	var start := OverworldMap.cell_of(OverworldScreen.catalog_of().maps[TOWN].start)
	var state := OverworldState.fresh(TOWN, start, "down", BootsCode.PYTHON)
	state.look = LOOK.duplicate(true)
	state.name = "Tinker"
	state.flags = ALL_BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(3)
	studio = screen.get("_studio") as StudioMode
	assert_object(studio).override_failure_message("the Studio was not mounted").is_not_null()


func _view() -> PixelView:
	return screen.get("_view") as PixelView


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	get_tree().root.push_input(event)


func _tap(code: Key) -> void:
	_key(code, true)
	await get_tree().process_frame
	_key(code, false)
	await get_tree().process_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


## A click on the world Control at a point of the town, as the mouse would make it.
func _click_world(point: Vector2) -> void:
	var catcher := studio.get_node("Chrome/World") as Control
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var on_view := _view().to_screen(point)
	event.position = catcher.get_global_transform().affine_inverse() * (_view().get_global_transform() * on_view)
	event.global_position = _view().get_global_transform() * on_view
	get_tree().root.push_input(event, true)
	await get_tree().process_frame
	var up := event.duplicate() as InputEventMouseButton
	up.pressed = false
	get_tree().root.push_input(up, true)
	await get_tree().process_frame


func _click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	event.global_position = point
	get_tree().root.push_input(event, true)
	await get_tree().process_frame
	var up := event.duplicate() as InputEventMouseButton
	up.pressed = false
	get_tree().root.push_input(up, true)
	await get_tree().process_frame


func test_the_studio_is_not_there_without_the_toggle() -> void:
	OS.unset_environment("ROOTWARD_STUDIO")
	var was := Settings.studio
	Settings.studio = false
	assert_bool(StudioMode.available()).is_false()
	Settings.studio = was


func test_f2_enters_edit_and_f1_leaves_with_the_play_view_back() -> void:
	await _open()
	var camera := screen.get("_camera") as Camera2D
	var zoom_before := camera.zoom
	var position_before := camera.position
	var size_before := _view().size
	assert_bool(studio.editing).is_false()
	await _tap(KEY_F2)
	await _frames(3)
	assert_bool(studio.editing).override_failure_message("F2 should edit").is_true()
	assert_bool(studio.get_node("Chrome").visible).is_true()
	assert_bool(studio.overlay().visible).is_true()
	assert_bool(studio.studio_camera().overview).override_failure_message("F2 should fit the whole map").is_true()
	_assert_map_fits()
	(
		assert_bool(_view().size.x < size_before.x and _view().size.y < size_before.y)
		. override_failure_message("the town should shrink to the space between the panels")
		. is_true()
	)
	# O restores the play framing, then fits the map again; leaving gives the play camera back whole.
	await _tap(KEY_O)
	assert_bool(studio.studio_camera().overview).is_false()
	await _tap(KEY_O)
	assert_bool(studio.studio_camera().overview).is_true()
	await _tap(KEY_F1)
	await _frames(3)
	assert_bool(studio.editing).override_failure_message("F1 should play").is_false()
	assert_bool(studio.get_node("Chrome").visible).is_false()
	assert_bool(studio.overlay().visible).is_false()
	assert_that(_view().size).is_equal(size_before)
	assert_that(camera.zoom).is_equal(zoom_before)
	assert_that(camera.position).is_equal(position_before)


func test_navigating_to_another_map_fits_its_full_editable_area() -> void:
	await _open()
	await _tap(KEY_F2)
	await _frames(3)
	assert_bool(studio.go_to_map("home")).is_true()
	await _frames(3)
	assert_bool(studio.studio_camera().overview).is_true()
	_assert_map_fits()
	assert_bool(studio.go_to_map(TOWN)).is_true()
	await _frames(3)
	assert_bool(studio.studio_camera().overview).is_true()
	_assert_map_fits()


func _assert_map_fits() -> void:
	var world := Vector2(OverworldMap.size_of(studio.current_map()) * OverworldScale.TILE)
	var visible := Vector2(_view().viewport.size) / (screen.get("_camera") as Camera2D).zoom
	var required := world + Vector2.ONE * StudioCamera.OVERVIEW_MARGIN * 2.0
	assert_bool(visible.x + 1.0 >= required.x and visible.y + 1.0 >= required.y).override_failure_message(
		"the full map with its margin should fit: visible %s, required %s" % [visible, required]
	).is_true()


func test_workspace_routing_keeps_one_shelf_and_reflows_the_world_on_resize() -> void:
	await _open()
	await _tap(KEY_F2)
	await _frames(2)
	var place := studio.place_panel()
	var land := studio._land_panel as StudioLandPanel
	var people := studio.people_panel()
	var inspector := studio.inspector()
	var quest := studio.quest_panel
	var lower: Array[Control] = [place, land, people, studio.build_panel()]
	for tab: String in ["land", "people", "build", "quests", "objects", "people", "land", "build", "objects"]:
		studio.set_tab(tab)
		await _frames(2)
		var visible_shelves := 0
		for shelf: Control in lower:
			if shelf.visible:
				visible_shelves += 1
		assert_int(visible_shelves).override_failure_message("exactly the selected lower shelf should show for %s" % tab).is_equal(
			0 if tab == "quests" or (tab == "objects" and not studio.place_list_shown()) else 1
		)
		if tab == "quests":
			assert_bool(quest.visible).override_failure_message("Quests owns its overlay").is_true()
			assert_bool(inspector.visible).override_failure_message("Quests hides the ordinary inspector").is_false()
		else:
			assert_bool(quest.visible).override_failure_message("other tabs hide the Quests overlay").is_false()
			assert_bool(inspector.visible).override_failure_message("the ordinary inspector follows the workspace descriptor").is_true()
		assert_int(studio._bottom()).is_equal(
			StudioStyle.BOTTOM + (StudioStyle.PLACE if tab in ["land", "people", "build"] or (tab == "objects" and studio.place_list_shown()) else 0)
		)
	studio.set_tab("build")
	assert_str(studio.tab).is_equal("build")
	assert_bool(studio.build_panel().visible).is_true()
	# The user's Objects shelf preference survives every other tab, including a second route through Quests.
	studio.set_place_list(false)
	for tab: String in ["land", "people", "build", "quests", "objects"]:
		studio.set_tab(tab)
		await _frames(2)
		assert_bool(place.visible).override_failure_message("Objects shelf preference survives %s" % tab).is_false()
		assert_int(studio._bottom()).is_equal(
			StudioStyle.BOTTOM + (StudioStyle.PLACE if tab in ["land", "people", "build"] else 0)
		)
	# A smaller desktop leaves a positive world viewport and keeps both the shelf and catcher docked to the same edge.
	var window := get_window()
	window.size = Vector2i(1280, 720)
	await _frames(4)
	studio.set_tab("people")
	await _frames(2)
	assert_bool(_view().size.x > 0 and _view().size.y > 0).override_failure_message("world remains visible at a smaller window size").is_true()
	assert_int(int(studio._catcher.offset_bottom)).is_equal(-studio._bottom())
	assert_int(int(studio.people_panel().offset_bottom)).is_equal(-StudioStyle.BOTTOM)
	assert_bool(
		studio.people_panel().get_global_rect().end.y
		<= studio.get_global_rect().end.y - StudioStyle.BOTTOM + 2
	).override_failure_message("the lower shelf stays above the status bar after resizing").is_true()


func test_clicking_the_hidden_objects_shelf_cannot_start_or_place_an_asset() -> void:
	await _open()
	await _tap(KEY_F2)
	await _frames(3)
	var place := studio.place_panel()
	var card := place.find_child("Card_barrel", true, false) as Control
	assert_object(card).override_failure_message("the Objects shelf has a barrel card for the click probe").is_not_null()
	var click_point := card.get_global_transform() * (card.size / 2.0)
	studio.set_tab("people")
	studio.people_panel().choose_view("start")
	await _frames(3)
	assert_bool(place.visible).is_false()
	assert_bool(studio.people_panel().visible).is_true()
	var before := studio.work.doc().data.duplicate(true)
	await _click_at(click_point)
	assert_dict(studio.work.doc().data).override_failure_message("a click at a hidden card cannot change the map").is_equal(before)
	assert_dict(studio.arrange.placing).override_failure_message("a hidden card cannot start placement").is_empty()


func test_tab_switch_cancels_land_stroke_and_placement_without_committing() -> void:
	await _open()
	await _tap(KEY_F2)
	var before := studio.work.doc().data.duplicate(true)
	studio.set_tab("land")
	studio.set_ground("cobble")
	studio.land.press(Vector2i(4, 4), false)
	assert_str(studio.land.mode).is_equal("brush")
	assert_dict(studio.work.doc().data).is_equal(before)
	studio.set_tab("people")
	assert_str(studio.land.mode).override_failure_message("leaving Land restores an unfinished brush stroke").is_empty()
	assert_dict(studio.work.doc().data).override_failure_message("tab switching does not commit a partial land stroke").is_equal(before)
	studio.set_tab("objects")
	studio.start_place("barrel")
	assert_bool(studio.arrange.placing.is_empty()).is_false()
	studio.set_tab("people")
	assert_dict(studio.arrange.placing).override_failure_message("leaving Objects cancels an unfinished placement").is_empty()
	assert_dict(studio.work.doc().data).override_failure_message("tab switching does not place the pending asset").is_equal(before)


func test_escape_releases_search_focus_before_cancelling_the_active_placement() -> void:
	await _open()
	await _tap(KEY_F2)
	studio.set_tab("people")
	var inn := -1
	for object: Dictionary in studio.current_map().objects:
		if String(object.get("art", "")) == "inn":
			inn = int(object.index)
	assert_int(inn).is_greater_equal(0)
	studio.select(inn)
	studio.start_place("barrel")
	var search := studio.people_panel().find_child("PeopleSearch", true, false) as LineEdit
	search.grab_focus()
	await _frames(1)
	assert_bool(search.has_focus()).is_true()
	var before := studio.work.doc().data.duplicate(true)
	await _tap(KEY_DELETE)
	await _tap(KEY_R)
	await _tap(KEY_UP)
	assert_dict(studio.work.doc().data).override_failure_message("text focus must keep editing shortcuts out of the map").is_equal(before)
	assert_bool(studio.arrange.placing.is_empty()).is_false()
	await _tap(KEY_ESCAPE)
	assert_bool(search.has_focus()).override_failure_message("the first Escape releases text focus").is_false()
	assert_bool(studio.arrange.placing.is_empty()).override_failure_message("the first Escape must not also cancel placement").is_false()
	await _tap(KEY_ESCAPE)
	assert_dict(studio.arrange.placing).override_failure_message("the next Escape cancels placement").is_empty()
	assert_dict(studio.work.doc().data).is_equal(before)
	assert_array(studio.selected_sids()).is_equal([studio.work.sid_at(inn)])


func test_tab_switch_cancels_link_preview_and_returns_to_its_source_map() -> void:
	await _open()
	await _tap(KEY_F2)
	var inn_sid := -1
	for object: Dictionary in studio.current_map().objects:
		if String(object.get("art", "")) == "inn":
			inn_sid = studio.work.sid_at(int(object.index))
	assert_bool(studio.link.begin(inn_sid)).is_true()
	assert_bool(studio.go_to_map("home")).is_true()
	await _frames(2)
	assert_bool(studio.link.active).is_true()
	assert_str(String(studio.current_map().id)).is_equal("home")
	var source_before := studio.work.map_data("lanternroot").duplicate(true)
	studio.set_tab("people")
	await _frames(3)
	assert_bool(studio.link.active).override_failure_message("tab changes cancel the pending link").is_false()
	assert_str(String(studio.current_map().id)).override_failure_message("link cancellation returns to its source map").is_equal("lanternroot")
	assert_array(studio.selected_sids()).is_equal([inn_sid])
	assert_dict(studio.work.map_data("lanternroot")).override_failure_message("cancelling a link changes no source data").is_equal(source_before)


func test_keys_in_edit_do_not_reach_the_game() -> void:
	await _open()
	var boots := screen.get("_boots") as Control
	var talk := screen.get("_talk") as DialogueBox
	var player := screen.get("_player") as Walker
	await _tap(KEY_F2)
	await _frames(2)
	var state_before := (screen.state as Dictionary).duplicate(true)
	var cell_before := player.cell
	for code: Key in [
		KEY_UP,
		KEY_DOWN,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_W,
		KEY_A,
		KEY_S,
		KEY_D,
		KEY_B,
		KEY_SPACE,
		KEY_X,
		KEY_ENTER,
		KEY_Z,
		KEY_E
	]:
		await _tap(code)
	await _frames(10)
	assert_bool(studio.editing).is_true()
	assert_that(player.cell).override_failure_message("the player must not walk while editing").is_equal(cell_before)
	assert_bool(player.moving).is_false()
	assert_bool(boots.visible).override_failure_message("B must not open the boots in Edit").is_false()
	assert_bool(talk.busy).override_failure_message("Space must not open a talk in Edit").is_false()
	(
		assert_bool((screen.get("_things") as ThingTown).busy())
		. override_failure_message("X must not edit a thing")
		. is_false()
	)
	assert_array(screen.get("_held") as Array).is_empty()
	assert_dict(screen.state).override_failure_message("the game's state must not change in Edit").is_equal(
		state_before
	)
	# The same key opens the boots in Play, so the checks above were not vacuous.
	await _tap(KEY_F1)
	await _frames(2)
	await _tap(KEY_B)
	assert_bool(boots.visible).override_failure_message("B should open the boots in Play").is_true()


func test_to_world_is_the_inverse_of_to_screen() -> void:
	await _open()
	await _frames(2)
	var view := _view()
	var points: Array[Vector2] = [Vector2.ZERO, Vector2(123.5, 77.25), Vector2(520, 1800), Vector2(-40, 12)]
	for point: Vector2 in points:
		var back := view.to_world(view.to_screen(point))
		assert_float(back.x).override_failure_message("x of %s" % point).is_equal_approx(point.x, 0.01)
		assert_float(back.y).override_failure_message("y of %s" % point).is_equal_approx(point.y, 0.01)
		var there := view.to_screen(view.to_world(point))
		assert_float(there.x).is_equal_approx(point.x, 0.01)
		assert_float(there.y).is_equal_approx(point.y, 0.01)
	# And with the Studio's camera: zoomed and away from the player.
	await _tap(KEY_F2)
	studio.studio_camera().focus(Vector2(900, 700))
	await _frames(3)
	for point: Vector2 in points:
		var back := view.to_world(view.to_screen(point))
		assert_float(back.x).is_equal_approx(point.x, 0.01)
		assert_float(back.y).is_equal_approx(point.y, 0.01)


## A small map of plain blocks (no art by these names): `back` stands with its feet on row 4, `front` on row 5, and a
## flat rug lies under both.
func _small_map() -> Dictionary:
	var row := "........"
	var data := {
		"id": "pick-test",
		"name": "Pick test",
		"ground": [row, row, row, row, row, row, row, row],
		"legend": {".": "grass"},
		"start": [0, 0],
		"objects":
		[
			{"kind": "prop", "art": "nope-back", "at": [2, 2], "size": [2, 2], "solid": false},
			{"kind": "prop", "art": "nope-front", "at": [3, 3], "size": [2, 2], "solid": false},
			{"kind": "prop", "art": "nope-rug", "at": [2, 2], "size": [4, 4], "solid": false, "draw_layer": "ground"},
			{"kind": "warp", "at": [6, 6], "to": {"map": "home", "at": [1, 1]}},
		],
	}
	var built := OverworldMap.build(data, {"grass": {"walk": true}})
	small = TownMapView.new({})
	add_child(small)
	await get_tree().process_frame
	small.show_map(built.map)
	await get_tree().process_frame
	return built.map


func test_picking_returns_the_front_most_first_and_the_footprints_of_unseen_things() -> void:
	var map := await _small_map()
	var pick := StudioPick.new()
	pick.rebuild(small, map)
	var tile := float(OverworldScale.TILE)
	# Cell (3, 3) is under back, front and the rug: front stands lowest (feet row 5), then back (row 4), then the rug.
	assert_array(pick.at(Vector2(3.5, 3.5) * tile)).is_equal([1, 0, 2])
	# Cell (2, 2): back and the rug only.
	assert_array(pick.at(Vector2(2.5, 2.5) * tile)).is_equal([0, 2])
	# Cell (5, 5): the rug's last cell only, since front covers (3..4).
	assert_array(pick.at(Vector2(5.5, 5.5) * tile)).is_equal([2])
	# The warp has no picture, so its footprint answers.
	assert_array(pick.at(Vector2(6.5, 6.5) * tile)).is_equal([3])
	# Open ground: nothing.
	assert_array(pick.at(Vector2(0.5, 0.5) * tile)).is_empty()
	assert_array(pick.objects_at_cell(Vector2i(3, 3))).is_equal([0, 1, 2])
	assert_bool(pick.is_stale(small)).is_false()


func test_clicking_the_inn_selects_it_and_the_inspector_shows_its_fields() -> void:
	await _open()
	await _tap(KEY_F2)
	var map := studio.current_map()
	var inn := -1
	for object: Dictionary in map.objects:
		if String(object.get("art", "")) == "inn":
			inn = int(object.index)
			assert_that(object.size).is_equal(Vector2i(6, 6))
	assert_int(inn).override_failure_message("Lanternroot has an inn").is_greater_equal(0)
	var at: Vector2i = (map.objects as Array)[inn].at
	var middle := (Vector2(at) + Vector2(3, 3)) * OverworldScale.TILE
	assert_int(studio.pick_at(middle)[0]).override_failure_message("the inn is what stands at its middle").is_equal(inn)
	studio.focus(middle)
	await _frames(4)
	await _click_world(middle)
	assert_int(studio.selection).is_equal(inn)
	var lines := studio.inspector().lines
	assert_bool("art: inn" in lines).override_failure_message(str(lines)).is_true()
	assert_bool("size: 6 x 6" in lines).override_failure_message(str(lines)).is_true()
	assert_str(studio.inspector().raw_json).contains('"art": "inn"')
	# A click on open ground clears it.
	var spot := _open_ground_near(middle)
	studio.focus(spot)
	await _frames(4)
	await _click_world(spot)
	assert_int(studio.selection).is_equal(-1)
	# With nothing selected the inspector shows the map itself (S6), not an object.
	assert_bool("id: lanternroot" in studio.inspector().lines).is_true()
	assert_str(studio.inspector().raw_json).is_empty()


## A point of open ground (nothing drawn or standing there) near `near`.
func _open_ground_near(near: Vector2) -> Vector2:
	for dy: int in range(-8, 9):
		for dx: int in range(-12, 13):
			var point := near + (Vector2(dx, dy) + Vector2(0.5, 0.5)) * OverworldScale.TILE
			var cell := Vector2i((point / OverworldScale.TILE).floor())
			if OverworldMap.inside(studio.current_map(), cell) and studio.pick_at(point).is_empty():
				return point
	return near


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
