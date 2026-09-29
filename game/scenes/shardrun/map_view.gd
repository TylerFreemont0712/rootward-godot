class_name MapView
extends Control
## A layer of the Machine as a tall scroll of rooms, in the spirit of Slay the Spire's map: dotted paths climb from the
## bottom row to the guardian waiting at the top. The map is taller than its window and glides: the wheel, a drag, the
## scroll bar, Page Up/Down or a room taking focus moves it, eased toward where it was asked to be. A new layer opens on
## its guardian and pans down to where you start. Every kind of room has its own hue and outline (MapMarkers), named in
## the legend at the right; the guardians of every layer stand on the rail at the left.

signal enter_pressed(node_id: String)

const NAMES := {
	"fight": "Fight", "elite": "Elite", "boss": "Guardian", "rest": "Rest", "forge": "Forge", "treasure": "Cache"
}
const WHAT := {
	"fight": "Foes bar the way.",
	"elite": "A stronger foe, and a richer reward.",
	"boss": "The layer's guardian. Beat it to go deeper.",
	"rest": "Recover Integrity, or cleanse a curse.",
	"forge": "Rework a shard, widen a spell, or bind a new one.",
	"treasure": "A sealed cache: a relic, or a curse.",
}
const LEGEND: Array[String] = ["fight", "elite", "rest", "forge", "treasure", "boss"]
const HINT := "Hover a room to see what waits there."
const RAIL_WIDTH := 128.0
const SIDE_WIDTH := 256.0
const WHEEL_STEP := 120.0
const DRAG_START := 6.0
## How quickly the view catches up with its target: the gap shrinks by e^(-GLIDE * seconds).
const GLIDE := 9.0
## Where the row you stand on sits in the window, from its top: low, so the rooms ahead are in view.
const STAND_AT := 0.76
## Seconds a new layer holds on its guardian before gliding down to the first row.
const INTRO_HOLD := 0.9

## Where each layer's view was left ("seed:layer" -> scroll), so a rebuilt screen glides on from there.
static var _left_at: Dictionary = {}

var state: Dictionary = {}
var catalog: Dictionary = {}
var _rooms: Dictionary = {}
var _states: Dictionary = {}
var _reachable: Dictionary = {}
var _rail: GuardianRail
var _view: Control
var _canvas: MapCanvas
var _wall: TextureRect
var _fade: Control
var _bar: VScrollBar
var _side: VBoxContainer
## The legend along the map's foot, when the window is too narrow for the side panel.
var _strip: PanelContainer
var _title: Label
var _subtitle: Label
var _flavor: Label
var _detail_text: Label
var _traveling := false
var _pulse := 0.0
var _scroll := 0.0
var _scroll_to := 0.0
var _placed := false
var _intro := 0.0
var _pressing := false
var _dragging := false
var _drag_from := 0.0
var _drag_scroll := 0.0


func _init() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view = Control.new()
	_view.clip_contents = true
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	_canvas = MapCanvas.new()
	for kind: String in LEGEND:
		_canvas.icons[kind] = Art.texture("shardrun/map-" + kind)
	_view.add_child(_canvas)
	_wall = TextureRect.new()
	_wall.stretch_mode = TextureRect.STRETCH_TILE
	_wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wall.modulate = Color(0.4, 0.34, 0.29)
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall.show_behind_parent = true
	_canvas.add_child(_wall)
	_fade = Control.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.draw.connect(_draw_fade)
	_view.add_child(_fade)
	_bar = VScrollBar.new()
	_bar.value_changed.connect(
		func(value: float) -> void:
			scroll_to(value)
			_scroll = _scroll_to
	)
	_view.add_child(_bar)
	_rail = GuardianRail.new()
	_rail.guardian_pressed.connect(func() -> void: scroll_to(0.0))
	add_child(_rail)
	_side = Ui.vbox([], 10)
	add_child(_side)
	_title = Ui.label("", "Subheading")
	_subtitle = Ui.tint(Ui.label("", "Faint"), UiTheme.AMBER_DIM) as Label
	_flavor = Ui.sized(Ui.label("", "Muted", true), 14) as Label
	_detail_text = Ui.label(HINT, "Muted", true)
	_side.add_child(Ui.vbox([_title, _subtitle], 2))
	_side.add_child(_flavor)
	_side.add_child(Ui.panel(_detail_text, "Card"))
	_side.add_child(Ui.expand(Ui.spacer(0, 1), true))
	_side.add_child(Ui.label("ROOMS", "Faint"))
	for kind: String in LEGEND:
		_side.add_child(_legend_row(kind))
	_side.add_child(Ui.sized(Ui.label("Wheel or drag to look ahead.", "Faint", true), 12))
	var chips := Ui.flow([], 2)
	for kind: String in LEGEND:
		var chip := _legend_row(kind)
		chip.custom_minimum_size.x = 118
		chips.add_child(chip)
	_strip = Ui.panel(chips)
	_strip.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(UiTheme.GROUND, 0.9), UiTheme.LINE, 1, 6, Vector2(8, 4))
	)
	_view.add_child(_strip)


func show_map(run_state: Dictionary, run_catalog: Dictionary) -> void:
	state = run_state
	catalog = run_catalog
	var layer := ShardrunRules.layer_of(state, catalog)
	var layers: Array = catalog.config.layers
	_title.text = layer.name
	_subtitle.text = "LAYER %d OF %d" % [int(state.layer) + 1, layers.size()]
	_flavor.text = String(layer.get("flavor", ""))
	_wall.texture = Art.texture("shardrun/map-wall-%s-0" % layer.id)
	_states = ShardrunViews.node_states(state)
	_reachable = ShardrunViews.reachable(state)
	var guardians := ShardrunViews.guardians(state, catalog)
	_rail.show_guardians(guardians)
	var foes: Array = guardians[int(state.layer)].foes if int(state.layer) < guardians.size() else []
	_canvas.state = state
	_canvas.catalog = catalog
	_canvas.states = _states
	_canvas.reachable = _reachable
	_canvas.guardian_name = ", ".join(foes.map(func(foe: Dictionary) -> String: return foe.name))
	_canvas.portrait = null if foes.is_empty() else Art.texture("foes/" + String(foes[0].get("sprite", foes[0].id)))
	_canvas.focused = ""
	_traveling = false
	_detail_text.text = HINT
	for room: Button in _rooms.values():
		room.queue_free()
	_rooms.clear()
	for node: Dictionary in state.map.nodes:
		_rooms[node.id] = _room(node, _states.get(node.id, "ahead"))
	_placed = false
	_layout()


func _room(node: Dictionary, where: String) -> Button:
	var room := Button.new()
	var radius := MapCanvas.BOSS_RADIUS if node.kind == "boss" else MapCanvas.RADIUS
	room.flat = true
	room.size = Vector2.ONE * (radius * 2.0 + 12.0)
	room.mouse_filter = Control.MOUSE_FILTER_PASS
	room.tooltip_text = _describe(node, where)
	room.disabled = where != "open"
	room.focus_mode = Control.FOCUS_ALL if where == "open" else Control.FOCUS_NONE
	if where == "open":
		room.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for look: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		room.add_theme_stylebox_override(look, StyleBoxEmpty.new())
	room.add_theme_stylebox_override("focus", UiTheme.box(Color.TRANSPARENT, UiTheme.TEAL, 2, int(radius) + 6))
	room.mouse_entered.connect(func() -> void: focus_room(node.id, false))
	room.mouse_exited.connect(func() -> void: focus_room(""))
	room.focus_entered.connect(func() -> void: focus_room(node.id))
	room.pressed.connect(func() -> void: travel_to(node.id))
	_canvas.add_child(room)
	return room


func _legend_row(kind: String) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.tooltip_text = WHAT[kind]
	row.draw.connect(
		func() -> void:
			var at := Vector2(18, 17)
			if kind == _canvas.legend_kind:
				row.draw_rect(Rect2(Vector2.ZERO, row.size), Color(UiTheme.room(kind), 0.1))
			if kind == "boss":
				MapMarkers.draw_guardian(row, at, 11.0, null, 1.0)
			else:
				MapMarkers.draw_room(row, kind, at, 13.0, 1.0, _canvas.icons.get(kind))
	)
	var name := Ui.tint(Ui.label(NAMES[kind], "Muted"), UiTheme.room(kind))
	name.position = Vector2(44, 5)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name)
	row.mouse_entered.connect(
		func() -> void:
			_canvas.legend_kind = kind
			row.queue_redraw()
	)
	row.mouse_exited.connect(
		func() -> void:
			_canvas.legend_kind = ""
			row.queue_redraw()
	)
	return row


## Shows what waits in a room (or the hint, for ""); `reveal` glides the map to it when it is out of sight.
func focus_room(id: String, reveal := true) -> void:
	_canvas.focused = id
	var node := _node(id)
	if node.is_empty():
		_detail_text.text = HINT
		return
	var where: String = _states.get(id, "ahead")
	var status := where.to_upper()
	if where == "open":
		status = "AVAILABLE"
	elif where == "ahead" and not _reachable.has(id):
		status = "OUT OF REACH"
	_detail_text.text = "%s  ·  %s\n%s" % [NAMES.get(node.kind, node.kind), status, _describe(node, where)]
	if reveal:
		_reveal(id)


func travel_to(id: String) -> void:
	if _traveling or _states.get(id) != "open":
		return
	_traveling = true
	focus_room(id)
	var tween := create_tween()
	tween.tween_property(_canvas, "pop", 1.0, 0.13).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_canvas, "pop", 0.0, 0.13)
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


func _node(id: String) -> Dictionary:
	for node: Dictionary in state.get("map", {}).get("nodes", []):
		if node.id == id:
			return node
	return {}


# --- Scrolling -------------------------------------------------------------------------------------------------------


## How far down the map the window's top edge is asked to go, clamped to the map.
func scroll_to(value: float) -> void:
	_scroll_to = clampf(value, 0.0, max_scroll())


## Puts the view there at once, with no glide (and no opening pan).
func jump_to(value: float) -> void:
	_intro = 0.0
	scroll_to(value)
	_scroll = _scroll_to
	_apply_scroll()


func max_scroll() -> float:
	return maxf(0.0, _canvas.size.y - _view.size.y)


func scroll_target() -> float:
	return _scroll_to


func _key() -> String:
	return "%s:%d" % [state.get("seed", ""), int(state.get("layer", 0))]


## Where the view rests: the row you stand on low in the window, or the bottom row before the first step.
func _standing_scroll() -> float:
	var room: Button = _rooms.get(state.position) if state.position != null else null
	if room == null:
		return max_scroll()
	return room.position.y + room.size.y * 0.5 - _view.size.y * STAND_AT


func _place_view() -> void:
	_placed = true
	var key := _key()
	if state.position == null and not _left_at.has(key) and not Settings.reduced_motion:
		_scroll = 0.0
		_scroll_to = 0.0
		_intro = INTRO_HOLD
		return
	_scroll = clampf(float(_left_at.get(key, _standing_scroll())), 0.0, max_scroll())
	scroll_to(_standing_scroll())


func _reveal(id: String) -> void:
	var room: Button = _rooms.get(id)
	if room == null or _view.size.y <= 0.0:
		return
	var y := room.position.y + room.size.y * 0.5
	var margin := minf(120.0, _view.size.y * 0.25)
	if y - margin < _scroll_to or y + margin > _scroll_to + _view.size.y:
		scroll_to(y - _view.size.y * 0.5)


func _on_view_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		var notches := button.factor if button.factor > 0.0 else 1.0
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_intro = 0.0
			scroll_to(_scroll_to - WHEEL_STEP * notches)
			_view.accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_intro = 0.0
			scroll_to(_scroll_to + WHEEL_STEP * notches)
			_view.accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_pressing = button.pressed
			_dragging = false
			_drag_from = button.position.y
			_drag_scroll = _scroll
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pressing:
		if not _dragging and absf(motion.position.y - _drag_from) > DRAG_START:
			_dragging = true
			_intro = 0.0
		if _dragging:
			scroll_to(_drag_scroll - (motion.position.y - _drag_from))
			_scroll = _scroll_to
		return
	var pan := event as InputEventPanGesture
	if pan != null:
		_intro = 0.0
		scroll_to(_scroll_to + pan.delta.y * 40.0)
		_view.accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or not is_visible_in_tree():
		return
	match key.keycode:
		KEY_PAGEUP:
			scroll_to(_scroll_to - _view.size.y * 0.8)
		KEY_PAGEDOWN:
			scroll_to(_scroll_to + _view.size.y * 0.8)
		KEY_HOME:
			scroll_to(0.0)
		KEY_END:
			scroll_to(max_scroll())
		_:
			return
	_intro = 0.0
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_pulse += delta
	if _intro > 0.0:
		_intro -= delta
		if _intro <= 0.0:
			scroll_to(max_scroll())
	# LEARN: lerping by a fixed fraction each frame glides faster on a faster screen. Keeping e^(-rate * delta) of the
	# gap instead is the same curve at any frame rate, so the scroll feels the same at 30 and 144 frames a second.
	if not _dragging:
		_scroll = lerpf(_scroll_to, _scroll, exp(-GLIDE * delta))
		if absf(_scroll - _scroll_to) < 0.5:
			_scroll = _scroll_to
	_apply_scroll()


func _apply_scroll() -> void:
	var slack := maxf(0.0, (_view.size.y - _canvas.size.y) * 0.5)
	_canvas.position = Vector2(0, roundf(slack - _scroll))
	_bar.visible = max_scroll() > 0.0
	_bar.max_value = _canvas.size.y
	_bar.page = _view.size.y
	_bar.set_value_no_signal(_scroll)
	_fade.queue_redraw()
	if _placed and not state.is_empty():
		_left_at[_key()] = _scroll_to


# --- Layout ----------------------------------------------------------------------------------------------------------


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var side := SIDE_WIDTH if size.x > 900.0 else 0.0
	_side.visible = side > 0.0
	_strip.visible = not _side.visible
	_rail.position = Vector2.ZERO
	_rail.size = Vector2(RAIL_WIDTH, size.y)
	_side.position = Vector2(size.x - side + 16.0, 14.0)
	_side.size = Vector2(maxf(0.0, side - 30.0), maxf(0.0, size.y - 28.0))
	_view.position = Vector2(RAIL_WIDTH, 0)
	_view.size = Vector2(maxf(0.0, size.x - RAIL_WIDTH - side), size.y)
	_fade.size = _view.size
	_bar.position = Vector2(_view.size.x - 14.0, 10.0)
	_bar.size = Vector2(10.0, maxf(0.0, _view.size.y - 20.0))
	_strip.size = Vector2(maxf(0.0, _view.size.x - 40.0), 0.0)
	_strip.position = Vector2(12.0, _view.size.y - _strip.get_combined_minimum_size().y - 10.0)
	_canvas.foot = MapCanvas.FOOT + (_view.size.y - _strip.position.y if _strip.visible else 0.0)
	queue_redraw()
	if state.is_empty():
		return
	var rows := int(ShardrunRules.layer_of(state, catalog).rows)
	_canvas.size = Vector2(_view.size.x - 16.0, _canvas.height_for(rows))
	_wall.size = _canvas.size
	for node: Dictionary in state.map.nodes:
		var room: Button = _rooms.get(node.id)
		if room != null:
			room.position = _canvas.place(node) - room.size * 0.5
	if not _placed and _view.size.y > 0.0:
		_place_view()
	scroll_to(_scroll_to)
	_apply_scroll()


# --- Drawing ---------------------------------------------------------------------------------------------------------


func _draw() -> void:
	draw_rect(Rect2(0, 0, RAIL_WIDTH, size.y), Color(UiTheme.GROUND, 0.92))
	draw_line(Vector2(RAIL_WIDTH, 0), Vector2(RAIL_WIDTH, size.y), UiTheme.LINE, 1.0)
	if _side.visible:
		var x := size.x - SIDE_WIDTH
		draw_rect(Rect2(x, 0, SIDE_WIDTH, size.y), Color(UiTheme.GROUND, 0.92))
		draw_line(Vector2(x, 0), Vector2(x, size.y), UiTheme.LINE, 1.0)


## Shadows at the window's edges where the map goes on beyond them, and a chevron while there is more above.
func _draw_fade() -> void:
	var width := _fade.size.x
	var depth := 64.0
	var dark := Color(UiTheme.GROUND, 0.95)
	var clear := Color(UiTheme.GROUND, 0.0)
	if _scroll > 1.0:
		var top := PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, depth), Vector2(0, depth)])
		_fade.draw_polygon(top, PackedColorArray([dark, dark, clear, clear]))
		var bob := 0.0 if Settings.reduced_motion else 3.0 * sin(_pulse * 3.0)
		var tip := Vector2(width * 0.5, 14.0 + bob)
		var chevron := PackedVector2Array([tip + Vector2(-14, 10), tip, tip + Vector2(14, 10)])
		_fade.draw_polyline(chevron, Color(UiTheme.AMBER, 0.8), 3.0, true)
	if _scroll < max_scroll() - 1.0:
		var bottom := PackedVector2Array(
			[
				Vector2(0, _fade.size.y - depth),
				Vector2(width, _fade.size.y - depth),
				_fade.size,
				Vector2(0, _fade.size.y)
			]
		)
		_fade.draw_polygon(bottom, PackedColorArray([clear, clear, dark, dark]))
