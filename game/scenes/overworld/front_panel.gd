class_name FrontPanel
extends RefCounted
## Lanternroot's front screens (the characters, a character's progress, the creator) in one look (ADR-0061): a dark warm
## panel with a thin amber edge, the chosen or focused thing in bright amber, a short fade and grow on opening, and
## the same four sounds everywhere (open, move, confirm, back).
##
##   var panel := FrontPanel.panel(Ui.vbox([...]))
##   FrontPanel.reveal(overlay, panel)          # fades the overlay in and grows the panel from 0.97
##   FrontPanel.button(Text.t("Play"), _play, "PrimaryButton")

const FILL := OverworldStyle.PANEL_FILL
const CHOSEN_FILL := Color(0.17, 0.12, 0.07, 0.98)
const RADIUS := OverworldStyle.PANEL_RADIUS
const PADDING := OverworldStyle.PANEL_PADDING
const OPEN_TIME := OverworldStyle.OPEN_TIME
const CLOSE_TIME := 0.12
## The shade behind an overlay: the screen under it stays in sight, quieter.
const SHADE := Color(0.04, 0.03, 0.05, 0.72)
## The tallest a button may be is not set; the shortest is, so a child's finger or a pad's cursor finds it easily.
const BUTTON_HEIGHT := 60.0


static func box(padding := PADDING) -> StyleBoxFlat:
	return UiTheme.box(FILL, UiTheme.AMBER_DIM, 2, RADIUS, padding)


## The box of the chosen or focused thing: the same shape, brighter and amber.
static func chosen_box(padding := PADDING) -> StyleBoxFlat:
	return UiTheme.box(CHOSEN_FILL, UiTheme.AMBER, 3, RADIUS, padding)


static func panel(child: Control, padding := PADDING) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(padding))
	node.add_child(child)
	return node


## The frame drawn over a focused button: thick and amber, so the one Enter presses is plain at a glance.
static func focus_frame(radius := 8) -> StyleBoxFlat:
	return UiTheme.box(Color(UiTheme.AMBER, 0.14), UiTheme.AMBER, 3, radius, Vector2(16, 8))


## A button in the front screens' look: tall enough to find, with the amber focus frame. `variation` is the game's
## (PrimaryButton, DangerButton).
static func button(text: String, on_pressed: Callable, variation := "") -> Button:
	var node := Ui.button(text, on_pressed, variation)
	node.custom_minimum_size.y = BUTTON_HEIGHT
	node.add_theme_stylebox_override("focus", focus_frame())
	return node


## A heading in the overworld's display face.
static func heading(text: String, font_size := OverworldStyle.HEADING) -> Label:
	var node := Ui.label(text, "Heading")
	node.add_theme_font_size_override("font_size", font_size)
	return node


## Small print in the lifted muted tone (hints, row names).
static func small(text: String, wrap := false) -> Label:
	var node := Ui.label(text, "Muted", wrap)
	node.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	node.add_theme_color_override("font_color", OverworldStyle.MUTED)
	return node


## A full-window layer that holds an overlay: a shade that takes the clicks, and its content centred.
static func overlay() -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.visible = false
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	return layer


## Centres `panel` in `layer` and keeps its pivot in its middle, so it grows from the centre.
static func centre(layer: Control, panel: Control) -> void:
	var middle := CenterContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(panel)
	layer.add_child(middle)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0)


## Opens `layer`: it fades in over 0.15 s while `panel` grows from 0.97 to full size, with the open sound.
static func reveal(layer: Control, panel: Control, sound := true) -> void:
	layer.visible = true
	if sound:
		Sound.play("sfx-open", 0.35)
	if Settings.reduced_motion:
		layer.modulate.a = 1.0
		panel.scale = Vector2.ONE
		return
	panel.pivot_offset = panel.size / 2.0
	layer.modulate.a = 0.0
	panel.scale = Vector2.ONE * OverworldStyle.OPEN_FROM
	var tween := layer.create_tween().set_parallel()
	tween.tween_property(layer, "modulate:a", 1.0, OPEN_TIME)
	tween.tween_property(panel, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Closes `layer` with a short fade, then hides it and calls `then` (if valid).
static func conceal(layer: Control, then := Callable()) -> void:
	if Settings.reduced_motion or not layer.is_inside_tree():
		layer.visible = false
		if then.is_valid():
			then.call()
		return
	var tween := layer.create_tween()
	tween.tween_property(layer, "modulate:a", 0.0, CLOSE_TIME)
	tween.tween_callback(
		func() -> void:
			layer.visible = false
			layer.modulate.a = 1.0
			if then.is_valid():
				then.call()
	)


## The sounds of the front screens: moving between choices, confirming, and going back.
static func moved() -> void:
	Sound.play("sfx-card-flick-1", 0.3)


static func confirmed() -> void:
	Sound.play("sfx-card-place-1", 0.4)


static func cancelled() -> void:
	Sound.play("sfx-whiff", 0.3)


## A line of key help at the foot of a screen: "Enter: play   Esc: back".
static func keys(text: String) -> Label:
	var node := small(text)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return node


## The pad button just pressed (JOY_BUTTON_A...), or -1 for any other event.
# LEARN: the game's ui_accept and ui_cancel are keys only (Enter, Space, Esc), so a pad's A and B are read here and
# turned into what Enter and Esc do; the D-pad is already in ui_up, ui_down, ui_left and ui_right.
static func pad_button(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.is_pressed() and not event.is_echo():
		return (event as InputEventJoypadButton).button_index
	return -1


## Whether `event` means confirm: Enter or Space, or a pad's A.
static func is_confirm(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_accept") or pad_button(event) == JOY_BUTTON_A


## Whether `event` means back: Esc, or a pad's B.
static func is_back(event: InputEvent) -> bool:
	return event.is_action_pressed("ui_cancel") or pad_button(event) == JOY_BUTTON_B


## Presses the focused button in `viewport`, as a pad's A does: Godot's buttons answer ui_accept, a key, by
## themselves. True when there was one to press.
static func press_focused(viewport: Viewport) -> bool:
	var focused := viewport.gui_get_focus_owner()
	if focused is BaseButton and not (focused as BaseButton).disabled:
		var button := focused as BaseButton
		if button.toggle_mode:
			button.button_pressed = not button.button_pressed
		button.pressed.emit()
		return true
	return false
