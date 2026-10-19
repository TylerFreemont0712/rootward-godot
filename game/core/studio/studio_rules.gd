class_name StudioRules
extends RefCounted
## The checks of Lanternroot Studio (Concept/v0.3/10, section 9.5), pure: what is wrong with a draft world of maps (an
## error, which stops Publish) and what is doubtful (a warning, shown and accepted). The whole world is checked at once,
## since a warp or a person can name another map.
##
##   var problems := StudioRules.check({"maps": maps, "sids": sids, "terrain": terrain, "townsfolk": townsfolk,
##       "art": art, "footprints": footprints})
##   for problem in problems:                         # the errors first, then the warnings
##       print("%s %s: %s" % [problem.severity, problem.file, problem.message])
##
## `maps` is content path -> map data as parsed, drafts applied. `sids` (optional) is content path -> the session id of
## each object, in order. `art` is picture id -> true; `footprints` (optional) is picture id -> [w, h]. A problem about
## one object carries its sid and its cell; a problem about the whole file has sid -1 and cell (-1, -1). A message names
## an object by its picture (a person by its id, a warp as "warp") and its cell as "x, y".

## The cell of a problem that is about no cell.
const NOWHERE := Vector2i(-1, -1)
## The ground that terrain.jsonc calls water.
const WATER := "water"
## One step to each neighbouring cell, for the flood fill from the start.
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## The problems in `world`: the errors first, then the warnings, each group in the order of the maps' paths.
static func check(world: Dictionary) -> Array[Dictionary]:
	var maps: Dictionary = world.get("maps", {})
	var terrain: Dictionary = world.get("terrain", {})
	var paths := _sorted_keys(maps)
	var ctx := {
		"ids": {},
		"built": {},
		"people": {},
		"art": world.get("art", {}),
		"footprints": world.get("footprints", {}),
		"townsfolk": world.get("townsfolk", {}),
		"sids": world.get("sids", {}),
	}
	var loaded := {}
	for path in paths:
		var entry := _load(path, maps[path], terrain)
		loaded[path] = entry
		ctx.ids[entry.id] = true
		if not (entry.map as Dictionary).is_empty():
			ctx.built[entry.id] = entry.map
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	for path in paths:
		_check_map(path, loaded[path], ctx, errors, warnings)
	errors.append_array(warnings)
	return errors


static func _load(path: String, data: Dictionary, terrain: Dictionary) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var checked: Dictionary = ContentLoader._checked(
		OverworldContent.map_schema(), data.duplicate(true), path, "", diagnostics
	)
	var rejected: Array[String] = []
	for diagnostic: Dictionary in diagnostics:
		if diagnostic.severity == "error":
			rejected.append(diagnostic.message)
	var entry := {"id": String(data.get("id", "")), "checked": checked, "rejected": rejected, "map": {}, "build": []}
	if not checked.is_empty():
		var built := OverworldMap.build(checked, terrain)
		entry.map = built.map
		entry.build = built.problems
	return entry


static func _check_map(
	path: String, entry: Dictionary, ctx: Dictionary, errors: Array[Dictionary], warnings: Array[Dictionary]
) -> void:
	var file_id := path.get_file().get_basename()
	if String(entry.id) != file_id:
		errors.append(_problem("error", path, 'map id "%s" is not its file name "%s"' % [entry.id, file_id]))
	for message: String in entry.rejected:
		errors.append(_problem("error", path, message))
	if (entry.checked as Dictionary).is_empty():
		return
	var map: Dictionary = entry.map
	var sids: Array = ctx.sids.get(path, [])
	for found: Dictionary in entry.build:
		errors.append(_build_problem(path, map, found, sids))
	var reached := _reached(map)
	var objects: Array = entry.checked.objects
	for index: int in objects.size():
		_check_object(path, index, objects[index], map, reached, sids, ctx, errors, warnings)
	_check_water(path, map, sids, warnings)


