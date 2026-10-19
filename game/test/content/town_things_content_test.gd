extends GdUnitTestSuite
## Lanternroot's things that take code (TownThings, ADR-0061), checked as content: every program on the town's map has a
## thing file and every thing file is run on the map; every file in things/ loads, each starter belongs to the thing
## that names it, and each thing has three hints and both starters; the cabbage gate's two tiles are solid while it is
## shut, in the loaded map; the hello quest opens once the boots and the first action are done; and the town's boots
## table answers for every tile in both languages, within the sandbox's cap (timed, and the time printed).

const THINGS := "res://content/packs/core/overworld/things"
const TOWN := "lanternroot"
const GATE := "cabbage-gate"
const HINTS := 3
const LANGUAGES: Array[String] = ["python", "javascript"]
const STARTER_EXTENSIONS := {"python": ".starter.py", "javascript": ".starter.js"}
## The four ways the boots can go, each as BootsCode.rule takes it: the key, its axis and its step.
const WAYS: Array[Dictionary] = [
	{"key": "right", "axis": "x", "by": 1},
	{"key": "down", "axis": "y", "by": 1},
	{"key": "up", "axis": "y", "by": -1},
	{"key": "left", "axis": "x", "by": -1},
]

var _world: Dictionary = {}


func before() -> void:
	_world = OverworldContent.load_world()


func _catalog() -> Dictionary:
	return _world.catalog


func _maps() -> Dictionary:
	return _catalog().maps


## The map's object with this id, or {} when it has none.
static func _object_of(map: Dictionary, id: String) -> Dictionary:
	for object: Dictionary in map.objects:
		if String(object.get("id", "")) == id:
			return object
	return {}


## The cells an object stands on: its footprint, from its position and size.
static func _footprint(object: Dictionary) -> Array[Vector2i]:
	var at := OverworldMap.cell_of(object.get("at", [0, 0]))
	var size := OverworldMap.cell_of(object.get("size", [1, 1]))
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			out.append(at + Vector2i(x, y))
	return out


func test_the_world_loads_and_the_things_are_in_it() -> void:
	assert_bool(bool(_world.ok)).override_failure_message("the world has errors").is_true()
	assert_array(_catalog().things.keys()).contains([GATE, "crossroads-sign"])


## A program on a map runs a thing, so its thing file must load; a thing file that no map runs is one the player can
## never reach. Both are checked from the loaded world.
func test_every_program_on_the_map_has_a_thing_file_and_every_thing_file_is_run_on_the_map() -> void:
	var programs: Array[String] = []
	var missing: Array[String] = []
	for map_id: String in _maps():
		var map: Dictionary = _maps()[map_id]
		for object: Dictionary in map.objects:
			if not object.has("program"):
				continue
			var id := String(object.get("id", ""))
			programs.append(id)
			if not _catalog().things.has(id):
				missing.append("%s runs a program on %s, and has no thing file" % [id, map_id])
	var unrun: Array[String] = []
	for id: String in _catalog().things:
		if not programs.has(id):
			unrun.append("%s has a thing file, and no map runs it" % id)
	assert_array(missing).override_failure_message("programs without a thing file: %s" % [missing]).is_empty()
	assert_array(unrun).override_failure_message("thing files no map runs: %s" % [unrun]).is_empty()
	assert_int(programs.size()).override_failure_message("the town should run programs").is_greater_equal(2)


## Every file in things/ loads (one that fails is left out of the catalog, which would hide it). Each starter file
## belongs to a thing whose starter field names that file, so a starter cannot sit beside the wrong thing.
func test_every_thing_file_on_disk_loads_and_each_starter_belongs_to_its_thing() -> void:
	var bad: Array[String] = []
	var things_on_disk := 0
	for name: String in DirAccess.get_files_at(THINGS):
		if name.ends_with(".jsonc"):
			things_on_disk += 1
			if not _catalog().things.has(name.get_basename()):
				bad.append("%s is on disk and did not load" % name)
			continue
		for language: String in STARTER_EXTENSIONS:
			var extension: String = STARTER_EXTENSIONS[language]
			if not name.ends_with(extension):
				continue
			var owner := name.trim_suffix(extension)
			if not _catalog().things.has(owner):
				bad.append("%s is a starter with no thing beside it" % name)
			elif String(_catalog().things[owner].starter[language]) != name:
				bad.append("%s is not the %s starter of %s" % [name, language, owner])
	assert_array(bad).override_failure_message("things and starters that do not match: %s" % [bad]).is_empty()
	assert_int(things_on_disk).override_failure_message("the town should have things on disk").is_greater_equal(2)


