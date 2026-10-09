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
const LABEL := 26
const SMALL := 22
const HEADING := 40
## The colour of small print (hints, the help line, the row labels): lifted from the game's muted tone, which is too
## dim for a child reading on a dark panel (about 9:1 against the panel).
const MUTED := Color("#cdbb98")

const BODY_FILE := "res://ui/fonts/lora.ttf"
# LEARN: a SystemFont names families the OS may or may not have, and the list is tried in order. One line therefore
# works on Linux (Noto), Windows (Yu Gothic, Meiryo) and macOS (Hiragino) without shipping a Japanese font file.
const JAPANESE: Array[String] = ["Noto Sans CJK JP", "Yu Gothic", "Meiryo", "Hiragino Sans", "IPAGothic", "DejaVu Sans"]

static var _faces: Dictionary = {}
static var _theme: Theme


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
