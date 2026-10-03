class_name CircleLayerArt
extends RefCounted
## What each kind of layer looks like (ADR-0039). A spell's circle is a stack of these, one per shard, each a different
## figure at its own radius: they are drawn in the circle's flat disc space (a circle of radius `r` round the origin),
## so they narrow, lean, flare and close with the circle, and through CircleStyles' `ring` and `node` they take the
## hand of the circle's style. `grow` goes 0 to 1 as the layer draws itself in; `alpha` carries the fade of the whole.
##
## Every figure turns on the circle's own clock, the way its direction (`dir`) and numbers (`seed`) were drawn from the
## shard (CircleLayers), so a shard has one look, however many times it is played.

const STARS: Array[Vector2i] = [
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 2), Vector2i(9, 4)
]


## Draws one layer of `spec` ({kind, word, seed, dir}) in the band from radius `inner` out to `r`: the figures that
## fill (spokes, a spiral, a honeycomb, a rosette) fill only that band, so the layers stacked one inside another stay
## readable instead of drawing over each other.
static func draw(c: MagicCircle, spec: Dictionary, r: float, inner: float, grow: float, alpha: float) -> void:
	if grow <= 0.0 or alpha <= 0.0:
		return
	var seed := int(spec.get("seed", 0))
	var dir := float(spec.get("dir", 1))
	var band := Vector2(inner, r)
	match String(spec.get("kind", "")):
		"runes":
			_runes(c, String(spec.get("word", "")), band, grow, alpha, dir)
		"star":
			_star(c, r, grow, alpha, dir, seed)
		"lattice":
			_lattice(c, band, grow, alpha, dir)
		"spiral":
			_spiral(c, band, grow, alpha, dir, seed)
		"satellites":
			_satellites(c, String(spec.get("word", "")), band, grow, alpha, dir, seed)
		"brackets":
			_brackets(c, band, grow, alpha, dir, seed)
		"spokes":
			_spokes(c, band, grow, alpha, dir, seed)
		"wave":
			_wave(c, band, grow, alpha, dir, seed)
		"pulses":
			_pulses(c, band, grow, alpha, dir)
		"nested":
			_nested(c, band, grow, alpha, dir, seed)
		"dashes":
			_dashes(c, r, grow, alpha, dir)
		"rosette":
			_rosette(c, band, grow, alpha, dir, seed)


## How heavy a stroke is for a circle of this size: the strokes are written for one of about a hundred pixels.
static func weight(c: MagicCircle) -> float:
	return clampf(c.radius / 100.0, 0.9, 2.6)


## A bright line with its halo.
static func _line(c: MagicCircle, from: Vector2, to: Vector2, thin: float, alpha: float) -> void:
	var width := thin * weight(c)
	c.draw_line(from, to, Color(c.mid, 0.26 * alpha), width * 3.0, true)
	c.draw_line(from, to, Color(c.hot, 0.85 * alpha), width, true)


## A bright polyline with its halo.
static func _poly(c: MagicCircle, points: PackedVector2Array, thin: float, alpha: float) -> void:
	if points.size() < 2:
		return
	var width := thin * weight(c)
	c.draw_polyline(points, Color(c.mid, 0.26 * alpha), width * 3.0, true)
	c.draw_polyline(points, Color(c.hot, 0.85 * alpha), width, true)


