extends GdUnitTestSuite
## Navigation, cosmetic persistence and modal focus are behavior, independent of the painted backdrop.

const ROOT := "user://test-foundry-menus"

var _title: Control
var _old_path := ""
var _old_skin := ""
var _old_motion := false


func before_test() -> void:
	_old_path = Settings.path
	_old_skin = Settings.character_skin
	_old_motion = Settings.reduced_motion
	Game.reset(ROOT)
	assert_bool(Game.boot()).is_true()
	Game.profile.name = "Menu Tester"
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profile.avatar = "vesper"
	Game.profile.tutorial = {}
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	Game.use("program")
	Settings.path = ROOT + "/settings.json"
	Settings.reduced_motion = true
	_title = (load(Game.TITLE) as PackedScene).instantiate() as Control
	add_child(_title)
	await get_tree().process_frame


func after_test() -> void:
	_title.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Settings.path = _old_path
	Settings.character_skin = _old_skin
	Settings.reduced_motion = _old_motion


func test_home_separates_adventure_from_the_learning_placeholder() -> void:
	assert_object(_button(_title, "Adventure")).is_not_null()
	assert_object(_button(_title, "Academy")).is_not_null()
	assert_object(_button(_title, "Play")).is_null()
	_title.call("_open_academy")
	var overlay := _title.get("_overlay") as Control
	(
		assert_bool(
			overlay.find_children("*", "Label", true, false).any(
				func(label: Label) -> bool: return label.text == "IN PREPARATION"
			)
		)
		. is_true()
	)
	assert_bool(Game.session.in_progress()).is_false()
	_title.call("_close_overlay")
	_title.call("_show_setup")
	assert_object(_button(_title, "Begin a new descent")).is_not_null()
	assert_object(_button(_title, "Pip's travels")).is_not_null()
	assert_object(_button(_title, "Records")).is_not_null()
	assert_object(_button(_title, "Artificer")).is_not_null()
	assert_object(_button(_title, "Card Shardrun")).is_null()


