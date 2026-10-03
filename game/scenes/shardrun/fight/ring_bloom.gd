class_name RingBloom
extends RefCounted
## A circle that grows from its centre (ADR-0043): the first shard sets the core ring, and every shard after it sets
## one more ring round the others, so the spell is larger with each shard, up to six. A ring is never written. It
## stands whole the moment its function begins and only turns a little, into its place, while the function runs.

## The most rings a spell holds: the outermost ring's share of the radius is 1.
const MAX_RINGS := 6
## The core ring's share of the radius, and how wide a ring's band is (also as shares of the radius).
const CORE := 0.2
const BAND := 0.1
## The small turn a ring makes as it is set, in radians, and the share of its function it appears in.
const SET_TURN := 0.5
const APPEAR := 0.12
const SCALE_IN := 0.08
## How the ornament on a ring is drawn, by the look the shard's layer has (CircleLayers.KINDS).
const ORNAMENTS := {
	"runes": "ticks",
	"dashes": "ticks",
	"brackets": "ticks",
	"spokes": "ticks",
	"pulses": "beads",
	"satellites": "beads",
	"rosette": "beads",
	"wave": "dashes",
	"spiral": "dashes",
	"star": "polygon",
	"lattice": "polygon",
	"nested": "polygon",
}


## The outer radius of ring `index` (0 the core), as a share of the radius: even steps from the core to the rim.
static func outer_share(index: int) -> float:
	return lerpf(CORE, 1.0, float(clampi(index, 0, MAX_RINGS - 1)) / float(MAX_RINGS - 1))


## What a ring looks like `progress` (0 → 1, over its function) after it begins: nothing before, whole from the
## first moments, and turning into place. {alpha, scale, turn}; `turn` is the angle it still has to make, signed by
## its direction.
static func state(progress: float, direction: int) -> Dictionary:
	if progress <= 0.0:
		return {"alpha": 0.0, "scale": 1.0, "turn": 0.0}
	var settled := MagicCircle._ease_out(progress)
	return {
		"alpha": MagicCircle._ease_out(minf(1.0, progress / APPEAR)),
		"scale": 1.0 + SCALE_IN * (1.0 - MagicCircle._ease_out(minf(1.0, progress / 0.3))),
		"turn": SET_TURN * (1.0 - settled) * float(direction),
	}


static func draw(c: MagicCircle, radius: float, fade: float) -> void:
	var count := maxi(1, c.layers.size())
	var width := clampf(radius / 100.0, 0.9, 2.4)
	var pulse := 1.0 + c._flare * 0.3
	for index in count:
		var progress := 1.0 if c.layers.is_empty() else c._layer_progress(index)
		if progress <= 0.0:
			continue
		var layer: Dictionary = {} if c.layers.is_empty() else c.layers[index]
		var shown := state(progress, int(layer.get("dir", 1)))
		var drift := 0.0
		if c._formed:
			drift = (c.clock - c._formed_at) * 0.05 * float(layer.get("dir", 1))
		var alpha: float = fade * float(shown.alpha)
		var outer := radius * outer_share(index) * float(shown.scale)
		var inner := outer - radius * BAND * float(shown.scale) if index > 0 else outer * 0.62
		var turn: float = float(shown.turn) + drift + float(int(layer.get("seed", index * 7)) % 628) / 100.0
		_ring(c, outer, inner, alpha, width, pulse)
		_ornament(c, String(ORNAMENTS.get(String(layer.get("kind", "")), "ticks")), outer, inner, turn, alpha, index)
		if index == 0:
			_core(c, inner, alpha, pulse)
	for shock: float in c._shocks:
		var age := (c.clock - shock) / 0.32
		if age < 1.0:
			c._arc(
				radius * lerpf(0.2, 1.15, MagicCircle._ease_out(age)), 0.0, TAU, 3.0 * (1.0 - age), (1.0 - age) * fade
			)


## A ring: a faint filled band, a bright outer line with a halo, a thinner inner one.
static func _ring(c: MagicCircle, outer: float, inner: float, alpha: float, width: float, pulse: float) -> void:
	c.draw_circle(Vector2.ZERO, outer, Color(c.mid, 0.05 * alpha))
	c.draw_arc(Vector2.ZERO, (outer + inner) * 0.5, 0.0, TAU, 96, Color(c.mid, 0.1 * alpha), outer - inner, true)
	c.draw_arc(Vector2.ZERO, outer, 0.0, TAU, 96, Color(c.mid, 0.28 * alpha), width * 4.0 * pulse, true)
	c.draw_arc(Vector2.ZERO, outer, 0.0, TAU, 96, Color(c.hot, 0.92 * alpha), width * 1.7, true)
	c.draw_arc(Vector2.ZERO, inner, 0.0, TAU, 96, Color(c.hot, 0.55 * alpha), width * 0.9, true)


static func _ornament(
	c: MagicCircle, kind: String, outer: float, inner: float, turn: float, alpha: float, index: int
) -> void:
	var middle := (outer + inner) * 0.5
	var count := 12 + 4 * index
	match kind:
		"ticks":
			for i in count:
				var a := turn + TAU * i / count
				var length := 0.5 if i % 3 == 0 else 0.3
				c.draw_line(
					Vector2.from_angle(a) * (middle - (outer - inner) * length),
					Vector2.from_angle(a) * (middle + (outer - inner) * length),
					Color(c.hot, 0.7 * alpha),
					1.3,
					true
				)
		"beads":
			for i in count:
				var at := Vector2.from_angle(turn + TAU * i / count) * middle
				c.draw_circle(at, 2.8, Color(c.mid, 0.3 * alpha))
				c.draw_circle(at, 1.4, Color(c.hot, 0.9 * alpha))
		"dashes":
			for i in count:
				var from := turn + TAU * i / count
				c.draw_arc(
					Vector2.ZERO, middle, from, from + TAU / count * 0.55, 6, Color(c.hot, 0.8 * alpha), 2.0, true
				)
		_:
			# A polygon turned inside the ring, its corners touching the inner line.
			var sides := 5 + index
			var corners := PackedVector2Array()
			for i in sides + 1:
				corners.append(Vector2.from_angle(turn + TAU * i / sides - PI * 0.5) * inner)
			c.draw_polyline(corners, Color(c.mid, 0.28 * alpha), 4.0, true)
			c.draw_polyline(corners, Color(c.hot, 0.85 * alpha), 1.3, true)


## The core of the first ring: a bright jewel that flares with each bolt.
static func _core(c: MagicCircle, inner: float, alpha: float, pulse: float) -> void:
	c.draw_circle(Vector2.ZERO, inner * 0.55 * pulse, Color(c.mid, 0.2 * alpha))
	c.draw_circle(Vector2.ZERO, inner * 0.26 * pulse, Color(c.hot, (0.55 + 0.45 * c._flare) * alpha))
