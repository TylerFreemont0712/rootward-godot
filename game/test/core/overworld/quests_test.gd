extends GdUnitTestSuite
## Lanternroot's quests (ADR-0061): a step is done when its condition holds over the town's flags, a quest opens when
## the quests it comes after are done (a loop of afters never opens), the tracker shows the first open quest's next
## step (with "3 / 6" for a counting step), the log lists every quest, and a change of flags says which quests it
## finished.

const QUESTS := {
	"boots":
	{
		"order": 1,
		"title": "Your own two feet",
		"steps":
		[
			{"text": "Take a step.", "hint": "B opens your boots.", "done": {"flag": "first-step"}},
			{"text": "Leave the house.", "done": {"flag": "left-home"}},
		],
	},
	"hello":
	{
		"order": 2,
		"after": ["boots"],
		"title": "Hello",
		"summary": "Meet the town.",
		"giver": "hotaru",
		"steps":
		[
			{"text": "Meet Marta.", "done": {"flag": "met-innkeeper"}},
			{"text": "Meet more of the town.", "done": {"count": "met-", "at_least": 3}},
		],
	},
	"memory":
	{
		"order": 3,
		"after": ["hello"],
		"title": "Remember me",
		"steps": [{"text": "Write your save.", "done": {"flag": "memory-written"}}],
	},
}


func test_holds_counts_flags_with_a_prefix() -> void:
	var condition := {"count": "met-", "at_least": 2}
	assert_bool(Quests.holds(condition, {"met-a": true})).is_false()
	assert_bool(Quests.holds(condition, {"met-a": true, "met-b": true})).is_true()
	# A flag set to false does not count, nor one that only contains the prefix.
	assert_bool(Quests.holds(condition, {"met-a": true, "met-b": false, "x-met-c": true})).is_false()
	assert_int(Quests.counted("met-", {"met-a": true, "met-b": true, "left-home": true})).is_equal(2)


func test_holds_joins_a_count_with_talks_conditions() -> void:
	var condition := {"count": "met-", "at_least": 1, "flag": "read-notices", "not": "gone"}
	assert_bool(Quests.holds(condition, {"met-a": true, "read-notices": true})).is_true()
	assert_bool(Quests.holds(condition, {"met-a": true})).is_false()
	assert_bool(Quests.holds(condition, {"met-a": true, "read-notices": true, "gone": true})).is_false()
	assert_bool(Quests.holds({}, {})).is_true()


func test_status_follows_the_quests_it_comes_after() -> void:
	assert_str(Quests.status(QUESTS, "boots", {})).is_equal(Quests.OPEN)
	assert_str(Quests.status(QUESTS, "hello", {})).is_equal(Quests.LOCKED)
	var walked := {"first-step": true, "left-home": true}
	assert_str(Quests.status(QUESTS, "boots", walked)).is_equal(Quests.DONE)
	assert_str(Quests.status(QUESTS, "hello", walked)).is_equal(Quests.OPEN)
	assert_str(Quests.status(QUESTS, "memory", walked)).is_equal(Quests.LOCKED)


func test_steps_count_evidence_even_when_completed_in_another_order() -> void:
	assert_int(Quests.steps_done(QUESTS.boots, {"left-home": true})).is_equal(1)
	assert_int(Quests.steps_done(QUESTS.boots, {"first-step": true})).is_equal(1)
	assert_int(Quests.steps_done(QUESTS.boots, {"first-step": true, "left-home": true})).is_equal(2)


func test_current_keeps_the_first_unfinished_content_index_separate_from_done_count() -> void:
	var now := Quests.current(QUESTS, {"left-home": true})
	assert_int(now.step).is_equal(0)
	assert_int(now.done).is_equal(1)
	assert_str(now.text).is_equal("Take a step.")
	assert_str(now.hint).is_equal("B opens your boots.")


func test_entries_show_each_steps_evidence_and_instructions_independently() -> void:
	var listed := Quests.entries(QUESTS, {"left-home": true})
	assert_bool(listed[0].steps[0].done).is_false()
	assert_bool(listed[0].steps[1].done).is_true()
	assert_str(listed[0].steps[0].hint).is_equal("B opens your boots.")
	assert_str(listed[0].steps[1].hint).is_equal("")
	assert_int(listed[0].done).is_equal(1)
	assert_int(listed[0].total).is_equal(2)
	assert_int(listed[0].next_step.step).is_equal(0)


