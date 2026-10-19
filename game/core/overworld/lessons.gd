class_name Lessons
extends RefCounted
## Lanternroot's lessons after the boots (ADR-0061), as pure rules. Lesson 2, "Remember me" (`memory`): the player
## writes save(player), which gets the player and gives back what the town should remember. Lesson 3, "Light the lane"
## (`lamps`): the player writes light_all(lamps) (lightAll in JavaScript), which lights every lamp it is given.
##
##   Lessons.source(id, blocks, language)    # the code a Builder's blocks make
##   Lessons.starter(id, language)           # what a Scribe starts typing from
##   Lessons.cases(id, name)                 # what a check runs the program on
##   Lessons.check(id, cases, run)           # {ok, problem, cases: [{ok, reason, ...}]} over a LessonRun result
##   Lessons.advice(id, checked)             # what Hotaru points at: "passed", "forgot-map", "first-only", ...
##   Lessons.restore(state, maps, home)      # {state, note}: where Continue puts the player, from their own save
##
## Blocks: the memory lesson's are the fields its save keeps (["x", "y", "map"]); the lamps lesson's are three switches,
## {first, loop, inside}: light the first lamp, a loop over the lamps, and "light it" inside that loop.
## Every judgement is a reason code with its details; the screen puts it into words.

const MEMORY := "memory"
const LAMPS := "lamps"
const IDS: Array[String] = [MEMORY, LAMPS]
const PYTHON := "python"
const JAVASCRIPT := "javascript"
## The function each lesson calls, by language.
const ENTRY := {
	MEMORY: {PYTHON: "save", JAVASCRIPT: "save"},
	LAMPS: {PYTHON: "light_all", JAVASCRIPT: "lightAll"},
}
## What the player is, to their save: where they stand, which map, which way they face, their name.
const FIELDS: Array[String] = ["x", "y", "map", "facing", "name"]
## What a save must keep for the town to find the player again.
const NEEDED: Array[String] = ["x", "y", "map"]
const LAMP_BLOCKS: Array[String] = ["first", "loop", "inside"]
## Lamp names, for the lamps a check makes up (code data, like ids: never translated).
const LAMP_NAMES: Array[String] = ["Moss", "Willow", "Ember", "Pebble", "Thistle", "Clover", "Bramble", "Fern"]
## The lamps a check lights: an empty lane, one lamp, five lamps.
const LANE_SIZES: Array[int] = [0, 1, 5]

# --- code from blocks ---------------------------------------------------------------------------------------------


static func entry(id: String, language: String) -> String:
	return String((ENTRY.get(id, {}) as Dictionary).get(language, ""))


## The blocks a lesson starts with: nothing kept, nothing lit.
static func fresh_blocks(id: String) -> Variant:
	if id == LAMPS:
		return {"first": false, "loop": false, "inside": false}
	return []


static func source(id: String, blocks: Variant, language: String) -> String:
	if id == LAMPS:
		return lamps_source(blocks if blocks is Dictionary else {}, language)
	return save_source(blocks if blocks is Array else [], language)


## save(player) keeping `fields` (in FIELDS order; anything else is left out).
static func save_source(fields: Array, language: String) -> String:
	var kept: Array[String] = []
	for field in FIELDS:
		if field in fields:
			kept.append(field)
	if language == JAVASCRIPT:
		if kept.is_empty():
			return "function save(player) {\n  return {};\n}\n"
		var js: PackedStringArray = ["function save(player) {", "  return {"]
		for field in kept:
			js.append("    %s: player.%s," % [field, field])
		js.append_array(["  };", "}"])
		return "\n".join(js) + "\n"
	if kept.is_empty():
		return "def save(player):\n    return {}\n"
	var py: PackedStringArray = ["def save(player):", "    return {"]
	for field in kept:
		py.append('        "%s": player["%s"],' % [field, field])
	py.append("    }")
	return "\n".join(py) + "\n"


