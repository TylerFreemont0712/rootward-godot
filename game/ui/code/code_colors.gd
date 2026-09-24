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


static func bbcode(line: String, language: String) -> String:
	var keywords := String(KEYWORDS.get(language, KEYWORDS.python)).split(" ")
	var comment := "#" if language == "python" else "//"
	var out := ""
	var i := 0
	while i < line.length():
		var character := line[i]
		if line.substr(i, comment.length()) == comment:
			return out + _paint(line.substr(i), COMMENT)
		if character == '"' or character == "'" or character == "`":
			var end := i + 1
			while end < line.length() and line[end] != character:
				end += 2 if line[end] == "\\" else 1
			end = mini(end + 1, line.length())
			out += _paint(line.substr(i, end - i), STRING)
			i = end
		elif _is_digit(character):
			var end := i
			while end < line.length() and (_is_digit(line[end]) or line[end] == "."):
				end += 1
			out += _paint(line.substr(i, end - i), NUMBER)
			i = end
		elif _is_word(character):
			var end := i
			while end < line.length() and (_is_word(line[end]) or _is_digit(line[end])):
				end += 1
			var word := line.substr(i, end - i)
			if word in keywords:
				out += _paint(word, KEYWORD)
			elif end < line.length() and line[end] == "(":
				out += _paint(word, CALL)
			else:
				out += word
			i = end
		else:
			out += "[lb]" if character == "[" else character
			i += 1
	return out


static func _paint(text: String, colour: String) -> String:
	return "[color=%s]%s[/color]" % [colour, text.replace("[", "[lb]")]


static func _is_digit(character: String) -> bool:
	return character >= "0" and character <= "9"


static func _is_word(character: String) -> bool:
	return (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or character == "_"
