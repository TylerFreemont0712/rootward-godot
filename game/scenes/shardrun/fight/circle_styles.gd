class_name CircleStyles
extends RefCounted
## The magic circle's other hands (ADR-0037): the same disc, timing and runes as the codex circle (MagicCircle), drawn
## another way. Each draws in the circle's flat disc space (a circle of radius r round the origin) on the circle
## itself, so it narrows, turns, flares and closes exactly as the codex circle does.
##
##   rootglass      a ring that grows like a vine and buds leaves; branches instead of a star; a seed that blooms
##   clockwork      a toothed ring, a clock face with a hand that sweeps once, two small gears turning against it
##   constellation  stars pricked round the rim, joined one line at a time; a scatter of stars inside; a bright star

const LEAVES := 14
const STARS := 18


static func main_disc(c: MagicCircle, r: float, fade: float, breathe: float, closing: float) -> void:
	c.draw_circle(Vector2.ZERO, r * 0.95, Color(c.mid, 0.1 * fade * breathe + 0.12 * c._flare))
	match c.style:
		"rootglass":
			_rootglass(c, r, fade)
		"clockwork":
			_clockwork(c, r, fade)
		"constellation":
			_constellation(c, r, fade)
	for ring in int(c._facts.runes):
		c._rune_ring(r * (0.78 - 0.17 * ring), ring, fade, closing)
	for shock: float in c._shocks:
		var age := (c.clock - shock) / 0.32
		if age < 1.0:
			c._arc(r * lerpf(0.25, 1.2, MagicCircle._ease_out(age)), 0.0, TAU, 3.0 * (1.0 - age), (1.0 - age) * fade)


static func front_disc(c: MagicCircle, r: float, alpha: float, index: int) -> void:
	c.draw_circle(Vector2.ZERO, r * 0.9, Color(c.mid, 0.08 * alpha + 0.1 * c._flare * alpha))
	match c.style:
		"rootglass":
			_vine(c, r, 0.0, 1.0, 6, alpha)
			_branches(c, r * 0.7, 3 + index, 1.0, alpha)
		"clockwork":
			_gear(c, r, 10 + 2 * index, 1.0, alpha)
			_arc_ring(c, r * 0.55, alpha * 0.8)
		"constellation":
			for i in 8:
				_sparkle(c, Vector2.from_angle(TAU * i / 8.0) * r, 3.0, alpha)
			c._star(r * 0.65, 4 + index, 1, 1.0, 0.0, alpha * 0.7)
	c.draw_circle(Vector2.ZERO, r * 0.12, Color(c.hot, (0.4 + 0.6 * c._flare) * alpha))


## A stroke of light along points: a wide faint halo under a thin bright line.
static func _stroke(c: MagicCircle, points: PackedVector2Array, width: float, alpha: float) -> void:
	if points.size() < 2 or alpha <= 0.0:
		return
	c.draw_polyline(points, Color(c.mid, 0.28 * alpha), width * 3.2, true)
	c.draw_polyline(points, Color(c.hot, 0.9 * alpha), width, true)


static func _arc_ring(c: MagicCircle, r: float, alpha: float) -> void:
	c._arc(r, 0.0, TAU, 1.2, alpha)


# --- rootglass ---------------------------------------------------------------------------------------------------


static func _rootglass(c: MagicCircle, r: float, fade: float) -> void:
	# The vine grows from two points at once, a bud of light at each tip, and leaves open where it has passed.
	var grown := MagicCircle._ease_out(c._phase(0.0, 0.4))
	for start: float in [-PI * 0.5, PI * 0.5]:
		_vine(c, r, start, grown * 0.5, LEAVES / 2, fade)
		if grown < 1.0:
			c.draw_circle(_vine_point(r, start + PI * grown), 5.0, Color(c.hot, fade))
	c._arc(r * 0.86, 0.0, TAU * MagicCircle._ease_out(c._phase(0.1, 0.45)), 1.2, fade * 0.7)
	_branches(c, r * 0.66, int(c._facts.star[0]), c._phase(0.4, 0.84), fade)
	# The seed in the middle blooms last.
	var bloom := MagicCircle._ease_out(c._phase(0.72, 1.0))
	if bloom > 0.0:
		for i in 5:
			var a := TAU * i / 5.0 + c.clock * 0.4
			var petal := PackedVector2Array()
			for k in 9:
				var u := float(k) / 8.0
				var bulge := sin(u * PI) * r * 0.07 * bloom
				petal.append(Vector2.from_angle(a) * r * 0.2 * u * bloom + Vector2.from_angle(a + PI * 0.5) * bulge)
			for k in range(8, -1, -1):
				var u := float(k) / 8.0
				var bulge := sin(u * PI) * r * 0.07 * bloom
				petal.append(Vector2.from_angle(a) * r * 0.2 * u * bloom - Vector2.from_angle(a + PI * 0.5) * bulge)
			_stroke(c, petal, 1.2, fade)
		c.draw_circle(Vector2.ZERO, r * (0.06 + 0.04 * c._flare) * bloom, Color(c.hot, (0.6 + 0.4 * c._flare) * fade))


