class_name JsoncWriter
extends RefCounted
## The canonical text of a map file (Concept/v0.3/10, section 9.6): the header comment kept word for word, then the
## data in its own key order, one row or one object to a line. Read a file, write it back unchanged, and the bytes
## are the same.
##
##   var source := FileAccess.get_file_as_string(path)
##   var text := JsoncWriter.map_text(JsoncWriter.header_of(source), JsoncWriter.normalized(Jsonc.parse(source).value))
##
## LEARN: Godot's JSON parser returns every number as a float, so `13` comes back as `13.0`. Written as it is, that
## would put `13.0` into the file. normalized() turns each whole float into an int first; only then is the text made.

## Every integer up to 2^53 is exact in a float, so only floats up to this size can be whole ints without loss.
const MAX_WHOLE := 9007199254740992.0


## The lines before the first line that starts with `{`, each with its newline. "" when there is no such line.
static func header_of(text: String) -> String:
	var pos := 0
	while pos < text.length():
		var stop := text.find("\n", pos)
		stop = text.length() if stop == -1 else stop + 1
		if text.substr(pos, stop - pos).strip_edges().begins_with("{"):
			return text.substr(0, pos)
		pos = stop
	return ""


## The value with every whole float turned into an int, through arrays and dictionaries alike. Dictionaries keep
## their key order.
static func normalized(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			if _is_whole(number):
				return int(number)
			return number
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(normalized(item))
			return items
		TYPE_DICTIONARY:
			var dict := {}
			for key: Variant in value:
				dict[key] = normalized(value[key])
			return dict
	return value


## One line of text for a value: `{"k": v, "k2": v2}`, `[a, b]`, a string in JSON quotes, a whole number as an int.
static func compact(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			var number: float = value
			return str(int(number)) if _is_whole(number) else JSON.stringify(number)
		TYPE_STRING:
			return JSON.stringify(value)
		TYPE_ARRAY:
			var items := PackedStringArray()
			for item: Variant in value:
				items.append(compact(item))
			return "[%s]" % ", ".join(items)
		TYPE_DICTIONARY:
			var pairs := PackedStringArray()
			for key: Variant in value:
				pairs.append("%s: %s" % [JSON.stringify(String(key)), compact(value[key])])
			return "{%s}" % ", ".join(pairs)
	return JSON.stringify(value)


## The whole text of a map: the header, then `{`, each top-level key on its own line, then `}` and a final newline.
## `ground` and `objects` take one item to a line; every other value is compact.
static func map_text(header: String, data: Dictionary) -> String:
	var value: Dictionary = normalized(data)
	var entries := PackedStringArray()
	for key: Variant in value:
		entries.append(" %s: %s" % [JSON.stringify(String(key)), _map_value(String(key), value[key])])
	if entries.is_empty():
		return header + "{\n}\n"
	return header + "{\n" + ",\n".join(entries) + "\n}\n"


## A top-level value of a map. A non-empty `ground` or `objects` array is one item to a line, indented two spaces,
## with the closing bracket on its own line.
static func _map_value(key: String, value: Variant) -> String:
	var lines_key := key == "ground" or key == "objects"
	if not lines_key or typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
		return compact(value)
	var items := PackedStringArray()
	for item: Variant in value:
		items.append("  " + compact(item))
	return "[\n" + ",\n".join(items) + "\n ]"


## The whole text of the catalog (`catalog.jsonc`): the header, then `{`, each top-level key indented two spaces;
## `categories` one category to a line and `assets` one entry to a line, indented four, with the closing bracket or
## brace on its own line at two; every other value compact.
static func catalog_text(header: String, data: Dictionary) -> String:
	var value: Dictionary = normalized(data)
	var entries := PackedStringArray()
	for key: Variant in value:
		entries.append("  %s: %s" % [JSON.stringify(String(key)), _catalog_value(String(key), value[key])])
	if entries.is_empty():
		return header + "{\n}\n"
	return header + "{\n" + ",\n".join(entries) + "\n}\n"


static func _catalog_value(key: String, value: Variant) -> String:
	var items := PackedStringArray()
	if key == "categories" and typeof(value) == TYPE_ARRAY and not (value as Array).is_empty():
		for item: Variant in value:
			items.append("    " + compact(item))
		return "[\n" + ",\n".join(items) + "\n  ]"
	if key == "assets" and typeof(value) == TYPE_DICTIONARY and not (value as Dictionary).is_empty():
		for id: Variant in value:
			items.append("    %s: %s" % [JSON.stringify(String(id)), compact(value[id])])
		return "{\n" + ",\n".join(items) + "\n  }"
	return compact(value)


## The whole text of the quests file (`quests.jsonc`): the header, then each quest as an object with one key to a line,
## its `steps` list one step to a line, and `}` at two spaces, with a final newline. Every other value is compact.
static func quests_text(header: String, data: Dictionary) -> String:
	var value: Dictionary = normalized(data)
	var entries := PackedStringArray()
	for key: Variant in value:
		entries.append("  %s: %s" % [JSON.stringify(String(key)), _quest_value(value[key])])
	if entries.is_empty():
		return header + "{\n}\n"
	return header + "{\n" + ",\n".join(entries) + "\n}\n"


## One quest: its keys on lines of their own, four spaces in, with `steps` one step to a line, six spaces in.
static func _quest_value(quest: Variant) -> String:
	if typeof(quest) != TYPE_DICTIONARY or (quest as Dictionary).is_empty():
		return compact(quest)
	var lines := PackedStringArray()
	for key: Variant in quest:
		var field: Variant = quest[key]
		if String(key) == "steps" and typeof(field) == TYPE_ARRAY and not (field as Array).is_empty():
			var steps := PackedStringArray()
			for step: Variant in field:
				steps.append("      " + compact(step))
			lines.append('    "steps": [\n' + ",\n".join(steps) + "\n    ]")
		else:
			lines.append("    %s: %s" % [JSON.stringify(String(key)), compact(field)])
	return "{\n" + ",\n".join(lines) + "\n  }"


## The whole text of a talk file (`talk/<id>.jsonc`): the header, then the data as pretty JSON, two spaces to a level,
## every key and every list item on a line of its own, `[]` and `{}` for an empty list and object, and a final newline.
## Strings and numbers are compact.
static func talk_text(header: String, data: Dictionary) -> String:
	return header + _pretty(normalized(data), "") + "\n"


## The townsfolk schedule file: one schedule per line, matching its compact authored layout while preserving the header.
static func schedules_text(header: String, data: Dictionary) -> String:
	var value: Dictionary = normalized(data)
	var entries := PackedStringArray()
	for key: Variant in value:
		entries.append("  %s: %s" % [JSON.stringify(String(key)), compact(value[key])])
	if entries.is_empty():
		return header + "{\n}\n"
	return header + "{\n" + ",\n".join(entries) + "\n}\n"


## One value at an indent: an object or a non-empty list takes a line for each entry, two spaces deeper than `indent`,
## with its closing bracket back at `indent`. The text starts after the key or bullet that the caller has written.
static func _pretty(value: Variant, indent: String) -> String:
	var inner := indent + "  "
	match typeof(value):
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			if dict.is_empty():
				return "{}"
			var pairs := PackedStringArray()
			for key: Variant in dict:
				pairs.append("%s%s: %s" % [inner, JSON.stringify(String(key)), _pretty(dict[key], inner)])
			return "{\n" + ",\n".join(pairs) + "\n" + indent + "}"
		TYPE_ARRAY:
			var items: Array = value
			if items.is_empty():
				return "[]"
			var lines := PackedStringArray()
			for item: Variant in items:
				lines.append(inner + _pretty(item, inner))
			return "[\n" + ",\n".join(lines) + "\n" + indent + "]"
	return compact(value)


static func _is_whole(number: float) -> bool:
	return absf(number) <= MAX_WHOLE and number == floorf(number)
