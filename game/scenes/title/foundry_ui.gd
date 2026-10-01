class_name FoundryUi
extends RefCounted
## A theme owned by the front door. Duplicating it keeps these refinements out of the run's UI.


static func text(english: String, japanese: String) -> String:
	return japanese if Game.profile.get("preferred_language", "en") == "ja" else english


static func theme() -> Theme:
	var result := UiTheme.shared().duplicate(true) as Theme
	result.default_font_size = 18
	for variation: String in ["Heading", "Subheading", "Narration"]:
		result.set_font("font", variation, UiTheme.ui_font(600 if variation != "Narration" else 400))
		result.set_font_size("font_size", variation, 24 if variation == "Heading" else 18)
		result.set_constant("shadow_outline_size", variation, 0)
	result.set_font_size("font_size", "Muted", 16)
	result.set_font_size("font_size", "Faint", 14)
	result.set_color("font_color", "Faint", UiTheme.MUTED)
	for variation: String in ["Button", "PrimaryButton", "DangerButton", "QuietButton"]:
		if variation == "QuietButton":
			result.set_type_variation(variation, "Button")
		var primary := variation == "PrimaryButton"
		var quiet := variation == "QuietButton"
		var accent := UiTheme.FAIL if variation == "DangerButton" else UiTheme.AMBER
		result.set_font_size("font_size", variation, 18)
		result.set_color("font_color", variation, accent if primary else UiTheme.TEXT)
		result.set_color("font_hover_color", variation, UiTheme.AMBER)
		result.set_color("font_pressed_color", variation, UiTheme.TEXT)
		result.set_color("font_focus_color", variation, UiTheme.TEXT)
		result.set_color("font_disabled_color", variation, UiTheme.FAINT)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var lit := state in ["hover", "pressed"]
			var fill := Color(UiTheme.AMBER, 0.12 if lit else (0.06 if primary else 0.0))
			var edge := accent if lit or primary else Color.TRANSPARENT
			if quiet and not lit:
				edge = Color.TRANSPARENT
			var style := UiTheme.box(fill, edge, 0, 6, Vector2(12, 6))
			style.border_width_bottom = 1 if lit or primary else 0
			result.set_stylebox(state, variation, style)
		result.set_stylebox("focus", variation, UiTheme.box(Color.TRANSPARENT, UiTheme.AMBER, 1, 6))
	for variation: String in ["Overlay", "Card", "Header", "Sunken"]:
		var margin := Vector2(20, 16) if variation == "Overlay" else Vector2(14, 10)
		result.set_stylebox(
			"panel", variation, UiTheme.box(Color(UiTheme.PANEL, 0.94), UiTheme.AMBER_DIM, 1, 10, margin)
		)
	result.set_font_size("font_size", "LineEdit", 18)
	result.set_font_size("font_size", "OptionButton", 18)
	return result


static func button(label: String, callback: Callable, primary := false, quiet := false) -> Button:
	var variation := "QuietButton" if quiet else ("PrimaryButton" if primary else "")
	var control := Ui.button(label, callback, variation)
	control.custom_minimum_size.y = 34
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return control


static func heading(eyebrow: String, title: String, back: Callable) -> Control:
	return Ui.hbox(
		[
			Ui.vbox([Ui.label(eyebrow, "Faint"), Ui.label(title, "Heading")], 8),
			Ui.spacer(),
			button(text("Back", "戻る"), back, false, true)
		],
		16
	)


static func rule() -> Control:
	var line := ColorRect.new()
	line.color = UiTheme.LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func action(title: String, subtitle: String, callback: Callable, primary := false) -> Button:
	var control := button(title, callback, primary)
	control.custom_minimum_size.y = 60
	control.tooltip_text = subtitle
	# LEARN: keep the button's text for accessibility; its child labels supply the two visual text sizes.
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, Color.TRANSPARENT)
	var title_label := Ui.label(title, "Subheading")
	title_label.add_theme_color_override("font_color", UiTheme.AMBER if primary else UiTheme.TEXT)
	var row := Ui.hbox(
		[Ui.expand(Ui.vbox([title_label, Ui.label(subtitle, "Muted", true)], 6)), Ui.label("›", "Heading")], 16
	)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 6)
	margin.add_child(row)
	control.add_child(margin)
	HoverInfo._ignore_mouse(margin)
	return control


static func place(parent: Control, child: Control, rect: Rect2) -> void:
	child.position = rect.position
	child.size = rect.size
	parent.add_child(child)


static func page(content: Control, minimum: Vector2) -> PanelContainer:
	var panel := Ui.panel(content, "Overlay")
	panel.custom_minimum_size = minimum
	return panel


static func icon_button(icon: String, label: String, callback: Callable, primary := false, quiet := false) -> Button:
	var control := button(label, callback, primary, quiet)
	control.icon = Art.texture("menus/icons/" + icon)
	control.add_theme_constant_override("h_separation", 12)
	return control


static func wordmark(texture: Texture2D) -> AtlasTexture:
	var scan := texture.get_image()
	var original := Vector2(scan.get_size())
	scan.resize(160, maxi(1, roundi(160.0 * original.y / original.x)), Image.INTERPOLATE_NEAREST)
	var low := Vector2i(scan.get_size())
	var high := Vector2i.ZERO
	# LEARN: tiny alpha remnants can enlarge get_used_rect. Measure visible pixels on a thumbnail instead.
	for y in scan.get_height():
		for x in scan.get_width():
			if scan.get_pixel(x, y).a > 0.25:
				low = Vector2i(mini(low.x, x), mini(low.y, y))
				high = Vector2i(maxi(high.x, x + 1), maxi(high.y, y + 1))
	var bounds := Rect2(Vector2(low), Vector2(high - low)).grow(1)
	var ratio := original / Vector2(scan.get_size())
	var crop := AtlasTexture.new()
	crop.atlas = texture
	crop.region = Rect2(bounds.position * ratio, bounds.size * ratio).intersection(Rect2(Vector2.ZERO, original))
	return crop


static func rebuild(root: Control, build: Callable) -> void:
	var index := -1
	if root.is_inside_tree():
		index = root.find_children("*", "Button", true, false).find(root.get_viewport().gui_get_focus_owner())
	Ui.clear(root)
	build.call()
	var buttons := root.find_children("*", "Button", true, false)
	if index >= 0 and not buttons.is_empty():
		focus.call_deferred(buttons[mini(index, buttons.size() - 1)] as Control)


static func focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		control.grab_focus()
