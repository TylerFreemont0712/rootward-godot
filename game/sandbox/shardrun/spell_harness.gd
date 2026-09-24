class_name SpellHarness
extends RefCounted
## Runs Shardrun spells in the sandbox (old ADR-0012, ADR-0013). A spell's shards are real functions, each taking the
## bolts and the battle and returning bolts. Every spell of a turn runs in one sandbox job, one process start for all
## of them; the harness prints one result line per spell, with a trace of the bolts after every shard.
##
## A shard is a Dictionary from content: {id, function (snake_case), code: {python, javascript}}.
## A run is a Dictionary:
##   {ok: true, bolts, trace, work, console}
##   {ok: false, reason, shard?, line?, trace, console}
## where trace is [{shard, given, returned, bolts}] and work is the bolts handed to shards in all (the cast's price).

const HARNESSES := {
	SandboxJob.PYTHON: "res://sandbox/shardrun/spell_harness.py",
	SandboxJob.JAVASCRIPT: "res://sandbox/shardrun/spell_harness.js",
}
const ENTRIES := {SandboxJob.PYTHON: "spell.py", SandboxJob.JAVASCRIPT: "spell.js"}


## The name a shard's function has in `language`: snake_case in Python, camelCase in JavaScript.
static func function_name(shard: Dictionary, language: String) -> String:
	var snake: String = shard.function
	if language == SandboxJob.PYTHON:
		return snake
	var parts := snake.split("_")
	var name := parts[0]
	for i in range(1, parts.size()):
		var part := parts[i]
		name += part.substr(0, 1).to_upper() + part.substr(1)
	return name


## Runs `spells` ([{id, shards: [shard Dictionary]}]) from the same `input` ({bolts, battle, limit, trace_limit}).
## Returns spell id -> run. When one spell stops the whole job (an endless loop), each spell runs again alone, so the
## timeout lands on the spell that caused it and the others still report.
static func run(
	language: String, spells: Array[Dictionary], input: Dictionary, limits: SandboxJob = null
) -> Dictionary:
	var runs := {}
	var runnable: Array[Dictionary] = []
	for spell in spells:
		var missing := _missing_code(spell, language)
		if missing != "":
			runs[spell.id] = _failure(missing, [], "")
		else:
			runnable.append(spell)
	if runnable.is_empty():
		return runs
	var marker := "@@shardrun-%s@@" % Crypto.new().generate_random_bytes(6).hex_encode()
	var job := build_job(language, runnable, input, marker, limits)
	var result := Sandbox.run(job)
	if _stopped_early(result) and runnable.size() > 1:
		for spell in runnable:
			var alone: Array[Dictionary] = [spell]
			runs.merge(run(language, alone, input, limits), true)
		return runs
	runs.merge(read_runs(result, runnable, marker), true)
	return runs


static func build_job(
	language: String, spells: Array[Dictionary], input: Dictionary, marker: String, limits: SandboxJob = null
) -> SandboxJob:
	var shards: Array[Dictionary] = []
	var index_of := {}
	var programs: Array[Dictionary] = []
	for spell in spells:
		var indexes: Array[int] = []
		for shard: Dictionary in spell.shards:
			if not index_of.has(shard.id):
				index_of[shard.id] = shards.size()
				var name := function_name(shard, language)
				shards.append({"id": shard.id, "name": name, "source": shard.code[language]})
			indexes.append(index_of[shard.id])
		programs.append({"id": spell.id, "shards": indexes})
	var data := {
		"marker": marker,
		"shards": shards,
		"spells": programs,
		"bolts": input.bolts,
		"battle": input.battle,
		"limit": input.limit,
		"traceLimit": input.trace_limit,
	}
	var entry: String = ENTRIES[language]
	var files: Dictionary[String, String] = {entry: FileAccess.get_file_as_string(HARNESSES[language])}
	var job := SandboxJob.of(language, files, entry)
	if limits != null:
		job.time_ms = limits.time_ms
		job.wall_ms = limits.wall_ms
		job.memory_mb = limits.memory_mb
		job.output_kb = limits.output_kb
	# Written as JavaScript would, so shard code sees 4 rather than 4.0 (see JsJson).
	job.stdin = JsJson.stringify(data)
	return job


## Each spell's run from a finished job, keyed by spell id.
static func read_runs(result: SandboxResult, spells: Array[Dictionary], marker: String) -> Dictionary:
	var printed: PackedStringArray = []
	var lines := {}
	for line in result.stdout.split("\n"):
		if not line.begins_with(marker):
			printed.append(line)
			continue
		var parsed: Variant = JSON.parse_string(line.substr(marker.length()))
		if parsed is Dictionary and (parsed as Dictionary).has("spell"):
			lines[parsed.spell] = parsed
	var console := "\n".join(printed).strip_edges()
	var runs := {}
	for spell in spells:
		var line: Dictionary = lines.get(spell.id, {})
		if line.is_empty():
			runs[spell.id] = _failure(_describe(result), [], console)
		elif line.ok:
			var work := 0
			for step: Dictionary in line.trace:
				work += int(step.given)
			runs[spell.id] = {"ok": true, "bolts": line.bolts, "trace": line.trace, "work": work, "console": console}
		else:
			var reason: String = line.error
			if line.has("shard"):
				reason = (
					"%s%s: %s" % [line.shard, "" if not line.has("line") else " line %d" % int(line.line), line.error]
				)
			var run := _failure(reason, line.trace, console)
			if line.has("shard"):
				run.shard = line.shard
			if line.has("line"):
				run.line = int(line.line)
			runs[spell.id] = run
	return runs


static func _failure(reason: String, trace: Array, console: String) -> Dictionary:
	return {"ok": false, "reason": reason, "trace": trace, "console": console}


static func _missing_code(spell: Dictionary, language: String) -> String:
	for shard: Dictionary in spell.shards:
		var code: Dictionary = shard.get("code", {})
		if not code.has(language):
			return "a shard has no %s code" % language
	return ""


static func _stopped_early(result: SandboxResult) -> bool:
	return (
		result.status
		in [SandboxResult.TIMEOUT, SandboxResult.OOM, SandboxResult.SANDBOX_ERROR, SandboxResult.RUNTIME_ERROR]
	)


## Why a spell has no result line: the whole run's ending, in the player's words.
static func _describe(result: SandboxResult) -> String:
	match result.status:
		SandboxResult.TIMEOUT:
			return "it ran out of time (a loop that never ends?)"
		SandboxResult.OOM:
			return "it ran out of memory"
		SandboxResult.SANDBOX_ERROR:
			return "the sandbox failed to run it"
	var last := Sandbox._last_line(result.stderr, "")
	if last != "":
		return last
	return "a shard has a syntax error" if result.status == SandboxResult.COMPILE_ERROR else "a shard raised an error"
