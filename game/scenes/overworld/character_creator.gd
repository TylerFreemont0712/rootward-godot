class_name CharacterCreator
extends Control
## Name a tinker, choose the male or female character, and choose Builder or Scribe. Each model has one complete
## authored sprite sheet. Appearance part and color controls are retired until a future customization pass.

signal done(look: Dictionary, chosen_name: String)
signal cancelled

const PREVIEW_ZOOM := 3.0
const NAME_LENGTH := 12
const GRASS := Color("#7fbf55")
const GRASS_EDGE := Color("#3f7040")

var look: Dictionary = {"model": "male"}
var options: Dictionary = {}
var style := OverworldState.BUILDER
var can_cancel := false
var japanese_reading := "hiragana"

var _panel: PanelContainer
var _name: LineEdit
var _name_shown: Label
var _preview: WalkPreview
var _model_buttons: Dictionary = {}
var _style_buttons: Dictionary = {}
var _reading_buttons: Dictionary = {}
var _previous_reading := "hiragana"
var _style_line: Label
var _help: Label
var _pad := false
var _closing := false


func _ready() -> void:
	theme = OverworldStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.08, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


static func label_of(id: String, labels: Dictionary = {}, translated := true) -> String:
	var english := String(labels.get(id, id.capitalize()))
	return Text.t(english) if translated else english


func open(
	choices: Dictionary, start_look: Dictionary = {}, start_name := "", start_style := OverworldState.BUILDER
) -> void:
	options = choices
	var from: Dictionary = start_look if not start_look.is_empty() else choices.get("start", {})
	look = {"model": OverworldArt.player_model(from)}
	style = OverworldState.SCRIBE if start_style == OverworldState.SCRIBE else OverworldState.BUILDER
	_previous_reading = Text.japanese_reading()
	japanese_reading = _previous_reading
	_closing = false
	_build()
	_name.text = start_name
	_name_changed(start_name)
	_refresh_model()
	_refresh_style()
	_refresh_reading()
	_refresh_help()
	FrontPanel.reveal(self, _panel)
	_name.grab_focus.call_deferred()


func _build() -> void:
	for child in get_children():
		if child is not ColorRect:
			remove_child(child)
			child.queue_free()
	_model_buttons.clear()
	_style_buttons.clear()
	_reading_buttons.clear()
	var column := Ui.vbox([], 18)
	_panel = FrontPanel.panel(column)
	var box := FrontPanel.box()
	box.bg_color.a = 1.0
	_panel.add_theme_stylebox_override("panel", box)
	FrontPanel.centre(self, _panel)
	column.add_child(FrontPanel.heading(Text.t("Who are you?")))
	column.add_child(FrontPanel.small(Text.t("The new tinker of Lanternroot. Make yourself!")))
	column.add_child(Ui.hbox([_left_column(), _right_column()], 36))
	column.add_child(_footer())


func _left_column() -> Control:
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(GRASS, GRASS_EDGE, 3, 12, Vector2(30, 20)))
	_preview = WalkPreview.new()
	_preview.zoom = PREVIEW_ZOOM
	stage.add_child(_preview)
	_name_shown = Ui.label("", "Subheading")
	_name_shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_shown.clip_text = true
	_name_shown.custom_minimum_size.x = 240
	return Ui.vbox([stage, _name_shown], 12)


