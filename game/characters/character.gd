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
## Seconds to cross-fade from one clip into the next, and from a finished clip back into the idle (longer: softer).
const BLEND := 0.18
const BLEND_TO_IDLE := 0.3
## Clips that loop; every other clip returns to the idle when it ends (or holds its last pose, see HOLDS).
const LOOPS: Array[String] = ["idle-breathe", "channel"]
const HOLDS: Array[String] = ["death"]
## A cast ends in its push, held: "<cast>-hold" loops it while the circle fires and "<cast>-end" lets go (end_cast).
const CASTS: Array[String] = ["cast-light", "cast-heavy"]
const IDLE := "idle-breathe"
## Limited animation (ADR-0029): a humanoid skin's pose, leg IK and springs advance together this many times a second
## and hold in between, as Guilty Gear and 2XKO animate. Off by default since ADR-0030 (the player found it choppy):
## ROOTWARD_LIMITED=15 (any rate) turns it on, ROOTWARD_LIMITED=style uses a skin's own `style.fps`.
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
## The idle this character returns to after every clip (the player's chosen one, ADR-0037; IDLE by default).
var idle_clip := IDLE
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
## The slowed charge's window in clip time (it starts at x) and its speed.
var _charge_from := -1.0
var _charge_speed := 1.0
var _stature := 0.0


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
		play(idle_clip)


## Wears a different idle, playing it now if the character is idling (an unknown clip keeps IDLE).
func set_idle(clip: String) -> void:
	var was_idle := current == idle_clip or current == ""
	idle_clip = clip if player != null and player.has_animation(clip) else IDLE
	if was_idle and player != null and is_inside_tree():
		play(idle_clip)


## A cast: a clip with a release (the strike the stage times its circle to), other than a cast's hold and letting go.
func is_cast(clip: String) -> bool:
	if clip.ends_with("-hold") or clip.ends_with("-end"):
		return false
	return clip in CASTS or moves.get(clip, {}).get("release") != null


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
	_cast = clip if is_cast(clip) else ""
	_letting_go = false
	_play(clip)


func _play(clip: String, blend := BLEND) -> void:
	_charge_until = -1.0
	_serial += 1
	current = clip
	player.speed_scale = 1.0
	player.play(clip, blend)
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
	# LEARN: wait in the wind-up, never in the strike. Only the clip's charge window (`charge`: [from, to] in clip
	# time, or a time, meaning from the start) is slowed to wait for a long circle; before it and after it the clip
	# plays at its own speed (_process switches), so the gesture and the strike look the same whatever the circle.
	var window := charge_window(facts)
	if window.y > at and seconds > left:
		var from := maxf(window.x, at)
		var stretch := window.y - from
		var own_speed := (from - at) + (float(release) - window.y)
		_charge_speed = clampf(stretch / maxf(seconds - own_speed, 0.01), CHARGE_SLOWEST, 1.0)
		_charge_from = from
		_charge_until = window.y
		player.speed_scale = _charge_speed if at >= from else 1.0
	else:
		player.speed_scale = clampf(left / seconds, RELEASE_SPEED.x, RELEASE_SPEED.y)


## A clip's charge window in clip time ([from, to], or (-1, -1) without one).
static func charge_window(facts: Dictionary) -> Vector2:
	var charge: Variant = facts.get("charge")
	if charge is Array and (charge as Array).size() == 2:
		return Vector2(float(charge[0]), float(charge[1]))
	if charge is float or charge is int:
		return Vector2(0.0, float(charge))
	return Vector2(-1.0, -1.0)


## Seconds until the current clip's release at its current speed (0 when it has none or it has passed).
func release_left() -> float:
	var release: Variant = moves.get(current, {}).get("release")
	if release == null or player == null:
		return 0.0
	return maxf(0.0, float(release) - player.current_animation_position) / maxf(player.speed_scale, 0.01)


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
	_play(
		ending if player.has_animation(ending) else idle_clip, BLEND if player.has_animation(ending) else BLEND_TO_IDLE
	)


