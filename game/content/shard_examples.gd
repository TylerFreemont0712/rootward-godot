class_name ShardExamples
extends RefCounted
## Runs every shard's worked examples in the sandbox, in both languages: the examples are the promise a shard's summary
## makes, and this is what keeps it (the old content validation's executeShards). One job per language.

## Examples check what a shard does, not the run's bolt cap, so they get room well past any balance setting.
const EXAMPLE_BOLT_LIMIT := 256
const DEFAULT_BATTLE := {
	"turn": 1,
	"me": {"hp": 30, "max": 30, "block": 0, "mana": 6},
	"foes": [{"name": "Training Dummy", "hp": 20, "max": 20, "shield": 0, "weak": [], "resist": []}],
}


## Diagnostics for every example that failed or produced other bolts than it expects: the shards', and the program
## cards' (ADR-0012) when the catalog has them. Blocks while the sandbox runs.
static func check(catalog: Dictionary, languages: Array[String] = ShardrunChecks.LANGUAGES) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var sets: Array[Dictionary] = [
		{"noun": "shard", "cards": ShardrunCatalog.sorted_values(catalog.shards), "same": same_bolts}
	]
	var cards: Dictionary = (catalog.get("programs", {}) as Dictionary).get("cards", {})
	if not cards.is_empty():
		sets.append({"noun": "card", "cards": ShardrunCatalog.sorted_values(cards), "same": same_program_bolts})
	for language in languages:
		if not Sandbox.is_available(language):
			diagnostics.append(
				_diagnostic("warning", "not-executed", "no sandbox for %s: examples not run" % language, "")
			)
			continue
		for group in sets:
			diagnostics.append_array(_run(language, group.noun, group.cards, group.same))
	return diagnostics


## One sandbox job running every example of these shards (or cards) in one language; `same` compares the bolts.
static func _run(language: String, noun: String, shards: Array, same: Callable) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var spells: Array[Dictionary] = []
	var owners := {}
	for shard: Dictionary in shards:
		if not (shard.code as Dictionary).has(language):
			continue
		var examples: Array = shard.examples
		for i in examples.size():
			var example: Dictionary = examples[i]
			var id := "%s#%d" % [shard.id, i]
			spells.append(
				{"id": id, "shards": [shard], "bolts": example.bolts, "battle": example.get("battle", DEFAULT_BATTLE)}
			)
			owners[id] = [shard, example]
	var input := {"bolts": [], "battle": DEFAULT_BATTLE, "limit": EXAMPLE_BOLT_LIMIT, "trace_limit": 1}
	var limits := SandboxJob.new()
	limits.time_ms = 20000
	limits.wall_ms = 60000
	limits.output_kb = 4096
	var runs := SpellHarness.run(language, spells, input, limits)
	for id: String in owners:
		var shard: Dictionary = owners[id][0]
		var example: Dictionary = owners[id][1]
		var run: Dictionary = runs.get(id, {"ok": false, "reason": "no result"})
		var label := '%s %s (%s): example "%s"' % [noun, shard.id, language, example.name]
		if not run.ok:
			diagnostics.append(_diagnostic("error", "shard-example", "%s failed: %s" % [label, run.reason], shard.id))
		elif not same.call(run.bolts, example.expect):
			var message := (
				"%s expected %s but got %s" % [label, JsJson.stringify(example.expect), JsJson.stringify(run.bolts)]
			)
			diagnostics.append(_diagnostic("error", "shard-example", message, shard.id))
	return diagnostics


## A program card's bolts ({power, element, foe?, block?}) match when every field does, the power within a rounding
## error and `block: false` the same as no block at all.
static func same_program_bolts(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in expected.size():
		if not actual[i] is Dictionary:
			return false
		var got: Dictionary = actual[i]
		var want: Dictionary = expected[i]
		var power: Variant = got.get("power")
		if not (power is int or power is float) or absf(float(power) - float(want.power)) >= 1e-6:
			return false
		if got.get("element") != want.element or bool(got.get("block", false)) != bool(want.get("block", false)):
			return false
		var foe: Variant = got.get("foe")
		if want.has("foe") != (foe != null):
			return false
		if foe != null and int(foe) != int(want.foe):
			return false
	return true


## LEARN: 4 * 0.6 is 2.4000000000000004 in both Python and JavaScript (IEEE 754 doubles), so power and multiplier are
## compared with a tolerance; every other field must match exactly.
static func same_bolts(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for i in expected.size():
		var got := ShardrunRules.parse_bolt(actual[i])
		var want: Dictionary = expected[i]
		if got.is_empty():
			return false
		if (
			absf(float(got.power) - float(want.power)) >= 1e-6
			or absf(float(got.mult) - float(want.get("mult", 1))) >= 1e-6
		):
			return false
		for key: String in ["element", "target", "pierce", "ward"]:
			if got[key] != want[key]:
				return false
	return true


static func _diagnostic(severity: String, code: String, message: String, file: String) -> Dictionary:
	return {"severity": severity, "code": code, "message": message, "file": file}
