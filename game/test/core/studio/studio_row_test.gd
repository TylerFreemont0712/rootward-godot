extends GdUnitTestSuite
## StudioRow: the cells of a Shift-drag row.

const LINES := {
	"wall": {"line": {"horizontal": "wall", "vertical": "wall_v"}},
	"wall_v": {"line": {"horizontal": "wall", "vertical": "wall_v"}},
	"corner": {},
}


func test_line_drag_turns_both_ways_and_keeps_instance_properties() -> void:
	var template := {"kind": "prop", "art": "wall", "solid": false, "group": "garden", "flip": true}
	var vertical := StudioRow.oriented(template, Vector2i(2, 8), Vector2i(3, 2), LINES)
	assert_str(vertical.art).is_equal("wall_v")
	assert_bool(vertical.solid).is_false()
	assert_bool(vertical.flip).is_true()
	assert_str(vertical.group).is_equal("garden")
	assert_str(template.art).is_equal("wall")
	assert_str(StudioRow.oriented(vertical, Vector2i.ZERO, Vector2i(4, 1), LINES).art).is_equal("wall")
	assert_str(StudioRow.oriented(vertical, Vector2i.ZERO, Vector2i.ZERO, LINES).art).is_equal("wall_v")


func test_only_complete_line_pairs_of_single_cell_props_use_default_drag() -> void:
	assert_bool(StudioRow.is_line({"kind": "prop", "art": "wall"}, LINES)).is_true()
	assert_bool(StudioRow.is_line({"kind": "prop", "art": "corner"}, LINES)).is_false()
	assert_bool(StudioRow.is_line({"kind": "prop", "art": "wall", "program": "cabbage-gate"}, LINES)).is_false()
	assert_bool(StudioRow.is_line({"kind": "prop", "art": "wall", "size": [2, 1]}, LINES)).is_false()
	assert_bool(StudioRow.is_line({"kind": "person", "art": "wall"}, LINES)).is_false()
	assert_bool(StudioRow.is_line({"kind": "prop", "art": "wall"}, {"wall": LINES.wall})).is_false()


func _xs(cells: Array[Vector2i]) -> Array[int]:
	var out: Array[int] = []
	for cell: Vector2i in cells:
		out.append(cell.x)
	return out


func _ys(cells: Array[Vector2i]) -> Array[int]:
	var out: Array[int] = []
	for cell: Vector2i in cells:
		out.append(cell.y)
	return out


func test_one_by_one_pieces_fill_every_cell_to_the_right() -> void:
	var cells := StudioRow.cells(Vector2i(2, 6), Vector2i(11, 6), Vector2i.ONE)
	assert_int(cells.size()).is_equal(10)
	assert_array(_xs(cells)).is_equal([2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
	assert_array(_ys(cells)).is_equal([6, 6, 6, 6, 6, 6, 6, 6, 6, 6])


func test_dragging_left_goes_left_from_the_start() -> void:
	var cells := StudioRow.cells(Vector2i(8, 3), Vector2i(5, 3), Vector2i.ONE)
	assert_array(_xs(cells)).is_equal([8, 7, 6, 5])


func test_dragging_up_and_down_is_vertical() -> void:
	var up := StudioRow.cells(Vector2i(4, 9), Vector2i(4, 6), Vector2i.ONE)
	assert_array(_ys(up)).is_equal([9, 8, 7, 6])
	assert_array(_xs(up)).is_equal([4, 4, 4, 4])
	var down := StudioRow.cells(Vector2i(4, 2), Vector2i(4, 4), Vector2i.ONE)
	assert_array(_ys(down)).is_equal([2, 3, 4])


func test_a_mostly_vertical_diagonal_is_vertical_and_a_tie_is_horizontal() -> void:
	var tall := StudioRow.cells(Vector2i(3, 3), Vector2i(5, 8), Vector2i.ONE)
	assert_array(_ys(tall)).is_equal([3, 4, 5, 6, 7, 8])
	assert_array(_xs(tall)).is_equal([3, 3, 3, 3, 3, 3])
	var tie := StudioRow.cells(Vector2i(3, 3), Vector2i(6, 6), Vector2i.ONE)
	assert_array(_xs(tie)).is_equal([3, 4, 5, 6])
	assert_array(_ys(tie)).is_equal([3, 3, 3, 3])


func test_a_wide_piece_steps_by_its_width_and_a_tall_one_by_its_height() -> void:
	var bench := StudioRow.cells(Vector2i(2, 5), Vector2i(9, 5), Vector2i(2, 1))
	assert_array(_xs(bench)).is_equal([2, 4, 6, 8])
	var tall := StudioRow.cells(Vector2i(2, 5), Vector2i(2, 11), Vector2i(1, 3))
	assert_array(_ys(tall)).is_equal([5, 8, 11])
	var short := StudioRow.cells(Vector2i(2, 5), Vector2i(2, 10), Vector2i(1, 3))
	assert_array(_ys(short)).is_equal([5, 8])


func test_a_short_drag_is_one_cell_and_the_row_is_never_empty() -> void:
	assert_array(StudioRow.cells(Vector2i(5, 5), Vector2i(5, 5), Vector2i.ONE)).is_equal([Vector2i(5, 5)])
	assert_array(StudioRow.cells(Vector2i(5, 5), Vector2i(6, 5), Vector2i(3, 1))).is_equal([Vector2i(5, 5)])


func test_sizes_below_one_count_as_one() -> void:
	var cells := StudioRow.cells(Vector2i(0, 0), Vector2i(3, 0), Vector2i(0, -2))
	assert_int(cells.size()).is_equal(4)
