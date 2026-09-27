extends GdUnitTestSuite
## A program run's relics are tiered, and where they are found decides the tiers they can be (ProgramLoot).

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _start(seed := "loot-test") -> Dictionary:
	var options := {"seed": seed, "language": "python", "difficulty": "beginner", "playstyle": "program"}
	return Shardrun.start(catalog, options)


func _tiers(ids: Array) -> Array:
	return ids.map(func(id: String) -> String: return catalog.relics[id].tier)


func test_every_program_relic_has_a_tier_and_spellforge_keeps_its_rarities() -> void:
	for relic: Dictionary in catalog.relics.values():
		assert_array(ProgramSchemas.TIERS).contains([relic.tier])
		assert_bool(relic.has("rarity")).is_false()
	# The Spellforge catalog is untouched: its firewall is still a common relic by rarity.
	var shared: Dictionary = ContentLoader.load_shardrun().catalog.relics
	assert_str(String(shared.firewall.rarity)).is_equal("common")


func test_an_elite_offers_only_rare_or_better() -> void:
	for n in 12:
		var state := _start("elite-%d" % n)
		for tier: String in _tiers(ProgramLoot.draft_relics(state, "elite", 1, catalog)):
			assert_array(["rare", "epic", "legendary"]).contains([tier])


func test_a_guardian_offers_only_epic_or_legendary() -> void:
	for n in 12:
		var state := _start("boss-%d" % n)
		var offered := ProgramLoot.draft_relics(state, "boss", 3, catalog)
		assert_int(offered.size()).is_greater(0)
		for tier: String in _tiers(offered):
			assert_array(["epic", "legendary"]).contains([tier])


func test_offers_are_distinct_and_never_what_the_run_holds() -> void:
	var state := _start()
	var first := ProgramLoot.draft_relics(state, "treasure", 3, catalog)
	assert_int(first.size()).is_equal(3)
	assert_int({}.merged({first[0]: 1, first[1]: 1, first[2]: 1}).size()).is_equal(3)
	state.relics = first.duplicate()
	for id: String in ProgramLoot.draft_relics(state, "treasure", 3, catalog):
		assert_bool(id in first).is_false()


func test_a_tier_that_ran_dry_gives_way_to_the_others() -> void:
	var state := _start()
	# Hold every rare: an elite must still offer something, from its other tiers.
	for relic: Dictionary in catalog.relics.values():
		if relic.tier == "rare":
			(state.relics as Array).append(relic.id)
	var offered := ProgramLoot.draft_relics(state, "elite", 1, catalog)
	assert_int(offered.size()).is_equal(1)
	assert_array(["epic", "legendary"]).contains([catalog.relics[offered[0]].tier])


func test_the_same_room_offers_the_same() -> void:
	var state := _start()
	assert_array(ProgramLoot.draft_relics(state, "boss", 3, catalog)).is_equal(
		ProgramLoot.draft_relics(state.duplicate(true), "boss", 3, catalog)
	)


func test_curses_are_never_offered_as_loot() -> void:
	for where: String in ["treasure", "elite", "boss"]:
		for id: String in ProgramLoot.draft_relics(_start(where), where, 3, catalog):
			assert_bool(catalog.relics[id].get("cursed", false)).is_false()


func test_tiers_count_one_to_five_and_curses_zero() -> void:
	assert_int(ProgramLoot.tier_number({"tier": "common"})).is_equal(1)
	assert_int(ProgramLoot.tier_number({"tier": "legendary"})).is_equal(5)
	assert_int(ProgramLoot.tier_number({"tier": "common", "cursed": true})).is_equal(0)
