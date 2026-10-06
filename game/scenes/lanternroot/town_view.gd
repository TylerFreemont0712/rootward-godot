class_name LanternTownView
extends Control
## Lanternroot's hamlet, drawn from LanternLayout (ADR-0055): houses hang from the roots, bridges are imports, lanterns
## are answered letters. It decides nothing; it shows a layout, reports which house was clicked, and plays the Night
## Watch: a light walking from house to house, lighting each lantern that held and setting a gremlin on each that broke.

signal house_pressed(module: String)

const SKY_TOP := Color("#0b0806")
const SKY_BOTTOM := Color("#141016")
const DEEP_GLOW := Color("#f2a541")

## Where the 1000 x 1000 town square is drawn, in this control's coordinates; set by the screen around its panels.
var area := Rect2(40, 150, 1300, 880)
var language := LanternCode.PYTHON
## How dark the night is (0 day, 1 midnight) and where the Night Watch's light is.
var night := 0.0
var watch_light := Vector2(-100, -100)
var watch_visible := false

var _layout := {"houses": [], "bridges": []}
var _ghosts: Array[Dictionary] = []
var _hovered := ""
var _time := 0.0
## Per lantern id: how far its gremlin has popped in (0-1), so a new gremlin grows rather than appears.
var _pops := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)


func show_town(layout: Dictionary, ghosts: Array[Dictionary]) -> void:
	_layout = layout
	_ghosts = ghosts
	for house: Dictionary in layout.houses:
		for lantern: Dictionary in house.lanterns:
			if lantern.state == LanternRules.DARK and not _pops.has(lantern.id):
				_pops[lantern.id] = 1.0
	queue_redraw()


## Where a house stands on screen.
func house_point(module: String) -> Vector2:
	for house: Dictionary in _layout.houses:
		if house.module == module:
			return _to_screen(house.at)
	return area.get_center()


## The Night Watch: darkness falls, a light visits every house in order and its lanterns take their new states from
## `after`, then the darkness lifts a little. Awaited by the screen.
func play_night(after: Dictionary, reduced_motion: bool) -> void:
	var step := 0.05 if reduced_motion else 0.55
	var fall := create_tween()
	fall.tween_property(self, "night", 0.82, step * 2.0)
	await fall.finished
	watch_visible = true
	var houses: Array = _layout.houses
	if not houses.is_empty():
		watch_light = _to_screen(houses[0].at) + Vector2(-160, -120)
	for house: Dictionary in after.houses:
		var walk := create_tween()
		walk.tween_property(self, "watch_light", _to_screen(house.at) + Vector2(0, -70), step)
		await walk.finished
		_replace_house(house)
		for lantern: Dictionary in house.lanterns:
			if lantern.state == LanternRules.DARK:
				_pops[lantern.id] = 0.0
				create_tween().tween_method(func(v: float) -> void: _pops[lantern.id] = v, 0.0, 1.0, step)
				Sound.play("sfx-glitch", 0.5)
			elif lantern.state == LanternRules.LIT:
				Sound.play("sfx-glyph", 0.35, 1.0 + randf() * 0.2)
		await get_tree().create_timer(step * 0.5).timeout
	_layout = after
	watch_visible = false
	var rise := create_tween()
	rise.tween_property(self, "night", 0.0, step * 2.0)
	await rise.finished


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := _house_at((event as InputEventMouseMotion).position)
		if over != _hovered:
			_hovered = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over != "" else Control.CURSOR_ARROW
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var module := _house_at(click.position)
			if module != "":
				accept_event()
				house_pressed.emit(module)


func _get_tooltip(at_position: Vector2) -> String:
	var module := _house_at(at_position)
	for house: Dictionary in _layout.houses:
		if house.module == module:
			var lines: Array[String] = [String(house.name) + "  ·  " + LanternCode.file_name(module, language)]
			for lantern: Dictionary in house.lanterns:
				lines.append("%s  %s" % [_state_mark(lantern.state), Text.t(lantern.title)])
			return "\n".join(lines)
	return ""


func _draw() -> void:
	_draw_sky()
	var font := get_theme_default_font()
	var code_font := UiTheme.code_font()
	var points := {}
	for house: Dictionary in _layout.houses:
		points[house.module] = _to_screen(house.at)
	for bridge: Dictionary in _layout.bridges:
		if points.has(bridge.from) and points.has(bridge.to):
			var ends := _bridge_ends(points[bridge.from], points[bridge.to])
			var lit := _house_lit(bridge.from) > 0.0 and _house_lit(bridge.to) > 0.0
			var label := ("from %s import" if language == LanternCode.PYTHON else 'require("./%s")') % bridge.to
			LanternTownPainter.bridge(self, ends[0], ends[1], lit, fmod(_time * 0.35, 1.0), code_font, label)
	for ghost in _ghosts:
		var at := _to_screen(ghost.at)
		LanternTownPainter.house(self, at, Color(ghost.roof), 0.0, false, true, _time)
		_label(font, code_font, at, Text.t(ghost.name), Text.t("a letter waits"), 0.45)
	for house: Dictionary in _layout.houses:
		var at: Vector2 = points[house.module]
		var lit := _house_lit(house.module)
		LanternTownPainter.house(self, at, Color(house.roof), lit, _hovered == house.module, false, _time)
		_draw_lanterns(house, at)
		var title := Text.t(house.name) if not house.own else Text.t("Your workshop")
		_label(font, code_font, at, title, LanternCode.file_name(house.module, language), 1.0)
	_draw_fireflies()
	if night > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.06, night * 0.7))
	if watch_visible:
		LanternTownPainter.glow(self, watch_light, 70.0, Color(LanternTownPainter.GLOW, 0.5))
		draw_circle(watch_light, 6.0, Color.WHITE)


