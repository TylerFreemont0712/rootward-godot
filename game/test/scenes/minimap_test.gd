extends GdUnitTestSuite
## Lanternroot's minimap (v0.4, Concept/v0.4/01 section 9.2): the picture is baked in the player's colours (ground by
## ground, solid footprints by their kind), the player's dot sits on its cell, and it appears only once enabled.

const TERRAIN := {"grass": {"walk": true}, "water": {"walk": false}, "path": {"walk": true}}
const COLOURS := {
	"grass": Color("#6fbf5b"),
	"water": Color("#4a90d9"),
	"path": Color("#d8b878"),
	"building": Color("#8a4f2c"),
	"tree": Color("#2f6b34"),
	"thing": Color("#e2c04f"),
}
## Four by three: water in the middle, a house, an oak, a barrel, and a rug (not solid) in the corners.
const DATA := {
	"id": "small",
	"name": "Small",
	"legend": {".": "grass", "~": "water", ",": "path"},
	"ground": ["....", ".~~.", ",..."],
	"objects":
	[
		{"kind": "building", "art": "home", "at": [0, 0], "size": [1, 1], "door": [0, 0], "to": {"map": "x", "at": [0, 0]}},
		{"kind": "prop", "art": "oak", "at": [1, 0]},
		{"kind": "prop", "art": "barrel", "at": [2, 0]},
		{"kind": "prop", "art": "rug", "at": [3, 0], "solid": false},
		{"kind": "building", "art": "shop", "at": [3, 2], "size": [1, 1], "door": [0, 0]},
	],
	"start": [0, 2],
}

var minimap: Minimap
var map: Dictionary


func before_test() -> void:
	map = OverworldMap.build(DATA, TERRAIN).map
	minimap = Minimap.new()
	add_child(minimap)
	minimap.setup({})


func after_test() -> void:
	minimap.free()


func _same(got: Color, want: Color) -> void:
	assert_str(got.to_html(false)).is_equal(want.to_html(false))


func test_a_water_cell_is_baked_in_the_players_water_colour() -> void:
	minimap.show_map(map, COLOURS)
	_same(minimap.colour_at(Vector2i(1, 1)), COLOURS.water)
	_same(minimap.colour_at(Vector2i(2, 1)), COLOURS.water)
	_same(minimap.colour_at(Vector2i(0, 1)), COLOURS.grass)
	_same(minimap.colour_at(Vector2i(0, 2)), COLOURS.path)


func test_solid_footprints_take_the_colour_of_their_kind() -> void:
	minimap.show_map(map, COLOURS)
	# A house whose door leads somewhere keeps its door open, so that cell is ground; the shop's is shut.
	_same(minimap.colour_at(Vector2i(0, 0)), COLOURS.grass)
	_same(minimap.colour_at(Vector2i(3, 2)), COLOURS.building)
	_same(minimap.colour_at(Vector2i(1, 0)), COLOURS.tree)
	_same(minimap.colour_at(Vector2i(2, 0)), COLOURS.thing)
	# A rug is not solid: the ground shows.
	_same(minimap.colour_at(Vector2i(3, 0)), COLOURS.grass)


func test_names_the_player_left_out_fall_back_to_the_stand_in_greys() -> void:
	minimap.show_map(map, {})
	_same(minimap.colour_at(Vector2i(1, 1)), Minimap.STAND_IN.water)
	_same(minimap.colour_at(Vector2i(1, 0)), Minimap.STAND_IN.tree)


