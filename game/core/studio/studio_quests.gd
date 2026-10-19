class_name StudioQuests
extends RefCounted
## Lanternroot Studio's flag browser (ADR-0066, phase S9): every flag the town uses, with where it is set (talk nodes,
## things' raises, lessons) and where it is read (quest steps, talk conditions, unlocks). Pure: the Studio shows the
## index and jumps to each entry; nothing here reads a file or a node.
##
##   var index := StudioQuests.flag_index(quests, talk, maps, lesson_flags)  # flag -> {set_by, read_by}
##   StudioQuests.where_text(entry)                  # "talk pip, node hello", "quest hello, step 3", ...
##   StudioQuests.orphans(index)                     # {never_set, never_read}: the flags to look at
##   StudioQuests.condition_text(condition)          # "met-innkeeper", "6 or more of met-…"
##   StudioQuests.flags_read(condition)              # the flags a condition reads; a count reads "met-*"
##
## A count reads its prefix as "met-*": one key of the index that every flag starting with "met-" falls under. A flag
## that is set counts towards the prefixes it starts with, so "met-*" lists who sets met- flags.

const SET_BY := "set_by"
const READ_BY := "read_by"
## A prefix's key ends with this: "met-*" is every flag that starts with "met-".
const PREFIX := "*"
## The kinds of entry: who sets a flag, or where it is read.
const TALK := "talk"
const THING := "thing"
const LESSON := "lesson"
const QUEST := "quest"
const UNLOCK := "unlock"


## A condition in English: "met-innkeeper", "not met-innkeeper", "met-a and not met-b", "all of: a, b, not c", or
## "6 or more of met-…". "" for {} (always) and for anything that is not a condition.
static func condition_text(condition: Variant) -> String:
	if not condition is Dictionary:
		return ""
	var kept := condition as Dictionary
	var pieces: Array[String] = []
	if kept.has("count"):
		var prefix := String(kept.get("count", "")).trim_suffix(PREFIX)
		pieces.append("%d or more of %s…" % [int(kept.get("at_least", 1)), prefix])
	if kept.has("flag"):
		pieces.append(String(kept.get("flag", "")))
	if kept.has("not"):
		pieces.append("not %s" % String(kept.get("not", "")))
	var parts: Array[String] = []
	for part: Variant in _all_of(kept):
		var text := condition_text(part)
		if text != "":
			parts.append(text)
	if not parts.is_empty():
		pieces.append("all of: %s" % ", ".join(parts))
	return " and ".join(pieces)


## The flags a condition reads, in the order it names them, each once. A count reads its prefix as "met-*". Anything
## that is not a condition, and {} (always), read nothing.
static func flags_read(condition: Variant) -> Array[String]:
	var out: Array[String] = []
	_read_into(condition, out)
	return out


## Every flag that is set or read anywhere, keyed by the flag (a count's prefix as "met-*"). Each key holds `set_by` and
## `read_by`, lists of entries in content order:
##   set_by:  {kind: "talk", id, node}, {kind: "thing", id, map}, {kind: "lesson", id}
##   read_by: {kind: "quest", id, step} (step counts from 0), {kind: "talk", id, node, where} (where: "start 0" or
##            "choice 1", counting from 0; node is "" for a start rule), {kind: "unlock", id, map}
## `lesson_flags` is what the lessons set, as {flag, lesson} (they are not in the data).
static func flag_index(
	quests: Dictionary, talk: Dictionary, maps: Dictionary, lesson_flags: Array[Dictionary] = []
) -> Dictionary:
	var index := {}
	# The reads first: a count's prefix is a key by then, so each set can reach the prefixes it counts towards.
	_read_by_quests(quests, index)
	_read_by_talk(talk, index)
	_read_by_unlocks(maps, index)
	_set_by_talk(talk, index)
	_set_by_things(maps, index)
	for lesson: Dictionary in lesson_flags:
		_mark_set(index, String(lesson.get("flag", "")), {"kind": LESSON, "id": String(lesson.get("lesson", ""))})
	return index