func _right_column() -> Control:
	_name = LineEdit.new()
	_name.placeholder_text = Text.t("Your name")
	_name.max_length = NAME_LENGTH
	_name.custom_minimum_size = Vector2(460, 0)
	_name.text_changed.connect(_name_changed)
	_name.text_submitted.connect(func(_text: String) -> void: (_model_buttons[String(look.model)] as Button).grab_focus())
	var models := Ui.hbox([], 12)
	var labels: Dictionary = options.get("labels", {})
	for id: String in ["male", "female"]:
		var button := Ui.button(label_of(id, labels), _choose_model.bind(id))
		button.custom_minimum_size = Vector2(220, 62)
		_model_buttons[id] = button
		models.add_child(button)
	var column := Ui.vbox([
		Ui.label(Text.t("Name"), "Muted"), _name,
		Ui.spacer(0, 10), Ui.label(Text.t("Character"), "Muted"), models,
		Ui.spacer(0, 18), _style_row(),
	], 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Text.japanese():
		column.add_child(_reading_row())
	return column


func _reading_row() -> Control:
	var row := Ui.hbox([], 12)
	for mode: String in ["hiragana", "kanji"]:
		var button := Ui.button(Text.t("Hiragana") if mode == "hiragana" else Text.t("Kanji"), _choose_reading.bind(mode))
		button.custom_minimum_size = Vector2(220, 50)
		_reading_buttons[mode] = button
		row.add_child(button)
	return Ui.vbox([
		Ui.label(Text.t("Japanese reading"), "Muted"), row,
		FrontPanel.small(Text.t("Choose hiragana or standard Japanese with kanji. You can change this in Settings anytime."), true),
	], 8)


func _choose_reading(mode: String) -> void:
	if mode not in ["hiragana", "kanji"] or mode == japanese_reading:
		return
	japanese_reading = mode
	var chosen_name := _name.text
	Text.set_japanese_reading(mode)
	# LEARN: rebuild translated copy from English, retaining the unfinished character and the exact typed name.
	_build()
	_name.text = chosen_name
	_name_changed(chosen_name)
	_refresh_model()
	_refresh_style()
	_refresh_reading()
	_refresh_help()
	(_reading_buttons[mode] as Button).grab_focus.call_deferred()


func _refresh_reading() -> void:
	for mode: String in _reading_buttons:
		(_reading_buttons[mode] as Button).theme_type_variation = "PrimaryButton" if mode == japanese_reading else ""


func _style_row() -> Control:
	var row := Ui.hbox([], 12)
	for id: String in [OverworldState.BUILDER, OverworldState.SCRIBE]:
		var text := Text.t("Builder: blocks") if id == OverworldState.BUILDER else Text.t("Scribe: type code")
		var button := Ui.button(text, _choose_style.bind(id))
		button.custom_minimum_size = Vector2(220, 58)
		_style_buttons[id] = button
		row.add_child(button)
	_style_line = FrontPanel.small("", true)
	_style_line.custom_minimum_size.x = 460
	return Ui.vbox([Ui.label(Text.t("How do you build?"), "Muted"), row, _style_line], 10)


func _footer() -> Control:
	var back := FrontPanel.button(Text.t("Back"), _cancel)
	back.visible = can_cancel
	_help = FrontPanel.keys("")
	_help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var finish := FrontPanel.button(Text.t("That's me!  ▶"), _finish, "PrimaryButton")
	finish.custom_minimum_size.x = 230
	return Ui.hbox([back, _help, finish], 20)


func _choose_model(model: String) -> void:
	look = {"model": model}
	FrontPanel.moved()
	_refresh_model()


func _refresh_model() -> void:
	for id: String in _model_buttons:
		(_model_buttons[id] as Button).theme_type_variation = "PrimaryButton" if id == String(look.model) else ""
	_preview.set_look(look)


func preview_sheet() -> CharacterSheet:
	return _preview.figure() if _preview != null else null


func _choose_style(id: String) -> void:
	style = id
	FrontPanel.moved()
	_refresh_style()


func _refresh_style() -> void:
	for id: String in _style_buttons:
		(_style_buttons[id] as Button).theme_type_variation = "PrimaryButton" if id == style else ""
	_style_line.text = (
		Text.t("Snap blocks together, and see the code they make beside them.")
		if style == OverworldState.BUILDER else Text.t("Type the code yourself, the way programmers do.")
	)


func _name_changed(text: String) -> void:
	var chosen := text.strip_edges()
	_name_shown.text = chosen if chosen != "" else Text.t("Tinker")


func _finish() -> void:
	if _closing:
		return
	_closing = true
	var chosen := _name.text.strip_edges()
	FrontPanel.confirmed()
	done.emit(look.duplicate(true), chosen if chosen != "" else Text.t("Tinker"))
	FrontPanel.conceal(self)


func _cancel() -> void:
	if _closing or not can_cancel:
		return
	_closing = true
	FrontPanel.cancelled()
	Text.set_japanese_reading(_previous_reading)
	cancelled.emit()
	FrontPanel.conceal(self)


func _refresh_help() -> void:
	if _help != null:
		_help.text = Text.t("D-pad: choose   A: press   B: back") if _pad else Text.t("Arrows: choose   Enter: press   Esc: back")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pad := event is InputEventJoypadButton or (
		event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5
	)
	if (pad or event is InputEventKey) and pad != _pad:
		_pad = pad
		_refresh_help()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	var pad := FrontPanel.pad_button(event)
	if FrontPanel.is_back(event):
		_cancel()
	elif pad == JOY_BUTTON_START:
		_finish()
	elif pad == JOY_BUTTON_A:
		FrontPanel.press_focused(get_viewport())
	else:
		return
	get_viewport().set_input_as_handled()
