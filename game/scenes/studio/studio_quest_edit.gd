class_name StudioQuestEdit
extends RefCounted
## The quest editor's edits as commands (Concept/v0.3/10, S9): what a control wants to change, looked at against the
## doc's data as it is, so the command is one StudioCommands accepts and an edit that changes nothing is no command.
## Pure: data in, a command (or {}) out. The views send what comes out to StudioQuestWork.do.
##
##   StudioQuestEdit.set_value(data, ["hello", "title"], "Hi")         # set_at; null erases a key that is there
##   StudioQuestEdit.add_item(data, ["hello", "steps"], step)          # insert_at, or set_at when the list is not there
##   StudioQuestEdit.move_item(data, ["hello", "steps"], 2, 1)         # one batch: out of 2, into 1
##   StudioQuestEdit.remove_item(["hello", "steps"], 2)


## The value at a path of keys and indexes, or null when anything on the way is missing.
static func at(data: Variant, path: Array) -> Variant:
	var value: Variant = data
	for step: Variant in path:
		if value is Dictionary and typeof(step) == TYPE_STRING and (value as Dictionary).has(step):
			value = (value as Dictionary)[step]
		elif value is Array and typeof(step) == TYPE_INT and int(step) >= 0 and int(step) < (value as Array).size():
			value = (value as Array)[int(step)]
		else:
			return null
	return value


## Whether a path reaches something.
static func has(data: Variant, path: Array) -> bool:
	if path.is_empty():
		return true
	var parent: Variant = at(data, path.slice(0, path.size() - 1))
	var last: Variant = path.back()
	if parent is Dictionary:
		return (parent as Dictionary).has(last)
	if parent is Array and typeof(last) == TYPE_INT:
		return int(last) >= 0 and int(last) < (parent as Array).size()
	return false


## set_at for a value; {} when it would change nothing (the value is already there, or a null has no key to erase).
static func set_value(data: Variant, path: Array, value: Variant) -> Dictionary:
	if value == null:
		if not has(data, path) or at(data, path) == null:
			return {}
	elif has(data, path) and typeof(at(data, path)) == typeof(value) and at(data, path) == value:
		return {}
	return {"type": "set_at", "path": path.duplicate(), "value": value}


## An item into the list at a path (-1: the end); a list that is not there yet is made with the item in it.
static func add_item(data: Variant, list_path: Array, item: Variant, index := -1) -> Dictionary:
	if at(data, list_path) is Array:
		return {"type": "insert_at", "path": list_path.duplicate(), "index": index, "value": item}
	return {"type": "set_at", "path": list_path.duplicate(), "value": [item]}


static func remove_item(list_path: Array, index: int) -> Dictionary:
	return {"type": "remove_at", "path": list_path.duplicate(), "index": index}


## An item moved from one place in a list to another, as one undo step. {} when it does not move.
static func move_item(data: Variant, list_path: Array, from: int, to: int) -> Dictionary:
	var list: Variant = at(data, list_path)
	if not list is Array or from == to or from < 0 or to < 0 or from >= (list as Array).size() or to >= (list as Array).size():
		return {}
	var item: Variant = (list as Array)[from]
	return batch("Move an item", [remove_item(list_path, from), {"type": "insert_at", "path": list_path.duplicate(), "index": to, "value": item}])


## The commands that are not empty, as one undo step (the command itself when there is just one); {} for none.
static func batch(label: String, commands: Array) -> Dictionary:
	var kept: Array = commands.filter(func(command: Variant) -> bool: return command is Dictionary and not (command as Dictionary).is_empty())
	if kept.is_empty():
		return {}
	if kept.size() == 1:
		return kept[0]
	return {"type": "batch", "name": label, "commands": kept}


## The lowest unused id of the form "<base>", "<base>-2", "<base>-3"...
static func fresh_id(base: String, taken: Array) -> String:
	if not base in taken:
		return base
	var n := 2
	while "%s-%d" % [base, n] in taken:
		n += 1
	return "%s-%d" % [base, n]


## Whether text is an id the content takes: lower case letters, digits, hyphens and underscores, starting with a letter.
static func is_id(text: String) -> bool:
	if text == "" or not (text[0] >= "a" and text[0] <= "z"):
		return false
	for character: String in text:
		if not ((character >= "a" and character <= "z") or (character >= "0" and character <= "9") or character == "-" or character == "_"):
			return false
	return true
