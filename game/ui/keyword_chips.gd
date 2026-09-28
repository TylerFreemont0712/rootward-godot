class_name KeywordChips
extends Control
## A program card's keywords on its face (ADR-0018), as code: `once`, `const`... each a small pill in its own colour
## along the bottom of the picture's window. What each one means is in the card's details.

const COLOURS := {
	"once": "#ffb05c",
	"volatile": "#ff6b7a",
	"const": "#5cd6c0",
	"__init__": "#9be37a",
	"lambda": "#c79cff",
}

var keywords: Array = []


static func create(words: Array) -> KeywordChips:
	var chips := KeywordChips.new()
	chips.keywords = words.duplicate()
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chips


static func colour_of(keyword: String) -> Color:
	return Color(COLOURS.get(keyword, "#c9c9d6"))


func _draw() -> void:
	if keywords.is_empty():
		return
	var font := UiTheme.ui_font(600)
	var font_size := maxi(9, int(size.y * 0.66))
	var gap := size.y * 0.25
	var widths: Array[float] = []
	var total := -gap
	for word: String in keywords:
		var width := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + size.y * 0.7
		widths.append(width)
		total += width + gap
	var x := (size.x - total) * 0.5
	for index in keywords.size():
		var word: String = keywords[index]
		var tint := colour_of(word)
		var pill := Rect2(x, 0, widths[index], size.y)
		draw_style_box(UiTheme.box(Color(0.04, 0.03, 0.06, 0.9), Color(tint, 0.85), 1, int(size.y * 0.3)), pill)
		var baseline := size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2(x, baseline), word, HORIZONTAL_ALIGNMENT_CENTER, widths[index], font_size, tint)
		x += widths[index] + gap
