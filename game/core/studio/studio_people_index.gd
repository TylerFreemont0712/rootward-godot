class_name StudioPeopleIndex
extends RefCounted
## Read-only People & Doors views over draft-aware map documents and the loaded catalog.
## All coordinates are cells. This index never opens sessions, changes documents or resolves file paths.


## One record per townsfolk definition, including every placement so duplicate IDs stay visible and repairable.
static func people(townsfolk: Dictionary, maps: Dictionary, schedules: Dictionary = {}) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var known: Dictionary = {}
	var placed := _locations_by_person(maps)
	for id_variant: Variant in townsfolk.keys():
		var id := String(id_variant)
		var person: Variant = townsfolk[id_variant]
		if not person is Dictionary:
			continue
		known[id] = true
		var definition: Dictionary = person
		var locations: Array[Dictionary] = []
		locations.assign(placed.get(id, []))
		var raw_schedule: Variant = schedules.get(id, {})
		var schedule: Dictionary = raw_schedule if raw_schedule is Dictionary else {}
		rows.append(
			{
				"id": id,
				"name": String(definition.get("name", id)),
				"title": String(definition.get("title", "")),
				"talk": String(definition.get("talk", id)),
				"locations": locations,
				"schedule": schedule.duplicate(true),
				"scheduled": not schedule.is_empty(),
				"unknown": false,
			}
		)
	# Broken or legacy map references remain visible, even when their definition disappeared from townsfolk data.
	for id_variant: Variant in placed:
		var id := String(id_variant)
		if known.has(id):
			continue
		var raw_schedule: Variant = schedules.get(id, {})
		var schedule: Dictionary = raw_schedule if raw_schedule is Dictionary else {}
		rows.append(
			{
				"id": id,
				"name": id,
				"title": "",
				"talk": id,
				"locations": placed[id],
				"schedule": schedule.duplicate(true),
				"scheduled": not schedule.is_empty(),
				"unknown": true,
			}
		)
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var by_name := String(a.name).naturalnocasecmp_to(String(b.name))
			return by_name < 0 if by_name != 0 else String(a.id) < String(b.id)
	)
	return rows


## Buildings and warps on one map, with their link state derived from the candidate world.
static func entrances(map_id: String, source: Dictionary, maps: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var objects: Variant = source.get("objects", [])
	if not objects is Array:
		return out
	for index in (objects as Array).size():
		var value: Variant = (objects as Array)[index]
		if not value is Dictionary:
			continue
		var object: Dictionary = value
		var kind := String(object.get("kind", ""))
		if kind not in ["building", "warp"]:
			continue
		var cell := OverworldMap.cell_of(object.get("at", [0, 0]))
		var size := OverworldMap.cell_of(object.get("size", [1, 1]))
		if kind == "building":
			cell += OverworldMap.cell_of(object.get("door", [0, maxi(size.y - 1, 0)]))
		var raw_target: Variant = object.get("to", {})
		var target: Dictionary = raw_target if raw_target is Dictionary else {}
		var state := link_state(kind, target, maps)
		var problem := {}
		if state not in ["valid", "closed"]:
			problem = {
				"code": state, "severity": "error", "map": map_id, "index": index,
				"cell": cell, "source": object.duplicate(true), "target": target.duplicate(true),
			}
		var raw_destination: Variant = maps.get(String(target.get("map", "")), {})
		var is_interior := bool((raw_destination as Dictionary).get("interior", false)) if raw_destination is Dictionary else false
		out.append(
			{
				"map": map_id,
				"index": index,
				"kind": kind,
				"art": String(object.get("art", "")),
				"name": String(object.get("name", object.get("art", kind))),
				"cell": cell,
				"target": target.duplicate(true),
				"state": state,
				"problem": problem,
				"interior": is_interior,
				"source": object.duplicate(true),
			}
		)
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var first: Vector2i = a.cell
			var second: Vector2i = b.cell
			if first.y != second.y:
				return first.y < second.y
			if first.x != second.x:
				return first.x < second.x
			return int(a.index) < int(b.index)
	)
	return out


