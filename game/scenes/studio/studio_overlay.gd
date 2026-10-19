class_name StudioOverlay
extends Node2D
## Lanternroot Studio's overlays (ADR-0066), drawn in world pixels inside the PixelView's viewport, above the town: the
## grid, every object's footprint, solid cells, doors and warps with the name of where they lead, a label for what is
## under the cursor, the player's ring, and the selection's outline. Each of the first six is a switch in `options`;
## with all of them off, and nothing selected or hovered, nothing is drawn and the picture is the play view.
##
## The grid, footprints, solid cells and door markers sit still in the world, so they are drawn once, on a layer
## behind this node, and the GPU pans them; only the hover, the selection and the labels (which depend on the zoom)
## are drawn again as the mouse moves.

const TILE := OverworldScale.TILE
const GRID := Color(1, 1, 1, 0.16)
const GRID_MAJOR := Color(1, 1, 1, 0.34)
const SOLID_TINT := Color(0.9, 0.18, 0.15, 0.34)
const DOOR := Color("#5cc8b8")
const SHUT_DOOR := Color(0.75, 0.7, 0.6, 0.7)
const SELECTION := Color("#f2a541")
const FITS := Color("#5fd36f")
const CLASHES := Color("#e2584f")
const FOOTPRINT_SELECTED := Color("#5cc8b8")
const TALK := Color("#e9c46a")
const WIRE := Color("#7fd3ff")
const KINDS := {
	"building": Color("#f2a541"),
	"prop": Color("#e9dcc0"),
	"sign": Color("#e9c46a"),
	"person": Color("#8bc96a"),
	"warp": Color("#5cc8b8"),
}
## The size of the labels in the pictures that reach the screen (viewport pixels), whatever the zoom.
const LABEL_SIZE := 10

var options: Dictionary = {}
var map: Dictionary = {}
## Map id -> the name shown for it, for the doors' labels.
var names: Dictionary = {}
## Townsperson id -> their talk id, for the overlay of talk links (S7).
var talks: Dictionary = {}
## Structured authored entrances, including invalid destinations omitted by the compiled warp dictionary.
var entrances: Array[Dictionary] = []
## The camera's zoom: how many viewport pixels one world pixel takes. Lines are one viewport pixel wide at any zoom.
var zoom := 1.0
var hover_cell := Vector2i.ZERO
var hover_cell_shown := false
var hover_label := ""
var hover_point := Vector2.ZERO
## The cells and the drawn pictures of everything selected, in world pixels.
var selected_footprints: Array[Rect2] = []
var selected_pictures: Array[Rect2] = []
## What is being moved or placed: {footprint: Rect2, ok: bool, parts: StudioGhost.parts} each. Green where it fits.
var ghosts: Array[Dictionary] = []
## The selection rectangle (world pixels), or an empty Rect2; matched footprints preview explicit area selection.
var box := Rect2()
var area_footprints: Array[Rect2] = []
var box_count := -1
## The selected thing's handles (world rectangles): its footprint's, dragged to remake it at another size, and a
## building's door, a bar dragged along its bottom row.
var handles: Array[Rect2] = []
## Where a dragged door or start flag would go now ((-1, -1) when none is dragged).
var door_drag := Vector2i(-1, -1)
var start_drag := Vector2i(-1, -1)
## The footprints of things waiting for their remake: hatched, so a placeholder never passes for the real picture.
var remaking_boxes: Array[Rect2] = []
## The Land tab's brush under the cursor (world pixels; empty for none), outlined in the colour of its ground.
var brush := Rect2()
var brush_colour := Color.WHITE
## Persistent link markers remain visible independently of the general overlay switches.
var link_source := Vector2i(-1, -1)
var link_arrival := Vector2i(-1, -1)
var link_facing := "down"
var player_feet := Vector2.ZERO

var _layer: _Layer


func _init() -> void:
	name = "StudioOverlay"
	_layer = _Layer.new(self)
	_layer.show_behind_parent = true
	add_child(_layer)


func set_map(shown: Dictionary, map_names: Dictionary, entrance_rows: Array[Dictionary] = []) -> void:
	map = shown
	names = map_names
	entrances = entrance_rows
	redraw_all()


