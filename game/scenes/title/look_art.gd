class_name LookArt
extends Control
## The picture on a cosmetic option's card (ADR-0037), drawn by the game's own effects rather than painted: a magic
## circle writing itself in its style, a bolt's sheet flying in place, an impact's sheet landing, or a move's pose
## on the motion dummy (a picture made by tools/move_thumbs). While `live` it plays on a loop; otherwise it holds its
## most telling moment, still. Silent: the cards never make a sound. A legendary bolt or impact has no sheet, so it
## holds a still preview instead (docs/LEGENDARY_LOOKS.md, "Carousel").

## A card replays its demonstration this often, and lets a finished circle rest this long before it closes it.
const LOOP_SECONDS := 5.0
const SETTLE := 1.0
## The still previews of the legendary looks, drawn on the card's picture field (the card less its title band). A bolt's
## route runs from ORIGIN_AT to TARGET_AT, both shares of the field, through STILL_STARS stars from a fixed seed.
const STILL_SEED := 1729
const STILL_STARS := 5
const STILL_SPREAD := 0.2
const ORIGIN_AT := Vector2(0.18, 0.78)
const TARGET_AT := Vector2(0.82, 0.22)
## A black hole's disc is this share of the field's shorter side, held at HOLE_PROGRESS of its timeline.
const HOLE_RADIUS_SHARE := 0.2
const HOLE_PROGRESS := 0.6
## The title band under a card's picture, and the middle card's width, against which a still bolt's strokes are scaled.
const BAND_HEIGHT := 30.0
const FULL_CARD_WIDTH := 186.0

var slot := ""
var option: Dictionary = {}
var live := false
var _clock := 0.0
var _effect: Node2D
## Whether `_effect` is a still preview: the card never ticks it, and a black hole holds its clock at time_scale 0.
var _still := false
## The card's global transform when its still was built. A black hole stays on its global point, so a card that moves
## builds it again (see _follow_still_place).
var _still_place := Transform2D()


static func make(for_slot: String, for_option: Dictionary) -> LookArt:
	var art := LookArt.new()
	art.slot = for_slot
	art.option = for_option
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if for_slot in CosmeticRules.NATIVE:
		var picture := Ui.picture("menus/moves/" + String(for_option.get("clip", "")), Vector2(150, 150), "✦")
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_bottom = -30
		art.add_child(picture)
	art.resized.connect(art._restart)
	return art


func set_live(value: bool) -> void:
	if live == value and _effect != null:
		return
	live = value
	_restart()


func _restart() -> void:
	if slot in CosmeticRules.NATIVE or size.x < 8.0 or not is_inside_tree():
		return
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	_still = false
	_clock = 0.0
	if _is_drawn_still():
		_show_still()
		return
	var middle := Vector2(size.x * 0.5, (size.y - 30.0) * 0.5)
	match slot:
		"circle":
			var circle := MagicCircle.cast(self, middle, 2, "none", minf(size.x, size.y) * 0.3, "", 1.0, true)
			circle.style = String(option.get("style", "codex"))
			# Built layer by layer, as a spell is, then left to settle: the card shows the circle at rest, not the
			# flare of the moment it was sealed.
			circle.external_construction = true
			circle.use_plan(CircleLayers.demo_plan(3 if circle.style == "ring-bloom" else 2))
			# The orrery has no stack of smaller circles in front of it, so it stays centred on its card.
			if circle.style != "orrery":
				circle.position.x -= circle.radius * 0.35
			circle.set_process(false)
			_effect = circle
			if not live:
				_advance(_built_by(circle) + SETTLE)
		"bolt":
			var bolt := SpellAnim.play(
				self, String(option.get("sprite", "")), middle, "none", size.x / 300.0, 0.0, true
			)
			if bolt != null:
				bolt.set_process(false)
				_effect = bolt
				_advance(0.1)
		"impact":
			var foot := Vector2(size.x * 0.5, size.y - 40.0)
			var blow := SpellAnim.play(self, String(option.get("sprite", "")), foot, "none", size.y / 520.0, 0.0, true)
			if blow != null:
				blow.looping = true
				blow.set_process(false)
				_effect = blow
				_advance(blow.impact_time() + 0.12)


## Whether this look is a legendary bolt or impact with no sheet: its `draw` names the renderer that draws it.
func _is_drawn_still() -> bool:
	var renderer := String(option.get("draw", ""))
	if slot == "bolt":
		return renderer in CosmeticRules.BOLT_DRAWS
	return slot == "impact" and renderer in CosmeticRules.IMPACT_DRAWS


## A still preview on the card's picture field (the card less its title band): a bolt's route of stars, or a black hole
## held mid-blast. The card does not tick it; a black hole keeps processing, so its lens copy refits every frame.
func _show_still() -> void:
	var field := Vector2(size.x, size.y - BAND_HEIGHT)
	if slot == "bolt":
		_effect = _still_bolt(field)
	else:
		_effect = _still_black_hole(field)
	_still = true
	_still_place = get_global_transform()


func _still_bolt(field: Vector2) -> StillBolt:
	var stars := ConstellationPath.stars(STILL_SEED, STILL_STARS, STILL_SPREAD)
	var bolt := StillBolt.new()
	bolt.route = ConstellationPath.route(field * ORIGIN_AT, field * TARGET_AT, stars)
	bolt.colour = LegendaryLook.TINT_BY_ROLE["strike"]
	bolt.draw_scale = field.x / FULL_CARD_WIDTH
	add_child(bolt)
	return bolt


