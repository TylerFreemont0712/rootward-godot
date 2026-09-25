class_name BattleFX
extends Node2D
## Effects for the spell stage: a ward, a cast seal, a travelling bolt, or a hit burst (ADR-0008).
##
## With its spell sprites (res://assets/fx/spell/, redrawn by ComfyUI from the concept boards) an effect is a few layers
## of one shader (spell_sprite.gdshader: dissolve, reveal, wobble, shimmer) and a spray of sparkles, all moved by one
## timeline in `_animate`. Without them it is the older line art, drawn in `_draw`. Art is optional either way.

enum Kind { WARD, CAST, BOLT, BURST, WAVE, VORTEX }

const FOXFIRE_WARD := preload("res://assets/fx/foxfire-ward.png")
const SPELL_SHADER := preload("res://scenes/shardrun/fight/spell_sprite.gdshader")
const SPRITES := "res://assets/fx/spell/%s.png"
## Drawn sizes of the sprites, in stage pixels, before the effect's own scale.
const BOLT_SIZE := 190.0
const BURST_SIZE := 240.0
const SEAL_SIZE := 210.0
const WARD_SIZE := 300.0
const WAVE_SIZE := 520.0
const VORTEX_SIZE := 300.0
## The sprites' colour for a spell with no element: the arcane violet the neutral bolts and bursts are drawn in.
const ARCANE := Color("#b48cff")

static var _sprites: Dictionary = {}
static var _sheets: Dictionary = {}
static var _glint: Texture2D
static var _soft: Texture2D
static var _ring: Texture2D

var kind := Kind.BURST
var element := "none"
var tint := Color.WHITE
var duration := 0.7
var elapsed := 0.0
var progress := 0.0
var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var arc_height := 0.0
var _layers: Dictionary = {}
var _trail: CPUParticles2D
var _ribbon: SpellRibbon
var _sprited := false
var _finishing := false
## Layers drawn from an animated sheet, by layer name: the sheet's facts ({frames, columns, fps, loop, rects}).
var _animated: Dictionary = {}


static func spawn(
	parent: Node, effect_kind: Kind, at: Vector2, colour: Color, seconds := 0.7, element_name := "none"
) -> BattleFX:
	var effect := BattleFX.new()
	effect.kind = effect_kind
	effect.element = element_name
	effect.position = at
	effect.tint = colour
	effect.duration = seconds
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	effect.material = additive
	parent.add_child(effect)
	return effect


## A spell sprite by name ("bolt-fire", "seal"), loaded once; null when the art is not there.
static func sprite(name: String) -> Texture2D:
	if not _sprites.has(name):
		var path := SPRITES % name
		_sprites[name] = load(path) if ResourceLoader.exists(path) else null
	return _sprites[name]


static func has_sprite(base: String, element_name: String) -> bool:
	return sprite("%s-%s" % [base, element_name]) != null or sprite(base + "-none") != null


func _element_sprite(base: String) -> Texture2D:
	var texture := sprite("%s-%s" % [base, element])
	return texture if texture != null else sprite(base + "-none")


## The name of the sprite `_element_sprite` would use, so its animated sheet (if any) can be found.
func _element_name(base: String) -> String:
	return "%s-%s" % [base, element] if sprite("%s-%s" % [base, element]) != null else base + "-none"


## An effect's animated sheet ({texture, frames, columns, size, fps, loop}), or {} when it has only a still picture.
static func sheet(name: String) -> Dictionary:
	if not _sheets.has(name):
		var found := {}
		var base := SPRITES % (name + "-sheet")
		var texture_path := base.get_basename() + ".webp"
		var facts_path := base.get_basename() + ".json"
		if ResourceLoader.exists(texture_path) and FileAccess.file_exists(facts_path):
			var facts: Variant = JSON.parse_string(FileAccess.get_file_as_string(facts_path))
			if facts is Dictionary:
				found = facts
				found.texture = load(texture_path)
		_sheets[name] = found
	return _sheets[name]


func _ready() -> void:
	_sprited = _build()
	if _sprited:
		_animate(0.0)


func set_flight(from: Vector2, to: Vector2, lift: float) -> void:
	from_point = from
	to_point = to
	arc_height = lift
	set_flight_progress(0.0)


