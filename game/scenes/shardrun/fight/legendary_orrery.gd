class_name LegendaryOrrery
extends RefCounted
## The orrery (the circle style "orrery", docs/LEGENDARY_LOOKS.md): a legendary circle that models the spell. A bright
## core with a pulsing star; two tilted orbits turning slowly; one planet per shard on them, marked with its role's
## glyph in prism colours. A planet arrives with a shock ring, a flare and a constellation line to the planet before it.
## While a call runs, a sweep turns round the rim and lights the calling planet, and motes orbit. It has no text.
## Its last planet is the bolts' origin (final_node): both read planet_positions, so they cannot disagree.
##
## Reduced motion (Settings.reduced_motion): the planets and their links stay, and are still. Each link is at its steady
## light at once, with no arrival flare. Dropped: the sweep; the drift (every slow change: the orbits' turn, the star's
## turn and pulse, the planets' hue); the lighting-up of the first draw; the shock rings (on arrival and on each bolt);
## the flares (a planet's on arrival, the core's on each bolt). The motes hold still. A calling planet keeps its glow,
## which does not move. MagicCircle's own sparks (its bursts on a bolt and on the close, drawn over the orrery) are not
## the orrery's, and still move; so does the circle's swell as it closes.
##
## The orrery is drawn SIZE times its circle's radius (see frame_of), in the circle's own layout: the same centre,
## squash and lean as the other centred styles.
##
## MagicCircle._draw calls draw() in its own centred space, where the disc is seen narrowed and leaned back. The orbits
## are ellipses there; the core, the planets and their glyphs are placed round and upright (see _local).

## The two orbits, first then second: each one's radius (a share of the disc), how flat it is seen (its minor share),
## its tilt in radians, how far that tilt turns a second, and how fast a planet travels round it (radians a second).
const RING_RADIUS: Array[float] = [0.84, 0.95]
const RING_FLAT: Array[float] = [0.36, 0.58]
const RING_TILT: Array[float] = [0.42, -0.66]
const RING_TURN: Array[float] = [0.06, -0.04]
const RING_SPEED: Array[float] = [0.28, -0.22]
## Points in each orbit's outline, and the motes that orbit the core.
const ORBIT_STEPS := 48
const MOTES := 10
## How fast the sweep turns round the rim (radians a second), and how far round it reaches (a share of the disc).
const SWEEP_RATE := 2.2
const SWEEP_REACH := 0.95
## The arrival flourishes, in seconds: a shock ring runs out, a flare fades, a link grows out to its planet, and a link
## settles from bright to its steady light. A bolt's ring runs out in PULSE_SECONDS.
const SHOCK_SECONDS := 0.6
const FLARE_SECONDS := 0.8
const LINK_GROW_SECONDS := 0.35
const LINK_BRIGHT_SECONDS := 1.2
const PULSE_SECONDS := 0.32
## A link's light: bright as it arrives (the flare), then its steady light, bright enough to read in a fight.
const LINK_FLARE := 1.0
const LINK_STEADY := 0.8
## How many times its circle's radius the orrery is drawn. The planets, orbits and glyphs are placed in the circle's own
## space, so this enlarges the orrery alone, never the circle (the other styles keep their layout).
const SIZE := 1.25
## How long the orrery takes to light when first drawn, and how the star pulses (radians a second, a share of its size).
const INTRO_SECONDS := 0.45
const STAR_PULSE := 3.2
const STAR_SWELL := 0.12
## The points in a spiral glyph's stroke.
const SPIRAL_STEPS := 24


## One planet: a shard's place on the orrery. `place` is on the unit disc (see _local); `depth` is positive on the
## nearer half of its orbit. `arrived_at` is the circle's clock when the shard arrived, -1.0 before that. `calling`
## marks the planet whose call runs now.
class Planet:
	extends RefCounted
	var index := 0
	var role := ""
	var ring := 0
	var place := Vector2.ZERO
	var depth := 0.0
	var arrived_at := -1.0
	var calling := false


