extends GdUnitTestSuite
## Placed art can change footprint without a generator or a new art id. Mask area, identity and the original
## picture footprint survive; malformed edits never mutate their input.


func test_building_resize_keeps_identity_and_positions_the_door_by_its_cell_center() -> void:
	var source := {
		"kind": "building", "art": "inn", "id": "village-inn", "at": [3, 4], "size": [6, 6], "door": [4, 5],
		"to": {"map": "inn-room", "at": [3, 5], "facing": "up"}, "name": "The Fox", "text": "Welcome!",
		"program": "inn-program", "solid_unless": "open", "custom": {"approved": ["roof", "windows"]},
	}
	var snapshot := source.duplicate(true)
	var result := StudioResize.object_at_size(source, Vector2i(3, 4))
	assert_bool(result.ok).is_true()
	assert_array(result.object.size).is_equal([3, 4])
	assert_array(result.object.art_size).is_equal([6, 6])
	assert_array(result.object.door).is_equal([2, 3])
	for key: String in ["art", "id", "at", "to", "name", "text", "program", "solid_unless", "custom"]:
		assert_that(result.object[key]).is_equal(source[key])
	(result.object.custom.approved as Array).append("chimney")
	assert_dict(source).is_equal(snapshot)


func test_off_center_door_stays_on_the_corresponding_side_when_growing() -> void:
	var source := {"kind": "building", "art": "cottage", "size": [5, 5], "door": [0, 4]}
	var result := StudioResize.object_at_size(source, Vector2i(10, 10))
	assert_bool(result.ok).is_true()
	assert_array(result.object.door).is_equal([1, 9])


func test_repeated_resize_keeps_original_picture_size_and_reset_removes_override() -> void:
	var source := {"kind": "building", "art": "inn", "at": [2, 2], "size": [6, 6], "door": [3, 5]}
	var small: Dictionary = StudioResize.object_at_size(source, Vector2i(4, 4)).object
	var wide: Dictionary = StudioResize.object_at_size(small, Vector2i(7, 5)).object
	assert_array(wide.art_size).is_equal([6, 6])
	assert_str(wide.art).is_equal("inn")
	var reset: Dictionary = StudioResize.object_at_size(wide, Vector2i(6, 6)).object
	assert_bool(reset.has("art_size")).is_false()
	assert_array(reset.size).is_equal([6, 6])
	assert_array(source.size).is_equal([6, 6])
	assert_bool(source.has("art_size")).is_false()


func test_single_tile_prop_returns_to_its_implicit_default() -> void:
	var source := {"kind": "prop", "art": "barrel", "at": [3, 4], "solid": false, "flip": true, "sink": 4}
	var grown: Dictionary = StudioResize.object_at_size(source, Vector2i(3, 2)).object
	assert_array(grown.art_size).is_equal([1, 1])
	assert_array(grown.size).is_equal([3, 2])
	var reset: Dictionary = StudioResize.object_at_size(grown, Vector2i.ONE).object
	assert_dict(reset).is_equal(source)


func test_resizing_through_one_tile_restores_exact_asymmetric_door_and_mask() -> void:
	var source := {
		"kind": "building", "art": "workshop", "at": [3, 4], "size": [6, 5], "door": [0, 4],
		"solid_cells": [[5, 4], [0, 4], [2, 1]], "to": {"map": "room", "at": [2, 3]},
	}
	var tiny: Dictionary = StudioResize.object_at_size(source, Vector2i.ONE).object
	assert_array(tiny.door).is_equal([0, 0])
	assert_array(tiny.solid_cells).is_equal([[0, 0]])
	assert_dict(tiny.art_shape).is_equal({"door": [0, 4], "solid_cells": [[5, 4], [0, 4], [2, 1]]})
	var middle: Dictionary = StudioResize.object_at_size(tiny, Vector2i(4, 3)).object
	var direct: Dictionary = StudioResize.object_at_size(source, Vector2i(4, 3)).object
	assert_dict(middle).is_equal(direct)
	var reset: Dictionary = StudioResize.object_at_size(middle, Vector2i(6, 5)).object
	assert_dict(reset).is_equal(source)
	assert_bool(reset.has("art_size")).is_false()
	assert_bool(reset.has("art_shape")).is_false()


