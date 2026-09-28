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
