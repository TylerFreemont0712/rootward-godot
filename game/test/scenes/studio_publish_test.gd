extends GdUnitTestSuite
## S2's acceptance checks publish only into complete temporary content copies. Real content is read, never written.

const TEST_HOME := "user://studio_test"
const FIRST := "publish-a"
const SECOND := "publish-b"

var _root := ""
var _content := ""
var _drafts := ""
var _backups := ""
var _publisher: StudioPublish


func before_test() -> void:
	_root = TEST_HOME.path_join("publish-%d" % Time.get_ticks_usec())
	_content = _root.path_join("content")
	_drafts = _root.path_join("drafts")
	_backups = _root.path_join("backups")
	_copy_tree(ContentLoader.ROOT, _content)
	_publisher = StudioPublish.new()
	_publisher.content_root = _content
	_publisher.drafts_dir = _drafts
	_publisher.backups_dir = _backups
	_fixture(FIRST)
	_fixture(SECOND)


func after_test() -> void:
	_remove_tree(_root)
	_publisher = null


func test_moving_a_barrel_publishes_exactly_one_object_line_with_backup_and_no_draft() -> void:
	var session := _session()
	var original := session.base_text
	_move(session)
	assert_bool(session.save()).is_true()
	var reviewed := _publisher.review({FIRST: session})
	assert_int(int(reviewed.error_count)).is_equal(0)
	assert_array(reviewed.changes).has_size(1)
	assert_array(reviewed.changes[0].lines).is_equal(["Moved barrel from 1, 1 to 2, 1"])
	var result := _publisher.publish({FIRST: session}, true)
	assert_bool(result.ok).is_true()
	assert_array(result.files).is_equal([session.path])
	var published := StudioFiles.read_text(session.path)
	var before := original.split("\n")
	var after := published.split("\n")
	assert_int(after.size()).is_equal(before.size())
	var changed := 0
	for index: int in before.size():
		if before[index] != after[index]:
			changed += 1
			assert_bool(String(before[index]).contains('"art": "barrel"')).is_true()
	assert_int(changed).is_equal(1)
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(session.path, result.backup_stamp, _backups))).is_equal(original)
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(session.path, _drafts))).is_false()
	assert_int(session.changes()).is_equal(0)
	assert_bool(session.unsaved).is_false()
	assert_bool(session.history.can_undo()).is_false()


func test_missing_warp_target_stops_publish_and_preserves_the_draft() -> void:
	var session := _session()
	var original := session.base_text
	assert_bool(session.do({"type": "add", "object": {
		"kind": "warp", "at": [3, 3], "to": {"map": "not-a-map", "at": [0, 0]},
	}}).ok).is_true()
	assert_bool(session.save()).is_true()
	var reviewed := _publisher.review({FIRST: session})
	assert_bool(reviewed.ok).is_false()
	assert_int(int(reviewed.error_count)).is_greater(0)
	var result := _publisher.publish({FIRST: session}, true)
	assert_bool(result.ok).is_false()
	assert_array(result.files).is_empty()
	assert_str(StudioFiles.read_text(session.path)).is_equal(original)
	assert_bool(StudioFiles.load_draft(session.path, _drafts).ok).is_true()


func test_disk_change_after_review_is_detected_again_at_publish() -> void:
	var session := _session()
	_move(session)
	assert_bool(session.save()).is_true()
	assert_array(_publisher.review({FIRST: session}).conflicts).is_empty()
	var external := _disk_change(session.path, "name", "External name")
	var result := _publisher.publish({FIRST: session}, true)
	assert_bool(result.ok).is_false()
	assert_array(result.conflicts).has_size(1)
	assert_str(result.conflicts[0].file).is_equal(session.path)
	assert_str(StudioFiles.read_text(session.path)).is_equal(external)
	assert_bool(StudioFiles.load_draft(session.path, _drafts).ok).is_true()