func set_flight_progress(value: float) -> void:
	progress = value
	var tangent := to_point - from_point
	position = from_point.lerp(to_point, value) + Vector2(0.0, -arc_height * 4.0 * value * (1.0 - value))
	var slope := tangent + Vector2(0.0, -arc_height * 4.0 * (1.0 - 2.0 * value))
	rotation = slope.angle()
	if _ribbon != null:
		_ribbon.sample(position)
	queue_redraw()


## The bolt has landed: its head goes, and its trail of sparkles is left to fade where it hung in the air.
func finish() -> void:
	if _ribbon != null:
		_ribbon.release()
		_ribbon = null
	if _trail == null or _finishing:
		queue_free()
		return
	_finishing = true
	for layer: Sprite2D in _layers.values():
		layer.visible = false
	_trail.emitting = false
	get_tree().create_timer(_trail.lifetime + 0.05).timeout.connect(queue_free)


func _process(delta: float) -> void:
	elapsed += delta
	if _finishing:
		return
	if elapsed >= duration:
		finish()
		return
	if _sprited:
		_animate(clampf(progress if kind == Kind.BOLT else elapsed / duration, 0.0, 1.0))
	else:
		queue_redraw()


func _draw() -> void:
	if _sprited:
		return
	var t := clampf(progress if kind == Kind.BOLT else elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.62, 1.0, t)
	match kind:
		Kind.WARD:
			_draw_ward(t, fade)
		Kind.CAST:
			_draw_cast(t, fade)
		Kind.BOLT:
			_draw_bolt(t, fade)
		Kind.BURST:
			_draw_burst(t, fade)


# --- the sprite effects ---------------------------------------------------------------------------------------------


func _build() -> bool:
	if element == "none":
		tint = ARCANE
	var light := tint.lerp(Color.WHITE, 0.3)
	match kind:
		Kind.BOLT:
			var head := _element_sprite("bolt")
			if head == null:
				return false
			_layer_of("halo", _element_name("bolt"), {"tint": Color(tint, 0.5), "distort": 0.7})
			_layer_of("head", _element_name("bolt"), {"distort": 0.35, "glow": 1.15})
			_ribbon = SpellRibbon.create(get_parent(), element, tint)
			_ribbon.z_index = z_index - 1
			_trail = _sparkles(110, 0.6, false, 18.0, 70.0)
			# A fast bolt moves tens of pixels a frame; emitting along a strip behind its head, not from one point,
			# lays the trail as a stream rather than a string of clumps.
			_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
			_trail.emission_rect_extents = Vector2(34, 7)
			_trail.position = Vector2(-30, 0)
		Kind.BURST:
			var burst := _element_sprite("burst")
			if burst == null:
				return false
			_layer("flash", _soft_texture(), {"glow": 1.4})
			_layer("ring", _ring_texture(), {"tint": light})
			var burst_motif := SpellImpact.create(self, element, tint, 0.7)
			burst_motif.z_index = 2
			_layer_of(
				"burst",
				_element_name("burst"),
				{
					"edge_colour": tint.lerp(Color.WHITE, 0.1),
					"glow": 1.1,
					"radial": 0.55,
					"grain_scale": 2.4,
					"edge_width": 0.12
				}
			)
			_sparkles(28, 0.6, true, 260.0, 620.0).emitting = true
		Kind.CAST:
			var seal := sprite("seal")
			if seal == null:
				return false
			_layer("seal", seal, {"tint": light, "edge_colour": light, "glow": 1.2})
			_layer("inner", seal, {"tint": Color(light, 0.6), "edge_colour": light})
			var motes := _sparkles(18, 0.55, false, 0.0, 10.0)
			motes.emission_sphere_radius = SEAL_SIZE * 0.55
			motes.radial_accel_min = -520.0
			motes.radial_accel_max = -380.0
		Kind.WAVE:
			var wave := sprite("wave")
			if wave == null:
				return false
			_layer("wave", wave, {"tint": light, "edge_colour": light, "radial": 0.6, "grain_scale": 2.0})
		Kind.VORTEX:
			var vortex := sprite("vortex")
			if vortex == null:
				return false
			_layer_of("vortex", "vortex", {"tint": tint.lerp(Color.WHITE, 0.2), "edge_colour": light, "glow": 1.2})
			var inward := _sparkles(30, 0.5, false, 0.0, 10.0)
			inward.emission_sphere_radius = VORTEX_SIZE * 0.5
			inward.radial_accel_min = -900.0
			inward.radial_accel_max = -600.0
		Kind.WARD:
			var ward := sprite("ward")
			if ward == null:
				return false
			_layer_of("ward", "ward", {"shimmer": 0.35, "edge_colour": Color(0.75, 1.0, 0.95), "glow": 1.1})
			var motes := _sparkles(16, 0.9, false, 20.0, 50.0)
			motes.emission_sphere_radius = WARD_SIZE * 0.35
			motes.direction = Vector2.UP
			motes.spread = 25.0
			motes.position = Vector2(118, 0)
	return true


