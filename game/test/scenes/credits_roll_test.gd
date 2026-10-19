extends GdUnitTestSuite
## The credits (Concept/v0.4/01 section 5.10): the player's lines roll up, Esc skips to the closing card, and the roll is
## over once the card has been read.

var credits: CreditsRoll


func before_test() -> void:
	credits = CreditsRoll.new()
	credits.card_time = 0.2
	add_child(credits)
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	credits.free()


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)
	await get_tree().process_frame


func test_it_rolls_and_escape_skips_to_the_card_and_the_card_finishes_it() -> void:
	var done := [0]
	credits.finished.connect(func() -> void: done[0] += 1)
	var lines: Array[String] = ["Lanternroot", "", "Made by Kai", "Boots", "Menu"]
	credits.roll(lines, "Kai")
	await get_tree().process_frame
	assert_bool(credits.is_rolling()).is_true()
	assert_bool(credits.card_shown()).is_false()
	await _key(KEY_ESCAPE)
	assert_bool(credits.card_shown()).override_failure_message("Esc skips to the card").is_true()
	var card_words: Array[String] = []
	for label in credits.find_children("*", "Label", true, false):
		card_words.append((label as Label).text)
	assert_array(card_words).contains(["Lanternroot, made by Kai"])
	var over: bool = await _until(func() -> bool: return done[0] > 0)
	assert_bool(over).override_failure_message("finished fires once the card has been read").is_true()
	assert_int(done[0]).is_equal(1)
	assert_bool(credits.is_rolling()).is_false()


func test_a_held_key_speeds_it_up_until_the_card_comes() -> void:
	var done := [0]
	credits.finished.connect(func() -> void: done[0] += 1)
	var lines: Array[String] = ["Lanternroot", "Made by Mina"]
	credits.size = Vector2(320, 180)
	credits.roll(lines, "Mina")
	credits.speed_up(true)
	var carded: bool = await _until(func() -> bool: return credits.card_shown(), 10.0)
	assert_bool(carded).override_failure_message("the roll reaches the card").is_true()
	var over: bool = await _until(func() -> bool: return done[0] > 0)
	assert_bool(over).is_true()


func _until(done: Callable, seconds := 5.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true