func set_zoom(value: float) -> void:
	if is_equal_approx(zoom, value):
		return
	zoom = value
	redraw_all()


func set_options(value: Dictionary) -> void:
	options = value
	redraw_all()


func redraw_all() -> void:
	_layer.queue_redraw()
	queue_redraw()


## One viewport pixel in world pixels.
func pixel() -> float:
	return 1.0 / maxf(zoom, 0.01)


func enabled(option: String) -> bool:
	return bool(options.get(option, false))


# --- the part that moves with the mouse and the selection --------------------------------------------------------


func _draw() -> void:
	var px := pixel()
	if link_source.x >= 0:
		var source := Rect2(Vector2(link_source) * TILE, Vector2.ONE * TILE)
		_outline(self, source, SELECTION, px * 3.0)
		_label(source.position + Vector2(0, -6) * px, StudioText.t("link_source_marker"), SELECTION)
	if link_arrival.x >= 0:
		var arrival := Rect2(Vector2(link_arrival) * TILE, Vector2.ONE * TILE)
		draw_rect(arrival, Color(DOOR, 0.25))
		_outline(self, arrival, DOOR, px * 3.0)
		var way := Vector2(BootsRules.STEPS.get(link_facing, Vector2i.DOWN))
		var side := Vector2(-way.y, way.x)
		var centre := arrival.get_center()
		draw_colored_polygon(PackedVector2Array([
			centre + way * 12, centre - way * 8 + side * 8, centre - way * 8 - side * 8,
		]), DOOR)
		_label(arrival.position + Vector2(0, -6) * px, StudioText.t("link_arrival_marker"), DOOR)
	if enabled("grid") and hover_cell_shown:
		var cell := Rect2(Vector2(hover_cell) * TILE, Vector2.ONE * TILE)
		draw_rect(Rect2(cell.position, cell.size).grow(-px), Color(1, 1, 1, 0.14))
		_outline(self, cell, Color(1, 1, 1, 0.95), px * 2.0)
	for footprint: Rect2 in selected_footprints:
		draw_rect(footprint, Color(FOOTPRINT_SELECTED, 0.2))
		_outline(self, footprint, FOOTPRINT_SELECTED, px * 2.0)
	for picture: Rect2 in selected_pictures:
		_outline(self, picture.grow(px), SELECTION, px * 2.0)
	for waiting: Rect2 in remaking_boxes:
		_hatch(waiting, px)
	for handle: Rect2 in handles:
		draw_rect(handle, Color("#1a1410"))
		draw_rect(handle.grow(-px), SELECTION)
	for ghost: Dictionary in ghosts:
		_ghost(ghost, px)
	if door_drag.x >= 0:
		var door := door_rect(door_drag)
		draw_rect(Rect2(Vector2(door_drag) * TILE, Vector2.ONE * TILE), Color(DOOR, 0.3))
		draw_rect(door, Color("#1a1410"))
		draw_rect(door.grow(-px), DOOR)
	if enabled("doors") and not map.is_empty():
		_start_flag(start_drag if start_drag.x >= 0 else map.get("start", Vector2i.ZERO), String(map.get("facing", "down")), px)
	if brush.has_area():
		_outline(self, brush.grow(px), Color("#1a1410"), px * 3.0)
		_outline(self, brush, brush_colour.lightened(0.25), px * 2.0)
	if box.has_area():
		for footprint: Rect2 in area_footprints:
			draw_rect(footprint, Color(FOOTPRINT_SELECTED, 0.28))
			_outline(self, footprint, FOOTPRINT_SELECTED, px * 2.0)
		draw_rect(box, Color(SELECTION, 0.14))
		_outline(self, box, SELECTION, px * 2.0)
		if box_count >= 0:
			_label(box.position + Vector2(4, -8) * px, StudioText.t("area_count") % box_count, SELECTION)
	if enabled("doors"):
		_door_labels()
	if enabled("talk"):
		_talk_labels()
	if enabled("player"):
		draw_set_transform(player_feet + Vector2(0, -2), 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 32, Color(DOOR, 0.95), px * 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if enabled("labels") and hover_label != "":
		_label(hover_point + Vector2(10, -12) * px, hover_label, Color("#e9dcc0"))


## Diagonal stripes over a footprint: "remaking", until the remake's own picture is drawn.
func _hatch(area: Rect2, px: float) -> void:
	_outline(self, area, Color(SELECTION, 0.9), px * 2.0)
	var width := area.size.x
	var height := area.size.y
	var offset := -height
	# Each stripe is the points (offset + t, height - t), t from 0 to height, cut to the box's sides.
	while offset < width:
		var first := maxf(0.0, -offset)
		var last := minf(height, width - offset)
		if last > first:
			var from := area.position + Vector2(offset + first, height - first)
			var to := area.position + Vector2(offset + last, height - last)
			# A negative width is the hairline primitive: one pixel whatever the zoom, so a diagonal never vanishes.
			draw_line(from, to, Color(SELECTION, 0.75), -1.0)
		offset += 8.0 * px


## A thing picked up or about to be put down: its picture half see-through, its cells green (it fits) or red (it does not).
func _ghost(ghost: Dictionary, px: float) -> void:
	var colour := FITS if bool(ghost.ok) else CLASHES
	for part: Dictionary in ghost.get("parts", []):
		var rect: Rect2 = part.rect
		if part.has("texture"):
			if bool(part.flip):
				draw_set_transform(Vector2(rect.end.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
				draw_texture_rect_region(part.texture, Rect2(Vector2.ZERO, rect.size), part.region, Color(1, 1, 1, 0.62))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect_region(part.texture, rect, part.region, Color(1, 1, 1, 0.62))
		else:
			draw_rect(rect, Color(colour, 0.3))
	var footprint: Rect2 = ghost.footprint
	draw_rect(footprint, Color(colour, 0.34))
	_outline(self, footprint, colour, px * 2.0)


## The cells of the start flag's handle, in world pixels: the flag in the upper left of the start cell.
static func flag_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * TILE + Vector2(2, 2), Vector2(18, 22))


## A door's handle: a bar along the bottom of its cell, to drag along the building's bottom row.
static func door_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * TILE + Vector2(6, TILE - 9), Vector2(TILE - 12, 7))


## The map's start: its cell outlined in amber, a small flag on a pole at the cell's left edge, and an arrow in the
## bottom right corner the way the player faces there. No label: the player often stands on it in Edit.
func _start_flag(cell: Vector2i, facing: String, px: float) -> void:
	var corner := Vector2(cell) * TILE
	var area := Rect2(corner, Vector2.ONE * TILE)
	_outline(self, area.grow(-px), Color("#1a1410"), px * 3.0)
	_outline(self, area.grow(-px), SELECTION, px * 1.5)
	var pole := corner + Vector2(6, 4)
	draw_line(pole, pole + Vector2(0, TILE - 9), Color("#1a1410"), px * 4.0)
	draw_line(pole, pole + Vector2(0, TILE - 9), Color("#e9dcc0"), px * 2.0)
	var flag := PackedVector2Array([pole + Vector2(1, 0), pole + Vector2(14, 5), pole + Vector2(1, 10)])
	draw_colored_polygon(flag, SELECTION)
	draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), Color("#1a1410"), px)
	var way := Vector2(BootsRules.STEPS.get(facing, Vector2i.DOWN))
	var centre := corner + Vector2(TILE - 9, TILE - 9)
	var side := Vector2(-way.y, way.x)
	var arrow := PackedVector2Array([centre + way * 5.0, centre - way * 3.0 + side * 4.0, centre - way * 3.0 - side * 4.0])
	draw_colored_polygon(arrow, SELECTION)
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color("#1a1410"), px)


