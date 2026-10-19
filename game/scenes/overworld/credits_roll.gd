class_name CreditsRoll
extends Control
## The credits (Concept/v0.4/01 section 5.10): the player's own lines, in their order, roll up the night sky over the Lantern
## Root's dark shape, with fireflies drifting and the title music playing. Afterwards a card says "Lanternroot, made by
## <name>" and the roll is over. Any key speeds it up while it is held, and Esc skips to the card.
##
##   credits.roll(lines, "Kai")      # lines: what the player's credits() gave
##   credits.finished.connect(...)   # the card has been read (or skipped): the town takes over again

signal finished

## Pixels a second the lines rise, and how much faster a held key makes them.
const SPEED := 70.0
const FAST := 5.0
## How long the card stays, and how long before a key may close it.
const CARD_TIME := 4.0
const CARD_WAIT := 0.6
const FADE_BAND := 170.0
const NIGHT_TOP := Color("#070b1c")
const NIGHT_BOTTOM := Color("#1b1f3f")
const FIREFLIES := 46
const INK := PauseMenu.INK

## How long the card holds before it finishes by itself; tests make it short.
var card_time := CARD_TIME

var _rolling := false
var _card_shown := false
var _fast := false
var _offset := 0.0
var _held := 0.0
var _maker := ""
var _column: VBoxContainer
var _lines: Array[Label] = []
var _card: PanelContainer
var _fireflies: Array[Dictionary] = []
var _time := 0.0
var _tree: Texture2D
var _motion: Tween


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style(Vector2(56, 34)))
	_card.visible = false
	centre.add_child(_card)
	_tree = OverworldArt.building("lanterntree")
	var dice := RandomNumberGenerator.new()
	dice.seed = 20261015
	for i in FIREFLIES:
		_fireflies.append(
			{
				"at": Vector2(dice.randf(), dice.randf()),
				"drift": Vector2(dice.randf_range(-0.012, 0.012), dice.randf_range(-0.03, -0.006)),
				"phase": dice.randf() * TAU,
				"rate": dice.randf_range(0.6, 1.6),
				"glow": dice.randf_range(0.7, 1.4),
			}
		)


func is_rolling() -> bool:
	return _rolling


## Whether the closing card is on show.
func card_shown() -> bool:
	return _card_shown


## Starts the roll. `lines` is what the player's credits() gave (the first line is the title, shown large; an empty
## line is a gap) and `maker` the name on the closing card.
func roll(lines: Array[String], maker: String) -> void:
	_maker = maker
	_rolling = true
	_card_shown = false
	_fast = false
	_held = 0.0
	_offset = 0.0
	_time = 0.0
	Ui.clear(_column)
	_lines.clear()
	for index in lines.size():
		_column.add_child(_line(lines[index], index == 0))
	_column.reset_size()
	_card.visible = false
	Ui.clear(_card)
	_card.add_child(_card_body())
	_place()
	visible = true
	modulate.a = 0.0
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = create_tween()
	_motion.tween_property(self, "modulate:a", 1.0, 1.2)
	Sound.music("music-title")
	grab_focus()


func _line(text: String, first: bool) -> Control:
	if text == "":
		return Ui.spacer(0, 36)
	var label := Ui.label(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if first:
		label.add_theme_font_override("font", OverworldStyle.body_font(600))
		label.add_theme_font_size_override("font_size", 76)
		label.add_theme_color_override("font_color", UiTheme.AMBER)
		label.add_theme_constant_override("outline_size", 0)
	else:
		label.add_theme_font_size_override("font_size", 38)
		label.add_theme_color_override("font_color", INK)
	_lines.append(label)
	return label


func _card_body() -> Control:
	var words := Ui.label(Text.f("Lanternroot, made by %s", [_maker]), "Heading")
	words.add_theme_font_size_override("font_size", 50)
	words.add_theme_color_override("font_color", UiTheme.AMBER)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := PauseMenu.small(Text.t("Thank you for playing."))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return Ui.vbox([words, PauseMenu.rule(), hint], 14)


## Puts the lines where the roll has carried them: below the screen at the start, above it at the end.
func _place() -> void:
	_column.size.x = size.x
	_column.position = Vector2(0.0, size.y - _offset)


## Skips to the closing card (Esc).
func skip() -> void:
	if not _rolling or _card_shown:
		return
	_offset = size.y + _column.size.y + 40.0
	_place()
	_show_card()


## A speed-up for the roll: held keys do this; a test or a pad may too.
func speed_up(on: bool) -> void:
	_fast = on


func _show_card() -> void:
	_card_shown = true
	_held = 0.0
	_column.visible = false
	_card.visible = true
	_card.modulate.a = 0.0
	_card.create_tween().tween_property(_card, "modulate:a", 1.0, 0.9)
	Sound.play("sfx-chime", 0.5)


func _finish() -> void:
	if not _rolling:
		return
	_rolling = false
	_card_shown = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: visible = _rolling)
	finished.emit()


