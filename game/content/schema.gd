class_name Schema
extends RefCounted
## A small schema language for content, in the spirit of the old game's zod schemas: shapes, ranges, enums, defaults,
## strict objects, records and tagged unions. `check` validates a value and returns it with defaults filled in, whole
## numbers as ints, and every problem as a readable message with its path.
##
##   var foe := Schema.object({"id": Schema.ID, "hp": Schema.int_min(1), "weak": Schema.list_of(ELEMENT, [])})
##   var result := Schema.check(foe, data)   # {value, errors: ["hp: must be at least 1", ...]}
##
## A schema is a Dictionary with a "type": text, id, tag, int, number, bool, enum, list, object, record, union, any.
## Any schema can carry "optional": true (absent is fine, and stays absent) or "default": value (absent means value).

const ID_PATTERN := "^[a-z0-9]+(?:[.-][a-z0-9]+)*$"
const TAG_PATTERN := "^[a-z0-9][a-z0-9+#.-]*$"

const ID := {"type": "id"}
const TEXT := {"type": "text"}
const TAG := {"type": "tag"}
const BOOL := {"type": "bool"}
const NUMBER := {"type": "number"}
const INT := {"type": "int"}
const RATIO := {"type": "number", "min": 0.0, "max": 1.0}

static var _id_regex: RegEx
static var _tag_regex: RegEx


static func int_min(low: int) -> Dictionary:
	return {"type": "int", "min": low}


static func int_range(low: int, high: int) -> Dictionary:
	return {"type": "int", "min": low, "max": high}


static func one_of(values: Array) -> Dictionary:
	return {"type": "enum", "values": values}


static func list_of(item: Dictionary, default: Variant = null, min_items := 0, max_items := -1) -> Dictionary:
	var schema := {"type": "list", "item": item, "min": min_items, "max": max_items}
	if default != null:
		schema.default = default
	return schema


static func object(fields: Dictionary) -> Dictionary:
	return {"type": "object", "fields": fields}


static func optional(schema: Dictionary) -> Dictionary:
	var copy := schema.duplicate()
	copy.optional = true
	return copy


static func with_default(schema: Dictionary, value: Variant) -> Dictionary:
	var copy := schema.duplicate()
	copy.default = value
	return copy


## A record keyed by strings; with `keys`, exactly those keys (like a zod record over an enum).
static func record(value: Dictionary, keys: Array = [], key_pattern := "") -> Dictionary:
	return {"type": "record", "value": value, "keys": keys, "key_pattern": key_pattern}


## A tagged union: the value's `kind` picks the object schema from `options` (kind -> fields).
static func union(options: Dictionary, tag := "kind") -> Dictionary:
	return {"type": "union", "tag": tag, "options": options}


static func check(schema: Dictionary, value: Variant) -> Dictionary:
	var errors: Array[String] = []
	var result: Variant = _check(schema, value, "", errors)
	return {"value": result, "errors": errors}


static func _check(schema: Dictionary, value: Variant, path: String, errors: Array[String]) -> Variant:
	var where := path if path != "" else "(root)"
	match schema.type:
		"any":
			return value
		"text", "id", "tag":
			if not value is String:
				errors.append("%s: must be text" % where)
				return value
			var text: String = value
			if schema.type == "text" and text.is_empty():
				errors.append("%s: must not be empty" % where)
			if schema.type == "id" and not _id().search(text):
				errors.append(
					"%s: \"%s\" is not an id (lowercase letters and digits separated by '.' or '-')" % [where, text]
				)
			if schema.type == "tag" and not _tag().search(text):
				errors.append("%s: \"%s\" is not a tag (lowercase; separators '-', '.', '+', '#')" % [where, text])
			if schema.has("pattern") and not RegEx.create_from_string(schema.pattern).search(text):
				errors.append('%s: "%s" %s' % [where, text, schema.get("pattern_message", "has the wrong form")])
			return text
		"bool":
			if not value is bool:
				errors.append("%s: must be true or false" % where)
			return value
		"int", "number":
			return _number(schema, value, where, errors)
		"enum":
			if not value in schema.values:
				errors.append(
					"%s: must be one of %s, not %s" % [where, ", ".join(schema.values), JSON.stringify(value)]
				)
			return value
		"list":
			return _list(schema, value, path, errors)
		"object":
			return _object(schema.fields, value, path, errors)
		"record":
			return _record(schema, value, path, errors)
		"union":
			return _union(schema, value, path, errors)
	errors.append("%s: unknown schema type %s" % [where, schema.type])
	return value


