class_name StudioDiff
extends RefCounted
## The changes from one map draft to another, in plain words (Concept/v0.3/10, section 9.7): the list the Publish
## dialog shows before a file is written. Objects match by sid, so a moved barrel is one line, not a removal and an
## addition.
##
##   for line in StudioDiff.lines(base, edited):
##       print(line)                                  # Moved barrel from 39, 40 to 41, 40
##   print(StudioDiff.summary(base, edited))          # 1 moved, 1 ground cell
##
## A cell is two numbers, [column, row]; it prints as "column, row". A list that is not a cell and a dictionary print
## only as "changed", since their values are too long for a line.


## The changes from `base` to `edited`, one plain English line each, in this order: map fields, ground, removed,
## added, moved, changed. Objects match by sid.
static func lines(base: StudioDoc, edited: StudioDoc) -> Array[String]:
	if edited.kind == "catalog":
		return _catalog_lines(base, edited)
	if base.data.is_empty() and not edited.data.is_empty():
		return [_made_line(edited)]
	var out: Array[String] = []
	var pairs := _pairs(base, edited)
	out.append_array(_map_field_lines(base, edited))
	out.append_array(_ground_lines(base, edited))
	out.append_array(_removed_lines(pairs))
	out.append_array(_added_lines(pairs))
	out.append_array(_moved_lines(pairs))
	out.append_array(_changed_lines(pairs))
	return out


## A one-line summary: "3 moved, 2 added, 1 removed, 4 changed, 18 ground cells" (only the parts that are not zero;
## "no changes" when nothing changed). A changed line counts once per field.
static func summary(base: StudioDoc, edited: StudioDoc) -> String:
	if edited.kind == "catalog":
		return _catalog_summary(base, edited)
	if base.data.is_empty() and not edited.data.is_empty():
		return "new map"
	var parts := PackedStringArray()
	var pairs := _pairs(base, edited)
	var moved := _moved_lines(pairs).size()
	var added := _added_lines(pairs).size()
	var removed := _removed_lines(pairs).size()
	var changed := _changed_lines(pairs).size()
	var fields := _map_field_lines(base, edited).size()
	var painted := _painted(base, edited)
	if moved > 0:
		parts.append("%d moved" % moved)
	if added > 0:
		parts.append("%d added" % added)
	if removed > 0:
		parts.append("%d removed" % removed)
	if changed > 0:
		parts.append("%d changed" % changed)
	if fields > 0:
		parts.append("%d map %s" % [fields, _plural(fields, "field", "fields")])
	if painted > 0:
		parts.append("%d ground %s" % [painted, _plural(painted, "cell", "cells")])
	if _size(base) != _size(edited):
		parts.append("map size changed")
	if parts.is_empty():
		return "no changes"
	return ", ".join(parts)


## How an object is named in a line: a person by its id ("person pip"), a warp by the map it leads to ("warp to
## lanternroot"), a sign as "sign", and anything else by its art ("barrel").
static func name_of(object: Dictionary) -> String:
	var kind := str(object.get("kind", ""))
	if kind == "person":
		var id := str(object.get("id", ""))
		return "person %s" % id if id != "" else "person"
	if kind == "warp":
		var map_name := _warp_map(object)
		return "warp to %s" % map_name if map_name != "" else "warp"
	if kind == "sign":
		return "sign"
	var art := str(object.get("art", ""))
	if art != "":
		return art
	return kind if kind != "" else "object"


## A map made in the Studio (it began from nothing, phase S6): one line for all of it.
static func _made_line(edited: StudioDoc) -> String:
	var size := _size(edited)
	var count := _entries(edited).size()
	var title := str(edited.data.get("name", edited.data.get("id", "")))
	return "New map %s, %d x %d, with %d %s" % [title, size.x, size.y, count, _plural(count, "thing", "things")]


static func _map_field_lines(base: StudioDoc, edited: StudioDoc) -> Array[String]:
	var out: Array[String] = []
	for key: String in _union_keys(base.data, edited.data):
		if key == "ground" or key == "objects":
			continue
		var had := base.data.has(key)
		var has := edited.data.has(key)
		var before: Variant = base.data.get(key)
		var after: Variant = edited.data.get(key)
		if had == has and before == after:
			continue
		var detail := _detail(before, after, had, has)
		out.append("Map: %s %s" % [key, detail if detail != "" else "changed"])
	return out


