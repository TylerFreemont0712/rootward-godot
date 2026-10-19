class_name StudioFit
extends RefCounted
## Whether things fit where they are put (Concept/v0.3/10, section 7.2): every cell on the map, and no solid cell shared
## with something that is not moving. The ghost of a drag is green where this says ok and red, with the reason, where
## it does not.
##
##   var fit := StudioFit.check(map, pick, [{"kind": "prop", "art": "barrel", "at": Vector2i(3, 4), "size": Vector2i.ONE}])
##   if not fit.ok:
##       print(fit.reason)      # "overlaps the well", "off the map"
##
## It looks at the objects' footprints, not at the ground: water and walls are the map's own rules (Publish checks them).


## {ok, reason}. `items` are built-style objects (at and size as Vector2i) at the cells they would stand on; `ignore`
## holds the map's object indexes that are moving, which do not count as in the way.
static func check(map: Dictionary, pick: StudioPick, items: Array[Dictionary], ignore: Array[int] = []) -> Dictionary:
	var objects: Array = map.get("objects", [])
	var occupied: Dictionary = {}
	for item: Dictionary in items:
		var box := StudioPick.footprint(item)
		var solid := is_solid(item)
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				var cell := Vector2i(x, y)
				if not OverworldMap.inside(map, cell):
					return {"ok": false, "reason": "off the map"}
				if not solid:
					continue
				if occupied.has(cell):
					return {"ok": false, "reason": "overlaps the %s" % String(occupied[cell])}
				occupied[cell] = name_of(item)
				for index: int in pick.objects_at_cell(cell):
					if index in ignore or index >= objects.size():
						continue
					if is_solid(objects[index] as Dictionary):
						return {"ok": false, "reason": "overlaps the %s" % name_of(objects[index] as Dictionary)}
				for index: int in pick.objects_at_cell(cell + Vector2i.UP):
					if index in ignore:
						continue
					var object: Dictionary = objects[index]
					if String(object.get("kind", "")) == "building" and object.get("door_cell") == cell + Vector2i.UP:
						return {"ok": false, "reason": "blocks the %s's door" % name_of(object)}
	return {"ok": true, "reason": ""}


## Whether an object keeps others out of its cells: houses, people, and props that say so (solid unless told otherwise).
static func is_solid(object: Dictionary) -> bool:
	match String(object.get("kind", "")):
		"building", "person":
			return true
		"prop", "sign":
			return bool(object.get("solid", true))
	return false


## What to call an object in a sentence: its picture ("well"), a person by their id, else its kind.
static func name_of(object: Dictionary) -> String:
	for key: String in ["art", "id", "kind"]:
		if String(object.get(key, "")) != "":
			return String(object[key])
	return "thing"