func test_keep_requires_the_exact_conflicting_file_and_backs_up_the_disk_version() -> void:
	var session := _session()
	_move(session)
	var external := _disk_change(session.path, "name", "External name")
	assert_array(_publisher.review({FIRST: session}).conflicts).has_size(1)
	assert_bool(_publisher.publish({FIRST: session}, true, [_path(SECOND)]).ok).is_false()
	var result := _publisher.publish({FIRST: session}, true, [session.path])
	assert_bool(result.ok).is_true()
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(session.path, result.backup_stamp, _backups))).is_equal(external)
	assert_str(_doc(session.path).data.name).is_equal("Publish test")
	assert_array(_doc(session.path).data.objects[0].at).is_equal([2, 1])


func test_keep_is_blocked_if_disk_changes_again_after_the_conflict_was_reviewed() -> void:
	var session := _session()
	_move(session)
	_disk_change(session.path, "name", "External first")
	_publisher.review({FIRST: session})
	var second_change := _disk_change(session.path, "name", "External second")
	var result := _publisher.publish({FIRST: session}, true, [session.path])
	assert_bool(result.ok).is_false()
	assert_array(result.conflicts).has_size(1)
	assert_str(StudioFiles.read_text(session.path)).is_equal(second_change)


func test_keep_without_a_conflict_review_does_not_authorize_overwriting() -> void:
	var session := _session()
	_move(session)
	_disk_change(session.path, "name", "External")
	assert_bool(_publisher.publish({FIRST: session}, true, [session.path]).ok).is_false()


func test_rebase_preserves_non_overlapping_external_and_draft_edits() -> void:
	var session := _session()
	_move(session)
	var current := _disk_change(session.path, "name", "External name")
	var result := _publisher.rebase(session)
	assert_bool(result.ok).is_true()
	assert_str(session.base_text).is_equal(current)
	assert_str(session.doc().base_hash).is_equal(current.sha256_text())
	assert_str(session.doc().data.name).is_equal("External name")
	assert_array(session.doc().data.objects[0].at).is_equal([2, 1])
	assert_bool(session.history.can_undo()).is_false()
	assert_bool(StudioFiles.load_draft(session.path, _drafts).ok).is_true()
	assert_array(_publisher.review({FIRST: session}).conflicts).is_empty()
	assert_bool(_publisher.publish({FIRST: session}, true).ok).is_true()
	assert_str(_doc(session.path).data.name).is_equal("External name")
	assert_array(_doc(session.path).data.objects[0].at).is_equal([2, 1])


func test_a_rebase_conflict_preserves_session_history_and_saved_draft() -> void:
	var session := _session()
	_move(session)
	assert_bool(session.save()).is_true()
	var draft_text := StudioFiles.read_text(StudioFiles.draft_path(session.path, _drafts))
	var before_doc := session.doc()
	var before_history := session.history
	var external := _doc(session.path)
	external.data.objects[0].at = [3, 1]
	assert_bool(StudioFiles.write_content(session.path, external.to_text())).is_true()
	var result := _publisher.rebase(session)
	assert_bool(result.ok).is_false()
	assert_array(result.conflicts).is_not_empty()
	assert_bool(session.doc() == before_doc).is_true()
	assert_bool(session.history == before_history).is_true()
	assert_str(StudioFiles.read_text(StudioFiles.draft_path(session.path, _drafts))).is_equal(draft_text)


func test_rebase_object_identities_survive_a_restart_after_external_insertion() -> void:
	var session := _session()
	_move(session)
	var external := _doc(session.path)
	external.data.objects.insert(0, {"kind": "prop", "art": "crate", "at": [4, 1]})
	assert_bool(StudioFiles.write_content(session.path, external.to_text())).is_true()
	assert_bool(_publisher.rebase(session).ok).is_true()
	var reopened := _session()
	assert_array(reopened.base_doc.sids).is_equal(session.base_doc.sids)
	assert_array(reopened.doc().sids).is_equal(session.doc().sids)
	assert_array(StudioDiff.lines(reopened.base_doc, reopened.doc())).is_equal(["Moved barrel from 1, 1 to 2, 1"])
	var unvisited := _publisher.review({})
	assert_array(unvisited.changes[0].lines).is_equal(["Moved barrel from 1, 1 to 2, 1"])
	assert_bool(_publisher.publish({FIRST: reopened}, true).ok).is_true()
	assert_array(_doc(session.path).data.objects[0].at).is_equal([4, 1])
	assert_array(_doc(session.path).data.objects[1].at).is_equal([2, 1])


