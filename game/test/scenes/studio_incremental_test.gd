extends GdUnitTestSuite
## The incremental redraw (TownMapView.update_objects, StudioPick.update, StudioWork._build) gives what a whole redraw
## gives: after each edit the nodes, their order and metas, the pick answers and the built map equal a fresh one.
## Content, drafts and saves are isolated copies.

const TEST_ROOT := "user://studio_test/incremental"
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
var _old_entries: Dictionary = {}
var _old_loaded_from := ""


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
	_old_clipboard = StudioWork.clipboard
	StudioWork.clipboard = []
	_old_entries = StudioAssets._entries
	_old_loaded_from = StudioAssets._loaded_from
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
	assert_bool(StudioFiles.write_content(_path(), JsoncWriter.map_text("// Incremental fixture\n", _fixture()))).is_true()
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
	StudioAssets._entries = _old_entries
	StudioAssets._loaded_from = _old_loaded_from
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path() -> String:
	return StudioSession.path_of(TOWN, StudioMode.content_dir)


func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in 14:
		rows.append("....................")
	return {"id": TOWN, "name": "Incremental test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "prop", "art": "oak", "at": [2, 10]},
		{"kind": "prop", "art": "crate", "at": [5, 5], "flip": true},
		{"kind": "building", "art": "cottage", "at": [12, 2], "size": [3, 3], "door": [1, 2]},
		{"kind": "prop", "art": "barrel", "at": [8, 8]},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _copy_tree(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)
	for directory: String in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), target.path_join(directory))
	for file: String in DirAccess.get_files_at(source):
		DirAccess.copy_absolute(source.path_join(file), target.path_join(file))


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _sid(art: String) -> int:
	for index: int in (studio.work.doc().data.objects as Array).size():
		if String(studio.work.raw(index).get("art", "")) == art:
			return studio.work.sid_at(index)
	return -1


## What a node list says, for comparing: class, object_index, position, picture, region, flip and scale of every node.
func _described(parent: Node2D) -> Array[String]:
	var out: Array[String] = []
	for node: Node in parent.get_children():
		var line := "%s #%s %s" % [node.get_class(), node.get_meta("object_index", "-"), (node as Node2D).position]
		for part: Node in node.get_children():
			if part is Sprite2D:
				var sprite := part as Sprite2D
				line += " | %s %s %s %s %s" % [sprite.texture.resource_path if sprite.texture else "", sprite.region_rect if sprite.region_enabled else "", sprite.flip_h, sprite.position, sprite.scale]
		out.append(line)
	return out


func _same_as_fresh(step: String) -> void:
	var view := studio.map_view()
	var fresh := TownMapView.new(OverworldScreen.catalog_of())
	add_child(fresh)
	var map := studio.current_map()
	fresh.show_map(map, true, screen.call("_dark_groups"), TownThings.open_cells(map, screen.state.get("things", {})))
	# The player stands in `things` of the real view only.
	var shown := _described(view.things).filter(func(line: String) -> bool: return not line.contains("#-"))
	assert_array(shown).override_failure_message(step + ": things").is_equal(_described(fresh.things))
	assert_array(_described(view.underfoot)).override_failure_message(step + ": underfoot").is_equal(_described(fresh.underfoot))
	var other := StudioPick.new()
	other.rebuild(fresh, map)
	var pick := studio.pick()
	for y: int in range(0, 14 * 4):
		for x: int in range(0, 20 * 4):
			var point := Vector2(x, y) * (OverworldScale.TILE / 4.0)
			if pick.at(point) != other.at(point):
				assert_array(pick.at(point)).override_failure_message("%s: pick at %s" % [step, point]).is_equal(other.at(point))
				return
	for index: int in (map.objects as Array).size():
		assert_that(pick.picture_rect(index)).override_failure_message(step + ": rect %d" % index).is_equal(other.picture_rect(index))
	var rebuilt := StudioSession.build_data(studio.work.doc().data, studio.work.session().path, OverworldScreen.catalog_of().terrain)
	assert_bool(map == rebuilt.map).override_failure_message(step + ": built map").is_true()
	fresh.queue_free()


func test_edits_draw_what_a_whole_redraw_draws() -> void:
	var crate := _sid("crate")
	studio.work.place(StudioAssets.template("barrel"), Vector2i(3, 3), true)
	_same_as_fresh("place a barrel")
	studio.work.place(StudioAssets.template("cottage"), Vector2i(6, 12), true)
	_same_as_fresh("place a building")
	studio.work.move([crate], Vector2i(1, 2), true)
	_same_as_fresh("move")
	studio.work.flip([crate])
	_same_as_fresh("flip")
	studio.work.place_row(StudioAssets.template("barrel"), [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6)] as Array[Vector2i], true)
	_same_as_fresh("a row")
	studio.work.delete([_sid("oak")], true)
	_same_as_fresh("delete from the middle")
	for step: int in 5:
		studio.work.undo()
		_same_as_fresh("undo %d" % step)
	for step: int in 3:
		studio.work.redo()
		_same_as_fresh("redo %d" % step)
