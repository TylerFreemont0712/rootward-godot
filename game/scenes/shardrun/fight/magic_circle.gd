class_name MagicCircle
extends Node2D
## A magic circle written in the air in front of the caster, as isekai anime draws them (ADR-0030): a disc standing
## between her and the foes, facing them, so it is seen narrowed. It writes itself (rings drawn like pen strokes, a
## core lit) and, shard by shard, the spell's layers (ADR-0039): each shard of the spell adds one figure to the stack
## (CircleLayerArt), a rune ring, a ruled star, a honeycomb, orbiting letters, as it is played. It stays turning while
## the volley lasts, flares as each bolt leaves it, and closes when the program has finished. A spell of more shards
## is a larger circle (its tier, CircleLayers) with more, smaller circles stacked in front of the first, the bolts
## passing through them all. Drawn in code, in the element's colours, added onto the stage as light.
##
##   var circle := MagicCircle.cast(fx, at, 2, "fire", 110.0)
##   circle.use_plan(CircleLayers.plan(cards))        # one layer per shard
##   await circle.formed                              # its blow: the first bolt may leave
##   stage.fly(circle.launch_point(), ...)            # every bolt is born on its front circle
##   circle.pulse()
##   circle.close()                                   # the volley is over

## The circle has finished writing itself: the strike lands on it now.
signal formed
## The layer of the shard at `index` (0 the first played) has just arrived on the circle.
signal layer_added(index: int)

## Per tier: how long it takes to write itself (the beats of the sheets it replaced, so their sounds still land, and
## the budget its layers share), the sound it brings, how many smaller circles stand in front of it, and the ticks of
## its rim. The shards that write it, and so its layers, are CircleLayers'.
const TIERS: Array[Dictionary] = [
	{"form": 0.62, "sound": "sfx-cast-tier-1", "front": 1, "ticks": 36},
	{"form": 0.86, "sound": "sfx-cast-tier-2", "front": 1, "ticks": 48},
	{"form": 1.0, "sound": "sfx-cast-tier-3", "front": 2, "ticks": 60},
	{"form": 1.23, "sound": "sfx-cast-tier-4", "front": 3, "ticks": 72},
]
## Where the layers stand: the first played outermost, the last innermost (shares of the radius). One alone stands at
## the middle one.
const LAYER_OUTER := 0.8
const LAYER_INNER := 0.3
const LAYER_ALONE := 0.74
## A layer's arrival is heard at this share of the tier's volume, rising a little with each.
const LAYER_SOUND := 0.55
## The disc faces the foes, so from the camera it is narrowed to this share of its width, leaning back this far.
const SQUASH := 0.46
const TILT := -0.1
## How far in front of the first circle each smaller one stands (in radii), and how much smaller it is.
const STACK_STEP := 0.55
const STACK_SHRINK := 0.68
const CLOSE_SECONDS := 0.42
## A resolved shard writes its contribution over this many stage seconds.
const SHARD_DRAW_SECONDS := 0.34
const RUNES_FALLBACK := "λ ∑ { } => ; ∀ ∃ ( ) 0 1 ⊕ ⊗ != == [ ] ≤ ≥ :: -> & | ^"
## The elements whose layer (sfx-element-fire ...) sounds as the circle completes.
const ELEMENT_LAYERS: Array[String] = ["fire", "frost", "spark"]

