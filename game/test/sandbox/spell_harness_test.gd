extends GdUnitTestSuite
## The Godot spell harness against the old server's: the same spells of real shards, in both languages, must return
## the same bolts, traces, work and failures (fixture from tools/fixtures/spells.ts).

var fixture: Dictionary
var shards := {}


func before() -> void:
	fixture = Fixtures.load_json("spells")
	for shard: Dictionary in fixture.shards:
		shards[shard.id] = shard


func _spells() -> Array[Dictionary]:
	var spells: Array[Dictionary] = []
	for spell: Dictionary in fixture.spells:
		var list: Array[Dictionary] = []
		for id: String in spell.shards:
			list.append(shards[id])
		spells.append({"id": spell.id, "shards": list})
	return spells


func _pipeline_input(index: int) -> Dictionary:
	var raw: Dictionary = fixture.inputs[index]
	return {"bolts": raw.bolts, "battle": raw.battle, "limit": int(raw.limit), "trace_limit": int(raw.traceLimit)}


func test_every_spell_matches_the_old_server() -> void:
	var spells := _spells()
	for case: Dictionary in fixture.cases:
		var runs := SpellHarness.run(case.language, spells, _pipeline_input(int(case.input)))
		for spell_id: String in case.runs:
			var want: Dictionary = case.runs[spell_id]
			var got: Dictionary = runs[spell_id]
			var where := "%s input %d %s" % [case.language, int(case.input), spell_id]
			(
				assert_bool(got.ok)
				. override_failure_message("%s: ok %s, reason %s" % [where, got.ok, got.get("reason")])
				. is_equal(want.ok)
			)
			assert_array(got.trace).override_failure_message(where + ": trace").is_equal(want.trace)
			assert_str(got.console).override_failure_message(where + ": console").is_equal(want.console)
			if want.ok:
				assert_array(got.bolts).override_failure_message(where + ": bolts").is_equal(want.bolts)
				assert_int(got.work).override_failure_message(where + ": work").is_equal(int(want.work))
			else:
				assert_str(got.reason).override_failure_message(where + ": reason").is_equal(want.reason)
				assert_str(got.get("shard", "")).is_equal(want.get("shard", ""))
				if want.has("line"):
					assert_int(got.get("line", -1)).override_failure_message(where + ": line").is_equal(int(want.line))


func test_function_names_follow_each_language() -> void:
	var shard := {"function": "split_by_weakness"}
	assert_str(SpellHarness.function_name(shard, SandboxJob.PYTHON)).is_equal("split_by_weakness")
	assert_str(SpellHarness.function_name(shard, SandboxJob.JAVASCRIPT)).is_equal("splitByWeakness")


func test_an_endless_shard_times_out_alone() -> void:
	var loop := {
		"id": "test-loop",
		"function": "loop_forever",
		"code": {"python": "def loop_forever(bolts, battle):\n    while True:\n        pass\n"},
	}
	var fine: Dictionary = shards[(fixture.spells[0] as Dictionary).shards[0]]
	var spells: Array[Dictionary] = [{"id": "stuck", "shards": [loop]}, {"id": "fine", "shards": [fine]}]
	var limits := SandboxJob.new()
	limits.time_ms = 300
	var runs := SpellHarness.run(SandboxJob.PYTHON, spells, _pipeline_input(0), limits)
	assert_bool(runs.stuck.ok).is_false()
	assert_str(runs.stuck.reason).contains("ran out of time")
	assert_bool(runs.fine.ok).is_true()
