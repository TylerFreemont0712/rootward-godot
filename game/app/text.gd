class_name Text
extends RefCounted
## Everything the player reads, in the profile's language (ADR-0047). The game is written in English; Japanese comes
## from the overlays in `content/packs/*/locales/ja/`, every file a list of {en, to, kanji?}, keyed by the English itself
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
static var _japanese_reading := "hiragana"
static var _japanese_strings: Dictionary = {}
static var _japanese_kanji_strings: Dictionary = {}
static var _kanji_by_japanese: Dictionary = {}
static var _hiragana_phrases: Dictionary = {}
static var _hiragana_phrase_keys: Array[String] = []
static var _hiragana_phrases_by_first: Dictionary = {}
static var _converted_strings_by_reading: Dictionary = {}
const KANJI_PHRASES_TO_KANA := {
	"町が作った物を": "まちがつくったものを", "君の関数を": "きみのかんすうを", "読んで、変えて": "よんで、かえて",
	"並べよう。": "ならべよう。", "押していなかったから、": "おしていなかったから、", "私たちが": "わたしたちが",
	"忘れてしまったよ。": "わすれてしまったよ。", "家で目を覚ましたんだ。": "いえでめをさましたんだ。",
}
const KANJI_TO_KANA := {
	"辞書から": "じしょから", "辞書の": "じしょの", "辞書は": "じしょは", "辞書が": "じしょが", "辞書を": "じしょを", "辞書に": "じしょに", "辞書で": "じしょで", "辞書や": "じしょや", "辞書だよ": "じしょだよ", "辞書": "じしょ",
	"辞書（じしょ）から": "じしょから", "辞書（じしょ）の": "じしょの", "辞書（じしょ）は": "じしょは", "辞書（じしょ）が": "じしょが", "辞書（じしょ）を": "じしょを", "辞書（じしょ）に": "じしょに", "辞書（じしょ）で": "じしょで", "辞書（じしょ）や": "じしょや", "辞書（じしょ）だよ": "じしょだよ", "辞書（じしょ）": "じしょ",
	"時間帯": "じかんたい", "整数": "せいすう", "番人の": "ばんにんの", "番人は": "ばんにんは", "番人が": "ばんにんが", "番人に": "ばんにんに", "番人": "ばんにん",
	"時間の": "じかんの", "時間は": "じかんは", "時間が": "じかんが", "時間を": "じかんを", "時間に": "じかんに", "時間で": "じかんで", "時間": "じかん",
	"町の": "まちの", "町は": "まちは", "町を": "まちを", "町に": "まちに", "町で": "まちで", "町へ": "まちへ", "町": "まち",
	"町が": "まちが",
	"色の": "いろの", "色は": "いろは", "色が": "いろが", "色を": "いろを", "色に": "いろに", "色で": "いろで", "色と": "いろと", "色": "いろ",
	"数の": "かずの", "数は": "かずは", "数が": "かずが", "数を": "かずを", "数に": "かずに", "数で": "かずで", "数と": "かずと", "数も": "かずも", "数": "かず", "行": "ぎょう",
	"値が（あたい）": "あたいが", "値を（あたい）": "あたいを", "値は（あたい）": "あたいは", "値の（あたい）": "あたいの", "値に（あたい）": "あたいに", "値で（あたい）": "あたいで", "値（あたい）": "あたい", "値が": "あたいが", "値を": "あたいを", "値は": "あたいは", "値の": "あたいの", "値に": "あたいに", "値で": "あたいで", "値": "あたい",
	"君の": "きみの", "君は": "きみは", "君が": "きみが", "君を": "きみを", "君と": "きみと", "君も": "きみも", "君": "きみ",
	"名前の": "なまえの", "名前は": "なまえは", "名前が": "なまえが", "名前を": "なまえを", "名前に": "なまえに", "名前と": "なまえと", "名前": "なまえ",
	"言葉の": "ことばの", "言葉は": "ことばは", "言葉が": "ことばが", "言葉を": "ことばを", "言葉": "ことば",
	"靴の": "くつの", "靴を": "くつを", "靴が": "くつが", "靴は": "くつは", "靴": "くつ",
	"お店の": "おみせの", "お店は": "おみせは", "お店で": "おみせで", "お店に": "おみせに", "お店": "おみせ",
	"今日は": "きょうは", "今日の": "きょうの", "今日": "きょう", "明日は": "あしたは", "明日の": "あしたの", "明日": "あした",
	"天気の": "てんきの", "天気は": "てんきは", "天気が": "てんきが", "天気": "てんき",
	"村は": "むらは", "村の": "むらの", "村で": "むらで", "村": "むら", "家の": "いえの", "家は": "いえは", "家で": "いえで", "家": "いえ",
	"関数": "かんすう", "作ります": "つくります", "作った": "つくった", "作って": "つくって", "作る": "つくる",
	"読んで": "よんで", "読んだ": "よんだ", "読む": "よむ", "書いて": "かいて", "書いた": "かいた", "書く": "かく",
	"見て": "みて", "見た": "みた", "見る": "みる", "持って": "もって", "持った": "もった", "持つ": "もつ",
	"買って": "かって", "買った": "かった", "買う": "かう", "売って": "うって", "売った": "うった", "売る": "うる",
	"入れて": "いれて", "入れた": "いれた", "入れる": "いれる",
}
## The overlays' formats as patterns: [{regex: RegEx, english: String}], longest English first.
static var _patterns: Array[Dictionary] = []


