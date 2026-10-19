class_name StudioWorldTransaction
extends RefCounted
## Coordinates the draft writes and histories for a staged world edit. The in-flight manifest makes interrupted writes
## recoverable; maps, schedules and other future document adapters can participate without changing map command APIs.

## Fault points are disabled in normal use. They let focused transaction tests stop at a specific durability boundary.
static var failure_at := ""

var drafts_dir := StudioFiles.DRAFTS
var recovery: Dictionary = {"ok": true, "recovered": false, "error": ""}
var _plans: Dictionary = {}
var _undone: Dictionary = {}
var _histories_by_plan: Dictionary = {}
var _ledger: Dictionary = {"version": 1, "groups": []}
var _transitioning := false
var _pending_invalidations: Array[String] = []


func _init(drafts_folder := StudioFiles.DRAFTS) -> void:
	drafts_dir = drafts_folder
	recovery = StudioFiles.recover_world_transaction(drafts_dir)
	if bool(recovery.get("ok", false)):
		var ledger_path := StudioFiles.world_groups_path(drafts_dir)
		var saved: Variant = StudioFiles.read_record(ledger_path)
		if not FileAccess.file_exists(ledger_path):
			_ledger = {"version": 1, "groups": []}
		elif (
			saved is Dictionary
			and int((saved as Dictionary).get("version", 0)) == 1
			and (saved as Dictionary).get("groups", []) is Array
		):
			_ledger = saved as Dictionary
		else:
			recovery = {
				"ok": false,
				"recovered": false,
				"error": "The saved world action history cannot be read safely.",
			}


func apply(plan: Dictionary, histories: Dictionary, storage_updates: Array[Dictionary]) -> Dictionary:
	return _run(plan, histories, storage_updates, "forward")


func undo(plan: Dictionary, histories: Dictionary, storage_updates: Array[Dictionary]) -> Dictionary:
	var transaction_id := String(plan.get("id", ""))
	for change: Dictionary in plan.get("changes", []):
		var history: Variant = histories.get(String(change.key))
		if not history is StudioHistory or (history as StudioHistory).transaction_id_for_undo() != transaction_id:
			return {
				"ok": false, "error": "A dependent document changed after this world action; undo its later edit first."
			}
	return _run(plan, histories, storage_updates, "undo")


func redo(plan: Dictionary, histories: Dictionary, storage_updates: Array[Dictionary]) -> Dictionary:
	var transaction_id := String(plan.get("id", ""))
	for change: Dictionary in plan.get("changes", []):
		var history: Variant = histories.get(String(change.key))
		if not history is StudioHistory or (history as StudioHistory).transaction_id_for_redo() != transaction_id:
			return {
				"ok": false,
				"error": "A dependent document changed after this world action; redo is no longer available."
			}
	return _run(plan, histories, storage_updates, "redo")


func plan(transaction_id: String) -> Dictionary:
	return _plans.get(transaction_id, {})


func plan_for_document(document_key: String) -> Dictionary:
	for transaction_id: String in _plans:
		if _undone.has(transaction_id):
			continue
		var candidate: Dictionary = _plans[transaction_id]
		for change: Dictionary in candidate.get("changes", []):
			if String(change.key) == document_key:
				return candidate
	return {}


