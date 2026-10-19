class_name LessonBlocks
extends RefCounted
## The Builder's blocks for lessons 2 and 3 (ADR-0061), laid out like the code they make. Each block is a big toggle
## (Enter, Space, a click or the pad's A ticks it), so a child can build the function with the arrows alone:
##
##   ┃ save(player) keeps:            ┃ light_all(lamps):
##   ┃   [✓] x       across           ┃   [ ] Light the first lamp
##   ┃   [ ] map     which place      ┃   [✓] For each lamp in the lane:
##   ┃   ...                          ┃         [✓] Set its lit to True
##
## A toggle carries its block's id (meta "block"), so the editor can tell which one has the focus.

const FILL := Color("#2a2119")
const FILL_ON := Color("#3d2d19")
const EDGE := Color("#5a4630")
const CODE_COLOUR := Color("#f3e6c8")
## How far a block inside a loop is set in, like the body of a `for`.
const INDENT := 40.0
const HEIGHT := 38.0


## The memory lesson's blocks: one tick per field of the player. `on_toggle(field, on)` hears a tick.
static func memory(chosen: Array, language: String, on_toggle: Callable) -> Control:
	var rows: Array = [_heading("%s(player)" % Lessons.entry(Lessons.MEMORY, language), Text.t("keeps:"))]
	for field in Lessons.FIELDS:
		var block := toggle(field, LessonWords.field(field), field in chosen, true)
		block.toggled.connect(func(on: bool) -> void: on_toggle.call(field, on))
		rows.append(_indented(block, 0.0))
	return card(rows)


## The lamps lesson's blocks: "light the first lamp", and a loop holding "set its lit to True". The block inside the
## loop can only be ticked while the loop is there. `on_toggle(block, on)` hears a tick.
static func lamps(blocks: Dictionary, language: String, on_toggle: Callable) -> Control:
	var rows: Array = [_heading("%s(lamps):" % Lessons.entry(Lessons.LAMPS, language), "")]
	var made := {}
	for id in Lessons.LAMP_BLOCKS:
		var block := toggle("", LessonWords.lamp_block(id, language), bool(blocks.get(id, false)), false)
		block.set_meta("block", id)
		block.toggled.connect(func(on: bool) -> void: on_toggle.call(id, on))
		made[id] = block
		rows.append(_indented(block, INDENT if id == "inside" else 0.0))
	set_enabled(made.inside, bool(blocks.get("loop", false)))
	return card(rows)


## The toggles of a set of blocks, by block id.
static func toggles(blocks: Control) -> Dictionary:
	var found := {}
	for node in blocks.find_children("*", "Button", true, false):
		if node.has_meta("block"):
			found[String(node.get_meta("block"))] = node
	return found


## A block that cannot be used yet is faded and skipped by the focus.
static func set_enabled(block: Button, on: bool) -> void:
	block.disabled = not on
	block.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	block.modulate.a = 1.0 if on else 0.45


## A toggle block: a tick box, then `code` in the code face (a field's name) and `words` beside it.
static func toggle(code: String, words: String, on: bool, code_first: bool) -> Button:
	var block := Button.new()
	block.toggle_mode = true
	block.set_pressed_no_signal(on)
	block.focus_mode = Control.FOCUS_ALL
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	block.set_meta("block", code)
	var pad := Vector2(10, 4)
	block.add_theme_stylebox_override("normal", _style(FILL, EDGE, pad))
	block.add_theme_stylebox_override("hover", _style(FILL.lightened(0.06), UiTheme.AMBER_DIM, pad))
	block.add_theme_stylebox_override("pressed", _style(FILL_ON, UiTheme.AMBER, pad))
	block.add_theme_stylebox_override("hover_pressed", _style(FILL_ON.lightened(0.05), UiTheme.AMBER, pad))
	block.add_theme_stylebox_override("disabled", _style(FILL, EDGE, pad))
	var tick := _tick(block)
	var parts: Array = [tick]
	if code_first:
		var shown := Ui.label(code)
		shown.add_theme_font_override("font", UiTheme.code_font(600))
		shown.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
		shown.add_theme_color_override("font_color", CODE_COLOUR)
		shown.custom_minimum_size.x = 96
		var said := Ui.label(words, "Muted")
		parts.append_array([shown, said])
	else:
		var said := Ui.label(words)
		said.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
		parts.append(said)
	var inside := Ui.hbox(parts, 12)
	_hold(block, inside)
	block.toggled.connect(func(_on: bool) -> void: tick.queue_redraw())
	return block


## The card the blocks sit in: a block with a thick left edge, like the function it is.
static func card(rows: Array) -> PanelContainer:
	var holder := PanelContainer.new()
	var box := UiTheme.box(Color(0.07, 0.05, 0.04, 0.6), EDGE, 1, 10, Vector2(12, 8))
	box.border_width_left = 6
	box.border_color = UiTheme.AMBER_DIM
	holder.add_theme_stylebox_override("panel", box)
	holder.add_child(Ui.vbox(rows, 6))
	return holder


## The first block that can take the focus.
static func first(blocks: Control) -> Control:
	for node in blocks.find_children("*", "Button", true, false):
		if (node as Button).focus_mode != Control.FOCUS_NONE:
			return node as Control
	return null


static func _heading(code: String, words: String) -> Control:
	var shown := Ui.label(code)
	shown.add_theme_font_override("font", UiTheme.code_font(600))
	shown.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	shown.add_theme_color_override("font_color", UiTheme.AMBER)
	var said := Ui.label(words, "Muted")
	return Ui.hbox([shown, said], 10)


static func _indented(block: Control, by: float) -> Control:
	var row := Ui.hbox([Ui.spacer(16.0 + by, 1.0), block], 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


## Puts `inside` in the button and keeps the button as big as what it holds. A Button does not lay out its children,
## so `inside` is anchored to fill it and the button's least size follows `inside`'s.
static func _hold(block: Button, inside: Control) -> void:
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in inside.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(inside)
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 10
	inside.offset_right = -10
	var fit := func() -> void: block.custom_minimum_size = Vector2(inside.get_combined_minimum_size().x + 20.0, HEIGHT)
	inside.minimum_size_changed.connect(fit)
	fit.call()


static func _style(fill: Color, edge: Color, pad: Vector2) -> StyleBoxFlat:
	return UiTheme.box(fill, edge, 2, 8, pad)


## A tick box drawn for `block`: an empty rounded square, or an amber one with a dark tick when the block is on.
static func _tick(block: Button) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.draw.connect(
		func() -> void:
			var area := Rect2(Vector2(1, 1), box.size - Vector2(2, 2))
			if block.button_pressed:
				UiTheme.box(UiTheme.AMBER, UiTheme.AMBER, 2, 5).draw(box.get_canvas_item(), area)
				var at := func(x: float, y: float) -> Vector2: return area.position + area.size * Vector2(x, y)
				var tick := PackedVector2Array([at.call(0.22, 0.52), at.call(0.42, 0.72), at.call(0.78, 0.3)])
				box.draw_polyline(tick, Color("#2a1a0c"), 3.0, true)
			else:
				UiTheme.box(Color(0, 0, 0, 0.3), UiTheme.AMBER_DIM, 2, 5).draw(box.get_canvas_item(), area)
	)
	return box