## Loads the overlays once and switches the game's language. Called when a profile is chosen or changes language.
static func setup(locale: String, japanese_reading := "hiragana") -> void:
	if _translation == null:
		_load()
	set_japanese_reading(japanese_reading)
	TranslationServer.set_locale(locale if locale in OVERLAY_LOCALES else "en")


static func set_japanese_reading(reading: String) -> void:
	var normalized := reading if reading in ["hiragana", "kanji"] else "hiragana"
	if _japanese_reading == normalized and _converted_strings_by_reading.has(normalized):
		return
	_japanese_reading = normalized
	_refresh_translation()


static func japanese() -> bool:
	return TranslationServer.get_locale().begins_with("ja")


static func japanese_reading() -> String:
	return _japanese_reading


## The same edition for catalog prose that is localized before a screen is built.
static func translations() -> Dictionary:
	if _translation == null:
		_load()
	if not _converted_strings_by_reading.has(_japanese_reading):
		_refresh_translation()
	return _converted_strings_by_reading.get(_japanese_reading, {})


## `english` in the player's language, or itself when there is no translation (or the language is English).
static func t(english: String) -> String:
	if english == "" or not japanese():
		return english
	return String(TranslationServer.translate(english))


## Adult Japanese is authored as complete translations, never guessed from kana syllables at runtime.
## The kana edition keeps its reviewed readings. Inserted values are filled only after translation.
static func apply_japanese_reading(japanese: String) -> String:
	if _japanese_reading == "kanji":
		return String(_kanji_by_japanese.get(japanese, japanese))
	var replacements: Dictionary = KANJI_TO_KANA
	var phrases: Dictionary = KANJI_PHRASES_TO_KANA
	var result := ""
	var word := ""
	var quote := ""
	var safe_text := ""
	for i in japanese.length():
		var character := japanese[i]
		if quote != "":
			safe_text += character
			if character == quote:
				quote = ""
			continue
		if character in ["\"", "'", "`"]:
			quote = character
			safe_text += character
			continue
		safe_text += character
	# Exact, reviewed phrases cover Japanese without spaces. These phrases are applied only outside quoted/code spans.
	var phrase_text := ""
	var quoted := false
	var quote_char := ""
	for i in safe_text.length():
		var character := safe_text[i]
		if quoted:
			phrase_text += character
			if character == quote_char:
				quoted = false
			continue
		if character in ["\"", "'", "`"]:
			quoted = true
			quote_char = character
			phrase_text += character
			continue
		phrase_text += character
		for phrase: String in phrases:
			if phrase_text.ends_with(phrase):
				phrase_text = phrase_text.left(phrase_text.length() - phrase.length()) + String(phrases[phrase])
				break
	if _japanese_reading == "hiragana":
		phrase_text = _strip_known_reading_hints(_replace_reviewed_hiragana_phrases(phrase_text))
	for i in phrase_text.length():
		var character := phrase_text[i]
		if quote != "":
			result += character
			if character == quote:
				quote = ""
			continue
		if character in ["\"", "'", "`"]:
			result += String(replacements.get(word, word)) + character
			word = ""
			quote = character
			continue
		if character in [" ", "\t", "　", "、", "。", "？", "！", "：", "；", "「", "」", "『", "』", "（", "）", "・"]:
			result += String(replacements.get(word, word)) + character
			word = ""
		else:
			word += character
	return result + String(replacements.get(word, word))


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
		return fill(t(String(pattern.english)), args)
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
	_converted_strings_by_reading.clear()
	_translation = Translation.new()
	_translation.locale = "ja"
	var overlay := ContentLocale.load_overlay("ja")
	_japanese_strings = overlay.strings.duplicate()
	_japanese_kanji_strings = overlay.kanji_strings.duplicate()
	_kanji_by_japanese.clear()
	var ambiguous := {}
	for english: String in _japanese_kanji_strings:
		var japanese := String(_japanese_strings[english])
		var adult := String(_japanese_kanji_strings[english])
		if _kanji_by_japanese.has(japanese) and _kanji_by_japanese[japanese] != adult:
			ambiguous[japanese] = true
		_kanji_by_japanese[japanese] = adult
	# Inline Japanese has no English context. Leave an ambiguous phrase alone; keyed text always selects its edition.
	for japanese: String in ambiguous:
		_kanji_by_japanese.erase(japanese)
	var strings: Dictionary = _japanese_strings
	_load_hiragana_phrases()
	var formats: Array[String] = []
	for english: String in strings:
		_translation.add_message(english, String(strings[english]))
		if english.contains("%s") or english.contains("%d"):
			formats.append(english)
	# Longest first, so "%s takes %d from %d bolts." wins over "%s takes %d.".
	formats.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	_patterns.clear()
	for english in formats:
		var regex := RegEx.create_from_string("^" + _pattern_of(english) + "$")
		if regex.is_valid():
			_patterns.append({"regex": regex, "english": english})
	TranslationServer.add_translation(_translation)


