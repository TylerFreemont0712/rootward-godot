class_name Tasks
extends RefCounted
## The parts of the game the player builds (Concept/v0.4): each is a task in content (`overworld/tasks/<id>.jsonc`),
## a function to write in stages, each stage with cases, a judge and hints. Pure rules over a task's data; the sandbox
## runs the code (TaskRun) and these decide what it means.
##
##   Tasks.check_calls(task, 1, "python")      # every case of stages 0 and 1, as the harness's calls
##   Tasks.check(task, 1, run)                 # {ok, problem, cases: [verdict], stage_ok: [bool]}
##   Tasks.advice(task, 1, checked)            # {reason, case, text}: what to say about it
##   Tasks.source(task, blocks, "python")      # the code a Builder's blocks make
##   Tasks.open_stage(task, record, flags)     # the stage the editor opens on
##
## Checking stage n runs the cases of every stage up to n, each with its own function and judge: a later stage never
## breaks an earlier one. Stages are counted from 0 here and from 1 on screen. The format is Concept/v0.4/02.

const PYTHON := "python"
const JAVASCRIPT := "javascript"
const LANGUAGES: Array[String] = [PYTHON, JAVASCRIPT]
const EQUALS := "equals"
## How close two numbers must be to be the same answer (5 and 5.0, 0.1 + 0.2 and 0.3).
const TOLERANCE := 1e-6
## Run problems: the program never reached its cases.
const BROKEN := "broken"
const TIMEOUT := "timeout"
const FAILED := "failed"
## A call's function is not in the program (stage 2's, before it is written).
const NO_FUNCTION := "no-function"

# --- the task's shape ---------------------------------------------------------------------------------------------


static func stages(task: Dictionary) -> Array:
	return task.get("stages", []) if task.get("stages", []) is Array else []


static func stage_count(task: Dictionary) -> int:
	return stages(task).size()


static func stage(task: Dictionary, index: int) -> Dictionary:
	var all := stages(task)
	return all[index] if index >= 0 and index < all.size() and all[index] is Dictionary else {}


## The function stage `index` calls in `language`: the stage's own entry, else the task's.
static func entry(task: Dictionary, index: int, language: String) -> String:
	var named: Variant = stage(task, index).get("entry", task.get("entry", {}))
	return String((named as Dictionary).get(language, "")) if named is Dictionary else ""


## The names the harness may find the function by: JavaScript also takes the Python name, as the lessons do.
static func entries(task: Dictionary, index: int, language: String) -> Array[String]:
	var names: Array[String] = []
	var own := entry(task, index, language)
	if own != "":
		names.append(own)
	if language == JAVASCRIPT:
		var python := entry(task, index, PYTHON)
		if python != "" and not python in names:
			names.append(python)
	return names


## "menu_items(built)" in Python, "menuItems(built)" in JavaScript: the function as the player writes it.
static func signature(task: Dictionary, index: int, language: String) -> String:
	var names := PackedStringArray()
	for param: Variant in glossary(task, index).params:
		if param is Dictionary:
			names.append(String((param as Dictionary).get("name", "")))
	return "%s(%s)" % [entry(task, index, language), ", ".join(names)]


## What the Hints column shows for a stage: {params, gives, words}, the stage's own when it has them, else the task's.
static func glossary(task: Dictionary, index: int) -> Dictionary:
	var at := stage(task, index)
	return {
		"params": at.get("params", task.get("params", [])),
		"gives": at.get("gives", task.get("gives", {})),
		"words": at.get("words", task.get("words", {})),
	}


## The stage's hints, a step closer each.
static func hints(task: Dictionary, index: int) -> Array[String]:
	var out: Array[String] = []
	for hint: Variant in stage(task, index).get("hints", []):
		out.append(String(hint))
	return out


## Whether stage `index` may be opened: its `unlocked_by` (a quests condition) holds, or it has none.
static func unlocked(task: Dictionary, index: int, flags: Dictionary) -> bool:
	if index < 0 or index >= stage_count(task):
		return false
	var condition: Variant = stage(task, index).get("unlocked_by", {})
	return Quests.holds(condition if condition is Dictionary else {}, flags)


