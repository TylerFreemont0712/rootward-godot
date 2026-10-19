extends GdUnitTestSuite
## Lanternroot Studio's checks (studio_rules.gd, Concept/v0.3/10 section 9.5): the real maps give no errors, and each
## problem is found on a small map, with its severity, message, sid and cell.

const HOME := "res://content/packs/core/overworld/maps/home.jsonc"
const LANTERN := "res://content/packs/core/overworld/maps/lanternroot.jsonc"
const NOWHERE := Vector2i(-1, -1)


## The real maps, as the Studio reads them, with every picture on disk and the footprints the world pipeline wrote.
## Neither map may give an error (warnings are allowed).
func test_the_real_home_and_lanternroot_maps_give_no_errors() -> void:
	var maps := {}
	var sids := {}
	for path: String in [HOME, LANTERN]:
		var data: Dictionary = JsoncWriter.normalized(Jsonc.parse(FileAccess.get_file_as_string(path)).value)
		maps[path] = data
		sids[path] = range((data.objects as Array).size())
	var catalog: Dictionary = OverworldContent.load_world().catalog
	var world := {
		"maps": maps,
		"sids": sids,
		"terrain": catalog.terrain,
		"townsfolk": catalog.townsfolk,
		"art": _pictures(),
		"footprints": _footprints(),
	}
	assert_array(_errors(StudioRules.check(world))).is_empty()


func test_a_map_the_schema_rejects_is_an_error() -> void:
	var map := _map("a", ["..."], [{"kind": "prop", "art": "crate", "at": "nowhere"}])
	var problems := StudioRules.check(_world({_path("a"): map}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "objects[0].at: must be a list", -1, NOWHERE)


func test_a_map_whose_id_is_not_its_file_name_is_an_error() -> void:
	var map := _map("tavern", ["..."])
	var problems := StudioRules.check(_world({_path("inn"): map}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", 'map id "tavern" is not its file name "inn"', -1, NOWHERE)


func test_two_things_on_one_cell_is_an_error() -> void:
	var map := _map("a", ["....", "...."], [_prop("crate", [2, 1]), _prop("barrel", [2, 1])])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [10, 11]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "barrel at 2, 1: two things stand on this cell", 11, Vector2i(2, 1))


func test_a_thing_off_the_map_is_an_error() -> void:
	var map := _map("a", ["....", "...."], [_prop("crate", [9, 9])])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [7]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "crate at 9, 9: stands off the map", 7, Vector2i(9, 9))


func test_a_start_off_the_map_is_an_error() -> void:
	var map := _map("a", ["....", "...."], [], [7, 7])
	var problems := StudioRules.check(_world({_path("a"): map}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "the start at 7, 7 is off the map", -1, Vector2i(7, 7))


func test_a_ground_character_not_in_the_legend_is_an_error() -> void:
	var map := _map("a", ["...", ".?."])
	var problems := StudioRules.check(_world({_path("a"): map}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "ground row 1 column 1: ? is not in the legend", -1, Vector2i(1, 1))


func test_a_picture_that_does_not_exist_is_an_error() -> void:
	var map := _map("a", [".....", "....."], [_prop("barel", [3, 1])])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [4]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", 'barel at 3, 1: no picture "barel"', 4, Vector2i(3, 1))


func test_a_person_who_is_not_one_of_the_townsfolk_is_an_error() -> void:
	var map := _map("a", ["...", "..."], [_person("stranger", [1, 1])])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [3]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "stranger at 1, 1: not one of the townsfolk", 3, Vector2i(1, 1))


func test_a_person_placed_twice_on_one_map_is_an_error() -> void:
	var map := _map("a", ["....", "...."], [_person("pip", [1, 1]), _person("pip", [3, 1])])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [4, 5]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "pip at 3, 1: already placed at 1, 1 in a.jsonc", 5, Vector2i(3, 1))


func test_a_person_placed_on_two_maps_is_an_error_on_the_later_map() -> void:
	var a := _map("a", ["...", "..."], [_person("pip", [1, 1])])
	var b := _map("b", ["...", "..."], [_person("pip", [2, 1])])
	var problems := StudioRules.check(_world({_path("a"): a, _path("b"): b}, {_path("a"): [1], _path("b"): [9]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "pip at 2, 1: already placed at 1, 1 in a.jsonc", 9, Vector2i(2, 1))
	assert_str(problems[0].file).is_equal(_path("b"))


func test_a_warp_to_a_map_that_is_not_there_is_an_error() -> void:
	var map := _map("a", ["....", "...."], [_warp([2, 1], "nowhere", [1, 1])], [0, 0])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [3]}))
	assert_array(problems).has_size(1)
	_expect(
		problems[0], "error", 'warp at 2, 1: leads to map "nowhere", which is not one of the maps', 3, Vector2i(2, 1)
	)


