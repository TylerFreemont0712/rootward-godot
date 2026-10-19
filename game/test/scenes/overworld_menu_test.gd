extends GdUnitTestSuite
## Lanternroot's menu, quest tracker and quest log, driven the way a player drives them (ADR-0061): real key events go
## to the root of the tree, and the menu, the log and the tracker are read back from the screen. Esc opens the menu and
## Continue closes it; Save waits for the player's own save (lesson 2); the tracker shows the step under way, and a
## finished quest shows its toast. None of this needs the sandbox: the boots are read (or fail to be) on a thread
## before each case starts, and nothing here walks.

const ROOT := "user://test-overworld-menu"
const TOWN := "lanternroot"
const LOOK := {
	"outfit": "outfit/tunic",
	"hair": "hair/short",
	"colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal"},
}
## The opening's beats have played, so nothing opens over the town. The boots are not finished: their step to teach
## the cabbage gate is still to do, so the boots are the quest under way.
const ALL_BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true, "boots-expanded": true}

var screen: OverworldScreen
## The town as its content says it is (ADR-0061): its start is read from the map, not pinned here.
var _town: Dictionary = {}


func before() -> void:
	_town = OverworldContent.load_world().catalog.maps[TOWN]


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()


func after_test() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	Sound.silence()
	await _wait(0.1)
	Background.finish_all()
	OverworldStore.for_profile().delete_state()
	ScreenTransition.busy = false
	Game.reset()


## The town, opened in Lanternroot with these flags, once its boots have been read (or have failed to be). The player
## has built their own menu (v0.4: the shortcuts and the menu, from the test fixtures' reference programs) unless
## `own_menu` is false: then Esc opens Hotaru's pocket menu.
func _open(flags: Dictionary, own_menu := true, blocks: Array = []) -> void:
	var state := OverworldState.fresh(TOWN, OverworldMap.cell_of(_town.start), "down", BootsCode.PYTHON)
	state.look = LOOK.duplicate(true)
	state.name = "Tinker"
	if not blocks.is_empty():
		state.boots.blocks = blocks.duplicate(true)
	state.flags = flags.duplicate(true)
	# Hotaru's beats about the menus have been said, so none opens over the town.
	for told: String in ["pocket-menu-told", "own-menu-told"]:
		state.flags[told] = true
	if own_menu:
		for id: String in [Parts.SHORTCUTS, Parts.MENU]:
			state = Parts.with_record(state, id, Parts.passed_record({}, 0, TaskCheck.reference_of(id, "python"), "python"))
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _until(func() -> bool: return not bool(screen.get("_reading")))
	if own_menu:
		var parts := screen.get("_parts") as PartsRuntime
		await _until(func() -> bool: return parts.escape_opens_menu() and parts.menu_is_players())
	await _settle()


func _menu() -> PauseMenu:
	return screen.get("_menu") as PauseMenu


func _log() -> QuestLog:
	return screen.get("_log") as QuestLog


