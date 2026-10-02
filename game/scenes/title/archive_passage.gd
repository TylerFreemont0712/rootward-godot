class_name ArchivePassage
extends ColorRect
## An opaque-at-midpoint sigil veil hides the room swap without moving the catalogue itself.

signal midpoint
signal finished

var _veil: ShaderMaterial
var _motion: Tween


func _init() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_veil = ShaderMaterial.new()
	_veil.shader = preload("res://scenes/title/archive_passage.gdshader")
	material = _veil


func play() -> void:
	_motion = create_tween()
	_motion.tween_method(_advance, 0.0, 0.5, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(midpoint.emit)
	_motion.tween_method(_advance, 0.5, 1.0, 0.58).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(finished.emit)


func _advance(progress: float) -> void:
	_veil.set_shader_parameter("progress", progress)


func _gui_input(_event: InputEvent) -> void:
	accept_event()
