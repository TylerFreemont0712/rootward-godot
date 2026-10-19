extends GdUnitTestSuite
## The debug panel's pokes (Lanternroot, ADR-0061): a step is completed with the steps before it, reopened with the steps
## after it left undone, a quest is jumped to with the quests before it done, flags are set and cleared, and the
## changes a poke made are listed for the log. Each poke returns new flags and changes nothing it was given.

## Every condition kind: a flag, a negated flag, an all of two flags, a count of "met-" flags, and a mixed condition.
const QUESTS := {
	"walk":
	{
		"order": 1,
		"title": "Walk",
		"steps":
		[
			{"text": "Step", "done": {"flag": "stepped"}},
			{"text": "Gate", "done": {"not": "hall-closed"}},
			{"text": "Friends", "done": {"all": [{"flag": "a"}, {"flag": "b"}]}},
			{"text": "Crowd", "done": {"count": "met-", "at_least": 2}},
		],
	},
	"town":
	{
		"order": 2,
		"after": ["walk"],
		"title": "Town",
		"steps":
		[
			{"text": "Look", "done": {"flag": "looked"}},
			{"text": "Mixed", "done": {"flag": "x", "not": "y"}},
		],
	},
}


func test_complete_step_sets_the_flag_of_the_step() -> void:
	assert_dict(DebugPokes.complete_step(QUESTS, "walk", 0, {})).is_equal({"stepped": true})


func test_complete_step_does_the_steps_before_it_too() -> void:
	var done := DebugPokes.complete_step(QUESTS, "walk", 2, {})
	assert_int(Quests.steps_done(QUESTS.walk, done)).is_equal(3)
	assert_dict(done).is_equal({"stepped": true, "a": true, "b": true})


func test_complete_step_erases_a_flag_a_not_step_forbids() -> void:
	var done := DebugPokes.complete_step(QUESTS, "walk", 1, {"hall-closed": true, "stepped": true})
	assert_dict(done).is_equal({"stepped": true})


func test_complete_step_sets_only_the_missing_parts_of_an_all() -> void:
	var done := DebugPokes.complete_step(QUESTS, "walk", 2, {"a": true, "stepped": true})
	assert_dict(done).is_equal({"a": true, "stepped": true, "b": true})


func test_complete_step_adds_debug_flags_until_a_count_is_met() -> void:
	var done := DebugPokes.complete_step(QUESTS, "walk", 3, {"met-ann": true})
	assert_int(Quests.counted("met-", done)).is_equal(2)
	assert_bool(bool(done["met-ann"])).is_true()
	assert_bool(bool(done["met-debug-1"])).is_true()
	# Stepped, the two parts of the all, the flag already there and the one debug flag added.
	assert_int(done.size()).is_equal(5)


func test_complete_step_does_not_touch_the_flags_it_finds_there() -> void:
	# met-debug-1 is there already (set to false), so the flag it adds is met-debug-2.
	var done := DebugPokes.complete_step(QUESTS, "walk", 3, {"met-debug-1": false, "met-ann": true})
	assert_bool(bool(done["met-debug-1"])).is_false()
	assert_bool(bool(done["met-debug-2"])).is_true()
	assert_int(Quests.counted("met-", done)).is_equal(2)


func test_complete_step_leaves_a_condition_that_holds_alone() -> void:
	var flags := {"met-ann": true, "met-bo": true, "stepped": true, "a": true, "b": true}
	assert_dict(DebugPokes.complete_step(QUESTS, "walk", 3, flags)).is_equal(flags)


func test_a_step_the_quest_does_not_have_changes_nothing() -> void:
	assert_dict(DebugPokes.complete_step(QUESTS, "nowhere", 0, {"x": true})).is_equal({"x": true})
	assert_dict(DebugPokes.complete_step(QUESTS, "walk", 4, {})).is_equal({})
	assert_dict(DebugPokes.reopen_step(QUESTS, "walk", -1, {"stepped": true})).is_equal({"stepped": true})