# --- time ----------------------------------------------------------------------------------------------------------


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for fly in _fireflies:
		var at: Vector2 = fly.at + (fly.drift as Vector2) * delta
		at.x = fposmod(at.x + 0.03 * sin(_time * 0.4 + float(fly.phase)) * delta, 1.0)
		at.y = fposmod(at.y, 1.0)
		fly.at = at
	if _rolling and not _card_shown:
		_offset += SPEED * (FAST if _fast else 1.0) * delta
		_place()
		_fade_lines()
		if _offset >= size.y + _column.size.y + 40.0:
			_show_card()
	elif _rolling:
		_held += delta
		if _held >= card_time:
			_finish()
	queue_redraw()


## Lines fade in at the bottom of the screen and out at the top, so they come and go out of the dark.
func _fade_lines() -> void:
	for label in _lines:
		var middle := _column.position.y + label.position.y + label.size.y / 2.0
		label.modulate.a = clampf(minf(middle, size.y - middle) / FADE_BAND, 0.0, 1.0)


# --- looking -------------------------------------------------------------------------------------------------------


func _draw() -> void:
	var colours := PackedColorArray([NIGHT_TOP, NIGHT_TOP, NIGHT_BOTTOM, NIGHT_BOTTOM])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]), colours)
	if _tree != null:
		# The Lantern Root, a dark shape against the sky: darkened and a little blue, big and low.
		var side := minf(size.y * 1.05, size.x * 0.8)
		var at := Vector2((size.x - side) / 2.0, size.y - side * 0.94)
		draw_texture_rect(_tree, Rect2(at, Vector2(side, side)), false, Color(0.09, 0.11, 0.24, 0.5))
	for fly in _fireflies:
		var pulse := 0.5 + 0.5 * sin(_time * float(fly.rate) * 1.8 + float(fly.phase))
		var spot := (fly.at as Vector2) * size
		var scale := float(fly.glow)
		draw_circle(spot, 16.0 * scale, Color(1.0, 0.85, 0.4, 0.05 + 0.07 * pulse))
		draw_circle(spot, 8.0 * scale, Color(1.0, 0.88, 0.45, 0.12 + 0.16 * pulse))
		draw_circle(spot, 3.0 * scale, Color(1.0, 0.95, 0.7, 0.55 + 0.45 * pulse))


func _gui_input(event: InputEvent) -> void:
	_on_input(event)


func _unhandled_input(event: InputEvent) -> void:
	_on_input(event)


## Esc skips to the card; any other key speeds the roll while it is held; on the card a key (after a moment) ends it.
func _on_input(event: InputEvent) -> void:
	if not _rolling:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		return
	accept_event()
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	var down := (
		(event as InputEventKey).pressed
		if event is InputEventKey
		else (event as InputEventJoypadButton).pressed
		if event is InputEventJoypadButton
		else (event as InputEventMouseButton).pressed
	)
	if _card_shown:
		if down and _held >= CARD_WAIT:
			_finish()
		return
	if not down:
		_fast = false
		return
	if event.is_action_pressed("ui_cancel"):
		skip()
		return
	_fast = true
