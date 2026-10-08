class_name ConstellationVolley
extends Node2D
## The constellation bolts of one cast (docs/LEGENDARY_LOOKS.md, "The constellation bolt: a volley of
## riders"). One volley per cast owns each legendary bolt of that cast as a rider. A rider traces its
## route, flies it, flares at each star as the head passes, and lands once. The volley reads the orrery's
## last star once a frame, so every route turns with it, and converts each global target the same way.
## It draws with draw calls only, and frees itself once it is closed and every rider is done.

## The timeline, in seconds.
const TRACE_SECONDS := 0.32
const TRACE_REDUCED_SECONDS := 0.12
const FLIGHT_MIN_SECONDS := 0.12
const FLIGHT_MAX_SECONDS := 1.4
const IGNITE_SECONDS := 0.12
const FLARE_SECONDS := 0.35
const ORIGIN_SECONDS := 0.3
const BLOOM_SECONDS := 0.4
const ARRIVAL_FADE_SECONDS := 0.25
const LINE_FADE_SECONDS := 0.6
const STAR_KEEP_SECONDS := 0.8
const STAR_FADE_SECONDS := 0.3

## Sizes in pixels: a ring grows from a point to its radius, and sparks fly out to their reach.
const ORIGIN_RING := 22.0
const FIRST_RING_SCALE := 2.2
const FLARE_RING := 18.0
const BLOOM_RING := 56.0
const ORIGIN_REACH := 16.0
const FLARE_REACH := 20.0
const BLOOM_REACH := 44.0
const ORIGIN_SPARKS := 8
const FLARE_SPARKS := 6
const BLOOM_SPARKS := 12
const STAR_RADIUS := 6.0
const GLINT_LENGTH := 9.0
const RING_POINTS := 32
## A diamond under this many pixels across is not drawn (see diamond_is_drawn).
const MIN_DIAMOND_ACROSS := 0.5

## The trail's three strokes (wide and faint, body, white-hot core), the traced line and the sparks. Widths are before a
## rider's width scale. Alphas stay low: additive light clips to white when it stacks.
const OUTER_WIDTH := 9.0
const BODY_WIDTH := 4.2
const CORE_WIDTH := 1.6
const LINE_WIDTH := 1.5
const SPARK_WIDTH := 1.3
const OUTER_ALPHA := 0.22
const BODY_ALPHA := 0.6
const LINE_ALPHA := 0.55
const TRAIL_SHARE := 0.3
const TRAIL_SAMPLES := 8

## A bolt of this power or more draws its lines WIDE_SCALE times as wide.
const WIDE_POWER := 12.0
const WIDE_SCALE := 1.6
## Two targets this close are one foe: its bolts share a convergence point even if its point moves a pixel or two.
const SAME_TARGET_PX := 4.0
## A prism bolt's hue turns once across PRISM_SPAN of its route, and PRISM_TURNS_PER_SECOND of a turn each second.
const PRISM_SPAN := 0.8
const PRISM_TURNS_PER_SECOND := 0.35
## What a burst is (Burst.kind): an origin burst, a star's flare, or a convergence bloom.
const BURST_ORIGIN := "origin"
const BURST_FLARE := "flare"
const BURST_BLOOM := "bloom"
## The volley's draw layer, above the black hole's (1), so the convergence bloom is not hidden under the hole's disc.
# LEARN: z_index is relative to the parent, and the volley and the hole share one parent (the effects
# layer), so 2 over 1 orders them whatever their child order.
const Z_INDEX := 2

## How fast its time runs (a rehearsal stage slows it, ADR-0037); 1 in a fight.
var time_scale := 1.0
var _origin := Callable()
## The last origin read, in global coordinates. It is kept while the origin is not valid.
var _origin_global := Vector2.ZERO
var _riders: Array[Rider] = []
var _bursts: Array[Burst] = []
## The targets (global) that have had their convergence bloom. Reduced motion draws none, so it records none.
var _blooms := PackedVector2Array()
## Set by close(): no more bolts are expected, so the volley frees itself once its riders and flashes are done.
var _closed := false
var _finished := false
## Test-only. The draw calls the last draw pass made, counted by kind (see last_draw).
var _drawn := {}


