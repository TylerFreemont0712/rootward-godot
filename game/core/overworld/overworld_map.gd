class_name OverworldMap
extends RefCounted
## One map of Lanternroot's overworld (ADR-0061), built from content: a grid of ground, and the things standing on it.
##
##   var built := OverworldMap.build(data, terrain)   # {map, errors}
##   OverworldMap.blocked(map, Vector2i(3, 4), people)   # true for water, walls, houses, props, and anyone in `people`
##
## The ground is rows of characters, each one a terrain through the map's `legend` ("." is grass, say). Things stand
## on cells: a building covers its footprint except its door, which leads somewhere (`to`; without it the door stays
## shut); a prop or a sign is solid unless it says otherwise;
## a townsperson stands on a cell; a warp is a cell that leads somewhere when stepped on (the mat inside a door).
## Cells are Vector2i in memory; content and saves use [x, y].

const FACINGS: Array[String] = ["down", "up", "left", "right"]


static func build(data: Dictionary, terrain: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var rows: Array = data.get("ground", [])
	var height := rows.size()
	var width := 0 if rows.is_empty() else String(rows[0]).length()
	var legend: Dictionary = data.get("legend", {})
	var ground := PackedStringArray()
	var walk := PackedByteArray()
	ground.resize(width * height)
	walk.resize(width * height)
	for y in height:
		var row := String(rows[y])
		if row.length() != width:
			errors.append("ground row %d is %d wide, the map is %d" % [y, row.length(), width])
		for x in width:
			var ch := row.substr(x, 1) if x < row.length() else ""
			var kind := String(legend.get(ch, ""))
			if kind == "" or not terrain.has(kind):
				errors.append("ground row %d column %d: %s is not in the legend" % [y, x, ch])
				kind = "void"
			ground[y * width + x] = kind
			walk[y * width + x] = 1 if bool((terrain.get(kind, {}) as Dictionary).get("walk", false)) else 0
	var map := {
		"id": String(data.get("id", "")),
		"name": String(data.get("name", "")),
		"width": width,
		"height": height,
		"ground": ground,
		"walk": walk,
		"objects": [],
		"solid": {},
		"warps": {},
		"people": [],
		"start": cell_of(data.get("start", [0, 0])),
		"facing": String(data.get("facing", "down")),
		"interior": bool(data.get("interior", false)),
		"music": String(data.get("music", "")),
	}
	var objects: Array = data.get("objects", [])
	for i in objects.size():
		_place(map, objects[i] as Dictionary, i, errors)
	if not inside(map, map.start):
		errors.append("start %s is off the map" % map.start)
	return {"map": map, "errors": errors}


static func _place(map: Dictionary, object: Dictionary, index: int, errors: Array[String]) -> void:
	var placed := object.duplicate(true)
	var at := cell_of(object.get("at", [0, 0]))
	var size := cell_of(object.get("size", [1, 1]))
	placed.at = at
	placed.size = size
	placed.index = index
	var kind := String(object.get("kind", ""))
	(map.objects as Array).append(placed)
	match kind:
		"building":
			# A door that leads somewhere is a cell to walk into; a building with nowhere to go keeps its door shut
			# (solid like the walls), and reading it says what the place is.
			var door := at + cell_of(object.get("door", [0, 0]))
			var opens := object.has("to")
			placed.door_cell = door
			for y in size.y:
				for x in size.x:
					var cell := at + Vector2i(x, y)
					if cell != door or not opens:
						_solid(map, cell, index, errors)
			if opens:
				map.warps[door] = _target(object.to)
		"prop", "sign":
			if bool(object.get("solid", true)):
				for y in size.y:
					for x in size.x:
						_solid(map, at + Vector2i(x, y), index, errors)
		"person":
			(map.people as Array).append(placed)
		"warp":
			map.warps[at] = _target(object.get("to", {}))
		_:
			errors.append("thing %d has an unknown kind %s" % [index, kind])
	if not inside(map, at):
		errors.append("%s %d stands off the map at %s" % [kind, index, at])


static func _solid(map: Dictionary, cell: Vector2i, index: int, errors: Array[String]) -> void:
	if map.solid.has(cell):
		errors.append("two things stand on %s" % cell)
	map.solid[cell] = index


static func _target(to: Dictionary) -> Dictionary:
	return {
		"map": String(to.get("map", "")),
		"at": cell_of(to.get("at", [0, 0])),
		"facing": String(to.get("facing", "")),
	}


static func cell_of(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and (value as Array).size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


static func inside(map: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < int(map.width) and cell.y < int(map.height)


static func size_of(map: Dictionary) -> Vector2i:
	return Vector2i(int(map.width), int(map.height))


static func terrain_at(map: Dictionary, cell: Vector2i) -> String:
	if not inside(map, cell):
		return "void"
	return (map.ground as PackedStringArray)[cell.y * int(map.width) + cell.x]


## Whether `cell` can be walked onto: on the map, on walkable ground, not inside anything solid, nobody standing there
## (`people` holds the cells townspeople stand on now, cell -> anything).
static func blocked(map: Dictionary, cell: Vector2i, people: Dictionary = {}) -> bool:
	if not inside(map, cell):
		return true
	if (map.walk as PackedByteArray)[cell.y * int(map.width) + cell.x] == 0:
		return true
	return map.solid.has(cell) or people.has(cell)


## Where stepping onto `cell` takes the player, or {} if it is an ordinary cell.
static func warp_at(map: Dictionary, cell: Vector2i) -> Dictionary:
	return map.warps.get(cell, {})


## The thing that fills `cell` (a sign, a prop, a house), or {}.
static func thing_at(map: Dictionary, cell: Vector2i) -> Dictionary:
	if not map.solid.has(cell):
		return {}
	return (map.objects as Array)[int(map.solid[cell])]


static func ahead(cell: Vector2i, facing: String) -> Vector2i:
	return cell + BootsRules.STEPS.get(facing, Vector2i.ZERO)
