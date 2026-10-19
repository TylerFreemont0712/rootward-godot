class_name OverworldStrings
extends RefCounted
## Every English string Lanternroot shows a player, with where it comes from (Concept/v0.4/06; ADR-0047), for the
## Japanese coverage test (overworld_locale_test) and the translators' batches (tools/overworld_missing.gd):
##
##   OverworldStrings.shown()     # {english: source}, e.g. {"Pip's count": "quests.jsonc", "Next hint": "task_editor.gd"}
##
## Sources: what the overworld's scripts pass to Text (the literals of Text.t and Text.f), the boots' run messages,
## the content's prose (talk, townsfolk, map texts, quests, tasks, items, tracks, places, things), the comments of the
## starter code the editors show (translated line by line), the four keys and Hotaru. Code is never in it: a task's
## code, its case values and its choices' code are the player's language, not English.

const SCENES := "res://scenes/overworld"
const BOOTS_RUN := "res://sandbox/overworld/boots_run.gd"
## The messages the boots' harnesses (boots.py, boots.js) report when they cannot run the player's code.
const HARNESS_MESSAGES: Array[String] = [
	"there is no function on_key(key, player)",
	"there is no function onKey(key, player)",
	"the recursion went too deep",
]
## A Text.t or Text.f call's first argument, a double-quoted or single-quoted literal (captured with its quotes).
const TEXT_CALL := "Text\\.[tf]\\(\\s*(\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*')"
## The messages the boots report: the last literal of a failed(...) call in BootsRun.
const FAILED_CALL := 'failed\\([^\\n]*("(?:[^"\\\\]|\\\\.)*")\\)'


static func shown() -> Dictionary:
	var found := {}
	for path: String in scripts(SCENES):
		for text: String in literals(FileAccess.get_file_as_string(path), TEXT_CALL):
			_add(found, text, path.get_file())
	for text: String in literals(FileAccess.get_file_as_string(BOOTS_RUN), FAILED_CALL):
		_add(found, text, "boots_run.gd")
	for message: String in HARNESS_MESSAGES:
		_add(found, message, "boots harness")
	var catalog: Dictionary = OverworldContent.load_world().catalog
	for id: String in catalog.talk:
		for node: Dictionary in (catalog.talk[id].nodes as Dictionary).values():
			for line: Dictionary in node.get("lines", []):
				_add(found, String(line.get("text", "")), "talk/%s" % id)
			for choice: Dictionary in node.get("choices", []):
				_add(found, String(choice.get("text", "")), "talk/%s" % id)
	for id: String in catalog.townsfolk:
		var person: Dictionary = catalog.townsfolk[id]
		_add(found, String(person.get("name", "")), "townsfolk")
		_add(found, String(person.get("title", "")), "townsfolk")
	for map_id: String in catalog.maps:
		var map: Dictionary = catalog.maps[map_id]
		_add(found, String(map.get("name", "")), "maps/%s" % map_id)
		for thing: Dictionary in map.objects:
			if thing.has("text"):
				_add(found, String(thing.text), "maps/%s" % map_id)
	for key: String in BootsRules.KEYS:
		_add(found, key, "keys")
	_add(found, String(DialogueBox.HOTARU.name), "hotaru")
	# The creator's model names: a label from content, else the id made readable (CharacterCreator).
	var looks: Dictionary = catalog.get("looks", {})
	var labels: Dictionary = looks.get("labels", {}) if looks.get("labels") is Dictionary else {}
	for list_name: String in looks:
		if not looks[list_name] is Array:
			continue
		for id: Variant in looks[list_name]:
			if String(id) != "none":
				_add(found, CharacterCreator.label_of(String(id), labels, false), "looks")
	_quests(found, catalog.get("quests", {}))
	for id: String in catalog.get("tasks", {}):
		_task(found, catalog.tasks[id])
	for id: String in catalog.get("items", {}):
		_add(found, String(catalog.items[id].get("name", "")), "items")
		_add(found, String(catalog.items[id].get("about", "")), "items")
	for id: String in catalog.get("tracks", {}):
		_add(found, String(catalog.tracks[id].get("title", "")), "tracks")
		_add(found, String(catalog.tracks[id].get("place", "")), "tracks")
	for map_id: String in catalog.get("places", {}):
		for place: Dictionary in catalog.places[map_id]:
			_add(found, String(place.get("name", "")), "places")
	for id: String in catalog.get("things", {}):
		var thing: Dictionary = catalog.things[id]
		_add(found, String(thing.get("name", "")), "things/%s" % id)
		for hint: Variant in thing.get("hints", []):
			_add(found, String(hint), "things/%s" % id)
	for language: String in [Lessons.PYTHON, Lessons.JAVASCRIPT]:
		for lesson: String in Lessons.IDS:
			for comment in comments(Lessons.starter(lesson, language)):
				_add(found, comment, "lessons starter")
		for comment in comments(BootsCode.starter(language)):
			_add(found, comment, "boots starter")
	found.erase("")
	return found


