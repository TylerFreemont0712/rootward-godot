class_name SpellImpact
extends Node2D
## Animated vector motifs around the impact, so contact reads as an event rather than a scaled picture.

var element := "none"
var colour := Color.WHITE
var life := 0.55
var _elapsed := 0.0


static func create(parent: Node, spell_element: String, tint: Color, size := 1.0) -> SpellImpact:
	var impact := SpellImpact.new()
	impact.element = spell_element
	impact.colour = tint
	impact.scale = Vector2.ONE * size
	parent.add_child(impact)
	return impact


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= life:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var t := _elapsed / life
	var open := 1.0 - pow(1.0 - minf(t * 2.4, 1.0), 3.0)
	var alpha := 1.0 - smoothstep(0.35, 1.0, t)
	var radius := 25.0 + 125.0 * open
	for ring in 2:
		var r := radius * (0.72 + ring * 0.28)
		var points := PackedVector2Array()
		for i in 49:
			var angle := TAU * i / 48.0 + _elapsed * (1.5 if ring == 0 else -1.2)
			points.append(Vector2(cos(angle) * r, sin(angle) * r * 0.58))
		draw_polyline(points, Color(colour, alpha * (0.85 - 0.3 * ring)), 3.0 - ring, true)
	for i in 12:
		var angle := TAU * float(i) / 12.0 + (0.25 if i % 2 else 0.0)
		var direction := Vector2(cos(angle), sin(angle))
		var start := direction * radius * 0.42
		var end := direction * radius * (0.8 + 0.14 * sin(i * 2.3))
		match element:
			"fire":
				var lean := Vector2(-direction.y, direction.x) * 14.0 * (1.0 - t)
				draw_line(start, end + lean, Color(1.0, 0.47, 0.14, alpha), 5.0, true)
				draw_line(start, end + lean, Color(1.0, 0.93, 0.57, alpha), 1.8, true)
			"frost":
				var side := Vector2(-direction.y, direction.x) * 8.0
				draw_colored_polygon(
					PackedVector2Array([start, end + side, end + direction * 12.0, end - side]),
					Color(0.52, 0.87, 1.0, alpha * 0.5)
				)
				draw_line(start, end + direction * 12.0, Color(1, 1, 1, alpha), 1.5, true)
			"spark":
				var bend := start.lerp(end, 0.5) + Vector2(-direction.y, direction.x) * (10.0 if i % 2 else -10.0)
				draw_polyline(PackedVector2Array([start, bend, end]), Color(1.0, 0.94, 0.44, alpha), 4.0, true)
				draw_polyline(PackedVector2Array([start, bend, end]), Color(1, 1, 1, alpha), 1.3, true)
			_:
				draw_line(start, end, Color(colour, alpha * 0.8), 2.0, true)
				draw_circle(end, 3.0, Color(1, 1, 1, alpha))
