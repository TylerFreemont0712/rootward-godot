extends GdUnitTestSuite
## GroundLayer.repaint (Lanternroot Studio's Land tab, Concept/v0.3/10 section 7.8): painting a few cells again gives
## exactly the picture a whole bake of the painted map gives, pixel for pixel and in every ripple frame, wherever the
## cells are (inside one piece, across pieces, on the map's edge), and it refuses what only a whole bake can show.

const LEGEND := {
	".": "grass", ",": "path", "=": "cobble", "~": "water", "*": "flowers", "f": "floor", "W": "wall", "v": "void",
	"a": "meadow", "b": "dry_grass", "c": "forest_floor", "d": "moss", "e": "soil", "g": "tilled_soil",
	"h": "sand", "i": "gravel", "j": "brick_path", "k": "stone_path", "l": "wood_path",
	"m": "root_floor", "n": "fern_moss", "o": "glow_moss",
}

var _terrain: Dictionary = {}
var _kept := false


func before() -> void:
	_terrain = OverworldContent.load_world().catalog.terrain


func before_test() -> void:
	_kept = GroundLayer.keep_images
	GroundLayer.keep_images = true


func after_test() -> void:
	GroundLayer.keep_images = _kept


## A map of `rows` as the game builds it.
func _map(rows: Array, interior := false) -> Dictionary:
	var data := {"id": "test", "name": "Test", "legend": LEGEND, "ground": rows, "objects": [], "start": [0, 0]}
	if interior:
		data["interior"] = true
	var built := OverworldMap.build(data, _terrain)
	assert_array(built.errors).is_empty()
	return built.map


## `rows` with `cells` set to `ch`.
static func _painted(rows: Array, cells: Array[Vector2i], ch: String) -> Array:
	var out := rows.duplicate()
	for cell: Vector2i in cells:
		var row := String(out[cell.y])
		out[cell.y] = row.substr(0, cell.x) + ch + row.substr(cell.x + 1)
	return out


