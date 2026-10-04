extends GdUnitTestSuite
## The paradigm and focus draft is a seeded, explicit pair of choices; older drafts keep their original route.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _start(seed := "focus-test") -> Dictionary:
	return Shardrun.start(
		catalog, {"seed": seed, "language": "javascript", "difficulty": "beginner", "playstyle": "program"}
	)


func _choose(state: Dictionary, command: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	assert_bool(result.ok).override_failure_message(str(result.get("error", ""))).is_true()
	return result.state if result.ok else state


func test_every_paradigm_offers_its_three_focuses_and_swaps_only_one_basic() -> void:
	for paradigm: Dictionary in ProgramRules.config_of(catalog).paradigms:
		var state := _start()
		state.draft.offers = [paradigm.id]
		var expected: Array = (state.deck as Array).duplicate()
		expected[expected.find(paradigm.swap.out)] = paradigm.swap["in"]
		expected.append_array(paradigm.signature)
		state = _choose(state, {"type": "pick-paradigm", "paradigm_id": paradigm.id})
		assert_array(state.deck).is_equal(expected)
		assert_array(state.relics).contains([paradigm.law])
		assert_array(state.draft.pack).is_empty()
		assert_int((state.draft.focus_offers as Array).size()).is_equal(3)
		var refused := Shardrun.step(state, {"type": "pick-focus", "focus_id": "wrong"}, catalog)
		assert_bool(refused.ok).is_false()
		assert_array(state.draft.pack).is_empty()
		for focus: Dictionary in paradigm.focuses:
			var chosen := _choose(state, {"type": "pick-focus", "focus_id": focus.id})
			assert_str(chosen.focus).is_equal(focus.id)
			assert_array(chosen.deck).contains([focus.signature])
			assert_int((chosen.deck as Array).size()).is_equal(11)
			assert_array(chosen.relics).contains([focus.relic])
			assert_int((chosen.draft.pack as Array).size()).is_equal(3)
			var again := Shardrun.step(chosen, {"type": "pick-focus", "focus_id": focus.id}, catalog)
			assert_bool(again.ok).is_false()
			assert_array(ProgramDraft.pack(chosen, 0, catalog)).is_equal(chosen.draft.pack)


func test_a_legacy_draft_goes_straight_to_its_pack_without_new_rules() -> void:
	var state := _start()
	state.draft.erase("focus_offers")
	state.erase("focus")
	var original: Array = (state.deck as Array).duplicate()
	var paradigm := ProgramDraft.paradigm_of(catalog, state.draft.offers[0])
	state = _choose(state, {"type": "pick-paradigm", "paradigm_id": paradigm.id})
	original.append_array(paradigm.signature)
	assert_array(state.deck).is_equal(original)
	assert_array(state.relics).is_empty()
	assert_int((state.draft.pack as Array).size()).is_equal(3)


func test_rule_relics_never_enter_loot_and_history_names_the_focus() -> void:
	var state := _start()
	state = _choose(state, {"type": "pick-paradigm", "paradigm_id": state.draft.offers[0]})
	state = _choose(state, {"type": "pick-focus", "focus_id": state.draft.focus_offers[0]})
	for where: String in ["treasure", "elite", "boss"]:
		for id: String in ProgramLoot.draft_relics(state, where, 100, catalog):
			assert_bool(catalog.relics[id].tier in ProgramSchemas.RULE_TIERS).is_false()
	state.status = "won"
	var record := RunHistory.entry(state, catalog, "2026-10-04T00:00:00", "vesper")
	assert_str(record.branch).is_equal("%s/%s" % [state.paradigm, state.focus])
	assert_str(RunHistory.subject(record)).starts_with("feat(%s):" % record.branch)


func test_new_snapshot_defaults_leave_spellforge_exactly_unchanged() -> void:
	var state := {"playstyle": "program", "battle": {"foes": []}}
	ShardrunSchemas.program_state_defaults(state)
	assert_str(state.focus).is_empty()
	assert_int(state.cycles).is_equal(0)
	assert_array(state.battle.index).is_empty()
	assert_array(state.battle.dp).is_empty()
	state.cycles = 123
	ShardrunSchemas.program_state_defaults(state)
	assert_int(state.cycles).is_equal(123)
	var spellforge := {"playstyle": "spellbook", "battle": {"foes": []}}
	var before := spellforge.duplicate(true)
	ShardrunSchemas.program_state_defaults(spellforge)
	assert_dict(spellforge).is_equal(before)


func test_draft_weights_favour_the_focus_inside_its_paradigm() -> void:
	var weighted := catalog.duplicate(true)
	weighted.programs.config.draft.pack_size = 1
	weighted.programs.config.neutral = []
	for paradigm: Dictionary in weighted.programs.config.paradigms:
		if paradigm.id == "greedy":
			paradigm.pool = ["sweep", "take-max"]
	weighted.shards.sweep.rarity = "common"
	weighted.shards.sweep.focus = "sprint"
	weighted.shards["take-max"].rarity = "common"
	weighted.shards["take-max"].focus = "heap"
	var matching := 0
	for i in 1200:
		var state := {"seed": "focus-weight-%d" % i, "paradigm": "greedy", "focus": "sprint"}
		if ProgramDraft.pack(state, 0, weighted)[0] == "sweep":
			matching += 1
	assert_int(matching).is_between(830, 965)
