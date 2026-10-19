class_name OptionsPage
extends Control
## The town's Options page, built from the player's own code (Concept/v0.4/01 section 8.3): the rows are what their
## options() gave (`{setting, label}`, in their order and their words), the volume sliders show what their volume() makes
## of each notch, and a small chart draws their whole curve beside them. The page decides nothing: it sends what the
## player changed, and the town saves it.
##
##   page.open(rows, {"music": 7, "sound": 5, "text_speed": "normal", "track": "Lanternroot", "fullscreen": false},
##       volume_at, curve)
##   page.changed.connect(func(setting, value): ...)   # "music"/"sound": notch int; "text_speed": "slow"|...; "fullscreen": bool
##
## `volume_at(notch)` is the player's loudness for a notch (a float), or -1.0 while their volume() is not built: the
## slider is then locked ("Seren's knob isn't wired yet"). `curve` is the eleven loudnesses, 0 to 1, for the chart.

## The player moved a control: setting ("music", "sound", "text_speed", "fullscreen") and its new value.
signal changed(setting: String, value: Variant)
## The "track" row's Choose... was pressed: the town opens the Music panel.
signal open_music
## "More settings..." was pressed: the town opens the title's full settings panel.
signal more_settings
signal closed

const NOTCHES := 10
const SETTINGS: Array[String] = ["music", "sound", "text_speed", "track", "fullscreen"]
const SPEEDS: Array[String] = ["slow", "normal", "fast"]
const LABEL_WIDTH := 210.0
const SLIDER_WIDTH := 250.0
const READOUT_WIDTH := 120.0
const CHART_SIZE := Vector2(220, 120)
const INK := PauseMenu.INK

var _open := false
var _rows: Array[Dictionary] = []
var _values: Dictionary = {}
var _volume_at: Callable
var _curve := PackedFloat32Array()
var _lit := 0
var _hush := false
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}
var _notes: Dictionary = {}
var _speeds: Dictionary = {}
var _track_title: Label
var _fullscreen: CheckButton
var _more: Button
var _card: PanelContainer
var _list: VBoxContainer
var _chart: Control
var _motion: Tween

static var _knobs: Dictionary = {}


