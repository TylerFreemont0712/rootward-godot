class_name MapMarkers
extends RefCounted
## The map's markers and paths, drawn onto any CanvasItem (the map, its legend, the guardian rail). Each kind of room
## has an outline of its own as well as a hue of its own (UiTheme.ROOMS), so kinds stay apart at a glance, in the
## legend, and for eyes that mix up colours.
##
##   MapMarkers.draw_room(canvas, "elite", Vector2(40, 40), 30.0, 1.0, icon)

## Per kind: [corners, depth of a star's valleys (1 = none), turn in radians, size against a circle of the radius].
const SHAPES := {
	"fight": [28, 1.0, 0.0, 1.0],
	"elite": [8, 0.76, PI / 8.0, 1.14],
	"rest": [4, 1.0, 0.0, 1.2],
	"forge": [6, 1.0, PI / 6.0, 1.06],
	"treasure": [4, 1.0, PI / 4.0, 1.16],
	"boss": [14, 0.84, 0.0, 1.0],
}
const DIMMED := Color(0.42, 0.38, 0.35, 0.6)


static func outline(kind: String, at: Vector2, radius: float) -> PackedVector2Array:
	var spec: Array = SHAPES.get(kind, SHAPES.fight)
	var valleys: float = spec[1]
	var count: int = int(spec[0]) * (2 if valleys < 1.0 else 1)
	var points := PackedVector2Array()
	for i in count:
		var reach: float = radius * float(spec[3]) * (valleys if i % 2 == 1 and valleys < 1.0 else 1.0)
		var angle: float = float(spec[2]) - PI / 2.0 + TAU * i / count
		points.append(at + Vector2.from_angle(angle) * reach)
	return points


## A room: its outline filled dark in its hue, a rim, and its icon. `lit` runs from 0 (out of reach) to 1 (live).
static func draw_room(
	canvas: CanvasItem, kind: String, at: Vector2, radius: float, lit: float, icon: Texture2D
) -> void:
	var hue := UiTheme.room(kind).lerp(UiTheme.FAINT, 1.0 - lit)
	var shape := outline(kind, at, radius)
	canvas.draw_colored_polygon(_moved(shape, Vector2(3, 5)), Color(0, 0, 0, 0.3 + 0.25 * lit))
	canvas.draw_colored_polygon(shape, UiTheme.GROUND.lerp(hue, 0.14 + 0.16 * lit))
	_ring(canvas, outline(kind, at, radius - 6.0), Color(hue, 0.4 * lit), 1.5)
	_ring(canvas, shape, hue, 3.0)
	if icon == null:
		canvas.draw_circle(at, radius * 0.3, hue)
		return
	var side := radius * 1.3
	var tint := Color.WHITE.lerp(DIMMED, 1.0 - lit)
	canvas.draw_texture_rect(icon, Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side)), false, tint)


## A guardian: a crowned disc with its portrait inside. `lit` as for a room; `glow` (0 to 1) a halo around it.
static func draw_guardian(
	canvas: CanvasItem, at: Vector2, radius: float, portrait: Texture2D, lit: float, glow := 0.0
) -> void:
	var hue := UiTheme.room("boss").lerp(UiTheme.FAINT, 1.0 - lit)
	if glow > 0.0:
		canvas.draw_circle(at, radius * 1.3 + 8.0 * glow, Color(hue, 0.08 + 0.1 * glow))
	var crown := outline("boss", at, radius * 1.18)
	canvas.draw_colored_polygon(_moved(crown, Vector2(4, 6)), Color(0, 0, 0, 0.5))
	canvas.draw_colored_polygon(crown, hue.darkened(0.6))
	_ring(canvas, crown, hue, 2.5)
	canvas.draw_circle(at, radius, UiTheme.GROUND.lerp(hue, 0.14))
	canvas.draw_arc(at, radius, 0.0, TAU, 64, hue, 3.0, true)
	canvas.draw_arc(at, radius - 7.0, 0.0, TAU, 64, Color(hue, 0.35), 1.5, true)
	if portrait == null:
		canvas.draw_circle(at, radius * 0.3, hue)
		return
	var box := Vector2(radius, radius) * 1.5
	var picture := portrait.get_size()
	var fit := picture * minf(box.x / picture.x, box.y / picture.y)
	var tint := Color.WHITE.lerp(Color(0.26, 0.23, 0.22), 1.0 - lit)
	canvas.draw_texture_rect(portrait, Rect2(at - fit * 0.5, fit), false, tint)


## A tick in a small disc, for a room walked through or a guardian beaten.
static func draw_tick(canvas: CanvasItem, at: Vector2, radius: float) -> void:
	canvas.draw_circle(at, radius + 2.0, Color(0, 0, 0, 0.6))
	canvas.draw_circle(at, radius, UiTheme.TEAL.darkened(0.45))
	var tick := PackedVector2Array(
		[at + Vector2(-0.5, 0.0) * radius, at + Vector2(-0.1, 0.4) * radius, at + Vector2(0.5, -0.35) * radius]
	)
	canvas.draw_polyline(tick, UiTheme.TEXT, maxf(2.0, radius * 0.28), true)


## Dots from `from` to `to`, stopping `trims.x` and `trims.y` short of the ends so they meet the markers' rims.
## `phase` slides every dot along its gap, which reads as the path flowing where it leads.
static func draw_path(
	canvas: CanvasItem, from: Vector2, to: Vector2, colour: Color, dot: float, gap: float, trims: Vector2, phase := 0.0
) -> void:
	draw_trail(canvas, PackedVector2Array([from, to]), colour, dot, gap, trims, phase)


## Dots along a polyline (a winding path), spaced `gap` apart by distance along it; trims and phase as draw_path.
static func draw_trail(
	canvas: CanvasItem, points: PackedVector2Array, colour: Color, dot: float, gap: float, trims: Vector2, phase := 0.0
) -> void:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var end := total - trims.y
	var along := trims.x + fposmod(phase, 1.0) * gap
	var walked := 0.0
	var segment := 0
	while along <= end and segment < points.size() - 1:
		var length := points[segment].distance_to(points[segment + 1])
		if along > walked + length:
			walked += length
			segment += 1
			continue
		var t := (along - walked) / maxf(length, 0.001)
		canvas.draw_circle(points[segment].lerp(points[segment + 1], t), dot, colour, true, -1.0, true)
		along += gap


## A path that snakes from one point to another: a sideways wave of `amplitude` pixels, `waves` half-turns long,
## fading out at both ends so it still meets each marker head-on.
static func winding(from: Vector2, to: Vector2, amplitude: float, waves: float, steps := 24) -> PackedVector2Array:
	var across := (to - from).orthogonal().normalized()
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		points.append(from.lerp(to, t) + across * amplitude * sin(t * PI * waves) * sin(t * PI))
	return points


static func _ring(canvas: CanvasItem, points: PackedVector2Array, colour: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, colour, width, true)


static func _moved(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + by)
	return moved
