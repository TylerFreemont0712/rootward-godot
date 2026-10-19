extends GdUnitTestSuite
## Lanternroot Studio's flag browser (ADR-0066, phase S9): a condition read in English, the flags a condition reads, the
## index of where each flag is set and read (quest steps, talk conditions, unlocks, and what talk, things and lessons
## set), the one-line where, and the orphans. Small hand-made data, then the real content.

const QUESTS := {
	"hello":
	{
		"order": 2,
		"steps":
		[
			{"text": "Meet Marta.", "done": {"flag": "met-innkeeper"}},
			{"text": "Meet more of the town.", "done": {"count": "met-", "at_least": 2}},
			{"text": "Read the board.", "done": {"all": [{"flag": "read-notices"}, {"not": "met-innkeeper"}]}},
		],
	},
}

const TALK := {
	"innkeeper":
	{
		"id": "innkeeper",
		"start": [{"if": {"flag": "met-innkeeper"}, "goto": "again"}, {"goto": "hello"}],
		"nodes":
		{
			"hello":
			{
				"lines": [{"text": "Hi."}],
				"set": ["met-innkeeper"],
				"choices": [{"text": "Soup?", "goto": "soup"}, {"text": "Bye.", "goto": "bye", "if": {"not": "met-pip"}}],
			},
			"again": {"lines": [{"text": "Back?"}]},
			"soup": {"lines": [{"text": "Soup."}], "set": ["ate-soup"]},
			"bye": {"lines": [{"text": "Bye."}]},
		},
	},
	"pip":
	{
		"id": "pip",
		"start": [{"goto": "hello"}],
		"nodes":
		{
			"hello":
			{
				"lines": [{"text": "Hey."}],
				"set": ["met-pip", "read-notices"],
				"choices": [{"text": "Hi.", "goto": "bye", "if": {"flag": "met-innkeeper"}}],
			},
			"bye": {"lines": [{"text": "Bye."}]},
		},
	},
}

const MAPS := {
	"lanternroot":
	{
		"objects":
		[
			{"kind": "prop", "id": "cabbage-gate", "program": {"hook": "on_use", "raises": ["gate-open"]}},
			{
				"kind": "prop",
				"id": "talking-barrel",
				"program": {"hook": "on_use", "raises": [], "unlocked_by": {"flag": "met-innkeeper"}},
			},
			{"kind": "prop", "art": "rug"},
		],
	},
}


func test_condition_text_reads_a_flag_and_a_not() -> void:
	assert_str(StudioQuests.condition_text({"flag": "met-innkeeper"})).is_equal("met-innkeeper")
	assert_str(StudioQuests.condition_text({"not": "met-innkeeper"})).is_equal("not met-innkeeper")


func test_condition_text_reads_the_combined_form() -> void:
	assert_str(StudioQuests.condition_text({"flag": "met-a", "not": "met-b"})).is_equal("met-a and not met-b")


func test_condition_text_reads_all_of_and_a_count() -> void:
	var all := {"all": [{"flag": "a"}, {"flag": "b"}, {"not": "c"}]}
	assert_str(StudioQuests.condition_text(all)).is_equal("all of: a, b, not c")
	assert_str(StudioQuests.condition_text({"count": "met-", "at_least": 6})).is_equal("6 or more of met-…")


func test_condition_text_is_empty_for_always_and_for_what_is_not_a_condition() -> void:
	assert_str(StudioQuests.condition_text({})).is_equal("")
	assert_str(StudioQuests.condition_text({"all": []})).is_equal("")
	assert_str(StudioQuests.condition_text(null)).is_equal("")
	assert_str(StudioQuests.condition_text("met-innkeeper")).is_equal("")


func test_flags_read_lists_each_flag_once_in_the_order_named() -> void:
	var condition := {"all": [{"flag": "b"}, {"not": "a"}, {"flag": "b"}, {"count": "met-", "at_least": 2}]}
	assert_array(StudioQuests.flags_read(condition)).is_equal(["b", "a", "met-*"])
	assert_array(StudioQuests.flags_read({"flag": "x", "not": "y", "all": [{"not": "z"}]})).is_equal(["x", "y", "z"])


func test_flags_read_of_a_count_is_its_prefix_with_a_star_and_nothing_reads_nothing() -> void:
	assert_array(StudioQuests.flags_read({"count": "met-", "at_least": 1})).is_equal(["met-*"])
	assert_array(StudioQuests.flags_read({"count": "met-*", "at_least": 1})).is_equal(["met-*"])
	assert_array(StudioQuests.flags_read({})).is_empty()
	assert_array(StudioQuests.flags_read(null)).is_empty()


