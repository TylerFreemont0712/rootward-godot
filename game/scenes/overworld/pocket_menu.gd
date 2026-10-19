class_name PocketMenu
extends Control
## Hotaru's pocket menu (Concept/v0.4/01 section 8.1): the menu the town has before the player builds their own. A narrow
## card with no figure, rougher than the real one (a dashed amber edge, a tilt of half a degree), so the real menu,
## when it comes, feels like an upgrade. It always has Settings, Quit to title and Quit game, so nobody is ever trapped.
##
##   pocket.open({"can_save": false, "note": ""})   # note "shortcut-broken": the player's shortcut() lost Esc
##   pocket.chosen.connect(func(action): ...)        # "boots", "quests", "save", "title", "quit" or "fix"
##
## Settings opens the title's settings panel over the town (as PauseMenu does) and is not sent on.

## What the player picked: "boots", "quests", "save", "title", "quit" or "fix".
signal chosen(action: String)
## The menu closed: Continue, Esc, or a pad's B or Start.
signal closed

const CONTINUE := "continue"
const BOOTS := "boots"
const SAVE := "save"
const SETTINGS := "settings"
const TITLE := "title"
const QUIT := "quit"
const FIX := "fix"
const BROKEN := "shortcut-broken"
const ITEMS: Array[String] = [CONTINUE, BOOTS, "quests", SAVE, SETTINGS, TITLE, QUIT]
const LEAVING: Array[String] = [TITLE, QUIT]
const WIDTH := 380.0
const TILT := deg_to_rad(0.5)
const INK := PauseMenu.INK
## The card's fill: a little browner than the real menu's, like a page torn from a notebook.
const FILL := Color(0.13, 0.095, 0.07, 0.97)

var save_locked := true

var _open := false
var _covered := false
var _leaving := false
var _hush := false
var _last := CONTINUE
var _note_kind := ""
var _items: Dictionary = {}
var _card: PanelContainer
var _body: VBoxContainer
var _save_lock: Control
var _lock_note: Control
var _note: Label
var _status: Label
var _settings_page: CenterContainer
var _settings: FoundrySettingsPanel
var _motion: Tween
var _nudge: Tween


func _ready() -> void:
	theme = OverworldStyle.theme()
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
	_card.custom_minimum_size.x = WIDTH
	# No edge in the box itself: the dashed one is drawn over it (_draw_edge).
	var box := UiTheme.box(FILL, Color.TRANSPARENT, 0, 10, Vector2(26, 20))
	_card.add_theme_stylebox_override("panel", box)
	_card.resized.connect(
		func() -> void:
			_card.pivot_offset = _card.size / 2.0
			_card.queue_redraw()
	)
	_card.draw.connect(_draw_edge)
	centre.add_child(_card)
	_card.rotation = TILT
	var heading := Ui.label(Text.t("Hotaru's pocket menu"), "Muted")
	heading.add_theme_font_override("font", OverworldStyle.body_font(600))
	heading.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	heading.add_theme_color_override("font_color", UiTheme.AMBER)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body = Ui.vbox([], 1)
	_status = Ui.label("", "", true)
	_status.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_status.visible = false
	_note = PauseMenu.small("", true)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	var help := PauseMenu.help_line(Text.t("Arrows: choose   Enter: pick   Esc: back"))
	_card.add_child(Ui.vbox([heading, _dashes(), _body, _status, _dashes(), _note, _fix_slot(), help], 8))
	_settings_page = CenterContainer.new()
	_settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_page.visible = false
	add_child(_settings_page)


## A thin dashed rule, drawn, for the pocket menu's hand-made look.
func _dashes() -> Control:
	var line := Control.new()
	line.custom_minimum_size.y = 6
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(
		func() -> void:
			line.draw_dashed_line(
				Vector2(0, 3), Vector2(line.size.x, 3), Color(UiTheme.AMBER_DIM, 0.6), 2.0, 7.0
			)
	)
	return line


## The "Fix it" item waits here, hidden, until the note says the player's shortcut let Esc go.
func _fix_slot() -> Control:
	var button := _item(FIX, Text.t("Fix it"))
	button.visible = false
	return button


