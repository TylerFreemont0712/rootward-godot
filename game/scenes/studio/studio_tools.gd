class_name StudioTools
extends PanelContainer
## The left tools column (Concept/v0.3/10, section 6): Objects selection tools, the overlay switches of section 7.6,
## a switch for the catalog and the history list. Land painting tools and ground swatches share the lower workspace.

## An overlay was switched: its name in StudioOverlay.options, and whether it is on.
signal option_changed(option: String, on: bool)
## The switch for the list of pictures to place.
signal place_list_toggled(on: bool)
signal select_pressed
signal area_select_pressed
signal area_filter_chosen(filter: String)
## Run remakes was pressed (the queued remakes drawn by the world pipeline).
signal run_remakes_pressed
signal asset_updates_pressed

const OVERLAYS: Array[String] = ["grid", "footprints", "solid", "doors", "talk", "labels", "player"]

var history := StudioHistoryList.new()
var _switches: Dictionary = {}
var _place_switch: Button
var _place_on := true
var _remake_button: Button
var _remake_line: Label
var _updates_button: Button
var _on: Dictionary = {}
## The Objects tab's own tools.
var _objects_part: Control
var _select_button: Button
var _area_button: Button
var _area_options: Control
var _area_filter: OptionButton
var _active_tab := "objects"
var _area_active := false
var _remake_count := 0
var _remakes_running := false


func _init(options: Dictionary) -> void:
	name = "Tools"
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(8, 8)))
	custom_minimum_size.x = StudioStyle.LEFT
	var column := Ui.vbox([], 4)
	add_child(column)
	column.add_child(StudioStyle.caption(StudioText.t("tools")))
	_objects_part = Ui.vbox([], 4)
	_objects_part.name = "ObjectsTools"
	_select_button = StudioStyle.button(StudioText.t("tool_select"), func() -> void: select_pressed.emit(), true, StudioText.t("tool_select_tip"))
	_select_button.name = "SelectObjects"
	_objects_part.add_child(_select_button)
	_area_button = StudioStyle.button(StudioText.t("tool_area_select"), func() -> void: area_select_pressed.emit(), false, StudioText.t("tool_area_select_tip"))
	_area_button.name = "SelectArea"
	_objects_part.add_child(_area_button)
	_area_options = Ui.vbox([], 3)
	_area_options.add_child(StudioStyle.caption(StudioText.t("area_filter")))
	_area_filter = OptionButton.new()
	_area_filter.name = "AreaFilter"
	_area_filter.focus_mode = Control.FOCUS_NONE
	_area_filter.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	for filter: String in ["all", "props", "trees"]:
		_area_filter.add_item(StudioText.t("area_filter_" + filter))
		_area_filter.set_item_metadata(_area_filter.item_count - 1, filter)
	_area_filter.item_selected.connect(func(index: int) -> void: area_filter_chosen.emit(String(_area_filter.get_item_metadata(index))))
	_area_options.add_child(_area_filter)
	var help := StudioStyle.caption(StudioText.t("area_help"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_area_options.add_child(help)
	_area_options.visible = false
	_objects_part.add_child(_area_options)
	column.add_child(_objects_part)
	column.add_child(Ui.spacer(0, 6))
	column.add_child(StudioStyle.caption(StudioText.t("overlays")))
	for option: String in OVERLAYS:
		var button := StudioStyle.button(StudioText.t("overlay_" + option), Callable())
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_toggled.bind(option))
		_switches[option] = button
		_on[option] = bool(options.get(option, false))
		StudioStyle.choose(button, _on[option])
		column.add_child(button)
	column.add_child(Ui.spacer(0, 6))
	_place_switch = StudioStyle.button(StudioText.t("tool_place"), _toggle_place, true, StudioText.t("tool_place_tip"))
	_place_switch.alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_place_switch)
	_updates_button = StudioStyle.button(StudioText.t("review_button") % 0, func() -> void: asset_updates_pressed.emit())
	_updates_button.name = "AssetUpdates"
	_updates_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_updates_button)
	_remake_button = StudioStyle.button(StudioText.t("remake_run") % 0, func() -> void: run_remakes_pressed.emit(), false, StudioText.t("remake_run_tip"))
	_remake_button.name = "RunRemakes"
	_remake_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_remake_button.visible = false
	column.add_child(_remake_button)
	_remake_line = StudioStyle.caption("")
	_remake_line.name = "RemakeLine"
	_remake_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_remake_line.max_lines_visible = 3
	_remake_line.visible = false
	column.add_child(_remake_line)
	column.add_child(Ui.spacer(0, 6))
	column.add_child(history)


