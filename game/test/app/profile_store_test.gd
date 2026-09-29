extends GdUnitTestSuite

const ROOT := "user://test-profiles"
const LEGACY := "user://test-profile-legacy"


func before_test() -> void:
	_clear(ROOT)
	_clear(LEGACY)


func after_test() -> void:
	_clear(ROOT)
	_clear(LEGACY)


func test_create_list_rename_delete_and_last_played_order() -> void:
	var store := ProfileStore.new(ROOT)
	var a: Dictionary = store.create("  Aki  ", "ja", "vesper")
	var b: Dictionary = store.create("Mio", "en", "emberfox")
	assert_bool(a.ok).is_true()
	assert_str(a.profile.name).is_equal("Aki")
	assert_str(a.profile.created_at).is_not_empty()
	assert_int(store.list_profiles().size()).is_equal(2)
	assert_bool(store.activate(a.profile.id)).is_true()
	assert_str(store.active().id).is_equal(a.profile.id)
	assert_str(store.list_profiles()[0].id).is_equal(a.profile.id)
	assert_bool(store.rename(a.profile.id, " 秋 🍁 ").ok).is_true()
	assert_str(store.active().name).is_equal("秋 🍁")
	assert_bool(store.delete(a.profile.id)).is_true()
	assert_int(store.list_profiles().size()).is_equal(1)
	assert_str(store.active().id).is_equal(b.profile.id)


func test_unicode_names_limit_and_case_width_duplicates() -> void:
	var store := ProfileStore.new(ROOT)
	assert_bool(store.create("Ａｌｉｃｅ", "ja").ok).is_true()
	assert_bool(store.create("alice", "en").ok).is_false()
	assert_bool(store.create("　", "ja").ok).is_false()
	assert_bool(store.create("あいうえお🌸", "ja").ok).is_true()
	assert_bool(store.create("1234567890123456789012345", "en").ok).is_false()
	assert_bool(store.create("ミオ", "ja").ok).is_true()
	assert_bool(store.create("ﾐｵ", "ja").ok).is_false()


func test_two_profiles_have_separate_runs_and_histories() -> void:
	var store := ProfileStore.new(ROOT)
	var one: Dictionary = store.create("One")
	var two: Dictionary = store.create("Two")
	var first := SaveStore.new(store.run_root(one.profile.id))
	var second := SaveStore.new(store.run_root(two.profile.id))
	first.save_run("program", {"seed": "one"})
	first.append_history({"seed": "one"})
	assert_bool(FileAccess.file_exists(second.path_for("program"))).is_false()
	assert_array(second.load_history()).is_empty()
	second.save_run("program", {"seed": "two"})
	assert_str(FileAccess.get_file_as_string(first.path_for("program"))).contains("one")
	assert_str(FileAccess.get_file_as_string(second.path_for("program"))).contains("two")


func test_corrupt_profile_never_blocks_other_profiles() -> void:
	var store := ProfileStore.new(ROOT)
	var good: Dictionary = store.create("Good")
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("broken"))
	var file := FileAccess.open(ROOT.path_join("broken/profile.json"), FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	assert_int(store.list_profiles().size()).is_equal(1)
	assert_str(store.list_profiles()[0].id).is_equal(good.profile.id)


func test_legacy_saves_are_copied_verified_and_left_in_place() -> void:
	DirAccess.make_dir_recursive_absolute(LEGACY)
	var file := FileAccess.open(LEGACY.path_join("program.json"), FileAccess.WRITE)
	file.store_string('{"a": 1}')
	file.close()
	var store := ProfileStore.new(ROOT)
	var migrated: Dictionary = store.migrate_legacy(LEGACY, "python", "beginner")
	assert_bool(migrated.ok).is_true()
	assert_bool(migrated.profile.needs_name).is_true()
	var copied := store.run_root(migrated.profile.id).path_join("program.json")
	var original := FileAccess.get_file_as_string(LEGACY.path_join("program.json"))
	assert_str(FileAccess.get_file_as_string(copied)).is_equal(original)
	var continued := FileAccess.open(copied, FileAccess.WRITE)
	continued.store_string('{"a": 2}')
	continued.close()
	assert_bool(store.confirm_migration(migrated.profile.id)).is_true()
	assert_bool(store.get_profile(migrated.profile.id).migration_verified).is_true()
	assert_bool(FileAccess.file_exists(LEGACY.path_join("program.json"))).is_true()


static func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_clear(path.path_join(name))
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
