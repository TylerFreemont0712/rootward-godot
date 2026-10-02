extends GdUnitTestSuite
## Every skin stands the same height on the stage (ADR-0037): its measured stature is fitted to the view, whatever its
## model or drawing measures.


func test_every_shipped_skin_is_fitted_to_the_same_figure_height() -> void:
	for skin: String in Settings.CHARACTER_SKINS:
		var hero: HeroView = auto_free(HeroView.new())
		hero.preview_skin = skin
		hero.size = Vector2(300, 400)
		add_child(hero)
		var expected := 400.0 * HeroView.FIGURE_FILL
		assert_float(hero.figure_height()).is_equal_approx(expected, 0.01)
		if hero.sprite != null:
			var drawn := hero.sprite.fill * hero.sprite.stature() * 400.0
			assert_float(drawn).override_failure_message(skin).is_equal_approx(expected, 1.0)
		else:
			assert_object(hero.character).override_failure_message(skin).is_not_null()
			var floor_px := hero._to_stage(Vector3.ZERO).y
			var top_px := hero._to_stage(Vector3(0.0, hero.character.stature(), 0.0)).y
			assert_float(floor_px - top_px).override_failure_message(skin).is_equal_approx(expected, 1.0)
			# The soles stand on the view's floor, just above its bottom edge.
			assert_float(floor_px).override_failure_message(skin).is_between(392.0, 400.0)


func test_statures_are_measured_from_the_models() -> void:
	var shibu: StageCharacter = auto_free(StageCharacter.create("shibu"))
	var fox: StageCharacter = auto_free(StageCharacter.create("emberfox"))
	assert_float(shibu.stature()).is_between(1.55, 1.75)
	assert_float(fox.stature()).is_between(1.45, 1.65)
	var vesper: SpriteCharacter = auto_free(SpriteCharacter.create("vesper"))
	assert_float(vesper.stature()).is_between(0.85, 0.98)


func test_effects_are_sized_by_the_figure_not_the_view() -> void:
	var hero: HeroView = auto_free(HeroView.new())
	hero.preview_skin = "vesper"
	hero.size = Vector2(300, 400)
	add_child(hero)
	assert_float(hero.circle_radius(3)).is_greater(hero.circle_radius(0))
	assert_float(hero.circle_radius(0)).is_equal_approx(hero.figure_height() * 0.2, 0.01)
	assert_float(hero.height_share()).is_equal(HeroView.VIEW_SHARE)
