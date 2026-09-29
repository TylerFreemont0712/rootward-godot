class_name ProgramMutants
extends RefCounted
## The Mutator's edits (docs/NewEnemies.md, ADR-0026): a mutant is a card's own code with one small operator changed,
## as a mutation-testing tool (mutmut, Stryker) makes them. The sandbox runs the mutant exactly as written, so its
## preview is the truth. Pure text functions: the same card and operator always make the same mutant.
##
##   var mutant := ProgramMutants.mutate(card.code.python, "python", 0)   # {code, op, before, after, line} or {}

## Each operator: what it finds and what it writes, in one language or both. Tried in order from a starting index, the
## first that occurs in the code is the one used. Comparisons first: the classic mutants.
const OPERATORS: Array[Dictionary] = [
	{"find": " >= ", "into": " > ", "name": ">= becomes >"},
	{"find": " <= ", "into": " < ", "name": "<= becomes <"},
	{"find": " > ", "into": " >= ", "name": "> becomes >="},
	{"find": " < ", "into": " <= ", "name": "< becomes <="},
	{"find": "max(", "into": "min(", "name": "max becomes min"},
	{"find": "min(", "into": "max(", "name": "min becomes max"},
	{"find": "Math.max(", "into": "Math.min(", "name": "max becomes min", "language": "javascript"},
	{"find": "Math.min(", "into": "Math.max(", "name": "min becomes max", "language": "javascript"},
	{"find": " + 1", "into": " - 1", "name": "+ 1 becomes - 1"},
	{"find": " - 1", "into": " + 1", "name": "- 1 becomes + 1"},
	{"find": "reverse=True", "into": "reverse=False", "name": "the sort turns around", "language": "python"},
	{
		"find": "a.power - b.power",
		"into": "b.power - a.power",
		"name": "the sort turns around",
		"language": "javascript"
	},
	{
		"find": "b.power - a.power",
		"into": "a.power - b.power",
		"name": "the sort turns around",
		"language": "javascript"
	},
	{"find": " * 2", "into": " * 1", "name": "* 2 becomes * 1"},
	{"find": " + ", "into": " - ", "name": "+ becomes -"},
]


## The mutant of `code` from operator `start` on (wrapping round), or {} when no operator occurs in it. The edit is made
## in the function's body only (never its first line, the signature), at the operator's first occurrence there.
static func mutate(code: String, language: String, start: int) -> Dictionary:
	var body_at := code.find("\n")
	if body_at < 0:
		return {}
	for step in OPERATORS.size():
		var index := posmod(start + step, OPERATORS.size())
		var op: Dictionary = OPERATORS[index]
		if op.has("language") and op.language != language:
			continue
		var at := _find_in_code(code, String(op.find), body_at)
		if at < 0:
			continue
		var mutated := code.substr(0, at) + String(op.into) + code.substr(at + String(op.find).length())
		var line := code.substr(0, at).count("\n")
		var lines := code.split("\n")
		var changed := mutated.split("\n")
		return {
			"code": mutated, "op": index, "name": op.name, "line": line, "before": lines[line], "after": changed[line]
		}
	return {}


## Whether a card has any mutant at all in this language.
static func mutable(code: String, language: String) -> bool:
	return not mutate(code, language, 0).is_empty()


## The first occurrence of `needle` at or after `from` that is code, not a comment: a mutant must change what runs.
static func _find_in_code(code: String, needle: String, from: int) -> int:
	var at := code.find(needle, from)
	while at >= 0:
		var line_start := code.rfind("\n", at) + 1
		var before := code.substr(line_start, at - line_start)
		if not ("#" in before or "//" in before):
			return at
		at = code.find(needle, at + 1)
	return -1
