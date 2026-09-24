extends Control
## The first scene: for now it only says the game is alive. Phase 4 replaces it with the title screen.


func _ready() -> void:
	var label := Label.new()
	label.text = "Rootward"
	label.add_theme_font_size_override("font_size", 64)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
