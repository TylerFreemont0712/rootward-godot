class_name HotaruSprite
extends Node2D
## Hotaru in the world (ADR-0061): a firefly who floats a little behind and above the player, bobbing, her wings
## beating, her tail glowing softly. She drifts toward where she wants to be rather than snapping to it, so she trails
## the walk like something alive. notice(true) raises a small "!" above her head.

const FRAME := Vector2i(16, 16)
const BEAT := 0.12
const FOLLOW := 5.0
## Her glow is a firefly's, not a lamp's: a small halo and a faint light, breathing slowly.
const HALO_SIZE := 16
const HALO_STRENGTH := 0.4
const LIGHT_SIZE := 28
const LIGHT_ENERGY := 0.35
const PULSE_SPEED := 1.6
const PULSE_DEPTH := 0.1
const NOTICE := "res://assets/overworld/hotaru-notice.png"
## The notice when its picture is missing: the mark in sprites/hotaru.sprite (# ink, N and Y the glow colours).
const NOTICE_ROWS: Array[String] = ["..#..", ".#N#.", ".#N#.", ".#Y#.", "..#..", ".#N#.", "..#.."]

var target: Node2D
## The way the player faces; she keeps to the side behind them.
var facing := "down"

var _sprite: Sprite2D
var _glow: Sprite2D
var _light: PointLight2D
var _notice: Sprite2D
var _noticed := false
var _time := 0.0


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = glow_texture(HALO_SIZE, Color("#d6f57a"), HALO_STRENGTH)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.position = Vector2(0, -4)
	add_child(_glow)
	_light = PointLight2D.new()
	_light.texture = glow_texture(LIGHT_SIZE, Color.WHITE)
	_light.color = Color("#d6f57a")
	_light.energy = LIGHT_ENERGY
	_light.position = Vector2(0, -4)
	add_child(_light)
	_sprite = Sprite2D.new()
	_sprite.texture = OverworldArt.hotaru()
	_sprite.region_enabled = true
	_sprite.position = Vector2(0, -8)
	add_child(_sprite)
	_notice = Sprite2D.new()
	_notice.texture = notice_texture()
	_notice.centered = false
	_notice.position = Vector2(-2, -24)
	_notice.visible = _noticed
	add_child(_notice)


## Shows or hides the notice above her head: a small "!" for when she has something to say.
func notice(on: bool) -> void:
	_noticed = on
	if _notice != null:
		_notice.visible = on


## The notice mark: its picture from the pixel pipeline, or the same mark drawn here when that picture is missing.
static func notice_texture() -> Texture2D:
	var picture := OverworldArt.texture(NOTICE)
	if picture != null:
		return picture
	var made := Image.create_empty(5, 7, false, Image.FORMAT_RGBA8)
	for y in NOTICE_ROWS.size():
		for x in 5:
			var colour := _notice_colour(NOTICE_ROWS[y][x])
			if colour.a > 0.0:
				made.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(made)


static func _notice_colour(code: String) -> Color:
	match code:
		"#":
			return Color("#2a1d2b")
		"N":
			return Color("#fffbd0")
		"Y":
			return Color("#ffe27a")
	return Color(0, 0, 0, 0)


## A soft round light: a radial gradient that fades to nothing at its edge.
static func glow_texture(size: int, colour: Color, strength := 0.55) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(colour, strength))
	gradient.set_color(1, Color(colour, 0.0))
	var made := GradientTexture2D.new()
	made.gradient = gradient
	made.fill = GradientTexture2D.FILL_RADIAL
	made.fill_from = Vector2(0.5, 0.5)
	made.fill_to = Vector2(1.0, 0.5)
	made.width = size
	made.height = size
	return made


func settle() -> void:
	if target != null:
		position = _home()


func _home() -> Vector2:
	var behind := -Vector2(BootsRules.STEPS.get(facing, Vector2i(0, 1))) * 12.0
	return target.position + behind + Vector2(9, -18)


func _process(delta: float) -> void:
	_time += delta
	if target != null:
		var want := _home()
		position = position.lerp(want, 1.0 - exp(-FOLLOW * delta))
	var bob := sin(_time * 3.1) * 2.0
	_sprite.position = Vector2(0, -8 + round(bob))
	_glow.position = Vector2(0, -4 + round(bob))
	_light.position = _glow.position
	_notice.position = Vector2(-2, -24 + round(bob))
	var pulse := 0.9 + PULSE_DEPTH * sin(_time * PULSE_SPEED)
	_glow.modulate.a = pulse
	_light.energy = LIGHT_ENERGY * pulse
	if _sprite.texture != null:
		var row := {"down": 0, "up": 1, "left": 2, "right": 2}.get(facing, 0) as int
		var wing := int(_time / BEAT) % 2
		_sprite.region_rect = Rect2(Vector2(wing * FRAME.x, row * FRAME.y), FRAME)
		_sprite.flip_h = facing == "right"
