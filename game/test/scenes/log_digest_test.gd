extends GdUnitTestSuite
## The log digest: a volley of thirty bolts reads as a few lines, and nothing else changes.


func _bolt(kind: String, index: int, foe := "f1", extra := {}) -> Dictionary:
	var entry := {"kind": kind, "foe": foe, "bolt": index, "target": "front", "element": "none"}
	entry.merge(extra, true)
	return entry


func test_a_foe_that_absorbs_every_bolt_is_one_line() -> void:
	var entries: Array = [{"kind": "cast", "text": "main.py: 32 bolts, 81 ops, 5 mana."}]
	for index in 31:
		entries.append(
			_bolt("absorb", index, "f1", {"word": "cache hit", "text": "Cache hit: it already knows %d." % index})
		)
	entries.append(_bolt("hit", 31, "f1", {"amount": 16, "text": "The Cache Lich takes 16."}))
	var lines := LogDigest.story(entries, {"f1": "The Cache Lich"}).split("\n")
	assert_array(lines).contains_exactly(
		[
			"main.py: 32 bolts, 81 ops, 5 mana.",
			"The Cache Lich absorbs 31 bolts (cache hit).",
			"The Cache Lich takes 16."
		]
	)


func test_hits_on_one_foe_sum_and_keep_the_numbers_the_tally_reads() -> void:
	var entries: Array = []
	for index in 4:
		var extra := {
			"amount": 10, "overkill": 2 if index == 3 else 0, "affinity": "weak" if index < 2 else "", "text": "x"
		}
		entries.append(_bolt("hit", index, "f1", extra))
	entries.append(_bolt("hit", 4, "f2", {"amount": 7, "text": "Imp takes 7."}))
	var folded := LogDigest.digest(entries, {"f1": "Wisp"})
	assert_int(folded.size()).is_equal(2)
	assert_str(folded[0].text).is_equal("Wisp takes 40 from 4 bolts.")
	assert_int(folded[0].amount).is_equal(40)
	assert_int(folded[0].overkill).is_equal(2)
	assert_int(folded[0].weak).is_equal(2)
	# One bolt is left exactly as the rules wrote it.
	assert_str(folded[1].text).is_equal("Imp takes 7.")


func test_interleaved_bolts_fold_by_kind_and_foe_in_order_of_first_appearance() -> void:
	var entries: Array = [
		_bolt("glance", 0),
		_bolt("hit", 1, "f1", {"amount": 5}),
		_bolt("glance", 2),
		_bolt("hit", 3, "f1", {"amount": 5})
	]
	var folded := LogDigest.digest(entries, {"f1": "Golem"})
	(
		assert_array(folded.map(func(entry: Dictionary) -> String: return entry.text))
		. contains_exactly(["2 bolts glance off Golem.", "Golem takes 10 from 2 bolts."])
	)


func test_a_foes_repeated_blows_are_one_line() -> void:
	var entries: Array = []
	for blow in 5:
		entries.append({"kind": "enemy", "foe": "f9", "amount": 3, "text": "Fork Bomb hits you for 3."})
	var folded := LogDigest.digest(entries, {"f9": "Fork Bomb"})
	assert_int(folded.size()).is_equal(1)
	assert_str(folded[0].text).is_equal("Fork Bomb hits you 5 times for 15.")


func test_a_foes_name_is_learned_from_its_own_lines_when_no_fight_is_at_hand() -> void:
	var entries: Array = [
		_bolt("absorb", 0, "f1", {"text": "swallowed"}),
		_bolt("absorb", 1, "f1", {"text": "swallowed"}),
		{"kind": "defeat", "foe": "f1", "text": "Segfault Specter breaks apart."},
	]
	assert_str(LogDigest.story(entries)).starts_with("Segfault Specter absorbs 2 bolts.")


func test_other_entries_pass_through_untouched_and_in_order() -> void:
	var entries: Array = [
		{"kind": "turn", "amount": 2, "text": "Turn 2."},
		{"kind": "tempo", "amount": 12, "text": "The imp moves first."},
		{"kind": "ward", "amount": 4, "text": "Your relics gather 4 block after the cast."},
	]
	assert_array(LogDigest.digest(entries)).is_equal(entries)


func test_the_battle_log_text_reads_the_digest() -> void:
	var entries: Array[Dictionary] = []
	for index in 12:
		var entry := _bolt("glance", index, "f1", {"text": "A 2-power bolt glances off Golem."})
		entry.turn_number = 1
		entries.append(entry)
	var text := BattleLog.text(entries)
	assert_int(text.count("glances off")).is_equal(0)
	assert_str(text).contains("12 bolts glance off")
