class_name BattleStage
extends Control
## The painted arena with the Maintainer on the left and the foes on the right, and everything that happens between
## them: bolts in flight, bursts, numbers, banners, the shake of a heavy hit and the freeze of hit-stop. It knows how to
## show things, never what happened: LogPlayer tells it, entry by entry, from the rules' log.

## Where the foes stand across the stage (a share of its width), and where a lone foe stands.
const FOE_SPAN := Vector2(0.58, 0.94)
const LONE_FOE := 0.78
const HERO_X := 0.07
## The Maintainer's height as a share of the stage's, and the floor line everyone stands on (from the top): up in the
## painted floor, so the foes' name plates hang below their feet and everyone stands in the room rather than on
## its edge.
const HERO_HEIGHT := 0.6
const FLOOR := 0.79
## Where the painted floor meets the characters' feet in an arena picture (a share of its height): the backdrop is
## placed so this line lies on FLOOR.
const ART_FLOOR := 0.84
const IMPACT := preload("res://scenes/shardrun/fight/impact_frame.gdshader")

## Every stage skips its waits and animations (tests and tools that drive the screens).
static var instant := false

## Skip every wait and animation from here on (the player clicked through).
var fast := false:
	get:
		return fast or instant
var hero: HeroView
var foes: Dictionary = {}
var _world: Control
## A guardian's name and health, in a wide bar across the top middle of the arena (boss fights only).
var _boss_bar: Control
var _backdrop: TextureRect
var _grade: _Grade
var _shadows: _Shadows
var _fx: Control
var _shake_tween: Tween
## A strike landed a moment ago: the next ones in the same volley skip the impact frame, so it stays a single beat.
var _struck_recently := false


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_backdrop = TextureRect.new()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_backdrop)
	_grade = _Grade.new()
	_world.add_child(_grade)
	_shadows = _Shadows.new()
	_world.add_child(_shadows)
	hero = HeroView.new()
	_world.add_child(hero)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func set_backdrop(id: String) -> void:
	_backdrop.texture = Art.texture("backgrounds/" + id)
	# A painted arena keeps its colours; the old pixel art was dimmed so the fighters stood out, and is drawn sharp.
	var painted := _backdrop.texture != null and _backdrop.texture.resource_path.ends_with(".webp")
	_backdrop.modulate = Color(0.79, 0.77, 0.76) if painted else Color(0.85, 0.82, 0.8)
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if painted else CanvasItem.TEXTURE_FILTER_NEAREST
	_layout()


## Replaces the foes with these (a new fight), each fading in.
## `boss`: the first foe is a guardian, its health shown in the bar at the top instead of under its feet.
func set_foes(foe_states: Array, catalog: Dictionary, entrance := false, boss := false) -> void:
	for view: FoeView in foes.values():
		view.queue_free()
	foes.clear()
	if _boss_bar != null:
		_boss_bar.queue_free()
		_boss_bar = null
	var delay := 0.0
	for foe: Dictionary in foe_states:
		var view := FoeView.create(foe, catalog)
		_world.add_child(view)
		foes[foe.uid] = view
		if boss and _boss_bar == null:
			_boss_bar = view.take_card()
			add_child(_boss_bar)
		if entrance and not fast:
			view.enter(delay)
			delay += 0.18
		view.dim_if_dead.call_deferred()
	_layout.call_deferred()


func show_foes(foe_states: Array) -> void:
	for foe: Dictionary in foe_states:
		var view: FoeView = foes.get(foe.uid)
		if view != null:
			view.show_foe(foe)
	_layout.call_deferred()


