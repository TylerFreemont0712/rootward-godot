extends GdUnitTestSuite
## The Progress panel uses the selected complete 64 x 96 player sheet at the character screen's 2x.

const KIT_LOOK := {"model": "female"}


func test_the_header_draws_the_town_s_sheet_at_two_x() -> void:
	var catalog: Dictionary = OverworldContent.load_world().catalog
	var state := OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
	state.look = KIT_LOOK.duplicate(true)
	state.name = "Tinker"
	var panel := ProgressPanel.new()
	add_child(panel)
	auto_free(panel)
	panel.open(state, catalog)
	var figure := panel.find_child("Figure", true, false) as WalkPreview
	assert_object(figure).override_failure_message("the header has the town's figure").is_not_null()
	assert_object(figure.figure()).override_failure_message("drawn from the town's sheet for this look").is_same(
		OverworldArt.player_character(KIT_LOOK)
	)
	assert_vector(Vector2(figure.figure().frame) * figure.figure().scale).is_equal(Vector2(OverworldScale.PERSON))
	assert_vector(figure.custom_minimum_size).is_equal(Vector2(OverworldScale.PERSON) * CharacterStand.ZOOM)
