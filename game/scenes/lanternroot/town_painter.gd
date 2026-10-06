class_name LanternTownPainter
extends RefCounted
## How Lanternroot's pieces are drawn (ADR-0055): roots, rope bridges, houses, lanterns and gremlins, all from shapes,
## so the town needs no picture to exist (assets are optional). Each function draws onto the CanvasItem it is given,
## in that item's own coordinates.

const WOOD := Color("#3a2a1c")
const WOOD_DARK := Color("#24190f")
const ROOT := Color("#2a1d12")
const ROOT_LIGHT := Color("#4a3522")
const ROPE := Color("#8a6a44")
const GLOW := Color("#ffc46b")
const COLD := Color("#56606a")
const GREMLIN := Color("#2b1838")
const GREMLIN_EYE := Color("#ff4f6a")
const HOUSE_SIZE := Vector2(132, 86)

static var _glow: Texture2D


## A root hanging from the top edge down to `to`, thick at the top and tapering to a point, in a gentle S that sways
## with `sway`. `shade` 0 is a near root, 1 one far away in the dark.
static func root(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, sway: float, shade := 0.0) -> void:
	var steps := 20
	var centre := PackedVector2Array()
	var side := 1.0 if int(absf(from.x)) % 2 == 0 else -1.0
	for i in steps + 1:
		var t := float(i) / steps
		var bend := sin(t * TAU * 0.75) * (14.0 + width) * side
		centre.append(from.lerp(to, t) + Vector2(bend + sin(sway + t * 2.5) * 4.0 * t, 0))
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var w := lerpf(width, 0.6, pow(t, 0.8)) * 0.5
		var along := (centre[mini(i + 1, steps)] - centre[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-along.y, along.x)
		left.append(centre[i] + normal * w)
		right.append(centre[i] - normal * w)
	right.reverse()
	var body := left + right
	var colour := ROOT.lerp(Color("#140e09"), shade)
	canvas.draw_colored_polygon(body, colour)
	var light := PackedVector2Array()
	for i in steps - 2:
		light.append(left[i].lerp(centre[i], 0.4))
	canvas.draw_polyline(light, Color(ROOT_LIGHT, 0.8 * (1.0 - shade)), maxf(1.0, width * 0.12), true)


## A rope bridge sagging between two points, its planks every few steps; `lit` warms it, `pulse` (0-1) runs a glint
## along it from `a` to `b`, the direction the import points. `label` (the import line) sits on a dark tag mid-way.
static func bridge(
	canvas: CanvasItem, a: Vector2, b: Vector2, lit: bool, pulse: float, font: Font, label: String
) -> void:
	var sag := clampf(absf(b.x - a.x) * 0.16, 6.0, 70.0)
	var points := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / steps
		points.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * sag))
	var colour := ROPE if lit else ROPE.darkened(0.45)
	canvas.draw_polyline(points, colour, 2.0, true)
	canvas.draw_polyline(_offset(points, Vector2(0, 8)), colour.darkened(0.2), 1.5, true)
	for i in range(1, steps, 2):
		var p := points[i]
		canvas.draw_line(p, p + Vector2(0, 8), colour.darkened(0.1), 3.0)
	if lit:
		var at := points[int(clampf(pulse, 0.0, 1.0) * steps)]
		glow(canvas, at + Vector2(0, 4), 16.0, Color(GLOW, 0.8))
	if font != null and label != "":
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var middle := points[steps / 2] + Vector2(0, -14)
		var tag := Rect2(middle - Vector2(size.x / 2.0 + 8, size.y / 2.0 + 3), size + Vector2(16, 6))
		canvas.draw_rect(tag, Color(0.06, 0.045, 0.03, 0.85))
		canvas.draw_rect(tag, Color(colour, 0.6), false, 1.0)
		canvas.draw_string(
			font,
			Vector2(tag.position.x + 8, tag.position.y + 3 + size.y * 0.78),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			colour.lightened(0.3)
		)