## How fast its time runs (a rehearsal stage slows it, ADR-0037); 1 in a fight.
var time_scale := 1.0
var tier := 0
## How it is drawn (ADR-0037): "codex" (the pen-stroke rings and ruled star below), or one of CircleStyles'.
var style := "codex"
## A preview (a carousel card) writes itself without a sound.
var silent := false
var radius := 100.0
## How fast it writes itself (a snapped spell writes faster); once complete it turns at its own pace.
var speed := 1.0
var dark := Color.BLACK
var mid := Color.WHITE
var hot := Color.WHITE
var runes := RUNES_FALLBACK
var clock := 0.0
## The spell's layers (CircleLayers.plan), one per shard.
var layers: Array[Dictionary] = []
## Shard Weave takes its arrivals from the code walkthrough, rather than the tier's automatic timer.
var external_construction := false
var _layer_times: Array[float] = []
## A negative share uses the rehearsal clock; a traced share follows the current function's walkthrough.
var _traced_shares: Array[float] = []
var _sealed := false
var _facts: Dictionary = {}
var _formed := false
var _formed_at := 0.0
var _flare := 0.0
var _shocks: Array[float] = []
var _closing := -1.0
## How many of the layers have arrived so far.
var _arrived := 0
## Reduced motion (ADR-0030): the layers appear whole, without their arrival flourishes.
var _reduced := false
## The main disc's transform as last drawn (set by _disc_space), for the glyphs a layer sets upright in it.
var _disc_xf := Transform2D.IDENTITY
var _font: Font
var _element := "none"
## Light in the air round it: [position, velocity, age, life, size] in this node's space.
var _motes: Array[Array] = []
var _mote_debt := 0.0


## Writes a circle of `tier` (0..3) at `at` in `parent`, `size` pixels in radius, in `element`'s colours, with `words`
## (the spell's own function names) as its runes.
static func cast(
	parent: Node,
	at: Vector2,
	circle_tier: int,
	element: String,
	size: float,
	words := "",
	writing_speed := 1.0,
	silent := false
) -> MagicCircle:
	var circle := MagicCircle.new()
	circle.speed = maxf(writing_speed, 0.1)
	circle.tier = clampi(circle_tier, 0, TIERS.size() - 1)
	circle._facts = TIERS[circle.tier]
	circle.radius = size
	circle.position = at
	circle._element = element
	var ramp: Array = SpellAnim.RAMPS.get(element, SpellAnim.RAMPS.none)
	circle.dark = Color(ramp[0])
	circle.mid = Color(ramp[1])
	circle.hot = Color(ramp[2])
	if words.strip_edges() != "":
		circle.runes = words
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.material = light
	circle._font = UiTheme.crt_font()
	circle.silent = silent
	circle._reduced = Settings.reduced_motion
	parent.add_child(circle)
	if not silent:
		Sound.play(String(circle._facts.sound), SpellAnim.SOUND_VOLUME, circle.speed)
	return circle


## Gives the circle the layers of a spell, one per shard (CircleLayers.plan): they arrive in order while it writes
## itself. Set before the first frame; a circle with none is the bare frame.
func use_plan(plan: Array[Dictionary]) -> void:
	layers = plan


## Only the next shard may add a layer. Repeated or out-of-order callbacks cannot duplicate the drawing.
func construct_shard(index: int) -> void:
	if not external_construction or _sealed or _closing >= 0.0 or index != _arrived or index >= layers.size():
		return
	_layer_times.append(clock)
	_traced_shares.append(-1.0)
	_add_layer(index)
	_arrived += 1
	queue_redraw()


## LEARN: Function progress owns the stroke, so a long function cannot finish its figure on a separate timer.
## Only the current or next layer can be traced, and old callbacks never erase strokes already written.
func trace_shard(index: int, progress: float) -> void:
	if not external_construction or _sealed or _closing >= 0.0 or index < 0 or index >= layers.size():
		return
	if index == _arrived:
		_layer_times.append(clock)
		_traced_shares.append(clampf(progress, 0.0, 1.0))
		_arrived += 1
		_add_layer(index)
	elif index == _arrived - 1 and _traced_shares[index] >= 0.0:
		_traced_shares[index] = maxf(_traced_shares[index], clampf(progress, 0.0, 1.0))
	queue_redraw()


## The walkthrough ended. A failed program can seal a partial circle without inventing unexecuted shards.
func finish_construction() -> void:
	_sealed = true


func is_constructed() -> bool:
	return _formed


