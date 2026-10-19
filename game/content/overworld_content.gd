class_name OverworldContent
extends RefCounted
## Lanternroot's overworld as content (ADR-0061), from `packs/<pack>/overworld/`:
##
##   terrain.jsonc        what each kind of ground is (walkable or not, the sound of a step on it)
##   townsfolk.jsonc      who lives in town: name, title, portrait, how they look, what they say
##   quests.jsonc         what to do next: quests of steps, each done when the town's flags say so (Quests)
##   looks.jsonc          what the player can choose for their own character
##   maps/<id>.jsonc      a map: its ground as rows of characters, and the things on it
##   talk/<id>.jsonc      a conversation (Talk)
##   things/<id>.jsonc    a thing that takes code (TownThings): its name, three hints, and its starter code beside it
##
##   var loaded := OverworldContent.load_world()
##   # {ok, catalog: {terrain, townsfolk, looks, quests, maps, talk, things}, diagnostics}
## Maps come back built (OverworldMap.build), so a broken map is a load error, not a surprise in play.

const KINDS: Array[String] = ["building", "prop", "sign", "person", "warp"]
const SLOTS: Array[String] = ["skin", "eyes", "hair", "main", "second", "accent", "metal"]
## The languages a thing's starter code comes in, and the extension of each starter file (<id>.starter.<extension>).
const STARTERS := {"python": "py", "javascript": "js"}
## A field's name is what the player's code reads from thing.fields: snake_case, starting with a letter.
const FIELD_NAME := "^[a-z][a-z0-9_]*$"


## `drafts` (file path -> data) stands in for those files' own data: Lanternroot Studio's drafts (ADR-0066) load
## through the same checks as the files, so a draft that plays is a draft that would publish. A draft that is a String
## is a text file's text (a thing's starter code, Studio S8).
static func load_world(root := ContentLoader.ROOT, drafts := {}) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var catalog := {
		"terrain": {}, "townsfolk": {}, "looks": {}, "maps": {}, "talk": {}, "quests": {}, "things": {},
		# v0.4, the parts of the game the player builds: the tasks, the bag's items, the props that give them, the
		# named places of each map and the music box's tracks.
		"tasks": {}, "items": {}, "pickups": {}, "places": {}, "tracks": {},
		# Chapter 3: where the scheduled townsfolk go at each hour, and what Nym's shop buys and sells.
		"schedules": {}, "shop": {},
	}
	var raw_maps := {}
	for pack in ContentLoader._sorted_dirs(root.path_join("packs")):
		var dir := root.path_join("packs").path_join(pack).path_join("overworld")
		if not DirAccess.dir_exists_absolute(dir):
			continue
		_merge(catalog.terrain, _section(dir.path_join("terrain.jsonc"), terrain_schema(), diagnostics, drafts))
		_merge(catalog.townsfolk, _section(dir.path_join("townsfolk.jsonc"), townsfolk_schema(), diagnostics, drafts))
		_merge(catalog.looks, _section(dir.path_join("looks.jsonc"), looks_schema(), diagnostics, drafts))
		_merge(catalog.quests, _section(dir.path_join("quests.jsonc"), quests_schema(), diagnostics, drafts))
		_load_each(dir.path_join("maps"), map_schema(), raw_maps, diagnostics, drafts)
		_load_each(dir.path_join("talk"), talk_schema(), catalog.talk, diagnostics, drafts)
		_load_things(dir.path_join("things"), catalog.things, diagnostics, drafts)
		_load_tasks(dir.path_join("tasks"), catalog.tasks, diagnostics, drafts)
		_merge(catalog.items, _section(dir.path_join("items.jsonc"), items_schema(), diagnostics, drafts))
		_merge(catalog.pickups, _section(dir.path_join("pickups.jsonc"), pickups_schema(), diagnostics, drafts))
		_merge(catalog.places, _section(dir.path_join("places.jsonc"), places_schema(), diagnostics, drafts))
		_merge(catalog.tracks, _section(dir.path_join("tracks.jsonc"), tracks_schema(), diagnostics, drafts))
		_merge(catalog.schedules, _section(dir.path_join("schedules.jsonc"), schedules_schema(), diagnostics, drafts))
		_merge(catalog.shop, _section(dir.path_join("shop.jsonc"), shop_schema(), diagnostics, drafts))
	for id: String in raw_maps:
		var built := OverworldMap.build(raw_maps[id], catalog.terrain)
		for message: String in built.errors:
			ContentLoader._error(diagnostics, "map", message, "overworld/maps/%s.jsonc" % id)
		catalog.maps[id] = built.map
	_cross_check(catalog, diagnostics)
	_cross_check_programs(catalog, diagnostics)
	_cross_check_parts(catalog, diagnostics)
	var ok := diagnostics.all(func(d: Dictionary) -> bool: return d.severity != "error")
	return {"ok": ok, "catalog": catalog, "diagnostics": diagnostics}


