extends GdUnitTestSuite
## The real menu's list is the player's (Concept/v0.4/01 section 8.2): it shows `info.items` in their order and leaves
## out what is not asked for, with the words of the new items; the rule sits before the items that leave the town.

var menu: PauseMenu


func before_test() -> void:
	menu = PauseMenu.new()
	add_child(menu)
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	menu.free()


func _shown() -> Array[String]:
	var out: Array[String] = []
	for slot in menu.find_children("Slot_*", "Control", true, false):
		out.append(String(slot.name).trim_prefix("Slot_"))
	return out


func test_it_shows_the_given_items_in_order_and_not_the_missing_ones() -> void:
	var asked: Array[String] = ["continue", "quests", "workbench", "bag", "map", "music", "options", "save", "settings", "title", "credits", "quit"]
	menu.open({"items": asked, "can_save": true})
	await get_tree().process_frame
	assert_array(_shown()).is_equal(asked)
	assert_object(menu.item("characters")).override_failure_message("an item not asked for is not there").is_null()
	assert_object(menu.item("boots")).override_failure_message("Your boots is in the Workbench now").is_null()
	assert_str(menu.item("music").text).is_equal("Music box")
	assert_str(menu.item("workbench").text).is_equal("Workbench")
	assert_str(menu.item("bag").text).is_equal("Bag")
	assert_str(menu.item("credits").text).is_equal("Credits")


func test_it_remakes_the_list_when_the_items_change() -> void:
	menu.open({"items": ["continue", "settings", "quit"]})
	await get_tree().process_frame
	assert_array(_shown()).is_equal(["continue", "settings", "quit"])
	menu.close(false)
	menu.open({"items": ["continue", "bag", "quit"]})
	await get_tree().process_frame
	assert_array(_shown()).is_equal(["continue", "bag", "quit"])
	assert_bool(menu.save_locked).is_true()


func test_unknown_and_repeated_ids_are_left_out() -> void:
	assert_array(PauseMenu.shown_items(["continue", "teleport", "bag", "bag", "quit"])).is_equal(["continue", "bag", "quit"])
	assert_array(PauseMenu.shown_items(null)).is_equal(PauseMenu.ITEMS)


func test_picking_a_new_item_is_sent_to_the_town() -> void:
	var chosen: Array[String] = []
	menu.chosen.connect(func(action: String) -> void: chosen.append(action))
	menu.open({"items": ["continue", "bag", "options", "quit"]})
	menu.item("bag").pressed.emit()
	menu.item("options").pressed.emit()
	assert_array(chosen).is_equal(["bag", "options"])


func test_about_carries_the_extra_fields_and_keeps_the_map_place_when_none_is_given() -> void:
	var state := {"map": "lanternroot", "name": "Kai", "flags": {}}
	var catalog := {"maps": {"lanternroot": {"name": "Lanternroot"}}, "quests": {}}
	var info := PauseMenu.about(state, catalog, {"items": ["continue", "quit"], "first_time": true, "place": "", "clock": "18:40 · evening"})
	assert_str(String(info.place)).is_equal("Lanternroot")
	assert_bool(bool(info.first_time)).is_true()
	assert_str(String(info.clock)).is_equal("18:40 · evening")
	assert_array(info.items).is_equal(["continue", "quit"])
	var theirs := PauseMenu.about(state, catalog, {"place": "Home Hollow"})
	assert_str(String(theirs.place)).is_equal("Home Hollow")


func test_the_place_and_the_clock_show_in_the_side_card() -> void:
	menu.open({"items": ["continue", "quit"], "place": "Home Hollow", "clock": "18:40 · evening"})
	await get_tree().process_frame
	var texts: Array[String] = []
	for label in menu.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_array(texts).contains(["Home Hollow", "18:40 · evening"])


func test_the_first_time_the_items_fly_in_one_by_one_and_then_rest() -> void:
	menu.open({"items": ["continue", "bag", "quit"], "first_time": true})
	await get_tree().process_frame
	var last := menu.find_child("Slot_quit", true, false) as Control
	assert_float(last.modulate.a).override_failure_message("the last item has not flown in yet").is_less(0.5)
	await get_tree().create_timer(0.9).timeout
	for slot in menu.find_children("Slot_*", "Control", true, false):
		assert_float((slot as Control).modulate.a).is_equal(1.0)
		assert_float(((slot as Control).get_child(0) as Control).offset_left).is_equal(0.0)
