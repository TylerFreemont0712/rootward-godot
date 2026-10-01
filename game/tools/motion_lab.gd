extends Control
## The motion lab (ADR-0030): the move library played on the motion dummy (or any 3D skin) as on the stage, to judge
## and tune the moves before they go onto the skins. Pick a clip; a cast writes its magic circle, strikes on it, holds
## while a volley pours out of it and lets go. Slow it down, step it frame by frame, scrub it, compare limited
## animation (15 poses a second) with smooth, turn the camera, and follow the hands and head by their trails (good
## motion moves in arcs).
##   scripts/motion-lab.sh                  (ROOTWARD_SKIN=<id> opens another skin)
## ROOTWARD_CLIP plays a clip at once (for a screenshot).
## Keys: space pause, left/right a frame, up/down the speed, 1-9 the clips, L limited, T trails, V the view.

const SPEEDS: Array[float] = [0.1, 0.25, 0.5, 1.0]
const VIEWS: Array[Array] = [["Stage", 35.0], ["Side", 90.0], ["Front", 0.0], ["Back three-quarter", 145.0]]
const TRAIL_SECONDS := 0.7
const TRAILS := {"LeftHand": Color("#5cc8b8"), "RightHand": Color("#f2a541"), "Head": Color("#b48cff")}
## The view's camera, as HeroView frames a humanoid skin.
const FRAME := Vector2(2.4, 1.17)
const VOLLEY := 6
const VOLLEY_GAP := 0.16
const ELEMENTS: Array[String] = ["none", "fire", "frost", "spark"]

var _skin := "dummy"
var _hero: StageCharacter
var _viewport: SubViewport
var _view_box: SubViewportContainer
var _camera: Camera3D
var _overlay: Control
var _trail_mesh: ImmediateMesh
var _history: Dictionary = {}
var _speed := 1.0
var _paused := false
var _trails := true
var _loop := true
var _view := 0
var _element := "none"
var _clip := "idle-breathe"
var _serial := 0
var _circle: MagicCircle
var _clips_box: VBoxContainer
var _status: Label
var _slider: HSlider
var _limited_button: Button
var _speed_buttons: HBoxContainer


