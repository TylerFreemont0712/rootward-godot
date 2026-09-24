class_name Fixtures
extends RefCounted
## Loads the differential fixtures written by tools/fixtures/*.ts from the TypeScript engine.


static func load_json(name: String) -> Variant:
	var path := "res://test/fixtures/%s.json" % name
	var text := FileAccess.get_file_as_string(path)
	assert(text != "", "missing fixture %s (run node tools/fixtures/%s.ts)" % [path, name])
	return JSON.parse_string(text)


## A draw in [0, 1) as the 32-bit word it came from. LEARN: comparing words, not floats, makes the test immune to the
## last-digit rounding of a float that went through JSON text.
static func word(value: float) -> int:
	return roundi(value * Rng.TWO_32)
