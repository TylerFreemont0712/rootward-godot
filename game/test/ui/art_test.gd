extends GdUnitTestSuite
## Every picture and sound the Shardrun content names exists, and anything missing is null rather than an error.


func test_everything_the_content_names_is_there() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var missing: Array[String] = []
	for layer: Dictionary in catalog.config.layers:
		for key: String in ["backdrop", "boss_backdrop"]:
			if layer.has(key) and Art.texture("backgrounds/" + layer[key]) == null:
				missing.append("backgrounds/" + layer[key])
		for key: String in ["music", "battle_music", "boss_music"]:
			if layer.has(key) and Art.music(layer[key]) == null:
				missing.append("audio/" + layer[key])
	var foes: Array = (catalog.foes as Dictionary).values()
	foes.append_array((catalog.programs.foes as Dictionary).values())
	for foe: Dictionary in foes:
		if Art.texture("foes/" + foe.sprite) == null:
			missing.append("foes/" + foe.sprite)
	for relic: Dictionary in catalog.relics.values():
		if Art.texture("shardrun/relic-" + relic.icon) == null:
			missing.append("shardrun/relic-" + relic.icon)
	# The program run's own relics and cards (ADR-0016): every relic's icon and every card's picture.
	for relic: Dictionary in catalog.programs.relics.values():
		var icon := "shardrun/relic-" + String(relic.get("icon", relic.id))
		if Art.texture(icon) == null:
			missing.append(icon)
	for card: Dictionary in catalog.programs.cards.values():
		if Art.texture(ShardrunViews.art(card)) == null:
			missing.append(ShardrunViews.art(card))
	assert_array(missing).override_failure_message("missing: %s" % [missing]).is_empty()


func test_music_loops_at_its_loop_point() -> void:
	var stream := Art.music("music-battle-salvage") as AudioStreamOggVorbis
	assert_bool(stream.loop).is_true()
	assert_float(stream.loop_offset).is_equal_approx(7.2927, 0.0001)


func test_missing_art_is_null() -> void:
	assert_object(Art.texture("backgrounds/nowhere")).is_null()
	assert_object(Art.sound("sfx-nothing")).is_null()
	assert_object(Art.music("music-nothing")).is_null()
