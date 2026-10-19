extends GdUnitTestSuite
## `[` and `]` swap a thing for another variant of its catalog family in place (Concept/v0.3/10, 7.7): its feet kept,
## one undo step, refused where the new footprint does not fit. Content, drafts and saves are isolated copies; the
## size-changing family is a fixture catalog put in StudioAssets' cache for the test and taken out after it.

const TEST_ROOT := "user://studio_test/variants"
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
	assert_bool(StudioFiles.write_content(_path(), JsoncWriter.map_text("// Variants fixture\n", _fixture()))).is_true()
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
	return {"id": TOWN, "name": "Variants test", "legend": {".": "grass"}, "ground": rows, "start": [1, 1], "facing": "down", "objects": [
		{"kind": "prop", "art": "oak", "at": [2, 10]},
		{"kind": "prop", "art": "crate", "at": [5, 5], "flip": true},
		{"kind": "building", "art": "cottage", "at": [12, 2], "size": [3, 3], "door": [1, 2]},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _sid(art: String) -> int:
	for index: int in (studio.work.doc().data.objects as Array).size():
		if String(studio.work.raw(index).get("art", "")) == art:
			return studio.work.sid_at(index)
	return -1


## A family whose variants differ in size: a 1 x 1 crate and a 3 x 2 cart (which may not flip), a 3 x 3 cottage and a
## 5 x 3 hall with its door elsewhere. Real art names, so the town draws them.
func _sized_family() -> void:
	var entries := StudioAssets.entries().duplicate(true)
	entries["crate"] = {"name": "Crate", "kind": "prop", "size": [1, 1], "family": "box", "variant": "Small", "flippable": true}
	entries["cart"] = {"name": "Cart", "kind": "prop", "size": [3, 2], "family": "box", "variant": "Long", "flippable": false}
	entries["cottage"] = {"name": "Cottage", "kind": "building", "size": [3, 3], "door": [1, 2], "family": "house", "variant": "Small"}
	entries["hall"] = {"name": "Hall", "kind": "building", "size": [5, 3], "door": [2, 2], "family": "house", "variant": "Wide"}
	StudioAssets._entries = entries
	StudioAssets._loaded_from = StudioCatalogSession.path_of(StudioMode.content_dir)


func test_bracket_swaps_an_oak_for_its_other_variant_in_place_as_one_step() -> void:
	var oak := _sid("oak")
	var before := studio.work.doc().to_text()
	var steps := studio.work.session().history.labels().size()
	studio.select_sids([oak])
	assert_str((studio.inspector().find_child("Variant", true, false) as Label).text).is_equal("Round, 1 of 2")
	_key(KEY_BRACKETRIGHT)
	var object := studio.work.raw(studio.work.index_of(oak))
	assert_str(object.art).is_equal("oak2")
	assert_array(object.at).is_equal([2, 10])
	assert_bool(object.has("size")).is_false()
	assert_int(studio.work.session().history.labels().size()).is_equal(steps + 1)
	assert_str((studio.inspector().find_child("Variant", true, false) as Label).text).is_equal("Wide, 2 of 2")
	_key(KEY_BRACKETRIGHT)
	assert_str(studio.work.raw(studio.work.index_of(oak)).art).is_equal("oak")
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_a_variant_of_another_size_keeps_its_feet_and_drops_a_flip_it_cannot_take() -> void:
	_sized_family()
	var crate := _sid("crate")
	var before := studio.work.doc().to_text()
	assert_int(studio.work.swap_variant([crate], 1)).is_equal(1)
	var object := studio.work.raw(studio.work.index_of(crate))
	# The crate stood on (5, 5); the 3 x 2 cart stands there too: its top-left is (5 - 1, 5 - 1).
	assert_str(object.art).is_equal("cart")
	assert_array(object.at).is_equal([4, 4])
	assert_array(object.size).is_equal([3, 2])
	assert_bool(object.has("flip")).is_false()
	assert_int(studio.work.swap_variant([crate], -1)).is_equal(1)
	object = studio.work.raw(studio.work.index_of(crate))
	assert_str(object.art).is_equal("crate")
	assert_array(object.at).is_equal([5, 5])
	assert_bool(object.has("size")).is_false()
	assert_bool(studio.work.undo()).is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_str(studio.work.doc().to_text()).is_equal(before)


func test_a_building_variant_takes_its_own_door_with_its_feet_kept() -> void:
	_sized_family()
	var cottage := _sid("cottage")
	assert_int(studio.work.swap_variant([cottage], 1)).is_equal(1)
	var object := studio.work.raw(studio.work.index_of(cottage))
	# The cottage's bottom-middle cell is (13, 4); the 5 x 3 hall's is too.
	assert_str(object.art).is_equal("hall")
	assert_array(object.at).is_equal([11, 2])
	assert_array(object.size).is_equal([5, 3])
	assert_array(object.door).is_equal([2, 2])


func test_a_variant_that_does_not_fit_changes_nothing() -> void:
	_sized_family()
	assert_bool(studio.work.command({"type": "add", "object": {"kind": "prop", "art": "barrel", "at": [6, 4]}, "index": -1}).ok).is_true()
	var crate := _sid("crate")
	var before := studio.work.doc().to_text()
	var steps := studio.work.session().history.labels().size()
	assert_int(studio.work.swap_variant([crate], 1)).is_equal(0)
	assert_str(studio.work.doc().to_text()).is_equal(before)
	assert_int(studio.work.session().history.labels().size()).is_equal(steps)


func test_a_thing_with_no_other_variant_is_left_alone() -> void:
	studio.select_sids([_sid("crate")])
	assert_object(studio.inspector().find_child("Variant", true, false)).is_null()
	var before := studio.work.doc().to_text()
	assert_int(studio.work.swap_variant([_sid("crate")], 1)).is_equal(0)
	assert_str(studio.work.doc().to_text()).is_equal(before)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	studio._unhandled_input(event)
	event.pressed = false
	studio._unhandled_input(event)


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
