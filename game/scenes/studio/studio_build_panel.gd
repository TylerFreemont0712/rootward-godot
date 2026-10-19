class_name StudioBuildPanel
extends PanelContainer
## B01's thin construction wrapper: the shared catalog owns cards, search, previews and browsing state.

signal group_chosen(group: String)
signal paint_floor_requested

var catalog: StudioPlacePanel
var group := "building"
var _groups: Dictionary = {}
var _paint_floor: Button
var _interior := false


func _init() -> void:
	name = "BuildPanel"
	custom_minimum_size.y = StudioStyle.PLACE
	var column := Ui.vbox([], 3)
	add_child(column)
	var strip := Ui.hbox([], 4)
	strip.name = "BuildGroups"
	for id: String in StudioBuildCatalog.GROUPS:
		var button := StudioStyle.button(StudioText.t("build_group_" + id), func() -> void: choose_group(id), id == group)
		button.name = "BuildGroup_" + id
		button.custom_minimum_size.y = 22
		button.add_theme_font_size_override("font_size", StudioPlacePanel.FONT)
		_groups[id] = button
		strip.add_child(button)
	strip.add_child(Ui.spacer())
	_paint_floor = StudioStyle.button(StudioText.t("build_paint_floor"), func() -> void: paint_floor_requested.emit())
	_paint_floor.name = "PaintFloor"
	_paint_floor.custom_minimum_size.y = 22
	_paint_floor.add_theme_font_size_override("font_size", StudioPlacePanel.FONT)
	strip.add_child(_paint_floor)
	column.add_child(strip)
	catalog = StudioPlacePanel.new({"build_groups": [group]}, true)
	catalog.name = "BuildCatalog"
	catalog.custom_minimum_size.y = 0
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(catalog)
	_show_context()


func choose_group(id: String) -> void:
	if not StudioBuildCatalog.GROUPS.has(id):
		return
	group_chosen.emit(id)
	group = id
	catalog.set_scope({"build_groups": [group]})
	for key: String in _groups:
		StudioStyle.choose(_groups[key], key == group)
	_show_context()


func show_map(interior: bool) -> void:
	_interior = interior
	_show_context()


func _show_context() -> void:
	_paint_floor.visible = group == "furniture"
	_paint_floor.disabled = not _interior
	_paint_floor.tooltip_text = StudioText.t("build_floor_tip" if _interior else "build_floor_interior")
