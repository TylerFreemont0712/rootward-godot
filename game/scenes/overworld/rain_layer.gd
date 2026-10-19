class_name RainLayer
extends Control
## The town's weather (Concept/v0.4/05, section 2.7), drawn over the town and under the UI. "rain" falls as soft
## blue-white streaks; "cloud" lays a faint grey veil over the picture; "sun", or no weather, draws nothing. The layer
## ignores the mouse. With Settings.reduced_motion on, the rain has fewer drops (40) and falls more slowly.
##
##   rain.set_weather("rain")    # the weather of the day, from the weather table
##
## The streaks are cosmetic, so they come from a seeded RandomNumberGenerator here rather than from the game's Rng (which
## is for the rules): the same drops fall each time, which makes the screenshots and the tests repeatable.

const KINDS: Array[String] = ["rain", "cloud", "sun"]
const DROPS := 160
const CALM_DROPS := 40
## How far a drop falls, in pixels a second; reduced motion lets them fall at CALM_FALL.
const FALL := 640.0
const CALM_FALL := 220.0
## The slant: a drop moves this much sideways for each pixel it falls, and its streak leans the same way.
const SLANT := 0.2
const LENGTH_MIN := 18.0
const LENGTH_MAX := 32.0
const STREAK := Color(0.8, 0.88, 1.0, 0.62)
const STREAK_WIDTH := 2.0
const VEIL := Color(0.62, 0.64, 0.68)
const VEIL_ALPHA := 0.08
## Used as the layer's area until it has a size of its own (before it is laid out).
const DESIGN_AREA := Vector2(1920, 1080)
const SEED := 7

var _weather := ""
## The top of each streak, and its length.
var _points := PackedVector2Array()
var _lengths := PackedFloat32Array()
var _speed := FALL
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No weather yet: nothing to move, so no per-frame work until it rains.
	set_process(false)


## Sets the weather. An unknown kind is no weather (it draws nothing).
func set_weather(kind: String) -> void:
	_weather = kind if kind in KINDS else ""
	if _weather == "rain":
		_start_rain()
	else:
		_points.clear()
		_lengths.clear()
	set_process(_weather == "rain")
	queue_redraw()


func weather() -> String:
	return _weather


## How many drops are falling (0 unless it rains).
func drop_count() -> int:
	return _points.size()


## Where each drop's streak starts, for tests and the screenshot tool.
func drops() -> PackedVector2Array:
	return _points.duplicate()


## How fast the drops fall now, in pixels a second.
func speed() -> float:
	return _speed


## The alpha of the grey veil ("cloud"), or 0.0 when there is no veil.
func veil_alpha() -> float:
	return VEIL_ALPHA if _weather == "cloud" else 0.0


func _start_rain() -> void:
	var calm := Settings.reduced_motion
	var count := CALM_DROPS if calm else DROPS
	_speed = CALM_FALL if calm else FALL
	_rng.seed = SEED
	_points.resize(count)
	_lengths.resize(count)
	var area := _area()
	for index in count:
		_lengths[index] = _rng.randf_range(LENGTH_MIN, LENGTH_MAX)
		_points[index] = Vector2(_rng.randf_range(0.0, area.x), _rng.randf_range(0.0, area.y))


func _area() -> Vector2:
	return size if size.x > 0.0 and size.y > 0.0 else DESIGN_AREA


func _process(delta: float) -> void:
	var area := _area()
	var step := Vector2(SLANT, 1.0) * _speed * delta
	for index in _points.size():
		var point := _points[index] + step
		if point.y > area.y:
			# Back above the top, at a new place along it, so the rain never runs out.
			point = Vector2(_rng.randf_range(0.0, area.x), -_lengths[index])
		_points[index] = point
	queue_redraw()


func _draw() -> void:
	if _weather == "cloud":
		draw_rect(Rect2(Vector2.ZERO, size), Color(VEIL, VEIL_ALPHA))
	elif _weather == "rain":
		for index in _points.size():
			var top := _points[index]
			draw_line(top, top + Vector2(SLANT, 1.0) * _lengths[index], STREAK, STREAK_WIDTH, true)
