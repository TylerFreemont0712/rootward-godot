extends GdUnitTestSuite


func test_japanese_editions_cover_the_same_keys_and_keep_format_and_code_tokens() -> void:
	var overlay := ContentLocale.load_overlay("ja")
	assert_array(overlay.diagnostics).is_empty()
	assert_int(overlay.kanji_strings.size()).is_equal(overlay.strings.size())
	var changed := 0
	var mismatches: Array[String] = []
	var slots := RegEx.create_from_string("%[-+0-9.]*[sdf]|\\{[A-Za-z_][A-Za-z_0-9]*\\}|\\{[0-9]+\\}")
	var quoted := RegEx.create_from_string("`[^`]*`|\"[^\"\\n]*\"")
	for english: String in overlay.strings:
		var kana := String(overlay.strings[english])
		var adult := String(overlay.kanji_strings.get(english, ""))
		changed += 1 if kana != adult else 0
		for regex: RegEx in [slots, quoted]:
			var before: Array[String] = []
			var after: Array[String] = []
			for found: RegExMatch in regex.search_all(kana):
				before.append(found.get_string())
			for found: RegExMatch in regex.search_all(adult):
				after.append(found.get_string())
			if before != after:
				mismatches.append(english + " : " + str(before) + " => " + str(after))
	assert_array(mismatches).is_empty()
	assert_int(changed).is_greater(2000)


func test_japanese_loads_and_translates_prose_only() -> void:
	var overlay := ContentLocale.load_overlay("ja")
	assert_array(overlay.diagnostics).is_empty()
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var ja := ContentLocale.localize(catalog, overlay.strings)
	assert_str(ja.shards.adapt.name).is_equal("適応")
	assert_str(ja.shards.adapt.function).is_equal("adapt")
	assert_str(ja.shards.adapt.code.python).is_equal(catalog.shards.adapt.code.python)
	assert_str(ja.config.start.spells[0].name).is_equal("Bolt")  # spell names become function names: never translated
	assert_str(catalog.shards.adapt.name).is_equal("Adapt")  # the English catalog is untouched


func test_coverage_names_what_is_missing() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var overlay := ContentLocale.load_overlay("ja")
	var report := ContentLocale.coverage(catalog, overlay.strings)
	assert_int(report.total).is_greater(200)
	var without := (overlay.strings as Dictionary).duplicate()
	without.erase("Adapt")
	assert_array(ContentLocale.coverage(catalog, without).missing).contains(["Adapt"])


func test_unknown_locales_are_simply_english() -> void:
	var overlay := ContentLocale.load_overlay("xx")
	assert_int((overlay.strings as Dictionary).size()).is_equal(0)


func test_the_program_runs_content_is_translated_and_its_code_is_not() -> void:
	var overlay := ContentLocale.load_overlay("ja")
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var ja := ContentLocale.localize(catalog, overlay.strings)
	assert_str(ja.programs.cards["merge-sort"].name).is_equal("マージソート")
	assert_str(ja.programs.cards["merge-sort"].function).is_equal("merge_sort")
	assert_str(ja.programs.relics["jit-compiler"].name).is_equal("JITコンパイラ")
	assert_str(ja.programs.foes["deadlock-lock-a"].name).is_equal("ゴーレムのロックA")
	assert_str(ja.programs.config.paradigms[0].name).is_equal("分割統治")
	assert_str(ja.programs.config.keywords.once).contains("一度だけ")
	assert_str(ProgramRules.catalog_for(ja).config.layers[2].name).is_equal("割り込み鋳造所")
	# A name that is code stays code.
	assert_str(ja.programs.cards["import-heapq"].name).is_equal("import heapq")


func test_every_program_card_speaks_japanese() -> void:
	var overlay := ContentLocale.load_overlay("ja")
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var missing: Array[String] = []
	for card: Dictionary in catalog.programs.cards.values():
		for text: String in [card.name, card.summary]:
			if not (overlay.strings as Dictionary).has(text):
				missing.append(text)
	assert_array(missing).override_failure_message("no Japanese for: %s" % [missing]).is_empty()
