class_name ThingEditor
extends Control
## Where the player writes a thing's code (ADR-0061, TownThings): the function the thing runs when Space is pressed on
## it, typed in the code panel (BootsCodePanel, Scribe). "Run" (or Ctrl+Enter) hands the code to the town, which runs it
## exactly as Space does, and what came back is said here. Closing (Esc, or B on a pad) keeps the code typed.
##
##   editor.open(title, hint, caption, source, language)
##   run_asked(source)     the player pressed Run
##   closed(source)        the editor closed, with the code in it
##   report(text, ok)      what the town found, in green (ok) or in red

signal run_asked(source: String)
signal closed(source: String)

const PANEL_SIZE := Vector2(1180, 720)
const SHADE := Color(0.04, 0.03, 0.05, 0.6)
const HINT_COLOUR := Color("#d6f57a")

var _panel: PanelContainer
var _title: Label
var _hint: Label
var _caption: Label
var _code: BootsCodePanel
var _result: Label
var _run: Button


func _ready() -> void:
	theme = OverworldStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", OverworldStyle.panel_box())
	_panel.custom_minimum_size = PANEL_SIZE
	centre.add_child(_panel)
	_code = BootsCodePanel.new(true)
	_panel.add_child(Ui.vbox([_header(), _guide(), _code, _footer()], 16))


## Opens on `source` in `language`: the thing's name over its code, Hotaru's nudge in green, and what the code may
## change.
func open(title: String, hint: String, caption: String, source: String, language: String) -> void:
	_title.text = title
	_hint.text = hint
	_hint.visible = hint != ""
	_caption.text = caption
	_code.set_language(language, Text.t("Type your code here. Ctrl+Enter runs it."))
	_code.show_code(source)
	report("", true)
	visible = true
	OverworldStyle.pop_in(self, _panel)
	_focus_code.call_deferred()


## What the town found when the code ran: green when it went well, red when something went wrong.
func report(text: String, ok: bool) -> void:
	_result.text = text
	_result.add_theme_color_override("font_color", UiTheme.PASS if ok else UiTheme.FAIL)


# --- the layout -------------------------------------------------------------------------------------------------------


## The thing's name and Close.
func _header() -> Control:
	_title = Ui.label("", "Heading")
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close := Ui.button(Text.t("Close"), _close)
	close.custom_minimum_size = Vector2(120, 0)
	return Ui.hbox([_title, Ui.spacer(), close], 14)


## Hotaru's nudge in green, and under it what the code may change.
func _guide() -> Control:
	_hint = Ui.label("", "", true)
	_hint.add_theme_color_override("font_color", HINT_COLOUR)
	_caption = Ui.label("", "Muted", true)
	return Ui.vbox([_hint, _caption], 4)


## What the town found, beside Run.
func _footer() -> Control:
	_result = Ui.label("", "", true)
	_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result.custom_minimum_size = Vector2(0, 64)
	_run = Ui.button(Text.t("Run  ▶"), _run_code, "PrimaryButton")
	_run.tooltip_text = Text.t("Ctrl+Enter")
	_run.custom_minimum_size = Vector2(250, 64)
	_run.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.hbox([_result, _run], 18)


func _focus_code() -> void:
	if visible:
		_code.editor.grab_focus()


# --- running and closing ----------------------------------------------------------------------------------------------


## Run: the code as it stands goes to the town, which runs it as Space would.
func _run_code() -> void:
	if not visible:
		return
	report(Text.t("Trying it..."), true)
	Sound.play("sfx-card-place-1", 0.4)
	run_asked.emit(_code.editor.text)


## Close keeps the code: the town saves it, so the next opening starts from it.
func _close() -> void:
	if not visible:
		return
	visible = false
	Sound.play("sfx-whiff", 0.3)
	closed.emit(_code.editor.text)


## Ctrl+Enter runs the code from anywhere in the editor. It is read before the code panel, which would take it as a
## new line.
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.ctrl_pressed and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_run_code()


## Esc, or B on a pad, closes the editor. A on a pad presses the focused button: Godot's accept is keys only.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var pad := -1
	if event is InputEventJoypadButton and event.is_pressed():
		pad = (event as InputEventJoypadButton).button_index
	if event.is_action_pressed("ui_cancel") or pad == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		_close()
	elif pad == JOY_BUTTON_A:
		_press_focused()


func _press_focused() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is BaseButton and is_ancestor_of(focused):
		get_viewport().set_input_as_handled()
		(focused as BaseButton).pressed.emit()
