extends GdUnitTestSuite
## The developer inspector (Concept/v0.3/10, S7) on the mounted Studio, in Play. The acceptance: jumping the main quest
## to "Light the lane" and walking to the lane shows the lamps dark, and the event log shows the cabbage gate's code run
## with its result. Then: pokes need Play draft and never reach the real save; a quest step done and reopened; a thing
## reset and run again with chosen inputs (nothing kept); Ctrl-click teleports; the Events tab filters; F3 shows and
## hides it; a content file that changes is reloaded. Content, drafts and saves are isolated copies.

const TEST_ROOT := "user://studio_test/debug"
const OVERWORLD := "res://scenes/overworld/overworld.tscn"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true, "first-action": true, "boots-hint-seen": true}

var screen: OverworldScreen
var studio: StudioMode
var debug: StudioDebug
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
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh("home", Vector2i(2, 3), "down", BootsCode.PYTHON)
	state.look = LOOK.duplicate(true)
	state.name = "Debug tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	debug = studio.debug


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


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


## Play draft on, and the inspector shown: pokes are allowed.
func _poking() -> void:
	studio.set_play_draft(true)
	await _frames(2)
	studio.toggle_debug()
	await _frames(2)


func _texts(kind: String) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in DebugLog.latest(debug.book, DebugLog.LIMIT, [kind] as Array[String]):
		out.append(String(entry.text))
	return out


func _flags() -> Dictionary:
	return screen.state.get("flags", {})