## Starts a volley under `parent`, as its last child so it draws above what is there. `origin` returns the
## orrery's last star in global coordinates. Targets and the origin are global: each frame the volley converts
## them with `to_local`, so a parent that moves still aims right.
static func start(parent: Node, origin: Callable) -> ConstellationVolley:
	var volley := ConstellationVolley.new()
	volley.material = _additive()
	volley.z_index = Z_INDEX
	volley._origin = origin
	parent.add_child(volley)
	return volley


## Adds a bolt. `target` is global: the foe's point, or the hero's body point for a ward. `look` holds role, card,
## index, cast_serial, element_colour and power. `ms` is the flight in milliseconds, clamped to 0.12 to 1.4 s.
## `arrive` runs once, when the bolt lands. A bolt may join at any time before the volley frees itself, open or closed.
func add_rider(target: Vector2, look: Dictionary, ms: float, arrive: Callable) -> void:
	if _finished:
		# LEARN: the volley frees itself once it is closed and its riders are done. A bolt added after that still lands,
		# at once, so no hit is lost. The warning says the caller kept a volley past its life.
		push_warning("ConstellationVolley: a bolt was added after its volley freed itself, so it lands at once.")
		if arrive.is_valid():
			arrive.call()
		return
	var rider := _make_rider(target, look, ms, arrive)
	rider.origin_first = _riders.is_empty()
	rider.origin_pending = true
	_riders.append(rider)


## No more bolts are expected from this cast. The volley frees itself on the first frame after its last rider and flash
## are done. A bolt added before it frees still joins, so a late bolt flies rather than landing at once.
# LEARN: close() says no bolt is coming; it does not free the volley. A bolt that waits behind a falling blow can be
# added after the next cast has closed this volley, and it must still fly. Freeing waits for the riders, not the close.
func close() -> void:
	_closed = true


## Moves the volley on by `delta` seconds. `_process` calls it every frame with the frame's time times `time_scale`; a
## test steps it with a fixed delta.
func advance(delta: float) -> void:
	if _finished:
		return
	var origin_now := _read_origin()
	for rider: Rider in _riders:
		rider.age += delta
		# LEARN: a target is global, and the parent may move during a flight, so each target is converted every frame, as
		# the origin is. A target converted once, at the add, would aim where the parent was then.
		rider.route = ConstellationPath.route(origin_now, to_local(rider.target), rider.stars)
	for rider: Rider in _riders:
		_start_origin_burst(rider, origin_now)
		_fire_flares(rider)
		_arrive_if_due(rider)
	_age_bursts(delta)
	queue_redraw()
	if _closed and _is_all_done():
		_finish()


# LEARN: the scale is applied where the engine's delta arrives, as SpellAnim applies its own. A rehearsal stage
# steps its effects by hand through `_process`, passing seconds over its tempo, so the product is the seconds stepped.
func _process(frame_delta: float) -> void:
	advance(frame_delta * time_scale)


## Test-only. When a bolt is done, in seconds from its add: its longest fade has ended.
func done_seconds(index: int) -> float:
	return _riders[index].done_time()


## Test-only. A bolt's route, from the origin to the target, in this volley's own space as the last frame built it.
## `to_global` gives the global point.
func route_of(index: int) -> PackedVector2Array:
	return _riders[index].route


## Test-only. How many times each star of a bolt has flared, in star order.
func flare_counts(index: int) -> PackedInt32Array:
	return _riders[index].flares


## Test-only. When a bolt lands, in seconds from its add.
func arrival_seconds(index: int) -> float:
	return _riders[index].arrival_time()


## Test-only. The head's point in this volley's own space, as the last frame placed it: the origin while it waits
## in the trace.
func head_point(index: int) -> Vector2:
	var rider := _riders[index]
	return ConstellationPath.point_on(rider.route, rider.head())


## Test-only. Whether the head is drawn now: not during the trace, when the pen draws the route out.
func head_shown(index: int) -> bool:
	return _riders[index].head_visible()


## Test-only. The targets as they were given (global points) that have had their convergence bloom.
func bloom_targets() -> PackedVector2Array:
	return _blooms


## Test-only. The sparks alive now, across every burst.
func spark_count() -> int:
	var total := 0
	for burst: Burst in _bursts:
		total += burst.sparks.size()
	return total


