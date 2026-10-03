class_name GuardianRail
extends Control
## The run's layers stacked as a descent, the first at the top, each with its guardian's portrait: the beaten ones
## dimmed and ticked, the one this layer ends with lit, the later ones in shadow. Clicking the lit one asks the map to
## glide down to it.

signal guardian_pressed

const MEDALLION := 30.0
const CURRENT := 40.0
const TOP := 58.0
const BOTTOM := 40.0

## ShardrunViews.guardians: {layer, foes, where}, entry layer first.
var guardians: Array[Dictionary] = []
var _portraits: Array[Texture2D] = []
var _pulse := 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Guardians"


func show_guardians(shown: Array[Dictionary]) -> void:
	guardians = shown
	_portraits.clear()
	for guardian: Dictionary in guardians:
		var foes: Array = guardian.foes
		_portraits.append(null if foes.is_empty() else Art.texture("foes/" + String(foes[0].get("sprite", foes[0].id))))
	queue_redraw()


func centre(index: int) -> Vector2:
	var count := guardians.size()
	var span := size.y - TOP - BOTTOM - CURRENT * 2.0
	var step := minf(170.0, span / maxf(1.0, count - 1.0))
	var middle := TOP + CURRENT + span * 0.5
	return Vector2(size.x * 0.5, middle + step * (index - (count - 1) * 0.5))


func _process(delta: float) -> void:
	if not Settings.reduced_motion:
		_pulse += delta
		queue_redraw()


func _draw() -> void:
	var font := UiTheme.ui_font(600)
	draw_string(font, Vector2(0, 30), "DESCENT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, UiTheme.FAINT)
	for index in guardians.size() - 1:
		var beaten: bool = guardians[index].where == "beaten"
		var from := centre(index)
		var to := centre(index + 1)
		if beaten:
			draw_line(from, to, UiTheme.AMBER_DIM, 3.0, true)
		else:
			MapMarkers.draw_path(self, from, to, Color(UiTheme.FAINT, 0.7), 2.5, 11.0, Vector2(CURRENT, CURRENT))
	for index in guardians.size():
		var guardian := guardians[index]
		var at := centre(index)
		var current: bool = guardian.where == "current"
		var radius := CURRENT if current else MEDALLION
		var lit := 1.0 if current else (0.5 if guardian.where == "beaten" else 0.12)
		var glow := 0.5 + 0.5 * sin(_pulse * 2.6) if current else 0.0
		MapMarkers.draw_guardian(self, at, radius, _portraits[index], lit, glow)
		if guardian.where == "beaten":
			MapMarkers.draw_tick(self, at + Vector2(radius * 0.72, radius * 0.72), 10.0)
		var name := String(guardian.layer.name).get_slice(" / ", 0).trim_prefix("The ")
		var colour := UiTheme.AMBER if current else UiTheme.MUTED if guardian.where == "beaten" else UiTheme.FAINT
		var below := at + Vector2(0, radius * 1.18 + 17.0)
		var text_size := mini(13, int(13.0 * (size.x - 8.0) / maxf(1.0, font.get_string_size(name, 0, -1, 13).x)))
		draw_string_outline(
			font, below - Vector2(at.x, 0), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, text_size, 4, Color.BLACK
		)
		draw_string(font, below - Vector2(at.x, 0), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, text_size, colour)
		var ring := int(guardian.layer.get("ring", guardians.size() - index - 1))
		draw_string(font, below - Vector2(at.x, -18), "RING %d" % ring, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, colour)


func _index_at(point: Vector2) -> int:
	for index in guardians.size():
		var radius := CURRENT if guardians[index].where == "current" else MEDALLION
		if point.distance_to(centre(index)) <= radius * 1.25:
			return index
	return -1


func _get_tooltip(at_position: Vector2) -> String:
	var index := _index_at(at_position)
	if index < 0:
		return tooltip_text
	var guardian := guardians[index]
	var names: Array = (guardian.foes as Array).map(func(foe: Dictionary) -> String: return foe.name)
	var status := {"beaten": "Beaten", "current": "Waits below this layer", "ahead": "Deeper"}
	return (
		"Ring %d · %s\nGuardian: %s\n%s"
		% [
			int(guardian.layer.get("ring", guardians.size() - index - 1)),
			guardian.layer.name,
			", ".join(names) if not names.is_empty() else "?",
			status[guardian.where]
		]
	)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _index_at(click.position)
	if index >= 0 and guardians[index].where == "current":
		guardian_pressed.emit()
		accept_event()