func construction_time_left() -> float:
	if _reduced or _layer_times.is_empty():
		return 0.0
	var remaining := 0.0
	for index in _arrived:
		if _traced_shares[index] < 0.0:
			remaining = maxf(remaining, SHARD_DRAW_SECONDS - (clock - _layer_times[index]))
	return remaining


## The frame grows alongside the layers, never ahead of the walkthrough.
func construction_share() -> float:
	if layers.is_empty():
		return 1.0 if _sealed else 0.0
	var written := 0.0
	for index in _arrived:
		written += _layer_progress(index)
	return written / float(layers.size())


## Seconds from its first stroke to its completion (the strike's beat), in real time.
func form_time() -> float:
	return _form() / speed


## The same in the circle's own clock (which runs `speed` times faster while it writes itself).
func _form() -> float:
	return float(_facts.get("form", 0.8))


## Sparks thrown from `point` (in the parent's coordinates) into the circle: the fingers' snap that called it.
func spark_from(point: Vector2) -> void:
	var from := point - position
	for i in 14:
		var toward := (_disc_origin(0) - from).normalized().rotated(randf_range(-0.6, 0.6))
		_motes.append([from, toward * randf_range(160.0, 420.0), 0.0, randf_range(0.18, 0.34), randf_range(1.4, 2.6)])


## Where a bolt is born: somewhere on the front circle, in the parent's coordinates.
func launch_point() -> Vector2:
	if style == "script-loom":
		return position
	var front := int(_facts.front)
	var angle := randf() * TAU
	var reach := radius * pow(STACK_SHRINK, front) * randf_range(0.0, 0.45)
	return position + _disc_origin(front) + Vector2(cos(angle) * SQUASH, sin(angle)).rotated(TILT) * reach


## A bolt has left: the circle flares and a ring of light runs out through it.
func pulse() -> void:
	_flare = 1.0
	_shocks.append(clock)
	_burst(_disc_origin(int(_facts.front)), 8 + 2 * tier, 1.0, radius * pow(STACK_SHRINK, int(_facts.front)))


## The volley is over: the circle spins up, swells and fades, its runes scattering, then it is gone.
func close() -> void:
	if _closing < 0.0:
		_closing = clock
		_burst(_disc_origin(0), 18, 0.2, radius * 0.7)


func _process(frame_delta: float) -> void:
	var delta := frame_delta * time_scale
	clock += delta * (speed if not _formed and not external_construction else 1.0)
	_flare = maxf(0.0, _flare - delta * 4.0)
	# Motes spiral in while it writes itself and drift off its rim while it stands.
	var writing := not external_construction
	for index in _arrived:
		writing = writing or _layer_progress(index) < 1.0
	_mote_debt += delta * (36.0 if not _formed else 5.0 + 3.0 * tier) * (0.0 if _closing >= 0.0 or not writing else 1.0)
	while _mote_debt >= 1.0:
		_mote_debt -= 1.0
		_spawn_mote(not _formed)
	while (
		not external_construction
		and _arrived < layers.size()
		and _closing < 0.0
		and clock >= _layer_start(_arrived) * _form()
	):
		_add_layer(_arrived)
		_arrived += 1
	var complete := _sealed and construction_time_left() <= 0.0 if external_construction else clock >= _form()
	if not _formed and complete and _closing < 0.0:
		_formed = true
		_formed_at = clock
		_flare = 1.4
		_shocks.append(clock)
		_burst(_disc_origin(0), 26 + 8 * tier, 1.0, radius * 0.9)
		if _element in ELEMENT_LAYERS and not silent:
			Sound.play("sfx-element-" + _element, SpellAnim.SOUND_VOLUME * 0.8)
		formed.emit()
	for mote in _motes:
		mote[0] += mote[1] * delta
		mote[1] *= 1.0 - 2.2 * delta
		mote[2] += delta
	_motes = _motes.filter(func(mote: Array) -> bool: return mote[2] < mote[3])
	if _closing >= 0.0 and clock - _closing >= CLOSE_SECONDS:
		queue_free()
	queue_redraw()


