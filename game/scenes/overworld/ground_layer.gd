class_name GroundLayer
extends Node2D
## A map's ground (ADR-0061): grass (or a floor) under every cell, then each other ground on top as a dual grid, its
## tiles half a tile off the map's grid so each covers the corners of four cells (pipeline/pixel/terrain.py). Water
## ripples through its frames. Drawn once; only the water redraws as it ripples.

const TILE := 16
## Grounds drawn on top, in order: later ones cover earlier ones where they meet.
const OVERLAYS: Array[String] = ["flowers", "path", "cobble", "water"]
const RIPPLE := 0.45

var map: Dictionary = {}

var _texture: Texture2D
var _layout: Dictionary = {}
var _frame := 0
var _clock := 0.0
var _has_water := false


func show_map(shown: Dictionary) -> void:
	map = shown
	var art := OverworldArt.terrain()
	_texture = art.texture
	_layout = art.layout
	_has_water = (map.ground as PackedStringArray).has("water")
	queue_redraw()


func _process(delta: float) -> void:
	if not _has_water:
		return
	_clock += delta
	if _clock >= RIPPLE:
		_clock = 0.0
		_frame = (_frame + 1) % 3
		queue_redraw()


func _ground(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= int(map.width) or y >= int(map.height):
		return ""
	return (map.ground as PackedStringArray)[y * int(map.width) + x]


func _tile(row: int, column: int) -> Rect2:
	return Rect2(column * TILE, row * TILE, TILE, TILE)


func _draw() -> void:
	if map.is_empty():
		return
	if _texture == null or _layout.is_empty():
		_draw_plain()
		return
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
			draw_texture_rect_region(_texture, Rect2(x * TILE, y * TILE, TILE, TILE), _tile(row, variant))
	var overlays: Dictionary = _layout.get("overlay", {})
	for kind in OVERLAYS:
		if not overlays.has(kind) or not (map.ground as PackedStringArray).has(kind):
			continue
		var frames := int(overlays[kind].get("frames", 1))
		var row := int(overlays[kind].row) + (_frame % frames)
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
				var at := Rect2(vx * TILE - TILE / 2.0, vy * TILE - TILE / 2.0, TILE, TILE)
				draw_texture_rect_region(_texture, at, _tile(row, mask))


func _draw_plain() -> void:
	var colours := {"grass": "#86c45a", "path": "#dcb27c", "cobble": "#c2bab2", "water": "#4494d0", "floor": "#a8744a"}
	for y in int(map.height):
		for x in int(map.width):
			var colour := Color(String(colours.get(_ground(x, y), "#2a1d2b")))
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), colour)
