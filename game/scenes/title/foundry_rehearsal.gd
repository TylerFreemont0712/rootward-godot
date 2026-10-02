class_name FoundryRehearsal
extends Control
## The real skin renderer and cast circles, with a local rehearsal clock and no run or equipment mutations.

signal skin_ready
var hero: HeroView
var clip := StageCharacter.IDLE
var speed := 1.0
var paused := true
var looping := false
var circles := true
var tier := 1
var element := "none"
var zoom := 1.0
var view_angle := 35.0
var marks := true
var contrast := false
var _elapsed := 0.0
var _release := -1.0
var _next_pulse := -1.0
var _pulses := 0
var _replay := -1.0
var _circle: MagicCircle
var _bolts: Array[Dictionary] = []
var _fx: Control


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	resized.connect(_fit)


func set_skin(id: String) -> void:
	_clear_effects()
	if is_instance_valid(hero):
		remove_child(hero)
		hero.queue_free()
	hero = HeroView.new()
	hero.preview_skin = id
	add_child(hero)
	move_child(_fx, -1)
	clip = StageCharacter.IDLE
	_elapsed = 0.0
	_fit()
	seek(0.0)
	skin_ready.emit()


func clips() -> Array[String]:
	var available: Array[String] = []
	if hero == null:
		return available
	if hero.sprite != null:
		available.assign(hero.sprite.manifest.get("clips", {}).keys())
	elif hero.character != null and hero.character.player != null:
		available.assign(hero.character.player.get_animation_list())
	available = available.filter(
		func(id: String) -> bool: return not id.ends_with("-hold") and not id.ends_with("-end")
	)
	available.sort()
	return available


func play(animation: String) -> void:
	if animation not in clips():
		return
	_clear_effects()
	clip = animation
	_elapsed = 0.0
	hero.play(clip)
	set_paused(false)
	_set_actor_speed()
	_replay = maxf(duration() + 0.5, 4.5 if clip.begins_with("cast-") else 0.0)
	if circles and clip.begins_with("cast-"):
		_release = hero.release_left() * speed if hero.character != null else SpriteCharacter.RELEASE_MS / 1000.0
		if clip == "cast-heavy":
			_release = 0.0


func preview_circle() -> void:
	_clear_effects()
	_elapsed = 0.0
	set_paused(false)
	_form_circle()
	_replay = -1.0


func _form_circle() -> void:
	_release = -1.0
	var radius := 92.0 + tier * 12.0
	_circle = MagicCircle.cast(_fx, hero.circle_point(radius), tier, element, radius, "", speed)
	# LEARN: drive the complete effect with the stage's clock, including its turning/closing phases.
	_circle.process_mode = Node.PROCESS_MODE_DISABLED
	_circle.speed = 1.0
	_circle.formed.connect(func() -> void: _next_pulse = _elapsed, CONNECT_ONE_SHOT)


func set_paused(value: bool) -> void:
	paused = value
	if hero != null:
		hero.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT


func duration() -> float:
	if hero == null:
		return 0.0
	if hero.sprite != null:
		return hero.sprite._duration(hero.sprite.manifest.get("clips", {}).get(clip, {}))
	if hero.character != null and hero.character.player != null and hero.character.player.has_animation(clip):
		return hero.character.player.get_animation(clip).length
	return 0.0


func seek(seconds: float) -> void:
	_clear_effects()
	set_paused(true)
	_elapsed = clampf(seconds, 0.0, duration())
	if hero.sprite != null:
		hero.sprite.play(clip)
		hero.sprite._time = _elapsed
		var info: Dictionary = hero.sprite.manifest.clips.get(clip, {})
		hero.sprite.frame = clampi(hero.sprite._frame_at(info, _elapsed), 0, maxi(0, int(info.get("frames", 1)) - 1))
		hero.sprite.queue_redraw()
	elif hero.character != null and hero.character.player != null:
		hero.character.play(clip)
		# Inspect the chosen frame directly, without blending from a previous pose or the model's rest pose.
		hero.character.player.play(clip, 0.0)
		hero.character.player.seek(_elapsed, true)


func step(direction: int) -> void:
	if direction < 0:
		seek(_elapsed - 1.0 / 30.0)
		return
	set_paused(true)
	_set_actor_speed()
	if hero.sprite != null:
		hero.sprite._process(1.0 / (30.0 * speed))
	elif hero.character != null and hero.character.player != null:
		hero.character.player.advance(1.0 / (30.0 * speed))
	_tick(1.0 / 30.0)
	if is_instance_valid(_circle):
		_circle._process(1.0 / 30.0)


func _process(delta: float) -> void:
	if hero == null or paused:
		return
	_set_actor_speed()
	if is_instance_valid(_circle):
		_circle._process(delta * speed)
	_tick(delta * speed)


func _set_actor_speed() -> void:
	if hero.sprite != null:
		hero.sprite.playback_speed = speed
	elif hero.character != null and hero.character.player != null:
		hero.character.player.speed_scale = speed
	if is_instance_valid(_circle):
		_circle.speed = 1.0


func _tick(delta: float) -> void:
	_elapsed += delta
	if _release >= 0.0 and _elapsed >= _release:
		_form_circle()
	if _next_pulse >= 0.0 and _elapsed >= _next_pulse and is_instance_valid(_circle):
		_circle.pulse()
		_bolt(_circle.launch_point())
		_pulses += 1
		_next_pulse = _elapsed + 0.16
		if _pulses >= 6:
			_next_pulse = -1.0
			_circle.close()
			hero.end_cast()
	for bolt: Dictionary in _bolts.duplicate():
		bolt.age += delta
		var u := float(bolt.age) / 0.32
		var line: Line2D = bolt.line
		if u > 1.15:
			line.queue_free()
			_bolts.erase(bolt)
		else:
			line.points = PackedVector2Array([bolt.from.lerp(bolt.to, maxf(0.0, u - 0.18)), bolt.from.lerp(bolt.to, u)])
	if looping and _replay > 0.0 and _elapsed >= _replay:
		play(clip)


func _bolt(from: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = UiTheme.element(element)
	line.points = PackedVector2Array([from, from])
	_fx.add_child(line)
	_bolts.append({"line": line, "from": from, "to": Vector2(size.x + 30, from.y - 18 + _pulses * 7), "age": 0.0})


func _clear_effects() -> void:
	if _fx != null:
		Ui.clear(_fx)
	_circle = null
	_bolts.clear()
	_release = -1.0
	_next_pulse = -1.0
	_pulses = 0
	_replay = -1.0


func _fit() -> void:
	if hero == null:
		return
	hero.size = Vector2(310, 450) * zoom
	hero.position = Vector2(size.x * 0.39 - hero.size.x * 0.5, size.y * 0.90 - hero.size.y)
	if hero.character != null:
		hero.character.rotation_degrees.y = view_angle
	queue_redraw()


func _draw() -> void:
	if contrast:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.025, 0.90))
	if marks:
		var center := Vector2(size.x * 0.39, size.y * 0.90)
		var points := PackedVector2Array()
		for i in 97:
			var angle := i * TAU / 96
			points.append(center + Vector2(cos(angle) * 142, sin(angle) * 34))
		draw_polyline(points, Color(UiTheme.AMBER, 0.45), 2.0, true)