static func _number(schema: Dictionary, value: Variant, where: String, errors: Array[String]) -> Variant:
	if not (value is float or value is int) or (value is float and (is_nan(value) or is_inf(value))):
		errors.append("%s: must be a number" % where)
		return value
	var number := float(value)
	if schema.type == "int" and number != floorf(number):
		errors.append("%s: must be a whole number" % where)
		return value
	if schema.has("min") and number < float(schema.min):
		errors.append("%s: must be at least %s" % [where, JsMath.text(float(schema.min))])
	if schema.has("max") and number > float(schema.max):
		errors.append("%s: must be at most %s" % [where, JsMath.text(float(schema.max))])
	if schema.get("positive", false) and number <= 0.0:
		errors.append("%s: must be more than 0" % where)
	return int(number) if schema.type == "int" else number


static func _list(schema: Dictionary, value: Variant, path: String, errors: Array[String]) -> Variant:
	if not value is Array:
		errors.append("%s: must be a list" % (path if path != "" else "(root)"))
		return value
	var items: Array = value
	if items.size() < int(schema.get("min", 0)):
		errors.append("%s: needs at least %d item(s)" % [path, schema.min])
	if int(schema.get("max", -1)) >= 0 and items.size() > int(schema.max):
		errors.append("%s: allows at most %d item(s)" % [path, schema.max])
	var out: Array = []
	for i in items.size():
		out.append(_check(schema.item, items[i], "%s[%d]" % [path, i], errors))
	return out


static func _object(fields: Dictionary, value: Variant, path: String, errors: Array[String]) -> Variant:
	if not value is Dictionary:
		errors.append("%s: must be an object" % (path if path != "" else "(root)"))
		return value
	var input: Dictionary = value
	var out := {}
	for key: String in fields:
		var field: Dictionary = fields[key]
		var at := key if path == "" else "%s.%s" % [path, key]
		if not input.has(key):
			if field.has("default"):
				out[key] = _copy(field.default)
			elif not field.get("optional", false):
				errors.append("%s: is required" % at)
			continue
		out[key] = _check(field, input[key], at, errors)
	for key: Variant in input:
		if not fields.has(key):
			errors.append('%s: unknown field "%s"' % [path if path != "" else "(root)", key])
	return out


static func _record(schema: Dictionary, value: Variant, path: String, errors: Array[String]) -> Variant:
	if not value is Dictionary:
		errors.append("%s: must be an object" % path)
		return value
	var input: Dictionary = value
	var keys: Array = schema.get("keys", [])
	var out := {}
	for key: Variant in input:
		if not keys.is_empty() and not key in keys:
			errors.append('%s: unknown key "%s" (expected %s)' % [path, key, ", ".join(keys)])
		var pattern: String = schema.get("key_pattern", "")
		if pattern != "" and not RegEx.create_from_string(pattern).search(str(key)):
			errors.append('%s: key "%s" has the wrong form' % [path, key])
		out[key] = _check(schema.value, input[key], "%s.%s" % [path, key], errors)
	for key: String in keys:
		if not input.has(key):
			errors.append("%s.%s: is required" % [path, key])
	return out


static func _union(schema: Dictionary, value: Variant, path: String, errors: Array[String]) -> Variant:
	var tag: String = schema.tag
	if not value is Dictionary or not (value as Dictionary).has(tag):
		errors.append('%s: must be an object with a "%s"' % [path, tag])
		return value
	var options: Dictionary = schema.options
	var kind: Variant = value[tag]
	if not options.has(kind):
		errors.append("%s.%s: must be one of %s, not %s" % [path, tag, ", ".join(options.keys()), JSON.stringify(kind)])
		return value
	var fields: Dictionary = (options[kind] as Dictionary).duplicate()
	fields[tag] = one_of([kind])
	return _object(fields, value, path, errors)


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


static func _id() -> RegEx:
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(ID_PATTERN)
	return _id_regex


static func _tag() -> RegEx:
	if _tag_regex == null:
		_tag_regex = RegEx.create_from_string(TAG_PATTERN)
	return _tag_regex
