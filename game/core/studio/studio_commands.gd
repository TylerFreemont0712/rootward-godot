class_name StudioCommands
extends RefCounted
## The edits to a StudioDoc (Concept/v0.3/10, section 9.1), as plain Dictionaries that can be saved and shown later:
##
##   {"type": "add", "object": {...}, "index": -1}                 an object, at an index (-1: the end), with a new sid
##   {"type": "remove", "sid": 3}                                  an object
##   {"type": "move", "sids": [3, 4], "by": [1, 0]}                objects, by whole cells
##   {"type": "set", "sid": 3, "key": "solid", "value": false}     one field of one object (null erases it)
##   {"type": "set_map", "key": "start", "value": [2, 3]}          one top-level field of the map (null erases it)
##   {"type": "batch", "name": "Tidy the room", "commands": [...]} several commands, one undo step
##   {"type": "batch", ..., "shift": [4, 0]}                      as above, for a resize: how far the cells moved
##   {"type": "batch", ..., "elsewhere": [...], "elsewhere_undo": [...]}   as above, with changes to other maps
##   {"type": "set_entry", "id": "barrel-2x1", "value": {...}}     a catalog entry (null removes it; catalog docs only)
##   {"type": "set_rows", "rows": {"12": "..cobble..", "13": ""}}  whole ground rows of a map, by row number
##   {"type": "set_at", "path": ["hello", "steps", 2, "done"], "value": v}   any value, by path (null erases a key)
##   {"type": "insert_at", "path": ["hello", "steps"], "index": 1, "value": v}   an item into a list (-1: the end)
##   {"type": "remove_at", "path": ["hello", "steps"], "index": 1}          an item out of a list
##
## A path is a list of keys (text) and indexes (whole numbers) from the doc's data root. The by-path commands work on
## any kind of doc, and a map's objects are changed through add, remove and move (set_at may change one object's fields).
##
##   var result := StudioCommands.apply(doc, command)
##   if result["ok"]:
##       var edited: StudioDoc = result["doc"]
##       var back := StudioCommands.apply(edited, result["undo"])   # the doc as it was
##
## apply never changes the doc it is given: it works on a copy, so a refused command changes nothing. Whole floats
## are accepted wherever a whole number is wanted, since a command read back from JSON has them.
##
## Key order: the writer keeps each object's keys in order, so a set that erases a key records where the key was
## ("index" in its undo), and undoing it puts the key back in that place rather than at the end.


