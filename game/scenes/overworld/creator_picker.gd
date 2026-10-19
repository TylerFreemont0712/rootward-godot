class_name CreatorPicker
extends PanelContainer
## One row of the character creator (ADR-0061): a name, then either a part shown between two arrows ("◀ Bun ▶") or a
## row of colour swatches. The whole row takes focus, so a keyboard or a pad moves up and down between rows and left
## and right through the choices; a mouse clicks the arrows or a swatch. Says `changed` with the new choice.
##
##   var hair := CreatorPicker.parts(Text.t("Style"), looks.hair, "hair/bun", namer)
##   var colour := CreatorPicker.colours(Text.t("Colour"), looks.hair_colour, "hair_brown", namer)

signal changed(value: String)

const NAME_WIDTH := 160.0
const SWATCH := 40.0

var choices: Array[String] = []
var value := ""
var is_colour := false

var _title := ""
## Turns a choice's id into the words shown for it.
var _namer: Callable
var _shown: Label
var _swatches: Dictionary = {}
var _normal: StyleBoxFlat
var _focused: StyleBoxFlat


static func parts(title: String, options: Array, chosen: String, namer: Callable) -> CreatorPicker:
	return _make(title, options, chosen, namer, false)


static func colours(title: String, ramps: Array, chosen: String, namer: Callable) -> CreatorPicker:
	return _make(title, ramps, chosen, namer, true)


static func _make(title: String, options: Array, chosen: String, namer: Callable, colour: bool) -> CreatorPicker:
	var picker := CreatorPicker.new()
	picker._title = title
	for option: Variant in options:
		picker.choices.append(String(option))
	picker.value = chosen
	picker._namer = namer
	picker.is_colour = colour
	picker._build()
	return picker


func _build() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_normal = UiTheme.box(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), 0, 10, Vector2(14, 6))
	_focused = UiTheme.box(Color(UiTheme.AMBER, 0.12), UiTheme.AMBER, 3, 10, Vector2(14, 6))
	add_theme_stylebox_override("panel", _normal)
	focus_entered.connect(func() -> void: add_theme_stylebox_override("panel", _focused))
	focus_exited.connect(func() -> void: add_theme_stylebox_override("panel", _normal))
	var name_label := Ui.label(_title)
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	name_label.add_theme_color_override("font_color", OverworldStyle.MUTED)
	name_label.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	var row := Ui.hbox([name_label], 10)
	if is_colour:
		var strip := Ui.hbox([], 6)
		for ramp in choices:
			strip.add_child(_swatch(ramp))
		row.add_child(strip)
		_shown = Ui.label("")
		_shown.add_theme_color_override("font_color", OverworldStyle.MUTED)
		_shown.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
		row.add_child(_shown)
	else:
		_shown = Ui.label("")
		_shown.custom_minimum_size = Vector2(300, 0)
		_shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shown.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
		row.add_child(_arrow("◀", -1))
		row.add_child(_shown)
		row.add_child(_arrow("▶", 1))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_refresh()


func _arrow(glyph: String, by: int) -> Button:
	var arrow := Ui.button(glyph, _clicked.bind(by))
	arrow.focus_mode = Control.FOCUS_NONE
	arrow.custom_minimum_size = Vector2(52, 48)
	return arrow


func _swatch(ramp: String) -> Button:
	var shades := OverworldArt.ramp(ramp)
	var colour := shades[1] if shades.size() > 1 else (shades[0] if not shades.is_empty() else Color.GRAY)
	var swatch := Button.new()
	swatch.focus_mode = Control.FOCUS_NONE
	swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
	swatch.tooltip_text = String(_namer.call(ramp))
	swatch.add_theme_stylebox_override("normal", UiTheme.box(colour, Color("#2a1d2b"), 2, 8))
	swatch.add_theme_stylebox_override("hover", UiTheme.box(colour, UiTheme.AMBER_DIM, 3, 8))
	swatch.add_theme_stylebox_override("pressed", UiTheme.box(colour, UiTheme.AMBER, 3, 8))
	swatch.pressed.connect(_pick.bind(ramp))
	_swatches[ramp] = {"button": swatch, "colour": colour}
	return swatch


## Shows `chosen` without saying `changed` (the creator setting every row at once, as Surprise me does).
func show_value(chosen: String) -> void:
	value = chosen
	_refresh()


## Moves through the choices by `by`, round the ends, and says `changed`.
func step(by: int) -> void:
	if choices.is_empty():
		return
	var at := choices.find(value)
	if at < 0:
		_pick(choices[0] if by > 0 else choices[-1])
		return
	_pick(choices[posmod(at + by, choices.size())])


func _clicked(by: int) -> void:
	grab_focus()
	step(by)


func _pick(chosen: String) -> void:
	value = chosen
	_refresh()
	changed.emit(value)


func _refresh() -> void:
	if _shown != null:
		_shown.text = String(_namer.call(value))
	for ramp: String in _swatches:
		var entry: Dictionary = _swatches[ramp]
		var swatch := entry.button as Button
		var colour: Color = entry.colour
		var chosen := ramp == value
		# The chosen swatch wears a thick light ring and stands a little apart from its neighbours.
		swatch.add_theme_stylebox_override(
			"normal", UiTheme.box(colour, Color("#fff3d6") if chosen else Color("#2a1d2b"), 4 if chosen else 2, 8)
		)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left", true):
		step(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		step(1)
		accept_event()