## Test-only. The draw calls the last draw pass made, by kind: "line", "star", "ignite" (the flash), "ignite ring",
## "trail", and "glint" (the head's). For each burst kind ("origin", "flare", "bloom") its "ring", "spark" and "glint".
func last_draw() -> Dictionary:
	return _drawn.duplicate()


## Test-only. A bolt's colour at place `p` along its route, now: a prism bolt's palette turns with time at full motion.
func rider_colour(index: int, p: float) -> Color:
	return _riders[index].colour_at(p)


func _make_rider(target: Vector2, look: Dictionary, ms: float, arrive: Callable) -> Rider:
	var card := str(look.get("card", ""))
	var element: Color = look.get("element_colour", Color.WHITE)
	var bolt_seed := LegendaryLook.rider_seed(int(look.get("cast_serial", 0)), int(look.get("index", 0)), card)
	var style := LegendaryLook.bolt_style(str(look.get("role", "")), card, bolt_seed, element)
	var rider := Rider.new()
	rider.target = target
	rider.arrive = arrive
	rider.bolt_seed = bolt_seed
	rider.reduced = Settings.reduced_motion
	rider.trace = TRACE_REDUCED_SECONDS if rider.reduced else TRACE_SECONDS
	# LEARN: `ms` is milliseconds, the unit that BattleStage.fly and the flight table use. The contract words the clamp in
	# seconds, so the division happens here, once.
	rider.flight = clampf(ms / 1000.0, FLIGHT_MIN_SECONDS, FLIGHT_MAX_SECONDS)
	rider.stars = ConstellationPath.stars(bolt_seed, int(style["count"]), float(style["spread"]))
	rider.flares.resize(rider.stars.size())
	rider.prism = bool(style["prism"])
	rider.tint = style["colour"] as Color
	rider.width_scale = WIDE_SCALE if float(look.get("power", 0.0)) >= WIDE_POWER else 1.0
	return rider


## The orrery's last star in this volley's space, read once a frame. Without a valid origin, the last point read stays,
## in global coordinates, and is converted as the parent is now.
func _read_origin() -> Vector2:
	if _origin.is_valid():
		_origin_global = _origin.call()
	return to_local(_origin_global)


## A bolt's origin burst when it is added: a ring and eight sparks. The first bolt of a volley enlarges the flare on the
## orrery's last star, so its ring is larger and it has a glint.
func _start_origin_burst(rider: Rider, origin_now: Vector2) -> void:
	if not rider.origin_pending:
		return
	rider.origin_pending = false
	# LEARN: reduced motion drops the origin burst, its sparks and the bloom. The flights and the landings stay.
	if not full_motion():
		return
	var ring := ORIGIN_RING * (FIRST_RING_SCALE if rider.origin_first else 1.0)
	var burst := _burst(origin_now, ORIGIN_SECONDS, ring, rider.colour_at(1.0))
	burst.kind = BURST_ORIGIN
	burst.sparks = _sparks(rider.bolt_seed, ORIGIN_SPARKS, ORIGIN_REACH)
	burst.glint = rider.origin_first
	burst.width_scale = rider.width_scale
	_bursts.append(burst)


## Each star flares once, as the head passes it.
func _fire_flares(rider: Rider) -> void:
	for k: int in rider.stars.size():
		var star := k + 1
		if rider.flares[k] == 0 and rider.age >= rider.pass_time(star):
			rider.flares[k] += 1
			_bursts.append(_flare(rider, star))


func _flare(rider: Rider, star: int) -> Burst:
	var colour := rider.colour_at(float(star) / rider.segments())
	var burst := _burst(rider.route[star], FLARE_SECONDS, FLARE_RING, colour)
	burst.kind = BURST_FLARE
	burst.anchor = rider
	burst.point = star
	burst.glint = true
	burst.width_scale = rider.width_scale
	if full_motion():
		burst.sparks = _sparks(rider.bolt_seed + star * 131, FLARE_SPARKS, FLARE_REACH)
	return burst


## The landing: the bolt's `arrive` runs once. The last bolt aimed at a foe, if it has not bloomed yet, blooms there.
func _arrive_if_due(rider: Rider) -> void:
	if rider.arrived or rider.age < rider.arrival_time():
		return
	rider.arrived = true
	if rider.arrive.is_valid():
		rider.arrive.call()
	if _is_last_at(rider.target) and not _has_bloomed(rider.target):
		_bloom(rider)


