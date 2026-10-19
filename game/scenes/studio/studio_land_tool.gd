class_name StudioLandTool
extends RefCounted
## The Land tab's hand (Concept/v0.3/10, section 7.8): painting the ground with a brush of 1, 2, 3 or 5 cells, a line
## (Shift-drag with the brush), a rectangle, or a flood fill, in a ground of terrain.jsonc. A stroke shows as it goes:
## each step repaints only the cells round the ones it changed (TownMapView.paint_ground_cells, a millisecond or two),
## and when the button comes up the whole stroke is one command (StudioWork.paint), one undo step. Esc during a stroke
## puts the ground back. StudioLand works out the cells and the commands; this keeps what the hand is doing.

const TOOLS: Array[String] = ["brush", "rect", "fill"]
## Legacy catalogs without `paint` metadata keep their original tools. New surfaces are declared in terrain.jsonc.
const OUTDOOR: Array[String] = ["grass", "path", "cobble", "water", "flowers"]
const INDOOR: Array[String] = ["floor", "wall", "void"]

## The ground painted, the brush's size and the tool ("brush", "rect" or "fill").
var kind := "path"
var size := 1
var tool := "brush"
## What the button is doing: "" (nothing), "brush" (painting where it goes), "line" (Shift-drag) or "rect".
var mode := ""

var _studio: StudioMode
## The map as it was when the stroke began, and the one shown while it goes (its ground painted).
var _base: Dictionary = {}
var _preview: Dictionary = {}
## The brush's cells so far, in the order it reached them, and the same as a set.
var _painted: Array[Vector2i] = []
var _seen: Dictionary = {}
## The line's or the rectangle's cells now.
var _shape: Array[Vector2i] = []
var _start := Vector2i.ZERO
var _last := Vector2i.ZERO


func _init(studio: StudioMode) -> void:
	_studio = studio


## The grounds the Land shelf offers on the map shown.
func grounds() -> Array[String]:
	var place := "indoor" if bool(_studio.current_map().get("interior", false)) else "outdoor"
	var offered: Array[String] = []
	var terrain: Dictionary = _studio.catalog().get("terrain", {})
	for ground: String in terrain:
		if String((terrain[ground] as Dictionary).get("paint", "")) == place:
			offered.append(ground)
	return offered if not offered.is_empty() else (INDOOR if place == "indoor" else OUTDOOR)


## Keeps the chosen ground one the map offers (a room has no path, the town no wall).
func fit_to_map() -> void:
	if not kind in grounds():
		kind = grounds()[0]


## The button went down on `cell`; Shift with the brush draws a line.
func press(cell: Vector2i, shift: bool) -> void:
	cancel()
	if tool == "fill":
		_fill(cell)
		return
	_base = _studio.current_map()
	_preview = _base
	_start = cell
	_last = cell
	_painted = []
	_seen = {}
	_shape = []
	if tool == "rect":
		mode = "rect"
		_reshape(StudioLand.rect(cell, cell))
	elif shift:
		mode = "line"
		_reshape(StudioLand.stroke(cell, cell, size))
	else:
		mode = "brush"
		_stamp(StudioLand.brush(cell, size))
	_show_brush()


## The cursor moved (the Studio calls this whenever it looks at what is under the cursor).
func update() -> void:
	_show_brush()
	if mode == "":
		return
	var cell := _studio.cursor_cell()
	if cell == _last:
		return
	match mode:
		"brush":
			# Every cell between the last place and this one, so a quick stroke leaves no gaps.
			_stamp(StudioLand.stroke(_last, cell, size))
		"line":
			_reshape(StudioLand.stroke(_start, cell, size))
		"rect":
			_reshape(StudioLand.rect(_start, cell))
	_last = cell
	_show_brush()


## The button came up: the stroke becomes one change. False when it painted nothing (the ground goes back).
func release() -> bool:
	if mode == "":
		return false
	var cells: Array[Vector2i] = _painted if mode == "brush" else _shape
	var what := "Paint a line of %s" % kind if mode == "line" else ("Paint a rectangle of %s" % kind if mode == "rect" else "")
	mode = ""
	var done := bool(_studio.work.paint(cells, kind, what).ok)
	if not done:
		_restore()
	_base = {}
	_preview = {}
	_show_brush()
	return done


