class_name ShopPanel
extends Control
## Nym's shop (Concept/v0.4/05, section 2.9), in the bag's look. Two tabs: Sell lists the bag's stacks that Nym buys,
## each with its price for one and for all, asked of the player's price code live (`price_of`); Buy lists what Nym sells,
## with the cost. Left and Right change the tab, Up and Down choose a row, Enter sells one (or buys one), Shift+Enter
## sells the whole stack, and Esc leaves. A click works too (Shift+click sells the whole stack).
##
## The panel never changes the bag or the coins itself. It says what the player asked for (`sell`, `buy`); the town does
## it, then calls set_state with the bag and the coins as they are now, and show_status says how it went.
##
##   shop.open(bag, catalog.items, coins, buys, sells, price_of)
##   shop.set_state(bag, coins)                     # after a sale or a purchase
##   shop.show_status(Text.t("Sold 1 apple."), true)
##
## `buys` is {item: coins for one} and says which stacks Nym buys; `sells` is {item: cost} and is what Nym sells.
## `price_of(item, count)` is a coroutine that returns the coins for `count` of an item, or -1 when the player's code
## cannot price it (its row then shows "?").

signal sell(item: String, count: int)
signal buy(item: String)
signal closed

const TAB_SELL := "sell"
const TAB_BUY := "buy"
const WIDTH := 640.0
const ROW_HEIGHT := 60.0
const ICON := 44.0
const LIST_HEIGHT := 360.0
const INK := PauseMenu.INK

var _open := false
var _bag: Array = []
var _items: Dictionary = {}
var _coins := 0
var _buys: Dictionary = {}
var _sells: Dictionary = {}
var _price_of: Callable
var _tab := TAB_SELL
var _selected := 0
## The rows on show: sell rows {item, count}, buy rows {item, cost}.
var _offers: Array[Dictionary] = []
var _rows: Array[PanelContainer] = []
## The two price labels of each sell row, {"one": Label, "all": Label}; {} for a buy row. Index = row index.
var _price_labels: Array[Dictionary] = []
## Bumped whenever the rows are rebuilt, so an answer that comes late for an old row is dropped.
var _generation := 0
var _motion: Tween

