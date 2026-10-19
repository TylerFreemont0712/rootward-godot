extends GdUnitTestSuite


func test_add_remove_transaction_can_undo_redo_and_restore_with_monotonic_ids() -> void:
	var doc: StudioDoc = StudioDoc.parse("map.jsonc", "map", '{"id":"room","objects":[]}').doc
	var history := StudioHistory.new(doc)
	var histories := {"map.jsonc": history}
	var actions: Array[Dictionary] = [
		{
			"key": "map.jsonc",
			"path": "map.jsonc",
			"history": history,
			"command": {"type": "add", "object": {"kind": "person", "id": "pell", "at": [2, 3]}},
		}
	]
	var plan := StudioWorldPlan.build("move-person", "Move Pell", actions)
	assert_bool(plan.ok).is_true()
	assert_bool(history.do(plan.changes[0].forward).ok).is_true()
	var staged := StudioWorldPlan.stage(plan, histories, false)
	assert_bool(staged.ok).override_failure_message(str(staged)).is_true()
	if not staged.ok:
		return
	assert_bool(history.undo()).is_true()
	assert_int(history.doc.next_sid).is_greater(doc.next_sid)
	assert_bool(StudioWorldPlan.stage(plan, histories, true).ok).is_true()
	var record := {
		"id": plan.id,
		"label": plan.label,
		"primary_key": plan.primary_key,
		"state": "undone",
		"participants": plan.changes,
	}
	assert_bool(StudioWorldPlan.restore(record, histories).ok).is_true()
	assert_bool(history.redo()).is_true()
	record.state = "applied"
	assert_bool(StudioWorldPlan.restore(record, histories).ok).is_true()
	# Existing object identities must still protect against a stale/replaced session.
	history.doc = history.doc.copy()
	history.doc.sids[0] += 20
	assert_bool(StudioWorldPlan.stage(plan, histories, false).ok).is_false()


func test_legacy_allocator_hashes_restore_without_discarding_existing_draft_groups() -> void:
	var before: StudioDoc = StudioDoc.parse("map.jsonc", "map", '{"id":"room","objects":[]}').doc
	var history := StudioHistory.new(before)
	var applied := history.do({"type": "add", "object": {"kind": "person", "id": "pell", "at": [2, 3]}})
	var after := history.doc
	var record := {
		"id": "legacy",
		"state": "applied",
		"primary_key": "map.jsonc",
		"participants":
		[
			{
				"key": "map.jsonc",
				"path": "map.jsonc",
				"forward": applied.done,
				"inverse": applied.undo,
				"before_hash": StudioWorldPlan._legacy_hash(before, before.next_sid),
				"after_hash": StudioWorldPlan._legacy_hash(after, after.next_sid),
			}
		]
	}
	var restored := StudioWorldPlan.restore(record, {"map.jsonc": history})
	assert_bool(restored.ok).override_failure_message(str(restored)).is_true()
	assert_bool(StudioWorldPlan.stage(restored, {"map.jsonc": history}, false).ok).is_true()
	assert_bool(history.undo()).is_true()
	record.state = "undone"
	restored = StudioWorldPlan.restore(record, {"map.jsonc": history})
	assert_bool(restored.ok).override_failure_message(str(restored)).is_true()
	assert_bool(StudioWorldPlan.stage(restored, {"map.jsonc": history}, true).ok).is_true()
