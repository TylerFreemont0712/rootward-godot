extends GdUnitTestSuite
## Nym's shop (Concept/v0.4/05, section 2.9): the Sell and Buy lists, the prices that come in after the rows appear, the
## signals for a sale and a purchase, the mouse, and Esc.

const ITEMS := {
	"apple": {"name": "Apple", "about": "Crisp and red.", "icon": "item-apple", "colour": "cloth_red"},
	"cabbage": {"name": "Cabbage", "about": "Marta wants three.", "icon": "item-cabbage", "colour": "leaf"},
	"bread": {"name": "Bread", "about": "Warm from Marta's oven.", "icon": "item-bread", "colour": "cloth_yellow"},
	"gear": {"name": "Gear", "about": "Brannoc's best.", "icon": "item-gear", "colour": "leaf"},
}
## What Nym buys (coins for one), and what Nym sells (the cost).
const BUYS := {"apple": 4, "cabbage": 3}
const SELLS := {"bread": 5, "gear": 12}
## The player's price code: a coin value for one of each item it can price. "mystery" is one it cannot.
const UNIT := {"apple": 4, "cabbage": 3}

var shop: ShopPanel


func before_test() -> void:
	shop = ShopPanel.new()
	add_child(shop)
	await await_idle_frame()


func after_test() -> void:
	Sound.silence()
	shop.free()


## The player's price code, as the town calls it: a coroutine that answers a frame later.
func _price(item: String, count: int) -> int:
	await get_tree().process_frame
	if not UNIT.has(item):
		return -1
	return int(UNIT[item]) * count


func _key(code: Key, shift := false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.shift_pressed = shift
		get_tree().root.push_input(event)
	await get_tree().process_frame


## Opens the shop on the Sell tab and lets the price answers come in.
func _open(bag: Array) -> void:
	shop.open(bag, ITEMS, 12, BUYS, SELLS, _price)
	await _settle()


func _settle() -> void:
	for frame in 4:
		await await_idle_frame()


func test_sell_lists_the_stacks_nym_buys_with_their_prices() -> void:
	await _open([{"item": "apple", "count": 3}, {"item": "bread", "count": 2}, {"item": "cabbage", "count": 1}])
	assert_str(shop.tab()).is_equal("sell")
	assert_array(shop.shown_items()).is_equal(["apple", "cabbage"])
	assert_str(shop.coins_text()).is_equal("Coins: 12")
	assert_str(shop.row_text(0)).contains("1: 4 coins")
	assert_str(shop.row_text(0)).contains("all: 12 coins")
	assert_str(shop.row_text(1)).contains("1: 3 coins")
	assert_str(shop.row_text(1)).contains("all: 3 coins")


func test_a_price_the_code_cannot_give_shows_a_question_mark() -> void:
	shop.open([{"item": "mystery", "count": 2}], ITEMS, 12, {"mystery": 1}, SELLS, _price)
	await _settle()
	assert_str(shop.row_text(0)).contains("1: ? coins")
	assert_str(shop.row_text(0)).contains("all: ? coins")


func test_enter_sells_one_and_shift_enter_sells_the_whole_stack() -> void:
	await _open([{"item": "apple", "count": 3}])
	var sold: Array = []
	shop.sell.connect(func(item: String, count: int) -> void: sold.append([item, count]))
	await _key(KEY_ENTER)
	await _key(KEY_ENTER, true)
	assert_array(sold).is_equal([["apple", 1], ["apple", 3]])


func test_right_moves_to_buy_and_enter_buys_the_chosen_item() -> void:
	await _open([{"item": "apple", "count": 3}])
	await _key(KEY_RIGHT)
	assert_str(shop.tab()).is_equal("buy")
	assert_array(shop.shown_items()).is_equal(["bread", "gear"])
	assert_str(shop.row_text(0)).contains("5 coins")
	var bought: Array[String] = []
	shop.buy.connect(func(item: String) -> void: bought.append(item))
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	assert_array(bought).is_equal(["gear"])


func test_the_tab_buttons_and_a_click_work_with_the_mouse() -> void:
	await _open([{"item": "apple", "count": 3}])
	(shop.get("_tab_buy") as Button).pressed.emit()
	# The sell rows are freed at the end of the frame, as they are in the game, so let one pass.
	await await_idle_frame()
	assert_str(shop.tab()).is_equal("buy")
	var bought: Array[String] = []
	shop.buy.connect(func(item: String) -> void: bought.append(item))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var rows := shop.get("_rows") as Array
	(rows[1] as Control).gui_input.emit(click)
	assert_array(bought).is_equal(["gear"])


func test_a_click_sells_one_and_a_shift_click_sells_the_stack() -> void:
	await _open([{"item": "apple", "count": 3}])
	var sold: Array = []
	shop.sell.connect(func(item: String, count: int) -> void: sold.append([item, count]))
	var rows := shop.get("_rows") as Array
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(rows[0] as Control).gui_input.emit(click)
	click.shift_pressed = true
	(rows[0] as Control).gui_input.emit(click)
	assert_array(sold).is_equal([["apple", 1], ["apple", 3]])


func test_after_a_sale_the_bag_and_the_coins_come_back_in() -> void:
	await _open([{"item": "apple", "count": 3}])
	shop.set_state([{"item": "apple", "count": 2}], 16)
	await _settle()
	assert_str(shop.coins_text()).is_equal("Coins: 16")
	assert_array(shop.shown_items()).is_equal(["apple"])
	assert_str(shop.row_text(0)).contains("1: 4 coins")
	shop.show_status("Sold 1 apple for 4 coins.", true)
	assert_str(shop.status_text()).is_equal("Sold 1 apple for 4 coins.")


func test_esc_leaves_the_shop() -> void:
	await _open([{"item": "apple", "count": 3}])
	var closed: Array = []
	shop.closed.connect(func() -> void: closed.append(1))
	await _key(KEY_ESCAPE)
	assert_bool(shop.is_open()).is_false()
	assert_int(closed.size()).is_equal(1)