## Who talks with which talk file, and which things read one: a label over each person and each thing with `talk`.
## Things that answer on_step (plates, triggers) are marked, and each thing's links are drawn as wires to the things
## they reach (Studio S8).
func _talk_labels() -> void:
	var px := pixel()
	var by_id := {}
	for object: Dictionary in map.get("objects", []):
		if String(object.get("id", "")) != "":
			by_id[String(object.id)] = object
	for object: Dictionary in map.get("objects", []):
		var at: Vector2i = object.get("at", Vector2i.ZERO)
		var size: Vector2i = object.get("size", Vector2i.ONE)
		var middle := (Vector2(at) + Vector2(size) / 2.0) * TILE
		for target: String in TownWires.links_of(object):
			if by_id.has(target):
				var other: Dictionary = by_id[target]
				var there := (Vector2(other.get("at", Vector2i.ZERO)) + Vector2(other.get("size", Vector2i.ONE)) / 2.0) * TILE
				draw_dashed_line(middle, there, Color("#1a1410"), px * 4.0, 7.0 * px)
				draw_dashed_line(middle, there, WIRE, px * 2.0, 7.0 * px)
				draw_circle(there, 4.0 * px, WIRE)
		if TownWires.hook_of(object) == "on_step":
			var area := Rect2(Vector2(at) * TILE, Vector2(size) * TILE)
			_outline(self, area.grow(-px * 2.0), WIRE, px * 2.0)
			_label(Vector2(at) * TILE + Vector2(size.x * TILE / 2.0, -4.0 * px), "step: " + String(object.get("id", "")), WIRE, true)
	for object: Dictionary in map.get("objects", []):
		var talk := String(object.get("talk", ""))
		if String(object.get("kind", "")) == "person":
			talk = String(talks.get(String(object.get("id", "")), object.get("id", "")))
		if talk == "":
			continue
		var at: Vector2i = object.get("at", Vector2i.ZERO)
		var top := 2.4 if String(object.get("kind", "")) == "person" else 0.0
		_label(Vector2(at) * TILE + Vector2(TILE / 2.0, -top * TILE - 4.0 * pixel()), "talk: " + talk, TALK, true)


