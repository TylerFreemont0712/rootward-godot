class_name MapView
extends Control
## A layer of the Salvage as a place: chambers joined by corridors, climbing from the bottom row to the guardian at the
## top. The rooms you can walk into next glow; the way you came is lit. Rooms are buttons (hover to see who waits
## there); the corridors are drawn beneath them.

signal enter_pressed(node_id: String)

const ROOM := Vector2(62, 62)
const CHAMBER := Vector2(92, 70)
const MARGIN := Vector2(48, 60)
const NAMES := {
	"fight": "Fight", "elite": "Elite", "boss": "Guardian", "rest": "Rest", "forge": "Forge", "treasure": "Cache"
}
const WHAT := {
	"rest": "Recover Integrity, or cleanse a curse.",
	"forge": "Rework a shard, widen a spell, or bind a new one.",
	"treasure": "A sealed cache: a relic, or a curse.",
}
const ROOM_COLOURS := {
	"fight": "#e5ba78",
	"elite": "#e69a54",
	"boss": "#f1bf58",
	"rest": "#7ac2b3",
	"forge": "#b5a5f5",
	"treasure": "#e2d079",
}

var state: Dictionary = {}
var catalog: Dictionary = {}
var _rooms: Dictionary = {}
var _states: Dictionary = {}
var _chamber: Texture2D
var _wall: TextureRect
var _title: Label
var _details: PanelContainer
var _detail_text: Label
var _focused := ""
var _traveling := false
var _pulse := 0.0


func _init() -> void:
	clip_contents = true
	_wall = TextureRect.new()
	_wall.stretch_mode = TextureRect.STRETCH_TILE
	_wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wall.modulate = Color(0.46, 0.39, 0.33)
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall.show_behind_parent = true
	add_child(_wall)
	_title = Ui.label("", "Subheading")
	_title.position = Vector2(16, 10)
	add_child(_title)
	_detail_text = Ui.label("Hover a chamber to inspect its route.", "Muted", true)
	_detail_text.custom_minimum_size = Vector2(280, 0)
	_details = Ui.panel(_detail_text, "Overlay")
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_details)


func show_map(run_state: Dictionary, run_catalog: Dictionary) -> void:
	state = run_state
	catalog = run_catalog
	var layer := ShardrunRules.layer_of(state, catalog)
	var layers: Array = catalog.config.layers
	_title.text = "%s  ·  layer %d of %d" % [layer.name, int(state.layer) + 1, layers.size()]
	_wall.texture = Art.texture("shardrun/map-wall-%s-0" % layer.id)
	_chamber = Art.texture("shardrun/map-chamber-%s" % layer.id)
	_states = ShardrunViews.node_states(state)
	_focused = ""
	_traveling = false
	_detail_text.text = "Hover a chamber to inspect its route."
	for room: Button in _rooms.values():
		room.queue_free()
	_rooms.clear()
	for node: Dictionary in state.map.nodes:
		_rooms[node.id] = _room(node, _states.get(node.id, "ahead"))
	_layout()


func _room(node: Dictionary, where: String) -> Button:
	var room := Button.new()
	room.flat = true
	room.icon = Art.texture("shardrun/map-" + String(node.kind))
	room.expand_icon = true
	room.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room.custom_minimum_size = ROOM
	room.size = ROOM
	room.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if room.icon == null:
		room.text = String(NAMES.get(node.kind, "?")).substr(0, 1)
	var nameplate := Ui.label(String(NAMES.get(node.kind, node.kind)).to_upper(), "Faint")
	nameplate.add_theme_font_size_override("font_size", 11)
	nameplate.add_theme_color_override("font_color", Color(ROOM_COLOURS.get(node.kind, "#e5ba78")))
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.custom_minimum_size.x = 84
	nameplate.position = Vector2(-11, 60)
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(nameplate)
	room.tooltip_text = _describe(node, where)
	room.disabled = where != "open"
	room.focus_mode = Control.FOCUS_ALL if where == "open" else Control.FOCUS_NONE
	room.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	room.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	room.add_theme_stylebox_override("hover", UiTheme.box(Color(UiTheme.AMBER, 0.15), UiTheme.AMBER, 2, 23))
	room.add_theme_stylebox_override("focus", UiTheme.box(Color.TRANSPARENT, UiTheme.TEAL, 2, 23))
	var shade := {"current": 1.0, "open": 1.0, "visited": 0.7, "passed": 0.38, "ahead": 0.84}
	room.modulate = Color(1, 1, 1, shade.get(where, 0.7))
	room.mouse_entered.connect(func() -> void: focus_room(node.id))
	room.mouse_exited.connect(func() -> void: focus_room(""))
	room.focus_entered.connect(func() -> void: focus_room(node.id))
	room.pressed.connect(func() -> void: travel_to(node.id))
	add_child(room)
	return room


func focus_room(id: String) -> void:
	_focused = id
	var node: Dictionary = {}
	for candidate: Dictionary in state.get("map", {}).get("nodes", []):
		if candidate.id == id:
			node = candidate
			break
	if node.is_empty():
		_detail_text.text = "Hover a chamber to inspect its route."
	else:
		_detail_text.text = (
			"%s  ·  %s\n%s"
			% [
				NAMES.get(node.kind, node.kind),
				"AVAILABLE" if _states.get(id) == "open" else _states.get(id, "ahead").to_upper(),
				_describe(node, _states.get(id, "ahead"))
			]
		)
	queue_redraw()


