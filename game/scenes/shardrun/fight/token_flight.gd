class_name TokenFlight
extends Label
## A card's function name on its way from the code panel into the spell's circle (Token Stream, ADR-0058): it leaves its
## call on a curve, hovers round the circle's rim while the call runs, and dissolves into the circle when the call
## resolves and its layer is written.

## How far the curve leans, as a share of the distance: a lift off the line, not a slide.
const BEND := 0.3
const TRAVEL := 0.55
const LAND := 0.24
## The hover: a small orbit round the circle's centre, so a held token keeps moving.
const ORBIT := 26.0
const ORBIT_SPEED := 2.4

var _from := Vector2.ZERO
var _control := Vector2.ZERO
var _to := Vector2.ZERO
var _held := false
var _clock := 0.0
var _phase := 0.0


## Starts a token at `from` that flies to `to`, both in global (screen) coordinates. Top-level, so the parent's
## layout, which may settle after the flight starts, cannot move it.
static func launch(parent: Control, text: String, from: Vector2, to: Vector2, colour: Color) -> TokenFlight:
	var flight := TokenFlight.new()
	flight.text = text
	flight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flight.add_theme_font_override("font", UiTheme.code_font())
	flight.add_theme_font_size_override("font_size", 18)
	flight.add_theme_color_override("font_color", colour)
	flight.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 0.9))
	flight.add_theme_constant_override("outline_size", 4)
	parent.add_child(flight)
	# LEARN: a flight is top-level and in global coordinates, so no parent's transform moves it. The overlay's layout
	# can settle after a flight starts; a position computed against the old origin sent the token off the screen.
	flight.top_level = true
	flight.reset_size()
	flight._from = from
	flight._to = to
	flight._control = (from + to) * 0.5 + (to - from).orthogonal() * BEND
	flight._phase = float(text.hash() % 628) / 100.0
	flight.set_process(false)
	var tween := flight.create_tween()
	tween.tween_method(flight._along, 0.0, 1.0, TRAVEL).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(flight._hold)
	return flight


## The point on the curve at `t`: a quadratic Bezier from the call to the circle.
func point_at(t: float) -> Vector2:
	var a := _from.lerp(_control, t)
	var b := _control.lerp(_to, t)
	return a.lerp(b, t)


## The circle's rim the token hovers on: a small orbit round its centre.
func hover_point(time: float) -> Vector2:
	var angle := _phase + time * ORBIT_SPEED
	return _to + Vector2(cos(angle) * ORBIT, sin(angle) * ORBIT * 0.5)


## The call resolved: the token dissolves into the circle (its layer is written now).
func land() -> void:
	if not is_inside_tree():
		return
	_held = false
	set_process(false)
	pivot_offset = size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), LAND).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, LAND)
	tween.finished.connect(queue_free)


func _along(t: float) -> void:
	global_position = point_at(t) - size * 0.5


func _hold() -> void:
	_held = true
	set_process(true)


func _process(delta: float) -> void:
	if not _held:
		return
	_clock += delta
	global_position = hover_point(_clock) - size * 0.5
