extends GdUnitTestSuite
## Lanternroot Studio's file access (ADR-0066): drafts, backups and content writes. Each test works in its own folder
## under user://studio_test/, so nothing under res:// is written. The docs are parsed from the real map files.

const TEST_ROOT := "user://studio_test/"
const HOME := "res://content/packs/core/overworld/maps/home.jsonc"
const TOWN := "res://content/packs/core/overworld/maps/lanternroot.jsonc"

## The folder this test writes into; made in before_test and removed in after_test.
var _root := ""


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(_root)


func after_test() -> void:
	_remove_tree(_root)


func after() -> void:
	_remove_tree(TEST_ROOT)


func test_draft_path_maps_a_content_path_as_specified() -> void:
	assert_str(StudioFiles.draft_path(HOME, "user://d/")).is_equal(
		"user://d/content__packs__core__overworld__maps__home.jsonc.json"
	)
	assert_str(StudioFiles.draft_path(TOWN)).is_equal(
		StudioFiles.DRAFTS + "content__packs__core__overworld__maps__lanternroot.jsonc.json"
	)


func test_save_draft_then_load_draft_gives_back_the_same_doc() -> void:
	var text := StudioFiles.read_text(HOME)
	var doc := _parsed(HOME, text)
	doc.next_sid += 3
	assert_bool(StudioFiles.save_draft(doc, text, _root)).is_true()

	var loaded := StudioFiles.load_draft(HOME, _root)
	assert_bool(loaded["ok"]).is_true()
	assert_str(loaded["base_text"]).is_equal(text)
	assert_str(loaded["saved_at"]).is_not_empty()
	var back: StudioDoc = loaded["doc"]
	assert_str(back.path).is_equal(HOME)
	assert_str(back.kind).is_equal("map")
	assert_str(back.header).is_equal(doc.header)
	assert_bool(back.header.is_empty()).is_false()
	assert_str(back.base_hash).is_equal(doc.base_hash)
	assert_dict(back.data).is_equal(doc.data)
	assert_array(back.sids).is_equal(doc.sids)
	assert_int(back.next_sid).is_equal(doc.next_sid)


func test_load_draft_restores_sids_and_whole_numbers_as_ints() -> void:
	var text := StudioFiles.read_text(HOME)
	StudioFiles.save_draft(_parsed(HOME, text), text, _root)

	var back: StudioDoc = StudioFiles.load_draft(HOME, _root)["doc"]
	for sid: Variant in back.sids:
		assert_int(typeof(sid)).is_equal(TYPE_INT)
	var objects: Array = back.data["objects"]
	var first: Dictionary = objects[0]
	assert_array(first["at"]).is_equal([1, 2])
	for value: Variant in first["at"]:
		assert_int(typeof(value)).is_equal(TYPE_INT)


func test_save_draft_keeps_the_key_order_and_full_float_precision() -> void:
	var text := StudioFiles.read_text(HOME)
	var doc := _parsed(HOME, text)
	doc.data["scale"] = 0.1 + 0.2
	doc.data["half"] = 2.5
	StudioFiles.save_draft(doc, text, _root)

	var back: StudioDoc = StudioFiles.load_draft(HOME, _root)["doc"]
	assert_array(back.data.keys()).is_equal(doc.data.keys())
	assert_float(back.data["scale"]).is_equal(0.1 + 0.2)
	assert_float(back.data["half"]).is_equal(2.5)


func test_save_draft_writes_the_documented_fields() -> void:
	var text := StudioFiles.read_text(HOME)
	StudioFiles.save_draft(_parsed(HOME, text), text, _root)

	var record: Dictionary = JSON.parse_string(StudioFiles.read_text(StudioFiles.draft_path(HOME, _root)))
	assert_array(record.keys()).contains_exactly_in_any_order(
		["file", "kind", "header", "base_hash", "base_text", "data", "sids", "next_sid", "saved_at"]
	)