func test_a_door_to_a_map_that_is_not_there_is_an_error() -> void:
	var inn := {
		"kind": "building",
		"art": "inn",
		"at": [1, 1],
		"size": [2, 1],
		"door": [0, 0],
		"to": {"map": "nowhere", "at": [0, 0]},
	}
	var map := _map("a", ["....", "....", "...."], [inn])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [6]}))
	assert_array(problems).has_size(1)
	_expect(
		problems[0],
		"error",
		'door of inn at 1, 1: leads to map "nowhere", which is not one of the maps',
		6,
		Vector2i(1, 1)
	)


func test_a_warp_onto_unwalkable_ground_of_its_target_is_an_error() -> void:
	var problems := _warp_into_target(["...", "..#"], [])
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "warp at 0, 1: leads to b at 2, 1, which is not walkable", 2, Vector2i(0, 1))


func test_a_warp_onto_a_solid_thing_of_its_target_is_an_error() -> void:
	var problems := _warp_into_target(["...", "..."], [_prop("crate", [1, 1])], [1, 1])
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "warp at 0, 1: leads to b at 1, 1, which is not walkable", 2, Vector2i(0, 1))


func test_a_warp_off_the_map_of_its_target_is_an_error() -> void:
	var problems := _warp_into_target(["...", "..."], [], [5, 5])
	assert_array(problems).has_size(1)
	_expect(problems[0], "error", "warp at 0, 1: leads to b at 5, 5, which is not walkable", 2, Vector2i(0, 1))


func test_a_building_with_nothing_walkable_in_front_of_its_door_is_a_warning() -> void:
	var inn := {"kind": "building", "art": "inn", "at": [1, 1], "size": [2, 1], "door": [0, 0]}
	var map := _map("a", ["....", "....", ".#..", "...."], [inn])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [8]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "warning", "door of inn at 1, 1: nothing walkable in front of it", 8, Vector2i(1, 1))


