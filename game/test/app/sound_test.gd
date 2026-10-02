extends GdUnitTestSuite
## The Sound bus ends in one limiter however often the buses are set up, and the short sounds that repeat are jittered.


func test_the_sound_bus_has_exactly_one_limiter() -> void:
	Sound.set_volumes(1.0, 1.0)
	Sound.set_volumes(1.0, 1.0)
	var bus := AudioServer.get_bus_index(Sound.SOUND_BUS)
	var limiters := 0
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectLimiter:
			limiters += 1
			assert_float((effect as AudioEffectLimiter).ceiling_db).is_less(0.0)
	assert_int(limiters).is_equal(1)


func test_the_music_bus_is_left_alone() -> void:
	Sound.set_volumes(1.0, 1.0)
	var bus := AudioServer.get_bus_index(Sound.MUSIC_BUS)
	assert_int(AudioServer.get_bus_effect_count(bus)).is_equal(0)


func test_only_short_repeating_sounds_are_jittered() -> void:
	for id: String in ["sfx-glyph", "sfx-card-place", "sfx-card-flick", "sfx-card-slide"]:
		assert_float(float(Sound.JITTER.get(id, 0.0))).is_between(0.01, 0.1)
	assert_bool(Sound.JITTER.has("sfx-hit-compile")).is_false()


func test_every_cast_tier_has_its_own_sound_with_takes() -> void:
	for tier in MagicCircle.TIERS.size():
		var id: String = MagicCircle.TIERS[tier].sound
		assert_int(Sound.takes(id).size()).override_failure_message(id).is_greater_equal(2)