func _tracker() -> QuestTracker:
	return screen.get("_tracker") as QuestTracker


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	get_tree().root.push_input(event)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)
	await _settle()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _until(done: Callable, seconds := 20.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _focused() -> Control:
	return get_tree().root.gui_get_focus_owner()


func test_esc_opens_the_menu_and_continue_closes_it() -> void:
	await _open(ALL_BEATS)
	assert_bool(_menu().is_open()).override_failure_message("the menu starts closed").is_false()
	await _tap(KEY_ESCAPE)
	assert_bool(_menu().is_open()).override_failure_message("Esc opens the menu").is_true()
	assert_object(_focused()).override_failure_message("Continue has the focus when the menu opens").is_same(
		_menu().item(PauseMenu.CONTINUE)
	)
	assert_bool(_tracker().is_shown()).override_failure_message("the tracker hides under the menu").is_false()
	await _tap(KEY_ENTER)
	assert_bool(_menu().is_open()).override_failure_message("Enter on Continue closes the menu").is_false()
	await _tap(KEY_ESCAPE)
	assert_bool(_menu().is_open()).override_failure_message("Esc opens it again").is_true()
	await _tap(KEY_ESCAPE)
	assert_bool(_menu().is_open()).override_failure_message("and Esc closes it").is_false()


func test_before_the_menu_is_built_esc_opens_hotaru_s_pocket_menu() -> void:
	await _open(ALL_BEATS, false)
	await _tap(KEY_ESCAPE)
	var pocket := screen.get("_pocket") as PocketMenu
	assert_bool(pocket.is_open()).override_failure_message("Esc opens the pocket menu").is_true()
	assert_bool(_menu().is_open()).is_false()
	assert_array(pocket.shown_items()).contains(["continue", "settings", "title", "quit"])
	await _tap(KEY_ESCAPE)
	assert_bool(pocket.is_open()).override_failure_message("and Esc closes it").is_false()


func test_the_menu_shows_the_tinker_as_the_town_draws_them() -> void:
	await _open(ALL_BEATS)
	await _tap(KEY_ESCAPE)
	var figure := _menu().find_child("Figure", true, false) as CharacterStand
	assert_object(figure).override_failure_message("the menu has a figure").is_not_null()
	var walker := screen.get("_player") as Node
	assert_object(figure.sheet).override_failure_message("the menu's figure is the sheet the town walks with").is_same(
		walker.get("_sheet")
	)
	assert_bool(figure.has_picture()).override_failure_message("the figure has a picture, not the plain stand-in").is_true()
	assert_vector(Vector2(figure.sheet.frame) * figure.sheet.scale).override_failure_message(
		"drawn at the town's 64 x 96 people, not the old 25 x 35 parts"
	).is_equal(Vector2(OverworldScale.PERSON))


func test_save_is_locked_until_the_player_writes_their_own_save() -> void:
	await _open(ALL_BEATS)
	await _tap(KEY_ESCAPE)
	assert_bool(_menu().save_locked).override_failure_message("Save waits for memory-written").is_true()
	assert_bool(_menu().lock_note_shown()).override_failure_message("a kind line says where to learn it").is_true()
	_menu().item(PauseMenu.SAVE).pressed.emit()
	await _settle()
	assert_bool(_menu().is_open()).override_failure_message("a locked Save leaves the menu open").is_true()
	assert_str(_menu().status_text()).override_failure_message("a locked Save does not save").is_empty()
	await _tap(KEY_ESCAPE)

	screen.call("_set_flag", "memory-written")
	await _tap(KEY_ESCAPE)
	assert_bool(_menu().save_locked).override_failure_message("Save opens once memory-written is set").is_false()
	assert_bool(_menu().lock_note_shown()).override_failure_message("and the kind line goes").is_false()
	_menu().item(PauseMenu.SAVE).pressed.emit()
	var answered: bool = await _until(
		func() -> bool: return _menu().status_text() != "" and _menu().status_text() != Text.t("Saving...")
	)
	assert_bool(answered).override_failure_message("Save says how it went").is_true()


func test_the_tracker_shows_the_step_under_way() -> void:
	await _open(ALL_BEATS)
	var quests: Dictionary = screen.catalog.quests
	var current := Quests.current(quests, ALL_BEATS)
	# The boots are not finished, so their remaining cabbage-gate step is under way.
	assert_str(String(current.id)).override_failure_message("the boots are not done, so they are under way").is_equal(
		"boots"
	)
	assert_str(String(current.text)).is_equal("Teach the cabbage gate when to open.")
	assert_bool(_tracker().is_shown()).override_failure_message("the tracker shows over the town").is_true()
	assert_str(_tracker().step_text()).is_equal(Text.t(String(current.text)))
	assert_str(_tracker().title_text()).is_equal(Text.t(String(current.title)))


func test_finishing_a_quest_shows_its_toast_and_moves_the_tracker_on() -> void:
	# Every boots step but the last is done: including the extra boots direction and cabbage gate.
	var almost := {"woke": true, "first-step": true, "first-action": true, "boots-expanded": true, "all-ways": true, "cabbage-gate-open": true}
	await _open(almost)
	assert_str(_tracker().step_text()).is_equal(Text.t("Walk out of your house."))
	assert_str(_tracker().toast_text()).override_failure_message("no toast for quests done before").is_empty()
	screen.call("_set_flag", "left-home")
	await _settle()
	assert_str(_tracker().toast_text()).override_failure_message("finishing the boots quest shows its toast").is_equal(
		Text.f("Quest complete: %s", [Text.t("Your own two feet")])
	)
	var hotaru := screen.get("_hotaru") as HotaruSprite
	assert_bool(bool(hotaru.get("_noticed"))).override_failure_message("Hotaru shows her notice mark").is_true()
	var hello := Text.t("Say hello to Marta at the Warm Hearth.")
	var moved: bool = await _until(func() -> bool: return _tracker().step_text() == hello, 5.0)
	assert_bool(moved).override_failure_message("the tracker moves on to the next quest's first step").is_true()


func test_quests_opens_the_log_over_the_menu_and_esc_comes_back() -> void:
	await _open(ALL_BEATS)
	await _tap(KEY_ESCAPE)
	# A keyboard player has Quests in focus before choosing it, and the menu comes back to that focus when the log closes.
	_menu().item(PauseMenu.QUESTS).grab_focus()
	_menu().item(PauseMenu.QUESTS).pressed.emit()
	await _settle()
	assert_bool(_log().is_open()).override_failure_message("Quests opens the quest log").is_true()
	var entries := Quests.entries(screen.catalog.quests, ALL_BEATS)
	(
		assert_str(String(entries[_log().shown()].id))
		. override_failure_message("the log opens on the quest under way")
		. is_equal("boots")
	)
	await _tap(KEY_ESCAPE)
	assert_bool(_log().is_open()).override_failure_message("Esc closes the log").is_false()
	assert_bool(_menu().is_open()).override_failure_message("and the menu is still there under it").is_true()
	assert_object(_focused()).is_same(_menu().item(PauseMenu.QUESTS))


func test_time_played_grows_in_town_and_waits_while_the_menu_is_open() -> void:
	await _open(ALL_BEATS)
	await _wait(0.3)
	var before := float(screen.state.get("played_seconds", 0.0))
	assert_float(before).override_failure_message("time is played in town").is_greater(0.2)
	await _tap(KEY_ESCAPE)
	var paused := float(screen.state.get("played_seconds", 0.0))
	await _wait(0.3)
	(
		assert_float(float(screen.state.get("played_seconds", 0.0)))
		. override_failure_message("no time is played while the menu is open")
		. is_equal(paused)
	)
	await _tap(KEY_ESCAPE)
	screen.call("_save")
	var saved := OverworldStore.for_profile().load_state()
	assert_float(float(saved.get("played_seconds", 0.0))).override_failure_message("time played is saved").is_greater(
		0.2
	)


func test_loading_working_boots_recovers_milestones_without_repeating_the_lesson() -> void:
	var flags := {"woke": true, "first-step": true, "left-home": true}
	await _open(flags, false, [BootsCode.rule("right", "x", 1), BootsCode.rule("left", "x", -1),
		BootsCode.rule("up", "y", -1), BootsCode.rule("down", "y", 1)])
	assert_bool(bool(screen.state.flags.get("boots-expanded", false))).is_true()
	assert_bool(bool(screen.state.flags.get("all-ways", false))).is_true()
	assert_bool(bool(screen.state.flags.get("first-action", false))).is_false()


func test_extra_arrow_rule_counts_before_the_first_walk_and_survives_old_dialogue_flags() -> void:
	await _open({"woke": true}, false)
	var before: Dictionary = screen.state.flags.duplicate()
	screen.call("_open_boots")
	var tried := OverworldState.with_blocks(screen.state,
		[BootsCode.rule("right", "x", 1), BootsCode.rule("left", "x", -1)])
	await screen._on_boots_tried(tried)
	assert_bool(bool(screen.state.flags.get("boots-expanded", false))).is_true()
	assert_bool(bool(screen.state.flags.get("first-step", false))).is_false()
	var entry: Dictionary = Quests.entries(screen.catalog.quests, screen.state.flags)[0]
	assert_bool(bool(entry.steps[1].done)).is_true()
	assert_str(String(entry.next_step.text)).is_equal("Press Try them, then take a step.")
	var opens: Array[String] = []
	screen._on_talk_ended(before, opens)
	assert_bool(bool(screen.state.flags.get("boots-expanded", false))).is_true()
	assert_str(String(screen.state.boots.blocks[1].key)).is_equal("left")


func test_clicking_the_quest_card_opens_compact_instructions_before_the_menu_is_built() -> void:
	await _open(ALL_BEATS, false)
	var card := _tracker().get("_card") as Control
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = card.get_global_rect().get_center()
		card.gui_input.emit(event)
		await get_tree().process_frame
	assert_bool(_log().is_open()).is_true()
	assert_bool(_menu().is_open()).is_false()
	assert_object(_log().find_child("Instructions", true, false)).is_not_null()
	assert_bool(bool(screen.call("_paused"))).is_true()
	await _tap(KEY_ESCAPE)
	assert_bool(_log().is_open()).is_false()


func test_the_starting_pocket_menu_can_open_and_return_from_quests() -> void:
	await _open(ALL_BEATS, false)
	await _tap(KEY_ESCAPE)
	var pocket := screen.get("_pocket") as PocketMenu
	pocket.item("quests").pressed.emit()
	await _settle()
	assert_bool(_log().is_open()).is_true()
	assert_bool(pocket.is_open()).is_true()
	await _tap(KEY_ESCAPE)
	assert_bool(_log().is_open()).is_false()
	assert_bool(pocket.is_open()).is_true()
	assert_bool((pocket.get("_card") as Control).visible).is_true()


func test_clicking_a_quest_while_walking_opens_it_after_the_step_lands() -> void:
	await _open(ALL_BEATS, false)
	var player := screen.get("_player") as Walker
	player.walk_to(player.cell + Vector2i.RIGHT, "right", 0.12)
	screen.call("_open_quest_details", "boots")
	assert_bool(_log().is_open()).is_false()
	var opened := await _until(func() -> bool: return _log().is_open(), 2.0)
	assert_bool(opened).is_true()
	assert_bool(player.moving).is_false()
