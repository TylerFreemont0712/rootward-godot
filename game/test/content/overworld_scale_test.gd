extends GdUnitTestSuite
## The overworld's scale is written twice (ADR-0064): `OverworldScale` for the game, `overworld/scale.jsonc` for the art
## pipelines. If they disagree, art is cut for one world and drawn in another.

const FILE := "res://content/packs/core/overworld/scale.jsonc"


func _scale() -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var parsed: Variant = ContentLoader._read(FILE, diagnostics)
	assert_array(diagnostics).is_empty()
	return parsed if parsed is Dictionary else {}


func _pair(value: Variant) -> Vector2i:
	var pair: Array = value if value is Array else [0, 0]
	return Vector2i(int(pair[0]), int(pair[1]))


func test_the_game_and_the_pipelines_share_one_scale() -> void:
	var scale := _scale()
	assert_int(int(scale.get("tile", 0))).is_equal(OverworldScale.TILE)
	assert_that(_pair(scale.get("view"))).is_equal(OverworldScale.VIEW)
	assert_that(_pair(scale.get("person"))).is_equal(OverworldScale.PERSON)
	assert_int(int(scale.get("old_tile", 0))).is_equal(OverworldScale.OLD_TILE)


func test_the_view_is_a_whole_number_of_tiles() -> void:
	assert_int(OverworldScale.VIEW.x % OverworldScale.TILE).is_equal(0)
	assert_int(OverworldScale.VIEW.y % OverworldScale.TILE).is_equal(0)


func test_old_art_is_scaled_up_and_new_art_is_not() -> void:
	assert_float(OverworldScale.upscale(OverworldScale.TILE)).is_equal(1.0)
	assert_float(OverworldScale.upscale(16)).is_equal(2.5)
	assert_int(OverworldScale.drawn_tile({})).is_equal(16)
	assert_int(OverworldScale.drawn_tile({"tile": 40})).is_equal(40)
