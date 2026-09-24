extends GdUnitTestSuite


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
