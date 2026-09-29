extends GdUnitTestSuite
## A card's details appear where they end up, never at a first guess that then snaps or slides away.


func test_details_show_only_once_their_size_and_card_hold_still() -> void:
	var catalog := ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	var tags: Array[String] = ["Divide and conquer", "leaves them sorted"]
	var detail := CardDetail.create(
		catalog.shards["merge-sort"], "merge-sort", "python", true, Color.WHITE, tags, "", {}
	)
	detail.theme = UiTheme.shared()
	detail.top_level = true
	add_child(detail)
	var card := Rect2(200, 400, 120, 170)
	var shown_at: Array[float] = []
	var final_y := 0.0
	for frame in 8:
		# The card lifts for its first three frames, as a hand card does when it is pointed at.
		var lifted := card.grow_individual(0, 10.0 * mini(frame, 3), 0, -10.0 * mini(frame, 3))
		detail.place_beside(lifted, Vector2(1920, 1080))
		final_y = detail.global_position.y
		if detail.modulate.a > 0.0:
			shown_at.append(detail.global_position.y)
		await get_tree().process_frame
	assert_bool(shown_at.is_empty()).override_failure_message("it never showed").is_false()
	for y in shown_at:
		assert_float(y).is_equal(final_y)
	detail.free()