func test_save_draft_creates_its_folder() -> void:
	var nested := _root.path_join("made/later")
	var text := StudioFiles.read_text(HOME)
	assert_bool(StudioFiles.save_draft(_parsed(HOME, text), text, nested)).is_true()
	assert_bool(FileAccess.file_exists(StudioFiles.draft_path(HOME, nested))).is_true()


func test_load_draft_of_a_missing_draft_is_not_ok() -> void:
	assert_bool(StudioFiles.load_draft(HOME, _root)["ok"]).is_false()


func test_load_draft_of_an_unreadable_draft_is_not_ok() -> void:
	var file := FileAccess.open(StudioFiles.draft_path(HOME, _root), FileAccess.WRITE)
	file.store_string("{ not a draft")
	file.close()
	assert_bool(StudioFiles.load_draft(HOME, _root)["ok"]).is_false()


func test_list_drafts_lists_the_saved_drafts_sorted() -> void:
	_save(TOWN)
	_save(HOME)
	assert_array(StudioFiles.list_drafts(_root)).is_equal([HOME, TOWN])


func test_list_drafts_of_a_folder_without_drafts_is_empty() -> void:
	assert_array(StudioFiles.list_drafts(_root)).is_empty()
	assert_array(StudioFiles.list_drafts(_root.path_join("none"))).is_empty()


func test_discard_draft_removes_only_that_draft() -> void:
	_save(TOWN)
	_save(HOME)
	StudioFiles.discard_draft(HOME, _root)
	assert_array(StudioFiles.list_drafts(_root)).is_equal([TOWN])
	assert_bool(StudioFiles.load_draft(HOME, _root)["ok"]).is_false()
	StudioFiles.discard_draft(HOME, _root)
	assert_array(StudioFiles.list_drafts(_root)).is_equal([TOWN])


func test_backup_copies_a_file_into_the_stamp_folder_keeping_its_folders() -> void:
	var backups := _root.path_join("backups")
	assert_bool(StudioFiles.backup(HOME, "2026-10-13_12-00-00", backups)).is_true()
	var copy := backups.path_join("2026-10-13_12-00-00/content/packs/core/overworld/maps/home.jsonc")
	assert_bool(FileAccess.file_exists(copy)).is_true()
	assert_str(StudioFiles.read_text(copy)).is_equal(FileAccess.get_file_as_string(HOME))


func test_backup_of_a_missing_file_copies_nothing() -> void:
	var backups := _root.path_join("backups")
	assert_bool(StudioFiles.backup("res://content/packs/core/none.jsonc", "stamp", backups)).is_false()
	assert_bool(DirAccess.dir_exists_absolute(backups)).is_false()


func test_write_content_writes_the_text_and_leaves_no_tmp_file() -> void:
	var path := _root.path_join("content/packs/core/overworld/maps/home.jsonc")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var text := '// header\n{\n "id": "home"\n}\n'
	assert_bool(StudioFiles.write_content(path, text)).is_true()
	assert_str(StudioFiles.read_text(path)).is_equal(text)
	assert_bool(FileAccess.file_exists(path + ".tmp")).is_false()


func test_write_content_replaces_an_existing_file() -> void:
	var path := _root.path_join("town.jsonc")
	assert_bool(StudioFiles.write_content(path, "old\n")).is_true()
	assert_bool(StudioFiles.write_content(path, "new\n")).is_true()
	assert_str(StudioFiles.read_text(path)).is_equal("new\n")


func test_write_content_fails_when_its_folder_is_missing() -> void:
	var path := _root.path_join("missing/town.jsonc")
	assert_bool(StudioFiles.write_content(path, "text\n")).is_false()
	assert_bool(FileAccess.file_exists(path)).is_false()


func test_read_text_of_a_missing_file_is_empty() -> void:
	assert_str(StudioFiles.read_text(_root.path_join("none.jsonc"))).is_empty()


func test_can_write_is_true_for_a_user_folder() -> void:
	assert_bool(StudioFiles.can_write(_root)).is_true()
	assert_bool(FileAccess.file_exists(_root.path_join(StudioFiles.PROBE_NAME))).is_false()