func test_complete_step_handles_a_mixed_condition() -> void:
	# {flag: x, not: y}: x is set and y is erased. The step before it (looked) is done too.
	var done := DebugPokes.complete_step(QUESTS, "town", 1, {"y": true})
	assert_dict(done).is_equal({"looked": true, "x": true})


func test_reopen_step_erases_a_flag() -> void:
	assert_dict(DebugPokes.reopen_step(QUESTS, "walk", 0, {"stepped": true, "x": true})).is_equal({"x": true})


func test_reopen_step_sets_the_flag_a_not_step_forbids() -> void:
	var reopened := DebugPokes.reopen_step(QUESTS, "walk", 1, {})
	assert_dict(reopened).is_equal({"hall-closed": true})
	assert_dict(DebugPokes.reopen_step(QUESTS, "walk", 1, {"hall-closed": true})).is_equal({"hall-closed": true})


func test_reopen_step_fails_the_first_part_of_an_all_that_holds() -> void:
	var reopened := DebugPokes.reopen_step(QUESTS, "walk", 2, {"a": true, "b": true, "stepped": true})
	assert_dict(reopened).is_equal({"b": true, "stepped": true})


func test_reopen_step_takes_away_the_debug_flags_of_a_count_first() -> void:
	var flags := {"met-ann": true, "met-bo": true, "met-debug-1": true, "met-debug-2": true}
	var reopened := DebugPokes.reopen_step(QUESTS, "walk", 3, flags)
	# Both debug flags go, then met-bo (last name first), which is enough to fall below 2.
	assert_dict(reopened).is_equal({"met-ann": true})


func test_reopen_step_leaves_a_condition_that_fails_alone() -> void:
	assert_dict(DebugPokes.reopen_step(QUESTS, "walk", 0, {})).is_equal({})


func test_reopen_step_handles_a_mixed_condition() -> void:
	assert_dict(DebugPokes.reopen_step(QUESTS, "town", 1, {"x": true})).is_equal({})


func test_reopen_step_undoes_the_later_steps_too() -> void:
	var done := DebugPokes.complete_step(QUESTS, "walk", 3, {})
	assert_int(Quests.steps_done(QUESTS.walk, done)).is_equal(4)
	var reopened := DebugPokes.reopen_step(QUESTS, "walk", 0, done)
	assert_int(Quests.steps_done(QUESTS.walk, reopened)).is_equal(0)
	assert_str(Quests.status(QUESTS, "walk", reopened)).is_equal(Quests.OPEN)


func test_reopen_step_keeps_the_steps_before_it_done() -> void:
	var done := DebugPokes.complete_step(QUESTS, "walk", 3, {})
	var reopened := DebugPokes.reopen_step(QUESTS, "walk", 2, done)
	assert_int(Quests.steps_done(QUESTS.walk, reopened)).is_equal(2)


func test_jump_to_completes_the_quests_before_and_not_the_one_named() -> void:
	var flags := DebugPokes.jump_to(QUESTS, "town", {})
	assert_str(Quests.status(QUESTS, "walk", flags)).is_equal(Quests.DONE)
	var now := Quests.current(QUESTS, flags)
	assert_str(now.id).is_equal("town")
	assert_int(now.step).is_equal(0)


func test_jump_to_the_first_quest_only_reopens_its_first_step() -> void:
	var flags := DebugPokes.jump_to(QUESTS, "walk", {"stepped": true, "a": true})
	assert_dict(flags).is_equal({"a": true})
	var now := Quests.current(QUESTS, flags)
	assert_str(now.id).is_equal("walk")
	assert_int(now.step).is_equal(0)


func test_jump_to_leaves_the_quests_after_it_alone() -> void:
	var flags := {"looked": true, "x": true}
	assert_dict(DebugPokes.jump_to(QUESTS, "walk", flags)).is_equal(flags)