## When layer `index` lands, in the circle's own clock.
func _layer_start(index: int) -> float:
	return CircleLayers.start_share(index, layers.size())


## Layer `index` arrives: a burst of light where it will stand, a sound that climbs with each, and the signal.
func _add_layer(index: int) -> void:
	var stands := radius * _layer_share(index)
	if not _reduced and not external_construction:
		_burst(_disc_origin(0), 6 + tier, 0.0, stands)
	_flare = maxf(_flare, 0.45)
	if not silent:
		Sound.play("sfx-cast-layer", SpellAnim.SOUND_VOLUME * LAYER_SOUND, 0.88 + 0.07 * index)
	layer_added.emit(index)


## Where layer `index` stands, as a share of the circle's radius.
func _layer_share(index: int) -> float:
	if layers.size() <= 1:
		return LAYER_ALONE
	return lerpf(LAYER_OUTER, LAYER_INNER, float(index) / float(layers.size() - 1))


## How far in layer `index`'s band reaches, as a share of the radius: to just short of the next layer's, the innermost
## to the middle.
func _layer_inner(index: int) -> float:
	var count := layers.size()
	if count <= 1:
		return 0.12
	var step := (LAYER_OUTER - LAYER_INNER) / float(count - 1)
	return _layer_share(index) - step * 1.25 if index < count - 1 else 0.1


## 0 → 1 as layer `index` draws itself in; 0 before it arrives.
func _layer_progress(index: int) -> float:
	if external_construction:
		if index >= _arrived:
			return 0.0
		if _traced_shares[index] >= 0.0:
			return 1.0 if _reduced else _traced_shares[index]
		return 1.0 if _reduced else clampf((clock - _layer_times[index]) / SHARD_DRAW_SECONDS, 0.0, 1.0)
	return clampf((clock / _form() - _layer_start(index)) / CircleLayers.DRAW, 0.0, 1.0) if index < _arrived else 0.0


## A point on disc `index` at `angle`, `r` from its centre, in this node's space (the disc seen narrowed).
func _on_disc(index: int, angle: float, r: float) -> Vector2:
	return _disc_origin(index) + Vector2(cos(angle) * SQUASH, sin(angle)).rotated(TILT) * r


func _spawn_mote(inward: bool) -> void:
	var angle := randf() * TAU
	if inward:
		var from := _on_disc(0, angle, radius * randf_range(1.15, 1.6))
		var to := _on_disc(0, angle + 0.8, radius * randf_range(0.2, 0.9))
		_motes.append([from, (to - from) * 2.4, 0.0, 0.42, randf_range(1.2, 2.4)])
	else:
		var from := _on_disc(0, angle, radius * 0.95)
		_motes.append([from, Vector2(randf_range(-10, 30), randf_range(-60, -25)), 0.0, 0.9, randf_range(1.0, 2.0)])


## Sparks thrown out from `at`, mostly toward the foes when `forward` is high.
func _burst(at: Vector2, count: int, forward: float, spread: float) -> void:
	for i in count:
		var angle := randf() * TAU
		var speed := randf_range(0.6, 1.4) * spread * 2.2
		var velocity := Vector2(cos(angle) * SQUASH, sin(angle)).rotated(TILT) * speed
		velocity.x += forward * randf_range(0.0, 1.0) * spread * 1.6
		_motes.append([at, velocity, 0.0, randf_range(0.25, 0.5), randf_range(1.4, 2.8)])


## An awaited signal that never fired would hold its waiter forever: a circle taken off early still completes.
func _exit_tree() -> void:
	if not _formed:
		_formed = true
		formed.emit()


## The centre of disc `index` (0 the first, then the smaller ones in front, toward the foes), from this node.
func _disc_origin(index: int) -> Vector2:
	var along := 0.0
	for i in index:
		along += radius * STACK_STEP * pow(STACK_SHRINK, i)
	return Vector2(along, 0.0).rotated(TILT)