## New interior drafts with no incoming entrance. A generated room can be reconnected to its original building when its
## return warp still lands directly in front of one unlinked building; ambiguous or stale matches stay locate-only.
static func unlinked_room_drafts(maps: Dictionary, new_map_ids: Array[String]) -> Array[Dictionary]:
	var incoming := {}
	for source_id_variant: Variant in maps:
		var source_id := String(source_id_variant)
		var source_map: Variant = maps[source_id_variant]
		if not source_map is Dictionary:
			continue
		var source_objects: Variant = (source_map as Dictionary).get("objects", [])
		if not source_objects is Array:
			continue
		for value: Variant in source_objects:
			if not value is Dictionary:
				continue
			var target: Variant = (value as Dictionary).get("to")
			if target is Dictionary and String((target as Dictionary).get("map", "")) == source_id:
				continue
			if target is Dictionary:
				var target_id := String((target as Dictionary).get("map", ""))
				if target_id != "":
					incoming[target_id] = true
	var ids := new_map_ids.duplicate()
	ids.sort()
	var out: Array[Dictionary] = []
	for room_id: String in ids:
		var raw_room: Variant = maps.get(room_id, {})
		if not raw_room is Dictionary or not bool((raw_room as Dictionary).get("interior", false)) or incoming.has(room_id):
			continue
		var room: Dictionary = raw_room
		var return_target := _room_return_target(room_id, room)
		var candidate := _matching_unlinked_building(maps, return_target)
		out.append(
			{
				"id": room_id,
				"name": String(room.get("name", room_id)),
				"source": room.duplicate(true),
				"return": return_target,
				"building_map": String(candidate.get("map", "")),
				"building_index": int(candidate.get("index", -1)),
				"building": candidate.get("source", {}),
			}
		)
	return out