static func _vine_point(r: float, angle: float) -> Vector2:
	return Vector2.from_angle(angle) * r * (1.0 + 0.03 * sin(angle * 9.0))


## A wavy ring from `start` round `share` of a turn (each way from it when called twice), with `leaves` leaves.
static func _vine(c: MagicCircle, r: float, start: float, share: float, leaves: int, alpha: float) -> void:
	var sweep := TAU * share
	if sweep <= 0.001:
		return
	var points := PackedVector2Array()
	var count := maxi(6, int(64.0 * share) + 4)
	for i in count + 1:
		points.append(_vine_point(r, start + sweep * float(i) / count))
	_stroke(c, points, 2.6, alpha)
	for i in leaves:
		var along := (float(i) + 0.5) / float(leaves)
		if along > 1.0:
			break
		var a := start + sweep * along
		var at := _vine_point(r, a)
		var out := Vector2.from_angle(a + (0.6 if i % 2 == 0 else -0.6)) * r * 0.09
		var side := out.orthogonal() * 0.35
		_stroke(c, PackedVector2Array([at, at + out * 0.5 + side, at + out, at + out * 0.5 - side, at]), 1.0, alpha)


## Branches out from the middle, each forking twice near its end, grown as `drawn` goes 0 to 1.
static func _branches(c: MagicCircle, r: float, count: int, drawn: float, alpha: float) -> void:
	if drawn <= 0.0:
		return
	var turn := -c._spin(0.6) - c._spin(0.35)
	for i in count:
		var grown := clampf(drawn * count - i, 0.0, 1.0)
		if grown <= 0.0:
			break
		var a := turn + TAU * i / count
		var root := Vector2.from_angle(a) * r * 0.18
		var tip := Vector2.from_angle(a) * r * lerpf(0.18, 1.0, grown)
		_stroke(c, PackedVector2Array([root, tip]), 1.6, alpha)
		if grown > 0.6:
			var fork := Vector2.from_angle(a) * r * 0.62
			var twig := (grown - 0.6) / 0.4 * r * 0.24
			for bend: float in [-0.55, 0.55]:
				_stroke(c, PackedVector2Array([fork, fork + Vector2.from_angle(a + bend) * twig]), 1.1, alpha)
		c.draw_circle(tip, 2.6, Color(c.hot, alpha))


# --- clockwork ---------------------------------------------------------------------------------------------------


static func _clockwork(c: MagicCircle, r: float, fade: float) -> void:
	_gear(c, r, int(c._facts.ticks) / 2, MagicCircle._ease_out(c._phase(0.0, 0.36)), fade)
	c._arc(r * 0.84, 0.0, TAU * MagicCircle._ease_out(c._phase(0.06, 0.4)), 1.4, fade)
	# The clock face: twelve marks set in turn, then a hand that sweeps once round while it writes itself.
	var marks := int(12 * c._phase(0.2, 0.5))
	for i in marks:
		var a := TAU * i / 12.0
		var inner := 0.5 if i % 3 == 0 else 0.56
		c.draw_line(Vector2.from_angle(a) * r * inner, Vector2.from_angle(a) * r * 0.62, Color(c.hot, 0.8 * fade), 2.0)
	var sweep := c._phase(0.3, 1.0)
	if sweep > 0.0:
		var hand := Vector2.from_angle(-PI * 0.5 + TAU * sweep - c._spin(0.35)) * r * 0.58
		_stroke(c, PackedVector2Array([Vector2.ZERO, hand]), 1.8, fade)
	# Two small gears turning against the big one, on either side of the hub.
	var turning := c._phase(0.45, 0.85)
	if turning > 0.0:
		for side: float in [-1.0, 1.0]:
			_small_gear(c, Vector2(side * r * 0.33, r * 0.08), r * 0.15 * turning, -c.clock * 2.4 * side, fade)
	var hub := MagicCircle._ease_out(c._phase(0.74, 1.0))
	if hub > 0.0:
		c._arc(r * 0.12, 0.0, TAU * hub, 2.0, fade)
		c.draw_circle(Vector2.ZERO, r * (0.07 + 0.04 * c._flare) * hub, Color(c.hot, (0.6 + 0.4 * c._flare) * fade))


