extends GdUnitTestSuite
## The stacking magic circle's rules (ADR-0039): the tier a spell's shard count writes, and the layer each shard adds.


func _cards(ids: Array, role := "") -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for id: String in ids:
		cards.append({"id": id, "name": id.capitalize(), "role": role})
	return cards


func test_the_tier_follows_the_shard_count() -> void:
	var expected := {0: 0, 1: 0, 2: 0, 3: 1, 4: 1, 5: 2, 6: 3, 7: 3, 12: 3, -1: 0}
	for count: int in expected:
		assert_int(CircleLayers.tier_for(count)).is_equal(expected[count])


func test_each_tier_has_room_for_the_shards_that_write_it() -> void:
	for count in range(0, 13):
		var tier := CircleLayers.tier_for(count)
		assert_int(CircleLayers.capacity(tier)).is_greater_equal(mini(count, 6))
	# And no tier is larger than the most shards that call for it.
	assert_array(CircleLayers.TIER_SHARDS).is_equal([2, 4, 5, 6])


func test_a_layer_for_every_shard_never_more_than_the_tier_holds() -> void:
	for count in range(0, 10):
		var ids: Array = []
		for i in count:
			ids.append("card-%d" % i)
		var layers := CircleLayers.plan(_cards(ids))
		assert_int(layers.size()).is_equal(mini(count, 6))
		assert_int(layers.size()).is_less_equal(CircleLayers.capacity(CircleLayers.tier_for(count)))
		for slot in layers.size():
			assert_int(int(layers[slot].slot)).is_equal(slot)
			assert_int(int(layers[slot].count)).is_equal(layers.size())


func test_a_shards_look_is_the_same_every_time() -> void:
	var fork := {"id": "fork", "name": "Fork", "role": "source"}
	assert_str(CircleLayers.kind_of(fork)).is_equal(CircleLayers.kind_of(fork.duplicate()))
	assert_int(CircleLayers.seed_of(fork)).is_equal(Rng.hash_string("fork"))
	assert_dict(CircleLayers.plan([fork])[0]).is_equal(CircleLayers.plan([fork.duplicate()])[0])
	# Pinned: a look changes only on purpose (it is what a returning player has learnt to read).
	var pinned := {}
	for card: Dictionary in CircleLayers.DEMO_CARDS:
		pinned[card.id] = CircleLayers.kind_of(card)
	(
		assert_dict(pinned)
		. is_equal(
			{
				"fork": "rosette",
				"bubble-sort": "runes",
				"binary-execute": "spiral",
				"exhaustive-ward": "lattice",
				"kadane": "dashes",
				"import-math": "satellites",
			}
		)
	)


func test_a_role_picks_its_looks_from_its_family() -> void:
	for role: String in CircleLayers.FAMILIES:
		for id: String in ["a", "b", "c", "d", "e", "knapsack-strike", "fork"]:
			assert_array(CircleLayers.FAMILIES[role]).contains([CircleLayers.kind_of({"id": id, "role": role})])
	# A card with no role chooses among all of them.
	assert_array(CircleLayers.KINDS).contains([CircleLayers.kind_of({"id": "amplify"})])


func test_every_look_can_be_reached_and_is_a_known_one() -> void:
	var reachable := {}
	for family: Array in CircleLayers.FAMILIES.values():
		for kind: String in family:
			reachable[kind] = true
	for kind in CircleLayers.KINDS:
		assert_bool(reachable.has(kind)).is_true()
	assert_int(CircleLayers.KINDS.size()).is_greater_equal(10)


func test_different_shards_never_share_a_look_in_one_spell() -> void:
	# Many ids in one role: their natural looks collide, the plan still gives each its own.
	for trial in 20:
		var ids: Array = []
		for i in 6:
			ids.append("shard-%d-%d" % [trial, i])
		var layers := CircleLayers.plan(_cards(ids, "shape"))
		var seen := {}
		for layer in layers:
			assert_bool(seen.has(layer.kind)).is_false()
			seen[layer.kind] = true


func test_the_same_shard_twice_keeps_its_look_and_turns_the_other_way() -> void:
	var layers := CircleLayers.plan(_cards(["amplify", "amplify", "amplify", "amplify"], "shape"))
	assert_int(layers.size()).is_equal(4)
	for layer in layers:
		assert_str(layer.kind).is_equal(layers[0].kind)
	assert_int(int(layers[0].dir)).is_not_equal(int(layers[1].dir))
	assert_int(int(layers[0].dir)).is_equal(int(layers[2].dir))


func test_a_spell_of_different_roles_is_composed_differently_from_another() -> void:
	var first := CircleLayers.plan(CircleLayers.demo_cards(6))
	var second := CircleLayers.plan(_cards(["amplify", "chill", "kindle", "charge", "ward", "fork"]))
	var kinds_first: Array = first.map(func(layer: Dictionary) -> String: return layer.kind)
	var kinds_second: Array = second.map(func(layer: Dictionary) -> String: return layer.kind)
	assert_array(kinds_first).is_not_equal(kinds_second)


func test_the_rune_words_are_the_cards_function_names() -> void:
	assert_str(CircleLayers.call_name({"name": "Knapsack Strike"})).is_equal("knapsackStrike()")
	assert_str(CircleLayers.call_name({"name": "import math"})).is_equal("importMath()")
	assert_str(CircleLayers.call_name({"name": ""})).is_equal("")
	assert_str(CircleLayers.words([{"name": "Fork"}, {"name": "Chill"}])).is_equal("fork()  chill()  ")
	assert_str(CircleLayers.words([])).is_equal("")


func test_the_last_layer_is_whole_before_the_circle_completes() -> void:
	for count in range(1, 7):
		var last := CircleLayers.start_share(count - 1, count) + CircleLayers.DRAW
		assert_float(last).is_less_equal(0.97)
		for index in count - 1:
			assert_float(CircleLayers.start_share(index, count)).is_less(CircleLayers.start_share(index + 1, count))


func test_the_demonstration_spell_fills_each_tier() -> void:
	for tier in 4:
		var layers := CircleLayers.demo_plan(tier)
		assert_int(layers.size()).is_equal(CircleLayers.capacity(tier))
		assert_int(CircleLayers.tier_for(layers.size())).is_equal(tier)


func test_neighbouring_layers_turn_against_each_other() -> void:
	var layers := CircleLayers.plan(CircleLayers.demo_cards(6))
	for slot in layers.size() - 1:
		assert_int(int(layers[slot].dir) * int(layers[slot + 1].dir)).is_equal(-1)
