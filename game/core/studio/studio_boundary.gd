class_name StudioBoundary
extends RefCounted
## A connected boundary stroke, as copies of raw map objects. Collision and applying the edits belong to the caller.
## Connection bits are north 1, east 2, south 4 and west 8; even a wide or programmed gate can provide a neighbor.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## The catalog entry that owns this material's connection pictures, or "" for incomplete metadata.
static func group(template: Dictionary, entries: Dictionary) -> String:
	var raw_entry: Variant = entries.get(String(template.get("art", "")))
	if not raw_entry is Dictionary:
		return ""
	var join := String((raw_entry as Dictionary).get("join", ""))
	var raw_root: Variant = entries.get(join)
	if join.is_empty() or not raw_root is Dictionary:
		return ""
	var connections: Variant = (raw_root as Dictionary).get("connections")
	return join if connections is Dictionary and not (connections as Dictionary).is_empty() else ""


## Named/programmed things and larger footprints can connect to the stroke, but painting must never replace them.
static func supported(template: Dictionary, entries: Dictionary) -> bool:
	return (
		String(template.get("kind", "")) == "prop"
		and String(template.get("id", "")).is_empty()
		and not template.has("program")
		and OverworldMap.cell_of(template.get("size", [1, 1])) == Vector2i.ONE
		and not group(template, entries).is_empty()
	)


## Gates share the material's join group without appearing among its sixteen fence connection pictures.
static func is_fence(template: Dictionary, entries: Dictionary) -> bool:
	var join := group(template, entries)
	if join.is_empty():
		return false
	var root: Dictionary = entries[join]
	var connections: Dictionary = root.connections
	return connections.values().has(String(template.get("art", "")))


## A gate can replace a matching straight segment or stand alone, but it cannot swallow a corner or a junction.
## `cell` is the candidate footprint's top-left cell, as in raw map objects. Fit/protection checks remain separate.
static func gate_fits(template: Dictionary, cell: Vector2i, objects: Array, entries: Dictionary) -> bool:
	var join := group(template, entries)
	if join.is_empty() or is_fence(template, entries):
		return true
	var sockets := _sockets(template, entries)
	if sockets == 15:
		return true
	var size := OverworldMap.cell_of(template.get("size", [1, 1]))
	var footprint := Rect2i(cell, size)
	var occupied: Dictionary = {}
	for index: int in objects.size():
		if not objects[index] is Dictionary:
			continue
		var object: Dictionary = objects[index]
		var at := OverworldMap.cell_of(object.get("at", [0, 0]))
		var other_size := OverworldMap.cell_of(object.get("size", [1, 1]))
		if Rect2i(at, other_size).has_point(cell):
			# The piece being replaced is not an adjacent neighbor, including another cell of the same wide gate.
			continue
		_index(occupied, object, index, join, entries)
	for y: int in size.y:
		for x: int in size.x:
			var at := cell + Vector2i(x, y)
			for bit: int in DIRECTIONS.size():
				if (sockets & (1 << bit)) != 0:
					continue
				var neighbor := at + DIRECTIONS[bit]
				if not footprint.has_point(neighbor) and occupied.has(neighbor):
					return false
	return true