func _ready() -> void:
	theme = UiTheme.shared()
	var chosen := OS.get_environment("ROOTWARD_SKIN")
	if chosen != "" and StageCharacter.has_skin(chosen):
		_skin = chosen
	var backdrop := ColorRect.new()
	backdrop.color = UiTheme.GROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var stage := _stage()
	var panel := _panel()
	var row := Ui.hbox([stage, panel], 12)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		row.set("offset_" + side, 12.0 if side in ["left", "top"] else -12.0)
	add_child(row)
	_build_hero()
	var clip := OS.get_environment("ROOTWARD_CLIP")
	if clip != "":
		await get_tree().process_frame
		_play.call_deferred(clip)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _stage() -> Control:
	_view_box = SubViewportContainer.new()
	_view_box.stretch = true
	_view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_view_box.add_child(_viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#1d1722")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.62, 0.56, 0.6)
	environment.environment.ambient_light_energy = 0.9
	_viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.1
	_viewport.add_child(key)
	key.basis = Basis.looking_at(-HeroView.KEY_LIGHT)
	_viewport.add_child(_floor())
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Looking a little down on her, so the floor's stride lines show under her feet.
	_camera.size = FRAME.x + 0.2
	_camera.position = Vector3(0.45, FRAME.y + 0.95, 6.0)
	_camera.rotation_degrees.x = -9.0
	_camera.current = true
	_viewport.add_child(_camera)
	_trail_mesh = ImmediateMesh.new()
	var trails := MeshInstance3D.new()
	trails.mesh = _trail_mesh
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.vertex_color_use_as_albedo = true
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.no_depth_test = true
	trails.material_override = ink
	_viewport.add_child(trails)
	# The circle and its bolts are drawn in 2D over the view, as on the stage.
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view_box.add_child(_overlay)
	return _view_box


## A dark floor with a ring under her feet and lines a stride apart, so weight shifts and foot slides show.
func _floor() -> Node3D:
	var floor_node := Node3D.new()
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(40, 40)
	plane.mesh = mesh
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("#2a2230")
	ground.roughness = 1.0
	plane.material_override = ground
	floor_node.add_child(plane)
	var lines := StandardMaterial3D.new()
	lines.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lines.albedo_color = Color("#4a3d55")
	for i in range(-6, 7):
		for across: bool in [false, true]:
			var line := MeshInstance3D.new()
			var bar := BoxMesh.new()
			bar.size = Vector3(0.006, 0.001, 6.0) if not across else Vector3(6.0, 0.001, 0.006)
			line.mesh = bar
			line.material_override = lines
			line.position = Vector3(i * 0.25, 0.001, 0) if not across else Vector3(0, 0.001, i * 0.25)
			floor_node.add_child(line)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.44
	ring.mesh = torus
	ring.scale = Vector3(1, 0.02, 1)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(UiTheme.TEAL, 0.6)
	ring.material_override = glow
	floor_node.add_child(ring)
	return floor_node


func _panel() -> Control:
	var skins := OptionButton.new()
	# The skins that play the move library: a normalised one (the dummy, the reference skins) or a VRM.
	var known: Array[String] = []
	for id in Settings.all_skins():
		var vrm := FileAccess.file_exists("res://characters/%s/%s.vrm" % [id, id])
		if AnimeSkin.folder(id) != "" or vrm:
			known.append(id)
	for id in known:
		skins.add_item(id)
		if id == _skin:
			skins.select(skins.item_count - 1)
	skins.item_selected.connect(func(index: int) -> void: _set_skin(skins.get_item_text(index)))
	var elements := OptionButton.new()
	for element in ELEMENTS:
		elements.add_item(element)
	elements.item_selected.connect(func(index: int) -> void: _element = ELEMENTS[index])
	_clips_box = Ui.vbox([], 4)
	_status = Ui.label("", "Code")
	_slider = HSlider.new()
	_slider.step = 1.0 / 30.0
	_slider.value_changed.connect(_scrub)
	_speed_buttons = Ui.hbox([], 6)
	_limited_button = Ui.button("", _toggle_limited)
	var view_button := Ui.button("View: Stage", _turn_view)
	view_button.name = "View"
	var column := (
		Ui
		. vbox(
			[
				Ui.label("MOTION LAB", "Faint"),
				Ui.label("Moves on the dummy", "Subheading"),
				Ui.hbox([Ui.label("Skin", "Muted"), skins, Ui.label("Circle", "Muted"), elements], 8),
				Ui.label("CLIPS · 1-9", "Faint"),
				_clips_box,
				Ui.label("PLAYBACK", "Faint"),
				_speed_buttons,
				Ui.hbox(
					[
						Ui.button("⏯ Pause", _toggle_pause),
						Ui.button("◀ Frame", _step.bind(-1)),
						Ui.button("Frame ▶", _step.bind(1))
					],
					6
				),
				_slider,
				_status,
				Ui.hbox([_limited_button, Ui.button("Trails", _toggle_trails), Ui.button("Loop", _toggle_loop)], 6),
				view_button,
				Ui.label(
					(
						"Limited plays 15 poses a second, held (the 2XKO look); smooth plays every frame. "
						+ "Trails follow the lead hand (teal), the rear hand (amber) and the head (violet): "
						+ "good motion moves in arcs."
					),
					"Muted",
					true
				),
			],
			8
		)
	)
	column.custom_minimum_size.x = 420
	return Ui.panel(column, "Card")


func _build_hero() -> void:
	if _hero != null:
		_hero.queue_free()
	_hero = StageCharacter.create(_skin)
	_hero.rotation_degrees.y = float(VIEWS[_view][1])
	_viewport.add_child(_hero)
	_hero.set_light_direction(HeroView.KEY_LIGHT)
	_hero.clip_finished.connect(_on_finished)
	_history.clear()
	Ui.clear(_clips_box)
	var ids: Array = _hero.moves.keys()
	ids.sort()
	var shown := ids.filter(func(id: String) -> bool: return not id.ends_with("-hold") and not id.ends_with("-end"))
	var grid := GridContainer.new()
	grid.columns = 3
	for i in shown.size():
		var id: String = shown[i]
		grid.add_child(Ui.button("%d %s" % [i + 1, id] if i < 9 else id, _play.bind(id)))
	_clips_box.add_child(grid)
	_refresh()


func _set_skin(id: String) -> void:
	_skin = id
	_build_hero()


## Plays a clip; a cast writes its circle, strikes on it, fires a volley out of it and lets go, as on the stage.
func _play(clip: String) -> void:
	_serial += 1
	var serial := _serial
	_clip = clip
	_paused = false
	_hero.player.speed_scale = 1.0
	if is_instance_valid(_circle):
		_circle.queue_free()
	_hero.play(clip)
	_refresh()
	if not clip in StageCharacter.CASTS:
		return
	var tier := 1 if clip == "cast-light" else 3
	var height := _view_box.size.y * 0.92
	var size := clampf(height * (0.15 + 0.035 * tier), 56.0, 230.0)
	var palm: Variant = _hero.release_point()
	var at := _to_overlay(palm as Vector3) if palm != null else _view_box.size * 0.5
	_circle = MagicCircle.cast(
		_overlay, at + Vector2(size * 0.42 + height * 0.05, height * 0.005), tier, _element, size
	)
	_hero.release_in(_circle.form_time())
	await _circle.formed
	for i in VOLLEY:
		if serial != _serial or not is_instance_valid(_circle):
			return
		_bolt(_circle.launch_point())
		_circle.pulse()
		await get_tree().create_timer(VOLLEY_GAP).timeout
	if serial != _serial:
		return
	if is_instance_valid(_circle):
		_circle.close()
	_hero.end_cast()


## A streak of light leaving the circle toward where the foes would stand.
func _bolt(from: Vector2) -> void:
	var streak := Line2D.new()
	streak.width = 5.0
	streak.default_color = Color(SpellAnim.RAMPS.get(_element, SpellAnim.RAMPS.none)[2])
	var light := CanvasItemMaterial.new()
	light.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	streak.material = light
	streak.points = PackedVector2Array([from, from])
	_overlay.add_child(streak)
	var to := Vector2(_view_box.size.x + 40.0, from.y + randf_range(-60.0, 60.0))
	var tween := streak.create_tween()
	tween.tween_method(
		func(u: float) -> void:
			streak.points = PackedVector2Array([from.lerp(to, maxf(0.0, u - 0.15)), from.lerp(to, u)]),
		0.0,
		1.15,
		0.28
	)
	tween.tween_callback(streak.queue_free)


## With Loop on, a clip plays again half a second after it ends; a cast, after its letting go has ended.
func _on_finished(clip: String) -> void:
	if not _loop or _paused:
		return
	var ended := clip == _clip and not clip in StageCharacter.CASTS and not _hero.is_loop(clip)
	if not ended and not (_clip in StageCharacter.CASTS and clip == _clip + "-end"):
		return
	var serial := _serial
	await get_tree().create_timer(0.5).timeout
	if serial == _serial:
		_play(_clip)


func _process(_delta: float) -> void:
	if _hero == null or _hero.player == null:
		return
	_record_trails()
	if not _slider.has_focus():
		_slider.set_value_no_signal(_hero.player.current_animation_position)
	_refresh_status()


func _record_trails() -> void:
	_trail_mesh.clear_surfaces()
	if not _trails:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for bone: String in TRAILS:
		var point: Variant = _hero.bone_point(bone)
		if point == null:
			continue
		var points: Array = _history.get(bone, [])
		if not _paused:
			points.append([now, point])
		while not points.is_empty() and now - float(points[0][0]) > TRAIL_SECONDS / maxf(Engine.time_scale, 0.05):
			points.pop_front()
		_history[bone] = points
		if points.size() < 2:
			continue
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in points.size():
			var colour: Color = TRAILS[bone]
			colour.a = float(i) / points.size()
			_trail_mesh.surface_set_color(colour)
			_trail_mesh.surface_add_vertex(points[i][1])
		_trail_mesh.surface_end()


func _to_overlay(world: Vector3) -> Vector2:
	return _camera.unproject_position(world) * _view_box.size / Vector2(_viewport.size)


func _scrub(seconds: float) -> void:
	if _hero.player.current_animation == "":
		return
	_paused = true
	_hero.player.seek(seconds, true)
	_hero.player.pause()
	_refresh()


func _step(frames: int) -> void:
	if _hero.player.current_animation == "":
		return
	_paused = true
	_hero.player.pause()
	var length := _hero.player.current_animation_length
	_hero.player.seek(clampf(_hero.player.current_animation_position + frames / 30.0, 0.0, length), true)
	_refresh()


func _toggle_pause() -> void:
	_paused = not _paused
	if _paused:
		_hero.player.pause()
	else:
		_hero.player.play()
	_refresh()


func _set_speed(speed: float) -> void:
	_speed = speed
	Engine.time_scale = speed
	_refresh()


func _toggle_limited() -> void:
	_hero.set_limited(0.0 if _hero.limited_fps() > 0.0 else StageCharacter.LIMITED_FPS)
	_refresh()


func _toggle_trails() -> void:
	_trails = not _trails
	_history.clear()


func _toggle_loop() -> void:
	_loop = not _loop
	_refresh()


func _turn_view() -> void:
	_view = (_view + 1) % VIEWS.size()
	_hero.rotation_degrees.y = float(VIEWS[_view][1])
	_history.clear()
	(find_child("View", true, false) as Button).text = "View: " + String(VIEWS[_view][0])


func _refresh() -> void:
	Ui.clear(_speed_buttons)
	for speed in SPEEDS:
		_speed_buttons.add_child(Ui.choice("%sx" % str(speed), is_equal_approx(speed, _speed), _set_speed.bind(speed)))
	_limited_button.text = "Limited 15/s" if _hero != null and _hero.limited_fps() > 0.0 else "Smooth"
	if _hero != null and _hero.player != null:
		_slider.max_value = maxf(_hero.player.current_animation_length, 0.01)
	_refresh_status()


func _refresh_status() -> void:
	if _hero == null or _hero.player == null:
		return
	var at := _hero.player.current_animation_position
	_status.text = (
		"%s  %.2fs / %.2fs  frame %d%s%s"
		% [
			_hero.current,
			at,
			_hero.player.current_animation_length,
			roundi(at * 30.0),
			"  paused" if _paused else "",
			"  loop" if _loop else "",
		]
	)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo and not key.keycode in [KEY_LEFT, KEY_RIGHT]:
		return
	match key.keycode:
		KEY_SPACE:
			_toggle_pause()
		KEY_LEFT:
			_step(-1)
		KEY_RIGHT:
			_step(1)
		KEY_UP:
			_set_speed(SPEEDS[mini(SPEEDS.find(_speed) + 1, SPEEDS.size() - 1)])
		KEY_DOWN:
			_set_speed(SPEEDS[maxi(SPEEDS.find(_speed) - 1, 0)])
		KEY_L:
			_toggle_limited()
		KEY_T:
			_toggle_trails()
		KEY_V:
			_turn_view()
		_:
			var index := key.keycode - KEY_1
			var grid := _clips_box.get_child(0) if _clips_box.get_child_count() > 0 else null
			if grid != null and index >= 0 and index < mini(9, grid.get_child_count()):
				(grid.get_child(index) as Button).pressed.emit()
			else:
				return
	get_viewport().set_input_as_handled()
