extends GdUnitTestSuite
## Lanternroot's content loads clean, and its cross-checks catch letters that point at nothing.


func test_the_town_and_its_letters_load_without_a_problem() -> void:
	var loaded := LanternContent.load_town()
	assert_array(loaded.diagnostics).is_empty()
	var catalog: Dictionary = loaded.catalog
	assert_int((catalog.order as Array).size()).is_equal(10)
	assert_str(catalog.order[0]).is_equal("lamp-oil")
	assert_int(LanternRules.last_day(catalog)).is_equal(4)
	for id: String in catalog.order:
		var request: Dictionary = catalog.requests[id]
		assert_bool((request.solution as Dictionary).has_all(["python", "javascript"])).is_true()
		# Whole numbers reach the sandbox as ints, so Python sees 2 rather than 2.0.
		for example: Dictionary in request.examples:
			for arg: Variant in example.args:
				assert_bool(typeof(arg) != TYPE_FLOAT).override_failure_message("%s: %s" % [id, arg]).is_true()


func test_cross_checks_name_broken_references() -> void:
	var catalog: Dictionary = LanternContent.load_town().catalog.duplicate(true)
	catalog.requests.festival.requires = ["nowhere"]
	catalog.requests["big-oven"].replaces = "greeting"
	var diagnostics: Array[Dictionary] = []
	LanternContent._cross_check(catalog, diagnostics)
	var messages := diagnostics.map(func(d: Dictionary) -> String: return d.message)
	assert_array(messages).contains(
		['requires an unknown letter "nowhere"', 'must change the same function as "greeting"']
	)
