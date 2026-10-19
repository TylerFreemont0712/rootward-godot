class_name ProgressMark
extends Control
## The small mark beside a quest or a step in a character's progress (ADR-0061), drawn rather than typed so it never
## depends on a font having the glyph: done is a green disc with a tick, the quest underway an amber ring with a dot,
## and anything still to do or still to come an empty ring.
##
##   ProgressMark.of(Quests.DONE)        # done, open, locked; "tick" and "todo" for a step

const DONE_KINDS: Array[String] = ["done", "tick"]

var kind := "todo"


static func of(mark_kind: String, side := 26.0) -> ProgressMark:
	var mark := ProgressMark.new()
	mark.kind = mark_kind
	mark.custom_minimum_size = Vector2(side, side)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return mark


func _draw() -> void:
	var middle := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 1.0
	if kind in DONE_KINDS:
		draw_circle(middle, radius, UiTheme.PASS)
		var tick := PackedVector2Array(
			[
				middle + Vector2(-0.45, 0.0) * radius,
				middle + Vector2(-0.1, 0.38) * radius,
				middle + Vector2(0.5, -0.35) * radius,
			]
		)
		draw_polyline(tick, Color("#14200e"), maxf(2.0, radius * 0.28), true)
	elif kind == "open":
		draw_arc(middle, radius - 1.0, 0.0, TAU, 32, UiTheme.AMBER, 2.5, true)
		draw_circle(middle, radius * 0.38, UiTheme.AMBER)
	else:
		draw_arc(middle, radius - 1.0, 0.0, TAU, 32, UiTheme.FAINT, 2.0, true)
