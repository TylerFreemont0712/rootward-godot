class_name ArchivePassage
extends ColorRect
## An opaque-at-midpoint sigil veil hides the room swap without moving the catalogue itself.

signal midpoint
signal finished

var _veil: ShaderMaterial
var _motion: Tween
var _swapped := false


func _init() -> void:
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_veil = ShaderMaterial.new()
	_veil.shader = preload("res://scenes/title/archive_passage.gdshader")
	material = _veil
	resized.connect(_fit_aspect)


## Covers the whole window, whatever its shape: the stretch setting makes the viewport larger than the 1920x1080 design
## size in a window of another shape or scale, and a veil left at 1920x1080 would only reach part of it.
func cover_viewport() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _fit_aspect() -> void:
	if size.y > 0.0:
		_veil.set_shader_parameter("aspect", size.x / size.y)


func play() -> void:
	_swapped = false
	_motion = create_tween()
	_motion.tween_method(_advance, 0.0, 1.0, 1.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_callback(finished.emit)


func _advance(progress: float) -> void:
	_veil.set_shader_parameter("progress", progress)
	if progress >= 0.5 and not _swapped:
		_swapped = true
		midpoint.emit()


func _gui_input(_event: InputEvent) -> void:
	accept_event()