func _layout() -> void:
	_world.size = size
	_fx.size = size
	_shadows.size = size
	_grade.size = size
	_grade.queue_redraw()
	var floor_y := size.y * FLOOR
	_place_backdrop(floor_y)
	var hero_height := size.y * HERO_HEIGHT
	hero.size = Vector2(hero_height * 0.75, hero_height)
	hero.position = Vector2(size.x * HERO_X, floor_y - hero_height)
	var feet: Array[Vector3] = [Vector3(hero.position.x + hero.size.x * 0.5, floor_y, hero_height * 0.2)]
	if _boss_bar != null:
		_boss_bar.size = _boss_bar.get_combined_minimum_size()
		_boss_bar.position = Vector2((size.x - _boss_bar.size.x) * 0.5, 14.0)
	var count := foes.size()
	var index := 0
	for view: FoeView in foes.values():
		view.size = view.get_combined_minimum_size()
		var share := (index + 0.5) / count
		var x := size.x * lerpf(FOE_SPAN.x, FOE_SPAN.y, share)
		if count == 1:
			x = size.x * LONE_FOE
		view.position = Vector2(x - view.size.x * 0.5, floor_y - view.foot_offset())
		feet.append(Vector3(x, floor_y, view.sprite_width() * 0.36))
		index += 1
	_shadows.feet = feet
	_shadows.queue_redraw()


## The arena picture covers the stage, placed so its painted floor line lies on the stage's floor line.
func _place_backdrop(floor_y: float) -> void:
	var texture := _backdrop.texture
	if texture == null:
		_backdrop.size = size
		_backdrop.position = Vector2.ZERO
		return
	var aspect := float(texture.get_width()) / float(texture.get_height())
	var drawn := Vector2(size.x, size.x / aspect)
	if drawn.y < size.y:
		drawn = Vector2(size.y * aspect, size.y)
	var top := clampf(floor_y - drawn.y * ART_FLOOR, size.y - drawn.y, 0.0)
	_backdrop.size = drawn
	_backdrop.position = Vector2((size.x - drawn.x) * 0.5, top)


## Waits `ms` of game time, or not at all when fast.
func wait(ms: float) -> void:
	if fast or ms <= 0.0 or not is_inside_tree():
		return
	await get_tree().create_timer(ms / 1000.0).timeout


## A bolt from `from` to `to`; `arrive` is called when it lands.
func fly(from: Vector2, to: Vector2, element: String, ms: float, arrive: Callable, ward := false) -> void:
	if fast:
		arrive.call()
		return
	var colour: Color = UiTheme.TEAL if ward else UiTheme.element(element)
	var bolt := BattleFX.spawn(_fx, BattleFX.Kind.BOLT, from, colour, ms / 1000.0 + 0.05, "ward" if ward else element)
	bolt.set_flight(from, to, 42.0 + randf() * 48.0)
	var tween := bolt.create_tween()
	tween.tween_method(bolt.set_flight_progress, 0.0, 1.0, ms / 1000.0)
	tween.tween_callback(arrive)
	tween.tween_callback(bolt.finish)


func burst(at: Vector2, element: String, scale_to := 1.4) -> void:
	if fast:
		return
	if BattleFX.has_sprite("burst", element):
		var effect := BattleFX.spawn(_fx, BattleFX.Kind.BURST, at, UiTheme.element(element), 0.62, element)
		effect.scale = Vector2.ONE * (0.45 + scale_to * 0.25)
		return
	var id := "fx/burst-arcane" if element == "none" else "fx/burst-" + element
	var picture := Ui.picture(id, Vector2(96, 96), "")
	picture.pivot_offset = Vector2(48, 48)
	picture.position = at - Vector2(48, 48)
	picture.scale = Vector2(0.6, 0.6)
	_fx.add_child(picture)
	BattleFX.spawn(_fx, BattleFX.Kind.BURST, at, UiTheme.element(element), 0.48)
	var tween := picture.create_tween().set_parallel()
	tween.tween_property(picture, "scale", Vector2(scale_to, scale_to), 0.32)
	tween.tween_property(picture, "modulate", Color(1, 1, 1, 0), 0.36)
	tween.chain().tween_callback(picture.queue_free)


