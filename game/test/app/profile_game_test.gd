extends GdUnitTestSuite
## The active profile owns the live session, its last run and its preferred language.

const ROOT := "user://test-profile-game"

var _old_path := ""


func before_test() -> void:
	_clear(ROOT)
	Game.reset(ROOT)
	_old_path = Settings.path


func after_test() -> void:
	Background.finish_all()
	Settings.path = _old_path
	Game.reset(ROOT)
	_clear(ROOT)


func test_switching_player_reloads_only_that_players_run_and_preferences() -> void:
	assert_bool(Game.boot()).is_true()
	# Booting points saving at the player's own settings; choosing a profile saves them: keep this suite's apart.
	Settings.path = ROOT + "/settings.json"
	var first := Game.profile.duplicate(true)
	assert_bool(first.needs_name).is_true()
	Game.session.start(SandboxJob.JAVASCRIPT, "beginner", "first-player")
	var second: Dictionary = Game.profiles.create("ゆき 🌸", "ja", "emberfox")
	assert_bool(second.ok).is_true()
	assert_bool(Game.select_profile(String(second.profile.id))).is_true()
	assert_bool(Game.session.has_run()).is_false()
	assert_bool(TranslationServer.get_locale().begins_with("ja")).is_true()
	assert_str(Settings.character_skin).is_equal("emberfox")
	Settings.language = SandboxJob.JAVASCRIPT
	Settings.difficulty = "programmer"
	Game.remember_profile_settings()
	Game.session.start(SandboxJob.JAVASCRIPT, "programmer", "second-player")
	assert_bool(Game.select_profile(String(first.id))).is_true()
	assert_str(Game.session.state.seed).is_equal("first-player")
	assert_str(Settings.language).is_equal(SandboxJob.PYTHON)
	assert_bool(Game.select_profile(String(second.profile.id))).is_true()
	assert_str(Game.session.state.seed).is_equal("second-player")
	assert_str(Settings.difficulty).is_equal("programmer")


static func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_clear(path.path_join(name))
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