func test_flag_index_lists_a_talk_node_as_the_setter_of_its_flags() -> void:
	var index := StudioQuests.flag_index({}, TALK, {})
	var entry: Dictionary = index["met-innkeeper"]
	assert_array(entry.set_by).is_equal([{"kind": "talk", "id": "innkeeper", "node": "hello"}])
	assert_array(entry.read_by).is_not_empty()
	assert_array((index["ate-soup"] as Dictionary).set_by).is_equal([{"kind": "talk", "id": "innkeeper", "node": "soup"}])


func test_flag_index_lists_a_thing_and_a_lesson_as_setters() -> void:
	var lessons: Array[Dictionary] = [{"flag": "memory-written", "lesson": "memory"}]
	var index := StudioQuests.flag_index({}, {}, MAPS, lessons)
	assert_array((index["gate-open"] as Dictionary).set_by).is_equal([{"kind": "thing", "id": "cabbage-gate", "map": "lanternroot"}])
	assert_array((index["memory-written"] as Dictionary).set_by).is_equal([{"kind": "lesson", "id": "memory"}])


func test_flag_index_lists_a_quest_step_by_its_index_counting_from_zero() -> void:
	var index := StudioQuests.flag_index(QUESTS, {}, {})
	var entry: Dictionary = index["met-innkeeper"]
	assert_array(entry.read_by).is_equal([{"kind": "quest", "id": "hello", "step": 0}, {"kind": "quest", "id": "hello", "step": 2}])
	assert_array(((index["read-notices"] as Dictionary).read_by)).is_equal([{"kind": "quest", "id": "hello", "step": 2}])


func test_flag_index_lists_talk_start_rules_and_choices_as_readers() -> void:
	var index := StudioQuests.flag_index({}, TALK, {})
	var entry: Dictionary = index["met-innkeeper"]
	assert_array(entry.read_by).is_equal(
		[
			{"kind": "talk", "id": "innkeeper", "node": "", "where": "start 0"},
			{"kind": "talk", "id": "pip", "node": "hello", "where": "choice 0"},
		]
	)
	assert_array((index["met-pip"] as Dictionary).read_by).is_equal(
		[{"kind": "talk", "id": "innkeeper", "node": "hello", "where": "choice 1"}]
	)


func test_flag_index_lists_an_unlock_as_a_reader_of_the_flags_it_needs() -> void:
	var index := StudioQuests.flag_index({}, {}, MAPS)
	assert_array((index["met-innkeeper"] as Dictionary).read_by).is_equal(
		[{"kind": "unlock", "id": "talking-barrel", "map": "lanternroot"}]
	)


func test_flag_index_lists_a_flag_once_however_many_times_it_is_set_or_read() -> void:
	var talk := {"t": {"nodes": {"n": {"lines": [{"text": "x"}], "set": ["x", "x"]}}}}
	var quests := {"q": {"steps": [{"text": "x", "done": {"all": [{"flag": "x"}, {"flag": "x"}]}}]}}
	var index := StudioQuests.flag_index(quests, talk, {})
	assert_array((index["x"] as Dictionary).set_by).has_size(1)
	assert_array((index["x"] as Dictionary).read_by).has_size(1)


func test_a_count_lists_every_setter_of_its_prefix_in_content_order() -> void:
	var index := StudioQuests.flag_index(QUESTS, TALK, MAPS)
	assert_array((index["met-*"] as Dictionary).set_by).is_equal(
		[{"kind": "talk", "id": "innkeeper", "node": "hello"}, {"kind": "talk", "id": "pip", "node": "hello"}]
	)


func test_no_prefix_entry_exists_when_no_count_reads_one() -> void:
	var index := StudioQuests.flag_index({}, TALK, {})
	assert_bool(index.has("met-*")).is_false()


