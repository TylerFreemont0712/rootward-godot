extends GdUnitTestSuite

## A small map: 6 x 4, a wall in row 1, a barrel, a 2 x 2 oak, and a warp that leads back into this map.
const LAND := """// A small map for the land tests.
{
 "id": "land",
 "name": "Land",
 "legend": {"f": "floor", "w": "wall"},
 "ground": ["ffffff", "ffwwff", "ffffff", "ffffff"],
 "start": [1, 1],
 "facing": "down",
 "objects": [
  {"kind": "prop", "art": "barrel", "at": [1, 1]},
  {"kind": "prop", "art": "oak", "at": [4, 2], "size": [2, 2]},
  {"kind": "warp", "at": [0, 3], "to": {"map": "land", "at": [2, 1], "facing": "down"}}
 ]
}
"""

## Another map: two doors, one into land and one somewhere else.
const OTHER := """// A second map, whose doors lead into land and elsewhere.
{
 "id": "other",
 "name": "Other",
 "legend": {"f": "floor"},
 "ground": ["ff", "ff"],
 "objects": [
  {"kind": "warp", "at": [1, 1], "to": {"map": "land", "at": [2, 1], "facing": "up"}},
  {"kind": "warp", "at": [0, 0], "to": {"map": "elsewhere", "at": [1, 1]}}
 ]
}
"""


func _land() -> StudioDoc:
	return StudioDoc.parse("res://test/land.jsonc", "map", LAND).doc


func _other() -> StudioDoc:
	return StudioDoc.parse("res://test/other.jsonc", "map", OTHER).doc


func _cells(list: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in list:
		out.append(cell)
	return out


## The data (as JSON text, so key order counts) and the sids of a doc.
func _state(doc: StudioDoc) -> String:
	return "%s %s" % [JSON.stringify(doc.data), str(doc.sids)]


# --- brushes and lines ---------------------------------------------------------------------------------------------


func test_the_brush_sizes_are_one_two_three_and_five() -> void:
	assert_array(StudioLand.BRUSHES).is_equal([1, 2, 3, 5])


func test_a_brush_of_one_paints_only_its_cell() -> void:
	assert_array(StudioLand.brush(Vector2i(3, 2), 1)).is_equal([Vector2i(3, 2)])


func test_a_brush_of_two_covers_the_cell_and_the_cells_right_of_and_below_it() -> void:
	assert_array(StudioLand.brush(Vector2i(3, 2), 2)).is_equal(
		[Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3)]
	)


func test_a_brush_of_three_is_the_square_round_its_cell_row_by_row() -> void:
	assert_array(StudioLand.brush(Vector2i(3, 2), 3)).is_equal(
		[
			Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
			Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
			Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3),
		]
	)


func test_a_brush_of_five_centres_on_its_cell() -> void:
	var cells := StudioLand.brush(Vector2i(3, 3), 5)
	assert_int(cells.size()).is_equal(25)
	assert_array(cells.slice(0, 2)).is_equal([Vector2i(1, 1), Vector2i(2, 1)])
	assert_array(cells.slice(23)).is_equal([Vector2i(4, 5), Vector2i(5, 5)])
	assert_bool(cells.has(Vector2i(3, 3))).is_true()


func test_a_straight_line_has_every_cell_between_its_ends() -> void:
	assert_array(StudioLand.line(Vector2i(0, 0), Vector2i(4, 0))).is_equal(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	)
	assert_array(StudioLand.line(Vector2i(2, 5), Vector2i(2, 2))).is_equal(
		[Vector2i(2, 5), Vector2i(2, 4), Vector2i(2, 3), Vector2i(2, 2)]
	)