## light_all(lamps) from the three switches. "Light it" counts only inside the loop: on its own there is no lamp.
static func lamps_source(blocks: Dictionary, language: String) -> String:
	var first := bool(blocks.get("first", false))
	var loop := bool(blocks.get("loop", false))
	var inside := loop and bool(blocks.get("inside", false))
	if language == JAVASCRIPT:
		var js: PackedStringArray = ["function lightAll(lamps) {"]
		if first:
			js.append("  lamps[0].lit = true;")
		if loop:
			js.append("  for (const lamp of lamps) {")
			if inside:
				js.append("    lamp.lit = true;")
			js.append("  }")
		js.append("}")
		return "\n".join(js) + "\n"
	var py: PackedStringArray = ["def light_all(lamps):"]
	if first:
		py.append('    lamps[0]["lit"] = True')
	if loop:
		py.append("    for lamp in lamps:")
		py.append('        lamp["lit"] = True' if inside else "        pass")
	if not first and not loop:
		py.append("    pass")
	return "\n".join(py) + "\n"


## The text a Scribe starts from: the function, and comments saying what it gets. The part that does the work is theirs.
static func starter(id: String, language: String) -> String:
	if id == LAMPS:
		if language == JAVASCRIPT:
			return (
				"function lightAll(lamps) {\n"
				+ '  // lamps is an array. Each lamp is an object like {name: "Moss", lit: false}.\n'
				+ "  // Light every lamp on the lane.\n"
				+ "}\n"
			)
		return (
			"def light_all(lamps):\n"
			+ '    # lamps is a list. Each lamp is a dictionary like {"name": "Moss", "lit": False}.\n'
			+ "    # Light every lamp on the lane.\n"
			+ "    pass\n"
		)
	if language == JAVASCRIPT:
		return (
			"function save(player) {\n"
			+ "  // player.x and player.y are where you stand; player.map is which map.\n"
			+ "  // player.facing and player.name are there too.\n"
			+ "  // Give back an object of what the town should remember.\n"
			+ "  return {};\n"
			+ "}\n"
		)
	return (
		"def save(player):\n"
		+ '    # player["x"] and player["y"] are where you stand; player["map"] is which map.\n'
		+ '    # player["facing"] and player["name"] are there too.\n'
		+ "    # Give back a dictionary of what the town should remember.\n"
		+ "    return {}\n"
	)


## The code a Scribe typed, or their starter when they typed nothing.
static func typed_or_starter(id: String, typed: String, language: String) -> String:
	return typed if typed.strip_edges() != "" else starter(id, language)


# --- what a check runs on -----------------------------------------------------------------------------------------


static func cases(id: String, player_name := "Tinker") -> Array:
	return lanes() if id == LAMPS else players(player_name)


## The players a save is tried on: at home, in the square, at the edge of town.
static func players(player_name := "Tinker") -> Array:
	return [
		player_at("home", Vector2i(2, 3), "down", player_name),
		player_at("lanternroot", Vector2i(19, 16), "up", player_name),
		player_at("lanternroot", Vector2i(37, 2), "left", player_name),
	]


static func player_at(map_id: String, cell: Vector2i, facing: String, player_name: String) -> Dictionary:
	return {"x": cell.x, "y": cell.y, "map": map_id, "facing": facing, "name": player_name}


## The lanes light_all is tried on: none, one and five dark lamps.
static func lanes() -> Array:
	var out: Array = []
	for size in LANE_SIZES:
		out.append(lane(size))
	return out


static func lane(size: int, names: Array[String] = []) -> Array:
	var out: Array = []
	for i in size:
		var lamp_name := names[i] if i < names.size() else LAMP_NAMES[i % LAMP_NAMES.size()]
		out.append({"name": lamp_name, "lit": false})
	return out


## The props of a map's lane (group "lane"), in reading order: top row first, left to right. The order the lane
## lights in.
static func lane_lamps(map: Dictionary, group := "lane") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for object: Dictionary in map.get("objects", []):
		if String(object.get("group", "")) == group:
			found.append(object)
	found.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var at_a := OverworldMap.cell_of(a.get("at", [0, 0]))
			var at_b := OverworldMap.cell_of(b.get("at", [0, 0]))
			return at_a.x < at_b.x if at_a.y == at_b.y else at_a.y < at_b.y
	)
	return found


