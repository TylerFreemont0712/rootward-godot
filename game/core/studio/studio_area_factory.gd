class_name StudioAreaFactory
extends RefCounted
## Creates plain, walkable outdoor maps for Lanternroot Studio. These are separate map scenes; entrances can connect
## them later, and Publish writes each one as its own map file.

const MIN_DIMENSION := 8
## GroundLayer bakes map tiles into textures, so keep a single map within a predictable memory budget.
const MAX_DIMENSION := StudioLand.MAX_DIMENSION
const MAX_ID_LENGTH := 64
const ID_GLYPHS := "abcdefghijklmnopqrstuvwxyz0123456789"


## A safe, readable map id derived from a title. Names outside ASCII use "area" and remain unchanged as display names.
static func safe_id(title: String) -> String:
	var out := ""
	var lowered := title.to_lower()
	for index in lowered.length():
		var glyph := lowered.substr(index, 1)
		if ID_GLYPHS.contains(glyph):
			out += glyph
		elif not out.is_empty() and not out.ends_with("-"):
			out += "-"
	while out.ends_with("-"):
		out = out.substr(0, out.length() - 1)
	if out.is_empty():
		return "area"
	return _trim_id(out)


## The first id derived from `title` that is not already in `taken`.
static func unique_id(title: String, taken: Array[String]) -> String:
	var base := safe_id(title)
	if not taken.has(base):
		return base
	var suffix := 2
	var candidate := ""
	while true:
		var ending := "-%d" % suffix
		candidate = _trim_id(base.substr(0, MAX_ID_LENGTH - ending.length()) + ending)
		if not taken.has(candidate):
			break
		suffix += 1
	return candidate


## Whether an id is a safe map filename component.
static func valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > MAX_ID_LENGTH or id.begins_with("-") or id.begins_with(".") or id.ends_with("-") or id.ends_with("."):
		return false
	var previous_separator := false
	for index in id.length():
		var glyph := id.substr(index, 1)
		if glyph in ["-", "."]:
			if previous_separator:
				return false
			previous_separator = true
		elif ID_GLYPHS.contains(glyph):
			previous_separator = false
		else:
			return false
	return true


## A walkable outdoor map with one ground, no placed objects, and the chosen start. Returns {ok, data} or
## {ok: false, error}; it does not write files or mutate the terrain catalog.
static func create_data(
	id: String,
	title: String,
	size: Vector2i,
	ground: String,
	terrain: Dictionary,
	start: Vector2i = Vector2i(2, 2),
	facing: String = "down"
) -> Dictionary:
	var name := title.strip_edges()
	if not valid_id(id):
		return _failed("use a lowercase map id with letters, numbers and single hyphens or dots")
	if name.is_empty():
		return _failed("give the area a name")
	if name.length() > 80:
		return _failed("area names can be at most 80 characters")
	if size.x < MIN_DIMENSION or size.y < MIN_DIMENSION or size.x > MAX_DIMENSION or size.y > MAX_DIMENSION:
		return _failed("area dimensions must be between %d and %d tiles" % [MIN_DIMENSION, MAX_DIMENSION])
	if start.x < 0 or start.y < 0 or start.x >= size.x or start.y >= size.y:
		return _failed("the start cell must be inside the area")
	if facing not in ["up", "down", "left", "right"]:
		return _failed("choose a valid start facing")
	var surface: Variant = terrain.get(ground, {})
	if not surface is Dictionary or String(surface.get("paint", "")) != "outdoor" or not bool(surface.get("walk", false)):
		return _failed("choose a walkable outdoor ground")
	var glyph := StudioLand.free_char({}, ground)
	if glyph.is_empty():
		return _failed("no map symbol is available for %s" % ground)
	var rows: Array[String] = []
	for _y in size.y:
		rows.append(glyph.repeat(size.x))
	return {
		"ok": true,
		"error": "",
		"data": {
			"id": id,
			"name": name,
			"interior": false,
			"legend": {glyph: ground},
			"ground": rows,
			"start": [start.x, start.y],
			"facing": facing,
			"objects": [],
		},
	}


static func _failed(error: String) -> Dictionary:
	return {"ok": false, "error": error, "data": {}}


static func _trim_id(id: String) -> String:
	var trimmed := id.substr(0, mini(id.length(), MAX_ID_LENGTH))
	while trimmed.ends_with("-") or trimmed.ends_with("."):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed
