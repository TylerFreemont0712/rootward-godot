class_name StudioStyle
extends RefCounted
## The Studio's panels, in the game's look but compact (ADR-0066): opaque, square-edged bars around the town, small
## type, and buttons that never take the keyboard focus, so the arrow keys pan the camera instead of walking a menu.

## The panels' sizes, in the canvas's units (the 1920 x 1080 design size).
const TOP := 40
const BOTTOM := 28
const LEFT := 176
const RIGHT := 304
const SMALL := 14
## The shared lower shelf: the catalog shows two card rows, and Land uses the same workspace for its tools.
const PLACE := 300


## A panel's box: opaque, with a one-pixel edge, and `margin` inside it.
static func box(margin := Vector2(10, 6)) -> StyleBoxFlat:
	return UiTheme.box(UiTheme.PANEL, UiTheme.LINE, 1, 0, margin)


## A button for the bars: small, and out of the keyboard's way. `chosen` gives it the amber look of the one in use.
static func button(text: String, on_pressed: Callable, chosen := false, tip := "") -> Button:
	var node := Ui.button(text, on_pressed, "PrimaryButton" if chosen else "")
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size.y = 26
	node.tooltip_text = tip
	node.add_theme_font_size_override("font_size", SMALL)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return node


static func caption(text: String) -> Label:
	var node := Ui.label(text, "Muted")
	node.add_theme_font_size_override("font_size", 12)
	return node


static func line(text: String, colour := UiTheme.TEXT) -> Label:
	var node := Ui.label(text)
	node.add_theme_font_size_override("font_size", SMALL)
	node.add_theme_color_override("font_color", colour)
	return node


static func rule() -> HSeparator:
	return HSeparator.new()


## Gives a button the look of the one in use (or not).
static func choose(node: Button, chosen: bool) -> void:
	node.theme_type_variation = "PrimaryButton" if chosen else ""