## The stage the editor opens on: the first stage not passed yet when it is unlocked, else the last one passed (to
## practise), else 0. `record` is the task's record in the state (Parts.record).
static func open_stage(task: Dictionary, record: Dictionary, flags: Dictionary) -> int:
	var passed := int(record.get("passed", 0))
	if passed < stage_count(task) and unlocked(task, passed, flags):
		return passed
	return maxi(mini(passed, stage_count(task)) - 1, 0)


# --- a check -------------------------------------------------------------------------------------------------------


## The harness's calls for checking stage `index`: every case of stages 0 to index, in order, each with its stage's
## function and `mutates`.
static func check_calls(task: Dictionary, index: int, language: String) -> Array:
	var calls: Array = []
	for s in mini(index + 1, stage_count(task)):
		var mutates := int(stage(task, s).get("mutates", -1))
		var names := entries(task, s, language)
		var shape := signature(task, s, language)
		var after := bool(stage(task, s).get("args_after", false))
		for case_data: Variant in stage(task, s).get("cases", []):
			var args: Variant = (case_data as Dictionary).get("args", []) if case_data is Dictionary else []
			var call := {"entries": names, "signature": shape, "args": args, "mutates": mutates}
			if after:
				call.args_after = true
			calls.append(call)
	return calls


## The cases of check_calls, in the same order, each with the `stage` it belongs to.
static func check_cases(task: Dictionary, index: int) -> Array:
	var out: Array = []
	for s in mini(index + 1, stage_count(task)):
		for case_data: Variant in stage(task, s).get("cases", []):
			var one: Dictionary = (case_data as Dictionary).duplicate(true) if case_data is Dictionary else {}
			one.stage = s
			out.append(one)
	return out


## A run of check_calls judged: {ok, problem, cases, stage_ok}. `problem` is {} or the run's own trouble ({reason:
## "broken" | "timeout" | "failed", kind, message, line}); otherwise every case has a verdict ({ok, reason, ...}),
## from its stage's judge, or "error" / "no-function" when the call itself failed.
static func check(task: Dictionary, index: int, run: Dictionary) -> Dictionary:
	var top := mini(index, stage_count(task) - 1)
	var status := String(run.get("status", FAILED))
	if status != "ok":
		var problem := {
			"reason": status if status in [BROKEN, TIMEOUT] else FAILED,
			"kind": String(run.get("kind", "")),
			"message": String(run.get("message", "")),
			"line": int(run.get("line", 0)),
		}
		return {"ok": false, "problem": problem, "cases": [], "stage_ok": []}
	var results: Array = run.get("results", [])
	var all_cases := check_cases(task, top)
	if results.size() != all_cases.size():
		var wrong := {"reason": FAILED, "kind": "", "message": "the program answered for the wrong number of cases", "line": 0}
		return {"ok": false, "problem": wrong, "cases": [], "stage_ok": []}
	var verdicts: Array[Dictionary] = []
	var stage_ok: Array[bool] = []
	var at := 0
	for s in top + 1:
		var cases: Array = stage(task, s).get("cases", [])
		var mine := results.slice(at, at + cases.size())
		var judged := TaskJudges.judge(String(stage(task, s).get("judge", EQUALS)), cases, mine)
		var all_ok := true
		for i in cases.size():
			var result: Dictionary = mine[i] if mine[i] is Dictionary else {}
			var verdict: Dictionary
			if not bool(result.get("ok", false)):
				verdict = _failed_call(result)
			elif i < judged.size():
				verdict = judged[i]
			else:
				verdict = {"ok": false, "reason": "not-judged"}
			verdict.stage = s
			all_ok = all_ok and bool(verdict.get("ok", false))
			verdicts.append(verdict)
		stage_ok.append(all_ok)
		at += cases.size()
	return {"ok": not stage_ok.has(false), "problem": {}, "cases": verdicts, "stage_ok": stage_ok}


static func _failed_call(result: Dictionary) -> Dictionary:
	var kind := String(result.get("kind", "Error"))
	return {
		"ok": false,
		# A call whose function is not there yet is "no-function" (a judge's own "missing" means something else).
		"reason": NO_FUNCTION if kind == "missing" else "error",
		"kind": kind,
		"message": String(result.get("message", "")),
		"line": int(result.get("line", 0)),
	}


