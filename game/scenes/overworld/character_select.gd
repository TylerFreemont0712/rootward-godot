class_name CharacterSelect
extends Control
## Lanternroot's front door (ADR-0061): the player's characters standing in a row on the town's cobbles at night
## (CharacterSelectLineup), newest played first, and a last spot, a dim silhouette, to make someone new. The chosen
## one stands in a pool of lantern light with Hotaru at their shoulder, and a compact panel above the row tells
## about them: name, when they last played, one line (language, how they build, time played), the quest and step they
## are on ("Now:"), and the actions Play, Progress (ProgressPanel) and Delete (asked first). Choosing the New spot offers
## "Make a character", which opens the CharacterCreator over this screen; the character it makes is saved under a
## fresh id and walks straight into their house, where Hotaru wakes them.
##
## Mouse: hovering a spot chooses it, clicking the chosen one plays. Keyboard and pad: left and right choose, up and
## down reach the buttons, Enter or A presses the focused one (Play to begin with), P or Y shows the progress,
## Delete or X deletes, Esc or B goes back to the title.

const PANEL_WIDTH := 940.0
const PANEL_TOP := 190.0
## How far the stick must lean to choose, and how far back it must come before it chooses again.
const STICK_ON := 0.6
const STICK_OFF := 0.3

## Whether leaving changes the scene. A test sets it false and reads `went_to` instead.
var navigates := true
## Where the screen sent the player last: Game.OVERWORLD or Game.TITLE ("" before it left).
var went_to := ""
var store: OverworldStore
var catalog: Dictionary = {}
var creator: CharacterCreator
var progress: ProgressPanel
var lineup: CharacterSelectLineup

var _main: Control
## The characters saved, newest played first: [{id, state}]. The New spot is the one after them.
var _entries: Array[Dictionary] = []
var _index := -1
var _title: Label
var _name_label: Label
var _greeting: Label
var _panel: PanelContainer
var _body: VBoxContainer
var _play: Button
var _progress_button: Button
var _delete: Button
var _back: Button
var _help: Label
var _confirm: Control
var _confirm_panel: PanelContainer
var _pad := false
var _stick := false
var _leaving := false


func _ready() -> void:
	Game.boot()
	theme = OverworldStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog = OverworldScreen.catalog_of()
	store = OverworldStore.for_profile()
	_build()
	refresh()
	Sound.music_first(["music-lanternroot-front", "music-rest"])
	if not Settings.reduced_motion:
		_main.modulate.a = 0.0
		create_tween().tween_property(_main, "modulate:a", 1.0, OverworldStyle.OPEN_TIME * 2.0)


## Reads the characters again and stands them in the row, newest played first; the chosen one stays chosen when they
## are still there, else the first is, and Play takes the focus (unless `focus` is false: an overlay is still open).
func refresh(focus := true) -> void:
	var keep := chosen_id()
	_entries = store.characters()
	var looks: Array[Dictionary] = []
	var names: Array[String] = []
	for entry in _entries:
		var look: Variant = entry.state.get("look", {})
		looks.append(look if look is Dictionary else {})
		names.append(CharacterCard.name_of(entry.state))
	var start: Variant = (catalog.get("looks", {}) as Dictionary).get("start", {})
	var pick := 0
	for i in _entries.size():
		if keep != "" and String(_entries[i].id) == keep:
			pick = i
	lineup.set_slots(looks, names, start if start is Dictionary else {}, pick)
	_index = pick
	_fill()
	if focus:
		_play.grab_focus.call_deferred()


## The spots in the row: every character, then the New one.
func count() -> int:
	return _entries.size() + 1


## The characters on screen, newest played first.
func entries() -> Array[Dictionary]:
	return _entries


func chosen_index() -> int:
	return _index


## The id of the chosen character, or "" when the New spot is chosen.
func chosen_id() -> String:
	return String(_entries[_index].id) if _index >= 0 and _index < _entries.size() else ""


## The name the panel shows for the chosen character; "" when the New spot is chosen.
func panel_name() -> String:
	return _name_label.text if _name_label != null and not is_new_chosen() else ""


