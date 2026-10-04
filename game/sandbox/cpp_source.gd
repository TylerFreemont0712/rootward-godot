class_name CppSource
extends RefCounted
## A C++ card's code made ready for the ahead-of-time build (ADR-0046): counters put into its loops and functions, and
## the whole wrapped in a namespace of its own so two cards' helpers never collide. The build (tools/build_cpp.gd,
## scripts/build-cpp.sh) writes one translation unit a card.
##
## LEARN: `#line 1 "amplify.cpp"` tells the compiler that the next line is line 1 of amplify.cpp, so `__LINE__` (which
## the loop counter records) and any compiler error name the card's own line, not the generated file's.

const LOOP_HEAD := "^\\s*(for|while)\\s*\\("
## A function definition whose body opens on its own line's end: a return type, a name, its parameters, `{`.
const FUNCTION := "^\\s*(?:[A-Za-z_][\\w:<>,&*\\s]*?[\\s&*>])([A-Za-z_]\\w*)\\s*\\([^;=]*\\)\\s*(?:const\\s*)?\\{\\s*$"
const NOT_FUNCTIONS: Array[String] = ["if", "for", "while", "switch", "return", "else", "catch", "do"]

static var _loop: RegEx
static var _function: RegEx


## `code` with a loop counter at the start of every loop body and a call counter at the top of every function, each on
## the line it measures, so no line moves.
static func instrument(code: String) -> String:
	if _loop == null:
		_loop = RegEx.create_from_string(LOOP_HEAD)
		_function = RegEx.create_from_string(FUNCTION)
	var out: PackedStringArray = []
	for text in code.split("\n"):
		out.append(_line(text))
	return "\n".join(out)


static func _line(text: String) -> String:
	var comment := text.find("//")
	var code := text if comment < 0 else text.substr(0, comment)
	var tail := "" if comment < 0 else text.substr(comment)
	if _loop.search(code) != null:
		var end := header_end(code)
		if end >= 0:
			var rest := code.substr(end + 1).strip_edges()
			if rest.begins_with("{"):
				var brace := code.find("{", end + 1)
				return code.substr(0, brace + 1) + " ROOTWARD_LOOP();" + code.substr(brace + 1) + tail
			if rest != "" and rest.ends_with(";"):
				return code.substr(0, end + 1) + " { ROOTWARD_LOOP(); " + rest + " }" + tail
		return text
	var named := _function.search(code)
	if named != null and not named.get_string(1) in NOT_FUNCTIONS:
		var brace := code.rfind("{")
		return code.substr(0, brace + 1) + ' ROOTWARD_CALL("%s");' % named.get_string(1) + code.substr(brace + 1) + tail
	return text


## Where a `for (` or `while (` header's closing parenthesis is, or -1.
static func header_end(text: String) -> int:
	var start := text.find("(")
	if start < 0:
		return -1
	var depth := 0
	for i in range(start, text.length()):
		var c := text[i]
		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0:
				return i
	return -1


## One card's translation unit: its mode's header, a namespace of its own, and its instrumented code at its own lines.
static func unit(id: String, code: String, header: String) -> String:
	return (
		'#include "%s"\nnamespace %s {\n#line 1 "%s.cpp"\n%s\n}\n'
		% [header, namespace_of(id), id.get_slice("~", 0), instrument(code)]
	)


## A C++ name for a card id (or a mutant's, "<id>~<op>"): letters, digits and underscores.
static func namespace_of(id: String) -> String:
	var out := "card_"
	for c in id:
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return out
