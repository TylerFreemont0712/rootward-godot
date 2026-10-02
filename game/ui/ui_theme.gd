class_name UiTheme
extends RefCounted
## Rootward's look: the amber phosphor CRT of the old game (its mockups and design tokens), as one Godot Theme built in
## code. Every screen's root sets `theme = UiTheme.shared()`, and everything under it inherits. Colours are named here
## and nowhere else; a screen asks for a colour by its role (UiTheme.AMBER), never by its hex.
##
## Type variations (set a Control's `theme_type_variation`):
##   Labels: Title, Heading, Subheading, Narration, Big, Muted, Faint, Code
##   Buttons: PrimaryButton, DangerButton, ChipButton
##   PanelContainers: Card, Sunken, Overlay, Header

const GROUND := Color("#120e0a")
const PANEL := Color("#1a1410")
const PANEL_2 := Color("#211a13")
const PANEL_3 := Color("#2a2119")
const LINE := Color("#3c2f21")
const LINE_SOFT := Color("#2b2219")
const AMBER := Color("#f2a541")
const AMBER_DIM := Color("#a8712a")
const AMBER_GLOW := Color(0.95, 0.65, 0.25, 0.3)
const TEXT := Color("#e9dcc0")
const MUTED := Color("#a58f6e")
const FAINT := Color("#6f5e46")
const TEAL := Color("#5cc8b8")
const PASS := Color("#8bc96a")
const FAIL := Color("#e2584f")
const WARN := Color("#e9c46a")
const INTEGRITY := Color("#d9534f")
## Shards and mana: the arcane violet of the spellbook.
const SHARD := Color("#b48cff")
const SHARD_DIM := Color("#6b4fa8")
const ELEMENTS := {
	"none": Color("#d9d0bd"),
	"fire": Color("#ff9147"),
	"frost": Color("#82d8ff"),
	"spark": Color("#ffe066"),
}
const RARITIES := {
	"common": Color("#a58f6e"),
	"uncommon": Color("#5cc8b8"),
	"rare": Color("#f2a541"),
	"epic": Color("#c084fc"),
	"legendary": Color("#ff7a3d"),
	"boss": Color("#e2584f"),
}
## The map's rooms, a hue each far apart on the wheel, so a kind reads at a glance (MapMarkers adds a shape each too).
const ROOMS := {
	"fight": Color("#d8c6a2"),
	"elite": Color("#ec5a4f"),
	"boss": Color("#ff8a3d"),
	"rest": Color("#7fd06f"),
	"forge": Color("#b48cff"),
	"treasure": Color("#f5cb4a"),
}

## Sizes are in the design canvas, 1920x1080 (project.godot); the window scales them all together.
const BUTTON_PADDING := Vector2(15, 8)
const FONT_DIR := "res://ui/fonts/"
## Neither face has kana or kanji (nor every symbol), so text falls through to what the system has, glyph by glyph.
const SYSTEM_FALLBACKS: Array[String] = ["DejaVu Sans Mono", "DejaVu Sans", "Noto Sans CJK JP", "Noto Sans Mono"]

static var _theme: Theme
static var _fonts: Dictionary = {}
static var _live_themes: Array[Dictionary] = []


static func shared() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func element(name: String) -> Color:
	return ELEMENTS.get(name, ELEMENTS.none)


static func rarity(name: String) -> Color:
	return RARITIES.get(name, MUTED)


static func room(kind: String) -> Color:
	return ROOMS.get(kind, ROOMS.fight)


## The selected UI face, retaining the original lettering by default.
static func ui_font(weight := 400) -> Font:
	var chosen := UiFonts.face(Settings.font_style, weight)
	return chosen if chosen != null else code_font(weight)


## The display face for titles and big numbers; VT323 remains the original default.
static func crt_font() -> Font:
	return _font("vt323", 400) if Settings.font_style == "default" else ui_font(600)


## Source always retains a monospaced face, regardless of decorative UI lettering.
static func code_font(weight := 400) -> Font:
	return _font("ibm-plex-mono", weight)


static func track(theme: Theme, foundry := false) -> void:
	_live_themes = _live_themes.filter(func(item: Dictionary) -> bool: return item.ref.get_ref() != null)
	_live_themes.append({"ref": weakref(theme), "foundry": foundry})
	_apply_fonts(theme, foundry)


static func refresh_fonts() -> void:
	if _theme != null:
		_apply_fonts(_theme, false)
	for item: Dictionary in _live_themes:
		var theme := item.ref.get_ref() as Theme
		if theme != null:
			_apply_fonts(theme, item.foundry)


static func _apply_fonts(theme: Theme, foundry: bool) -> void:
	# LEARN: mutate live Theme resources instead of rebuilding scenes and losing menu/run state.
	theme.default_font = ui_font()
	for variation: String in ["Title", "Heading", "Subheading", "Narration", "Big"]:
		var font := crt_font()
		if foundry and variation in ["Heading", "Subheading", "Narration"]:
			font = ui_font(400 if variation == "Narration" else 600)
		theme.set_font("font", variation, font)
	theme.set_font("font", "Code", code_font())
	for type: String in ["CodeEdit", "TextEdit"]:
		theme.set_font("font", type, code_font())
	theme.set_font("normal_font", "RichTextLabel", ui_font())
	theme.set_font("bold_font", "RichTextLabel", ui_font(600))
	theme.set_font("mono_font", "RichTextLabel", code_font())
	theme.set_font("font", "TooltipLabel", ui_font())


static func _font(family: String, weight: int) -> Font:
	var key := "%s-%d" % [family, weight]
	if _fonts.has(key):
		return _fonts[key]
	var main := load(FONT_DIR + "%s-latin-%d-normal.woff2" % [family, weight]) as FontFile
	var extended := load(FONT_DIR + "%s-latin-ext-%d-normal.woff2" % [family, weight]) as FontFile
	var system := SystemFont.new()
	system.font_names = PackedStringArray(SYSTEM_FALLBACKS)
	var font: Font = system
	if main != null:
		var fallbacks: Array[Font] = []
		if extended != null:
			fallbacks.append(extended)
		fallbacks.append(system)
		main.fallbacks = fallbacks
		font = main
	_fonts[key] = font
	return font


