class_name StudioHistory
extends RefCounted
## The undo and redo history of one StudioDoc (Concept/v0.3/10, section 9.1). Every change goes through do(), which
## keeps the command as applied with the command that reverses it, so undo and redo are plain applies too.
##
##   var history := StudioHistory.new(doc)
##   history.do({"type": "remove", "sid": 3})   # the StudioCommands.apply result: ok, or an error
##   history.undo()                             # back to the doc before it
##   history.redo()                             # forward again, with the same sids

var doc: StudioDoc

signal transaction_redo_invalidated(transaction_ids: Array[String])
var _undo_stack: Array[Dictionary] = []  # {done, undo, label} entries, oldest first
var _redo_stack: Array[Dictionary] = []


func _init(start: StudioDoc) -> void:
	doc = start


## Applies a command and records it. A refused command changes nothing and is not recorded. A new change clears the
## redo stack.
func do(command: Dictionary) -> Dictionary:
	var label := StudioCommands.describe(doc, command)
	var result := StudioCommands.apply(doc, command)
	if not result["ok"]:
		return result
	doc = result["doc"]
	var invalidated := transaction_ids_for_redo()
	if not invalidated.is_empty():
		transaction_redo_invalidated.emit(invalidated)
	_undo_stack.append({"done": result["done"], "undo": result["undo"], "label": label})
	_redo_stack.clear()
	return result


## Records one side of a coordinated world action. The coordinator applies the same transaction ID to every participant
## history, so an undo request can never reverse just one document.
func do_transaction(command: Dictionary, transaction_id: String, primary := false, transaction_label := "") -> Dictionary:
	var result := do(command)
	if result.ok:
		var entry: Dictionary = _undo_stack.back()
		entry["transaction_id"] = transaction_id
		entry["primary"] = primary
		if transaction_label != "":
			entry["label"] = transaction_label
	return result


## Restores a transaction history row beside a persisted draft after restart; it does not apply the command to the doc.
func restore_transaction_entry(
	command: Dictionary, inverse: Dictionary, label: String, transaction_id: String, primary: bool, applied: bool
) -> void:
	var entry := {
		"done": command.duplicate(true),
		"undo": inverse.duplicate(true),
		"label": label,
		"transaction_id": transaction_id,
		"primary": primary,
	}
	if applied:
		_undo_stack.append(entry)
	else:
		_redo_stack.append(entry)


## Reverses the newest change. False, and nothing changes, when there is none to undo.
func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var entry: Dictionary = _undo_stack.back()
	var result := StudioCommands.apply(doc, entry["undo"])
	if not result["ok"]:
		return false
	doc = result["doc"]
	_undo_stack.pop_back()
	_redo_stack.append(entry)
	return true


## Cancel a provisional gesture without exposing it as a redoable authored edit.
func discard_latest() -> bool:
	if _undo_stack.is_empty() or transaction_id_for_undo() != "":
		return false
	var result := StudioCommands.apply(doc, _undo_stack.back().undo)
	if not result.ok:
		return false
	doc = result.doc
	_undo_stack.pop_back()
	return true


## Applies the newest undone change again, with the sids it had. False, and nothing changes, when there is none.
func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	var entry: Dictionary = _redo_stack.back()
	var result := StudioCommands.apply(doc, entry["done"])
	if not result["ok"]:
		return false
	doc = result["doc"]
	_redo_stack.pop_back()
	var redone := entry.duplicate(true)
	redone["done"] = result["done"]
	redone["undo"] = result["undo"]
	_undo_stack.append(redone)
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


## The command undo() would apply now: the newest change's undo, or {} when there is none. Changes nothing.
func peek_undo() -> Dictionary:
	if _undo_stack.is_empty():
		return {}
	var entry: Dictionary = _undo_stack.back()
	return (entry["undo"] as Dictionary).duplicate(true)


## The command redo() would apply now: the newest undone change's done, or {} when there is none. Changes nothing.
func peek_redo() -> Dictionary:
	if _redo_stack.is_empty():
		return {}
	var entry: Dictionary = _redo_stack.back()
	return (entry["done"] as Dictionary).duplicate(true)


## The coordinated transaction at the top of the undo or redo stack, or "" for an ordinary edit.
func transaction_id_for_undo() -> String:
	return _transaction_id(_undo_stack)


func transaction_id_for_redo() -> String:
	return _transaction_id(_redo_stack)


func transaction_ids_for_redo() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in _redo_stack:
		var transaction_id := String(entry.get("transaction_id", ""))
		if transaction_id != "" and not transaction_id in ids:
			ids.append(transaction_id)
	return ids


func transaction_ids_for_undo() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in _undo_stack:
		var transaction_id := String(entry.get("transaction_id", ""))
		if transaction_id != "" and not transaction_id in ids:
			ids.append(transaction_id)
	return ids


func _transaction_id(stack: Array[Dictionary]) -> String:
	if stack.is_empty():
		return ""
	return String((stack.back() as Dictionary).get("transaction_id", ""))


## A deep copy for rolling back a multi-document commit after an injected or real write failure.
func snapshot_state() -> Dictionary:
	return {"doc": doc, "undo": _undo_stack.duplicate(true), "redo": _redo_stack.duplicate(true)}


func restore_state(snapshot: Dictionary) -> void:
	doc = snapshot["doc"] as StudioDoc
	_undo_stack = snapshot["undo"].duplicate(true)
	_redo_stack = snapshot["redo"].duplicate(true)


## A new edit in any participant invalidates a transaction's redo in every participant.
func drop_transaction_redo(transaction_id: String) -> void:
	for index: int in range(_redo_stack.size() - 1, -1, -1):
		if String(_redo_stack[index].get("transaction_id", "")) == transaction_id:
			_redo_stack.remove_at(index)


func drop_transaction(transaction_id: String) -> void:
	for stack: Array[Dictionary] in [_undo_stack, _redo_stack]:
		for index: int in range(stack.size() - 1, -1, -1):
			if String(stack[index].get("transaction_id", "")) == transaction_id:
				stack.remove_at(index)


## The descriptions of the changes that stand (the ones not undone), oldest first.
func labels() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _undo_stack:
		out.append(String(entry["label"]))
	return out


## Combines the newest `count` adjacent edits into one history row, preserving their exact forward and reverse
## commands. Used when a previewed transition is accepted: its provisional add and destination link are one gesture.
func combine_latest(count: int, label: String) -> bool:
	if count < 2 or _undo_stack.size() < count:
		return false
	var first := _undo_stack.size() - count
	var done_commands: Array[Dictionary] = []
	var undo_commands: Array[Dictionary] = []
	for index: int in range(first, _undo_stack.size()):
		done_commands.append((_undo_stack[index].done as Dictionary).duplicate(true))
	for index: int in range(_undo_stack.size() - 1, first - 1, -1):
		undo_commands.append((_undo_stack[index].undo as Dictionary).duplicate(true))
	_undo_stack.resize(first)
	_undo_stack.append({
		"done": {"type": "batch", "name": label, "commands": done_commands},
		"undo": {"type": "batch", "name": label, "commands": undo_commands},
		"label": label,
	})
	return true