## What one frame needs, read from the circle once. `turn` is the clock the motion runs on: 0 under reduced motion, so
## nothing turns, while `now` is always the circle's clock (the arrivals are timed on it).
class Frame:
	extends RefCounted
	var radius := 0.0
	var fade := 1.0
	var mid := Color.WHITE
	var hot := Color.WHITE
	var width := 1.0
	var now := 0.0
	var turn := 0.0
	var reduced := false
	var intro := 1.0
	var flare := 0.0


## Every stroke goes through a Pen, so a test can count what one frame draws (the figure reported for six shards).
class Pen:
	extends RefCounted
	var commands := 0
	var _canvas: CanvasItem

	func _init(canvas: CanvasItem) -> void:
		_canvas = canvas

	func disc(at: Vector2, radius: float, colour: Color) -> void:
		commands += 1
		_canvas.draw_circle(at, radius, colour)

	func ring(at: Vector2, radius: float, width: float, colour: Color) -> void:
		commands += 1
		_canvas.draw_arc(at, radius, 0.0, TAU, 32, colour, width, true)

	func arc(at: Vector2, radius: float, start: float, finish: float, width: float, colour: Color) -> void:
		commands += 1
		_canvas.draw_arc(at, radius, start, finish, 24, colour, width, true)

	func segment(start: Vector2, finish: Vector2, width: float, colour: Color) -> void:
		commands += 1
		_canvas.draw_line(start, finish, colour, width, true)

	func line(points: PackedVector2Array, width: float, colour: Color) -> void:
		commands += 1
		_canvas.draw_polyline(points, colour, width, true)

	func lines(points: PackedVector2Array, colours: PackedColorArray, width: float) -> void:
		commands += 1
		_canvas.draw_polyline_colors(points, colours, width, true)

	func multiline(points: PackedVector2Array, colour: Color, width: float) -> void:
		commands += 1
		_canvas.draw_multiline(points, colour, width, true)

	func polygon(points: PackedVector2Array, colours: PackedColorArray) -> void:
		commands += 1
		_canvas.draw_polygon(points, colours)

	func fill(points: PackedVector2Array, colour: Color) -> void:
		commands += 1
		_canvas.draw_colored_polygon(points, colour)


## Draws the orrery on `circle`, at `radius` (the circle's own, see SIZE) and `fade` (1 down to 0 as the circle closes).
static func draw(circle: MagicCircle, radius: float, fade: float) -> void:
	paint(Pen.new(circle), circle, radius, fade)


## Every stroke of one frame, in order: the orbits and the core, the links and the planets, the sweep, then the motes.
## The planets' places come from planet_positions, the same function that gives the bolts' origin (final_node).
static func paint(pen: Pen, circle: MagicCircle, radius: float, fade: float) -> void:
	var frame := frame_of(circle, radius, fade)
	var planets := build_planets(circle)
	var spots := planet_positions(frame.turn, radius, planets.size())
	var sweep := sweep_of(frame.reduced, frame.now, planets)
	_orbits(pen, frame)
	_core(pen, frame)
	_pulses(pen, frame, circle._shocks)
	for pair: Vector2i in link_pairs(planets):
		_link(pen, frame, spots[pair.x], spots[pair.y], planets[pair.y].arrived_at)
	for planet: Planet in planets:
		if planet.arrived_at >= 0.0:
			_planet(pen, frame, planet, spots[planet.index], planets.size(), sweep)
	_sweep(pen, frame, sweep)
	_motes(pen, frame)


## Each shard's planet in the circle's local space, one per shard of the plan, in plan order. `time` is the orbits'
## clock (see motion_clock: 0 under reduced motion) and `radius` is the circle's own radius, as draw receives it (SIZE
## is applied here). Every planet has a place before its shard arrives, so no planet moves as shards arrive.
static func planet_positions(time: float, radius: float, count: int) -> PackedVector2Array:
	# LEARN: draw and the bolts' origins both ask this function for a planet's place. A second copy of the orbit's maths
	# would drift the first time one of the two changed, and the bolt would leave from empty air beside the star.
	var positions := PackedVector2Array()
	for index in count:
		positions.append(_planet_local(index, count, time, radius))
	return positions


