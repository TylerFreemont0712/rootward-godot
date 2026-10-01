class_name FoundryBackdrop
extends Control
## A still environment with localized lantern variation. There is no camera zoom or whole-screen pulsing.

const LIGHTS := preload("res://scenes/title/foundry_lights.gdshader")

var hero: HeroView
var _lights: ShaderMaterial
var _clock := 0.0
var _motion := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var painted := TextureRect.new()
	painted.texture = Art.texture("menus/kernel-foundry")
	if painted.texture == null:
		painted.texture = Art.texture("backgrounds/title")
	painted.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painted.stretch_mode = TextureRect.STRETCH_SCALE
	painted.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painted.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lights = ShaderMaterial.new()
	_lights.shader = LIGHTS
	painted.material = _lights
	add_child(painted)
	var shade := TextureRect.new()
	var fade := GradientTexture2D.new()
	fade.gradient = Gradient.new()
	fade.gradient.set_color(0, Color(UiTheme.GROUND, 0.8))
	fade.gradient.set_color(1, Color(UiTheme.GROUND, 0.0))
	fade.gradient.set_offset(1, 0.51)
	fade.width = 256
	fade.height = 4
	shade.texture = fade
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	hero = HeroView.new()
	hero.position = Vector2(1130, 316)
	hero.size = Vector2(208, 236)
	add_child(hero)
	apply_motion()


func apply_motion() -> void:
	_motion = not Settings.reduced_motion
	if _lights != null:
		_lights.set_shader_parameter("movement", 1.0 if _motion else 0.0)
	if hero != null:
		hero.process_mode = Node.PROCESS_MODE_INHERIT if _motion else Node.PROCESS_MODE_DISABLED


func refresh_skin() -> void:
	if hero != null:
		hero.set_skin(Settings.character_skin)
		apply_motion()


func _process(delta: float) -> void:
	if not _motion:
		return
	_clock += delta
	_lights.set_shader_parameter("clock", _clock)