func _ready() -> void:
	theme = OverworldStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style(Vector2(28, 20)))
	centre.add_child(_card)
	var heading := Ui.label(Text.t("Your options"), "Heading")
	heading.add_theme_color_override("font_color", UiTheme.AMBER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list = Ui.vbox([], 14)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart = _make_chart()
	var chart_box := Ui.vbox([_chart, PauseMenu.small(Text.t("Your volume curve"), true)], 6)
	chart_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_more = Ui.button(Text.t("More settings…"), more_settings.emit)
	PauseMenu.style_item(_more, OverworldStyle.LABEL, 18.0)
	_more.focus_entered.connect(Sound.play.bind("sfx-card-flick-1", 0.3))
	var help := PauseMenu.help_line(Text.t("Arrows: choose and change   Enter: pick   Esc: back"))
	var body := Ui.hbox([_list, PauseMenu.divider(), chart_box], 24)
	_card.add_child(
		Ui.vbox([heading, PauseMenu.rule(), body, PauseMenu.rule(), Ui.hbox([_more, Ui.spacer()], 0), help], 14)
	)


# --- opening and closing -------------------------------------------------------------------------------------------


func is_open() -> bool:
	return _open


## Opens over the town. `rows` are the player's `{setting, label}`; `values` is `{music, sound (notches 0 to 10),
## text_speed, track (the playing track's title), fullscreen}`; `volume_at` and `curve` are the player's volume().
func open(
	rows: Array[Dictionary], values: Dictionary, volume_at: Callable, curve: PackedFloat32Array = PackedFloat32Array()
) -> void:
	_rows = rows
	_values = values.duplicate()
	_volume_at = volume_at
	_curve = curve
	_build_rows()
	_open = true
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	_chart.queue_redraw()
	_focus_first()


func close() -> void:
	if not _open:
		return
	_open = false
	Sound.play("sfx-whiff", 0.3)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.fade_out(self, func() -> void: visible = _open)
	closed.emit()


## The track row's title changed (the Music panel played another): the page shows it.
func set_track_title(title: String) -> void:
	_values["track"] = title
	if _track_title != null:
		_track_title.text = title


func _focus_first() -> void:
	var first: Control = null
	for row in _rows:
		first = _control_of(String(row.setting))
		if first != null:
			break
	(first if first != null else _more).grab_focus()


## The control that takes the focus for a setting's row, or null when it is a locked slider or not on the page.
func _control_of(setting: String) -> Control:
	match setting:
		"music", "sound":
			var slider := _sliders.get(setting) as HSlider
			return slider if slider != null and slider.focus_mode != Control.FOCUS_NONE else null
		"text_speed":
			return _speeds.get(String(_values.get("text_speed", "normal"))) as Control
		"track":
			return _track_button
		"fullscreen":
			return _fullscreen
	return null


var _track_button: Button


# --- the rows ------------------------------------------------------------------------------------------------------


func _build_rows() -> void:
	Ui.clear(_list)
	_sliders.clear()
	_readouts.clear()
	_notes.clear()
	_speeds.clear()
	_track_title = null
	_track_button = null
	_fullscreen = null
	_lit = int(_values.get("music", 0))
	var made: Array[String] = []
	for row in _rows:
		var setting := String(row.get("setting", ""))
		if not setting in SETTINGS or setting in made:
			continue
		made.append(setting)
		var label := Ui.label(String(row.get("label", "")))
		label.add_theme_font_override("font", OverworldStyle.body_font(600))
		label.add_theme_color_override("font_color", INK)
		label.custom_minimum_size.x = LABEL_WIDTH
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var control: Control
		match setting:
			"music", "sound":
				control = _volume_row(setting)
			"text_speed":
				control = _speed_row()
			"track":
				control = _track_row()
			_:
				control = _fullscreen_row()
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := Ui.hbox([label, control], 18)
		line.name = "Row_" + setting
		_list.add_child(line)


func _loudness(notch: int) -> float:
	return float(_volume_at.call(notch)) if _volume_at.is_valid() else -1.0


func _volume_row(setting: String) -> Control:
	var slider := HSlider.new()
	slider.name = "Slider_" + setting
	slider.min_value = 0
	slider.max_value = NOTCHES
	slider.step = 1
	slider.tick_count = NOTCHES + 1
	slider.ticks_on_borders = true
	slider.scrollable = true
	slider.set_value_no_signal(clampi(int(_values.get(setting, 0)), 0, NOTCHES))
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 34)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_constant_override("center_grabber", 1)
	slider.add_theme_icon_override("grabber", _knob(UiTheme.AMBER_DIM))
	slider.add_theme_icon_override("grabber_highlight", _knob(UiTheme.AMBER))
	slider.add_theme_icon_override("grabber_disabled", _knob(UiTheme.FAINT))
	slider.add_theme_icon_override("tick", _tick())
	slider.add_theme_stylebox_override("slider", UiTheme.box(Color("#0c0907"), UiTheme.LINE, 1, 4, Vector2(0, 5)))
	slider.add_theme_stylebox_override("grabber_area", UiTheme.box(UiTheme.AMBER_DIM, Color.TRANSPARENT, 0, 4, Vector2(0, 5)))
	slider.add_theme_stylebox_override("grabber_area_highlight", UiTheme.box(UiTheme.AMBER, Color.TRANSPARENT, 0, 4, Vector2(0, 5)))
	var readout := Ui.label("")
	readout.custom_minimum_size.x = READOUT_WIDTH
	readout.add_theme_color_override("font_color", UiTheme.AMBER)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var note := PauseMenu.small(Text.t("Seren's knob isn't wired yet"), true)
	note.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	note.visible = false
	_sliders[setting] = slider
	_readouts[setting] = readout
	_notes[setting] = note
	if _loudness(int(slider.value)) < 0.0:
		# Not built: the knob is drawn, and it will not turn.
		slider.editable = false
		slider.focus_mode = Control.FOCUS_NONE
		slider.mouse_default_cursor_shape = Control.CURSOR_ARROW
		slider.modulate = Color(1, 1, 1, 0.55)
		note.visible = true
		readout.text = String("%d" % int(slider.value))
	else:
		_show_notch(setting)
		slider.value_changed.connect(_on_slider.bind(setting))
		slider.focus_entered.connect(_on_slider_focus.bind(setting))
	return Ui.vbox([Ui.hbox([slider, readout], 12), note], 2)


## The readout of a volume row: "7 → 49%".
func _show_notch(setting: String) -> void:
	var slider := _sliders[setting] as HSlider
	var loudness := _loudness(int(slider.value))
	(_readouts[setting] as Label).text = Text.f("%d → %d%%", [int(slider.value), roundi(loudness * 100.0)])


func _on_slider(value: float, setting: String) -> void:
	_values[setting] = int(value)
	_lit = int(value)
	_show_notch(setting)
	_chart.queue_redraw()
	changed.emit(setting, int(value))


