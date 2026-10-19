class_name TaskRun
extends RefCounted
## Runs the player's task programs in the sandbox (Concept/v0.4): one job calls their function once per call and the
## answers come back as one marked line (tasks.py, tasks.js). A check is every case of a stage and those before it; a
## table is the same job over every input the game can ask (every key, every notch, every minute), so the game reads
## the player's answers without waiting.
##
##   TaskRun.run("python", source, calls)          # {status, kind, message, line, printed, results: [...]}
##   TaskRun.check(task, 1, "python", source)      # Tasks.check over the stage's cases: {ok, problem, cases, stage_ok}
##   TaskRun.table(task, 0, "python", source, domain)  # {ok, values, errors, problem}
## Each call: {entries, signature, args, mutates} (Tasks.check_calls). Arguments go through JsJson, so a whole number
## reaches Python as an int.

const MARK := "@@task@@ "
const HARNESS := {
	SandboxJob.PYTHON: "res://sandbox/overworld/tasks.py",
	SandboxJob.JAVASCRIPT: "res://sandbox/overworld/tasks.js",
}
const ENTRY := "_task"
const TIME_MS := 3000
## A table of every cell of the town (map stage 2) is thousands of answers; the boots' cap is the model.
const OUTPUT_KB := 1024


static func run(language: String, source: String, calls: Array, time_ms := TIME_MS) -> Dictionary:
	if not HARNESS.has(language):
		return failed("tasks run in Python or JavaScript")
	var entry := ENTRY + (".py" if language == SandboxJob.PYTHON else ".js")
	var files: Dictionary[String, String] = {entry: FileAccess.get_file_as_string(HARNESS[language])}
	var job := SandboxJob.of(language, files, entry)
	job.time_ms = time_ms
	job.output_kb = OUTPUT_KB
	job.stdin = JsJson.stringify({"source": source, "calls": calls})
	return read(Sandbox.run(job), calls.size())


## A finished run as a record. Public so tests can feed it a run they made up.
static func read(run_result: SandboxResult, count: int) -> Dictionary:
	var record: Variant = null
	for line in run_result.stdout.split("\n"):
		if line.begins_with(MARK):
			record = JSON.parse_string(line.substr(MARK.length()))
	if record is Dictionary:
		return record_of(record, count)
	if run_result.status == SandboxResult.TIMEOUT:
		var timeout := failed("the program took too long: is there a loop that never ends?")
		timeout.status = "timeout"
		return timeout
	if run_result.status == SandboxResult.OOM:
		return failed("the program used too much memory")
	return failed(run_result.message if run_result.message != "" else "the program did not answer")


static func record_of(record: Dictionary, count: int) -> Dictionary:
	var out := failed("")
	out.status = String(record.get("status", "failed"))
	out.printed = String(record.get("printed", ""))
	if out.status == "broken":
		out.kind = String(record.get("kind", "Error"))
		out.message = String(record.get("message", ""))
		out.line = int(record.get("line", 0))
		return out
	var results: Array = record.get("results", [])
	if results.size() != count:
		return failed("the program answered for the wrong number of cases")
	out.results = results
	return out


static func failed(message: String) -> Dictionary:
	return {"status": "failed", "kind": "", "message": message, "line": 0, "results": [], "printed": ""}


## Stage `index` of `task` checked on `source`: Tasks.check over one run of every case up to it, with the run's
## `printed` beside it.
static func check(task: Dictionary, index: int, language: String, source: String) -> Dictionary:
	var ran := run(language, source, Tasks.check_calls(task, index, language))
	var checked := Tasks.check(task, index, ran)
	checked.printed = String(ran.get("printed", ""))
	return checked


## Stage `index`'s function on every argument list of `domain`: {ok, values, errors, problem}. `values` has one
## answer per argument list (null where the call failed); `errors` lists the failed ones ({index, kind, message,
## line}); `problem` is the run's own trouble ({} when it ran). `ok` is that it ran and no call failed.
static func table(task: Dictionary, index: int, language: String, source: String, domain: Array) -> Dictionary:
	var names := Tasks.entries(task, index, language)
	var shape := Tasks.signature(task, index, language)
	var mutates := int(Tasks.stage(task, index).get("mutates", -1))
	var calls: Array = []
	for args: Variant in domain:
		calls.append({"entries": names, "signature": shape, "args": args, "mutates": mutates})
	var ran := run(language, source, calls)
	if String(ran.status) != "ok":
		var problem := {"reason": String(ran.status), "kind": String(ran.kind), "message": String(ran.message), "line": int(ran.line)}
		return {"ok": false, "values": [], "errors": [], "problem": problem}
	var values: Array = []
	var errors: Array[Dictionary] = []
	var results: Array = ran.results
	for i in results.size():
		var result: Dictionary = results[i] if results[i] is Dictionary else {}
		if bool(result.get("ok", false)):
			values.append(result.get("value"))
		else:
			values.append(null)
			errors.append({
				"index": i,
				"kind": String(result.get("kind", "Error")),
				"message": String(result.get("message", "")),
				"line": int(result.get("line", 0)),
			})
	return {"ok": errors.is_empty(), "values": values, "errors": errors, "problem": {}}
