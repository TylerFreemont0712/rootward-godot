class_name CodeGlossary
extends RefCounted
## The hints beside Lanternroot's code editors (ADR-0061): what a function is given, what it gives back, and the few
## words of the language the task needs. Plain data, so the screen (CodeHints) only lays it out:
##
##   CodeGlossary.sections("lamps", "python")
##   # [{"title": "What your function gets", "entries": [{"term": "lamps", "meaning": "...", "example": "..."}]}, ...]
##
## Programs are "boots" (on_key / onKey) and the lessons' ids (Lessons.MEMORY, Lessons.LAMPS). Hints, not answers: an
## example is about some other thing (an item, a pet, a score), never the line the task asks for. A term is code and an
## example is code, so neither is translated; a meaning and a title are (each a literal Text.t call, so the locale check
## can find it).

const BOOTS := "boots"
const PYTHON := "python"
const JAVASCRIPT := "javascript"


## The three sections for `program` in `language`, in the order the player reads them. Empty for an unknown program.
static func sections(program: String, language: String) -> Array[Dictionary]:
	var python := language != JAVASCRIPT
	var gets: Array[Dictionary]
	var gives: Array[Dictionary]
	var words: Array[Dictionary]
	match program:
		BOOTS:
			gets = _boots_gets(python)
			gives = _boots_gives()
			words = _boots_words(python)
		Lessons.MEMORY:
			gets = _memory_gets(python)
			gives = _memory_gives(python)
			words = _memory_words(python)
		Lessons.LAMPS:
			gets = _lamps_gets(python)
			gives = _lamps_gives()
			words = _lamps_words(python)
		_:
			return []
	return [
		{"title": Text.t("What your function gets"), "entries": gets},
		{"title": Text.t("What it gives back"), "entries": gives},
		{"title": Text.t("Words you can use"), "entries": words},
	]


## The three sections for a v0.4 task (Concept/v0.4/02): what the function gets (its signature, then each parameter),
## what it gives back, and the words of `language` the stage needs, all from the task's glossary (Tasks.glossary).
## The content's prose goes through Text.t, since the pack's locales are keyed by the English.
static func sections_for_task(task: Dictionary, stage: int, language: String) -> Array[Dictionary]:
	var glossary := Tasks.glossary(task, stage)
	var gets: Array[Dictionary] = [
		_entry(
			Tasks.signature(task, stage, language),
			Text.t("The game calls this function, and hands it what is listed here."),
		),
	]
	for param: Variant in glossary.params:
		if param is Dictionary:
			var one: Dictionary = param
			gets.append(
				_entry(String(one.get("name", "")), Text.t(String(one.get("meaning", ""))), String(one.get("example", "")))
			)
	var gives: Array[Dictionary] = []
	var given: Dictionary = glossary.gives if glossary.gives is Dictionary else {}
	if not given.is_empty():
		gives.append(
			_entry(Text.t("your answer"), Text.t(String(given.get("meaning", ""))), String(given.get("example", "")))
		)
	var words: Array[Dictionary] = []
	var by_language: Dictionary = glossary.words if glossary.words is Dictionary else {}
	for word: Variant in by_language.get(language, by_language.get(PYTHON, [])):
		if word is Dictionary:
			var one: Dictionary = word
			words.append(
				_entry(String(one.get("term", "")), Text.t(String(one.get("meaning", ""))), String(one.get("example", "")))
			)
	return [
		{"title": Text.t("What your function gets"), "entries": gets},
		{"title": Text.t("What it gives back"), "entries": gives},
		{"title": Text.t("Words you can use"), "entries": words},
	]


## The function a program's town calls, as it is written: on_key(key, player), save(player), light_all(lamps).
static func signature(program: String, language: String) -> String:
	match program:
		BOOTS:
			return "%s(key, player)" % String(BootsCode.ENTRY.get(language, ""))
		Lessons.MEMORY:
			return "%s(player)" % Lessons.entry(Lessons.MEMORY, language)
		Lessons.LAMPS:
			return "%s(lamps)" % Lessons.entry(Lessons.LAMPS, language)
	return ""


# --- what the function gets ------------------------------------------------------------------------------------------


