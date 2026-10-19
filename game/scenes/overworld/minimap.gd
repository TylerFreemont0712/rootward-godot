class_name Minimap
extends Control
## Lanternroot's minimap (v0.4, Concept/v0.4/01 section 9.2): the whole map in a 240 x 168 frame, drawn in the player's
## own colours, with the player, the people, the doors and the tracked step's pin on it. It appears once the map part is
## built (`set_enabled(true)`) and the quest tracker holds it under its card, so the two move and hide together.
##
## The map is baked into one ImageTexture whenever the map or the colours change: every cell takes the colour of its
## ground (`colours[ground]`), and every solid footprint the colour of its kind ("building", "tree" or "thing"; see
## `kind_of`). It is baked at the size it is drawn, a pixel to a pixel, so its cells stay crisp at the odd scale the town
## needs (80 x 56 cells in 228 x 156 px). A room is scaled up to fit, at most 14 px a cell.
##
##   minimap.setup(catalog)
##   minimap.show_map(map, colours)         # colours: ground or kind -> Color; {} draws the stand-in greys
##   minimap.set_player(cell)               # an amber dot of 6 px that pulses once a second
##   minimap.set_people(cells)              # cream dots of 4 px
##   minimap.set_pin(cell)                  # a green star; Vector2i(-1, -1) for none
##   minimap.set_line("Warm Hearth Row", "18:40")   # under the map, either part optional
##   minimap.set_enabled(true)              # the conductor, once the map part is built
## A click on the map emits `open_full`.

signal open_full

const SIZE := Vector2(240, 168)
const PAD := 6.0
const MAX_CELL := 14.0
const NONE := Vector2i(-1, -1)
const PLAYER_DOT := 6.0
const PERSON_DOT := 4.0
const CREAM := Color("#f3e6c8")
const GREEN := Color("#8bc96a")
const DARK := Color("#17110c")
const GAP := 6.0
## The art ids that are trees, for the colour of a tree's footprint; anything else with "tree" in its id is one too.
const TREES: Array[String] = ["oak", "oak2", "birch", "pine", "apple", "apple2"]
## The greys a preview or a test draws with, until the player's own colours arrive.
const STAND_IN := {
	"grass": Color("#7d7d7d"),
	"flowers": Color("#8c8c8c"),
	"path": Color("#a8a8a8"),
	"cobble": Color("#9a9a9a"),
	"bridge": Color("#b4b4b4"),
	"floor": Color("#8f8f8f"),
	"rug": Color("#a0a0a0"),
	"water": Color("#3d3d3d"),
	"hedge": Color("#5a5a5a"),
	"wall": Color("#404040"),
	"void": Color("#141414"),
	"building": Color("#d0d0d0"),
	"tree": Color("#5e5e5e"),
	"thing": Color("#bcbcbc"),
}

var _catalog: Dictionary = {}
var _map: Dictionary = {}
var _colours: Dictionary = {}
var _texture: ImageTexture
var _image: Image
var _scale := 1.0
var _origin := Vector2.ZERO
var _player := NONE
var _people: Array[Vector2i] = []
var _pin := NONE
var _warps: Array[Vector2i] = []
var _enabled := false
var _shown := true
var _hover := false
var _time := 0.0
var _fade: Tween
var _line: Label
var _line_text := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = SIZE
	visible = false


func _ready() -> void:
	theme = OverworldStyle.theme()
	_line = Label.new()
	_line.name = "Line"
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.add_theme_font_override("font", OverworldStyle.body_font(600))
	_line.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_line.add_theme_color_override("font_color", PauseMenu.INK)
	_line.add_theme_stylebox_override("normal", PauseMenu.panel_style(Vector2(12, 2)))
	_line.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_line.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_line.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_line.offset_right = 0.0
	_line.offset_bottom = 0.0
	_line.visible = false
	add_child(_line)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	_apply_line()


# --- what the town tells it ---------------------------------------------------------------------------------------


## The catalog (the townsfolk and the maps). The map itself comes with `show_map`.
func setup(catalog: Dictionary) -> void:
	_catalog = catalog


## Shows `map` (an OverworldMap.build map) in `colours` (ground or kind -> Color; names it lacks fall back to the
## stand-in greys). Bakes the picture again.
func show_map(map: Dictionary, colours: Dictionary) -> void:
	_map = map
	_colours = colours
	_warps.clear()
	for cell: Vector2i in (map.get("warps", {}) as Dictionary):
		_warps.append(cell)
	_bake()
	queue_redraw()