func test_can_write_is_false_for_a_folder_that_does_not_exist() -> void:
	assert_bool(StudioFiles.can_write(_root.path_join("missing"))).is_false()


## The doc a map file parses to, for the tests that need one.
func test_user_content_paths_survive_draft_listing_and_backups() -> void:
	var path := _root.path_join("home.jsonc")
	var text := StudioFiles.read_text(HOME)
	StudioFiles.write_content(path, text)
	var folder := _root.path_join("drafts")
	assert_bool(StudioFiles.save_draft(_parsed(path, text), text, folder)).is_true()
	assert_array(StudioFiles.list_drafts(folder)).is_equal([path])
	var backups := _root.path_join("backups")
	assert_bool(StudioFiles.backup(path, "stamp", backups)).is_true()
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(path, "stamp", backups))).is_equal(text)


func test_batch_publish_backs_up_all_files_and_refuses_changed_hashes() -> void:
	var one := _root.path_join("one.jsonc")
	var two := _root.path_join("two.jsonc")
	StudioFiles.write_content(one, "one")
	StudioFiles.write_content(two, "two")
	var entries: Array[Dictionary] = [
		{"path": one, "text": "new one", "expected_hash": "one".sha256_text()},
		{"path": two, "text": "new two", "expected_hash": "stale".sha256_text()},
	]
	var backups := _root.path_join("backups")
	assert_bool(StudioFiles.batch_publish(entries, "stamp", backups).ok).is_false()
	assert_str(StudioFiles.read_text(one)).is_equal("one")
	assert_bool(DirAccess.dir_exists_absolute(backups)).is_false()
	entries[1].expected_hash = "two".sha256_text()
	var result := StudioFiles.batch_publish(entries, "stamp", backups)
	assert_bool(result.ok).is_true()
	assert_array(result.files).is_equal([one, two])
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(one, "stamp", backups))).is_equal("one")
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(two, "stamp", backups))).is_equal("two")
	assert_str(StudioFiles.read_text(two)).is_equal("new two")


func test_batch_publish_rolls_back_prior_writes_when_a_later_write_fails() -> void:
	var one := _root.path_join("one.jsonc")
	var two := _root.path_join("two.jsonc")
	StudioFiles.write_content(one, "one")
	StudioFiles.write_content(two, "two")
	# A directory at the temp-file path makes the second atomic write fail, after its backup succeeds.
	DirAccess.make_dir_recursive_absolute(two + ".tmp")
	var entries: Array[Dictionary] = [
		{"path": one, "text": "new one", "expected_hash": "one".sha256_text()},
		{"path": two, "text": "new two", "expected_hash": "two".sha256_text()},
	]
	var backups := _root.path_join("backups")
	var result := StudioFiles.batch_publish(entries, "stamp", backups)
	assert_bool(result.ok).is_false()
	assert_array(result.rollback_errors).is_empty()
	assert_str(StudioFiles.read_text(one)).is_equal("one")
	assert_str(StudioFiles.read_text(two)).is_equal("two")
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(two, "stamp", backups))).is_equal("two")


func test_batch_publish_makes_a_new_file_with_nothing_to_back_up() -> void:
	var one := _root.path_join("one.jsonc")
	var made := _root.path_join("made.jsonc")
	StudioFiles.write_content(one, "one")
	var entries: Array[Dictionary] = [
		{"path": one, "text": "new one", "expected_hash": "one".sha256_text()},
		{"path": made, "text": "a new map", "expected_hash": "".sha256_text(), "new": true},
	]
	var backups := _root.path_join("backups")
	var result := StudioFiles.batch_publish(entries, "stamp", backups)
	assert_bool(result.ok).override_failure_message(str(result)).is_true()
	assert_array(result.files).is_equal([one, made])
	assert_str(StudioFiles.read_text(made)).is_equal("a new map")
	assert_bool(StudioFiles.exists(StudioFiles.backup_path(made, "stamp", backups))).is_false()
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(one, "stamp", backups))).is_equal("one")


