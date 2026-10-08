class_name ForgeCardGrid
extends HFlowContainer
## The cards a forge acts on: one face per distinct card, with a badge for how many copies the deck holds. A face the
## action cannot use is dimmed and does not answer. A chosen face is ringed in the action's colour and the others step
## back, so what will happen is clear before anything is confirmed.

## A usable card was clicked.
signal picked(shard_id: String)

var _boxes: Dictionary = {}
var _faces: Dictionary = {}
var _rings: Dictionary = {}
var _usable: Dictionary = {}
var _ring_colour := UiTheme.AMBER
var _selected := ""
var _locked := false


## `ids` lists every copy (a duplicate is another copy); `usable` says which distinct cards can be picked.
static func create(
	session: ShardrunSession, ids: Array, usable: Dictionary, ring: Color, size_kind := CardFace.Size.DECK
) -> ForgeCardGrid:
	var grid := ForgeCardGrid.new()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid._usable = usable
	grid._ring_colour = ring
	grid._build(session, ids, size_kind)
	return grid


## The box a card's face sits in; the forge's animations play inside it.
func holder_of(shard_id: String) -> Control:
	return _boxes.get(shard_id)


func face_of(shard_id: String) -> CardFace:
	return _faces.get(shard_id)


func select(shard_id: String) -> void:
	_selected = shard_id
	_refresh()


## Stops the grid answering, while the chosen card's animation plays.
func lock() -> void:
	_locked = true
	for id: String in _faces:
		(_faces[id] as CardFace).pressed = Callable()


func _build(session: ShardrunSession, ids: Array, size_kind: CardFace.Size) -> void:
	var counts := {}
	for id: String in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var card_size: Vector2 = CardFace.SIZES[size_kind]
	for id: String in ids:
		if _boxes.has(id):
			continue
		var holder := Control.new()
		holder.custom_minimum_size = card_size
		var face := CardFace.create(id, session.catalog, session.state.language, session.show_summaries(), size_kind)
		face.draggable = false
		if _usable.get(id, false):
			face.pressed = _on_pressed.bind(id)
		holder.add_child(face)
		var ring := Panel.new()
		ring.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0), _ring_colour, 3, 10, Vector2.ZERO))
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.visible = false
		holder.add_child(ring)
		var copies: int = counts[id]
		var badge := Ui.label("×%d" % copies if copies > 1 else " ", "Subheading")
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var column := Ui.vbox([holder, badge], 2)
		add_child(column)
		_boxes[id] = holder
		_faces[id] = face
		_rings[id] = ring
	_refresh()


func _refresh() -> void:
	for id: String in _faces:
		var alpha := 1.0
		if not _usable.get(id, false):
			alpha = 0.42
		elif _selected != "" and id != _selected:
			alpha = 0.62
		(_faces[id] as CardFace).modulate.a = alpha
		(_rings[id] as Control).visible = id == _selected


func _on_pressed(_spot: Dictionary, button: int, shard_id: String) -> void:
	if button != MOUSE_BUTTON_LEFT or _locked:
		return
	select(shard_id)
	picked.emit(shard_id)
