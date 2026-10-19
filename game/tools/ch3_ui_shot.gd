extends Control
## Chapter 3's new pieces for screenshots (Concept/v0.4/05), each on a plain background:
##   CH3_SHOT=shop scripts/screenshot.sh res://tools/ch3_ui_shot.tscn shots/v04/ch3-shop.png 40
## Moments: shop (Nym's shop on the Sell tab, the price code's answers in, a status line), bag (the Bag with coins, a
## total of 9 things and "T: tidy"), rain (rain falling over the plain background), cloud (the grey veil instead).

## The price code's answers for the shop: a coin value for one, and -1 for an item it cannot price.
const PRICES := {"apple": 4, "cabbage": 3, "carrot": 2}
const BUYS := {"apple": 4, "cabbage": 3, "carrot": 2}
const SELLS := {"bread": 5, "lantern-oil": 8, "gear": 12}
const BAG := [
	{"item": "apple", "count": 3},
	{"item": "carrot", "count": 2},
	{"item": "cabbage", "count": 1},
	{"item": "honey", "count": 3},
]


func _ready() -> void:
	var moment := OS.get_environment("CH3_SHOT")
	Game.reset("user://ch3-ui-shot")
	Game.boot()
	var items: Dictionary = OverworldContent.load_world().catalog.items
	var plain := ColorRect.new()
	plain.color = Color("#1d2a24")
	plain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plain)
	match moment:
		"bag":
			_bag(items)
		"rain":
			_rain("rain")
		"cloud":
			_rain("cloud")
		_:
			_shop(items)


func _shop(items: Dictionary) -> void:
	var shop := ShopPanel.new()
	add_child(shop)
	shop.open(BAG, items, 12, BUYS, SELLS, _price)
	shop.show_status(Text.t("Sold 1 carrot for 2 coins."), true)


func _bag(items: Dictionary) -> void:
	var bag := BagPanel.new()
	add_child(bag)
	bag.set_coins(12)
	bag.set_total(9)
	bag.set_tidy_enabled(true)
	bag.open(BAG, items)


func _rain(kind: String) -> void:
	var rain := RainLayer.new()
	add_child(rain)
	rain.set_weather(kind)


## The price code, as the shop asks it: a coroutine that answers a frame later.
func _price(item: String, count: int) -> int:
	await get_tree().process_frame
	return int(PRICES[item]) * count if PRICES.has(item) else -1