static func _check_object(
	path: String,
	index: int,
	obj: Dictionary,
	map: Dictionary,
	reached: Dictionary,
	sids: Array,
	ctx: Dictionary,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	var sid := _sid(sids, index)
	var at := OverworldMap.cell_of(obj.at)
	match String(obj.kind):
		"person":
			_check_person(path, obj, sid, ctx, errors)
		"warp":
			_check_target(path, "warp", obj.to, at, sid, ctx, errors)
			if OverworldMap.inside(map, at) and not reached.has(at):
				var text := "warp at %s: cannot be reached from the start" % _text(at)
				warnings.append(_problem("warning", path, text, sid, at))
		_:
			_check_thing(path, obj, sid, map, reached, ctx, errors, warnings)


## A person: a known id (townsfolk.jsonc), and placed once across all the maps.
static func _check_person(path: String, obj: Dictionary, sid: int, ctx: Dictionary, errors: Array[Dictionary]) -> void:
	var id := String(obj.id)
	var at := OverworldMap.cell_of(obj.at)
	if not (ctx.townsfolk as Dictionary).has(id):
		errors.append(_problem("error", path, "%s at %s: not one of the townsfolk" % [id, _text(at)], sid, at))
	var people: Dictionary = ctx.people
	if people.has(id):
		var first: Dictionary = people[id]
		var where := "%s at %s: already placed at %s in %s"
		var text := where % [id, _text(at), _text(first.cell), String(first.file).get_file()]
		errors.append(_problem("error", path, text, sid, at))
	else:
		people[id] = {"file": path, "cell": at}


## A thing that is not a person or a warp: its picture and its footprint, and for a building its door.
static func _check_thing(
	path: String,
	obj: Dictionary,
	sid: int,
	map: Dictionary,
	reached: Dictionary,
	ctx: Dictionary,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	var art := String(obj.art)
	var at := OverworldMap.cell_of(obj.at)
	if not (ctx.art as Dictionary).has(art):
		errors.append(_problem("error", path, '%s at %s: no picture "%s"' % [art, _text(at), art], sid, at))
	if String(obj.kind) == "building":
		_check_building(path, obj, sid, map, reached, ctx, errors, warnings)
	if String(obj.kind) != "sign":
		_check_footprint(path, obj, sid, ctx, warnings)


## A building's door: where it leads (a door that leads somewhere is checked like a warp), a walkable cell in front of
## it, and reachable from the start.
static func _check_building(
	path: String,
	obj: Dictionary,
	sid: int,
	map: Dictionary,
	reached: Dictionary,
	ctx: Dictionary,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	var who := "door of %s" % obj.art
	var door := OverworldMap.cell_of(obj.at) + OverworldMap.cell_of(obj.door)
	var opens: bool = obj.has("to")
	if opens:
		_check_target(path, who, obj.to, door, sid, ctx, errors)
	if OverworldMap.blocked(map, door + Vector2i(0, 1)):
		var text := "%s at %s: nothing walkable in front of it" % [who, _text(door)]
		warnings.append(_problem("warning", path, text, sid, door))
	if opens and OverworldMap.inside(map, door) and not _door_reached(door, reached):
		var text := "%s at %s: cannot be reached from the start" % [who, _text(door)]
		warnings.append(_problem("warning", path, text, sid, door))


## A door or a warp must lead to a map that exists, to a cell that is walkable there (on the map, on walkable ground,
## not under a solid thing). `who` names the one that leads, `cell` is where it stands.
static func _check_target(
	path: String, who: String, to: Dictionary, cell: Vector2i, sid: int, ctx: Dictionary, errors: Array[Dictionary]
) -> void:
	var target := String(to.get("map", ""))
	var at := OverworldMap.cell_of(to.get("at", [0, 0]))
	if not (ctx.ids as Dictionary).has(target):
		var missing := '%s at %s: leads to map "%s", which is not one of the maps' % [who, _text(cell), target]
		errors.append(_problem("error", path, missing, sid, cell))
		return
	# The destination map already has its own schema/build problem; avoid inventing a second link problem from its
	# unavailable runtime form.
	if not (ctx.built as Dictionary).has(target):
		return
	var state := StudioPeopleIndex.link_state("warp", to, ctx.built)
	if state == "missing_map":
		var text := '%s at %s: leads to map "%s", which is not one of the maps' % [who, _text(cell), target]
		errors.append(_problem("error", path, text, sid, cell))
	elif state == "off_map":
		var text := "%s at %s: leads to %s at %s, which is not walkable" % [who, _text(cell), target, _text(at)]
		errors.append(_problem("error", path, text, sid, cell))
	elif state == "loop":
		var text := "%s at %s: leads to %s at %s, which triggers another entrance" % [who, _text(cell), target, _text(at)]
		errors.append(_problem("error", path, text, sid, cell))
	elif state == "blocked":
		var text := "%s at %s: leads to %s at %s, which is not walkable" % [who, _text(cell), target, _text(at)]
		errors.append(_problem("error", path, text, sid, cell))
	elif state == "invalid_facing":
		var text := "%s at %s: has an invalid facing at %s in %s" % [who, _text(cell), _text(at), target]
		errors.append(_problem("error", path, text, sid, cell))


## A picture drawn for another footprint than the thing's size (the world pipeline's footprint, world.json). A thing
## that takes code (a `program`) is drawn once on each tile of its footprint (TownMapView._add_thing), so its picture is
## one tile's.
static func _check_footprint(
	path: String, obj: Dictionary, sid: int, ctx: Dictionary, warnings: Array[Dictionary]
) -> void:
	var art := String(obj.art)
	var footprints: Dictionary = ctx.footprints
	if not footprints.has(art):
		return
	var drawn := OverworldMap.cell_of(footprints[art])
	var size := OverworldMap.cell_of(obj.get("art_size", obj.size))
	if obj.has("program") and drawn == Vector2i.ONE:
		size = Vector2i.ONE
	if size != drawn:
		var at := OverworldMap.cell_of(obj.at)
		var text := "%s at %s: size %s, but its picture is drawn for %s" % [art, _text(at), _size(size), _size(drawn)]
		warnings.append(_problem("warning", path, text, sid, at))


## Water under a solid thing: one warning per thing, at the first water cell under it.
static func _check_water(path: String, map: Dictionary, sids: Array, warnings: Array[Dictionary]) -> void:
	var wet := {}
	for cell: Vector2i in map.solid:
		var index: int = map.solid[cell]
		if not wet.has(index) and OverworldMap.terrain_at(map, cell) == WATER:
			wet[index] = cell
	var objects: Array = map.objects
	for index: int in objects.size():
		if not wet.has(index):
			continue
		var cell: Vector2i = wet[index]
		var text := "%s at %s: water under it" % [_name(objects[index]), _text(cell)]
		warnings.append(_problem("warning", path, text, _sid(sids, index), cell))


## A problem from OverworldMap.build, placed on the thing or the cell it names (its `code`, `index` and `cell`), with
## its words made plain; anything else keeps the builder's message and its cell.
static func _build_problem(path: String, map: Dictionary, found: Dictionary, sids: Array) -> Dictionary:
	var index := int(found.get("index", -1))
	var cell: Vector2i = found.get("cell", Vector2i(-1, -1))
	var objects: Array = map.objects
	var obj: Dictionary = objects[index] if index >= 0 and index < objects.size() else {}
	match String(found.get("code", "")):
		"off_map":
			return _problem(
				"error", path, "%s at %s: stands off the map" % [_name(obj), _text(cell)], _sid(sids, index), cell
			)
		"overlap":
			var text := "%s at %s: two things stand on this cell" % [_name(obj), _text(cell)]
			return _problem("error", path, text, _sid(sids, index), cell)
		"start_off":
			return _problem("error", path, "the start at %s is off the map" % _text(cell), -1, cell)
	return _problem("error", path, String(found.get("message", "")), _sid(sids, index), cell)


## The cells the player can walk to from the start: a flood fill over walkable cells that nothing solid covers, in four
## directions. The start itself counts, whatever it stands on. Off the map there is no start, and nothing is reached.
static func _reached(map: Dictionary) -> Dictionary:
	var reached := {}
	if not OverworldMap.inside(map, map.start):
		return reached
	var queue: Array[Vector2i] = [map.start]
	reached[map.start] = true
	var next := 0
	while next < queue.size():
		var cell: Vector2i = queue[next]
		next += 1
		for step: Vector2i in NEIGHBOURS:
			var there := cell + step
			if not reached.has(there) and not OverworldMap.blocked(map, there):
				reached[there] = true
				queue.append(there)
	return reached


## A door counts as reached when its own cell is, or a cell next to it is (the door may sit on a wall of the picture).
static func _door_reached(door: Vector2i, reached: Dictionary) -> bool:
	if reached.has(door):
		return true
	for step: Vector2i in NEIGHBOURS:
		if reached.has(door + step):
			return true
	return false


static func _problem(severity: String, file: String, message: String, sid := -1, cell := NOWHERE) -> Dictionary:
	return {"severity": severity, "file": file, "message": message, "sid": sid, "cell": cell}


## The session id of the object at `index`, or -1 when the caller gave no ids.
static func _sid(sids: Array, index: int) -> int:
	return int(sids[index]) if index >= 0 and index < sids.size() else -1


## An object's name in a message: its picture, a person's id, or "warp".
static func _name(obj: Dictionary) -> String:
	match String(obj.kind):
		"person":
			return String(obj.id)
		"warp":
			return "warp"
	return String(obj.get("art", ""))


static func _text(cell: Vector2i) -> String:
	return "%d, %d" % [cell.x, cell.y]


static func _size(size: Vector2i) -> String:
	return "%d x %d" % [size.x, size.y]


static func _sorted_keys(dict: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	keys.assign(dict.keys())
	keys.sort()
	return keys
