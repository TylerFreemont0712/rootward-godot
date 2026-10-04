class_name ScriptBelt
extends HBoxContainer
## The belt of scripts (ProgramScripts) in a fight's side panel: a slot for each place on the belt, and a script's
## picture in the slot it fills. Clicking a script uses it; hovering says what it does.

signal use_pressed(index: int)

const SLOT := Vector2(56, 56)


func show_belt(state: Dictionary, catalog: Dictionary) -> void:
	Ui.clear(self)
	var belt: Array = state.get("belt", [])
	var places := ProgramScripts.belt_size(state, catalog)
	add_theme_constant_override("separation", 6)
	alignment = BoxContainer.ALIGNMENT_CENTER
	for index in maxi(places, belt.size()):
		add_child(_slot(index, belt[index] if index < belt.size() else "", catalog))


func _slot(index: int, id: String, catalog: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = SLOT
	var script: Dictionary = (catalog.programs.scripts as Dictionary).get(id, {})
	var ring := UiTheme.rarity(String(script.get("rarity", "common"))) if not script.is_empty() else UiTheme.FAINT
	frame.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(ring, 0.12), Color(ring, 0.8 if not script.is_empty() else 0.3), 1, 8, Vector2(3, 3))
	)
	if script.is_empty():
		return frame
	var button := Button.new()
	button.flat = true
	button.custom_minimum_size = SLOT - Vector2(8, 8)
	var art := Art.texture("shardrun/script-" + id)
	if art != null:
		button.icon = art
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.text = String(script.name).left(5)
	button.pressed.connect(func() -> void: use_pressed.emit(index))
	frame.add_child(button)
	var needs := Text.t("Aim it at a foe.") if script.target == "foe" else ""
	HoverInfo.attach(frame, Text.t(script.name), Text.t(script.summary), needs, ring)
	return frame
