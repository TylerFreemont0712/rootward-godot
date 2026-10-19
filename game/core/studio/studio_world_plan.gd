class_name StudioWorldPlan
extends RefCounted
## A pure, staged edit to more than one Studio document. Keys and paths are stable content paths; each history and
## command belongs only to its own document. SIDs never identify a participant in another document.


## Builds every candidate document before anything is changed. An action is {key, path, history, command}.
static func build(transaction_id: String, label: String, actions: Array[Dictionary]) -> Dictionary:
	if transaction_id.is_empty() or actions.is_empty():
		return {"ok": false, "error": "A world transaction needs an ID and at least one document."}
	var changes: Array[Dictionary] = []
	var seen := {}
	for action: Dictionary in actions:
		var key := String(action.get("key", ""))
		var path := String(action.get("path", ""))
		var history: Variant = action.get("history")
		var command: Variant = action.get("command")
		if (
			key.is_empty()
			or path.is_empty()
			or seen.has(key)
			or not history is StudioHistory
			or not command is Dictionary
		):
			return {"ok": false, "error": "A world transaction contains an invalid or repeated document."}
		seen[key] = true
		var before: StudioDoc = (history as StudioHistory).doc
		var applied := StudioCommands.apply(before, command)
		if not bool(applied.get("ok", false)):
			return {"ok": false, "error": String(applied.get("error", "The change could not be staged."))}
		var after: StudioDoc = applied.doc
		(
			changes
			. append(
				{
					"key": key,
					"path": path,
					"before_hash": hash_doc(before),
					"after_hash": hash_doc(after),
					"before_doc": before,
					"after_doc": after,
					"forward": applied.done,
					"inverse": applied.undo,
					"summary": StudioCommands.describe(before, command),
				}
			)
		)
	changes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.key) < String(b.key))
	return {
		"ok": true,
		"id": transaction_id,
		"label": label,
		"primary_key": String(actions[0].get("key", "")),
		"changes": changes,
		"summaries": _summaries(changes, label),
	}


static func hash_doc(doc: StudioDoc) -> String:
	# LEARN: undo restores identities, but the allocator stays monotonic so a discarded SID is never reused.
	# Hashing that high-water mark would reject every undo of an add, despite restoring the exact same objects.
	return (doc.to_text() + "\n--session-sids--\n" + JSON.stringify(doc.sids)).sha256_text()


## Reconstructs one saved group around freshly opened draft docs. The commands remain local to each stable document key;
## the SIDs in a map command are checked against that map's own persisted draft identities.
static func restore(record: Dictionary, histories: Dictionary) -> Dictionary:
	var transaction_id := String(record.get("id", ""))
	var state := String(record.get("state", ""))
	if transaction_id.is_empty() or not state in ["applied", "undone"]:
		return {"ok": false, "error": "The saved world action has an invalid state."}
	var changes: Array[Dictionary] = []
	for participant: Variant in record.get("participants", []):
		if not participant is Dictionary:
			return {"ok": false, "error": "The saved world action has an invalid document."}
		var value: Dictionary = participant
		var key := String(value.get("key", ""))
		var history: Variant = histories.get(key)
		if key.is_empty() or not history is StudioHistory:
			return {"ok": false, "error": "A document in the saved world action cannot be opened."}
		var current: StudioDoc = (history as StudioHistory).doc
		var current_hash := String(value.get("after_hash" if state == "applied" else "before_hash", ""))
		var forward: Dictionary = value.get("forward", {})
		if not _matches_saved_hash(current, current_hash, forward):
			return {"ok": false, "error": "A document changed after the saved world action."}
		var inverse: Dictionary = value.get("inverse", {})
		var before: StudioDoc
		var after: StudioDoc
		if state == "applied":
			var before_result := StudioCommands.apply(current, inverse)
			if not bool(before_result.get("ok", false)):
				return {"ok": false, "error": "The saved world action can no longer be reversed."}
			before = before_result.doc
			after = current
		else:
			var after_result := StudioCommands.apply(current, forward)
			if not bool(after_result.get("ok", false)):
				return {"ok": false, "error": "The saved world action can no longer be replayed."}
			before = current
			after = after_result.doc
		if (
			not _matches_saved_hash(before, String(value.get("before_hash", "")), forward)
			or not _matches_saved_hash(after, String(value.get("after_hash", "")), forward)
		):
			return {"ok": false, "error": "The saved world action no longer matches its document versions."}
		var round_trip := StudioCommands.apply(before, forward)
		if not bool(round_trip.get("ok", false)) or hash_doc(round_trip.doc as StudioDoc) != hash_doc(after):
			return {"ok": false, "error": "The saved world action does not reproduce its recorded document."}
		(
			changes
			. append(
				{
					"key": key,
					"path": String(value.get("path", key)),
					"before_hash": hash_doc(before),
					"after_hash": hash_doc(after),
					"before_doc": before,
					"after_doc": after,
					"forward": forward,
					"inverse": inverse,
					"summary": String(value.get("summary", record.get("label", "World action"))),
				}
			)
		)
	return {
		"ok": true,
		"id": transaction_id,
		"label": String(record.get("label", "World action")),
		"primary_key": String(record.get("primary_key", "")),
		"changes": changes,
		"summaries": _summaries(changes, String(record.get("label", "World action"))),
		"state": state,
	}