func set_player(cell: Vector2i) -> void:
	if cell != _player:
		_player = cell
		queue_redraw()


func set_people(cells: Array[Vector2i]) -> void:
	_people = cells.duplicate()
	queue_redraw()


## The tracked step's pin: Vector2i(-1, -1) for none.
func set_pin(cell: Vector2i) -> void:
	if cell != _pin:
		_pin = cell
		queue_redraw()


## The line under the map: "<place> · <clock>", either part optional, hidden when both are empty.
func set_line(place: String, clock: String) -> void:
	var parts: Array[String] = []
	for part: String in [place, clock]:
		if part != "":
			parts.append(part)
	_line_text = " · ".join(parts)
	_apply_line()


## The map part is built (true) or not yet (false). Until it is, nothing shows.
func set_enabled(on: bool) -> void:
	_enabled = on
	_refresh_visibility()


func is_enabled() -> bool:
	return _enabled


## The tracker shows and hides the minimap with its card (a short fade). It still needs `set_enabled(true)` to show.
func set_shown(on: bool) -> void:
	_shown = on
	_refresh_visibility()


## Whether it is on screen (or fading in): enabled, and the tracker is showing.
func is_showing() -> bool:
	return _enabled and _shown


func line_text() -> String:
	return _line_text


# --- where things are (for the tracker's neighbours and the tests) ------------------------------------------------


## The pixels a cell takes in the frame: its rectangle at the baked scale.
func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(cell) * _scale, Vector2(_scale, _scale))


func cell_centre(cell: Vector2i) -> Vector2:
	return cell_rect(cell).get_center()


## Pixels a cell takes, as the map was fitted: the whole number of pixels per cell, or fewer for a big map.
func cell_scale() -> float:
	return _scale


## The baked picture (an image of the map's pixels), for tests; null before `show_map`.
func baked() -> Image:
	return _image


## The colour the baked picture has at the middle of `cell`.
func colour_at(cell: Vector2i) -> Color:
	if _image == null:
		return Color.TRANSPARENT
	var at := cell_centre(cell) - _origin
	return _image.get_pixelv(Vector2i(at).clamp(Vector2i.ZERO, _image.get_size() - Vector2i.ONE))


# --- the rules the full map shares --------------------------------------------------------------------------------


## The kind of a solid object, as the player's `map_colour` hears it: "building", "tree", or "thing" for any other solid
## prop. "" for an object nobody sees on a map (a person, a warp).
static func kind_of(object: Dictionary) -> String:
	var kind := String(object.get("kind", ""))
	if kind == "building":
		return "building"
	if kind != "prop" and kind != "sign":
		return ""
	var art := String(object.get("art", ""))
	if art in TREES or art.contains("tree"):
		return "tree"
	return "thing"


## One colour for every cell of `map` (row by row): its ground's, then a solid footprint's, in its kind's.
static func cell_colours(map: Dictionary, colours: Dictionary) -> PackedColorArray:
	var width := int(map.get("width", 0))
	var height := int(map.get("height", 0))
	var out := PackedColorArray()
	out.resize(width * height)
	var ground: PackedStringArray = map.get("ground", PackedStringArray())
	for i in mini(width * height, ground.size()):
		out[i] = colour_of(colours, ground[i])
	var objects: Array = map.get("objects", [])
	var solid: Dictionary = map.get("solid", {})
	for cell: Vector2i in solid:
		if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
			continue
		var index := int(solid[cell])
		var kind := kind_of(objects[index]) if index >= 0 and index < objects.size() else ""
		if kind != "":
			out[cell.y * width + cell.x] = colour_of(colours, kind)
	return out


## The colour for a ground or a kind: the player's, else the stand-in grey, else black.
static func colour_of(colours: Dictionary, key: String) -> Color:
	var chosen: Variant = colours.get(key)
	if chosen is Color:
		return chosen
	return STAND_IN.get(key, Color.BLACK)


## The ground and kind names a legend lists, in the town's order: the grounds, then the kinds.
static func legend_keys(colours: Dictionary) -> Array[String]:
	var order: Array[String] = []
	order.assign(STAND_IN.keys())
	var out: Array[String] = []
	for key in order:
		if colours.has(key):
			out.append(key)
	for key: String in colours:
		if not out.has(key):
			out.append(key)
	return out


