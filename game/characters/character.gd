class_name StageCharacter
extends Node3D
## A character on the stage, playing its clips with short blends between them. Two kinds (ADR-0005, ADR-0028):
##
## - a **VRM skin** (`characters/<id>/<id>.vrm`): an anime model imported by godot-vrm, keeping its MToon materials,
##   its spring-bone hair and cloth and its face expressions. Its clips are the shared move library
##   (`characters/moves/rootward.glb`), retargeted through Godot's humanoid profile, so every VRM skin moves alike.
## - a **glTF model** (`characters/<id>/<id>.glb`, Emberfox) with its own clips, dressed in the toon shader and ink.
##
##   var hero := StageCharacter.create("shibu")
##   add_child(hero)
##   hero.play("cast-light")      # then back to idle on its own
##   hero.release_in(0.86)        # time the palm to the sigil's blow
##
## A character with no model file becomes an empty node: art is optional, and the stage still runs.

signal clip_finished(clip: String)

const TOON := preload("res://characters/toon.gdshader")
const OUTLINE := preload("res://characters/outline.gdshader")
const MOVES := "res://characters/moves/rootward.glb"
const MOVES_META := "res://characters/moves/moves.json"
## Seconds to cross-fade from one clip into the next.
const BLEND := 0.18
## Clips that loop; every other clip returns to the idle when it ends (or holds its last pose, see HOLDS).
const LOOPS: Array[String] = ["idle-breathe", "channel"]
const HOLDS: Array[String] = ["victory", "death", "windup"]
## A cast ends in its push, held: "<cast>-hold" loops it while the circle fires and "<cast>-end" lets go (end_cast).
const CASTS: Array[String] = ["cast-light", "cast-heavy"]
const IDLE := "idle-breathe"
## Limited animation (ADR-0029): a humanoid skin's pose, leg IK and springs advance together this many times a second
## and hold in between, as Guilty Gear and 2XKO animate (no in-between interpolation reads as drawn, not 3D). A skin's
## `style.fps` overrides it; ROOTWARD_LIMITED=0 plays smoothly, for comparison.
const LIMITED_FPS := 15.0
## How far a cast may be sped up or slowed down to land its release on the stage's beat.
const RELEASE_SPEED := Vector2(0.55, 2.2)
## A cast's charge (the coil before the strike) may be slowed this far to wait for a circle that takes long to draw.
const CHARGE_SLOWEST := 0.3

var id: String
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var materials: Array[ShaderMaterial] = []
## A VRM skin's own player, holding its face expressions (`happy`, `angry`, `blink`...).
var face: AnimationPlayer
## The move library's facts per clip (moves.json): length, loop, release, hand, release_point, face.
var moves: Dictionary = {}
var current := ""
var _serial := 0
## Anime-shaded faces, which need the head's facing every frame (AnimeSkin, ADR-0029).
var _faces: Array[ShaderMaterial] = []
## Leg IK that keeps a humanoid skin's planted feet on its own floor (LegPlanting).
var _legs: LegPlanting
## skin.json `style` of an anime skin (its own light, shade, ink).
var _style_facts: Dictionary = {}
var _limited_fps := 0.0
var _held := 0.0
## The cast being played or held ("" when none), whether it should let go as soon as its push is reached, and the
## clip time at which its slowed charge ends and the strike plays at its own speed again (-1 when not slowed).
var _cast := ""
var _letting_go := false
var _charge_until := -1.0


static func create(character_id: String) -> StageCharacter:
	var character := StageCharacter.new()
	character.id = character_id
	character.name = character_id
	var vrm := "res://characters/%s/%s.vrm" % [character_id, character_id]
	var glb := "res://characters/%s/%s.glb" % [character_id, character_id]
	var anime := AnimeSkin.folder(character_id)
	if anime != "" and ResourceLoader.exists(MOVES):
		var facts := AnimeSkin.read(anime)
		character.model = (load(anime + String(facts.get("model", ""))) as PackedScene).instantiate() as Node3D
		character.add_child(character.model)
		character._dress_anime(anime, facts)
	elif ResourceLoader.exists(vrm) and ResourceLoader.exists(MOVES):
		character.model = (load(vrm) as PackedScene).instantiate() as Node3D
		character.add_child(character.model)
		character._dress_vrm()
	elif ResourceLoader.exists(glb):
		character.model = (load(glb) as PackedScene).instantiate() as Node3D
		character.add_child(character.model)
		character._dress()
	return character


