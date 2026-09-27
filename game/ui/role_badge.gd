class_name RoleBadge
extends Control
## A program card's role on its face: a glyph and a word in the role's colour, on a dark plate in the frame's lower
## panel. It says what a card is for before its code is read: it makes bolts (source), changes them (shape), puts them
## in order (order), aims them at foes (strike), or turns them into block (guard). A program is usually written in
## that order, so the badges of a good program read like a sentence.

const ROLES := {
	"source": {"word": "SOURCE", "colour": "#8fdc6b", "hint": "makes bolts"},
	"shape": {"word": "SHAPE", "colour": "#c79cff", "hint": "changes bolts"},
	"order": {"word": "ORDER", "colour": "#ffd166", "hint": "puts the volley in order"},
	"strike": {"word": "STRIKE", "colour": "#ff7a59", "hint": "aims bolts at foes"},
	"guard": {"word": "GUARD", "colour": "#7fb8ff", "hint": "turns bolts into block"},
}

var role := ""
## Below this height the word does not fit, and the glyph stands alone.
var word_from := 18.0


static func create(role_id: String) -> RoleBadge:
	var badge := RoleBadge.new()
	badge.role = role_id
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return badge


static func colour_of(role_id: String) -> Color:
	return Color((ROLES.get(role_id, {}) as Dictionary).get("colour", "#9a9aa8"))


## The role in words, for a card's details: "SOURCE · makes bolts".
static func describe(role_id: String) -> String:
	var known: Dictionary = ROLES.get(role_id, {})
	return "%s · %s" % [known.word, known.hint] if not known.is_empty() else role_id.to_upper()


func _draw() -> void:
	if not ROLES.has(role):
		return
	var tint := colour_of(role)
	draw_style_box(
		UiTheme.box(Color(0.05, 0.04, 0.07, 0.92), Color(tint, 0.8), 1, int(size.y * 0.5)), Rect2(Vector2.ZERO, size)
	)
	var with_word := size.y >= word_from
	var side := size.y * 0.6
	var centre := Vector2(size.y * 0.62 if with_word else size.x * 0.5, size.y * 0.5)
	_glyph(centre, side, tint)
	if not with_word:
		return
	var font := UiTheme.ui_font(600)
	var word: String = ROLES[role].word
	var left := centre.x + side * 0.72
	var width := size.x - left - size.y * 0.35
	var font_size := int(size.y * 0.5)
	while font_size > 7 and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	var baseline := size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(left, baseline), word, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, tint.lightened(0.2))


## The role's glyph in a square of `side` around `centre`: a burst (source), nested diamonds (shape), rising bars
## (order), a crosshair (strike), a shield (guard).
func _glyph(centre: Vector2, side: float, tint: Color) -> void:
	var r := side * 0.5
	var line := maxf(1.2, side * 0.11)
	match role:
		"source":
			draw_circle(centre, r * 0.34, tint)
			for i in 8:
				var angle := TAU * i / 8.0
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(centre + direction * r * 0.55, centre + direction * r, tint, line, true)
		"shape":
			var outer := _diamond(centre, r)
			outer.append(outer[0])
			draw_polyline(outer, tint, line, true)
			draw_colored_polygon(_diamond(centre, r * 0.45), tint)
		"order":
			var bar := side * 0.22
			for i in 3:
				var height := side * (0.35 + 0.3 * i)
				var x := centre.x - side * 0.44 + i * (bar + side * 0.11)
				draw_rect(Rect2(x, centre.y + r - height, bar, height), tint)
		"strike":
			draw_arc(centre, r * 0.62, 0.0, TAU, 24, tint, line, true)
			for i in 4:
				var angle := TAU * i / 4.0
				var direction := Vector2(cos(angle), sin(angle))
				draw_line(centre + direction * r * 0.3, centre + direction * r, tint, line, true)
			draw_circle(centre, line * 0.9, tint)
		"guard":
			var shield := PackedVector2Array(
				[
					centre + Vector2(-r * 0.8, -r * 0.8),
					centre + Vector2(r * 0.8, -r * 0.8),
					centre + Vector2(r * 0.8, -r * 0.05),
					centre + Vector2(0, r),
					centre + Vector2(-r * 0.8, -r * 0.05),
					centre + Vector2(-r * 0.8, -r * 0.8),
				]
			)
			draw_polyline(shield, tint, line, true)
			draw_line(centre + Vector2(0, -r * 0.55), centre + Vector2(0, r * 0.55), tint, line, true)


static func _diamond(centre: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array(
		[centre + Vector2(0, -r), centre + Vector2(r, 0), centre + Vector2(0, r), centre + Vector2(-r, 0)]
	)
