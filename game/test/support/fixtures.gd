class_name Fixtures
extends RefCounted
## The reference results the engine is tested against (game/test/fixtures/): recorded inputs, and what the engine did
## with them. They were first recorded from the TypeScript engine; they are the game's own (ADR-0021), so a change
## made on purpose re-records them from this engine, and the diff of the fixtures is reviewed with the change:
##
##   ROOTWARD_GOLDEN=update scripts/test.sh -a res://test/core/shardrun/shardrun_runs_test.gd
##
## A suite checks each result through `expect`, which compares, or, when re-recording, stores what the engine did in
## its place; the suite's `after` then writes the file.

const ROOT := "res://test/fixtures/"


## Whether this run re-records the fixtures instead of checking them.
static func updating() -> bool:
	return OS.get_environment("ROOTWARD_GOLDEN") == "update"


## `got` against `holder[key]`: the first difference, or "". When re-recording, `got` is stored in its place and
## there is no difference. `snaked` compares with the recorded value's keys in snake_case (the TypeScript engine's
## recordings are camelCase; what this engine records is already snake_case, which `snake` leaves alone).
static func expect(holder: Dictionary, key: String, got: Variant, path := "$", snaked := false) -> String:
	if updating():
		holder[key] = got
		return ""
	return diff(got, snake(holder[key]) if snaked else holder[key], path)


static func load_json(name: String) -> Variant:
	var path := ROOT + "%s.json" % name
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "missing fixture %s" % path)
	return JSON.parse_string(text)


## Writes a fixture back after re-recording: keys sorted and floats at full precision, so it reads back exactly and
## its diff shows only what changed. Plain fixtures are indented to be read; gzipped ones are compact.
static func save_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(ROOT + "%s.json" % name, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.close()


static func save_json_gz(name: String, value: Variant) -> void:
	# LEARN: PackedByteArray.compress(GZIP) writes a plain gzip stream, which decompress_dynamic reads back;
	# FileAccess.open_compressed would write Godot's own block format instead.
	var bytes := JSON.stringify(value, "", true, true).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var file := FileAccess.open(ROOT + "%s.json.gz" % name, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## A gzipped fixture (`<name>.json.gz`), for the big ones.
static func load_json_gz(name: String) -> Variant:
	var bytes := FileAccess.get_file_as_bytes(ROOT + "%s.json.gz" % name)
	assert(not bytes.is_empty(), "missing fixture %s.json.gz" % name)
	return JSON.parse_string(bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())


## A draw in [0, 1) as the 32-bit word it came from. LEARN: comparing words, not floats, makes the test immune to the
## last-digit rounding of a float that went through JSON text.
static func word(value: float) -> int:
	return roundi(value * Rng.TWO_32)


## The TypeScript engine's camelCase keys as this game's snake_case, all the way down. Values are left alone, and so
## are keys already snake_case (what this engine records).
static func snake(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key: String in value:
			result[snake_key(key)] = snake(value[key])
		return result
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return snake(item))
	return value


static func snake_key(key: String) -> String:
	var out := ""
	for i in key.length():
		var c := key[i]
		if c != c.to_lower() and i > 0:
			out += "_" + c.to_lower()
		else:
			out += c
	return out


## The first difference between two values as "path: got X, want Y", or "" when they are equal. Numbers compare by
## value, so 4 and 4.0 are the same; Dictionaries compare by key set, not key order.
static func diff(got: Variant, want: Variant, path := "$") -> String:
	var got_number := got is int or got is float
	var want_number := want is int or want is float
	if got_number and want_number:
		return "" if same_number(float(got), float(want)) else "%s: got %s, want %s" % [path, got, want]
	if got is Dictionary and want is Dictionary:
		var g: Dictionary = got
		var w: Dictionary = want
		for key: Variant in w:
			if not g.has(key):
				return "%s: missing key %s (want %s)" % [path, key, _short(w[key])]
		for key: Variant in g:
			if not w.has(key):
				return "%s: extra key %s (got %s)" % [path, key, _short(g[key])]
		for key: Variant in w:
			var inner := diff(g[key], w[key], "%s.%s" % [path, key])
			if inner != "":
				return inner
		return ""
	if got is Array and want is Array:
		var g: Array = got
		var w: Array = want
		for i in mini(g.size(), w.size()):
			var inner := diff(g[i], w[i], "%s[%d]" % [path, i])
			if inner != "":
				return inner
		if g.size() != w.size():
			return "%s: %d items, want %d" % [path, g.size(), w.size()]
		return ""
	if typeof(got) != typeof(want) or got != want:
		return "%s: got %s, want %s" % [path, _short(got), _short(want)]
	return ""


## Equal, or one unit in the last place apart. LEARN: Godot's JSON parser is not correctly rounded for 17-digit
## numbers: it reads "0.9750000000000001" (JavaScript's 1.3 * 0.75) as 0.975, one ulp away. Content's short decimals
## parse exactly; only the fixtures' computed values can land on such a number, so only the comparison forgives it.
static func same_number(got: float, want: float) -> bool:
	if got == want:
		return true
	return absf(got - want) <= absf(want) * 2.3e-16


static func _short(value: Variant) -> String:
	var text := JSON.stringify(value)
	return text if text.length() < 200 else text.substr(0, 200) + "..."