## A heavy spell's blow called down on a foe: lightning from the sky, a fire pillar, ice spikes or a beam of starlight
## (the element's strike sprite), landing on its feet. `arrive` is called at the moment of impact.
func strike(view: FoeView, element: String, arrive: Callable) -> void:
	if fast or not BattleFX.has_sprite("strike", element):
		arrive.call()
		return
	var colour := UiTheme.element(element)
	var fx := BattleFX.spawn(_fx, BattleFX.Kind.STRIKE, view.foot_point(), colour, 0.8, element)
	var impact_delay := 0.07 if element == "spark" else 0.2
	var first := not _struck_recently
	_struck_recently = true
	get_tree().create_timer(0.5).timeout.connect(func() -> void: _struck_recently = false)
	get_tree().create_timer(impact_delay).timeout.connect(
		func() -> void:
			if first:
				impact(colour)
			elif element == "spark":
				flash(Color(1.0, 0.97, 0.8, 0.5), 0.16)
			shake(0.45)
			arrive.call()
	)
	if fx != null:
		fx.z_index = 1


## A volley that hits several foes sends a wave across the floor under them.
func sweep(points: Array[Vector2], element: String) -> void:
	if fast or points.is_empty() or BattleFX.sprite("wave") == null:
		return
	var middle := Vector2.ZERO
	for point in points:
		middle += point
	middle /= points.size()
	var colour := UiTheme.element(element)
	BattleFX.spawn(_fx, BattleFX.Kind.WAVE, middle + Vector2(0, -10), colour, 0.9, element)


## A heavy cast opens a vortex at the casting hand while the spell gathers.
func vortex(element: String, seconds: float) -> void:
	if fast or BattleFX.sprite("vortex") == null:
		return
	var at := hero.hand_point()
	BattleFX.spawn(_fx, BattleFX.Kind.VORTEX, at, UiTheme.element(element), seconds, element)


## An anime impact frame: the stage drawn as an inverted silhouette on a flash of `colour` for a few frames. For the
## blows that should feel too strong to see (a heavy strike landing).
func impact(colour: Color, seconds := 0.07) -> void:
	if fast:
		return
	var frame := ColorRect.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shading := ShaderMaterial.new()
	shading.shader = IMPACT
	shading.set_shader_parameter("flash", colour.lerp(Color.WHITE, 0.55))
	frame.material = shading
	_fx.add_child(frame)
	get_tree().create_timer(seconds).timeout.connect(frame.queue_free)


## The whole stage lit for an instant (lightning), its colour's alpha the strength.
func flash(colour: Color, seconds := 0.2) -> void:
	if fast:
		return
	var light := ColorRect.new()
	light.color = colour
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light.material = additive
	_fx.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "modulate:a", 0.0, seconds)
	tween.tween_callback(light.queue_free)


## The stage darkens while a heavy spell gathers (0 is none), and clears again.
func dim(amount: float, seconds := 0.25) -> void:
	if fast:
		return
	var shade: ColorRect = _fx.get_node_or_null("Dim")
	if shade == null:
		shade = ColorRect.new()
		shade.name = "Dim"
		shade.color = Color(0.03, 0.02, 0.08, 0.0)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fx.add_child(shade)
		_fx.move_child(shade, 0)
	var tween := shade.create_tween()
	tween.tween_property(shade, "color:a", amount, seconds)


## A number or a word that rises from `at` and fades.
func popup(at: Vector2, text: String, colour: Color, font_size := 34) -> void:
	if fast:
		return
	var label := Ui.label(text, "Big")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	_fx.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.position = at - Vector2(label.size.x * 0.5, label.size.y)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 46, 0.9).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5).set_delay(0.5)
	tween.tween_callback(label.queue_free)


