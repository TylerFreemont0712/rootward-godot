extends GdUnitTestSuite
## What a program run offers after a fight (ProgramRewards, Paradigm Update B4): mostly the run's own paradigm, a
## neutral card or another paradigm's now and then, one of the player's own always, and an elite's fourth card from
## elsewhere.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _state(seed: String, paradigm := "greedy", focus := "") -> Dictionary:
	var options := {"seed": seed, "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.paradigm = paradigm
	state.focus = focus
	state.layer = 1
	return state


func _group(id: String, state: Dictionary) -> String:
	return ProgramRewards._group_of(catalog.shards[id], state)


func _tally(kind: String, runs: int, paradigm := "greedy", focus := "") -> Dictionary:
	var counts := {"own": 0, "neutral": 0, "other": 0, "cards": 0, "without_own": 0, "focus": 0}
	for n in runs:
		var state := _state("reward-%d" % n, paradigm, focus)
		var offer := ProgramRewards.draft_cards(state, kind, catalog)
		var own := 0
		for id: String in offer:
			counts[_group(id, state)] += 1
			counts.cards += 1
			if focus != "" and catalog.shards[id].get("focus", "") == focus:
				counts.focus += 1
		if offer.filter(func(id: String) -> bool: return _group(id, state) == "own").is_empty():
			counts.without_own += 1
	return counts


func test_a_fight_offers_three_cards_and_always_one_of_your_own() -> void:
	var counts := _tally("fight", 300)
	assert_int(counts.cards).is_equal(900)
	assert_int(counts.without_own).is_equal(0)


func test_the_shares_are_mostly_own_some_neutral_some_other() -> void:
	var counts := _tally("fight", 400)
	var total := float(counts.cards)
	# 50 / 30 / 20 before the own-card guarantee nudges the own share up a little.
	assert_float(counts.own / total).is_between(0.45, 0.68)
	assert_float(counts.neutral / total).is_between(0.15, 0.36)
	assert_float(counts.other / total).is_between(0.08, 0.28)


func test_every_paradigm_can_still_reach_other_paradigms_cards() -> void:
	for paradigm: String in ["greedy", "brute-force", "dynamic", "search-index", "divide-conquer"]:
		var counts := _tally("fight", 120, paradigm)
		assert_int(counts.other).override_failure_message("%s never saw another paradigm" % paradigm).is_greater(0)


func test_an_elite_adds_a_fourth_card_from_another_paradigm() -> void:
	for n in 60:
		var state := _state("elite-%d" % n)
		var offer := ProgramRewards.draft_cards(state, "elite", catalog)
		assert_int(offer.size()).is_equal(4)
		assert_str(_group(offer[3], state)).is_equal("other")


func test_a_guardian_never_offers_another_paradigms_cards() -> void:
	for n in 60:
		var state := _state("boss-%d" % n)
		for id: String in ProgramRewards.draft_cards(state, "boss", catalog):
			assert_str(_group(id, state)).is_not_equal("other")


func test_the_focus_cards_weigh_double_inside_your_own_share() -> void:
	var rules: Dictionary = ProgramRules.config_of(catalog).rewards
	var state := _state("focus-weight", "greedy", "heap")
	var pool := ShardrunCatalog.sorted_values(catalog.shards).filter(
		func(card: Dictionary) -> bool: return card.get("draftable", true)
	)
	var bucket := ProgramRewards._left(pool, state, [], "uncommon", "own")
	var focus_cards := bucket.filter(func(card: Dictionary) -> bool: return card.get("focus", "") == "heap")
	assert_int(focus_cards.size()).is_greater(0)
	var picked := 0
	var runs := 3000
	for n in runs:
		var id := ProgramRewards._pick(pool, state, [], "uncommon", "own", rules, Rng.create("focus-%d" % n, "x"))
		if catalog.shards[id].get("focus", "") == "heap":
			picked += 1
	var weight := float(rules.focus_weight)
	var expected := weight * focus_cards.size() / (weight * focus_cards.size() + bucket.size() - focus_cards.size())
	assert_float(float(picked) / runs).is_between(expected - 0.04, expected + 0.04)


func test_the_same_room_always_offers_the_same_cards() -> void:
	var first := ProgramRewards.draft_cards(_state("same"), "fight", catalog)
	var second := ProgramRewards.draft_cards(_state("same"), "fight", catalog)
	assert_array(first).is_equal(second)
	assert_int(first.size()).is_equal(3)
	assert_array(first).has_size(3)
	var distinct := {}
	for id: String in first:
		distinct[id] = true
	assert_int(distinct.size()).is_equal(3)


func test_pity_grows_without_a_rare_card_and_resets_when_one_is_offered() -> void:
	var step := float(ProgramRules.config_of(catalog).rewards.pity)
	var saw_growth := false
	var saw_reset := false
	var state := _state("pity")
	for n in 120:
		state.seed = "pity-%d" % n
		var before := float(state.get("rare_pity", 0.0))
		var offer := ProgramRewards.draft_cards(state, "fight", catalog)
		var rare := offer.any(func(id: String) -> bool: return catalog.shards[id].rarity == "rare")
		if rare:
			assert_float(float(state.rare_pity)).is_equal(0.0)
			saw_reset = saw_reset or before > 0.0
		else:
			assert_float(float(state.rare_pity)).is_equal_approx(before + step, 0.0001)
			saw_growth = true
	assert_bool(saw_growth).is_true()
	assert_bool(saw_reset).is_true()


func test_a_run_without_a_paradigm_keeps_the_old_draw() -> void:
	var state := _state("legacy")
	state.paradigm = ""
	assert_bool(ProgramRewards.applies(state)).is_false()
	var offer := ShardrunBattle.draft_shards(state, "fight", catalog)
	assert_int(offer.size()).is_equal(int(catalog.balance.reward_choices))
