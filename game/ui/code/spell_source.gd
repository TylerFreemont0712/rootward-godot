class_name SpellSource
extends RefCounted
## A spell as one program (old ADR-0013, "the function as a whole"): its shards' functions, and a cast function that
## calls them in slot order, in the run's language. `frames` plans a playback that walks it line by line. Values only
## ever change where the sandbox really measured them: the base bolt, after each shard returns, and the result; between
## those, the cursor just walks the lines being run.
##
##   var source := SpellSource.compose("python", "Bolt", ["amplify"], catalog.shards, 4)
##   for frame in SpellSource.frames(source, run_view, "normal"): ...   # {at, line, mark?, step?, bolts?, outcome?}

## Milliseconds a line holds the cursor, and the pause where a value is shown.
const SPEEDS := {
	"slow": {"line": 380, "pause": 700},
	"normal": {"line": 160, "pause": 380},
	"fast": {"line": 55, "pause": 150},
}

## [{number (1-based), text, kind: comment|blank|def|body|start|call|return, shard?}]
var lines: Array[Dictionary] = []
## The line that makes the starting bolt.
var start_line := 0
## One call per slot, in order: [{line, shard}].
var calls: Array[Dictionary] = []
var return_line := 0
## Shard id -> {def_line, body: [line numbers that run]}.
var functions: Dictionary = {}


static func compose(
	language: String, spell_name: String, shard_ids: Array, shards: Dictionary, base_power: int
) -> SpellSource:
	var source := SpellSource.new()
	var python := language == SandboxJob.PYTHON
	var comment := "#" if python else "//"
	var names: Array[String] = []
	for id: String in shard_ids:
		names.append((shards.get(id, {}) as Dictionary).get("name", id))
	var chain := " → ".join(names) if not names.is_empty() else "one plain bolt"
	source._add("%s %s: %s" % [comment, spell_name, chain], "comment")
	source._add("", "blank")

	# The cast comes first: it is what the spell is, and each call below leads down into the shard it names.
	var cast_name := "cast_" + snake_case(spell_name) if python else "cast" + pascal_case(spell_name)
	source._add("def %s(battle):" % cast_name if python else "function %s(battle) {" % cast_name, "def")
	var start := (
		(
			'    bolts = [{"power": %d, "element": "none", "target": "front", "pierce": False, "ward": False, "mult": 1}]'
			% base_power
		)
		if python
		else (
			'  let bolts = [{ power: %d, element: "none", target: "front", pierce: false, ward: false, mult: 1 }];'
			% base_power
		)
	)
	source.start_line = source._add(start, "start")
	for id: String in shard_ids:
		var shard: Dictionary = shards.get(id, {})
		var name := SpellHarness.function_name(shard, language) if shard.has("function") else id
		var call := "    bolts = %s(bolts, battle)" % name if python else "  bolts = %s(bolts, battle);" % name
		source.calls.append({"line": source._add(call, "call"), "shard": id})
	source.return_line = source._add("    return bolts" if python else "  return bolts;", "return")
	if not python:
		source._add("}", "body")

	var seen := {}
	for id: String in shard_ids:
		if seen.has(id):
			continue
		seen[id] = true
		source._add("", "blank")
		var shard: Dictionary = shards.get(id, {})
		var code: String = (shard.get("code", {}) as Dictionary).get(language, "")
		if code == "":
			source._add("%s %s: this shard is missing" % [comment, id], "comment")
			continue
		source._add_function(id, code.strip_edges(false, true), SpellHarness.function_name(shard, language), python)
	return source


func _add_function(id: String, code: String, function: String, python: bool) -> void:
	var def_line := 0
	var body: Array[int] = []
	var opener := ("def %s(" if python else "function %s(") % function
	var first := lines.size() + 1
	for text in code.split("\n"):
		var is_def := def_line == 0 and text.begins_with(opener)
		var number := _add(text, "def" if is_def else "body", id)
		if is_def:
			def_line = number
		elif def_line != 0 and runs(text):
			body.append(number)
	functions[id] = {"def_line": def_line if def_line != 0 else first, "body": body}