func test_where_text_reads_each_kind_of_entry() -> void:
	assert_str(StudioQuests.where_text({"kind": "talk", "id": "pip", "node": "hello"})).is_equal("talk pip, node hello")
	assert_str(StudioQuests.where_text({"kind": "talk", "id": "innkeeper", "node": "", "where": "start 0"})).is_equal(
		"talk innkeeper, start 0"
	)
	assert_str(StudioQuests.where_text({"kind": "talk", "id": "pip", "node": "hello", "where": "choice 1"})).is_equal(
		"talk pip, node hello, choice 1"
	)
	assert_str(StudioQuests.where_text({"kind": "thing", "id": "cabbage-gate", "map": "lanternroot"})).is_equal(
		"thing cabbage-gate on lanternroot"
	)
	assert_str(StudioQuests.where_text({"kind": "lesson", "id": "memory"})).is_equal("lesson memory")
	assert_str(StudioQuests.where_text({"kind": "quest", "id": "hello", "step": 2})).is_equal("quest hello, step 3")
	assert_str(StudioQuests.where_text({"kind": "unlock", "id": "talking-barrel", "map": "lanternroot"})).is_equal(
		"unlock of talking-barrel on lanternroot"
	)


func test_sorted_flags_sorts_the_keys_of_the_index() -> void:
	var index := {"b": {}, "met-*": {}, "a": {}}
	assert_array(StudioQuests.sorted_flags(index)).is_equal(["a", "b", "met-*"])


func test_orphans_split_flags_read_and_never_set_from_flags_set_and_never_read() -> void:
	var quests := {"q": {"steps": [{"text": "x", "done": {"flag": "need-me"}}]}}
	var talk := {"t": {"nodes": {"n": {"lines": [{"text": "x"}], "set": ["only-set"]}}}}
	var orphans := StudioQuests.orphans(StudioQuests.flag_index(quests, talk, {}))
	assert_array(orphans.never_set).is_equal(["need-me"])
	assert_array(orphans.never_read).is_equal(["only-set"])


func test_orphans_count_a_flag_a_prefix_covers_as_read_and_a_prefix_nothing_sets_as_never_set() -> void:
	var talk := {"t": {"nodes": {"n": {"lines": [{"text": "x"}], "set": ["met-a"]}}}}
	var covered := {"q": {"steps": [{"text": "x", "done": {"count": "met-", "at_least": 1}}]}}
	var covered_orphans := StudioQuests.orphans(StudioQuests.flag_index(covered, talk, {}))
	assert_array(covered_orphans.never_set).is_empty()
	assert_array(covered_orphans.never_read).is_empty()
	var unset := {"q": {"steps": [{"text": "x", "done": {"count": "zz-", "at_least": 1}}]}}
	var unset_orphans := StudioQuests.orphans(StudioQuests.flag_index(unset, talk, {}))
	assert_array(unset_orphans.never_set).is_equal(["zz-*"])
	assert_array(unset_orphans.never_read).is_equal(["met-a"])


func test_real_content_every_flag_a_quest_reads_is_in_the_index() -> void:
	var loaded := OverworldContent.load_world()
	assert_bool(loaded.ok).is_true()
	var catalog: Dictionary = loaded.catalog
	var index := StudioQuests.flag_index(catalog.quests, catalog.talk, catalog.maps)
	var missing: Array[String] = []
	for quest_id: String in catalog.quests:
		var steps: Array = (catalog.quests[quest_id] as Dictionary).get("steps", [])
		for step: Dictionary in steps:
			for flag: String in StudioQuests.flags_read(step.get("done", {})):
				if not index.has(flag):
					missing.append(flag)
	assert_array(missing).is_empty()
	assert_bool(index.has("met-*")).is_true()


func test_real_content_met_innkeeper_is_set_by_talk_and_read_by_hello_step_one() -> void:
	var catalog: Dictionary = OverworldContent.load_world().catalog
	var index := StudioQuests.flag_index(catalog.quests, catalog.talk, catalog.maps)
	var entry: Dictionary = index["met-innkeeper"]
	assert_array(entry.set_by).contains([{"kind": "talk", "id": "innkeeper", "node": "hello"}])
	assert_array(entry.read_by).contains([{"kind": "quest", "id": "hello", "step": 0}])


func test_real_content_met_star_lists_exactly_the_talk_nodes_that_set_a_met_flag() -> void:
	var catalog: Dictionary = OverworldContent.load_world().catalog
	var index := StudioQuests.flag_index(catalog.quests, catalog.talk, catalog.maps)
	var expected: Array[Dictionary] = []
	for talk_id: String in catalog.talk:
		var one: Dictionary = catalog.talk[talk_id]
		for node_id: String in one.get("nodes", {}):
			for flag: String in Talk.sets(one, node_id):
				if flag.begins_with("met-"):
					expected.append({"kind": "talk", "id": talk_id, "node": node_id})
					break
	assert_bool(expected.is_empty()).is_false()
	assert_array((index["met-*"] as Dictionary).set_by).is_equal(expected)
