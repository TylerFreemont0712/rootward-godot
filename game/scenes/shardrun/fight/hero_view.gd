class_name HeroView
extends Control
## The Maintainer on the stage: the 3D character (StageCharacter) rendered into its own small viewport with a clear
## background, so it stands in front of the painted arena like a sprite. Without a model, a 2D picture stands in, so
## a missing character never breaks the fight.
##
## LEARN: a SubViewport with `own_world_3d` is a separate little 3D world with its own camera; the container shows what
## it renders as a texture in the 2D interface. The fight stays a 2D screen with one 3D actor in it.

const CHARACTER := "emberfox"
const FALLBACK := "brand/wanderer"
const VIEW_SIZE := Vector2i(360, 480)

var character: StageCharacter
var _viewport: SubViewport
var _picture: Control
var _flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW_SIZE)
	var fox := StageCharacter.create(CHARACTER)
	if not fox.has_model():
		fox.free()
		_picture = Ui.picture(FALLBACK, Vector2(192, 288), "@")
		_picture.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		add_child(_picture)
		return
	character = fox
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
	camera.size = 2.2
	camera.position = Vector3(0.0, 0.92, 6.0)
	_viewport.add_child(camera)
	# Three-quarter view, turned toward the foes on the right.
	fox.rotation_degrees.y = 35.0
	_viewport.add_child(fox)


## Plays a clip (cast-light, cast-heavy, guard, hurt, victory, death...), then back to the idle on its own.
func play(clip: String) -> void:
	if character != null:
		character.play(clip)
	elif _picture != null and clip in ["hurt", "death"]:
		var tween := create_tween()
		tween.tween_property(_picture, "position:x", _picture.position.x - 10, 0.06)
		tween.tween_property(_picture, "position:x", _picture.position.x, 0.12)


## A flash over the whole figure: a cast's colour, or red when hit.
func flash(colour: Color, seconds := 0.25) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	if character != null:
		character.set_flash(colour)
		_flash_tween = create_tween()
		_flash_tween.tween_method(
			func(alpha: float) -> void: character.set_flash(Color(colour, alpha)), colour.a, 0.0, seconds
		)
	elif _picture != null:
		_picture.modulate = Color(1, 1, 1).lerp(colour, 0.6)
		_flash_tween = create_tween()
		_flash_tween.tween_property(_picture, "modulate", Color.WHITE, seconds)


## Where bolts leave from and blows land, in this control's parent's coordinates.
func hand_point() -> Vector2:
	return position + Vector2(size.x * 0.62, size.y * 0.45)


func body_point() -> Vector2:
	return position + Vector2(size.x * 0.5, size.y * 0.55)