## The cells that lead somewhere: doors and mats, drawn as small dark marks.
static func warp_cells(map: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in (map.get("warps", {}) as Dictionary):
		out.append(cell)
	return out


# --- baking and drawing -------------------------------------------------------------------------------------------


func _bake() -> void:
	var width := int(_map.get("width", 0))
	var height := int(_map.get("height", 0))
	if width <= 0 or height <= 0:
		_image = null
		_texture = null
		return
	var inner := SIZE - Vector2(PAD, PAD) * 2.0
	_scale = minf(minf(inner.x / width, inner.y / height), MAX_CELL)
	var pixels := Vector2i(floori(width * _scale), floori(height * _scale))
	var cells := cell_colours(_map, _colours)
	var data := PackedByteArray()
	data.resize(pixels.x * pixels.y * 4)
	var at := 0
	for y in pixels.y:
		var row := mini(int(y / _scale), height - 1) * width
		for x in pixels.x:
			var colour := cells[row + mini(int(x / _scale), width - 1)]
			data[at] = int(round(colour.r * 255.0))
			data[at + 1] = int(round(colour.g * 255.0))
			data[at + 2] = int(round(colour.b * 255.0))
			data[at + 3] = 255
			at += 4
	_image = Image.create_from_data(pixels.x, pixels.y, false, Image.FORMAT_RGBA8, data)
	_texture = ImageTexture.create_from_image(_image)
	_origin = (SIZE - Vector2(pixels)) / 2.0
	_origin = _origin.floor()


func _draw() -> void:
	var frame := UiTheme.box(Color(0.045, 0.033, 0.026, 0.94), UiTheme.AMBER if _hover else UiTheme.AMBER_DIM, 2, 10)
	frame.draw(get_canvas_item(), Rect2(Vector2.ZERO, SIZE))
	if _texture == null:
		return
	draw_texture(_texture, _origin)
	# Doors and mats: a small dark mark, never smaller than two pixels.
	var mark := maxf(2.0, ceilf(_scale))
	for cell in _warps:
		var spot := cell_rect(cell)
		draw_rect(Rect2(spot.get_center() - Vector2(mark, mark) / 2.0, Vector2(mark, mark)), DARK)
	for cell in _people:
		var spot := cell_centre(cell)
		draw_circle(spot, PERSON_DOT / 2.0 + 1.0, DARK)
		draw_circle(spot, PERSON_DOT / 2.0, CREAM)
	if _pin != NONE:
		_draw_star(cell_centre(_pin), 6.0)
	if _player != NONE:
		var spot := cell_centre(_player)
		if not Settings.reduced_motion:
			var phase := fmod(_time, 1.0)
			draw_arc(spot, PLAYER_DOT / 2.0 + 1.0 + phase * 5.0, 0.0, TAU, 24, Color(UiTheme.AMBER, 0.8 * (1.0 - phase)), 1.5, true)
		draw_circle(spot, PLAYER_DOT / 2.0 + 1.5, DARK)
		draw_circle(spot, PLAYER_DOT / 2.0, UiTheme.AMBER)


## A five-pointed star in green, with a dark edge so it reads on any colour.
func _draw_star(centre: Vector2, radius: float) -> void:
	draw_star(self, centre, radius)


static func draw_star(canvas: CanvasItem, centre: Vector2, radius: float, colour := GREEN) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var length := radius if i % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * length)
	canvas.draw_colored_polygon(points, colour)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, DARK, 1.5, true)


func _process(delta: float) -> void:
	if is_visible_in_tree() and _player != NONE and not Settings.reduced_motion:
		_time += delta
		queue_redraw()


func _apply_line() -> void:
	if _line == null:
		return
	_line.text = _line_text
	_line.visible = _line_text != ""
	var extra := GAP + _line.get_combined_minimum_size().y if _line.visible else 0.0
	custom_minimum_size = SIZE + Vector2(0, extra)


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, SIZE).has_point(point)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Sound.play("sfx-open", 0.3)
		open_full.emit()


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _refresh_visibility() -> void:
	var on := _enabled and _shown
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if on:
		visible = true
		if is_inside_tree():
			modulate.a = 0.0
			_fade = create_tween()
			_fade.tween_property(self, "modulate:a", 1.0, OverworldStyle.OPEN_TIME)
		else:
			modulate.a = 1.0
	elif is_inside_tree() and visible:
		_fade = OverworldStyle.fade_out(self, func() -> void: visible = _enabled and _shown)
	else:
		visible = false