static func box(
	background: Color, border: Color = Color.TRANSPARENT, width := 1, radius := 3, margin := Vector2(12, 8)
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin.x
	style.content_margin_right = margin.x
	style.content_margin_top = margin.y
	style.content_margin_bottom = margin.y
	return style


static func _build() -> Theme:
	var theme := Theme.new()
	theme.default_font = ui_font()
	theme.default_font_size = 16
	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_bars(theme)
	_scrolling(theme)
	var rich := "RichTextLabel"
	theme.set_color("default_color", rich, TEXT)
	theme.set_font("normal_font", rich, ui_font())
	theme.set_font("bold_font", rich, ui_font(600))
	theme.set_font("mono_font", rich, code_font())
	theme.set_stylebox("panel", "TooltipPanel", box(PANEL_3, AMBER_DIM, 1, 3, Vector2(10, 8)))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font("font", "TooltipLabel", ui_font())
	theme.set_font_size("font_size", "TooltipLabel", 14)
	_apply_fonts(theme, false)
	return theme


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	var crt: Array = [
		["Title", 76, AMBER],
		["Heading", 35, AMBER],
		["Subheading", 26, AMBER],
		["Narration", 20, MUTED],
		["Big", 34, AMBER],
	]
	for spec: Array in crt:
		var variation: String = spec[0]
		theme.set_type_variation(variation, "Label")
		theme.set_font("font", variation, crt_font())
		theme.set_font_size("font_size", variation, spec[1])
		theme.set_color("font_color", variation, spec[2])
	for variation: String in ["Title", "Heading", "Big"]:
		theme.set_color("font_shadow_color", variation, AMBER_GLOW)
		theme.set_constant("shadow_outline_size", variation, 6)
	theme.set_type_variation("Muted", "Label")
	theme.set_color("font_color", "Muted", MUTED)
	theme.set_font_size("font_size", "Muted", 16)
	theme.set_type_variation("Faint", "Label")
	theme.set_color("font_color", "Faint", FAINT)
	theme.set_font_size("font_size", "Faint", 14)
	theme.set_type_variation("Code", "Label")
	theme.set_font_size("font_size", "Code", 14)


static func _buttons(theme: Theme) -> void:
	var button := "Button"
	var pad := BUTTON_PADDING
	theme.set_stylebox("normal", button, box(PANEL_2, LINE, 1, 7, pad))
	theme.set_stylebox("hover", button, box(PANEL_3, AMBER_DIM, 1, 7, pad))
	theme.set_stylebox("pressed", button, box(PANEL_3, AMBER, 1, 7, pad))
	theme.set_stylebox("hover_pressed", button, box(PANEL_3, AMBER, 1, 7, pad))
	theme.set_stylebox("disabled", button, box(PANEL, LINE_SOFT, 1, 7, pad))
	theme.set_stylebox("focus", button, box(Color.TRANSPARENT, TEAL, 1, 7, pad))
	theme.set_font_size("font_size", button, 16)
	theme.set_color("font_color", button, TEXT)
	theme.set_color("font_hover_color", button, AMBER)
	theme.set_color("font_pressed_color", button, AMBER)
	theme.set_color("font_hover_pressed_color", button, AMBER)
	theme.set_color("font_focus_color", button, TEXT)
	theme.set_color("font_disabled_color", button, FAINT)

	theme.set_type_variation("PrimaryButton", button)
	theme.set_stylebox("normal", "PrimaryButton", box(Color("#2a1f12"), AMBER_DIM, 1, 7, pad))
	theme.set_stylebox("hover", "PrimaryButton", box(Color("#3a2a15"), AMBER, 1, 7, pad))
	theme.set_color("font_color", "PrimaryButton", AMBER)
	theme.set_color("font_focus_color", "PrimaryButton", AMBER)

	theme.set_type_variation("DangerButton", button)
	theme.set_stylebox("normal", "DangerButton", box(PANEL_2, FAIL.darkened(0.4), 1, 7, pad))
	theme.set_stylebox("hover", "DangerButton", box(PANEL_3, FAIL, 1, 7, pad))
	theme.set_color("font_color", "DangerButton", FAIL)
	theme.set_color("font_hover_color", "DangerButton", FAIL.lightened(0.2))

	theme.set_type_variation("ChipButton", button)
	theme.set_stylebox("normal", "ChipButton", box(PANEL_3, LINE, 1, 3, Vector2(8, 4)))
	theme.set_stylebox("hover", "ChipButton", box(Color("#35291d"), SHARD_DIM, 1, 3, Vector2(8, 4)))
	theme.set_stylebox("pressed", "ChipButton", box(Color("#2d2240"), SHARD, 1, 3, Vector2(8, 4)))
	theme.set_stylebox("hover_pressed", "ChipButton", box(Color("#2d2240"), SHARD, 1, 3, Vector2(8, 4)))
	theme.set_font_size("font_size", "ChipButton", 14)


static func _panels(theme: Theme) -> void:
	var panel := box(Color(PANEL, 0.94), LINE, 1, 8, Vector2(14, 10))
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	var variations := {
		"Card": box(PANEL_2, LINE, 1, 8, Vector2(14, 11)),
		"Sunken": box(Color("#0c0907"), LINE_SOFT, 1, 8, Vector2(12, 10)),
		"Overlay": _shadowed(box(Color(PANEL, 0.98), AMBER_DIM, 1, 10, Vector2(22, 18))),
		"Header": box(Color(PANEL, 0.94), LINE, 1, 8, Vector2(16, 10)),
		"Chip": box(PANEL_3, LINE, 1, 3, Vector2(8, 4)),
	}
	for variation: String in variations:
		theme.set_type_variation(variation, "PanelContainer")
		theme.set_stylebox("panel", variation, variations[variation])


static func _shadowed(style: StyleBoxFlat) -> StyleBoxFlat:
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 18
	return style


static func _bars(theme: Theme) -> void:
	var bar := "ProgressBar"
	theme.set_stylebox("background", bar, box(Color("#0c0907"), LINE, 1, 2, Vector2.ZERO))
	theme.set_stylebox("fill", bar, box(INTEGRITY, Color.TRANSPARENT, 0, 2, Vector2.ZERO))
	theme.set_color("font_color", bar, TEXT)
	theme.set_font_size("font_size", bar, 12)
	var slider := "HSlider"
	theme.set_stylebox("slider", slider, box(Color("#0c0907"), LINE, 1, 2, Vector2(0, 3)))
	theme.set_stylebox("grabber_area", slider, box(AMBER_DIM, Color.TRANSPARENT, 0, 2, Vector2(0, 3)))
	theme.set_stylebox("grabber_area_highlight", slider, box(AMBER, Color.TRANSPARENT, 0, 2, Vector2(0, 3)))


static func _scrolling(theme: Theme) -> void:
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, box(Color(0, 0, 0, 0.2), Color.TRANSPARENT, 0, 3, Vector2(4, 4)))
		theme.set_stylebox("grabber", bar, box(LINE, Color.TRANSPARENT, 0, 3, Vector2(4, 4)))
		theme.set_stylebox("grabber_highlight", bar, box(AMBER_DIM, Color.TRANSPARENT, 0, 3, Vector2(4, 4)))
		theme.set_stylebox("grabber_pressed", bar, box(AMBER, Color.TRANSPARENT, 0, 3, Vector2(4, 4)))
