class_name CharacterSelectBackdrop
extends Control
## What the character screen stands in front of (ADR-0061): Lanternroot's roofs at dusk standing along a horizon just
## behind the lineup's strip of cobbles, a warm glow where the title hangs, the dark ground below, and fireflies
## drifting over it all. Drawn, not built: the town's own building pictures in deep shade at a whole number of screen
## pixels per art pixel, so they stay crisp. A missing picture is simply left out.

## The skyline, left to right, and how far each one stands back (0 at the front, darker further back).
const SKYLINE: Array[Array] = [
	["archive", 1],
	["home", 0],
	["lanterntree", 1],
	["inn", 0],
	["smithy", 1],
	["hall", 1],
	["shop", 0],
	["workshop", 1],
	["cottage", 0],
	["shrine", 1],
	["rootgate", 0],
]
## Design pixels per art pixel for the skyline, before rounding to whole screen pixels.
const ZOOM := 2.0
## Where the roofs' feet stand, as a share of the window's height: just behind the lineup's cobbles.
const HORIZON := 0.745
const FIREFLIES := 16
const FIREFLY := Color("#d9f27e")

var _clock := 0.0
var _flies: Array[Vector3] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Where each firefly drifts about (x and y as a share of the window) and its own pace; the same every time.
	var random := RandomNumberGenerator.new()
	random.seed = 7331
	for i in FIREFLIES:
		_flies.append(Vector3(random.randf(), random.randf_range(0.12, 0.92), random.randf_range(0.6, 1.4)))


func _process(delta: float) -> void:
	if Settings.reduced_motion:
		return
	_clock += delta
	queue_redraw()


func _screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	return maxf(0.01, get_viewport().get_final_transform().get_scale().x)


func _draw() -> void:
	_draw_glow(Vector2(size.x / 2.0, 70.0), 520.0, Color(UiTheme.AMBER, 0.06))
	_draw_skyline()
	for fly in _flies:
		var at := Vector2(fly.x * size.x, fly.y * size.y)
		at += Vector2(sin(_clock * 0.35 * fly.z + fly.x * 9.0) * 40.0, cos(_clock * 0.5 * fly.z + fly.y * 7.0) * 24.0)
		var pulse := 0.45 + 0.55 * (0.5 + 0.5 * sin(_clock * 2.2 * fly.z + fly.x * 20.0))
		_draw_glow(at, 16.0, Color(FIREFLY, 0.10 * pulse))
		draw_circle(at, 3.0, Color(FIREFLY, 0.8 * pulse))


func _draw_glow(at: Vector2, radius: float, colour: Color) -> void:
	for ring in 6:
		draw_circle(at, radius * (1.0 - ring / 7.0), Color(colour, colour.a * (0.4 + ring * 0.12)))


func _draw_skyline() -> void:
	var on_screen := _screen_scale()
	var pixel := maxf(1.0, roundf(ZOOM * on_screen)) / on_screen
	var x := -40.0
	for entry in SKYLINE:
		var picture := OverworldArt.building(String(entry[0]))
		if picture == null:
			continue
		var drawn := Vector2(picture.get_size()) * pixel
		var back := int(entry[1]) == 1
		var shade := Color(0.2, 0.15, 0.2) if back else Color(0.3, 0.22, 0.24)
		var foot := size.y * HORIZON + (6.0 if back else 14.0) * pixel
		draw_texture_rect(picture, Rect2(Vector2(x, foot - drawn.y).round(), drawn), false, shade)
		x += drawn.x * (0.78 if back else 0.9)
		if x > size.x:
			break
	# The dark ground in front of the roofs, deeper toward the bottom of the window.
	var ground := size.y * HORIZON
	draw_rect(Rect2(0.0, ground - 1.0, size.x, size.y - ground + 1.0), Color(0.055, 0.042, 0.07))
	# The lane's own light where the ground begins.
	draw_rect(Rect2(0.0, ground - 1.0, size.x, 3.0), Color(UiTheme.AMBER, 0.12))