## The English strings, sorted.
static func shown_list() -> Array[String]:
	var out: Array[String] = []
	out.assign(shown().keys())
	out.sort()
	return out


static func _quests(found: Dictionary, quests: Dictionary) -> void:
	for id: String in quests:
		var quest: Dictionary = quests[id]
		_add(found, String(quest.get("title", "")), "quests")
		_add(found, String(quest.get("summary", "")), "quests")
		for step: Variant in quest.get("steps", []):
			if step is Dictionary:
				_add(found, String((step as Dictionary).get("text", "")), "quests")
				_add(found, String((step as Dictionary).get("hint", "")), "quests")


## A task's prose: its names and lines, the glossary's meanings, each stage's goal, hints and cases' descriptions,
## the advice, the Builder's labels (and a choice's label), and the comments of its starter code.
static func _task(found: Dictionary, task: Dictionary) -> void:
	var from := "tasks/%s" % String(task.get("id", ""))
	for key: String in ["name", "title", "built_line"]:
		_add(found, String(task.get(key, "")), from)
	_glossary(found, task, from)
	for stage: Variant in task.get("stages", []):
		if not stage is Dictionary:
			continue
		_add(found, String((stage as Dictionary).get("goal", "")), from)
		for hint: Variant in (stage as Dictionary).get("hints", []):
			_add(found, String(hint), from)
		for case_data: Variant in (stage as Dictionary).get("cases", []):
			if case_data is Dictionary:
				_add(found, String((case_data as Dictionary).get("say", "")), from)
		_glossary(found, stage, from)
	for said: Variant in (task.get("advice", {}) as Dictionary).values():
		_add(found, String(said), from)
	var design: Dictionary = task.get("blocks", {}) if task.get("blocks", {}) is Dictionary else {}
	for kind: String in ["slots", "toggles"]:
		for part: Variant in (design.get(kind, {}) as Dictionary).values():
			if not part is Dictionary:
				continue
			_add(found, String((part as Dictionary).get("label", "")), from)
			for choice: Variant in (part as Dictionary).get("choices", []):
				if choice is Dictionary and (choice as Dictionary).has("label"):
					_add(found, String((choice as Dictionary).label), from)
	for code: Variant in (task.get("code", {}) as Dictionary).values():
		for comment in comments(String(code)):
			_add(found, comment, from + " starter")


static func _glossary(found: Dictionary, holder: Dictionary, from: String) -> void:
	for param: Variant in holder.get("params", []):
		if param is Dictionary:
			_add(found, String((param as Dictionary).get("meaning", "")), from)
	if holder.get("gives") is Dictionary:
		_add(found, String((holder.gives as Dictionary).get("meaning", "")), from)
	if holder.get("words") is Dictionary:
		for list: Variant in (holder.words as Dictionary).values():
			for word: Variant in list:
				if word is Dictionary:
					_add(found, String((word as Dictionary).get("meaning", "")), from)


## The text of each comment in `code`: a Python `# ...` or a JavaScript `// ...`, the marker and the space after it
## left out (what CodeComments.localized translates).
static func comments(code: String) -> Array[String]:
	var out: Array[String] = []
	for line in code.split("\n"):
		var text := CodeComments.comment_of(line)
		if text != "":
			out.append(text)
	return out


static func _add(found: Dictionary, text: String, from: String) -> void:
	if text.strip_edges() == "" or found.has(text):
		return
	found[text] = from


## Every .gd file under `dir`, the subfolders too.
static func scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for name: String in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir.path_join(name))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(scripts(dir.path_join(sub)))
	return out


## The string literals `pattern` captures from `source`, each unquoted and unescaped.
static func literals(source: String, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var regex := RegEx.create_from_string(pattern)
	for hit: RegExMatch in regex.search_all(source):
		var text := unquote(hit.get_string(1))
		if text != "":
			out.append(text)
	return out


static func unquote(literal: String) -> String:
	var inner := literal.substr(1, literal.length() - 2)
	var out := ""
	var i := 0
	while i < inner.length():
		var c := inner[i]
		if c == "\\" and i + 1 < inner.length():
			out += String({"n": "\n", "t": "\t"}.get(inner[i + 1], inner[i + 1]))
			i += 2
		else:
			out += c
			i += 1
	return out
