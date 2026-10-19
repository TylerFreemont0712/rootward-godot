extends GdUnitTestSuite
## How a character's frames are found (ADR-0063): the parts sheet the creator's looks build, the cast sheets
## pipeline/animation/cast.py draws, which look gets which, and the breath a still figure takes. A sheet drawn for an
## older tile is shown enlarged to this world's (ADR-0064).

const CAST_LAYOUT := {
	"frame": [32, 48],
	"ground": 46,
	"tile": OverworldScale.TILE,
	"rows": ["down", "up", "left", "right"],
	"columns": ["stop", "idle"],
}


func test_a_parts_sheet_mirrors_right_and_has_no_idle_frame() -> void:
	var sheet := CharacterSheet.parts(null, Vector2i(25, 35))
	assert_that(sheet.rect("down", CharacterSheet.STAND)).is_equal(Rect2i(0, 0, 25, 35))
	assert_that(sheet.rect("left", CharacterSheet.STEP_B)).is_equal(Rect2i(50, 70, 25, 35))
	assert_that(sheet.rect("right", CharacterSheet.STAND)).is_equal(sheet.rect("left", CharacterSheet.STAND))
	assert_bool(sheet.flipped("right")).is_true()
	assert_that(sheet.rect("up", CharacterSheet.IDLE)).is_equal(sheet.rect("up", CharacterSheet.STAND))
	assert_bool(sheet.breathes()).is_false()
	assert_int(sheet.ground).is_equal(35)


func test_a_cast_sheet_has_a_row_per_facing_and_steps_on_its_idle_frame() -> void:
	var sheet := CharacterSheet.cast(null, CAST_LAYOUT)
	assert_that(sheet.frame).is_equal(Vector2i(32, 48))
	assert_int(sheet.ground).is_equal(46)
	assert_that(sheet.rect("right", CharacterSheet.STAND)).is_equal(Rect2i(0, 144, 32, 48))
	assert_that(sheet.rect("up", CharacterSheet.IDLE)).is_equal(Rect2i(32, 48, 32, 48))
	assert_int(sheet.rect("down", CharacterSheet.STEP_A).position.x).is_equal(32)
	assert_bool(sheet.flipped("right")).is_false()
	assert_bool(sheet.breathes()).is_true()


func test_a_cast_sheet_without_a_right_row_draws_left_mirrored() -> void:
	var layout := CAST_LAYOUT.duplicate()
	layout.rows = ["down", "up", "left"]
	var sheet := CharacterSheet.cast(null, layout)
	assert_that(sheet.rect("right", CharacterSheet.STAND)).is_equal(sheet.rect("left", CharacterSheet.STAND))
	assert_bool(sheet.flipped("right")).is_true()


func test_a_look_finds_its_cast_sheet_by_what_it_shows() -> void:
	var made := {
		"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "main": "cloth_teal"}
	}
	var index := {"sheets": {"player": {"file": "player.png", "look": made}}}
	# An unused part and a colour left at its default are not differences.
	var same := {
		"outfit": "outfit/tunic",
		"hair": "hair/short",
		"hat": "none",
		"colours": {"skin": "skin_peach", "main": "cloth_teal", "eyes": "eyes_dark"},
	}
	assert_str(OverworldArt.cast_file(index, same)).is_equal("player.png")
	var other := same.duplicate(true)
	other.hair = "hair/long"
	assert_str(OverworldArt.cast_file(index, other)).is_equal("")
	assert_str(OverworldArt.cast_file({}, same)).is_equal("")


func test_a_still_figure_settles_for_the_end_of_each_breath() -> void:
	assert_int(Walker.breath_pose(0.0)).is_equal(CharacterSheet.STAND)
	assert_int(Walker.breath_pose(Walker.BREATH * 0.5)).is_equal(CharacterSheet.STAND)
	assert_int(Walker.breath_pose(Walker.BREATH * 0.9)).is_equal(CharacterSheet.IDLE)
	assert_int(Walker.breath_pose(Walker.BREATH * 2.9)).is_equal(CharacterSheet.IDLE)


func test_a_walker_stands_its_cast_sheet_on_the_ground_row() -> void:
	var image := Image.create(64, 192, false, Image.FORMAT_RGBA8)
	var walker: Walker = auto_free(Walker.new(CharacterSheet.cast(ImageTexture.create_from_image(image), CAST_LAYOUT)))
	add_child(walker)
	walker.place(Vector2i(3, 4), "left")
	var sprite: Sprite2D = walker.get("_sprite")
	assert_that(sprite.position).is_equal(Vector2(-16, -46))
	assert_that(sprite.scale).is_equal(Vector2.ONE)
	assert_that(sprite.region_rect).is_equal(Rect2(0, 96, 32, 48))
	assert_bool(sprite.flip_h).is_false()


func test_a_sheet_drawn_for_16_px_tiles_is_shown_enlarged_on_its_ground_row() -> void:
	var old := CAST_LAYOUT.duplicate()
	old.erase("tile")
	var image := Image.create(64, 192, false, Image.FORMAT_RGBA8)
	var walker: Walker = auto_free(Walker.new(CharacterSheet.cast(ImageTexture.create_from_image(image), old)))
	add_child(walker)
	walker.place(Vector2i(3, 4), "down")
	var sprite: Sprite2D = walker.get("_sprite")
	assert_that(sprite.scale).is_equal(Vector2.ONE * 2.5)
	assert_that(sprite.position).is_equal(Vector2(-40, -115))
	assert_float(CharacterSheet.parts(null, Vector2i(25, 35)).scale).is_equal(2.5)


func test_every_cast_sheet_in_the_index_fits_its_layout() -> void:
	var index := OverworldArt.cast_index()
	if index.is_empty():
		return
	var layout := CharacterSheet.cast(null, index)
	var expected := Vector2i(
		layout.frame.x * (index.columns as Array).size(), layout.frame.y * (index.rows as Array).size()
	)
	for id: String in index.sheets:
		var texture := OverworldArt.texture(OverworldArt.CAST + String(index.sheets[id].file))
		assert_object(texture).override_failure_message("no picture for %s" % id).is_not_null()
		if texture != null:
			assert_that(Vector2i(texture.get_size())).override_failure_message(id).is_equal(expected)
