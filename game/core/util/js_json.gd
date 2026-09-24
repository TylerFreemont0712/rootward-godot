class_name JsJson
extends RefCounted
## JSON text the way JavaScript's JSON.stringify writes it.
##
## LEARN: Godot parses every JSON number as a float and writes floats back with a fraction: {"power": 4} round-trips
## as {"power": 4.0}. JavaScript has one number type and writes a whole number as "4". The difference matters to Python
## shard code, where 4 is an int and 4.0 a float (`range(4.0)` fails). Anything that goes to the sandbox, or that must
## match the old engine's text, is written with this instead of JSON.stringify.

## Whole numbers up to here are written as integers, as JavaScript does below 1e21.
const INTEGER_LIMIT := 1e21


static func stringify(value: Variant) -> String:
	var parts := PackedStringArray()
	_write(value, parts)
	return "".join(parts)


## JSON text read back the way JavaScript would hold it: a whole number is an int again, not 4.0. Returns null for text
## that is not JSON. A saved run comes back looking exactly like the run that was saved.
static func parse(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return whole_numbers(json.data)


## A copy of `value` with every float that holds a whole number (and fits an int) turned into an int.
static func whole_numbers(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var number: float = value
			if number == floorf(number) and absf(number) < 9.0e18:
				return int(number)
			return number
		TYPE_DICTIONARY:
			var out := {}
			var dictionary: Dictionary = value
			for key: Variant in dictionary:
				out[key] = whole_numbers(dictionary[key])
			return out
		TYPE_ARRAY:
			var out: Array = []
			for item: Variant in value:
				out.append(whole_numbers(item))
			return out
	return value


static func _write(value: Variant, parts: PackedStringArray) -> void:
	match typeof(value):
		TYPE_NIL:
			parts.append("null")
		TYPE_BOOL:
			parts.append("true" if value else "false")
		TYPE_INT:
			parts.append(str(value))
		TYPE_FLOAT:
			parts.append(number(value))
		TYPE_STRING, TYPE_STRING_NAME:
			parts.append(JSON.stringify(String(value)))
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			parts.append("{")
			var first := true
			for key: Variant in dictionary:
				if not first:
					parts.append(",")
				first = false
				parts.append(JSON.stringify(str(key)))
				parts.append(":")
				_write(dictionary[key], parts)
			parts.append("}")
		_:
			if value is Array or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
				parts.append("[")
				var first := true
				for item: Variant in value:
					if not first:
						parts.append(",")
					first = false
					_write(item, parts)
				parts.append("]")
			else:
				parts.append(JSON.stringify(value))


## A number as JavaScript writes it: whole numbers without a fraction, and NaN or infinities as null.
static func number(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "null"
	if value == floorf(value) and absf(value) < INTEGER_LIMIT:
		return "%d" % int(value) if absf(value) < 9.0e18 else String.num(value, 0)
	return JSON.stringify(value)