static func _section(file: String, schema: Dictionary, diagnostics: Array[Dictionary], drafts := {}) -> Dictionary:
	if not FileAccess.file_exists(file) and not drafts.has(file):
		return {}
	return ContentLoader._checked(schema, _data(file, diagnostics, drafts), file, "", diagnostics)


## A file's data: its draft when Lanternroot Studio has one (ADR-0066), else the file read and parsed. A draft is
## copied, since the checks fill in defaults.
static func _data(file: String, diagnostics: Array[Dictionary], drafts: Dictionary) -> Variant:
	if drafts.has(file):
		var draft: Variant = drafts[file]
		return draft.duplicate(true) if draft is Dictionary else draft
	return ContentLoader._read(file, diagnostics)


static func _merge(into: Dictionary, more: Dictionary) -> void:
	for key: String in more:
		into[key] = more[key]


static func _load_each(
	dir: String, schema: Dictionary, into: Dictionary, diagnostics: Array[Dictionary], drafts := {}
) -> void:
	var names: Array[String] = []
	if DirAccess.dir_exists_absolute(dir):
		names = ContentLoader._sorted_files(dir, ".jsonc")
	# A file that exists only as a draft (a map made in the Studio and not yet published) loads too.
	for file: String in drafts:
		if file.get_base_dir() == dir and not file.get_file() in names:
			names.append(file.get_file())
	names.sort()
	for name in names:
		var file := dir.path_join(name)
		var item := ContentLoader._checked(schema, _data(file, diagnostics, drafts), file, "", diagnostics)
		if item.is_empty():
			continue
		if item.id != name.get_basename():
			ContentLoader._error(diagnostics, "file-name", 'file name must be "%s.jsonc"' % item.id, file)
			continue
		into[item.id] = item


## Loads each thing (things/<id>.jsonc) into `into`, keyed by id, with the text of its starter code (`code`, by
## language). A thing whose starter is misnamed or missing is an error, and is left out.
static func _load_things(dir: String, into: Dictionary, diagnostics: Array[Dictionary], drafts := {}) -> void:
	var names: Array[String] = []
	if DirAccess.dir_exists_absolute(dir):
		names = ContentLoader._sorted_files(dir, ".jsonc")
	# A thing made in the Studio and not published yet loads from its drafts.
	for file: String in drafts:
		if file.get_base_dir() == dir and file.ends_with(".jsonc") and not file.get_file() in names:
			names.append(file.get_file())
	names.sort()
	for name in names:
		var file := dir.path_join(name)
		var thing := ContentLoader._checked(thing_schema(), _data(file, diagnostics, drafts), file, "", diagnostics)
		if thing.is_empty():
			continue
		if thing.id != name.get_basename():
			ContentLoader._error(diagnostics, "file-name", 'file name must be "%s.jsonc"' % thing.id, file)
			continue
		if into.has(thing.id):
			ContentLoader._error(diagnostics, "duplicate-id", 'thing "%s" is defined twice' % thing.id, file)
			continue
		var code := _starter_code(dir, thing, file, diagnostics, drafts)
		if code.size() == STARTERS.size():
			thing["code"] = code
			into[thing.id] = thing


## The text of each starter the thing names, by language. A starter is named <id>.starter.<extension> and sits
## beside the thing's file; a starter named otherwise, or missing, is an error.
static func _starter_code(
	dir: String, thing: Dictionary, file: String, diagnostics: Array[Dictionary], drafts := {}
) -> Dictionary:
	var code := {}
	for language: String in STARTERS:
		var starter := "%s.starter.%s" % [thing.id, STARTERS[language]]
		var drafted: Variant = drafts.get(dir.path_join(starter))
		if String(thing.starter[language]) != starter:
			var message := 'the %s starter must be named "%s"' % [language, starter]
			ContentLoader._error(diagnostics, "starter", message, file)
		elif drafted is String:
			code[language] = drafted
		elif not FileAccess.file_exists(dir.path_join(starter)):
			ContentLoader._error(diagnostics, "starter", 'there is no starter file "%s"' % starter, file)
		else:
			code[language] = FileAccess.get_file_as_string(dir.path_join(starter))
	return code