## Exact, reviewed full-string readings cover town phrases whose Japanese word boundaries are not explicit.
## Keys are applied longest-first and only outside ASCII quotes/backticks, so IDs and code examples stay unchanged.
static func _load_hiragana_phrases() -> void:
	_hiragana_phrases.clear()
	_hiragana_phrase_keys.clear()
	_hiragana_phrases_by_first.clear()
	var parsed := Jsonc.parse_file("res://content/japanese_hiragana_readings.jsonc")
	if parsed.is_empty() or not parsed.get("ok", false):
		push_error("Japanese hiragana readings could not be loaded")
		return
	var entries: Variant = parsed.get("value", [])
	if not entries is Array:
		push_error("Japanese hiragana readings must be an array")
		return
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var kanji := String(entry.get("kanji", ""))
		var hiragana := String(entry.get("hiragana", ""))
		if kanji != "" and hiragana != "":
			_hiragana_phrases[kanji] = hiragana
			_hiragana_phrase_keys.append(kanji)
	_hiragana_phrase_keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for phrase: String in _hiragana_phrase_keys:
		var first := phrase[0]
		var bucket: Array[String] = []
		for existing: Variant in _hiragana_phrases_by_first.get(first, []):
			bucket.append(String(existing))
		bucket.append(phrase)
		_hiragana_phrases_by_first[first] = bucket


