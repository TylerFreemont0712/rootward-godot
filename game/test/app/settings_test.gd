extends GdUnitTestSuite
## Saved options survive the playstyles the game has retired.

const FILE := "user://test-settings-playstyle.json"

var _old_path := ""
var _old_playstyle := ""


func before_test() -> void:
	_old_path = Settings.path
	_old_playstyle = Settings.playstyle


func after_test() -> void:
	Settings.path = _old_path
	Settings.playstyle = _old_playstyle
	DirAccess.remove_absolute(FILE)


func _load(saved: Dictionary) -> void:
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	Settings.load_file(FILE)


func test_a_save_left_on_the_retired_verifier_opens_the_shardrun() -> void:
	Settings.playstyle = "spellbook"
	_load({"playstyle": "verifier"})
	assert_str(Settings.playstyle).is_equal("program")


func test_the_combat_playstyles_still_load() -> void:
	for playstyle: String in Game.COMBAT:
		Settings.playstyle = "program"
		_load({"playstyle": playstyle})
		assert_str(Settings.playstyle).is_equal(playstyle)


func test_the_verifier_is_no_longer_a_playstyle() -> void:
	assert_bool(Game.PLAYSTYLES.has("verifier")).is_false()