## The last planet's place in the circle's local space: the planet of the last shard to arrive, once the circle is
## complete. Vector2.ZERO (the centre) with no shards.
static func final_node(time: float, radius: float, count: int) -> Vector2:
	# LEARN: the layout counts every shard of the plan, not the arrived ones, so nothing moves as shards arrive, and
	# arrivals come in plan order. So the last planet is the last shard's, and it is the last to arrive. A circle that
	# never receives its last shard (a function that returned early, a failed program) still has that place, which is
	# never drawn.
	if count <= 0:
		return Vector2.ZERO
	var positions := planet_positions(time, radius, count)
	return positions[count - 1]


## The frame's state, read from the circle. Only its clocks change from one frame to the next.
static func frame_of(circle: MagicCircle, radius: float, fade: float) -> Frame:
	var frame := Frame.new()
	frame.radius = radius * SIZE
	frame.fade = fade
	frame.mid = circle.mid
	frame.hot = circle.hot
	frame.width = clampf(frame.radius / 100.0, 0.8, 2.2)
	frame.now = circle.clock
	frame.reduced = circle._reduced
	frame.turn = motion_clock(circle)
	frame.intro = 1.0 if frame.reduced else MagicCircle._ease_out(circle.clock / INTRO_SECONDS)
	# LEARN: the circle sets its flare on every arrival and bolt, whatever the setting, so a flare is motion the orrery
	# has to drop itself: under reduced motion the core reads no flare.
	frame.flare = 0.0 if frame.reduced else circle._flare
	return frame


## The clock the motion runs on: the orbits, the planets and the motes. It stands still under reduced motion, so they
## stay where they are. MagicCircle reads it too, for the orrery's final node.
static func motion_clock(circle: MagicCircle) -> float:
	return 0.0 if circle._reduced else circle.clock


## One planet per layer of the circle, in arrival order. A shard that has not arrived is a planet with no arrival time
## yet, so the list is always the whole spell.
static func build_planets(circle: MagicCircle) -> Array[Planet]:
	var planets: Array[Planet] = []
	var count := circle.layers.size()
	var turn := motion_clock(circle)
	for index in count:
		var layer: Dictionary = circle.layers[index]
		var share := _call_share(circle, index)
		var planet := Planet.new()
		planet.index = index
		planet.role = String(layer.get("role", ""))
		planet.ring = index % 2
		planet.arrived_at = _arrival_clock(circle, index)
		# LEARN: only the newest arrival can be calling. A walkthrough can leave an earlier shard's trace short of its end
		# (a function that returned early), so "calling" describes the newest shard, never every unfinished one.
		planet.calling = index == circle._arrived - 1 and share >= 0.0 and share < 1.0 and not circle._sealed
		planet.place = _planet_on_disc(index, count, turn)
		planet.depth = sin(_orbit_angle(index, count, turn))
		planets.append(planet)
	return planets


## The constellation: each planet joined to the one before it, once it has arrived (the one before always has).
static func link_pairs(planets: Array[Planet]) -> Array[Vector2i]:
	var pairs: Array[Vector2i] = []
	for index in range(1, planets.size()):
		if planets[index].arrived_at >= 0.0 and planets[index - 1].arrived_at >= 0.0:
			pairs.append(Vector2i(index - 1, index))
	return pairs


## The angle the sweep ray points at, in radians on the unit disc, or -1.0 when there is no sweep: nothing is calling,
## or reduced motion is on.
static func sweep_of(reduced: bool, now: float, planets: Array[Planet]) -> float:
	if reduced:
		return -1.0
	for planet: Planet in planets:
		if planet.calling:
			return now * SWEEP_RATE
	return -1.0


## The sweep of a circle as it stands (see sweep_of).
static func sweep_angle(circle: MagicCircle) -> float:
	return sweep_of(circle._reduced, circle.clock, build_planets(circle))


## How far the call of layer `index` has run, 0 to 1, or -1.0 before it arrives. A traced call follows its walkthrough;
## an untraced one (or any layer of a circle built on the timer) draws itself as the layer does.
static func _call_share(circle: MagicCircle, index: int) -> float:
	if index >= circle._arrived:
		return -1.0
	if not circle.external_construction:
		return circle._layer_progress(index)
	if circle._traced_shares[index] >= 0.0:
		return circle._traced_shares[index]
	return clampf((circle.clock - circle._layer_times[index]) / MagicCircle.SHARD_DRAW_SECONDS, 0.0, 1.0)


