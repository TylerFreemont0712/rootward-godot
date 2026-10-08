class_name ForgeRune
extends Control
## A rune circle written over a card to melt it (ForgeAnimation): two rings drawn like pen strokes, a ruled star that
## turns inside them, the code symbols taking their places on the ring one by one, and a dark veil over the card
## beneath. `progress` runs from 0 (nothing drawn) to 1 (the card covered).

## The symbols are the ones the magic circles use, so a melted card reads as code being struck out.
const RUNES: Array[String] = ["λ", "∑", "{", "}", ";", "(", ")", "⊕", "⊗", "[", "]", "≤", "≥", "&"]
const RUNE_SIZE := 15

var colour := UiTheme.FAIL
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	var radius := minf(size.x, size.y) * 0.44
	draw_circle(centre, radius * 1.05, Color(0.04, 0.02, 0.03, 0.6 * smoothstep(0.1, 0.8, progress)))
	# The outer ring is written first, then the inner one; each goes round as it is drawn.
	draw_arc(centre, radius, -PI / 2.0, -PI / 2.0 + TAU * minf(1.0, progress * 1.6), 96, colour, 3.0, true)
	var inner := clampf((progress - 0.2) / 0.6, 0.0, 1.0)
	draw_arc(centre, radius * 0.8, -PI / 2.0, -PI / 2.0 - TAU * inner, 96, Color(colour, 0.85), 2.0, true)
	# A ruled star (two triangles) turns in the middle once the rings are drawn.
	var star := clampf((progress - 0.45) / 0.3, 0.0, 1.0)
	if star > 0.0:
		var turn := progress * PI * 0.8
		for offset: float in [0.0, PI / 3.0]:
			var points := PackedVector2Array()
			for corner in 4:
				var angle := turn + offset + corner * TAU / 3.0
				points.append(centre + Vector2(cos(angle), sin(angle)) * radius * 0.66)
			draw_polyline(points, Color(colour, star), 2.0, true)
	var font := UiTheme.code_font()
	for index in RUNES.size():
		var reveal := clampf((progress - 0.3 - index * 0.025) / 0.12, 0.0, 1.0)
		if reveal <= 0.0:
			continue
		var angle := -PI / 2.0 + TAU * index / RUNES.size()
		var glyph: String = RUNES[index]
		var width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, RUNE_SIZE).x
		var at := centre + Vector2(cos(angle), sin(angle)) * radius * 0.9
		draw_string(
			font,
			at + Vector2(-width * 0.5, RUNE_SIZE * 0.35),
			glyph,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			RUNE_SIZE,
			Color(colour, reveal)
		)
