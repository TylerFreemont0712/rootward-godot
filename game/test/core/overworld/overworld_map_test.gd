extends GdUnitTestSuite
## A map built from content (ADR-0061): ground through the legend, a house solid but for its door, which leads inside,
## props and signs in the way, people listed, and mistakes reported instead of hidden.

const TERRAIN := {"grass": {"walk": true}, "path": {"walk": true}, "water": {"walk": false}, "void": {"walk": false}}
const DATA := {
	"id": "test-town",
	"legend": {".": "grass", ",": "path", "~": "water"},
	"ground": ["......", "..,,..", "..,,~~", "......"],
	"start": [0, 0],
	"objects":
	[
		{
			"kind": "building",
			"art": "cottage",
			"at": [0, 1],
			"size": [2, 2],
			"door": [1, 1],
			"to": {"map": "cottage", "at": [2, 3]}
		},
		{"kind": "sign", "at": [5, 0], "text": "Lanternroot"},
		{"kind": "prop", "art": "flowers", "at": [5, 3], "solid": false},
		{"kind": "person", "id": "pip", "at": [3, 3]},
	],
}


func _map() -> Dictionary:
	var built := OverworldMap.build(DATA, TERRAIN)
	assert_array(built.errors).is_empty()
	return built.map


func test_ground_comes_through_the_legend() -> void:
	var map := _map()
	assert_int(map.width).is_equal(6)
	assert_int(map.height).is_equal(4)
	assert_str(OverworldMap.terrain_at(map, Vector2i(2, 1))).is_equal("path")
	assert_bool(OverworldMap.blocked(map, Vector2i(4, 2))).is_true()
	assert_bool(OverworldMap.blocked(map, Vector2i(2, 1))).is_false()


func test_a_house_is_solid_but_its_door_leads_inside() -> void:
	var map := _map()
	assert_bool(OverworldMap.blocked(map, Vector2i(0, 1))).is_true()
	assert_bool(OverworldMap.blocked(map, Vector2i(1, 2))).is_false()
	var warp := OverworldMap.warp_at(map, Vector2i(1, 2))
	assert_str(warp.map).is_equal("cottage")
	assert_that(warp.at).is_equal(Vector2i(2, 3))


func test_a_building_can_leave_its_roof_walkable_while_keeping_its_walls_solid() -> void:
	var data: Dictionary = DATA.duplicate(true)
	var building: Dictionary = data.objects[0]
	building["solid_rows"] = [1]
	var built := OverworldMap.build(data, TERRAIN)
	assert_array(built.errors).is_empty()
	var map: Dictionary = built.map
	assert_bool(OverworldMap.blocked(map, Vector2i(0, 1))).is_false()
	assert_bool(OverworldMap.blocked(map, Vector2i(0, 2))).is_true()
	assert_bool(OverworldMap.blocked(map, Vector2i(1, 2))).is_false()
	assert_that(OverworldMap.warp_at(map, Vector2i(1, 2)).map).is_equal("cottage")


func test_a_building_can_use_sparse_collision_for_a_tree_trunk_and_roots() -> void:
	var data: Dictionary = DATA.duplicate(true)
	var building: Dictionary = data.objects[0]
	building["solid_cells"] = [[0, 0], [0, 1], [1, 1]]
	var built := OverworldMap.build(data, TERRAIN)
	assert_array(built.errors).is_empty()
	var map: Dictionary = built.map
	assert_bool(OverworldMap.blocked(map, Vector2i(0, 1))).is_true()
	assert_bool(OverworldMap.blocked(map, Vector2i(0, 2))).is_true()
	assert_bool(OverworldMap.blocked(map, Vector2i(1, 2))).is_false()
	assert_bool(OverworldMap.blocked(map, Vector2i(1, 1))).is_false()


func test_an_empty_collision_mask_keeps_its_linked_door() -> void:
	var data: Dictionary = DATA.duplicate(true)
	(data.objects[0] as Dictionary)["solid_cells"] = []
	var built := OverworldMap.build(data, TERRAIN)
	assert_array(built.errors).is_empty()
	assert_bool(OverworldMap.blocked(built.map, Vector2i(0, 1))).is_false()
	assert_bool(OverworldMap.blocked(built.map, Vector2i(1, 2))).is_false()
	assert_str(OverworldMap.warp_at(built.map, Vector2i(1, 2)).map).is_equal("cottage")


func test_signs_block_and_flowers_do_not() -> void:
	var map := _map()
	assert_bool(OverworldMap.blocked(map, Vector2i(5, 0))).is_true()
	assert_str(OverworldMap.thing_at(map, Vector2i(5, 0)).text).is_equal("Lanternroot")
	assert_bool(OverworldMap.blocked(map, Vector2i(5, 3))).is_false()


func test_people_are_listed_and_block_where_they_stand_now() -> void:
	var map := _map()
	assert_int((map.people as Array).size()).is_equal(1)
	assert_bool(OverworldMap.blocked(map, Vector2i(3, 3), {Vector2i(3, 3): "pip"})).is_true()


func test_off_the_map_is_blocked_and_ahead_follows_facing() -> void:
	var map := _map()
	assert_bool(OverworldMap.blocked(map, Vector2i(-1, 0))).is_true()
	assert_that(OverworldMap.ahead(Vector2i(2, 2), "up")).is_equal(Vector2i(2, 1))


func test_mistakes_are_reported() -> void:
	var broken := DATA.duplicate(true)
	broken.ground[1] = "..?"
	var building: Dictionary = broken.objects[0]
	building["solid_rows"] = [2]
	broken.objects.append({"kind": "prop", "at": [5, 0]})
	broken.objects.append({"kind": "dragon", "at": [1, 0]})
	var errors: Array = OverworldMap.build(broken, TERRAIN).errors
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("is 3 wide"))).is_true()
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("not in the legend"))).is_true()
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("solid row outside its footprint"))).is_true()
	building.erase("solid_rows")
	building["solid_cells"] = [[2, 2]]
	var bad_cell_errors: Array = OverworldMap.build(broken, TERRAIN).errors
	assert_bool(bad_cell_errors.any(func(e: String) -> bool: return e.contains("solid cell outside its footprint"))).is_true()
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("two things stand on"))).is_true()
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("unknown kind dragon"))).is_true()