func test_unvisited_persisted_drafts_are_reviewed_and_published() -> void:
	var session := _session()
	_move(session)
	assert_bool(session.save()).is_true()
	var reviewed := _publisher.review({})
	assert_array(reviewed.changes).has_size(1)
	assert_str(reviewed.changes[0].file).is_equal(session.path)
	var result := _publisher.publish({}, true)
	assert_bool(result.ok).is_true()
	assert_array(result.files).is_equal([session.path])
	assert_array(_doc(session.path).data.objects[0].at).is_equal([2, 1])
	assert_array(StudioFiles.list_drafts(_drafts)).is_empty()


func test_memory_changes_take_priority_over_an_older_saved_draft() -> void:
	var session := _session()
	_move(session)
	assert_bool(session.save()).is_true()
	_move(session)
	assert_bool(session.unsaved).is_true()
	assert_bool(_publisher.publish({FIRST: session}, true).ok).is_true()
	assert_array(_doc(session.path).data.objects[0].at).is_equal([3, 1])


func test_unchanged_sessions_and_unchanged_persisted_drafts_do_not_count() -> void:
	var session := _session()
	assert_bool(session.save()).is_true()
	_disk_change(session.path, "name", "External")
	var reviewed := _publisher.review({FIRST: session})
	assert_array(reviewed.changes).is_empty()
	assert_array(reviewed.conflicts).is_empty()
	assert_bool(_publisher.publish({FIRST: session}, true).ok).is_false()


func test_warnings_require_explicit_acceptance() -> void:
	var session := _session()
	assert_bool(session.do({"type": "set", "sid": session.doc().sids[0], "key": "size", "value": [2, 1]}).ok).is_true()
	var reviewed := _publisher.review({FIRST: session})
	assert_int(int(reviewed.error_count)).is_equal(0)
	assert_int(int(reviewed.warning_count)).is_greater(0)
	assert_bool(_publisher.publish({FIRST: session}).ok).is_false()
	assert_bool(_publisher.publish({FIRST: session}, true).ok).is_true()


func test_an_invalid_unchanged_map_elsewhere_stops_the_whole_world_publish() -> void:
	var session := _session()
	_move(session)
	var untouched := _doc(_path(SECOND))
	untouched.data.objects.append({"kind": "warp", "at": [3, 3], "to": {"map": "missing-map", "at": [0, 0]}})
	assert_bool(StudioFiles.write_content(untouched.path, untouched.to_text())).is_true()
	var reviewed := _publisher.review({FIRST: session})
	assert_int(int(reviewed.error_count)).is_greater(0)
	assert_bool(_publisher.publish({FIRST: session}, true).ok).is_false()
	assert_str(StudioFiles.read_text(session.path)).is_equal(session.base_text)


func test_backup_failure_preserves_content_and_saved_drafts() -> void:
	var session := _session()
	_move(session)
	assert_bool(session.save()).is_true()
	var blocked := _root.path_join("backups-blocked")
	assert_bool(StudioFiles.write_content(blocked, "not a folder")).is_true()
	_publisher.backups_dir = blocked.path_join("nested")
	var result := _publisher.publish({FIRST: session}, true)
	assert_bool(result.ok).is_false()
	assert_array(result.files).is_empty()
	assert_str(StudioFiles.read_text(session.path)).is_equal(session.base_text)
	assert_bool(StudioFiles.load_draft(session.path, _drafts).ok).is_true()
	assert_bool(session.history.can_undo()).is_true()


