class_name LanternWatch
extends RefCounted
## Runs Lanternroot's tests against the player's town in the sandbox (ADR-0055): every module of the town as a file,
## the watch harness beside them (watch.py or watch.js), and the cases on standard input. One sandbox run for all the
## cases, so the whole Night Watch costs one interpreter start.
##
##   var report := LanternWatch.run(town.language, town.files, cases)
##   # {status, message, results: [{id, letter, kind, name, call, status, expected, actual, printed, error (its
##   #   kind, like "TypeError"), message, file, line}], in the order of `cases`}
##
## A result's status: "pass", "fail" (it returned something else), "error" (it raised), "missing" (no such module or
## function), "timeout" (this case was running when time ran out), or "unreached" (the run ended before it, for a
## reason other than a case running out of time).

const MARK := "@@lantern@@ "
const HARNESS := {
	SandboxJob.PYTHON: "res://sandbox/lanternroot/watch.py",
	SandboxJob.JAVASCRIPT: "res://sandbox/lanternroot/watch.js",
}
const ENTRY := "_lantern_watch"
const TIME_MS := 4000
## How many cases may run out of time before the rest are given up on: each costs a whole time limit.
const STUCK_LIMIT := 3


## Runs every case. A case that never ends costs only its own letter: the watch starts again with the other letters'
## cases after it, up to STUCK_LIMIT times, and the stuck letter's remaining cases are reported unreached.
static func run(language: String, files: Dictionary, cases: Array[Dictionary]) -> Dictionary:
	var report := _run_once(language, files, cases)
	var results: Array[Dictionary] = report.results
	for attempt in STUCK_LIMIT - 1:
		var stuck := _last_stuck(results)
		if stuck == -1 or stuck == results.size() - 1 or results[stuck + 1].status != "unreached":
			break
		var letter: String = results[stuck].letter
		var rest: Array[Dictionary] = []
		for case: Dictionary in cases.slice(stuck + 1):
			if case.letter != letter:
				rest.append(case)
		var more := _run_once(language, files, rest)
		var by_id := {}
		for result: Dictionary in more.results:
			by_id[result.id] = result
		for i in range(stuck + 1, results.size()):
			if by_id.has(results[i].id):
				results[i] = by_id[results[i].id]
			else:
				results[i].message = "not run: an earlier test of this letter never finished"
		report = more
	return {"status": report.status, "message": report.message, "results": results}


static func _last_stuck(results: Array[Dictionary]) -> int:
	for i in range(results.size() - 1, -1, -1):
		if results[i].status == "timeout":
			return i
	return -1


static func _run_once(language: String, files: Dictionary, cases: Array[Dictionary]) -> Dictionary:
	var modules: Array[String] = []
	var job_files: Dictionary[String, String] = {}
	for module: String in files:
		modules.append(module)
		job_files[LanternCode.file_name(module, language)] = String(files[module])
	var entry := LanternCode.file_name(ENTRY, language)
	job_files[entry] = FileAccess.get_file_as_string(HARNESS[language])
	var job := SandboxJob.of(language, job_files, entry)
	job.time_ms = TIME_MS
	job.stdin = JsJson.stringify({"modules": modules, "sources": files, "cases": _wire(cases)})
	var run := Sandbox.run(job)
	return read(run, cases)


## A finished run's records matched to its cases. Public so tests can feed it a run they made up.
static func read(run: SandboxResult, cases: Array[Dictionary]) -> Dictionary:
	var records := {}
	for line in run.stdout.split("\n"):
		if line.begins_with(MARK):
			var record: Variant = JsJson.parse(line.substr(MARK.length()))
			if record is Dictionary:
				records[String(record.get("id", ""))] = record
	var stuck := ""
	if not run.is_ok():
		for line in run.stderr.split("\n"):
			if line.begins_with("@case "):
				stuck = line.substr(6).strip_edges()
	var results: Array[Dictionary] = []
	var after_stuck := false
	for case in cases:
		var result := {
			"id": case.id,
			"letter": case.letter,
			"kind": case.kind,
			"name": case.name,
			"call": "",
			"expected": "",
			"actual": "",
			"printed": "",
			"error": "",
			"message": "",
			"file": "",
			"line": 0,
		}
		if records.has(case.id):
			var record: Dictionary = records[case.id]
			for key: String in ["call", "expected", "actual", "printed", "message", "file"]:
				result[key] = String(record.get(key, ""))
			result.status = String(record.get("status", "error"))
			result.error = String(record.get("kind", ""))
			result.line = int(record.get("line", 0))
		elif case.id == stuck:
			result.status = "timeout" if run.status == SandboxResult.TIMEOUT else "error"
			result.message = run.message
			after_stuck = true
		else:
			result.status = "unreached" if after_stuck or stuck != "" else "error"
			result.message = run.message if run.message != "" else "the watch could not run"
		results.append(result)
	var status := run.status if records.size() < cases.size() else SandboxResult.OK
	return {"status": status, "message": run.message, "results": results}


static func _wire(cases: Array[Dictionary]) -> Array:
	var wire: Array = []
	for case in cases:
		(
			wire
			. append(
				{
					"id": case.id,
					"module": case.module,
					"function": case.function,
					"args": case.args,
					"expect": case.expect,
				}
			)
		)
	return wire
