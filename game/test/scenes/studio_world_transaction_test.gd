extends GdUnitTestSuite

var _root := ""


func before_test() -> void:
	_root = "user://studio_test/transaction_recovery".path_join(str(Time.get_ticks_usec()))


func after_test() -> void:
	_remove_tree(_root)


func test_restart_rolls_back_prepared_transaction_and_completes_committed_transaction() -> void:
	for state: String in ["prepared", "committed"]:
		var first := _root.path_join("first.json")
		var second := _root.path_join("second.json")
		var storage: Array[Dictionary] = []
		for path: String in [first, second]:
			storage.append(
				{"path": path, "before": {"exists": true, "text": "before"}, "after": {"exists": true, "text": "after"}}
			)
		# A crash between writes leaves different sides on disk; the manifest determines both final images.
		assert_bool(StudioFiles.restore_storage_snapshot(first, storage[0].after)).is_true()
		assert_bool(StudioFiles.restore_storage_snapshot(second, storage[1].before)).is_true()
		(
			assert_bool(
				(
					StudioFiles
					. write_record(
						StudioFiles.world_transaction_manifest_path(_root),
						{
							"version": 1,
							"id": "interrupted",
							"state": state,
							"storage": storage,
						}
					)
				)
			)
			. is_true()
		)
		var recovered := StudioWorldTransaction.new(_root)
		assert_bool(recovered.recovery.ok).is_true()
		assert_bool(recovered.recovery.recovered).is_true()
		for path: String in [first, second]:
			assert_str(StudioFiles.read_text(path)).is_equal("before" if state == "prepared" else "after")
		assert_bool(FileAccess.file_exists(StudioFiles.world_transaction_manifest_path(_root))).is_false()
		assert_bool(StudioWorldTransaction.new(_root).recovery.recovered).is_false()


func test_unreadable_recovery_record_blocks_writes_and_preserves_drafts() -> void:
	var path := _root.path_join("first.json")
	assert_bool(StudioFiles.restore_storage_snapshot(path, {"exists": true, "text": "original"})).is_true()
	(
		assert_bool(
			(
				StudioFiles
				. write_record(
					StudioFiles.world_transaction_manifest_path(_root),
					{
						"version": 1,
						"id": "broken",
						"state": "unknown",
						"storage": [{"path": path}],
					}
				)
			)
		)
		. is_true()
	)
	var service := StudioWorldTransaction.new(_root)
	assert_bool(service.recovery.ok).is_false()
	var updates: Array[Dictionary] = [{"path": path, "text": "new"}]
	assert_bool(service.apply({}, {}, updates).ok).is_false()
	assert_str(StudioFiles.read_text(path)).is_equal("original")


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for folder: String in directory.get_directories():
		_remove_tree(path.path_join(folder))
	DirAccess.remove_absolute(path)
