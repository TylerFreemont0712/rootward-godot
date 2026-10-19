extends GdUnitTestSuite
## Lanternroot's character screen (ADR-0061): the characters in a row on the cobbles, newest played first, with the New
## spot last; choosing moves the light and fills the panel; Play, Delete (asked first) and Make a character do what they
## say; the keyboard chooses and plays; and every saved look shows as one composed character sheet. Each case runs in
## its own save folder, and the scene change stays out of the test (`navigates` is false, `went_to` says where it went).

const ROOT := "user://test-character-select"
const ROBE_LOOK := {"model": "female"}
## A hat and armour from the flat character parts.
const OLD_LOOK := {"outfit": "outfit/armor", "hat": "hat/kettle", "colours": {"main": "cloth_blue"}}

var screen: CharacterSelect


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	_wipe()
	OverworldStore.current = ""


func after_test() -> void:
	if is_instance_valid(screen):
		screen.free()
	Sound.silence()
	await get_tree().create_timer(0.1).timeout
	Background.finish_all()
	ScreenTransition.busy = false
	_wipe()
	Game.reset()


## Three characters, saved oldest first: Taro, Mina, Kai (so Kai was played last).
func _seed() -> void:
	var store := OverworldStore.for_profile()
	for who: Array in [["Taro", OLD_LOOK], ["Mina", ROBE_LOOK], ["Kai", {}]]:
		var state := OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
		state.look = who[1]
		state.name = who[0]
		store.save_character(store.new_id(), state)
		await get_tree().create_timer(0.03).timeout


func _open() -> void:
	screen = (
		(load("res://scenes/overworld/character_select.tscn") as PackedScene).instantiate()
		as CharacterSelect
	)
	screen.navigates = false
	add_child(screen)
	await _frames(4)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _wipe() -> void:
	var store := OverworldStore.for_profile()
	for entry in store.characters():
		store.delete_character(String(entry.id))
	_remove(ProjectSettings.globalize_path(ROOT))


func _remove(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):
		_remove(path.path_join(folder))
	DirAccess.remove_absolute(path)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)


func test_the_row_lists_every_character_newest_first_and_the_new_spot_last() -> void:
	await _seed()
	await _open()
	assert_int(screen.count()).is_equal(4)
	var names: Array[String] = []
	for entry in screen.entries():
		names.append(String(entry.state.name))
	assert_array(names).is_equal(["Kai", "Mina", "Taro"])
	assert_int(screen.lineup.slots.size()).is_equal(4)
	assert_bool(screen.lineup.slots[3].is_new).is_true()
	assert_int(screen.chosen_index()).is_equal(0)
	assert_str(screen.panel_name()).is_equal("Kai")


func test_choosing_moves_the_light_and_fills_the_panel() -> void:
	await _seed()
	await _open()
	var before := screen.lineup.light_x()
	screen.choose(2)
	assert_str(screen.panel_name()).is_equal("Taro")
	assert_int(screen.lineup.chosen).is_equal(2)
	await _frames(90)
	assert_float(screen.lineup.light_x()).is_greater(before + CharacterSelectLineup.SLOT * 1.5)
	assert_float(screen.lineup.light_x()).is_equal_approx(screen.lineup.centre_of(2).x, 3.0)
	screen.choose(3)
	assert_bool(screen.is_new_chosen()).is_true()
	assert_str(screen.panel_name()).is_equal("")


func test_the_mouse_chooses_by_hovering_and_plays_with_a_click_on_the_chosen_one() -> void:
	await _seed()
	await _open()
	var lineup := screen.lineup
	var second := lineup.centre_of(1) + Vector2(0, -40)
	assert_int(lineup.slot_at(second)).is_equal(1)
	assert_int(lineup.slot_at(Vector2(second.x, 20.0))).is_equal(-1)
	lineup.hovered.emit(1)
	assert_str(screen.panel_name()).is_equal("Mina")
	lineup.picked.emit(1)
	assert_str(screen.went_to).is_equal(Game.OVERWORLD)
	assert_str(OverworldStore.current).is_equal(String(screen.entries()[1].id))


func test_play_goes_to_the_overworld_as_the_chosen_character() -> void:
	await _seed()
	await _open()
	screen.choose(1)
	var mina := screen.chosen_id()
	screen._play_chosen()
	assert_str(screen.went_to).is_equal(Game.OVERWORLD)
	assert_str(OverworldStore.current).is_equal(mina)
	assert_str(String(OverworldStore.for_profile().load_character(mina).name)).is_equal("Mina")


