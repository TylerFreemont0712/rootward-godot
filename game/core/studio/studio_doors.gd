class_name StudioDoors
extends RefCounted
## Doors and rooms for Lanternroot Studio (Concept/v0.3/10-lanternroot-studio.md, section 7.9), as plain functions. A
## building's door can lead into a new room of its own; these work out that room, the links that point at a map or a
## cell, and the commands that change them. Nothing here draws, reads a file or changes what it is given.
##
## Cells are Vector2i in the signatures, [x, y] in the data (OverworldMap.cell_of reads either).
##
##   var made := StudioDoors.make_interior(building, "lanternroot", taken, "Pell's cottage")
##   if made["ok"]:
##       # made.room is the new map's data, made.room_id its id, made.to the building's new door
##       var linked := StudioCommands.apply(doc, StudioDoors.link_command(sid, made["to"]))
##
## The room's way out is a warp back to the building's front, so stepping out lands you where you came in.

const ROOM_SIZE: Vector2i = Vector2i(11, 8)
const ROOM_LEGEND: Dictionary = {"W": "wall", "f": "floor", "v": "void"}
const ID_GLYPHS: String = "abcdefghijklmnopqrstuvwxyz0123456789"


## A new room's map data, keys in this order: id, name, interior, legend, ground, start, facing, objects. Two wall
## rows on top, floor down to the row above the last, and a bottom row of void with one floor cell in the middle, where
## the doormat and the way out stand; the way out leads to `back`. {} when the size is too small for walls, a floor row
## and the way out (under 3 x 4).
@warning_ignore("integer_division")
static func room_template(id: String, title: String, back: Dictionary, size := ROOM_SIZE) -> Dictionary:
	var width := size.x
	var height := size.y
	if width < 3 or height < 4:
		return {}
	var mid := width / 2
	var rows: Array[String] = []
	for y in height:
		if y < 2:
			rows.append("W".repeat(width))
		elif y < height - 1:
			rows.append("f".repeat(width))
		else:
			rows.append("v".repeat(mid) + "f" + "v".repeat(width - mid - 1))
	var objects: Array[Dictionary] = [
		{"kind": "prop", "art": "doormat", "at": [mid, height - 1], "solid": false, "draw_layer": "ground"},
		{"kind": "warp", "at": [mid, height - 1], "to": back.duplicate(true)},
	]
	return {
		"id": id,
		"name": title,
		"interior": true,
		"legend": ROOM_LEGEND.duplicate(),
		"ground": rows,
		"start": [mid, height - 2],
		"facing": "up",
		"objects": objects,
	}


## Where a door into `room` lands: its start cell, facing up into the room.
static func way_in(room: Dictionary) -> Dictionary:
	var start := OverworldMap.cell_of(room.get("start", [0, 0]))
	return {"map": String(room.get("id", "")), "at": [start.x, start.y], "facing": "up"}


## An id for a new map: `base` made safe (lower case, every run of other characters one "-", "room" when nothing is
## left), then "-2", "-3" and so on for the first one not in `taken`.
static func room_id(base: String, taken: Array[String]) -> String:
	var clean := _safe_id(base)
	if not taken.has(clean):
		return clean
	var number := 2
	while taken.has("%s-%d" % [clean, number]):
		number += 1
	return "%s-%d" % [clean, number]


## The cell of a building's door: its corner plus the door's offset.
static func door_cell(building: Dictionary) -> Vector2i:
	return OverworldMap.cell_of(building.get("at", [0, 0])) + OverworldMap.cell_of(building.get("door", [0, 0]))


## The cell outside a building's door, where you land when you come out.
static func front_of(building: Dictionary) -> Vector2i:
	return door_cell(building) + Vector2i(0, 1)


