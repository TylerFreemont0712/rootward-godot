class_name BagPanel
extends Control
## The town's Bag, the player's inventory (Concept/v0.4/01 section 8.4): a grid of 6 by 4 slots, 64 px each, one stack in
## each, in the order the player's add() left them. A slot shows the item's picture at 2x (a round stand-in in the
## item's colour with its first letter while there is no picture), and its count in an amber badge. The slot in focus
## says its name and what it is, below. Arrows move, Esc, B or I close.
##
##   bag.open([{"item": "apple", "count": 3}], catalog.items)   # items: id -> {name, about, icon, colour}
##
## Chapter 3 (Concept/v0.4/05): set_coins(n) shows a "Coins: n" line (-1 hides it); set_total(n) makes the header say
## "n things" (-1 keeps "n kinds"); set_tidy_enabled(true) shows "T: tidy", and then T emits `tidy` (the town tidies).

signal closed
signal tidy

const COLUMNS := 6
const ROWS := 4
const SLOT := 64.0
const GAP := 4.0
const ICON_FOLDER := "res://assets/overworld/world/"
const INK := PauseMenu.INK

## Trimmed item pictures, by icon id: an AtlasTexture of the used part, or null when there is no picture.
static var _icons: Dictionary = {}

var _open := false
var _bag: Array = []
var _items: Dictionary = {}
var _selected := 0
var _top := 0
var _card: PanelContainer
var _grid: Control
var _name: Label
var _about: Label
var _count: Label
var _motion: Tween
var _coins := -1
var _total := -1
var _tidy_enabled := false
var _coins_line: Label
var _tidy_hint: Label


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
	_card.custom_minimum_size.x = 490
	centre.add_child(_card)
	var heading := Ui.label(Text.t("Bag"), "Heading")
	heading.add_theme_color_override("font_color", UiTheme.AMBER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = PauseMenu.small("")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var note := PauseMenu.small(Text.t("Nym's design, your code: add() put these here."), true)
	note.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_coins_line = PauseMenu.small("")
	_coins_line.visible = _coins >= 0
	_tidy_hint = PauseMenu.help_line(Text.t("T: tidy"))
	_tidy_hint.visible = _tidy_enabled
	_grid = Control.new()
	_grid.name = "Grid"
	_grid.custom_minimum_size = Vector2(COLUMNS * SLOT + (COLUMNS - 1) * GAP, ROWS * SLOT + (ROWS - 1) * GAP)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid.draw.connect(_draw_grid)
	_grid.gui_input.connect(_on_grid_input)
	_name = Ui.label("")
	_name.add_theme_font_override("font", OverworldStyle.body_font(600))
	_name.add_theme_color_override("font_color", UiTheme.AMBER)
	_about = PauseMenu.small("", true)
	_about.custom_minimum_size.y = 60
	var help := PauseMenu.help_line(Text.t("Arrows: choose   Esc or I: close"))
	_card.add_child(
		Ui.vbox(
			[
				Ui.hbox([heading, _count], 12),
				note,
				_coins_line,
				PauseMenu.rule(),
				_grid,
				PauseMenu.rule(),
				Ui.vbox([_name, _about], 2),
				_tidy_hint,
				help
			],
			12
		)
	)


# --- opening and closing -------------------------------------------------------------------------------------------


func is_open() -> bool:
	return _open


## Opens over the town. `bag` is the player's stacks `[{item, count}]`; `items` is the catalog's items (id -> {name, about,
## icon, colour}).
func open(bag: Array, items: Dictionary) -> void:
	_bag = bag
	_items = items
	_selected = 0
	_top = 0
	_open = true
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	_refresh()


func close() -> void:
	if not _open:
		return
	_open = false
	Sound.play("sfx-whiff", 0.3)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.fade_out(self, func() -> void: visible = _open)
	closed.emit()


## Chapter 3's coins line and total (-1 hides or keeps the old header).
func set_coins(coins: int) -> void:
	_coins = coins
	if is_node_ready():
		_refresh()


func set_total(total: int) -> void:
	_total = total
	if is_node_ready():
		_refresh()


## T tidies the bag (the town's `tidy`). Off until the part is built: then the hint "T: tidy" shows too.
func set_tidy_enabled(on: bool) -> void:
	_tidy_enabled = on
	if is_node_ready():
		_tidy_hint.visible = on


func _refresh() -> void:
	var total := _bag.size()
	if _total >= 0:
		_count.text = Text.t("1 thing") if _total == 1 else Text.f("%d things", [_total])
	else:
		_count.text = Text.f("%d kinds", [total]) if total != 1 else Text.t("1 kind")
	_coins_line.visible = _coins >= 0
	_coins_line.text = Text.f("Coins: %d", [_coins]) if _coins >= 0 else ""
	if total == 0:
		_name.text = ""
		_about.text = Text.t("Nothing yet. Apple trees are a good start.")
	else:
		var stack := _stack(_selected)
		var item := String(stack.get("item", ""))
		var entry := _entry(item)
		_name.text = Text.t(String(entry.get("name", item)))
		_about.text = Text.t(String(entry.get("about", "")))
	_grid.queue_redraw()


func _stack(index: int) -> Dictionary:
	if index < 0 or index >= _bag.size():
		return {}
	var stack: Variant = _bag[index]
	return stack if stack is Dictionary else {}


func _entry(item: String) -> Dictionary:
	var entry: Variant = _items.get(item, {})
	return entry if entry is Dictionary else {}


# --- the grid ------------------------------------------------------------------------------------------------------


func _slot_rect(cell: int) -> Rect2:
	var column := cell % COLUMNS
	var row := cell / COLUMNS
	return Rect2(Vector2(column * (SLOT + GAP), row * (SLOT + GAP)), Vector2(SLOT, SLOT))


func _draw_grid() -> void:
	var plain := UiTheme.box(OverworldStyle.WELL_FILL, UiTheme.LINE, 1, 8)
	var chosen := UiTheme.box(Color(UiTheme.AMBER, 0.16), UiTheme.AMBER, 3, 8)
	var font := OverworldStyle.body_font(600)
	for cell in COLUMNS * ROWS:
		var rect := _slot_rect(cell)
		var index := _top * COLUMNS + cell
		var stack := _stack(index)
		var picked := index == _selected and not _bag.is_empty()
		(chosen if picked else plain).draw(_grid.get_canvas_item(), rect)
		if stack.is_empty():
			continue
		var item := String(stack.get("item", ""))
		_draw_icon(rect, item)
		_draw_badge(rect, int(stack.get("count", 0)), font)


## The item's picture at 2x, centred in the slot; or a round stand-in in the item's colour with its first letter.
func _draw_icon(rect: Rect2, item: String) -> void:
	var entry := _entry(item)
	var picture := icon_picture(String(entry.get("icon", "")))
	if picture != null:
		var size := picture.get_size()
		var scale := 2.0 if size.x * 2.0 <= SLOT - 8.0 and size.y * 2.0 <= SLOT - 8.0 else 1.0
		var drawn := size * scale
		_grid.draw_texture_rect(picture, Rect2(rect.position + (rect.size - drawn) / 2.0, drawn), false)
		return
	var ramp := OverworldArt.ramp(String(entry.get("colour", "")))
	var colour := ramp[mini(1, ramp.size() - 1)] if not ramp.is_empty() else UiTheme.AMBER_DIM
	var centre := rect.get_center() + Vector2(0, -3)
	_grid.draw_circle(centre + Vector2(0, 3), 22.0, Color(0, 0, 0, 0.3))
	_grid.draw_circle(centre, 22.0, Color("#2a1a0c"))
	_grid.draw_circle(centre, 20.0, colour)
	_grid.draw_arc(centre + Vector2(-3, -3), 13.0, PI * 1.05, PI * 1.55, 10, colour.lightened(0.35), 3.0, true)
	var name := String(entry.get("name", item))
	var initial := name.substr(0, 1).to_upper()
	var ink := Color("#2a1a0c") if colour.get_luminance() > 0.45 else Color("#fff5dc")
	_grid.draw_string(
		OverworldStyle.body_font(600), centre + Vector2(-20, 9), initial, HORIZONTAL_ALIGNMENT_CENTER, 40, 26, ink
	)


func _draw_badge(rect: Rect2, count: int, font: Font) -> void:
	var words := str(count)
	var width := maxf(22.0, font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 12.0)
	var badge := Rect2(rect.end - Vector2(width + 3.0, 22.0 + 3.0), Vector2(width, 22.0))
	UiTheme.box(UiTheme.AMBER, Color("#2a1a0c"), 2, 8).draw(_grid.get_canvas_item(), badge)
	_grid.draw_string(
		font, badge.position + Vector2(0, 16.5), words, HORIZONTAL_ALIGNMENT_CENTER, width, 16, Color("#2a1a0c")
	)


## An item's picture from the world pipeline with its transparent margin trimmed (the object sits at the bottom of a
## 40 by 60 picture), or null when there is no picture yet.
static func icon_picture(icon: String) -> Texture2D:
	if icon == "":
		return null
	if _icons.has(icon):
		return _icons[icon]
	var found: Texture2D = null
	var full := OverworldArt.texture(ICON_FOLDER + icon + ".png")
	if full != null:
		var used := full.get_image().get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var trimmed := AtlasTexture.new()
			trimmed.atlas = full
			trimmed.region = Rect2(used)
			found = trimmed
	_icons[icon] = found
	return found


func _on_grid_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	var click := event as InputEventMouseButton
	var at := Vector2.ZERO
	if motion != null:
		at = motion.position
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		at = click.position
	else:
		return
	for cell in COLUMNS * ROWS:
		if _slot_rect(cell).grow(GAP / 2.0).has_point(at):
			var index := _top * COLUMNS + cell
			if index < _bag.size() and index != _selected:
				_select(index)
			return


# --- choosing ------------------------------------------------------------------------------------------------------


func _select(index: int) -> void:
	if _bag.is_empty():
		return
	index = clampi(index, 0, _bag.size() - 1)
	if index == _selected:
		return
	_selected = index
	var row := _selected / COLUMNS
	if row < _top:
		_top = row
	elif row >= _top + ROWS:
		_top = row - ROWS + 1
	Sound.play("sfx-card-flick-1", 0.3)
	_refresh()


func _move(dx: int, dy: int) -> void:
	if _bag.is_empty():
		return
	var row := _selected / COLUMNS
	var target := _selected
	if dx != 0:
		target = _selected + dx
	else:
		var wanted := _selected + dy * COLUMNS
		if wanted >= _bag.size() and (row + 1) * COLUMNS < _bag.size():
			wanted = _bag.size() - 1
		target = wanted if wanted >= 0 and wanted < _bag.size() else _selected
	_select(target)


# --- looking at it (for tests and the town) --------------------------------------------------------------------------


## How many stacks the panel shows.
func stack_count() -> int:
	return _bag.size()


## The item ids in the slots, in order.
func shown_items() -> Array[String]:
	var out: Array[String] = []
	for stack: Variant in _bag:
		out.append(String((stack as Dictionary).get("item", "")) if stack is Dictionary else "")
	return out


func selected_index() -> int:
	return _selected


func selected_name() -> String:
	return _name.text


## The line at the bottom: the item's about, or the empty bag's words.
func about_text() -> String:
	return _about.text


func empty_shown() -> bool:
	return _bag.is_empty()


## The header's words: "3 kinds", or "12 things" once set_total gave a total.
func header_text() -> String:
	return _count.text


## The coins line ("" while it is hidden).
func coins_text() -> String:
	return _coins_line.text if _coins_line.visible else ""


func tidy_hint_shown() -> bool:
	return _tidy_hint.visible


# --- input ---------------------------------------------------------------------------------------------------------


## While the bag is open nothing reaches the town. Arrows (or a pad's d-pad) move; Esc, I, B or Start close it.
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var start := event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	var key := event as InputEventKey
	if event.is_action_pressed("ui_cancel") or start or (key != null and key.keycode == KEY_I):
		close()
		return
	if key != null and key.keycode == KEY_T and _tidy_enabled:
		tidy.emit()
		return
	if event.is_action_pressed("ui_left"):
		_move(-1, 0)
	elif event.is_action_pressed("ui_right"):
		_move(1, 0)
	elif event.is_action_pressed("ui_up"):
		_move(0, -1)
	elif event.is_action_pressed("ui_down"):
		_move(0, 1)