static func has_skin(character_id: String) -> bool:
	if AnimeSkin.folder(character_id) != "":
		return true
	for extension: String in ["vrm", "glb"]:
		if ResourceLoader.exists("res://characters/%s/%s.%s" % [character_id, character_id, extension]):
			return true
	return false


func _ready() -> void:
	if player != null:
		play(IDLE)


func has_model() -> bool:
	return model != null


## A VRM skin (MToon, which needs a real light in the view).
func is_vrm() -> bool:
	return face != null


## Any skin that plays the shared move library (a VRM or a normalised anime skin).
func is_humanoid() -> bool:
	return not moves.is_empty()


## The anime shaders are unshaded and take the light as a direction (toward the light, world space). A skin may bring
## its own (skin.json `style.light`, in its own facing: x to its left, y up, z to its front), as Guilty Gear gives each
## character a light tuned to its pose, so its shadow shapes read.
func set_light_direction(direction: Vector3) -> void:
	var own: Variant = _style_facts.get("light")
	if own is Array and (own as Array).size() == 3 and model != null:
		direction = (
			global_basis * Vector3(own[0], own[1], own[2])
			if is_inside_tree()
			else basis * Vector3(own[0], own[1], own[2])
		)
	for material in materials:
		material.set_shader_parameter("light_dir", direction.normalized())


func play(clip: String) -> void:
	if player == null or not player.has_animation(clip):
		return
	_cast = clip if clip in CASTS else ""
	_letting_go = false
	_play(clip)


func _play(clip: String) -> void:
	_charge_until = -1.0
	_serial += 1
	current = clip
	player.speed_scale = 1.0
	player.play(clip, BLEND)
	_schedule_face(clip)


## Times a cast so its release (the palm thrust at the circle) lands `seconds` from now. A cast with a `charge` waits
## in its charge: only the coil before the strike is slowed, so the strike itself keeps its snap whatever the circle's
## length; anything else is sped up or slowed down as a whole.
func release_in(seconds: float) -> void:
	var facts: Dictionary = moves.get(current, {})
	var release: Variant = facts.get("release")
	if release == null or seconds <= 0.0 or player == null:
		return
	var at := player.current_animation_position
	var left := float(release) - at
	if left <= 0.0:
		return
	var charge: Variant = facts.get("charge")
	# LEARN: wait in the wind-up, never in the strike. Only the coil before `charge` is stretched; once the playhead
	# passes it (_process) the speed returns to 1, so the snap is the same whatever the circle's length.
	if charge != null and float(charge) > at and seconds > left:
		var strike := float(release) - float(charge)
		var speed := (float(charge) - at) / maxf(seconds - strike, 0.01)
		player.speed_scale = clampf(speed, CHARGE_SLOWEST, 1.0)
		_charge_until = float(charge)
	else:
		player.speed_scale = clampf(left / seconds, RELEASE_SPEED.x, RELEASE_SPEED.y)


## Plays in limited animation at `fps` poses a second (0: smoothly), as a skin's style sets it; the motion lab toggles
## it to compare.
func set_limited(fps: float) -> void:
	_limited_fps = fps
	_held = 0.0
	if player == null:
		return
	var manual := fps > 0.0
	player.callback_mode_process = (
		AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if manual
		else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	)
	if skeleton != null:
		skeleton.modifier_callback_mode_process = (
			Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
			if manual
			else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
		)


func limited_fps() -> float:
	return _limited_fps


## The volley is over: the held cast lets go (at once if it is holding, else as soon as its push is reached).
func end_cast() -> void:
	if _cast == "" or player == null:
		return
	if current == _cast:
		_letting_go = true
	else:
		_let_go()