## The first cell round `near` on `map` where someone can stand.
func _open_cell(map_id: String, near: Vector2i) -> Vector2i:
	var map: Dictionary = studio.catalog().maps[map_id]
	for radius: int in range(0, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell := near + Vector2i(dx, dy)
				if not OverworldMap.blocked(map, cell):
					return cell
	return near


func _teleport(map_id: String, near: Vector2i) -> Vector2i:
	var cell := _open_cell(map_id, near)
	assert_bool(bool((studio.parts().teleport as Callable).call(map_id, cell))).is_true()
	await _frames(2)
	return cell


func _thing(id: String) -> Dictionary:
	for object: Dictionary in studio.current_map().objects:
		if String(object.get("id", "")) == id:
			return object
	return {}


func test_jumping_to_light_the_lane_and_walking_there_shows_the_lamps_dark() -> void:
	await _poking()
	assert_bool(debug.visible).is_true()
	assert_float(studio.pixel_view().offset_right).override_failure_message("the town shrinks beside it").is_equal(-float(StudioDebug.WIDTH))
	assert_bool(debug.jump_to("lamps")).is_true()
	await _frames(2)
	var quests: Dictionary = studio.catalog().quests
	assert_str(String(Quests.current(quests, _flags()).get("id", ""))).is_equal("lamps")
	assert_int(int(Quests.current(quests, _flags()).get("step", -1))).is_equal(0)
	assert_bool(bool(_flags().get("lamps-lit", false))).is_false()
	await _teleport(TOWN, Vector2i(48, 16))
	assert_str(String(screen.state.map)).is_equal(TOWN)
	assert_array(screen.get("_map").get("_dark_groups") as Array).override_failure_message("the lane's lamps are drawn dark").contains_exactly(["lane"])
	assert_array(_texts("poke")).contains(["Jumped to Light the lane"])
	assert_bool(_texts("quest").size() >= 3).override_failure_message("the steps the jump finished are logged").is_true()
	assert_bool(_texts("warp").any(func(text: String) -> bool: return text.begins_with("home ") and text.contains(TOWN))).is_true()


func test_the_cabbage_gates_code_run_is_logged_with_its_result() -> void:
	await _poking()
	await _teleport(TOWN, Vector2i(4, 45))
	var gate := _thing("cabbage-gate")
	assert_bool(gate.is_empty()).is_false()
	var host := (studio.parts().things as Callable).call() as ThingHost
	host.use(gate, [] as Array[String])
	for frame: int in 600:
		if not _texts("thing").is_empty():
			break
		await get_tree().process_frame
	var ran := _texts("thing")
	assert_array(ran).has_size(1)
	assert_str(ran[0]).starts_with("cabbage-gate ran in ")
	assert_str(ran[0]).contains("in {")
	assert_str(ran[0]).contains("→ out")
	var entry: Dictionary = DebugLog.latest(debug.book, 1, ["thing"] as Array[String])[0]
	assert_bool((entry.data as Dictionary).has("verdict")).is_true()
	assert_str(String(((entry.data.input as Dictionary).get("thing", {}) as Dictionary).get("id", ""))).is_equal("cabbage-gate")


func test_pokes_need_play_draft_and_never_reach_the_real_save() -> void:
	studio.toggle_debug()
	await _frames(2)
	assert_bool(debug.can_poke()).is_false()
	assert_bool(debug.set_flag("poked-flag")).override_failure_message("no pokes on the real save").is_false()
	assert_bool(_flags().has("poked-flag")).is_false()
	studio.set_play_draft(true)
	await _frames(2)
	assert_bool(debug.set_flag("poked-flag")).is_true()
	await _frames(1)
	assert_bool(bool(_flags().get("poked-flag", false))).is_true()
	assert_array(_texts("flag")).contains(["set poked-flag"])
	assert_array(_texts("poke")).contains(["Set poked-flag"])
	assert_bool(debug.clear_flag("poked-flag")).is_true()
	await _frames(1)
	assert_bool(_flags().has("poked-flag")).is_false()
	assert_bool(debug.set_flag("poked-again")).is_true()
	studio.set_play_draft(false)
	await _frames(2)
	assert_bool(_flags().has("poked-again")).override_failure_message("the real state comes back without the poke").is_false()
	var saved := OverworldStore.for_profile().load_state()
	assert_bool((saved.get("flags", {}) as Dictionary).has("poked-again")).override_failure_message("the real save never had it").is_false()


func test_a_quest_step_done_and_reopened() -> void:
	await _poking()
	assert_bool(debug.complete_step("hello", 0)).is_true()
	await _frames(1)
	assert_bool(bool(_flags().get("met-innkeeper", false))).is_true()
	assert_bool(_texts("quest").any(func(text: String) -> bool: return text.begins_with("Hello, Lanternroot: step 1 done"))).is_true()
	assert_bool(debug.reopen_step("hello", 0)).is_true()
	await _frames(1)
	assert_bool(bool(_flags().get("met-innkeeper", false))).is_false()
	assert_bool(_texts("quest").any(func(text: String) -> bool: return text.contains("not done any more"))).is_true()


func test_a_thing_reset_and_run_again_with_chosen_inputs_keeps_nothing() -> void:
	await _poking()
	await _teleport(TOWN, Vector2i(4, 45))
	var poked := screen.state.duplicate(true)
	poked["things"] = {"cabbage-gate": {"fields": {"open": true}}}
	(studio.parts().poke_state as Callable).call(poked)
	await _frames(1)
	assert_bool(debug.reset_thing("cabbage-gate")).is_true()
	assert_bool((screen.state.get("things", {}) as Dictionary).has("cabbage-gate")).is_false()
	assert_array(_texts("poke")).contains(["Reset cabbage-gate"])
	var before := JSON.stringify([screen.state.flags, screen.state.get("things", {}), screen.state.map, screen.state.cell])
	var host := (studio.parts().things as Callable).call() as ThingHost
	var input := host.input_of(_thing("cabbage-gate"), [] as Array[String])
	assert_str(String((input.get("thing", {}) as Dictionary).get("id", ""))).is_equal("cabbage-gate")
	var result: Dictionary = await debug.rerun(_thing("cabbage-gate"), JSON.stringify(input))
	assert_bool(result.has("run")).is_true()
	var after := JSON.stringify([screen.state.flags, screen.state.get("things", {}), screen.state.map, screen.state.cell])
	assert_str(after).override_failure_message("a re-run changes nothing").is_equal(before)
	assert_bool(_texts("thing").any(func(text: String) -> bool: return text.contains("a look only"))).is_true()
	assert_dict(await debug.rerun(_thing("cabbage-gate"), "not json")).is_empty()


func test_ctrl_click_teleports_and_the_events_tab_filters() -> void:
	await _poking()
	await _teleport(TOWN, Vector2i(20, 30))
	await _frames(2)
	var view := studio.pixel_view()
	var target := _open_cell(TOWN, OverworldState.cell(screen.state) + Vector2i(2, 0))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.ctrl_pressed = true
	click.position = view.get_global_transform() * view.to_screen((Vector2(target) + Vector2(0.5, 0.5)) * OverworldScale.TILE)
	click.global_position = click.position
	get_tree().root.push_input(click, true)
	await _frames(2)
	assert_vector(Vector2(OverworldState.cell(screen.state))).is_equal(Vector2(target))
	assert_bool(_texts("poke").any(func(text: String) -> bool: return text.begins_with("Teleported to lanternroot"))).is_true()
	debug.show_tab("events")
	debug.kinds = ["warp"] as Array[String]
	debug.rebuild()
	await _frames(1)
	var rows := debug.find_child("Body", true, false) as VBoxContainer
	assert_int(rows.get_child_count()).override_failure_message("the chips and the warp rows").is_greater(1)


func test_f3_shows_and_hides_it_in_play_only() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	get_tree().root.push_input(key)
	await _frames(1)
	assert_bool(debug.visible).is_true()
	get_tree().root.push_input(key)
	await _frames(1)
	assert_bool(debug.visible).is_false()
	assert_float(studio.pixel_view().offset_right).is_equal(0.0)
	studio.toggle_debug()
	studio.set_editing(true)
	await _frames(1)
	assert_bool(debug.visible).override_failure_message("Edit has its own panels").is_false()
	studio.set_editing(false)
	await _frames(1)
	assert_bool(debug.visible).override_failure_message("and it comes back with Play").is_true()


func test_a_content_file_that_changes_is_reloaded() -> void:
	studio.toggle_debug()
	await _frames(2)
	var talk := StudioMode.content_dir.path_join("packs/core/overworld/talk/innkeeper.jsonc")
	var text := StudioFiles.read_text(talk)
	# The files' times are in whole seconds.
	OS.delay_msec(1100)
	assert_bool(StudioFiles.write_content(talk, text + "\n")).is_true()
	for frame: int in 400:
		if not _texts("content").is_empty():
			break
		await get_tree().create_timer(0.01).timeout
	assert_array(_texts("content")).contains(["Content reloaded (innkeeper.jsonc)"])


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
