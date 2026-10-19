class_name LessonRun
extends RefCounted
## Runs the player's lesson programs in the sandbox (ADR-0061): lesson 2's save (what the town remembers about the
## player) and lesson 3's light_all (every lamp on the lane). One job calls the player's function on every case, and
## the answers come back as one marked line (lessons.py, lessons.js):
##
##   LessonRun.run(Lessons.MEMORY, language, source, cases)
##   # {status: "ok" | "broken" | "timeout" | "failed", kind, message, line, printed,
##   #  results: [{ok: true, value} or {ok: false, kind, message, line}], one per case}
##   LessonRun.save(language, source, player)   # {ok, kept: Dictionary, message}: what the player's save returns
##   LessonRun.lamps(language, source, lamps)   # {ok, lamps: Array, message}: the lamps after light_all ran
## A `message` is the run's own words in English (the kind, the error and its line) for a log; the screens put a
## result into words with Lessons.check's reasons.

const MARK := "@@lesson@@ "
const HARNESS := {
	SandboxJob.PYTHON: "res://sandbox/overworld/lessons.py",
	SandboxJob.JAVASCRIPT: "res://sandbox/overworld/lessons.js",
}
const ENTRY := "_lesson"
const TIME_MS := 3000
## The names a lesson's function may have, by language: JavaScript takes the Python name too.
const SIGNATURES := {
	Lessons.MEMORY: "save(player)",
	Lessons.LAMPS: "light_all(lamps)",
}


static func run(lesson: String, language: String, source: String, cases: Array) -> Dictionary:
	if not HARNESS.has(language):
		return failed("lessons run in Python or JavaScript")
	if not lesson in Lessons.IDS:
		return failed("there is no lesson %s" % lesson)
	var entry := ENTRY + (".py" if language == SandboxJob.PYTHON else ".js")
	var files: Dictionary[String, String] = {entry: FileAccess.get_file_as_string(HARNESS[language])}
	var job := SandboxJob.of(language, files, entry)
	job.time_ms = TIME_MS
	var name := Lessons.entry(lesson, language)
	var entries: Array[String] = [name]
	if language == SandboxJob.JAVASCRIPT and Lessons.entry(lesson, Lessons.PYTHON) != name:
		entries.append(Lessons.entry(lesson, Lessons.PYTHON))
	var signature := String(SIGNATURES[lesson]).replace(Lessons.entry(lesson, Lessons.PYTHON), name)
	job.stdin = JSON.stringify(
		{"lesson": lesson, "entries": entries, "signature": signature, "source": source, "cases": cases}
	)
	return read(Sandbox.run(job), cases.size())


## A finished run as a record. Public so tests can feed it a run they made up.
static func read(run_result: SandboxResult, count: int) -> Dictionary:
	for line in run_result.stdout.split("\n"):
		if not line.begins_with(MARK):
			continue
		var record: Variant = JSON.parse_string(line.substr(MARK.length()))
		if record is Dictionary:
			return record_of(record, count)
	if run_result.status == SandboxResult.TIMEOUT:
		var timeout := failed("the program took too long: is there a loop that never ends?")
		timeout.status = "timeout"
		return timeout
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


## The player's save on one player: {ok, kept, message}. `kept` is what it gave back when that was a dictionary.
static func save(language: String, source: String, player: Dictionary) -> Dictionary:
	var ran := run(Lessons.MEMORY, language, source, [player])
	var one := _first(ran)
	if not bool(one.get("ok", false)):
		return {"ok": false, "kept": {}, "message": _words(ran, one)}
	var value: Variant = one.get("value")
	if not value is Dictionary:
		return {"ok": false, "kept": {}, "message": "save gave back %s, not a dictionary" % Lessons.shown(value)}
	return {"ok": true, "kept": value, "message": ""}


## light_all on one lane: {ok, lamps, message}. `lamps` is the lane as the code left it (the lane given, on an error).
static func lamps(language: String, source: String, lamps_in: Array) -> Dictionary:
	var ran := run(Lessons.LAMPS, language, source, [lamps_in])
	var one := _first(ran)
	if not bool(one.get("ok", false)):
		return {"ok": false, "lamps": lamps_in, "message": _words(ran, one)}
	var value: Variant = one.get("value")
	if not value is Array:
		return {"ok": false, "lamps": lamps_in, "message": "light_all gave back %s, not a list" % Lessons.shown(value)}
	return {"ok": true, "lamps": value, "message": ""}


static func _first(ran: Dictionary) -> Dictionary:
	if String(ran.status) != "ok" or (ran.results as Array).is_empty():
		return {}
	var first: Variant = (ran.results as Array)[0]
	return first if first is Dictionary else {}


## A failed run or case in a line of English, for a log.
static func _words(ran: Dictionary, one: Dictionary) -> String:
	var source: Dictionary = one if not one.is_empty() else ran
	var kind := String(source.get("kind", ""))
	var message := String(source.get("message", ""))
	if kind == "" or kind == "missing":
		return message
	var at := " (line %d)" % int(source.line) if int(source.get("line", 0)) > 0 else ""
	return "%s: %s%s" % [kind, message, at]
