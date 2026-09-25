class_name CodeColors
extends RefCounted
## One line of Python or JavaScript as BBCode with its keywords, strings, numbers and comments coloured, for a
## RichTextLabel. A line at a time is enough: shard code has no strings that span lines.
##
## LEARN: a tiny tokenizer walks the line once, left to right, deciding what each character starts (a string, a number,
## a word, a comment). Regular expressions could colour each kind, but they would fight over overlaps ("#" inside a
## string); one pass that knows where it is never does.

## The words each language reserves, space-separated.
const KEYWORDS := {
	"python":
	(
		"def return for in if elif else while and or not lambda import from True False None "
		+ "break continue pass is with as"
	),
	"javascript":
	"function return for of in if else while const let var true false null undefined new break continue typeof",
}
const KEYWORD := "#d19bff"
const STRING := "#9fd07a"
const NUMBER := "#f2a541"
const COMMENT := "#6f5e46"
const CALL := "#82d8ff"
## A card's plain-words summary, written as a comment the way a docstring would be: green, like most editors' comments.
const DOC := "#86c17a"


static func bbcode(line: String, language: String) -> String:
	var out := ""
	for token in tokens(line, language):
		out += _paint(token.text, token.colour) if token.colour != "" else String(token.text).replace("[", "[lb]")
	return out


## The line cut into pieces, each with its colour ("" for plain text), in order: joined, they are the line again.
static func tokens(line: String, language: String) -> Array[Dictionary]:
	var keywords := String(KEYWORDS.get(language, KEYWORDS.python)).split(" ")
	var comment := "#" if language == "python" else "//"
	var out: Array[Dictionary] = []
	var i := 0
	while i < line.length():
		var character := line[i]
		if line.substr(i, comment.length()) == comment:
			out.append({"text": line.substr(i), "colour": COMMENT})
			return out
		if character == '"' or character == "'" or character == "`":
			var end := i + 1
			while end < line.length() and line[end] != character:
				end += 2 if line[end] == "\\" else 1
			end = mini(end + 1, line.length())
			out.append({"text": line.substr(i, end - i), "colour": STRING})
			i = end
		elif _is_digit(character):
			var end := i
			while end < line.length() and (_is_digit(line[end]) or line[end] == "."):
				end += 1
			out.append({"text": line.substr(i, end - i), "colour": NUMBER})
			i = end
		elif _is_word(character):
			var end := i
			while end < line.length() and (_is_word(line[end]) or _is_digit(line[end])):
				end += 1
			var word := line.substr(i, end - i)
			var colour := ""
			if word in keywords:
				colour = KEYWORD
			elif end < line.length() and line[end] == "(":
				colour = CALL
			out.append({"text": word, "colour": colour})
			i = end
		else:
			out.append({"text": character, "colour": ""})
			i += 1
	return out


static func _paint(text: String, colour: String) -> String:
	return "[color=%s]%s[/color]" % [colour, text.replace("[", "[lb]")]


static func _is_digit(character: String) -> bool:
	return character >= "0" and character <= "9"


static func _is_word(character: String) -> bool:
	return (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or character == "_"


## Plain words as comment lines of `language` ("# " or "// " before each), wrapped at `columns` characters.
static func comment_lines(text: String, language: String, columns: int) -> PackedStringArray:
	var mark := "# " if language == "python" else "// "
	var lines: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		if line != "" and mark.length() + line.length() + 1 + word.length() > columns:
			lines.append(mark + line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(mark + line)
	return lines


## A card's code for a narrow box: comment lines longer than `columns` rewrapped under their own indentation and mark,
## code lines left as they are (the box clips them).
static func fit_code(code: String, language: String, columns: int) -> PackedStringArray:
	var mark := "#" if language == "python" else "//"
	var out: PackedStringArray = []
	for line in code.strip_edges(false, true).split("\n"):
		var body := line.strip_edges(true, false)
		if line.length() <= columns or not body.begins_with(mark):
			out.append(line)
			continue
		var indent := line.substr(0, line.length() - body.length())
		for part in comment_lines(body.trim_prefix(mark).strip_edges(), language, columns - indent.length()):
			out.append(indent + part)
	return out
