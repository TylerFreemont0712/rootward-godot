class_name TownThings
extends RefCounted
## Things in Lanternroot's town that take code (ADR-0061; Concept/v0.3/09, sections 3 and 4): a gate that opens when its
## code says so, a sign that answers in Hotaru's words. Pure: no nodes, no I/O. The sandbox runs the player's code
## (ThingRun); this decides what the answer may change.
##
## A thing is a prop of the map with an `id` and a `program`, in the content's shape (lanternroot.jsonc):
##
##   {"kind": "prop", "id": "root-gate", "solid_unless": "open", "at": [49, 12], "size": [2, 1],
##    "program": {"hook": "on_use", "fields": {"open": {"type": "bool", "default": false}}, "raises": []}}
##
## A program may say `unlocked_by`, a condition in the quests' language ({flag}, {not}, {all}, {count}): until it holds
## the thing is a plain prop (its code does not run, X does not open it, and it shows no prompt of its own).
## A field is "bool", "whole" (a whole number from "min" to "max", both included) or "text" (60 characters or fewer).
## `raises` names the flags the code may set. A hook may change its own fields, say its words (120 characters or fewer)
## and raise the flags it names. Nothing else: no position, no other thing, no other flag.
##
##   var fields := TownThings.fields_of(thing, saved_fields)        # declared fields, saved values over the defaults
##   var args := TownThings.use_input(thing, fields, player, keys, text)  # the request for ThingRun.run
##   var verdict := TownThings.judge_use(thing, run, standing_on)    # {ok, reason, changes, say, raised, dropped, line}
##   state = TownThings.with_changes(state, thing["id"], verdict["changes"])

const HOOK := "on_use"
## Every hook a program may answer (Studio S8): Space's on_use, a step's on_step, a link's on_change (TownWires).
const HOOKS: Array[String] = ["on_use", "on_step", "on_change"]
const BOOL := "bool"
const WHOLE := "whole"
const TEXT := "text"
const TYPES: Array[String] = [BOOL, WHOLE, TEXT]
## Text fields are short: a name, a label. What a hook says is cut to SAY_MAX.
const TEXT_MAX := 60
const SAY_MAX := 120
## The keys a hook's answer may carry. Any other key is dropped, and named in the verdict's `dropped`.
const ANSWER_KEYS: Array[String] = ["set", "say", "raises"]

## Why a use did not go through (judge_use's `reason`). A use that went through has "".
const BROKEN := "broken"
const TIMEOUT := "timeout"
const OOM := "oom"
const FAILED := "failed"
const ERROR := "error"
const NOT_DICT := "not-dict"
const OCCUPIED := "occupied"


## Whether a thing's code may run now: always, unless its program's `unlocked_by` condition does not hold over `flags`.
static func unlocked(thing: Dictionary, flags: Dictionary) -> bool:
	var program: Variant = thing.get("program")
	if not program is Dictionary or not (program as Dictionary).has("unlocked_by"):
		return true
	var condition: Variant = (program as Dictionary).unlocked_by
	return condition is Dictionary and Quests.holds(condition, flags)


## The fields a thing has now: each declared field's saved value if the save holds one that still fits the declaration,
## else its default. Saved names the thing no longer declares are left out.
static func fields_of(thing: Dictionary, saved: Dictionary) -> Dictionary:
	var out := {}
	var specs := specs_of(thing)
	for name: String in specs:
		var spec: Dictionary = specs[name]
		var value: Variant = _clean(spec, saved.get(name))
		if value == null:
			value = _clean(spec, spec.get("default"))
		if value == null:
			value = _zero(spec)
		if value != null:
			out[name] = value
	return out


## The field declarations of a thing's program, by name. Anything that is not a declaration (a dictionary) is left out.
static func specs_of(thing: Dictionary) -> Dictionary:
	var out := {}
	var declared: Variant = _program_of(thing).get("fields", {})
	if declared is Dictionary:
		for name: Variant in declared:
			var spec: Variant = (declared as Dictionary)[name]
			if spec is Dictionary:
				out[String(name)] = spec
	return out


