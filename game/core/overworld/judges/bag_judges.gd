class_name BagJudges
extends RefCounted
## The judges of the bag's add(bag, item) (task bag, stage 1) and remove(bag, item) (stage 2): Concept/v0.4/01 section
## 5.6 and 02 section 5. Each takes a whole stage's cases and results and gives one verdict per case ({ok, reason,
## ...details}); TaskJudges.judge sends the name here. The bag is a list of stacks, {item: text, count: whole number}.
## The judges compare the bag's totals per item, and check each stack. Bag.valid_add and Bag.valid_remove judge one live
## call the same way, so a case needs only its arguments ([before, item]) and no `want`.


## add(bag, item): `before` is the case's bag, `after` is the bag the code gave back. Reasons, in the order checked:
## "not-list" (got), "not-stack" (index, got: a stack that is not {item, count}), "bad-count" (name, got: a count
## below 1), "two-stacks" (name: the same item in two stacks), "no-more" (name, want, got: the item's total did not go
## up by exactly one), "changed-other" (name, want, got: another item's total changed, or one went missing).
static func bag_add(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var args := _args_of(cases[i])
		out.append(add_one(_stacks_at(args, 0), _item_at(args, 1), TaskJudges.value_of(results, i)))
	return out


## remove(bag, item). Reasons, in the order checked: "not-list" (got), "not-stack" (index, got), "zero-stack" (name,
## got: a stack left at a count below 1), "invented" (name, want, got: the item was not in the bag, yet now something of
## it is, or another total changed), "no-less" (name, want, got: the item's total did not go down by exactly one),
## "changed-other" (name, want, got: another item's total changed).
static func bag_remove(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		var args := _args_of(cases[i])
		out.append(remove_one(_stacks_at(args, 0), _item_at(args, 1), TaskJudges.value_of(results, i)))
	return out


## One add, judged: the bag before, the item, and the answer (whatever the code gave back).
static func add_one(before: Array, item: String, after: Variant) -> Dictionary:
	if not after is Array:
		return {"ok": false, "reason": "not-list", "got": after}
	var stacks: Array = after
	for index in stacks.size():
		if not _is_stack(stacks[index]):
			return {"ok": false, "reason": "not-stack", "index": index, "got": stacks[index]}
	for stack: Variant in stacks:
		if _count_of(stack) < 1:
			return {"ok": false, "reason": "bad-count", "name": _item_of(stack), "got": _count_of(stack)}
	var held := _stacks_per_item(stacks)
	for name: String in held:
		if int(held[name]) > 1:
			return {"ok": false, "reason": "two-stacks", "name": name}
	var was := _totals(before)
	var now := _totals(stacks)
	var want := int(was.get(item, 0)) + 1
	if int(now.get(item, 0)) != want:
		return {"ok": false, "reason": "no-more", "name": item, "want": want, "got": int(now.get(item, 0))}
	for name: String in _names(was, now):
		if name != item and int(was.get(name, 0)) != int(now.get(name, 0)):
			return {
				"ok": false,
				"reason": "changed-other",
				"name": name,
				"want": int(was.get(name, 0)),
				"got": int(now.get(name, 0)),
			}
	return TaskJudges.right()


## One remove, judged: the bag before, the item, and the answer.
static func remove_one(before: Array, item: String, after: Variant) -> Dictionary:
	if not after is Array:
		return {"ok": false, "reason": "not-list", "got": after}
	var stacks: Array = after
	for index in stacks.size():
		if not _is_stack(stacks[index]):
			return {"ok": false, "reason": "not-stack", "index": index, "got": stacks[index]}
	for stack: Variant in stacks:
		if _count_of(stack) < 1:
			return {"ok": false, "reason": "zero-stack", "name": _item_of(stack), "got": _count_of(stack)}
	var was := _totals(before)
	var now := _totals(stacks)
	var had := int(was.get(item, 0))
	if had == 0:
		# Nothing of the item was there, so nothing at all should change.
		for name: String in _names(was, now):
			if int(was.get(name, 0)) != int(now.get(name, 0)):
				return {
					"ok": false,
					"reason": "invented",
					"name": name,
					"want": int(was.get(name, 0)),
					"got": int(now.get(name, 0)),
				}
		return TaskJudges.right()
	if int(now.get(item, 0)) != had - 1:
		return {"ok": false, "reason": "no-less", "name": item, "want": had - 1, "got": int(now.get(item, 0))}
	for name: String in _names(was, now):
		if name != item and int(was.get(name, 0)) != int(now.get(name, 0)):
			return {
				"ok": false,
				"reason": "changed-other",
				"name": name,
				"want": int(was.get(name, 0)),
				"got": int(now.get(name, 0)),
			}
	return TaskJudges.right()


# --- helpers -------------------------------------------------------------------------------------------------------


## A case's argument list, or [] when the case has none.
static func _args_of(case_data: Variant) -> Array:
	if case_data is Dictionary and (case_data as Dictionary).get("args") is Array:
		return (case_data as Dictionary).get("args") as Array
	return []


static func _stacks_at(args: Array, index: int) -> Array:
	if index < args.size() and args[index] is Array:
		return args[index] as Array
	return []


static func _item_at(args: Array, index: int) -> String:
	return str(args[index]) if index < args.size() else ""


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


## Each item's total over every stack of the bag (every item name, the empty one too).
static func _totals(stacks: Array) -> Dictionary:
	var out := {}
	for stack: Variant in stacks:
		if _is_stack(stack):
			var item := _item_of(stack)
			out[item] = int(out.get(item, 0)) + _count_of(stack)
	return out


## How many stacks each item has.
static func _stacks_per_item(stacks: Array) -> Dictionary:
	var out := {}
	for stack: Variant in stacks:
		var item := _item_of(stack)
		out[item] = int(out.get(item, 0)) + 1
	return out


## Every item name in either bag, the first bag's first, each once.
static func _names(first: Dictionary, second: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for name: Variant in first.keys() + second.keys():
		if not String(name) in out:
			out.append(String(name))
	return out
