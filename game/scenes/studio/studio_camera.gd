class_name StudioCamera
extends RefCounted
## The Studio's camera (Lanternroot Studio, ADR-0066): pan, zoom in whole steps, an overview of the whole map, and a way
## back to the play camera. It drives the overworld's Camera2D while editing and gives it back, as it was, on leaving.
##
## LEARN: the picture is shown at PixelView's whole-number scale `s`, and the Camera2D adds its own `zoom` `z`, so one
## art pixel is s * z screen pixels. Keeping s * z a whole number keeps every art pixel the same size on screen. That
## number, `shown`, is what the wheel steps (1, 2, 3, 4); z is shown / s. Only the overview breaks the rule, to fit
## the whole map.

const TILE := OverworldScale.TILE
## The screen pixels one art pixel may take, besides the scale the view has now.
const STEPS: Array[int] = [1, 2, 3, 4]
## The overview leaves this much of the world beyond the map's edges, in art pixels.
const OVERVIEW_MARGIN := 40.0

## The camera's centre in world pixels, kept as a float while panning and shown rounded to whole pixels.
var centre := Vector2.ZERO
## Screen pixels per art pixel wanted, whole (the overview has its own zoom).
var shown := 2
var overview := false

var _view: PixelView
var _camera: Camera2D
var _world := Vector2.ZERO
var _play_centre := Vector2.ZERO
var _play_zoom := Vector2.ONE
var _before_overview := {}
var _scale_seen := 0


func _init(view: PixelView = null, camera: Camera2D = null) -> void:
	_view = view
	_camera = camera


## Editing starts: remembers the play camera, and starts from the same picture it showed.
func begin(map_size: Vector2i) -> void:
	_world = Vector2(map_size * TILE)
	_play_centre = _camera.position
	_play_zoom = _camera.zoom
	centre = _camera.position
	shown = maxi(1, roundi(_view.scale_factor * _camera.zoom.x))
	overview = false
	_before_overview = {}
	_scale_seen = 0


## Editing ends: the camera is where play had it (the overworld aims it again on the next frame).
func end() -> void:
	_camera.zoom = _play_zoom
	_camera.position = _play_centre
	overview = false


## A different map is shown: its size, and a look at its start.
func map_changed(map_size: Vector2i, focus: Vector2) -> void:
	_world = Vector2(map_size * TILE)
	overview = false
	_before_overview = {}
	centre = focus
	fit_map()


## Screen pixels per art pixel now (the number the status bar shows).
func screen_zoom() -> float:
	return _view.scale_factor * _camera.zoom.x


## Sets the camera to what this object wants. Called every frame: the view's scale changes when the window or the
## panels do, and the zoom follows it.
func apply() -> void:
	if overview:
		_camera.zoom = Vector2.ONE * _overview_zoom()
		centre = _world / 2.0
	else:
		_camera.zoom = Vector2.ONE * (float(shown) / float(_view.scale_factor))
		centre = centre.clamp(Vector2.ZERO, _world)
	_scale_seen = _view.scale_factor
	_camera.position = centre.round()


## True once when the view's scale changed since the last `apply`, so the zoom needs applying again.
func needs_apply() -> bool:
	return _view.scale_factor != _scale_seen


## Moves the centre by `delta` world pixels.
func pan(delta: Vector2) -> void:
	if overview:
		return
	centre += delta
	apply()


## Centres on a point of the world.
func focus(point: Vector2) -> void:
	if overview:
		overview = false
	centre = point
	apply()


## One wheel step in (`direction` 1) or out (-1), keeping the world point under `anchor` (a point on the view) still.
func step(direction: int, anchor: Vector2) -> void:
	var steps := _steps()
	var from := _nearest(steps, screen_zoom())
	var to := clampi(from + direction, 0, steps.size() - 1)
	if to == from and not overview:
		return
	var before := _view.to_world(anchor)
	overview = false
	shown = steps[to]
	apply()
	_camera.force_update_scroll()
	centre += before - _view.to_world(anchor)
	apply()


## O: the whole map fitted to the view, or back to where the camera was.
func toggle_overview() -> void:
	if overview:
		overview = false
		centre = _before_overview.get("centre", centre)
		shown = _before_overview.get("shown", shown)
	else:
		fit_map()
		return
	apply()


## Fits every cell inside the usable viewport. Zooming or panning can still focus on individual buildings afterward.
func fit_map() -> void:
	if not overview:
		_before_overview = {"centre": centre, "shown": shown}
	overview = true
	apply()


## Home: the camera on the player.
func home(feet: Vector2) -> void:
	focus(feet + Vector2(0, -TILE / 2.0))


## How fast WASD pans, in art pixels a second, so the picture moves the same on screen at any zoom.
func pan_speed(fast: bool) -> float:
	var zoom := maxf(screen_zoom(), 0.25)
	return (2700.0 if fast else 900.0) / zoom


func _overview_zoom() -> float:
	var view := Vector2(_view.viewport.size)
	var room := _world + Vector2.ONE * OVERVIEW_MARGIN * 2.0
	return minf(view.x / room.x, view.y / room.y)


func _steps() -> Array[int]:
	var steps := STEPS.duplicate()
	if not _view.scale_factor in steps:
		steps.append(_view.scale_factor)
	steps.sort()
	return steps


static func _nearest(steps: Array[int], zoom: float) -> int:
	var best := 0
	for i: int in steps.size():
		if absf(float(steps[i]) - zoom) < absf(float(steps[best]) - zoom):
			best = i
	return best