## The lane's lamps in the order they light when the lesson is done: nearest `cell` (where the player stands) first,
## so the light runs away from the player down the lane. Ties keep reading order.
static func lane_from(map: Dictionary, cell: Vector2i, group := "lane") -> Array[Dictionary]:
	var found := lane_lamps(map, group)
	var far: Array[int] = []
	for lamp in found:
		var at := OverworldMap.cell_of(lamp.get("at", [0, 0]))
		far.append(absi(at.x - cell.x) + absi(at.y - cell.y))
	var order: Array[int] = []
	order.assign(range(found.size()))
	order.sort_custom(func(a: int, b: int) -> bool: return far[a] < far[b] if far[a] != far[b] else a < b)
	var out: Array[Dictionary] = []
	for i in order:
		out.append(found[i])
	return out


## The lamps of a map's lane, in reading order: their names, or made-up ones.
static func lane_names(map: Dictionary, group := "lane") -> Array[String]:
	var found := lane_lamps(map, group)
	var names: Array[String] = []
	for i in found.size():
		var given := String(found[i].get("name", ""))
		names.append(given if given != "" else LAMP_NAMES[i % LAMP_NAMES.size()])
	return names


# --- checks -------------------------------------------------------------------------------------------------------


## A whole run judged: {ok, problem, cases}. `problem` is {} or a run that never reached the cases
## ({reason: "broken" | "timeout" | "failed", kind, message, line}); each case is judged on its own otherwise.
static func check(id: String, given: Array, run: Dictionary) -> Dictionary:
	var status := String(run.get("status", "failed"))
	if status != "ok":
		var problem := {
			"reason": status if status in ["broken", "timeout"] else "failed",
			"kind": String(run.get("kind", "")),
			"message": String(run.get("message", "")),
			"line": int(run.get("line", 0)),
		}
		return {"ok": false, "problem": problem, "cases": []}
	var results: Array = run.get("results", [])
	var judged: Array[Dictionary] = []
	var ok := results.size() == given.size()
	for i in given.size():
		var result: Dictionary = results[i] if i < results.size() and results[i] is Dictionary else {}
		var case_check := judge_lane(given[i], result) if id == LAMPS else judge_save(given[i], result)
		ok = ok and bool(case_check.ok)
		judged.append(case_check)
	return {"ok": ok, "problem": {}, "cases": judged}