## One frame of the effect's life, `t` from 0 to 1 (a bolt's flight, or its time).
func _animate(t: float) -> void:
	_advance(clampf(t / 0.9, 0.0, 1.0))
	match kind:
		Kind.BOLT:
			var arrive := smoothstep(0.0, 0.06, t)
			_shape("head", BOLT_SIZE * (1.0 + 0.07 * sin(elapsed * 32.0)), 0.0, {"tint": Color(1, 1, 1, arrive)})
			_shape(
				"halo", BOLT_SIZE * 1.3 * (1.0 + 0.1 * sin(elapsed * 21.0)), 0.0, {"tint": Color(tint, 0.5 * arrive)}
			)
		Kind.BURST:
			# A white flash at contact; the burst pops out, drifts, and breaks into wisps; a shockwave outruns it.
			var flash := clampf(t / 0.2, 0.0, 1.0)
			_shape("flash", 170.0 * lerpf(0.5, 1.6, _out(flash)), 0.0, {"tint": Color(1, 1, 1, 1.0 - flash)})
			var wave := clampf(t / 0.42, 0.0, 1.0)
			_shape(
				"ring",
				300.0 * lerpf(0.15, 1.5, _out(wave)),
				0.0,
				{"tint": Color(tint.lerp(Color.WHITE, 0.4), pow(1.0 - wave, 1.5))}
			)
			var pop := _out(clampf(t / 0.26, 0.0, 1.0), 3.0)
			_shape(
				"burst",
				BURST_SIZE * (lerpf(0.25, 1.0, pop) + 0.16 * t),
				t * 0.35,
				{"dissolve": pow(smoothstep(0.32, 1.0, t), 1.4)}
			)
		Kind.CAST:
			# The seal is drawn in around its rim like a pen stroke, turns, and burns away once the spell has gone.
			var open := _out(clampf(t / 0.3, 0.0, 1.0))
			var leave := smoothstep(0.62, 1.0, t)
			_shape(
				"seal",
				SEAL_SIZE * lerpf(0.6, 1.0, open),
				elapsed * 1.1,
				{"reveal": smoothstep(0.0, 0.32, t), "dissolve": leave}
			)
			_shape(
				"inner",
				SEAL_SIZE * 0.58 * lerpf(0.5, 1.0, open),
				-elapsed * 2.0,
				{"reveal": smoothstep(0.1, 0.42, t), "dissolve": leave}
			)
		Kind.WAVE:
			# A ring of the spell's colour runs out across the floor, laid flat under the foes.
			# LEARN: squash the whole effect, not the spinning sprite: a squashed parent turns its child's spin into an
			# ellipse lying on the floor, where squashing the child after turning it would tilt the ellipse instead.
			var spread := _out(clampf(t / 0.7, 0.0, 1.0), 3.0)
			scale = Vector2(1.0, 0.3)
			_shape("wave", WAVE_SIZE * lerpf(0.2, 1.3, spread), elapsed * 1.4, {"dissolve": smoothstep(0.45, 1.0, t)})
		Kind.VORTEX:
			# It opens, turns faster as the spell gathers, and collapses into the hand.
			var open := _out(clampf(t / 0.35, 0.0, 1.0))
			var close := smoothstep(0.7, 1.0, t)
			var size := VORTEX_SIZE * lerpf(0.3, 1.0, open) * (1.0 - 0.8 * close)
			_shape(
				"vortex", size, -elapsed * (3.0 + 6.0 * t), {"tint": Color(tint.lerp(Color.WHITE, 0.2), 1.0 - close)}
			)
		Kind.WARD:
			# The barrier gathers out of noise, shimmers while it holds, and crumbles away.
			var gone := maxf(1.0 - smoothstep(0.0, 0.22, t), smoothstep(0.72, 1.0, t))
			_shape("ward", WARD_SIZE * (1.0 + 0.02 * sin(elapsed * 8.0)), 0.0, {"dissolve": gone}, Vector2(118, 0))