static func terrain_schema() -> Dictionary:
	return Schema.record(
		Schema.object({
			"walk": Schema.BOOL,
			"step": Schema.with_default(Schema.TEXT, "grass"),
			"paint": Schema.optional(Schema.one_of(["outdoor", "indoor"])),
		}), [], "^[a-z][a-z0-9_]*$"
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
				Schema.with_default(Schema.record(Schema.TEXT, [], "^(skin|eyes|hair|main|second|accent|metal)$"), {}),
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
	var model := Schema.one_of(["male", "female"])
	return (
		Schema
		. object(
			{
				"models": Schema.list_of(model, null, 1, 2),
				"start": Schema.object({"model": model}),
				# Complete character choices; future appearance controls need their own authored art first.
				"labels": Schema.with_default(Schema.record(Schema.TEXT), {}),
			}
		)
	)


static func quests_schema() -> Dictionary:
	# A step's optional pin (Studio S9): where it happens, a map and a cell, for the editor and the tracker to point at.
	var pin := Schema.object({"map": Schema.ID, "at": Schema.list_of(Schema.INT, null, 2, 2)})
	var step := Schema.object(
		{"text": Schema.TEXT, "hint": Schema.optional(Schema.TEXT), "done": {"type": "any"}, "at": Schema.optional(pin)}
	)
	return (
		Schema
		. record(
			(
				Schema
				. object(
					{
						"order": Schema.INT,
						"title": Schema.TEXT,
						"summary": Schema.TEXT,
						"giver": Schema.optional(Schema.TEXT),
						"after": Schema.list_of(Schema.ID, []),
						"steps": Schema.list_of(step, null, 1),
					}
				)
			)
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
										"art_size": Schema.optional(Schema.list_of(Schema.int_min(1), null, 2, 2)),
										"art_shape": Schema.optional(Schema.object({
											"door": Schema.optional(point),
											"door_size": Schema.optional(Schema.list_of(Schema.int_min(1), null, 2, 2)),
											"solid_rows": Schema.optional(Schema.list_of(Schema.int_min(0))),
											"solid_cells": Schema.optional(Schema.list_of(Schema.list_of(Schema.int_min(0), null, 2, 2))),
										})),
										"door": point,
											# Building walls sit near the front edge; these local rows stay solid while walkers pass behind roofs.
										"solid_rows": Schema.optional(Schema.list_of(Schema.int_min(0))),
										# Sparse local collision mask for organic footprints such as the lantern tree.
										"solid_cells": Schema.optional(Schema.list_of(Schema.list_of(Schema.int_min(0), null, 2, 2))),
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
										"art_size": Schema.optional(Schema.list_of(Schema.int_min(1), null, 2, 2)),
										"solid": Schema.with_default(Schema.BOOL, true),
										"talk": Schema.optional(Schema.ID),
										"text": Schema.optional(Schema.TEXT),
										"sink": Schema.with_default(Schema.INT, 0),
										# Flat art such as rugs and steps sits above terrain and below walkers.
										"draw_layer": Schema.optional(Schema.one_of(["ground"])),
										# Props that act together (the lamps of one lane), for a quest or a program to find.
										"group": Schema.optional(Schema.TEXT),
										# A thing (TownThings): a prop whose program runs when the player presses Space at it. Its id names its file.
										"id": Schema.optional(Schema.ID),
										"program": Schema.optional(program_schema()),
										# Solid until this bool field of the program is true (the cabbage gate's open).
										"solid_unless": Schema.optional(field_name()),
										# Drawn mirrored left to right (Lanternroot Studio's flip, ADR-0066).
										"flip": Schema.optional(Schema.BOOL),
										# Space opens one of the parts' panels here once that part is built (v0.4): the
										# Workbench desk, the music box, Pell's map table.
										"opens": Schema.optional(Schema.one_of(OPENS)),
									},
									"sign":
									{
										"art": Schema.with_default(Schema.TEXT, "sign"),
										"at": point,
										"text": Schema.TEXT,
										"talk": Schema.optional(Schema.ID)
									},
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


## A thing that takes code (TownThings): its id, its name, its three hints (a nudge, a concept, then a plan that
## names the step without writing the code), and the starter file it opens with for each language.
# --- v0.4: the parts of the game the player builds ------------------------------------------------------------------


## What a prop may open with Space (its "opens").
const OPENS: Array[String] = ["workbench", "music", "map", "bag", "clock", "tally", "lockbox", "drills"]


## Loads each task (tasks/<id>.jsonc, Concept/v0.4/02) into `into`, keyed by id, with its starter code (`code`, by
## language) read from the files beside it, as a thing's are.
static func _load_tasks(dir: String, into: Dictionary, diagnostics: Array[Dictionary], drafts := {}) -> void:
	var names: Array[String] = []
	if DirAccess.dir_exists_absolute(dir):
		names = ContentLoader._sorted_files(dir, ".jsonc")
	for file: String in drafts:
		if file.get_base_dir() == dir and file.ends_with(".jsonc") and not file.get_file() in names:
			names.append(file.get_file())
	names.sort()
	for name in names:
		var file := dir.path_join(name)
		var task := ContentLoader._checked(task_schema(), _data(file, diagnostics, drafts), file, "", diagnostics)
		if task.is_empty():
			continue
		if task.id != name.get_basename():
			ContentLoader._error(diagnostics, "file-name", 'file name must be "%s.jsonc"' % task.id, file)
			continue
		for problem in Tasks.problems(task):
			ContentLoader._error(diagnostics, "task", problem, file)
		var code := _starter_code(dir, task, file, diagnostics, drafts)
		if code.size() == STARTERS.size():
			task["code"] = code
			into[task.id] = task


## A task's file (Concept/v0.4/02, sections 1 to 3). Blocks and cases are checked by Tasks.problems, since their shape
## is code's (lines, slots, toggles; a case's extra fields belong to its judge).
static func task_schema() -> Dictionary:
	var language_text := Schema.object({"python": Schema.TEXT, "javascript": Schema.TEXT})
	var param := Schema.object({"name": Schema.TEXT, "meaning": Schema.TEXT, "example": Schema.with_default(Schema.TEXT, "")})
	var gives := Schema.object({"meaning": Schema.TEXT, "example": Schema.with_default(Schema.TEXT, "")})
	var word := Schema.object({"term": Schema.TEXT, "meaning": Schema.TEXT, "example": Schema.with_default(Schema.TEXT, "")})
	var words := Schema.object({"python": Schema.list_of(word, []), "javascript": Schema.list_of(word, [])})
	var stage := Schema.object(
		{
			"flag": Schema.ID,
			"goal": Schema.TEXT,
			"unlocked_by": Schema.optional({"type": "any"}),
			"entry": Schema.optional(language_text),
			"params": Schema.optional(Schema.list_of(param)),
			"gives": Schema.optional(gives),
			"words": Schema.optional(words),
			"mutates": Schema.with_default(Schema.INT, -1),
			# The arguments as the function left them come back too (a pure function must not change them).
			"args_after": Schema.with_default(Schema.BOOL, false),
			"judge": Schema.with_default(Schema.TEXT, Tasks.EQUALS),
			"cases": Schema.list_of({"type": "any"}, null, 1),
			"hints": Schema.list_of(Schema.TEXT, null, 3),
		}
	)
	return Schema.object(
		{
			"id": Schema.ID,
			"name": Schema.TEXT,
			"title": Schema.TEXT,
			"giver": Schema.ID,
			"built_line": Schema.TEXT,
			"entry": language_text,
			"params": Schema.list_of(param, []),
			"gives": Schema.optional(gives),
			"words": Schema.with_default(words, {"python": [], "javascript": []}),
			"starter": language_text,
			"blocks": Schema.optional({"type": "any"}),
			"stages": Schema.list_of(stage, null, 1),
			"advice": Schema.with_default(Schema.record(Schema.TEXT), {}),
		}
	)


## The bag's items: a name, a line about it, its icon (a picture in game/assets/overworld/world/) and a palette ramp for
## the stand-in drawn when the icon is missing.
static func items_schema() -> Dictionary:
	return Schema.record(
		Schema.object(
			{
				"name": Schema.TEXT,
				"about": Schema.TEXT,
				"icon": Schema.with_default(Schema.TEXT, ""),
				"colour": Schema.with_default(Schema.TEXT, "cloth_grey"),
			}
		)
	)


## The props that give an item, by map: a cell of the prop's footprint, the item, and the seconds of play before it
## gives again (-1: once only).
static func pickups_schema() -> Dictionary:
	var pickup := Schema.object(
		{
			"at": Schema.list_of(Schema.INT, null, 2, 2),
			"item": Schema.ID,
			"regrow": Schema.with_default(Schema.NUMBER, 240.0),
		}
	)
	return Schema.record(Schema.list_of(pickup, []))


## The named places of each map, as rectangles of cells (the map's place_of, the full map's labels).
static func places_schema() -> Dictionary:
	var place := Schema.object(
		{
			"id": Schema.ID,
			"name": Schema.TEXT,
			"x": Schema.INT,
			"y": Schema.INT,
			"w": Schema.int_min(1),
			"h": Schema.int_min(1),
		}
	)
	return Schema.record(Schema.list_of(place, []))


## The music box's tracks: each a music id with its title and where it is heard, in `order`.
static func tracks_schema() -> Dictionary:
	return Schema.record(
		Schema.object({"title": Schema.TEXT, "place": Schema.TEXT, "order": Schema.with_default(Schema.INT, 0)})
	)


## Where each scheduled townsperson goes (Concept/v0.4/05, 2.8): a cell of the town for home, work and the inn.
static func schedules_schema() -> Dictionary:
	var point := Schema.list_of(Schema.INT, null, 2, 2)
	return Schema.record(Schema.object({"home": point, "work": point, "inn": point}))


## Nym's shop (Concept/v0.4/05, 2.9): what Nym buys from the player and for how many coins each, and what Nym sells.
static func shop_schema() -> Dictionary:
	return Schema.object({"buys": Schema.record(Schema.int_min(0)), "sells": Schema.record(Schema.int_min(1))})


## The parts' content against the rest: a task's giver lives in town and its flags are its own; a pickup's item exists,
## on a map that exists, under a prop; a place lies inside its map; a track has its music.
static func _cross_check_parts(catalog: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var flags := {}
	for id: String in catalog.tasks:
		var task: Dictionary = catalog.tasks[id]
		var file := "overworld/tasks/%s.jsonc" % id
		if not catalog.townsfolk.has(String(task.giver)):
			ContentLoader._error(diagnostics, "task", "%s's giver %s does not live in town" % [id, task.giver], file)
		for stage: Dictionary in task.stages:
			var flag := String(stage.flag)
			if flags.has(flag):
				ContentLoader._error(diagnostics, "task", 'flag "%s" is set by %s and %s' % [flag, flags[flag], id], file)
			flags[flag] = id
	for map_id: String in catalog.pickups:
		var file := "overworld/pickups.jsonc"
		if not catalog.maps.has(map_id):
			ContentLoader._error(diagnostics, "pickups", "there is no map %s" % map_id, file)
			continue
		for pickup: Dictionary in catalog.pickups[map_id]:
			var at := OverworldMap.cell_of(pickup.at)
			if not catalog.items.has(String(pickup.item)):
				ContentLoader._error(diagnostics, "pickups", "%s at %s gives %s, which is not an item" % [map_id, at, pickup.item], file)
			var under := OverworldMap.thing_at(catalog.maps[map_id], at)
			if under.is_empty():
				under = OverworldMap.prop_over(catalog.maps[map_id], at)
			if under.is_empty():
				# A warning: a pickup under nothing never gives anything, and a map edited in the Studio can move a prop.
				_warn(diagnostics, "pickups", "%s at %s is under no prop" % [map_id, at], file)
	for map_id: String in catalog.places:
		var file := "overworld/places.jsonc"
		if not catalog.maps.has(map_id):
			ContentLoader._error(diagnostics, "places", "there is no map %s" % map_id, file)
			continue
		var size := OverworldMap.size_of(catalog.maps[map_id])
		for place: Dictionary in catalog.places[map_id]:
			var rect := Rect2i(int(place.x), int(place.y), int(place.w), int(place.h))
			if not Rect2i(Vector2i.ZERO, size).encloses(rect):
				# A warning: a map made smaller in the Studio leaves a place partly outside, where it simply never matches.
				_warn(diagnostics, "places", "%s's %s is not inside the map" % [map_id, place.id], file)
	var town: Dictionary = catalog.maps.get("lanternroot", {})
	var taken := {}
	for person: String in catalog.schedules:
		var file := "overworld/schedules.jsonc"
		if not catalog.townsfolk.has(person):
			ContentLoader._error(diagnostics, "schedules", "%s is not a townsperson" % person, file)
		for spot: String in catalog.schedules[person]:
			var at := OverworldMap.cell_of(catalog.schedules[person][spot])
			if town.is_empty() or OverworldMap.blocked(town, at, {}, {}) or not OverworldMap.warp_at(town, at).is_empty():
				_warn(diagnostics, "schedules", "%s's %s at %s is not a free cell to stand on" % [person, spot, at], file)
			if taken.has(at):
				_warn(diagnostics, "schedules", "%s's %s at %s is also %s's" % [person, spot, at, taken[at]], file)
			taken[at] = person
	for list: String in ["buys", "sells"]:
		for item: String in (catalog.shop.get(list, {}) as Dictionary):
			if not catalog.items.has(item):
				ContentLoader._error(diagnostics, "shop", "the shop %s %s, which is not an item" % [list, item], "overworld/shop.jsonc")
	for id: String in catalog.tracks:
		if not FileAccess.file_exists("res://assets/audio/%s.ogg" % id):
			ContentLoader._error(diagnostics, "tracks", "there is no music %s" % id, "overworld/tracks.jsonc")


static func _warn(diagnostics: Array[Dictionary], code: String, message: String, file: String) -> void:
	diagnostics.append({"severity": "warning", "code": code, "message": message, "file": file})


static func thing_schema() -> Dictionary:
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"name": Schema.TEXT,
				"hints": Schema.list_of(Schema.TEXT, null, 3, 3),
				"starter": Schema.object({"python": Schema.TEXT, "javascript": Schema.TEXT}),
			}
		)
	)


