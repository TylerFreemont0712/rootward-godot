class_name MagicCircle
extends Node2D
## A magic circle written in the air in front of the caster, as isekai anime draws them (ADR-0030): a disc standing
## between her and the foes, facing them, so it is seen narrowed. It writes itself (rings drawn like pen strokes,
## runes set one by one, a star ruled edge by edge, a core lit), stays turning while the volley lasts, flares as each
## bolt leaves it, and closes when the program has finished. A stronger cast writes more rings, a finer star and
## more, smaller circles stacked in front of the first, the bolts passing through them all. Drawn in code, in the
## element's colours, added onto the stage as light.
##
##   var circle := MagicCircle.cast(fx, at, 2, "fire", 110.0, "knapsackStrike → chill")
##   await circle.formed                              # its blow: the first bolt may leave
##   stage.fly(circle.launch_point(), ...)            # every bolt is born on its front circle
##   circle.pulse()
##   circle.close()                                   # the volley is over

## The circle has finished writing itself: the strike lands on it now.
signal formed

## Per tier: how long it takes to write itself (the beats of the sheets it replaced, so their sounds still land), the
## sound it brings, its rune rings, its star {points / step}, and how many smaller circles stand in front of it.
const TIERS: Array[Dictionary] = [
	{"form": 0.62, "sound": "sfx-cast-tier-1", "runes": 1, "star": [3, 1], "front": 1, "ticks": 36},
	{"form": 0.86, "sound": "sfx-cast-tier-2", "runes": 1, "star": [6, 2], "front": 1, "ticks": 48},
	{"form": 1.0, "sound": "sfx-cast-tier-3", "runes": 2, "star": [7, 3], "front": 2, "ticks": 60},
	{"form": 1.23, "sound": "sfx-cast-tier-4", "runes": 2, "star": [8, 3], "front": 3, "ticks": 72},
]
## The disc faces the foes, so from the camera it is narrowed to this share of its width, leaning back this far.
const SQUASH := 0.46
const TILT := -0.1
## How far in front of the first circle each smaller one stands (in radii), and how much smaller it is.
const STACK_STEP := 0.55
const STACK_SHRINK := 0.68
const CLOSE_SECONDS := 0.42
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
var _facts: Dictionary = {}
var _formed := false
var _flare := 0.0
var _shocks: Array[float] = []
var _closing := -1.0
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
	parent.add_child(circle)
	if not silent:
		Sound.play(String(circle._facts.sound), SpellAnim.SOUND_VOLUME, circle.speed)
	return circle


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
	clock += delta * (speed if not _formed else 1.0)
	_flare = maxf(0.0, _flare - delta * 4.0)
	# Motes spiral in while it writes itself and drift off its rim while it stands.
	_mote_debt += delta * (36.0 if not _formed else 5.0 + 3.0 * tier) * (0.0 if _closing >= 0.0 else 1.0)
	while _mote_debt >= 1.0:
		_mote_debt -= 1.0
		_spawn_mote(not _formed)
	if not _formed and clock >= _form():
		_formed = true
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
	var u := clock / _form()
	return clampf((u - from) / (to - from), 0.0, 1.0)


func _draw() -> void:
	var closing := 0.0 if _closing < 0.0 else clampf((clock - _closing) / CLOSE_SECONDS, 0.0, 1.0)
	var fade := 1.0 - closing * closing
	var swell := 1.0 + closing * 0.35
	var pop := 1.0 + 0.08 * maxf(0.0, _flare - 0.4)
	var breathe := 0.85 + 0.15 * sin(clock * 5.0)
	# The smaller circles in front first, so the first circle is laid over them toward the caster.
	for index in range(int(_facts.front), 0, -1):
		var appear := _phase(0.5 + 0.12 * index, 0.78 + 0.08 * index)
		if appear <= 0.0:
			continue
		var size := radius * pow(STACK_SHRINK, index) * (0.5 + 0.5 * _ease_out(appear)) * swell
		var spin := clock * (0.9 if index % 2 == 1 else -0.7) * (1.0 + closing * 6.0)
		_disc_space(index, spin)
		if style == "codex":
			_front_disc(size, appear * fade * breathe, index)
		else:
			CircleStyles.front_disc(self, size, appear * fade * breathe, index)
	var spin_outer := _spin(0.35)
	_disc_space(0, spin_outer)
	if style == "codex":
		_main_disc(radius * swell * pop, fade, breathe, closing)
	else:
		CircleStyles.main_disc(self, radius * swell * pop, fade, breathe, closing)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_light(fade)