func test_a_shallow_diagonal_line_is_exact_and_has_no_gaps() -> void:
	assert_array(StudioLand.line(Vector2i(0, 0), Vector2i(4, 1))).is_equal(
		[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	)


func test_a_long_diagonal_line_has_no_gaps_and_one_cell_per_step_plus_the_start() -> void:
	var cells := StudioLand.line(Vector2i(0, 0), Vector2i(7, 3))
	assert_int(cells.size()).is_equal(8)
	assert_array(cells.slice(0, 1)).is_equal([Vector2i(0, 0)])
	assert_array(cells.slice(7)).is_equal([Vector2i(7, 3)])
	for index in range(1, cells.size()):
		var step := (cells[index] - cells[index - 1]).abs()
		assert_bool(maxi(step.x, step.y) == 1).is_true()


func test_a_line_drawn_backwards_joins_its_ends_too() -> void:
	assert_array(StudioLand.line(Vector2i(4, 1), Vector2i(0, 0))).is_equal(
		[Vector2i(4, 1), Vector2i(3, 1), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)]
	)


func test_a_line_from_a_cell_to_itself_is_that_cell() -> void:
	assert_array(StudioLand.line(Vector2i(2, 2), Vector2i(2, 2))).is_equal([Vector2i(2, 2)])


func test_a_stroke_stamps_the_brush_at_each_cell_of_the_line_once_in_touch_order() -> void:
	assert_array(StudioLand.stroke(Vector2i(0, 0), Vector2i(2, 0), 2)).is_equal(
		[
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
			Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 0), Vector2i(3, 1),
		]
	)


func test_a_stroke_with_overlapping_brushes_has_no_repeated_cells() -> void:
	var cells := StudioLand.stroke(Vector2i(0, 0), Vector2i(3, 3), 3)
	var unique := {}
	for cell: Vector2i in cells:
		unique[cell] = true
	assert_int(cells.size()).is_equal(unique.size())
	assert_bool(cells.has(Vector2i(0, 0))).is_true()


func test_a_stroke_with_a_brush_of_one_is_the_line() -> void:
	assert_array(StudioLand.stroke(Vector2i(0, 0), Vector2i(0, 2), 1)).is_equal(
		StudioLand.line(Vector2i(0, 0), Vector2i(0, 2))
	)


func test_a_rect_fills_between_two_corners_given_in_either_order() -> void:
	var filled := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]
	assert_array(StudioLand.rect(Vector2i(1, 1), Vector2i(2, 2))).is_equal(filled)
	assert_array(StudioLand.rect(Vector2i(2, 2), Vector2i(1, 1))).is_equal(filled)


func test_clip_keeps_only_the_cells_inside_the_size() -> void:
	var cells := _cells([Vector2i(-1, 0), Vector2i(0, 0), Vector2i(5, 3), Vector2i(6, 0), Vector2i(2, 4)])
	assert_array(StudioLand.clip(cells, Vector2i(6, 4))).is_equal([Vector2i(0, 0), Vector2i(5, 3)])


# --- the fill and the legend ---------------------------------------------------------------------------------------


