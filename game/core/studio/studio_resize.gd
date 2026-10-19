class_name StudioResize
extends RefCounted
## Changes a placed picture's footprint without changing its art or identity. The first footprint is kept as
## art_size while the picture is stretched. Buildings keep their original door and mask in art_shape so repeated
## resizes always sample the same geometry; returning to the original size restores it and removes both overrides.
## No asset pipeline is needed.


## A copied raw map object at `size`, or an error. Doors follow the relative center of their original cell;
## collision masks cover every resized cell touched by their original solid areas. The input is never changed.
static func object_at_size(object: Dictionary, size: Vector2i) -> Dictionary:
	if not String(object.get("kind", "")) in ["building", "prop"]:
		return _failed("only buildings and props can be resized")
	if size.x < 1 or size.y < 1:
		return _failed("a footprint needs positive whole tile dimensions")
	var old := _pair(object.get("size", [1, 1]))
	var original := _pair(object.get("art_size", [old.x, old.y]))
	if old.x < 1 or old.y < 1 or original.x < 1 or original.y < 1:
		return _failed("the original footprint needs positive whole tile dimensions")
	if size == old:
		return _failed("it is already %d × %d" % [size.x, size.y])
	var out := object.duplicate(true)
	if String(object.kind) == "prop" and size == Vector2i.ONE:
		out.erase("size")
	else:
		out["size"] = [size.x, size.y]
	if size == original:
		out.erase("art_size")
	else:
		out["art_size"] = [original.x, original.y]
	var basis := _shape_of(object)
	var basis_size := old
	if String(object.kind) == "building":
		if object.has("art_shape"):
			if not object.art_shape is Dictionary:
				return _failed("the original art_shape must be an object")
			basis = (object.art_shape as Dictionary).duplicate(true)
			basis_size = original
		else:
			# Older drafts may already carry art_size alone. Capture their current shape at that original size once.
			var captured := _resized_shape(basis, old, original)
			if not bool(captured.ok):
				return _failed(String(captured.error))
			basis = captured.value
			basis_size = original
		if size == original:
			out.erase("art_shape")
		else:
			out["art_shape"] = basis.duplicate(true)
	var resized := _resized_shape(basis, basis_size, size)
	if not bool(resized.ok):
		return _failed(String(resized.error))
	for key: String in ["door", "solid_rows", "solid_cells"]:
		out.erase(key)
		if (resized.value as Dictionary).has(key):
			out[key] = resized.value[key]
	# Missing doors use the map's [0, 0] default. Keep their original absence on reset, but make the moved default
	# explicit while stretched so a door still follows its relative cell center.
	if String(object.kind) == "building" and not basis.has("door") and size != original:
		out["door"] = [_cell_center(0, original.x, size.x), _cell_center(0, original.y, size.y)]
	return {"ok": true, "object": out, "error": ""}


static func _shape_of(object: Dictionary) -> Dictionary:
	var shape := {}
	for key: String in ["door", "solid_rows", "solid_cells"]:
		if object.has(key):
			shape[key] = object[key]
	return shape.duplicate(true)


static func _resized_shape(shape: Dictionary, old: Vector2i, size: Vector2i) -> Dictionary:
	if shape.has("solid_rows") and shape.has("solid_cells"):
		return {"ok": false, "error": "use solid_rows or solid_cells, not both"}
	var value := {}
	if shape.has("door"):
		var door := _pair(shape.door)
		# A hand-moved door is anchored to the footprint where it was edited. Its wall masks still use art_size.
		var door_size := _pair(shape.get("door_size", [old.x, old.y]))
		if door_size.x < 1 or door_size.y < 1:
			return {"ok": false, "error": "the original door_size needs positive whole tile dimensions"}
		if door.x < 0 or door.y < 0 or door.x >= door_size.x or door.y >= door_size.y:
			return {"ok": false, "error": "the door must be inside the original footprint"}
		value["door"] = [_cell_center(door.x, door_size.x, size.x), _cell_center(door.y, door_size.y, size.y)]
	if shape.has("solid_rows"):
		var rows := _resized_rows(shape.solid_rows, old.y, size.y)
		if not bool(rows.ok):
			return rows
		value["solid_rows"] = (shape.solid_rows as Array).duplicate(true) if old == size else rows.value
	if shape.has("solid_cells"):
		var cells := _resized_cells(shape.solid_cells, old, size)
		if not bool(cells.ok):
			return cells
		value["solid_cells"] = (shape.solid_cells as Array).duplicate(true) if old == size else cells.value
	# Reset restores the authored order and exact mask. A separately edited door still projects from its own anchor.
	return {"ok": true, "value": value}


static func _failed(error: String) -> Dictionary:
	return {"ok": false, "object": {}, "error": error}


## Invalid pairs return a negative sentinel so malformed data is refused rather than silently rounded.
static func _pair(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() == 2:
		for coordinate: Variant in value:
			if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
				return Vector2i(-1, -1)
			if float(coordinate) != floorf(float(coordinate)):
				return Vector2i(-1, -1)
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


static func _cell_center(cell: int, old: int, size: int) -> int:
	return clampi(floori((float(cell) + 0.5) * float(size) / float(old)), 0, size - 1)


## LEARN: conservative area resampling keeps thin walls when shrinking. Sampling only destination cell centers
## can erase a one-cell pillar entirely; using the old cell's covered interval keeps its corresponding area solid.
static func _covered(cell: int, old: int, size: int) -> Vector2i:
	var first := clampi(floori(float(cell) * float(size) / float(old)), 0, size - 1)
	var last := clampi(ceili(float(cell + 1) * float(size) / float(old)) - 1, first, size - 1)
	return Vector2i(first, last)


static func _resized_rows(value: Variant, old: int, size: int) -> Dictionary:
	if not value is Array:
		return {"ok": false, "error": "solid_rows must be an array"}
	var marked := {}
	for raw: Variant in value:
		if not (raw is int or raw is float) or not is_finite(float(raw)):
			return {"ok": false, "error": "solid_rows must contain whole rows inside the original footprint"}
		if float(raw) != floorf(float(raw)) or int(raw) < 0 or int(raw) >= old:
			return {"ok": false, "error": "solid_rows must contain whole rows inside the original footprint"}
		var span := _covered(int(raw), old, size)
		for y: int in range(span.x, span.y + 1):
			marked[y] = true
	var rows: Array[int] = []
	for y: int in size:
		if marked.has(y):
			rows.append(y)
	return {"ok": true, "value": rows}


static func _resized_cells(value: Variant, old: Vector2i, size: Vector2i) -> Dictionary:
	if not value is Array:
		return {"ok": false, "error": "solid_cells must be an array"}
	var marked := {}
	for raw: Variant in value:
		var cell := _pair(raw)
		if cell.x < 0 or cell.y < 0 or cell.x >= old.x or cell.y >= old.y:
			return {"ok": false, "error": "solid_cells must contain whole cells inside the original footprint"}
		var across := _covered(cell.x, old.x, size.x)
		var down := _covered(cell.y, old.y, size.y)
		for y: int in range(down.x, down.y + 1):
			for x: int in range(across.x, across.y + 1):
				marked[Vector2i(x, y)] = true
	var cells: Array = []
	for y: int in size.y:
		for x: int in size.x:
			if marked.has(Vector2i(x, y)):
				cells.append([x, y])
	return {"ok": true, "value": cells}