## Verifies that every current document is the version the plan was built from, then stages the opposite side.
static func stage(plan: Dictionary, histories: Dictionary, forward: bool) -> Dictionary:
	var staged := {}
	for change: Dictionary in plan.get("changes", []):
		var key := String(change.key)
		var history: Variant = histories.get(key)
		if not history is StudioHistory:
			return {"ok": false, "error": "A document in this world transaction is no longer open."}
		var current: StudioDoc = (history as StudioHistory).doc
		var expected := String(change.before_hash if forward else change.after_hash)
		if hash_doc(current) != expected:
			return {"ok": false, "error": "A document in this world transaction changed since it was staged."}
		var command: Dictionary = change.forward if forward else change.inverse
		var result := StudioCommands.apply(current, command)
		if not bool(result.get("ok", false)):
			return {"ok": false, "error": String(result.get("error", "A world transaction could not be staged."))}
		var target: StudioDoc = result.doc
		var target_hash := String(change.after_hash if forward else change.before_hash)
		if hash_doc(target) != target_hash:
			return {"ok": false, "error": "A world transaction no longer produces its recorded document."}
		staged[key] = result
	return {"ok": true, "results": staged}


## Earlier P02 drafts included the allocator in their hashes. Accept only a verified legacy image, then restore
## the plan with semantic hashes; the coordinator rewrites its ledger on the next durable transition.
static func _matches_saved_hash(doc: StudioDoc, expected: String, forward: Dictionary) -> bool:
	if hash_doc(doc) == expected or _legacy_hash(doc, doc.next_sid) == expected:
		return true
	# An add's explicit SID records the allocator just before that add. Undo leaves the allocator above it.
	for allocated: int in _added_sids(forward):
		if not doc.sids.has(allocated) and _legacy_hash(doc, allocated) == expected:
			return true
	return false


static func _legacy_hash(doc: StudioDoc, allocator: int) -> String:
	return (doc.to_text() + "\n--session-sids--\n" + JSON.stringify(doc.sids)
		+ "\n--next-sid--\n" + str(allocator)).sha256_text()


static func _added_sids(command: Dictionary) -> Array[int]:
	var out: Array[int] = []
	if String(command.get("type", "")) == "add":
		out.append(int(command.get("sid", -1)))
	elif String(command.get("type", "")) == "batch":
		for child: Dictionary in command.get("commands", []):
			out.append_array(_added_sids(child))
	return out


static func _summaries(changes: Array[Dictionary], fallback: String) -> Array[String]:
	var out: Array[String] = []
	for change: Dictionary in changes:
		var summary := String(change.get("summary", ""))
		if summary != "":
			out.append(summary)
	if out.is_empty():
		out.append(fallback)
	return out
