class_name MapView
extends Control
## A layer of the Salvage as a place: chambers joined by corridors, climbing from the bottom row to the guardian at the
## top. The rooms you can walk into next glow; the way you came is lit. Rooms are buttons (hover to see who waits
## there); the corridors are drawn beneath them.

signal enter_pressed(node_id: String)

const ROOM := Vector2(46, 46)
const CHAMBER := Vector2(78, 58)
const MARGIN := Vector2(48, 60)
const NAMES := {
	"fight": "Fight", "elite": "Elite", "boss": "Guardian", "rest": "Rest", "forge": "Forge", "treasure": "Cache"
}
const WHAT := {
	"rest": "Recover Integrity, or cleanse a curse.",
	"forge": "Rework a shard, widen a spell, or bind a new one.",
	"treasure": "A sealed cache: a relic, or a curse.",
}

var state: Dictionary = {}
var catalog: Dictionary = {}
var _rooms: Dictionary = {}
var _states: Dictionary = {}
var _chamber: Texture2D
var _wall: TextureRect
var _title: Label
var _pulse := 0.0


func _init() -> void:
	clip_contents = true
	_wall = TextureRect.new()
	_wall.stretch_mode = TextureRect.STRETCH_TILE
	_wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_wall.modulate = Color(0.32, 0.28, 0.25)
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall.show_behind_parent = true
	add_child(_wall)
	_title = Ui.label("", "Subheading")
	_title.position = Vector2(16, 10)
	add_child(_title)


func show_map(run_state: Dictionary, run_catalog: Dictionary) -> void:
	state = run_state
	catalog = run_catalog
	var layer := ShardrunRules.layer_of(state, catalog)
	var layers: Array = catalog.config.layers
	_title.text = "%s  ·  layer %d of %d" % [layer.name, int(state.layer) + 1, layers.size()]
	_wall.texture = Art.texture("shardrun/map-wall-%s-0" % layer.id)
	_chamber = Art.texture("shardrun/map-chamber-%s" % layer.id)
	_states = ShardrunViews.node_states(state)
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
	room.tooltip_text = _describe(node, where)
	room.disabled = where != "open"
	room.focus_mode = Control.FOCUS_ALL if where == "open" else Control.FOCUS_NONE
	room.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	room.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	room.add_theme_stylebox_override("hover", UiTheme.box(Color(UiTheme.AMBER, 0.15), UiTheme.AMBER, 2, 23))
	room.add_theme_stylebox_override("focus", UiTheme.box(Color.TRANSPARENT, UiTheme.TEAL, 2, 23))
	var shade := {"current": 1.0, "open": 1.0, "visited": 0.55, "passed": 0.28, "ahead": 0.72}
	room.modulate = Color(1, 1, 1, shade.get(where, 0.7))
	room.pressed.connect(func() -> void: enter_pressed.emit(node.id))
	add_child(room)
	return room


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
		var colour := UiTheme.LINE.lightened(0.15)
		var width := 4.0
		if walked:
			colour = UiTheme.AMBER_DIM
			width = 5.0
		elif next:
			colour = Color(UiTheme.AMBER, 0.55 + 0.35 * sin(_pulse * 4.0))
		draw_line(place(from), place(to), Color(0, 0, 0, 0.5), width + 4.0)
		draw_line(place(from), place(to), colour, width)
	if state.position == null:
		for node: Dictionary in state.map.nodes:
			if int(node.row) == 0:
				var at := place(node)
				draw_line(at + Vector2(0, 50), at, Color(UiTheme.AMBER, 0.35), 3.0)
	for node: Dictionary in state.map.nodes:
		var at := place(node)
		var where: String = _states.get(node.id, "ahead")
		var tint := Color(0.7, 0.62, 0.55) if where in ["open", "current"] else Color(0.42, 0.37, 0.33)
		if _chamber != null:
			draw_texture_rect(_chamber, Rect2(at - CHAMBER * 0.5, CHAMBER), false, tint)
		else:
			draw_rect(Rect2(at - CHAMBER * 0.5, CHAMBER), Color(UiTheme.PANEL_3, 0.9))
		if where == "open":
			var glow := 0.55 + 0.45 * sin(_pulse * 4.0)
			draw_arc(at, 31.0 + glow * 3.0, 0.0, TAU, 40, Color(UiTheme.AMBER, 0.5 + glow * 0.5), 3.0)
		elif where == "current":
			draw_arc(at, 30.0, 0.0, TAU, 32, UiTheme.TEAL, 3.0)
		elif where == "visited":
			draw_arc(at, 26.0, 0.0, TAU, 32, Color(UiTheme.AMBER_DIM, 0.6), 2.0)
