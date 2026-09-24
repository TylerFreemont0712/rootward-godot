class_name Jsonc
extends RefCounted
## JSON with comments: the format of every content file (ADR-0004). `//` and `/* */` comments and trailing commas are
## allowed; everything else is plain JSON.
##
## LEARN: comments and trailing commas are blanked out with spaces rather than deleted, so every character keeps its
## line and column, and the JSON parser's error line points at the right place in the file.


## {ok: true, value} or {ok: false, error, line}.
static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	var error := json.parse(strip(text))
	if error != OK:
		return {"ok": false, "error": json.get_error_message(), "line": json.get_error_line() + 1}
	return {"ok": true, "value": json.data}


static func parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "no such file", "line": 0}
	return parse(FileAccess.get_file_as_string(path))


## The text with comments and trailing commas replaced by spaces.
static func strip(text: String) -> String:
	var out := text.to_utf32_buffer().to_int32_array()
	var n := out.size()
	var i := 0
	var last_comma := -1  # a comma not yet followed by anything but blanks
	while i < n:
		var c := out[i]
		if c == 34:  # a string: skip to its closing quote, honouring escapes
			last_comma = -1
			i += 1
			while i < n and out[i] != 34:
				i += 2 if out[i] == 92 else 1
			i += 1
			continue
		if c == 47 and i + 1 < n and out[i + 1] == 47:  # // to the end of the line
			while i < n and out[i] != 10:
				out[i] = 32
				i += 1
			continue
		if c == 47 and i + 1 < n and out[i + 1] == 42:  # /* to */
			while i < n and not (out[i] == 42 and i + 1 < n and out[i + 1] == 47):
				if out[i] != 10:
					out[i] = 32
				i += 1
			if i < n:
				out[i] = 32
				out[i + 1] = 32
				i += 2
			continue
		if c == 44:
			last_comma = i
		elif c == 93 or c == 125:  # ] or }: a comma just before it was trailing
			if last_comma >= 0:
				out[last_comma] = 32
			last_comma = -1
		elif c != 32 and c != 9 and c != 10 and c != 13:
			last_comma = -1
		i += 1
	return out.to_byte_array().get_string_from_utf32()