func test_every_thing_has_three_hints_and_both_starters() -> void:
	var bad: Array[String] = []
	for id: String in _catalog().things:
		var thing: Dictionary = _catalog().things[id]
		var hints: Array = thing.get("hints", [])
		if hints.size() != HINTS:
			bad.append("%s has %d hints, not %d" % [id, hints.size(), HINTS])
		for hint: Variant in hints:
			if String(hint).strip_edges() == "":
				bad.append("%s has an empty hint" % id)
		var code: Dictionary = thing.get("code", {})
		for language: String in LANGUAGES:
			if String(code.get(language, "")).strip_edges() == "":
				bad.append("%s has no %s starter" % [id, language])
	assert_array(bad).override_failure_message("things without their hints or starters: %s" % [bad]).is_empty()


## The gate is a prop with two tiles. Shut, both tiles block the walk in the loaded map, with or without the things'
## open cells; open, both let the walk through.
func test_the_cabbage_gate_is_solid_on_both_tiles_while_it_is_shut() -> void:
	var map: Dictionary = _maps()[TOWN]
	var gate := _object_of(map, GATE)
	assert_bool(gate.is_empty()).override_failure_message("the town has no %s" % GATE).is_false()
	var cells := _footprint(gate)
	assert_int(cells.size()).override_failure_message("the gate should cover two tiles").is_equal(2)
	var shut := TownThings.open_cells(map, {})
	for cell: Vector2i in cells:
		(
			assert_bool(OverworldMap.blocked(map, cell))
			. override_failure_message("%s is walkable while shut" % cell)
			. is_true()
		)
		(
			assert_bool(TownThings.blocked(map, cell, {}, shut))
			. override_failure_message("%s is walkable while shut" % cell)
			. is_true()
		)
		assert_bool(shut.has(cell)).override_failure_message("%s is open while shut" % cell).is_false()
	var opened := TownThings.open_cells(map, {GATE: {"fields": {"open": true}}})
	for cell: Vector2i in cells:
		(
			assert_bool(TownThings.blocked(map, cell, {}, opened))
			. override_failure_message("%s stays solid once open" % cell)
			. is_false()
		)


## The quest that the two flags open. The boots quest is done when its five steps are, and the first step of the
## first open quest is then hello's; without the first action, or without the gate opening, hello stays shut.
func test_the_hello_quest_opens_once_the_boots_are_taught_and_the_gate_has_opened() -> void:
	var quests: Dictionary = _catalog().quests
	var taught := {
		"first-step": true, "first-action": true, "boots-expanded": true, "all-ways": true, "cabbage-gate-open": true, "left-home": true
	}
	assert_str(Quests.status(quests, "boots", taught)).override_failure_message("boots not done").is_equal(Quests.DONE)
	assert_str(Quests.status(quests, "hello", taught)).override_failure_message("hello did not open").is_equal(
		Quests.OPEN
	)
	assert_str(String(Quests.current(quests, taught).get("id", ""))).is_equal("hello")
	var no_action := taught.duplicate()
	no_action.erase("boots-expanded")
	(
		assert_str(Quests.status(quests, "hello", no_action))
		. override_failure_message("hello opened with no first action")
		. is_equal(Quests.LOCKED)
	)
	var no_gate := taught.duplicate()
	no_gate.erase("cabbage-gate-open")
	(
		assert_str(Quests.status(quests, "hello", no_gate))
		. override_failure_message("hello opened with the gate shut")
		. is_equal(Quests.LOCKED)
	)
	assert_str(String(Quests.current(quests, no_gate).get("id", ""))).is_equal("boots")


## The town's boots table, as the game makes it (BootsRun, with its sandbox limits), for the town's own size and all
## four keys. An answer that did not fit the sandbox's output cap, or did not cover every tile, fails here. The time
## each language takes is printed; it is measured, not asserted.
func test_the_town_boots_table_answers_every_tile_in_both_languages_within_the_sandbox_cap(
	_do_skip := not (Sandbox.is_available(SandboxJob.PYTHON) and Sandbox.is_available(SandboxJob.JAVASCRIPT)),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	var map: Dictionary = _maps()[TOWN]
	var size := OverworldMap.size_of(map)
	var blocks: Array = []
	for way: Dictionary in WAYS:
		blocks.append(BootsCode.rule(way.key, way.axis, way.by))
	for language: String in LANGUAGES:
		var started := Time.get_ticks_usec()
		var table := BootsRun.run(language, BootsCode.source(blocks, language), size)
		var milliseconds := (Time.get_ticks_usec() - started) / 1000
		print(
			(
				"%s: the town's boots table (%dx%d, %d keys) took %d ms, status %s"
				% [language, size.x, size.y, WAYS.size(), milliseconds, table.status]
			)
		)
		assert_str(String(table.status)).override_failure_message("%s: %s" % [language, table.message]).is_equal("ok")
		assert_int(table.x.size()).override_failure_message("%s: one answer per tile per key" % language).is_equal(
			size.x * size.y * WAYS.size()
		)
