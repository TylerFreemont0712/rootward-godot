extends GdUnitTestSuite
## Publish carries the catalog (Concept/v0.3/10, 7.7 and 9.5): a remake's catalog entry and the map object that uses it
## are reviewed in words, wait as warnings while the remake is queued (errors otherwise), and publish together into a
## temporary content copy. Real content is read, never written.

const TEST_HOME := "user://studio_test"
const MAP := "catalog-publish"

var _root := ""
var _content := ""
var _drafts := ""
var _publisher: StudioPublish


func before_test() -> void:
	_root = TEST_HOME.path_join("catalog-publish-%d" % Time.get_ticks_usec())
	_content = _root.path_join("content")
	_drafts = _root.path_join("drafts")
	_copy_tree(ContentLoader.ROOT, _content)
	_publisher = StudioPublish.new()
	_publisher.content_root = _content
	_publisher.drafts_dir = _drafts
	_publisher.backups_dir = _root.path_join("backups")
	var data := {
		"id": MAP, "name": "Catalog publish test", "legend": {".": "grass"},
		"ground": [".....", ".....", ".....", ".....", "....."], "start": [0, 0],
		"objects": [{"kind": "prop", "art": "bench", "at": [1, 1], "size": [2, 1]}],
	}
	assert_bool(StudioFiles.write_content(StudioSession.path_of(MAP, _content), JsoncWriter.map_text("// Fixture\n", data))).is_true()


func after_test() -> void:
	_remove_tree(_root)


## The bench remade at 3 x 1: the catalog gains its entry (and the bench a family), the map's bench becomes it.
func _remake() -> Dictionary:
	var catalog := StudioCatalogSession.open(_drafts, _content)
	assert_object(catalog).is_not_null()
	var bench := catalog.entry("bench")
	assert_bool(catalog.set_entry("bench", StudioRemake.family_entry("bench", bench))).is_true()
	assert_bool(catalog.set_entry("bench-3x1", StudioRemake.entry_for("bench", bench, Vector2i(3, 1)))).is_true()
	assert_bool(catalog.save()).is_true()
	var map := StudioSession.open(MAP, _drafts, _content)
	var sid: int = map.doc().sids[0]
	assert_bool(map.do({"type": "batch", "name": "Remake", "commands": [
		{"type": "set", "sid": sid, "key": "art", "value": "bench-3x1"},
		{"type": "set", "sid": sid, "key": "size", "value": [3, 1]},
	]}).ok).is_true()
	assert_bool(map.save()).is_true()
	return {"catalog": catalog, "map": map}


func test_a_queued_remake_reviews_as_warnings_and_publishes_with_the_map() -> void:
	var made := _remake()
	var map: StudioSession = made.map
	_publisher.remakes_waiting = ["bench-3x1"] as Array[String]
	var reviewed := _publisher.review({MAP: map})
	assert_int(int(reviewed.error_count)).is_equal(0)
	assert_int(int(reviewed.warning_count)).is_greater_equal(2)
	var lines: Array[String] = []
	for change: Dictionary in reviewed.changes:
		lines.append_array(change.lines)
	assert_array(lines).contains(["added catalog entry bench-3x1 (Bench, 3 × 1)", "changed catalog entry bench: family, variant"])
	assert_bool((reviewed.sessions as Dictionary).has(StudioCatalogSession.KEY)).is_false()
	assert_object(reviewed.catalog_session).is_not_null()
	var waiting := 0
	for problem: Dictionary in reviewed.problems:
		if String(problem.message).contains("waits for its remake"):
			waiting += 1
			assert_str(String(problem.severity)).is_equal("warning")
	assert_int(waiting).is_greater_equal(2)
	var result := _publisher.publish({MAP: map}, true)
	assert_bool(result.ok).is_true()
	var catalog_path := StudioCatalogSession.path_of(_content)
	assert_array(result.files).contains([catalog_path, map.path])
	var written := StudioFiles.read_text(catalog_path)
	var parsed := StudioDoc.parse(catalog_path, "catalog", written)
	assert_bool(parsed.ok).is_true()
	assert_str((parsed.doc as StudioDoc).to_text()).is_equal(written)
	var assets: Dictionary = (parsed.doc as StudioDoc).data.assets
	assert_str(String(assets.keys().back())).is_equal("bench-3x1")
	assert_str(String(assets.bench.family)).is_equal("bench")
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(catalog_path, _drafts))).is_false()
	assert_str(StudioFiles.read_text(map.path)).contains('"art": "bench-3x1"')


func test_without_a_queued_remake_the_missing_picture_stops_publish() -> void:
	var made := _remake()
	var reviewed := _publisher.review({MAP: made.map})
	assert_int(int(reviewed.error_count)).is_greater_equal(2)
	assert_bool(_publisher.publish({MAP: made.map}, true).ok).is_false()
	assert_bool(StudioFiles.exists(StudioFiles.draft_path(StudioCatalogSession.path_of(_content), _drafts))).is_true()


func test_a_saved_catalog_draft_is_found_without_its_session_and_reopens() -> void:
	_remake()
	var reopened := StudioCatalogSession.open(_drafts, _content)
	assert_bool(reopened.entry("bench-3x1").is_empty()).is_false()
	assert_int(reopened.changes()).is_equal(2)
	_publisher.remakes_waiting = ["bench-3x1"] as Array[String]
	var reviewed := _publisher.review({})
	var files: Array[String] = []
	for change: Dictionary in reviewed.changes:
		files.append(String(change.file))
	assert_array(files).contains([StudioCatalogSession.path_of(_content)])


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
