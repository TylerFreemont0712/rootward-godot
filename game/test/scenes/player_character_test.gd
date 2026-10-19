extends GdUnitTestSuite
## The authored player never returns to the legacy composer, every direction has genuine animation frames,
## and a held-key walk keeps its clip phase when crossing a tile seam.


func test_both_models_have_complete_native_sheets_and_distinct_directions() -> void:
	for model: String in ["male", "female"]:
		var sheet := OverworldArt.player_character({"model": model})
		assert_that(sheet.frame).is_equal(Vector2i(64, 96))
		assert_float(sheet.scale).is_equal(1.0)
		assert_int(sheet.ground).is_equal(93)
		assert_object(sheet.texture).is_not_null()
		assert_that(Vector2i(sheet.texture.get_size())).is_equal(Vector2i(768, 384))
		var image := sheet.texture.get_image()
		var fps := float(sheet.animations.walk.fps)
		var directions := {}
		for way: String in ["down", "up", "left", "right"]:
			assert_bool(sheet.flipped(way)).is_false()
			var poses := {}
			for index in 8:
				var rect := sheet.animation_rect(way, "walk", (index + 0.01) / fps)
				assert_bool(Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect)).is_true()
				var frame := image.get_region(rect)
				poses[hash(frame.get_data())] = true
				var used := frame.get_used_rect()
				assert_bool(used.has_area()).is_true()
				assert_bool(used.position.x > 0 and used.end.x < 64).is_true()
				assert_int(used.end.y).is_equal(93)
			assert_int(poses.size()).override_failure_message(model + "/" + way + " has repeated walk art").is_greater_equal(6)
			directions[hash(image.get_region(sheet.animation_rect(way, "idle", 0.0)).get_data())] = true
		assert_int(directions.size()).is_equal(4)
	assert_object(OverworldArt.player_character({"model": "male"})).is_not_same(
		OverworldArt.player_character({"model": "female"})
	)


func test_legacy_saved_parts_select_the_new_default_model_without_loading_old_art() -> void:
	var old := {"outfit": "outfit/armor", "hair": "hair/spiky", "hat": "hat/kettle", "colours": {"skin": "skin_deep"}}
	assert_object(OverworldArt.player_character(old)).is_same(OverworldArt.player_character({"model": "male"}))
	assert_object(OverworldArt.player_character({})).is_same(OverworldArt.player_character({"model": "male"}))


func test_clips_loop_and_the_blink_has_its_own_short_duration() -> void:
	var sheet := OverworldArt.player_character({"model": "female"})
	assert_int(sheet.animation_column("walk", 0.0)).is_equal(4)
	assert_int(sheet.animation_column("walk", 0.25)).is_equal(7)
	assert_int(sheet.animation_column("walk", 2.0 / 3.0 + 0.001)).is_equal(4)
	assert_int(sheet.animation_column("idle", 1.06)).is_equal(2)
	assert_int(sheet.animation_column("idle", 1.15)).is_equal(3)
	assert_int(sheet.animation_column("idle", 1.61)).is_equal(0)


func test_tile_arrivals_do_not_restart_the_stride_or_create_another_sprite() -> void:
	var sheet := OverworldArt.player_character({"model": "male"})
	var walker: Walker = auto_free(Walker.new(sheet))
	add_child(walker)
	walker.set_process(false)
	walker.place(Vector2i(4, 4), "right")
	walker.walk_to(Vector2i(5, 4), "right")
	walker._process(0.12)
	var phase: float = walker.get("_walk_clock")
	var sprite: Sprite2D = walker.get("_sprite")
	assert_that(sprite.region_rect).is_equal(Rect2(sheet.animation_rect("right", "walk", phase)))
	(walker.get("_tween") as Tween).kill()
	walker._arrive()
	walker.walk_to(Vector2i(6, 4), "right")
	assert_float(float(walker.get("_walk_clock"))).is_equal(phase)
	assert_that(sprite.region_rect).is_equal(Rect2(sheet.animation_rect("right", "walk", phase)))
	walker._process(0.1)
	assert_float(float(walker.get("_walk_clock"))).is_greater(phase)
	assert_int((walker.get("_art") as Node2D).get_child_count()).is_equal(1)
	(walker.get("_tween") as Tween).kill()
	walker._arrive()
	walker._process(0.2)
	assert_float(float(walker.get("_walk_clock"))).is_equal(0.0)
	assert_that(sprite.region_rect).is_equal(Rect2(sheet.animation_rect("right", "idle", 0.2)))


func test_vertical_gait_slows_while_tile_travel_gets_faster() -> void:
	assert_float(Walker.STEP_TIME).is_equal_approx(0.176, 0.000001)
	var sheet := OverworldArt.player_character({"model": "male"})
	var vertical: Walker = auto_free(Walker.new(sheet))
	add_child(vertical)
	vertical.set_process(false)
	vertical.place(Vector2i(2, 2), "up")
	vertical.walk_to(Vector2i(2, 1), "up")
	vertical._process(0.2)
	assert_float(float(vertical.get("_walk_clock"))).is_equal_approx(0.17, 0.000001)
	(vertical.get("_tween") as Tween).kill()
	var horizontal: Walker = auto_free(Walker.new(sheet))
	add_child(horizontal)
	horizontal.set_process(false)
	horizontal.place(Vector2i(2, 2), "right")
	horizontal.walk_to(Vector2i(3, 2), "right")
	horizontal._process(0.2)
	assert_float(float(horizontal.get("_walk_clock"))).is_equal_approx(0.2, 0.000001)
	(horizontal.get("_tween") as Tween).kill()


func test_creator_only_offers_male_and_female_and_saves_the_selected_sheet() -> void:
	var creator: CharacterCreator = auto_free(CharacterCreator.new())
	add_child(creator)
	creator.open(OverworldContent.load_world().catalog.looks, {}, "Tinker")
	assert_int((creator.get("_model_buttons") as Dictionary).size()).is_equal(2)
	creator._choose_model("female")
	assert_that(creator.look).is_equal({"model": "female"})
	assert_object(creator.preview_sheet()).is_same(OverworldArt.player_character({"model": "female"}))
	assert_str((creator.get("_name") as LineEdit).text).is_equal("Tinker")
