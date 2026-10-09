extends GdUnitTestSuite
## Lanternroot's overworld content, checked whole (ADR-0061): the world loads with no errors, every townsperson has a
## talk, every talk reads to its end, every door leads to a map and a cell on it, every person on a map is a townsperson
## who stands on open ground alone, every prop or sign with a talk finds that talk, and each start can be walked on.

const MAPS := "res://content/packs/core/overworld/maps"
const TALKING: Array[String] = ["prop", "sign"]

var _world: Dictionary = {}


func before() -> void:
	_world = OverworldContent.load_world()


func _catalog() -> Dictionary:
	return _world.catalog


func _maps() -> Dictionary:
	return _catalog().maps


func test_the_world_loads_with_no_errors() -> void:
	var errors: Array[String] = []
	for diagnostic: Dictionary in _world.diagnostics:
		if diagnostic.severity == "error":
			errors.append(ContentLoader.describe(diagnostic))
	assert_array(errors).override_failure_message("content errors: %s" % [errors]).is_empty()
	assert_bool(bool(_world.ok)).is_true()
	assert_array(_maps().keys()).contains(["home", "lanternroot"])


func test_every_townsperson_has_a_talk_that_exists() -> void:
	var talks: Dictionary = _catalog().talk
	var missing: Array[String] = []
	for id: String in _catalog().townsfolk:
		var talk := String(_catalog().townsfolk[id].get("talk", ""))
		if not talks.has(talk):
			missing.append("%s talks with %s" % [id, talk])
	assert_array(missing).override_failure_message("townsfolk without a talk: %s" % [missing]).is_empty()
	assert_array(_catalog().townsfolk.keys()).is_not_empty()


func test_every_talk_reads_to_its_end_with_no_empty_node() -> void:
	var found := {}
	for id: String in _catalog().talk:
		var problems := Talk.problems(_catalog().talk[id])
		if not problems.is_empty():
			found[id] = problems
	assert_dict(found).override_failure_message("talks that do not read through: %s" % [found]).is_empty()
	assert_array(_catalog().talk.keys()).is_not_empty()


func test_every_door_leads_to_a_map_and_a_cell_on_it() -> void:
	var bad: Array[String] = []
	var doors := 0
	for map_id: String in _maps():
		var map: Dictionary = _maps()[map_id]
		for cell: Vector2i in map.warps:
			doors += 1
			var to: Dictionary = map.warps[cell]
			var target: Dictionary = _maps().get(String(to.map), {})
			if target.is_empty():
				bad.append("%s: the door at %s leads to %s, which is no map" % [map_id, cell, to.map])
			elif not OverworldMap.inside(target, OverworldMap.cell_of(to.at)):
				bad.append("%s: the door at %s leads to %s at %s, off that map" % [map_id, cell, to.map, to.at])
	assert_array(bad).override_failure_message("bad doors: %s" % [bad]).is_empty()
	assert_int(doors).override_failure_message("the town should have doors to check").is_greater(0)


func test_every_person_on_a_map_is_one_of_the_townsfolk() -> void:
	var strangers: Array[String] = []
	for map_id: String in _maps():
		for person: Dictionary in _maps()[map_id].people:
			if not _catalog().townsfolk.has(String(person.id)):
				strangers.append("%s: %s" % [map_id, person.id])
	assert_array(strangers).override_failure_message("people who are not townsfolk: %s" % [strangers]).is_empty()


func test_every_person_stands_on_open_ground_and_alone() -> void:
	var bad: Array[String] = []
	for map_id: String in _maps():
		var map: Dictionary = _maps()[map_id]
		var taken := {}
		for person: Dictionary in map.people:
			var cell := OverworldMap.cell_of(person.at)
			if OverworldMap.blocked(map, cell):
				bad.append("%s: %s stands on %s, which is blocked" % [map_id, person.id, cell])
			if taken.has(cell):
				bad.append("%s: %s and %s share %s" % [map_id, taken[cell], person.id, cell])
			taken[cell] = person.id
	assert_array(bad).override_failure_message("people in the way: %s" % [bad]).is_empty()


func test_every_prop_or_sign_with_a_talk_finds_that_talk() -> void:
	# Read from the files as written: a talk the schema drops would otherwise pass without being checked at all.
	var missing: Array[String] = []
	var in_files := 0
	for name: String in DirAccess.get_files_at(MAPS):
		if not name.ends_with(".jsonc"):
			continue
		var parsed := Jsonc.parse_file(MAPS.path_join(name))
		var reason := String(parsed.get("error", ""))
		assert_bool(bool(parsed.ok)).override_failure_message("%s does not parse: %s" % [name, reason]).is_true()
		if not bool(parsed.ok):
			continue
		for object: Dictionary in (parsed.value as Dictionary).get("objects", []):
			if String(object.get("kind", "")) in TALKING and object.has("talk"):
				in_files += 1
				if not _catalog().talk.has(String(object.talk)):
					missing.append("%s talks with %s, which is no talk" % [name, object.talk])
	assert_array(missing).override_failure_message("props and signs without their talk: %s" % [missing]).is_empty()
	# Both counts must be real: zero on both sides would pass the checks below without checking anything.
	(
		assert_int(in_files)
		. override_failure_message("the town's files should have props and signs that talk")
		. is_greater_equal(1)
	)
	# And the world keeps every one of them, so the game can find it.
	var in_world := 0
	for map_id: String in _maps():
		for object: Dictionary in _maps()[map_id].objects:
			if String(object.get("kind", "")) in TALKING and object.has("talk"):
				in_world += 1
	assert_int(in_world).override_failure_message("the world should have props and signs that talk").is_greater_equal(1)
	(
		assert_int(in_world)
		. override_failure_message("the world keeps %d of the %d props and signs that talk" % [in_world, in_files])
		. is_equal(in_files)
	)
	print("props and signs that talk: %d in the files, %d in the world" % [in_files, in_world])


func test_the_lanternroot_start_is_walkable() -> void:
	var map: Dictionary = _maps().lanternroot
	(
		assert_bool(OverworldMap.blocked(map, map.start))
		. override_failure_message("lanternroot starts on %s, which is blocked" % [map.start])
		. is_false()
	)


func test_every_maps_start_is_walkable() -> void:
	var blocked: Array[String] = []
	for map_id: String in _maps():
		var map: Dictionary = _maps()[map_id]
		if OverworldMap.blocked(map, map.start):
			blocked.append("%s starts on %s" % [map_id, map.start])
	assert_array(blocked).override_failure_message("starts that cannot be walked on: %s" % [blocked]).is_empty()