func _draw_sky() -> void:
	var bands := 48
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, size.y * t, size.x, size.y / bands + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	# The undercity far below: a warm haze and its lights, the way the surface station looks down on it.
	LanternTownPainter.glow(self, Vector2(size.x * 0.4, size.y + 200), 1100.0, Color(DEEP_GLOW, 0.20))
	LanternTownPainter.glow(self, Vector2(size.x * 0.4, size.y + 60), 520.0, Color(DEEP_GLOW, 0.16))
	for i in 46:
		var x := fposmod(i * 263.7, size.x - 40.0) + 20.0
		var y := size.y - 40.0 - fposmod(i * 71.3, size.y * 0.22)
		var twinkle := 0.55 + 0.45 * sin(_time * (0.8 + fposmod(i * 0.37, 1.0)) + i)
		LanternTownPainter.glow(self, Vector2(x, y), 7.0, Color(DEEP_GLOW, 0.35 * twinkle))
		draw_circle(Vector2(x, y), 1.2, Color(DEEP_GLOW, 0.8 * twinkle))
	# Roots: far ones first, thin and dark, then nearer and thicker.
	for i in 14:
		var x := size.x * (0.02 + i * 0.071)
		var depth := 120.0 + fposmod(i * 157.0, 300.0)
		LanternTownPainter.root(
			self, Vector2(x, -20), Vector2(x + 18.0 * sin(i * 1.3), depth), 9.0 + (i % 4) * 2.0, _time * 0.4 + i, 0.7
		)
	for i in 7:
		var x := size.x * (0.06 + i * 0.13)
		var depth := 90.0 + fposmod(i * 113.0, 170.0)
		LanternTownPainter.root(
			self, Vector2(x, -20), Vector2(x - 12.0, depth), 22.0 + (i % 3) * 8.0, _time * 0.5 + i * 2.0
		)


func _draw_lanterns(house: Dictionary, at: Vector2) -> void:
	var lanterns: Array = house.lanterns
	var count := lanterns.size()
	for i in count:
		var lantern: Dictionary = lanterns[i]
		var x := at.x + (i - (count - 1) / 2.0) * 34.0
		var hook := Vector2(x, at.y + LanternTownPainter.HOUSE_SIZE.y / 2.0 + 14)
		var flicker := 0.5 + 0.5 * sin(_time * 7.0 + i * 1.7 + at.x)
		LanternTownPainter.lantern(self, hook, lantern.state, flicker, float(_pops.get(lantern.id, 1.0)))


func _label(font: Font, code_font: Font, at: Vector2, title: String, file: String, alpha: float) -> void:
	var y := at.y + LanternTownPainter.HOUSE_SIZE.y / 2.0 + 74
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(
		font, Vector2(at.x - width / 2.0, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiTheme.TEXT, alpha)
	)
	var file_width := code_font.get_string_size(file, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(
		code_font,
		Vector2(at.x - file_width / 2.0, y + 18),
		file,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(UiTheme.AMBER_DIM, alpha)
	)


func _draw_fireflies() -> void:
	var lit := 0
	for house: Dictionary in _layout.houses:
		for lantern: Dictionary in house.lanterns:
			if lantern.state == LanternRules.LIT:
				lit += 1
	for i in 4 + lit * 4:
		var phase := float(i) * 2.399
		var p := Vector2(
			area.position.x + fposmod(i * 211.0 + sin(_time * 0.3 + phase) * 60.0, area.size.x),
			area.position.y + fposmod(i * 97.0 + cos(_time * 0.25 + phase) * 40.0 - _time * 6.0, area.size.y)
		)
		var blink := 0.5 + 0.5 * sin(_time * 2.0 + phase * 3.0)
		LanternTownPainter.glow(self, p, 9.0, Color(LanternTownPainter.GLOW, 0.4 * blink))
		draw_circle(p, 1.6, Color(LanternTownPainter.GLOW, 0.9 * blink))


## Where a bridge between two houses is tied: the corner of each platform that faces the other house.
func _bridge_ends(a: Vector2, b: Vector2) -> Array[Vector2]:
	var half := LanternTownPainter.HOUSE_SIZE.x / 2.0 + 20.0
	var deck := LanternTownPainter.HOUSE_SIZE.y / 2.0 + 6.0
	var side := 1.0 if b.x >= a.x else -1.0
	return [a + Vector2(side * half, deck), b + Vector2(-side * half, deck)]


func _replace_house(house: Dictionary) -> void:
	var houses: Array = _layout.houses
	for i in houses.size():
		if houses[i].module == house.module:
			houses[i] = house
			return
	houses.append(house)


func _house_lit(module: String) -> float:
	for house: Dictionary in _layout.houses:
		if house.module == module:
			var lanterns: Array = house.lanterns
			if lanterns.is_empty():
				return 0.0
			var lit := lanterns.filter(func(l: Dictionary) -> bool: return l.state == LanternRules.LIT).size()
			return float(lit) / lanterns.size()
	return 0.0


func _house_at(point: Vector2) -> String:
	for house: Dictionary in _layout.houses:
		var at := _to_screen(house.at)
		var box := Rect2(at - Vector2(90, 100), Vector2(180, 230))
		if box.has_point(point):
			return String(house.module)
	return ""


func _to_screen(at: Vector2) -> Vector2:
	return area.position + at / 1000.0 * area.size


static func _state_mark(state: String) -> String:
	match state:
		LanternRules.LIT:
			return "✦"
		LanternRules.DARK:
			return "✖"
	return "○"