var _card: PanelContainer
var _coin_line: Label
var _tab_sell: Button
var _tab_buy: Button
var _note: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _name: Label
var _about: Label
var _status: Label
var _help: Label


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style(Vector2(28, 20)))
	_card.custom_minimum_size.x = WIDTH
	centre.add_child(_card)
	var heading := Ui.label(Text.t("Nym's shop"), "Heading")
	heading.add_theme_color_override("font_color", UiTheme.AMBER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coin_line = PauseMenu.small("")
	_coin_line.add_theme_color_override("font_color", UiTheme.AMBER)
	_coin_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The tabs keep the keys to themselves: the panel reads the arrows and Enter, so a tab never takes the focus.
	_tab_sell = Ui.button(Text.t("Sell to Nym"), _set_tab.bind(TAB_SELL))
	_tab_buy = Ui.button(Text.t("Buy from Nym"), _set_tab.bind(TAB_BUY))
	for tab: Button in [_tab_sell, _tab_buy]:
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(150, 44)
	_note = PauseMenu.small("", true)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_scroll = Ui.scroll(_list)
	_scroll.custom_minimum_size.y = LIST_HEIGHT
	_name = Ui.label("", "", true)
	_name.add_theme_font_override("font", OverworldStyle.body_font(600))
	_name.add_theme_color_override("font_color", UiTheme.AMBER)
	_about = PauseMenu.small("", true)
	_about.custom_minimum_size.y = 48
	_status = PauseMenu.small("", true)
	_help = PauseMenu.help_line("")
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(
		_card
		. add_child(
			(
				Ui
				. vbox(
					[
						Ui.hbox([heading, _coin_line], 16),
						_note,
						Ui.hbox([_tab_sell, _tab_buy], 10),
						PauseMenu.rule(),
						_scroll,
						PauseMenu.rule(),
						Ui.vbox([_name, _about], 2),
						_status,
						_help,
					],
					12
				)
			)
		)
	)


func is_open() -> bool:
	return _open


## Opens over the town on the Sell tab. `bag` is the player's stacks `[{item, count}]`; `items` is the catalog's items;
## `coins` the player's coins; `buys` and `sells` as the file says; `price_of` the player's price code (see above).
func open(bag: Array, items: Dictionary, coins: int, buys: Dictionary, sells: Dictionary, price_of: Callable) -> void:
	_bag = bag
	_items = items
	_coins = coins
	_buys = buys
	_sells = sells
	_price_of = price_of
	_tab = TAB_SELL
	_selected = 0
	_open = true
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	show_status("", true)
	_refresh()


## After a sale or a purchase: the bag and the coins as they are now. The sell prices are asked again.
func set_state(bag: Array, coins: int) -> void:
	_bag = bag
	_coins = coins
	_refresh()


## The line under the list: what happened. `ok` colours it green; otherwise it is the warm amber of a question.
func show_status(text: String, ok: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.PASS if ok else UiTheme.WARN)


func close() -> void:
	if not _open:
		return
	_open = false
	Sound.play("sfx-whiff", 0.3)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.fade_out(self, func() -> void: visible = _open)
	closed.emit()


# --- the page ------------------------------------------------------------------------------------------------------


func _refresh() -> void:
	_coin_line.text = Text.f("Coins: %d", [_coins])
	_tab_sell.theme_type_variation = "PrimaryButton" if _tab == TAB_SELL else ""
	_tab_buy.theme_type_variation = "PrimaryButton" if _tab == TAB_BUY else ""
	if _tab == TAB_SELL:
		_note.text = Text.t("Nym pays what your price code says.")
		_help.text = Text.t(
			"Left, Right: Sell or Buy   Up, Down: choose   Enter: sell one   Shift+Enter: sell all   Esc: leave"
		)
	else:
		_note.text = Text.t("Nym sells these. Your code decides if you can pay.")
		_help.text = Text.t("Left, Right: Sell or Buy   Up, Down: choose   Enter: buy one   Esc: leave")
	_rebuild()


## The rows of the tab on show, rebuilt from the bag or the shop's table. The sell prices are asked after.
func _rebuild() -> void:
	_generation += 1
	Ui.clear(_list)
	_offers = _current_offers()
	_rows.clear()
	_price_labels.clear()
	_selected = clampi(_selected, 0, maxi(_offers.size() - 1, 0))
	if _offers.is_empty():
		_list.add_child(
			PauseMenu.small(
				(
					Text.t("Nym buys nothing you hold yet.")
					if _tab == TAB_SELL
					else Text.t("Nym has nothing to sell today.")
				),
				true
			)
		)
	for index in _offers.size():
		var row := _make_row(index)
		_rows.append(row)
		_list.add_child(row)
	_restyle()
	_describe()
	if _tab == TAB_SELL:
		_ask_prices()


func _current_offers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _tab == TAB_SELL:
		for stack: Variant in _bag:
			if not (stack is Dictionary):
				continue
			var item := String((stack as Dictionary).get("item", ""))
			var count := int((stack as Dictionary).get("count", 0))
			if count > 0 and _buys.has(item):
				out.append({"item": item, "count": count})
	else:
		for item: Variant in _sells.keys():
			out.append({"item": String(item), "count": 0, "cost": int(_sells[item])})
	return out


func _make_row(index: int) -> PanelContainer:
	var offer: Dictionary = _offers[index]
	var item := String(offer.item)
	var entry := _entry(item)
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = ROW_HEIGHT
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.draw.connect(_draw_icon.bind(icon, item))
	var title := Ui.label(Text.t(String(entry.get("name", item))))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	var parts: Array[Control] = [icon, title]
	if _tab == TAB_SELL:
		var count := Ui.label(Text.f("x%d", [int(offer.count)]), "Muted")
		var one := PauseMenu.small("")
		var all := PauseMenu.small("")
		parts.append_array([count, one, all])
		_price_labels.append({"one": one, "all": all})
	else:
		var cost := PauseMenu.small(Text.t("1 coin") if int(offer.cost) == 1 else Text.f("%d coins", [int(offer.cost)]))
		parts.append(cost)
		_price_labels.append({})
	var inside := Ui.hbox(parts, 14)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in inside.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(inside)
	row.mouse_entered.connect(_select.bind(index))
	row.gui_input.connect(_on_row_input.bind(index))
	return row


## The item's picture as BagPanel draws it (2x when it fits), or the stand-in circle in its colour with its first letter.
func _draw_icon(icon: Control, item: String) -> void:
	var entry := _entry(item)
	var picture := BagPanel.icon_picture(String(entry.get("icon", "")))
	if picture != null:
		var picture_size := picture.get_size()
		var zoom := 2.0 if picture_size.x * 2.0 <= ICON and picture_size.y * 2.0 <= ICON else 1.0
		var drawn := picture_size * zoom
		icon.draw_texture_rect(picture, Rect2((icon.size - drawn) / 2.0, drawn), false)
		return
	var ramp := OverworldArt.ramp(String(entry.get("colour", "")))
	var colour := ramp[mini(1, ramp.size() - 1)] if not ramp.is_empty() else UiTheme.AMBER_DIM
	var centre := icon.size / 2.0
	icon.draw_circle(centre, ICON / 2.0 - 2.0, Color("#2a1a0c"))
	icon.draw_circle(centre, ICON / 2.0 - 4.0, colour)
	var ink := Color("#2a1a0c") if colour.get_luminance() > 0.45 else Color("#fff5dc")
	var initial := String(entry.get("name", item)).substr(0, 1).to_upper()
	icon.draw_string(
		OverworldStyle.body_font(600),
		centre + Vector2(-ICON / 2.0, 8),
		initial,
		HORIZONTAL_ALIGNMENT_CENTER,
		ICON,
		24,
		ink
	)


func _restyle() -> void:
	for index in _rows.size():
		var on := index == _selected
		var fill := Color(UiTheme.AMBER, 0.16) if on else OverworldStyle.WELL_FILL
		var edge := UiTheme.AMBER if on else UiTheme.LINE
		_rows[index].add_theme_stylebox_override("panel", UiTheme.box(fill, edge, 3 if on else 1, 8, Vector2(12, 6)))


func _describe() -> void:
	if _offers.is_empty():
		_name.text = ""
		_about.text = ""
		return
	var offer := _offers[_selected]
	var entry := _entry(String(offer.item))
	_name.text = Text.t(String(entry.get("name", offer.item)))
	_about.text = Text.t(String(entry.get("about", "")))


func _entry(item: String) -> Dictionary:
	var entry: Variant = _items.get(item, {})
	return entry if entry is Dictionary else {}


# --- prices --------------------------------------------------------------------------------------------------------


## Asks the price code, live, for each sell row: the price for one and for the whole stack. Each answer shows when it
## comes in (a row says "?" when the code cannot price it).
func _ask_prices() -> void:
	if not _price_of.is_valid():
		return
	for index in _offers.size():
		_ask_row(_generation, index)


func _ask_row(generation: int, index: int) -> void:
	var item := String(_offers[index].item)
	var count := int(_offers[index].count)
	var one: int = await _price_of.call(item, 1)
	if not _still_wanted(generation, index):
		return
	_show_price(index, "one", one)
	var all: int = one
	if count != 1:
		all = await _price_of.call(item, count)
		if not _still_wanted(generation, index):
			return
	_show_price(index, "all", all)


func _still_wanted(generation: int, index: int) -> bool:
	return generation == _generation and index < _price_labels.size()


func _show_price(index: int, which: String, coins: int) -> void:
	var label := _price_labels[index].get(which) as Label
	if label == null:
		return
	if which == "one":
		label.text = (Text.t("1: 1 coin") if coins == 1 else Text.f("1: %d coins", [coins])) if coins >= 0 else Text.t("1: ? coins")
	else:
		label.text = (Text.t("all: 1 coin") if coins == 1 else Text.f("all: %d coins", [coins])) if coins >= 0 else Text.t("all: ? coins")


# --- choosing ------------------------------------------------------------------------------------------------------


func _set_tab(tab: String) -> void:
	if tab == _tab:
		return
	_tab = tab
	_selected = 0
	Sound.play("sfx-card-flick-1", 0.3)
	_refresh()


func _switch(step: int) -> void:
	var tabs: Array[String] = [TAB_SELL, TAB_BUY]
	_set_tab(tabs[posmod(tabs.find(_tab) + step, tabs.size())])


func _select(index: int) -> void:
	if _offers.is_empty():
		return
	index = clampi(index, 0, _offers.size() - 1)
	if index == _selected:
		return
	_selected = index
	Sound.play("sfx-card-flick-1", 0.3)
	_restyle()
	_describe()
	_scroll.ensure_control_visible(_rows[_selected])


## Sells one (or the whole stack, when `whole_stack`), or buys one. Nothing changes until the town answers.
func _act(whole_stack: bool) -> void:
	if _offers.is_empty():
		return
	var offer := _offers[_selected]
	var item := String(offer.item)
	if _tab == TAB_SELL:
		sell.emit(item, int(offer.count) if whole_stack else 1)
	else:
		buy.emit(item)


func _on_row_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_select(index)
	_act(click.shift_pressed)


## While the shop is open nothing reaches the town. Left and Right change the tab; Up and Down choose; Enter acts, with
## Shift it takes the whole stack; Esc or Start leaves.
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var start := event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if event.is_action_pressed("ui_cancel") or start:
		close()
	elif event.is_action_pressed("ui_left"):
		_switch(-1)
	elif event.is_action_pressed("ui_right"):
		_switch(1)
	elif event.is_action_pressed("ui_up"):
		_select(_selected - 1)
	elif event.is_action_pressed("ui_down"):
		_select(_selected + 1)
	elif event.is_action_pressed("ui_accept"):
		var key := event as InputEventKey
		_act(key != null and key.shift_pressed)


# --- looking at it (for tests and the town) --------------------------------------------------------------------------


## The tab on show: "sell" or "buy".
func tab() -> String:
	return _tab


## The item ids of the rows on show, in order.
func shown_items() -> Array[String]:
	var out: Array[String] = []
	for offer: Dictionary in _offers:
		out.append(String(offer.item))
	return out


func selected_index() -> int:
	return _selected


func selected_item() -> String:
	return String(_offers[_selected].item) if not _offers.is_empty() else ""


## The coins line, as the player reads it: "Coins: 12".
func coins_text() -> String:
	return _coin_line.text


func status_text() -> String:
	return _status.text


func about_text() -> String:
	return _about.text


## Everything a row says, joined: the name, the count or cost, and (for a sell row) its two prices, once they have come.
func row_text(index: int) -> String:
	if index < 0 or index >= _rows.size():
		return ""
	var words := PackedStringArray()
	for label: Node in _rows[index].find_children("*", "Label", true, false):
		if (label as Label).text != "":
			words.append((label as Label).text)
	return " | ".join(words)