## One player's save: kept x, y and map equal to the player's. Reasons: "kept", "error", "nothing" (no return value),
## "not-dict", "kept-nothing", "forgot" (field, missing: every needed field left out), "wrong" (field, want, got).
static func judge_save(player: Dictionary, result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _error_of(result)
	var kept: Variant = result.get("value")
	if kept == null:
		return {"ok": false, "reason": "nothing"}
	if not kept is Dictionary:
		return {"ok": false, "reason": "not-dict", "got": shown(kept)}
	var memory: Dictionary = kept
	if memory.is_empty():
		return {"ok": false, "reason": "kept-nothing"}
	var missing: Array[String] = []
	for field in NEEDED:
		if not memory.has(field):
			missing.append(field)
	if not missing.is_empty():
		return {"ok": false, "reason": "forgot", "field": missing[0], "missing": missing}
	for field in NEEDED:
		if not same(memory[field], player[field]):
			return {
				"ok": false,
				"reason": "wrong",
				"field": field,
				"want": shown(player[field]),
				"got": shown(memory[field])
			}
	return {"ok": true, "reason": "kept", "kept": kept_fields(memory)}


## One lane after light_all: every lamp lit, none added or lost. Reasons: "lit" (total), "error" (with `empty` when the
## lane had no lamps), "not-list", "count" (want, got), "changed" (index: a lamp that is not the one given),
## "not-true" (index, got: lit is something other than True), "dark" (dark, total, index of the first).
static func judge_lane(lamps_in: Array, result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		var error := _error_of(result)
		error.empty = lamps_in.is_empty()
		return error
	var after: Variant = result.get("value")
	if not after is Array:
		return {"ok": false, "reason": "not-list", "got": shown(after)}
	var lamps_out: Array = after
	if lamps_out.size() != lamps_in.size():
		return {"ok": false, "reason": "count", "want": lamps_in.size(), "got": lamps_out.size()}
	var dark := 0
	var first_dark := -1
	for i in lamps_out.size():
		var lamp: Variant = lamps_out[i]
		if not lamp is Dictionary or String((lamp as Dictionary).get("name", "")) != String(lamps_in[i].name):
			return {"ok": false, "reason": "changed", "index": i}
		var lit: Variant = (lamp as Dictionary).get("lit")
		if lit is bool and lit:
			continue
		if lit != null and not lit is bool and _truthy(lit):
			return {"ok": false, "reason": "not-true", "index": i, "got": shown(lit)}
		dark += 1
		if first_dark < 0:
			first_dark = i
	if dark > 0:
		return {"ok": false, "reason": "dark", "dark": dark, "total": lamps_out.size(), "index": first_dark}
	return {"ok": true, "reason": "lit", "total": lamps_out.size()}


## What Hotaru points at after a check, as a code the screen puts into words: "passed"; a run that never reached the
## cases: "missing" (no such function), "broken", "timeout", "failed"; else the most telling case. For a save:
## "forgot-map" (x and y kept, map not: two places have the same x and y), "forgot", "wrong", "no-return",
## "not-dict", "empty", "error". For a lane, a dark lamp says the most, so it comes first: "first-only" (only the first
## lamp lit), "all-dark", "some-dark"; then "empty-lane" (an error with no lamps: there is no first lamp), "lost",
## "changed", "not-true", "not-list", "error".
static func advice(id: String, checked: Dictionary) -> String:
	if bool(checked.get("ok", false)):
		return "passed"
	var problem: Dictionary = checked.get("problem", {})
	if not problem.is_empty():
		if String(problem.get("kind", "")) == "missing":
			return "missing"
		return String(problem.get("reason", "failed"))
	var judged: Array = checked.get("cases", [])
	if id == LAMPS:
		for case_check: Dictionary in judged:
			if String(case_check.get("reason", "")) == "dark":
				var dark := int(case_check.dark)
				var total := int(case_check.total)
				if dark == total:
					return "all-dark"
				return "first-only" if dark == total - 1 and int(case_check.index) == 1 else "some-dark"
	for case_check: Dictionary in judged:
		if bool(case_check.get("ok", false)):
			continue
		var reason := String(case_check.get("reason", "error"))
		match reason:
			"forgot":
				var missing: Array = case_check.get("missing", [])
				return "forgot-map" if missing == ["map"] else "forgot"
			"nothing":
				return "no-return"
			"kept-nothing":
				return "empty"
			"error":
				return "empty-lane" if bool(case_check.get("empty", false)) else "error"
			"count":
				return "lost"
		return reason
	return "failed"


static func _error_of(result: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"reason": "error",
		"kind": String(result.get("kind", "Error")),
		"message": String(result.get("message", "")),
		"line": int(result.get("line", 0)),
	}


static func _truthy(value: Variant) -> bool:
	if value is String:
		return value != ""
	if value is float or value is int:
		return value != 0
	if value is Array or value is Dictionary:
		return not value.is_empty()
	return value != null


## The fields a save kept, the player's in FIELDS order first, then anything else it kept.
static func kept_fields(memory: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for field in FIELDS:
		if memory.has(field):
			out.append(field)
	for key: Variant in memory:
		if not String(key) in out:
			out.append(String(key))
	return out


## Two values from a run are the same: numbers by value (JSON gives floats), anything else by type and value.
static func same(a: Variant, b: Variant) -> bool:
	var numbers := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numbers and typeof(b) in numbers:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


## A value as the player wrote it: whole numbers without ".0", text in quotes, nothing as null.
static func shown(value: Variant) -> String:
	if value == null:
		return "null"
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) < 1e15:
		return str(int(value))
	if value is String:
		return '"%s"' % value
	if value is bool:
		return "true" if value else "false"
	return JSON.stringify(value)


# --- restoring the player's place -----------------------------------------------------------------------------------


## Where Continue puts the player. Before lesson 2 the state is unchanged (the town keeps the place for them). After it,
## the place is what their own save kept (`state.memory`): its map, x, y and facing. A save that forgot something, or
## names a map the town does not know, or a cell off the map or inside something solid that is shut, wakes the
## player at `home`'s start, with a note saying why: "no-memory", "forgot-map", "unknown-map", "forgot-place",
## "outside", "blocked".
static func restore(state: Dictionary, maps: Dictionary, home: String) -> Dictionary:
	if not bool((state.get("flags", {}) as Dictionary).get("memory-written", false)):
		return {"state": state, "note": ""}
	var note := _place_problem(state.get("memory"), maps, state.get("things", {}))
	if note != "":
		var house: Dictionary = maps.get(home, {})
		var start := OverworldMap.cell_of(house.get("start", Vector2i.ZERO))
		return {"state": OverworldState.moved(state, home, start, String(house.get("facing", "down"))), "note": note}
	var memory: Dictionary = state.memory
	var facing := String(memory.get("facing", ""))
	if not facing in OverworldMap.FACINGS:
		facing = String(state.get("facing", "down"))
	var cell := Vector2i(int(memory.x), int(memory.y))
	return {"state": OverworldState.moved(state, String(memory.map), cell, facing), "note": ""}


static func _place_problem(memory: Variant, maps: Dictionary, things: Dictionary) -> String:
	if not memory is Dictionary or (memory as Dictionary).is_empty():
		return "no-memory"
	var kept: Dictionary = memory
	if not kept.has("map"):
		return "forgot-map"
	if not maps.has(String(kept.map)):
		return "unknown-map"
	if not (_whole(kept.get("x")) and _whole(kept.get("y"))):
		return "forgot-place"
	var map: Dictionary = maps[String(kept.map)]
	var cell := Vector2i(int(kept.x), int(kept.y))
	if not OverworldMap.inside(map, cell):
		return "outside"
	# A shut gate is solid; an open one is walkable, so a memory saved on it is a place the player can stand.
	var open := TownThings.open_cells(map, things)
	if OverworldMap.blocked(map, cell, people_of(map), open):
		return "blocked"
	return ""


static func _whole(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_equal_approx(value, roundf(value))


## The cells a map's townspeople stand on, for OverworldMap.blocked.
static func people_of(map: Dictionary) -> Dictionary:
	var cells := {}
	for person: Dictionary in map.get("people", []):
		cells[OverworldMap.cell_of(person.get("at", [0, 0]))] = String(person.get("id", ""))
	return cells


# --- the lesson's record in the state --------------------------------------------------------------------------------


## The lesson's record: {blocks, code: {language: typed}, language, source, passed}. Missing parts are filled in.
static func record(state: Dictionary, id: String) -> Dictionary:
	var lessons: Dictionary = state.get("lessons", {}) if state.get("lessons", {}) is Dictionary else {}
	var saved: Dictionary = lessons.get(id, {}) if lessons.get(id, {}) is Dictionary else {}
	var out := saved.duplicate(true)
	var blocks: Variant = out.get("blocks")
	if (id == LAMPS and not blocks is Dictionary) or (id != LAMPS and not blocks is Array):
		out.blocks = fresh_blocks(id)
	if not out.get("code") is Dictionary:
		out.code = {}
	out.passed = bool(out.get("passed", false))
	return out


## The state with the lesson's record replaced.
static func with_record(state: Dictionary, id: String, kept: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	var lessons: Dictionary = out.get("lessons", {}) if out.get("lessons", {}) is Dictionary else {}
	lessons[id] = kept.duplicate(true)
	out.lessons = lessons
	return out


## The state with flags set.
static func with_flags(state: Dictionary, names: Array[String]) -> Dictionary:
	var flags: Dictionary = (state.get("flags", {}) as Dictionary).duplicate()
	for flag in names:
		flags[flag] = true
	return OverworldState.flagged(state, flags)


## What the player's save is given: where they stand now.
static func player_of(state: Dictionary) -> Dictionary:
	var cell := OverworldState.cell(state)
	return player_at(
		String(state.get("map", "")), cell, String(state.get("facing", "down")), String(state.get("name", ""))
	)