## The index's flags in alphabetical order (prefixes such as "met-*" among them).
static func sorted_flags(index: Dictionary) -> Array[String]:
	var out: Array[String] = []
	out.assign(index.keys())
	out.sort()
	return out


## Where an entry is, in a short line: "talk pip, node hello", "talk pip, node hello, choice 1", "thing cabbage-gate
## on lanternroot", "lesson memory", "quest hello, step 3" (counting from 1), "talk innkeeper, start 0", "unlock of
## talking-barrel on lanternroot".
static func where_text(entry: Dictionary) -> String:
	var kind := String(entry.get("kind", ""))
	var id := String(entry.get("id", ""))
	var on_map := String(entry.get("map", ""))
	if kind == TALK:
		var parts: Array[String] = ["talk %s" % id]
		var node := String(entry.get("node", ""))
		if node != "":
			parts.append("node %s" % node)
		var where_at := String(entry.get("where", ""))
		if where_at != "":
			parts.append(where_at)
		return ", ".join(parts)
	if kind == THING:
		return "thing %s on %s" % [id, on_map]
	if kind == LESSON:
		# The game's own code (waking, the boots' first steps, the menu's Save) is listed as the lesson "game".
		return "the game itself" if id == "game" else "lesson %s" % id
	if kind == QUEST:
		return "quest %s, step %d" % [id, int(entry.get("step", 0)) + 1]
	if kind == UNLOCK:
		return "unlock of %s on %s" % [id, on_map]
	return ""


## The flags to look at. `never_set`: read (or a count reads their prefix) and set nowhere, sorted. `never_read`: set and
## read nowhere, sorted. A flag that a count's prefix covers counts as read, and a prefix nothing sets is never set.
static func orphans(index: Dictionary) -> Dictionary:
	var never_set: Array[String] = []
	var never_read: Array[String] = []
	var flags := sorted_flags(index)
	for flag: String in flags:
		var entry: Dictionary = index[flag]
		var set_by: Array = entry[SET_BY]
		var read_by: Array = entry[READ_BY]
		if flag.ends_with(PREFIX):
			if set_by.is_empty():
				never_set.append(flag)
		elif set_by.is_empty() and not read_by.is_empty():
			never_set.append(flag)
		elif not set_by.is_empty() and read_by.is_empty() and not _counted(flag, flags):
			never_read.append(flag)
	return {"never_set": never_set, "never_read": never_read}


## The parts of an `all` (its conditions), or none.
static func _all_of(condition: Dictionary) -> Array:
	var parts: Variant = condition.get("all", [])
	if parts is Array:
		return parts
	return []


static func _read_into(condition: Variant, out: Array[String]) -> void:
	if not condition is Dictionary:
		return
	var kept := condition as Dictionary
	if kept.has("count"):
		_add_once(out, _prefix_key(String(kept.get("count", ""))))
	if kept.has("flag"):
		_add_once(out, String(kept.get("flag", "")))
	if kept.has("not"):
		_add_once(out, String(kept.get("not", "")))
	for part: Variant in _all_of(kept):
		_read_into(part, out)


## The key a count's prefix has in the index: "met-" becomes "met-*", and "met-*" stays as it is.
static func _prefix_key(prefix: String) -> String:
	if prefix == "":
		return ""
	return prefix if prefix.ends_with(PREFIX) else prefix + PREFIX


static func _add_once(out: Array[String], flag: String) -> void:
	if flag != "" and not (flag in out):
		out.append(flag)


## Adds an entry under a flag's `role` (SET_BY or READ_BY), once. The flag is listed even when this is its only entry.
static func _add(index: Dictionary, role: String, flag: String, entry: Dictionary) -> void:
	if flag == "":
		return
	if not index.has(flag):
		index[flag] = {SET_BY: [], READ_BY: []}
	var list: Array = (index[flag] as Dictionary)[role]
	if not (entry in list):
		list.append(entry.duplicate())