func travel_to(id: String) -> void:
	if _traveling or _states.get(id) != "open":
		return
	_traveling = true
	focus_room(id)
	var room: Button = _rooms.get(id)
	if room != null:
		room.pivot_offset = ROOM * 0.5
		var tween := room.create_tween()
		tween.tween_property(room, "scale", Vector2(1.18, 1.18), 0.13).set_trans(Tween.TRANS_BACK)
		tween.tween_property(room, "scale", Vector2.ONE, 0.13)
		await tween.finished
	enter_pressed.emit(id)
	_traveling = false


func _describe(node: Dictionary, where: String) -> String:
	var name: String = NAMES.get(node.kind, node.kind)
	var foes := ShardrunViews.room_foes(state, node, catalog)
	var text := name
	if not foes.is_empty():
		text += ": " + ", ".join(foes.map(func(foe: Dictionary) -> String: return foe.name))
	elif WHAT.has(node.kind):
		text += ": " + WHAT[node.kind]
	match where:
		"open":
			text += "\nClick to go there."
		"current":
			text += "\nYou are here."
	return text


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


## Where a room sits: rows climb from the bottom, the boss alone at the top.
func place(node: Dictionary) -> Vector2:
	var layer := ShardrunRules.layer_of(state, catalog)
	var rows := int(layer.rows)
	var columns := int(layer.columns)
	var area := Rect2(MARGIN, size - MARGIN * 2.0)
	# The boss is one more row above the top one; rows 0..rows span the whole height.
	var step := area.size.y / rows
	if node.kind == "boss":
		return Vector2(area.get_center().x, area.position.y)
	var x := area.position.x + (int(node.col) + 0.5) * area.size.x / columns
	return Vector2(x, area.end.y - int(node.row) * step)


func _layout() -> void:
	_wall.size = size
	_details.position = Vector2(maxf(16.0, size.x - 335.0), 16.0)
	if state.is_empty():
		return
	for node: Dictionary in state.map.nodes:
		var room: Button = _rooms.get(node.id)
		if room != null:
			room.position = place(node) - ROOM * 0.5
	queue_redraw()


func _draw() -> void:
	if state.is_empty():
		return
	var by_id := {}
	for node: Dictionary in state.map.nodes:
		by_id[node.id] = node
	for edge: Array in state.map.edges:
		var from: Dictionary = by_id.get(edge[0], {})
		var to: Dictionary = by_id.get(edge[1], {})
		if from.is_empty() or to.is_empty():
			continue
		var walked: bool = edge[0] in state.visited and (edge[1] in state.visited)
		var next: bool = edge[0] == state.position and _states.get(edge[1]) == "open"
		var focused_route: bool = next and edge[1] == _focused
		var colour := UiTheme.LINE.lightened(0.15)
		var width := 4.0
		if walked:
			colour = UiTheme.AMBER_DIM
			width = 5.0
		elif next:
			colour = Color(UiTheme.TEAL if focused_route else UiTheme.AMBER, 0.7 + 0.3 * sin(_pulse * 4.0))
			width = 9.0 if focused_route else 5.0
		draw_line(place(from), place(to), Color(0, 0, 0, 0.5), width + 4.0)
		draw_line(place(from), place(to), colour, width)
	if state.position == null:
		for node: Dictionary in state.map.nodes:
			if int(node.row) == 0:
				var at := place(node)
				var selected: bool = node.id == _focused
				draw_line(
					at + Vector2(0, 50),
					at,
					Color(UiTheme.TEAL if selected else UiTheme.AMBER, 0.75 if selected else 0.35),
					6.0 if selected else 3.0
				)
	for node: Dictionary in state.map.nodes:
		var at := place(node)
		var where: String = _states.get(node.id, "ahead")
		var tint := Color(0.92, 0.80, 0.68) if where in ["open", "current"] else Color(0.60, 0.53, 0.48)
		if _chamber != null:
			draw_texture_rect(_chamber, Rect2(at - CHAMBER * 0.5, CHAMBER), false, tint)
		else:
			draw_rect(Rect2(at - CHAMBER * 0.5, CHAMBER), Color(UiTheme.PANEL_3, 0.9))
		if where == "open":
			var glow := 0.55 + 0.45 * sin(_pulse * 4.0)
			var selected: bool = node.id == _focused
			draw_arc(
				at,
				40.0 + glow * (7.0 if selected else 3.0),
				0.0,
				TAU,
				40,
				Color(UiTheme.TEAL if selected else UiTheme.AMBER, 0.5 + glow * 0.5),
				4.0 if selected else 3.0
			)
		elif where == "current":
			draw_arc(at, 40.0, 0.0, TAU, 32, UiTheme.TEAL, 3.0)
		elif where == "visited":
			draw_arc(at, 37.0, 0.0, TAU, 32, Color(UiTheme.AMBER_DIM, 0.6), 2.0)