func test_fill_floods_the_same_character_through_its_four_neighbours() -> void:
	var rows := ["ffw", "fww", "ffw"]
	(
		assert_array(StudioLand.fill(rows, Vector2i(0, 0)))
		. contains_exactly_in_any_order(
			[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
		)
	)


func test_fill_does_not_cross_a_diagonal() -> void:
	var rows := ["fw", "wf"]
	assert_array(StudioLand.fill(rows, Vector2i(0, 0))).is_equal([Vector2i(0, 0)])
	assert_array(StudioLand.fill(rows, Vector2i(1, 1))).is_equal([Vector2i(1, 1)])


func test_fill_is_empty_when_its_start_is_off_the_rows() -> void:
	var rows := ["ff", "ff"]
	assert_array(StudioLand.fill(rows, Vector2i(2, 0))).is_empty()
	assert_array(StudioLand.fill(rows, Vector2i(0, 2))).is_empty()
	assert_array(StudioLand.fill(rows, Vector2i(-1, 0))).is_empty()


func test_char_for_is_the_first_character_of_a_kind_in_the_legend_or_empty() -> void:
	var legend := {"f": "floor", "g": "grass", "G": "grass"}
	assert_str(StudioLand.char_for(legend, "grass")).is_equal("g")
	assert_str(StudioLand.char_for(legend, "floor")).is_equal("f")
	assert_str(StudioLand.char_for(legend, "water")).is_equal("")


func test_free_char_is_the_kinds_first_letter_then_its_capital() -> void:
	assert_str(StudioLand.free_char({}, "cobble")).is_equal("c")
	assert_str(StudioLand.free_char({"c": "water"}, "cobble")).is_equal("C")
	assert_str(StudioLand.free_char({"c": "water", "C": "stone"}, "cobble")).is_equal("#")


func test_free_char_moves_on_to_the_letters_once_the_symbols_are_used() -> void:
	var legend := {"c": "water", "C": "stone"}
	var symbols := "#%&+-:;<>?@^_|"
	for index in symbols.length():
		legend[symbols.substr(index, 1)] = "x"
	assert_str(StudioLand.free_char(legend, "cobble")).is_equal("a")


func test_free_char_never_gives_a_quote_a_backslash_or_a_space() -> void:
	assert_str(StudioLand.free_char({}, " \"x")).is_equal("#")
	assert_str(StudioLand.free_char({}, "\"quoted")).is_equal("#")


# --- paint ---------------------------------------------------------------------------------------------------------


func test_paint_of_a_kind_the_legend_has_changes_only_the_cells_that_differ() -> void:
	var result := StudioLand.paint(_land().data, _cells([Vector2i(2, 1), Vector2i(4, 1)]), "wall")
	assert_bool(result["ok"]).is_true()
	assert_int(result["changed"]).is_equal(1)
	assert_str(result["added_char"]).is_equal("")
	assert_dict(result["command"]).is_equal(
		{"type": "batch", "name": "Paint wall", "commands": [{"type": "set_rows", "rows": {"1": "ffwwwf"}}]}
	)


func test_paint_of_a_new_kind_adds_a_free_character_to_the_legend_first() -> void:
	var doc := _land()
	var result := StudioLand.paint(doc.data, _cells([Vector2i(0, 0), Vector2i(1, 0)]), "cobble")
	assert_bool(result["ok"]).is_true()
	assert_int(result["changed"]).is_equal(2)
	assert_str(result["added_char"]).is_equal("c")
	var command: Dictionary = result["command"]
	assert_str(command["name"]).is_equal("Paint cobble")
	assert_dict(command["commands"][0]).is_equal(
		{"type": "set_map", "key": "legend", "value": {"f": "floor", "w": "wall", "c": "cobble"}}
	)
	assert_dict(command["commands"][1]).is_equal({"type": "set_rows", "rows": {"0": "ccffff"}})
	var edited: StudioDoc = StudioCommands.apply(doc, command)["doc"]
	assert_str(edited.data["ground"][0]).is_equal("ccffff")
	assert_str(edited.data["legend"]["c"]).is_equal("cobble")


func test_paint_undo_gives_back_the_same_text_for_a_known_and_a_new_kind() -> void:
	var doc := _land()
	for kind: String in ["wall", "cobble"]:
		var result := StudioLand.paint(doc.data, _cells([Vector2i(0, 0), Vector2i(4, 1)]), kind)
		var applied := StudioCommands.apply(doc, result["command"])
		var painted: StudioDoc = applied["doc"]
		var back: StudioDoc = StudioCommands.apply(painted, applied["undo"])["doc"]
		assert_str(back.to_text()).is_equal(doc.to_text())


func test_paint_refuses_when_no_cell_would_change() -> void:
	var result := StudioLand.paint(_land().data, _cells([Vector2i(2, 1)]), "wall")
	assert_bool(result["ok"]).is_false()
	assert_str(result["error"]).is_equal("nothing to paint")
	assert_bool(StudioLand.paint(_land().data, _cells([]), "wall")["ok"]).is_false()


func test_paint_clips_cells_off_the_map_and_counts_a_repeated_cell_once() -> void:
	var cells := _cells([Vector2i(-1, 0), Vector2i(6, 0), Vector2i(0, 4), Vector2i(0, 0), Vector2i(0, 0)])
	var result := StudioLand.paint(_land().data, cells, "wall")
	assert_bool(result["ok"]).is_true()
	assert_int(result["changed"]).is_equal(1)
	assert_str(result["command"]["commands"][0]["rows"]["0"]).is_equal("wfffff")


func test_paint_refuses_an_empty_kind() -> void:
	assert_bool(StudioLand.paint(_land().data, _cells([Vector2i(0, 0)]), "")["ok"]).is_false()


# --- resize --------------------------------------------------------------------------------------------------------


func test_growing_on_the_left_moves_objects_and_start_and_keeps_the_rows_text() -> void:
	var doc := _land()
	var result := StudioLand.resize(doc.data, doc.sids, {"left": 4}, "floor", "land")
	assert_bool(result["ok"]).is_true()
	assert_str(str(result["size"])).is_equal("(10, 4)")
	assert_array(result["dropped"]).is_empty()
	assert_array(result["command"]["shift"]).is_equal([4, 0])
	var applied := StudioCommands.apply(doc, result["command"])
	var edited: StudioDoc = applied["doc"]
	assert_array(edited.object_of_sid(1)["at"]).is_equal([5, 1])
	assert_array(edited.object_of_sid(2)["at"]).is_equal([8, 2])
	assert_array(edited.object_of_sid(3)["at"]).is_equal([4, 3])
	assert_array(edited.object_of_sid(3)["to"]["at"]).is_equal([6, 1])
	assert_str(edited.object_of_sid(3)["to"]["facing"]).is_equal("down")
	assert_array(edited.data["start"]).is_equal([5, 1])
	assert_str(edited.data["ground"][0]).is_equal("ffffffffff")
	assert_str(edited.data["ground"][1]).is_equal("ffffffwwff")
	var back: StudioDoc = StudioCommands.apply(edited, applied["undo"])["doc"]
	assert_str(back.to_text()).is_equal(doc.to_text())


func test_shrinking_drops_an_object_that_falls_off_and_lists_it() -> void:
	var doc := _land()
	var result := StudioLand.resize(doc.data, doc.sids, {"right": -2}, "floor", "land")
	assert_bool(result["ok"]).is_true()
	assert_str(str(result["size"])).is_equal("(4, 4)")
	var dropped: Array = result["dropped"]
	assert_int(dropped.size()).is_equal(1)
	assert_dict(dropped[0]).is_equal({"sid": 2, "kind": "prop", "art": "oak", "at": Vector2i(4, 2)})
	var applied := StudioCommands.apply(doc, result["command"])
	var edited: StudioDoc = applied["doc"]
	assert_array(edited.sids).is_equal([1, 3])
	assert_str(edited.data["ground"][1]).is_equal("ffww")
	var back: StudioDoc = StudioCommands.apply(edited, applied["undo"])["doc"]
	assert_str(back.to_text()).is_equal(doc.to_text())


func test_a_resize_that_moves_nothing_only_rewrites_the_ground() -> void:
	var doc := _land()
	var result := StudioLand.resize(doc.data, doc.sids, {"bottom": 1}, "floor", "land")
	var types: Array = []
	for command: Dictionary in result["command"]["commands"]:
		types.append(command["type"])
	assert_array(types).is_equal(["set_map"])
	assert_str(str(result["size"])).is_equal("(6, 5)")


func test_a_resize_refuses_a_map_below_one_cell_each_way() -> void:
	var doc := _land()
	assert_bool(StudioLand.resize(doc.data, doc.sids, {"right": -6}, "floor", "land")["ok"]).is_false()
	assert_bool(StudioLand.resize(doc.data, doc.sids, {"top": -4, "bottom": -1}, "floor", "land")["ok"]).is_false()


func test_a_map_can_grow_to_the_supported_ceiling_but_not_beyond_it() -> void:
	var doc := _land()
	var grown := StudioLand.resize(doc.data, doc.sids, {"right": StudioLand.MAX_DIMENSION - 6}, "floor", "land")
	assert_bool(grown.ok).is_true()
	assert_str(str(grown.size)).is_equal("(128, 4)")
	var too_wide := StudioLand.resize(doc.data, doc.sids, {"right": StudioLand.MAX_DIMENSION - 5}, "floor", "land")
	assert_bool(too_wide.ok).is_false()
	assert_str(too_wide.error).contains("at most 128 x 128")


func test_a_resize_refuses_a_start_that_falls_off_the_map() -> void:
	var doc := _land()
	var left := StudioLand.resize(doc.data, doc.sids, {"left": -2}, "floor", "land")
	assert_bool(left["ok"]).is_false()
	assert_bool(String(left["error"]).contains("start")).is_true()
	assert_bool(StudioLand.resize(doc.data, doc.sids, {"top": -2}, "floor", "land")["ok"]).is_false()
	assert_bool(StudioLand.resize(doc.data, doc.sids, {"left": -1}, "floor", "land")["ok"]).is_true()


func test_a_resize_with_a_fill_kind_missing_from_the_legend_grows_the_legend_first() -> void:
	var doc := _land()
	var result := StudioLand.resize(doc.data, doc.sids, {"bottom": 1}, "grass", "land")
	var commands: Array = result["command"]["commands"]
	assert_dict(commands[0]).is_equal(
		{"type": "set_map", "key": "legend", "value": {"f": "floor", "w": "wall", "g": "grass"}}
	)
	var edited: StudioDoc = StudioCommands.apply(doc, result["command"])["doc"]
	assert_str(edited.data["ground"][4]).is_equal("gggggg")
	assert_str(edited.data["legend"]["g"]).is_equal("grass")


func test_a_link_into_another_map_is_not_moved_by_a_resize() -> void:
	var door: StudioDoc = StudioDoc.parse(
		"res://test/door.jsonc",
		"map",
		'{"id": "land", "legend": {"f": "floor"}, "ground": ["ff", "ff"], "start": [0, 0], "objects": [{"kind": "warp", "at": [1, 1], "to": {"map": "other", "at": [2, 2]}}]}'
	).doc
	var result := StudioLand.resize(door.data, door.sids, {"left": 1}, "floor", "land")
	var types: Array = []
	for command: Dictionary in result["command"]["commands"]:
		types.append(command["type"])
	assert_array(types).is_equal(["move", "set_map", "set_map"])


func test_links_into_lists_the_objects_that_lead_into_a_map() -> void:
	var other := _other()
	assert_array(StudioLand.links_into(other.data, "land")).is_equal([0])
	assert_array(StudioLand.links_into(other.data, "elsewhere")).is_equal([1])
	assert_array(StudioLand.links_into(other.data, "nowhere")).is_empty()


func test_follow_moves_the_doors_of_another_map_into_a_resized_map() -> void:
	var other := _other()
	var command := StudioLand.follow(other.data, other.sids, "land", Vector2i(4, 0))
	assert_str(command["name"]).is_equal("Follow land's new size")
	var applied := StudioCommands.apply(other, command)
	var edited: StudioDoc = applied["doc"]
	assert_array(edited.object_of_sid(1)["to"]["at"]).is_equal([6, 1])
	assert_str(edited.object_of_sid(1)["to"]["facing"]).is_equal("up")
	assert_dict(edited.object_of_sid(2)["to"]).is_equal({"map": "elsewhere", "at": [1, 1]})
	var back: StudioDoc = StudioCommands.apply(edited, applied["undo"])["doc"]
	assert_str(back.to_text()).is_equal(other.to_text())


func test_follow_is_empty_when_nothing_moved_or_nothing_leads_there() -> void:
	var other := _other()
	assert_dict(StudioLand.follow(other.data, other.sids, "land", Vector2i.ZERO)).is_empty()
	assert_dict(StudioLand.follow(other.data, other.sids, "nowhere", Vector2i(1, 0))).is_empty()
