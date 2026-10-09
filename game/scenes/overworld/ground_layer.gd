class_name GroundLayer
extends Node2D
## A map's ground (ADR-0061): grass (or a floor) under every cell, then each other ground on top as a dual grid, its
## tiles half a tile off the map's grid so each covers the corners of four cells (pipeline/pixel/terrain.py). Water
## ripples through its frames. Baked once per map into one picture for each ripple frame (three while water shows), so
## a ripple swaps a picture instead of redrawing every tile.

const TILE := 16
## Grounds drawn on top, in order: later ones cover earlier ones where they meet.
const OVERLAYS: Array[String] = ["flowers", "path", "cobble", "water"]
const RIPPLE := 0.45
## The dual grid's tiles reach half a tile past the map's edges, so the pictures start that far out.
const MARGIN := TILE / 2
## The flat colour of each ground, drawn when the art is missing.
const PLAIN := {"grass": "#86c45a", "path": "#dcb27c", "cobble": "#c2bab2", "water": "#4494d0", "floor": "#a8744a"}

var map: Dictionary = {}

var _layout: Dictionary = {}
var _pictures: Array[Texture2D] = []
var _frame := 0
var _clock := 0.0


func show_map(shown: Dictionary) -> void:
	map = shown
	_pictures.clear()
	if not map.is_empty():
		var art := OverworldArt.terrain()
		_layout = art.layout
		_bake(art.texture as Texture2D)
	queue_redraw()


func _process(delta: float) -> void:
	if _pictures.size() < 2:
		return
	_clock += delta
	if _clock >= RIPPLE:
		_clock = 0.0
		_frame = (_frame + 1) % _pictures.size()
		queue_redraw()


func _ground(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= int(map.width) or y >= int(map.height):
		return ""
	return (map.ground as PackedStringArray)[y * int(map.width) + x]


func _tile(row: int, column: int) -> Rect2i:
	return Rect2i(column * TILE, row * TILE, TILE, TILE)


func _draw() -> void:
	if not _pictures.is_empty():
		draw_texture(_pictures[_frame % _pictures.size()], Vector2(-MARGIN, -MARGIN))


## Paints the whole ground into one picture per ripple frame: the same tiles, in the same order, that were drawn cell by
## cell before. Without the art, a flat block per cell.
# LEARN: Image.blend_rect alpha-blends like the canvas does, and the lint keeps every ground pixel fully opaque or fully
# clear, so a baked picture matches the tile-by-tile draw exactly. Then one texture draw replaces every tile draw.
func _bake(atlas: Texture2D) -> void:
	var source: Image = null
	if atlas != null and not _layout.is_empty():
		source = atlas.get_image()
	if source != null:
		source.convert(Image.FORMAT_RGBA8)
	var extent := Vector2i(int(map.width) + 1, int(map.height) + 1) * TILE
	var frames := _frame_count() if source != null else 1
	for frame in frames:
		var picture := Image.create_empty(extent.x, extent.y, false, Image.FORMAT_RGBA8)
		if source == null:
			_paint_plain(picture)
		else:
			_paint_ground(picture, source, frame)
		_pictures.append(ImageTexture.create_from_image(picture))


## One picture per frame of the most ripples a shown overlay has: three while there is water, otherwise one.
func _frame_count() -> int:
	var count := 1
	var overlays: Dictionary = _layout.get("overlay", {})
	for kind in OVERLAYS:
		if overlays.has(kind) and (map.ground as PackedStringArray).has(kind):
			count = maxi(count, int(overlays[kind].get("frames", 1)))
	return count


func _paint_ground(picture: Image, source: Image, frame: int) -> void:
	var base: Dictionary = _layout.get("base", {})
	var indoors := bool(map.get("interior", false))
	var under: Dictionary = base.get("floor" if indoors else "grass", {})
	for y in int(map.height):
		for x in int(map.width):
			var kind := _ground(x, y)
			var row := int(under.get("row", 0))
			var count := maxi(1, int(under.get("count", 1)))
			# Outdoors grass is under everything, so a path's rounded corners show grass. Indoors each cell is its own
			# base: floor, wall or the dark beyond the room.
			if indoors and base.has(kind):
				row = int(base[kind].row)
				count = int(base[kind].count)
			# A cell's variant comes from its place, so the same map always looks the same.
			var variant := (x * 7 + y * 13 + (x * y) % 5) % count
			picture.blend_rect(source, _tile(row, variant), Vector2i(x * TILE + MARGIN, y * TILE + MARGIN))
	var overlays: Dictionary = _layout.get("overlay", {})
	for kind in OVERLAYS:
		if not overlays.has(kind) or not (map.ground as PackedStringArray).has(kind):
			continue
		var frames := int(overlays[kind].get("frames", 1))
		var row := int(overlays[kind].row) + (frame % frames)
		for vy in int(map.height) + 1:
			for vx in int(map.width) + 1:
				var mask := (
					int(_ground(vx - 1, vy - 1) == kind)
					| int(_ground(vx, vy - 1) == kind) << 1
					| int(_ground(vx - 1, vy) == kind) << 2
					| int(_ground(vx, vy) == kind) << 3
				)
				if mask == 0:
					continue
				picture.blend_rect(source, _tile(row, mask), Vector2i(vx * TILE, vy * TILE))


func _paint_plain(picture: Image) -> void:
	for y in int(map.height):
		for x in int(map.width):
			var colour := Color(String(PLAIN.get(_ground(x, y), "#2a1d2b")))
			picture.fill_rect(Rect2i(x * TILE + MARGIN, y * TILE + MARGIN, TILE, TILE), colour)
