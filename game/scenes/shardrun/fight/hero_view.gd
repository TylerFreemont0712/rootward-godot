class_name HeroView
extends Control
## The Maintainer on the stage: a rigged 3D model inside a transparent SubViewport, or a skin drawn as sprite sheets
## (SpriteCharacter, ADR-0008), with Godot spell effects drawn independently over the arena.

const FALLBACK := "brand/wanderer"
const VIEW_SIZE := Vector2i(360, 480)
## The orthographic camera's height and aim. A VRM skin levitates and throws her arms overhead, so she is framed with
## more air above her than Emberfox is.
const FRAME_GLB := Vector2(1.95, 0.92)
## A humanoid skin (VRM or anime) stands with her feet on the view's floor and room above for a jump and raised arms;
## her view is also taller on the stage (`height_share`), so she is drawn half again as large as before.
const FRAME_VRM := Vector2(2.4, 1.17)
const TALL_SHARE := 0.92
const SHORT_SHARE := 0.6
## Where the key light comes from (toward the light, world space): front-left and above, as from the arena's lanterns.
## The anime shaders take it as a direction; MToon gets a real light along it.
const KEY_LIGHT := Vector3(0.45, 0.62, 0.64)

## A rehearsal skin can be browsed without changing the equipped appearance.
var preview_skin := ""
var character: StageCharacter
var sprite: SpriteCharacter
var _viewport: SubViewport
var _camera: Camera3D
var _picture: Control
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No minimum: the stage sizes the Maintainer to its own height (a bigger minimum pushed her feet through the floor).
	_build_skin()


func set_skin(id: String) -> void:
	if not id in Settings.all_skins():
		return
	Settings.character_skin = id
	_build_skin()


func set_preview_skin(id: String) -> void:
	if id not in Settings.all_skins():
		return
	preview_skin = id
	if is_inside_tree():
		_build_skin()


func _build_skin() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	character = null
	sprite = null
	_viewport = null
	_camera = null
	_picture = null
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var skin := preview_skin if preview_skin != "" else Settings.character_skin
	if SpriteCharacter.exists(skin):
		sprite = SpriteCharacter.create(skin)
		if sprite.has_clips():
			sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(sprite)
			return
		sprite.free()
		sprite = null

	var actor: StageCharacter = StageCharacter.create(skin)
	if not actor.has_model():
		actor.free()
		_picture = Ui.picture(FALLBACK, Vector2(192, 288), "@")
		_picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		add_child(_picture)
		return

	character = actor
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.size = VIEW_SIZE
	container.add_child(_viewport)
	add_child(container)

	if actor.is_vrm():
		_light(_viewport)
	actor.set_light_direction(KEY_LIGHT)
	var frame := FRAME_VRM if actor.is_humanoid() else FRAME_GLB
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = frame.x
	_camera.position = Vector3(0.0, frame.y, 6.0)
	_camera.current = true
	_viewport.add_child(_camera)
	# Cant the model toward the foes.
	actor.rotation_degrees.y = 35.0
	_viewport.add_child(actor)


## LEARN: the viewport has a world of its own (`own_world_3d`), so the arena's light never reaches it. Emberfox's
## toon shader carries its own light; MToon is lit like any material, and with no light a VRM skin is a silhouette.
## A warm key from the front-left, as from the arena's lanterns, and a soft ambient for the shade side.
func _light(viewport: SubViewport) -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.62, 0.56, 0.6)
	environment.environment.ambient_light_energy = 0.9
	viewport.add_child(environment)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.1
	viewport.add_child(key)
	key.basis = Basis.looking_at(-KEY_LIGHT)


## Plays a rigged clip. Spell sigils, shields, projectiles, and impact art remain on the separate BattleFX layer.
func play(clip: String) -> void:
	if sprite != null:
		sprite.play(clip)
		if clip in ["hurt", "death"]:
			_recoil(sprite)
	elif character != null:
		character.play(clip)
	elif _picture != null and clip in ["hurt", "death"]:
		_recoil(_picture)


## A skin with no hurt clip of its own is knocked back a step and returns.
func _recoil(node: Control) -> void:
	var tween := create_tween()
	tween.tween_property(node, "position:x", node.position.x - 10.0, 0.06)
	tween.tween_property(node, "position:x", node.position.x, 0.12)


## A colour flash over the whole figure, for a cast or a hit.
func flash(colour: Color, seconds := 0.25) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	if sprite != null:
		sprite.set_flash(colour)
		_flash_tween = create_tween()
		_flash_tween.tween_method(
			func(alpha: float) -> void: sprite.set_flash(Color(colour, alpha)), colour.a, 0.0, seconds
		)
	elif character != null:
		character.set_flash(colour)
		_flash_tween = create_tween()
		_flash_tween.tween_method(
			func(alpha: float) -> void: character.set_flash(Color(colour, alpha)), colour.a, 0.0, seconds
		)
	elif _picture != null:
		_picture.modulate = Color(1, 1, 1).lerp(colour, 0.6)
		_flash_tween = create_tween()
		_flash_tween.tween_property(_picture, "modulate", Color.WHITE, seconds)


## Times the current cast so its release lands `seconds` from now (a 3D skin; a sprite skin times itself).
func release_in(seconds: float) -> void:
	if character != null:
		character.release_in(seconds)


## Seconds until the current cast's release (the strike, or the snap), 0 for a skin that does not time its casts.
func release_left() -> float:
	return character.release_left() if character != null else 0.0


## The volley is over: a 3D skin lets go of its held cast (a sprite skin's cast already ended on its own).
func end_cast() -> void:
	if character != null:
		character.end_cast()


## Where projectiles leave from and where shield/hit effects land, in the stage's coordinates. A VRM skin answers
## with where her palm will be at the cast's release (so the sigil is drawn where she strikes), else her hand now.
func hand_point() -> Vector2:
	if sprite != null:
		return position + sprite.hand_point()
	if character != null and _camera != null:
		var point: Variant = character.release_point()
		if point == null:
			point = character.bone_point("LeftHand")
		if point != null:
			return position + _to_stage(point as Vector3)
	return position + Vector2(size.x * 0.72, size.y * 0.40)


## Where the cast's magic circle stands: just beyond her palm at the strike, toward the foes (a circle of `size`
## pixels in radius stands a little in front of her hand, not on it).
func circle_point(size: float) -> Vector2:
	return hand_point() + Vector2(size * 0.42 + self.size.y * 0.05, self.size.y * 0.005)


## A point in the character's world, in this view's own coordinates.
func _to_stage(world: Vector3) -> Vector2:
	var pixel := _camera.unproject_position(world)
	return pixel * size / Vector2(_viewport.size)


func body_point() -> Vector2:
	if character != null and _camera != null:
		var chest: Variant = character.bone_point("Chest")
		if chest != null:
			return position + _to_stage(chest as Vector3)
	return position + Vector2(size.x * 0.5, size.y * 0.55)


## Just above the top of the head, in the stage's coordinates (for the Maintainer's plate).
func head_point() -> Vector2:
	if character != null and _camera != null:
		var head: Variant = character.bone_point("Head")
		if head != null:
			return position + _to_stage((head as Vector3) + Vector3(0.0, 0.28, 0.0))
	return position


## How much of the arena's height this view takes: a humanoid skin is drawn larger than the older looks.
func height_share() -> float:
	return TALL_SHARE if character != null and character.is_humanoid() else SHORT_SHARE