## Whether no other bolt aimed at `target` is still flying.
func _is_last_at(target: Vector2) -> bool:
	for other: Rider in _riders:
		if not other.arrived and _same_target(other.target, target):
			return false
	return true


func _has_bloomed(target: Vector2) -> bool:
	for point: Vector2 in _blooms:
		if _same_target(point, target):
			return true
	return false


## A foe's convergence bloom: a ring and twelve sparks where its last bolt landed. It is anchored to the route's last
## point, the target, so it stays on the foe while the parent moves.
func _bloom(rider: Rider) -> void:
	if not full_motion():
		return
	_blooms.append(rider.target)
	var last := rider.route.size() - 1
	var burst := _burst(rider.route[last], BLOOM_SECONDS, BLOOM_RING, rider.colour_at(1.0))
	burst.kind = BURST_BLOOM
	burst.anchor = rider
	burst.point = last
	burst.sparks = _sparks(rider.bolt_seed + 977, BLOOM_SPARKS, BLOOM_REACH)
	_bursts.append(burst)


## Ages every burst, moves each flare to its star and each bloom to its foe, and drops the bursts that are over.
func _age_bursts(delta: float) -> void:
	# LEARN: the orrery turns during a flight, and a parent may move, so a flare follows its star and a bloom its foe each
	# frame, instead of staying where they started.
	var alive: Array[Burst] = []
	for burst: Burst in _bursts:
		burst.age += delta
		if burst.anchor != null and burst.point < burst.anchor.route.size():
			burst.centre = burst.anchor.route[burst.point]
		if not burst.is_over():
			alive.append(burst)
	_bursts = alive


## Whether every rider is done and every flash is over.
func _is_all_done() -> bool:
	for rider: Rider in _riders:
		if not rider.is_done():
			return false
	return _bursts.is_empty()


func _finish() -> void:
	_finished = true
	queue_free()


func _draw() -> void:
	_drawn.clear()
	for rider: Rider in _riders:
		if rider.route.size() > 1 and not rider.is_done():
			_draw_rider(rider)
	for burst: Burst in _bursts:
		# LEARN: under reduced motion only a star's flare is drawn, and only its glint. An origin burst or a bloom begun at
		# full motion is not drawn once the setting changes: it ages out unseen, so the setting takes effect at once.
		if burst.kind == BURST_FLARE or full_motion():
			_draw_burst(burst)


## Counts one draw call of `kind` in the draw pass in progress, for last_draw.
func _note(kind: String) -> void:
	_drawn[kind] = int(_drawn.get(kind, 0)) + 1


func _draw_rider(rider: Rider) -> void:
	_draw_traced_line(rider)
	_draw_stars(rider)
	_draw_trail(rider)


## The route as the pen traced it: each segment drawn out, then fading once the head has passed its far end.
func _draw_traced_line(rider: Rider) -> void:
	var segments := rider.segments()
	var pen := rider.pen() * segments
	for k: int in segments:
		var drawn := clampf(pen - k, 0.0, 1.0)
		if drawn <= 0.0:
			return
		var from := rider.route[k]
		var colour := rider.colour_at((k + 0.5) / segments)
		colour.a = LINE_ALPHA * rider.line_alpha(k)
		draw_line(from, from.lerp(rider.route[k + 1], drawn), colour, LINE_WIDTH * rider.width_scale)
		_note("line")


## Each star ignites as the pen reaches it: a white flash, a ring and a scale-in over IGNITE_SECONDS. Then it
## stays a diamond until STAR_KEEP_SECONDS after the head passes it.
func _draw_stars(rider: Rider) -> void:
	for k: int in rider.stars.size():
		var star := k + 1
		var ignite := rider.ignite_time(star)
		if rider.age < ignite:
			continue
		var grow := clampf((rider.age - ignite) / IGNITE_SECONDS, 0.0, 1.0)
		var at := rider.route[star]
		var colour := rider.colour_at(float(star) / rider.segments())
		colour.a = rider.star_alpha(star)
		_draw_diamond(at, STAR_RADIUS * _ease_out(grow), colour)
		if grow < 1.0:
			_draw_ignition(at, grow, colour)


