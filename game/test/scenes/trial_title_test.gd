extends GdUnitTestSuite

const ROOT := "user://test-trial-title"


func test_new_player_can_browse_optional_tutorial_without_starting_either_run() -> void:
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
	title.call("_show_setup")
	var adventure := title.get("_adventure") as FoundryAdventurePanel
	assert_bool(Game.profile.tutorial.get("trial_prompted", false)).is_false()
	assert_bool(Game.session.has_run()).is_false()
	assert_str(_button_text(adventure, "Start tutorial")).is_empty()
	for button: Node in adventure.find_children("*", "Button", true, false):
		if (button as Button).text == "Pip's travels":
			(button as Button).pressed.emit()
			break
	assert_str(_button_text(adventure, "Start tutorial")).is_equal("Start tutorial")
	assert_bool(Game.trial_session.has_run()).is_false()
	assert_bool(Game.session.has_run()).is_false()
	assert_int((title.get("_overlay") as Control).get_child_count()).is_equal(0)
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