## Each door's and warp's label says where it leads, over its cell; under it when the cell above is the start (a
## room's doormat), so the label never hides the start.
func _door_labels() -> void:
	if not entrances.is_empty():
		for entrance: Dictionary in entrances:
			var state := String(entrance.state)
			var target: Dictionary = entrance.target
			var problem := not (entrance.problem as Dictionary).is_empty()
			var label := StudioText.t("people_link_state_" + state)
			if not target.is_empty():
				var target_cell := OverworldMap.cell_of(target.get("at", [0, 0]))
				label += " · " + StudioText.f("people_location_line", [
					String(names.get(String(target.get("map", "")), target.get("map", ""))), target_cell.x, target_cell.y])
			var at := Vector2(entrance.cell) * TILE + Vector2(TILE / 2.0, -4.0 * pixel())
			if (entrance.cell as Vector2i) + Vector2i.UP == map.get("start", Vector2i(-1, -1)):
				at.y = (entrance.cell.y + 1) * TILE + (LABEL_SIZE + 6.0) * pixel()
			_label(at,
				("! " if problem else "") + label, CLASHES if problem else SHUT_DOOR if state == "closed" else DOOR, true)
		return
	var warps: Dictionary = map.get("warps", {})
	var start: Vector2i = map.get("start", Vector2i(-1, -1))
	for cell: Vector2i in warps:
		var target: Dictionary = warps[cell]
		var shown := String(names.get(String(target.map), target.map))
		var at := Vector2(cell) * TILE + Vector2(TILE / 2.0, -4.0 * pixel())
		if cell + Vector2i.UP == start:
			at.y = (cell.y + 1) * TILE + (LABEL_SIZE + 6.0) * pixel()
		_label(at, "to " + shown, DOOR, true)


## A label whose letters are LABEL_SIZE viewport pixels tall at any zoom, on a dark plate. `centred` puts the text's
## middle on x.
func _label(at: Vector2, text: String, colour: Color, centred := false) -> void:
	var font := UiTheme.ui_font(600)
	var size := maxi(1, roundi(LABEL_SIZE * pixel()))
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pad := 3.0 * pixel()
	var origin := at - Vector2(extent.x / 2.0 if centred else 0.0, 0.0)
	var plate := Rect2(origin - Vector2(pad, extent.y - pad * 0.6), extent + Vector2(pad * 2.0, pad * 1.4))
	draw_rect(plate, Color(0.07, 0.055, 0.045, 0.94))
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