func is_new_chosen() -> bool:
	return _index >= _entries.size()


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = UiTheme.GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	add_child(CharacterSelectBackdrop.new())
	_main = Control.new()
	_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	lineup = CharacterSelectLineup.new()
	lineup.hovered.connect(_hover)
	lineup.picked.connect(_pick)
	_main.add_child(lineup)

	_title = FrontPanel.heading(Text.t("Lanternroot"), 60)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiTheme.AMBER)
	_greeting = Ui.label(Text.t("Who walks into town today?"))
	_greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	_greeting.add_theme_color_override("font_color", OverworldStyle.MUTED)
	var heading := Ui.vbox([_title, _greeting], 2)
	heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	heading.offset_top = 40.0
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(heading)

	_body = Ui.vbox([], 8)
	_play = FrontPanel.button("", _play_chosen, "PrimaryButton")
	_play.custom_minimum_size.x = 260
	_progress_button = FrontPanel.button(Text.t("Progress"), _show_progress)
	_progress_button.custom_minimum_size.x = 190
	_delete = FrontPanel.button(Text.t("Delete"), _ask_delete, "DangerButton")
	_delete.custom_minimum_size.x = 170
	var actions := Ui.hbox([_play, _progress_button, _delete], 14)
	_panel = FrontPanel.panel(Ui.vbox([_body, Ui.spacer(0, 4), actions], 10), Vector2(30, 22))
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# A holder that lets the mouse through to the row around the panel, and keeps the panel at the top of its box.
	var holder := Ui.vbox([_panel], 0)
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = PANEL_TOP
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(holder)

	_back = FrontPanel.button(Text.t("◀  Back"), _go_back)
	_back.custom_minimum_size.x = 200
	_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_back.offset_left = 48.0
	_back.offset_bottom = -36.0
	_back.offset_top = -36.0 - FrontPanel.BUTTON_HEIGHT
	_back.offset_right = 48.0 + 200.0
	_main.add_child(_back)
	_help = FrontPanel.keys("")
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_right = -56.0
	_help.offset_bottom = -52.0
	_main.add_child(_help)
	_refresh_help()

	creator = CharacterCreator.new()
	creator.can_cancel = true
	creator.done.connect(_on_created)
	creator.cancelled.connect(_on_overlay_closed)
	add_child(creator)
	progress = ProgressPanel.new()
	progress.closed.connect(_on_overlay_closed)
	add_child(progress)
	_confirm = FrontPanel.overlay()
	add_child(_confirm)


# --- choosing ------------------------------------------------------------------------------------------------------


## Chooses the spot at `index` (a character, or the New spot last): the light moves and the panel tells about them.
func choose(index: int, sound := false) -> void:
	var to := clampi(index, 0, count() - 1)
	if to == _index:
		return
	_index = to
	lineup.choose(to)
	_fill()
	if sound:
		FrontPanel.moved()


## Chooses the neighbour `by` spots along, stopping at the ends of the row.
func step(by: int) -> void:
	choose(_index + by, true)


func _hover(index: int) -> void:
	if not _overlay_open() and not _leaving:
		choose(index, true)


## A click on a spot: another spot is chosen (a touch has no hover); the chosen one plays, or makes someone new.
func _pick(index: int) -> void:
	if _overlay_open() or _leaving:
		return
	if index == _index:
		_play_chosen()
	else:
		choose(index, true)


## Fills the panel for the chosen spot, and the buttons.
func _fill() -> void:
	Ui.clear(_body)
	_name_label = null
	if is_new_chosen():
		_fill_new()
	else:
		_fill_character(_entries[_index].state)
	_panel.reset_size.call_deferred()
	var named := not is_new_chosen()
	_progress_button.visible = named
	_delete.visible = named
	_play.text = Text.t("Play  ▶") if named else Text.t("Make a character")
	# Up and down walk the buttons (left and right choose a character), round to Back and on to Play again.
	var column: Array[Control] = [_play]
	for button: Button in [_progress_button, _delete]:
		if button.visible:
			column.append(button)
	column.append(_back)
	for i in column.size():
		column[i].focus_neighbor_bottom = column[(i + 1) % column.size()].get_path()
		column[i].focus_neighbor_top = column[(i + column.size() - 1) % column.size()].get_path()
		column[i].focus_neighbor_left = column[i].get_path()
		column[i].focus_neighbor_right = column[i].get_path()