func groups_for_document(document_key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for group: Variant in _ledger.get("groups", []):
		if not group is Dictionary:
			continue
		for participant: Variant in (group as Dictionary).get("participants", []):
			if participant is Dictionary and String((participant as Dictionary).get("key", "")) == document_key:
				out.append((group as Dictionary).duplicate(true))
				break
	return out


func published(paths: Array[String], histories: Dictionary) -> void:
	var written := {}
	for path: String in paths:
		written[path] = true
	var kept: Array = []
	for value: Variant in _ledger.get("groups", []):
		if not value is Dictionary:
			continue
		var group: Dictionary = value
		var complete := true
		for participant: Variant in group.get("participants", []):
			if not participant is Dictionary or not written.has(String((participant as Dictionary).get("path", ""))):
				complete = false
				break
		if complete:
			var transaction_id := String(group.get("id", ""))
			var participants: Dictionary = _histories_by_plan.get(transaction_id, histories)
			for history: Variant in participants.values():
				if history is StudioHistory:
					(history as StudioHistory).drop_transaction(transaction_id)
			_plans.erase(transaction_id)
			_undone.erase(transaction_id)
			_histories_by_plan.erase(transaction_id)
		else:
			kept.append(group)
	var next := _ledger.duplicate(true)
	next["groups"] = kept
	var path := StudioFiles.world_groups_path(drafts_dir)
	if kept.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	else:
		StudioFiles.write_record(path, next)
	_ledger = next


func restore_group(record: Dictionary, histories: Dictionary) -> Dictionary:
	var transaction_id := String(record.get("id", ""))
	if _plans.has(transaction_id):
		return {"ok": true, "plan": _plans[transaction_id]}
	var restored := StudioWorldPlan.restore(record, histories)
	if not bool(restored.get("ok", false)):
		return restored
	var plan_data: Dictionary = restored
	var applied := String(record.get("state", "")) == "applied"
	for change: Dictionary in plan_data.get("changes", []):
		var history: StudioHistory = histories[String(change.key)] as StudioHistory
		history.restore_transaction_entry(
			change.forward,
			change.inverse,
			String(plan_data.label),
			transaction_id,
			String(change.key) == String(plan_data.primary_key),
			applied
		)
	_register_plan(plan_data, histories, true)
	if not applied:
		_undone[transaction_id] = true
	return {"ok": true, "plan": plan_data}


func forget(transaction_id: String, histories: Dictionary) -> void:
	var participants: Dictionary = _histories_by_plan.get(transaction_id, histories)
	for history: Variant in participants.values():
		if history is StudioHistory:
			(history as StudioHistory).drop_transaction(transaction_id)
	_plans.erase(transaction_id)
	_undone.erase(transaction_id)
	_histories_by_plan.erase(transaction_id)
	_remove_ledger_group(transaction_id)


func invalidate_redo(transaction_id: String, histories: Dictionary) -> void:
	if not _undone.has(transaction_id):
		return
	var participants: Dictionary = _histories_by_plan.get(transaction_id, histories)
	for history: Variant in participants.values():
		if history is StudioHistory:
			(history as StudioHistory).drop_transaction_redo(transaction_id)
	_plans.erase(transaction_id)
	_undone.erase(transaction_id)
	_histories_by_plan.erase(transaction_id)
	_remove_ledger_group(transaction_id)


func _run(
	plan_data: Dictionary, histories: Dictionary, storage_updates: Array[Dictionary], operation: String
) -> Dictionary:
	if not bool(recovery.get("ok", false)):
		return {
			"ok": false,
			"error": String(recovery.get("error", "A previous world transaction needs recovery.")),
			"recovery_required": true
		}
	var transaction_id := String(plan_data.get("id", ""))
	var forward := operation == "forward" or operation == "redo"
	var staged := StudioWorldPlan.stage(plan_data, histories, forward)
	if not bool(staged.get("ok", false)):
		return staged
	if not operation in ["forward", "undo", "redo"]:
		return {"ok": false, "error": "Unknown world transaction operation."}
	var ledger_result := _ledger_after(plan_data, histories, operation)
	if not bool(ledger_result.get("ok", false)):
		return ledger_result
	var updates := storage_updates.duplicate(true)
	var groups: Array = ledger_result.ledger.groups
	(
		updates
		. append(
			{
				"path": StudioFiles.world_groups_path(drafts_dir),
				"exists": not groups.is_empty(),
				"text": JSON.stringify(ledger_result.ledger, "\t", false, true),
			}
		)
	)
	var paths := {}
	var storage: Array[Dictionary] = []
	for update: Dictionary in updates:
		var path := String(update.get("path", ""))
		if not path.begins_with("user://") or paths.has(path):
			return {"ok": false, "error": "A world transaction contains an invalid or repeated draft file."}
		paths[path] = true
		var desired := {"exists": bool(update.get("exists", true)), "text": String(update.get("text", ""))}
		storage.append({"path": path, "before": StudioFiles.storage_snapshot(path), "after": desired})
	if storage.is_empty():
		return {"ok": false, "error": "A world transaction has no durable draft payload."}
	var history_snapshots := {}
	for change: Dictionary in plan_data.get("changes", []):
		var key := String(change.key)
		var history: Variant = histories.get(key)
		if not history is StudioHistory:
			return {"ok": false, "error": "A document in this world transaction is no longer open."}
		history_snapshots[key] = (history as StudioHistory).snapshot_state()
	var manifest_path := StudioFiles.world_transaction_manifest_path(drafts_dir)
	var manifest := {
		"version": 1,
		"id": transaction_id,
		"state": "prepared",
		"operation": operation,
		"documents": _manifest_documents(plan_data),
		"storage": storage,
	}
	if not StudioFiles.write_record(manifest_path, manifest):
		return {"ok": false, "error": "The world transaction recovery record could not be saved."}
	if failure_at == "after_manifest_prepared":
		return _rollback(
			plan_data,
			histories,
			history_snapshots,
			manifest_path,
			manifest,
			"Injected failure after preparing the transaction."
		)
	var written := 0
	for entry: Dictionary in storage:
		if not StudioFiles.restore_storage_snapshot(String(entry.path), entry.after):
			return _rollback(
				plan_data,
				histories,
				history_snapshots,
				manifest_path,
				manifest,
				"A world transaction draft could not be saved."
			)
		written += 1
		if failure_at == "after_first_storage_write" and written == 1:
			return _rollback(
				plan_data,
				histories,
				history_snapshots,
				manifest_path,
				manifest,
				"Injected failure after the first draft write."
			)
	manifest["state"] = "committed"
	if failure_at == "before_commit_manifest" or not StudioFiles.write_record(manifest_path, manifest):
		manifest["state"] = "prepared"
		return _rollback(
			plan_data,
			histories,
			history_snapshots,
			manifest_path,
			manifest,
			"The world transaction could not be committed."
		)
	_transitioning = true
	_pending_invalidations.clear()
	var changed := _change_histories(plan_data, histories, operation)
	if not bool(changed.get("ok", false)) or failure_at == "after_history_commit":
		_transitioning = false
		_pending_invalidations.clear()
		manifest["state"] = "prepared"
		StudioFiles.write_record(manifest_path, manifest)
		return _rollback(
			plan_data,
			histories,
			history_snapshots,
			manifest_path,
			manifest,
			String(changed.get("error", "Injected failure after updating history."))
		)
	_transitioning = false
	_ledger = ledger_result.ledger
	if operation == "forward":
		_register_plan(plan_data, histories, true)
		_undone.erase(transaction_id)
	elif operation == "undo":
		_undone[transaction_id] = true
	elif operation == "redo":
		_undone.erase(transaction_id)
	for invalidated_id: String in _pending_invalidations:
		if invalidated_id != transaction_id:
			_invalidate_group_in_memory(invalidated_id)
	_pending_invalidations.clear()
	if FileAccess.file_exists(manifest_path):
		DirAccess.remove_absolute(manifest_path)
	return {"ok": true, "id": transaction_id, "operation": operation, "documents": _manifest_documents(plan_data)}


func _on_transaction_redo_invalidated(transaction_ids: Array[String]) -> void:
	for transaction_id: String in transaction_ids:
		if not _undone.has(transaction_id):
			continue
		if _transitioning:
			if not transaction_id in _pending_invalidations:
				_pending_invalidations.append(transaction_id)
			continue
		_invalidate_group_in_memory(transaction_id)
		_remove_ledger_group(transaction_id)


func _register_plan(plan_data: Dictionary, histories: Dictionary, connect_histories := false) -> void:
	var transaction_id := String(plan_data.get("id", ""))
	_plans[transaction_id] = plan_data
	_histories_by_plan[transaction_id] = histories.duplicate()
	if not connect_histories:
		return
	for history: Variant in histories.values():
		if (
			history is StudioHistory
			and not (history as StudioHistory).transaction_redo_invalidated.is_connected(
				_on_transaction_redo_invalidated
			)
		):
			(history as StudioHistory).transaction_redo_invalidated.connect(_on_transaction_redo_invalidated)


func _invalidate_group_in_memory(transaction_id: String) -> void:
	var plan_data: Dictionary = _plans.get(transaction_id, {})
	var histories: Dictionary = _histories_by_plan.get(transaction_id, {})
	for change: Dictionary in plan_data.get("changes", []):
		var history: Variant = histories.get(String(change.key))
		if history is StudioHistory:
			(history as StudioHistory).drop_transaction_redo(transaction_id)
	_plans.erase(transaction_id)
	_undone.erase(transaction_id)
	_histories_by_plan.erase(transaction_id)


func _remove_ledger_group(transaction_id: String) -> void:
	var next := _ledger.duplicate(true)
	var kept: Array = []
	for group: Variant in next.get("groups", []):
		if group is Dictionary and String((group as Dictionary).get("id", "")) != transaction_id:
			kept.append(group)
	next["groups"] = kept
	if next == _ledger:
		return
	var path := StudioFiles.world_groups_path(drafts_dir)
	if kept.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	else:
		StudioFiles.write_record(path, next)
	_ledger = next


func _ledger_after(plan_data: Dictionary, histories: Dictionary, operation: String) -> Dictionary:
	var next := _ledger.duplicate(true)
	var groups: Array = next.get("groups", []).duplicate(true)
	var transaction_id := String(plan_data.get("id", ""))
	if operation == "forward":
		var invalidated := {}
		for history: Variant in histories.values():
			if history is StudioHistory:
				for redo_id: String in (history as StudioHistory).transaction_ids_for_redo():
					if _undone.has(redo_id):
						invalidated[redo_id] = true
		var filtered: Array = []
		for group: Variant in groups:
			if group is Dictionary and not invalidated.has(String((group as Dictionary).get("id", ""))):
				filtered.append(group)
		groups = filtered
	var found := false
	for index: int in groups.size():
		var group: Variant = groups[index]
		if not group is Dictionary or String((group as Dictionary).get("id", "")) != transaction_id:
			continue
		found = true
		(group as Dictionary)["state"] = "undone" if operation == "undo" else "applied"
		for participant: Dictionary in (group as Dictionary).get("participants", []):
			for change: Dictionary in plan_data.get("changes", []):
				if String(participant.get("key", "")) == String(change.key):
					participant["before_hash"] = change.before_hash
					participant["after_hash"] = change.after_hash
					break
		break
	if operation == "forward":
		if found:
			return {"ok": false, "error": "A world transaction ID was reused."}
		var participants: Array[Dictionary] = []
		for change: Dictionary in plan_data.get("changes", []):
			(
				participants
				. append(
					{
						"key": String(change.key),
						"path": String(change.path),
						"before_hash": String(change.before_hash),
						"after_hash": String(change.after_hash),
						"forward": change.forward,
						"inverse": change.inverse,
						"summary": String(change.summary),
					}
				)
			)
		(
			groups
			. append(
				{
					"id": transaction_id,
					"label": String(plan_data.get("label", "World action")),
					"primary_key": String(plan_data.get("primary_key", "")),
					"state": "applied",
					"participants": participants,
				}
			)
		)
	elif not found:
		return {"ok": false, "error": "The saved world action record is missing."}
	next["version"] = 1
	next["groups"] = groups
	return {"ok": true, "ledger": next}


func _change_histories(plan_data: Dictionary, histories: Dictionary, operation: String) -> Dictionary:
	var forward := operation == "forward"
	for change: Dictionary in plan_data.get("changes", []):
		var history: StudioHistory = histories[String(change.key)] as StudioHistory
		var changed := false
		match operation:
			"forward":
				var command: Dictionary = change.forward
				changed = bool(
					(
						history
						. do_transaction(
							command,
							String(plan_data.id),
							String(change.key) == String(plan_data.primary_key),
							String(plan_data.get("label", "World action"))
						)
						. get("ok", false)
					)
				)
			"undo":
				changed = history.undo()
			"redo":
				changed = history.redo()
		if not changed:
			return {"ok": false, "error": "A document history refused the coordinated world action."}
	return {"ok": true}


func _rollback(
	plan_data: Dictionary,
	histories: Dictionary,
	snapshots: Dictionary,
	manifest_path: String,
	manifest: Dictionary,
	error: String
) -> Dictionary:
	for key: String in snapshots:
		var history: Variant = histories.get(key)
		if history is StudioHistory:
			(history as StudioHistory).restore_state(snapshots[key])
	var restored := true
	for entry: Dictionary in manifest.get("storage", []):
		if not StudioFiles.restore_storage_snapshot(String(entry.path), entry.before):
			restored = false
	if restored and FileAccess.file_exists(manifest_path):
		DirAccess.remove_absolute(manifest_path)
	return {
		"ok": false,
		"error": error,
		"recovery_required": not restored,
		"transaction_id": String(plan_data.get("id", "")),
	}


func _manifest_documents(plan_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for change: Dictionary in plan_data.get("changes", []):
		(
			out
			. append(
				{
					"key": String(change.key),
					"path": String(change.path),
					"before_hash": String(change.before_hash),
					"after_hash": String(change.after_hash),
					"summary": String(change.summary),
				}
			)
		)
	return out