static func _replace_reviewed_hiragana_phrases(text: String) -> String:
	if _hiragana_phrases.has(text):
		return String(_hiragana_phrases[text])
	var result := ""
	var unquoted := ""
	var quote := ""
	for i in text.length():
		var character := text[i]
		if quote != "":
			result += character
			if character == quote:
				quote = ""
			continue
		if character in ["\"", "'", "`"]:
			result += _replace_phrase_segment(unquoted) + character
			unquoted = ""
			quote = character
		else:
			unquoted += character
	unquoted = _replace_phrase_segment(unquoted)
	if _japanese_reading == "hiragana":
		for kanji: String in KANJI_TO_KANA:
			var hinted := kanji + "（" + String(KANJI_TO_KANA[kanji]) + "）"
			unquoted = unquoted.replace(hinted, String(KANJI_TO_KANA[kanji]))
	return result + unquoted


static func _replace_phrase_segment(text: String) -> String:
	var result := ""
	var index := 0
	while index < text.length():
		var matched := ""
		var candidates: Array = _hiragana_phrases_by_first.get(text[index], [])
		for phrase: String in candidates:
			if not text.substr(index).begins_with(phrase):
				continue
			var end := index + phrase.length()
			var left_ok := index == 0 or _is_reading_boundary(text[index - 1])
			var right_ok := end == text.length() or _is_reading_boundary(text[end])
			if left_ok and right_ok:
				matched = phrase
				break
		if matched != "":
			result += String(_hiragana_phrases[matched])
			index += matched.length()
		else:
			result += text[index]
			index += 1
	return result


static func _is_reading_boundary(character: String) -> bool:
	return character in [
		" ", "\t", "　", "、", "。", "？", "！", "：", "；", "「", "」", "『", "』", "（", "）", "・", ",", ".", "?", "!", ":", ";", "(", ")", "/", "…"
	]


static func _strip_known_reading_hints(text: String) -> String:
	var result := ""
	var unquoted := ""
	var quote := ""
	for i in text.length():
		var character := text[i]
		if quote != "":
			result += character
			if character == quote:
				quote = ""
			continue
		if character in ["\"", "'", "`"]:
			result += _strip_hints_from_segment(unquoted) + character
			unquoted = ""
			quote = character
		else:
			unquoted += character
	return result + _strip_hints_from_segment(unquoted)


static func _strip_hints_from_segment(text: String) -> String:
	var result := text
	for kanji: String in KANJI_TO_KANA:
		var hinted := kanji + "（" + String(KANJI_TO_KANA[kanji]) + "）"
		result = result.replace(hinted, String(KANJI_TO_KANA[kanji]))
	return result


## Auto-translating Controls read the Translation directly. Rebuild every entry from the immutable catalog copy.
static func _refresh_translation() -> void:
	if _translation == null or _japanese_strings.is_empty():
		return
	var was_japanese := TranslationServer.get_locale().begins_with("ja")
	if not _converted_strings_by_reading.has(_japanese_reading):
		var converted := {}
		for english: String in _japanese_strings:
			converted[english] = (
				String(_japanese_kanji_strings.get(english, _japanese_strings[english]))
				if _japanese_reading == "kanji" else apply_japanese_reading(String(_japanese_strings[english]))
			)
		_converted_strings_by_reading[_japanese_reading] = converted
	var converted_strings: Dictionary = _converted_strings_by_reading[_japanese_reading]
	TranslationServer.remove_translation(_translation)
	for english: String in _japanese_strings:
		_translation.erase_message(english)
		_translation.add_message(english, String(converted_strings[english]))
	TranslationServer.add_translation(_translation)
	if was_japanese:
		# Refresh mounted auto-translate controls without running them through a temporary English locale.
		var scene_tree := Engine.get_main_loop() as SceneTree
		if scene_tree != null:
			scene_tree.root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)


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
