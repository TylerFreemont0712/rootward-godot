class_name OverworldMap
extends RefCounted
## One map of Lanternroot's overworld (ADR-0061), built from content: a grid of ground, and the things standing on it.
##
##   var built := OverworldMap.build(data, terrain)   # {map, errors}
##   OverworldMap.blocked(map, Vector2i(3, 4), people)   # true for water, walls, houses, props, and anyone in `people`
##
## The ground is rows of characters, each one a terrain through the map's `legend` ("." is grass, say). Things stand
## on cells: a building covers its footprint except its door, which leads somewhere (`to`; without it the door stays
## shut); `solid_rows` can narrow a building's collision to its wall line and `solid_cells` can trace an irregular
## base, so people can walk behind roofs and around a tree trunk; a prop or sign is solid unless it says otherwise;
## a townsperson stands on a cell; a warp is a cell that leads somewhere when stepped on (the mat inside a door).
## Cells are Vector2i in memory; content and saves use [x, y].

const FACINGS: Array[String] = ["down", "up", "left", "right"]


## `errors` are the problems' messages; `problems` are the same, each with a `code` (ground_width, ground_legend,
## unknown_kind, off_map, overlap, start_off), the object's `index` (-1 when none) and the `cell` (Vector2i(-1, -1)
## when none), so a tool such as Lanternroot Studio can point at what is wrong without reading the words.
static func build(data: Dictionary, terrain: Dictionary) -> Dictionary:
	var problems: Array[Dictionary] = []
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
			var wide := "ground row %d is %d wide, the map is %d" % [y, row.length(), width]
			_problem(problems, "ground_width", wide, -1, Vector2i(0, y))
		for x in width:
			var ch := row.substr(x, 1) if x < row.length() else ""
			var kind := String(legend.get(ch, ""))
			if kind == "" or not terrain.has(kind):
				var unknown := "ground row %d column %d: %s is not in the legend" % [y, x, ch]
				_problem(problems, "ground_legend", unknown, -1, Vector2i(x, y))
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
		_place(map, objects[i] as Dictionary, i, problems)
	if not inside(map, map.start):
		_problem(problems, "start_off", "start %s is off the map" % map.start, -1, map.start)
	var errors: Array[String] = []
	for problem: Dictionary in problems:
		errors.append(String(problem.message))
	return {"map": map, "errors": errors, "problems": problems}


static func _problem(problems: Array[Dictionary], code: String, message: String, index: int, cell: Vector2i) -> void:
	problems.append({"code": code, "message": message, "index": index, "cell": cell})


static func _place(map: Dictionary, object: Dictionary, index: int, problems: Array[Dictionary]) -> void:
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
			# (solid like the walls), and reading it says what the place is. Buildings normally block the whole footprint;
			# the collision mask lets a walker pass behind a roof and be drawn behind the building.
			var door := at + cell_of(object.get("door", [0, 0]))
			var opens := object.has("to")
			placed.door_cell = door
			var collision_cells: Array[Vector2i] = []
			if object.has("solid_cells"):
				if object.has("solid_rows"):
					_problem(
						problems,
						"building_collision",
						"building %d must use solid_cells or solid_rows, not both" % index,
						index,
						at
					)
				var cells: Variant = object.get("solid_cells")
				if cells is Array:
					for point: Variant in cells:
						if (
							point is Array
							and point.size() == 2
							and point[0] is int
							and point[1] is int
							and int(point[0]) >= 0
							and int(point[0]) < size.x
							and int(point[1]) >= 0
							and int(point[1]) < size.y
						):
							var cell := at + Vector2i(int(point[0]), int(point[1]))
							if not collision_cells.has(cell):
								collision_cells.append(cell)
						else:
							_problem(
								problems,
								"building_solid_cells",
								"building %d has a solid cell outside its footprint" % index,
								index,
								at
							)
				else:
					_problem(
						problems,
						"building_solid_cells",
						"building %d solid_cells must be an array" % index,
						index,
						at
					)
					for y in size.y:
						for x in size.x:
							collision_cells.append(at + Vector2i(x, y))
			else:
				var solid_rows: Array = []
				if not object.has("solid_rows"):
					for y in size.y:
						solid_rows.append(y)
				elif object.get("solid_rows") is Array:
					for row: Variant in object.solid_rows:
						if row is int and int(row) >= 0 and int(row) < size.y:
							if not solid_rows.has(int(row)):
								solid_rows.append(int(row))
						else:
							_problem(
								problems,
								"building_solid_rows",
								"building %d has a solid row outside its footprint" % index,
								index,
								at
							)
				else:
					_problem(
						problems,
						"building_solid_rows",
						"building %d solid_rows must be an array" % index,
						index,
						at
					)
					for y in size.y:
						solid_rows.append(y)
				for y: int in solid_rows:
					for x in size.x:
						collision_cells.append(at + Vector2i(x, y))
			for cell: Vector2i in collision_cells:
				if cell != door or not opens:
					_solid(map, cell, index, problems)
			if opens:
				map.warps[door] = _target(object.to)
		"prop", "sign":
			if bool(object.get("solid", true)):
				for y in size.y:
					for x in size.x:
						_solid(map, at + Vector2i(x, y), index, problems)
		"person":
			(map.people as Array).append(placed)
		"warp":
			map.warps[at] = _target(object.get("to", {}))
		_:
			_problem(problems, "unknown_kind", "thing %d has an unknown kind %s" % [index, kind], index, at)
	if not inside(map, at):
		_problem(problems, "off_map", "%s %d stands off the map at %s" % [kind, index, at], index, at)


static func _solid(map: Dictionary, cell: Vector2i, index: int, problems: Array[Dictionary]) -> void:
	if map.solid.has(cell):
		_problem(problems, "overlap", "two things stand on %s" % cell, index, cell)
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
## (`people` holds the cells townspeople stand on now, cell -> anything). `open` holds the cells of solid things that
## are open now (TownThings.open_cells): a solid cell in it is walkable, as the ground under it is.
static func blocked(map: Dictionary, cell: Vector2i, people: Dictionary = {}, open: Dictionary = {}) -> bool:
	if not inside(map, cell):
		return true
	if (map.walk as PackedByteArray)[cell.y * int(map.width) + cell.x] == 0:
		return true
	if people.has(cell):
		return true
	return map.solid.has(cell) and not open.has(cell)


## Where stepping onto `cell` takes the player, or {} if it is an ordinary cell.
static func warp_at(map: Dictionary, cell: Vector2i) -> Dictionary:
	return map.warps.get(cell, {})


## The thing that fills `cell` (a sign, a prop, a house), or {}.
static func thing_at(map: Dictionary, cell: Vector2i) -> Dictionary:
	if not map.solid.has(cell):
		return {}
	return (map.objects as Array)[int(map.solid[cell])]


## Any prop whose footprint covers `cell`, solid or not (a crop row you walk over, a rug), or {}. The last one drawn
## wins, as it is the one on top. For what a cell holds beyond what blocks it: a pickup under a walkable crop row.
static func prop_over(map: Dictionary, cell: Vector2i) -> Dictionary:
	var found := {}
	for object: Variant in map.get("objects", []):
		if not object is Dictionary or String((object as Dictionary).get("kind", "")) != "prop":
			continue
		var at := cell_of((object as Dictionary).get("at", [-1, -1]))
		var size := cell_of((object as Dictionary).get("size", [1, 1]))
		if Rect2i(at, size).has_point(cell):
			found = object
	return found


static func ahead(cell: Vector2i, facing: String) -> Vector2i:
	return cell + BootsRules.STEPS.get(facing, Vector2i.ZERO)
