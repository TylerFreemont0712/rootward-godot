class_name CardCrest
extends Control
## The paradigm shield on a program card. Its shape stays within Rootglass; the crest changes with the card's paradigm.

var paradigm_id := "neutral"
var tint := Color("#d9c796")


static func create(id: String, accent: Color) -> CardCrest:
	var crest := CardCrest.new()
	crest.paradigm_id = id
	crest.tint = accent
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return crest


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shield := PackedVector2Array(
		[
			Vector2(w * 0.5, h * 0.04),
			Vector2(w * 0.95, h * 0.18),
			Vector2(w * 0.95, h * 0.53),
			Vector2(w * 0.83, h * 0.76),
			Vector2(w * 0.5, h * 0.96),
			Vector2(w * 0.17, h * 0.76),
			Vector2(w * 0.05, h * 0.53),
			Vector2(w * 0.05, h * 0.18),
		]
	)
	draw_colored_polygon(shield, Color(tint.darkened(0.68), 0.98))
	var outline := shield.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, tint.lightened(0.35), maxf(1.2, w * 0.055), true)
	var centre := Vector2(w * 0.5, h * 0.5)
	var unit := minf(w, h)
	var ink := tint.lightened(0.62)
	match paradigm_id:
		"divide-conquer":
			_branch(centre, unit, ink)
		"search-index":
			_index(centre, unit, ink)
		"greedy":
			_greedy(centre, unit, ink)
		"brute-force":
			_mesh(centre, unit, ink)
		"dynamic":
			_table(centre, unit, ink)
		_:
			_neutral(centre, unit, ink)


func _branch(centre: Vector2, unit: float, ink: Color) -> void:
	var top := centre + Vector2(0, -unit * 0.23)
	var left := centre + Vector2(-unit * 0.2, unit * 0.2)
	var right := centre + Vector2(unit * 0.2, unit * 0.2)
	var joint := centre + Vector2(0, unit * 0.02)
	var line := maxf(1.2, unit * 0.055)
	draw_line(top, joint, ink, line, true)
	draw_line(joint, left, ink, line, true)
	draw_line(joint, right, ink, line, true)
	for point: Vector2 in [top, left, right]:
		draw_circle(point, unit * 0.07, ink)


func _index(centre: Vector2, unit: float, ink: Color) -> void:
	var start := centre + Vector2(-unit * 0.23, -unit * 0.19)
	var gap := unit * 0.17
	var line := maxf(1.2, unit * 0.055)
	for row in 3:
		var y := start.y + gap * row
		var marker := centre.x - unit * 0.1 if row == 1 else centre.x - unit * 0.2
		draw_circle(Vector2(marker, y), unit * 0.045, ink)
		draw_line(Vector2(marker + unit * 0.09, y), Vector2(centre.x + unit * 0.17, y), ink, line, true)
	draw_arc(centre + Vector2(unit * 0.21, unit * 0.19), unit * 0.11, -0.8, 1.55, 12, ink, line, true)
	draw_line(centre + Vector2(unit * 0.29, unit * 0.27), centre + Vector2(unit * 0.37, unit * 0.35), ink, line, true)


func _greedy(centre: Vector2, unit: float, ink: Color) -> void:
	var line := maxf(1.2, unit * 0.06)
	var origin := centre + Vector2(-unit * 0.23, unit * 0.22)
	var target := centre + Vector2(unit * 0.2, -unit * 0.19)
	draw_line(origin, target, ink, line, true)
	draw_line(target, target + Vector2(-unit * 0.04, unit * 0.17), ink, line, true)
	draw_line(target, target + Vector2(-unit * 0.17, unit * 0.03), ink, line, true)
	for step in 3:
		var point := origin.lerp(target, float(step + 1) / 4.0)
		draw_circle(point, unit * (0.035 + step * 0.012), ink)


func _mesh(centre: Vector2, unit: float, ink: Color) -> void:
	var line := maxf(1.0, unit * 0.045)
	var upper: Array[Vector2] = []
	var lower: Array[Vector2] = []
	for index in 3:
		var x := centre.x + (float(index) - 1.0) * unit * 0.2
		upper.append(Vector2(x, centre.y - unit * 0.2))
		lower.append(Vector2(x, centre.y + unit * 0.2))
	for from: Vector2 in upper:
		for to: Vector2 in lower:
			draw_line(from, to, Color(ink, 0.78), line, true)
	for point: Vector2 in upper + lower:
		draw_circle(point, unit * 0.045, ink)


func _table(centre: Vector2, unit: float, ink: Color) -> void:
	var side := unit * 0.43
	var cell := side / 3.0
	var origin := centre - Vector2(side * 0.5, side * 0.42)
	var line := maxf(1.0, unit * 0.04)
	for row in 3:
		for column in 3:
			var rect := Rect2(origin + Vector2(column * cell, row * cell), Vector2.ONE * cell)
			if row == 1 and column == 1:
				draw_rect(rect.grow(-line), Color(ink, 0.82), true)
			else:
				draw_rect(rect, ink, false, line, true)
	draw_line(centre + Vector2(-unit * 0.2, unit * 0.3), centre + Vector2(unit * 0.2, unit * 0.3), ink, line, true)
	draw_line(centre + Vector2(unit * 0.11, unit * 0.22), centre + Vector2(unit * 0.2, unit * 0.3), ink, line, true)


func _neutral(centre: Vector2, unit: float, ink: Color) -> void:
	draw_circle(centre, unit * 0.06, ink)
	for index in 4:
		var direction := Vector2.RIGHT.rotated(PI * 0.5 * index)
		draw_line(centre + direction * unit * 0.1, centre + direction * unit * 0.26, ink, maxf(1.1, unit * 0.045), true)
