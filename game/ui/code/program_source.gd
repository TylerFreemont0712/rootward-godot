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


## `key` names a line for as long as it means the same thing, so the panel can tell which lines are new: a call is keyed
## by its slot and card, a card's function by the card and the line within it.
static func lines(
	language: String, card_ids: Array, catalog: Dictionary, seed: Array = [], imports: Array = [], hooks: Array = []
) -> Array[Dictionary]:
	var python := language == SandboxJob.PYTHON
	var comment := "#" if python else "//"
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
	_add(out, "def program(battle):" if python else "function program(battle) {", "def", "def")
	if seed.is_empty():
		seed = ProgramRules.config_of(catalog).seed
	var start := (
		"    bolts = %s" % _seed_code(seed, python) if python else "  let bolts = %s;" % _seed_code(seed, python)
	)
	_add(out, start, "seed", "seed")
	var called: Array = []
	for slot in steps.size():
		var card: Dictionary = catalog.shards.get(steps[slot], {})
		called.append_array(_hooks(out, hooks, "before", card, slot, python, catalog))
		var line := _add(out, _call(card, String(steps[slot]), python), "call", "call:%d:%s" % [slot, steps[slot]])
		line.card = steps[slot]
		line.slot = slot
		called.append(steps[slot])
		called.append_array(_hooks(out, hooks, "after", card, slot, python, catalog))
	if steps.is_empty():
		_add(out, "    %s play cards to write the program" % comment, "comment", "empty")
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


static func _call(card: Dictionary, id: String, python: bool) -> String:
	var name := SpellHarness.function_name(card, SandboxJob.PYTHON if python else SandboxJob.JAVASCRIPT)
	if not card.has("function"):
		name = id
	return "    bolts = %s(bolts, battle)" % name if python else "  bolts = %s(bolts, battle);" % name


## The calls an import's hooks add around the card at `slot` (heapq's before a strike), as lines; returns their cards.
static func _hooks(
	out: Array[Dictionary], hooks: Array, when: String, card: Dictionary, slot: int, python: bool, catalog: Dictionary
) -> Array:
	var cards: Array = []
	for hook: Dictionary in hooks:
		if hook.when != when or hook.role != card.get("role", ""):
			continue
		var by: Dictionary = catalog.shards.get(hook.card, {})
		var line := _add(out, _call(by, String(hook.card), python), "hook", "hook:%d:%s:%s" % [slot, when, hook.card])
		line.card = hook.card
		cards.append(hook.card)
	return cards


static func _add(out: Array[Dictionary], text: String, kind: String, key: String) -> Dictionary:
	var line := {"text": text, "kind": kind, "key": key}
	out.append(line)
	return line


## The seed volley as code: n copies of one bolt as a comprehension (each copy its own object, so no card that changes
## one bolt changes them all), or, when they differ, a literal list.
static func _seed_code(bolts: Array, python: bool) -> String:
	var first: Dictionary = bolts[0] if not bolts.is_empty() else {}
	if bolts.size() > 1 and bolts.all(func(bolt: Dictionary) -> bool: return bolt == first):
		var one := _literal([first], python).trim_prefix("[").trim_suffix("]")
		if python:
			return "[%s for _ in range(%d)]" % [one, bolts.size()]
		return "Array.from({ length: %d }, () => (%s))" % [bolts.size(), one]
	return _literal(bolts, python)


## The seed volley as a literal of the language: Python's dict syntax, or JavaScript's object syntax.
static func _literal(bolts: Array, python: bool) -> String:
	var parts: PackedStringArray = []
	for bolt: Dictionary in bolts:
		var fields: PackedStringArray = []
		for key: String in bolt:
			var value: Variant = bolt[key]
			var shown := '"%s"' % value if value is String else JsMath.text(value)
			if value is bool:
				shown = ("True" if value else "False") if python else ("true" if value else "false")
			fields.append(('"%s": %s' if python else "%s: %s") % [key, shown])
		parts.append("{%s}" % ", ".join(fields) if python else "{ %s }" % ", ".join(fields))
	return "[%s]" % ", ".join(parts)