func _on_slider_focus(setting: String) -> void:
	_lit = int((_sliders[setting] as HSlider).value)
	_chart.queue_redraw()
	if _open:
		Sound.play("sfx-card-flick-1", 0.3)


func _speed_row() -> Control:
	var current := String(_values.get("text_speed", "normal"))
	var words := {"slow": Text.t("Slow"), "normal": Text.t("Normal"), "fast": Text.t("Fast")}
	var line := Ui.hbox([], 8)
	for speed in SPEEDS:
		var button := Ui.choice(String(words[speed]), speed == current, _on_speed.bind(speed))
		button.name = "Speed_" + speed
		button.custom_minimum_size = Vector2(100, 40)
		_speeds[speed] = button
		line.add_child(button)
	return line


func _on_speed(speed: String) -> void:
	_values["text_speed"] = speed
	for other: String in _speeds:
		var button := _speeds[other] as Button
		button.set_pressed_no_signal(other == speed)
		button.theme_type_variation = "PrimaryButton" if other == speed else ""
	changed.emit("text_speed", speed)


func _track_row() -> Control:
	_track_title = Ui.label(String(_values.get("track", "")))
	_track_title.add_theme_color_override("font_color", UiTheme.AMBER)
	_track_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_track_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_track_button = Ui.button(Text.t("Choose…"), open_music.emit)
	_track_button.custom_minimum_size = Vector2(0, 40)
	return Ui.hbox([_track_title, _track_button], 12)


func _fullscreen_row() -> Control:
	_fullscreen = CheckButton.new()
	_fullscreen.name = "Fullscreen"
	_fullscreen.focus_mode = Control.FOCUS_ALL
	_fullscreen.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fullscreen.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["checked", "checked_mirrored"]:
		_fullscreen.add_theme_icon_override(state, _switch(true))
	for state: String in ["unchecked", "unchecked_mirrored"]:
		_fullscreen.add_theme_icon_override(state, _switch(false))
	_fullscreen.add_theme_icon_override("checked_disabled", _switch(true))
	_fullscreen.add_theme_icon_override("unchecked_disabled", _switch(false))
	_fullscreen.set_pressed_no_signal(bool(_values.get("fullscreen", false)))
	_fullscreen.text = Text.t("On") if _fullscreen.button_pressed else Text.t("Off")
	_fullscreen.toggled.connect(_on_fullscreen)
	return _fullscreen


func _on_fullscreen(on: bool) -> void:
	_values["fullscreen"] = on
	_fullscreen.text = Text.t("On") if on else Text.t("Off")
	changed.emit("fullscreen", on)


# --- looking at it (for tests and the town) ------------------------------------------------------------------------------


## The volume slider of "music" or "sound", or null when that row is not on the page.
func slider(setting: String) -> HSlider:
	return _sliders.get(setting) as HSlider


## Whether a volume row is locked because the player's volume() is not built.
func is_locked(setting: String) -> bool:
	var found := _sliders.get(setting) as HSlider
	return found != null and not found.editable


## The words beside a volume slider ("7 → 49%").
func readout(setting: String) -> String:
	var found := _readouts.get(setting) as Label
	return found.text if found != null else ""


## The notch the chart lights.
func lit_notch() -> int:
	return _lit


## The settings on the page, in order.
func shown_settings() -> Array[String]:
	var out: Array[String] = []
	for line in _list.get_children():
		out.append(String(line.name).trim_prefix("Row_"))
	return out


func speed_button(speed: String) -> Button:
	return _speeds.get(speed) as Button


func more_button() -> Button:
	return _more


func label_of(setting: String) -> String:
	var line := _list.get_node_or_null("Row_" + setting)
	return (line.get_child(0) as Label).text if line != null else ""


# --- the chart -----------------------------------------------------------------------------------------------------


func _make_chart() -> Control:
	var chart := Control.new()
	chart.name = "Chart"
	chart.custom_minimum_size = CHART_SIZE
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.draw.connect(_draw_chart)
	return chart


