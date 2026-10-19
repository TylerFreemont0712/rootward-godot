extends GdUnitTestSuite
## The hints beside the code editors (ADR-0061): every program in both languages has the three sections, the parameter
## terms are the real names the town calls the function with, and the glossary only hints: no example is the answer.

const PROGRAMS: Array[String] = ["boots", "memory", "lamps"]
const LANGUAGES: Array[String] = ["python", "javascript"]
const TITLES: Array[String] = ["What your function gets", "What it gives back", "Words you can use"]


func test_every_program_has_the_three_sections_with_entries() -> void:
	for program in PROGRAMS:
		for language in LANGUAGES:
			var sections := CodeGlossary.sections(program, language)
			var where := "%s in %s" % [program, language]
			assert_int(sections.size()).override_failure_message("three sections for " + where).is_equal(3)
			for i in sections.size():
				(
					assert_str(String(sections[i].title))
					. override_failure_message("section %d of %s" % [i, where])
					. is_equal(TITLES[i])
				)
				var entries: Array = sections[i].entries
				(
					assert_bool(entries.is_empty())
					. override_failure_message("%s has entries in %s" % [TITLES[i], where])
					. is_false()
				)


func test_no_term_or_meaning_is_empty() -> void:
	for program in PROGRAMS:
		for language in LANGUAGES:
			for section in CodeGlossary.sections(program, language):
				for entry: Dictionary in section.entries:
					var where := "%s in %s: %s" % [program, language, entry]
					(
						assert_str(String(entry.term).strip_edges())
						. override_failure_message("a term: " + where)
						. is_not_empty()
					)
					(
						assert_str(String(entry.meaning).strip_edges())
						. override_failure_message("a meaning: " + where)
						. is_not_empty()
					)
					assert_bool(entry.has("example")).override_failure_message("an example key: " + where).is_true()


func test_an_unknown_program_has_no_sections() -> void:
	assert_int(CodeGlossary.sections("nothing", "python").size()).is_equal(0)


func test_the_function_terms_are_the_names_the_town_calls() -> void:
	for language in LANGUAGES:
		var boots := _terms(CodeGlossary.sections("boots", language), 0)
		(
			assert_bool("%s(key, player)" % BootsCode.ENTRY[language] in boots)
			. override_failure_message(str(boots))
			. is_true()
		)
		for name: String in ["key", "player", "player.x", "player.y"]:
			assert_bool(name in boots).override_failure_message("boots (%s) names %s" % [language, name]).is_true()
		var memory := _terms(CodeGlossary.sections(Lessons.MEMORY, language), 0)
		(
			assert_bool("%s(player)" % Lessons.entry(Lessons.MEMORY, language) in memory)
			. override_failure_message(str(memory))
			. is_true()
		)
		var lamps := _terms(CodeGlossary.sections(Lessons.LAMPS, language), 0)
		(
			assert_bool("%s(lamps)" % Lessons.entry(Lessons.LAMPS, language) in lamps)
			. override_failure_message(str(lamps))
			. is_true()
		)
		assert_bool("lamps" in lamps).is_true()


func test_memory_names_every_field_the_lesson_keeps() -> void:
	var python := _terms(CodeGlossary.sections(Lessons.MEMORY, "python"), 0)
	var script := _terms(CodeGlossary.sections(Lessons.MEMORY, "javascript"), 0)
	for field in Lessons.FIELDS:
		assert_bool('player["%s"]' % field in python).override_failure_message("python names " + field).is_true()
		assert_bool("player.%s" % field in script).override_failure_message("javascript names " + field).is_true()


func test_lamps_name_a_lamps_name_and_its_lit() -> void:
	var python := _terms(CodeGlossary.sections(Lessons.LAMPS, "python"), 0)
	assert_bool('lamp["name"]' in python and 'lamp["lit"]' in python).is_true()
	var script := _terms(CodeGlossary.sections(Lessons.LAMPS, "javascript"), 0)
	assert_bool("lamp.name" in script and "lamp.lit" in script).is_true()


func test_boots_and_lamps_give_nothing_back_and_memory_gives_a_dictionary() -> void:
	for language in LANGUAGES:
		for program: String in ["boots", Lessons.LAMPS]:
			var gives := _terms(CodeGlossary.sections(program, language), 1)
			assert_str(gives[0]).is_equal("nothing")
		var kept := _terms(CodeGlossary.sections(Lessons.MEMORY, language), 1)
		assert_str(kept[0]).is_equal("a dictionary" if language == "python" else "an object")


func test_the_words_fit_the_language() -> void:
	var python := _terms(CodeGlossary.sections(Lessons.LAMPS, "python"), 2)
	assert_bool("for … in … :" in python and "True   False" in python).override_failure_message(str(python)).is_true()
	var script := _terms(CodeGlossary.sections(Lessons.LAMPS, "javascript"), 2)
	(
		assert_bool("for (const … of …) { }" in script and "true   false" in script)
		. override_failure_message(str(script))
		. is_true()
	)
	var move := _terms(CodeGlossary.sections("boots", "python"), 2)
	(
		assert_bool("if … :" in move and "elif … :" in move and "+=   -=" in move)
		. override_failure_message(str(move))
		. is_true()
	)
	var dictionary := _terms(CodeGlossary.sections(Lessons.MEMORY, "python"), 2)
	assert_bool('{"key": value}' in dictionary and 'thing["key"]' in dictionary and "return" in dictionary).is_true()
	var object := _terms(CodeGlossary.sections(Lessons.MEMORY, "javascript"), 2)
	assert_bool("{key: value}" in object and "thing.key" in object).is_true()


## Hints, not answers: nothing in the glossary is the working line for its task.
func test_no_example_is_the_answer() -> void:
	for language in LANGUAGES:
		for program in PROGRAMS:
			for example in _examples(CodeGlossary.sections(program, language)):
				match program:
					"lamps":
						(
							assert_bool("lit" in example)
							. override_failure_message("lamps example sets lit: " + example)
							. is_false()
						)
					"memory":
						var fields := 0
						for field in Lessons.NEEDED:
							if field in example:
								fields += 1
						(
							assert_int(fields)
							. override_failure_message("memory example keeps x, y and map: " + example)
							. is_less(3)
						)
						(
							assert_bool("player" in example)
							. override_failure_message("memory example uses player: " + example)
							. is_false()
						)
					"boots":
						(
							assert_bool(
								"player.x +=" in example or "player.y -=" in example or "player.x -=" in example
							)
							. is_false()
						)
						(
							assert_bool("player" in example)
							. override_failure_message("boots example uses player: " + example)
							. is_false()
						)


func _terms(sections: Array[Dictionary], at: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in sections[at].entries:
		out.append(String(entry.term))
	return out


func _examples(sections: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for section in sections:
		for entry: Dictionary in section.entries:
			if String(entry.example) != "":
				out.append(String(entry.example))
	return out
