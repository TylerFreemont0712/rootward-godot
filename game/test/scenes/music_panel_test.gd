extends GdUnitTestSuite
## The town's Music panel (Concept/v0.4/01 section 8.5): the player's titles, a note by the one playing, Enter plays,
## "Next" asks the player's next_track, and the town's track can be set or given back.

const TITLES: Array[String] = ["Lanternroot", "Warm Hearth", "Study"]
const IDS: Array[String] = ["music-lanternroot-town", "music-lanternroot-home", "music-lanternroot-lesson"]

var panel: MusicPanel


func before_test() -> void:
	panel = MusicPanel.new()
	add_child(panel)
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	panel.free()


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)
	await get_tree().process_frame


func test_it_lists_the_titles_with_a_note_by_the_playing_one() -> void:
	panel.open(TITLES, IDS, IDS[1], "", func(index: int, count: int) -> int: return (index + 1) % count)
	await get_tree().process_frame
	assert_array(panel.shown_titles()).is_equal(TITLES)
	assert_bool(panel.note_shown(0)).is_false()
	assert_bool(panel.note_shown(1)).is_true()
	assert_bool(panel.note_shown(2)).is_false()


func test_next_uses_the_players_next_index() -> void:
	var asked: Array = []
	# The player's next_track here is a funny one, so the panel can only be using it if it lands on the last tune.
	var next := func(index: int, count: int) -> int:
		asked.append([index, count])
		return 2
	panel.open(TITLES, IDS, IDS[0], "", next)
	await get_tree().process_frame
	var played: Array[String] = []
	panel.play.connect(func(id: String) -> void: played.append(id))
	panel.next_button().pressed.emit()
	assert_array(played).is_equal([IDS[2]])
	assert_str(panel.playing_id()).is_equal(IDS[2])
	assert_bool(panel.note_shown(2)).is_true()
	assert_array(asked[0]).is_equal([0, 3])
	await _key(KEY_R)
	assert_int(played.size()).override_failure_message("R is Next too").is_equal(2)


func test_next_is_hidden_when_next_track_is_not_built() -> void:
	panel.open(TITLES, IDS, IDS[0], "", func(_index: int, _count: int) -> int: return -1)
	await get_tree().process_frame
	assert_bool(panel.next_button().visible).is_false()
	var played: Array[String] = []
	panel.play.connect(func(id: String) -> void: played.append(id))
	await _key(KEY_R)
	assert_array(played).override_failure_message("R does nothing then").is_empty()


func test_choosing_a_row_plays_it() -> void:
	panel.open(TITLES, IDS, "", "", Callable())
	await get_tree().process_frame
	var played: Array[String] = []
	panel.play.connect(func(id: String) -> void: played.append(id))
	panel.row(1).pressed.emit()
	assert_array(played).is_equal([IDS[1]])
	assert_bool(panel.next_button().visible).is_false()


func test_the_town_track_is_set_from_the_focused_row_and_given_back() -> void:
	panel.open(TITLES, IDS, IDS[0], "", Callable())
	await get_tree().process_frame
	var set_to: Array[String] = []
	panel.set_town_track.connect(func(id: String) -> void: set_to.append(id))
	panel.row(2).grab_focus()
	assert_str(panel.town_button().text).is_equal("Play in town: Study")
	panel.town_button().pressed.emit()
	panel.own_button().pressed.emit()
	assert_array(set_to).is_equal([IDS[2], ""])
	assert_str(panel.town_id()).is_empty()


func test_escape_closes_it() -> void:
	panel.open(TITLES, IDS, "", "", Callable())
	await get_tree().process_frame
	await _key(KEY_ESCAPE)
	assert_bool(panel.is_open()).is_false()
