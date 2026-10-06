class_name LanternContent
extends RefCounted
## Lanternroot's content (ADR-0055): `packs/<pack>/lanternroot/town.jsonc` (villagers, where each house stands, the
## days) and one `requests/<id>.jsonc` per letter, with its starter and reference code beside it in both languages:
## `<id>.starter.py`, `<id>.solution.py`, `<id>.starter.js`, `<id>.solution.js`. A change order (`replaces`) has no
## starter: the player changes code they already wrote.
##
##   var loaded := LanternContent.load_town()   # {ok, catalog: {town, requests, order}, diagnostics}

const CODE := {"python": "py", "javascript": "js"}
const MODULE_PATTERN := "^[a-z][a-z0-9_]*$"
const FUNCTION_PATTERN := "^[a-z][a-z0-9_]*$"


static func load_town(root := ContentLoader.ROOT) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var town := {}
	var requests := {}
	for pack in ContentLoader._sorted_dirs(root.path_join("packs")):
		var dir := root.path_join("packs").path_join(pack).path_join("lanternroot")
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var town_file := dir.path_join("town.jsonc")
		if FileAccess.file_exists(town_file):
			town = ContentLoader._checked(
				town_schema(), ContentLoader._read(town_file, diagnostics), town_file, "", diagnostics
			)
		_load_requests(dir.path_join("requests"), requests, diagnostics)
	var order: Array[String] = []
	order.assign(requests.keys())
	order.sort_custom(func(a: String, b: String) -> bool: return requests[a].order < requests[b].order)
	var catalog := {"town": town, "requests": requests, "order": order}
	if town.is_empty():
		ContentLoader._error(diagnostics, "missing", "no lanternroot/town.jsonc in any pack", root)
	else:
		_cross_check(catalog, diagnostics)
	var ok := diagnostics.all(func(d: Dictionary) -> bool: return d.severity != "error")
	return {"ok": ok, "catalog": catalog, "diagnostics": diagnostics}


static func town_schema() -> Dictionary:
	var point := Schema.list_of(Schema.NUMBER, null, 2, 2)
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"villagers":
				Schema.record(Schema.object({"name": Schema.TEXT, "role": Schema.TEXT, "colour": Schema.TEXT})),
				"houses":
				Schema.record(
					Schema.object({"name": Schema.TEXT, "at": point, "roof": Schema.TEXT}), [], MODULE_PATTERN
				),
				"huts": Schema.list_of(point),
				"days":
				Schema.list_of(
					Schema.object({"day": Schema.int_min(1), "title": Schema.TEXT, "dawn": Schema.TEXT}), null, 1
				),
			}
		)
	)


static func request_schema() -> Dictionary:
	var name_of := func(pattern: String) -> Dictionary: return {"type": "text", "pattern": pattern}
	return (
		Schema
		. object(
			{
				"id": Schema.ID,
				"order": Schema.int_min(1),
				"day": Schema.int_min(1),
				"villager": Schema.TEXT,
				"title": Schema.TEXT,
				"module": name_of.call(MODULE_PATTERN),
				"function": name_of.call(FUNCTION_PATTERN),
				"params": Schema.list_of(name_of.call(FUNCTION_PATTERN)),
				"concepts": Schema.list_of(Schema.TEXT, []),
				"requires": Schema.list_of(Schema.ID, []),
				"replaces": Schema.optional(Schema.ID),
				"letter": Schema.TEXT,
				"examples":
				Schema.list_of(
					Schema.object({"args": Schema.list_of({"type": "any"}), "expect": {"type": "any"}}), null, 1
				),
				"checks":
				Schema.list_of(
					Schema.object(
						{"name": Schema.TEXT, "args": Schema.list_of({"type": "any"}), "expect": {"type": "any"}}
					)
				),
				"hints": Schema.list_of(Schema.TEXT, null, 3, 3),
				"learn": Schema.TEXT,
				# Generated from the files beside the request, never written in it.
				"starter": Schema.optional({"type": "any"}),
				"solution": Schema.optional({"type": "any"}),
			}
		)
	)


static func _load_requests(dir: String, into: Dictionary, diagnostics: Array[Dictionary]) -> void:
	for name in ContentLoader._sorted_files(dir, ".jsonc"):
		var file := dir.path_join(name)
		var raw: Variant = ContentLoader._read(file, diagnostics)
		if not raw is Dictionary:
			continue
		var id := name.get_basename()
		(raw as Dictionary).starter = _code(dir, id, "starter")
		(raw as Dictionary).solution = _code(dir, id, "solution")
		var item := ContentLoader._checked(request_schema(), raw, file, "", diagnostics)
		if item.is_empty():
			continue
		if item.id != id:
			ContentLoader._error(diagnostics, "file-name", 'file name must be "%s.jsonc"' % item.id, file)
			continue
		# LEARN: Godot reads every JSON number as a float; a test's 2 must reach Python as the int 2, not 2.0.
		item.examples = JsJson.whole_numbers(item.examples)
		item.checks = JsJson.whole_numbers(item.checks)
		into[id] = item


static func _code(dir: String, id: String, kind: String) -> Dictionary:
	var code := {}
	for language: String in CODE:
		var path := dir.path_join("%s.%s.%s" % [id, kind, CODE[language]])
		if FileAccess.file_exists(path):
			code[language] = FileAccess.get_file_as_string(path)
	return code


static func _cross_check(catalog: Dictionary, diagnostics: Array[Dictionary]) -> void:
	var town: Dictionary = catalog.town
	var requests: Dictionary = catalog.requests
	var last_day: int = (town.days as Array).size()
	for id: String in catalog.order:
		var request: Dictionary = requests[id]
		var file := "lanternroot/requests/%s.jsonc" % id
		var problems: Array[String] = []
		if not town.villagers.has(request.villager):
			problems.append('unknown villager "%s"' % request.villager)
		if request.day > last_day:
			problems.append("day %d is past the last day, %d" % [request.day, last_day])
		for needed: String in request.requires:
			if not requests.has(needed):
				problems.append('requires an unknown letter "%s"' % needed)
			elif requests[needed].order >= request.order:
				problems.append('requires "%s", which comes later' % needed)
		for language: String in CODE:
			if not (request.solution as Dictionary).has(language):
				problems.append("has no %s solution" % language)
			if not request.has("replaces") and not (request.starter as Dictionary).has(language):
				problems.append("has no %s starter" % language)
		if request.has("replaces"):
			var replaced: Dictionary = requests.get(request.replaces, {})
			if replaced.is_empty():
				problems.append('replaces an unknown letter "%s"' % request.replaces)
			elif replaced.module != request.module or replaced.function != request.function:
				problems.append('must change the same function as "%s"' % request.replaces)
			elif not request.replaces in request.requires:
				problems.append('must require the letter it replaces, "%s"' % request.replaces)
		for problem in problems:
			ContentLoader._error(diagnostics, "reference", problem, file)