func test_next_step_explains_the_selected_quest_independently_of_the_tracker() -> void:
	var next := Quests.next_step(QUESTS.boots, {"left-home": true})
	assert_int(next.step).is_equal(0)
	assert_str(next.hint).is_equal("B opens your boots.")
	assert_dict(Quests.next_step(QUESTS.boots, {"first-step": true, "left-home": true})).is_empty()


func test_completed_locked_quest_evidence_survives_until_its_prerequisites_finish() -> void:
	var flags := {"memory-written": true}
	assert_int(Quests.steps_done(QUESTS.memory, flags)).is_equal(1)
	assert_str(Quests.status(QUESTS, "memory", flags)).is_equal(Quests.LOCKED)
	assert_bool(Quests.entries(QUESTS, flags)[2].steps[0].done).is_true()
	var after := flags.merged({
		"first-step": true, "left-home": true, "met-innkeeper": true, "met-a": true, "met-b": true,
	})
	assert_str(Quests.status(QUESTS, "memory", after)).is_equal(Quests.DONE)
	assert_array(Quests.finished(QUESTS, flags, after)).contains_exactly(["boots", "hello", "memory"])


func test_a_loop_of_afters_stays_locked() -> void:
	var looped := {
		"a": {"after": ["b"], "steps": [{"text": "A", "done": {}}]},
		"b": {"after": ["a"], "steps": [{"text": "B", "done": {}}]},
		"c": {"after": ["c"], "steps": [{"text": "C", "done": {}}]},
	}
	assert_str(Quests.status(looped, "a", {})).is_equal(Quests.LOCKED)
	assert_str(Quests.status(looped, "b", {})).is_equal(Quests.LOCKED)
	assert_str(Quests.status(looped, "c", {})).is_equal(Quests.LOCKED)
	assert_dict(Quests.current(looped, {})).is_empty()


func test_an_after_that_is_no_quest_stays_locked() -> void:
	var lost := {"a": {"after": ["nowhere"], "steps": [{"text": "A", "done": {}}]}}
	assert_str(Quests.status(lost, "a", {})).is_equal(Quests.LOCKED)


func test_current_is_the_next_step_of_the_first_open_quest() -> void:
	var now := Quests.current(QUESTS, {})
	assert_str(now.id).is_equal("boots")
	assert_str(now.title).is_equal("Your own two feet")
	assert_int(now.step).is_equal(0)
	assert_str(now.text).is_equal("Take a step.")
	assert_str(now.hint).is_equal("B opens your boots.")
	assert_str(now.progress).is_equal("")
	assert_int(now.done).is_equal(0)
	assert_int(now.total).is_equal(2)
	var later := Quests.current(QUESTS, {"first-step": true})
	assert_int(later.step).is_equal(1)
	assert_str(later.text).is_equal("Leave the house.")


func test_current_shows_progress_for_a_counting_step() -> void:
	var flags := {"first-step": true, "left-home": true, "met-innkeeper": true, "met-guard": true}
	var now := Quests.current(QUESTS, flags)
	assert_str(now.id).is_equal("hello")
	assert_str(now.text).is_equal("Meet more of the town.")
	assert_str(now.progress).is_equal("2 / 3")
	# Past the target, the progress stops at it.
	flags.merge({"met-a": true, "met-b": true, "met-c": true})
	assert_str(Quests.current(QUESTS, flags).id).is_equal("memory")


func test_current_is_empty_when_everything_open_is_done() -> void:
	var flags := {"first-step": true, "left-home": true, "met-innkeeper": true, "met-a": true, "met-b": true}
	flags["memory-written"] = true
	assert_dict(Quests.current(QUESTS, flags)).is_empty()


func test_quests_are_ordered_by_order_then_id() -> void:
	var quests := {"b": {"order": 1}, "a": {"order": 1}, "z": {"order": 0}}
	assert_array(Quests.ordered(quests)).contains_exactly(["z", "a", "b"])


func test_entries_list_every_quest_with_its_steps() -> void:
	var listed := Quests.entries(QUESTS, {"first-step": true})
	assert_array(listed.map(func(e: Dictionary) -> String: return e.id)).contains_exactly(["boots", "hello", "memory"])
	assert_str(listed[0].status).is_equal(Quests.OPEN)
	assert_bool(listed[0].steps[0].done).is_true()
	assert_bool(listed[0].steps[1].done).is_false()
	assert_str(listed[1].status).is_equal(Quests.LOCKED)
	assert_str(listed[1].summary).is_equal("Meet the town.")
	assert_str(listed[1].giver).is_equal("hotaru")
	assert_str(listed[2].summary).is_equal("")


