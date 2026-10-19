class_name HotaruSprite
extends Node2D
## Hotaru in the world (ADR-0061): a small fairy who floats a little behind and above the player, bobbing, her wings
## beating, a soft light around her. She drifts toward where she wants to be rather than snapping to it, so she trails
## the walk like something alive. notice(true) raises a small "!" above her head.

## Her picture is drawn at the world's own scale (ADR-0064): 32 x 32 art pixels, one per world pixel.
const FRAME := Vector2i(32, 32)
const BEAT := 0.12
const FOLLOW := 5.0
## Her glow is a fairy's, not a lamp's: a small halo and a faint light, breathing slowly.
const HALO_SIZE := 44
const HALO_STRENGTH := 0.4
const LIGHT_SIZE := 70
## The middle of her body in the frame, below the frame's middle: where the halo and the light sit.
const HEART := Vector2(0, -16)
const BODY_AT := Vector2(0, -20)
const BOB := 5.0
const NOTICE_AT := Vector2(-3, -52)
const LIGHT_ENERGY := 0.35
const PULSE_SPEED := 1.6
const PULSE_DEPTH := 0.1
## Chapter 3: the dimmest she gets when the town dims her (set_brightness 0.0). Full is 1.0.
const DIM_BRIGHTNESS := 0.15
const NOTICE := "res://assets/overworld/hotaru-notice.png"
## The notice when its picture is missing: the mark in sprites/hotaru.sprite (# ink, N, Y and Z the glow colours).
const NOTICE_ROWS: Array[String] = [
	"..###..",
	".#NNY#.",
	".#NNY#.",
	".#NYZ#.",
	".#NYZ#.",
	".#NYZ#.",
	".#NYZ#.",
	".#NYZ#.",
	"..#YZ#.",
	"..###..",
	".......",
	"..###..",
	".#NYZ#.",
	".#YZZ#.",
	"..###..",
]

var target: Node2D
## The way the player faces; she keeps to the side behind them.
var facing := "down"

var _sprite: Sprite2D
var _glow: Sprite2D
var _light: PointLight2D
var _notice: Sprite2D
var _noticed := false
var _time := 0.0
## -1 breathes (the default); 0.0 to 1.0 is the brightness the town gives her (set_brightness).
var _brightness := -1.0


func _ready() -> void:
	_glow = Sprite2D.new()
	_glow.texture = glow_texture(HALO_SIZE, Color("#d6f57a"), HALO_STRENGTH)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.position = HEART
	add_child(_glow)
	_light = PointLight2D.new()
	_light.texture = glow_texture(LIGHT_SIZE, Color.WHITE)
	_light.color = Color("#d6f57a")
	_light.energy = LIGHT_ENERGY
	_light.position = HEART
	add_child(_light)
	_sprite = Sprite2D.new()
	_sprite.texture = OverworldArt.hotaru()
	_sprite.region_enabled = true
	_sprite.position = BODY_AT
	add_child(_sprite)
	_notice = Sprite2D.new()
	_notice.texture = notice_texture()
	_notice.centered = false
	_notice.position = NOTICE_AT
	_notice.visible = _noticed
	add_child(_notice)


## Shows or hides the notice above her head: a small "!" for when she has something to say.
func notice(on: bool) -> void:
	_noticed = on
	if _notice != null:
		_notice.visible = on


## Chapter 3 (Concept/v0.4/05): the town sets how bright her halo and light are, 0.0 (dim) to 1.0 (full). The halo's alpha
## and the light's energy follow it, between DIM_BRIGHTNESS and full, instead of the slow breathing. -1.0 (the default)
## brings the breathing back.
func set_brightness(value: float) -> void:
	_brightness = clampf(value, 0.0, 1.0) if value >= 0.0 else -1.0
	_light_by(_strength())


## How strong her glow is this moment: the breathing pulse, or the brightness the town set.
func _strength() -> float:
	if _brightness < 0.0:
		return 0.9 + PULSE_DEPTH * sin(_time * PULSE_SPEED)
	return lerpf(DIM_BRIGHTNESS, 1.0, _brightness)


## Her halo's alpha and her light's energy, both at `strength` of their normal values.
func _light_by(strength: float) -> void:
	if _glow == null or _light == null:
		return
	_glow.modulate.a = strength
	_light.energy = LIGHT_ENERGY * strength


## The notice mark: its picture from the pixel pipeline, or the same mark drawn here when that picture is missing.
static func notice_texture() -> Texture2D:
	var picture := OverworldArt.texture(NOTICE)
	if picture != null:
		return picture
	var made := Image.create_empty(7, 15, false, Image.FORMAT_RGBA8)
	for y in NOTICE_ROWS.size():
		for x in 7:
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
		"Z":
			return Color("#ffb84a")
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
	# Behind the player and up by their shoulder: the figure stands about two tiles tall.
	var behind := -Vector2(BootsRules.STEPS.get(facing, Vector2i(0, 1))) * OverworldScale.TILE * 0.75
	return target.position + behind + Vector2(0.55, -1.4) * OverworldScale.TILE


func _process(delta: float) -> void:
	_time += delta
	if target != null:
		var want := _home()
		position = position.lerp(want, 1.0 - exp(-FOLLOW * delta))
	var bob := Vector2(0, round(sin(_time * 3.1) * BOB))
	_sprite.position = BODY_AT + bob
	_glow.position = HEART + bob
	_light.position = _glow.position
	_notice.position = NOTICE_AT + bob
	_light_by(_strength())
	if _sprite.texture != null:
		var row := {"down": 0, "up": 1, "left": 2, "right": 2}.get(facing, 0) as int
		var wing := int(_time / BEAT) % 2
		_sprite.region_rect = Rect2(Vector2(wing * FRAME.x, row * FRAME.y), FRAME)
		_sprite.flip_h = facing == "right"