## A toothed ring of `teeth` teeth, drawn round `share` of a turn.
static func _gear(c: MagicCircle, r: float, teeth: int, share: float, alpha: float) -> void:
	if share <= 0.0:
		return
	var points := PackedVector2Array()
	var steps := maxi(4, int(teeth * 4 * share))
	for i in steps + 1:
		var u := float(i) / float(teeth * 4)
		var a := TAU * u - PI * 0.5
		var up := (i % 4) in [1, 2]
		points.append(Vector2.from_angle(a) * r * (1.0 if up else 0.93))
	_stroke(c, points, 2.2, alpha)


static func _small_gear(c: MagicCircle, centre: Vector2, r: float, turn: float, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var a := turn + TAU * float(i) / 32.0
		points.append(centre + Vector2.from_angle(a) * r * (1.0 if (i % 4) in [1, 2] else 0.8))
	_stroke(c, points, 1.2, alpha)
	c.draw_circle(centre, r * 0.25, Color(c.hot, 0.7 * alpha))


# --- constellation -----------------------------------------------------------------------------------------------


static func _constellation(c: MagicCircle, r: float, fade: float) -> void:
	# Stars pricked round the rim one after another, a faint dotted ring between them.
	var rim := int(c._facts.ticks) / 3
	var pricked := c._phase(0.0, 0.4) * rim
	for i in rim:
		var shown := clampf(pricked - i, 0.0, 1.0)
		if shown <= 0.0:
			break
		var a := TAU * i / rim - PI * 0.5
		_sparkle(c, Vector2.from_angle(a) * r, (4.5 if i % 4 == 0 else 2.6) * (1.6 - 0.6 * shown), shown * fade)
	var dots := int(96 * c._phase(0.1, 0.45))
	for i in dots:
		if i % 2 == 0:
			c.draw_circle(Vector2.from_angle(TAU * i / 96.0) * r * 0.9, 1.1, Color(c.hot, 0.5 * fade))
	# The figure: the tier's star as stars joined by lines, then a wandering line through stars inside it.
	var star: Array = c._facts.star
	c._star(r * 0.6, int(star[0]), int(star[1]), c._phase(0.42, 0.84), -c._spin(0.6) - c._spin(0.35), fade * 0.75)
	var inside: Array[Vector2] = []
	for i in STARS:
		# A fixed scatter (no randomness, so the same circle draws the same sky every time).
		var a := float(i) * 2.399963
		inside.append(Vector2.from_angle(a) * r * (0.2 + 0.32 * fposmod(float(i) * 0.618034, 1.0)))
	var joined := c._phase(0.5, 0.95) * (STARS - 1)
	for i in STARS:
		_sparkle(c, inside[i], 2.0, fade * clampf(c._phase(0.35, 0.6) * STARS - i, 0.0, 1.0))
		if i < STARS - 1 and joined > i:
			var b := inside[i].lerp(inside[i + 1], clampf(joined - i, 0.0, 1.0))
			c.draw_line(inside[i], b, Color(c.hot, 0.45 * fade), 1.0, true)
	var core := MagicCircle._ease_out(c._phase(0.74, 1.0))
	if core > 0.0:
		_sparkle(c, Vector2.ZERO, r * (0.12 + 0.06 * c._flare) * core, fade)


## A four-pointed star of light at `at`, `size` from its middle to a point.
static func _sparkle(c: MagicCircle, at: Vector2, size: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	c.draw_circle(at, size * 0.9, Color(c.mid, 0.22 * alpha))
	for arm: Vector2 in [Vector2(size, 0), Vector2(0, size)]:
		c.draw_line(at - arm, at + arm, Color(c.hot, 0.9 * alpha), maxf(1.0, size * 0.18), true)
	c.draw_circle(at, maxf(1.0, size * 0.22), Color(c.hot, alpha))