func test_modal_stops_background_focus_and_restores_its_opener() -> void:
	var opener := _button(_title, "Settings")
	opener.grab_focus()
	opener.pressed.emit()
	await get_tree().process_frame
	assert_int(opener.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_object(get_viewport().gui_get_focus_owner()).is_not_null()
	assert_bool((_title.get("_overlay") as Control).is_ancestor_of(get_viewport().gui_get_focus_owner())).is_true()
	_title.call("_close_overlay")
	assert_int(opener.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(opener)


func test_character_equips_a_skin_without_closing_or_starting_a_run() -> void:
	_title.call("_open_skins")
	var panel := _panel("FoundryCharacterPanel") as FoundryCharacterPanel
	var looks: Array = panel.get("_looks")
	for i in looks.size():
		if looks[i].id == "emberfox":
			panel.set("_at", i)
	panel.call("_equip_current")
	assert_str(Settings.character_skin).is_equal("emberfox")
	assert_str(Game.profiles.get_profile(String(Game.profile.id)).avatar).is_equal("emberfox")
	assert_int((_title.get("_overlay") as Control).get_child_count()).is_greater(0)
	assert_bool(Game.session.has_run()).is_false()
	assert_str(panel.selected_class).is_equal("artificer")
	assert_bool((_button(panel, "Current skin") as Button).disabled).is_true()


func test_reduce_motion_applies_to_the_current_scene_immediately() -> void:
	Settings.reduced_motion = false
	var backdrop := _title.get("_backdrop") as FoundryBackdrop
	backdrop.apply_motion()
	_title.call("_open_options")
	var panel := _panel("FoundrySettingsPanel") as FoundrySettingsPanel
	Settings.reduced_motion = true
	panel.call("_saved")
	assert_bool(backdrop.get("_motion")).is_false()
	assert_int(backdrop.hero.process_mode).is_equal(Node.PROCESS_MODE_DISABLED)
	Settings.reduced_motion = false
	panel.call("_saved")
	assert_bool(backdrop.get("_motion")).is_true()


func test_library_creatures_come_from_the_live_catalog_and_can_be_searched() -> void:
	_title.call("_open_archive")
	var panel := _panel("FoundryLibraryPanel") as FoundryLibraryPanel
	panel.set("_kind", "foes")
	panel.set("_query", "tally")
	panel.call("_rebuild")
	assert_int((panel.get("_list") as VBoxContainer).get_child_count()).is_greater(0)
	var pictures := (panel.get("_details") as Control).find_children("*", "TextureRect", true, false)
	assert_bool(pictures.any(func(picture: TextureRect) -> bool: return picture.texture != null)).is_true()
	panel.set("_query", "there-is-no-such-creature")
	panel.call("_refresh")
	assert_int((panel.get("_list") as VBoxContainer).get_child_count()).is_equal(0)


func test_adventure_keeps_focus_on_language_choice_and_tutorial_is_opt_in() -> void:
	_title.call("_show_setup")
	var language := _button(_title, "JavaScript")
	language.grab_focus()
	language.pressed.emit()
	await get_tree().process_frame
	assert_str(Settings.language).is_equal("javascript")
	assert_str((get_viewport().gui_get_focus_owner() as Button).text).is_equal("JavaScript")
	assert_object(_button(_title, "Start tutorial")).is_null()
	_button(_title, "Pip's travels").pressed.emit()
	assert_object(_button(_title, "Start tutorial")).is_not_null()
	assert_object(_button(_title, "Begin a new descent")).is_null()
	assert_bool(Game.session.in_progress()).is_false()
	assert_bool(Game.trial_active).is_false()
	_button(_title, "Descent").pressed.emit()
	assert_object(_button(_title, "Begin a new descent")).is_not_null()
	assert_object(_button(_title, "Start tutorial")).is_null()


func test_library_role_filter_retains_the_selected_cards_upgrade() -> void:
	_title.call("_open_archive")
	var panel := _panel("FoundryLibraryPanel") as FoundryLibraryPanel
	panel.set("_role", "source")
	panel.set("_query", "Ember Constant")
	panel.call("_refresh")
	assert_int((panel.get("_list") as VBoxContainer).get_child_count()).is_equal(1)
	panel.set("_upgraded", true)
	panel.call("_show_entry", Game.catalog.programs.cards["fire-constant"])
	var labels := panel.find_children("*", "Label", true, false)
	assert_bool(labels.any(func(label: Label) -> bool: return label.text == "Ember Constant+")).is_true()


func test_locale_buttons_rebuild_without_freeing_the_signal_sender() -> void:
	for locale: String in ["日本語", "EN", "日本語", "EN"]:
		var sender := _button(_title, locale)
		var parent := sender.get_parent()
		sender.grab_focus()
		sender.pressed.emit()
		# LEARN: a clicked control must survive until its pressed signal has finished dispatching.
		assert_bool(is_instance_valid(sender)).is_true()
		assert_bool(parent.is_queued_for_deletion()).is_true()
		assert_bool(sender.is_inside_tree()).is_false()
		await get_tree().process_frame
	assert_str(Game.profile.preferred_language).is_equal("en")
	assert_object(_button(_title, "Adventure")).is_not_null()


func test_menu_buttons_round_trip_with_and_without_animation() -> void:
	for reduced: bool in [true, false]:
		Settings.reduced_motion = reduced
		for label: String in ["Settings", "Character", "Library", "Academy", "Menu Tester"]:
			await _press(label)
			assert_int((_title.get("_overlay") as Control).get_child_count()).is_greater(0)
			await _press("Back")
			assert_int((_title.get("_overlay") as Control).get_child_count()).is_equal(0)
		await _press("Adventure")
		assert_object(_button(_title, "Begin a new descent")).is_not_null()
		for label: String in ["Records", "Field guide", "Artificer"]:
			await _press(label)
			await _press("Back")
		await _press("Back")
		assert_object(_button(_title, "Adventure")).is_not_null()
		assert_bool(Game.session.in_progress()).is_false()


func test_settings_library_and_nested_profile_buttons_can_replace_their_own_pages() -> void:
	await _press("Settings")
	for label: String in ["Audio", "Spell playback", "Display"]:
		await _press(label)
		assert_object(_button(_title, "Back")).is_not_null()
	await _press("Back")
	await _press("Library")
	for label: String in ["Creatures", "Relics", "Concepts", "Shards", "Spellforge", "Shardrun"]:
		await _press(label)
		assert_object(_button(_title, "Back")).is_not_null()
	await _press("Back")
	for label: String in ["New player", "Rename", "Delete"]:
		await _press("Menu Tester")
		await _press(label)
		await _press("Keep player" if label == "Delete" else "Cancel")
		assert_int((_title.get("_overlay") as Control).get_child_count()).is_equal(0)


func test_compact_pages_fit_their_space_in_both_ui_languages() -> void:
	for locale: String in ["en", "ja"]:
		_title.call("_set_locale", locale)
		_title.call("_show_setup")
		await get_tree().process_frame
		await get_tree().process_frame
		var adventure := _panel("FoundryAdventurePanel")
		assert_float(adventure.size.x).is_less_equal(730.0)
		assert_float(adventure.size.y).is_less_equal(540.0)
		for entry: Array in [
			["_open_options", "FoundrySettingsPanel", Vector2(770, 490)],
			["_open_skins", "FoundryCharacterPanel", Vector2(1040, 590)],
			["_open_archive", "FoundryLibraryPanel", Vector2(970, 600)]
		]:
			_title.call(entry[0])
			await get_tree().process_frame
			await get_tree().process_frame
			var panel := _panel(entry[1])
			var limit: Vector2 = entry[2]
			assert_float(panel.size.x).is_less_equal(limit.x)
			assert_float(panel.size.y).is_less_equal(limit.y)
			_title.call("_close_overlay")
	_title.call("_set_locale", "en")


func _press(label: String) -> void:
	var overlay := _title.get("_overlay") as Control
	var button := _button(overlay if overlay.get_child_count() > 0 else _title, label)
	assert_object(button).is_not_null()
	if button == null:
		return
	button.grab_focus()
	button.pressed.emit()
	if not Settings.reduced_motion:
		await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame
	await get_tree().process_frame


func _panel(wanted: String) -> Control:
	for child: Node in _title.find_children("*", "", true, false):
		if child.get_script() != null and child.get_script().get_global_name() == wanted:
			return child as Control
	return null


static func _button(root: Node, wanted: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == wanted:
			return node as Button
	return null