func _fill_character(state: Dictionary) -> void:
	var flags := CharacterDigest.flags_of(state)
	var quests: Dictionary = catalog.get("quests", {})
	var name_label := FrontPanel.heading(CharacterCard.name_of(state), 46)
	name_label.add_theme_color_override("font_color", UiTheme.AMBER)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label = name_label
	var when := FrontPanel.small(CharacterCard.last_played(state))
	when.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_body.add_child(Ui.hbox([name_label, when], 16))
	# One plain line (the player's word, v0.4: "have it be a little more basic with what it shows"): the language, how
	# they build and the time played. The counts of quests, people met and keys are in Progress.
	_body.add_child(FrontPanel.small(CharacterCard.detail_line(state)))
	_body.add_child(_rule())
	var quest := Quests.current(quests, flags)
	var now := FrontPanel.small(Text.t("Now:"))
	now.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var quest_title := Ui.label(
		Text.t(String(quest.title)) if not quest.is_empty() else Text.t("All done for now"),
		"Subheading"
	)
	quest_title.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	quest_title.clip_text = true
	quest_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var step_text := FrontPanel.small(
		(
			Text.t(String(quest.text))
			if not quest.is_empty()
			else Text.t("Lanternroot is yours to explore.")
		),
		true
	)
	step_text.add_theme_color_override("font_color", UiTheme.TEXT)
	step_text.custom_minimum_size.y = 56
	_body.add_child(Ui.hbox([now, quest_title], 10))
	_body.add_child(step_text)


func _fill_new() -> void:
	var title := FrontPanel.heading(Text.t("New character"), 42)
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	_body.add_child(title)
	var line := (
		Text.t("Nobody lives here yet. Make your first character!")
		if _entries.is_empty()
		else Text.t("Make someone new to walk the town: a new name, a new look, a fresh start.")
	)
	var invitation := Ui.label(line, "", true)
	invitation.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	invitation.add_theme_color_override("font_color", UiTheme.TEXT)
	_body.add_child(invitation)


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = UiTheme.LINE
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


# --- acting --------------------------------------------------------------------------------------------------------


func _play_chosen() -> void:
	if _index < 0 or _leaving or _overlay_open():
		return
	if is_new_chosen():
		open_creator()
		return
	OverworldStore.current = chosen_id()
	_leave(Game.OVERWORLD)


func open_creator() -> void:
	FrontPanel.confirmed()
	_set_main_enabled(false)
	creator.open(catalog.get("looks", {}))


## A new character, made: a fresh start in their house, with the look, the name and the way they like to build. Saved
## under a new id, it is the character the town plays now; Hotaru wakes them, since nothing is remembered yet.
func _on_created(look: Dictionary, chosen_name: String) -> void:
	var home: Dictionary = catalog.get("maps", {}).get(OverworldScreen.START_MAP, {})
	var start := OverworldMap.cell_of(home.get("start", [0, 0]))
	var state := OverworldState.fresh(OverworldScreen.START_MAP, start, "down", BootsCode.PYTHON)
	state.look = look
	state.name = chosen_name
	state.boots.style = creator.style
	var id := store.new_id()
	store.save_character(id, state)
	OverworldStore.current = id
	_leave(Game.OVERWORLD)


func _show_progress() -> void:
	if is_new_chosen() or _index < 0 or _overlay_open():
		return
	FrontPanel.confirmed()
	_set_main_enabled(false)
	progress.open(_entries[_index].state, catalog)


# --- deleting ------------------------------------------------------------------------------------------------------


func _ask_delete() -> void:
	if is_new_chosen() or _index < 0 or _overlay_open():
		return
	var who := CharacterCard.name_of(_entries[_index].state)
	Ui.clear(_confirm)
	var shade := ColorRect.new()
	shade.color = FrontPanel.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(shade)
	var heading := FrontPanel.heading(Text.f("Delete %s?", [who]))
	var line := Ui.label(
		Text.f("%s and everything they have done go for good. This cannot be undone.", [who]),
		"",
		true
	)
	line.custom_minimum_size.x = 520
	var keep := FrontPanel.button(Text.f("Keep %s", [who]), _close_confirm, "PrimaryButton")
	var gone := FrontPanel.button(Text.t("Delete for good"), delete_chosen, "DangerButton")
	for button: Button in [keep, gone]:
		button.custom_minimum_size.x = 240
	var buttons := Ui.hbox([keep, gone], 20)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm_panel = FrontPanel.panel(
		Ui.vbox([heading, line, Ui.spacer(0, 6), buttons], 16), Vector2(28, 22)
	)
	FrontPanel.centre(_confirm, _confirm_panel)
	# The two buttons only reach each other: the screen underneath is out of reach while the question is asked.
	for button: Button in [keep, gone]:
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	keep.focus_neighbor_left = keep.get_path()
	keep.focus_neighbor_right = gone.get_path()
	gone.focus_neighbor_left = keep.get_path()
	gone.focus_neighbor_right = gone.get_path()
	_set_main_enabled(false)
	FrontPanel.reveal(_confirm, _confirm_panel)
	# Keeping is the safe answer, and the one Enter gives.
	keep.grab_focus.call_deferred()