## Proposes a stroke and the affected neighbors. Fit candidates first, then plan again with accepted cells before
## applying: a rejected new cell must not leave its neighbors joined toward a picture that was never placed.
## Each record is {index, object}; index -1 adds an object, otherwise it replaces the original object at that index.
static func plan(
	template: Dictionary, cells: Array[Vector2i], objects: Array, entries: Dictionary
) -> Dictionary:
	var edits: Array[Dictionary] = []
	var candidates: Array[Dictionary] = []
	var ignore: Array[int] = []
	var result := {"edits": edits, "candidates": candidates, "ignore": ignore}
	if not supported(template, entries) or cells.is_empty():
		return result
	var join := group(template, entries)
	var original: Array[Dictionary] = []
	var work: Array[Dictionary] = []
	var occupied: Dictionary = {}
	for index: int in objects.size():
		var object := _raw(objects[index]) if objects[index] is Dictionary else {}
		original.append(object)
		work.append(object.duplicate(true))
		_index(occupied, object, index, join, entries)
	var requested: Array[int] = []
	var seen: Dictionary = {}
	var affected: Dictionary = {}
	var fence := is_fence(template, entries)
	for cell: Vector2i in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		affected[cell] = true
		for direction: Vector2i in DIRECTIONS:
			affected[cell + direction] = true
		var index := _eligible_at(cell, occupied, work, entries)
		if index >= 0:
			if not ignore.has(index):
				ignore.append(index)
			# LEARN: joining a fence is idempotent; existing instance fields survive, and gates stay as openings.
			# A deliberately painted gate takes the template's collision while keeping the old instance's other data.
			if not fence:
				var replacement: Dictionary = work[index]
				replacement["art"] = String(template.art)
				if template.has("solid"):
					replacement["solid"] = template.solid
				else:
					replacement.erase("solid")
		else:
			var made := _raw(template)
			made["at"] = [cell.x, cell.y]
			index = work.size()
			work.append(made)
			_index(occupied, made, index, join, entries)
		requested.append(index)
	var root: Dictionary = entries[join]
	var connections: Dictionary = root.connections
	var visited: Dictionary = {}
	for raw_cell: Variant in affected:
		var cell: Vector2i = raw_cell
		var indexes: Array = occupied.get(cell, [])
		for index: int in indexes:
			if visited.has(index):
				continue
			visited[index] = true
			var object: Dictionary = work[index]
			if not supported(object, entries) or not is_fence(object, entries):
				continue
			var at := OverworldMap.cell_of(object.get("at", [0, 0]))
			var mask := 0
			for bit: int in DIRECTIONS.size():
				var neighbor := at + DIRECTIONS[bit]
				if _connected_neighbor(neighbor, (bit + 2) % DIRECTIONS.size(), occupied, work, entries):
					mask |= 1 << bit
			var art := String(connections.get(str(mask), object.art))
			object["art"] = art
			# The connection mask already owns orientation; mirroring a corner would disconnect its rail sockets.
			object.erase("flip")
	for index: int in work.size():
		if index >= original.size() or work[index] != original[index]:
			edits.append(_record(index, original.size(), work[index]))
	for index: int in requested:
		candidates.append(_record(index, original.size(), work[index]))
	return result


## A wide gate's socket is on the outside edge of its footprint, never on one of its internal cell boundaries.
static func _has_socket(object: Dictionary, cell: Vector2i, bit: int, entries: Dictionary) -> bool:
	if (_sockets(object, entries) & (1 << bit)) == 0:
		return false
	var at := OverworldMap.cell_of(object.get("at", [0, 0]))
	var size := OverworldMap.cell_of(object.get("size", [1, 1]))
	var footprint := Rect2i(at, size)
	if not footprint.has_point(cell):
		return false
	match bit:
		0:
			return cell.y == at.y
		1:
			return cell.x == footprint.end.x - 1
		2:
			return cell.y == footprint.end.y - 1
		3:
			return cell.x == at.x
	return false


static func _sockets(object: Dictionary, entries: Dictionary) -> int:
	if is_fence(object, entries):
		return 15
	var raw_entry: Variant = entries.get(String(object.get("art", "")), {})
	if not raw_entry is Dictionary:
		return 15
	return int((raw_entry as Dictionary).get("sockets", 15)) & 15


static func _connected_neighbor(
	cell: Vector2i, reciprocal_bit: int, occupied: Dictionary, objects: Array[Dictionary], entries: Dictionary
) -> bool:
	var indexes: Array = occupied.get(cell, [])
	for index: int in indexes:
		if _has_socket(objects[index], cell, reciprocal_bit, entries):
			return true
	return false


