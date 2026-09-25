class_name HeroView
extends Control
## The Maintainer on the stage: a rigged 3D model inside a transparent SubViewport, or a skin drawn as sprite sheets
## (SpriteCharacter, ADR-0008), with Godot spell effects drawn independently over the arena.

const FALLBACK := "brand/wanderer"
const VIEW_SIZE := Vector2i(360, 480)

var character: StageCharacter
var sprite: SpriteCharacter
var _viewport: SubViewport
var _picture: Control
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_SIZE)
	_build_skin()


func set_skin(id: String) -> void:
	if not id in Settings.CHARACTER_SKINS:
		return
	Settings.character_skin = id
	_build_skin()


func _build_skin() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	character = null
	sprite = null
	_viewport = null
	_picture = null
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if SpriteCharacter.exists(Settings.character_skin):
		sprite = SpriteCharacter.create(Settings.character_skin)
		if sprite.has_clips():
			sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(sprite)
			return
		sprite.free()
		sprite = null

	var actor: StageCharacter = StageCharacter.create(Settings.character_skin)
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

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.95
	camera.position = Vector3(0.0, 0.92, 6.0)
	camera.current = true
	_viewport.add_child(camera)
	# Blender's +Y-facing artwork imports facing Godot's -Z. Flip Tamamo to the camera, then cant her toward the foes.
	actor.rotation_degrees.y = 198.0 if Settings.character_skin == "tamamo_no_mae" else 35.0
	_viewport.add_child(actor)


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


## Where projectiles leave from and where shield/hit effects land, in the stage's coordinates.
func hand_point() -> Vector2:
	if sprite != null:
		return position + sprite.hand_point()
	return position + Vector2(size.x * 0.72, size.y * 0.40)


func body_point() -> Vector2:
	return position + Vector2(size.x * 0.5, size.y * 0.55)