static func _boots_gets(python: bool) -> Array[Dictionary]:
	var language := PYTHON if python else JAVASCRIPT
	return [
		_entry(
			signature(BOOTS, language),
			Text.t("The town calls this every time you press a key, and hands it these two things."),
		),
		_entry(
			"key",
			Text.t("The key that was just pressed: right, left, up or down (as text), or a letter."),
			'key == "up"' if python else 'key === "up"',
		),
		_entry("player", Text.t("You. It holds where you stand, in the fields x and y.")),
		_entry(
			"player.x",
			Text.t("How far across you stand. Moving right makes x bigger, moving left makes it smaller."),
		),
		_entry(
			"player.y",
			Text.t("How far down you stand. Moving down makes y bigger, moving up makes it smaller."),
		),
	]


static func _memory_gets(python: bool) -> Array[Dictionary]:
	var language := PYTHON if python else JAVASCRIPT
	var out: Array[Dictionary] = [
		_entry(
			signature(Lessons.MEMORY, language),
			Text.t("The town calls this when you save, and hands it you, the player."),
		),
	]
	for field in Lessons.FIELDS:
		var term := 'player["%s"]' % field if python else "player.%s" % field
		out.append(_entry(term, _field_meaning(field), _field_example(field)))
	return out


static func _field_meaning(field: String) -> String:
	match field:
		"x":
			return Text.t("How far across you stand. Right makes it bigger.")
		"y":
			return Text.t("How far down you stand. Down makes it bigger.")
		"map":
			return Text.t("Which place you are in, as text: home or the town.")
		"facing":
			return Text.t("Which way you are facing, as text: up, down, left or right.")
		"name":
			return Text.t("Your name, as text.")
	return field


static func _field_example(field: String) -> String:
	match field:
		"x", "y":
			return "# a number, like 12"
		"map", "facing", "name":
			return '# text, like "moss"'
	return ""


static func _lamps_gets(python: bool) -> Array[Dictionary]:
	var language := PYTHON if python else JAVASCRIPT
	return [
		_entry(
			signature(Lessons.LAMPS, language),
			Text.t("The town calls this on the lane, and hands it the lamps."),
		),
		_entry(
			"lamps",
			(
				Text.t("A list of lamps. It can be empty, or hold many.")
				if python
				else Text.t("An array of lamps. It can be empty, or hold many.")
			),
		),
		_entry(
			"lamps[0]",
			Text.t("The first lamp. Counting starts at 0, and an empty list has no first one."),
		),
		_entry(
			"len(lamps)" if python else "lamps.length",
			Text.t("How many lamps there are."),
		),
		_entry(
			'lamp["name"]' if python else "lamp.name",
			Text.t("A lamp's name, as text, like Moss."),
		),
		_entry(
			'lamp["lit"]' if python else "lamp.lit",
			(
				Text.t("Whether the lamp shines: True or False.")
				if python
				else Text.t("Whether the lamp shines: true or false.")
			),
		),
	]


# --- what it gives back ----------------------------------------------------------------------------------------------


static func _boots_gives() -> Array[Dictionary]:
	return [
		_entry(
			Text.t("nothing"),
			Text.t("It gives nothing back. It changes player, and the town reads where you stand afterwards."),
		),
	]


static func _memory_gives(python: bool) -> Array[Dictionary]:
	if python:
		return [
			_entry(
				Text.t("a dictionary"),
				Text.t("Return a dictionary: names, each with a value. Whatever you leave out is forgotten."),
				'{"colour": "red", "size": 3}',
			),
		]
	return [
		_entry(
			Text.t("an object"),
			Text.t("Return an object: names, each with a value. Whatever you leave out is forgotten."),
			'{colour: "red", size: 3}',
		),
	]


static func _lamps_gives() -> Array[Dictionary]:
	return [
		_entry(
			Text.t("nothing"),
			Text.t("It gives nothing back. It changes the lamps themselves, and the town looks at them afterwards."),
		),
	]


# --- words you can use -----------------------------------------------------------------------------------------------


