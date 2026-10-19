class_name Quests
extends RefCounted
## Lanternroot's quests (ADR-0061): what to do next, read from what the town remembers (the state's flags). A quest has
## steps; a step is done when its condition holds; a quest opens when the quests it comes `after` are done. Pure: the
## tracker and the log ask, the flags answer.
##
##   Quests.current(quests, flags)        # {id, title, step, text, done, total} of the first open quest, or {}
##   Quests.entries(quests, flags)        # the log: every quest in order with its status and steps
##   Quests.finished(quests, before, after)  # quests a change of flags completed, for a "quest done" moment
##
## A condition is Talk's ({flag}, {not}, {all}) plus {"count": "met-", "at_least": 7}: how many flags start with a
## prefix. Quests come from content (`overworld/quests.jsonc`), ordered by their `order`.

const LOCKED := "locked"
const OPEN := "open"
const DONE := "done"


static func holds(condition: Dictionary, flags: Dictionary) -> bool:
	if condition.has("count"):
		if counted(String(condition.count), flags) < int(condition.get("at_least", 1)):
			return false
	return Talk.holds(condition, flags)


## How many flags that are set start with `prefix`.
static func counted(prefix: String, flags: Dictionary) -> int:
	var n := 0
	for flag: String in flags:
		if flag.begins_with(prefix) and bool(flags[flag]):
			n += 1
	return n


static func ordered(quests: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(quests.keys())
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			var order_a := int((quests[a] as Dictionary).get("order", 0))
			var order_b := int((quests[b] as Dictionary).get("order", 0))
			return order_a < order_b if order_a != order_b else a < b
	)
	return ids


static func steps_done(quest: Dictionary, flags: Dictionary) -> int:
	var n := 0
	for step: Dictionary in quest.get("steps", []):
		if holds(step.get("done", {}), flags):
			n += 1
	return n


## The first unfinished step and its instructions. Completed evidence counts wherever it appears in the quest;
## `step` remains the actual content index, so a later completed step cannot make the tracker skip an earlier one.
static func next_step(quest: Dictionary, flags: Dictionary) -> Dictionary:
	var steps: Array = quest.get("steps", [])
	for i in steps.size():
		var step: Dictionary = steps[i]
		if holds(step.get("done", {}), flags):
			continue
		return {
			"step": i,
			"text": String(step.get("text", "")),
			"hint": String(step.get("hint", "")),
			"progress": _progress(step.get("done", {}), flags),
			"done": steps_done(quest, flags),
			"total": steps.size(),
			"at": (step.get("at", {}) as Dictionary).duplicate() if step.get("at") is Dictionary else {},
		}
	return {}


static func status(quests: Dictionary, id: String, flags: Dictionary, depth := 0) -> String:
	var quest: Dictionary = quests.get(id, {})
	for before: Variant in quest.get("after", []):
		# A loop of quests each waiting for the other never opens, rather than recursing forever.
		if depth > quests.size() or not quests.has(String(before)):
			return LOCKED
		if status(quests, String(before), flags, depth + 1) != DONE:
			return LOCKED
	return DONE if steps_done(quest, flags) >= (quest.get("steps", []) as Array).size() else OPEN


## The step to do now: the first unfinished step of the tracked quest while it is open (v0.4: the log's Track), else
## of the first open quest; {} when every open quest is done. The step's pin (`at`, Studio S9) and the quest's giver
## come with it, for the tracker to point and to show a face.
static func current(quests: Dictionary, flags: Dictionary, tracked := "") -> Dictionary:
	var order := ordered(quests)
	if tracked != "" and order.has(tracked):
		order.erase(tracked)
		order.push_front(tracked)
	for id in order:
		if status(quests, id, flags) != OPEN:
			continue
		var quest: Dictionary = quests[id]
		return next_step(quest, flags).merged({
			"id": id, "title": String(quest.get("title", "")), "giver": String(quest.get("giver", "")),
		})
	return {}


## "3 / 7" for a counting step (a count of flags, or of an item in the bag), "" otherwise.
static func _progress(condition: Dictionary, flags: Dictionary) -> String:
	var target := int(condition.get("at_least", 1))
	if condition.has("has"):
		return "%d / %d" % [mini(Talk.has_count(String(condition.has), flags), target), target]
	if not condition.has("count"):
		return ""
	return "%d / %d" % [mini(counted(String(condition.count), flags), target), target]


## Every quest for the log, in order. Each step has its own evidence, hint and count; `next_step` supplies the
## instructions to show when its quest is selected, independently of the quest the tracker currently follows.
static func entries(quests: Dictionary, flags: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ordered(quests):
		var quest: Dictionary = quests[id]
		var done := steps_done(quest, flags)
		var steps: Array[Dictionary] = []
		var steps_in: Array = quest.get("steps", [])
		for i in steps_in.size():
			var step: Dictionary = steps_in[i]
			steps.append({
				"step": i,
				"text": String(step.get("text", "")),
				"hint": String(step.get("hint", "")),
				"done": holds(step.get("done", {}), flags),
				"progress": _progress(step.get("done", {}), flags),
			})
		(
			out
			. append(
				{
					"id": id,
					"title": String(quest.get("title", "")),
					"summary": String(quest.get("summary", "")),
					"giver": String(quest.get("giver", "")),
					"status": status(quests, id, flags),
					"steps": steps,
					"done": done,
					"total": steps_in.size(),
					"next_step": next_step(quest, flags),
				}
			)
		)
	return out


## The quests a change of flags completed (done after, not done before).
static func finished(quests: Dictionary, before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in ordered(quests):
		if status(quests, id, before) != DONE and status(quests, id, after) == DONE:
			out.append(id)
	return out


## What is wrong with the quests: an `after` that is no quest, a quest without steps.
static func problems(quests: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for id: String in quests:
		var quest: Dictionary = quests[id]
		if (quest.get("steps", []) as Array).is_empty():
			found.append("%s has no steps" % id)
		for before: Variant in quest.get("after", []):
			if not quests.has(String(before)):
				found.append("%s comes after %s, which is no quest" % [id, before])
	return found