## Movement, deletion and variant changes also affect joins. Dry-apply the edit to learn the resulting stable sids,
## then append only connection corrections to the same transaction. Unrelated edits avoid making a document copy.
static func connected_command(doc: StudioDoc, change: Dictionary, entries: Dictionary) -> Dictionary:
	if doc == null or not _touches_boundary(doc, change, entries):
		return change
	var applied := StudioCommands.apply(doc, change)
	if not bool(applied.get("ok", false)):
		return change
	var after: StudioDoc = applied.doc
	var objects: Array = after.data.get("objects", [])
	var grouped: Dictionary = {}
	var templates: Dictionary = {}
	for raw_object: Variant in objects:
		if not raw_object is Dictionary:
			continue
		var object: Dictionary = raw_object
		if not supported(object, entries) or not is_fence(object, entries):
			continue
		var join := group(object, entries)
		if not grouped.has(join):
			grouped[join] = []
			templates[join] = object
		(grouped[join] as Array).append(OverworldMap.cell_of(object.get("at", [0, 0])))
	var corrections: Array[Dictionary] = []
	for join: String in grouped:
		var positions: Array[Vector2i] = []
		positions.assign(grouped[join])
		var reconciled := plan(templates[join], positions, objects, entries)
		for edit: Dictionary in reconciled.edits:
			var index := int(edit.index)
			if index < 0 or index >= after.sids.size():
				continue
			var before: Dictionary = objects[index]
			var corrected: Dictionary = edit.object
			for key: String in ["art", "flip"]:
				if before.get(key) != corrected.get(key):
					corrections.append({"type": "set", "sid": after.sids[index], "key": key, "value": corrected.get(key)})
	if corrections.is_empty():
		return change
	if String(change.get("type", "")) == "batch":
		# LEARN: extend the existing batch instead of nesting it. Its shift and cross-map metadata then run once,
		# and undo reverses both the user's edit and these neighbor corrections as one step.
		var combined := change.duplicate(true)
		var commands: Array = combined.commands
		commands.append_array(corrections)
		return combined
	var commands: Array = [change.duplicate(true)]
	commands.append_array(corrections)
	return {"type": "batch", "name": StudioCommands.describe(doc, change), "commands": commands}


## This reads only the command's touched objects; checking an ordinary text/ground edit never scans the map.
static func _touches_boundary(doc: StudioDoc, change: Dictionary, entries: Dictionary) -> bool:
	match String(change.get("type", "")):
		"add":
			var object: Variant = change.get("object")
			return object is Dictionary and _join_object(object as Dictionary, entries)
		"remove":
			return _join_object(_sid_object(doc, change.get("sid")), entries)
		"move":
			var sids: Variant = change.get("sids")
			if sids is Array:
				for sid: Variant in sids:
					if _join_object(_sid_object(doc, sid), entries):
						return true
		"set":
			var key := String(change.get("key", ""))
			if key not in ["art", "at", "size", "kind", "id", "program", "flip"]:
				return false
			# A batch may change kind and art in separate steps, so recognize a new boundary art independently.
			if key == "art" and not group({"art": change.get("value", "")}, entries).is_empty():
				return true
			var object := _sid_object(doc, change.get("sid"))
			if _join_object(object, entries):
				return true
			if key in ["art", "kind"] and not object.is_empty():
				object[key] = change.get("value")
				return _join_object(object, entries)
		"batch":
			var commands: Variant = change.get("commands")
			if commands is Array:
				for command: Variant in commands:
					if command is Dictionary and _touches_boundary(doc, command as Dictionary, entries):
						return true
	return false


static func _join_object(object: Dictionary, entries: Dictionary) -> bool:
	return String(object.get("kind", "")) == "prop" and not group(object, entries).is_empty()


static func _sid_object(doc: StudioDoc, value: Variant) -> Dictionary:
	return doc.object_of_sid(int(value)) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else {}


static func _record(index: int, previous_count: int, object: Dictionary) -> Dictionary:
	return {"index": index if index < previous_count else -1, "object": object.duplicate(true)}


## Spatial entries keep the original array indexes; no removals or insertions can change another object's identity.
static func _index(
	occupied: Dictionary, object: Dictionary, index: int, join: String, entries: Dictionary
) -> void:
	if String(object.get("kind", "")) != "prop" or group(object, entries) != join:
		return
	var at := OverworldMap.cell_of(object.get("at", [0, 0]))
	var size := OverworldMap.cell_of(object.get("size", [1, 1]))
	for y: int in size.y:
		for x: int in size.x:
			var cell := at + Vector2i(x, y)
			var indexes: Array = occupied.get(cell, [])
			indexes.append(index)
			occupied[cell] = indexes


static func _eligible_at(cell: Vector2i, occupied: Dictionary, work: Array[Dictionary], entries: Dictionary) -> int:
	var indexes: Array = occupied.get(cell, [])
	for index: int in indexes:
		if supported(work[index], entries):
			return index
	return -1


## Input can come from a built map as well as its raw document; the returned object always uses serializable cells.
static func _raw(object: Dictionary) -> Dictionary:
	var out := object.duplicate(true)
	for key: String in ["at", "size"]:
		var value: Variant = out.get(key)
		if value is Vector2i:
			var cell: Vector2i = value
			out[key] = [cell.x, cell.y]
	return out