## The ignition flash: a white disc that shrinks and fades as the star scales in. Under full
## motion, a ring grows round it.
# LEARN: reduced motion keeps the flash and drops the ring around it. The ring is the growing
# motion the contract removes (docs/LEGENDARY_LOOKS.md, Reduced motion).
func _draw_ignition(at: Vector2, grow: float, colour: Color) -> void:
	var fading := 1.0 - grow
	draw_circle(at, STAR_RADIUS * 1.6 * fading, _with_alpha(Color.WHITE, 0.6 * fading))
	_note("ignite")
	if not full_motion():
		return
	draw_arc(at, lerpf(3.0, 16.0, grow), 0.0, TAU, RING_POINTS, _with_alpha(colour, fading), LINE_WIDTH, true)
	_note("ignite ring")


## Whether a diamond of this radius is drawn: not one under MIN_DIAMOND_ACROSS across.
# LEARN: a near-zero diamond is skipped. A polygon that small fails to triangulate ("Invalid polygon data, triangulation
# failed"), and no one could see it anyway.
static func diamond_is_drawn(radius: float) -> bool:
	return radius * 2.0 >= MIN_DIAMOND_ACROSS


func _draw_diamond(at: Vector2, radius: float, colour: Color) -> void:
	if not diamond_is_drawn(radius) or colour.a <= 0.0:
		return
	var points := PackedVector2Array(
		[
			at + Vector2(0.0, -radius),
			at + Vector2(radius, 0.0),
			at + Vector2(0.0, radius),
			at + Vector2(-radius, 0.0),
		]
	)
	draw_colored_polygon(points, colour)
	_note("star")


## The comet's trail: three strokes over each other, a wide faint one behind, a narrow bright one at the head, and a
## white-hot core. Each sample takes its colour from its place along the route, and the head has a glint. The head is
## hidden through the trace.
func _draw_trail(rider: Rider) -> void:
	if not rider.head_visible():
		return
	var head := rider.head()
	var fade := rider.fade()
	if head <= 0.0 or fade <= 0.0:
		return
	var tail := maxf(0.0, head - TRAIL_SHARE)
	var points := PackedVector2Array()
	var outer := PackedColorArray()
	var body := PackedColorArray()
	var core := PackedColorArray()
	for i: int in TRAIL_SAMPLES:
		var along := float(i) / (TRAIL_SAMPLES - 1)
		var p := lerpf(tail, head, along)
		var colour := rider.colour_at(p)
		points.append(ConstellationPath.point_on(rider.route, p))
		outer.append(_with_alpha(colour, OUTER_ALPHA * along * fade))
		body.append(_with_alpha(colour, BODY_ALPHA * along * along * fade))
		core.append(_with_alpha(rider.core_colour(), along * along * along * fade))
	var widen := rider.width_scale
	draw_polyline_colors(points, outer, OUTER_WIDTH * widen)
	draw_polyline_colors(points, body, BODY_WIDTH * widen)
	draw_polyline_colors(points, core, CORE_WIDTH * widen)
	_note("trail")
	_draw_glint(points[points.size() - 1], GLINT_LENGTH * widen, rider.core_colour(), fade)


## A four-point glint: two long rays and two short diagonals. `kind` is the name it counts under in last_draw.
func _draw_glint(at: Vector2, length: float, colour: Color, alpha: float, kind: String = "glint") -> void:
	if length <= 0.0 or alpha <= 0.0:
		return
	var lit := _with_alpha(colour, alpha)
	var diag := length * 0.45
	draw_line(at - Vector2(length, 0.0), at + Vector2(length, 0.0), lit, 1.2)
	draw_line(at - Vector2(0.0, length), at + Vector2(0.0, length), lit, 1.2)
	draw_line(at - Vector2(diag, diag), at + Vector2(diag, diag), lit, 0.8)
	draw_line(at - Vector2(diag, -diag), at + Vector2(diag, -diag), lit, 0.8)
	_note(kind)


## A flash: a ring that grows and fades, a glint for a flare or the first bolt, and its sparks. Reduced motion keeps
## only the glint, which shrinks and fades where it stands: the ring and the sparks are the motion.
# LEARN: reduced motion drops the ring and the sparks, but not the glint. The glint does not grow, so a star's flare
# still shows that it flared, as the contract's static glint.
func _draw_burst(burst: Burst) -> void:
	var u := burst.progress()
	var fade := 1.0 - u
	var full := full_motion()
	if full:
		var radius := lerpf(burst.radius_from, burst.radius_to, _ease_out(u))
		var ring := _with_alpha(burst.colour, 0.6 * fade * fade)
		draw_arc(burst.centre, radius, 0.0, TAU, RING_POINTS, ring, LINE_WIDTH * burst.width_scale, true)
		_note(burst.kind + " ring")
	if burst.glint:
		_draw_glint(burst.centre, GLINT_LENGTH * 1.8 * pow(fade, 0.7), burst.colour, fade, burst.kind + " glint")
	if full:
		_draw_burst_sparks(burst, u)