## What to say about a check: {reason, case, text}. The reason is the run's problem's, else "edge" when the only
## cases that failed are edge cases, else the first failing case's. `case` is that case's content merged with its
## verdict ({} for a problem). `text` is the task's own advice for the reason with its {placeholders} filled, or ""
## when the task has none (the editor then says the game's own words, TaskWords). "passed" when everything worked.
static func advice(task: Dictionary, index: int, checked: Dictionary, language := PYTHON) -> Dictionary:
	if bool(checked.get("ok", false)):
		return {"reason": "passed", "case": {}, "text": ""}
	var problem: Dictionary = checked.get("problem", {})
	if not problem.is_empty():
		var reason := String(problem.get("reason", FAILED))
		return {"reason": reason, "case": problem, "text": _filled(task, reason, problem, language), "template": template_of(task, reason)}
	var cases := check_cases(task, index)
	var verdicts: Array = checked.get("cases", [])
	var failing: Array[int] = []
	for i in verdicts.size():
		if not bool((verdicts[i] as Dictionary).get("ok", false)):
			failing.append(i)
	if failing.is_empty():
		return {"reason": FAILED, "case": {}, "text": ""}
	var first := failing[0]
	var merged: Dictionary = (cases[first] as Dictionary).duplicate(true) if first < cases.size() else {}
	merged.merge(verdicts[first] as Dictionary, true)
	var all_edges := failing.all(func(i: int) -> bool: return i < cases.size() and bool((cases[i] as Dictionary).get("edge", false)))
	var verdict_reason := String(merged.get("reason", FAILED))
	var reason := "edge" if all_edges and not verdict_reason in ["error", NO_FUNCTION] else verdict_reason
	var text := _filled(task, reason, merged, language)
	var template := template_of(task, reason)
	if text == "" and reason == "edge":
		text = _filled(task, verdict_reason, merged, language)
		template = template_of(task, verdict_reason)
	return {"reason": reason, "case": merged, "text": text, "template": template}


## The task's own advice for `reason`, its placeholders still in it ("" when it has none): a screen translates it before
## it fills it (a translation keyed by the filled words could never match).
static func template_of(task: Dictionary, reason: String) -> String:
	var said: Variant = (task.get("advice", {}) as Dictionary).get(reason, "") if task.get("advice", {}) is Dictionary else ""
	return String(said)


## The task's advice for `reason` with its placeholders filled from `details`; "" when it has none.
static func _filled(task: Dictionary, reason: String, details: Dictionary, language: String) -> String:
	var said: Variant = (task.get("advice", {}) as Dictionary).get(reason, "") if task.get("advice", {}) is Dictionary else ""
	return fill(String(said), details, language)


## `{say}`, `{got}`, `{want}`, `{line}`, `{kind}`, `{message}`, `{index}`, `{name}`, `{arg0}`… in `text`, from a case's
## content and verdict. Values are shown as code shows them in `language`.
static func fill(text: String, details: Dictionary, language := PYTHON) -> String:
	if text == "" or not "{" in text:
		return text
	var out := text
	for key: String in ["say", "kind", "message", "name"]:
		out = out.replace("{%s}" % key, String(details.get(key, "")))
	for key: String in ["line", "index"]:
		out = out.replace("{%s}" % key, str(int(details.get(key, 0))))
	for key: String in ["got", "want"]:
		if details.has(key):
			out = out.replace("{%s}" % key, shown(details[key], language))
	var args: Array = details.get("args", []) if details.get("args", []) is Array else []
	for i in args.size():
		out = out.replace("{arg%d}" % i, shown(args[i], language))
	return out


# --- comparing answers ---------------------------------------------------------------------------------------------


