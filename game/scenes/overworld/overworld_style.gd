class_name OverworldStyle
extends RefCounted
## The overworld's text look (ADR-0061): its faces and sizes in one place, so the dialogue, the boots editor, the
## creator and Hotaru's bubble read alike. The body face is Lora, a plain serif with open letters and a generous
## x-height. Its Japanese (the kana the youngest readers meet first) falls through to a Gothic, whose plain strokes
## suit a small screen and a young reader. The heading keeps the game's display face, and code keeps its monospaced one.
##
## A screen takes the whole look from `theme()`, so its labels, buttons and boxes need no font of their own:
##   control.theme = OverworldStyle.theme()

const BODY := 34
const LABEL := 24
const SMALL := 22
## Small print a child still reads (the place, the save note, the status line): 20 is the floor. Code keeps 26.
const HINT := 20
const CODE := 26
const HEADING := 34
## The code editors' sizes (the boots' and the lessons'): compact, so more lines of code fit. Still comfortable to read.
const EDITOR_TITLE := 26
const EDITOR_TEXT := 19
const EDITOR_SMALL := 17
const EDITOR_CODE := 20
## The padding of a button in the code editors (the theme's is 15 x 8).
const EDITOR_BUTTON_PADDING := Vector2(12, 6)
## The colour of small print (hints, the help line, the row labels): lifted from the game's muted tone, which is too
## dim for a child reading on a dark panel (about 9:1 against the panel).
const MUTED := Color("#cdbb98")

## The one panel look of Lanternroot's screens (panel_box): a dark warm fill, a 2 px amber edge and round corners.
const PANEL_FILL := Color(0.1, 0.075, 0.06, 0.96)
const PANEL_RADIUS := 12
const PANEL_PADDING := Vector2(22, 16)
## How long a panel takes to open or close, and how small it starts as it grows open (pop_in, fade_out).
const OPEN_TIME := 0.15
const OPEN_FROM := 0.97
## The fill of a well sunk into a panel (well_box).
const WELL_FILL := Color(0.045, 0.033, 0.026, 0.8)

const BODY_FILE := "res://ui/fonts/lora.ttf"
# LEARN: a SystemFont names families the OS may or may not have, and the list is tried in order. One line therefore
# works on Linux (Noto), Windows (Yu Gothic, Meiryo) and macOS (Hiragino) without shipping a Japanese font file.
const JAPANESE: Array[String] = ["Noto Sans CJK JP", "Yu Gothic", "Meiryo", "Hiragino Sans", "IPAGothic", "DejaVu Sans"]

static var _faces: Dictionary = {}
static var _theme: Theme
static var _menu_theme: Theme
static var _editor_theme: Theme


## Lora at `weight` (400 for text, 600 for names), with the Japanese fallback. The game's own face if Lora is missing.
static func body_font(weight := 400) -> Font:
	if not _faces.has(weight):
		_faces[weight] = _make_body(weight)
	return _faces[weight]


static func heading_font() -> Font:
	return UiTheme.crt_font()


## The overworld's theme: the game's look with the body face and the sizes above. Built once and shared.
static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## The theme for a menu the player walks with keys or a pad: theme() with a bold amber ring on whatever has the focus,
## so the focus is always plain to see. Built once and shared.
static func menu_theme() -> Theme:
	if _menu_theme == null:
		_menu_theme = theme().duplicate(true) as Theme
		# OptionButton, CheckBox and the button variations (PrimaryButton) fall back to Button's ring in this theme.
		_menu_theme.set_stylebox("focus", "Button", focus_box())
		for type: String in ["TextEdit", "CodeEdit", "LineEdit"]:
			_menu_theme.set_stylebox("focus", type, focus_box(10))
	return _menu_theme


