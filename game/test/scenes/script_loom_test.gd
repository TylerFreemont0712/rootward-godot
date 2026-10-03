extends GdUnitTestSuite
## Test the geometry that actually reaches the renderer, not just the animation's internal progress counter.


func _length(paths: Array[PackedVector2Array]) -> float:
	var length := 0.0
	for path in paths:
		for index in range(1, path.size()):
			length += path[index - 1].distance_to(path[index])
	return length


func test_the_writing_tip_reveals_only_the_traversed_distance() -> void:
	var paths := ScriptLoom.strokes({"seed": 4}, 0, 4, 100.0)
	assert_array(ScriptLoom.prefix(paths, 0.0)).is_empty()
	for progress: float in [0.02, 0.2, 0.5, 0.8, 1.0]:
		var written := ScriptLoom.prefix(paths, progress)
		assert_float(_length(written)).is_equal_approx(_length(paths) * progress, 0.001)
		if progress < 0.2:
			assert_int(written.size()).is_equal(1)
			assert_float(written[0][0].distance_to(written[0][-1])).is_greater(0.1)


func test_the_first_function_leaves_later_sectors_empty_in_the_visible_geometry() -> void:
	var paths := ScriptLoom.prefix(ScriptLoom.strokes({}, 0, 4, 100.0), 1.0)
	for path in paths:
		for point in path:
			# This function owns the top-right quadrant only. No full rim or disc conceals the unvisited quarters.
			assert_float(point.x).is_greater_equal(-0.001)
			assert_float(point.y).is_less_equal(0.001)
	assert_int(paths.size()).is_equal(3)
	assert_int(ScriptLoom.strokes({}, 3, 4, 100.0).size()).is_equal(4)


func test_each_shard_count_makes_a_distinct_finite_seal_without_missing_sectors() -> void:
	for count in range(1, 7):
		var end := Vector2.UP * 100.0
		for slot in count:
			var paths := ScriptLoom.strokes({"seed": slot}, slot, count, 100.0)
			assert_vector(paths[0][0]).is_equal_approx(end, Vector2.ONE * 0.001)
			end = Vector2.from_angle(-PI * 0.5 + TAU * (slot + 1) / count) * 100.0
			for path in paths:
				for point in path:
					assert_bool(point.is_finite()).is_true()
					assert_float(point.length()).is_less_equal(100.001)
		assert_vector(end).is_equal_approx(Vector2.UP * 100.0, Vector2.ONE * 0.001)


func test_unique_cast_is_optional_and_available_on_every_skin() -> void:
	var catalog := Cosmetics.catalog()
	assert_array(CosmeticRules.check(catalog)).is_empty()
	assert_str(CosmeticRules.defaults(catalog).cast_light).is_equal("finger-snap")
	for slot: String in ["cast_light", "cast_heavy"]:
		var entry := CosmeticRules.find(catalog, slot, "script-loom")
		assert_bool(CosmeticRules.playable(entry, [])).is_true()
		assert_str(entry.circle_style).is_equal("script-loom")
		assert_str(entry.construction).is_equal("shards")


func test_unfinished_drawing_stays_still_while_time_passes_and_starts_turning_after_sealing() -> void:
	var circle: MagicCircle = auto_free(MagicCircle.cast(self, Vector2(200, 200), 1, "none", 100.0, "", 1.0, true))
	circle.style = "script-loom"
	circle.external_construction = true
	circle.use_plan(CircleLayers.plan(CircleLayers.demo_cards(4)))
	circle.set_process(false)
	circle.trace_shard(0, 0.2)
	circle._process(5.0)
	assert_float(circle._layer_progress(0)).is_equal(0.2)
	assert_float(circle.drawing_clock()).is_equal(0.0)
	assert_vector(circle.launch_point()).is_equal(circle.position)
	circle.finish_construction()
	circle._process(0.0)
	assert_float(circle.drawing_clock()).is_equal(0.0)
	circle._process(0.3)
	assert_float(circle.drawing_clock()).is_equal_approx(0.3, 0.0001)


func test_character_option_preview_uses_the_unique_renderer_while_its_strokes_are_partial() -> void:
	var art: LookArt = auto_free(
		LookArt.make("cast_heavy", CosmeticRules.find(Cosmetics.catalog(), "cast_heavy", "script-loom"))
	)
	art.size = Vector2(180, 210)
	add_child(art)
	art.set_process(false)
	art.set_live(true)
	art._advance(0.23)
	var circle := art._effect as MagicCircle
	assert_str(circle.style).is_equal("script-loom")
	assert_bool(circle.external_construction).is_true()
	assert_float(circle._layer_progress(0)).is_between(0.1, 0.4)
	assert_float(circle._layer_progress(1)).is_equal(0.0)