func _let_go() -> void:
	var ending := _cast + "-end"
	_cast = ""
	_letting_go = false
	_play(ending if player.has_animation(ending) else IDLE)


## Where the casting palm will be at the current clip's release, in world space; null when the clip has none.
func release_point() -> Variant:
	var facts: Dictionary = moves.get(current, {})
	var point: Array = facts.get("release_point", [])
	if point.size() != 3 or skeleton == null:
		return null
	var hips := skeleton.find_bone("Hips")
	var height := skeleton.get_bone_global_rest(hips).origin.y if hips >= 0 else 1.0
	return model.global_transform * (Vector3(point[0], point[1], point[2]) * height)


## The world position of a bone right now (the casting hand, for effects that follow it).
func bone_point(bone: String) -> Variant:
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return null
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


## A flash of colour over the whole character (a hit, a cast); alpha is its strength.
func set_flash(colour: Color) -> void:
	for material in materials:
		material.set_shader_parameter("flash", colour)


func _dress_vrm() -> void:
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	face = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var style := _style()
	if style in ["anime", "anime-ink"]:
		materials = AnimeSkin.restyle_vrm(model, style == "anime-ink", 0.35)
		for material in materials:
			if AnimeSkin.is_face(material):
				_faces.append(material)
	_add_moves()
	_blink()


func _dress_anime(skin_folder: String, facts: Dictionary) -> void:
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	_style_facts = facts.get("style", {})
	materials = AnimeSkin.dress(model, skin_folder, facts, _style() == "anime-ink")
	for material in materials:
		if AnimeSkin.is_face(material):
			_faces.append(material)
	_add_moves()
	if skeleton != null:
		AnimeSkin.curl_tails(skeleton, facts.get("chains", []), float(facts.get("tail_curl", -14.0)))
		var springs := (
			AnimeSkin.springs(skeleton, facts.get("chains", []))
			if OS.get_environment("ROOTWARD_NO_SPRINGS") == ""
			else null
		)
		if springs != null:
			skeleton.add_child(springs)


## The anime look with ink is the game's (ADR-0029); ROOTWARD_STYLE=mtoon|anime compares the others.
static func _style() -> String:
	var style := OS.get_environment("ROOTWARD_STYLE")
	return style if style != "" else "anime-ink"


## The shared move library on its own player, driving the humanoid skeleton, with its feet planted by leg IK.
func _add_moves() -> void:
	if skeleton != null:
		_legs = LegPlanting.attach(skeleton)
	player = AnimationPlayer.new()
	player.name = "Moves"
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library("", load(MOVES) as AnimationLibrary)
	var file := FileAccess.open(MOVES_META, FileAccess.READ)
	if file != null:
		moves = (JSON.parse_string(file.get_as_text()) as Dictionary).get("clips", {})
	for clip: String in moves:
		if is_loop(clip) and player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.animation_finished.connect(_on_finished)
	if OS.get_environment("ROOTWARD_LIMITED") != "0":
		_limited_fps = float(_style_facts.get("fps", LIMITED_FPS))
	if _limited_fps > 0.0:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		if skeleton != null:
			skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL


## The face shader reads the light against the head's facing, which the clips turn every frame.
func _process(delta: float) -> void:
	var step := delta
	if _limited_fps > 0.0 and player != null:
		_held += delta
		if _held < 1.0 / _limited_fps:
			return
		step = _held
		_held = 0.0
		player.advance(step)
	if _charge_until >= 0.0 and player != null and player.current_animation_position >= _charge_until:
		player.speed_scale = 1.0
		_charge_until = -1.0
	# The feet's targets follow the pose just reached, before the skeleton's IK and springs run on it.
	if _legs != null and player != null:
		_legs.update(moves.get(current, {}), player.current_animation_position)
	if _limited_fps > 0.0 and skeleton != null:
		skeleton.advance(step)
	if _faces.is_empty() or skeleton == null:
		return
	var head := skeleton.find_bone("Head")
	if head < 0:
		return
	var turned := skeleton.get_bone_global_pose(head).basis * skeleton.get_bone_global_rest(head).basis.inverse()
	var basis := skeleton.global_basis * turned
	for material in _faces:
		material.set_shader_parameter("head_forward", (basis * Vector3.BACK).normalized())
		material.set_shader_parameter("head_up", (basis * Vector3.UP).normalized())