## Lets go of a stroke under way, and the ground goes back to the map's.
func cancel() -> void:
	if mode == "":
		return
	mode = ""
	_restore()
	_base = {}
	_preview = {}
	_show_brush()


## E: the ground under the cursor becomes the one painted, when the map offers it.
func eyedrop() -> String:
	var here := OverworldMap.terrain_at(_studio.current_map(), _studio.cursor_cell())
	if here in grounds():
		kind = here
	return kind


func _fill(cell: Vector2i) -> void:
	var rows: Array = _studio.work.doc().data.get("ground", [])
	var cells := StudioLand.fill(rows, cell)
	if cells.is_empty():
		return
	_studio.work.paint(cells, kind, "Fill with %s" % kind)


## Adds the brush's new cells to the stroke and shows them.
func _stamp(cells: Array[Vector2i]) -> void:
	var fresh: Array[Vector2i] = []
	for cell: Vector2i in StudioLand.clip(cells, OverworldMap.size_of(_base)):
		if not _seen.has(cell):
			_seen[cell] = true
			_painted.append(cell)
			fresh.append(cell)
	if not fresh.is_empty():
		_show(fresh, fresh)


## The line or the rectangle is now `cells`: the stroke's start shows again where it left, and the new cells painted.
func _reshape(cells: Array[Vector2i]) -> void:
	var clipped := StudioLand.clip(cells, OverworldMap.size_of(_base))
	var touched: Array[Vector2i] = _shape.duplicate()
	touched.append_array(clipped)
	_shape = clipped
	# The preview starts again from the map as it was, with the new shape on it.
	_preview = _base
	_show(clipped, touched)


## Shows the preview with `cells` painted, repainting `touched` (the cells that may look different now).
# LEARN: each step is a new Dictionary with a new ground array. The ground layer holds the one it last drew and compares
# against it; painting into that same Dictionary would leave nothing to compare, and the real map is never touched until
# the stroke ends as one command (docs/LEARNING_LOG.md, 2026-10-14).
func _show(cells: Array[Vector2i], touched: Array[Vector2i]) -> void:
	var next := _preview.duplicate()
	var ground: PackedStringArray = (_preview.ground as PackedStringArray).duplicate()
	var width := int(_base.width)
	for cell: Vector2i in cells:
		ground[cell.y * width + cell.x] = kind
	next["ground"] = ground
	_preview = next
	var t := Time.get_ticks_usec()
	if not _studio.map_view().paint_ground_cells(_preview, touched):
		# Water where there was none needs three ripple frames: the whole ground is baked once, then strokes are quick.
		_studio.map_view().ground.show_map(_preview)
	_studio.lap("land", t)


## The ground on screen goes back to the map's.
func _restore() -> void:
	var map := _studio.current_map()
	if not _studio.map_view().paint_ground(map):
		_studio.map_view().ground.show_map(map)


## The outline under the cursor: the brush's cells, or the cell a rectangle or a fill starts from.
func _show_brush() -> void:
	var overlay := _studio.overlay()
	if overlay == null:
		return
	if not _studio.land_tab() or not _studio.cursor_over_map():
		overlay.brush = Rect2()
	else:
		var side := size if tool == "brush" else 1
		var cell := _studio.cursor_cell()
		var cells := StudioLand.brush(cell, side)
		if mode == "rect":
			cells = [_start, cell] as Array[Vector2i]
		var box := Rect2i(cells[0], Vector2i.ONE)
		for one: Vector2i in cells:
			box = box.expand(one).expand(one + Vector2i.ONE)
		overlay.brush = Rect2(Vector2(box.position) * OverworldScale.TILE, Vector2(box.size) * OverworldScale.TILE)
		overlay.brush_colour = Color(String(GroundLayer.PLAIN.get(kind, "#e9dcc0")))
	overlay.queue_redraw()