## Every other map object that leads to `map_id`, with its raw source for safe diagnostics and revalidation.
static func incoming_links(maps: Dictionary, map_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for source_id_variant: Variant in maps:
		var source_id := String(source_id_variant)
		if source_id == map_id:
			continue
		var raw_source: Variant = maps[source_id_variant]
		if not raw_source is Dictionary:
			continue
		var objects: Variant = (raw_source as Dictionary).get("objects", [])
		if not objects is Array:
			continue
		for index: int in (objects as Array).size():
			var value: Variant = (objects as Array)[index]
			if not value is Dictionary:
				continue
			var object: Dictionary = value
			var target: Variant = object.get("to")
			if not target is Dictionary or String((target as Dictionary).get("map", "")) != map_id:
				continue
			out.append({"map": source_id, "index": index, "source": object.duplicate(true)})
	return out


static func _room_return_target(room_id: String, room: Dictionary) -> Dictionary:
	var targets: Array[Dictionary] = []
	var objects: Variant = room.get("objects", [])
	if not objects is Array:
		return {}
	for value: Variant in objects:
		if not value is Dictionary or String((value as Dictionary).get("kind", "")) != "warp":
			continue
		var raw_target: Variant = (value as Dictionary).get("to")
		if not raw_target is Dictionary:
			continue
		var target: Dictionary = raw_target
		if String(target.get("map", "")) != room_id:
			targets.append(target.duplicate(true))
	return targets[0] if targets.size() == 1 else {}


static func _matching_unlinked_building(maps: Dictionary, target: Dictionary) -> Dictionary:
	var map_id := String(target.get("map", ""))
	var raw_map: Variant = maps.get(map_id, {})
	if map_id == "" or not raw_map is Dictionary:
		return {}
	var cell := OverworldMap.cell_of(target.get("at", [0, 0]))
	var objects: Variant = (raw_map as Dictionary).get("objects", [])
	if not objects is Array:
		return {}
	var matches: Array[Dictionary] = []
	for index: int in (objects as Array).size():
		var value: Variant = (objects as Array)[index]
		if not value is Dictionary:
			continue
		var object: Dictionary = value
		if String(object.get("kind", "")) != "building" or object.has("to"):
			continue
		if StudioDoors.front_of(object) == cell:
			matches.append({"map": map_id, "index": index, "source": object.duplicate(true)})
	return matches[0] if matches.size() == 1 else {}


## Link validity uses the same runtime map rules as StudioLink, while retaining a distinct missing-map diagnostic.
static func link_state(kind: String, target: Dictionary, maps: Dictionary) -> String:
	if target.is_empty():
		return "closed" if kind == "building" else "missing"
	var map_id := String(target.get("map", ""))
	var raw_destination: Variant = maps.get(map_id, {})
	if not raw_destination is Dictionary or (raw_destination as Dictionary).is_empty():
		return "missing_map"
	var destination: Dictionary = raw_destination
	var facing := String(target.get("facing", "down"))
	if facing != "" and not OverworldMap.FACINGS.has(facing):
		return "invalid_facing"
	var cell := OverworldMap.cell_of(target.get("at", [0, 0]))
	if not OverworldMap.inside(destination, cell):
		return "off_map"
	if not OverworldMap.warp_at(destination, cell).is_empty():
		return "loop"
	var people := _people_at(destination)
	if OverworldMap.blocked(destination, cell, people):
		return "blocked"
	return "valid"


## A new-game start or person may stand only on walkable, unoccupied ground that does not trigger a transition.
static func cell_state(map: Dictionary, cell: Vector2i) -> String:
	if not OverworldMap.inside(map, cell):
		return "off_map"
	if not OverworldMap.warp_at(map, cell).is_empty():
		return "transition"
	if OverworldMap.blocked(map, cell, _people_at(map)):
		return "blocked"
	return "valid"


## Scheduled people may move only within Lanternroot. Callers that stage the schedule document in the same world
## transaction can set allow_reanchor; all other placement paths keep the authored work anchor fixed.
static func person_cell_state(
	map: Dictionary, person_id: String, cell: Vector2i, schedules: Dictionary, allow_reanchor := false
) -> String:
	var raw_schedule: Variant = schedules.get(person_id, {})
	if raw_schedule is Dictionary and not (raw_schedule as Dictionary).is_empty():
		if String(map.get("id", "")) != "lanternroot":
			return "scheduled_cross_map"
		if not allow_reanchor:
			var schedule: Dictionary = raw_schedule
			var work_cell := OverworldMap.cell_of(schedule.get("work", [-1, -1]))
			if cell != work_cell:
				return "scheduled_anchor"
	var state := cell_state(map, cell)
	if state == "blocked" and _person_id_at(map, cell) == person_id:
		return "valid"
	return state


static func _people_at(map: Dictionary) -> Dictionary:
	var occupied := {}
	for value: Variant in map.get("people", []):
		if not value is Dictionary:
			continue
		var person: Dictionary = value
		var cell := OverworldMap.cell_of(person.get("at", [-1, -1]))
		occupied[cell] = String(person.get("id", "person"))
	return occupied


static func _person_id_at(map: Dictionary, cell: Vector2i) -> String:
	for value: Variant in map.get("people", []):
		if not value is Dictionary:
			continue
		var person: Dictionary = value
		if OverworldMap.cell_of(person.get("at", [-1, -1])) == cell:
			return String(person.get("id", "person"))
	return ""


static func _locations_by_person(maps: Dictionary) -> Dictionary:
	# Index the world once, instead of scanning every object again for each roster entry.
	var out := {}
	var map_ids: Array[String] = []
	map_ids.assign(maps.keys())
	map_ids.sort()
	for map_id: String in map_ids:
		var raw_map: Variant = maps.get(map_id, {})
		if not raw_map is Dictionary:
			continue
		var objects: Variant = (raw_map as Dictionary).get("objects", [])
		if not objects is Array:
			continue
		for index: int in (objects as Array).size():
			var source: Variant = (objects as Array)[index]
			if not source is Dictionary or String((source as Dictionary).get("kind", "")) != "person":
				continue
			var person: Dictionary = source
			var id := String(person.get("id", ""))
			if id.is_empty():
				continue
			if not out.has(id):
				out[id] = []
			(out[id] as Array).append({
				"map": map_id, "index": index, "at": OverworldMap.cell_of(person.get("at", [0, 0])),
				"facing": String(person.get("facing", "down")), "source": person.duplicate(true),
			})
	return out
