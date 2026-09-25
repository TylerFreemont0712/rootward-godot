class_name TraceBoard
extends Control
## A clickable, animated model of the lesson's execution path. The next stage reveals one trace clue.

signal step_requested

const NODE_WIDTH := 188.0
const NODE_HEIGHT := 86.0

var stages: Array = []
var tokens: Array = []
var phase := 0
var complete := false
var _clock := 0.0


func _init() -> void:
	custom_minimum_size.y = 250
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or complete:
		return
	var next := phase + 1
	if next < stages.size() and _node_rect(next).has_point(click.position):
		step_requested.emit()
		accept_event()


func _draw() -> void:
	draw_style_box(UiTheme.box(UiTheme.PANEL, UiTheme.LINE, 1, 8, Vector2(12, 12)), Rect2(Vector2.ZERO, size))
	var font := UiTheme.ui_font()
	draw_string(
		font,
		Vector2(24, 35),
		"EXECUTION BOARD  /  CLICK THE NEXT STAGE TO TRACE",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		UiTheme.TEAL
	)
	if stages.is_empty():
		return
	for i in stages.size():
		var rect := _node_rect(i)
		if i < stages.size() - 1:
			var next_rect := _node_rect(i + 1)
			var a := Vector2(rect.end.x, rect.get_center().y)
			var b := Vector2(next_rect.position.x, next_rect.get_center().y)
			var lit := i < phase or complete
			draw_line(a, b, UiTheme.TEAL if lit else UiTheme.LINE, 3.0, true)
			if i == phase and not complete:
				var moving := a.lerp(b, fmod(_clock * 1.3, 1.0))
				draw_circle(moving, 11.0, Color(UiTheme.TEAL, 0.18))
				draw_circle(moving, 4.0, UiTheme.TEAL)
		var active := i == phase and not complete
		var visited := i <= phase or complete
		var border := UiTheme.TEAL if active else (UiTheme.AMBER_DIM if visited else UiTheme.LINE)
		var fill := UiTheme.PANEL_3 if active else UiTheme.PANEL_2
		draw_style_box(UiTheme.box(fill, border, 2 if active else 1, 8, Vector2(10, 8)), rect)
		draw_string(font, rect.position + Vector2(13, 25), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, border)
		draw_string(
			font,
			rect.position + Vector2(13, 54),
			String(stages[i]),
			HORIZONTAL_ALIGNMENT_LEFT,
			NODE_WIDTH - 24,
			16,
			UiTheme.TEXT if visited else UiTheme.MUTED
		)
		if active:
			draw_circle(rect.position + Vector2(NODE_WIDTH - 14, 15), 3.0 + 1.2 * sin(_clock * 6.0), UiTheme.TEAL)
	if not tokens.is_empty():
		var lane_y := maxf(192.0, size.y * 0.64)
		draw_string(font, Vector2(24, lane_y - 24), "WORKING SET", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.MUTED)
		var chip_width := minf(118.0, (size.x - 56.0 - (tokens.size() - 1) * 10.0) / tokens.size())
		for i in tokens.size():
			var rect := Rect2(Vector2(24.0 + i * (chip_width + 10.0), lane_y), Vector2(chip_width, 49.0))
			var glow := i == mini(phase, tokens.size() - 1) and not complete
			draw_style_box(
				UiTheme.box(UiTheme.PANEL_3, UiTheme.TEAL if glow else UiTheme.LINE, 1, 6, Vector2(4, 4)), rect
			)
			draw_string(
				font,
				rect.position + Vector2(0, 31),
				String(tokens[i]),
				HORIZONTAL_ALIGNMENT_CENTER,
				chip_width,
				17,
				UiTheme.TEXT if glow else UiTheme.MUTED
			)
	draw_string(
		font,
		Vector2(24, size.y - 28),
		"CURRENT STAGE  /  %s" % String(stages[mini(phase, stages.size() - 1)]),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		UiTheme.AMBER
	)


func _node_rect(index: int) -> Rect2:
	var gap := maxf(16.0, (size.x - 48.0 - stages.size() * NODE_WIDTH) / maxf(1.0, stages.size() - 1.0))
	return Rect2(Vector2(24.0 + index * (NODE_WIDTH + gap), 78.0), Vector2(NODE_WIDTH, NODE_HEIGHT))
