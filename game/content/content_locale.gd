class_name ContentLocale
extends RefCounted
## Translations of content, keyed by the English text itself (old ADR-0018): `packs/<pack>/locales/<locale>/*.jsonc`,
## each a list of {en, to, note?}. Renaming an id or moving a file never breaks a translation; editing the English makes
## its old translation stop matching, so the screen falls back to English and `coverage` names the line to redo.
##
## The rules always read English. Only what a player is shown is translated, and only the prose fields below: never
## an id, a function name, code, or a spell's name (the code view turns a spell's name into a function name).

const FIELDS := {
	"shard": ["name", "summary"],
	"foe": ["name", "flavor"],
	"relic": ["name", "summary", "flavor"],
	"run": ["difficulties.*.name", "difficulties.*.summary", "layers.*.name", "layers.*.flavor"],
}
const ENTRY := {
	"type": "object",
	"fields": {"en": {"type": "text"}, "to": {"type": "text"}, "note": {"type": "text", "optional": true}},
}


## English -> translation for `locale`, from every pack, with diagnostics for broken files and duplicate entries.
static func load_overlay(locale: String, root := ContentLoader.ROOT) -> Dictionary:
	var strings := {}
	var seen_in := {}
	var diagnostics: Array[Dictionary] = []
	for pack in ContentLoader._sorted_dirs(root.path_join("packs")):
		var dir := root.path_join("packs").path_join(pack).path_join("locales").path_join(locale)
		for name in ContentLoader._sorted_files(dir, ".jsonc"):
			var file := dir.path_join(name)
			var parsed := Jsonc.parse_file(file)
			if not parsed.ok:
				ContentLoader._error(diagnostics, "parse", "line %d: %s" % [parsed.line, parsed.error], file)
				continue
			var checked := Schema.check(Schema.list_of(ENTRY), parsed.value)
			for message: String in checked.errors:
				ContentLoader._error(diagnostics, "schema", message, file)
			if not checked.errors.is_empty():
				continue
			for entry: Dictionary in checked.value:
				if seen_in.has(entry.en):
					var message := '"%s" is already translated in %s' % [entry.en, seen_in[entry.en]]
					ContentLoader._error(diagnostics, "duplicate-translation", message, file)
					continue
				seen_in[entry.en] = file
				strings[entry.en] = entry.to
	return {"locale": locale, "strings": strings, "diagnostics": diagnostics}


## A copy of `catalog` with every translatable field in `strings`' language; fields without a translation stay English.
static func localize(catalog: Dictionary, strings: Dictionary) -> Dictionary:
	var out := catalog.duplicate(true)
	for kind: String in ["shard", "foe", "relic"]:
		for item: Dictionary in (out[kind + "s"] as Dictionary).values():
			for path: String in FIELDS[kind]:
				_translate(item, path.split("."), strings)
	for path: String in FIELDS.run:
		_translate(out.config, path.split("."), strings)
	return out


## Every translatable English string of the catalog, and which of them `strings` lacks.
static func coverage(catalog: Dictionary, strings: Dictionary) -> Dictionary:
	var english := {}
	for kind: String in ["shard", "foe", "relic"]:
		for item: Dictionary in (catalog[kind + "s"] as Dictionary).values():
			for path: String in FIELDS[kind]:
				_collect(item, path.split("."), english)
	for path: String in FIELDS.run:
		_collect(catalog.config, path.split("."), english)
	var missing: Array = english.keys().filter(func(text: String) -> bool: return not strings.has(text))
	return {"total": english.size(), "translated": english.size() - missing.size(), "missing": missing}


static func _translate(node: Variant, path: PackedStringArray, strings: Dictionary) -> void:
	_visit(
		node,
		path,
		func(holder: Variant, key: Variant) -> void:
			var text: Variant = holder[key]
			if text is String and strings.has(text):
				holder[key] = strings[text]
	)


static func _collect(node: Variant, path: PackedStringArray, into: Dictionary) -> void:
	_visit(
		node,
		path,
		func(holder: Variant, key: Variant) -> void:
			if holder[key] is String:
				into[holder[key]] = true
	)


## Calls `leaf(holder, key)` for every value at `path`, where `*` walks every element of a list.
static func _visit(node: Variant, path: PackedStringArray, leaf: Callable) -> void:
	if path.is_empty():
		return
	var head := path[0]
	var rest := path.slice(1)
	if head == "*":
		if node is Array:
			for i in (node as Array).size():
				if rest.is_empty():
					leaf.call(node, i)
				else:
					_visit(node[i], rest, leaf)
		return
	if not node is Dictionary or not (node as Dictionary).has(head):
		return
	if rest.is_empty():
		leaf.call(node, head)
	else:
		_visit(node[head], rest, leaf)