## A prop's program (TownThings): the hook it answers, the fields its code may change, and the flags it may raise.
static func program_schema() -> Dictionary:
	return (
		Schema
		. object(
			{
				"hook": Schema.one_of(TownThings.HOOKS),
				# The things this one's changes reach: each answers on_change (TownWires, Studio S8).
				"links": Schema.list_of(Schema.ID, []),
				"fields": Schema.record(field_schema(), [], FIELD_NAME),
				"raises": Schema.list_of(Schema.ID, []),
				# The thing takes code only once this holds (the quests' condition language; Studio S8).
				"unlocked_by": Schema.optional({"type": "any"}),
			}
		)
	)


## A declared field, by its type: a bool, a whole number from min to max (both included), or text. Each has a default,
## which TownThings.problems checks against the type and the bounds.
static func field_schema() -> Dictionary:
	return (
		Schema
		. union(
			{
				"bool": {"default": Schema.BOOL},
				"whole": {"min": Schema.INT, "max": Schema.INT, "default": Schema.INT},
				"text": {"default": {"type": "any"}},
			},
			"type"
		)
	)


## A field's name, which is what the player's code reads from thing.fields: snake_case, from a letter.
static func field_name() -> Dictionary:
	return {"type": "text", "pattern": FIELD_NAME, "pattern_message": "is not a field name (snake_case, from a letter)"}