func test_row_mask_order_and_missing_shape_fields_restore_exactly() -> void:
	var source := {"kind": "building", "art": "inn", "size": [4, 4], "solid_rows": [3, 1, 3]}
	var tiny: Dictionary = StudioResize.object_at_size(source, Vector2i.ONE).object
	assert_bool(tiny.art_shape.has("door")).is_false()
	assert_array(tiny.art_shape.solid_rows).is_equal([3, 1, 3])
	assert_dict(StudioResize.object_at_size(tiny, Vector2i(4, 4)).object).is_equal(source)
	var full := {"kind": "building", "art": "hall", "size": [4, 4], "door": [1, 3]}
	var grown: Dictionary = StudioResize.object_at_size(full, Vector2i(6, 5)).object
	assert_bool(grown.art_shape.has("solid_rows")).is_false()
	assert_bool(grown.art_shape.has("solid_cells")).is_false()
	assert_dict(StudioResize.object_at_size(grown, Vector2i(4, 4)).object).is_equal(full)


func test_manually_moved_door_uses_its_own_anchor_while_masks_use_original_size() -> void:
	var source := {
		"kind": "building", "art": "workshop", "size": [6, 6], "door": [2, 5],
		"solid_cells": [[5, 5], [1, 3], [0, 5]],
	}
	var edited: Dictionary = StudioResize.object_at_size(source, Vector2i(12, 12)).object
	edited["door"] = [10, 11]
	edited.art_shape["door"] = [10, 11]
	edited.art_shape["door_size"] = [12, 12]
	var resized: Dictionary = StudioResize.object_at_size(edited, Vector2i(10, 10)).object
	assert_array(resized.door).is_equal([8, 9])
	assert_array(resized.art_shape.door_size).is_equal([12, 12])
	var reset: Dictionary = StudioResize.object_at_size(resized, Vector2i(6, 6)).object
	assert_array(reset.door).is_equal([5, 5])
	assert_array(reset.solid_cells).is_equal(source.solid_cells)
	assert_bool(reset.has("art_size")).is_false()
	assert_bool(reset.has("art_shape")).is_false()
	assert_bool(StudioResize.object_at_size({"kind": "building", "size": [2, 2], "art_size": [4, 4], "art_shape": {"door": [0, 0], "door_size": [0, 1]}}, Vector2i(3, 3)).ok).is_false()


func test_expanding_irregular_cells_covers_the_same_relative_solid_areas() -> void:
	var source := {
		"kind": "building", "art": "workshop", "size": [2, 2], "door": [1, 1],
		"solid_cells": [[0, 0], [1, 0], [0, 1]],
	}
	var result := StudioResize.object_at_size(source, Vector2i(4, 4))
	assert_bool(result.ok).is_true()
	assert_array(result.object.solid_cells).is_equal([
		[0, 0], [1, 0], [2, 0], [3, 0], [0, 1], [1, 1], [2, 1], [3, 1],
		[0, 2], [1, 2], [0, 3], [1, 3],
	])
	assert_array(source.solid_cells).is_equal([[0, 0], [1, 0], [0, 1]])


func test_shrinking_irregular_cells_preserves_thin_walls_and_deduplicates() -> void:
	var source := {
		"kind": "building", "art": "hall", "size": [4, 4], "door": [3, 3],
		"solid_cells": [[0, 0], [1, 0], [3, 0], [1, 2]],
	}
	var result := StudioResize.object_at_size(source, Vector2i(2, 2))
	assert_bool(result.ok).is_true()
	assert_array(result.object.solid_cells).is_equal([[0, 0], [1, 0], [0, 1]])
	var very_small := StudioResize.object_at_size(source, Vector2i.ONE)
	assert_array(very_small.object.solid_cells).is_equal([[0, 0]])
	assert_array(very_small.object.door).is_equal([0, 0])


