class_name RuneGlyphs
extends RefCounted
## Runes drawn as strokes, so they never depend on a font having the characters: twenty-three angular glyphs in the
## spirit of the old futhark, each a few polylines in a box a half unit wide and two tall, y up the glyph's height.
## Set on a ring, a glyph stands radially, its top toward the rim.

const COUNT := 23
const _GLYPHS: Array = [
	[[[0, -1], [0, 1]], [[0, -0.4], [0.5, -0.9]], [[0, 0.1], [0.5, -0.4]]],
	[[[-0.4, 1], [-0.4, -1], [0.4, -0.4], [0.4, 1]]],
	[[[0, -1], [0, 1]], [[0, -0.5], [0.5, 0], [0, 0.5]]],
	[[[0, -1], [0, 1]], [[0, -1], [0.5, -0.5]], [[0, -0.4], [0.5, 0.1]]],
	[[[-0.4, 1], [-0.4, -1], [0.3, -0.5], [-0.4, 0]], [[-0.4, 0], [0.4, 1]]],
	[[[0.4, -0.8], [-0.3, 0], [0.4, 0.8]]],
	[[[-0.4, -0.9], [0.4, 0.9]], [[0.4, -0.9], [-0.4, 0.9]]],
	[[[-0.2, -1], [-0.2, 1]], [[-0.2, -1], [0.4, -0.5], [-0.2, 0]]],
	[[[-0.4, -1], [-0.4, 1]], [[0.4, -1], [0.4, 1]], [[-0.4, -0.4], [0.4, 0.4]]],
	[[[0, -1], [0, 1]], [[-0.4, -0.3], [0.4, 0.3]]],
	[[[0, -1], [0, 1]], [[-0.2, -1], [0.2, -1]]],
	[[[-0.1, -0.9], [-0.4, -0.4], [0.1, 0]], [[0.1, 0], [0.4, 0.4], [-0.1, 0.9]]],
	[[[0, -1], [0, 1]], [[0, -1], [0.4, -0.6]], [[0, 1], [-0.4, 0.6]]],
	[[[-0.4, -1], [-0.4, 1]], [[-0.4, -1], [0.4, -0.5], [-0.4, 0]], [[-0.4, 0], [0.4, 0.5], [-0.4, 1]]],
	[[[0, -1], [0, 1]], [[-0.5, -0.5], [0, 0], [0.5, -0.5]]],
	[[[0.4, -1], [-0.3, -0.4], [0.3, 0.4], [-0.4, 1]]],
	[[[0, -1], [0, 1]], [[-0.4, -0.5], [0, -1], [0.4, -0.5]]],
	[[[-0.4, -1], [-0.4, 1]], [[-0.4, -1], [0.3, -0.5], [-0.4, 0], [0.3, 0.5], [-0.4, 1]]],
	[[[-0.4, -1], [-0.4, 1]], [[0.4, -1], [0.4, 1]], [[-0.4, -1], [0, -0.3], [0.4, -1]]],
	[[[0, -1], [0, 1]], [[0, -1], [0.45, -0.5]]],
	[[[0, -1], [0.4, 0], [0, 1], [-0.4, 0], [0, -1]]],
	[[[-0.4, -0.9], [-0.4, 0.9], [0.4, -0.9], [0.4, 0.9], [-0.4, -0.9]]],
	[[[0, -0.9], [0.4, -0.2], [0, 0.3], [-0.4, -0.2], [0, -0.9]], [[-0.4, 0.9], [0, 0.3], [0.4, 0.9]]],
]


## The strokes of glyph `which` (any integer; it wraps), as unit-box polylines.
static func strokes(which: int) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	for line: Array in _GLYPHS[posmod(which, COUNT)]:
		var points := PackedVector2Array()
		for point: Array in line:
			points.append(Vector2(float(point[0]), float(point[1])))
		found.append(points)
	return found


## Draws glyph `which` centred at `at`, `height` tall, its top turned to `angle` (radians from straight up), as a
## soft halo under a bright line.
static func draw(
	canvas: CanvasItem, which: int, at: Vector2, angle: float, height: float, halo: Color, line: Color, width: float
) -> void:
	for stroke in strokes(which):
		var placed := PackedVector2Array()
		for point in stroke:
			placed.append(at + Vector2(point.x * height * 0.5, point.y * height * 0.5).rotated(angle))
		canvas.draw_polyline(placed, halo, width * 2.6, true)
		canvas.draw_polyline(placed, line, width, true)