func test_delete_asks_first_and_then_removes_only_that_character() -> void:
	await _seed()
	await _open()
	screen.choose(1)
	var mina := screen.chosen_id()
	screen._ask_delete()
	assert_bool(screen._confirm.visible).is_true()
	assert_int(OverworldStore.for_profile().characters().size()).is_equal(3)
	screen.delete_chosen()
	await _frames(10)
	var left: Array[String] = []
	for entry in OverworldStore.for_profile().characters():
		left.append(String(entry.state.name))
	assert_array(left).is_equal(["Kai", "Taro"])
	assert_array(OverworldStore.for_profile().load_character(mina).keys()).is_empty()
	assert_int(screen.count()).is_equal(3)
	assert_str(screen.went_to).is_equal("")


func test_keeping_a_character_leaves_the_row_alone() -> void:
	await _seed()
	await _open()
	screen._ask_delete()
	_key(KEY_ESCAPE)
	await _frames(20)
	assert_bool(screen._confirm.visible).is_false()
	assert_int(OverworldStore.for_profile().characters().size()).is_equal(3)
	assert_str(screen.went_to).is_equal("")


func test_with_nobody_saved_the_empty_state_offers_a_character_and_opens_the_creator() -> void:
	await _open()
	assert_int(screen.entries().size()).is_equal(0)
	assert_int(screen.count()).is_equal(1)
	assert_bool(screen.is_new_chosen()).is_true()
	assert_bool(screen._play.visible).is_true()
	assert_str(screen._play.text).is_equal("Make a character")
	assert_bool(screen._progress_button.visible).is_false()
	assert_bool(screen._delete.visible).is_false()
	await _frames(3)
	assert_bool(screen._play.has_focus()).is_true()
	screen._play.pressed.emit()
	assert_bool(screen.creator.visible).is_true()
	assert_str(screen.went_to).is_equal("")


func test_the_keyboard_chooses_plays_and_goes_back() -> void:
	await _seed()
	await _open()
	_key(KEY_RIGHT)
	await _frames(2)
	assert_int(screen.chosen_index()).is_equal(1)
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	await _frames(2)
	assert_int(screen.chosen_index()).is_equal(3)
	_key(KEY_LEFT)
	await _frames(2)
	assert_int(screen.chosen_index()).is_equal(2)
	_key(KEY_ENTER)
	await _frames(2)
	assert_str(screen.went_to).is_equal(Game.OVERWORLD)
	assert_str(OverworldStore.current).is_equal(String(screen.entries()[2].id))


func test_escape_goes_back_to_the_title() -> void:
	await _seed()
	await _open()
	_key(KEY_ESCAPE)
	await _frames(2)
	assert_str(screen.went_to).is_equal(Game.TITLE)


func test_a_look_the_kit_cannot_draw_still_shows_a_picture_about_as_tall() -> void:
	await _seed()
	await _open()
	var taro := screen.lineup.slots[2].stand
	var kai := screen.lineup.slots[0].stand
	assert_bool(taro.has_picture()).is_true()
	assert_bool(kai.has_picture()).is_true()
	assert_float(taro.sheet.scale).is_equal(1.0)
	assert_vector(Vector2(taro.sheet.frame)).is_equal(Vector2(64, 96))
	assert_float(absf(taro.frame_size().y - kai.frame_size().y)).is_less(kai.frame_size().y * 0.25)
	assert_bool(screen.lineup.slots[3].stand.silhouette).is_true()


## Every Label's text under `node`.
func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


func test_the_card_is_basic_with_no_count_boxes() -> void:
	await _seed()
	await _open()
	var texts := _texts(screen._body)
	for text in texts:
		assert_bool(text in ["quests", "met", "keys"]).override_failure_message("count box word: %s" % text).is_false()
		assert_bool(text.contains(" / ")).override_failure_message("a count like %s" % text).is_false()
	assert_str(screen.panel_name()).is_equal("Kai")
	assert_bool(texts.has("Played today")).is_true()
	# One line for the language, how they build and the time played; then the rule and what they are doing now.
	assert_bool(texts.has("Python · Builder · A few minutes")).is_true()
	assert_bool(texts.has("Now:")).is_true()
	assert_bool(texts.has(Text.t("Your own two feet"))).is_true()
	assert_bool(screen._play.visible and screen._progress_button.visible and screen._delete.visible).is_true()


func test_the_detail_line_has_the_language_the_style_and_the_time_played() -> void:
	var state := OverworldState.fresh("lanternroot", Vector2i(13, 45), "down", "python")
	state["played_seconds"] = 4800
	assert_str(CharacterCard.detail_line(state)).is_equal("Python · Builder · 1 h 20 min")
	state.boots.style = OverworldState.SCRIBE
	state["played_seconds"] = 720
	assert_str(CharacterCard.detail_line(state)).is_equal("Python · Scribe · 12 min")
