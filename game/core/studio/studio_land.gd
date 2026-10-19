class_name StudioLand
extends RefCounted
## Painting and resizing a map's ground and things (Concept/v0.3/10, section 7.8 and S5), as plain functions. Each one
## works out the cells, or the command, for a change and leaves applying it to StudioCommands and StudioHistory, so
## the Studio can show what will happen before it does. Nothing here draws, reads a file or changes what it is given.
##
## Cells are Vector2i, x = column, y = row. A map's ground is rows of characters, each one a kind of ground through
## the map's legend, as OverworldMap reads it.
##
##   var painted := StudioLand.paint(doc.data, StudioLand.stroke(from, to, 2), "cobble")
##   if painted["ok"]:
##       var result := StudioCommands.apply(doc, painted["command"])   # one undo step, "Paint cobble"
##
##   var grown := StudioLand.resize(doc.data, doc.sids, {"left": 4}, "grass", "lanternroot")
##   # grown.command is one batch, "Resize the map to 84 x 56": the objects, the links and the start move along

const BRUSHES: Array[int] = [1, 2, 3, 5]
## GroundLayer bakes each map into textures measured in pixels, so a hard ceiling avoids accidental multi-gigabyte maps.
const MAX_DIMENSION := 128

## The characters a new legend character can be, after the kind's own letters: the symbols in this order, then a-z,
## A-Z and 0-9. Never a quote, a backslash or a space, which would be hard to read or write in a map file.
const SYMBOLS: String = "#%&+-:;<>?@^_|"
const LOWER: String = "abcdefghijklmnopqrstuvwxyz"
const UPPER: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const DIGITS: String = "0123456789"
const NEVER: String = "\"\\ "


