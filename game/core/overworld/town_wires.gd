class_name TownWires
extends RefCounted
## Links between things in Lanternroot's town (Concept/v0.3/10, S8: "a plate's weight opens a door"). A thing is a prop
## with an `id` and a `program`, as TownThings has them. Its program names its hook (when its code runs) and may list
## `links`, the ids of the things it is wired to. Pure: no nodes, no I/O, no randomness. The caller runs the code
## (ThingRun) and applies what it changes; this only says which things are reached and what they are told.
##
##   on_use     runs when the player presses Space at the thing (TownThings)
##   on_step    runs when the player steps onto one of its cells (a plate, which must not be solid)
##   on_change  runs when a thing that links to it changed some of its fields; its code sees thing.source
##
##   {"kind": "prop", "id": "plate-1", "solid": false, "at": [2, 3], "size": [2, 1],
##    "program": {"hook": "on_step", "fields": {}, "raises": [], "links": ["door-1"]}}
##   {"kind": "prop", "id": "door-1", "solid": true, "at": [4, 3], "size": [1, 2],
##    "program": {"hook": "on_change", "fields": {"open": {"type": "bool", "default": false}}, "raises": []}}
##
##   var plates := TownWires.step_targets(map.objects, cell)            # the plates under the player
##   var doors := TownWires.change_targets(map.objects, "plate-1", visited)  # the things the plate links to
##   var input := TownWires.with_source(input, TownWires.source_of("door-1", fields, changes))

const HOOKS: Array[String] = ["on_use", "on_step", "on_change"]
## How many links one action may follow. The caller counts the links it follows; change_targets does not.
const MAX_CHAIN := 8


## The names the code may define for a hook: the snake_case name first, then the camelCase one (the JavaScript
## spelling). An unknown hook has none.
static func entries(hook: String) -> Array[String]:
	match hook:
		"on_use":
			return ["on_use", "onUse"]
		"on_step":
			return ["on_step", "onStep"]
		"on_change":
			return ["on_change", "onChange"]
	return []


## The hook a thing's program names ("on_use", "on_step" or "on_change"), or "" when it has no program.
static func hook_of(thing: Dictionary) -> String:
	return String(_program_of(thing).get("hook", ""))


## The ids the thing's program links to, in the content's order. Anything that is not a string is left out.
static func links_of(thing: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var links: Variant = _program_of(thing).get("links", [])
	if links is Array:
		for link: Variant in links:
			if link is String:
				out.append(String(link))
	return out


## The things whose hook is on_step and whose footprint (at up to at + size minus one) covers `cell`, in object order.
static func step_targets(objects: Array, cell: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for object: Variant in objects:
		if not object is Dictionary:
			continue
		var thing := object as Dictionary
		if hook_of(thing) == "on_step" and _covers(thing, cell):
			out.append(thing)
	return out


## The things that `from_id` links to, in its links' order, that answer on_change and whose id is not a key of `visited`
## (the ids already reached in this action; it is not changed here). A link to an id no thing on the map has is skipped,
## and a thing linked twice comes once. A `from_id` that is not on the map reaches nothing.
static func change_targets(objects: Array, from_id: String, visited: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_id := _index(objects)
	if not by_id.has(from_id):
		return out
	var seen := {}
	for link: String in links_of(by_id[from_id]):
		if seen.has(link) or visited.has(link) or not by_id.has(link):
			continue
		seen[link] = true
		var target: Dictionary = by_id[link]
		if hook_of(target) == "on_change":
			out.append(target)
	return out


## What an on_change thing's code is told about the thing that changed: its id, its fields after the change (the fields
## it had, with `changes` written over them) and the sorted names of what changed. Nothing passed in is changed.
static func source_of(from_id: String, fields: Dictionary, changes: Dictionary) -> Dictionary:
	var merged := fields.duplicate(true)
	var changed: Array[String] = []
	for name: Variant in changes:
		merged[name] = changes[name]
		changed.append(String(name))
	changed.sort()
	return {"id": from_id, "fields": merged, "changed": changed}


## A copy of a run's input (TownThings.use_input's shape: {thing, player}) with `source` written into its thing. The input
## passed in is not changed.
static func with_source(input: Dictionary, source: Dictionary) -> Dictionary:
	var out := input.duplicate(true)
	var thing: Dictionary = {}
	var given: Variant = out.get("thing")
	if given is Dictionary:
		thing = given
	thing["source"] = source.duplicate(true)
	out["thing"] = thing
	return out


## What is wrong with the links on a map's objects, one line each (empty when all is well): a hook that is not one of
## HOOKS, links that are not a list of thing ids, a link to an id no thing on the map has, a link to itself, a link to a
## thing that does not answer on_change, and an on_step thing that is solid (nobody could step onto it).
static func problems(objects: Array) -> Array[String]:
	var out: Array[String] = []
	var by_id := _index(objects)
	for index in objects.size():
		var object: Variant = objects[index]
		if not object is Dictionary:
			continue
		var thing := object as Dictionary
		if not thing.has("program"):
			continue
		var id := String(thing.get("id", ""))
		var label := id if id != "" else "object %d" % index
		var hook := hook_of(thing)
		if not (hook in HOOKS):
			out.append("%s has a hook %s that is not on_use, on_step or on_change" % [label, hook])
		var program := _program_of(thing)
		if program.has("links") and not _is_text_list(program["links"]):
			out.append("%s has links that are not a list of thing ids" % label)
		for other: String in links_of(thing):
			if other == id:
				out.append("%s links to itself" % label)
			elif not by_id.has(other):
				out.append("%s links to %s, which is not a thing on this map" % [label, other])
			elif hook_of(by_id[other]) != "on_change":
				out.append("%s links to %s, which does not answer on_change" % [label, other])
		if hook == "on_step" and bool(thing.get("solid", true)):
			out.append("%s answers on_step but is solid, so nobody can step onto it" % label)
	return out


## Whether a cell is inside a thing's footprint: from `at` up to `at` plus `size`, the far edge not included.
static func _covers(thing: Dictionary, cell: Vector2i) -> bool:
	var at := OverworldMap.cell_of(thing.get("at", [0, 0]))
	var size := OverworldMap.cell_of(thing.get("size", [1, 1]))
	return cell.x >= at.x and cell.x < at.x + size.x and cell.y >= at.y and cell.y < at.y + size.y


## The objects by id, the first thing with each id winning. Things without an id are left out.
static func _index(objects: Array) -> Dictionary:
	var out := {}
	for object: Variant in objects:
		if object is Dictionary:
			var id := String((object as Dictionary).get("id", ""))
			if id != "" and not out.has(id):
				out[id] = object
	return out


## Whether a value is an array of strings (an empty array is one).
static func _is_text_list(value: Variant) -> bool:
	if not value is Array:
		return false
	for item: Variant in value:
		if not item is String:
			return false
	return true


static func _program_of(thing: Dictionary) -> Dictionary:
	var program: Variant = thing.get("program", {})
	if program is Dictionary:
		return program
	return {}