## Records a flag as set by an entry: under the flag, and under each prefix a count reads that the flag starts with.
static func _mark_set(index: Dictionary, flag: String, entry: Dictionary) -> void:
	if flag == "":
		return
	_add(index, SET_BY, flag, entry)
	for key: String in index.keys():
		if key.ends_with(PREFIX) and flag.begins_with(key.trim_suffix(PREFIX)):
			_add(index, SET_BY, key, entry)


## The things on a map that run a program and have an id: the objects with a `program` dictionary.
static func _programs(map: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not map is Dictionary:
		return out
	for object: Variant in (map as Dictionary).get("objects", []):
		if not object is Dictionary:
			continue
		var thing := object as Dictionary
		if thing.get("program") is Dictionary and String(thing.get("id", "")) != "":
			out.append(thing)
	return out


## Flags a talk node sets: its `set`.
static func _set_by_talk(talk: Dictionary, index: Dictionary) -> void:
	for talk_id: String in talk:
		var one: Dictionary = talk[talk_id]
		var nodes: Dictionary = one.get("nodes", {})
		for node_id: String in nodes:
			for flag: String in Talk.sets(one, node_id):
				_mark_set(index, flag, {"kind": TALK, "id": talk_id, "node": node_id})


## Flags a thing raises: its program's `raises`, for each thing with a program and an id on a map.
static func _set_by_things(maps: Dictionary, index: Dictionary) -> void:
	for map_id: String in maps:
		for thing: Dictionary in _programs(maps[map_id]):
			for flag: String in TownThings.raises_of(thing):
				_mark_set(index, flag, {"kind": THING, "id": String(thing.get("id", "")), "map": map_id})


## Flags a quest step reads: its `done` condition, by step (counting from 0).
static func _read_by_quests(quests: Dictionary, index: Dictionary) -> void:
	for quest_id: String in quests:
		var quest: Dictionary = quests[quest_id]
		var steps: Array = quest.get("steps", [])
		for i in steps.size():
			var step: Dictionary = steps[i]
			for flag: String in flags_read(step.get("done", {})):
				_add(index, READ_BY, flag, {"kind": QUEST, "id": quest_id, "step": i})


## Flags a talk reads: each start rule's `if` ("start 0" is the first rule) and each choice's `if` ("choice 0" is the
## first choice of its node).
static func _read_by_talk(talk: Dictionary, index: Dictionary) -> void:
	for talk_id: String in talk:
		var one: Dictionary = talk[talk_id]
		var rules: Array = one.get("start", [])
		for i in rules.size():
			var rule: Dictionary = rules[i]
			for flag: String in flags_read(rule.get("if", {})):
				_add(index, READ_BY, flag, {"kind": TALK, "id": talk_id, "node": "", "where": "start %d" % i})
		var nodes: Dictionary = one.get("nodes", {})
		for node_id: String in nodes:
			var choices: Array = (nodes[node_id] as Dictionary).get("choices", [])
			for j in choices.size():
				var choice: Dictionary = choices[j]
				for flag: String in flags_read(choice.get("if", {})):
					var where_at := "choice %d" % j
					_add(index, READ_BY, flag, {"kind": TALK, "id": talk_id, "node": node_id, "where": where_at})


## Flags an unlock reads: a thing's program `unlocked_by` condition.
static func _read_by_unlocks(maps: Dictionary, index: Dictionary) -> void:
	for map_id: String in maps:
		for thing: Dictionary in _programs(maps[map_id]):
			var program: Dictionary = thing.get("program", {})
			for flag: String in flags_read(program.get("unlocked_by", {})):
				_add(index, READ_BY, flag, {"kind": UNLOCK, "id": String(thing.get("id", "")), "map": map_id})


## Whether a prefix in the index (a count reads it) covers the flag.
static func _counted(flag: String, flags: Array[String]) -> bool:
	for key: String in flags:
		if key.ends_with(PREFIX) and flag.begins_with(key.trim_suffix(PREFIX)):
			return true
	return false
