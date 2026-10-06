class_name LanternRules
extends RefCounted
## Lanternroot's rules (ADR-0055), pure functions over a town: a plain Dictionary saved as JSON.
##
##   {version, language, day, files: {module: source}, solved: {letter: {day}}, lanterns: {lantern: "lit"|"dark"},
##    hints: {letter: shown}, runs: {letter: count}, read: [letter], yesterday: {module: source}, nights: [summary],
##    complete: bool}
##
## A letter asks for one function in one module. Answering it lights a lantern on that module's house. A change order
## (`replaces`) asks for a change to a function already written and shares its lantern; from then on its tests are
## the ones that stand for that function. Each night the Night Watch reruns every standing test against the whole
## town, so a change in one house that breaks another is caught the evening it happens: the broken lantern goes dark
## and a gremlin moves in until it is fixed. The next day comes when today's letters are answered and no lantern is
## dark. Functions return a new town; they never change the one they are given.

const VERSION := 1
const LANGUAGES: Array[String] = [LanternCode.PYTHON, LanternCode.JAVASCRIPT]
const NAME_PATTERN := "^[a-z][a-z0-9_]{0,23}$"
## Names a player's own module may not take: standard modules a file of theirs would hide from every other file.
const RESERVED: Array[String] = [
	"math",
	"random",
	"json",
	"string",
	"time",
	"os",
	"sys",
	"re",
	"copy",
	"collections",
	"itertools",
	"functools",
	"typing",
	"types",
	"abc",
	"io",
	"fs",
	"test",
	"statistics",
	"operator",
	"heapq",
	"bisect",
	"enum",
	"dataclasses"
]
const LIT := "lit"
const DARK := "dark"


static func new_town(language: String) -> Dictionary:
	return {
		"version": VERSION,
		"language": language,
		"day": 1,
		"files": {},
		"solved": {},
		"lanterns": {},
		"hints": {},
		"runs": {},
		"read": [],
		"yesterday": {},
		"nights": [],
		"complete": false,
	}


static func last_day(catalog: Dictionary) -> int:
	return (catalog.town.days as Array).size()


static func day_info(catalog: Dictionary, day: int) -> Dictionary:
	for info: Dictionary in catalog.town.days:
		if int(info.day) == day:
			return info
	return {"day": day, "title": "", "dawn": ""}


static func is_solved(town: Dictionary, id: String) -> bool:
	return (town.solved as Dictionary).has(id)


## The letters waiting today, in order: their day has come, what they require is answered, and they are not.
static func letters(catalog: Dictionary, town: Dictionary) -> Array[Dictionary]:
	var open: Array[Dictionary] = []
	for id: String in catalog.order:
		var request: Dictionary = catalog.requests[id]
		if int(request.day) > int(town.day) or is_solved(town, id):
			continue
		if (request.requires as Array).all(func(needed: String) -> bool: return is_solved(town, needed)):
			open.append(request)
	return open


## Today's letters and every earlier day's, all answered.
static func day_done(catalog: Dictionary, town: Dictionary) -> bool:
	for id: String in catalog.order:
		if int(catalog.requests[id].day) <= int(town.day) and not is_solved(town, id):
			return false
	return true


## The lantern a letter lights: its own id, or for a change order, the lantern of the letter it changes.
static func lantern_of(catalog: Dictionary, id: String) -> String:
	var request: Dictionary = catalog.requests[id]
	while request.has("replaces"):
		request = catalog.requests[request.replaces]
	return String(request.id)


## Opening a letter puts its starter into its module (once): the file is made if it is new, and the stub is added at the
## end if the function is not there yet. A change order adds nothing; the code to change is already in town.
static func open_letter(catalog: Dictionary, town: Dictionary, id: String) -> Dictionary:
	var out := town.duplicate(true)
	var request: Dictionary = catalog.requests[id]
	if not id in out.read:
		(out.read as Array).append(id)
	var language: String = out.language
	var starter: String = (request.starter as Dictionary).get(language, "")
	if starter == "" or request.has("replaces"):
		return out
	var files: Dictionary = out.files
	var source: String = files.get(request.module, "")
	if not LanternCode.defines(language, source, LanternCode.function_name(request, language)):
		files[request.module] = LanternCode.append(language, source, starter)
	return out


static func set_file(town: Dictionary, module: String, source: String) -> Dictionary:
	var out := town.duplicate(true)
	out.files[module] = source
	return out


## A new, empty module of the player's own: {ok, town} or {ok: false, error}.
static func add_module(town: Dictionary, name: String) -> Dictionary:
	if not RegEx.create_from_string(NAME_PATTERN).search(name):
		return {"ok": false, "error": "Use lowercase letters, digits and _ and start with a letter."}
	if name in RESERVED:
		return {"ok": false, "error": "That name belongs to a standard module; your file would hide it."}
	if (town.files as Dictionary).has(name):
		return {"ok": false, "error": "There is already a house with that name."}
	return {"ok": true, "town": set_file(town, name, "")}