func test_a_second_write_failure_rolls_back_the_first_and_keeps_both_drafts_and_backups() -> void:
	var first := _session(FIRST)
	var second := _session(SECOND)
	_move(first)
	_move(second)
	assert_bool(first.save()).is_true()
	assert_bool(second.save()).is_true()
	assert_int(DirAccess.make_dir_recursive_absolute(second.path + ".tmp")).is_equal(OK)
	var result := _publisher.publish({FIRST: first, SECOND: second}, true)
	assert_bool(result.ok).is_false()
	assert_array(result.rollback_errors).is_empty()
	assert_str(StudioFiles.read_text(first.path)).is_equal(first.base_text)
	assert_str(StudioFiles.read_text(second.path)).is_equal(second.base_text)
	assert_bool(StudioFiles.load_draft(first.path, _drafts).ok).is_true()
	assert_bool(StudioFiles.load_draft(second.path, _drafts).ok).is_true()
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(first.path, result.backup_stamp, _backups))).is_equal(first.base_text)
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(second.path, result.backup_stamp, _backups))).is_equal(second.base_text)


func test_revert_discards_the_draft_and_adopts_current_disk_content() -> void:
	var session := _session()
	_move(session)
	assert_bool(session.save()).is_true()
	var external := _disk_change(session.path, "name", "External")
	assert_bool(_publisher.revert(session).ok).is_true()
	assert_str(session.base_text).is_equal(external)
	assert_str(session.doc().data.name).is_equal("External")
	assert_array(session.doc().data.objects[0].at).is_equal([1, 1])
	assert_int(session.changes()).is_equal(0)
	assert_bool(session.history.can_undo()).is_false()
	assert_array(StudioFiles.list_drafts(_drafts)).is_empty()


func test_the_review_dialog_requires_warning_acceptance_and_lists_the_problems() -> void:
	var session := _session()
	assert_bool(session.do({"type": "set", "sid": session.doc().sids[0], "key": "size", "value": [2, 1]}).ok).is_true()
	var dialog := auto_free(StudioPublishDialog.new()) as StudioPublishDialog
	add_child(dialog)
	dialog.render_review(_publisher.review({FIRST: session}))
	assert_bool(dialog.publish_button.disabled).is_true()
	assert_int(dialog.problems_panel.warning_count).is_greater(0)
	dialog.warnings_checkbox.button_pressed = true
	assert_bool(dialog.publish_button.disabled).is_false()


func _session(id := FIRST) -> StudioSession:
	var session := StudioSession.open(id, _drafts, _content)
	assert_object(session).is_not_null()
	return session


func _move(session: StudioSession) -> void:
	assert_bool(session.do({"type": "move", "sids": [session.doc().sids[0]], "by": [1, 0]}).ok).is_true()


func _path(id: String) -> String:
	return StudioSession.path_of(id, _content)


func _doc(path: String) -> StudioDoc:
	var parsed := StudioDoc.parse(path, "map", StudioFiles.read_text(path))
	assert_bool(parsed.ok).is_true()
	return parsed.doc as StudioDoc


func _disk_change(path: String, key: String, value: Variant) -> String:
	var doc := _doc(path)
	doc.data[key] = value
	var text := doc.to_text()
	assert_bool(StudioFiles.write_content(path, text)).is_true()
	return text


func _fixture(id: String) -> void:
	var data := {
		"id": id, "name": "Publish test", "legend": {".": "grass"},
		"ground": [".....", ".....", ".....", ".....", "....."], "start": [0, 0],
		"objects": [{"kind": "prop", "art": "barrel", "at": [1, 1]}],
	}
	assert_bool(StudioFiles.write_content(_path(id), JsoncWriter.map_text("// Publish fixture\n", data))).is_true()


func _copy_tree(source: String, target: String) -> void:
	assert_int(DirAccess.make_dir_recursive_absolute(target)).is_equal(OK)
	for folder: String in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(folder), target.path_join(folder))
	for file_name: String in DirAccess.get_files_at(source):
		assert_int(DirAccess.copy_absolute(source.path_join(file_name), target.path_join(file_name))).is_equal(OK)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for folder: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(folder))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
