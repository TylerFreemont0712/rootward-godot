class_name GearArt
extends RefCounted
## The little gear Lanternroot draws for its parts (the part-built banner, the Workbench's cards and the Lantern Engine):
## a toothed wheel with a hole, drawn from polygons so it turns smoothly at any size. Lit it is amber with a soft glow;
## dim it is a dark outline. A socket is the empty place a missing part's gear will go.
##
##   GearArt.draw(canvas, centre, 30.0, angle, true)         # a lit gear
##   GearArt.draw_socket(canvas, centre, 30.0)                # an empty place

const TEETH := 10
const LIT_FILL := Color("#f2a541")
const LIT_EDGE := Color("#ffd58a")
const LIT_HOLE := Color("#3a2410")
const DIM_FILL := Color("#2a2119")
const DIM_EDGE := Color("#5a4630")
const DIM_HOLE := Color("#14100c")


## A gear of `radius` (to the tips of its teeth) centred on `centre`, turned by `angle` radians.
static func draw(canvas: CanvasItem, centre: Vector2, radius: float, angle: float, lit: bool, teeth := TEETH) -> void:
	if lit:
		canvas.draw_circle(centre, radius * 1.35, Color(UiTheme.AMBER, 0.10))
		canvas.draw_circle(centre, radius * 1.12, Color(UiTheme.AMBER, 0.14))
	var outline := outline_of(centre, radius, angle, teeth)
	var fill := LIT_FILL if lit else DIM_FILL
	var edge := LIT_EDGE if lit else DIM_EDGE
	canvas.draw_colored_polygon(outline, fill)
	var closed := outline.duplicate()
	closed.append(outline[0])
	canvas.draw_polyline(closed, edge, maxf(1.5, radius * 0.06), true)
	# A ring on the face and the hole at the hub.
	canvas.draw_arc(centre, radius * 0.56, 0.0, TAU, 32, Color(edge, 0.55 if lit else 0.5), maxf(1.0, radius * 0.05), true)
	canvas.draw_circle(centre, radius * 0.3, LIT_HOLE if lit else DIM_HOLE)
	canvas.draw_arc(centre, radius * 0.3, 0.0, TAU, 24, edge, maxf(1.0, radius * 0.05), true)
	if lit:
		# A glint on one tooth side so the turning shows.
		canvas.draw_arc(centre, radius * 0.72, angle - 0.9, angle - 0.4, 8, Color(1, 1, 1, 0.35), maxf(1.5, radius * 0.07), true)


## The gear's outline: `teeth` trapezoids around a root circle.
static func outline_of(centre: Vector2, radius: float, angle: float, teeth := TEETH) -> PackedVector2Array:
	var points := PackedVector2Array()
	var root := radius * 0.78
	var step := TAU / teeth
	for i in teeth:
		var middle := angle + step * i
		for part: Array in [[-0.5, root], [-0.3, radius], [0.3, radius], [0.5, root]]:
			points.append(centre + Vector2.from_angle(middle + step * float(part[0])) * float(part[1]))
	return points


## An empty place for a gear: a dashed ring and a small hub.
static func draw_socket(canvas: CanvasItem, centre: Vector2, radius: float) -> void:
	var segments := 14
	for i in segments:
		var from := TAU * i / segments
		canvas.draw_arc(centre, radius * 0.88, from, from + TAU / segments * 0.55, 6, DIM_EDGE, maxf(1.5, radius * 0.06), true)
	canvas.draw_circle(centre, radius * 0.16, DIM_EDGE)