## The theme of the two code editors: menu_theme() with the smaller EDITOR_ sizes and tighter buttons. Built once.
static func editor_theme() -> Theme:
	if _editor_theme == null:
		_editor_theme = menu_theme().duplicate(true) as Theme
		_editor_theme.default_font_size = EDITOR_TEXT
		_editor_theme.set_font_size("font_size", "Heading", EDITOR_TITLE)
		_editor_theme.set_font_size("font_size", "Subheading", EDITOR_TEXT)
		for variation: String in ["Narration", "Muted", "Faint", "Code"]:
			_editor_theme.set_font_size("font_size", variation, EDITOR_SMALL)
		_editor_theme.set_font_size("normal_font_size", "RichTextLabel", EDITOR_TEXT)
		for type: String in ["Button", "OptionButton", "LineEdit"]:
			_editor_theme.set_font_size("font_size", type, EDITOR_TEXT)
		for type: String in ["Button", "PrimaryButton", "OptionButton"]:
			for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				if _editor_theme.has_stylebox(state, type):
					var box := (_editor_theme.get_stylebox(state, type) as StyleBoxFlat).duplicate() as StyleBoxFlat
					box.content_margin_left = EDITOR_BUTTON_PADDING.x
					box.content_margin_right = EDITOR_BUTTON_PADDING.x
					box.content_margin_top = EDITOR_BUTTON_PADDING.y
					box.content_margin_bottom = EDITOR_BUTTON_PADDING.y
					_editor_theme.set_stylebox(state, type, box)
	return _editor_theme


## The panel every Lanternroot screen sits in.
static func panel_box() -> StyleBoxFlat:
	return UiTheme.box(PANEL_FILL, UiTheme.AMBER_DIM, 2, PANEL_RADIUS, PANEL_PADDING)


## A sunken well inside a panel (the boots' list of blocks, the pair of buttons in a switch): darker than the panel,
## with a thin edge, so what sits in it reads as one group.
static func well_box(padding := Vector2(14, 14), radius := 12) -> StyleBoxFlat:
	return UiTheme.box(WELL_FILL, UiTheme.LINE, 1, radius, padding)


## A ring drawn just outside a control that has the focus: amber, 3 px, no fill.
static func focus_box(radius := 9) -> StyleBoxFlat:
	var ring := UiTheme.box(Color.TRANSPARENT, UiTheme.AMBER, 3, radius, Vector2.ZERO)
	ring.draw_center = false
	ring.set_expand_margin_all(3)
	return ring


## Opens a panel the Lanternroot way: `fading` (the panel and its shade) fades in while `growing` (the panel) grows from
## a touch smaller to its size, about its middle.
static func pop_in(fading: CanvasItem, growing: Control) -> Tween:
	fading.modulate.a = 0.0
	growing.pivot_offset_ratio = Vector2(0.5, 0.5)
	growing.scale = Vector2.ONE * OPEN_FROM
	var tween := fading.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(fading, "modulate:a", 1.0, OPEN_TIME)
	tween.tween_property(growing, "scale", Vector2.ONE, OPEN_TIME)
	return tween


## Closes a panel the Lanternroot way: `fading` fades out, then `done` is called (to hide it or put it away).
static func fade_out(fading: CanvasItem, done: Callable) -> Tween:
	var tween := fading.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fading, "modulate:a", 0.0, OPEN_TIME)
	tween.tween_callback(done)
	return tween


static func _make_body(weight: int) -> Font:
	if not ResourceLoader.exists(BODY_FILE):
		return UiTheme.ui_font(weight)
	# LEARN: the Lora file is one shared resource, so the fallbacks go on the FontVariation that wraps it, not on the
	# file (UiFonts sets a different fallback on the same file for its own face).
	var japanese := SystemFont.new()
	japanese.font_names = PackedStringArray(JAPANESE)
	japanese.font_weight = weight
	var face := FontVariation.new()
	face.base_font = load(BODY_FILE) as FontFile
	face.variation_opentype = {"wght": float(weight)}
	face.fallbacks = [japanese]
	return face


static func _build() -> Theme:
	var result := UiTheme.shared().duplicate(true) as Theme
	result.default_font = body_font()
	result.default_font_size = LABEL
	result.set_font("font", "Heading", heading_font())
	result.set_font_size("font_size", "Heading", HEADING)
	result.set_font("font", "Subheading", body_font(600))
	result.set_font_size("font_size", "Subheading", BODY)
	result.set_font("font", "Narration", body_font())
	result.set_font_size("font_size", "Narration", SMALL)
	result.set_font_size("font_size", "Muted", SMALL)
	result.set_color("font_color", "Muted", MUTED)
	result.set_font_size("font_size", "Faint", SMALL)
	result.set_font_size("font_size", "Code", SMALL)
	result.set_font("normal_font", "RichTextLabel", body_font())
	result.set_font("bold_font", "RichTextLabel", body_font(600))
	result.set_font_size("normal_font_size", "RichTextLabel", BODY)
	result.set_font_size("font_size", "Button", LABEL)
	result.set_font_size("font_size", "OptionButton", LABEL)
	result.set_font_size("font_size", "LineEdit", BODY)
	return result
