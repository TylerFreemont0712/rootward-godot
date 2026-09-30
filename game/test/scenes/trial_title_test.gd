extends GdUnitTestSuite

const ROOT := "user://test-trial-title"


func test_first_program_start_offers_the_trial() -> void:
	# A first start needs a first profile: a folder left by an earlier run already has the Trial offered.
	_clear(ROOT)
	Game.reset(ROOT)
	assert_bool(Game.boot()).is_true()
	var named := Game.profiles.rename(String(Game.profile.id), "Trial Tester")
	assert_bool(named.ok).is_true()
	assert_bool(Game.select_profile(String(named.profile.id))).is_true()
	Game.use("program")
	var title := (load(Game.TITLE) as PackedScene).instantiate()
	add_child(title)
	await get_tree().process_frame
	title.call("_begin", false)
	assert_bool(Game.profile.tutorial.get("trial_prompted", false)).is_true()
	assert_bool(Game.session.has_run()).is_false()
	var overlay := title.get("_overlay") as Control
	assert_int(overlay.get_child_count()).is_greater(0)
	assert_str(_button_text(overlay, "Start the Trial")).is_equal("Start the Trial")
	assert_str(_button_text(overlay, "Start a full run")).is_equal("Start a full run")
	title.queue_free()
	await get_tree().process_frame


static func _button_text(root: Node, wanted: String) -> String:
	for button: Node in root.find_children("*", "Button", true, false):
		if (button as Button).text == wanted:
			return wanted
	return ""


static func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_clear(path.path_join(name))
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
