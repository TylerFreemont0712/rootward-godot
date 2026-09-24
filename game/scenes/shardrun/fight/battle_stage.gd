class_name BattleStage
extends Control
## The painted arena with the Maintainer on the left and the foes on the right, and everything that happens between
## them: bolts in flight, bursts, numbers, banners, the shake of a heavy hit and the freeze of hit-stop. It knows how to
## show things, never what happened: LogPlayer tells it, entry by entry, from the rules' log.

const FOE_SPAN := Vector2(0.5, 0.95)
const HERO_X := 0.04

## Every stage skips its waits and animations (tests and tools that drive the screens).
static var instant := false

## Skip every wait and animation from here on (the player clicked through).
var fast := false:
	get:
		return fast or instant
var hero: HeroView
var foes: Dictionary = {}
var _world: Control
var _backdrop: TextureRect
var _fx: Control
var _shake_tween: Tween


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_backdrop = TextureRect.new()
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(_backdrop)
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
	_backdrop.modulate = Color(0.85, 0.82, 0.8)


## Replaces the foes with these (a new fight), each fading in.
func set_foes(foe_states: Array, catalog: Dictionary, entrance := false) -> void:
	for view: FoeView in foes.values():
		view.queue_free()
	foes.clear()
	var delay := 0.0
	for foe: Dictionary in foe_states:
		var view := FoeView.create(foe, catalog)
		_world.add_child(view)
		foes[foe.uid] = view
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
	_backdrop.size = size
	_fx.size = size
	var hero_height := size.y * 0.98
	hero.size = Vector2(hero_height * 0.75, hero_height)
	hero.position = Vector2(size.x * HERO_X, size.y - hero_height)
	var count := foes.size()
	var index := 0
	for view: FoeView in foes.values():
		view.size = view.get_combined_minimum_size()
		var share := (index + 0.5) / count
		var x := size.x * lerpf(FOE_SPAN.x, FOE_SPAN.y, share)
		if count == 1:
			x = size.x * 0.74
		view.position = Vector2(x - view.size.x * 0.5, size.y - view.size.y - 8)
		index += 1


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
	var id := "shardrun/bolt-ward" if ward else "shardrun/bolt-" + element
	var bolt := Ui.picture(id, Vector2(40, 40), "◆")
	bolt.modulate = UiTheme.TEAL if ward and bolt is Label else Color.WHITE
	bolt.pivot_offset = Vector2(20, 20)
	_fx.add_child(bolt)
	bolt.position = from - Vector2(20, 20)
	var lift := -40.0 - randf() * 50.0
	var tween := bolt.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			bolt.position = from.lerp(to, t) + Vector2(0, lift * 4.0 * t * (1.0 - t)) - Vector2(20, 20),
		0.0,
		1.0,
		ms / 1000.0
	)
	tween.tween_callback(arrive)
	tween.tween_callback(bolt.queue_free)


func burst(at: Vector2, element: String, scale_to := 1.4) -> void:
	if fast:
		return
	var id := "fx/burst-arcane" if element == "none" else "fx/burst-" + element
	var picture := Ui.picture(id, Vector2(96, 96), "")
	picture.pivot_offset = Vector2(48, 48)
	picture.position = at - Vector2(48, 48)
	picture.scale = Vector2(0.6, 0.6)
	_fx.add_child(picture)
	var tween := picture.create_tween().set_parallel()
	tween.tween_property(picture, "scale", Vector2(scale_to, scale_to), 0.32)
	tween.tween_property(picture, "modulate", Color(1, 1, 1, 0), 0.36)
	tween.chain().tween_callback(picture.queue_free)


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
	var glow := Ui.picture("fx/ward", Vector2(220, 220), "")
	glow.modulate = Color(UiTheme.TEAL, 0.0)
	glow.position = hero.body_point() - Vector2(110, 110)
	_fx.add_child(glow)
	var tween := glow.create_tween()
	tween.tween_property(glow, "modulate:a", 0.85, 0.15)
	tween.tween_property(glow, "modulate:a", 0.0, 0.45)
	tween.tween_callback(glow.queue_free)


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
		amount *= 0.7
	_shake_tween.tween_property(_world, "position", Vector2.ZERO, 0.04)


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
