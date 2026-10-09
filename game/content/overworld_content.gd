class_name OverworldContent
extends RefCounted
## Lanternroot's overworld as content (ADR-0061), from `packs/<pack>/overworld/`:
##
##   terrain.jsonc        what each kind of ground is (walkable or not, the sound of a step on it)
##   townsfolk.jsonc      who lives in town: name, title, portrait, how they look, what they say
##   looks.jsonc          what the player can choose for their own character
##   maps/<id>.jsonc      a map: its ground as rows of characters, and the things on it
##   talk/<id>.jsonc      a conversation (Talk)
##
##   var loaded := OverworldContent.load_world()   # {ok, catalog: {terrain, townsfolk, looks, maps, talk}, diagnostics}
## Maps come back built (OverworldMap.build), so a broken map is a load error, not a surprise in play.

const KINDS: Array[String] = ["building", "prop", "sign", "person", "warp"]
const SLOTS: Array[String] = ["skin", "hair", "main", "second", "accent", "metal"]


static func load_world(root := ContentLoader.ROOT) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var catalog := {"terrain": {}, "townsfolk": {}, "looks": {}, "maps": {}, "talk": {}}
	var raw_maps := {}
	for pack in ContentLoader._sorted_dirs(root.path_join("packs")):
		var dir := root.path_join("packs").path_join(pack).path_join("overworld")
		if not DirAccess.dir_exists_absolute(dir):
			continue
		_merge(catalog.terrain, _section(dir.path_join("terrain.jsonc"), terrain_schema(), diagnostics))
		_merge(catalog.townsfolk, _section(dir.path_join("townsfolk.jsonc"), townsfolk_schema(), diagnostics))
		_merge(catalog.looks, _section(dir.path_join("looks.jsonc"), looks_schema(), diagnostics))
		_load_each(dir.path_join("maps"), map_schema(), raw_maps, diagnostics)
		_load_each(dir.path_join("talk"), talk_schema(), catalog.talk, diagnostics)
	for id: String in raw_maps:
		var built := OverworldMap.build(raw_maps[id], catalog.terrain)
		for message: String in built.errors:
			ContentLoader._error(diagnostics, "map", message, "overworld/maps/%s.jsonc" % id)
		catalog.maps[id] = built.map
	_cross_check(catalog, diagnostics)
	var ok := diagnostics.all(func(d: Dictionary) -> bool: return d.severity != "error")
	return {"ok": ok, "catalog": catalog, "diagnostics": diagnostics}


static func _section(file: String, schema: Dictionary, diagnostics: Array[Dictionary]) -> Dictionary:
	if not FileAccess.file_exists(file):
		return {}
	return ContentLoader._checked(schema, ContentLoader._read(file, diagnostics), file, "", diagnostics)


static func _merge(into: Dictionary, more: Dictionary) -> void:
	for key: String in more:
		into[key] = more[key]