## A line across the middle of the stage (a new turn, a victory).
func banner(text: String, colour: Color, ms := 900.0) -> void:
	if fast:
		return
	var label := Ui.label(text, "Heading")
	label.add_theme_color_override("font_color", colour)
	var plate := Ui.panel(label, "Overlay")
	_fx.add_child(plate)
	plate.size = plate.get_combined_minimum_size()
	plate.position = Vector2((size.x - plate.size.x) * 0.5, size.y * 0.3)
	plate.modulate = Color(1, 1, 1, 0)
	var tween := plate.create_tween()
	tween.tween_property(plate, "modulate", Color.WHITE, 0.15)
	tween.tween_interval(ms / 1000.0)
	tween.tween_property(plate, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_callback(plate.queue_free)


func ward_glow() -> void:
	if fast:
		return
	BattleFX.spawn(_fx, BattleFX.Kind.WARD, hero.body_point(), UiTheme.TEAL, 0.95, "ward")
	var ward_seal := BattleFX.spawn(_fx, BattleFX.Kind.CAST, hero.body_point(), Color(1.0, 0.78, 0.38), 0.58)
	ward_seal.scale = Vector2.ONE * 0.82


func cast_flash(element: String, heavy := false) -> void:
	if fast:
		return
	var colour := UiTheme.element(element)
	var seal := BattleFX.spawn(_fx, BattleFX.Kind.CAST, hero.hand_point(), colour, 0.82 if heavy else 0.68, element)
	seal.scale = Vector2.ONE * (1.45 if heavy else 1.0)
	if heavy:
		var flare := BattleFX.spawn(_fx, BattleFX.Kind.BURST, hero.body_point(), Color(1.0, 0.73, 0.34), 0.62)
		flare.scale = Vector2.ONE * 1.35


func shake(strength: float) -> void:
	if fast or not Settings.shake or strength <= 0.0:
		return
	if _shake_tween != null:
		_shake_tween.kill()
	_shake_tween = create_tween()
	var amount := clampf(strength, 0.0, 1.0) * 12.0
	for i in 6:
		var offset := Vector2(randf_range(-amount, amount), randf_range(-amount, amount) * 0.6)
		_shake_tween.tween_property(_world, "position", offset, 0.035)
		_shake_tween.parallel().tween_property(_fx, "position", offset, 0.035)
		amount *= 0.7
	_shake_tween.tween_property(_world, "position", Vector2.ZERO, 0.04)
	_shake_tween.parallel().tween_property(_fx, "position", Vector2.ZERO, 0.04)


## Freezes the action for a moment so a heavy hit lands with weight.
## LEARN: Engine.time_scale slows every timer and tween at once; the timer that ends the freeze ignores the time scale
## (its last argument), or it would be frozen too and the game would never wake up.
func hit_stop(ms: float) -> void:
	if fast or not is_inside_tree():
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Soft dark ellipses on the floor under everyone's feet: the cheapest thing that makes a figure stand on a painting.
class _Shadows:
	extends Control

	## (x, floor y, half width) per figure.
	var feet: Array[Vector3] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for foot in feet:
			for ring in 4:
				var spread := 1.0 + ring * 0.22
				draw_set_transform(Vector2(foot.x, foot.y), 0.0, Vector2(1.0, 0.24))
				draw_circle(Vector2.ZERO, foot.z * spread, Color(0.02, 0.01, 0.03, 0.42 - ring * 0.09))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A shared near-ground haze and edge shade make painted rooms and sprite actors occupy one light space.
class _Grade:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		for step in 24:
			var y := size.y * float(step) / 24.0
			var t := float(step) / 23.0
			var darkness := 0.06 + pow(t, 2.7) * 0.42
			draw_rect(Rect2(0, y, size.x, size.y / 24.0 + 1.0), Color(0.04, 0.025, 0.05, darkness))
		draw_rect(Rect2(0, size.y * BattleStage.FLOOR, size.x, 2.0), Color(1.0, 0.67, 0.34, 0.11))