## 0 → 1 as `clock` crosses the share `from`..`to` of the forming time.
func _phase(from: float, to: float) -> float:
	var u := construction_share() if external_construction else clock / _form()
	# LEARN: remap early frame phases to the entire shard sequence. Its rim must keep writing until the last shard.
	if external_construction and to <= 0.5:
		return u
	return clampf((u - from) / (to - from), 0.0, 1.0)


func _draw() -> void:
	if external_construction and _arrived == 0:
		return
	var closing := 0.0 if _closing < 0.0 else clampf((clock - _closing) / CLOSE_SECONDS, 0.0, 1.0)
	var fade := 1.0 - closing * closing
	var swell := 1.0 + closing * 0.35
	var pop := 1.0 + 0.08 * maxf(0.0, _flare - 0.4)
	var breathe := 0.85 + 0.15 * sin(clock * 5.0)
	if style == "script-loom":
		var turn := (clock - _formed_at) * 0.08 if _formed else 0.0
		_disc_xf = Transform2D(-0.12, Vector2(0.72, 1.0), 0.0, Vector2.ZERO) * Transform2D(turn, Vector2.ZERO)
		draw_set_transform_matrix(_disc_xf)
		ScriptLoom.draw(self, radius * swell, fade)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	# The smaller circles in front first, so the first circle is laid over them toward the caster.
	for index in range(int(_facts.front), 0, -1):
		var appear := _front_appear(index)
		if appear <= 0.0:
			continue
		var growth := 1.0 if external_construction else 0.5 + 0.5 * _ease_out(appear)
		var size := radius * pow(STACK_SHRINK, index) * growth * swell
		var spin := drawing_clock() * (0.9 if index % 2 == 1 else -0.7) * (1.0 + closing * 6.0)
		_disc_space(index, spin)
		if style == "codex":
			_front_disc(
				size,
				fade * breathe if external_construction else appear * fade * breathe,
				index,
				appear if external_construction else 1.0
			)
		else:
			CircleStyles.front_disc(
				self, size, appear * fade * breathe, index, appear if external_construction else 1.0
			)
	var spin_outer := _spin(0.35)
	_disc_space(0, spin_outer)
	var r := radius * swell * pop
	if style == "codex":
		_main_disc(r, fade, breathe)
	else:
		CircleStyles.main_disc(self, r, fade, breathe)
	_crown(r, fade)
	_stack(r, fade)
	_shocks_draw(r, fade)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_light(fade)


## How far the smaller circle `index` (1 the nearest) has appeared, 0 → 1. With layers it comes with one of the last
## of them, so the stack in front grows as the spell does; without, in the last half of the writing.
func _front_appear(index: int) -> float:
	if layers.is_empty():
		return _phase(0.5 + 0.12 * index, 0.78 + 0.08 * index)
	var follows := clampi(layers.size() - int(_facts.front) + index - 1, 0, layers.size() - 1)
	return _layer_progress(follows)


## The layers, outermost first: each arrives with a ring of light closing in on where it will stand, then draws itself
## in as its own figure (CircleLayerArt) and turns on.
func _stack(r: float, fade: float) -> void:
	for index in layers.size():
		var progress := _layer_progress(index)
		if progress <= 0.0:
			continue
		var stands := r * _layer_share(index)
		var grow := progress if external_construction else (1.0 if _reduced else _ease_out(progress))
		var alpha := fade * minf(1.0, progress * 4.0) * (1.0 + 0.35 * _flare)
		if not external_construction and not _reduced and progress < 1.0:
			var left := 1.0 - progress
			draw_circle(Vector2.ZERO, stands * 1.05, Color(mid, 0.12 * left * fade))
			_arc(lerpf(r * 1.2, stands, _ease_out(progress)), 0.0, TAU, 2.6 * left, left * fade)
		CircleLayerArt.draw(self, layers[index], stands, r * _layer_inner(index), grow, alpha)
		_disc_space(0, _spin(0.35))


