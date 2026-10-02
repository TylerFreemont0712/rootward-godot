class_name SpellRibbon
extends Node2D
## A travelling spell leaves a live, fading energy ribbon in stage space, separate from its sprite head.

const MAX_POINTS := 28

## How fast its time runs (a rehearsal stage slows it, ADR-0037); 1 in a fight.
var time_scale := 1.0
var element := "none"
var colour := Color.WHITE
var points: Array[Vector2] = []
var _age := 0.0
var _released := false
var _release_age := 0.0


static func create(parent: Node, spell_element: String, tint: Color) -> SpellRibbon:
	var ribbon := SpellRibbon.new()
	ribbon.element = spell_element
	ribbon.colour = tint
	parent.add_child(ribbon)
	return ribbon


func sample(at: Vector2) -> void:
	if not points.is_empty() and points[-1].distance_to(at) < 5.0:
		points[-1] = at
	else:
		points.append(at)
	if points.size() > MAX_POINTS:
		points.pop_front()
	queue_redraw()


func release() -> void:
	_released = true


func _process(frame_delta: float) -> void:
	var delta := frame_delta * time_scale
	_age += delta
	if _released:
		_release_age += delta
		if _release_age > 0.42:
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var fade := 1.0 - _release_age / 0.42 if _released else 1.0
	for i in range(1, points.size()):
		var p := float(i) / float(points.size() - 1)
		var width := (3.0 + 20.0 * p) * fade
		var alpha := p * p * fade
		var a := points[i - 1]
		var b := points[i]
		draw_line(a, b, Color(colour, alpha * 0.15), width * 2.5, true)
		draw_line(a, b, Color(colour, alpha * 0.55), width, true)
		draw_line(a, b, Color(1, 1, 1, alpha * 0.72), maxf(1.0, width * 0.2), true)
		if i % 3 == 0:
			_detail(a, b, p, alpha)


func _detail(a: Vector2, b: Vector2, p: float, alpha: float) -> void:
	var direction := (b - a).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var center := a.lerp(b, 0.5)
	match element:
		"fire":
			var curl := center + normal * sin(_age * 17.0 + p * 18.0) * (9.0 + 12.0 * p)
			draw_line(center, curl, Color(1.0, 0.52, 0.17, alpha), 3.0, true)
			draw_circle(curl, 2.5 * p, Color(1.0, 0.78, 0.3, alpha))
		"frost":
			var crystal := center + normal * (8.0 + 12.0 * p)
			draw_line(center, crystal, Color(0.62, 0.9, 1.0, alpha), 2.0, true)
			draw_line(crystal - direction * 4.0, crystal + direction * 4.0, Color(1, 1, 1, alpha), 1.2, true)
		"spark":
			var fork := center + normal * (10.0 + 14.0 * p)
			draw_line(center, center + normal * 7.0 + direction * 4.0, Color(1.0, 0.93, 0.4, alpha), 2.0, true)
			draw_line(center + normal * 7.0 + direction * 4.0, fork, Color(1, 1, 1, alpha), 1.5, true)
		_:
			var orbit := center + normal * sin(_age * 9.0 + p * 20.0) * 13.0
			draw_circle(orbit, 2.0 * p, Color(0.78, 0.65, 1.0, alpha))