func _draw_chart() -> void:
	var size := _chart.size
	UiTheme.box(OverworldStyle.WELL_FILL, UiTheme.LINE, 1, 8).draw(_chart.get_canvas_item(), Rect2(Vector2.ZERO, size))
	var plot := Rect2(Vector2(14, 12), size - Vector2(28, 28))
	var grid := Color(UiTheme.AMBER_DIM, 0.3)
	for part: float in [0.0, 0.5, 1.0]:
		var y := plot.end.y - plot.size.y * part
		_chart.draw_dashed_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), grid, 1.0, 4.0)
	_chart.draw_line(plot.position, Vector2(plot.position.x, plot.end.y), grid, 1.0)
	if _curve.size() != NOTCHES + 1:
		# Not built yet: a faint guess, drawn dashed, says what a curve will look like.
		_chart.draw_dashed_line(Vector2(plot.position.x, plot.end.y), plot.position + Vector2(plot.size.x, 0), Color(UiTheme.FAINT, 0.8), 2.0, 6.0)
		return
	var points := PackedVector2Array()
	for notch in _curve.size():
		var at := Vector2(plot.position.x + plot.size.x * notch / float(NOTCHES), plot.end.y - plot.size.y * clampf(_curve[notch], 0.0, 1.0))
		points.append(at)
	_chart.draw_polyline(points, UiTheme.AMBER_DIM, 3.0, true)
	for notch in points.size():
		_chart.draw_circle(points[notch], 3.0, UiTheme.AMBER_DIM)
	var lit := clampi(_lit, 0, NOTCHES)
	var spot := points[lit]
	_chart.draw_line(Vector2(spot.x, plot.end.y), spot, Color(UiTheme.AMBER, 0.5), 1.5)
	_chart.draw_circle(spot, 9.0, Color(UiTheme.AMBER, 0.25))
	_chart.draw_circle(spot, 5.5, UiTheme.AMBER)
	_chart.draw_circle(spot, 2.5, Color("#fff2cf"))
	var font := OverworldStyle.body_font(600)
	_chart.draw_string(font, Vector2(plot.position.x - 4, size.y - 3), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, OverworldStyle.MUTED)
	_chart.draw_string(font, Vector2(plot.end.x - 14, size.y - 3), "10", HORIZONTAL_ALIGNMENT_RIGHT, 24, 14, OverworldStyle.MUTED)


## A round slider knob, drawn once: a ring of dark ink around `colour`.
static func _knob(colour: Color) -> Texture2D:
	if _knobs.has(colour):
		return _knobs[colour]
	var side := 30
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var middle := (side - 1) / 2.0
	for y in side:
		for x in side:
			var away := Vector2(x, y).distance_to(Vector2(middle, middle))
			var outer := clampf(middle + 0.5 - away, 0.0, 1.0)
			var inner := clampf(middle - 3.5 - away, 0.0, 1.0)
			var shade := Color("#2a1a0c").lerp(colour, inner)
			image.set_pixel(x, y, Color(shade.r, shade.g, shade.b, outer))
	var texture := ImageTexture.create_from_image(image)
	_knobs[colour] = texture
	return texture


## An on/off switch, drawn once: an amber pill with its knob to the right when on, a dark one with the knob left when off.
static func _switch(on: bool) -> Texture2D:
	var key := "switch-on" if on else "switch-off"
	if _knobs.has(key):
		return _knobs[key]
	var width := 52
	var height := 28
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var back := UiTheme.AMBER_DIM if on else Color("#0c0907")
	var edge := UiTheme.AMBER if on else UiTheme.LINE
	var knob := Color("#fff2cf") if on else UiTheme.MUTED
	var knob_at := Vector2(width - 14.0, 14.0) if on else Vector2(14.0, 14.0)
	for y in height:
		for x in width:
			# A pill: the distance to the segment between the two end centres.
			var along := clampf(x + 0.5, 14.0, width - 14.0)
			var away := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(along, 14.0))
			var outer := clampf(14.0 - away + 0.5, 0.0, 1.0)
			var inner := clampf(12.0 - away + 0.5, 0.0, 1.0)
			var colour := edge.lerp(back, inner)
			var dot := clampf(9.0 - Vector2(x + 0.5, y + 0.5).distance_to(knob_at) + 0.5, 0.0, 1.0)
			colour = colour.lerp(knob, dot)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b, outer))
	var texture := ImageTexture.create_from_image(image)
	_knobs[key] = texture
	return texture


static func _tick() -> Texture2D:
	if _knobs.has("tick"):
		return _knobs["tick"]
	var image := Image.create(2, 10, false, Image.FORMAT_RGBA8)
	image.fill(Color(UiTheme.AMBER_DIM, 0.5))
	var texture := ImageTexture.create_from_image(image)
	_knobs["tick"] = texture
	return texture


# --- input ---------------------------------------------------------------------------------------------------------


## While the page is open nothing reaches the town. Esc, B or Start goes back.
func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var start := event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if event.is_action_pressed("ui_cancel") or start:
		close()
		return
	if get_viewport().gui_get_focus_owner() == null:
		_focus_first()