## {ok: true, doc, undo, done} for the command, or {ok: false, error}. Errors change nothing.
static func apply(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var work := doc.copy()
	var result := _apply_in_place(work, command)
	if result["ok"]:
		result["doc"] = work
	return result


## A short English description for the history list: "Add barrel", "Remove oak", "Move 3 things", "Set solid of
## barrel", "Set the map's start", or the name of a batch. Describe the doc as it is before the command applies.
static func describe(doc: StudioDoc, command: Dictionary) -> String:
	var kind := str(command.get("type", ""))
	match kind:
		"add":
			return "Add %s" % _name_of(command.get("object"))
		"remove":
			return "Remove %s" % _name_for_sid(doc, command.get("sid"))
		"move":
			var listed: Variant = command.get("sids")
			var count := (listed as Array).size() if typeof(listed) == TYPE_ARRAY else 0
			if count == 1:
				return "Move %s" % _name_for_sid(doc, (listed as Array)[0])
			return "Move %d things" % count
		"set":
			return "Set %s of %s" % [str(command.get("key", "")), _name_for_sid(doc, command.get("sid"))]
		"set_map":
			return "Set the map's %s" % str(command.get("key", ""))
		"set_entry":
			return "Set the catalog's %s" % str(command.get("id", ""))
		"set_rows":
			return "Paint the ground"
		"set_at":
			return _set_at_name(command)
		"insert_at":
			return _insert_at_name(command)
		"remove_at":
			return _remove_at_name(command)
		"batch":
			return _batch_name(command)
	return "Unknown change"


## Applies a command to a doc the caller owns: apply's copy, or one step of a batch. A refused command can leave the
## doc part changed, which is why only apply (that throws its copy away) is public.
static func _apply_in_place(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var kind: Variant = command.get("type")
	if typeof(kind) != TYPE_STRING:
		return _refused("a command needs a type")
	match String(kind):
		"add":
			return _add(doc, command)
		"remove":
			return _remove(doc, command)
		"move":
			return _move(doc, command)
		"set":
			return _set_object(doc, command)
		"set_map":
			return _set_map(doc, command)
		"batch":
			return _batch(doc, command)
		"set_entry":
			return _set_entry(doc, command)
		"set_rows":
			return _set_rows(doc, command)
		"set_at":
			return _set_at(doc, command)
		"insert_at":
			return _insert_at(doc, command)
		"remove_at":
			return _remove_at(doc, command)
	return _refused('unknown command type "%s"' % String(kind))


## A value set at a path. A dictionary key that is not there yet is added (at `index` in the key order when given, else
## at the end). A null erases a key, and the undo puts the key back in its place. A list item is replaced; a null is
## kept in a list. A key holding null cannot be written back by undo, so it is refused.
static func _set_at(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var path: Variant = _path_of(command.get("path"))
	if path == null or (path as Array).is_empty():
		return _refused("set_at needs a path of keys and indexes")
	if not command.has("value"):
		return _refused("set_at needs a value (null erases a key)")
	var steps: Array = path
	var refusal := _objects_refusal(steps, command.get("value"))
	if not refusal.is_empty():
		return _refused(refusal)
	var found := _walk(doc, steps, steps.size() - 1)
	if not found["ok"]:
		return found
	var holder: Variant = found["value"]
	var last: Variant = steps.back()
	var value: Variant = JsoncWriter.normalized(command.get("value"))
	var undo := {"type": "set_at", "path": steps.duplicate(), "value": null}
	if typeof(holder) == TYPE_DICTIONARY:
		var target: Dictionary = holder
		if typeof(last) != TYPE_STRING:
			return _refused("%s is a dictionary, so its key is text" % str(last))
		var name := String(last)
		if not target.has(name):
			if value == null:
				return _refused('no key "%s" to erase' % name)
			var raw: Variant = command.get("index")
			var place: Variant = -1 if raw == null else _as_int(raw)
			if place == null:
				return _refused("set_at index must be a whole number")
			_put(target, name, value, int(place))
			return _applied(undo, _done_of(command, steps))
		if target[name] == null:
			return _refused('"%s" holds null, which set_at cannot write back' % name)
		var keys: Array = target.keys()
		undo["value"] = JsoncWriter.normalized(target[name])
		if value == null:
			undo["index"] = keys.find(name)
		_put(target, name, value, -1)
		return _applied(undo, _done_of(command, steps))
	if typeof(holder) == TYPE_ARRAY:
		var items: Array = holder
		if typeof(last) != TYPE_INT or int(last) < 0 or int(last) >= items.size():
			return _refused("no item %s in the list" % str(last))
		undo["value"] = JsoncWriter.normalized(items[int(last)])
		items[int(last)] = value
		return _applied(undo, _done_of(command, steps))
	return _refused("the path goes through a value that is not a list or dictionary")


## An item put into a list at `index` (-1 or the list's size: at the end). Its undo removes that item.
static func _insert_at(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var path: Variant = _path_of(command.get("path"))
	if path == null:
		return _refused("insert_at needs a path of keys and indexes")
	if not command.has("value"):
		return _refused("insert_at needs a value")
	var steps: Array = path
	if _is_objects_list(steps):
		return _refused(_objects_list_refusal())
	var found := _list_at(doc, steps)
	if not found["ok"]:
		return found
	var list: Array = found["list"]
	var raw: Variant = command.get("index")
	var position: Variant = -1 if raw == null else _as_int(raw)
	if position == null or position < -1 or position > list.size():
		return _refused("insert_at index must be -1 or from 0 to %d" % list.size())
	var at := list.size() if position == -1 else int(position)
	list.insert(at, JsoncWriter.normalized(command.get("value")))
	var undo := {"type": "remove_at", "path": steps.duplicate(), "index": at}
	return _applied(undo, _done_of(command, steps))


## An item taken out of a list. Its undo puts the same item back at the same index.
static func _remove_at(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var path: Variant = _path_of(command.get("path"))
	if path == null:
		return _refused("remove_at needs a path of keys and indexes")
	var steps: Array = path
	if _is_objects_list(steps):
		return _refused(_objects_list_refusal())
	var found := _list_at(doc, steps)
	if not found["ok"]:
		return found
	var list: Array = found["list"]
	var position: Variant = _as_int(command.get("index"))
	if position == null or position < 0 or position >= list.size():
		return _refused("remove_at index %s is not an item of the list" % str(command.get("index")))
	var at := int(position)
	var removed: Variant = JsoncWriter.normalized(list[at])
	list.remove_at(at)
	var undo := {"type": "insert_at", "path": steps.duplicate(), "index": at, "value": removed}
	return _applied(undo, _done_of(command, steps))


## The value a path reaches after its first `count` steps from the data root, as {ok, value}. Each step must be a key
## that is there in a dictionary, or an index inside a list; anything else is refused.
static func _walk(doc: StudioDoc, steps: Array, count: int) -> Dictionary:
	var value: Variant = doc.data
	for i: int in count:
		var step: Variant = steps[i]
		if typeof(value) == TYPE_DICTIONARY:
			var dict: Dictionary = value
			if typeof(step) != TYPE_STRING:
				return _refused("%s is a dictionary, so its key is text" % str(step))
			if not dict.has(step):
				return _refused('no key "%s" on the path' % String(step))
			value = dict[step]
		elif typeof(value) == TYPE_ARRAY:
			var list: Array = value
			if typeof(step) != TYPE_INT or int(step) < 0 or int(step) >= list.size():
				return _refused("no item %s on the path" % str(step))
			value = list[int(step)]
		else:
			return _refused("the path goes through a value that is not a list or dictionary")
	return {"ok": true, "value": value}


## The list at a path, as {ok, list}; refused when the path does not reach a list.
static func _list_at(doc: StudioDoc, steps: Array) -> Dictionary:
	var found := _walk(doc, steps, steps.size())
	if not found["ok"]:
		return found
	var value: Variant = found["value"]
	if typeof(value) != TYPE_ARRAY:
		return _refused("the path does not lead to a list")
	return {"ok": true, "list": value}


## A path as a list of text keys and int indexes (whole floats count, since commands come back from JSON), or null.
static func _path_of(value: Variant) -> Variant:
	if typeof(value) != TYPE_ARRAY:
		return null
	var steps: Array = []
	for item: Variant in value:
		if typeof(item) == TYPE_STRING:
			steps.append(String(item))
		else:
			var whole: Variant = _as_int(item)
			if whole == null:
				return null
			steps.append(int(whole))
	return steps


## A map's objects keep their sids only while the list keeps its length. So a path cannot name the list itself, and an
## object at ["objects", i] can only be replaced by another object (its fields can still be set one at a time).
static func _objects_refusal(steps: Array, value: Variant) -> String:
	if _is_objects_list(steps):
		return _objects_list_refusal()
	if steps.size() == 2 and steps[0] == "objects" and typeof(value) != TYPE_DICTIONARY:
		return "an object of the map is a dictionary"
	return ""


static func _is_objects_list(steps: Array) -> bool:
	return steps.size() == 1 and steps[0] == "objects"


static func _objects_list_refusal() -> String:
	return "a map's objects change through add, remove and move, not by path"


## The undo and the done command both carry the path as normalized keys and indexes.
static func _done_of(command: Dictionary, steps: Array) -> Dictionary:
	var done := JsoncWriter.normalized(command) as Dictionary
	done["path"] = steps.duplicate()
	return done


## "Set flag of hello": the last name of the path, and the first. A path with one step is named by that step alone.
static func _set_at_name(command: Dictionary) -> String:
	var names := _path_names(command)
	if names.is_empty():
		return "Set a value"
	if names.size() == 1:
		return "Set %s" % names[0]
	return "Set %s of %s" % [names[names.size() - 1], names[0]]


static func _insert_at_name(command: Dictionary) -> String:
	var names := _path_names(command)
	if names.is_empty():
		return "Add an item"
	if names.size() == 1:
		return "Add to %s" % names[0]
	return "Add to %s's %s" % [names[0], names[names.size() - 1]]


static func _remove_at_name(command: Dictionary) -> String:
	var names := _path_names(command)
	if names.is_empty():
		return "Remove an item"
	if names.size() == 1:
		return "Remove from %s" % names[0]
	return "Remove from %s's %s" % [names[0], names[names.size() - 1]]


## The names of a path's steps for a description: a key as it is, an index as "item" and its place from 1.
static func _path_names(command: Dictionary) -> PackedStringArray:
	var names := PackedStringArray()
	var path: Variant = _path_of(command.get("path"))
	if path == null:
		return names
	for step: Variant in path:
		names.append("item %d" % (int(step) + 1) if typeof(step) == TYPE_INT else String(step))
	return names


## A catalog entry set, replaced in place or removed (`value` null). The undo puts the old entry back where it was,
## so the file keeps its order: an entry is added at the end unless the command gives an `index`.
static func _set_entry(doc: StudioDoc, command: Dictionary) -> Dictionary:
	if doc.kind != "catalog":
		return _refused("set_entry is for the catalog")
	var id := str(command.get("id", "")) if typeof(command.get("id")) == TYPE_STRING else ""
	var value: Variant = command.get("value")
	if id.is_empty():
		return _refused("set_entry needs an id")
	if value != null and typeof(value) != TYPE_DICTIONARY:
		return _refused("a catalog entry is an object")
	var assets: Variant = doc.data.get("assets", {})
	if typeof(assets) != TYPE_DICTIONARY:
		return _refused("the catalog's assets are not an object")
	var old_assets: Dictionary = assets
	var keys: Array = old_assets.keys()
	var had := old_assets.has(id)
	var before: Variant = (old_assets[id] as Dictionary).duplicate(true) if had and old_assets[id] is Dictionary else old_assets.get(id)
	var at := keys.find(id) if had else int(_as_int(command.get("index")) if command.get("index") != null else -1)
	var rebuilt := {}
	var placed := false
	for i: int in keys.size():
		var key: Variant = keys[i]
		if i == at and not had and value != null:
			rebuilt[id] = JsoncWriter.normalized(value)
			placed = true
		if key == id:
			if value != null:
				rebuilt[id] = JsoncWriter.normalized(value)
			continue
		rebuilt[key] = old_assets[key]
	if value != null and not placed and not rebuilt.has(id):
		rebuilt[id] = JsoncWriter.normalized(value)
	doc.data["assets"] = rebuilt
	var undo := {"type": "set_entry", "id": id, "value": before if had else null}
	if had and value == null:
		undo["index"] = at
	return _applied(undo, JsoncWriter.normalized(command) as Dictionary)


static func _add(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var object: Variant = command.get("object")
	if typeof(object) != TYPE_DICTIONARY:
		return _refused("add needs an object")
	var sid := doc.next_sid
	var given: Variant = command.get("sid")
	if given != null:
		var whole: Variant = _as_int(given)
		if whole == null or whole < 1:
			return _refused("add needs a sid from 1 up")
		sid = int(whole)
	if doc.index_of_sid(sid) != -1:
		return _refused("sid %d is already in use" % sid)
	var objects: Variant = _objects_of(doc)
	if objects == null:
		return _refused("the map's objects are not a list")
	var count := (objects as Array).size()
	var raw: Variant = command.get("index")
	var position: Variant = -1 if raw == null else _as_int(raw)
	if position == null or position < -1 or position > count:
		return _refused("add index must be -1 or from 0 to %d" % count)
	var index := count if position == -1 else int(position)
	(objects as Array).insert(index, JsoncWriter.normalized(object))
	doc.sids.insert(index, sid)
	doc.next_sid = maxi(doc.next_sid, sid + 1)
	var done := JsoncWriter.normalized(command) as Dictionary
	done["sid"] = sid
	return _applied({"type": "remove", "sid": sid}, done)


static func _remove(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var sid: Variant = _as_int(command.get("sid"))
	if sid == null:
		return _refused("remove needs a sid")
	var index := doc.index_of_sid(int(sid))
	if index == -1:
		return _refused("no object with sid %d" % int(sid))
	var objects: Array = doc.data.get("objects", [])
	var removed: Dictionary = (objects[index] as Dictionary).duplicate(true)
	objects.remove_at(index)
	doc.sids.remove_at(index)
	var undo := {"type": "add", "object": removed, "index": index, "sid": int(sid)}
	return _applied(undo, JsoncWriter.normalized(command) as Dictionary)


static func _move(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var listed: Variant = command.get("sids")
	if typeof(listed) != TYPE_ARRAY:
		return _refused("move needs a list of sids")
	var by: Variant = _cell_of(command.get("by"))
	if by == null:
		return _refused("move needs a by of two whole numbers")
	var step: Vector2i = by
	var sids: Array = []
	for item: Variant in listed:
		var sid: Variant = _as_int(item)
		if sid == null:
			return _refused("move needs whole-number sids")
		if sids.has(int(sid)):
			return _refused("sid %d is listed twice" % int(sid))
		var object: Variant = _live(doc, int(sid))
		if object == null:
			return _refused("no object with sid %d" % int(sid))
		if _cell_of((object as Dictionary).get("at")) == null:
			return _refused("the object with sid %d has no cell" % int(sid))
		sids.append(int(sid))
	for sid: int in sids:
		var object: Dictionary = _live(doc, sid)
		var at: Vector2i = _cell_of(object["at"])
		object["at"] = [at.x + step.x, at.y + step.y]
	var undo := {"type": "move", "sids": sids, "by": [-step.x, -step.y]}
	return _applied(undo, JsoncWriter.normalized(command) as Dictionary)


static func _set_object(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var sid: Variant = _as_int(command.get("sid"))
	if sid == null:
		return _refused("set needs a sid")
	var object: Variant = _live(doc, int(sid))
	if object == null:
		return _refused("no object with sid %d" % int(sid))
	return _set_field(object as Dictionary, command, {"type": "set", "sid": int(sid)})


static func _set_map(doc: StudioDoc, command: Dictionary) -> Dictionary:
	if command.get("key") == "objects":
		return _refused("set_map cannot change the objects; use add, remove and move")
	return _set_field(doc.data, command, {"type": "set_map"})


## Replaces whole ground rows by row number. `rows` maps each number (a string, as JSON gives it) to the row's new text;
## the undo replaces the same rows with their old text. Every row is checked before any changes, so a bad one changes
## nothing.
static func _set_rows(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var listed: Variant = command.get("rows")
	if typeof(listed) != TYPE_DICTIONARY or (listed as Dictionary).is_empty():
		return _refused("set_rows needs rows: an object of row number to text, not empty")
	var ground: Variant = doc.data.get("ground")
	if typeof(ground) != TYPE_ARRAY:
		return _refused("the map's ground is not a list of rows")
	var rows: Array = ground
	var given: Dictionary = listed
	var old_text := {}
	for key: Variant in given:
		var index: Variant = _row_index(key)
		if index == null:
			return _refused('set_rows row "%s" is not a whole number' % str(key))
		if int(index) < 0 or int(index) >= rows.size():
			return _refused("set_rows row %d is outside the ground" % int(index))
		if typeof(given[key]) != TYPE_STRING:
			return _refused("set_rows row %d is not text" % int(index))
		old_text[str(int(index))] = str(rows[int(index)])
	for key: Variant in given:
		rows[int(_row_index(key))] = String(given[key])
	var undo := {"type": "set_rows", "rows": old_text}
	return _applied(undo, JsoncWriter.normalized(command) as Dictionary)


## A row number as a whole int: a string of digits (the way JSON keys are), or a whole number. Null otherwise.
static func _row_index(key: Variant) -> Variant:
	if typeof(key) == TYPE_STRING:
		var text := String(key)
		return int(text) if text.is_valid_int() else null
	return _as_int(key)


## Sets, or erases (a null value), one key of `target`, and returns the command that puts it back. `undo_base` holds
## the command's type and sid; the key, the old value and (when the key was there) its place are added.
static func _set_field(target: Dictionary, command: Dictionary, undo_base: Dictionary) -> Dictionary:
	var key: Variant = command.get("key")
	if typeof(key) != TYPE_STRING or String(key).is_empty():
		return _refused("set needs a key")
	var name := String(key)
	var raw: Variant = command.get("index")
	var place: Variant = -1 if raw == null else _as_int(raw)
	if place == null:
		return _refused("set index must be a whole number")
	var value: Variant = JsoncWriter.normalized(command.get("value"))
	var keys: Array = target.keys()
	var existed := target.has(name)
	var undo := undo_base.duplicate()
	undo["key"] = name
	undo["value"] = JsoncWriter.normalized(target.get(name))
	if existed:
		undo["index"] = keys.find(name)
	_put(target, name, value, int(place))
	return _applied(undo, JsoncWriter.normalized(command) as Dictionary)


## Puts `value` under `key`, or erases the key for a null value. A key that is not there yet goes to `index` in the
## key order when it is inside the dictionary, else to the end; a key already there keeps its place.
static func _put(target: Dictionary, key: String, value: Variant, index: int) -> void:
	if value == null:
		target.erase(key)
		return
	if target.has(key) or index < 0 or index >= target.size():
		target[key] = value
		return
	var keys := target.keys()
	var values := target.values()
	target.clear()
	for position: int in keys.size():
		if position == index:
			target[key] = value
		target[keys[position]] = values[position]


## Runs the commands in order and records them as one step. An optional `shift` ([dx, dy], how far the map's cells
## moved in a resize) is carried into the done command, and the undo carries it negated, so a step knows its move.
## Optional `elsewhere` and `elsewhere_undo` are what the step does to other maps, and how to take it back: lists of
## {map, command}, applied by the Studio to those maps' own drafts (a person moved here from another map, the way out
## of a room following its door). This doc never reads them; the undo carries the two lists swapped.
static func _batch(doc: StudioDoc, command: Dictionary) -> Dictionary:
	var list: Variant = command.get("commands")
	if typeof(list) != TYPE_ARRAY:
		return _refused("batch needs a list of commands")
	var shift: Variant = null
	if command.get("shift") != null:
		shift = _cell_of(command.get("shift"))
		if shift == null:
			return _refused("a batch's shift is two whole numbers")
	for key: String in ["elsewhere", "elsewhere_undo"]:
		if command.get(key) != null and not _other_maps(command.get(key)):
			return _refused("a batch's %s is a list of {map, command}" % key)
	var commands: Array = list
	var undos: Array = []
	var dones: Array = []
	for item: Variant in commands:
		if typeof(item) != TYPE_DICTIONARY:
			return _refused("a batch holds commands, each a Dictionary")
		var sub: Dictionary = item
		var result := _apply_in_place(doc, sub)
		if not result["ok"]:
			return result
		undos.push_front(result["undo"])
		dones.append(result["done"])
	var name := _name_field(command)
	var undo := {"type": "batch", "name": name, "commands": undos}
	var done := {"type": "batch", "name": name, "commands": dones}
	if shift != null:
		var step: Vector2i = shift
		done["shift"] = [step.x, step.y]
		undo["shift"] = [-step.x, -step.y]
	if command.get("elsewhere") != null or command.get("elsewhere_undo") != null:
		var there: Array = JsoncWriter.normalized(command.get("elsewhere", []))
		var back: Array = JsoncWriter.normalized(command.get("elsewhere_undo", []))
		done["elsewhere"] = there
		done["elsewhere_undo"] = back
		undo["elsewhere"] = back.duplicate(true)
		undo["elsewhere_undo"] = there.duplicate(true)
	return _applied(undo, done)


## Whether `value` is a list of {map: an id, command: a Dictionary}.
static func _other_maps(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for item: Variant in value:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var one: Dictionary = item
		if typeof(one.get("map")) != TYPE_STRING or typeof(one.get("command")) != TYPE_DICTIONARY:
			return false
	return true


static func _refused(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func _applied(undo: Dictionary, done: Dictionary) -> Dictionary:
	return {"ok": true, "undo": undo, "done": done}


## The map's objects, made (empty) when the map has none yet. Null when "objects" is there but is not a list.
static func _objects_of(doc: StudioDoc) -> Variant:
	if not doc.data.has("objects"):
		doc.data["objects"] = []
	var objects: Variant = doc.data["objects"]
	return objects if typeof(objects) == TYPE_ARRAY else null


## The object with this sid as it is in the doc (a reference, so changing it changes the doc), or null.
static func _live(doc: StudioDoc, sid: int) -> Variant:
	var index := doc.index_of_sid(sid)
	if index == -1:
		return null
	var objects: Array = doc.data.get("objects", [])
	var object: Variant = objects[index]
	return object if typeof(object) == TYPE_DICTIONARY else null


## The value as an int when it is a whole number (a float from JSON counts), else null.
static func _as_int(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number == floorf(number) and absf(number) <= JsoncWriter.MAX_WHOLE:
			return int(number)
	return null


## A cell from a [x, y] list of whole numbers, as a Vector2i, or null.
static func _cell_of(value: Variant) -> Variant:
	if typeof(value) != TYPE_ARRAY:
		return null
	var pair: Array = value
	if pair.size() != 2:
		return null
	var x: Variant = _as_int(pair[0])
	var y: Variant = _as_int(pair[1])
	if x == null or y == null:
		return null
	return Vector2i(int(x), int(y))


static func _name_field(command: Dictionary) -> String:
	var name: Variant = command.get("name")
	return String(name) if typeof(name) == TYPE_STRING else ""


static func _batch_name(command: Dictionary) -> String:
	var name := _name_field(command)
	if not name.is_empty():
		return name
	var count := 0
	var list: Variant = command.get("commands")
	if typeof(list) == TYPE_ARRAY:
		count = (list as Array).size()
	return "1 change" if count == 1 else "%d changes" % count


## The art of an object (its picture's name), a person by their id ("person pell"), else its kind, else "thing".
static func _name_of(value: Variant) -> String:
	if typeof(value) == TYPE_DICTIONARY:
		var object: Dictionary = value
		if object.get("kind") == "person" and typeof(object.get("id")) == TYPE_STRING:
			return "person %s" % String(object.id)
		for key: String in ["art", "kind"]:
			if typeof(object.get(key)) == TYPE_STRING and not String(object[key]).is_empty():
				return String(object[key])
	return "thing"


static func _name_for_sid(doc: StudioDoc, value: Variant) -> String:
	var sid: Variant = _as_int(value)
	return _name_of(doc.object_of_sid(int(sid)) if sid != null else {})
