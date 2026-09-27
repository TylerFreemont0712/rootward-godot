class_name ProgramSource
extends RefCounted
## A Program as the code it is (ADR-0012): a `program` function that starts from the seed volley and calls each card's
## function in slot order, then every card's function once, in the run's language. The code panel draws these lines,
## and writes in the new ones as cards are played.
##
##   var lines := ProgramSource.lines("python", ["salvo", "merge-sort"], catalog)
##   # [{text, kind, key, card?, slot?}], kind one of comment|blank|def|seed|call|return|close|body


## `key` names a line for as long as it means the same thing, so the panel can tell which lines are new: a call is keyed
## by its slot and card, a card's function by the card and the line within it.
static func lines(language: String, card_ids: Array, catalog: Dictionary, seed: Array = []) -> Array[Dictionary]:
	var python := language == SandboxJob.PYTHON
	var comment := "#" if python else "//"
	var out: Array[Dictionary] = []
	var names: Array[String] = []
	for id: String in card_ids:
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
	for slot in card_ids.size():
		var card: Dictionary = catalog.shards.get(card_ids[slot], {})
		var name := SpellHarness.function_name(card, language) if card.has("function") else String(card_ids[slot])
		var call := "    bolts = %s(bolts, battle)" % name if python else "  bolts = %s(bolts, battle);" % name
		var line := _add(out, call, "call", "call:%d:%s" % [slot, card_ids[slot]])
		line.card = card_ids[slot]
		line.slot = slot
	if card_ids.is_empty():
		_add(out, "    %s play cards to write the program" % comment, "comment", "empty")
	_add(out, "    return bolts" if python else "  return bolts;", "return", "return")
	if not python:
		_add(out, "}", "close", "close")
	var seen := {}
	for id: String in card_ids:
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
