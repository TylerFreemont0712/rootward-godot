class_name FullMap
extends Control
## Lanternroot's full map (v0.4, Concept/v0.4/01 section 9.3): an overlay over the town with the whole map drawn at the
## largest whole-number scale that fits its panel, in the player's colours (the colours of their `map_colour`). Each
## place's name sits at the centre of its rectangle, in the overworld's body face with a dark outline. The player, the
## people and the tracked step's pin are drawn on it, and a legend on the right says what each colour is. Esc or M
## closes it (and the menu's map item, or the key the player's `shortcut` gives, opens it).
##
##   map.open(map, colours, places, player_cell, people_cells, pin)
##   map.set_colour_names({"water": "blue"})    # optional: the legend says "water: blue"

signal closed

const PANEL_SIZE := Vector2(1300, 900)
const LEGEND_WIDTH := 300.0
const NAME_SIZE := 20
const NONE := Vector2i(-1, -1)

var _open := false
var _map: Dictionary = {}
var _colours: Dictionary = {}
var _names: Dictionary = {}
var _places: Array = []
var _player := NONE
var _people: Array[Vector2i] = []
var _pin := NONE
var _texture: ImageTexture
var _warps: Array[Vector2i] = []
var _time := 0.0
var _motion: Tween
var _card: PanelContainer
var _heading: Label
var _where: Label
var _view: Control
var _legend: VBoxContainer
var _legend_keys: Array[String] = []
var _note: Label


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_dim_input)
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style())
	_card.custom_minimum_size = PANEL_SIZE
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)
	centre.add_child(_card)
	_heading = Ui.label(Text.t("Map"), "Heading")
	_heading.add_theme_color_override("font_color", UiTheme.AMBER)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_where = PauseMenu.small("")
	_where.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_view = Control.new()
	_view.name = "View"
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.clip_contents = true
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.draw.connect(_draw_view)
	_legend = Ui.vbox([], 5)
	_legend.custom_minimum_size.x = LEGEND_WIDTH
	var side := Ui.vbox([_legend, Ui.expand(Ui.spacer(), true)], 8)
	side.custom_minimum_size.x = LEGEND_WIDTH
	var body := Ui.hbox([_view, PauseMenu.divider(), side], 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var help := PauseMenu.help_line(Text.t("Esc or M: close"))
	_card.add_child(
		Ui.vbox([Ui.hbox([_heading, _where], 12), PauseMenu.rule(), body, PauseMenu.rule(), help], 14)
	)
	set_process(false)


func is_open() -> bool:
	return _open


## Opens the map over the town. `colours` is ground or kind -> Color, `places` a list of {name, x, y, w, h}, the cells are
## on `map`, and `pin` is Vector2i(-1, -1) for none.
func open(
	map: Dictionary,
	colours: Dictionary,
	places: Array,
	player_cell: Vector2i,
	people_cells: Array[Vector2i],
	pin := NONE
) -> void:
	_map = map
	_colours = colours
	_places = places
	_player = player_cell
	_people = people_cells.duplicate()
	_pin = pin
	_warps = Minimap.warp_cells(map)
	_bake()
	_fill_legend()
	_where.text = Text.t(String(map.get("name", "")))
	_open = true
	visible = true
	set_process(true)
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	_view.queue_redraw()


func close() -> void:
	if not _open:
		return
	_open = false
	set_process(false)
	Sound.play("sfx-whiff", 0.3)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.fade_out(self, func() -> void: visible = _open)
	closed.emit()


## The names the legend gives each colour ("water" -> "blue"), when the player's code gave names.
func set_colour_names(names: Dictionary) -> void:
	_names = names
	if _open:
		_fill_legend()


## The grounds and kinds the legend lists, in order.
func legend_grounds() -> Array[String]:
	return _legend_keys


## The whole pixels each cell takes at the size of the map's view now (the largest whole number that fits, at least 1).
func current_scale() -> int:
	return scale_for(_view.size, Vector2i(int(_map.get("width", 0)), int(_map.get("height", 0))))


## The largest whole number of pixels a cell can take for `map_size` cells to fit in `room`; never less than 1.
static func scale_for(room: Vector2, map_size: Vector2i) -> int:
	if map_size.x <= 0 or map_size.y <= 0:
		return 1
	return maxi(1, floori(minf(room.x / map_size.x, room.y / map_size.y)))


# --- the legend ---------------------------------------------------------------------------------------------------


func _fill_legend() -> void:
	Ui.clear(_legend)
	_legend_keys = Minimap.legend_keys(_colours)
	var title := PauseMenu.small(Text.t("Legend"))
	title.add_theme_font_override("font", OverworldStyle.body_font(600))
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	_legend.add_child(title)
	for key in _legend_keys:
		_legend.add_child(_legend_row(key))
	_note = PauseMenu.small(Text.t("Drawn with your map_colour()"), true)
	_note.name = "Note"
	_legend.add_child(Ui.spacer(0, 2))
	_legend.add_child(_note)
	_legend.add_child(PauseMenu.rule())
	_legend.add_child(_marker_row("player", Text.t("You")))
	_legend.add_child(_marker_row("person", Text.t("People")))
	_legend.add_child(_marker_row("pin", Text.t("Your next step")))
	_legend.add_child(_marker_row("door", Text.t("Doors")))


func _legend_row(key: String) -> Control:
	var swatch := Control.new()
	swatch.custom_minimum_size = Vector2(30, 22)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var colour := Minimap.colour_of(_colours, key)
	swatch.draw.connect(
		func() -> void:
			UiTheme.box(colour, Color(0, 0, 0, 0.5), 1, 5).draw(swatch.get_canvas_item(), Rect2(Vector2.ZERO, swatch.size))
	)
	var words := key
	if _names.has(key):
		words = "%s: %s" % [key, String(_names[key])]
	# The ground is code (what map_colour gets), so it stays; a Japanese reader also gets its everyday word.
	if Text.japanese() and ground_word(key) != key:
		words = "%s %s" % [ground_word(key), words]
	var label := Ui.label(words)
	label.name = "Row_" + key
	label.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	label.add_theme_color_override("font_color", PauseMenu.INK)
	return Ui.hbox([swatch, label], 12)


## A ground's everyday word in the player's language (each a literal Text.t, so the locale check finds it).
static func ground_word(ground: String) -> String:
	match ground:
		"grass":
			return Text.t("Grass")
		"flowers":
			return Text.t("Flowers")
		"path":
			return Text.t("Path")
		"cobble":
			return Text.t("Cobbles")
		"bridge":
			return Text.t("Bridge")
		"floor":
			return Text.t("Floor")
		"rug":
			return Text.t("Rug")
		"water":
			return Text.t("Water")
		"hedge":
			return Text.t("Hedge")
		"wall":
			return Text.t("Wall")
		"void":
			return Text.t("Nothing there")
		"building":
			return Text.t("Buildings")
		"tree":
			return Text.t("Trees")
		"thing":
			return Text.t("Things")
	return ground


func _marker_row(kind: String, words: String) -> Control:
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(30, 22)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(_draw_marker.bind(mark, kind))
	var label := Ui.label(words)
	label.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	label.add_theme_color_override("font_color", OverworldStyle.MUTED)
	return Ui.hbox([mark, label], 12)


func _draw_marker(mark: Control, kind: String) -> void:
	var centre := mark.size / 2.0
	match kind:
		"player":
			mark.draw_circle(centre, 6.0, Minimap.DARK)
			mark.draw_circle(centre, 4.5, UiTheme.AMBER)
		"person":
			mark.draw_circle(centre, 5.0, Minimap.DARK)
			mark.draw_circle(centre, 3.5, Minimap.CREAM)
		"pin":
			Minimap.draw_star(mark, centre, 9.0)
		"door":
			mark.draw_rect(Rect2(centre - Vector2(5, 5), Vector2(10, 10)), Minimap.DARK)
			mark.draw_rect(Rect2(centre - Vector2(5, 5), Vector2(10, 10)), OverworldStyle.MUTED, false, 1.5)


# --- the map ------------------------------------------------------------------------------------------------------


## One pixel to a cell: the view stretches it by a whole number, so each cell stays a crisp square.
func _bake() -> void:
	var width := int(_map.get("width", 0))
	var height := int(_map.get("height", 0))
	if width <= 0 or height <= 0:
		_texture = null
		return
	var cells := Minimap.cell_colours(_map, _colours)
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			image.set_pixel(x, y, cells[y * width + x])
	_texture = ImageTexture.create_from_image(image)


## Where the map sits in the view and its whole-number scale: {scale, origin}.
func _layout() -> Dictionary:
	var size := Vector2i(int(_map.get("width", 0)), int(_map.get("height", 0)))
	var pixel := scale_for(_view.size, size)
	var origin := ((_view.size - Vector2(size * pixel)) / 2.0).floor()
	return {"scale": pixel, "origin": origin}


func _draw_view() -> void:
	if _texture == null:
		return
	var placed := _layout()
	var pixel := float(placed.scale)
	var origin: Vector2 = placed.origin
	var width := float(_map.width)
	var height := float(_map.height)
	var edge := Rect2(origin, Vector2(width, height) * pixel)
	_view.draw_rect(edge.grow(3.0), Color(0, 0, 0, 0.55))
	_view.draw_texture_rect(_texture, edge, false)
	_view.draw_rect(edge.grow(3.0), UiTheme.AMBER_DIM, false, 2.0)
	var at := func(cell: Vector2i) -> Vector2: return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * pixel
	var mark := maxf(4.0, pixel * 0.7)
	for cell in _warps:
		_view.draw_rect(Rect2(at.call(cell) - Vector2(mark, mark) / 2.0, Vector2(mark, mark)), Minimap.DARK)
	var font := OverworldStyle.body_font(600)
	for place: Dictionary in _places:
		var words := Text.t(String(place.get("name", "")))
		if words == "":
			continue
		var middle := origin + (Vector2(float(place.get("x", 0)) + float(place.get("w", 0)) / 2.0, float(place.get("y", 0)) + float(place.get("h", 0)) / 2.0)) * pixel
		var size := font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE)
		var left := clampf(middle.x - size.x / 2.0, edge.position.x + 4.0, maxf(edge.end.x - size.x - 4.0, edge.position.x + 4.0))
		var base := Vector2(left, middle.y + size.y / 4.0)
		_view.draw_string_outline(font, base, words, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, 6, Color(0.05, 0.035, 0.025, 0.95))
		_view.draw_string(font, base, words, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, PauseMenu.INK)
	for cell in _people:
		var spot: Vector2 = at.call(cell)
		_view.draw_circle(spot, 6.0, Minimap.DARK)
		_view.draw_circle(spot, 4.5, Minimap.CREAM)
	if _pin != NONE:
		Minimap.draw_star(_view, at.call(_pin), 11.0)
	if _player != NONE:
		var spot: Vector2 = at.call(_player)
		if not Settings.reduced_motion:
			var phase := fmod(_time, 1.0)
			_view.draw_arc(spot, 7.0 + phase * 8.0, 0.0, TAU, 28, Color(UiTheme.AMBER, 0.8 * (1.0 - phase)), 2.0, true)
		_view.draw_circle(spot, 7.0, Minimap.DARK)
		_view.draw_circle(spot, 5.0, UiTheme.AMBER)


func _process(delta: float) -> void:
	if _open and not Settings.reduced_motion:
		_time += delta
		_view.queue_redraw()


# --- input --------------------------------------------------------------------------------------------------------


func _dim_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()


## While the map is open nothing reaches the town. Esc, M, or a pad's B or Start closes it.
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	var pad := event as InputEventJoypadButton
	var start := pad != null and (pad.button_index == JOY_BUTTON_START or pad.button_index == JOY_BUTTON_B)
	if event.is_action_pressed("ui_cancel") or start or (key != null and key.keycode == KEY_M):
		close()
