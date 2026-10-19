class_name StudioRow
extends RefCounted
## The cells of a row dragged out with Shift in place mode (Concept/v0.3/10, section 7.3), pure: pieces stand side by
## side along the longer way of the drag, touching without overlapping.
##
##   StudioRow.cells(Vector2i(2, 9), Vector2i(11, 9), Vector2i.ONE)   # ten cells, x = 2..11
##
## The cells are cursor cells (the bottom-middle cell of each piece, the one StudioWork.footing takes).


## A catalog line pair opts a one-cell prop into ordinary drag placement. Programmed things keep their own footprint
## and placement behavior; their art is repeated per cell by the game, rather than turned into modular boundaries.
static func is_line(template: Dictionary, entries: Dictionary) -> bool:
	if String(template.get("kind", "")) != "prop" or template.has("program"):
		return false
	if OverworldMap.cell_of(template.get("size", [1, 1])) != Vector2i.ONE:
		return false
	var raw_entry: Variant = entries.get(String(template.get("art", "")), {})
	if not raw_entry is Dictionary or not (raw_entry as Dictionary).get("line", {}) is Dictionary:
		return false
	var pair: Dictionary = (raw_entry as Dictionary).get("line", {})
	return entries.has(String(pair.get("horizontal", ""))) and entries.has(String(pair.get("vertical", "")))


## The selected piece for a click, or its matching orientation for a drag. Only the picture changes: eyedropped
## properties (solid, group, flip, etc.) belong to the instance and must survive choosing another direction.
static func oriented(template: Dictionary, start: Vector2i, end: Vector2i, entries: Dictionary) -> Dictionary:
	var out := template.duplicate(true)
	if start == end or not is_line(template, entries):
		return out
	var across := end - start
	var axis := "horizontal" if absi(across.x) >= absi(across.y) else "vertical"
	var entry: Dictionary = entries[String(template.art)]
	out["art"] = String((entry.line as Dictionary)[axis])
	return out


## The cursor cells of a row from `start` toward `end`: along the dominant axis (horizontal when the drag is as wide as
## it is tall), one piece every `size` cells so the footprints touch. The first is `start`; never empty. The other axis
## keeps `start`'s value.
static func cells(start: Vector2i, end: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [start]
	var across := end - start
	var horizontal := absi(across.x) >= absi(across.y)
	var step := maxi(size.x if horizontal else size.y, 1)
	var length := absi(across.x if horizontal else across.y)
	var direction := 1 if (across.x if horizontal else across.y) >= 0 else -1
	for index: int in range(1, length / step + 1):
		var along := index * step * direction
		out.append(start + (Vector2i(along, 0) if horizontal else Vector2i(0, along)))
	return out