## The cells a brush of `size` paints round `cell`, row by row from the top left. An odd size centres on the cell; 2
## covers the cell and the ones right of it and below it. Less than 1 paints nothing.
@warning_ignore("integer_division")
static func brush(cell: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if size < 1:
		return out
	var top := cell - Vector2i((size - 1) / 2, (size - 1) / 2)
	for dy in size:
		for dx in size:
			out.append(top + Vector2i(dx, dy))
	return out


## The cells from one cell to another along a Bresenham line, both ends included. Each step moves at most one cell in
## each direction, so a diagonal run has no gaps. From a cell to itself, that cell alone.
static func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var span := (to - from).abs()
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var err := span.x - span.y
	var cell := from
	while true:
		out.append(cell)
		if cell == to:
			break
		var doubled := 2 * err
		if doubled >= -span.y:
			err -= span.y
			cell.x += step.x
		if doubled <= span.x:
			err += span.x
			cell.y += step.y
	return out


## The brush stamped at every cell of the line from `from` to `to`: each cell once, in the order the stroke first
## reaches it.
static func stroke(from: Vector2i, to: Vector2i, size: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	for centre: Vector2i in line(from, to):
		for cell: Vector2i in brush(centre, size):
			if not seen.has(cell):
				seen[cell] = true
				out.append(cell)
	return out


## Every cell of the filled rectangle between two corners, given in either order, row by row.
static func rect(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var low := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var high := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			out.append(Vector2i(x, y))
	return out


## The cells that lie inside [0, size.x) x [0, size.y), in their order.
static func clip(cells: Array[Vector2i], size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _inside(cell, size):
			out.append(cell)
	return out


## The flood fill from `start`: every cell reached from it through the four neighbours that holds the same character,
## in the order the fill reaches them. Empty when `start` is off the rows.
static func fill(rows: Array, start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var want := _char_at(rows, start)
	if want.is_empty():
		return out
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		out.append(cell)
		for step: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var next := cell + step
			if not seen.has(next) and _char_at(rows, next) == want:
				seen[next] = true
				queue.append(next)
	return out


## The legend's character for a kind: the first one in the legend's order when several, or "" when there is none.
static func char_for(legend: Dictionary, kind: String) -> String:
	for key: Variant in legend:
		if legend[key] == kind:
			return String(key)
	return ""


## A character the legend does not use yet, for a new kind: the kind's first letter in lower case, then in upper case,
## then the symbols in order, then a-z, A-Z and 0-9. "" when every one is taken.
static func free_char(legend: Dictionary, kind: String) -> String:
	var first := kind.substr(0, 1)
	var order: Array[String] = [first.to_lower(), first.to_upper()]
	for run: String in [SYMBOLS, LOWER, UPPER, DIGITS]:
		for index in run.length():
			order.append(run.substr(index, 1))
	for glyph: String in order:
		if _usable(glyph, legend):
			return glyph
	return ""


## What painting `cells` with the ground `kind` takes. The cells on the map that are not that character already change,
## in one set_rows. The command is a batch named "Paint <kind>"; when the legend has no character for the kind yet, the
## batch first adds one (a free character) to the legend. {ok: true, command, changed, added_char} with added_char ""
## when the legend had the kind, else {ok: false, error}. Changes nothing.
static func paint(data: Dictionary, cells: Array[Vector2i], kind: String) -> Dictionary:
	if kind.is_empty():
		return _fail("paint needs a ground kind")
	var rows := _rows_of(data)
	var legend := _legend_of(data)
	var glyph := char_for(legend, kind)
	var added := ""
	if glyph.is_empty():
		added = free_char(legend, kind)
		if added.is_empty():
			return _fail("no character is free for %s" % kind)
		glyph = added
	var edited := {}
	var changed := 0
	for cell: Vector2i in clip(cells, _size_of(rows)):
		# The text read is the edited one when this row was already painted, so a cell listed twice counts once.
		var text: String = edited.get(cell.y, String(rows[cell.y]))
		if cell.x >= text.length() or text.substr(cell.x, 1) == glyph:
			continue
		edited[cell.y] = text.substr(0, cell.x) + glyph + text.substr(cell.x + 1)
		changed += 1
	if changed == 0:
		return _fail("nothing to paint")
	var new_rows := {}
	var ys: Array = edited.keys()
	ys.sort()
	for y: int in ys:
		new_rows[str(y)] = edited[y]
	var commands: Array = []
	if not added.is_empty():
		var grown := legend.duplicate()
		grown[added] = kind
		commands.append({"type": "set_map", "key": "legend", "value": grown})
	commands.append({"type": "set_rows", "rows": new_rows})
	var command := {"type": "batch", "name": "Paint %s" % kind, "commands": commands}
	return {"ok": true, "command": command, "changed": changed, "added_char": added}


## What growing or shrinking the map by `edges` takes: {"left", "top", "right", "bottom"}, each a whole number that is
## positive to grow and negative to shrink (missing ones are 0). `sids[i]` is the session id of data.objects[i].
##
## The new map is W = width + left + right cells wide and H = height + top + bottom rows high. Old cell (x, y) is at
## (x + left, y + top); each new cell with no old one takes the fill, the character for `fill_kind` (a legend character
## is added when the legend has none). An object whose footprint falls outside the new map is dropped; the others move
## by (left, top), and so do their links into `map_id` (their "to" at). The start moves with them and must stay on the
## map. {ok: true, command, size: Vector2i, dropped: [{sid, kind, art, at}]} or {ok: false, error}. Changes nothing.
##
## The command is one batch, "Resize the map to W x H", with "shift": [left, top] so the history knows the cells moved.
static func resize(data: Dictionary, sids: Array[int], edges: Dictionary, fill_kind: String, map_id: String) -> Dictionary:
	var ground: Variant = data.get("ground", [])
	var objects: Variant = data.get("objects", [])
	if typeof(ground) != TYPE_ARRAY or typeof(objects) != TYPE_ARRAY:
		return _fail("the map's ground and objects must be lists")
	if fill_kind.is_empty():
		return _fail("a resize needs a ground kind for its new cells")
	var rows: Array = ground
	var list: Array = objects
	if sids.size() != list.size():
		return _fail("the session ids do not match the map's objects")
	var left_value: Variant = _whole(edges.get("left", 0))
	var top_value: Variant = _whole(edges.get("top", 0))
	var right_value: Variant = _whole(edges.get("right", 0))
	var bottom_value: Variant = _whole(edges.get("bottom", 0))
	if left_value == null or top_value == null or right_value == null or bottom_value == null:
		return _fail("the edges are whole numbers")
	var left := int(left_value)
	var top := int(top_value)
	var right := int(right_value)
	var bottom := int(bottom_value)
	var shift := Vector2i(left, top)
	var height := rows.size()
	var width := _size_of(rows).x
	var new_size := Vector2i(width + left + right, height + top + bottom)
	if new_size.x < 1 or new_size.y < 1:
		return _fail("the map would be %d x %d: it needs a cell each way" % [new_size.x, new_size.y])
	if new_size.x > MAX_DIMENSION or new_size.y > MAX_DIMENSION:
		return _fail("a map can be at most %d x %d tiles" % [MAX_DIMENSION, MAX_DIMENSION])
	var start := OverworldMap.cell_of(data.get("start", [0, 0]))
	var new_start := start + shift
	if not _inside(new_start, new_size):
		return _fail("the start would fall off the map at %d, %d" % [new_start.x, new_start.y])
	var legend := _legend_of(data)
	var glyph := char_for(legend, fill_kind)
	var grown_legend := {}
	if glyph.is_empty():
		glyph = free_char(legend, fill_kind)
		if glyph.is_empty():
			return _fail("no character is free for %s" % fill_kind)
		grown_legend = legend.duplicate()
		grown_legend[glyph] = fill_kind
	var new_rows: Array = []
	for y in new_size.y:
		var source := ""
		var old_y := y - top
		if old_y >= 0 and old_y < height:
			source = String(rows[old_y])
		new_rows.append(_shifted_row(source, left, new_size.x, glyph))
	var dropped: Array[Dictionary] = []
	var kept: Array[int] = []
	var kept_index: Array[int] = []
	for index in list.size():
		if typeof(list[index]) != TYPE_DICTIONARY:
			return _fail("object %d is not an object" % index)
		var object: Dictionary = list[index]
		var at := OverworldMap.cell_of(object.get("at", [0, 0]))
		var footprint := OverworldMap.cell_of(object.get("size", [1, 1]))
		if _footprint_inside(at + shift, footprint, new_size):
			kept.append(sids[index])
			kept_index.append(index)
		else:
			dropped.append(
				{
					"sid": sids[index],
					"kind": str(object.get("kind", "")),
					"art": str(object.get("art", "")),
					"at": at,
				}
			)
	var commands: Array = []
	for item: Dictionary in dropped:
		commands.append({"type": "remove", "sid": item["sid"]})
	if shift != Vector2i.ZERO:
		if not kept.is_empty():
			commands.append({"type": "move", "sids": kept.duplicate(), "by": [left, top]})
		for index: int in kept_index:
			var object: Dictionary = list[index]
			var to: Variant = object.get("to")
			if typeof(to) == TYPE_DICTIONARY and str((to as Dictionary).get("map", "")) == map_id:
				commands.append(_linked_to(to, sids[index], shift))
	if not grown_legend.is_empty():
		commands.append({"type": "set_map", "key": "legend", "value": grown_legend})
	commands.append({"type": "set_map", "key": "ground", "value": new_rows})
	if shift != Vector2i.ZERO:
		commands.append({"type": "set_map", "key": "start", "value": [new_start.x, new_start.y]})
	var command := {
		"type": "batch",
		"name": "Resize the map to %d x %d" % [new_size.x, new_size.y],
		"shift": [left, top],
		"commands": commands,
	}
	return {"ok": true, "command": command, "size": new_size, "dropped": dropped}


## The indexes of data's objects whose "to" leads into the map `map_id`, in file order.
static func links_into(data: Dictionary, map_id: String) -> Array[int]:
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
		if typeof(to) == TYPE_DICTIONARY and str((to as Dictionary).get("map", "")) == map_id:
			out.append(index)
	return out


## The batch that keeps another map's doors into `map_id` landing right after map_id changed size by `shift`: each object
## of `data` that leads into map_id gets its "to" at moved by the same shift. {} when none leads there or nothing moved.
static func follow(data: Dictionary, sids: Array[int], map_id: String, shift: Vector2i) -> Dictionary:
	if shift == Vector2i.ZERO:
		return {}
	var commands: Array = []
	for index: int in links_into(data, map_id):
		if index < sids.size():
			var object: Dictionary = (data["objects"] as Array)[index]
			commands.append(_linked_to(object["to"], sids[index], shift))
	if commands.is_empty():
		return {}
	return {"type": "batch", "name": "Follow %s's new size" % map_id, "commands": commands}


## A set of one object's "to", with its "at" moved by `shift`; its other keys stay as they are.
static func _linked_to(to: Dictionary, sid: int, shift: Vector2i) -> Dictionary:
	var moved: Dictionary = to.duplicate(true)
	var at := OverworldMap.cell_of(moved.get("at", [0, 0])) + shift
	moved["at"] = [at.x, at.y]
	return {"type": "set", "sid": sid, "key": "to", "value": moved}


## A row after the map grew or shrank: each new column takes the old column it lies over (`left` columns to the right of
## it), or the fill where there is none. A row that shrinks from the left drops its first cells, and so on.
static func _shifted_row(row: String, left: int, width: int, glyph: String) -> String:
	var out := ""
	for x in width:
		var old_x := x - left
		out += row.substr(old_x, 1) if old_x >= 0 and old_x < row.length() else glyph
	return out


## Whether a thing whose footprint is `footprint` cells, with its corner at `at`, lies wholly inside `size`.
static func _footprint_inside(at: Vector2i, footprint: Vector2i, size: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x + footprint.x <= size.x and at.y + footprint.y <= size.y


static func _usable(glyph: String, legend: Dictionary) -> bool:
	return glyph.length() == 1 and not NEVER.contains(glyph) and not legend.has(glyph)


static func _inside(cell: Vector2i, size: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## The character at a cell of the rows, or "" when the cell is off them (a row shorter than the cell's column counts).
static func _char_at(rows: Array, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := String(rows[cell.y])
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row.substr(cell.x, 1)


## The map's rows as a list, or an empty list when the ground is not one.
static func _rows_of(data: Dictionary) -> Array:
	var ground: Variant = data.get("ground", [])
	return ground if typeof(ground) == TYPE_ARRAY else []


static func _legend_of(data: Dictionary) -> Dictionary:
	var legend: Variant = data.get("legend", {})
	return legend if typeof(legend) == TYPE_DICTIONARY else {}


## The size in cells: x is the longest row, y the number of rows.
static func _size_of(rows: Array) -> Vector2i:
	var width := 0
	for row: Variant in rows:
		width = maxi(width, String(row).length())
	return Vector2i(width, rows.size())


## The value as an int when it is a whole number (a float from JSON counts), else null.
static func _whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if number == floorf(number):
			return int(number)
	return null


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
