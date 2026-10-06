extends GdUnitTestSuite
## Lanternroot's screen end to end: a new player is welcomed, a town is founded, a letter opens at the workbench with
## its starter, a real run in the sandbox lights the lantern, and the town is saved.

const ROOT := "user://test-lanternroot"

var screen: LanternrootScreen


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	for language in LanternRules.LANGUAGES:
		LanternStore.for_profile().delete_town(language)
	screen = (load(Game.LANTERNROOT) as PackedScene).instantiate() as LanternrootScreen
	add_child(screen)
	await get_tree().process_frame


func after_test() -> void:
	screen.queue_free()
	Background.finish_all()
	await get_tree().process_frame


func _labels() -> Array[String]:
	var texts: Array[String] = []
	for node in screen.find_children("*", "Label", true, false):
		texts.append((node as Label).text)
	for node in screen.find_children("*", "Button", true, false):
		texts.append((node as Button).text)
	return texts


func test_a_new_player_is_welcomed_and_chooses_a_language() -> void:
	assert_array(_labels()).contains(["Welcome to Lanternroot", "Python"])
	assert_bool(screen.town.is_empty()).is_true()
	screen.start("python")
	assert_int(screen.town.day).is_equal(1)
	assert_array(_labels()).contains(["Oil for the lamps", "How many loaves?", "A proper greeting"])
	assert_bool(FileAccess.file_exists(LanternStore.for_profile().path_for("python"))).is_true()


func test_answering_a_letter_lights_its_lantern() -> void:
	screen.start("python")
	screen.call("_open_letter", "lamp-oil")
	var bench := screen.get("_bench") as LanternWorkbench
	assert_bool(bench.visible).is_true()
	assert_str(bench.editor.text).contains("def lamp_oil(lamps):")
	bench.editor.text = "def lamp_oil(lamps):\n    return lamps * 3\n"
	await screen.call("_run_tests")
	assert_str(screen.town.lanterns.get("lamp-oil", "")).is_equal(LanternRules.LIT)
	assert_array(_labels()).contains(["✦ The lantern is lit!"])
	screen.call("_leave_bench")
	var saved := LanternStore.for_profile().load_town("python")
	assert_str(saved.files.lamps).contains("return lamps * 3")
	assert_bool(LanternRules.is_solved(saved, "lamp-oil")).is_true()
