extends GdUnitTestSuite
## The town's Bag (Concept/v0.4/01 section 8.4): a slot for each of the player's stacks, in their order, the selected
## one named at the bottom, and the empty bag's own words.

const ITEMS := {
	"apple": {"name": "Apple", "about": "Crisp and red.", "icon": "item-apple", "colour": "cloth_red"},
	"cabbage": {"name": "Cabbage", "about": "Marta wants three.", "icon": "item-cabbage", "colour": "leaf"},
	"honey": {"name": "Honey", "about": "From the hive.", "icon": "item-honey", "colour": "cloth_yellow"},
}

var bag: BagPanel


func before_test() -> void:
	bag = BagPanel.new()
	add_child(bag)
	await get_tree().process_frame


func after_test() -> void:
	Sound.silence()
	bag.free()


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		get_tree().root.push_input(event)
	await get_tree().process_frame


func test_the_slots_match_the_stacks_in_order() -> void:
	bag.open([{"item": "cabbage", "count": 3}, {"item": "apple", "count": 1}, {"item": "honey", "count": 2}], ITEMS)
	await get_tree().process_frame
	assert_int(bag.stack_count()).is_equal(3)
	assert_array(bag.shown_items()).is_equal(["cabbage", "apple", "honey"])
	assert_bool(bag.empty_shown()).is_false()
	assert_str(bag.selected_name()).is_equal("Cabbage")
	assert_str(bag.about_text()).is_equal("Marta wants three.")


func test_arrows_move_the_selection_and_i_closes_it() -> void:
	bag.open([{"item": "cabbage", "count": 3}, {"item": "apple", "count": 1}, {"item": "honey", "count": 2}], ITEMS)
	await get_tree().process_frame
	await _key(KEY_RIGHT)
	assert_str(bag.selected_name()).is_equal("Apple")
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	assert_int(bag.selected_index()).override_failure_message("the last slot is the end of the row").is_equal(2)
	await _key(KEY_LEFT)
	assert_int(bag.selected_index()).is_equal(1)
	await _key(KEY_I)
	assert_bool(bag.is_open()).is_false()


func test_down_goes_a_row_and_stops_at_the_last_stack() -> void:
	var stacks: Array = []
	for index in 8:
		stacks.append({"item": "apple", "count": index + 1})
	bag.open(stacks, ITEMS)
	await get_tree().process_frame
	await _key(KEY_DOWN)
	assert_int(bag.selected_index()).is_equal(6)
	await _key(KEY_DOWN)
	assert_int(bag.selected_index()).is_equal(6)
	await _key(KEY_UP)
	assert_int(bag.selected_index()).is_equal(0)


func test_an_empty_bag_says_where_to_start() -> void:
	bag.open([], ITEMS)
	await get_tree().process_frame
	assert_bool(bag.empty_shown()).is_true()
	assert_str(bag.about_text()).is_equal("Nothing yet. Apple trees are a good start.")
	await _key(KEY_ESCAPE)
	assert_bool(bag.is_open()).is_false()


func test_an_item_the_catalog_does_not_know_still_has_a_slot() -> void:
	bag.open([{"item": "mystery", "count": 1}], ITEMS)
	await get_tree().process_frame
	assert_str(bag.selected_name()).is_equal("mystery")


func test_coins_show_when_given_and_hide_at_minus_one() -> void:
	bag.open([{"item": "apple", "count": 1}], ITEMS)
	await get_tree().process_frame
	assert_str(bag.coins_text()).is_equal("")
	bag.set_coins(12)
	assert_str(bag.coins_text()).is_equal("Coins: 12")
	bag.set_coins(-1)
	assert_str(bag.coins_text()).is_equal("")


func test_the_header_counts_things_once_a_total_is_given() -> void:
	bag.open([{"item": "apple", "count": 3}, {"item": "honey", "count": 2}], ITEMS)
	await get_tree().process_frame
	assert_str(bag.header_text()).is_equal("2 kinds")
	bag.set_total(5)
	assert_str(bag.header_text()).is_equal("5 things")
	bag.set_total(1)
	assert_str(bag.header_text()).is_equal("1 thing")
	bag.set_total(-1)
	assert_str(bag.header_text()).is_equal("2 kinds")


func test_t_tidies_only_once_tidy_is_enabled() -> void:
	bag.open([{"item": "honey", "count": 2}, {"item": "apple", "count": 1}], ITEMS)
	await get_tree().process_frame
	var tidied: Array = []
	bag.tidy.connect(func() -> void: tidied.append(1))
	assert_bool(bag.tidy_hint_shown()).is_false()
	await _key(KEY_T)
	assert_int(tidied.size()).is_equal(0)
	bag.set_tidy_enabled(true)
	assert_bool(bag.tidy_hint_shown()).is_true()
	await _key(KEY_T)
	assert_int(tidied.size()).is_equal(1)
	assert_bool(bag.is_open()).is_true()