## The rim of a stronger circle: a ring of beads for the third tier, the grand circle's chevrons beyond it.
func _crown(r: float, fade: float) -> void:
	if tier < 2:
		return
	var set_in := construction_share() if external_construction else _ease_out(_phase(0.0, 0.5))
	var beads := 36 + 12 * tier
	for i in int(beads * set_in):
		draw_circle(Vector2.from_angle(TAU * i / beads) * r * 1.07, 1.5, Color(hot, 0.65 * fade))
	if tier >= 3:
		for i in int(12 * set_in):
			var a := TAU * i / 12.0 + _spin(0.2)
			var tip := Vector2.from_angle(a) * r * 1.2
			var base := Vector2.from_angle(a) * r * 1.1
			var side := Vector2.from_angle(a + PI * 0.5) * r * 0.04
			draw_polyline(PackedVector2Array([base + side, tip, base - side]), Color(hot, 0.8 * fade), 1.6, true)


## Motes in the stage's plane. Release emphasis stays on the rings instead of drawing glare across the hero.
func _light(fade: float) -> void:
	for mote in _motes:
		var left := 1.0 - float(mote[2]) / float(mote[3])
		var at: Vector2 = mote[0]
		var size: float = mote[4]
		draw_circle(at, size * 2.6, Color(mid, 0.25 * left * fade))
		draw_circle(at, size, Color(hot, left * fade))


## Rotation speeds that start fast while it writes itself and settle once it is complete; closing spins it up.
func _spin(rate: float) -> float:
	var settle := 1.0 if external_construction else 1.0 + 3.0 * (1.0 - _phase(0.0, 1.0))
	var closing := 0.0 if _closing < 0.0 else (clock - _closing) * 8.0
	return drawing_clock() * rate * settle + closing * rate


## Unfinished strokes stay in place while the nib writes; the finished seal may turn afterward.
func drawing_clock() -> float:
	return (
		maxf(0.0, clock - _formed_at)
		if external_construction and _formed
		else (0.0 if external_construction else clock)
	)


# LEARN: everything is drawn in a flat "disc space" (a circle of radius r round the origin) and this transform maps it
# to the stage: narrowed, leaned back, moved along the cast axis. A ring's spin is one more rotation inside it, so the
# rings, the star and the runes all narrow correctly however they turn.
func _disc_space(index: int, spin: float) -> void:
	var disc := Transform2D(TILT, Vector2(SQUASH, 1.0), 0.0, _disc_origin(index))
	# The last one set is the main disc's (drawn after the smaller ones): the layers set their letters upright in it.
	_disc_xf = disc * Transform2D(spin, Vector2.ZERO)
	draw_set_transform_matrix(_disc_xf)


## The frame of the codex circle: the glow, the two outer rings drawn like pen strokes, the ticks between them and the
## core. What stands inside it is the layers' (_stack).
func _main_disc(r: float, fade: float, breathe: float) -> void:
	var written := construction_share() if external_construction else 1.0
	var glow := Color(mid, (0.1 * fade * breathe + 0.12 * _flare) * written)
	if not external_construction or _formed:
		for i in 4:
			draw_circle(Vector2.ZERO, r * (0.35 + 0.22 * i), Color(dark, 0.07 * fade * _phase(0.0, 0.4)))
		draw_circle(Vector2.ZERO, r * 0.95, glow)
	# The outer rings, drawn like pen strokes from two points at once, a bright nib on each.
	var stroke := construction_share() if external_construction else _ease_out(_phase(0.0, 0.34))
	for start: float in [-PI * 0.5, PI * 0.5]:
		_arc(r, start, PI * stroke, 3.2, fade)
		_arc(r * 0.93, start + PI * 0.25, PI * _ease_out(_phase(0.08, 0.4)), 1.6, fade)
		if stroke < 1.0:
			var nib := Vector2(cos(start + PI * stroke), sin(start + PI * stroke)) * r
			draw_circle(nib, 5.0, Color(hot, fade))
	# Ticks between the rings, set one after another.
	var ticks := int(_facts.ticks)
	var shown := int(ticks * _phase(0.18, 0.5))
	for i in shown:
		var a := TAU * i / ticks
		var long := 0.84 if i % 6 == 0 else 0.88
		draw_line(Vector2.from_angle(a) * r * long, Vector2.from_angle(a) * r * 0.92, Color(hot, 0.7 * fade), 1.4)
	# The core: lit last, flaring on each bolt.
	var core := _ease_out(_phase(0.74, 1.0))
	if core > 0.0:
		_arc(r * 0.22, 0.0, TAU * core, 2.0, fade)
		_arc(r * 0.15, PI, TAU * core, 1.2, fade)
		draw_circle(Vector2.ZERO, r * (0.1 + 0.05 * _flare) * core, Color(hot, (0.55 + 0.45 * _flare) * fade))
		draw_circle(Vector2.ZERO, r * 0.2 * core, Color(mid, 0.25 * fade))


