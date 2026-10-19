extends GdUnitTestSuite
## The world's objects (ADR-0064, pipeline/world): every picture world.json lists is there at the size it records,
## cut for this world's tile, as wide as its footprint or wider; and the game draws it before the older picture of
## that name.

const WORLD := "res://assets/overworld/world/"


func test_every_world_picture_is_there_at_its_recorded_size() -> void:
	var index := OverworldArt.index("world")
	for id: String in index:
		var entry: Dictionary = index[id]
		var texture := OverworldArt.texture(WORLD + "%s.png" % id)
		assert_object(texture).override_failure_message("no picture for %s" % id).is_not_null()
		if texture == null:
			continue
		var size: Array = entry.get("size", [0, 0])
		var footprint: Array = entry.get("footprint", [1, 1])
		assert_that(Vector2i(texture.get_size())).override_failure_message(id).is_equal(
			Vector2i(int(size[0]), int(size[1]))
		)
		assert_int(int(entry.get("tile", 0))).override_failure_message(id).is_equal(OverworldScale.TILE)
		assert_int(int(size[0])).override_failure_message(id).is_greater_equal(int(footprint[0]) * OverworldScale.TILE)
		assert_int(int(size[1])).override_failure_message(id).is_greater_equal(int(footprint[1]) * OverworldScale.TILE)


func test_a_world_picture_is_drawn_first_and_at_its_own_size() -> void:
	var index := OverworldArt.index("world")
	for id: String in index:
		var kind := String((index[id] as Dictionary).get("kind", ""))
		var drawn := OverworldArt.building(id) if kind in ["building", "landmark"] else OverworldArt.prop(id)
		assert_str(drawn.resource_path if drawn != null else "").override_failure_message(id).is_equal(
			WORLD + "%s.png" % id
		)
		var folder := "buildings" if kind in ["building", "landmark"] else "props"
		assert_float(OverworldArt.art_scale(folder, id)).override_failure_message(id).is_equal(1.0)


func test_an_older_picture_without_a_world_one_is_enlarged() -> void:
	assert_float(OverworldArt.art_scale("props", "no-such-prop")).is_equal(2.5)