## A burst's sparks, each flying out from the centre as the flash ages, with its tail a little behind its head.
func _draw_burst_sparks(burst: Burst, u: float) -> void:
	var fade := 1.0 - u
	for spark: Vector2 in burst.sparks:
		var head_at := burst.centre + spark * _ease_out(u)
		var tail_at := burst.centre + spark * _ease_out(maxf(0.0, u - 0.2))
		draw_line(tail_at, head_at, _with_alpha(burst.colour, fade), SPARK_WIDTH * burst.width_scale)
		_note(burst.kind + " spark")


static func _burst(centre: Vector2, seconds: float, radius: float, colour: Color) -> Burst:
	var burst := Burst.new()
	burst.centre = centre
	burst.duration = seconds
	burst.radius_to = radius
	burst.colour = colour
	return burst


## Spark directions, each a unit vector times its reach. They come from `salt`, so a burst looks the same each time.
static func _sparks(salt: int, count: int, reach: float) -> PackedVector2Array:
	var sparks := PackedVector2Array()
	for k: int in count:
		var angle := TAU * LegendaryLook.unit(salt, k)
		var length := reach * (0.6 + 0.4 * LegendaryLook.unit(salt, count + k))
		sparks.append(Vector2.from_angle(angle) * length)
	return sparks


## The prism palette: a cosine palette with the channels a third of a turn apart, as the black hole's.
static func prism_colour(turn: float) -> Color:
	return Color(
		0.5 + 0.5 * cos(TAU * turn),
		0.5 + 0.5 * cos(TAU * (turn + 1.0 / 3.0)),
		0.5 + 0.5 * cos(TAU * (turn + 2.0 / 3.0))
	)


## Whether the volley draws its full effects: origin bursts, sparks, convergence blooms, prism cycling, and the
## rings of an ignition, a flare and a bloom. Reduced motion (Settings.reduced_motion) turns them off, except
## that a flare keeps its glint.
# LEARN: the setting is read as each effect starts and as it is drawn, not once when a bolt is added, so turning
# reduced motion on during a cast stops the sparks and blooms at once. The trace keeps the length it was given: a
# timeline cannot change length mid-flight without jumping.
static func full_motion() -> bool:
	return not Settings.reduced_motion


## The glow's material: every line and ring adds its light to what lies beneath it.
# LEARN: one additive material on the whole volley, so overlapping lines and rings add light instead of covering each
# other. Stacked additive light clips to white, which is why the alphas here are low.
static func _additive() -> CanvasItemMaterial:
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return glow


static func _with_alpha(colour: Color, alpha: float) -> Color:
	return Color(colour.r, colour.g, colour.b, alpha)


static func _ease_out(u: float) -> float:
	return 1.0 - (1.0 - u) * (1.0 - u)


## Whether two targets are one foe.
# LEARN: the contract gives one point per foe. The few pixels of slack keep a foe's bolts together if its point drifts a
# little between two adds, so the convergence bloom still comes once per foe.
static func _same_target(a: Vector2, b: Vector2) -> bool:
	return a.distance_squared_to(b) <= SAME_TARGET_PX * SAME_TARGET_PX


