class_name LogDigest
extends RefCounted
## Many bolts, one line. A cast of thirty bolts records thirty entries, which is right for the rules and the stage, but
## read as a log or a story it is a wall of the same sentence. The digest folds the bolt entries of one volley that
## share a kind and a foe into a single entry that says how many and how much, and leaves everything else as it was.
## The fight's log window and the run's story both read the digest, never the raw entries.

## The entries a volley's bolts record, one apiece, and a foe's strikes, one a blow.
const BOLT_KINDS: Array[String] = ["hit", "absorb", "glance", "locked", "wasted", "ward"]
const STRIKE_KIND := "enemy"
const UNKNOWN_FOE := "a foe"


## `entries` with each volley's repeated bolt entries merged. A merged entry keeps the kind (so colours and tallies
## still work) and carries `count`, the sums of `amount`, `overkill` and `blocked`, how many bolts were weak or
## resisted (`weak`, `resist`) and a new `text`. `names` maps a foe's uid to its name for entries that do not carry
## `foe_name`.
static func digest(entries: Array, names := {}) -> Array[Dictionary]:
	names = _learn_names(entries, names)
	var out: Array[Dictionary] = []
	var volley: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if _repeats(entry):
			volley.append(entry)
			continue
		_fold(volley, out, names)
		volley.clear()
		out.append(entry)
	_fold(volley, out, names)
	return out


## Whether an entry is one of a run that folds: a bolt's, or a foe's blow.
static func _repeats(entry: Dictionary) -> bool:
	return (entry.kind in BOLT_KINDS and entry.has("bolt")) or entry.kind == STRIKE_KIND


## The sentences of `entries` joined by `joiner` (a line each by default): what the run's ending and the map's chronicle
## tell.
static func story(entries: Array, names := {}, joiner := "\n") -> String:
	var lines: PackedStringArray = []
	for entry: Dictionary in digest(entries, names):
		if entry.has("text"):
			lines.append(String(entry.text))
	return joiner.join(lines)


## A foe's name by uid, for the foes of a state's fight (empty when it has none).
static func names_of(state: Dictionary) -> Dictionary:
	var names := {}
	for foe: Dictionary in (state.get("battle", {}) as Dictionary).get("foes", []):
		names[foe.uid] = foe.name
	return names


## `names` plus the names the entries themselves give their foes (a foe's own hit or defeat says who it is), for a log
## read with no fight to look the foes up in.
static func _learn_names(entries: Array, names: Dictionary) -> Dictionary:
	var learned := names.duplicate()
	var patterns := {"hit": " takes ", "defeat": " breaks apart", "shield": " raises "}
	for entry: Dictionary in entries:
		var cut: String = patterns.get(entry.kind, "")
		if cut == "" or not entry.has("foe") or learned.has(entry.foe) or entry.has("foe_name"):
			continue
		var text := String(entry.get("text", "")).trim_prefix("Initiative: ")
		if text.contains(cut):
			learned[entry.foe] = text.split(cut)[0]
	return learned


static func _fold(volley: Array[Dictionary], out: Array[Dictionary], names: Dictionary) -> void:
	# Grouped by what happened and to whom, in the order each first happened.
	var groups := {}
	for entry in volley:
		var key := "%s|%s" % [entry.kind, entry.get("foe", "")]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(entry)
	for group: Array in groups.values():
		out.append(group[0] if group.size() == 1 else _merge(group, names))


static func _merge(group: Array, names: Dictionary) -> Dictionary:
	var first: Dictionary = group[0]
	var merged := first.duplicate()
	var sums := {"amount": 0, "overkill": 0, "blocked": 0, "weak": 0, "resist": 0}
	var words := {}
	for entry: Dictionary in group:
		sums.amount += int(entry.get("amount", 0))
		sums.overkill += int(entry.get("overkill", 0))
		sums.blocked += int(entry.get("blocked", 0))
		sums.weak += 1 if entry.get("affinity", "") == "weak" else 0
		sums.resist += 1 if entry.get("affinity", "") == "resist" else 0
		var word := _stem(String(entry.get("word", "")))
		if word != "":
			words[word] = int(words.get(word, 0)) + 1
		if entry.get("element", "none") != first.get("element", "none"):
			merged.element = "none"
	merged.merge(sums, true)
	merged.erase("affinity")
	merged.count = group.size()
	merged.word = ", ".join(PackedStringArray(words.keys()))
	var foe := String(names.get(first.get("foe", ""), first.get("foe_name", UNKNOWN_FOE)))
	merged.text = _sentence(String(first.kind), foe, group.size(), sums, String(merged.word))
	return merged


static func _sentence(kind: String, foe: String, count: int, sums: Dictionary, word: String) -> String:
	match kind:
		"hit":
			var shield := " (%d into its shield)" % sums.blocked if int(sums.blocked) > 0 else ""
			return "%s takes %d from %d bolts%s." % [foe, sums.amount, count, shield]
		"absorb":
			return "%s absorbs %d bolts%s." % [foe, count, " (%s)" % word if word != "" else ""]
		"glance":
			return "%d bolts glance off %s." % [count, foe]
		"locked":
			return "%s holds its lock against %d bolts." % [foe, count]
		"wasted":
			return "%d bolts fly at %s, already down (%d power wasted)." % [count, foe, sums.amount]
		"enemy":
			var blocked := " (%d blocked)" % sums.blocked if int(sums.blocked) > 0 else ""
			return "%s hits you %d times for %d%s." % [foe, count, sums.amount, blocked]
		"ward":
			return "Wards gather %d block from %d bolts." % [sums.amount, count]
	return "%d × %s" % [count, kind]


## A word with its numbers taken off, so "pending +3" and "pending +5" are one word.
static func _stem(word: String) -> String:
	var plain := ""
	for character in word:
		if character.to_lower() != character.to_upper() or character == " " or character == "-":
			plain += character
	return plain.strip_edges()