## A house standing on its platform, centred on `at`, with a root hanging down to its roof. `glow` (0-1) is how much of
## it is lit, `hover` outlines it, `ghost` draws only a faint plan of a house not built yet.
static func house(
	canvas: CanvasItem, at: Vector2, roof: Color, glow_amount: float, hover: bool, ghost: bool, sway: float
) -> void:
	var size := HOUSE_SIZE
	var body := Rect2(at - Vector2(size.x / 2.0, size.y / 2.0), size)
	if ghost:
		_dashed_rect(canvas, body, Color(ROPE, 0.35))
		var tip := Vector2(at.x, body.position.y - 44)
		canvas.draw_polyline(
			PackedVector2Array([body.position, tip, body.position + Vector2(size.x, 0)]), Color(ROPE, 0.35), 1.5, true
		)
		return
	root(canvas, Vector2(at.x + 18, -20), Vector2(at.x + 6, body.position.y - 40), 7.0, sway)
	var platform := Rect2(body.position + Vector2(-22, size.y), Vector2(size.x + 44, 12))
	canvas.draw_rect(platform, WOOD_DARK)
	canvas.draw_rect(Rect2(platform.position, Vector2(platform.size.x, 3)), ROPE.darkened(0.3))
	for post: float in [platform.position.x + 10, platform.end.x - 14]:
		canvas.draw_line(Vector2(post, platform.end.y), Vector2(post - 6, platform.end.y + 28), WOOD_DARK, 4.0)
	if glow_amount > 0.0:
		glow(canvas, at + Vector2(0, 10), 150.0, Color(GLOW, 0.22 * glow_amount))
	canvas.draw_rect(body, WOOD)
	for i in range(1, 5):
		var y := body.position.y + size.y * i / 5.0
		canvas.draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), WOOD_DARK, 1.0)
	var roof_points := PackedVector2Array(
		[
			body.position + Vector2(-16, 4),
			Vector2(at.x, body.position.y - 48),
			body.position + Vector2(size.x + 16, 4),
		]
	)
	canvas.draw_colored_polygon(roof_points, roof.darkened(0.25))
	canvas.draw_polyline(roof_points, roof.lightened(0.15), 3.0, true)
	var door := Rect2(Vector2(at.x - 13, body.end.y - 40), Vector2(26, 40))
	canvas.draw_rect(door, WOOD_DARK)
	canvas.draw_circle(door.position + Vector2(20, 22), 2.0, ROPE)
	for side: int in [-1, 1]:
		var window := Rect2(Vector2(at.x + side * 40 - 12, body.position.y + 18), Vector2(24, 22))
		var light := COLD.darkened(0.5).lerp(GLOW, glow_amount)
		canvas.draw_rect(window, light)
		canvas.draw_line(window.get_center() - Vector2(0, 11), window.get_center() + Vector2(0, 11), WOOD_DARK, 2.0)
		canvas.draw_line(window.get_center() - Vector2(12, 0), window.get_center() + Vector2(12, 0), WOOD_DARK, 2.0)
	if hover:
		canvas.draw_rect(body.grow(6), Color(GLOW, 0.7), false, 2.0)


## A lantern hanging from `hook`: "lit" glows and flickers, "dark" is cold with a gremlin on it, "unlit" waits.
static func lantern(canvas: CanvasItem, hook: Vector2, state: String, flicker: float, pop: float) -> void:
	var at := hook + Vector2(0, 22)
	canvas.draw_line(hook, at - Vector2(0, 9), ROPE, 1.5)
	var frame := Color("#5a4632")
	if state == LanternRules.LIT:
		glow(canvas, at, 34.0 + flicker * 6.0, Color(GLOW, 0.35))
		canvas.draw_circle(at, 8.0, GLOW.lightened(0.2 * flicker))
	elif state == LanternRules.DARK:
		canvas.draw_circle(at, 8.0, COLD.darkened(0.3))
	else:
		canvas.draw_circle(at, 8.0, Color("#2a2119"))
	canvas.draw_arc(at, 9.0, 0, TAU, 20, frame, 2.0, true)
	canvas.draw_line(at - Vector2(7, 9), at + Vector2(7, -9), frame, 2.0)
	canvas.draw_line(at - Vector2(5, -9), at + Vector2(5, 9), frame, 2.0)
	if state == LanternRules.DARK:
		gremlin(canvas, at + Vector2(0, -16), pop, flicker)


## A small gremlin (a bug) perched at `at`; `pop` (0-1) scales it in as it arrives.
static func gremlin(canvas: CanvasItem, at: Vector2, pop: float, wiggle: float) -> void:
	var s := clampf(pop, 0.0, 1.0)
	if s <= 0.0:
		return
	var r := 12.0 * s
	var centre := at + Vector2(sin(wiggle * 6.0) * 1.5, 0)
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[centre + Vector2(-r, -r * 0.4), centre + Vector2(-r * 0.7, -r * 1.5), centre + Vector2(-r * 0.2, -r * 0.8)]
		),
		GREMLIN
	)
	canvas.draw_colored_polygon(
		PackedVector2Array(
			[centre + Vector2(r, -r * 0.4), centre + Vector2(r * 0.7, -r * 1.5), centre + Vector2(r * 0.2, -r * 0.8)]
		),
		GREMLIN
	)
	canvas.draw_circle(centre, r, GREMLIN)
	canvas.draw_arc(centre, r, PI * 1.1, PI * 1.9, 12, Color(GREMLIN_EYE, 0.35), 1.5, true)
	glow(canvas, centre + Vector2(-r * 0.35, -r * 0.1), 5.0 * s, Color(GREMLIN_EYE, 0.6))
	glow(canvas, centre + Vector2(r * 0.35, -r * 0.1), 5.0 * s, Color(GREMLIN_EYE, 0.6))
	canvas.draw_circle(centre + Vector2(-r * 0.35, -r * 0.1), 1.8 * s, GREMLIN_EYE)
	canvas.draw_circle(centre + Vector2(r * 0.35, -r * 0.1), 1.8 * s, GREMLIN_EYE)


## A soft round glow: one radial-gradient texture, tinted and stretched, cheap enough to draw dozens a frame.
static func glow(canvas: CanvasItem, at: Vector2, radius: float, colour: Color) -> void:
	canvas.draw_texture_rect(
		_glow_texture(), Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, colour
	)


## LEARN: a glow drawn as stacked circles shows its rings as bands; a radial GradientTexture2D with an eased falloff is
## smooth at any size, and is made once and shared (a static var lives as long as the program).
static func _glow_texture() -> Texture2D:
	if _glow == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 1.0])
		gradient.colors = PackedColorArray(
			[Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)]
		)
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		_glow = texture
	return _glow


static func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out


static func _dashed_rect(canvas: CanvasItem, rect: Rect2, colour: Color) -> void:
	var corners: Array[Vector2] = [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	]
	for i in 4:
		canvas.draw_dashed_line(corners[i], corners[(i + 1) % 4], colour, 1.5, 8.0)