## The first `share` (0..1) of a closed outline's edges, the last one part way.
static func _partial(corners: PackedVector2Array, share: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var edges := corners.size()
	var reach := float(edges) * clampf(share, 0.0, 1.0)
	points.append(corners[0])
	for i in edges:
		var part := clampf(reach - i, 0.0, 1.0)
		if part <= 0.0:
			break
		points.append(corners[i].lerp(corners[(i + 1) % edges], part))
	return points


static func _glyph(c: MagicCircle, at: Vector2, rotation: float, glyph: String, size: int, alpha: float) -> void:
	if glyph == " " or glyph == "":
		return
	c.draw_set_transform_matrix(c._disc_xf * Transform2D(rotation, at))
	c.draw_char(c._font, Vector2(-size * 0.3, size * 0.35), glyph, size, Color(c.hot, alpha))


static func _flat(c: MagicCircle) -> void:
	c.draw_set_transform_matrix(c._disc_xf)


## The shard's own function name set round a band, glyph by glyph, turning one way between two thin rings.
static func _runes(c: MagicCircle, word: String, band: Vector2, grow: float, alpha: float, dir: float) -> void:
	var r := band.y - 0.0
	var size := clampi(int(minf((band.y - band.x) * 0.8, c.radius * 0.11)), 7, 18)
	var text := (word if word != "" else c.runes.strip_edges()) + "  "
	CircleStyles.ring(c, r + size * 0.62, 0.0, TAU * grow, 1.0, alpha * 0.7)
	CircleStyles.ring(c, r - size * 0.62, 0.0, TAU * grow, 1.0, alpha * 0.7)
	var count := maxi(8, int(TAU * r / (size * 0.82)))
	var turn := dir * c.drawing_clock() * 0.5
	for i in count:
		var shown := clampf(grow * count - i, 0.0, 1.0)
		if shown <= 0.0:
			break
		var a := turn + TAU * i / count
		var place := Transform2D(a, Vector2.ZERO) * Transform2D(0.0, Vector2(0.0, -r))
		var pop := Transform2D(0.0, Vector2.ONE * (1.6 - 0.6 * shown), 0.0, Vector2.ZERO)
		c.draw_set_transform_matrix(c._disc_xf * place * pop)
		var glyph := text[i % text.length()]
		if glyph != " ":
			c.draw_char(c._font, Vector2(-size * 0.3, size * 0.35), glyph, size, Color(c.hot, shown * alpha))
	_flat(c)


## A ruled star {points / step} in a thin ring, counter-turning, its corners lit.
static func _star(c: MagicCircle, r: float, grow: float, alpha: float, dir: float, seed: int) -> void:
	var shape := STARS[seed % STARS.size()]
	var points := shape.x
	var turn := dir * c.drawing_clock() * 0.4 - PI * 0.5
	CircleStyles.ring(c, r, 0.0, TAU * grow, 1.0, alpha * 0.6)
	var corners: Array[Vector2] = []
	for i in points:
		corners.append(Vector2.from_angle(turn + TAU * i / points) * r)
	var edges := float(points) * grow
	for i in points:
		var share := clampf(edges - i, 0.0, 1.0)
		if share <= 0.0:
			break
		var a := corners[i]
		_line(c, a, a.lerp(corners[(i + shape.y) % points], share), 1.5, alpha)
		CircleStyles.node(c, a, 1.8, alpha)


## A chain of hexagons round the band, drawn cell by cell, the whole honeycomb turning slowly.
static func _lattice(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float) -> void:
	var mid := (band.x + band.y) * 0.5
	var cell := minf((band.y - band.x) * 0.5, mid * 0.5)
	var count := clampi(roundi(TAU * mid / (cell * 1.75)), 6, 18)
	var turn := dir * c.drawing_clock() * 0.25
	for index in count:
		var share := clampf(grow * count - index, 0.0, 1.0)
		if share <= 0.0:
			break
		var a := turn + TAU * index / count
		var centre := Vector2.from_angle(a) * mid
		var corners := PackedVector2Array()
		for k in 6:
			corners.append(centre + Vector2.from_angle(a + PI / 6.0 + TAU * k / 6.0) * cell)
		_poly(c, _partial(corners, share), 1.2, alpha)
		if share >= 1.0:
			c.draw_circle(centre, 1.6, Color(c.hot, alpha * 0.8))


## Three arms spiralling across the band, turning.
static func _spiral(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float, seed: int) -> void:
	var arms := 3 + seed % 2
	var turn := dir * c.drawing_clock() * 0.7
	for arm in arms:
		var points := PackedVector2Array()
		var steps := maxi(4, int(36.0 * grow))
		for i in steps + 1:
			var u := grow * float(i) / steps
			var reach := lerpf(band.x, band.y, u)
			points.append(Vector2.from_angle(turn + TAU * arm / arms + dir * u * TAU * 0.9) * reach)
		_poly(c, points, 1.5, alpha)
		CircleStyles.node(c, points[points.size() - 1], 1.8, alpha)


## Small circles carrying the shard's letters, orbiting a thin ring, each trailing a streak of light.
static func _satellites(
	c: MagicCircle, word: String, band: Vector2, grow: float, alpha: float, dir: float, seed: int
) -> void:
	var r := (band.x + band.y) * 0.5
	var count := 3 + seed % 3
	var turn := dir * c.drawing_clock() * 0.65
	var body := clampf((band.y - band.x) * 0.45, 5.0, 15.0)
	CircleStyles.ring(c, r, 0.0, TAU * grow, 0.9, alpha * 0.55)
	var text := (word if word != "" else "{}") + "  "
	for k in count:
		var shown := clampf(grow * count - k, 0.0, 1.0)
		if shown <= 0.0:
			break
		var a := turn + TAU * k / count
		var at := Vector2.from_angle(a) * r
		CircleStyles.ring(c, r, a - dir * 0.7, dir * 0.7 * shown, 1.8, alpha)
		c.draw_circle(at, body * shown, Color(c.mid, 0.2 * alpha))
		c.draw_arc(at, body * shown, 0.0, TAU, 20, Color(c.hot, 0.9 * alpha), 1.4, true)
		var size := maxi(7, int(body * 1.35))
		_glyph(c, at, 0.0, text[(k * 3) % text.length()], size, alpha * shown)
		_flat(c)


## Short arcs with caps, like the brackets round a block of code, turning against the circle.
static func _brackets(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float, seed: int) -> void:
	var count := 3 + seed % 3
	var turn := dir * c.drawing_clock() * 0.45
	var length := TAU / count * 0.58
	var high := band.y
	var low := lerpf(band.x, band.y, 0.45)
	for k in count:
		var shown := clampf(grow * count * 0.9 - k * 0.6, 0.0, 1.0)
		if shown <= 0.0:
			continue
		var from := turn + TAU * k / count
		CircleStyles.ring(c, high, from, length * shown, 2.2, alpha)
		CircleStyles.ring(c, low, from, length * shown, 1.0, alpha * 0.7)
		for end: float in [from, from + length * shown]:
			_line(c, Vector2.from_angle(end) * low, Vector2.from_angle(end) * high, 1.3, alpha)


## Beams radiating across the band, long and short by turns, shimmering.
static func _spokes(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float, seed: int) -> void:
	var count := clampi(int(TAU * band.y / (8.0 + 2.0 * (seed % 3))), 10, 40)
	var turn := dir * c.drawing_clock() * 0.3
	for i in count:
		var a := turn + TAU * i / count
		var reach := band.y if i % 2 == 0 else lerpf(band.x, band.y, 0.6)
		var shimmer := 0.55 + 0.45 * sin(c.drawing_clock() * 4.0 + i * 0.9)
		var tip := Vector2.from_angle(a) * lerpf(band.x, reach, grow)
		_line(c, Vector2.from_angle(a) * band.x, tip, 1.1, alpha * shimmer)
		if i % 2 == 0:
			CircleStyles.node(c, tip, 1.5, alpha * grow)


## Two waves braided round the band, running against each other.
static func _wave(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float, seed: int) -> void:
	var lobes := 6 + seed % 7
	var sweep := TAU * grow
	var mid := (band.x + band.y) * 0.5
	var amp := (band.y - band.x) * 0.42
	for pass_index in 2:
		var side := 1.0 if pass_index == 0 else -1.0
		var points := PackedVector2Array()
		var steps := maxi(8, int(120.0 * grow))
		for i in steps + 1:
			var angle := sweep * float(i) / steps - PI * 0.5
			points.append(
				Vector2.from_angle(angle) * (mid + amp * sin(angle * lobes + dir * side * c.drawing_clock() * 1.9))
			)
		_poly(c, points, 1.4 if pass_index == 0 else 1.0, alpha * (1.0 if pass_index == 0 else 0.7))


## Rings that ripple across the band one after another, like sonar.
static func _pulses(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float) -> void:
	CircleStyles.ring(c, band.y, 0.0, TAU * grow, 1.0, alpha * 0.55)
	for k in 3:
		var phase := fposmod(c.drawing_clock() * 0.6 + k / 3.0, 1.0)
		var moving := phase if dir > 0.0 else 1.0 - phase
		CircleStyles.ring(
			c,
			lerpf(band.x, band.y, moving),
			0.0,
			TAU * (grow if c.external_construction else 1.0),
			1.6,
			alpha * sin(phase * PI) * grow
		)


## Polygons set one inside another through the band, each turning its own way.
static func _nested(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float, seed: int) -> void:
	var sides := 3 + seed % 4
	for level in 3:
		var share := clampf(grow * 3.0 - level * 0.7, 0.0, 1.0)
		if share <= 0.0:
			break
		var reach := lerpf(band.y, band.x, level / 2.0)
		var turn := dir * c.drawing_clock() * (0.35 + 0.15 * level) * (1.0 if level % 2 == 0 else -1.0) - PI * 0.5
		var corners := PackedVector2Array()
		for i in sides:
			corners.append(Vector2.from_angle(turn + TAU * i / sides) * reach)
		_poly(c, _partial(corners, share), 1.4 - 0.2 * level, alpha)
		if share >= 1.0:
			for corner in corners:
				CircleStyles.node(c, corner, 1.4, alpha)


## A dashed ring with a bright run of light going round it.
static func _dashes(c: MagicCircle, r: float, grow: float, alpha: float, dir: float) -> void:
	var count := 28
	var width := TAU / count * 0.55
	for i in count:
		var shown := clampf(grow * count - i, 0.0, 1.0)
		if shown <= 0.0:
			break
		var from := TAU * i / count
		c.draw_arc(Vector2.ZERO, r, from, from + width * shown, 4, Color(c.hot, 0.7 * alpha), 1.8, true)
	var head := dir * c.drawing_clock() * 1.6
	CircleStyles.ring(c, r * 0.94, head - dir * 1.0, dir * 1.0 * grow, 2.4, alpha)
	CircleStyles.node(c, Vector2.from_angle(head) * r * 0.94, 2.0, alpha * grow)


## A chain of overlapping circles round the band, as a flower is drawn.
static func _rosette(c: MagicCircle, band: Vector2, grow: float, alpha: float, dir: float, seed: int) -> void:
	var mid := (band.x + band.y) * 0.5
	var count := 6 + 2 * (seed % 3)
	var turn := dir * c.drawing_clock() * 0.3
	var petal := minf((band.y - band.x) * 0.6, mid * sin(PI / count) * 1.7)
	for k in count:
		var shown := clampf(grow * 1.6 - float(k) / count * 0.6, 0.0, 1.0)
		if shown <= 0.0:
			continue
		var a := turn + TAU * k / count
		CircleStyles.ring(c, petal, a + PI, TAU * shown, 1.1, alpha, Vector2.from_angle(a) * mid)
