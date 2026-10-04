class_name ProgramSource
extends RefCounted
## A Program as the code it is (ADR-0012): its imports at the top (ADR-0018), then a `program` function that starts from
## the seed volley and calls each card's function in slot order (an import's hook where it runs), then every function
## it calls, once, in the run's language. The code panel draws these lines, and writes in the new ones as cards are
## played.
##
##   var lines := ProgramSource.lines("python", ["salvo", "merge-sort"], catalog)
##   # [{text, kind, key, card?, slot?}], kind one of import|comment|blank|def|seed|call|hook|return|close|body
##   # (a call's slot is its step: the program's cards but its imports)

## The `program` function's first line in each language.
const OPENERS := {
	"python": "def program(battle):",
	"javascript": "function program(battle) {",
	"cpp": "Bolts program(const Battle& battle) {",
}


## `key` names a line for as long as it means the same thing, so the panel can tell which lines are new: a call is keyed
## by its slot and card, a card's function by the card and the line within it.
static func lines(
	language: String, card_ids: Array, catalog: Dictionary, seed: Array = [], imports: Array = [], hooks: Array = []
) -> Array[Dictionary]:
	var python := language == SandboxJob.PYTHON
	var comment := CodeLanguage.comment(language)
	var out: Array[Dictionary] = []
	for id: String in imports:
		var import_line: String = ((catalog.shards.get(id, {}) as Dictionary).get("line", {}) as Dictionary).get(
			language, "import %s" % id
		)
		var line := _add(out, import_line, "import", "import:" + id)
		line.card = id
	if not imports.is_empty():
		_add(out, "", "blank", "imports-end")
	var steps := ProgramDeck.steps(card_ids, catalog)
	var names: Array[String] = []
	for id: String in steps:
		names.append((catalog.shards.get(id, {}) as Dictionary).get("name", id))
	var chain := " → ".join(names) if not names.is_empty() else "nothing yet"
	_add(out, "%s Program: %s" % [comment, chain], "comment", "head")
	_add(out, OPENERS.get(language, OPENERS.python), "def", "def")
	if seed.is_empty():
		seed = ProgramRules.config_of(catalog).seed
	_add(out, _seed_line(seed, language), "seed", "seed")
	var called: Array = []
	for slot in steps.size():
		var card: Dictionary = catalog.shards.get(steps[slot], {})
		called.append_array(_hooks(out, hooks, "before", card, slot, language, catalog))
		var call := _call(card, String(steps[slot]), language)
		var line := _add(out, call, "call", "call:%d:%s" % [slot, steps[slot]])
		line.card = steps[slot]
		line.slot = slot
		called.append(steps[slot])
		called.append_array(_hooks(out, hooks, "after", card, slot, language, catalog))
	if steps.is_empty():
		_add(out, "%s%s play cards to write the program" % [_indent(language), comment], "comment", "empty")
	_add(out, "    return bolts" if python else "  return bolts;", "return", "return")
	if not python:
		_add(out, "}", "close", "close")
	var seen := {}
	for id: String in called:
		if seen.has(id):
			continue
		seen[id] = true
		_add(out, "", "blank", "gap:" + id)
		var code: String = ((catalog.shards.get(id, {}) as Dictionary).get("code", {}) as Dictionary).get(language, "")
		var number := 0
		for text in code.strip_edges(false, true).split("\n"):
			var line := _add(out, text, "def" if number == 0 else "body", "fn:%s:%d" % [id, number])
			line.card = id
			number += 1
	return out


static func _indent(language: String) -> String:
	return "    " if language == SandboxJob.PYTHON else "  "


static func _call(card: Dictionary, id: String, language: String) -> String:
	var name := SpellHarness.function_name(card, language)
	if not card.has("function"):
		name = id
	return (
		"    bolts = %s(bolts, battle)" % name
		if language == SandboxJob.PYTHON
		else "  bolts = %s(bolts, battle);" % name
	)


## The calls an import's hooks add around the card at `slot` (heapq's before a strike), as lines; returns their cards.
static func _hooks(
	out: Array[Dictionary],
	hooks: Array,
	when: String,
	card: Dictionary,
	slot: int,
	language: String,
	catalog: Dictionary
) -> Array:
	var cards: Array = []
	for hook: Dictionary in hooks:
		if hook.when != when or hook.role != card.get("role", ""):
			continue
		var by: Dictionary = catalog.shards.get(hook.card, {})
		var call := _call(by, String(hook.card), language)
		var line := _add(out, call, "hook", "hook:%d:%s:%s" % [slot, when, hook.card])
		line.card = hook.card
		cards.append(hook.card)
	return cards


static func _add(out: Array[Dictionary], text: String, kind: String, key: String) -> Dictionary:
	var line := {"text": text, "kind": kind, "key": key}
	out.append(line)
	return line


## The line that starts the program from its seed volley: n copies of one bolt (each its own object, so no card that
## changes one bolt changes them all), or, when they differ, a literal list.
static func _seed_line(bolts: Array, language: String) -> String:
	var first: Dictionary = bolts[0] if not bolts.is_empty() else {}
	var same := bolts.size() > 1 and bolts.all(func(bolt: Dictionary) -> bool: return bolt == first)
	match language:
		SandboxJob.PYTHON:
			if same:
				return "    bolts = [%s for _ in range(%d)]" % [bolt_literal(first, language), bolts.size()]
			return "    bolts = %s" % list_literal(bolts, language)
		SandboxJob.CPP:
			if same:
				return "  Bolts bolts(%d, %s);" % [bolts.size(), bolt_literal(first, language)]
			return "  Bolts bolts = %s;" % list_literal(bolts, language)
	if same:
		return "  let bolts = Array.from({ length: %d }, () => (%s));" % [bolts.size(), bolt_literal(first, language)]
	return "  let bolts = %s;" % list_literal(bolts, language)


## A list of bolts as a literal of the language.
static func list_literal(bolts: Array, language: String) -> String:
	var parts: PackedStringArray = []
	for bolt: Dictionary in bolts:
		parts.append(bolt_literal(bolt, language))
	return ("{%s}" if language == SandboxJob.CPP else "[%s]") % ", ".join(parts)


## One bolt as a literal: Python's dict, JavaScript's object, or C++'s designated initializers (`Bolt{.power = 3}`).
static func bolt_literal(bolt: Dictionary, language: String) -> String:
	var fields: PackedStringArray = []
	for key: String in bolt:
		var value: Variant = bolt[key]
		var shown := '"%s"' % value if value is String else JsMath.text(value)
		if value is bool:
			shown = ("True" if value else "False") if language == SandboxJob.PYTHON else ("true" if value else "false")
		match language:
			SandboxJob.PYTHON:
				fields.append('"%s": %s' % [key, shown])
			SandboxJob.CPP:
				fields.append(".%s = %s" % [key, shown])
			_:
				fields.append("%s: %s" % [key, shown])
	match language:
		SandboxJob.PYTHON:
			return "{%s}" % ", ".join(fields)
		SandboxJob.CPP:
			return "Bolt{%s}" % ", ".join(fields)
	return "{ %s }" % ", ".join(fields)