## A new room behind a building's door. {ok: true, room, room_id, to} where `to` is the way in (way_in), and the room's
## way out leads back to the front of the building in `outside_id`. Refused with {ok: false, error} when the object is
## not a building, when its door already leads somewhere, or when the room would be too small.
static func make_interior(
	building: Dictionary, outside_id: String, taken: Array[String], title: String, size := ROOM_SIZE
) -> Dictionary:
	if String(building.get("kind", "")) != "building":
		return {"ok": false, "error": "only a building has a door"}
	if building.has("to"):
		return {"ok": false, "error": "its door already leads to %s" % _map_of(building.get("to"))}
	var id := room_id(String(building.get("art", "")), taken)
	var front := front_of(building)
	var back := {"map": outside_id, "at": [front.x, front.y], "facing": "down"}
	var room := room_template(id, title, back, size)
	if room.is_empty():
		return {"ok": false, "error": "a room needs at least 3 x 4 cells"}
	return {"ok": true, "room": room, "room_id": id, "to": way_in(room)}


## The door's offset from a building's corner when its handle is dragged to `cell`: along the bottom row, clamped to the
## building's width.
static func door_along(building: Dictionary, cell: Vector2i) -> Vector2i:
	var at := OverworldMap.cell_of(building.get("at", [0, 0]))
	var footprint := OverworldMap.cell_of(building.get("size", [1, 1]))
	return Vector2i(clampi(cell.x - at.x, 0, maxi(footprint.x - 1, 0)), maxi(footprint.y - 1, 0))