## One bolt of the volley: its stars, its clock, and what it has done. Times are seconds from its add.
class Rider:
	extends RefCounted
	## The target, in global coordinates, as it was given.
	var target := Vector2.ZERO
	var bolt_seed := 0
	var tint := Color.WHITE
	var prism := false
	## Reduced motion when the bolt was added. It sets the trace's length only: the effects read the setting as they run.
	var reduced := false
	var trace := 0.0
	var flight := 0.0
	var age := 0.0
	var width_scale := 1.0
	var arrive := Callable()
	var arrived := false
	var origin_pending := false
	var origin_first := false
	## Each star as Vector2(t, s), and how many times each star has flared.
	var stars := PackedVector2Array()
	var flares := PackedInt32Array()
	## The route as the last frame built it: the origin, each star, then the target.
	var route := PackedVector2Array()

	func segments() -> int:
		return stars.size() + 1

	func arrival_time() -> float:
		return trace + flight

	## When the head passes route point `k`: 0 is the origin and segments() is the target. The flight takes equal shares.
	func pass_time(k: int) -> float:
		return trace + flight * float(k) / float(segments())

	## When the pen reaches star `star` (1-based) during the trace.
	func ignite_time(star: int) -> float:
		return trace * float(star) / float(segments())

	## The pen's progress along the route during the trace, 0 to 1.
	func pen() -> float:
		return clampf(age / trace, 0.0, 1.0)

	## The head's progress along the route: 0 at the origin through the trace, where the head waits hidden, then the
	## flight's progress.
	func head() -> float:
		return clampf((age - trace) / flight, 0.0, 1.0)

	## Whether the head is drawn: not during the trace, when only the pen moves.
	func head_visible() -> bool:
		return age >= trace

	## The trail's opacity: full until the landing, then fading over ARRIVAL_FADE_SECONDS.
	func fade() -> float:
		var since := age - arrival_time()
		return clampf(1.0 - since / ConstellationVolley.ARRIVAL_FADE_SECONDS, 0.0, 1.0)

	## A star's opacity: full until the head passes it, kept STAR_KEEP_SECONDS, fading over the last STAR_FADE_SECONDS.
	func star_alpha(star: int) -> float:
		var since := age - pass_time(star)
		if since <= 0.0:
			return 1.0
		var left := ConstellationVolley.STAR_KEEP_SECONDS - since
		return clampf(left / ConstellationVolley.STAR_FADE_SECONDS, 0.0, 1.0)

	## The traced line's opacity for segment `k` (0-based): full until the head passes its far end, then fading.
	func line_alpha(k: int) -> float:
		var since := age - pass_time(k + 1)
		if since <= 0.0:
			return 1.0
		return clampf(1.0 - since / ConstellationVolley.LINE_FADE_SECONDS, 0.0, 1.0)

	## When everything this bolt draws is gone: the traced line's fade after the landing, or the last star's keep.
	# LEARN: the trail's 0.25 s fade is not the end. The traced line and the last star keep their own longer fades, so a
	# rider is done only when the longest of them has ended. Freeing at the landing would cut those fades short.
	func done_time() -> float:
		var line_done := arrival_time() + ConstellationVolley.LINE_FADE_SECONDS
		var stars_done := pass_time(stars.size()) + ConstellationVolley.STAR_KEEP_SECONDS
		return maxf(line_done, stars_done)

	func is_done() -> bool:
		return age >= done_time()

	## The colour at place `p` along the route: the tint, or for a prism bolt the palette. The palette cycles
	## with time at full motion.
	func colour_at(p: float) -> Color:
		if not prism:
			return tint
		var turn := 0.0
		if ConstellationVolley.full_motion():
			turn = age * ConstellationVolley.PRISM_TURNS_PER_SECOND
		return ConstellationVolley.prism_colour(p * ConstellationVolley.PRISM_SPAN + turn)

	## The white-hot core of the trail: the prism core, or the tint lifted towards white.
	func core_colour() -> Color:
		return LegendaryLook.PRISM_CORE if prism else tint.lerp(Color.WHITE, 0.75)


## A flash at one point: a ring that grows and fades, an optional glint, and sparks. A flare or a bloom follows a
## point of its rider's route: `anchor` is the rider and `point` the index, so it moves each frame.
class Burst:
	extends RefCounted
	var centre := Vector2.ZERO
	var anchor: Rider = null
	var point := 0
	var age := 0.0
	var duration := 0.3
	var radius_from := 3.0
	var radius_to := 20.0
	var colour := Color.WHITE
	## BURST_ORIGIN, BURST_FLARE or BURST_BLOOM: the draw rules and the census (last_draw) read it.
	var kind := ""
	var glint := false
	var width_scale := 1.0
	## Each spark's direction times its reach, in pixels.
	var sparks := PackedVector2Array()

	func progress() -> float:
		return clampf(age / duration, 0.0, 1.0)

	func is_over() -> bool:
		return age >= duration
