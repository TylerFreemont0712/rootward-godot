extends GdUnitTestSuite
## A sprite skin (Vesper, ADR-0008): its clips load, a clip it was not drawn with plays a stand-in, and a cast's
## wind-up reaches its release frame just as the stage launches the bolts.

var vesper: SpriteCharacter


func before_test() -> void:
	vesper = auto_free(SpriteCharacter.create("vesper"))
	vesper.size = Vector2(360, 480)


func test_vesper_has_her_idle_and_her_cast() -> void:
	assert_bool(SpriteCharacter.exists("vesper")).is_true()
	assert_bool(vesper.has_clips()).is_true()
	assert_str(vesper.clip).is_equal("idle-breathe")
	vesper.play("cast-light")
	assert_str(vesper.clip).is_equal("cast-light")


func test_a_clip_she_was_not_drawn_with_plays_its_stand_in() -> void:
	vesper.play("cast-heavy")
	assert_str(vesper.clip).is_equal("cast-light")
	vesper.play("guard")
	assert_str(vesper.clip).is_equal("idle-breathe")
	vesper.play("no-such-clip")
	assert_str(vesper.clip).is_equal("idle-breathe")


func test_the_cast_releases_when_the_bolts_launch() -> void:
	var info: Dictionary = vesper.manifest.clips["cast-light"]
	var release := int(info.releaseFrame)
	assert_int(vesper._frame_at(info, 0.0)).is_equal(0)
	assert_int(vesper._frame_at(info, SpriteCharacter.RELEASE_MS / 1000.0)).is_equal(release)
	# After the release the clip plays at its own rate.
	assert_int(vesper._frame_at(info, SpriteCharacter.RELEASE_MS / 1000.0 + 1.0)).is_equal(release + int(info.fps))


func test_the_hand_is_on_the_foe_side_of_her_body_at_the_release() -> void:
	vesper.play("cast-light")
	var hand := vesper.hand_point()
	assert_float(hand.x).is_greater(vesper.size.x * 0.55)
	assert_float(hand.y).is_less(vesper.size.y * 0.6)


func test_a_skin_without_sprites_is_not_a_sprite_skin() -> void:
	assert_bool(SpriteCharacter.exists("emberfox")).is_false()