func test_non_integer_scale_keeps_every_solid_cells_covered_area() -> void:
	var source := {
		"kind": "building", "art": "archive", "size": [3, 3], "door": [1, 2], "solid_cells": [[1, 1]],
	}
	var result := StudioResize.object_at_size(source, Vector2i(2, 2))
	assert_bool(result.ok).is_true()
	# The center ninth overlaps all four target cells. Center-point sampling would lose its collision entirely.
	assert_array(result.object.solid_cells).is_equal([[0, 0], [1, 0], [0, 1], [1, 1]])


func test_row_masks_expand_and_shrink_without_invalid_rows() -> void:
	var source := {"kind": "building", "art": "shop", "size": [4, 4], "door": [2, 3], "solid_rows": [3, 1, 3]}
	var grown := StudioResize.object_at_size(source, Vector2i(5, 8))
	assert_array(grown.object.solid_rows).is_equal([2, 3, 6, 7])
	var small := StudioResize.object_at_size(source, Vector2i(2, 2))
	assert_array(small.object.solid_rows).is_equal([0, 1])
	assert_array(source.solid_rows).is_equal([3, 1, 3])


func test_empty_masks_stay_empty_and_full_collision_does_not_gain_a_mask() -> void:
	var source := {"kind": "building", "art": "smithy", "size": [3, 3], "door": [1, 2]}
	var full := StudioResize.object_at_size(source, Vector2i(4, 4))
	assert_bool(full.object.has("solid_rows")).is_false()
	assert_bool(full.object.has("solid_cells")).is_false()
	source["solid_cells"] = []
	assert_array(StudioResize.object_at_size(source, Vector2i(4, 4)).object.solid_cells).is_empty()
	source.erase("solid_cells")
	source["solid_rows"] = []
	assert_array(StudioResize.object_at_size(source, Vector2i(4, 4)).object.solid_rows).is_empty()


func test_invalid_kinds_sizes_and_noops_are_refused_without_mutation() -> void:
	for kind: String in ["person", "warp", "start", "sign", ""]:
		assert_bool(StudioResize.object_at_size({"kind": kind}, Vector2i(2, 2)).ok).is_false()
	var source := {"kind": "prop", "art": "barrel", "size": [2, 2]}
	var snapshot := source.duplicate(true)
	for size: Vector2i in [Vector2i.ZERO, Vector2i(-1, 2), Vector2i(2, 0), Vector2i(2, 2)]:
		var result := StudioResize.object_at_size(source, size)
		assert_bool(result.ok).is_false()
		assert_str(result.error).is_not_empty()
		assert_dict(result.object).is_empty()
	assert_dict(source).is_equal(snapshot)
	assert_bool(StudioResize.object_at_size({"kind": "prop", "size": [1.5, 2]}, Vector2i(3, 3)).ok).is_false()
	assert_bool(StudioResize.object_at_size({"kind": "prop", "art_size": [0, 1]}, Vector2i(3, 3)).ok).is_false()


func test_bad_masks_or_door_are_refused_instead_of_discarding_collision() -> void:
	var source := {"kind": "building", "art": "inn", "size": [2, 2], "door": [1, 1]}
	for bad: Variant in ["all", [2], [0.5], [-1]]:
		source["solid_rows"] = bad
		assert_bool(StudioResize.object_at_size(source, Vector2i(3, 3)).ok).is_false()
	source.erase("solid_rows")
	for bad: Variant in ["all", [[2, 0]], [[-1, 0]], [[0.5, 1]], [[0, 0, 1]]]:
		source["solid_cells"] = bad
		assert_bool(StudioResize.object_at_size(source, Vector2i(3, 3)).ok).is_false()
	source["solid_cells"] = []
	source["solid_rows"] = []
	assert_bool(StudioResize.object_at_size(source, Vector2i(3, 3)).ok).is_false()
	source.erase("solid_cells")
	source.erase("solid_rows")
	source["door"] = [2, 1]
	assert_bool(StudioResize.object_at_size(source, Vector2i(3, 3)).ok).is_false()