## When layer `index` arrived, in the circle's clock; -1.0 before it does.
static func _arrival_clock(circle: MagicCircle, index: int) -> float:
	if index >= circle._arrived:
		return -1.0
	return circle._layer_times[index] if circle.external_construction else circle._layer_start(index) * circle._form()


## Where planet `index` starts round its orbit: the planets of one orbit spread evenly, and the second orbit's sit half
## a step between the first's, so no two planets share a place.
static func _planet_angle(index: int, count: int) -> float:
	var ring := index % 2
	var on_ring := ceili(float(count - ring) / 2.0)
	var slot := floori(float(index) / 2.0)
	return TAU * slot / on_ring + (PI / on_ring if ring == 1 else 0.0)


## Planet `index` of `count` in the circle's local space, at orbit clock `time`, for a circle of `radius` (see SIZE).
static func _planet_local(index: int, count: int, time: float, radius: float) -> Vector2:
	return _local(_planet_on_disc(index, count, time), radius * SIZE)


## Planet `index` of `count` on the unit disc, at orbit clock `time`.
static func _planet_on_disc(index: int, count: int, time: float) -> Vector2:
	var ring := index % 2
	return _ellipse(ring, _orbit_angle(index, count, time), RING_RADIUS[ring], time)


## Where planet `index` of `count` is round its orbit at `time`, in radians. Its depth is the sine of this.
static func _orbit_angle(index: int, count: int, time: float) -> float:
	return _planet_angle(index, count) + RING_SPEED[index % 2] * time


## A point on orbit `ring` at `angle` round it, `reach` from the core (on the unit disc). The orbit's tilt turns with
## `turn`.
static func _ellipse(ring: int, angle: float, reach: float, turn: float) -> Vector2:
	var tilt := RING_TILT[ring] + RING_TURN[ring] * turn
	var along := Vector2.from_angle(tilt)
	var across := along.orthogonal() * RING_FLAT[ring]
	return (along * cos(angle) + across * sin(angle)) * reach


## Unit-disc space to the circle's local space: the disc narrowed and leaned back, exactly as MagicCircle draws a
## centred style. LEARN: the glyphs and the planets are placed through this map and drawn in local space, not in the
## narrowed disc space, so they keep their shape while the orbits they sit on are squashed.
static func _local(point: Vector2, radius: float) -> Vector2:
	return Vector2(point.x * MagicCircle.CENTRED_SQUASH, point.y).rotated(MagicCircle.CENTRED_LEAN) * radius


## Two tilted orbits, each drawn twice: a soft halo and a thin bright line. Each is brighter on its nearer half. LEARN:
## the far half is not hidden behind the core, because the circle's light is additive and additive light cannot hide
## anything. Depth is a brightness gradient along each arc instead.
static func _orbits(pen: Pen, frame: Frame) -> void:
	for ring in RING_RADIUS.size():
		var halo := Color(frame.mid, 0.3 * frame.fade * frame.intro)
		var bright := Color(frame.hot, 0.85 * frame.fade * frame.intro)
		_orbit_stroke(pen, frame, ring, halo, frame.width * 3.2, 0.35)
		_orbit_stroke(pen, frame, ring, bright, frame.width, 0.2)


static func _orbit_stroke(pen: Pen, frame: Frame, ring: int, colour: Color, width: float, far_share: float) -> void:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for step in ORBIT_STEPS + 1:
		var angle := TAU * step / ORBIT_STEPS
		points.append(_local(_ellipse(ring, angle, RING_RADIUS[ring], frame.turn), frame.radius))
		colours.append(Color(colour, colour.a * lerpf(far_share, 1.0, 0.5 + 0.5 * sin(angle))))
	pen.lines(points, colours, width)