func _still_black_hole(field: Vector2) -> BlackHoleImpact:
	var radius := minf(field.x, field.y) * HOLE_RADIUS_SHARE
	# LEARN: BlackHoleImpact takes a global point and keeps to it, so the card's centre is converted first; a local point
	# would put the hole off its card.
	var centre := get_global_transform() * (field * 0.5)
	# No role and no card: the impact's base features, which is the singularity the option describes.
	var hole := BlackHoleImpact.play(self, centre, radius, {"role": "", "card": ""})
	# LEARN: the timeline moves to HOLE_PROGRESS at full speed, then its time_scale goes to 0. The clock holds there, but
	# the process keeps running, so the lens copy refits every frame; stopping the process would leave the copy behind.
	# The shader reads only `progress`, never TIME, so the held frame is always the same.
	hole.advance(HOLE_PROGRESS * hole.duration)
	hole.time_scale = 0.0
	return hole


## A black hole stays on its global point, so a card that has moved builds its still again where the card is now. A
## bolt is drawn in the card's own space and needs no such check.
func _follow_still_place() -> void:
	if _effect is BlackHoleImpact and get_global_transform() != _still_place:
		_restart()


## When the card's demonstration spell has drawn its last layer, in seconds.
func _built_by(circle: MagicCircle) -> float:
	return 0.15 + circle.layers.size() * 0.32 + 0.35


func _advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and is_instance_valid(_effect):
		var step := minf(left, 1.0 / 30.0)
		_tick(step)
		left -= step


func _tick(seconds: float) -> void:
	_clock += seconds
	if _effect is MagicCircle and (_effect as MagicCircle).external_construction:
		var circle := _effect as MagicCircle
		for index in circle.layers.size():
			var start := 0.15 + index * 0.32
			if _clock < start:
				break
			circle.trace_shard(index, (_clock - start) / 0.32)
		if _clock >= 0.15 + circle.layers.size() * 0.32:
			circle.finish_construction()
	_effect.call("_process", seconds)


func _process(delta: float) -> void:
	if _still:
		_follow_still_place()
		return
	if not live:
		return
	if not is_instance_valid(_effect):
		_restart()
		return
	_tick(delta)
	if _effect is MagicCircle:
		var circle := _effect as MagicCircle
		if _clock > _built_by(circle) + SETTLE + 0.3 and circle._closing < 0.0:
			circle.close()
	if _clock >= LOOP_SECONDS:
		_restart()


## A still constellation bolt, drawn as the volley draws one (constellation_volley.gd): the route's thin line, its
## three-stroke trail to the target, its stars as diamonds and a glint at the target. Nothing moves.
class StillBolt:
	extends Node2D
	const LINE_WIDTH := 1.5
	const LINE_ALPHA := 0.55
	const OUTER_WIDTH := 9.0
	const OUTER_ALPHA := 0.22
	const BODY_WIDTH := 4.2
	const BODY_ALPHA := 0.6
	const CORE_WIDTH := 1.6
	const STAR_RADIUS := 6.0
	const GLINT_LENGTH := 9.0

	## The origin, each star, then the target, as ConstellationPath.route gives them.
	var route := PackedVector2Array()
	var colour := Color.WHITE
	## Scales every stroke, star and glint, so a side card's bolt is drawn at that card's size.
	var draw_scale := 1.0

	func _init() -> void:
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = glow

	func _draw() -> void:
		if route.size() < 2:
			return
		draw_polyline(route, _with_alpha(colour, LINE_ALPHA), LINE_WIDTH * draw_scale)
		for k in range(1, route.size() - 1):
			_draw_diamond(route[k], STAR_RADIUS * draw_scale)
		_draw_trail()
		_draw_glint(route[route.size() - 1])

	## Three strokes over one another, each sample brighter than the last: a wide faint one, a narrower body and a
	## white-hot core, all fading in from the origin.
	func _draw_trail() -> void:
		var last := float(route.size() - 1)
		var outer := PackedColorArray()
		var body := PackedColorArray()
		var hot := PackedColorArray()
		for k in route.size():
			var along := float(k) / last
			outer.append(_with_alpha(colour, OUTER_ALPHA * along))
			body.append(_with_alpha(colour, BODY_ALPHA * along * along))
			hot.append(_with_alpha(_core(), along * along * along))
		draw_polyline_colors(route, outer, OUTER_WIDTH * draw_scale)
		draw_polyline_colors(route, body, BODY_WIDTH * draw_scale)
		draw_polyline_colors(route, hot, CORE_WIDTH * draw_scale)

	func _draw_diamond(at: Vector2, radius: float) -> void:
		var points := PackedVector2Array(
			[
				at + Vector2(0.0, -radius),
				at + Vector2(radius, 0.0),
				at + Vector2(0.0, radius),
				at + Vector2(-radius, 0.0),
			]
		)
		draw_colored_polygon(points, colour)

	## A four-point glint: two long rays and two short diagonals.
	func _draw_glint(at: Vector2) -> void:
		var length := GLINT_LENGTH * draw_scale
		var diag := length * 0.45
		var lit := _core()
		draw_line(at - Vector2(length, 0.0), at + Vector2(length, 0.0), lit, 1.2)
		draw_line(at - Vector2(0.0, length), at + Vector2(0.0, length), lit, 1.2)
		draw_line(at - Vector2(diag, diag), at + Vector2(diag, diag), lit, 0.8)
		draw_line(at - Vector2(diag, -diag), at + Vector2(diag, -diag), lit, 0.8)

	## The white-hot core: the tint lifted most of the way to white.
	func _core() -> Color:
		return colour.lerp(Color.WHITE, 0.75)

	func _with_alpha(tint: Color, alpha: float) -> Color:
		return Color(tint.r, tint.g, tint.b, alpha)
