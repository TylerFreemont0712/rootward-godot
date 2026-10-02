class_name FoundryBestiary
extends RefCounted
## Resolve encounter locations from the same effective catalog the chosen mode actually runs.


static func layers(catalog: Dictionary, mode: String) -> Array:
	var effective := ProgramRules.catalog_for(catalog) if mode == "program" else catalog
	return effective.config.layers


static func entries(catalog: Dictionary, mode: String, bosses: bool, layer_id := "all") -> Dictionary:
	var effective := ProgramRules.catalog_for(catalog) if mode == "program" else catalog
	var result := {}
	var routes: Array = effective.config.layers
	# LEARN: boss status belongs to the encounter pool, not the sprite size or a name convention.
	for index in routes.size():
		var layer: Dictionary = routes[index]
		if layer_id != "all" and layer.id != layer_id:
			continue
		for kind: String in ["boss"] if bosses else ["fight", "elite"]:
			for group: Array in layer.encounters.get(kind, []):
				for id: String in group:
					if not effective.foes.has(id):
						continue
					if not result.has(id):
						var creature: Dictionary = effective.foes[id].duplicate(true)
						creature.locations = []
						creature.boss = bosses
						creature.summary = (
							"%s %s" % [creature.get("flavor", ""), ShardrunViews.trait_view(creature).get("text", "")]
						)
						result[id] = creature
					var location := {
						"id": layer.id,
						"name": layer.name,
						"number": index + 1,
						"kind": kind,
						"group": group.duplicate()
					}
					if not location in result[id].locations:
						result[id].locations.append(location)
	return result


static func location_text(creature: Dictionary) -> String:
	var names: Array[String] = []
	for location: Dictionary in creature.get("locations", []):
		var name := FoundryUi.text("Layer %d · %s", "第%d層 · %s") % [int(location.number), location.name]
		if not name in names:
			names.append(name)
	return " / ".join(names)
