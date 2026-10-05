extends GdUnitTestSuite
## Saved options survive the playstyles the game has retired.

const FILE := "user://test-settings-playstyle.json"

var _old_path := ""
var _old_playstyle := ""
var _old_display: Array = []


func before_test() -> void:
	_old_path = Settings.path
	_old_playstyle = Settings.playstyle
	_old_display = [
		Settings.fullscreen,
		Settings.window_size,
		Settings.screen,
		Settings.vsync,
		Settings.frame_limit,
		Settings.background_slowdown,
		Settings.show_fps,
		Settings.ui_scale,
		Settings.gpu_index,
		Settings.renderer
	]


func after_test() -> void:
	Settings.path = _old_path
	Settings.playstyle = _old_playstyle
	Settings.fullscreen = _old_display[0]
	Settings.window_size = _old_display[1]
	Settings.screen = _old_display[2]
	Settings.vsync = _old_display[3]
	Settings.frame_limit = _old_display[4]
	Settings.background_slowdown = _old_display[5]
	Settings.show_fps = _old_display[6]
	Settings.ui_scale = _old_display[7]
	Settings.gpu_index = _old_display[8]
	Settings.renderer = _old_display[9]
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


func test_the_display_options_load_only_when_they_are_offered() -> void:
	_load(
		{
			"fullscreen": true,
			"window_size": "1600x900",
			"screen": 1,
			"vsync": "adaptive",
			"frame_limit": 60.0,
			"background_slowdown": false,
			"show_fps": true,
			"ui_scale": 1.0,
			"gpu_index": 0,
			"renderer": "gl_compatibility"
		}
	)
	assert_bool(Settings.fullscreen).is_true()
	assert_that(Settings.window_size).is_equal(Vector2i(1600, 900))
	assert_int(Settings.screen).is_equal(1)
	assert_str(Settings.vsync).is_equal("adaptive")
	assert_int(Settings.frame_limit).is_equal(60)
	assert_bool(Settings.background_slowdown).is_false()
	assert_bool(Settings.show_fps).is_true()
	assert_float(Settings.ui_scale).is_equal(1.0)
	assert_int(Settings.gpu_index).is_equal(0)
	assert_str(Settings.renderer).is_equal("gl_compatibility")
	_load(
		{
			"window_size": "1x1",
			"screen": 99,
			"vsync": "hyper",
			"frame_limit": 7,
			"ui_scale": 9.0,
			"gpu_index": 12,
			"renderer": "vulkan-ultra"
		}
	)
	assert_that(Settings.window_size).is_equal(Vector2i(1600, 900))
	assert_int(Settings.screen).is_equal(1)
	assert_str(Settings.vsync).is_equal("adaptive")
	assert_int(Settings.frame_limit).is_equal(60)
	assert_float(Settings.ui_scale).is_equal(1.0)
	assert_int(Settings.gpu_index).is_equal(0)
	assert_str(Settings.renderer).is_equal("gl_compatibility")


func test_the_display_options_are_saved_and_come_back() -> void:
	Settings.path = FILE
	Settings.vsync = "off"
	Settings.frame_limit = Graphics.UNLIMITED
	Settings.gpu_index = 1
	Settings.renderer = "mobile"
	Settings.window_size = Vector2i(1280, 720)
	Settings.save_file()
	Settings.vsync = "on"
	Settings.frame_limit = Graphics.AUTO
	Settings.gpu_index = Graphics.AUTO
	Settings.renderer = "auto"
	Settings.window_size = Graphics.DEFAULT_WINDOW
	Settings.load_file(FILE)
	assert_str(Settings.vsync).is_equal("off")
	assert_int(Settings.frame_limit).is_equal(Graphics.UNLIMITED)
	assert_int(Settings.gpu_index).is_equal(1)
	assert_str(Settings.renderer).is_equal("mobile")
	assert_that(Settings.window_size).is_equal(Vector2i(1280, 720))


func test_the_combat_playstyles_still_load() -> void:
	for playstyle: String in Game.COMBAT:
		Settings.playstyle = "program"
		_load({"playstyle": playstyle})
		assert_str(Settings.playstyle).is_equal(playstyle)


func test_the_verifier_is_no_longer_a_playstyle() -> void:
	assert_bool(Game.PLAYSTYLES.has("verifier")).is_false()
