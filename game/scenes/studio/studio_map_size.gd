class_name StudioMapSize
extends ConfirmationDialog
## Map size (Concept/v0.3/10, section 7.8): how many rows and columns to add (or, below zero, take away) at each of the
## four edges, and the ground the new cells get. Before it is confirmed it says the new size, the things that would
## fall off, and how many doors of other maps lead here (they move with the map). StudioWork.resize does it.

var _studio: StudioMode
var _edges: Dictionary = {}
var _fill: OptionButton
var _summary: Label
var _kinds: Array[String] = []
var _planning := false


func _init(studio: StudioMode) -> void:
	_studio = studio
	name = "MapSize"
	title = StudioText.t("map_size_title")
	ok_button_text = StudioText.t("map_size_ok")
	var grid := GridContainer.new()
	grid.columns = 4
	for edge: String in ["top", "bottom", "left", "right"]:
		grid.add_child(StudioStyle.line(StudioText.t("map_size_" + edge)))
		var spin := SpinBox.new()
		spin.name = "Edge_" + edge
		spin.step = 1
		spin.allow_greater = false
		spin.allow_lesser = false
		spin.custom_minimum_size.x = 96
		spin.value_changed.connect(func(_value: float) -> void: _plan())
		_edges[edge] = spin
		grid.add_child(spin)
	_fill = OptionButton.new()
	_fill.name = "Fill"
	_fill.item_selected.connect(func(_index: int) -> void: _plan())
	_summary = StudioStyle.line("")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(440, 0)
	var help := StudioStyle.caption(StudioText.t("map_size_help"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fill_row := Ui.hbox([StudioStyle.line(StudioText.t("map_size_fill")), _fill], 8)
	add_child(Ui.vbox([help, grid, fill_row, _summary], 10))
	confirmed.connect(_confirm)


## Opens for the map shown, every edge at 0 and the new cells in the map's first ground.
func open() -> void:
	var size := OverworldMap.size_of(_studio.current_map())
	for edge: String in _edges:
		var spin := _edges[edge] as SpinBox
		spin.set_value_no_signal(0)
	_kinds = _studio.land.grounds()
	_fill.clear()
	for kind: String in _kinds:
		_fill.add_item(kind.capitalize())
	_fill.select(0)
	_plan()
	popup_centered()


## The edges asked for: {top, bottom, left, right}.
func edges() -> Dictionary:
	var out := {}
	for edge: String in _edges:
		out[edge] = int((_edges[edge] as SpinBox).value)
	return out


## Sets an edge, as typing in its box would (for tests).
func set_edge(edge: String, value: int) -> void:
	(_edges[edge] as SpinBox).value = value


func fill_kind() -> String:
	return _kinds[maxi(0, _fill.selected)] if not _kinds.is_empty() else "grass"


## The words under the boxes now (for tests).
func summary() -> String:
	return _summary.text


func _plan() -> void:
	if _planning:
		return
	_planning = true
	_set_edge_limits()
	var plan := _studio.work.resize_plan(edges(), fill_kind())
	if not bool(plan.get("ok", false)):
		_summary.text = String(plan.get("error", ""))
		get_ok_button().disabled = true
		_planning = false
		return
	var size: Vector2i = plan.size
	var lines: Array[String] = [StudioText.t("map_size_new") % [size.x, size.y]]
	var dropped: Array = plan.dropped
	if not dropped.is_empty():
		var names: Array[String] = []
		for item: Dictionary in dropped.slice(0, 6):
			var at: Vector2i = item.at
			names.append("%s at %d, %d" % [String(item.art) if String(item.art) != "" else String(item.kind), at.x, at.y])
		var more := " …" if dropped.size() > 6 else ""
		lines.append(StudioText.t("map_size_dropped") % [dropped.size(), ", ".join(names) + more])
	if int(plan.links) > 0:
		lines.append(StudioText.t("map_size_links") % int(plan.links))
	_summary.text = "\n".join(lines)
	get_ok_button().disabled = edges().values().all(func(value: int) -> bool: return value == 0)
	_planning = false


## Bound opposite edges together so one operation can grow a map to the full supported size without a per-edge 64-tile
## ceiling. Shrinking still previews against the start and placed objects before it can be confirmed.
func _set_edge_limits() -> void:
	var size := OverworldMap.size_of(_studio.current_map())
	for edge: String in ["top", "bottom", "left", "right"]:
		var spin := _edges[edge] as SpinBox
		var opposite := String({"top": "bottom", "bottom": "top", "left": "right", "right": "left"}[edge])
		var current := size.y if edge in ["top", "bottom"] else size.x
		var other := int((_edges[opposite] as SpinBox).value)
		spin.min_value = 1 - current - other
		spin.max_value = StudioLand.MAX_DIMENSION - current - other


func _confirm() -> void:
	_studio.work.resize(edges(), fill_kind())