## The indexes of data's objects whose "to" leads to `map_id` at exactly `cell`, in file order.
static func links_to(data: Dictionary, map_id: String, cell: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var objects: Variant = data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		return out
	var list: Array = objects
	for index in list.size():
		var object: Variant = list[index]
		if typeof(object) != TYPE_DICTIONARY:
			continue
		var to: Variant = (object as Dictionary).get("to")
		if typeof(to) != TYPE_DICTIONARY:
			continue
		var target: Dictionary = to
		if String(target.get("map", "")) == map_id and OverworldMap.cell_of(target.get("at", [0, 0])) == cell:
			out.append(index)
	return out


## The batch that makes every link in `data` to (map_id, from) lead to (map_id, to) instead: each one keeps its other
## keys (facing and so on) and changes only "at". {} when none links there, or from is to.
static func retarget(data: Dictionary, sids: Array[int], map_id: String, from: Vector2i, to: Vector2i) -> Dictionary:
	if from == to:
		return {}
	var objects: Array = data.get("objects", [])
	var commands: Array = []
	for index: int in links_to(data, map_id, from):
		if index >= sids.size():
			continue
		var object: Dictionary = objects[index]
		var moved: Dictionary = (object["to"] as Dictionary).duplicate(true)
		moved["at"] = [to.x, to.y]
		commands.append({"type": "set", "sid": sids[index], "key": "to", "value": moved})
	if commands.is_empty():
		return {}
	return {"type": "batch", "name": "Follow the door of %s" % map_id, "commands": commands}


## The command that makes an object's "to" lead to `target` ({map, at, facing}; at is a cell or [x, y]).
static func link_command(sid: int, target: Dictionary) -> Dictionary:
	var at := OverworldMap.cell_of(target.get("at", [0, 0]))
	var value := {"map": String(target.get("map", "")), "at": [at.x, at.y], "facing": String(target.get("facing", ""))}
	return {"type": "set", "sid": sid, "key": "to", "value": value}


## The command that takes an object's "to" away, so its door stays shut.
static func unlink_command(sid: int) -> Dictionary:
	return {"type": "set", "sid": sid, "key": "to", "value": null}


## Every place the person stands, maps in id order: [{map, index, at, facing}]. A person is an object of kind "person"
## with this id; a missing facing reads as "down", as a map's does.
static func standing(maps: Dictionary, person_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map_ids: Array[String] = []
	map_ids.assign(maps.keys())
	map_ids.sort()
	for map_id: String in map_ids:
		var data: Variant = maps[map_id]
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var objects: Variant = (data as Dictionary).get("objects", [])
		if typeof(objects) != TYPE_ARRAY:
			continue
		var list: Array = objects
		for index in list.size():
			var object: Variant = list[index]
			if typeof(object) != TYPE_DICTIONARY:
				continue
			var person: Dictionary = object
			if String(person.get("kind", "")) != "person" or String(person.get("id", "")) != person_id:
				continue
			out.append(
				{
					"map": map_id,
					"index": index,
					"at": OverworldMap.cell_of(person.get("at", [0, 0])),
					"facing": String(person.get("facing", "down")),
				}
			)
	return out


## What the quests say about a person, for the inspector: "Gives <quest title>" for each quest they give, then
## "<quest title>: <step text>" for each step whose done condition reads a flag their talk sets. Quests in their order;
## each line once. `talk` is their talk ({} when they have none).
static func mentions(person_id: String, quests: Dictionary, talk: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for reference: Dictionary in quest_references(person_id, quests, talk):
		_add_once(out, String(reference.label))
	return out


## Stable quest/step identities come from giver IDs and dialogue flags, never a match against displayed prose.
static func quest_references(person_id: String, quests: Dictionary, talk: Dictionary) -> Array[Dictionary]:
	# LEARN: keep quest IDs and step indexes beside labels; translated prose cannot safely identify an edit target.
	var said := _flags_said(talk)
	var out: Array[Dictionary] = []
	for id: String in Quests.ordered(quests):
		var quest: Dictionary = quests[id]
		var title := String(quest.get("title", id))
		if String(quest.get("giver", "")) == person_id:
			out.append({"id": id, "step": -1, "title": title, "role": "giver", "label": "Gives %s" % title})
		var steps: Array = quest.get("steps", [])
		for index: int in steps.size():
			var step: Variant = steps[index]
			if typeof(step) != TYPE_DICTIONARY:
				continue
			var done: Variant = (step as Dictionary).get("done", {})
			if typeof(done) == TYPE_DICTIONARY and _reads(done, said):
				out.append({"id": id, "step": index, "title": title, "role": "step",
					"text": String((step as Dictionary).get("text", "")),
					"label": "%s: %s" % [title, String((step as Dictionary).get("text", ""))]})
	return out


## The id from a title or a name: lower case, every run of characters outside a-z and 0-9 as one "-", no "-" at either
## end, and "room" when nothing is left.
static func _safe_id(text: String) -> String:
	var out := ""
	var lowered := text.to_lower()
	for index in lowered.length():
		var glyph := lowered.substr(index, 1)
		if ID_GLYPHS.contains(glyph):
			out += glyph
		elif not out.is_empty() and not out.ends_with("-"):
			out += "-"
	while out.ends_with("-"):
		out = out.substr(0, out.length() - 1)
	return out if not out.is_empty() else "room"


## The map a link leads to, read from a "to" that may be missing or not an object.
static func _map_of(to: Variant) -> String:
	if typeof(to) != TYPE_DICTIONARY:
		return ""
	return String((to as Dictionary).get("map", ""))


## Every flag the talk's nodes set, once each.
static func _flags_said(talk: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var nodes: Variant = talk.get("nodes", {})
	if typeof(nodes) != TYPE_DICTIONARY:
		return out
	for node_id: Variant in (nodes as Dictionary).keys():
		for flag: String in Talk.sets(talk, String(node_id)):
			if not out.has(flag):
				out.append(flag)
	return out


## Whether a done condition reads one of `flags`: a flag it names, one it negates, a prefix a count reads, or any part
## of an all. "not" may hold a flag name (as Talk reads it) or a condition.
static func _reads(condition: Dictionary, flags: Array[String]) -> bool:
	if condition.has("flag") and flags.has(String(condition.get("flag"))):
		return true
	if condition.has("not"):
		var negated: Variant = condition.get("not")
		if typeof(negated) == TYPE_STRING and flags.has(String(negated)):
			return true
		if typeof(negated) == TYPE_DICTIONARY and _reads(negated, flags):
			return true
	if condition.has("count"):
		var prefix := String(condition.get("count"))
		for flag: String in flags:
			if flag.begins_with(prefix):
				return true
	if typeof(condition.get("all")) == TYPE_ARRAY:
		for part: Variant in condition.get("all"):
			if typeof(part) == TYPE_DICTIONARY and _reads(part, flags):
				return true
	return false


static func _add_once(lines: Array[String], line: String) -> void:
	if not lines.has(line):
		lines.append(line)
