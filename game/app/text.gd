class_name Text
extends RefCounted
## Everything the player reads, in the profile's language (ADR-0047). The game is written in English; Japanese comes
## from the overlays in `content/packs/*/locales/ja/`, every file a list of {en, to}, keyed by the English itself
## (ContentLocale). The same overlays serve three ways:
##
##   - A Label or Button whose whole text is a key is translated by Godot itself: `setup` registers every pair with
##     the TranslationServer, and Controls translate their `text` (auto-translate) whenever the locale changes.
##   - Text made from a format is translated before it is filled: `Text.f("%d mana", [3])` looks up "%d mana".
##   - A sentence the rules wrote (the fight's log, a refusal) is matched against the overlays' formats:
##     `Text.sentence("Tally Wisp takes 9.")` finds "%s takes %d.", translates it, and translates the name inside.
##
## A translation whose words must come in another order numbers its slots: "{2} に {1}" fills the second argument
## first. Code, ids and numbers are never translated, and the rules always keep their English.

const OVERLAY_LOCALES: Array[String] = ["ja"]

static var _translation: Translation
## The overlays' formats as patterns: [{regex: RegEx, to: String}], longest English first.
static var _patterns: Array[Dictionary] = []


## Loads the overlays once and switches the game's language. Called when a profile is chosen or changes language.
static func setup(locale: String) -> void:
	if _translation == null:
		_load()
	TranslationServer.set_locale(locale if locale in OVERLAY_LOCALES else "en")


static func japanese() -> bool:
	return TranslationServer.get_locale().begins_with("ja")


## `english` in the player's language, or itself when there is no translation (or the language is English).
static func t(english: String) -> String:
	if english == "" or not japanese():
		return english
	return String(TranslationServer.translate(english))


## A format translated, then filled: `Text.f("%d bolts", [3])`.
static func f(english: String, args: Array) -> String:
	return fill(t(english), args)


## A sentence the rules wrote, in the player's language: as a whole if it is a key, else matched against the
## overlays' formats, with each name it carries translated too. Unmatched, it stays English.
static func sentence(english: String) -> String:
	if english == "" or not japanese():
		return english
	var whole := String(TranslationServer.translate(english))
	if whole != english:
		return whole
	for pattern in _patterns:
		var found := (pattern.regex as RegEx).search(english)
		if found == null:
			continue
		var args: Array = []
		for i in range(1, found.get_group_count() + 1):
			var part := found.get_string(i)
			args.append(part if part.is_valid_int() else t(part))
		return fill(String(pattern.to), args)
	return english


## Several sentences joined by spaces (a log line), each translated.
static func sentences(english: String) -> String:
	if not japanese():
		return english
	var out := ""
	for part in split_sentences(english):
		# Japanese sentences run on with no space; one left in English still needs its space after.
		if out != "" and out[out.length() - 1] in [".", "!", "?", ":"]:
			out += " "
		out += sentence(part)
	return out


## A template filled with `args`: numbered slots ({1}, {2}) when the template has them, else `%` in order.
static func fill(template: String, args: Array) -> String:
	if template.contains("{1}"):
		var out := template
		for i in args.size():
			out = out.replace("{%d}" % (i + 1), str(args[i]))
		return out
	# LEARN: GDScript's `%` refuses "%d" for a String (a number read back from a sentence is one), so the slots are
	# filled here, each with the value's text, in order; "%%" is a percent sign.
	var out := ""
	var next := 0
	var i := 0
	while i < template.length():
		var c := template[i]
		if c == "%" and i + 1 < template.length():
			var kind := template[i + 1]
			if kind == "%":
				out += "%"
				i += 2
				continue
			if kind in ["s", "d"] and next < args.size():
				out += str(args[next])
				next += 1
				i += 2
				continue
		out += c
		i += 1
	return out


## "A. B! C?" -> ["A.", "B!", "C?"]: a sentence ends at . ! ? followed by a space.
static func split_sentences(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var start := 0
	for i in text.length():
		var c := text[i]
		if (c == "." or c == "!" or c == "?") and (i + 1 == text.length() or text[i + 1] == " "):
			out.append(text.substr(start, i + 1 - start).strip_edges())
			start = i + 1
	var rest := text.substr(start).strip_edges()
	if rest != "":
		out.append(rest)
	return out


static func _load() -> void:
	_translation = Translation.new()
	_translation.locale = "ja"
	var overlay := ContentLocale.load_overlay("ja")
	var strings: Dictionary = overlay.strings
	var formats: Array[String] = []
	for english: String in strings:
		_translation.add_message(english, String(strings[english]))
		if english.contains("%s") or english.contains("%d"):
			formats.append(english)
	TranslationServer.add_translation(_translation)
	# Longest first, so "%s takes %d from %d bolts." wins over "%s takes %d.".
	formats.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	_patterns.clear()
	for english in formats:
		var regex := RegEx.create_from_string("^" + _pattern_of(english) + "$")
		if regex.is_valid():
			_patterns.append({"regex": regex, "to": String(strings[english])})


## A format as a regular expression: %s matches any text, %d a whole number, everything else itself.
static func _pattern_of(english: String) -> String:
	var out := ""
	var i := 0
	while i < english.length():
		var c := english[i]
		if c == "%" and i + 1 < english.length() and english[i + 1] in ["s", "d"]:
			out += "(.+?)" if english[i + 1] == "s" else "(-?\\d+)"
			i += 2
			continue
		if c in ["\\", ".", "+", "*", "?", "(", ")", "[", "]", "{", "}", "^", "$", "|"]:
			out += "\\"
		out += c
		i += 1
	return out