func test_a_door_the_player_cannot_reach_from_the_start_is_a_warning() -> void:
	var inn := {
		"kind": "building",
		"art": "inn",
		"at": [4, 1],
		"size": [1, 1],
		"door": [0, 0],
		"to": {"map": "a", "at": [1, 1]},
	}
	var problems := StudioRules.check(_world({_path("a"): _sealed_pocket([inn])}, {_path("a"): [2]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "warning", "door of inn at 4, 1: cannot be reached from the start", 2, Vector2i(4, 1))


func test_a_warp_the_player_cannot_reach_from_the_start_is_a_warning() -> void:
	var problems := StudioRules.check(_world({_path("a"): _sealed_pocket([_warp([4, 1], "a", [1, 1])])}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "warning", "warp at 4, 1: cannot be reached from the start", -1, Vector2i(4, 1))


## A door on a wall cell still counts as reached when the cell next to it is reached, so there is no warning.
func test_a_door_on_a_wall_next_to_a_reached_cell_is_not_a_warning() -> void:
	var inn := {
		"kind": "building",
		"art": "inn",
		"at": [2, 1],
		"size": [1, 1],
		"door": [0, 0],
		"to": {"map": "a", "at": [1, 1]},
	}
	var map := _map("a", ["....", "..#.", "....", "...."], [inn], [1, 1])
	assert_array(StudioRules.check(_world({_path("a"): map}))).is_empty()


func test_a_picture_drawn_for_another_footprint_is_a_warning() -> void:
	var map := _map("a", ["....", "....", "...."], [_prop("crate", [1, 1])])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [5]}, {"crate": [2, 2]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "warning", "crate at 1, 1: size 1 x 1, but its picture is drawn for 2 x 2", 5, Vector2i(1, 1))


func test_a_deliberately_resized_picture_uses_its_native_footprint() -> void:
	var object := _prop("crate", [1, 1])
	object["size"] = [2, 2]
	object["art_size"] = [1, 1]
	var map := _map("a", ["....", "....", "....", "...."], [object])
	assert_array(StudioRules.check(_world({_path("a"): map}, {}, {"crate": [1, 1]}))).is_empty()


func test_a_thing_that_takes_code_is_drawn_per_tile_so_its_one_tile_picture_fits() -> void:
	var gate := _prop("crate", [1, 1])
	gate["size"] = [2, 1]
	gate["id"] = "plot-gate"
	gate["solid_unless"] = "open"
	gate["program"] = {"hook": "on_use", "fields": {"open": {"type": "bool", "default": false}}}
	var map := _map("a", ["....", "....", "...."], [gate])
	assert_array(StudioRules.check(_world({_path("a"): map}, {}, {"crate": [1, 1]}))).is_empty()


func test_a_solid_thing_on_water_is_a_warning() -> void:
	var map := _map("a", ["....", ".~..", "...."], [_prop("crate", [1, 1])])
	var problems := StudioRules.check(_world({_path("a"): map}, {_path("a"): [6]}))
	assert_array(problems).has_size(1)
	_expect(problems[0], "warning", "crate at 1, 1: water under it", 6, Vector2i(1, 1))


func test_a_thing_that_is_not_solid_on_water_is_not_a_warning() -> void:
	var crate := _prop("crate", [1, 1])
	crate["solid"] = false
	var map := _map("a", ["....", ".~..", "...."], [crate])
	assert_array(StudioRules.check(_world({_path("a"): map}))).is_empty()


func test_errors_come_before_warnings() -> void:
	var map := _map("a", ["....", "...."], [_prop("crate", [3, 0]), _prop("barel", [1, 1])])
	var problems := StudioRules.check(_world({_path("a"): map}, {}, {"crate": [2, 2]}))
	assert_array(problems).has_size(2)
	_expect(problems[0], "error", 'barel at 1, 1: no picture "barel"', -1, Vector2i(1, 1))
	_expect(problems[1], "warning", "crate at 3, 0: size 1 x 1, but its picture is drawn for 2 x 2", -1, Vector2i(3, 0))


func _path(id: String) -> String:
	return "res://content/packs/test/maps/%s.jsonc" % id


## A map of grass ('.'), walls ('#') and water ('~'), with the given things and start.
func _map(id: String, rows: Array, objects: Array = [], start := [0, 0]) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"legend": {".": "grass", "#": "wall", "~": "water"},
		"ground": rows,
		"start": start,
		"facing": "down",
		"objects": objects,
	}


func _prop(art: String, at: Array) -> Dictionary:
	return {"kind": "prop", "art": art, "at": at}


func _person(id: String, at: Array) -> Dictionary:
	return {"kind": "person", "id": id, "at": at, "facing": "down"}


func _warp(at: Array, map: String, to_at: Array) -> Dictionary:
	return {"kind": "warp", "at": at, "to": {"map": map, "at": to_at, "facing": "down"}}


## A world of the given maps: the test terrain, two townsfolk, and a few pictures.
func _world(maps: Dictionary, sids := {}, footprints := {}) -> Dictionary:
	return {
		"maps": maps,
		"sids": sids,
		"terrain": _terrain(),
		"townsfolk": {"pip": {}, "keeper": {}},
		"art": {"crate": true, "barrel": true, "inn": true, "sign": true},
		"footprints": footprints,
	}


func _terrain() -> Dictionary:
	return {
		"grass": {"walk": true, "step": "grass"},
		"wall": {"walk": false},
		"water": {"walk": false},
		"void": {"walk": false},
	}


## Map "a" with a pocket of two grass cells at (4, 1) and (4, 2) that no walkable way reaches from the start (1, 1).
func _sealed_pocket(objects: Array) -> Dictionary:
	return _map("a", ["######", "#.##.#", "#.##.#", "######"], objects, [1, 1])


## Map "a" is a grass row with a warp to `target` on map "b", which has the given rows and things. Returns the problems
## of both maps.
func _warp_into_target(rows: Array, things: Array, target: Array = [2, 1]) -> Array[Dictionary]:
	var a := _map("a", ["....", "...."], [_warp([0, 1], "b", target)], [1, 0])
	var b := _map("b", rows, things)
	return StudioRules.check(_world({_path("a"): a, _path("b"): b}, {_path("a"): [2]}))


func _pictures() -> Dictionary:
	var art := {}
	for folder: String in ["world", "buildings", "props"]:
		for name: String in DirAccess.get_files_at("res://assets/overworld/%s" % folder):
			if name.ends_with(".png"):
				art[name.get_basename()] = true
	return art


func _footprints() -> Dictionary:
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/overworld/world/world.json"))
	var footprints := {}
	for art: String in index:
		var entry: Dictionary = index[art]
		if entry.has("footprint"):
			footprints[art] = entry.footprint
	return footprints


func _errors(problems: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for problem: Dictionary in problems:
		if problem.severity == "error":
			out.append(problem)
	return out


## One problem, checked field by field.
func _expect(problem: Dictionary, severity: String, message: String, sid: int, cell: Vector2i) -> void:
	assert_str(problem.severity).is_equal(severity)
	assert_str(problem.message).is_equal(message)
	assert_int(problem.sid).is_equal(sid)
	assert_that(problem.cell).is_equal(cell)