## What is drawn unnarrowed, in the stage's own plane: the beam through the stack as a bolt leaves, the glint on the
## core, and the motes.
func _light(fade: float) -> void:
	var front := int(_facts.front)
	if _flare > 0.05:
		var start := _disc_origin(0)
		var end := _disc_origin(front) + Vector2(radius * 0.7, 0.0).rotated(TILT)
		draw_line(start, end, Color(mid, 0.35 * _flare * fade), 10.0 * _flare, true)
		draw_line(start, end, Color(hot, 0.9 * _flare * fade), 2.5 * _flare, true)
		var core := _disc_origin(0)
		var reach := radius * (0.9 + 0.7 * _flare)
		for arm: Vector2 in [Vector2(reach, 0), Vector2(0, reach * 0.75)]:
			draw_line(core - arm, core + arm, Color(mid, 0.3 * _flare * fade), 5.0, true)
			draw_line(core - arm, core + arm, Color(hot, 0.85 * _flare * fade), 1.4, true)
		var diagonal := Vector2(1, 1).normalized() * reach * 0.35
		draw_line(core - diagonal, core + diagonal, Color(hot, 0.6 * _flare * fade), 1.0, true)
		draw_line(
			core - diagonal.orthogonal(), core + diagonal.orthogonal(), Color(hot, 0.6 * _flare * fade), 1.0, true
		)
	for mote in _motes:
		var left := 1.0 - float(mote[2]) / float(mote[3])
		var at: Vector2 = mote[0]
		var size: float = mote[4]
		draw_circle(at, size * 2.6, Color(mid, 0.25 * left * fade))
		draw_circle(at, size, Color(hot, left * fade))


## Rotation speeds that start fast while it writes itself and settle once it is complete; closing spins it up.
func _spin(rate: float) -> float:
	var settle := 1.0 + 3.0 * (1.0 - _phase(0.0, 1.0))
	var closing := 0.0 if _closing < 0.0 else (clock - _closing) * 8.0
	return clock * rate * settle + closing * rate


# LEARN: everything is drawn in a flat "disc space" (a circle of radius r round the origin) and this transform maps it
# to the stage: narrowed, leaned back, moved along the cast axis. A ring's spin is one more rotation inside it, so the
# rings, the star and the runes all narrow correctly however they turn.
func _disc_space(index: int, spin: float) -> void:
	var disc := Transform2D(TILT, Vector2(SQUASH, 1.0), 0.0, _disc_origin(index))
	draw_set_transform_matrix(disc * Transform2D(spin, Vector2.ZERO))


