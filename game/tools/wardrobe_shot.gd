extends Control
## The wardrobe panel on its own, for a screenshot:
##   scripts/screenshot.sh res://tools/wardrobe_shot.tscn shots/wardrobe.png


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#171422")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel := SkinSelectionPanel.create()
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.add_child(panel)
	add_child(centre)