## Deletes the chosen character and everything they did, and stands the ones left; the next one along is chosen.
func delete_chosen() -> void:
	if is_new_chosen() or _index < 0:
		return
	var id := chosen_id()
	var at := _index
	store.delete_character(id)
	if OverworldStore.current == id:
		OverworldStore.current = ""
	Sound.play("sfx-whiff", 0.4)
	_index = -1
	refresh(false)
	choose(mini(at, count() - 1))
	_close_confirm(false)


func _close_confirm(sound := true) -> void:
	if not _confirm.visible:
		return
	if sound:
		FrontPanel.cancelled()
	FrontPanel.conceal(_confirm, _on_overlay_closed)


# --- around --------------------------------------------------------------------------------------------------------


func _overlay_open() -> bool:
	return creator.visible or progress.visible or _confirm.visible


func _on_overlay_closed() -> void:
	_set_main_enabled(true)
	_play.grab_focus()


## The screen under an overlay can be neither focused nor clicked, so arrows and a mouse stay in the overlay.
func _set_main_enabled(on: bool) -> void:
	var focus := Control.FOCUS_BEHAVIOR_INHERITED if on else Control.FOCUS_BEHAVIOR_DISABLED
	var mouse := Control.MOUSE_BEHAVIOR_INHERITED if on else Control.MOUSE_BEHAVIOR_DISABLED
	_main.focus_behavior_recursive = focus
	_main.mouse_behavior_recursive = mouse


func _go_back() -> void:
	if _leaving or _overlay_open():
		return
	FrontPanel.cancelled()
	_leave(Game.TITLE)


func _leave(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	went_to = path
	if path != Game.TITLE:
		FrontPanel.confirmed()
	if navigates:
		Game.go(path)


func _refresh_help() -> void:
	_help.text = (
		Text.t("D-pad: choose   A: play   Y: progress   X: delete   B: back")
		if _pad
		else Text.t("Arrows: choose   Enter: play   P: progress   Delete: delete   Esc: back")
	)


## Left and right choose a character whatever has the focus, so they are read before the buttons see them.
func _input(event: InputEvent) -> void:
	var pad := (
		event is InputEventJoypadButton
		or (
			event is InputEventJoypadMotion
			and absf((event as InputEventJoypadMotion).axis_value) > 0.5
		)
	)
	if (pad or event is InputEventKey) and pad != _pad:
		_pad = pad
		_refresh_help()
	if _leaving or _overlay_open():
		return
	var by := 0
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_pressed("ui_left", true):
			by = -1
		elif event.is_action_pressed("ui_right", true):
			by = 1
	elif (
		event is InputEventJoypadMotion
		and (event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_X
	):
		var lean := (event as InputEventJoypadMotion).axis_value
		if absf(lean) < STICK_OFF:
			_stick = false
		elif absf(lean) > STICK_ON and not _stick:
			_stick = true
			by = int(signf(lean))
	if by != 0:
		step(by)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _overlay_open():
		if _confirm.visible and not _leaving:
			_confirm_input(event)
		return
	var pad := FrontPanel.pad_button(event)
	var key := event as InputEventKey
	var pressed_key := key.keycode if key != null and key.pressed and not key.echo else KEY_NONE
	if FrontPanel.is_back(event):
		_go_back()
	elif pad == JOY_BUTTON_A:
		if not FrontPanel.press_focused(get_viewport()):
			_play_chosen()
	elif event.is_action_pressed("ui_accept"):
		# A button with the focus has already pressed itself; with none, Enter plays.
		_play_chosen()
	elif pressed_key == KEY_P or pad == JOY_BUTTON_Y:
		_show_progress()
	elif pressed_key == KEY_DELETE or pad == JOY_BUTTON_X:
		_ask_delete()
	else:
		return
	get_viewport().set_input_as_handled()


func _confirm_input(event: InputEvent) -> void:
	if FrontPanel.is_back(event):
		_close_confirm()
	elif FrontPanel.pad_button(event) == JOY_BUTTON_A:
		FrontPanel.press_focused(get_viewport())
	else:
		return
	get_viewport().set_input_as_handled()
