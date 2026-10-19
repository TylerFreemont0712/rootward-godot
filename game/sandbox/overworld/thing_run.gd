class_name ThingRun
extends RefCounted
## Runs a thing's player code in the sandbox (ADR-0061; Concept/v0.3/09, section 4): one job per use, one call of the
## code's on_use(thing, player) (or onUse), and one record back (hooks.py, hooks.js). What the record means for the town
## is TownThings.judge_use's to say.
##
##   var record := ThingRun.run(language, source, TownThings.use_input(thing, fields, player, keys, text))
##   # {status: "ok" | "broken" | "timeout" | "oom" | "failed", ok, value, kind, message, line, printed}
##
## Limits: 1 s of the code's time, 3 s of wall clock, 64 MB of memory and 16 KB of output. What the code prints goes out
## as it is, so 16 KB of it stops the run with "failed".

const MARK := "@@thing@@ "
const HARNESS := {
	SandboxJob.PYTHON: "res://sandbox/overworld/hooks.py",
	SandboxJob.JAVASCRIPT: "res://sandbox/overworld/hooks.js",
}
const ENTRY := "_thing"
## The names the hook may have, in either language: a Python player may write onUse, a JavaScript one on_use.
const ENTRIES: Array[String] = ["on_use", "onUse"]
## The same for each hook (Studio S8: a plate answers on_step, a door a link's on_change).
const HOOK_ENTRIES := {
	"on_use": ["on_use", "onUse"], "on_step": ["on_step", "onStep"], "on_change": ["on_change", "onChange"],
}
const TIME_MS := 1000
const WALL_MS := 3000
const MEMORY_MB := 64
const OUTPUT_KB := 16


## `args` is TownThings.use_input's request: the thing's id, fields, keys and text (and, for on_change, `source`: what
## the linked thing changed), and the player. `hook` says which function of the code is called.
static func run(language: String, source: String, args: Dictionary, hook := "on_use") -> Dictionary:
	if not HARNESS.has(language):
		return failed("things run in Python or JavaScript")
	var entry := ENTRY + (".py" if language == SandboxJob.PYTHON else ".js")
	var files: Dictionary[String, String] = {entry: FileAccess.get_file_as_string(HARNESS[language])}
	var job := SandboxJob.of(language, files, entry)
	job.time_ms = TIME_MS
	job.wall_ms = WALL_MS
	job.memory_mb = MEMORY_MB
	job.output_kb = OUTPUT_KB
	job.stdin = JSON.stringify(
		{"entries": HOOK_ENTRIES.get(hook, ENTRIES), "source": source, "thing": args.get("thing", {}), "player": args.get("player", {})}
	)
	return read(Sandbox.run(job))


## A finished run as a record. Public so tests can feed it a run they made up. The answer is the last marked line: the
## harness writes it after the code has finished, so anything the code printed that looks like one comes before it. A
## run that was stopped (time, memory, output) answers nothing, and its printing is not read at all.
static func read(result: SandboxResult) -> Dictionary:
	if result.status == SandboxResult.TIMEOUT:
		return failed_as("timeout", result.message)
	if result.status == SandboxResult.OOM:
		return failed_as("oom", result.message)
	if result.status != SandboxResult.OK:
		return failed(result.message if result.message != "" else "the program did not answer")
	var answer: Dictionary = {}
	# LEARN: the code's prints share standard output with the answer, so the answer is the last marked line. The harness
	# writes it after the code has finished, so a printed line that looks like one comes before it. A run that was stopped
	# is not read at all: its output may end in a printed line that looks like an answer.
	for line in result.stdout.split("\n"):
		if not line.begins_with(MARK):
			continue
		var record: Variant = JSON.parse_string(line.substr(MARK.length()))
		if record is Dictionary:
			answer = record
	if answer.is_empty():
		return failed("the program did not answer")
	return record_of(answer)


static func record_of(record: Dictionary) -> Dictionary:
	return {
		"status": String(record.get("status", "failed")),
		"ok": bool(record.get("ok", false)),
		"value": record.get("value"),
		"kind": String(record.get("kind", "")),
		"message": String(record.get("message", "")),
		"line": int(record.get("line", 0)),
		"printed": String(record.get("printed", "")),
	}


static func failed(message: String) -> Dictionary:
	return failed_as("failed", message)


static func failed_as(status: String, message: String) -> Dictionary:
	return {
		"status": status,
		"ok": false,
		"value": null,
		"kind": "",
		"message": message,
		"line": 0,
		"printed": "",
	}
