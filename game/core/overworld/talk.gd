class_name Talk
extends RefCounted
## A conversation with someone in town (ADR-0061): nodes of lines, choices that lead to other nodes, and flags the
## talk sets, so the town remembers what was said. Pure: the dialogue box asks what to show and says what was chosen.
##
##   var node := Talk.opening(talk, flags)   # the first node, picked by the talk's `start` rules
##   Talk.lines(talk, node)                  # [{text, speaker, mood}]
##   Talk.choices(talk, node, flags)         # [{text, goto}], only those whose `if` holds
##   Talk.next(talk, node)                   # where a node without choices goes ("" ends the talk)
##   Talk.sets(talk, node)                   # flags reaching this node sets
##
## A talk in content:
##   {"id": "innkeeper", "start": [{"if": {"flag": "met"}, "goto": "again"}, {"goto": "hello"}],
##    "nodes": {"hello": {"lines": [{"text": "...", "mood": "happy"}], "choices": [{"text": "...", "goto": "news"}],
##              "set": ["met"], "next": "bye"}}}
## A line's `speaker` defaults to the person spoken to; "hotaru" is the firefly, "you" is the player.


## The prefix of a bag count among the facts a condition sees ("bag:cabbage": 3).
const BAG_FACT := "bag:"


static func opening(talk: Dictionary, flags: Dictionary) -> String:
	for rule: Dictionary in talk.get("start", []):
		if holds(rule.get("if", {}), flags):
			return String(rule.get("goto", ""))
	return ""


## A condition: {"flag": "x"} (set), {"not": "x"} (not set), {"all": [...]} (every one), {"has": "cabbage",
## "at_least": 3} (that many in the bag, v0.4), or {} (always). The bag's counts are facts the town puts beside the
## flags as "bag:<item>" (Parts.facts); they are never saved, and a talk asked without them sees an empty bag.
static func holds(condition: Dictionary, flags: Dictionary) -> bool:
	if condition.has("flag") and not bool(flags.get(String(condition.flag), false)):
		return false
	if condition.has("has") and has_count(String(condition.has), flags) < int(condition.get("at_least", 1)):
		return false
	if condition.has("not") and bool(flags.get(String(condition.not), false)):
		return false
	for part: Dictionary in condition.get("all", []):
		if not holds(part, flags):
			return false
	return true


## How many of `item` the bag holds, from the facts beside the flags (0 when they are not there).
static func has_count(item: String, flags: Dictionary) -> int:
	var count: Variant = flags.get(BAG_FACT + item, 0)
	return int(count) if count is int or count is float else 0


static func node(talk: Dictionary, id: String) -> Dictionary:
	return (talk.get("nodes", {}) as Dictionary).get(id, {})


static func lines(talk: Dictionary, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in node(talk, id).get("lines", []):
		(
			out
			. append(
				{
					"text": String(line.get("text", "")),
					"speaker": String(line.get("speaker", "")),
					"mood": String(line.get("mood", "")),
				}
			)
		)
	return out


static func choices(talk: Dictionary, id: String, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for choice: Dictionary in node(talk, id).get("choices", []):
		if holds(choice.get("if", {}), flags):
			out.append({"text": String(choice.get("text", "")), "goto": String(choice.get("goto", ""))})
	return out


static func next(talk: Dictionary, id: String) -> String:
	return String(node(talk, id).get("next", ""))


static func sets(talk: Dictionary, id: String) -> Array[String]:
	var out: Array[String] = []
	for flag: Variant in node(talk, id).get("set", []):
		out.append(String(flag))
	return out


## Flags with the node's own set: what the town remembers after reaching it.
static func remember(talk: Dictionary, id: String, flags: Dictionary) -> Dictionary:
	var out := flags.duplicate()
	for flag in sets(talk, id):
		out[flag] = true
	return out


## What is wrong with a talk: a start or a choice that leads nowhere, a node nothing can reach, an empty node.
static func problems(talk: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var nodes: Dictionary = talk.get("nodes", {})
	var reached := {}
	for rule: Dictionary in talk.get("start", []):
		_lead(String(rule.get("goto", "")), nodes, "start", found, reached)
	for id: String in nodes:
		var n: Dictionary = nodes[id]
		if (n.get("lines", []) as Array).is_empty():
			found.append("%s has no lines" % id)
		for choice: Dictionary in n.get("choices", []):
			_lead(String(choice.get("goto", "")), nodes, id, found, reached, true)
		if n.has("next"):
			_lead(String(n.next), nodes, id, found, reached, true)
	for id: String in nodes:
		if not reached.has(id):
			found.append("nothing leads to %s" % id)
	return found


static func _lead(
	target: String, nodes: Dictionary, from: String, found: Array[String], reached: Dictionary, may_end := false
) -> void:
	if target == "" and may_end:
		return
	if not nodes.has(target):
		found.append("%s leads to %s, which is not a node" % [from, target])
		return
	reached[target] = true
