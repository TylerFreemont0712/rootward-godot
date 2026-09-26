extends GdUnitTestSuite
## The Godot spell harness against the old server's: the same spells of real shards, in both languages, must return
## the same bolts, traces, work and failures (fixture from tools/fixtures/spells.ts).

## A recursive card with a loop and a comprehension (map): four bolts make four calls, and only the last call, with one
## bolt left, goes round each loop once.
const WALK := {
	"id": "walk",
	"function": "walk",
	"code":
	{
		"python":
		(
			"def walk(bolts, battle):\n"
			+ "    if len(bolts) > 1:\n"
			+ "        return walk(bolts[1:], battle) + bolts[:1]\n"
			+ "    out = []\n"
			+ "    for bolt in bolts:\n"
			+ "        out.append(bolt)\n"
			+ "    return [dict(b) for b in out]\n"
		),
		"javascript":
		(
			"function walk(bolts, battle) {\n"
			+ "  if (bolts.length > 1) return walk(bolts.slice(1), battle).concat(bolts.slice(0, 1));\n"
			+ "  const out = [];\n"
			+ "  for (const bolt of bolts) out.push(bolt);\n"
			+ "  return out.map((b) => ({ ...b }));\n"
			+ "}\n"
		),
	},
}

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


func test_a_counted_run_measures_loops_and_recursion() -> void:
	var bolts := [{"power": 1, "element": "none"}, {"power": 2, "element": "none"}]
	bolts.append_array([{"power": 3, "element": "none"}, {"power": 4, "element": "none"}])
	var battle := {"turn": 1, "me": {"hp": 30, "max": 30, "block": 0, "mana": 5}, "foes": []}
	var expected := {"python": {"5": 1, "7": 1}, "javascript": {"4": 1, "5": 1}}
	for language: String in ["python", "javascript"]:
		var spells: Array[Dictionary] = [{"id": "w", "shards": [WALK]}]
		var input := {"bolts": bolts, "battle": battle, "limit": 64, "trace_limit": 4}
		var plain: Dictionary = SpellHarness.run(language, spells, input).w
		input.count = true
		var counted: Dictionary = SpellHarness.run(language, spells, input).w
		assert_bool(counted.ok).override_failure_message(str(counted.get("reason"))).is_true()
		# Counting never changes what a card does.
		assert_array(counted.bolts).is_equal(plain.bolts)
		assert_bool((plain.trace[0] as Dictionary).has("loops")).is_false()
		var step: Dictionary = counted.trace[0]
		assert_int(int(step.calls)).override_failure_message(language).is_equal(4)
		var loops := {}
		for line: String in step.loops:
			loops[line] = int(step.loops[line])
		assert_dict(loops).override_failure_message(language).is_equal(expected[language])
