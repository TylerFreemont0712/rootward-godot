extends GdUnitTestSuite
## The debug panel's event log (Lanternroot, ADR-0061): a book keeps its newest LIMIT entries with their ids and times,
## the latest entries come newest first (optionally only some kinds), the clock reads "m:ss.t" from the start, and a
## value is cut to one short line for the panel.


func test_an_empty_book_has_no_entries_and_starts_at_one() -> void:
	assert_dict(DebugLog.empty()).is_equal({"entries": [], "next": 1})


func test_add_appends_an_entry_with_an_id_and_its_time() -> void:
	var book := DebugLog.add(DebugLog.empty(), "flag", "set first-step", {"flag": "first-step"}, 500)
	var entries: Array = book["entries"]
	assert_int(entries.size()).is_equal(1)
	assert_dict(entries[0]).is_equal(
		{"id": 1, "kind": "flag", "text": "set first-step", "data": {"flag": "first-step"}, "at": 500}
	)
	assert_int(book["next"]).is_equal(2)


func test_add_changes_neither_the_book_nor_the_data_it_was_given() -> void:
	var book := DebugLog.add(DebugLog.empty(), "talk", "hello", {}, 0)
	var before := book.duplicate(true)
	var data := {"who": "marta"}
	var added := DebugLog.add(book, "talk", "again", data, 10)
	data["who"] = "changed"
	assert_dict(book).is_equal(before)
	var entry: Dictionary = (added["entries"] as Array)[1]
	assert_str(entry["data"]["who"]).is_equal("marta")


func test_the_log_keeps_only_the_newest_entries() -> void:
	var book := DebugLog.empty()
	for n: int in range(DebugLog.LIMIT + 5):
		book = DebugLog.add(book, "poke", "poke %d" % n, {}, n)
	var entries: Array = book["entries"]
	assert_int(entries.size()).is_equal(DebugLog.LIMIT)
	assert_int(entries[0]["id"]).is_equal(6)
	assert_int(entries[entries.size() - 1]["id"]).is_equal(DebugLog.LIMIT + 5)
	assert_int(book["next"]).is_equal(DebugLog.LIMIT + 6)


func test_latest_gives_the_newest_entries_first() -> void:
	var book := DebugLog.empty()
	for text: String in ["a", "b", "c"]:
		book = DebugLog.add(book, "flag", text, {}, 0)
	var recent := DebugLog.latest(book, 2)
	assert_int(recent.size()).is_equal(2)
	assert_str(recent[0]["text"]).is_equal("c")
	assert_str(recent[1]["text"]).is_equal("b")
	assert_int(DebugLog.latest(book, 10).size()).is_equal(3)
	assert_array(DebugLog.latest(book, 0)).is_empty()
	assert_array(DebugLog.latest(DebugLog.empty(), 3)).is_empty()


func test_latest_keeps_only_the_kinds_asked_for() -> void:
	var book := DebugLog.empty()
	book = DebugLog.add(book, "quest", "q1", {}, 0)
	book = DebugLog.add(book, "flag", "f1", {}, 0)
	book = DebugLog.add(book, "quest", "q2", {}, 0)
	book = DebugLog.add(book, "talk", "t1", {}, 0)
	var kinds: Array[String] = ["quest"]
	var quests := DebugLog.latest(book, 5, kinds)
	assert_int(quests.size()).is_equal(2)
	assert_str(quests[0]["text"]).is_equal("q2")
	assert_str(quests[1]["text"]).is_equal("q1")
	var others: Array[String] = ["flag", "talk"]
	assert_int(DebugLog.latest(book, 5, others).size()).is_equal(2)


func test_latest_hands_out_copies_of_the_entries() -> void:
	var book := DebugLog.add(DebugLog.empty(), "thing", "a", {"n": 1}, 0)
	var recent := DebugLog.latest(book, 1)
	recent[0]["text"] = "changed"
	var entry: Dictionary = (book["entries"] as Array)[0]
	assert_str(entry["text"]).is_equal("a")


func test_the_clock_reads_minutes_seconds_and_tenths_from_the_start() -> void:
	assert_str(DebugLog.clock(75400, 0)).is_equal("1:15.4")
	assert_str(DebugLog.clock(10000, 2500)).is_equal("0:07.5")
	assert_str(DebugLog.clock(5099, 0)).is_equal("0:05.0")
	assert_str(DebugLog.clock(600000, 0)).is_equal("10:00.0")
	assert_str(DebugLog.clock(999, 0)).is_equal("0:00.9")
	assert_str(DebugLog.clock(100, 500)).is_equal("0:00.0")


func test_value_text_is_one_line_with_the_keys_in_their_own_order() -> void:
	assert_str(DebugLog.value_text({"b": 1, "a": "x"})).is_equal('{"b":1,"a":"x"}')
	assert_str(DebugLog.value_text(3)).is_equal("3")
	assert_str(DebugLog.value_text("hi")).is_equal('"hi"')


func test_value_text_cuts_a_long_value_with_an_ellipsis_inside_the_limit() -> void:
	var cut := DebugLog.value_text([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 10)
	assert_str(cut).is_equal("[1,2,3,4,…")
	assert_int(cut.length()).is_equal(10)
	# A value of exactly the limit stays whole.
	assert_str(DebugLog.value_text("abcd", 6)).is_equal('"abcd"')


func test_value_text_defaults_to_eighty_characters() -> void:
	var long := DebugLog.value_text("x".repeat(100))
	assert_int(long.length()).is_equal(80)
	assert_bool(long.ends_with("…")).is_true()


func test_the_panel_kinds_are_the_ones_the_log_names() -> void:
	assert_array(DebugLog.KINDS).contains_exactly(["talk", "flag", "quest", "thing", "warp", "poke", "content"])