## The module as the last Night Watch saw it, put back: {ok, town}, or ok false when that night it did not exist.
static func restore(town: Dictionary, module: String) -> Dictionary:
	var yesterday: Dictionary = town.yesterday
	if not yesterday.has(module):
		return {"ok": false, "town": town}
	return {"ok": true, "town": set_file(town, module, yesterday[module])}


## Shows the next rung of a letter's hint ladder (three at most) and returns how many are showing.
static func take_hint(town: Dictionary, id: String) -> Dictionary:
	var out := town.duplicate(true)
	out.hints[id] = mini(int(out.hints.get(id, 0)) + 1, 3)
	return out


## A letter's tests: its examples, which the letter shows, then the Night Watch's checks, which it does not.
static func letter_cases(catalog: Dictionary, id: String, language: String) -> Array[Dictionary]:
	var request: Dictionary = catalog.requests[id]
	var function := LanternCode.function_name(request, language)
	var cases: Array[Dictionary] = []
	var examples: Array = request.examples
	for i in examples.size():
		cases.append(_case(request, function, "%s#e%d" % [id, i + 1], "example", "", examples[i]))
	var checks: Array = request.checks
	for i in checks.size():
		cases.append(_case(request, function, "%s#c%d" % [id, i + 1], "check", checks[i].name, checks[i]))
	return cases


## Which letter's tests stand for each lantern: the latest answered letter that lights it.
static func standing(catalog: Dictionary, town: Dictionary) -> Dictionary:
	var stands := {}
	for id: String in catalog.order:
		if is_solved(town, id):
			stands[lantern_of(catalog, id)] = id
	return stands


## Every standing test in town: what the Night Watch runs.
static func night_cases(catalog: Dictionary, town: Dictionary) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var stands := standing(catalog, town)
	for lantern: String in stands:
		cases.append_array(letter_cases(catalog, stands[lantern], town.language))
	return cases


## The results of running a letter's tests at the workbench: {town, lit, relit}. All passing answers the letter and
## lights its lantern (or relights it, chasing out a gremlin).
static func record_run(catalog: Dictionary, town: Dictionary, id: String, results: Array) -> Dictionary:
	var out := town.duplicate(true)
	out.runs[id] = int(out.runs.get(id, 0)) + 1
	var passed := not results.is_empty() and results.all(func(r: Dictionary) -> bool: return r.status == "pass")
	if not passed:
		return {"town": out, "lit": false, "relit": false}
	var lantern := lantern_of(catalog, id)
	var relit: bool = out.lanterns.get(lantern, "") == DARK
	if not is_solved(out, id):
		out.solved[id] = {"day": out.day}
	if not relit or standing(catalog, out).get(lantern, "") == id:
		out.lanterns[lantern] = LIT
	else:
		relit = false
	return {"town": out, "lit": true, "relit": relit}


## The Night Watch's results: every standing lantern lit or dark, yesterday's files kept, and the day advanced when it
## can be. Returns {town, report: {night, passed, failed, dark, relit, new_day, complete}}.
static func night_watch(catalog: Dictionary, town: Dictionary, results: Array) -> Dictionary:
	var out := town.duplicate(true)
	var failing := {}
	var passed := 0
	for result: Dictionary in results:
		if result.status == "pass":
			passed += 1
		else:
			failing[lantern_of(catalog, String(result.id).get_slice("#", 0))] = true
	var dark: Array[String] = []
	var relit: Array[String] = []
	for lantern: String in standing(catalog, out):
		var was: String = out.lanterns.get(lantern, "")
		if failing.has(lantern):
			out.lanterns[lantern] = DARK
			dark.append(lantern)
		else:
			out.lanterns[lantern] = LIT
			if was == DARK:
				relit.append(lantern)
	out.yesterday = (out.files as Dictionary).duplicate()
	var night := (out.nights as Array).size() + 1
	var new_day := false
	if dark.is_empty() and day_done(catalog, out):
		if int(out.day) < last_day(catalog):
			out.day = int(out.day) + 1
			new_day = true
		else:
			out.complete = true
	var report := {
		"night": night,
		"day": int(town.day),
		"passed": passed,
		"failed": results.size() - passed,
		"dark": dark,
		"relit": relit,
		"new_day": new_day,
		"complete": bool(out.complete),
	}
	(out.nights as Array).append(report)
	return {"town": out, "report": report}


static func _case(
	request: Dictionary, function: String, id: String, kind: String, name: String, test: Dictionary
) -> Dictionary:
	return {
		"id": id,
		"letter": String(request.id),
		"kind": kind,
		"name": name,
		"module": String(request.module),
		"function": function,
		"args": test.args,
		"expect": test.expect,
	}
