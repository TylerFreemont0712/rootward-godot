class_name ContentLoader
extends RefCounted
## Loads and checks the Shardrun content (ADR-0004): balance.jsonc and every pack's shardrun/ folder. Each file is
## checked against its schema (ShardrunSchemas), which also fills in defaults; then references between files are
## checked (a starting spell names shards that exist, an encounter names foes that exist, and so on).
##
##   var loaded := ContentLoader.load_shardrun()
##   if loaded.ok: var catalog: Dictionary = loaded.catalog   # the shape Shardrun reads (ShardrunCatalog)
##   for d in loaded.diagnostics: print(ContentLoader.describe(d))
##
## A diagnostic is {severity: "error" | "warning", code, message, file}. Errors make `ok` false; warnings do not.

const ROOT := "res://content"
const CODE_EXTENSIONS := {"python": "py", "javascript": "js"}


static func load_shardrun(root := ROOT) -> Dictionary:
	var diagnostics: Array[Dictionary] = []
	var balance_file := root.path_join("balance.jsonc")
	var balance_raw: Variant = _read(balance_file, diagnostics)
	var balance := {}
	var sandbox := {}
	if balance_raw is Dictionary:
		balance = _checked(
			ShardrunSchemas.balance(),
			(balance_raw as Dictionary).get("shardrun"),
			balance_file,
			"shardrun",
			diagnostics
		)
		var defaults: Variant = (balance_raw as Dictionary).get("sandbox_defaults")
		sandbox = _checked(ShardrunSchemas.sandbox_defaults(), defaults, balance_file, "sandbox_defaults", diagnostics)

	var catalog := {
		"config": {},
		"shards": {},
		"foes": {},
		"relics": {},
		"balance": balance,
		"sandbox": sandbox,
		"programs": {"config": {}, "cards": {}},
	}
	var programs_file := ""
	var run_file := ""
	for pack in _sorted_dirs(root.path_join("packs")):
		var programs_dir := root.path_join("packs").path_join(pack).path_join("programs")
		if DirAccess.dir_exists_absolute(programs_dir):
			var cards: Dictionary = catalog.programs.cards
			_load_kind(programs_dir.path_join("cards"), ProgramSchemas.card(), cards, "card", diagnostics)
			var config_file := programs_dir.path_join("programs.jsonc")
			if FileAccess.file_exists(config_file):
				programs_file = config_file
				var config := _checked(
					ProgramSchemas.config(), _read(config_file, diagnostics), config_file, "", diagnostics
				)
				catalog.programs.config = config
		var dir := root.path_join("packs").path_join(pack).path_join("shardrun")
		if not DirAccess.dir_exists_absolute(dir):
			continue
		_load_kind(dir.path_join("shards"), ShardrunSchemas.shard(), catalog.shards, "shard", diagnostics)
		_load_kind(dir.path_join("relics"), ShardrunSchemas.relic(), catalog.relics, "relic", diagnostics)
		_load_kind(dir.path_join("foes"), ShardrunSchemas.foe(), catalog.foes, "foe", diagnostics)
		var file := dir.path_join("run.jsonc")
		if FileAccess.file_exists(file):
			if run_file != "":
				_error(diagnostics, "duplicate-id", "the Shardrun run is already defined in %s" % run_file, file)
				continue
			run_file = file
			var config := _checked(ShardrunSchemas.run_config(), _read(file, diagnostics), file, "", diagnostics)
			if not config.is_empty():
				config.id = "shardrun"
				catalog.config = config
	if run_file == "":
		_error(diagnostics, "no-run", "no pack declares shardrun/run.jsonc", root)
	elif not (catalog.config as Dictionary).is_empty():
		ShardrunChecks.check(catalog, run_file, diagnostics)
	if programs_file != "" and not (catalog.programs.config as Dictionary).is_empty():
		ProgramSchemas.check(catalog, programs_file, diagnostics)
	var ok := diagnostics.all(func(d: Dictionary) -> bool: return d.severity != "error")
	return {"ok": ok, "catalog": catalog, "diagnostics": diagnostics}


static func describe(diagnostic: Dictionary) -> String:
	return "%s %s [%s] %s" % [diagnostic.severity, diagnostic.file, diagnostic.code, diagnostic.message]


## Loads every `<id>.jsonc` in `dir` into `into`, keyed by id. A shard also gets `code` from `<id>.py` and `<id>.js`.
static func _load_kind(
	dir: String, schema: Dictionary, into: Dictionary, noun: String, diagnostics: Array[Dictionary]
) -> void:
	for name in _sorted_files(dir, ".jsonc"):
		var file := dir.path_join(name)
		var raw: Variant = _read(file, diagnostics)
		if raw == null:
			continue
		if noun in ["shard", "card"] and raw is Dictionary:
			(raw as Dictionary).code = _shard_code(dir, name.get_basename())
		var item := _checked(schema, raw, file, "", diagnostics)
		if item.is_empty():
			continue
		if item.id != name.get_basename():
			_error(diagnostics, "file-name", 'file name must be "%s.jsonc" to match the id inside it' % item.id, file)
			continue
		if into.has(item.id):
			_error(diagnostics, "duplicate-id", '%s "%s" is defined twice' % [noun, item.id], file)
			continue
		into[item.id] = item


static func _shard_code(dir: String, id: String) -> Dictionary:
	var code := {}
	for language: String in CODE_EXTENSIONS:
		var path := dir.path_join("%s.%s" % [id, CODE_EXTENSIONS[language]])
		if FileAccess.file_exists(path):
			code[language] = FileAccess.get_file_as_string(path)
	return code


static func _read(file: String, diagnostics: Array[Dictionary]) -> Variant:
	var parsed := Jsonc.parse_file(file)
	if not parsed.ok:
		_error(diagnostics, "parse", "line %d: %s" % [parsed.line, parsed.error], file)
		return null
	return parsed.value


## The value checked against `schema`, with defaults filled in; {} (and diagnostics) when it does not fit.
static func _checked(
	schema: Dictionary, raw: Variant, file: String, section: String, diagnostics: Array[Dictionary]
) -> Dictionary:
	if raw == null:
		if section != "":
			_error(diagnostics, "schema", 'missing section "%s"' % section, file)
		return {}
	var result := Schema.check(schema, raw)
	for message: String in result.errors:
		_error(diagnostics, "schema", (section + "." + message) if section != "" else message, file)
	return result.value if result.errors.is_empty() and result.value is Dictionary else {}


static func _error(diagnostics: Array[Dictionary], code: String, message: String, file: String) -> void:
	diagnostics.append({"severity": "error", "code": code, "message": message, "file": file})


static func _sorted_dirs(path: String) -> Array[String]:
	var names: Array[String] = []
	names.assign(DirAccess.get_directories_at(path))
	names.sort()
	return names


static func _sorted_files(path: String, extension: String) -> Array[String]:
	var names: Array[String] = []
	for name in DirAccess.get_files_at(path):
		if name.ends_with(extension):
			names.append(name)
	names.sort()
	return names
