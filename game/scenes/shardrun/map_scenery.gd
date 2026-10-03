class_name MapScenery
extends Control
## Brass wall fittings and occasional maintenance notices beside the long route. Seeded through hash(), never
## the rules' RNG; rebuilding a map does not change its jokes, encounters or available paths.

const NOTICES := {
	3:
	[
		"HELLO, WORLD",
		"WORKS ON MY MACHINE",
		"TODO: REMOVE BEFORE RELEASE",
		"chmod +x",
		"SANDBOX: NO WARRANTY",
		"404: EXIT NOT FOUND"
	],
	2:
	[
		"free() PARKING",
		"MEMORY LEAK: MIND THE DRIP",
		"DO NOT DEREFERENCE",
		"CACHE MISS",
		"malloc: VACANCIES",
		"GARBAGE COLLECTION: TUESDAYS"
	],
	1:
	[
		"BUSY WAIT",
		"IRQ: PLEASE HOLD",
		"DRIVER NOT FOUND",
		"DEADLOCK: USE OTHER DOOR",
		"RACE CONDITION CROSSING",
		"BUS LANE: DEVICES ONLY"
	],
	0:
	[
		"sudo: KNOCK FIRST",
		"PERMISSION DENIED",
		"HERE BE DAEMONS",
		"NO PANIC IN THE KERNEL",
		"ROOT ACCESS: NO REFUNDS",
		"rm -rf: DO NOT PULL"
	],
}
const PATINA := {3: Color("#bf9251"), 2: Color("#77aaa0"), 1: Color("#c28055"), 0: Color("#cebd8c")}

var ring := 3
var rows := 8
var _offset := 0
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(state: Dictionary, layer: Dictionary) -> void:
	ring = int(layer.get("ring", 3))
	rows = int(state.get("trial", {}).get("map_rows", layer.rows))
	_offset = posmod(hash("%s:%s" % [state.get("seed", ""), layer.id]), NOTICES.get(ring, NOTICES[3]).size())
	queue_redraw()


func _process(delta: float) -> void:
	if not Settings.reduced_motion:
		_clock += delta
		queue_redraw()


func _draw() -> void:
	if size.x < 780.0:
		return
	var hue: Color = PATINA.get(ring, PATINA[3])
	var dark := Color("#17110b")
	for side: int in [0, 1]:
		var x := 22.0 if side == 0 else size.x - 22.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(hue, 0.3), 3.0, true)
		draw_line(Vector2(x + 7, 0), Vector2(x + 7, size.y), Color(hue, 0.12), 1.0, true)
	for index in range(1, rows, 2):
		var notices: Array = NOTICES.get(ring, NOTICES[3])
		var text: String = notices[(_offset + index) % notices.size()]
		var width := minf(195.0, size.x * 0.17)
		var x := 33.0 if index % 4 == 1 else size.x - width - 33.0
		var y := MapCanvas.FOOT + (index - 0.5) * MapCanvas.ROW_STEP
		var plate := Rect2(x, y - 24, width, 48)
		UiTheme.box(Color(dark, 0.83), Color(hue, 0.48), 1, 2).draw(get_canvas_item(), plate)
		for bolt: Vector2 in [plate.position + Vector2(5, 5), plate.end - Vector2(5, 5)]:
			draw_circle(bolt, 2.0, Color(hue, 0.7))
		var font := UiTheme.code_font()
		var font_size := mini(11, int(11.0 * (width - 16) / maxf(1.0, font.get_string_size(text, 0, -1, 11).x)))
		draw_string(font, Vector2(x + 8, y + 4), text, HORIZONTAL_ALIGNMENT_CENTER, width - 16, font_size, hue)
		if ring == 1:
			_draw_timing_wheel(Vector2(x + width * 0.5, y + 72), hue)
		elif ring == 2:
			var at := Vector2(x + width * 0.5, y + 48)
			draw_rect(Rect2(at - Vector2(28, 0), Vector2(56, 42)), Color(hue, 0.12))
			draw_rect(Rect2(at - Vector2(28, 0), Vector2(56, 42)), Color(hue, 0.35), false, 1.0)
			draw_line(at + Vector2(0, 10), at + Vector2(0, 35), Color(hue, 0.25), 3.0)
			var drop := 0.0 if Settings.reduced_motion else fmod(_clock * 8.0 + index * 12, 30.0)
			draw_circle(at + Vector2(30, 15 + drop), 1.7, Color(hue, 0.55))
		elif ring == 0:
			var at := Vector2(x + width * 0.5, y + 46)
			var trace := PackedVector2Array([at, at + Vector2(0, 16), at + Vector2(28, 16), at + Vector2(28, 57)])
			draw_polyline(trace, Color(hue, 0.32), 2.0, true)
			var packet := 0.0 if Settings.reduced_motion else fmod(_clock * 5.0 + index * 12, 38.0)
			draw_circle(at + Vector2(28, 18 + packet), 2.0, Color(hue, 0.58))
		else:
			var travel := 0.0 if Settings.reduced_motion else 22.0 * sin(_clock * 0.18 + index)
			var at := Vector2(x + width * 0.5, y + 74 + travel)
			draw_line(Vector2(at.x, y + 32), at, Color(hue, 0.36), 1.0)
			draw_rect(Rect2(at - Vector2(12, 0), Vector2(24, 30)), Color(hue, 0.34), false, 1.5)
			for bar: int in [-6, 0, 6]:
				draw_line(at + Vector2(bar, 0), at + Vector2(bar, 30), Color(hue, 0.22), 1.0)


func _draw_timing_wheel(at: Vector2, hue: Color) -> void:
	draw_circle(at, 25.0, Color("#15100b"))
	draw_arc(at, 25, 0, TAU, 48, Color(hue, 0.42), 3, true)
	draw_arc(at, 17, 0, TAU, 40, Color(hue, 0.26), 1, true)
	var rotation := 0.0 if Settings.reduced_motion else _clock * 0.06
	for index in 8:
		var spoke := Vector2.from_angle(rotation + index * TAU / 8)
		draw_line(at + spoke * 6, at + spoke * 24, Color(hue, 0.36), 2, true)
	draw_circle(at, 5, Color(hue, 0.4))
