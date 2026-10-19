class_name BootsBlocks
extends RefCounted
## The blocks of the boots editor (ADR-0061), drawn the way the code they make is laid out: a rule's first line says
## which key, and its second, set in, says what changes, as `if key == "right":` sits over `player.x += 1`.
##
##   When [→ right] is pressed:            [✕]
##       change [x across] by [+1]
##
## Each card's pickers come in the order key, axis, amount. A card knows its rule's place in the list (meta "row").

const FILL := Color("#2a2119")
const FILL_LIT := Color("#3a2c1c")
const EDGE := Color("#6b5235")
## How far a rule's second line is set in, like the body of an `if`.
const INDENT := 32


## One rule as a card. `on_change(index, field, value)` hears a picker change ("key", "change" or "by");
## `on_remove(index)` hears the ✕.
static func card(block: Dictionary, index: int, on_change: Callable, on_remove: Callable) -> PanelContainer:
	var actions: Array = block.get("do", [])
	var action: Dictionary = actions[0] if not actions.is_empty() and actions[0] is Dictionary else {}
	var key := _picker(
		BootsRules.KEYS.map(func(k: String) -> String: return key_name(k)),
		BootsRules.KEYS.find(String(block.get("key", "right")))
	)
	key.item_selected.connect(func(i: int) -> void: on_change.call(index, "key", BootsRules.KEYS[i]))
	var axis := _picker(
		BootsCode.AXES.map(func(a: String) -> String: return axis_name(a)),
		BootsCode.AXES.find(String(action.get("change", "x")))
	)
	axis.item_selected.connect(func(i: int) -> void: on_change.call(index, "change", BootsCode.AXES[i]))
	var by := _picker(
		BootsCode.AMOUNTS.map(func(n: int) -> String: return "%+d" % n),
		BootsCode.AMOUNTS.find(int(action.get("by", 1)))
	)
	by.item_selected.connect(func(i: int) -> void: on_change.call(index, "by", BootsCode.AMOUNTS[i]))
	var remove := Ui.button("✕", on_remove.bind(index))
	remove.tooltip_text = Text.t("Take this rule away")
	remove.custom_minimum_size = Vector2(40, 0)
	var top := Ui.hbox([word("when"), key, word("pressed"), Ui.spacer(), remove], 8)
	var bottom := Ui.hbox([Ui.spacer(INDENT, 1), word("change"), axis, word("by"), by], 8)
	for line: HBoxContainer in [top, bottom]:
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", style(false))
	holder.add_child(Ui.vbox([top, bottom], 4))
	holder.set_meta("row", index)
	return holder


## A card's look: a block with a thick left edge, like the bar of a code block; lit (an amber edge all round and a
## warmer fill) while one of its controls has the focus, so the player sees which rule they are on.
static func style(lit: bool) -> StyleBoxFlat:
	var box := UiTheme.box(
		FILL_LIT if lit else FILL, UiTheme.AMBER if lit else EDGE, 2 if lit else 1, 8, Vector2(10, 6)
	)
	box.border_width_left = 6
	box.border_color = UiTheme.AMBER if lit else EDGE
	return box


## The card's first picker (its key), to give the focus to.
static func first_picker(holder: Control) -> Control:
	var found := holder.find_children("*", "OptionButton", true, false)
	return found[0] as Control if not found.is_empty() else holder


## The row a control sits in (its card's "row"), or -1 when it is not in a card.
static func row_of(control: Node) -> int:
	var at := control
	while at != null:
		if at.has_meta("row"):
			return int(at.get_meta("row"))
		at = at.get_parent()
	return -1


static func word(id: String) -> Label:
	return Ui.label(word_text(id))


## The words a rule is written in. Each is a literal Text.t call, so the locale check can find it.
static func word_text(id: String) -> String:
	match id:
		"when":
			return Text.t("When")
		"pressed":
			return Text.t("is pressed:")
		"change":
			return Text.t("change")
		"by":
			return Text.t("by")
	return id


## A key as the picker shows it: an arrow, then its name. Each is a literal Text.t call, for the locale check.
static func key_name(key: String) -> String:
	match key:
		"up":
			return Text.t("↑  up")
		"down":
			return Text.t("↓  down")
		"left":
			return Text.t("←  left")
		"right":
			return Text.t("→  right")
	return key


## An axis as the picker shows it: the code's name, then the direction in words (the help line says the same).
static func axis_name(axis: String) -> String:
	match axis:
		"x":
			return Text.t("x  across")
		"y":
			return Text.t("y  down")
	return axis


## A small drawing of the two axes: x points right, y points down, from the top-left corner where both are 0.
static func axis_glyph() -> Control:
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(52, 52)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(_draw_axes.bind(glyph))
	return glyph


static func _draw_axes(on: Control) -> void:
	var origin := Vector2(8, 8)
	var font := OverworldStyle.body_font(600)
	_arrow(on, origin, Vector2(40, 8), UiTheme.AMBER)
	_arrow(on, origin, Vector2(8, 40), UiTheme.TEAL)
	on.draw_circle(origin, 3.0, UiTheme.TEXT)
	on.draw_string(
		font, Vector2(36, 28), "x", HORIZONTAL_ALIGNMENT_LEFT, -1, OverworldStyle.EDITOR_SMALL, UiTheme.AMBER
	)
	on.draw_string(font, Vector2(16, 50), "y", HORIZONTAL_ALIGNMENT_LEFT, -1, OverworldStyle.EDITOR_SMALL, UiTheme.TEAL)


static func _arrow(on: Control, from: Vector2, to: Vector2, colour: Color) -> void:
	on.draw_line(from, to, colour, 2.5, true)
	var back := (from - to).normalized() * 8.0
	var side := Vector2(-back.y, back.x) * 0.6
	on.draw_colored_polygon(PackedVector2Array([to, to + back + side, to + back - side]), colour)


static func _picker(options: Array, chosen: int) -> OptionButton:
	var picker := OptionButton.new()
	for option: Variant in options:
		picker.add_item(String(option))
	picker.select(maxi(0, chosen))
	picker.focus_mode = Control.FOCUS_ALL
	return picker
