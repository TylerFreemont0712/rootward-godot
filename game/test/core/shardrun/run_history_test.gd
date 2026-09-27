extends GdUnitTestSuite
## Finished runs as commits (RunHistory): the record, the conventional message, the decoration, the diffstat.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _finished(status: String) -> Dictionary:
	var state := Shardrun.start(
		catalog, {"seed": "history", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	)
	state.paradigm = "greedy"
	state.status = status
	state.stats.damage = 1204
	state.stats.fights = 14
	state.integrity = 40
	state.visited = ["a", "b", "c"]
	return state


func test_a_won_run_ships_a_feature_and_is_tagged() -> void:
	var record := RunHistory.entry(_finished("won"), catalog, "2026-09-28T04:12:00", "vesper")
	assert_str(RunHistory.subject(record)).is_equal("feat(greedy): ship it, all 3 layers cleared")
	assert_str(RunHistory.oneline(record, true)).contains("(HEAD -> main, tag: shipped) feat(greedy)")
	assert_int(RunHistory.short_hash(record).length()).is_equal(7)


func test_a_lost_run_is_reverted_and_names_what_ended_it() -> void:
	var state := _finished("lost")
	state.battle = {"kind": "boss", "foes": [{"name": "Deadlock Golem", "hp": 40}, {"name": "Imp", "hp": 0}]}
	state.layer = 1
	var record := RunHistory.entry(state, catalog, "2026-09-28T04:12:00", "vesper")
	assert_str(RunHistory.subject(record)).is_equal("revert(greedy): kernel panic on layer 2 by Deadlock Golem")
	assert_str(String(record.fight)).is_equal("boss")


func test_an_abandoned_run_is_reset() -> void:
	var record := RunHistory.entry(_finished("abandoned"), catalog, "2026-09-28T04:12:00", "emberfox")
	assert_str(RunHistory.subject(record)).is_equal("chore(greedy): reset --hard on layer 1")
	assert_str(RunHistory.oneline(record)).not_contains("HEAD")


func test_damage_is_insertions_and_integrity_lost_is_deletions() -> void:
	var record := RunHistory.entry(_finished("won"), catalog, "2026-09-28T04:12:00", "vesper")
	assert_str(RunHistory.diffstat(record)).is_equal(" 3 rooms changed, 1204 insertions(+), 20 deletions(-)")


func test_git_show_prints_the_header_the_message_and_the_stat() -> void:
	var record := RunHistory.entry(_finished("won"), catalog, "2026-09-28T04:12:00", "vesper")
	var lines := RunHistory.show(record, true)
	assert_str(lines[0]).starts_with("commit %s" % record.hash)
	assert_str(lines[1]).is_equal("Author: Vesper <vesper@rootward>")
	assert_str(lines[2]).is_equal("Date:   2026-09-28 04:12:00")
	assert_str(lines[4]).is_equal("    " + RunHistory.subject(record))
	assert_str(lines[lines.size() - 1]).is_equal(RunHistory.diffstat(record))


func test_the_same_run_finished_at_another_time_has_another_hash() -> void:
	var state := _finished("won")
	var first := RunHistory.entry(state, catalog, "2026-09-28T04:12:00", "vesper")
	var again := RunHistory.entry(state, catalog, "2026-09-28T04:12:00", "vesper")
	var later := RunHistory.entry(state, catalog, "2026-09-29T09:00:00", "vesper")
	assert_str(String(first.hash)).is_equal(String(again.hash))
	assert_str(String(first.hash)).is_not_equal(String(later.hash))
