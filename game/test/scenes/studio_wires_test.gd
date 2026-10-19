extends GdUnitTestSuite
## Links between things (Concept/v0.3/10, S8, the wiring idea: a plate's weight opens a door), on the mounted town. A
## pressure plate answers on_step: stepping on it sets its `pressed`; it links to the plot gate, which answers
## on_change and opens when the plate's `pressed` is true. Then the gate's cells are open ground. Content, drafts and
## saves are isolated copies; the things' files are written into the copy.

const TEST_ROOT := "user://studio_test/wires"
const OVERWORLD := "res://scenes/overworld/overworld.tscn"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true, "first-action": true}
const WIDTH := 20
const HEIGHT := 48
const PLATE := Vector2i(5, 11)
const GATE := Vector2i(8, 11)

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
	StudioAssets.reload()
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// Wires fixture\n", _fixture()))).is_true()
	_write_thing("pressure-plate", 'def on_step(thing, player):\n    return {"set": {"pressed": True}}\n', "function onStep(thing, player) {\n  return {set: {pressed: true}};\n}\n")
	_write_thing("plot-gate", 'def on_change(thing, player):\n    if thing.source["fields"]["pressed"]:\n        return {"set": {"open": True}, "say": "The gate swings open."}\n', "function onChange(thing, player) {\n  if (thing.source.fields.pressed) return {set: {open: true}, say: \"The gate swings open.\"};\n}\n")
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Wires tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load(OVERWORLD) as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
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
	StudioAssets.reload()
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


## A grass town: a plate (the stone step) that answers on_step and links to the plot gate, which answers on_change.
func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {"id": TOWN, "name": "Wires test", "legend": {".": "grass"}, "ground": rows, "start": [2, 2], "facing": "down", "objects": [
		{"kind": "prop", "art": "step", "id": "pressure-plate", "at": [PLATE.x, PLATE.y], "solid": false, "draw_layer": "ground",
			"program": {"hook": "on_step", "fields": {"pressed": {"type": "bool", "default": false}}, "links": ["plot-gate"]}},
		{"kind": "prop", "art": "gate", "id": "plot-gate", "at": [GATE.x, GATE.y], "size": [2, 1], "solid_unless": "open",
			"program": {"hook": "on_change", "fields": {"open": {"type": "bool", "default": false}}}},
		{"kind": "building", "art": "home", "at": [10, 39], "size": [6, 6], "door": [3, 5], "to": {"map": "home", "at": [5, 6], "facing": "up"}},
	]}


func _write_thing(id: String, python: String, javascript: String) -> void:
	var dir := StudioMode.content_dir.path_join("packs/core/overworld/things")
	var hints: Array[String] = ["One.", "Two.", "Three."]
	assert_bool(StudioFiles.write_content(dir.path_join(id + ".jsonc"), StudioThings.thing_text(id, id, hints))).is_true()
	assert_bool(StudioFiles.write_content(dir.path_join(id + ".starter.py"), python)).is_true()
	assert_bool(StudioFiles.write_content(dir.path_join(id + ".starter.js"), javascript)).is_true()


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _field(id: String, field: String) -> Variant:
	var things: Dictionary = screen.state.get("things", {})
	return ((things.get(id, {}) as Dictionary).get("fields", {}) as Dictionary).get(field)


func test_the_loader_takes_the_plate_and_the_gate_and_their_links() -> void:
	var loaded := OverworldContent.load_world(StudioMode.content_dir)
	for diagnostic: Dictionary in loaded.diagnostics:
		assert_str(String(diagnostic.get("severity", ""))).override_failure_message(ContentLoader.describe(diagnostic)).is_not_equal("error")


func test_stepping_on_the_plate_opens_the_linked_gate() -> void:
	studio.set_editing(false)
	await _frames(2)
	var map := screen.call("_current") as Dictionary
	assert_bool(TownThings.blocked(map, GATE, {}, TownThings.open_cells(map, screen.state.get("things", {})))).override_failure_message("the gate starts shut").is_true()
	screen.state = OverworldState.moved(screen.state, TOWN, PLATE, "up")
	screen.call("_on_arrived", PLATE)
	for frame: int in 900:
		if _field("plot-gate", "open") == true:
			break
		await get_tree().process_frame
	assert_bool(_field("pressure-plate", "pressed") == true).override_failure_message("the plate's on_step set pressed").is_true()
	assert_bool(_field("plot-gate", "open") == true).override_failure_message("its link's on_change opened the gate").is_true()
	map = screen.call("_current") as Dictionary
	assert_bool(TownThings.blocked(map, GATE, {}, TownThings.open_cells(map, screen.state.get("things", {})))).override_failure_message("the gate's cells are open ground").is_false()
	var runs := DebugLog.latest(studio.debug.book, DebugLog.LIMIT, ["thing"] as Array[String])
	assert_int(runs.size()).is_equal(2)
	assert_str(String(runs[0].text)).starts_with("plot-gate ran")
	assert_str(String(runs[1].text)).starts_with("pressure-plate ran")


func test_space_does_not_run_a_plate_or_a_gate_that_answer_only_steps_and_links() -> void:
	studio.set_editing(false)
	await _frames(2)
	var things := screen.get("_things") as ThingTown
	var plate: Dictionary = (screen.call("_current") as Dictionary).objects[0]
	assert_bool(things.use_if_code(plate)).is_false()


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