func test_the_picture_is_scaled_to_fit_and_centred() -> void:
	minimap.show_map(map, COLOURS)
	# Four by three cells in 228 x 156: a room is scaled up, at most 14 px a cell.
	assert_float(minimap.cell_scale()).is_equal(Minimap.MAX_CELL)
	var image := minimap.baked()
	assert_vector(Vector2(image.get_size())).is_equal(Vector2(56, 42))
	var rect := minimap.cell_rect(Vector2i(0, 0))
	assert_vector(rect.position).is_equal(Vector2(floorf((240.0 - 56.0) / 2.0), floorf((168.0 - 42.0) / 2.0)))
	# The town's 80 by 56 cells come to about 3 px a cell.
	var town: Dictionary = OverworldMap.build({"id": "t", "legend": {".": "grass"}, "ground": _rows(80, 56), "objects": [], "start": [0, 0]}, TERRAIN).map
	minimap.show_map(town, COLOURS)
	assert_float(minimap.cell_scale()).is_between(2.7, 3.0)
	assert_vector(Vector2(minimap.baked().get_size())).is_less_equal(Vector2(228, 156))


func _rows(width: int, height: int) -> Array:
	var rows: Array = []
	for y in height:
		rows.append(".".repeat(width))
	return rows


func test_the_player_dot_sits_on_its_cell() -> void:
	minimap.show_map(map, COLOURS)
	minimap.set_player(Vector2i(2, 1))
	var centre := minimap.cell_centre(Vector2i(2, 1))
	assert_vector(centre).is_equal(Vector2(floorf(184.0 / 2.0) + 2.0 * 14.0 + 7.0, floorf(126.0 / 2.0) + 1.0 * 14.0 + 7.0))
	assert_bool(Rect2(Vector2.ZERO, Minimap.SIZE).has_point(centre)).is_true()
	assert_bool(minimap.cell_rect(Vector2i(2, 1)).has_point(centre)).is_true()


func test_it_appears_only_once_the_map_part_is_built() -> void:
	assert_bool(minimap.is_enabled()).is_false()
	assert_bool(minimap.visible).is_false()
	minimap.set_enabled(true)
	assert_bool(minimap.is_enabled()).is_true()
	assert_bool(minimap.visible).is_true()
	minimap.set_enabled(false)
	await get_tree().create_timer(0.4).timeout
	assert_bool(minimap.visible).is_false()


func test_the_line_joins_the_place_and_the_clock_and_hides_when_both_are_empty() -> void:
	minimap.set_line("Warm Hearth Row", "18:40")
	assert_str(minimap.line_text()).is_equal("Warm Hearth Row · 18:40")
	minimap.set_line("", "18:40")
	assert_str(minimap.line_text()).is_equal("18:40")
	minimap.set_line("Lantern Square", "")
	assert_str(minimap.line_text()).is_equal("Lantern Square")
	var base := minimap.custom_minimum_size.y
	minimap.set_line("", "")
	assert_str(minimap.line_text()).is_empty()
	assert_bool((minimap.get_node("Line") as Label).visible).is_false()
	assert_float(minimap.custom_minimum_size.y).is_equal(Minimap.SIZE.y)
	assert_float(base).is_greater(Minimap.SIZE.y)


func test_a_click_on_the_map_opens_the_full_map() -> void:
	var fired := [0]
	minimap.open_full.connect(func() -> void: fired[0] += 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(100, 80)
	minimap._gui_input(click)
	assert_int(fired[0]).is_equal(1)
	assert_bool(minimap._has_point(Vector2(100, 80))).is_true()
	assert_bool(minimap._has_point(Vector2(100, 190))).is_false()


func test_the_kinds_tell_buildings_trees_and_other_things_apart() -> void:
	assert_str(Minimap.kind_of({"kind": "building", "art": "inn"})).is_equal("building")
	assert_str(Minimap.kind_of({"kind": "prop", "art": "oak2"})).is_equal("tree")
	assert_str(Minimap.kind_of({"kind": "prop", "art": "expand-willow-tree"})).is_equal("tree")
	assert_str(Minimap.kind_of({"kind": "prop", "art": "barrel"})).is_equal("thing")
	assert_str(Minimap.kind_of({"kind": "sign", "art": "sign"})).is_equal("thing")
	assert_str(Minimap.kind_of({"kind": "person", "id": "pip"})).is_empty()