## Two answers are the same: numbers within TOLERANCE (JSON makes every number a float), lists item by item in order,
## dictionaries key by key, anything else by type and value.
static func same(a: Variant, b: Variant) -> bool:
	if is_number(a) and is_number(b):
		return absf(float(a) - float(b)) <= TOLERANCE
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in (a as Array).size():
			if not same(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for key: Variant in a:
			if not (b as Dictionary).has(key) or not same(a[key], b[key]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


static func is_number(value: Variant) -> bool:
	return (value is int or value is float) and not value is bool


## A whole number, however it came (JSON gives 50.0 for 50).
static func is_whole(value: Variant) -> bool:
	return is_number(value) and is_equal_approx(float(value), roundf(float(value))) and absf(float(value)) < 1e15


## The kind of a value in words the player knows: "number", "text", "list", "dictionary", "true or false", "nothing".
static func kind_of(value: Variant) -> String:
	if value == null:
		return "nothing"
	if value is bool:
		return "true or false"
	if is_number(value):
		return "number"
	if value is String:
		return "text"
	if value is Array:
		return "list"
	if value is Dictionary:
		return "dictionary"
	return "something else"


## A value as the player's language writes it: None / null, True / true, whole numbers without ".0", text in quotes.
static func shown(value: Variant, language := PYTHON) -> String:
	var python := language != JAVASCRIPT
	if value == null:
		return "None" if python else "null"
	if value is bool:
		if python:
			return "True" if value else "False"
		return "true" if value else "false"
	if is_whole(value):
		return str(int(float(value)))
	if is_number(value):
		return str(float(value))
	if value is String:
		return '"%s"' % value
	if value is Array:
		var parts := PackedStringArray()
		for item: Variant in value:
			parts.append(shown(item, language))
		return "[%s]" % ", ".join(parts)
	if value is Dictionary:
		var parts := PackedStringArray()
		for key: Variant in value:
			var name := '"%s"' % key if python else String(key)
			parts.append("%s: %s" % [name, shown(value[key], language)])
		return "{%s}" % ", ".join(parts)
	return str(value)


# --- Builder blocks ------------------------------------------------------------------------------------------------


## The blocks of a fresh record: the task's `start`, every slot it does not name on its first choice.
static func fresh_blocks(task: Dictionary) -> Dictionary:
	var blocks: Dictionary = task.get("blocks", {}) if task.get("blocks", {}) is Dictionary else {}
	var start: Dictionary = blocks.get("start", {}) if blocks.get("start", {}) is Dictionary else {}
	var slots := {}
	for id: String in blocks.get("slots", {}):
		slots[id] = int((start.get("slots", {}) as Dictionary).get(id, 0))
	var toggles: Array[String] = []
	for id: Variant in start.get("toggles", []):
		toggles.append(String(id))
	return {"slots": slots, "toggles": toggles}


## The code `blocks` ({slots: {id: index}, toggles: [ids on]}) make in `language`: the task's lines, a `[toggle]` line
## only while its toggle is on, every `{slot}` replaced by its chosen choice's code.
static func source(task: Dictionary, blocks: Dictionary, language: String) -> String:
	var design: Dictionary = task.get("blocks", {}) if task.get("blocks", {}) is Dictionary else {}
	var lines: Array = (design.get("lines", {}) as Dictionary).get(language, [])
	var slots: Dictionary = design.get("slots", {})
	var chosen: Dictionary = blocks.get("slots", {}) if blocks.get("slots", {}) is Dictionary else {}
	var on: Array = blocks.get("toggles", []) if blocks.get("toggles", []) is Array else []
	var out := PackedStringArray()
	for raw: Variant in lines:
		var line := String(raw)
		var toggle := line_toggle(line)
		if toggle != "":
			if not toggle in on:
				continue
			line = line.substr(toggle.length() + 2)
		for id: String in slots:
			var key := "{%s}" % id
			if key in line:
				line = line.replace(key, choice_code(slots[id], int(chosen.get(id, 0)), language))
		out.append(line)
	return "\n".join(out) + "\n"


## The toggle a block line belongs to ("[low]    return 0" belongs to "low"), or "".
static func line_toggle(line: String) -> String:
	if not line.begins_with("["):
		return ""
	var close := line.find("]")
	return line.substr(1, close - 1) if close > 1 else ""


## The code of a slot's choice in `language`: a plain string is the same in both, a {label, python, javascript} has its
## own. An index out of range takes the first choice.
static func choice_code(slot: Variant, index: int, language: String) -> String:
	var choices: Array = (slot as Dictionary).get("choices", []) if slot is Dictionary else []
	if choices.is_empty():
		return ""
	var choice: Variant = choices[index] if index >= 0 and index < choices.size() else choices[0]
	if choice is Dictionary:
		return String((choice as Dictionary).get(language, (choice as Dictionary).get(PYTHON, "")))
	return String(choice)


## What a slot's choice shows on its chip: its label, else its code in `language`.
static func choice_label(slot: Variant, index: int, language: String) -> String:
	var choices: Array = (slot as Dictionary).get("choices", []) if slot is Dictionary else []
	if choices.is_empty():
		return ""
	var choice: Variant = choices[index] if index >= 0 and index < choices.size() else choices[0]
	if choice is Dictionary and (choice as Dictionary).has("label"):
		return String((choice as Dictionary).label)
	return choice_code(slot, index, language)


## Whether a slot or toggle shows at stage `index` (its `stage` is the first that shows it, 0 by default).
static func shows_at(design_part: Variant, index: int) -> bool:
	return int((design_part as Dictionary).get("stage", 0)) <= index if design_part is Dictionary else true


# --- content checks ------------------------------------------------------------------------------------------------


## What is wrong with a task's data beyond its schema: cases without an argument list, a judge nobody wrote, block
## lines missing for a language, a `[toggle]` or `{slot}` the blocks do not declare, a start choice out of range.
static func problems(task: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var id := String(task.get("id", "?"))
	for s in stage_count(task):
		var at := stage(task, s)
		var judge_name := String(at.get("judge", EQUALS))
		if not judge_name in TaskJudges.NAMES:
			found.append('%s stage %d: there is no judge "%s"' % [id, s + 1, judge_name])
		for language in LANGUAGES:
			if entry(task, s, language) == "":
				found.append("%s stage %d: no %s function to call" % [id, s + 1, language])
		var cases: Array = at.get("cases", [])
		for i in cases.size():
			if not cases[i] is Dictionary or not (cases[i] as Dictionary).get("args") is Array:
				found.append("%s stage %d case %d: a case needs its args, a list" % [id, s + 1, i + 1])
	var design: Variant = task.get("blocks")
	if design == null:
		return found
	if not design is Dictionary:
		found.append("%s: blocks must be an object" % id)
		return found
	var slots: Dictionary = (design as Dictionary).get("slots", {}) if (design as Dictionary).get("slots", {}) is Dictionary else {}
	var toggles: Dictionary = (design as Dictionary).get("toggles", {}) if (design as Dictionary).get("toggles", {}) is Dictionary else {}
	var lines: Dictionary = (design as Dictionary).get("lines", {}) if (design as Dictionary).get("lines", {}) is Dictionary else {}
	var slot_name := RegEx.create_from_string("\\{([a-z_][a-z0-9_]*)\\}")
	for language in LANGUAGES:
		if not lines.get(language) is Array or (lines[language] as Array).is_empty():
			found.append("%s: blocks have no %s lines" % [id, language])
			continue
		for raw: Variant in lines[language]:
			var line := String(raw)
			var toggle := line_toggle(line)
			if toggle != "" and not toggles.has(toggle):
				found.append('%s: a %s block line names toggle "%s", which the blocks do not declare' % [id, language, toggle])
			for hit in slot_name.search_all(line):
				var name := hit.get_string(1)
				# A word in braces that is no slot is code (a JavaScript object), unless it looks meant as one.
				if not slots.has(name) and name.length() > 1 and line.count("{%s}" % name) > 0 and _looks_like_slot(name, slots):
					found.append('%s: a %s block line uses slot "%s", which the blocks do not declare' % [id, language, name])
	for name: String in slots:
		var choices: Variant = (slots[name] as Dictionary).get("choices", []) if slots[name] is Dictionary else []
		if not choices is Array or (choices as Array).size() < 2:
			found.append('%s: slot "%s" needs two choices or more' % [id, name])
	var start: Dictionary = (design as Dictionary).get("start", {}) if (design as Dictionary).get("start", {}) is Dictionary else {}
	for name: Variant in start.get("slots", {}):
		var choices: Array = (slots.get(name, {}) as Dictionary).get("choices", []) if slots.get(name, {}) is Dictionary else []
		var index := int((start.slots as Dictionary)[name])
		if index < 0 or index >= choices.size():
			found.append('%s: the start choice of slot "%s" is out of range' % [id, name])
	for name: Variant in start.get("toggles", []):
		if not toggles.has(String(name)):
			found.append('%s: the start turns on toggle "%s", which the blocks do not declare' % [id, name])
	return found


## A braced word that no slot declares is taken for a typo of a slot only when a slot's name is close to it.
static func _looks_like_slot(name: String, slots: Dictionary) -> bool:
	for slot: String in slots:
		if slot.similarity(name) > 0.7:
			return true
	return false