static func _boots_words(python: bool) -> Array[Dictionary]:
	if python:
		return [
			_entry(
				"if … :",
				Text.t("Run the indented lines only when the check after if is true."),
				'if score == 10:\n    print("won")',
			),
			_entry(
				"elif … :",
				Text.t("Another check, tried only when the ones above it were not true."),
				'elif colour == "red":',
			),
			_entry("==", Text.t("Asks: are these two the same? One = stores a value instead."), 'name == "Moss"'),
			_entry("+=   -=", Text.t("Make a number bigger, or smaller, by an amount."), "score += 5"),
			_entry("thing.name", Text.t("A dot reaches a field inside a thing."), "pet.mood"),
			_entry(
				Text.t("indentation"),
				Text.t("The spaces at the start of a line say which lines belong inside the if above. Use 4."),
				"if ready:\n    go()",
			),
			_entry("pass", Text.t("Does nothing. It fills a body that has to hold something.")),
		]
	return [
		_entry(
			"if (…) { }",
			Text.t("Run the lines inside the braces only when the check in the brackets is true."),
			'if (score === 10) {\n  console.log("won");\n}',
		),
		_entry(
			"else if (…) { }",
			Text.t("Another check, tried only when the ones above it were not true."),
			'else if (colour === "red") { }',
		),
		_entry("===", Text.t("Asks: are these two the same? One = stores a value instead."), 'name === "Moss"'),
		_entry("+=   -=", Text.t("Make a number bigger, or smaller, by an amount."), "score += 5;"),
		_entry("thing.name", Text.t("A dot reaches a field inside a thing."), "pet.mood"),
		_entry(
			"{ }",
			Text.t("Braces wrap the lines that belong together. A ; ends a line."),
			"if (ready) {\n  go();\n}",
		),
	]


static func _memory_words(python: bool) -> Array[Dictionary]:
	if python:
		return [
			_entry(
				'{"key": value}',
				Text.t("A dictionary: names, each with a value, between braces and separated by commas."),
				'{"colour": "red", "size": 3}',
			),
			_entry('thing["key"]', Text.t("Looks a value up in a dictionary by its name."), 'pet["mood"]'),
			_entry("return", Text.t("Hands a value back to whoever called the function, and stops."), "return total"),
			_entry('"text"', Text.t("Quotes make text. A name in a dictionary is text too."), '"Moss"'),
		]
	return [
		_entry(
			"{key: value}",
			Text.t("An object: names, each with a value, between braces and separated by commas."),
			'{colour: "red", size: 3}',
		),
		_entry("thing.key", Text.t("Looks a value up in an object by its name."), "pet.mood"),
		_entry("return", Text.t("Hands a value back to whoever called the function, and stops."), "return total;"),
		_entry('"text"', Text.t("Quotes make text."), '"Moss"'),
	]


static func _lamps_words(python: bool) -> Array[Dictionary]:
	if python:
		return [
			_entry(
				"for … in … :",
				Text.t("Visit each thing in a list, one after another, running the indented lines for each."),
				"for item in items:\n    print(item)",
			),
			_entry(
				'thing["key"] = value',
				Text.t("Sets a value inside a dictionary: it changes the dictionary itself."),
				'pet["mood"] = "happy"',
			),
			_entry(
				"True   False", Text.t("The two yes-or-no values. Write them with a capital letter."), "ready = True"
			),
			_entry(
				"if … :",
				Text.t("Run the indented lines only when the check after if is true."),
				"if len(items) > 0:",
			),
			_entry(
				Text.t("indentation"),
				Text.t("The spaces at the start of a line say which lines belong inside the for above. Use 4."),
				"for item in items:\n    print(item)",
			),
			_entry("pass", Text.t("Does nothing. It fills a body that has to hold something.")),
		]
	return [
		_entry(
			"for (const … of …) { }",
			Text.t("Visit each thing in an array, one after another, running the lines in the braces for each."),
			"for (const item of items) {\n  console.log(item);\n}",
		),
		_entry(
			"thing.key = value;",
			Text.t("Sets a value inside an object: it changes the object itself."),
			'pet.mood = "happy";',
		),
		_entry("true   false", Text.t("The two yes-or-no values, in small letters."), "ready = true;"),
		_entry(
			"if (…) { }",
			Text.t("Run the lines inside the braces only when the check is true."),
			"if (items.length > 0) { }"
		),
		_entry(
			"{ }",
			Text.t("Braces wrap the lines that belong together. A ; ends a line."),
			"for (const item of items) {\n  go(item);\n}",
		),
	]


static func _entry(term: String, meaning: String, example := "") -> Dictionary:
	return {"term": term, "meaning": meaning, "example": example}
