extends GdUnitTestSuite
## What one key press does with the player's boots (ADR-0061): walking one tile, bumping into what is there, standing
## still for a key with no rule, refusing a jump or a diagonal, and an error kept for its tile.

const SIZE := Vector2i(4, 3)


## A made-up table: `rule(key, cell)` returns where the code would send the player, or null for an error.
func _table(rule: Callable) -> Dictionary:
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var marks := PackedInt32Array()
	for key in BootsRules.KEYS:
		for y in SIZE.y:
			for x in SIZE.x:
				var to: Variant = rule.call(key, Vector2i(x, y))
				xs.append(x if to == null else (to as Vector2i).x)
				ys.append(y if to == null else (to as Vector2i).y)
				marks.append(0 if to == null else -1)
	return {
		"status": "ok",
		"width": SIZE.x,
		"height": SIZE.y,
		"keys": BootsRules.KEYS.duplicate(),
		"x": xs,
		"y": ys,
		"error": marks,
		"errors": [{"kind": "NameError", "message": "name 'speed' is not defined", "line": 3}],
	}


func _right_only(key: String, cell: Vector2i) -> Variant:
	return cell + Vector2i(1, 0) if key == "right" else cell


func _open(_cell: Vector2i) -> bool:
	return false


func test_a_rule_that_moves_one_tile_walks() -> void:
	var step := BootsRules.move(_table(_right_only), "right", Vector2i(1, 1), SIZE, _open)
	assert_str(step.kind).is_equal("walk")
	assert_that(step.to).is_equal(Vector2i(2, 1))
	assert_str(step.facing).is_equal("right")


func test_a_key_without_a_rule_stands_still() -> void:
	var step := BootsRules.move(_table(_right_only), "left", Vector2i(1, 1), SIZE, _open)
	assert_str(step.kind).is_equal("still")
	assert_that(step.to).is_equal(Vector2i(1, 1))


func test_walking_into_something_turns_to_face_it() -> void:
	var wall := func(cell: Vector2i) -> bool: return cell == Vector2i(2, 1)
	var step := BootsRules.move(_table(_right_only), "right", Vector2i(1, 1), SIZE, wall)
	assert_str(step.kind).is_equal("bump")
	assert_that(step.to).is_equal(Vector2i(1, 1))
	assert_str(step.facing).is_equal("right")


func test_off_the_map_is_outside() -> void:
	var step := BootsRules.move(_table(_right_only), "right", Vector2i(3, 0), SIZE, _open)
	assert_str(step.kind).is_equal("outside")


func test_more_than_one_tile_or_a_diagonal_is_too_far() -> void:
	var leap := func(key: String, cell: Vector2i) -> Variant: return cell + Vector2i(2, 0) if key == "right" else cell
	assert_str(BootsRules.move(_table(leap), "right", Vector2i(0, 0), SIZE, _open).kind).is_equal("far")
	var slant := func(key: String, cell: Vector2i) -> Variant: return cell + Vector2i(1, 1) if key == "down" else cell
	var step := BootsRules.move(_table(slant), "down", Vector2i(0, 0), SIZE, _open)
	assert_str(step.kind).is_equal("far")
	assert_str(step.facing).is_equal("right")


func test_an_error_is_reported_for_the_tile_that_raised_it() -> void:
	var broken := func(key: String, cell: Vector2i) -> Variant: return null if key == "down" else cell
	var step := BootsRules.move(_table(broken), "down", Vector2i(1, 1), SIZE, _open)
	assert_str(step.kind).is_equal("error")
	assert_int(int(step.error.line)).is_equal(3)


func test_no_table_means_no_boots() -> void:
	var step := BootsRules.move(BootsRun.failed(SIZE, BootsRules.KEYS, "nothing"), "up", Vector2i.ZERO, SIZE, _open)
	assert_str(step.kind).is_equal("empty")


func test_taught_lists_the_keys_that_move_the_player_somewhere() -> void:
	assert_array(BootsRules.taught(_table(_right_only))).contains_exactly(["right"])


func test_facing_follows_the_larger_part_of_a_move() -> void:
	assert_str(BootsRules.facing_of(Vector2i(0, -3))).is_equal("up")
	assert_str(BootsRules.facing_of(Vector2i(-1, 1))).is_equal("left")
	assert_str(BootsRules.facing_of(Vector2i.ZERO)).is_equal("")
