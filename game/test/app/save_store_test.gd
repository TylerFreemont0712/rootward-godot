extends GdUnitTestSuite
## Saves that cannot be played are set aside, and the history survives a line cut short by a crash.

const ROOT := "user://test-save-store"

var catalog: Dictionary


func before() -> void:
	catalog = ContentLoader.load_shardrun().catalog


func after_test() -> void:
	_clear(ROOT)


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)


func _run() -> Dictionary:
	var options := {"seed": "save-store", "language": "python", "difficulty": "beginner", "playstyle": "spellbook"}
	return Shardrun.start(catalog, options)


func test_a_real_run_is_usable() -> void:
	assert_str(SaveStore.unusable(JsJson.parse(JSON.stringify(_run())))).is_empty()


## P2-12: a snapshot whose fields have the wrong shape is refused, not handed to the screens.
func test_a_run_with_fields_of_the_wrong_shape_is_unusable() -> void:
	var broken: Array[Dictionary] = []
	for change: Array in [
		["map", null], ["integrity", "full"], ["spells", {}], ["status", "dancing"], ["log", "none"], ["layer", null]
	]:
		var state := _run()
		state[change[0]] = change[1]
		broken.append(state)
	var no_integrity := _run()
	no_integrity.erase("integrity")
	broken.append(no_integrity)
	var battle_without_foes := _run()
	battle_without_foes.status = "battle"
	battle_without_foes.battle = {"turn": 1}
	broken.append(battle_without_foes)
	for state in broken:
		assert_str(SaveStore.unusable(state)).override_failure_message("accepted: %s" % [state.keys()]).is_not_empty()


## P2-15: a crash-truncated last line loses only itself, not the next run appended after it.
func test_a_cut_line_does_not_swallow_the_next_run() -> void:
	var saves := SaveStore.new(ROOT)
	assert_int(saves.append_history({"id": "first"})).is_equal(OK)
	var file := FileAccess.open(saves.history_path(), FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string('{"id": "cut sh')
	file.close()
	assert_int(saves.append_history({"id": "after"})).is_equal(OK)
	var ids := saves.load_history().map(func(record: Dictionary) -> String: return String(record.id))
	assert_array(ids).is_equal(["after", "first"])
