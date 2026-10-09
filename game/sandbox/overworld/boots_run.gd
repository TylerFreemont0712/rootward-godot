class_name BootsRun
extends RefCounted
## Runs the player's movement code (their "boots", ADR-0061) in the sandbox: one job calls it for every key on every
## tile of a map, and the answers come back as a table the town walks on (BootsRules.move). Walking never waits for
## the sandbox, and every step is still the player's real code.
##
##   var table := BootsRun.run(SandboxJob.PYTHON, source, Vector2i(40, 30))
##   # {status: "ok" | "broken" | "timeout" | "failed", message, width, height, keys,
##   #  x: PackedInt32Array, y: PackedInt32Array, error: PackedInt32Array, errors: [{kind, message, line}],
##   #  remembers, printed}

const MARK := "@@boots@@ "
const HARNESS := {
	SandboxJob.PYTHON: "res://sandbox/overworld/boots.py",
	SandboxJob.JAVASCRIPT: "res://sandbox/overworld/boots.js",
}
const ENTRY := "_boots"
const TIME_MS := 3000


static func run(language: String, source: String, size: Vector2i, keys: Array[String] = BootsRules.KEYS) -> Dictionary:
	if not HARNESS.has(language):
		return failed(size, keys, "boots run in Python or JavaScript")
	var entry := ENTRY + (".py" if language == SandboxJob.PYTHON else ".js")
	var files: Dictionary[String, String] = {entry: FileAccess.get_file_as_string(HARNESS[language])}
	var job := SandboxJob.of(language, files, entry)
	job.time_ms = TIME_MS
	job.stdin = JSON.stringify({"source": source, "keys": keys, "width": size.x, "height": size.y})
	return read(Sandbox.run(job), size, keys)


## A finished run as a table. Public so tests can feed it a run they made up.
static func read(run: SandboxResult, size: Vector2i, keys: Array[String]) -> Dictionary:
	for line in run.stdout.split("\n"):
		if not line.begins_with(MARK):
			continue
		var record: Variant = JSON.parse_string(line.substr(MARK.length()))
		if record is Dictionary:
			return table_of(record, size, keys)
	if run.status == "timeout":
		var timeout := failed(size, keys, "your boots took too long: is there a loop that never ends?")
		timeout.status = "timeout"
		return timeout
	return failed(size, keys, run.message if run.message != "" else "the boots did not answer")


static func table_of(record: Dictionary, size: Vector2i, keys: Array[String]) -> Dictionary:
	var table := failed(size, keys, "")
	table.status = String(record.get("status", "failed"))
	table.printed = String(record.get("printed", ""))
	if table.status == "broken":
		table.errors = [_error_of(record)]
		table.message = _message_of(table.errors[0])
		return table
	var count := size.x * size.y * keys.size()
	var xs: Array = record.get("x", [])
	var ys: Array = record.get("y", [])
	var marks: Array = record.get("error", [])
	if xs.size() != count or ys.size() != count or marks.size() != count:
		return failed(size, keys, "the boots answered for the wrong number of tiles")
	table.x = PackedInt32Array(xs.map(func(v: Variant) -> int: return int(v)))
	table.y = PackedInt32Array(ys.map(func(v: Variant) -> int: return int(v)))
	table.error = PackedInt32Array(marks.map(func(v: Variant) -> int: return int(v)))
	var errors: Array[Dictionary] = []
	for error: Variant in record.get("errors", []):
		if error is Dictionary:
			errors.append(_error_of(error))
	table.errors = errors
	table.remembers = bool(record.get("remembers", false))
	return table


static func failed(size: Vector2i, keys: Array[String], message: String) -> Dictionary:
	return {
		"status": "failed",
		"message": message,
		"width": size.x,
		"height": size.y,
		"keys": keys.duplicate(),
		"x": PackedInt32Array(),
		"y": PackedInt32Array(),
		"error": PackedInt32Array(),
		"errors": [],
		"remembers": false,
		"printed": "",
	}


static func _error_of(record: Dictionary) -> Dictionary:
	return {
		"kind": String(record.get("kind", "Error")),
		"message": String(record.get("message", "")),
		"line": int(record.get("line", 0)),
	}


static func _message_of(error: Dictionary) -> String:
	if error.kind == "missing":
		return error.message
	var at := " (line %d)" % error.line if int(error.line) > 0 else ""
	return "%s: %s%s" % [error.kind, error.message, at]
