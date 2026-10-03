class_name RingMotifs
extends RefCounted
## What is drawn in the band of one Ring Bloom ring (ADR-0043, ADR-0044): rune bands, lotus petals, scallops, sawtooth
## crowns, chains of diamonds, crescents, eyes, sun rays and an inscribed polygon. Every motif is whole the moment it
## is drawn; `turn` is the angle the ring still has to make into place, so it is the only thing that moves.
## All of them draw in the disc's own flat space (MagicCircle's transform narrows it), between `inner` and `outer`.

## What each ring takes, from the core outward: a flower round the core, a band of runes, a motif of the shard's own
## choosing, runes again, and a crown on the rim. Where there is a choice the shard's seed makes it, so a spell is the
## same every time and two spells differ.
const BANDS: Array = [
	[],
	["lotus", "eyes"],
	["runes"],
	["scallops", "diamonds", "crescents"],
	["runes"],
	["sawtooth", "rays", "scallops"],
]


static func band_for(index: int, seed: int) -> String:
	var choices: Array = BANDS[clampi(index, 1, BANDS.size() - 1)]
	return String(choices[posmod(seed, choices.size())])


static func draw(
	c: MagicCircle, motif: String, outer: float, inner: float, turn: float, alpha: float, seed: int
) -> void:
	var middle := (outer + inner) * 0.5
	var band := outer - inner
	var count := clampi(int(TAU * middle / (band * 1.1)), 8, 44)
	match motif:
		"runes":
			_runes(c, middle, band, count, turn, alpha, seed)
		"lotus":
			_lotus(c, inner, outer, clampi(count / 2, 6, 16), turn, alpha)
		"scallops":
			_scallops(c, middle, band, clampi(count / 2, 6, 20), turn, alpha)
		"sawtooth":
			_sawtooth(c, inner, outer, clampi(count, 10, 36), turn, alpha)
		"diamonds":
			_diamonds(c, middle, band, clampi(count / 2, 6, 20), turn, alpha)
		"crescents":
			_crescents(c, middle, band, clampi(count / 2, 6, 18), turn, alpha)
		"eyes":
			_eyes(c, middle, band, clampi(count / 3, 5, 12), turn, alpha)
		"rays":
			_rays(c, inner, outer, clampi(count, 12, 40), turn, alpha)
		_:
			_polygon(c, inner, 5 + seed % 4, turn, alpha)


## The core: an eight-point star of two squares round a jewel, and a small ring of beads.
static func core(c: MagicCircle, radius: float, turn: float, alpha: float, pulse: float) -> void:
	for half in 2:
		var corners := PackedVector2Array()
		for i in 5:
			corners.append(
				Vector2.from_angle(turn * (1.0 if half == 0 else -1.0) + PI * 0.25 * half + TAU * i / 4.0) * radius
			)
		_line(c, corners, alpha, 1.0)
	for i in 8:
		var at := Vector2.from_angle(turn + TAU * i / 8.0) * radius * 0.5
		c.draw_circle(at, maxf(1.4, radius * 0.045), Color(c.hot, 0.9 * alpha))
	c.draw_circle(Vector2.ZERO, radius * 0.3 * pulse, Color(c.mid, 0.25 * alpha))
	c.draw_circle(Vector2.ZERO, radius * 0.17 * pulse, Color(c.hot, (0.6 + 0.4 * c._flare) * alpha))


static func _line(c: MagicCircle, points: PackedVector2Array, alpha: float, thin: float) -> void:
	c.draw_polyline(points, Color(c.mid, 0.3 * alpha), 4.0 * thin, true)
	c.draw_polyline(points, Color(c.hot, 0.88 * alpha), 1.4 * thin, true)


static func _at(angle: float, radius: float) -> Vector2:
	return Vector2.from_angle(angle) * radius


static func _runes(
	c: MagicCircle, middle: float, band: float, count: int, turn: float, alpha: float, seed: int
) -> void:
	for i in count:
		var angle := turn + TAU * i / count
		RuneGlyphs.draw(
			c,
			seed + i * 7 + i / 3,
			_at(angle, middle),
			angle + PI * 0.5,
			band * 0.62,
			Color(c.mid, 0.22 * alpha),
			Color(c.hot, 0.95 * alpha),
			1.7
		)


static func _lotus(c: MagicCircle, inner: float, outer: float, count: int, turn: float, alpha: float) -> void:
	var half := TAU / count * 0.42
	for i in count:
		var angle := turn + TAU * i / count
		var petal := PackedVector2Array()
		for step in 13:
			var u := step / 12.0
			var width := sin(u * PI) * half
			petal.append(_at(angle - width, lerpf(inner, outer, u)))
		for step in range(12, -1, -1):
			var u := step / 12.0
			var width := sin(u * PI) * half
			petal.append(_at(angle + width, lerpf(inner, outer, u)))
		_line(c, petal, alpha, 0.8)
		c.draw_line(_at(angle, inner), _at(angle, lerpf(inner, outer, 0.8)), Color(c.hot, 0.5 * alpha), 1.0, true)


