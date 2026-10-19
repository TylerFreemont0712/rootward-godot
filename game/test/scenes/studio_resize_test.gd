extends GdUnitTestSuite
## Resizing by remaking (Concept/v0.3/10, 7.7): a selected barrel's handle dragged two cells and confirmed becomes
## barrel-2x1 in the draft at once, its catalog entry and spec queued, drawn as the barrel stretched and hatched; Run
## remakes uses a fake pipeline in a temporary folder. Content, drafts, saves and the queue are isolated copies; the
## world pipeline's real specs are only read.

const TEST_ROOT := "user://studio_test/resize"
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
var _old_stand_ins: Dictionary = {}


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
	_old_clipboard = StudioWork.clipboard
	StudioWork.clipboard = []
	_old_stand_ins = OverworldArt.stand_ins.duplicate(true)
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
	assert_bool(StudioFiles.write_content(_path(), JsoncWriter.map_text("// Resize fixture\n", _fixture()))).is_true()
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
	OverworldArt.stand_ins = _old_stand_ins
	StudioAssets.reload()
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path() -> String:
	return StudioSession.path_of(TOWN, StudioMode.content_dir)


func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in 14:
		rows.append("....................")
	return {"id": TOWN, "name": "Resize test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "prop", "art": "barrel", "at": [5, 6]},
		{"kind": "prop", "art": "oak", "at": [12, 6]},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _sid(art: String) -> int:
	for index: int in (studio.work.doc().data.objects as Array).size():
		if String(studio.work.raw(index).get("art", "")).begins_with(art):
			return studio.work.sid_at(index)
	return -1


## A world point in the root viewport's canvas coordinates.
func _canvas(world: Vector2) -> Vector2:
	var view := studio.pixel_view()
	return view.get_global_transform() * view.to_screen(world)


func _mouse(world: Vector2, pressed: Variant) -> void:
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


## Drags the barrel's right handle from its edge to the middle of cell (x, 6), and lets go.
func _drag_right_handle(to_x: int) -> void:
	studio.select_sids([_sid("barrel")])
	await _frames(1)
	var handle: Rect2 = studio.overlay().handles[0]
	await _mouse(handle.get_center(), null)
	await _mouse(handle.get_center(), true)
	await _mouse((Vector2(to_x, 6) + Vector2(0.5, 0.5)) * OverworldScale.TILE, null)
	await _mouse((Vector2(to_x, 6) + Vector2(0.5, 0.5)) * OverworldScale.TILE, false)


func test_a_dragged_handle_resizes_immediately_without_an_art_remake() -> void:
	var before := studio.work.doc().to_text()
	await _drag_right_handle(7)
	assert_bool(studio.remaking.asking()).is_false()
	assert_str(studio.work.doc().to_text()).is_not_equal(before)
	var object := studio.work.raw(studio.work.index_of(_sid("barrel")))
	assert_str(object.art).is_equal("barrel")
	assert_array(object.size).is_equal([3, 1])
	assert_array(object.art_size).is_equal([1, 1])
	assert_array(object.at).is_equal([5, 6])
	assert_array(studio.remaking.waiting()).is_empty()
	assert_bool(OverworldArt.stand_ins.has("barrel-3x1")).is_false()
	assert_int(studio.overlay().remaking_boxes.size()).is_equal(0)
	# The town draws the barrel's own picture stretched across the two cells, not a plain block.
	var drawn := _sprites_of(studio.work.index_of(_sid("barrel")))
	assert_int(drawn.size()).is_equal(1)
	assert_bool(is_same(drawn[0].texture, OverworldArt.prop("barrel"))).is_true()
	assert_float(drawn[0].scale.x / drawn[0].scale.y).is_equal_approx(3.0, 0.001)
	# The content file is untouched: only drafts.
	assert_bool(StudioFiles.read_text(_path()).contains("barrel-3x1")).is_false()
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_run_remakes_with_a_fake_pipeline_marks_it_made_and_drops_the_stand_in() -> void:
	studio.remaking.remake(_sid("barrel"), Vector2i(3, 1))
	var remakes := studio.remaking.remakes
	var fake := _root.path_join("fake.sh")
	var file := FileAccess.open(fake, FileAccess.WRITE)
	file.store_string("#!/usr/bin/env bash\necho \"made $1\"\n")
	file.close()
	remakes.objects_dir = ProjectSettings.globalize_path(_root.path_join("objects"))
	remakes.program = "bash"
	remakes.arguments = PackedStringArray([ProjectSettings.globalize_path(fake)])
	remakes.made_check = func(_id: String) -> bool: return true
	var button := studio.find_child("RunRemakes", true, false) as Button
	assert_bool(button.visible).is_true()
	assert_bool(button.disabled).is_false()
	button.pressed.emit()
	for frame: int in 300:
		if not remakes.running:
			break
		await get_tree().process_frame
	assert_bool(remakes.running).is_false()
	assert_str(StudioRemake.state_of(remakes.queue, "barrel-3x1")).is_equal(StudioRemake.DONE)
	assert_bool(OverworldArt.stand_ins.has("barrel-3x1")).is_false()
	assert_bool(FileAccess.file_exists(remakes.objects_dir.path_join("barrel-3x1.jsonc"))).is_true()
	assert_bool(button.visible).is_false()


func test_adopted_pictures_have_handles_and_explicit_remaking_still_reuses_variants() -> void:
	studio.select_sids([_sid("oak")])
	await _frames(1)
	assert_int(studio.overlay().handles.size()).is_equal(3)
	studio.select_sids([_sid("barrel")])
	await _frames(1)
	assert_int(studio.overlay().handles.size()).is_equal(3)
	studio.remaking.remake(_sid("barrel"), Vector2i(4, 1))
	assert_str(studio.work.raw(studio.work.index_of(_sid("barrel"))).art).is_equal("barrel-4x1")
	# A size whose picture exists already (barrel-2x1, made by the world pipeline) is only a swap: nothing is queued.
	studio.remaking.remake(_sid("barrel"), Vector2i(2, 1))
	assert_str(studio.work.raw(studio.work.index_of(_sid("barrel"))).art).is_equal("barrel-2x1")
	assert_bool("barrel-2x1" in studio.remaking.waiting()).is_false()
	studio.remaking.remake(_sid("barrel"), Vector2i(1, 1))
	var object := studio.work.raw(studio.work.index_of(_sid("barrel")))
	assert_str(object.art).is_equal("barrel")
	assert_bool(object.has("size")).is_false()


## The acceptance's last step with the real remade picture (barrel-2x1, made by scripts/world.sh): while it waits, the
## town draws the barrel stretched; when a run reports it made, its own picture replaces the stand-in at once.
func test_a_made_picture_replaces_its_placeholder_without_a_restart() -> void:
	var sid := _sid("barrel")
	studio.remaking.remake(sid, Vector2i(2, 1))
	OverworldArt.stand_ins["barrel-2x1"] = {"source": "barrel", "from": [1, 1]}
	studio.map_rebuilt(studio.current_map(), {})
	var waiting := _sprites_of(studio.work.index_of(sid))
	assert_bool(is_same(waiting[0].texture, OverworldArt.prop("barrel"))).is_true()
	studio.remaking._finished(["barrel-2x1"] as Array[String], [] as Array[String])
	var made := _sprites_of(studio.work.index_of(sid))
	assert_int(made.size()).is_equal(1)
	assert_bool(is_same(made[0].texture, OverworldArt.prop("barrel-2x1"))).is_true()
	assert_that(made[0].texture.get_size()).is_equal(Vector2(80, 60))
	assert_that(made[0].scale).is_equal(Vector2.ONE)


func _sprites_of(index: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for node: Node2D in studio.map_view().nodes_of(index):
		for child: Node in node.get_children():
			if child is Sprite2D:
				out.append(child as Sprite2D)
	return out


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