static func _square(at: Vector2i, side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in side:
		for x in side:
			out.append(at + Vector2i(x, y))
	return out


func _layer(map: Dictionary) -> GroundLayer:
	var layer := GroundLayer.new()
	add_child(layer)
	layer.show_map(map)
	return auto_free(layer)


## Repaints `rows` into `painted` and compares every frame with a whole bake of `painted`.
func _assert_repaint_matches(rows: Array, painted: Array, interior := false) -> void:
	var layer := _layer(_map(rows, interior))
	var after := _map(painted, interior)
	assert_bool(layer.can_repaint(after)).override_failure_message("the painted map can be repainted").is_true()
	var changed := layer.changed_cells(after)
	assert_bool(changed.is_empty()).override_failure_message("the change is seen").is_false()
	assert_bool(layer.repaint(after, changed)).is_true()
	var whole := _layer(after)
	for frame in GroundLayer.frame_count_of(after, OverworldArt.terrain().layout):
		var got := layer.baked_picture(frame)
		var want := whole.baked_picture(frame)
		assert_vector(Vector2(got.get_size())).is_equal(Vector2(want.get_size()))
		assert_bool(got.get_data() == want.get_data()).override_failure_message(
			"frame %d of the repaint is the whole bake's, pixel for pixel" % frame
		).is_true()


static func _grass(width: int, height: int) -> Array:
	var rows: Array = []
	for y in height:
		rows.append(".".repeat(width))
	return rows


func test_a_five_wide_cobble_road_through_grass_repaints_as_a_whole_bake_would() -> void:
	var rows := _grass(20, 12)
	var road: Array[Vector2i] = []
	for x in 20:
		for y in range(4, 9):
			road.append(Vector2i(x, y))
	_assert_repaint_matches(rows, _painted(rows, road, "="))


func test_cells_across_the_pieces_borders_and_on_the_maps_edges() -> void:
	var rows := _grass(20, 12)
	# A piece is eight tiles; the cells either side of x = 7 and 8 and y = 7 and 8 straddle four pieces.
	var cells := _square(Vector2i(6, 6), 4)
	cells.append_array([Vector2i(0, 0), Vector2i(19, 0), Vector2i(0, 11), Vector2i(19, 11), Vector2i(10, 0)])
	_assert_repaint_matches(rows, _painted(rows, cells, ","))


func test_painting_grass_back_over_a_path_takes_its_edges_away() -> void:
	var rows := _painted(_grass(20, 12), _square(Vector2i(3, 3), 6), ",")
	_assert_repaint_matches(rows, _painted(rows, _square(Vector2i(4, 4), 2), "."))


func test_water_ripples_repaint_in_every_frame() -> void:
	var rows := _painted(_grass(20, 12), _square(Vector2i(2, 2), 3), "~")
	var painted := _painted(rows, _square(Vector2i(9, 5), 4), "~")
	painted = _painted(painted, [Vector2i(10, 6), Vector2i(11, 6)] as Array[Vector2i], "*")
	_assert_repaint_matches(rows, painted)


func test_repeated_path_and_water_tiles_vary_by_position_deterministically() -> void:
	var rows := _grass(24, 16)
	for at: Vector2i in [Vector2i(2, 2), Vector2i(14, 2)]:
		rows = _painted(rows, _square(at, 3), ",")
	for at: Vector2i in [Vector2i(2, 9), Vector2i(14, 9)]:
		rows = _painted(rows, _square(at, 3), "~")
	var shown := _map(rows)
	var first := _layer(shown).baked_picture()
	var repeat := _layer(shown).baked_picture()
	var pairs: Array = [
		[Vector2i(3, 3), Vector2i(15, 3)],
		[Vector2i(3, 10), Vector2i(15, 10)],
	]
	for pair: Array in pairs:
		var left_cell: Vector2i = pair[0]
		var right_cell: Vector2i = pair[1]
		var left := first.get_region(_cell_pixels(left_cell))
		var right := first.get_region(_cell_pixels(right_cell))
		assert_bool(left.get_data() != right.get_data()).override_failure_message(
			"repeated %s cells have subtle terrain variation" % _ground_name(left_cell, rows)
		).is_true()
		assert_bool(left.get_data() == repeat.get_region(_cell_pixels(left_cell)).get_data()).is_true()
		assert_bool(right.get_data() == repeat.get_region(_cell_pixels(right_cell)).get_data()).is_true()


func test_every_outdoor_ground_uses_several_stable_authored_textures() -> void:
	for glyph: String in [".", ",", "=", "~", "*", "a", "b", "c", "d", "e", "g", "h", "i", "j", "k", "l", "m", "n", "o"]:
		var rows: Array[String] = []
		for y in 8:
			rows.append(glyph.repeat(12))
		var shown := _map(rows)
		var first := _layer(shown).baked_picture()
		var repeat := _layer(shown).baked_picture()
		assert_bool(first.get_data() == repeat.get_data()).override_failure_message("%s is stable across reload" % LEGEND[glyph]).is_true()
		var samples := {}
		for y in range(2, 6):
			for x in range(2, 10):
				samples[first.get_region(_cell_pixels(Vector2i(x, y))).get_data().hex_encode().sha256_text()] = true
		assert_int(samples.size()).override_failure_message("%s has varied cells" % LEGEND[glyph]).is_greater(3)


func test_all_eighteen_overlay_layers_repaint_exactly_across_chunks_and_map_edges() -> void:
	var rows := _grass(28, 16)
	var painted := rows.duplicate()
	var glyphs: Array[String] = ["a", "b", "c", "d", "*", "e", "g", ",", "i", "h", "=", "~", "j", "k", "l", "m", "n", "o"]
	for index in glyphs.size():
		var at := Vector2i((index % 6) * 4, 1 + (index / 6) * 5)
		rows = _painted(rows, _square(at, 3), glyphs[index])
		painted = _painted(painted, _square(at + Vector2i.ONE, 4), glyphs[index])
	_assert_repaint_matches(rows, painted)


func test_three_tile_wide_paths_keep_rims_only_at_the_outer_edges() -> void:
	for kind: String in ["path", "brick_path", "stone_path", "wood_path"]:
		var glyph := StudioLand.char_for(LEGEND, kind)
		var rows := _grass(9, 9)
		for y in range(1, 8):
			rows = _painted(rows, [Vector2i(3, y), Vector2i(4, y), Vector2i(5, y)] as Array[Vector2i], glyph)
		var layer := _layer(_map(rows))
		var index := layer._overlays.find(kind)
		var plane := floori(float(index) / GroundLayer.MASK_LAYERS)
		var shift := (index % GroundLayer.MASK_LAYERS) * 4
		var inside: int = (layer._masks_at(Vector2i(4, 4), plane) >> shift) & 15
		var left_edge: int = (layer._masks_at(Vector2i(3, 4), plane) >> shift) & 15
		var right_edge: int = (layer._masks_at(Vector2i(6, 4), plane) >> shift) & 15
		assert_int(inside).override_failure_message("%s has no border along the 3-wide interior" % kind).is_equal(15)
		assert_int(left_edge).override_failure_message("%s has an exposed left edge" % kind).is_equal(10)
		assert_int(right_edge).override_failure_message("%s has an exposed right edge" % kind).is_equal(5)


func test_texture_variation_does_not_change_walkability_or_ripple_frames() -> void:
	var shown := _map([".abcdeghi,=~", ".abcdeghi,=~"])
	var walk: PackedByteArray = shown.walk
	for y in 2:
		for x in 12:
			assert_int(walk[y * 12 + x]).is_equal(0 if x == 11 else 1)
	assert_int(GroundLayer.frame_count_of(shown, OverworldArt.terrain().layout)).is_equal(3)
	var layer := _layer(shown)
	assert_bool(layer.baked_picture(0).get_data() != layer.baked_picture(1).get_data()).is_true()


func _cell_pixels(cell: Vector2i) -> Rect2i:
	var margin := Vector2i(GroundLayer.MARGIN, GroundLayer.MARGIN)
	var size := Vector2i(GroundLayer.TILE, GroundLayer.TILE)
	return Rect2i(cell * GroundLayer.TILE + margin, size)


func _ground_name(cell: Vector2i, rows: Array) -> String:
	return "path" if String(rows[cell.y])[cell.x] == "," else "water"


func test_an_interior_repaints_its_floor_and_walls() -> void:
	var rows: Array = ["WWWWWWWWWW", "ffffffffff", "ffffffffff", "ffffffffff", "vvvvvvvvvv"]
	_assert_repaint_matches(rows, _painted(rows, [Vector2i(3, 1), Vector2i(4, 2), Vector2i(9, 3)] as Array[Vector2i], "W"), true)


func test_without_kept_images_a_repaint_is_still_exact() -> void:
	GroundLayer.keep_images = false
	var rows := _grass(20, 12)
	_assert_repaint_matches(rows, _painted(rows, _square(Vector2i(7, 7), 3), "="))


func test_another_size_or_water_coming_needs_a_whole_bake() -> void:
	var layer := _layer(_map(_grass(20, 12)))
	assert_bool(layer.can_repaint(_map(_grass(21, 12)))).override_failure_message("another width").is_false()
	var wet := _map(_painted(_grass(20, 12), [Vector2i(3, 3)] as Array[Vector2i], "~"))
	assert_bool(layer.can_repaint(wet)).override_failure_message("water needs three frames where there was one").is_false()
	assert_bool(layer.repaint(wet, layer.changed_cells(wet))).is_false()


func test_the_town_view_paints_only_the_ground() -> void:
	var view := TownMapView.new({})
	add_child(view)
	auto_free(view)
	var rows := _grass(20, 12)
	view.show_map(_map(rows))
	var painted := _map(_painted(rows, _square(Vector2i(5, 5), 5), "="))
	assert_bool(view.paint_ground(painted)).is_true()
	assert_bool(view.ground.map.ground == painted.ground).override_failure_message("the ground shows the painted map").is_true()
	assert_bool(view.paint_ground(_map(_grass(24, 12)))).override_failure_message("a new size is a whole show_map").is_false()