## The flags the thing's program may set, in the content's order.
static func raises_of(thing: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raises: Variant = _program_of(thing).get("raises", [])
	if raises is Array:
		for flag: Variant in raises:
			if flag is String and flag != "":
				out.append(String(flag))
	return out


## The request ThingRun sends for one use: the thing's id and its declared fields, `keys` (the keys the player's
## boots know: thing.keys in the code), `text` (the prop's default words: thing.text), and where the player stands.
## Plain values only, and the code gets no other part of the state.
static func use_input(
	thing: Dictionary, fields: Dictionary, player: Dictionary, keys: Array[String], text: String
) -> Dictionary:
	var declared := {}
	for name: String in specs_of(thing):
		if fields.has(name):
			declared[name] = fields[name]
	var known: Array = []
	for key: String in keys:
		known.append(key)
	return {
		"thing": {"id": String(thing.get("id", "")), "fields": declared, "keys": known, "text": text},
		"player":
		{
			"x": int(player.get("x", 0)),
			"y": int(player.get("y", 0)),
			"map": String(player.get("map", "")),
			"facing": String(player.get("facing", "")),
			"name": String(player.get("name", "")),
		},
	}


## What one use changed, judged from the sandbox's run (ThingRun.run). Nothing is written here: the caller applies
## `changes` (with_changes) and `raised` (the flags).
##   ok       true when the code ran and its answer may be used (nothing given back counts, and changes nothing)
##   reason   "" when ok, else why: broken, timeout, oom, failed, error, not-dict, or occupied
##   changes  the declared fields the answer sets, each one of its declared type and bounds
##   say      the words, cut to SAY_MAX characters
##   raised   the flags the answer raises that the program lists
##   dropped  every name the answer tried that was refused: a key other than set, say and raises, a field the thing does
##            not declare or a value that does not fit it, a flag it may not raise
##   line     the line of the error, when the run raised one
## `standing_on` says the player stands on the thing: a change that would close a gate under them is refused (occupied).
static func judge_use(thing: Dictionary, run: Dictionary, standing_on: bool) -> Dictionary:
	var status := String(run.get("status", ""))
	if status != "ok":
		return _judged(false, _reason_of(status), int(run.get("line", 0)))
	if not bool(run.get("ok", false)):
		return _judged(false, ERROR, int(run.get("line", 0)))
	var value: Variant = run.get("value")
	if value == null:
		return _judged(true, "", 0)
	if not value is Dictionary:
		return _judged(false, NOT_DICT, 0)
	var answer := value as Dictionary
	var declared := specs_of(thing)
	var changes := {}
	var raised: Array[String] = []
	var dropped: Array[String] = []
	for key: Variant in answer:
		if not (String(key) in ANSWER_KEYS):
			dropped.append(String(key))
	if answer.has("set"):
		_take_sets(answer["set"], declared, changes, dropped)
	var say := ""
	if answer.has("say"):
		var words: Variant = answer["say"]
		if words is String:
			say = (words as String).left(SAY_MAX)
		else:
			dropped.append("say")
	if answer.has("raises"):
		_take_raises(answer["raises"], raises_of(thing), raised, dropped)
	var solid := String(thing.get("solid_unless", ""))
	if standing_on and solid != "" and changes.has(solid) and not bool(changes[solid]):
		return _judged(false, OCCUPIED, 0, {}, "", [], dropped)
	return _judged(true, "", 0, changes, say, raised, dropped)


## The state with `changes` written into one thing's saved fields. The state passed in is not changed, and no other
## thing is touched.
static func with_changes(state: Dictionary, thing_id: String, changes: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	var things := _things_of(out)
	var entry := _entry_copy(things, thing_id)
	var fields: Dictionary = _saved_fields(things, thing_id).duplicate(true)
	for name: Variant in changes:
		fields[name] = changes[name]
	entry["fields"] = fields
	things[thing_id] = entry
	out["things"] = things
	return out


## The cells that open things leave walkable: a thing with a solid_unless field, and that field is true now. The
## footprint of a closed thing is not in it, so it stays solid. Cell -> true.
static func open_cells(map: Dictionary, things: Dictionary) -> Dictionary:
	var out := {}
	for object: Variant in map.get("objects", []):
		if not object is Dictionary:
			continue
		var thing := object as Dictionary
		var solid := String(thing.get("solid_unless", ""))
		if solid == "" or not thing.has("program"):
			continue
		var fields := fields_of(thing, _saved_fields(things, String(thing.get("id", ""))))
		if not bool(fields.get(solid, false)):
			continue
		var at := OverworldMap.cell_of(thing.get("at", [0, 0]))
		var size := OverworldMap.cell_of(thing.get("size", [1, 1]))
		for y in size.y:
			for x in size.x:
				out[at + Vector2i(x, y)] = true
	return out


## OverworldMap.blocked, with the open things' cells let through (see open_cells). Walls, water and people still block.
static func blocked(map: Dictionary, cell: Vector2i, people: Dictionary = {}, open: Dictionary = {}) -> bool:
	if not open.has(cell):
		return OverworldMap.blocked(map, cell, people)
	var lifted := map.duplicate()
	var solid: Dictionary = (map.get("solid", {}) as Dictionary).duplicate()
	solid.erase(cell)
	lifted["solid"] = solid
	return OverworldMap.blocked(lifted, cell, people)


## What is wrong with the map's objects as content, one line each (empty when all is well): two things with one id, a
## thing that is not a prop, a program that does not name its hook, a field that is not a bool, whole or text, a field
## without a fitting default, a raises that is not a list of flag names, and a solid_unless that is not a bool field.
static func problems(objects: Array) -> Array[String]:
	var out: Array[String] = []
	var ids := {}
	for index in objects.size():
		var object: Variant = objects[index]
		if not object is Dictionary:
			out.append("object %d is not a dictionary" % index)
			continue
		var thing := object as Dictionary
		var id := String(thing.get("id", ""))
		var label := id if id != "" else "object %d" % index
		if not thing.has("program"):
			if String(thing.get("solid_unless", "")) != "":
				out.append("%s is solid unless something, but it has no program" % label)
			continue
		if id == "":
			out.append("%s has a program but no id" % label)
		elif ids.has(id):
			out.append("two things are called %s" % id)
		else:
			ids[id] = true
		var kind := String(thing.get("kind", ""))
		if kind != "prop":
			out.append("%s is a %s, but only a prop can run code" % [label, kind])
		out.append_array(_program_problems(thing, label))
	return out


static func _program_problems(thing: Dictionary, label: String) -> Array[String]:
	var out: Array[String] = []
	var program: Variant = thing.get("program")
	if not program is Dictionary:
		out.append("%s has a program that is not a dictionary" % label)
		return out
	var kept := program as Dictionary
	if not String(kept.get("hook", "")) in HOOKS:
		out.append("%s has a program that does not name its hook (%s)" % [label, ", ".join(HOOKS)])
	var declared: Variant = kept.get("fields", {})
	if declared is Dictionary:
		for name: Variant in declared:
			out.append_array(_field_problems(label, String(name), (declared as Dictionary)[name]))
	else:
		out.append("%s has fields that are not a dictionary" % label)
	var raises: Variant = kept.get("raises", [])
	if raises is Array:
		for flag: Variant in raises:
			if not (flag is String and flag != ""):
				out.append("%s raises something that is not a flag name" % label)
	else:
		out.append("%s raises is not a list of flag names" % label)
	if kept.has("unlocked_by") and not _condition(kept.unlocked_by):
		out.append("%s is unlocked by something that is not a condition ({flag}, {not}, {all} or {count})" % label)
	var solid := String(thing.get("solid_unless", ""))
	if solid != "":
		var specs := specs_of(thing)
		var is_bool := specs.has(solid) and String((specs[solid] as Dictionary).get("type", "")) == BOOL
		if not is_bool:
			out.append("%s is solid unless %s, which is not a bool field of its program" % [label, solid])
	return out


## Whether `value` is a condition the quests read: a dictionary with a flag, a not, an all of conditions, or a count.
static func _condition(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var condition := value as Dictionary
	if condition.has("all"):
		if not condition.all is Array:
			return false
		for part: Variant in condition.all:
			if not _condition(part):
				return false
		return true
	return condition.has("flag") or condition.has("not") or condition.has("count")


static func _field_problems(label: String, name: String, spec: Variant) -> Array[String]:
	var out: Array[String] = []
	if not spec is Dictionary:
		out.append("%s field %s is not a dictionary" % [label, name])
		return out
	var declared := spec as Dictionary
	var kind := String(declared.get("type", ""))
	if not (kind in TYPES):
		out.append("%s field %s has type %s; it must be bool, whole or text" % [label, name, kind])
		return out
	if kind == WHOLE and not (_is_number(declared.get("min")) and _is_number(declared.get("max"))):
		out.append("%s field %s needs a min and a max" % [label, name])
	elif kind == WHOLE and float(declared["min"]) > float(declared["max"]):
		out.append("%s field %s has min above max" % [label, name])
	if not declared.has("default"):
		out.append("%s field %s has no default" % [label, name])
	elif _clean(declared, declared["default"]) == null:
		out.append("%s field %s has a default that does not fit its type" % [label, name])
	return out


## Writes the answer's sets that the thing declares and the value fits. Every other name goes to `dropped`.
static func _take_sets(sets: Variant, declared: Dictionary, changes: Dictionary, dropped: Array[String]) -> void:
	if not sets is Dictionary:
		dropped.append("set")
		return
	for key: Variant in sets:
		var name := String(key)
		var clean: Variant = null
		if declared.has(name):
			var spec: Dictionary = declared[name]
			clean = _clean(spec, sets[key])
		if clean == null:
			dropped.append(name)
		else:
			changes[name] = clean


## Keeps the flags the program lists, once each (a flag asked for twice is one flag). Anything else goes to `dropped`.
static func _take_raises(
	asked: Variant, may_raise: Array[String], raised: Array[String], dropped: Array[String]
) -> void:
	if not asked is Array:
		dropped.append("raises")
		return
	for flag: Variant in asked:
		if not (flag is String and (flag as String) in may_raise):
			dropped.append(str(flag))
		elif not ((flag as String) in raised):
			raised.append(String(flag))


## The value as the field's declaration allows it: a bool, a whole number within the bounds, or text of 60 characters or
## fewer. Anything else gives null, which is never a field's value.
static func _clean(spec: Dictionary, value: Variant) -> Variant:
	var kind := String(spec.get("type", ""))
	if kind == BOOL:
		return value if typeof(value) == TYPE_BOOL else null
	if kind == WHOLE:
		return _whole(spec, value)
	if kind == TEXT and typeof(value) == TYPE_STRING and (value as String).length() <= TEXT_MAX:
		return value
	return null


## A whole number within the bounds. JSON may carry 2 as 2.0, so an integral float counts; a bool never does.
static func _whole(spec: Dictionary, value: Variant) -> Variant:
	if not _is_number(value):
		return null
	var number := float(value)
	if not is_finite(number) or number != floorf(number):
		return null
	if number < float(spec.get("min", 0)) or number > float(spec.get("max", 0)):
		return null
	return int(number)


## What a field holds when neither the save nor the content gives a fitting value. Only a content mistake gets here.
static func _zero(spec: Dictionary) -> Variant:
	var kind := String(spec.get("type", ""))
	if kind == BOOL:
		return false
	if kind == WHOLE:
		return int(spec.get("min", 0))
	if kind == TEXT:
		return ""
	return null


static func _reason_of(status: String) -> String:
	if status == "broken":
		return BROKEN
	if status == "timeout":
		return TIMEOUT
	if status == "oom":
		return OOM
	return FAILED


static func _judged(
	ok: bool,
	reason: String,
	line: int,
	changes: Dictionary = {},
	say: String = "",
	raised: Array = [],
	dropped: Array = []
) -> Dictionary:
	return {
		"ok": ok, "reason": reason, "changes": changes, "say": say, "raised": raised, "dropped": dropped, "line": line
	}


static func _program_of(thing: Dictionary) -> Dictionary:
	var program: Variant = thing.get("program", {})
	if program is Dictionary:
		return program
	return {}


static func _things_of(state: Dictionary) -> Dictionary:
	var things: Variant = state.get("things", {})
	if things is Dictionary:
		return things
	return {}


static func _entry_copy(things: Dictionary, thing_id: String) -> Dictionary:
	var entry: Variant = things.get(thing_id, {})
	if entry is Dictionary:
		return (entry as Dictionary).duplicate(true)
	return {}


static func _saved_fields(things: Dictionary, thing_id: String) -> Dictionary:
	var entry: Variant = things.get(thing_id, {})
	if entry is Dictionary:
		var fields: Variant = (entry as Dictionary).get("fields", {})
		if fields is Dictionary:
			return fields
	return {}


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
