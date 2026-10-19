extends GdUnitTestSuite
## Lanternroot's quest log (v0.4, Concept/v0.4/01 section 9.4): an open quest has a Track button (or T) that says which
## quest to follow, the tracked quest is marked, and each quest shows its giver's face.

const QUESTS := {
	"a": {"order": 1, "title": "First", "giver": "innkeeper", "summary": "S.", "steps": [{"text": "x", "done": {"flag": "fa"}}]},
	"b": {"order": 2, "title": "Second", "giver": "hotaru", "summary": "S.", "steps": [{"text": "y", "done": {"flag": "fb"}}]},
	"c": {"order": 3, "after": ["b"], "title": "Third", "giver": "pip", "summary": "S.", "steps": [{"text": "z", "done": {"flag": "fc"}}]},
}
const PEOPLE := {"innkeeper": {"name": "Marta", "portrait": "innkeeper"}, "pip": {"name": "Pip", "portrait": "pip"}}

var log_view: QuestLog
var tracked_ids: Array[String] = []


func before_test() -> void:
	tracked_ids.clear()
	log_view = QuestLog.new()
	add_child(log_view)
	log_view.track.connect(func(id: String) -> void: tracked_ids.append(id))
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	log_view.free()
	await get_tree().process_frame


func _open(focus: String, tracked := "", expanded := false) -> void:
	log_view.open(Quests.entries(QUESTS, {}), PEOPLE, focus, tracked, expanded)
	await get_tree().process_frame


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)


func test_the_track_button_says_which_quest_to_follow() -> void:
	await _open("b", "a")
	assert_str(log_view.tracked()).is_equal("a")
	var button := log_view.find_child("Track", true, false) as Button
	assert_object(button).override_failure_message("an open quest that is not tracked has the button").is_not_null()
	button.pressed.emit()
	await get_tree().process_frame
	assert_array(tracked_ids).is_equal(["b"])
	assert_str(log_view.tracked()).is_equal("b")
	# Now it is the tracked one: the button gives way to the mark.
	assert_object(log_view.find_child("Track", true, false)).is_null()
	assert_object(log_view.find_child("Tracking", true, false)).is_not_null()


func test_the_t_key_tracks_the_quest_on_the_page() -> void:
	await _open("b", "a")
	_key(KEY_T)
	await get_tree().process_frame
	assert_array(tracked_ids).is_equal(["b"])


func test_a_quest_still_hidden_cannot_be_tracked() -> void:
	await _open("a", "a")
	# "c" comes after "b", which is not done: it is locked.
	log_view._show(2)
	_key(KEY_T)
	await get_tree().process_frame
	assert_array(tracked_ids).is_empty()
	assert_object(log_view.find_child("Track", true, false)).is_null()


func test_the_quest_under_way_is_the_tracked_one_unless_another_was_chosen() -> void:
	await _open("a")
	assert_str(log_view.tracked()).is_equal("a")
	assert_object(log_view.find_child("Tracking", true, false)).is_not_null()


func test_each_open_quest_shows_its_givers_face_and_a_hidden_one_none() -> void:
	await _open("a", "a")
	for id: String in ["a", "b"]:
		assert_object(log_view.find_child("Quest_" + id, true, false).get_node_or_null("Face")).override_failure_message(id).is_not_null()
	assert_object(log_view.find_child("Quest_c", true, false)).is_null()


func test_the_log_still_closes_with_escape() -> void:
	await _open("a")
	_key(KEY_ESCAPE)
	await get_tree().process_frame
	assert_bool(log_view.is_open()).is_false()


func test_the_starting_log_is_compact_and_hides_future_quests() -> void:
	await _open("a")
	assert_bool((log_view.get("_left") as Control).visible).is_false()
	assert_bool((log_view.get("_journal") as Control).visible).is_false()
	assert_bool((log_view.get("_chooser") as Control).visible).is_true()
	assert_object(log_view.find_child("Quest_c", true, false)).is_null()
	assert_object(log_view.find_child("Instructions", true, false)).is_not_null()


func test_choosing_a_quest_shows_its_instructions() -> void:
	await _open("a")
	var chooser := log_view.get("_chooser") as OptionButton
	chooser.item_selected.emit(1)
	assert_int(log_view.shown()).is_equal(1)
	assert_object(log_view.find_child("Instructions", true, false)).is_not_null()


func test_progress_coding_unlocks_an_expandable_journal_with_history() -> void:
	log_view.open(Quests.entries(QUESTS, {"fa": true}), PEOPLE, "b", "b", true,
		func(done: int, total: int) -> int: return done * 100 / total if total > 0 else 0)
	await get_tree().process_frame
	var button := log_view.get("_journal") as Button
	assert_bool(button.visible).is_true()
	assert_object(log_view.find_child("Quest_a", true, false)).is_null()
	button.pressed.emit()
	await get_tree().process_frame
	assert_bool((log_view.get("_left") as Control).visible).is_true()
	assert_object(log_view.find_child("Quest_a", true, false)).is_not_null()
	assert_object(log_view.find_child("QuestProgress", true, false)).is_not_null()
	assert_object(log_view.find_child("Quest_c", true, false)).is_null()
	button.pressed.emit()
	await get_tree().process_frame
	assert_bool((log_view.get("_left") as Control).visible).is_false()
	assert_str(String((log_view.get("_entries") as Array)[log_view.shown()].id)).is_equal("b")
