class_name DungeonBackdrop
extends TextureRect
## A painted Machine room with localized light, drifting dust, steam and coolant. BattleStage can drive its clock
## so a paused rehearsal pauses the scenery too. Motion never changes the camera or the character floor.

const LIGHTS := preload("res://ui/dungeon_lights.gdshader")
const LAMPS := {
	3:
	[
		Vector4(0.257, 0.22, 0.024, 0.07),
		Vector4(0.54, 0.14, 0.025, 0.07),
		Vector4(0.63, 0.44, 0.024, 0.07),
		Vector4(0.83, 0.55, 0.028, 0.07)
	],
	2:
	[
		Vector4(0.18, 0.25, 0.024, 0.06),
		Vector4(0.49, 0.10, 0.024, 0.06),
		Vector4(0.89, 0.48, 0.024, 0.06),
		Vector4(0.69, 0.48, 0.018, 0.05)
	],
	1:
	[
		Vector4(0.185, 0.34, 0.025, 0.07),
		Vector4(0.31, 0.49, 0.02, 0.06),
		Vector4(0.92, 0.39, 0.025, 0.07),
		Vector4(0.72, 0.31, 0.02, 0.06)
	],
	0:
	[
		Vector4(0.13, 0.46, 0.025, 0.06),
		Vector4(0.395, 0.44, 0.02, 0.05),
		Vector4(0.606, 0.44, 0.02, 0.05),
		Vector4(0.87, 0.39, 0.025, 0.06)
	],
}
const SHAFT_LAMPS := [
	Vector4(0.252, 0.145, 0.025, 0.035),
	Vector4(0.169, 0.283, 0.025, 0.035),
	Vector4(0.62, 0.164, 0.018, 0.035),
	Vector4(0.895, 0.367, 0.02, 0.035),
]

var automatic := true
var ring := -1
var elapsed := 0.0
var _lights: ShaderMaterial


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_scene(art_id: String, scene_ring := -1, shaft := false) -> void:
	texture = Art.texture(art_id)
	ring = scene_ring
	if ring < 0:
		for number: int in LAMPS:
			if art_id.contains("arena-ring-%d-" % number):
				ring = number
				break
	if not LAMPS.has(ring):
		material = null
		_lights = null
		return
	_lights = ShaderMaterial.new()
	_lights.shader = LIGHTS
	_lights.set_shader_parameter("ring", ring)
	_lights.set_shader_parameter("shaft", shaft)
	var lamps: Array = SHAFT_LAMPS if shaft else LAMPS[ring]
	for index in lamps.size():
		_lights.set_shader_parameter("lamp_%d" % index, lamps[index])
	material = _lights
	elapsed = 0.0
	advance(0.0)


func _process(delta: float) -> void:
	if automatic:
		advance(delta)


func advance(seconds: float) -> void:
	if _lights == null:
		return
	var moving := not Settings.reduced_motion
	if moving:
		elapsed += seconds
	_lights.set_shader_parameter("movement", 1.0 if moving else 0.0)
	_lights.set_shader_parameter("clock", elapsed)
