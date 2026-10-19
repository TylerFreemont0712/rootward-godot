class_name CodeComments
extends RefCounted
## The comments in starter code, in the player's language (Concept/v0.4/06): a starter's `# ...` (Python) and `// ...`
## (JavaScript) lines are English in the game's files, and each comment's text is translated through Text, the marker
## and the indent kept. The code itself is never touched.
##
##   CodeComments.localized("def f(x):\n    # x is a number.\n    return x\n")
##   # "def f(x):\n    # x は かずだよ。\n    return x\n" when the language is Japanese


## The text of a line's comment ("x is a number." for "    # x is a number."), or "" when the line is not a comment.
## Only whole-line comments: a comment after code is left alone (it may sit inside a string).
static func comment_of(line: String) -> String:
	var bare := line.strip_edges(true, false)
	for marker: String in ["# ", "// "]:
		if bare.begins_with(marker):
			return bare.substr(marker.length()).strip_edges()
	return ""


## `code` with each whole-line comment's text translated (Text.t), the rest as it was.
static func localized(code: String) -> String:
	if not Text.japanese():
		return code
	var out := PackedStringArray()
	for line in code.split("\n"):
		var text := comment_of(line)
		if text == "":
			out.append(line)
			continue
		var translated := Text.t(text)
		out.append(line.substr(0, line.length() - line.strip_edges(true, false).length()) + _marker(line) + translated)
	return "\n".join(out)


static func _marker(line: String) -> String:
	return "# " if line.strip_edges(true, false).begins_with("# ") else "// "