## Shows the tools declared by the selected workspace descriptor.
func show_tab(tab: String) -> void:
	_active_tab = tab
	var descriptor: Dictionary = StudioTopBar.DESCRIPTORS.get(tab, {})
	var allowed: Array = descriptor.get("tools", [])
	_objects_part.visible = allowed.has("select")
	_area_button.visible = allowed.has("area")
	_area_options.visible = allowed.has("area") and _area_active
	_place_switch.visible = allowed.has("catalog")
	_updates_button.visible = tab == "objects"
	_remake_button.visible = tab == "objects" and (_remake_count > 0 or _remakes_running)
	_remake_line.visible = tab == "objects" and _remakes_running and _remake_line.text != ""


func show_object_tool(area: bool, filter: String) -> void:
	_area_active = area
	StudioStyle.choose(_select_button, not area)
	StudioStyle.choose(_area_button, area)
	_area_options.visible = area and _active_tab == "objects"
	for index: int in _area_filter.item_count:
		if String(_area_filter.get_item_metadata(index)) == filter:
			_area_filter.select(index)

## A ground's picture from the terrain atlas: its own base tile, or for one drawn only on top (flowers) its full tile.
static func ground_icon(kind: String) -> Texture2D:
	var art := OverworldArt.terrain()
	var atlas := art.texture as Texture2D
	var layout: Dictionary = art.layout
	if atlas == null or layout.is_empty():
		return null
	var tile := int(layout.get("tile", OverworldScale.TILE))
	var region := Rect2()
	var base: Dictionary = layout.get("base", {})
	var overlay: Dictionary = layout.get("overlay", {})
	if base.has(kind):
		region = Rect2(0, int(base[kind].row) * tile, tile, tile)
	elif overlay.has(kind):
		region = Rect2(15 * tile, int(overlay[kind].row) * tile, tile, tile)
	else:
		return null
	var icon := AtlasTexture.new()
	icon.atlas = atlas
	icon.region = region
	return icon


func _toggled(option: String) -> void:
	show_option(option, not _on[option])
	option_changed.emit(option, _on[option])


## Shows the switch as on or off without telling anyone.
func show_option(option: String, on: bool) -> void:
	_on[option] = on
	StudioStyle.choose(_switches[option], on)


func _toggle_place() -> void:
	show_place_list(not _place_on)
	place_list_toggled.emit(_place_on)


## Shows the pictures-list switch as on or off without telling anyone.
func show_place_list(on: bool) -> void:
	_place_on = on
	StudioStyle.choose(_place_switch, on)



## The remakes waiting and whether a run is going: Run remakes (n), or the run's last line while it works.
func show_remakes(count: int, running: bool, line: String) -> void:
	_remake_count = count
	_remakes_running = running
	_remake_button.visible = _active_tab == "objects" and (count > 0 or running)
	_remake_button.disabled = running or count == 0
	_remake_button.text = StudioText.t("remake_running") if running else StudioText.t("remake_run") % count
	_remake_line.text = line
	_remake_line.visible = _active_tab == "objects" and running and line != ""


func show_updates(count: int) -> void:
	_updates_button.text = StudioText.t("review_button") % count