func test_jump_to_an_unknown_quest_changes_nothing() -> void:
	assert_dict(DebugPokes.jump_to(QUESTS, "nowhere", {"a": true})).is_equal({"a": true})


func test_set_flag_and_clear_flag_return_new_flags() -> void:
	var base := {"x": true}
	assert_dict(DebugPokes.set_flag(base, "y")).is_equal({"x": true, "y": true})
	assert_dict(DebugPokes.clear_flag(base, "x")).is_equal({})
	assert_dict(base).is_equal({"x": true})


func test_flag_changes_lists_what_was_set_and_cleared_sorted() -> void:
	var changes := DebugPokes.flag_changes(
		{"b": true, "c": true, "d": false}, {"a": true, "c": true, "d": true, "e": false}
	)
	# b was set and is gone; a and d are now set; c and e (false) did not change what counts as set.
	assert_array(changes["set"]).is_equal(["a", "d"])
	assert_array(changes["cleared"]).is_equal(["b"])


func test_flag_changes_of_the_same_flags_is_empty() -> void:
	var changes := DebugPokes.flag_changes({"a": true}, {"a": true})
	assert_array(changes["set"]).is_empty()
	assert_array(changes["cleared"]).is_empty()


func test_step_changes_lists_the_steps_made_done_in_quest_order() -> void:
	var changes := DebugPokes.step_changes(QUESTS, {}, DebugPokes.complete_step(QUESTS, "walk", 2, {}))
	assert_int(changes.size()).is_equal(3)
	assert_dict(changes[0]).is_equal({"quest": "walk", "title": "Walk", "step": 0, "text": "Step", "done": true})
	assert_int(changes[2]["step"]).is_equal(2)
	assert_bool(bool(changes[2]["done"])).is_true()


func test_step_changes_lists_the_steps_made_undone() -> void:
	var done := DebugPokes.complete_step(QUESTS, "walk", 1, {})
	var undone := DebugPokes.reopen_step(QUESTS, "walk", 0, done)
	var changes := DebugPokes.step_changes(QUESTS, done, undone)
	assert_int(changes.size()).is_equal(2)
	assert_bool(bool(changes[0]["done"])).is_false()
	assert_bool(bool(changes[1]["done"])).is_false()
	assert_array(DebugPokes.step_changes(QUESTS, done, done)).is_empty()


func test_the_pokes_do_not_change_what_they_are_given() -> void:
	var flags := {"met-ann": true, "hall-closed": true, "x": true}
	var before := flags.duplicate(true)
	DebugPokes.complete_step(QUESTS, "walk", 3, flags)
	DebugPokes.reopen_step(QUESTS, "walk", 1, flags)
	DebugPokes.jump_to(QUESTS, "town", flags)
	DebugPokes.set_flag(flags, "z")
	DebugPokes.clear_flag(flags, "x")
	DebugPokes.flag_changes(flags, before)
	DebugPokes.step_changes(QUESTS, flags, before)
	assert_dict(flags).is_equal(before)


func test_jumping_to_the_real_lamps_quest_opens_it_at_its_first_step() -> void:
	var quests: Dictionary = OverworldContent.load_world().catalog.quests
	var flags := DebugPokes.jump_to(quests, "lamps", {})
	var now := Quests.current(quests, flags)
	assert_str(now.id).is_equal("lamps")
	assert_int(now.step).is_equal(0)
	for id: String in Quests.ordered(quests):
		if id == "lamps":
			break
		assert_str(Quests.status(quests, id, flags)).is_equal(Quests.DONE)


func test_completing_a_real_counting_step_gives_it_enough_flags() -> void:
	var quests: Dictionary = OverworldContent.load_world().catalog.quests
	var flags := DebugPokes.complete_step(quests, "hello", 2, {})
	assert_int(Quests.counted("met-", flags)).is_equal(6)
	assert_int(Quests.steps_done(quests.hello, flags)).is_equal(3)