## A layer drawn from sprite `sprite_name`: its animated sheet when there is one (see _advance), else its picture.
func _layer_of(name: String, sprite_name: String, params: Dictionary) -> Sprite2D:
	var animated := sheet(sprite_name)
	if animated.is_empty():
		return _layer(name, sprite(sprite_name), params)
	var layer := _layer(name, animated.texture, params)
	var size := float(animated.size)
	var whole := Vector2(layer.texture.get_width(), layer.texture.get_height())
	layer.region_enabled = true
	layer.region_rect = Rect2(Vector2.ZERO, Vector2(size, size))
	var cell := Vector4(0, 0, size / whole.x, size / whole.y)
	(layer.material as ShaderMaterial).set_shader_parameter("frame_rect", cell)
	(layer.material as ShaderMaterial).set_shader_parameter("current_rect", cell)
	_animated[name] = animated.merged({"cell": Vector2(cell.z, cell.w)})
	return layer


## Shows the frame each animated layer is at: a loop by the clock, a one-shot across `life` (0 to 1) of the effect.
func _advance(life: float) -> void:
	for name: String in _animated:
		var facts: Dictionary = _animated[name]
		var count := int(facts.frames)
		var index := int(elapsed * float(facts.fps)) % count if facts.loop else mini(count - 1, int(life * count))
		var cell: Vector2 = facts.cell
		var column := index % int(facts.columns)
		var row := index / int(facts.columns)
		var shading := (_layers[name] as Sprite2D).material as ShaderMaterial
		shading.set_shader_parameter("current_rect", Vector4(column * cell.x, row * cell.y, cell.x, cell.y))


func _layer(name: String, texture: Texture2D, params: Dictionary) -> Sprite2D:
	var layer := Sprite2D.new()
	layer.texture = texture
	var shading := ShaderMaterial.new()
	shading.shader = SPELL_SHADER
	shading.set_shader_parameter("noise", _noise())
	for key: String in params:
		shading.set_shader_parameter(key, params[key])
	layer.material = shading
	add_child(layer)
	_layers[name] = layer
	return layer


func _shape(name: String, size: float, spin: float, params: Dictionary, offset := Vector2.ZERO) -> void:
	var layer: Sprite2D = _layers.get(name)
	if layer == null:
		return
	var width := layer.region_rect.size.x if layer.region_enabled else float(layer.texture.get_width())
	layer.scale = Vector2.ONE * (size / width)
	layer.rotation = spin
	layer.position = offset
	var shading := layer.material as ShaderMaterial
	for key: String in params:
		shading.set_shader_parameter(key, params[key])


## Sparkles of the spell's colour: a spray (one shot) or a trail left behind in the air (they stay where they were
## emitted, not where the bolt is now).
func _sparkles(amount: int, life: float, one_shot: bool, speed_min: float, speed_max: float) -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.amount = amount
	sparks.lifetime = life
	sparks.one_shot = one_shot
	sparks.explosiveness = 1.0 if one_shot else 0.0
	sparks.local_coords = false
	sparks.texture = _glint_texture()
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 10.0
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = speed_min
	sparks.initial_velocity_max = speed_max
	sparks.damping_min = 300.0 if one_shot else 20.0
	sparks.damping_max = 700.0 if one_shot else 60.0
	sparks.angle_min = -30.0
	sparks.angle_max = 30.0
	sparks.scale_amount_min = 0.22
	sparks.scale_amount_max = 0.55
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = shrink
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(tint, 0.0))
	ramp.add_point(0.35, Color(tint.lerp(Color.WHITE, 0.25), 0.95))
	sparks.color_ramp = ramp
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparks.material = additive
	add_child(sparks)
	return sparks


func _out(x: float, power := 2.0) -> float:
	return 1.0 - pow(1.0 - x, power)


static func _noise() -> Texture2D:
	var baked := sprite("noise")
	if baked != null:
		return baked
	var generated := NoiseTexture2D.new()
	generated.seamless = true
	generated.noise = FastNoiseLite.new()
	_sprites["noise"] = generated
	return generated


## A four-pointed glint for the sparkles, drawn once in code (no art needed).
static func _glint_texture() -> Texture2D:
	if _glint == null:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5) / 32.0
				var core := exp(-d.length_squared() * 38.0)
				var arms := exp(-absf(d.x) * 26.0 - absf(d.y) * 3.4) + exp(-absf(d.y) * 26.0 - absf(d.x) * 3.4)
				image.set_pixel(x, y, Color(1, 1, 1, clampf(core + arms * 0.85, 0.0, 1.0)))
		_glint = ImageTexture.create_from_image(image)
	return _glint


