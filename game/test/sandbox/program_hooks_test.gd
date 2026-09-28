extends GdUnitTestSuite
## An import's hooks run for real in the sandbox (ADR-0018): the import card's own function, on the volley, before or
## after every card of its role, in both languages.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _run(language: String, cards: Array, hooks: Array) -> Dictionary:
	var shards: Array[Dictionary] = []
	for id: String in cards:
		shards.append(catalog.shards[id])
	var spells: Array[Dictionary] = [{"id": "p", "shards": shards}]
	var with_cards: Array = []
	for hook: Dictionary in hooks:
		var with_card := hook.duplicate()
		with_card.card = catalog.shards[hook.card]
		with_cards.append(with_card)
	var input := {
		"bolts": [{"power": 3, "element": "none"}, {"power": 9, "element": "none"}, {"power": 5, "element": "none"}],
		"battle": ShardExamples.DEFAULT_BATTLE,
		"limit": 128,
		"trace_limit": 32,
		"hooks": with_cards,
	}
	return SpellHarness.run(language, spells, input).get("p", {})


func _powers(bolts: Array) -> Array:
	return bolts.map(func(bolt: Dictionary) -> int: return int(bolt.power))


func test_bisect_sorts_what_each_source_makes() -> void:
	var hooks := [{"card": "import-bisect", "when": "after", "role": "source"}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		if not Sandbox.is_available(language):
			continue
		var run := _run(language, ["literal"], hooks)
		assert_bool(run.ok).override_failure_message(str(run.get("reason", ""))).is_true()
		assert_array(_powers(run.bolts)).is_equal([3, 5, 9, 9])


func test_heapq_hands_each_strike_the_strongest_bolt_first() -> void:
	var hooks := [{"card": "import-heapq", "when": "before", "role": "strike"}]
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		if not Sandbox.is_available(language):
			continue
		var plain := _run(language, ["round-robin"], [])
		var heaped := _run(language, ["round-robin"], hooks)
		assert_bool(heaped.ok).override_failure_message(str(heaped.get("reason", ""))).is_true()
		assert_array(_powers(plain.bolts)).is_equal([3, 9, 5])
		assert_array(_powers(heaped.bolts)).is_equal([9, 5, 3])
		# The strike's step still reports the volley it was given, whole.
		assert_int(int(heaped.trace[0].given)).is_equal(3)


func test_new_imports_compose_with_sources_shapes_and_strikes() -> void:
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var grouped := _run(language, ["literal"], [{"card": "import-collections", "when": "after", "role": "source"}])
		assert_bool(grouped.ok).is_true()
		assert_array(_powers(grouped.bolts)).is_equal([26])
		var shaped := _run(language, ["amplify"], [{"card": "import-operator", "when": "after", "role": "shape"}])
		assert_bool(shaped.ok).is_true()
		assert_array(_powers(shaped.bolts)).is_equal([7, 13, 9])
		var copied := _run(language, ["round-robin"], [{"card": "import-copy", "when": "before", "role": "strike"}])
		assert_bool(copied.ok).is_true()
		assert_array(_powers(copied.bolts)).is_equal([3, 9, 5, 3])


func test_elemental_source_mirror_and_window_make_a_mixed_volley() -> void:
	for language: String in [SandboxJob.PYTHON, SandboxJob.JAVASCRIPT]:
		var run := _run(language, ["spark-constant", "recursive-mirror", "sliding-window", "zip-ward"], [])
		assert_bool(run.ok).override_failure_message(str(run.get("reason", ""))).is_true()
		# Original powers 3,9,5,6,3,3,5,2 become sliding sums 3,12,17,20,14,12,11,10 before being split.
		assert_array(_powers(run.bolts)).is_equal([2, 1, 6, 6, 9, 8, 10, 10, 7, 7, 6, 6, 6, 5, 5, 5])
		(
			assert_int(
				(run.bolts as Array).filter(func(bolt: Dictionary) -> bool: return bolt.get("block", false)).size()
			)
			. is_equal(8)
		)