## The programs on each map, as TownThings reads them (a duplicate id, a field that is not a bool, a solid_unless that
## is not a bool field, and so on). Each program's thing must have its file in things/.
static func _cross_check_programs(catalog: Dictionary, diagnostics: Array[Dictionary]) -> void:
	for map_id: String in catalog.maps:
		var file := "overworld/maps/%s.jsonc" % map_id
		var objects: Array = catalog.maps[map_id].objects
		for problem in TownThings.problems(objects):
			ContentLoader._error(diagnostics, "map", problem, file)
		for problem in TownWires.problems(objects):
			# A hook that is none of the three is TownThings' to say, once.
			if not problem.contains(" has a hook "):
				ContentLoader._error(diagnostics, "map", problem, file)
		for thing: Dictionary in objects:
			var id := String(thing.get("id", ""))
			if thing.has("program") and id != "" and not catalog.things.has(id):
				var message := "%s runs a program, but things/%s.jsonc is missing or does not load" % [id, id]
				ContentLoader._error(diagnostics, "map", message, file)


static func _cross_check(catalog: Dictionary, diagnostics: Array[Dictionary]) -> void:
	for problem in Quests.problems(catalog.quests):
		ContentLoader._error(diagnostics, "quests", problem, "overworld/quests.jsonc")
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
		for thing: Dictionary in map.objects:
			if thing.has("talk") and not catalog.talk.has(String(thing.talk)):
				ContentLoader._error(
					diagnostics,
					"map",
					"a thing at %s talks with %s, which is not a talk" % [thing.at, thing.talk],
					"overworld/maps/%s.jsonc" % map_id
				)
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
