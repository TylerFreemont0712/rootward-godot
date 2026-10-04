class_name TextCoverage
extends RefCounted
## What the game shows that is not content (ADR-0047), found in its source: the keys of every `Text.t("...")` and
## `Text.f("...", ...)` call on screen, and every sentence the rules write into a log or a refusal. scripts/locale.sh
## counts them against the overlays, as it counts content.

const INTERFACE_DIRS: Array[String] = ["res://scenes", "res://ui", "res://app"]
const RULES_DIRS: Array[String] = ["res://core"]
## A Text call's first argument, a literal (it may sit on the next line).
const CALL := 'Text\\.(?:t|f)\\(\\s*"((?:[^"\\\\]|\\\\.)*)"'
## A string a rule writes for the player: the value of a log entry's "text", a refusal's message, or a `text` variable.
const SENTENCE := (
	'(?:"text"\\s*:|"message"\\s*:|var text :?=|text =|_no\\([^,]+,|refuse\\([^,]+,)'
	+ '\\s*\\(?\\s*"((?:[^"\\\\]|\\\\.)*)"'
)


## Every interface key in the source, in the order found, without repeats.
static func interface_strings() -> Array[String]:
	return _scan(INTERFACE_DIRS, CALL)


## Every sentence the rules write, as its format.
static func rule_sentences() -> Array[String]:
	return _scan(RULES_DIRS, SENTENCE)


static func _scan(dirs: Array[String], pattern: String) -> Array[String]:
	var regex := RegEx.create_from_string(pattern)
	var found: Array[String] = []
	var seen := {}
	for dir in dirs:
		for file in _files(dir):
			if file == "res://app/text.gd":
				continue  # its doc comments show examples, not keys
			for match in regex.search_all(FileAccess.get_file_as_string(file)):
				var text := match.get_string(1).c_unescape()
				if text.strip_edges() == "" or seen.has(text) or not _has_words(text):
					continue
				seen[text] = true
				found.append(text)
	return found


## Whether a string has something to translate: at least one letter outside a format slot.
static func _has_words(text: String) -> bool:
	var stripped := text.replace("%s", "").replace("%d", "")
	for c in stripped:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			return true
	return false


static func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(sub)))
	return out
