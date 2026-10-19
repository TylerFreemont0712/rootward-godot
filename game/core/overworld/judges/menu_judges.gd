class_name MenuJudges
extends RefCounted
## The judges of the menu's menu_items(built) (task menu) and the Options page's options() (task options): Concept/v0.4/01
## sections 5.2 and 5.3, and 02 section 5. Each takes a whole stage's cases and results and gives one verdict per case
## ({ok, reason, ...details}); TaskJudges.judge sends the name here.


## menu_items(built): the list the menu shows, each case judged on its own. The reasons, in the order they are checked:
## "not-list" (got), "first" (want: continue; got: the first item, or the empty list), "last" (want: quit; got), "missing"
## (name: the first item of built that is left out), "twice" (name), "unknown" (name: an item that is neither in built
## nor continue or quit).
static func menu_items(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		out.append(menu_one(_built_of(cases[i]), TaskJudges.value_of(results, i)))
	return out


static func menu_one(built: Array, got: Variant) -> Dictionary:
	if not got is Array:
		return {"ok": false, "reason": "not-list", "got": got}
	var items: Array = got
	if items.is_empty() or not Tasks.same(items[0], "continue"):
		return {"ok": false, "reason": "first", "want": "continue", "got": items[0] if not items.is_empty() else items}
	var last: Variant = items[items.size() - 1]
	if not Tasks.same(last, "quit"):
		return {"ok": false, "reason": "last", "want": "quit", "got": last}
	for item: Variant in built:
		if items.count(item) == 0:
			return {"ok": false, "reason": "missing", "name": str(item)}
	for item: Variant in items:
		if items.count(item) > 1:
			return {"ok": false, "reason": "twice", "name": str(item)}
	for item: Variant in items:
		if not (Tasks.same(item, "continue") or Tasks.same(item, "quit") or built.has(item)):
			return {"ok": false, "reason": "unknown", "name": str(item)}
	return TaskJudges.right()


## The built list a case gives (its first argument), or [] when it has none.
static func _built_of(case_data: Variant) -> Array:
	var args: Variant = (case_data as Dictionary).get("args", []) if case_data is Dictionary else []
	if args is Array and not (args as Array).is_empty() and (args as Array)[0] is Array:
		var built: Variant = (args as Array)[0]
		return built as Array
	return []


## options(): the Options page's rows, each case judged on its own. The reasons, in the order they are checked:
## "not-list" (got), "not-row" (index, got: an item that is not a dictionary with a text label and a setting),
## "unknown-setting" (name), "label-empty" (name: the row's setting), "label-long" (name, got: over 24 characters),
## "twice" (name: a setting with two rows), "needs" (name: "music" or "sound", the first one left out).
static func options_rows(cases: Array, results: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in cases.size():
		out.append(rows_one(TaskJudges.value_of(results, i)))
	return out


static func rows_one(got: Variant) -> Dictionary:
	if not got is Array:
		return {"ok": false, "reason": "not-list", "got": got}
	var rows: Array = got
	var seen: Array[String] = []
	for index in rows.size():
		var row: Variant = rows[index]
		if not row is Dictionary or not (row as Dictionary).has("setting") or not (row as Dictionary).has("label"):
			return {"ok": false, "reason": "not-row", "index": index, "got": row}
		var fields: Dictionary = row
		var label: Variant = fields["label"]
		if not label is String:
			return {"ok": false, "reason": "not-row", "index": index, "got": row}
		var name := str(fields["setting"])
		if not name in Parts.SETTINGS:
			return {"ok": false, "reason": "unknown-setting", "name": name}
		var words := String(label).strip_edges()
		if words == "":
			return {"ok": false, "reason": "label-empty", "name": name}
		if words.length() > 24:
			return {"ok": false, "reason": "label-long", "name": name, "got": label}
		if name in seen:
			return {"ok": false, "reason": "twice", "name": name}
		seen.append(name)
	for needed: String in ["music", "sound"]:
		if not needed in seen:
			return {"ok": false, "reason": "needs", "name": needed}
	return TaskJudges.right()