func test_batch_publish_refuses_a_new_file_that_someone_made_meanwhile() -> void:
	var made := _root.path_join("made.jsonc")
	StudioFiles.write_content(made, "somebody's map")
	var entries: Array[Dictionary] = [{"path": made, "text": "a new map", "expected_hash": "".sha256_text(), "new": true}]
	var result := StudioFiles.batch_publish(entries, "stamp", _root.path_join("backups"))
	assert_bool(result.ok).is_false()
	assert_array(result.conflicts).is_equal([made])
	assert_str(StudioFiles.read_text(made)).is_equal("somebody's map")


func test_batch_publish_removes_a_new_file_again_when_a_later_write_fails() -> void:
	var made := _root.path_join("made.jsonc")
	var two := _root.path_join("two.jsonc")
	StudioFiles.write_content(two, "two")
	DirAccess.make_dir_recursive_absolute(two + ".tmp")
	var entries: Array[Dictionary] = [
		{"path": made, "text": "a new map", "expected_hash": "".sha256_text(), "new": true},
		{"path": two, "text": "new two", "expected_hash": "two".sha256_text()},
	]
	var result := StudioFiles.batch_publish(entries, "stamp", _root.path_join("backups"))
	assert_bool(result.ok).is_false()
	assert_array(result.rollback_errors).is_empty()
	assert_bool(StudioFiles.exists(made)).override_failure_message("the new file is taken away again").is_false()
	assert_str(StudioFiles.read_text(two)).is_equal("two")


func test_a_new_maps_session_saves_a_draft_that_opens_as_new() -> void:
	var content := _root.path_join("content")
	DirAccess.make_dir_recursive_absolute(content.path_join("packs/core/overworld/maps"))
	var data := {"id": "room", "name": "Room", "interior": true, "legend": {"f": "floor"}, "ground": ["ff", "ff"], "start": [0, 0], "facing": "up", "objects": []}
	var drafts := _root.path_join("drafts")
	var made := StudioSession.create("room", data, drafts, content)
	assert_object(made).is_not_null()
	assert_bool(made.is_new).is_true()
	assert_int(made.changes()).is_equal(1)
	assert_str(made.status()).contains("1 change")
	assert_bool(made.save()).is_true()
	assert_bool(StudioFiles.exists(made.path)).override_failure_message("a draft only: no content file").is_false()
	var opened := StudioSession.open("room", drafts, content)
	assert_object(opened).is_not_null()
	assert_bool(opened.is_new).is_true()
	assert_str(JSON.stringify(opened.doc().data)).is_equal(JSON.stringify(made.doc().data))
	assert_bool(bool(opened.build({"floor": {"walk": true}}).ok)).is_true()
	# A file of that name already there: no new map over it.
	StudioFiles.write_content(StudioSession.path_of("taken", content), "{}")
	assert_object(StudioSession.create("taken", data, drafts, content)).is_null()


func test_existing_backup_is_never_overwritten() -> void:
	var path := _root.path_join("home.jsonc")
	StudioFiles.write_content(path, "first")
	var backups := _root.path_join("backups")
	assert_bool(StudioFiles.backup(path, "stamp", backups)).is_true()
	StudioFiles.write_content(path, "second")
	assert_bool(StudioFiles.backup(path, "stamp", backups)).is_false()
	assert_str(StudioFiles.read_text(StudioFiles.backup_path(path, "stamp", backups))).is_equal("first")


func _parsed(path: String, text: String) -> StudioDoc:
	var parsed := StudioDoc.parse(path, "map", text)
	var doc: StudioDoc = parsed["doc"]
	return doc


## Saves the draft of a real map file, unchanged, into this test's folder.
func _save(path: String) -> void:
	var text := StudioFiles.read_text(path)
	StudioFiles.save_draft(_parsed(path, text), text, _root)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(name))
	for name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
