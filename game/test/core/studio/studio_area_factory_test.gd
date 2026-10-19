extends GdUnitTestSuite

const TERRAIN := {
    "grass": {"walk": true, "paint": "outdoor"},
    "meadow": {"walk": true, "paint": "outdoor"},
    "water": {"walk": false, "paint": "outdoor"},
    "wall": {"walk": false, "paint": "indoor"},
}


func test_ids_are_safe_and_collisions_get_a_numeric_suffix() -> void:
    assert_str(StudioAreaFactory.safe_id("Mossback Grove!")).is_equal("mossback-grove")
    assert_str(StudioAreaFactory.safe_id("森")).is_equal("area")
    assert_str(StudioAreaFactory.unique_id("Mossback Grove", ["mossback-grove", "mossback-grove-2"])).is_equal(
        "mossback-grove-3"
    )
    for invalid: String in ["", "-trail", "trail-", "two--words", "one..two", "one.-two", "../woods", "UpperCase"]:
        assert_bool(StudioAreaFactory.valid_id(invalid)).override_failure_message(invalid).is_false()
    assert_bool(StudioAreaFactory.valid_id("mossback-grove-2")).is_true()
    assert_bool(StudioAreaFactory.valid_id("mossback.grove-2")).is_true()


func test_long_area_titles_make_unique_ids_within_the_filename_limit() -> void:
    var title := "A".repeat(80)
    var id := StudioAreaFactory.unique_id(title, ["a".repeat(64)])
    assert_int(id.length()).is_less_equal(64)
    assert_bool(StudioAreaFactory.valid_id(id)).is_true()
    assert_str(id).ends_with("-2")


func test_new_area_is_a_walkable_named_map_with_a_configurable_start() -> void:
    var made := StudioAreaFactory.create_data(
        "mossback-grove", "  Mossback Grove  ", Vector2i(24, 18), "meadow", TERRAIN, Vector2i(4, 5), "left"
    )
    assert_bool(made.ok).is_true()
    var data: Dictionary = made.data
    assert_str(data.name).is_equal("Mossback Grove")
    assert_bool(data.interior).is_false()
    assert_dict(data.legend).is_equal({"m": "meadow"})
    assert_int((data.ground as Array).size()).is_equal(18)
    for row: String in data.ground:
        assert_str(row).is_equal("m".repeat(24))
    assert_array(data.start).is_equal([4, 5])
    assert_str(data.facing).is_equal("left")
    assert_array(data.objects).is_empty()
    var built := OverworldMap.build(data, TERRAIN)
    assert_array(built.errors).is_empty()
    assert_bool(OverworldMap.blocked(built.map, Vector2i(12, 9))).is_false()


func test_area_defaults_are_small_walkable_spawn_values_and_start_must_be_inside() -> void:
    var made := StudioAreaFactory.create_data("small-grove", "Small Grove", Vector2i(40, 30), "meadow", TERRAIN)
    assert_bool(made.ok).is_true()
    assert_array(made.data.start).is_equal([2, 2])
    assert_str(made.data.facing).is_equal("down")
    assert_bool(StudioAreaFactory.create_data(
        "outside", "Outside", Vector2i(8, 8), "meadow", TERRAIN, Vector2i(8, 1)
    ).ok).is_false()


func test_new_area_rejects_unsafe_ids_unwalkable_surfaces_and_oversized_maps() -> void:
    assert_bool(StudioAreaFactory.create_data("../unsafe", "Wood", Vector2i(24, 18), "grass", TERRAIN).ok).is_false()
    assert_bool(StudioAreaFactory.create_data("pond", "Pond", Vector2i(24, 18), "water", TERRAIN).ok).is_false()
    assert_bool(StudioAreaFactory.create_data("hall", "Hall", Vector2i(129, 18), "grass", TERRAIN).ok).is_false()
