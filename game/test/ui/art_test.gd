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


func test_every_shard_and_forge_upgrade_has_art() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var missing: Array[String] = []
	for shard_id: String in catalog.shards:
		var art_id := ShardrunViews.art(catalog.shards[shard_id], shard_id)
		if Art.texture(art_id) == null:
			missing.append("%s (%s)" % [shard_id, art_id])
	assert_array(missing).override_failure_message("missing shard art: %s" % [missing]).is_empty()


func test_shared_effects_use_the_same_texture() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var pairs := {"amplify": "amplify", "fork": "fork", "charge": "arc", "chill": "chill", "sweep": "scatter"}
	for card_id: String in pairs:
		var card: Dictionary = catalog.programs.cards[card_id]
		var shard: Dictionary = catalog.shards[pairs[card_id]]
		assert_str(ShardrunViews.art(card)).is_equal(ShardrunViews.art(shard))
		assert_object(Art.texture(ShardrunViews.art(card))).is_same(Art.texture(ShardrunViews.art(shard)))


func test_shared_icon_schema_rejects_paths_outside_the_icon_library() -> void:
	var loaded: Dictionary = ContentLoader.load_shardrun().catalog.programs.cards.amplify.duplicate(true)
	loaded.icon = "shardrun/shard-amplify"
	assert_array(Schema.check(ProgramSchemas.card(), loaded).errors).is_empty()
	for invalid: String in ["../shard-amplify", "backgrounds/arena-salvage", "shardrun/shard-amplify.png"]:
		loaded.icon = invalid
		assert_str(" ".join(Schema.check(ProgramSchemas.card(), loaded).errors)).contains("icon:")


func test_program_cards_no_longer_use_low_resolution_placeholders() -> void:
	var cards: Dictionary = ContentLoader.load_shardrun().catalog.programs.cards
	var placeholders: Array[String] = []
	for card: Dictionary in cards.values():
		var texture := Art.texture(ShardrunViews.art(card))
		if texture == null or mini(texture.get_width(), texture.get_height()) < 128:
			placeholders.append(String(card.id))
	assert_array(placeholders).override_failure_message("unfinished program icons: %s" % [placeholders]).is_empty()


func test_every_layer_names_music_that_is_there_and_loops() -> void:
	var loops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Art.LOOPS))
	var missing: Array[String] = []
	for layer: Dictionary in ContentLoader.load_shardrun().catalog.config.layers:
		for key: String in ["music", "battle_music", "boss_music", "rest_music"]:
			var id := String(layer.get(key, ""))
			if id != "" and (Art.music(id) == null or not loops.has(id)):
				missing.append("%s.%s: %s" % [layer.id, key, id])
	assert_array(missing).override_failure_message("missing: %s" % [missing]).is_empty()


func test_music_loops_at_its_loop_point() -> void:
	var loops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Art.LOOPS))
	var stream := Art.music("music-battle-salvage") as AudioStreamOggVorbis
	assert_bool(stream.loop).is_true()
	assert_float(stream.loop_offset).is_equal_approx(float(loops["music-battle-salvage"].loopStart), 0.0001)
	assert_float(stream.loop_offset).is_greater(1.0)


func test_missing_art_is_null() -> void:
	assert_object(Art.texture("backgrounds/nowhere")).is_null()
	assert_object(Art.sound("sfx-nothing")).is_null()
	assert_object(Art.music("music-nothing")).is_null()
