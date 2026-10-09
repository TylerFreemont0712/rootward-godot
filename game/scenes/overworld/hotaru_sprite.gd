class_name HotaruSprite
extends Node2D
## Hotaru in the world (ADR-0061): a firefly who floats a little behind and above the player, bobbing, her wings
## beating, her tail glowing. She drifts toward where she wants to be rather than snapping to it, so she trails the
## walk like something alive.

const FRAME := Vector2i(16, 16)
const BEAT := 0.12
const FOLLOW := 5.0

var target: Node2D
## The way the player faces; she keeps to the side behind them.
var facing := "down"

var _sprite: Sprite2D
var _glow: Sprite2D
var _light: PointLight2D
var _time := 0.0


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = glow_texture(24, Color("#d6f57a"))
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.position = Vector2(0, -4)
	add_child(_glow)
	_light = PointLight2D.new()
	_light.texture = glow_texture(64, Color.WHITE)
	_light.color = Color("#d6f57a")
	_light.energy = 0.9
	_light.position = Vector2(0, -4)
	add_child(_light)
	_sprite = Sprite2D.new()
	_sprite.texture = OverworldArt.hotaru()
	_sprite.region_enabled = true
	_sprite.position = Vector2(0, -8)
	add_child(_sprite)


## A soft round light: a radial gradient that fades to nothing at its edge.
static func glow_texture(size: int, colour: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(colour, 0.55))
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
	var pulse := 0.75 + 0.25 * sin(_time * 2.2)
	_glow.modulate.a = pulse
	_light.energy = 0.7 + 0.3 * pulse
	if _sprite.texture != null:
		var row := {"down": 0, "up": 1, "left": 2, "right": 2}.get(facing, 0) as int
		var wing := int(_time / BEAT) % 2
		_sprite.region_rect = Rect2(Vector2(wing * FRAME.x, row * FRAME.y), FRAME)
		_sprite.flip_h = facing == "right"