static func _outline(canvas: CanvasItem, rect: Rect2, colour: Color, width: float) -> void:
	var inner := rect.grow(-width / 2.0)
	canvas.draw_rect(inner, colour, false, width)


# --- the part that stays still: drawn once on a layer behind this node --------------------------------------------


class _Layer:
	extends Node2D
	var _overlay: StudioOverlay

	func _init(overlay: StudioOverlay) -> void:
		name = "Fixed"
		_overlay = overlay

	func _draw() -> void:
		var o := _overlay
		if o.map.is_empty():
			return
		var px := o.pixel()
		var cells := Vector2(int(o.map.width), int(o.map.height))
		if o.enabled("solid"):
			for cell: Vector2i in o.map.solid:
				draw_rect(Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE), SOLID_TINT)
		if o.enabled("footprints"):
			for object: Dictionary in o.map.objects:
				var box := StudioPick.footprint(object)
				var colour: Color = KINDS.get(String(object.get("kind", "")), Color.WHITE)
				_dotted(Rect2(Vector2(box.position) * TILE, Vector2(box.size) * TILE), Color(colour, 0.9), px)
		if o.enabled("grid"):
			for x: int in range(0, int(cells.x) + 1):
				var strong := x % 8 == 0
				draw_rect(Rect2(x * TILE - px / 2.0, 0, px, cells.y * TILE), GRID_MAJOR if strong else GRID)
			for y: int in range(0, int(cells.y) + 1):
				var strong := y % 8 == 0
				draw_rect(Rect2(0, y * TILE - px / 2.0, cells.x * TILE, px), GRID_MAJOR if strong else GRID)
		if o.enabled("doors"):
			_doors(px)

	func _doors(px: float) -> void:
		if not _overlay.entrances.is_empty():
			for entrance: Dictionary in _overlay.entrances:
				var rect := Rect2(Vector2(entrance.cell) * TILE, Vector2.ONE * TILE)
				var state := String(entrance.state)
				if state == "closed":
					_dotted(rect.grow(-px * 2.0), SHUT_DOOR, px)
				elif not (entrance.problem as Dictionary).is_empty():
					StudioOverlay._outline(self, rect, CLASHES, px * 2.0)
					draw_line(rect.position, rect.end, CLASHES, px * 2.0)
					draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), CLASHES, px * 2.0)
				else:
					draw_rect(rect, Color(DOOR, 0.22))
					StudioOverlay._outline(self, rect, DOOR, px * 2.0)
					_arrow(rect, String((entrance.target as Dictionary).get("facing", "down")), px)
			return
		for object: Dictionary in _overlay.map.get("objects", []):
			if String(object.get("kind", "")) == "building" and not object.has("to"):
				var shut := Rect2(Vector2(object.door_cell) * TILE, Vector2.ONE * TILE)
				_dotted(shut.grow(-px * 2.0), SHUT_DOOR, px)
		var warps: Dictionary = _overlay.map.get("warps", {})
		for cell: Vector2i in warps:
			var rect := Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE)
			draw_rect(rect, Color(DOOR, 0.22))
			StudioOverlay._outline(self, rect, DOOR, px * 2.0)
			_arrow(rect, String((warps[cell] as Dictionary).facing), px)

	## A small triangle in the cell, pointing the way you face after stepping through.
	func _arrow(rect: Rect2, facing: String, px: float) -> void:
		var way := Vector2(BootsRules.STEPS.get(facing, Vector2i.ZERO))
		if way == Vector2.ZERO:
			way = Vector2(0, 1)
		var centre := rect.get_center()
		var side := Vector2(-way.y, way.x)
		var points := PackedVector2Array(
			[centre + way * 9.0, centre - way * 6.0 + side * 7.0, centre - way * 6.0 - side * 7.0]
		)
		draw_colored_polygon(points, Color(DOOR, 0.95))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0.05, 0.1, 0.1), px)

	func _dotted(rect: Rect2, colour: Color, px: float) -> void:
		var inner := rect.grow(-px / 2.0)
		var corners := [
			inner.position,
			Vector2(inner.end.x, inner.position.y),
			inner.end,
			Vector2(inner.position.x, inner.end.y),
		]
		for i: int in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], colour, px, 4.0 * px)