static func _soft_texture() -> Texture2D:
	if _soft == null:
		_soft = _radial([0.0, 0.35, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	return _soft


static func _ring_texture() -> Texture2D:
	if _ring == null:
		_ring = _radial(
			[0.0, 0.8, 0.9, 0.96, 1.0],
			[Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.2), Color(1, 1, 1, 0)]
		)
	return _ring


static func _radial(offsets: Array, colours: Array) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colours)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


# --- the line art (no sprites) --------------------------------------------------------------------------------------


func _draw_ward(t: float, fade: float) -> void:
	var reveal := smoothstep(0.0, 0.16, t)
	var pulse := 0.92 + sin(elapsed * 13.0) * 0.08
	var alpha := fade * reveal * pulse
	var grow := lerpf(0.84, 1.08, reveal)
	draw_set_transform(Vector2.ZERO, elapsed * 0.12, Vector2.ONE * grow)
	draw_texture_rect(FOXFIRE_WARD, Rect2(-104, -104, 208, 208), false, Color(0.78, 0.92, 1.0, alpha * 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var shield := _ellipse(76.0 * grow, 126.0 * grow, 0.0, TAU, 72, sin(elapsed * 0.8) * 0.045)
	var glass := Color(0.26, 0.73, 0.94, alpha * 0.07)
	draw_colored_polygon(shield, glass)
	draw_polyline(_closed(shield), Color(0.42, 0.88, 1.0, alpha * 0.88), 3.0, true)
	draw_polyline(_ellipse(68.0, 117.0, 0.0, TAU, 72, -elapsed * 0.18), Color(1.0, 0.73, 0.32, alpha * 0.9), 2.0, true)
	draw_polyline(_ellipse(61.0, 107.0, 0.0, TAU, 72, elapsed * 0.26), Color(0.75, 0.94, 1.0, alpha * 0.48), 1.2, true)
	for i in 12:
		var angle := TAU * float(i) / 12.0 - elapsed * 0.32
		var outward := Vector2(cos(angle) * 77.0, sin(angle) * 128.0)
		var inward := Vector2(cos(angle) * 66.0, sin(angle) * 113.0)
		draw_line(inward, outward, Color(1.0, 0.82, 0.46, alpha * 0.75), 1.4, true)
		if i % 2 == 0:
			_draw_diamond(outward, 4.0 + sin(elapsed * 9.0 + i) * 1.0, Color(1.0, 0.9, 0.65, alpha))
	for i in 9:
		var angle := TAU * float(i) / 9.0 + elapsed * 0.55
		var mote := Vector2(cos(angle) * 85.0, sin(angle) * 136.0)
		draw_circle(mote, 4.3, Color(1.0, 0.61, 0.28, alpha * 0.55))
		draw_circle(mote, 1.8, Color(1.0, 0.95, 0.76, alpha))
	_draw_fox_mark(Vector2(0, -116.0), 13.0, Color(1.0, 0.82, 0.5, alpha))
	_draw_fox_mark(Vector2(0, 114.0), 11.0, Color(0.66, 0.9, 1.0, alpha))


func _draw_cast(t: float, fade: float) -> void:
	var reveal := smoothstep(0.0, 0.22, t)
	var radius := lerpf(12.0, 49.0, ease(t, 0.68))
	var alpha := fade * reveal
	var spin := elapsed * 2.4
	draw_set_transform(Vector2.ZERO, -spin * 0.34, Vector2.ONE * (radius / 112.0))
	draw_texture_rect(FOXFIRE_WARD, Rect2(-104, -104, 208, 208), false, Color(1.0, 0.68, 0.34, alpha * 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, alpha * 0.12))
	draw_polyline(_ellipse(radius, radius, 0.0, TAU, 64, spin), Color(1.0, 0.77, 0.36, alpha * 0.95), 2.4, true)
	draw_polyline(
		_ellipse(radius * 0.76, radius * 0.76, 0.0, TAU, 64, -spin * 1.4),
		Color(1.0, 0.92, 0.65, alpha * 0.82),
		1.4,
		true
	)
	draw_polyline(
		_ellipse(radius * 0.42, radius * 0.42, 0.0, TAU, 48, spin * 2.0), Color(0.9, 0.97, 1.0, alpha * 0.7), 1.2, true
	)
	for i in 8:
		var angle := TAU * float(i) / 8.0 + spin
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(direction * radius * 0.78, direction * radius * 1.13, Color(1.0, 0.84, 0.48, alpha * 0.8), 1.8, true)
		_draw_diamond(direction * radius * 1.12, 4.0, Color(1.0, 0.94, 0.72, alpha))
	for i in 6:
		var angle := TAU * float(i) / 6.0 - spin * 1.6
		var spark := Vector2(cos(angle), sin(angle)) * radius * 1.42
		draw_circle(spark, 2.0 + sin(elapsed * 18.0 + i) * 0.8, Color(1.0, 0.72, 0.31, alpha))
	_draw_fox_mark(Vector2.ZERO, radius * 0.22, Color(1.0, 0.98, 0.82, alpha))


func _draw_bolt(_t: float, fade: float) -> void:
	var pulse := 0.84 + 0.16 * sin(elapsed * 32.0)
	for i in 4:
		var trail := -float(i + 1) * 8.0
		draw_line(
			Vector2(trail - 7.0, 0),
			Vector2(trail + 5.0, 0),
			Color(tint.r, tint.g, tint.b, fade * (0.46 - i * 0.08)),
			2.2 - i * 0.3,
			true
		)
	draw_circle(Vector2.ZERO, 13.0 * pulse, Color(tint.r, tint.g, tint.b, fade * 0.22))
	draw_circle(Vector2.ZERO, 7.2 * pulse, Color(1.0, 0.78, 0.38, fade * 0.88))
	draw_polyline(_ellipse(10.5, 10.5, 0.0, TAU, 32, elapsed * 9.0), Color(1.0, 0.95, 0.74, fade), 1.6, true)
	_draw_diamond(Vector2.ZERO, 6.8, Color(1.0, 1.0, 0.92, fade))
	for i in 3:
		var phase := elapsed * 12.0 + TAU * float(i) / 3.0
		var mote := Vector2(cos(phase) * 14.0, sin(phase) * 7.0)
		draw_circle(mote, 1.6, Color(1.0, 0.92, 0.62, fade * 0.9))


func _draw_burst(t: float, fade: float) -> void:
	var radius := lerpf(6.0, 58.0, ease(t, 0.48))
	var alpha := fade * (1.0 - t * 0.35)
	for ring in 3:
		var r := radius * (0.56 + ring * 0.25)
		draw_polyline(
			_ellipse(r, r * (0.82 + ring * 0.08), 0.0, TAU, 48, elapsed * (2.0 - ring * 0.7)),
			Color(tint.r, tint.g, tint.b, alpha * (0.82 - ring * 0.18)),
			2.5 - ring * 0.55,
			true
		)
	for i in 9:
		var angle := TAU * float(i) / 9.0 + elapsed * (1.8 if i % 2 == 0 else -1.2)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(direction * radius * 0.24, direction * radius * 1.15, Color(1.0, 0.88, 0.58, alpha), 2.0, true)
		draw_circle(direction * radius, 2.2, Color(1.0, 0.98, 0.84, alpha))
	_draw_fox_mark(Vector2.ZERO, 10.0 * (1.0 - t * 0.35), Color(1.0, 0.95, 0.76, alpha))


func _draw_fox_mark(at: Vector2, size: float, colour: Color) -> void:
	var points := PackedVector2Array(
		[
			at + Vector2(-size * 0.8, size * 0.2),
			at + Vector2(-size * 0.48, -size),
			at + Vector2(0, -size * 0.34),
			at + Vector2(size * 0.48, -size),
			at + Vector2(size * 0.8, size * 0.2),
			at + Vector2(0, size),
		]
	)
	draw_polyline(_closed(points), colour, 1.5, true)


func _draw_diamond(at: Vector2, size: float, colour: Color) -> void:
	var points := PackedVector2Array(
		[
			at + Vector2(0, -size),
			at + Vector2(size * 0.55, 0),
			at + Vector2(0, size),
			at + Vector2(-size * 0.55, 0),
		]
	)
	draw_colored_polygon(points, colour)


func _ellipse(rx: float, ry: float, start: float, end: float, steps: int, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps + 1:
		var angle := start + (end - start) * float(i) / float(steps) + phase
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed
