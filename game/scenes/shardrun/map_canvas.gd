class_name MapCanvas
extends Control
## The whole of a layer's map, taller than its window (MapView scrolls it): where every room sits, and the dotted paths,
## room markers and guardian drawn there. The rooms' buttons are its children, laid over what it draws.

## The map's measures, in design pixels.
const ROW_STEP := 128.0
const RADIUS := 30.0
const BOSS_RADIUS := 70.0
## From the map's top to its top row: room for the guardian's medallion and name plate.
const HEAD := 372.0
const FOOT := 92.0
const SIDE_PAD := 56.0
const JITTER := Vector2(22, 14)
const DOT_GAP := 13.0

var state: Dictionary = {}
var catalog: Dictionary = {}
## ShardrunViews.node_states and ShardrunViews.reachable of the state.
var states: Dictionary = {}
var reachable: Dictionary = {}
var icons: Dictionary = {}
var portrait: Texture2D
var guardian_name := ""
## The room pointed at, and the kind the legend is pointing at ("" for none).
var focused := ""
var legend_kind := ""
## The chosen room swelling as you set off, 0 to 1.
var pop := 0.0
## Space under the bottom row (more when a legend lies over the map's foot).
var foot := FOOT
var _pulse := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func height_for(rows: int) -> float:
	return HEAD + (rows - 1) * ROW_STEP + foot


## Where a room sits: rows climb from the bottom, a little off the grid so the map reads as a place, and the guardian
## alone at the top.
func place(node: Dictionary) -> Vector2:
	if node.kind == "boss":
		return Vector2(size.x * 0.5, 30.0 + BOSS_RADIUS * 1.18)
	var columns := int(ShardrunRules.layer_of(state, catalog).columns)
	var column := (size.x - SIDE_PAD * 2.0) / columns
	var x := SIDE_PAD + (int(node.col) + 0.5) * column
	var y := size.y - foot - int(node.row) * ROW_STEP
	return Vector2(x, y) + jitter(String(node.id), minf(JITTER.x, column * 0.14))


## LEARN: hash() gives the same number for the same String on every run, so a room's nudge off the grid stays put
## without drawing on the run's Rng, whose stream belongs to the rules.
static func jitter(id: String, reach_x: float) -> Vector2:
	var bits := hash(id)
	var x := float(bits & 0xFF) / 255.0 - 0.5
	var y := float((bits >> 8) & 0xFF) / 255.0 - 0.5
	return Vector2(x * 2.0 * reach_x, y * 2.0 * JITTER.y)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _draw() -> void:
	if state.is_empty():
		return
	var calm := Settings.reduced_motion
	var glow := 1.0 if calm else 0.5 + 0.5 * sin(_pulse * 3.6)
	_draw_paths(0.0 if calm else _pulse * 1.4)
	for node: Dictionary in state.map.nodes:
		if node.kind == "boss":
			_draw_guardian(node, glow)
		else:
			_draw_room(node, glow, calm)


func _draw_paths(flow: float) -> void:
	var by_id := {}
	for node: Dictionary in state.map.nodes:
		by_id[node.id] = node
	for edge: Array in state.map.edges:
		var from: Dictionary = by_id.get(edge[0], {})
		var to: Dictionary = by_id.get(edge[1], {})
		if from.is_empty() or to.is_empty():
			continue
		var walked: bool = edge[0] in state.visited and (edge[1] in state.visited or edge[1] == state.position)
		var next: bool = edge[0] == state.position and states.get(edge[1]) == "open"
		var alive: bool = reachable.has(edge[1]) and (edge[0] == state.position or reachable.has(edge[0]))
		var colour := Color(UiTheme.FAINT, 0.4)
		var dot := 2.6
		var phase := 0.0
		if walked:
			colour = UiTheme.AMBER
			dot = 4.5
		elif next:
			colour = UiTheme.TEAL if edge[1] == focused else UiTheme.AMBER
			dot = 5.0 if edge[1] == focused else 4.2
			phase = flow
		elif alive:
			colour = Color(UiTheme.MUTED, 0.8)
			dot = 3.2
		var trims := Vector2(_radius_of(from) + 8.0, _radius_of(to) + 10.0)
		var a := place(from)
		var b := place(to)
		if to.kind == "boss":
			# Paths climb to the guardian's name plate, not through it.
			b = _gate(b)
			trims.y = 4.0
		MapMarkers.draw_path(self, a, b, Color(0, 0, 0, 0.6), dot + 1.8, DOT_GAP, trims, phase)
		MapMarkers.draw_path(self, a, b, colour, dot, DOT_GAP, trims, phase)
	if state.position == null:
		for node: Dictionary in state.map.nodes:
			if int(node.row) == 0:
				var at := place(node)
				var colour := UiTheme.TEAL if node.id == focused else UiTheme.AMBER
				var trims := Vector2(0.0, RADIUS + 10.0)
				MapMarkers.draw_path(self, at + Vector2(0, 80), at, Color(0, 0, 0, 0.6), 6.0, DOT_GAP, trims, flow)
				MapMarkers.draw_path(self, at + Vector2(0, 80), at, colour, 4.2, DOT_GAP, trims, flow)


func _radius_of(node: Dictionary) -> float:
	return BOSS_RADIUS * 1.18 if node.kind == "boss" else RADIUS


## The foot of the guardian's name plate, where the paths below it meet.
func _gate(guardian: Vector2) -> Vector2:
	return guardian + Vector2(0, BOSS_RADIUS * 1.18 + 70.0)


func _draw_room(node: Dictionary, glow: float, calm: bool) -> void:
	var at := place(node)
	var where: String = states.get(node.id, "ahead")
	var radius := RADIUS
	var lit := 0.3
	match where:
		"current", "open":
			lit = 1.0
		"visited":
			lit = 0.6
		"ahead":
			lit = 0.9 if reachable.has(node.id) else 0.3
	if where == "open":
		var chosen: bool = node.id == focused
		var halo := UiTheme.TEAL if chosen else UiTheme.AMBER
		if not calm:
			radius *= 1.0 + 0.06 * sin(_pulse * 3.2 + at.x * 0.02)
		radius *= 1.0 + 0.28 * pop * float(chosen)
		draw_circle(at, radius + 16.0, Color(halo, 0.1 + 0.08 * glow))
		draw_arc(at, radius + 12.0 + 3.0 * glow, 0.0, TAU, 48, Color(halo, 0.5 + 0.5 * glow), 3.0, true)
	elif node.id == focused:
		draw_arc(at, radius + 11.0, 0.0, TAU, 48, Color(UiTheme.MUTED, 0.7), 2.0, true)
	if node.kind == legend_kind:
		draw_arc(at, radius + 18.0, 0.0, TAU, 48, Color(UiTheme.room(node.kind), 0.4 + 0.6 * glow), 3.0, true)
	MapMarkers.draw_room(self, node.kind, at, radius, lit, icons.get(node.kind))
	if where == "current":
		draw_arc(at, radius + 10.0, 0.0, TAU, 48, UiTheme.TEAL, 3.5, true)
		_draw_pin(at - Vector2(0, radius + 22.0))
	elif where == "visited":
		MapMarkers.draw_tick(self, at + Vector2(radius * 0.78, radius * 0.72), 9.0)


## "You are here": a teal pin over the room you stand in.
func _draw_pin(tip: Vector2) -> void:
	var bob := 0.0 if Settings.reduced_motion else 3.0 * sin(_pulse * 3.0)
	var at := tip + Vector2(0, bob)
	draw_circle(at + Vector2(0, -16), 9.0, UiTheme.TEAL)
	draw_colored_polygon(PackedVector2Array([at, at + Vector2(-9, -13), at + Vector2(9, -13)]), UiTheme.TEAL)
	draw_circle(at + Vector2(0, -16), 3.5, UiTheme.GROUND)


func _draw_guardian(node: Dictionary, glow: float) -> void:
	var at := place(node)
	var hue := UiTheme.room("boss")
	var radius := BOSS_RADIUS * (1.0 + 0.2 * pop * float(node.id == focused))
	if states.get(node.id) == "open":
		var halo := UiTheme.TEAL if node.id == focused else UiTheme.AMBER
		draw_arc(at, radius * 1.3 + 4.0 * glow, 0.0, TAU, 64, Color(halo, 0.5 + 0.5 * glow), 3.0, true)
	if legend_kind == "boss":
		draw_arc(at, radius * 1.4, 0.0, TAU, 64, Color(hue, 0.4 + 0.6 * glow), 3.0, true)
	MapMarkers.draw_guardian(self, at, radius, portrait, 1.0, glow)
	var font := UiTheme.crt_font()
	var title := guardian_name if guardian_name != "" else "Guardian"
	var caption := "GUARDIAN OF %s" % String(ShardrunRules.layer_of(state, catalog).name).to_upper()
	var line := Vector2(0, at.y + radius * 1.18 + 36.0)
	var plate_width := maxf(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x, 200.0) + 40.0
	var plate := Rect2(at.x - plate_width * 0.5, line.y - 32.0, plate_width, _gate(at).y - line.y + 32.0)
	UiTheme.box(Color(UiTheme.GROUND, 0.92), Color(hue, 0.5), 1, 8).draw(get_canvas_item(), plate)
	draw_string_outline(font, line, title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 8, Color.BLACK)
	draw_string(font, line, title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, hue)
	var small := UiTheme.ui_font(600)
	draw_string(small, line + Vector2(0, 22), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, UiTheme.MUTED)