func _main_disc(r: float, fade: float, breathe: float, closing: float) -> void:
	var glow := Color(mid, 0.1 * fade * breathe + 0.12 * _flare)
	for i in 4:
		draw_circle(Vector2.ZERO, r * (0.35 + 0.22 * i), Color(dark, 0.07 * fade * _phase(0.0, 0.4)))
	draw_circle(Vector2.ZERO, r * 0.95, glow)
	# The outer rings, drawn like pen strokes from two points at once, a bright nib on each.
	var stroke := _ease_out(_phase(0.0, 0.34))
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
	# The runes: the spell's own names, round the band, each set with a small pop.
	for ring in int(_facts.runes):
		var band := r * (0.78 - 0.17 * ring)
		_rune_ring(band, ring, fade, closing)
		_arc(band - r * 0.075, 0.0, TAU * _ease_out(_phase(0.25 + ring * 0.1, 0.6)), 1.2, fade * 0.8)
	# The star, ruled edge by edge, turning the other way.
	var star: Array = _facts.star
	var inner := r * (0.6 if int(_facts.runes) == 1 else 0.43)
	# Drawn inside the turning disc: its own turn is the disc's taken away, so it counter-rotates.
	var turn := -_spin(0.6) - _spin(0.35)
	_star(inner, int(star[0]), int(star[1]), _phase(0.42, 0.84), turn, fade)
	if tier >= 3:
		_star(inner * 0.62, 4, 1, _phase(0.6, 0.9), -turn * 1.6, fade)
	# The core: lit last, flaring on each bolt.
	var core := _ease_out(_phase(0.74, 1.0))
	if core > 0.0:
		_arc(r * 0.22, 0.0, TAU * core, 2.0, fade)
		_arc(r * 0.15, PI, TAU * core, 1.2, fade)
		draw_circle(Vector2.ZERO, r * (0.1 + 0.05 * _flare) * core, Color(hot, (0.55 + 0.45 * _flare) * fade))
		draw_circle(Vector2.ZERO, r * 0.2 * core, Color(mid, 0.25 * fade))
	for shock: float in _shocks:
		var age := (clock - shock) / 0.32
		if age < 1.0:
			_arc(r * lerpf(0.25, 1.2, _ease_out(age)), 0.0, TAU, 3.0 * (1.0 - age), (1.0 - age) * fade)


## One of the smaller circles in front: a ring, a few runes' worth of ticks, a turning square, a bright centre.
func _front_disc(r: float, alpha: float, index: int) -> void:
	draw_circle(Vector2.ZERO, r * 0.9, Color(mid, 0.08 * alpha + 0.1 * _flare * alpha))
	_arc(r, 0.0, TAU, 2.4, alpha)
	_arc(r * 0.82, 0.0, TAU, 1.2, alpha * 0.8)
	for i in 12:
		var a := TAU * i / 12.0
		draw_line(Vector2.from_angle(a) * r * 0.82, Vector2.from_angle(a) * r * 0.92, Color(hot, 0.6 * alpha), 1.2)
	_star(r * 0.7, 4 + index, 1 if index % 2 == 0 else 2, 1.0, 0.0, alpha)
	draw_circle(Vector2.ZERO, r * 0.12, Color(hot, (0.4 + 0.6 * _flare) * alpha))


## A stroke of light: a wide faint halo under a thin bright line.
func _arc(r: float, from: float, sweep: float, width: float, alpha: float) -> void:
	if sweep <= 0.001 or alpha <= 0.0:
		return
	var points := maxi(8, int(48.0 * sweep / TAU) + 8)
	draw_arc(Vector2.ZERO, r, from, from + sweep, points, Color(mid, 0.28 * alpha), width * 3.2, true)
	draw_arc(Vector2.ZERO, r, from, from + sweep, points, Color(hot, 0.9 * alpha), width, true)


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


func _rune_ring(band: float, ring: int, fade: float, closing: float) -> void:
	var size := maxi(10, int(radius * 0.13))
	var spacing := float(size) * 0.82
	var count := maxi(8, int(TAU * band / spacing))
	var set_in := _phase(0.24 + ring * 0.1, 0.7)
	var turn := -_spin(0.5 if ring == 0 else -0.4) - _spin(0.35)
	var scatter := band * (1.0 + closing * 0.6)
	var disc := Transform2D(TILT, Vector2(SQUASH, 1.0), 0.0, _disc_origin(0)) * Transform2D(_spin(0.35), Vector2.ZERO)
	var text := runes
	for i in count:
		var shown := clampf(set_in * count - i, 0.0, 1.0)
		if shown <= 0.0:
			break
		var a := turn + TAU * i / count
		var glyph := text[(i + ring * 7) % text.length()]
		if glyph == " ":
			continue
		var place := Transform2D(a, Vector2.ZERO) * Transform2D(0.0, Vector2(0.0, -scatter))
		var grow := Transform2D(0.0, Vector2.ONE * (1.6 - 0.6 * shown), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(disc * place * grow)
		draw_char(_font, Vector2(-size * 0.3, size * 0.35), glyph, size, Color(hot, shown * fade))
	draw_set_transform_matrix(disc)


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)
