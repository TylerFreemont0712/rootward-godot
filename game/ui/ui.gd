class_name Ui
extends RefCounted
## Small constructors for the controls every screen builds, so a screen reads as what it shows:
##
##   add_child(Ui.vbox([Ui.label("A quiet alcove", "Heading"), Ui.button("Rest", _rest, "PrimaryButton")]))


static func label(text: String, variation := "", wrap := false) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.custom_minimum_size.x = 40
	return node


static func button(text: String, on_pressed: Callable, variation := "") -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_ALL
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	return node


## A button that stays down when chosen, one of a group (difficulty, speed, on/off).
static func choice(text: String, chosen: bool, on_pressed: Callable) -> Button:
	var node := button(text, on_pressed, "PrimaryButton" if chosen else "")
	node.toggle_mode = true
	node.set_pressed_no_signal(chosen)
	return node


static func hbox(children: Array = [], separation := 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	_adopt(box, children)
	return box


static func vbox(children: Array = [], separation := 8) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	_adopt(box, children)
	return box


static func flow(children: Array = [], separation := 8) -> HFlowContainer:
	var box := HFlowContainer.new()
	box.add_theme_constant_override("h_separation", separation)
	box.add_theme_constant_override("v_separation", separation)
	_adopt(box, children)
	return box


static func panel(child: Control, variation := "") -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	node.add_child(child)
	return node


static func scroll(child: Control, horizontal := false) -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_child(child)
	return node


## A picture from game/assets by id at a fixed size, pixel-crisp; `fallback` (a glyph or a word) when there is none.
## `content` centred in the space it is given, and scrollable when it is taller than that space, so nothing on a
## screen can end up out of reach below the window's edge.
static func centered_scroll(content: Control) -> ScrollContainer:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(content)
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.add_child(center)
	return node


static func picture(id: String, size: Vector2, fallback := "") -> Control:
	var texture := Art.texture(id)
	if texture == null:
		var stand_in := label(fallback, "Faint")
		stand_in.custom_minimum_size = size
		stand_in.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stand_in.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return stand_in
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func spacer(width := 0.0, height := 0.0) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(width, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width == 0.0 and height == 0.0:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func expand(node: Control, vertical := false) -> Control:
	if vertical:
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func tint(node: Control, colour: Color, property := "font_color") -> Control:
	node.add_theme_color_override(property, colour)
	return node


static func sized(node: Control, font_size: int) -> Control:
	node.add_theme_font_size_override("font_size", font_size)
	return node


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func _adopt(parent: Control, children: Array) -> void:
	for child: Variant in children:
		if child is Control:
			parent.add_child(child as Control)
