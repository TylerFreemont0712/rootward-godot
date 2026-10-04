class_name ProgramBodySource
extends RefCounted
## A next-card body rendered as ordinary slice, call and join statements. Slots retain their original identity.


static func append(
	out: Array[Dictionary],
	steps: Array,
	slot: int,
	language: String,
	catalog: Dictionary,
	hooks: Array,
	options: Dictionary
) -> Dictionary:
	var used := {}
	return _body(out, steps, slot, "bolts", "", int(options.depth), language, catalog, hooks, options, used)


static func _body(
	out: Array[Dictionary],
	steps: Array,
	slot: int,
	volley: String,
	prefix: String,
	depth: int,
	language: String,
	catalog: Dictionary,
	hooks: Array,
	options: Dictionary,
	used: Dictionary
) -> Dictionary:
	if language != "python":
		_line(out, "  {", "scope:" + prefix)
	var card: Dictionary = catalog.shards[steps[slot]]
	var nested: bool = depth > 1 and card.get("splits", false) and slot + 1 < steps.size()
	var parts := _halves(out, volley, prefix, language)
	if depth > 1 and not nested:
		var quarters: Array[String] = []
		for part in parts:
			quarters.append_array(_halves(out, part, part + "_", language))
		parts = quarters
	for part in parts:
		_hook(out, hooks, "before", card, slot, part, language, catalog)
	var function := SpellHarness.function_name(card, language)
	var statements: Array[String] = []
	for part in parts:
		statements.append("%s = %s(%s, battle)" % [part, function, part])
	var text := (
		"    %s = %s"
		% [
			", ".join(parts),
			", ".join(parts.map(func(part: String) -> String: return "%s(%s, battle)" % [function, part]))
		]
	)
	if language != "python":
		text = "  " + "; ".join(statements) + ";"
	var kind := "body" if used.has(slot) else "call"
	used[slot] = true
	out.append({"text": text, "kind": kind, "key": "body:%d:%s" % [slot, prefix], "card": steps[slot], "slot": slot})
	var called: Array = [steps[slot]]
	for hook: Dictionary in hooks:
		if hook.role == card.get("role", ""):
			called.append(hook.card)
	for part in parts:
		_hook(out, hooks, "after", card, slot, part, language, catalog)
	var next := slot + 1
	if nested:
		for part in parts:
			var inside := _body(
				out, steps, slot + 1, part, part + "_", depth - 1, language, catalog, hooks, options, used
			)
			next = int(inside.next)
			called.append_array(inside.called)
	_join(out, volley, parts, prefix, language)
	var extra := int(options.get("rejoin_power", 0))
	if extra > 0:
		var boost := "    %s = [dict(b, power=b['power'] + %d) for b in %s]" % [volley, extra, volley]
		if language == "javascript":
			boost = "  %s = %s.map(b => ({ ...b, power: b.power + %d }));" % [volley, volley, extra]
		elif language == "cpp":
			boost = "  for (auto& b : %s) b.power += %d;" % [volley, extra]
		_line(out, boost, "boost:" + prefix)
	if language != "python":
		_line(out, "  }", "scope-end:" + prefix)
	return {"next": next, "called": called}


static func _halves(out: Array[Dictionary], volley: String, prefix: String, language: String) -> Array[String]:
	var left := prefix + "left"
	var right := prefix + "right"
	var middle := prefix + "middle"
	match language:
		"python":
			_line(out, "    %s = (len(%s) + 1) // 2" % [middle, volley], "mid:" + prefix)
			_line(
				out, "    %s, %s = %s[:%s], %s[%s:]" % [left, right, volley, middle, volley, middle], "split:" + prefix
			)
		"javascript":
			_line(out, "  const %s = Math.ceil(%s.length / 2);" % [middle, volley], "mid:" + prefix)
			_line(
				out,
				"  let %s = %s.slice(0, %s), %s = %s.slice(%s);" % [left, volley, middle, right, volley, middle],
				"split:" + prefix
			)
		"cpp":
			_line(
				out, "  const auto %s = %s.begin() + (%s.size() + 1) / 2;" % [middle, volley, volley], "mid:" + prefix
			)
			_line(
				out,
				"  Bolts %s(%s.begin(), %s), %s(%s, %s.end());" % [left, volley, middle, right, middle, volley],
				"split:" + prefix
			)
	return [left, right]


static func _join(
	out: Array[Dictionary], volley: String, parts: Array[String], prefix: String, language: String
) -> void:
	match language:
		"python":
			_line(out, "    %s = %s" % [volley, " + ".join(parts)], "join:" + prefix)
		"javascript":
			_line(out, "  %s = [].concat(%s);" % [volley, ", ".join(parts)], "join:" + prefix)
		"cpp":
			_line(out, "  %s.clear();" % volley, "join:" + prefix)
			for part in parts:
				_line(
					out,
					"  %s.insert(%s.end(), %s.begin(), %s.end());" % [volley, volley, part, part],
					"join:" + prefix + part
				)


static func _hook(
	out: Array[Dictionary],
	hooks: Array,
	when: String,
	card: Dictionary,
	slot: int,
	part: String,
	language: String,
	catalog: Dictionary
) -> void:
	for hook: Dictionary in hooks:
		if hook.when != when or hook.role != card.get("role", ""):
			continue
		var function := SpellHarness.function_name(catalog.shards[hook.card], language)
		var call := "%s = %s(%s, battle)" % [part, function, part]
		_line(
			out,
			("    " + call) if language == "python" else ("  " + call + ";"),
			"hook:%d:%s:%s:%s" % [slot, part, when, hook.card]
		)


static func _line(out: Array[Dictionary], text: String, key: String) -> void:
	out.append({"text": text, "kind": "body", "key": "split:" + key})