static func _scallops(c: MagicCircle, middle: float, band: float, count: int, turn: float, alpha: float) -> void:
	var step := TAU / count
	for i in count:
		var angle := turn + step * i
		var arc := PackedVector2Array()
		for k in 11:
			var u := k / 10.0
			var swing := angle + step * u
			arc.append(_at(swing, middle + sin(u * PI) * band * 0.5))
		_line(c, arc, alpha, 1.1)
		c.draw_circle(_at(angle, middle), 2.0, Color(c.hot, 0.9 * alpha))


static func _sawtooth(c: MagicCircle, inner: float, outer: float, count: int, turn: float, alpha: float) -> void:
	var crown := PackedVector2Array()
	for i in count * 2 + 1:
		crown.append(_at(turn + PI * i / count, outer if i % 2 == 1 else inner))
	_line(c, crown, alpha, 0.9)
	for i in count:
		c.draw_circle(_at(turn + TAU * (i + 0.5) / count, outer + 2.0), 1.3, Color(c.hot, 0.8 * alpha))


static func _diamonds(c: MagicCircle, middle: float, band: float, count: int, turn: float, alpha: float) -> void:
	for i in count:
		var angle := turn + TAU * i / count
		var across := TAU / count * middle * 0.34
		var shape := PackedVector2Array(
			[
				_at(angle, middle - band * 0.46),
				_at(angle, middle) + _at(angle + PI * 0.5, across),
				_at(angle, middle + band * 0.46),
				_at(angle, middle) + _at(angle - PI * 0.5, across),
				_at(angle, middle - band * 0.46),
			]
		)
		_line(c, shape, alpha, 0.8)
		c.draw_circle(_at(angle, middle), 1.5, Color(c.hot, 0.9 * alpha))


static func _crescents(c: MagicCircle, middle: float, band: float, count: int, turn: float, alpha: float) -> void:
	for i in count:
		var angle := turn + TAU * i / count
		var centre := _at(angle, middle)
		var size := band * 0.4
		var outer_arc := PackedVector2Array()
		var inner_arc := PackedVector2Array()
		for k in 13:
			var swing := angle + PI * 0.5 - PI + PI * k / 12.0
			outer_arc.append(centre + _at(swing, size))
			inner_arc.append(centre + _at(swing, size * 0.72) + _at(angle, size * 0.3))
		_line(c, outer_arc, alpha, 0.7)
		_line(c, inner_arc, alpha, 0.5)
		c.draw_circle(centre + _at(angle, size * 0.1), 1.2, Color(c.hot, 0.9 * alpha))


static func _eyes(c: MagicCircle, middle: float, band: float, count: int, turn: float, alpha: float) -> void:
	for i in count:
		var angle := turn + TAU * i / count
		var centre := _at(angle, middle)
		var length := TAU / count * middle * 0.34
		var lens := PackedVector2Array()
		for k in 9:
			var u := k / 8.0 * 2.0 - 1.0
			lens.append(centre + _at(angle + PI * 0.5, u * length) + _at(angle, (1.0 - u * u) * band * 0.3))
		for k in range(7, -1, -1):
			var u := k / 8.0 * 2.0 - 1.0
			lens.append(centre + _at(angle + PI * 0.5, u * length) - _at(angle, (1.0 - u * u) * band * 0.3))
		_line(c, lens, alpha, 0.8)
		c.draw_circle(centre, band * 0.12, Color(c.hot, 0.95 * alpha))


static func _rays(c: MagicCircle, inner: float, outer: float, count: int, turn: float, alpha: float) -> void:
	for i in count:
		var angle := turn + TAU * i / count
		var long := i % 2 == 0
		c.draw_line(
			_at(angle, inner + (outer - inner) * 0.1),
			_at(angle, outer - (outer - inner) * (0.0 if long else 0.4)),
			Color(c.hot, (1.0 if long else 0.75) * alpha),
			2.4 if long else 1.5,
			true
		)
		if long:
			c.draw_circle(_at(angle, outer), 1.7, Color(c.hot, 0.95 * alpha))


static func _polygon(c: MagicCircle, radius: float, sides: int, turn: float, alpha: float) -> void:
	var corners := PackedVector2Array()
	for i in sides + 1:
		corners.append(_at(turn + TAU * i / sides - PI * 0.5, radius))
	_line(c, corners, alpha, 0.9)