## The bright core: a halo in the element's colour, a pale centre and a star that pulses. It stands upright, not
## narrowed like the orbits, and it flares with each bolt (not under reduced motion, see frame_of).
static func _core(pen: Pen, frame: Frame) -> void:
	var lit := frame.fade * frame.intro * (0.85 + 0.15 * frame.flare)
	pen.disc(Vector2.ZERO, frame.radius * 0.9, Color(frame.mid, 0.05 * lit))
	pen.disc(Vector2.ZERO, frame.radius * 0.36, Color(frame.mid, 0.12 * lit))
	var swell := 0.0 if frame.reduced else STAR_SWELL * sin(frame.now * STAR_PULSE)
	var outer := frame.radius * 0.2 * (1.0 + swell)
	var star := _star_points(Vector2.ZERO, 8, outer, outer * 0.4, frame.turn * 0.25)
	pen.fill(star, Color(frame.hot, 0.5 * lit))
	star.append(star[0])
	pen.line(star, frame.width, Color(frame.mid, 0.8 * lit))
	pen.disc(Vector2.ZERO, frame.radius * 0.07 * (1.0 + 0.2 * frame.flare), Color(frame.hot, 0.95 * lit))


## The points of a star: `tips` points out to `outer` from `at`, the waists between them at `inner`, turned by `turn`.
static func _star_points(at: Vector2, tips: int, outer: float, inner: float, turn: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point in tips * 2:
		var reach := outer if point % 2 == 0 else inner
		points.append(at + Vector2.from_angle(turn - PI * 0.5 + TAU * point / (tips * 2.0)) * reach)
	return points


## The rings that run out through the core as each bolt leaves it (MagicCircle's pulses), drawn on the disc. Motion, so
## reduced motion has none.
static func _pulses(pen: Pen, frame: Frame, shocks: Array[float]) -> void:
	if frame.reduced:
		return
	for shock: float in shocks:
		var age := (frame.now - shock) / PULSE_SECONDS
		if age < 0.0 or age >= 1.0:
			continue
		var share := lerpf(0.25, 1.1, MagicCircle._ease_out(age))
		var colour := Color(frame.hot, 0.8 * (1.0 - age) * frame.fade)
		_disc_ring(pen, frame, share, frame.width * (1.0 + 2.0 * (1.0 - age)), colour)


## A ring on the disc itself (in its narrowed, leaned space), at `share` of the radius.
static func _disc_ring(pen: Pen, frame: Frame, share: float, width: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for step in ORBIT_STEPS + 1:
		points.append(_local(Vector2.from_angle(TAU * step / ORBIT_STEPS) * share, frame.radius))
	pen.line(points, width, colour)


## A planet at `at` (its place from planet_positions): a dim body with a bright rim and its role's glyph in prism
## colours. A calling planet glows, and brightens as the sweep passes its angle. On arrival it has a shock ring and a
## flare, which are motion, so reduced motion has neither.
static func _planet(pen: Pen, frame: Frame, planet: Planet, at: Vector2, total: int, sweep: float) -> void:
	var body := maxf(frame.radius * 0.1, 3.0)
	if not frame.reduced:
		_arrival_flourish(pen, frame, at, body, frame.now - planet.arrived_at)
	var lit := _lit(planet, sweep)
	var alpha := frame.fade * frame.intro * (0.45 + 0.55 * (0.5 + 0.5 * planet.depth))
	var hue := float(planet.index) / float(maxi(total, 1)) + frame.turn * 0.02
	if lit > 0.0:
		# A calling planet glows in its own prism colour: the sweep lights it in its place on the spectrum.
		pen.disc(at, body * 2.6, _prism(hue, 0.3 * lit * frame.fade))
	pen.disc(at, body, Color(frame.mid, (0.22 + 0.25 * lit) * alpha))
	pen.ring(at, body * 1.15, frame.width, Color(frame.hot, (0.75 + 0.25 * lit) * alpha))
	_glyph(pen, planet.role, at, body * 1.4, hue, alpha, frame.width)


## On arrival a shock ring runs out from the planet, and the planet flares. Both are over within a second.
static func _arrival_flourish(pen: Pen, frame: Frame, at: Vector2, body: float, age: float) -> void:
	if age < 0.0:
		return
	if age < SHOCK_SECONDS:
		var shock := age / SHOCK_SECONDS
		var radius := lerpf(body, frame.radius * 0.3, MagicCircle._ease_out(shock))
		pen.ring(at, radius, frame.width * 1.4, Color(frame.hot, 0.85 * (1.0 - shock) * frame.fade))
	if age < FLARE_SECONDS:
		var flare := age / FLARE_SECONDS
		pen.disc(at, body * (1.0 + 2.6 * (1.0 - flare)), Color(frame.mid, 0.4 * (1.0 - flare) * frame.fade))


## How lit a planet is: a calling planet glows, and is lit most as the sweep passes its angle on the rim.
static func _lit(planet: Planet, sweep: float) -> float:
	if not planet.calling:
		return 0.0
	if sweep < 0.0:
		return 0.45
	return 0.45 + 0.55 * pow(maxf(0.0, cos(sweep - planet.place.angle())), 6.0)


## A constellation line from a planet to the one before it: it grows out to its planet, shines bright as it arrives,
## then settles to its steady light (at once, with no flare, under reduced motion).
static func _link(pen: Pen, frame: Frame, start: Vector2, target: Vector2, arrived_at: float) -> void:
	var age := frame.now - arrived_at
	var grow := 1.0 if frame.reduced else clampf(age / LINK_GROW_SECONDS, 0.0, 1.0)
	var settle := clampf(age / LINK_BRIGHT_SECONDS, 0.0, 1.0)
	var bright := LINK_STEADY if frame.reduced else lerpf(LINK_FLARE, LINK_STEADY, settle)
	var finish := start.lerp(target, grow)
	var alpha := bright * frame.fade * frame.intro
	pen.segment(start, finish, frame.width * 3.0, Color(frame.mid, 0.2 * alpha))
	pen.segment(start, finish, frame.width * 0.9, Color(frame.hot, 0.9 * alpha))


## The sweep: a ray turning round the rim, with a trail behind it that fades to nothing. None while nothing calls.
static func _sweep(pen: Pen, frame: Frame, sweep: float) -> void:
	if sweep < 0.0:
		return
	var trail := PackedVector2Array([Vector2.ZERO])
	var colours := PackedColorArray([Color(frame.hot, 0.0)])
	for step in 3:
		var back := 0.6 - 0.3 * step
		trail.append(_local(Vector2.from_angle(sweep - back) * SWEEP_REACH, frame.radius))
		colours.append(Color(frame.hot, (0.02 + 0.2 * step) * frame.fade * frame.intro))
	pen.polygon(trail, colours)
	var ray := Vector2.from_angle(sweep)
	var inner := _local(ray * 0.12, frame.radius)
	var outer := _local(ray * SWEEP_REACH, frame.radius)
	pen.segment(inner, outer, frame.width * 1.2, Color(frame.hot, 0.75 * frame.fade))


## Motes that orbit: small points riding the two orbits at their own radii and speeds, brighter on the nearer side.
static func _motes(pen: Pen, frame: Frame) -> void:
	for mote in MOTES:
		var ring := mote % 2
		var share := fposmod(mote * 0.618034, 1.0)
		var reach := 0.3 + 0.62 * fposmod(mote * 0.3819, 1.0)
		var speed := (0.5 + share) * (1.0 if ring == 0 else -1.0)
		var angle := TAU * share + speed * frame.turn
		var at := _local(_ellipse(ring, angle, reach, frame.turn), frame.radius)
		var near := 0.3 + 0.6 * (0.5 + 0.5 * sin(angle))
		pen.disc(at, 1.4 * frame.width, Color(frame.hot, near * frame.fade * frame.intro))


## One of the seven roles' glyphs, upright at `at` in prism colours. A card with no role (a Spellforge shard) is the
## dot.
static func _glyph(pen: Pen, role: String, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	match role:
		"source":
			_glyph_spiral(pen, at, size, hue, alpha, width)
		"shape":
			_glyph_hexagon(pen, at, size, hue, alpha, width)
		"order":
			_glyph_brackets(pen, at, size, hue, alpha, width)
		"strike":
			_glyph_star(pen, at, size, hue, alpha, width)
		"guard":
			_glyph_shield(pen, at, size, hue, alpha, width)
		"import":
			_glyph_ring(pen, at, size, hue, alpha, width)
		_:
			_glyph_dot(pen, at, size, hue, alpha, width)


## A spiral turning one and a half times out from its centre.
static func _glyph_spiral(pen: Pen, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	for step in SPIRAL_STEPS + 1:
		var t := float(step) / SPIRAL_STEPS
		points.append(at + Vector2.from_angle(t * TAU * 1.5) * size * (0.15 + 0.85 * t))
	pen.lines(points, _prism_strip(points.size(), hue, 0.3, alpha), width)


## A hexagon, filled faintly under its outline.
static func _glyph_hexagon(pen: Pen, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	var points := PackedVector2Array()
	for side in 6:
		points.append(at + Vector2.from_angle(TAU * side / 6.0 - PI * 0.5) * size * 0.85)
	pen.fill(points, _prism(hue + 0.5, 0.18 * alpha))
	points.append(points[0])
	pen.lines(points, _prism_strip(points.size(), hue, 0.25, alpha), width)


## A pair of brackets, drawn as chevrons: the order's glyph.
static func _glyph_brackets(pen: Pen, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	var left := PackedVector2Array(
		[at + Vector2(0.4, -0.85) * size, at + Vector2(-0.3, 0.0) * size, at + Vector2(0.4, 0.85) * size]
	)
	var right := PackedVector2Array(
		[at + Vector2(-0.4, -0.85) * size, at + Vector2(0.3, 0.0) * size, at + Vector2(-0.4, 0.85) * size]
	)
	pen.lines(left, _prism_strip(3, hue, 0.12, alpha), width)
	pen.lines(right, _prism_strip(3, hue + 0.5, 0.12, alpha), width)


## A four-pointed star, its waists pinched in, with a bright centre: the strike's glyph.
static func _glyph_star(pen: Pen, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	var points := _star_points(at, 4, size, size * 0.22, 0.0)
	points.append(points[0])
	pen.lines(points, _prism_strip(points.size(), hue, 0.35, alpha), width)
	pen.disc(at, width * 1.4, _prism(hue + 0.5, alpha))


## A shield, its outline in prism colours, with an arc over its top: the guard's glyph.
static func _glyph_shield(pen: Pen, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	var points := PackedVector2Array(
		[
			at + Vector2(-0.75, -0.7) * size,
			at + Vector2(0.75, -0.7) * size,
			at + Vector2(0.75, 0.1) * size,
			at + Vector2(0.0, 0.95) * size,
			at + Vector2(-0.75, 0.1) * size,
		]
	)
	points.append(points[0])
	pen.lines(points, _prism_strip(points.size(), hue, 0.2, alpha), width)
	pen.arc(at, size * 1.25, PI * 1.15, PI * 1.85, width, _prism(hue + 0.4, alpha))


## A ring with ticks round it: the import's glyph.
static func _glyph_ring(pen: Pen, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	pen.ring(at, size * 0.9, width, _prism(hue, alpha))
	var ticks := PackedVector2Array()
	for tick in 8:
		var direction := Vector2.from_angle(TAU * tick / 8.0)
		ticks.append(at + direction * size * 0.9)
		ticks.append(at + direction * size * 1.25)
	pen.multiline(ticks, _prism(hue + 0.5, alpha), width)


## A plain dot in a ring: the utility glyph, and the one a role-less card takes.
static func _glyph_dot(pen: Pen, at: Vector2, size: float, hue: float, alpha: float, width: float) -> void:
	pen.disc(at, size * 0.4, _prism(hue, alpha))
	pen.ring(at, size * 0.9, width, _prism(hue + 0.33, 0.8 * alpha))


## A saturated colour of the spectrum, at `alpha`.
static func _prism(hue: float, alpha: float) -> Color:
	return Color.from_hsv(fposmod(hue, 1.0), 0.45, 1.0, alpha)


## One prism colour per point, the hue running from `hue` over `spread` of the wheel. LEARN: draw_polyline_colors takes
## one colour per point, so a hue that sweeps along a whole stroke costs one draw call.
static func _prism_strip(count: int, hue: float, spread: float, alpha: float) -> PackedColorArray:
	var colours := PackedColorArray()
	for index in count:
		colours.append(_prism(hue + spread * float(index) / float(maxi(count - 1, 1)), alpha))
	return colours