static func _ground_lines(base: StudioDoc, edited: StudioDoc) -> Array[String]:
	var out: Array[String] = []
	var painted := _painted(base, edited)
	if painted > 0:
		out.append("Painted %d ground %s" % [painted, _plural(painted, "cell", "cells")])
	var before := _size(base)
	var after := _size(edited)
	if before != after:
		out.append("Resized the map from %d x %d to %d x %d" % [before.x, before.y, after.x, after.y])
	return out


## Both docs' objects with their sids, read once for every kind of line: the lists in file order and each by sid.
static func _pairs(base: StudioDoc, edited: StudioDoc) -> Dictionary:
	var before := _entries(base)
	var after := _entries(edited)
	return {"before": before, "after": after, "before_by_sid": _by_sid(before), "after_by_sid": _by_sid(after)}


static func _removed_lines(pairs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var kept: Dictionary = pairs.after_by_sid
	for entry: Dictionary in pairs.before:
		if not kept.has(entry["sid"]):
			var object: Dictionary = entry["object"]
			out.append("Removed %s%s" % [name_of(object), _where(object)])
	return out


static func _added_lines(pairs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var existing: Dictionary = pairs.before_by_sid
	for entry: Dictionary in pairs.after:
		if not existing.has(entry["sid"]):
			var object: Dictionary = entry["object"]
			out.append("Added %s%s" % [name_of(object), _where(object)])
	return out


static func _moved_lines(pairs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var after: Dictionary = pairs.after_by_sid
	for entry: Dictionary in pairs.before:
		if not after.has(entry["sid"]):
			continue
		var before_object: Dictionary = entry["object"]
		var now: Dictionary = after[entry["sid"]]
		if before_object.get("at") != now.get("at"):
			var from_text := _value_text(before_object.get("at"))
			var to_text := _value_text(now.get("at"))
			out.append("Moved %s from %s to %s" % [name_of(now), from_text, to_text])
	return out


static func _changed_lines(pairs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var after: Dictionary = pairs.after_by_sid
	for entry: Dictionary in pairs.before:
		if not after.has(entry["sid"]):
			continue
		var before_object: Dictionary = entry["object"]
		var now: Dictionary = after[entry["sid"]]
		# LEARN: Dictionary == compares contents in the engine, far faster than walking every key here; on the town
		# almost every object is untouched, so this one comparison is most of the work saved.
		if before_object == now:
			continue
		for key: String in _union_keys(before_object, now):
			if key == "at":
				continue
			var had := before_object.has(key)
			var has := now.has(key)
			if had == has and before_object.get(key) == now.get(key):
				continue
			var detail := _detail(before_object.get(key), now.get(key), had, has)
			var line := "Changed %s of %s%s" % [key, name_of(now), _where(now)]
			if detail != "":
				line += ": " + detail
			out.append(line)
	return out


## The cells that differ: every character of a row that both docs have and that differs from the same column of the
## other, and every character of a row that only one doc has (a row that is longer in one doc counts its extra cells).
## A map that changed size counts none: a resize moves its cells (a column added on the left shifts every column), so
## comparing them one by one would paint the whole map. The resize line says it instead.
static func _painted(base: StudioDoc, edited: StudioDoc) -> int:
	if _size(base) != _size(edited):
		return 0
	var before := _rows(base)
	var after := _rows(edited)
	var count := 0
	for index: int in maxi(before.size(), after.size()):
		var old_row := before[index] if index < before.size() else ""
		var new_row := after[index] if index < after.size() else ""
		if old_row == new_row:
			continue
		for column: int in maxi(old_row.length(), new_row.length()):
			if old_row.substr(column, 1) != new_row.substr(column, 1):
				count += 1
	return count


## The map's size in cells: x is the longest row, y the number of rows.
static func _size(doc: StudioDoc) -> Vector2i:
	var rows := _rows(doc)
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	return Vector2i(width, rows.size())


static func _rows(doc: StudioDoc) -> Array[String]:
	var rows: Array[String] = []
	var ground: Variant = doc.data.get("ground", [])
	if typeof(ground) != TYPE_ARRAY:
		return rows
	var list: Array = ground
	for row: Variant in list:
		rows.append(str(row))
	return rows


## Each object of a doc with its sid, in file order: [{sid, object}, ...]. Items that are not dictionaries are skipped.
static func _entries(doc: StudioDoc) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var objects: Variant = doc.data.get("objects", [])
	if typeof(objects) != TYPE_ARRAY:
		return entries
	var list: Array = objects
	for index: int in mini(list.size(), doc.sids.size()):
		if typeof(list[index]) == TYPE_DICTIONARY:
			entries.append({"sid": doc.sids[index], "object": list[index]})
	return entries


static func _by_sid(entries: Array[Dictionary]) -> Dictionary:
	var found := {}
	for entry: Dictionary in entries:
		found[entry["sid"]] = entry["object"]
	return found


## The keys of `first` in their order, then the keys only `second` has.
static func _union_keys(first: Dictionary, second: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key: Variant in first:
		keys.append(String(key))
	for key: Variant in second:
		if not first.has(key):
			keys.append(String(key))
	return keys


## What follows the name of a changed field: "false to true", "set to 3", "removed". Empty when the values are
## structured (a dictionary or a list that is not a cell) and so are not written.
static func _detail(before: Variant, after: Variant, had: bool, has: bool) -> String:
	if not has:
		return "removed"
	if not had:
		return "" if _structured(after) else "set to %s" % _value_text(after)
	if _structured(before) or _structured(after):
		return ""
	return "%s to %s" % [_value_text(before), _value_text(after)]


## " at 12, 40" for the object's cell, "" when it has none.
static func _where(object: Dictionary) -> String:
	var at: Variant = object.get("at")
	if not _is_cell(at):
		return ""
	return " at %s" % _value_text(at)


static func _warp_map(object: Dictionary) -> String:
	var target: Variant = object.get("to")
	if typeof(target) != TYPE_DICTIONARY:
		return ""
	var dest: Dictionary = target
	return str(dest.get("map", ""))


## A value as a line shows it: a cell as "x, y", anything else as JSON (`true`, `3`, `"text"`).
static func _value_text(value: Variant) -> String:
	if _is_cell(value):
		var cell: Array = value
		return "%d, %d" % [int(cell[0]), int(cell[1])]
	return JsoncWriter.compact(value)


static func _is_cell(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var cell: Array = value
	return cell.size() == 2 and _is_number(cell[0]) and _is_number(cell[1])


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _structured(value: Variant) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		return true
	return typeof(value) == TYPE_ARRAY and not _is_cell(value)


static func _plural(count: int, one: String, many: String) -> String:
	return one if count == 1 else many


# --- the catalog ---------------------------------------------------------------------------------------------------


## The catalog's entries that changed, in words: "added catalog entry barrel-2x1 (Barrel, 2 × 1)", "changed catalog
## entry barrel: family", "removed catalog entry oak". Additions and changes in the edited order, then removals.
static func _catalog_lines(base: StudioDoc, edited: StudioDoc) -> Array[String]:
	var before: Dictionary = base.data.get("assets", {})
	var after: Dictionary = edited.data.get("assets", {})
	var out: Array[String] = []
	for id: Variant in after:
		var entry: Dictionary = after[id] if after[id] is Dictionary else {}
		if not before.has(id):
			var variant := String(entry.get("variant", ""))
			out.append("added catalog entry %s (%s%s)" % [id, entry.get("name", id), ", " + variant if variant != "" else ""])
			continue
		var old: Dictionary = before[id] if before[id] is Dictionary else {}
		var fields: Array[String] = []
		for key: String in _union_keys(old, entry):
			if old.get(key) != entry.get(key):
				fields.append(key)
		if not fields.is_empty():
			out.append("changed catalog entry %s: %s" % [id, ", ".join(fields)])
	for id: Variant in before:
		if not after.has(id):
			out.append("removed catalog entry %s" % id)
	return out


static func _catalog_summary(base: StudioDoc, edited: StudioDoc) -> String:
	var counts := {"added": 0, "changed": 0, "removed": 0}
	for line: String in _catalog_lines(base, edited):
		counts[line.get_slice(" ", 0)] += 1
	var parts := PackedStringArray()
	var first := true
	for kind: String in ["added", "changed", "removed"]:
		if int(counts[kind]) > 0:
			var noun := (" " + _plural(int(counts[kind]), "entry", "entries")) if first else ""
			parts.append("%d%s %s" % [counts[kind], noun, kind])
			first = false
	return ", ".join(parts) if not parts.is_empty() else "no changes"
