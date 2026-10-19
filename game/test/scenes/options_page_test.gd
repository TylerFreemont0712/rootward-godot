extends GdUnitTestSuite
## The town's Options page (Concept/v0.4/01 section 8.3): the rows are the player's, in their order and words; a
## volume slider is locked while their volume() is not built and otherwise shows "7 → 49%" and says what changed.

const ROWS: Array[Dictionary] = [
	{"setting": "sound", "label": "Boom volume"},
	{"setting": "music", "label": "Songs"},
	{"setting": "text_speed", "label": "Talking"},
	{"setting": "track", "label": "Tune"},
	{"setting": "fullscreen", "label": "Big"},
]
const VALUES := {"music": 7, "sound": 5, "text_speed": "normal", "track": "Lanternroot", "fullscreen": false}

var page: OptionsPage


func before_test() -> void:
	page = OptionsPage.new()
	add_child(page)
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	page.free()


func _squared(notch: int) -> float:
	return pow(notch / 10.0, 2.0)


func _curve() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for notch in 11:
		out.append(_squared(notch))
	return out


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)
	await get_tree().process_frame


func test_the_rows_are_the_players_in_their_order_with_their_words() -> void:
	page.open(ROWS, VALUES, _squared, _curve())
	await get_tree().process_frame
	assert_array(page.shown_settings()).is_equal(["sound", "music", "text_speed", "track", "fullscreen"])
	assert_str(page.label_of("music")).is_equal("Songs")
	assert_str(page.label_of("sound")).is_equal("Boom volume")


func test_a_slider_is_locked_when_volume_at_gives_minus_one() -> void:
	page.open(ROWS, VALUES, func(_notch: int) -> float: return -1.0, PackedFloat32Array())
	await get_tree().process_frame
	assert_bool(page.is_locked("music")).is_true()
	assert_bool(page.is_locked("sound")).is_true()
	var changes: Array[String] = []
	page.changed.connect(func(setting: String, _value: Variant) -> void: changes.append(setting))
	page.slider("music").value = 3
	assert_array(changes).override_failure_message("a locked slider says nothing").is_empty()
	var words: Array[String] = []
	for label in page.find_children("*", "Label", true, false):
		words.append((label as Label).text)
	assert_array(words).contains(["Seren's knob isn't wired yet"])


func test_moving_a_slider_emits_changed_and_shows_the_percent() -> void:
	page.open(ROWS, VALUES, _squared, _curve())
	await get_tree().process_frame
	assert_bool(page.is_locked("music")).is_false()
	assert_str(page.readout("music")).is_equal("7 → 49%")
	var changes: Array = []
	page.changed.connect(func(setting: String, value: Variant) -> void: changes.append([setting, value]))
	page.slider("music").value = 8
	assert_array(changes).is_equal([["music", 8]])
	assert_str(page.readout("music")).is_equal("8 → 64%")
	assert_int(page.lit_notch()).override_failure_message("the chart lights the notch").is_equal(8)


func test_the_arrow_keys_move_the_focused_slider() -> void:
	page.open(ROWS, VALUES, _squared, _curve())
	await get_tree().process_frame
	page.slider("sound").grab_focus()
	var changes: Array = []
	page.changed.connect(func(setting: String, value: Variant) -> void: changes.append([setting, value]))
	await _key(KEY_LEFT)
	assert_array(changes).is_equal([["sound", 4]])
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	assert_int(int(page.slider("sound").value)).is_equal(6)


func test_text_speed_track_fullscreen_and_more_settings_speak() -> void:
	page.open(ROWS, VALUES, _squared, _curve())
	await get_tree().process_frame
	var changes: Array = []
	page.changed.connect(func(setting: String, value: Variant) -> void: changes.append([setting, value]))
	var signals: Array[String] = []
	page.open_music.connect(func() -> void: signals.append("music"))
	page.more_settings.connect(func() -> void: signals.append("more"))
	page.speed_button("fast").pressed.emit()
	assert_array(changes).is_equal([["text_speed", "fast"]])
	(page.find_child("Fullscreen", true, false) as CheckButton).button_pressed = true
	assert_array(changes[1]).is_equal(["fullscreen", true])
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).text == "Choose…":
			(button as Button).pressed.emit()
	page.more_button().pressed.emit()
	assert_array(signals).is_equal(["music", "more"])


func test_escape_closes_it() -> void:
	page.open(ROWS, VALUES, _squared, _curve())
	await get_tree().process_frame
	await _key(KEY_ESCAPE)
	assert_bool(page.is_open()).is_false()
