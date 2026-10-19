class_name TidyJudges
extends RefCounted
## The judges of the bag's tidy(bag) (task tidy, Concept/v0.4/05, 2.10): the same stacks, in A to Z order by item name.
## Each takes a whole stage's cases and results and gives one verdict per case ({ok, reason, ...details}); TaskJudges.judge
## sends the name here. A case gives its bag as its first argument and no `want`: the bag as it was is the reference, so
## the game can judge a live tidy the same way.


## tidy(bag): the answer must hold each of the bag's stacks once, unchanged, and be in order by item name. Reasons, in the
## order checked: "not-list" (got), "not-stack" (index, got: a thing that is not {item: text, count: whole number}),
## "lost" (name, want, got: a stack of the bag is missing or its count changed; got is 0 when it is missing; the first
## one in the bag's order), "invented" (name, got: a stack the bag did not have), "not-sorted" (index, name: the stack
## that comes before the one before it).
static func tidy_sorted(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		out.append(tidy_one(_bag_of(cases[i]), TaskJudges.value_of(results, i)))
	return out


## One tidy, judged: the bag before it, and the answer (whatever the code gave back).
static func tidy_one(bag: Array, answer: Variant) -> Dictionary:
	if not answer is Array:
		return {"ok": false, "reason": "not-list", "got": answer}
	var stacks: Array = answer
	for index in stacks.size():
		if not _is_stack(stacks[index]):
			return {"ok": false, "reason": "not-stack", "index": index, "got": stacks[index]}
	# Every stack of the bag must be found in the answer, once, with the same count.
	var unmatched: Array = stacks.duplicate()
	for stack: Variant in bag:
		var name := _item_of(stack)
		var want := _count_of(stack)
		var found := _find(unmatched, name)
		if found < 0:
			return {"ok": false, "reason": "lost", "name": name, "want": want, "got": 0}
		var got := _count_of(unmatched[found])
		unmatched.remove_at(found)
		if got != want:
			return {"ok": false, "reason": "lost", "name": name, "want": want, "got": got}
	if not unmatched.is_empty():
		return {"ok": false, "reason": "invented", "name": _item_of(unmatched[0]), "got": _count_of(unmatched[0])}
	for index in range(1, stacks.size()):
		if _item_of(stacks[index - 1]) > _item_of(stacks[index]):
			return {"ok": false, "reason": "not-sorted", "index": index, "name": _item_of(stacks[index])}
	return TaskJudges.right()


# --- helpers -------------------------------------------------------------------------------------------------------


## A case's bag (its first argument), or [] when the case has none.
static func _bag_of(case_data: Variant) -> Array:
	var args: Variant = (case_data as Dictionary).get("args", []) if case_data is Dictionary else []
	if args is Array and not (args as Array).is_empty() and (args as Array)[0] is Array:
		return (args as Array)[0] as Array
	return []


## Whether a value is a stack: a dictionary with a text "item" and a whole "count".
static func _is_stack(stack: Variant) -> bool:
	if not stack is Dictionary:
		return false
	var data: Dictionary = stack
	return data.get("item") is String and Tasks.is_whole(data.get("count"))


static func _item_of(stack: Variant) -> String:
	return String((stack as Dictionary).get("item", "")) if stack is Dictionary else ""


static func _count_of(stack: Variant) -> int:
	return int((stack as Dictionary).get("count", 0)) if stack is Dictionary else 0


## The place of the first stack of `item` in `stacks`, or -1.
static func _find(stacks: Array, item: String) -> int:
	for index in stacks.size():
		if _item_of(stacks[index]) == item:
			return index
	return -1
