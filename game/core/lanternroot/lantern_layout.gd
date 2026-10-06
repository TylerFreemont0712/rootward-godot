class_name LanternLayout
extends RefCounted
## The town as the player's program draws it (ADR-0055): one house per module, one lantern per letter it answers, one
## rope bridge per import between two of the player's modules. Nothing here is placed by hand except where a house
## stands; the picture is read from the code, so the town is always an honest map of the program's dependencies.
##
##   {houses: [{module, name, at: Vector2 (in a 1000 x 1000 square), roof, own, lanterns: [{id, title, state}],
##              gremlins}], bridges: [{from, to}]}


static func of(catalog: Dictionary, town: Dictionary) -> Dictionary:
	var files: Dictionary = town.files
	var modules := ordered_modules(catalog, town)
	var houses: Array[Dictionary] = []
	var huts: Array = catalog.town.huts
	var hut := 0
	for module in modules:
		var spot: Dictionary = (catalog.town.houses as Dictionary).get(module, {})
		var at := Vector2(500, 500)
		var own := spot.is_empty()
		if own:
			var point: Array = huts[hut % huts.size()] if not huts.is_empty() else [500, 500]
			at = Vector2(float(point[0]), float(point[1]))
			hut += 1
		else:
			at = Vector2(float(spot.at[0]), float(spot.at[1]))
		var lanterns := _lanterns(catalog, town, module)
		houses.append(
			{
				"module": module,
				"name": module if own else String(spot.name),
				"at": at,
				"roof": "#5a4632" if own else String(spot.roof),
				"own": own,
				"lanterns": lanterns,
				"gremlins": lanterns.filter(func(l: Dictionary) -> bool: return l.state == LanternRules.DARK).size(),
			}
		)
	var bridges: Array[Dictionary] = []
	for module in modules:
		for target in LanternCode.imports(town.language, String(files[module]), modules, module):
			bridges.append({"from": module, "to": target})
	return {"houses": houses, "bridges": bridges}


## The town's modules: the houses content places, in the order the letters ask for them, then the player's own.
static func ordered_modules(catalog: Dictionary, town: Dictionary) -> Array[String]:
	var files: Dictionary = town.files
	var modules: Array[String] = []
	for id: String in catalog.order:
		var module := String(catalog.requests[id].module)
		if files.has(module) and not module in modules:
			modules.append(module)
	for module: String in files:
		if not module in modules:
			modules.append(module)
	return modules


static func _lanterns(catalog: Dictionary, town: Dictionary, module: String) -> Array[Dictionary]:
	var lanterns: Array[Dictionary] = []
	var seen := {}
	for id: String in catalog.order:
		var request: Dictionary = catalog.requests[id]
		if request.module != module:
			continue
		var lantern := LanternRules.lantern_of(catalog, id)
		if seen.has(lantern) or not (lantern in town.read or LanternRules.is_solved(town, lantern)):
			continue
		seen[lantern] = true
		(
			lanterns
			. append(
				{
					"id": lantern,
					"title": String(catalog.requests[lantern].title),
					"state": String(town.lanterns.get(lantern, "unlit")),
				}
			)
		)
	return lanterns