## The ring of light that runs out through the circle as each bolt leaves it.
func _shocks_draw(r: float, fade: float) -> void:
	for shock: float in _shocks:
		var age := (clock - shock) / 0.32
		if age < 1.0:
			_arc(r * lerpf(0.25, 1.2, _ease_out(age)), 0.0, TAU, 3.0 * (1.0 - age), (1.0 - age) * fade)


## One of the smaller circles in front: a ring, a few runes' worth of ticks, a turning square, a bright centre.
func _front_disc(r: float, alpha: float, index: int, progress := 1.0) -> void:
	if not external_construction or _formed:
		draw_circle(Vector2.ZERO, r * 0.9, Color(mid, 0.08 * alpha + 0.1 * _flare * alpha))
	_arc(r, 0.0, TAU * progress, 2.4, alpha)
	_arc(r * 0.82, 0.0, TAU * progress, 1.2, alpha * 0.8)
	for i in int(12 * progress):
		var a := TAU * i / 12.0
		draw_line(Vector2.from_angle(a) * r * 0.82, Vector2.from_angle(a) * r * 0.92, Color(hot, 0.6 * alpha), 1.2)
	_star(r * 0.7, 4 + index, 1 if index % 2 == 0 else 2, progress, 0.0, alpha)
	if progress >= 1.0:
		draw_circle(Vector2.ZERO, r * 0.12, Color(hot, (0.4 + 0.6 * _flare) * alpha))


## A stroke of light: a wide faint halo under a thin bright line, an arc of radius `r` about `centre`.
func _arc(r: float, from: float, sweep: float, width: float, alpha: float, centre := Vector2.ZERO) -> void:
	if sweep <= 0.001 or alpha <= 0.0:
		return
	var points := maxi(8, int(48.0 * sweep / TAU) + 8)
	draw_arc(centre, r, from, from + sweep, points, Color(mid, 0.28 * alpha), width * 3.2, true)
	draw_arc(centre, r, from, from + sweep, points, Color(hot, 0.9 * alpha), width, true)


## A star polygon {points / step} in radius r, its edges ruled one after another as `drawn` goes 0 → 1.
func _star(r: float, points: int, step: int, drawn: float, turn: float, alpha: float) -> void:
	if drawn <= 0.0:
		return
	var corners: Array[Vector2] = []
	for i in points:
		corners.append(Vector2.from_angle(turn + TAU * i / points - PI * 0.5) * r)
	var edges := float(points) * drawn
	for i in points:
		var share := clampf(edges - i, 0.0, 1.0)
		if share <= 0.0:
			break
		var a := corners[i]
		var b := a.lerp(corners[(i + step) % points], share)
		draw_line(a, b, Color(mid, 0.3 * alpha), 4.5, true)
		draw_line(a, b, Color(hot, 0.85 * alpha), 1.5, true)
		draw_circle(a, 2.6, Color(hot, alpha))


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)