func _draw_edge() -> void:
	# The dashed amber edge, inset a little, with its corners left open the way a hand would draw them.
	var rect := Rect2(Vector2.ZERO, _card.size).grow(-4.0)
	var colour := Color(UiTheme.AMBER, 0.85)
	var corner := 14.0
	var left := rect.position.x
	var right := rect.end.x
	var top := rect.position.y
	var bottom := rect.end.y
	_card.draw_dashed_line(Vector2(left + corner, top), Vector2(right - corner, top), colour, 3.0, 9.0)
	_card.draw_dashed_line(Vector2(left + corner, bottom), Vector2(right - corner, bottom), colour, 3.0, 9.0)
	_card.draw_dashed_line(Vector2(left, top + corner), Vector2(left, bottom - corner), colour, 3.0, 9.0)
	_card.draw_dashed_line(Vector2(right, top + corner), Vector2(right, bottom - corner), colour, 3.0, 9.0)
	for end: Vector2 in [Vector2(left, top), Vector2(right, top), Vector2(left, bottom), Vector2(right, bottom)]:
		var sx := 1.0 if end.x == left else -1.0
		var sy := 1.0 if end.y == top else -1.0
		_card.draw_arc(end + Vector2(sx, sy) * corner, corner, _corner_start(sx, sy), _corner_start(sx, sy) + PI / 2.0, 6, colour, 3.0, true)


static func _corner_start(sx: float, sy: float) -> float:
	if sx > 0.0 and sy > 0.0:
		return PI
	if sx < 0.0 and sy > 0.0:
		return 1.5 * PI
	if sx < 0.0 and sy < 0.0:
		return 0.0
	return 0.5 * PI


# --- items ---------------------------------------------------------------------------------------------------------


## The words of each item. Each is a literal Text.t call, so the locale check finds it.
static func item_text(action: String) -> String:
	match action:
		"continue":
			return Text.t("Continue")
		"boots":
			return Text.t("Your boots")
		"quests":
			return Text.t("Quests")
		"save":
			return Text.t("Save")
		"settings":
			return Text.t("Settings")
		"title":
			return Text.t("Quit to title")
		"quit":
			return Text.t("Quit game")
		"fix":
			return Text.t("Fix it")
	return action


func _item(action: String, words := "") -> Button:
	var button := Ui.button(words if words != "" else item_text(action), _pick.bind(action))
	button.name = "Item_" + action
	PauseMenu.style_item(button, 24, 18.0)
	button.focus_entered.connect(_on_focus.bind(action))
	button.mouse_entered.connect(_hover.bind(button))
	_items[action] = button
	if action == SAVE:
		_save_lock = PauseMenu.mark("lock", 26.0)
		button.add_child(_save_lock)
		_save_lock.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_save_lock.offset_left = -48
		_save_lock.offset_right = -22
		_save_lock.offset_top = -13
		_save_lock.offset_bottom = 13
	return button


func _build_items() -> void:
	if not _body.get_children().is_empty():
		return
	for action in ITEMS:
		_body.add_child(_item(action))
		if action == SAVE:
			var words := PauseMenu.small(Text.t("You will build saving yourself. Ask Vell at the Archive."), true)
			words.add_theme_font_size_override("font_size", OverworldStyle.HINT)
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_lock_note = Ui.hbox([Ui.spacer(20, 0), words], 0)
			_lock_note.visible = false
			_body.add_child(_lock_note)


# --- opening and closing ---------------------------------------------------------------------------------------------


func is_open() -> bool:
	return _open


## Opens over the town. `info`: {can_save (the player's own save is written), note ("" for the usual line, or
## "shortcut-broken" when the player's shortcut() no longer opens the menu on Esc)}.
func open(info: Dictionary) -> void:
	_build_items()
	_open = true
	_covered = false
	_leaving = false
	save_locked = not bool(info.get("can_save", false))
	_note_kind = String(info.get("note", ""))
	var broken := _note_kind == BROKEN
	_note.text = (
		Text.t("Your shortcut() doesn't open the menu on Esc.")
		if broken
		else Text.t("This is just my pocket menu. Mira at the workshop could build you a real one!")
	)
	(_items[FIX] as Button).visible = broken
	_status.text = ""
	_status.visible = false
	_save_lock.visible = save_locked
	_lock_note.visible = false
	var save := _items[SAVE] as Button
	if save_locked:
		save.add_theme_color_override("font_color", OverworldStyle.MUTED)
	else:
		save.add_theme_color_override("font_color", INK)
	_close_settings(true)
	_card.visible = true
	_card.modulate.a = 1.0
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	_focus_item(CONTINUE)