func test_finished_names_the_quests_a_change_completed() -> void:
	var before := {"first-step": true}
	var after := {"first-step": true, "left-home": true}
	assert_array(Quests.finished(QUESTS, before, after)).contains_exactly(["boots"])
	assert_array(Quests.finished(QUESTS, after, after)).is_empty()
	var everything := after.merged({"met-innkeeper": true, "met-a": true, "met-b": true, "memory-written": true})
	assert_array(Quests.finished(QUESTS, after, everything)).contains_exactly(["hello", "memory"])


func test_problems_find_an_after_that_is_no_quest_and_a_quest_without_steps() -> void:
	assert_array(Quests.problems(QUESTS)).is_empty()
	var broken := {"a": {"after": ["ghost"], "steps": [{"text": "A", "done": {}}]}, "b": {"steps": []}}
	var found := Quests.problems(broken)
	assert_int(found.size()).is_equal(2)
	assert_bool(found.any(func(p: String) -> bool: return p.contains("ghost"))).is_true()
	assert_bool(found.any(func(p: String) -> bool: return p.contains("b has no steps"))).is_true()


func test_the_town_quests_have_no_problems_and_open_in_turn() -> void:
	var quests: Dictionary = OverworldContent.load_world().catalog.quests
	assert_array(Quests.problems(quests)).is_empty()
	# Chapter 1 (with v0.4's menu before the save), then chapter 2's branches after the lamps.
	assert_array(Quests.ordered(quests).slice(0, 5)).contains_exactly(["boots", "hello", "menu", "memory", "lamps"])
	# The boots' five steps are all done, including the extra arrow rule and the cabbage gate.
	var flags := {
		"first-step": true, "boots-expanded": true, "all-ways": true, "cabbage-gate-open": true, "left-home": true
	}
	flags.merge({"met-innkeeper": true, "met-guildmaster": true, "read-notices": true})
	for who: String in ["a", "b", "c", "d"]:
		flags["met-" + who] = true
	assert_str(Quests.current(quests, flags).id).is_equal("menu")
	flags.merge({"menu-asked": true, "menu-key-written": true, "menu-built": true, "menu-opened": true})
	assert_str(Quests.current(quests, flags).id).is_equal("memory")
	flags.merge({"memory-asked": true, "memory-written": true, "saved-once": true})
	assert_str(Quests.current(quests, flags).id).is_equal("lamps")
	flags.merge({"lamps-asked": true, "lamps-written": true, "lamps-lit": true})
	# Two quests open at once after the lamps; the first by order is followed unless another is tracked.
	assert_str(Quests.current(quests, flags).id).is_equal("options")
	assert_str(Quests.current(quests, flags, "bag").id).is_equal("bag")
	assert_str(Quests.status(quests, "credits", flags)).is_equal(Quests.LOCKED)


func test_a_counting_step_over_the_bag_shows_its_count() -> void:
	var quests := {"soup": {"order": 1, "title": "Soup", "steps": [{"text": "Three cabbages", "done": {"has": "cabbage", "at_least": 3}}]}}
	var flags := {"bag:cabbage": 2}
	var now := Quests.current(quests, flags)
	assert_str(String(now.progress)).is_equal("2 / 3")
	flags["bag:cabbage"] = 3
	assert_dict(Quests.current(quests, flags)).is_empty()


func test_boots_learned_before_the_first_walk_do_not_hide_the_unfinished_walk() -> void:
	var quests: Dictionary = OverworldContent.load_world().catalog.quests
	var flags := {"boots-expanded": true, "all-ways": true, "left-home": true, "cabbage-gate-open": true}
	var now := Quests.current(quests, flags)
	assert_str(now.id).is_equal("boots")
	assert_int(now.step).is_equal(0)
	assert_int(now.done).is_equal(4)
	var listed := Quests.entries(quests, flags)[0]
	assert_bool(listed.steps[0].done).is_false()
	for i in range(1, 5):
		assert_bool(listed.steps[i].done).is_true()
	flags["first-step"] = true
	assert_str(Quests.status(quests, "boots", flags)).is_equal(Quests.DONE)