func _add(text: String, kind: String, shard := "") -> int:
	var line := {"number": lines.size() + 1, "text": text, "kind": kind}
	if shard != "":
		line.shard = shard
	lines.append(line)
	return lines.size()


## Whether the cursor stops on a line: blank lines, closing braces and comments are skipped.
static func runs(text: String) -> bool:
	var stripped := text.strip_edges()
	return not (stripped == "" or stripped == "}" or stripped.begins_with("#") or stripped.begins_with("//"))


## When each line lights up. Each call pauses on its line, walks the shard's body, then returns to the call with the
## bolts that shard really passed on. A misfire stops on the failing line when the sandbox reported one.
static func frames(source: SpellSource, run: Dictionary, speed: String) -> Array[Dictionary]:
	var timing: Dictionary = SPEEDS.get(speed, SPEEDS.normal)
	var line_ms := float(timing.line)
	var pause := float(timing.pause)
	var out: Array[Dictionary] = []
	var clock := [0.0]
	var push := func(frame: Dictionary, dwell: float) -> void:
		frame.at = clock[0]
		out.append(frame)
		clock[0] += dwell

	var base: Dictionary = run.get("base", {})
	var start := {"line": source.start_line, "mark": "start", "bolts": base.get("bolts", [])}
	if base.has("outcome"):
		start.outcome = base.outcome
	push.call(start, pause)
	var steps: Array = run.get("steps", [])
	var misfire: Dictionary = run.get("misfire", {})
	var failing := -2
	if not misfire.is_empty():
		failing = steps.size() if misfire.has("shard") else -1
	if failing == -1:
		# No shard to blame (a timeout, say): the whole cast stops where it began.
		push.call({"line": source.start_line, "mark": "error"}, pause * 2)
		return out
	for index in source.calls.size():
		var call: Dictionary = source.calls[index]
		var function: Dictionary = source.functions.get(call.shard, {})
		var body: Array = function.get("body", [])
		push.call({"line": call.line}, line_ms)
		if index == failing:
			var error_line := -1
			if not function.is_empty() and misfire.has("line"):
				error_line = int(function.def_line) + int(misfire.line) - 1
			for line: int in body:
				if error_line >= 0 and line >= error_line:
					break
				push.call({"line": line}, line_ms)
			var stop: int = error_line if error_line >= 0 else (body[-1] if not body.is_empty() else call.line)
			push.call({"line": stop, "mark": "error"}, pause * 2)
			return out
		if index >= steps.size():
			break
		for line: int in body:
			push.call({"line": line}, line_ms)
		var step: Dictionary = steps[index]
		var returned := {"line": call.line, "mark": "step", "step": index, "bolts": step.bolts}
		if step.has("outcome"):
			returned.outcome = step.outcome
		push.call(returned, pause)
	var result := {"line": source.return_line, "mark": "result"}
	if run.has("result"):
		result.outcome = run.result
	push.call(result, pause * 1.6)
	return out


## Total playback time, including the last pause.
static func length_ms(played: Array[Dictionary], speed: String) -> float:
	var timing: Dictionary = SPEEDS.get(speed, SPEEDS.normal)
	return (float(played[-1].at) if not played.is_empty() else 0.0) + float(timing.pause) * 1.6


static func snake_case(name: String) -> String:
	var out := ""
	var gap := false
	for character in name.strip_edges().to_lower():
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			if gap and out != "":
				out += "_"
			out += character
			gap = false
		else:
			gap = true
	return out if out != "" else "spell"


static func pascal_case(name: String) -> String:
	var out := ""
	for word in snake_case(name).split("_", false):
		out += word.substr(0, 1).to_upper() + word.substr(1)
	return out if out != "" else "Spell"