## Closes the menu, with the cancel sound (Esc, B, Start) or quietly.
func close(cancel := true) -> void:
	if not _open:
		return
	_open = false
	_covered = false
	_close_settings(true)
	if cancel:
		Sound.play("sfx-whiff", 0.3)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.fade_out(self, func() -> void: visible = _open)
	closed.emit()


## Something is over the menu (true) or has gone (false): the card hides and comes back, as PauseMenu's does.
func cover(on: bool) -> void:
	if not _open:
		return
	_covered = on
	_card.visible = not on
	if not on:
		PauseMenu.pop_in(_card)
		_focus_item(_last)


## What the menu says after something it asked for (the save), under the list, in `colour`.
func show_status(text: String, colour := INK) -> void:
	_status.text = text
	_status.visible = text != ""
	_status.add_theme_color_override("font_color", colour)


func status_text() -> String:
	return _status.text if _status.visible else ""


## The note at the bottom, for tests and the town.
func note_text() -> String:
	return _note.text


## The ids of the items showing now, in order.
func shown_items() -> Array[String]:
	var out: Array[String] = []
	var all: Array[String] = ITEMS.duplicate()
	all.append(FIX)
	for action in all:
		var button := _items.get(action) as Button
		if button != null and button.visible:
			out.append(action)
	return out


## The menu's item for `action` ("continue", "boots", "save", "settings", "title", "quit", "fix").
func item(action: String) -> Button:
	return _items.get(action) as Button


func lock_note_shown() -> bool:
	return _lock_note != null and _lock_note.visible


func settings_open() -> bool:
	return _settings != null


# --- choosing ------------------------------------------------------------------------------------------------------


func _focus_item(action: String) -> void:
	var button := _items.get(action) as Button
	if button == null or not button.is_visible_in_tree():
		return
	_hush = true
	button.grab_focus()
	_hush = false


func _on_focus(action: String) -> void:
	_last = action
	if not _hush:
		Sound.play("sfx-card-flick-1", 0.3)


func _hover(button: Button) -> void:
	if _open and not _covered and not _leaving and not button.has_focus():
		button.grab_focus()


func _pick(action: String) -> void:
	if not _open or _covered or _leaving:
		return
	if action == SAVE and save_locked:
		_nudge_lock()
		return
	Sound.play("sfx-card-place-1", 0.4)
	match action:
		"continue":
			close(false)
		"settings":
			_open_settings()
		_:
			_leaving = action in LEAVING
			chosen.emit(action)


## Save is still locked: the padlock gives a little shake, and the kind line under it says why.
func _nudge_lock() -> void:
	Sound.play("sfx-whiff", 0.3, 0.8)
	_lock_note.visible = true
	if _nudge != null and _nudge.is_valid():
		_nudge.kill()
	_save_lock.rotation = 0.0
	_nudge = create_tween()
	for angle: float in [0.3, -0.3, 0.18, -0.12, 0.0]:
		_nudge.tween_property(_save_lock, "rotation", angle, 0.05)


func _open_settings() -> void:
	_settings = PauseMenu.settings_in(_settings_page, _close_settings.bind(false))
	_card.visible = false


func _close_settings(quiet := false) -> void:
	if _settings == null:
		return
	_settings = null
	PauseMenu.close_settings_in(_settings_page)
	if quiet:
		return
	Sound.play("sfx-whiff", 0.3)
	_card.visible = true
	PauseMenu.pop_in(_card)
	_focus_item(SETTINGS)


## While the menu is open nothing reaches the town. Esc, B or Start goes back one step: out of the settings, or out of
## the menu.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or _covered:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo() or _leaving:
		return
	var start := event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if event.is_action_pressed("ui_cancel") or start:
		if _settings != null:
			_close_settings()
		else:
			close()
		return
	if get_viewport().gui_get_focus_owner() == null and _settings == null:
		_focus_item(_last)