## Where the casting palm will be at the current clip's release, in world space; null when the clip has none.
func release_point() -> Variant:
	var facts: Dictionary = moves.get(current, {})
	var point: Array = facts.get("release_point", [])
	if point.size() != 3 or skeleton == null:
		return null
	var hips := skeleton.find_bone("Hips")
	var height := skeleton.get_bone_global_rest(hips).origin.y if hips >= 0 else 1.0
	return model.global_transform * (Vector3(point[0], point[1], point[2]) * height)


## How tall the figure stands as built, in metres: the top of every mesh in its rest pose (hair, ears and hat
## included), measured from its floor. Skins differ (a 1.4 m kid, a 1.75 m fox), and the stage fits each one to the
## same height on screen by it (HeroView), so no skin is drawn bigger only because its model is.
func stature() -> float:
	if _stature > 0.0 or model == null:
		return maxf(_stature, 0.0)
	var top := 0.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.visible:
			continue
		# LEARN: walk the local transforms up to this node rather than read global_transform, so it works before the
		# character is in the tree (a view sizes its camera as it builds) and ignores where the stage put it.
		var to_here := Transform3D.IDENTITY
		var node: Node = mesh
		while node != null and node != self:
			if node is Node3D:
				to_here = (node as Node3D).transform * to_here
			node = node.get_parent()
		top = maxf(top, (to_here * mesh.get_aabb()).end.y)
	_stature = top if top > 0.1 else 1.6
	return _stature


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
	var limited := OS.get_environment("ROOTWARD_LIMITED")
	if limited == "style":
		_limited_fps = float(_style_facts.get("fps", LIMITED_FPS))
	elif limited.is_valid_float():
		_limited_fps = float(limited)
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
	_hand_off_early()
	if _charge_until >= 0.0 and player != null:
		var position := player.current_animation_position
		if position >= _charge_until:
			player.speed_scale = 1.0
			_charge_until = -1.0
		elif position >= _charge_from:
			player.speed_scale = _charge_speed
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


## A clip that ends hands over to what follows it a blend's length *before* its end, so the cross-fade has the clip
## to fade from (_process). This is the fallback for a clip that ends without that.
func _on_finished(clip: StringName) -> void:
	_hand_off(String(clip))


## What follows a clip, and how long it fades into it: a cast's hold (or its letting go), the idle, or nothing (a
## loop, or a pose that is held, as death is).
func _after(clip: String) -> Array:
	if clip == _cast:
		# The push is reached: held while the circle fires, unless the volley is already over.
		if _letting_go or not player.has_animation(clip + "-hold"):
			var ending := clip + "-end"
			return [ending, BLEND] if player.has_animation(ending) else [idle_clip, BLEND_TO_IDLE]
		return [clip + "-hold", BLEND]
	if clip in HOLDS or is_loop(clip):
		return []
	return [idle_clip, BLEND_TO_IDLE]


func _hand_off(clip: String) -> void:
	var next := _after(clip)
	clip_finished.emit(clip)
	player.speed_scale = 1.0
	_charge_until = -1.0
	if next.is_empty():
		return
	if clip == _cast and String(next[0]) != clip + "-hold":
		_cast = ""
		_letting_go = false
	_play(String(next[0]), float(next[1]))


# LEARN: the mixer is deterministic (Godot's default): a cross-fade blends the new clip over what the old one still
# contributes, and a clip that has *finished* contributes nothing, so a fade started from animation_finished rose out
# of the rest pose (a T-pose arm flashed up). Starting the fade while the old clip still plays its last moments
# blends from where it really is.
func _hand_off_early() -> void:
	if player == null or current == "" or not player.is_playing() or player.current_animation != current:
		return
	var next := _after(current)
	if next.is_empty():
		return
	var left := (player.current_animation_length - player.current_animation_position) / maxf(player.speed_scale, 0.01)
	if left <= float(next[1]):
		_hand_off(current)