static func _load_each(dir: String, schema: Dictionary, into: Dictionary, diagnostics: Array[Dictionary]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name in ContentLoader._sorted_files(dir, ".jsonc"):
		var file := dir.path_join(name)
		var item := ContentLoader._checked(schema, ContentLoader._read(file, diagnostics), file, "", diagnostics)
		if item.is_empty():
			continue
		if item.id != name.get_basename():
			ContentLoader._error(diagnostics, "file-name", 'file name must be "%s.jsonc"' % item.id, file)
			continue
		into[item.id] = item


static func terrain_schema() -> Dictionary:
	return Schema.record(
		Schema.object({"walk": Schema.BOOL, "step": Schema.with_default(Schema.TEXT, "grass")}), [], "^[a-z]+$"
	)


static func _look_schema() -> Dictionary:
	var part := Schema.optional(Schema.TEXT)
	return (
		Schema
		. object(
			{
				"outfit": Schema.TEXT,
				"hair": part,
				"hat": part,
				"face": part,
				"item": part,
				"colours":
				Schema.with_default(Schema.record(Schema.TEXT, [], "^(skin|hair|main|second|accent|metal)$"), {}),
			}
		)
	)


static func townsfolk_schema() -> Dictionary:
	return (
		Schema
		. record(
			(
				Schema
				. object(
					{
						"name": Schema.TEXT,
						"title": Schema.TEXT,
						"portrait": Schema.TEXT,
						"look": _look_schema(),
						"talk": Schema.ID,
						"voice": Schema.with_default(Schema.NUMBER, 1.0),
					}
				)
			)
		)
	)


static func looks_schema() -> Dictionary:
	var choices := Schema.list_of(Schema.TEXT, null, 1)
	return (
		Schema
		. object(
			{
				"hair": choices,
				"outfit": choices,
				"hat": choices,
				"face": choices,
				"skin": choices,
				"hair_colour": choices,
				"cloth": choices,
				"start": _look_schema(),
			}
		)
	)


static func map_schema() -> Dictionary:
	var point := Schema.list_of(Schema.INT, null, 2, 2)
	var target := Schema.object(
		{
			"map": Schema.ID,
			"at": point,
			"facing": Schema.with_default(Schema.one_of(["", "down", "up", "left", "right"]), "")
		}
	)
	var facing := Schema.with_default(Schema.one_of(["down", "up", "left", "right"]), "down")
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"interior": Schema.with_default(Schema.BOOL, false),
				"music": Schema.with_default(Schema.TEXT, ""),
				"legend": Schema.record(Schema.TEXT),
				"ground": Schema.list_of(Schema.TEXT, null, 1),
				"start": point,
				"facing": facing,
				"objects":
				(
					Schema
					. list_of(
						(
							Schema
							. union(
								{
									"building":
									{
										"art": Schema.TEXT,
										"at": point,
										"size": point,
										"door": point,
										"to": Schema.optional(target),
										"name": Schema.optional(Schema.TEXT),
										"text": Schema.optional(Schema.TEXT),
										"sink": Schema.with_default(Schema.INT, 0),
									},
									"prop":
									{
										"art": Schema.TEXT,
										"at": point,
										"size": Schema.with_default(point, [1, 1]),
										"solid": Schema.with_default(Schema.BOOL, true),
										"text": Schema.optional(Schema.TEXT),
										"sink": Schema.with_default(Schema.INT, 0),
									},
									"sign":
									{"art": Schema.with_default(Schema.TEXT, "sign"), "at": point, "text": Schema.TEXT},
									"person": {"id": Schema.ID, "at": point, "facing": facing},
									"warp": {"at": point, "to": target},
								}
							)
						),
						[]
					)
				),
			}
		)
	)


static func talk_schema() -> Dictionary:
	var condition := {"type": "any"}
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"start":
				Schema.list_of(Schema.object({"if": Schema.optional(condition), "goto": Schema.TEXT}), null, 1),
				"nodes":
				(
					Schema
					. record(
						(
							Schema
							. object(
								{
									"lines":
									(
										Schema
										. list_of(
											(
												Schema
												. object(
													{
														"text": Schema.TEXT,
														"speaker": Schema.optional(Schema.TEXT),
														"mood": Schema.optional(Schema.TEXT),
													}
												)
											),
											null,
											1
										)
									),
									"choices":
									Schema.list_of(
										Schema.object(
											{"text": Schema.TEXT, "goto": Schema.TEXT, "if": Schema.optional(condition)}
										),
										[]
									),
									"set": Schema.list_of(Schema.TEXT, []),
									"next": Schema.optional(Schema.TEXT),
									"open": Schema.optional(Schema.TEXT),
								}
							)
						)
					)
				),
			}
		)
	)


static func _cross_check(catalog: Dictionary, diagnostics: Array[Dictionary]) -> void:
	for id: String in catalog.talk:
		for problem in Talk.problems(catalog.talk[id]):
			ContentLoader._error(diagnostics, "talk", problem, "overworld/talk/%s.jsonc" % id)
	for id: String in catalog.townsfolk:
		var person: Dictionary = catalog.townsfolk[id]
		if not catalog.talk.has(person.talk):
			ContentLoader._error(
				diagnostics,
				"townsfolk",
				"%s talks with %s, which is not a talk" % [id, person.talk],
				"overworld/townsfolk.jsonc"
			)
	for map_id: String in catalog.maps:
		var map: Dictionary = catalog.maps[map_id]
		for person: Dictionary in map.people:
			if not catalog.townsfolk.has(String(person.id)):
				ContentLoader._error(
					diagnostics, "map", "%s is not one of the townsfolk" % person.id, "overworld/maps/%s.jsonc" % map_id
				)
		for cell: Vector2i in map.warps:
			var to: Dictionary = map.warps[cell]
			if not catalog.maps.has(String(to.map)):
				ContentLoader._error(
					diagnostics,
					"map",
					"a door at %s leads to %s, which is not a map" % [cell, to.map],
					"overworld/maps/%s.jsonc" % map_id
				)
			elif not OverworldMap.inside(catalog.maps[to.map], to.at):
				ContentLoader._error(
					diagnostics,
					"map",
					"a door at %s leads off the map %s" % [cell, to.map],
					"overworld/maps/%s.jsonc" % map_id
				)
