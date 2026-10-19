extends GdUnitTestSuite
## Hotaru's pocket menu (Concept/v0.4/01 section 8.1): the stand-in menu before the player builds one. It always has
## Continue, Your boots, Save, Settings, Quit to title and Quit game; Save waits for the player's own save; and when
## the player's shortcut() lets go of Esc its note says so and a Fix it item appears.

var pocket: PocketMenu


func before_test() -> void:
	pocket = PocketMenu.new()
	add_child(pocket)
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	pocket.free()


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)
	await get_tree().process_frame


func test_it_lists_its_starting_items_and_the_usual_note() -> void:
	pocket.open({"can_save": false, "note": ""})
	await get_tree().process_frame
	assert_bool(pocket.is_open()).is_true()
	assert_array(pocket.shown_items()).is_equal(["continue", "boots", "quests", "save", "settings", "title", "quit"])
	assert_str(pocket.note_text()).is_equal("This is just my pocket menu. Mira at the workshop could build you a real one!")
	assert_bool(pocket.item("fix").visible).is_false()
	assert_bool(pocket.save_locked).override_failure_message("Save waits for the player's own save").is_true()


func test_a_broken_shortcut_changes_the_note_and_offers_fix_it() -> void:
	pocket.open({"can_save": true, "note": "shortcut-broken"})
	await get_tree().process_frame
	assert_str(pocket.note_text()).is_equal("Your shortcut() doesn't open the menu on Esc.")
	assert_array(pocket.shown_items()).is_equal(["continue", "boots", "quests", "save", "settings", "title", "quit", "fix"])
	assert_bool(pocket.save_locked).is_false()
	var chosen: Array[String] = []
	pocket.chosen.connect(func(action: String) -> void: chosen.append(action))
	pocket.item("fix").pressed.emit()
	assert_array(chosen).is_equal(["fix"])


func test_locked_save_says_nothing_but_unlocked_save_is_sent_on() -> void:
	var chosen: Array[String] = []
	pocket.chosen.connect(func(action: String) -> void: chosen.append(action))
	pocket.open({"can_save": false, "note": ""})
	pocket.item("save").pressed.emit()
	assert_array(chosen).override_failure_message("a locked Save is not sent").is_empty()
	assert_bool(pocket.lock_note_shown()).override_failure_message("it says where to learn it").is_true()
	pocket.close(false)
	pocket.open({"can_save": true, "note": ""})
	pocket.item("save").pressed.emit()
	pocket.item("boots").pressed.emit()
	assert_array(chosen).is_equal(["save", "boots"])


func test_continue_and_escape_close_it_and_settings_opens_the_titles_panel() -> void:
	var closes := [0]
	pocket.closed.connect(func() -> void: closes[0] += 1)
	pocket.open({"can_save": false, "note": ""})
	pocket.item("settings").pressed.emit()
	await get_tree().process_frame
	assert_bool(pocket.settings_open()).is_true()
	await _key(KEY_ESCAPE)
	assert_bool(pocket.settings_open()).override_failure_message("Esc leaves the settings first").is_false()
	assert_bool(pocket.is_open()).is_true()
	await _key(KEY_ESCAPE)
	assert_bool(pocket.is_open()).is_false()
	assert_int(closes[0]).is_equal(1)
	pocket.open({"can_save": false, "note": ""})
	pocket.item("continue").pressed.emit()
	assert_bool(pocket.is_open()).is_false()


func test_leaving_items_are_sent_on() -> void:
	var chosen: Array[String] = []
	pocket.chosen.connect(func(action: String) -> void: chosen.append(action))
	pocket.open({"can_save": false, "note": ""})
	pocket.item("title").pressed.emit()
	pocket.item("quit").pressed.emit()
	assert_array(chosen).override_failure_message("after one leaving item the menu takes no more").is_equal(["title"])
