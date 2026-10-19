class_name StudioLandPanel
extends PanelContainer
## Land's painting tools and ground swatches in the same lower workspace as the Objects catalog.

signal ground_chosen(kind: String)
signal brush_chosen(size: int)
signal land_tool_chosen(tool: String)
signal map_size_pressed

var _grounds: GridContainer
var _ground_buttons: Dictionary = {}
var _brush_buttons: Dictionary = {}
var _land_tool_buttons: Dictionary = {}


func _init() -> void:
	name = "LandPanel"
	custom_minimum_size.y = StudioStyle.PLACE
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(10, 8)))
	var tools := _toolbox()
	tools.custom_minimum_size.x = 370
	var palette := _palette()
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := Ui.hbox([tools, VSeparator.new(), palette], 14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(content)


func _toolbox() -> Control:
	var section := Ui.vbox([], 5)
	section.add_child(StudioStyle.caption(StudioText.t("land_tools")))
	var tool_row := Ui.hbox([], 4)
	for tool: String in StudioLandTool.TOOLS:
		var button := StudioStyle.button(
			StudioText.t("land_tool_" + tool),
			func() -> void: land_tool_chosen.emit(tool),
			false,
			StudioText.t("land_tool_%s_tip" % tool)
		)
		button.name = "Tool_" + tool
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 32
		button.add_theme_font_size_override("font_size", 12)
		_land_tool_buttons[tool] = button
		tool_row.add_child(button)
	section.add_child(tool_row)
	var sizes := Ui.hbox([], 3)
	for size: int in StudioLand.BRUSHES:
		var button := StudioStyle.button(
			str(size),
			func() -> void: brush_chosen.emit(size),
			false,
			StudioText.t("land_brush_tip")
		)
		button.name = "Brush_%d" % size
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_brush_buttons[size] = button
		sizes.add_child(button)
	var brush := Ui.vbox([StudioStyle.caption(StudioText.t("land_brush")), sizes], 3)
	brush.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var resize := StudioStyle.button(
		StudioText.t("land_map_size"),
		func() -> void: map_size_pressed.emit(),
		false,
		StudioText.t("land_map_size_tip")
	)
	resize.name = "MapSize"
	resize.custom_minimum_size.y = 32
	section.add_child(Ui.hbox([brush, resize], 10))
	var variations := StudioStyle.caption(StudioText.t("land_variations"))
	variations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(variations)
	return section


func _palette() -> Control:
	var section := Ui.vbox([], 5)
	var heading := Ui.hbox([StudioStyle.caption(StudioText.t("land_ground")), Ui.spacer()], 5)
	section.add_child(heading)
	_grounds = GridContainer.new()
	_grounds.name = "GroundSwatches"
	_grounds.columns = 7
	_grounds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grounds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grounds.add_theme_constant_override("h_separation", 4)
	_grounds.add_theme_constant_override("v_separation", 4)
	section.add_child(_grounds)
	return section


## The ground types offered by this map and the active brush, size and paint tool.
func show_land(kinds: Array[String], kind: String, size: int, tool: String) -> void:
	if _ground_buttons.keys() != Array(kinds):
		Ui.clear(_grounds)
		_ground_buttons.clear()
		for one: String in kinds:
			var label := "Dirt path" if one == "path" else one.replace("_", " ").capitalize()
			var button := StudioStyle.button(
				label, func() -> void: ground_chosen.emit(one), false, label
			)
			button.name = "Ground_" + one
			button.icon = StudioTools.ground_icon(one)
			button.expand_icon = false
			button.add_theme_constant_override("icon_max_width", 28)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 34
			button.add_theme_font_size_override("font_size", 12)
			_ground_buttons[one] = button
			_grounds.add_child(button)
	for one: String in _ground_buttons:
		StudioStyle.choose(_ground_buttons[one], one == kind)
	for one: int in _brush_buttons:
		StudioStyle.choose(_brush_buttons[one], one == size)
		(_brush_buttons[one] as Button).disabled = tool != "brush"
	for one: String in _land_tool_buttons:
		StudioStyle.choose(_land_tool_buttons[one], one == tool)