func _dress() -> void:
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		_toon(mesh as MeshInstance3D)
	if player != null:
		for clip in LOOPS:
			if player.has_animation(clip):
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		player.animation_finished.connect(_on_finished)
	_add_spring_bones()


func _toon(mesh: MeshInstance3D) -> void:
	for surface in mesh.mesh.get_surface_count():
		var imported := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
		var toon := ShaderMaterial.new()
		toon.shader = TOON
		if imported != null and imported.albedo_texture != null:
			toon.set_shader_parameter("drawing", imported.albedo_texture)
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		toon.next_pass = outline
		mesh.set_surface_override_material(surface, toon)
		materials.append(toon)


## Tail and ears follow the body with a little lag and settle, instead of being stiff (no take moves them).
func _add_spring_bones() -> void:
	if skeleton == null:
		return
	var chains: Array[Array] = []
	if skeleton.find_bone("Tail1") >= 0:
		chains.append(["Tail1", "Tail5", 0.45, 0.35])
	for ear: String in ["LeftEar", "RightEar"]:
		if skeleton.find_bone(ear) >= 0:
			chains.append([ear, ear, 1.4, 0.6])
	if chains.is_empty():
		return
	var springs := SpringBoneSimulator3D.new()
	springs.name = "Springs"
	springs.setting_count = chains.size()
	for i in chains.size():
		var chain: Array = chains[i]
		springs.set_root_bone_name(i, chain[0])
		springs.set_end_bone_name(i, chain[1])
		springs.set_stiffness(i, chain[2])
		springs.set_drag(i, chain[3])
		springs.set_gravity(i, 0.0)
		# An ear is a single bone: the spring needs a tip beyond it to swing. The tail's last bone gets one too.
		springs.set_extend_end_bone(i, true)
		springs.set_end_bone_length(i, 0.06)
	skeleton.add_child(springs)


## A clip's expressions (moves.json `face`), each at its time; a newer clip cancels the older one's.
func _schedule_face(clip: String) -> void:
	if face == null:
		return
	var serial := _serial
	_express("neutral")
	for change: Dictionary in moves.get(clip, {}).get("face", []):
		if float(change.get("weight", 1.0)) < 0.5:
			continue
		var expression: String = change.get("expression", "neutral")
		var timer := get_tree().create_timer(float(change.get("t", 0.0))) if is_inside_tree() else null
		if timer == null:
			continue
		timer.timeout.connect(_express_if.bind(expression, serial))


func _express_if(expression: String, serial: int) -> void:
	if serial == _serial:
		_express(expression)


func _express(expression: String) -> void:
	if face != null and face.has_animation(expression):
		face.play(expression, 0.08)


## Blinks every few seconds while the face is neutral.
func _blink() -> void:
	if face == null or not face.has_animation("blink"):
		return
	var timer := Timer.new()
	timer.wait_time = 3.4
	timer.autostart = true
	timer.timeout.connect(
		func() -> void:
			timer.wait_time = randf_range(2.2, 5.0)
			if face.current_animation in ["", "neutral", "blink"]:
				face.play("blink")
				face.queue("neutral")
	)
	add_child(timer)


func is_loop(clip: String) -> bool:
	return bool(moves.get(clip, {}).get("loop", clip in LOOPS))


func _on_finished(clip: StringName) -> void:
	clip_finished.emit(String(clip))
	player.speed_scale = 1.0
	_charge_until = -1.0
	var ended := String(clip)
	if ended == _cast:
		# The push is reached: held while the circle fires, unless the volley is already over.
		if _letting_go or not player.has_animation(ended + "-hold"):
			_let_go()
		else:
			_play(ended + "-hold")
	elif not ended in HOLDS and not is_loop(ended):
		_play(IDLE)
