class_name PauseMenu
extends Control
## Lanternroot's menu (ADR-0061): Esc, or a pad's Start, opens it over the town, and the town waits underneath (no
## step, no talk, no time played). The left side shows the tinker: their figure (as the town and the character screen
## draw them, CharacterStand), name, where they are, how long they have played and what to do next. The right side is the
## list, and since v0.4 the list is the player's own (their menu_items, Concept/v0.4/01 section 8.2): `info.items`, in
## their order, from this vocabulary:
##
##   continue · quests · workbench · bag · map · music · options · save · settings · characters · title · credits · quit
##
## Save is lesson 2: until the player has written their own save, it is shown locked with a line saying where to learn
## it. Settings opens the title's own settings panel over the town. Everything else is the town's to do, and is asked
## for with `chosen(action)`. The look here (the panel, the items, the marks, the pop-in) is shared by the quest log
## and the tracker, so the three read as one.
##
##   menu.open(PauseMenu.about(state, catalog, {"items": [...], "first_time": true, "place": "...", "clock": "18:40 · evening"}))
##   menu.cover(true)    # the quest log is over the menu; cover(false) brings the menu back

## Something the town does: "quests", "boots", "save", "characters", "title" or "quit".
signal chosen(action: String)
## The menu closed: Continue, Esc, or a pad's B or Start.
signal closed

const CONTINUE := "continue"
const QUESTS := "quests"
## "Your boots" left the list for the Workbench (v0.4); the constant stays so old callers compile.
const BOOTS := "boots"
const WORKBENCH := "workbench"
const BAG := "bag"
const MAP := "map"
const MUSIC := "music"
const OPTIONS := "options"
const SAVE := "save"
const SETTINGS := "settings"
const CHARACTERS := "characters"
const TITLE := "title"
const CREDITS := "credits"
const QUIT := "quit"
## Every item the menu knows, in the town's own order. An id outside this list is never shown.
const ALL_ITEMS: Array[String] = [
	CONTINUE, QUESTS, WORKBENCH, BAG, MAP, MUSIC, OPTIONS, SAVE, SETTINGS, CHARACTERS, TITLE, CREDITS, QUIT
]
## What the menu lists when its caller gives no items (the town's order before the player builds a menu).
const ITEMS: Array[String] = [CONTINUE, QUESTS, SAVE, SETTINGS, CHARACTERS, TITLE, QUIT]
## How long an item takes to fly in the first time, and how long it waits for the one before.
const FLY_TIME := 0.24
const FLY_GAP := 0.06
const FLY_FROM := 90.0
## The items that leave the town: the menu takes no more input once one is chosen.
const LEAVING: Array[String] = [CHARACTERS, TITLE, QUIT]

const FILL := OverworldStyle.PANEL_FILL
const INK := Color("#f3e6c8")
const ITEM_HEIGHT := 44.0
const SIDE_WIDTH := 190.0
const LIST_WIDTH := 230.0

## Whether Save waits for the player's own save (lesson 2). Set by open().
var save_locked := true

var _open := false
var _covered := false
var _leaving := false
var _hush := false
var _last := CONTINUE
var _items: Dictionary = {}
var _slots: Dictionary = {}
var _listed: Array[String] = []
var _list_box: VBoxContainer
var _dim: ColorRect
var _card: PanelContainer
var _figure: CharacterStand
var _name: Label
var _place: Label
var _clock: Label
var _played: Label
var _quest_title: Label
var _quest_step: Label
var _save_lock: Control
var _lock_note: Control
var _status: Label
var _settings_page: CenterContainer
var _settings: FoundrySettingsPanel
var _motion: Tween
var _nudge: Tween
var _fly: Tween


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.04, 0.03, 0.05, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", panel_style())
	_card.resized.connect(func() -> void: _card.pivot_offset = _card.size / 2.0)
	centre.add_child(_card)
	var body := Ui.hbox([_side(), divider(), _list()], 18)
	var help := help_line(Text.t("Arrows: choose   Enter: pick   Esc: back"))
	_card.add_child(Ui.vbox([body, rule(), help], 10))
	_settings_page = CenterContainer.new()
	_settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_page.visible = false
	add_child(_settings_page)


# --- the look the menu, the quest log and the tracker share --------------------------------------------------------


## The Lanternroot panel (OverworldStyle.panel_box): a dark warm fill, a thin amber edge, round corners. A smaller
## `padding` suits a card over the town (the tracker, the toast).
static func panel_style(padding := Vector2(22, 16)) -> StyleBoxFlat:
	var style := OverworldStyle.panel_box()
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	return style


## A choice in a list: plain until it has the focus, then framed and lettered in amber. The mouse moves the focus
## too, so only one choice is ever lit. `indent` leaves room on the left for a mark (see `mark`).
static func style_item(button: Button, font_size := 24, indent := 18.0) -> void:
	var pad := Vector2(14, 4)
	var styles := {
		"normal": UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 10, pad),
		"hover": UiTheme.box(Color(UiTheme.AMBER, 0.07), Color.TRANSPARENT, 0, 10, pad),
		"pressed": UiTheme.box(Color(UiTheme.AMBER, 0.24), UiTheme.AMBER, 3, 10, pad),
		"hover_pressed": UiTheme.box(Color(UiTheme.AMBER, 0.24), UiTheme.AMBER, 3, 10, pad),
		"disabled": UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 10, pad),
		"focus": UiTheme.box(Color(UiTheme.AMBER, 0.14), UiTheme.AMBER, 3, 10, pad),
	}
	for state: String in styles:
		var style := styles[state] as StyleBoxFlat
		style.content_margin_left = indent
		button.add_theme_stylebox_override(state, style)
	button.add_theme_font_override("font", OverworldStyle.body_font(600))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK)
	for state: String in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, UiTheme.AMBER)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = ITEM_HEIGHT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## A small drawn mark, the same in every font: "done" (a ticked box), "todo" (an empty box), "open" (a ring with a
## dot: the step under way), "locked" or "lock" (a padlock). Change it with set_mark.
static func mark(kind: String, side := 26.0) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(side, side)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("kind", kind)
	box.resized.connect(func() -> void: box.pivot_offset = box.size / 2.0)
	box.draw.connect(func() -> void: _draw_mark(box))
	return box


static func set_mark(box: Control, kind: String) -> void:
	box.set_meta("kind", kind)
	box.queue_redraw()


static func _draw_mark(box: Control) -> void:
	var side := minf(box.size.x, box.size.y)
	var area := Rect2((box.size - Vector2(side, side)) / 2.0, Vector2(side, side)).grow(-2.0)
	var centre := area.get_center()
	var at := func(x: float, y: float) -> Vector2: return area.position + area.size * Vector2(x, y)
	match String(box.get_meta("kind", "")):
		"done":
			UiTheme.box(UiTheme.AMBER, UiTheme.AMBER, 2, 6).draw(box.get_canvas_item(), area)
			var tick := PackedVector2Array([at.call(0.22, 0.52), at.call(0.42, 0.72), at.call(0.78, 0.3)])
			box.draw_polyline(tick, Color("#2a1a0c"), maxf(2.0, side * 0.13), true)
		"todo":
			UiTheme.box(Color(0, 0, 0, 0.25), UiTheme.AMBER_DIM, 2, 6).draw(box.get_canvas_item(), area)
		"open":
			box.draw_arc(centre, area.size.x * 0.42, 0.0, TAU, 40, UiTheme.AMBER, maxf(2.0, side * 0.1), true)
			box.draw_circle(centre, area.size.x * 0.17, UiTheme.AMBER)
		"locked", "lock":
			var colour := UiTheme.MUTED if String(box.get_meta("kind")) == "locked" else UiTheme.AMBER_DIM
			var shackle := Vector2(centre.x, area.position.y + area.size.y * 0.42)
			box.draw_arc(shackle, area.size.x * 0.24, PI, TAU, 16, colour, maxf(2.0, side * 0.11), true)
			var lock_body := Rect2(at.call(0.16, 0.42), area.size * Vector2(0.68, 0.52))
			UiTheme.box(colour, colour, 0, 3).draw(box.get_canvas_item(), lock_body)
			box.draw_circle(lock_body.get_center(), side * 0.07, FILL)


## Fades `control` in over 0.15 s while it grows from 0.97 to its size (OverworldStyle.pop_in, the one opening).
static func pop_in(control: Control) -> Tween:
	return OverworldStyle.pop_in(control, control)


static func rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(UiTheme.AMBER_DIM, 0.45)
	line.custom_minimum_size.y = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(UiTheme.AMBER_DIM, 0.35)
	line.custom_minimum_size.x = 2
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The keys a panel answers to, in small print at its foot.
static func help_line(text: String) -> Label:
	var line := Ui.label(text, "Muted")
	line.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	line.add_theme_color_override("font_color", OverworldStyle.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return line


## Small print in the overworld's muted colour.
static func small(text: String, wrap := false) -> Label:
	var line := Ui.label(text, "Muted", wrap)
	line.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	line.add_theme_color_override("font_color", OverworldStyle.MUTED)
	return line


## Time played as a child reads it: "less than a minute", "12 min", "1 h 05 min".
static func duration(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 1:
		return Text.t("less than a minute")
	if minutes < 60:
		return Text.f("%d min", [minutes])
	return Text.f("%d h %02d min", [minutes / 60, minutes % 60])


## The words of each item. Each is a literal Text.t call, so the locale check finds it.
static func item_text(action: String) -> String:
	match action:
		"continue":
			return Text.t("Continue")
		"quests":
			return Text.t("Quests")
		"boots":
			return Text.t("Your boots")
		"workbench":
			return Text.t("Workbench")
		"bag":
			return Text.t("Bag")
		"map":
			return Text.t("Map")
		"music":
			return Text.t("Music box")
		"options":
			return Text.t("Your options")
		"credits":
			return Text.t("Credits")
		"save":
			return Text.t("Save")
		"settings":
			return Text.t("Settings")
		"characters":
			return Text.t("Characters")
		"title":
			return Text.t("Quit to title")
		"quit":
			return Text.t("Quit game")
	return action


# --- building -----------------------------------------------------------------------------------------------------


## The tinker's side: their figure on a little stage, their name, the place, the time played, and what to do next.
func _side() -> Control:
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override(
		"panel", UiTheme.box(Color("#1c1510"), Color(UiTheme.AMBER_DIM, 0.5), 1, 12, Vector2(18, 10))
	)
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_figure = CharacterStand.new()
	_figure.name = "Figure"
	_figure.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage.add_child(_figure)
	_name = Ui.label("")
	_name.add_theme_font_override("font", OverworldStyle.body_font(600))
	_name.add_theme_font_size_override("font_size", 24)
	_name.add_theme_color_override("font_color", INK)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size.x = SIDE_WIDTH
	_place = small("", true)
	_place.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock = small("", true)
	_clock.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_played = small("", true)
	_played.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_played.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_title = Ui.label("", "", true)
	_quest_title.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	_quest_title.add_theme_color_override("font_color", UiTheme.AMBER)
	_quest_step = Ui.label("", "", true)
	_quest_step.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	_quest_step.add_theme_color_override("font_color", INK)
	var next := Ui.vbox([_quest_title, _quest_step], 4)
	var side := Ui.vbox([stage, _name, Ui.vbox([_place, _clock, _played], 2), rule(), next], 8)
	side.custom_minimum_size.x = SIDE_WIDTH
	return side


func _list() -> Control:
	_list_box = Ui.vbox([], 1)
	_status = Ui.label("", "", true)
	_status.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_status.visible = false
	var list := Ui.vbox([_list_box, _status], 10)
	list.custom_minimum_size.x = LIST_WIDTH
	return list


## The items the menu shows, from the caller's list: known ids only, each once, in the caller's order. A caller with no
## list gets ITEMS.
static func shown_items(given: Variant) -> Array[String]:
	var out: Array[String] = []
	if not given is Array:
		return ITEMS.duplicate()
	for id: Variant in given as Array:
		var name := String(id)
		if name in ALL_ITEMS and not name in out:
			out.append(name)
	return out


## Builds the list again when it is not the one on show. The rule goes before the first item that leaves the town.
func _build_items(ids: Array[String]) -> void:
	if ids == _listed and not _items.is_empty():
		return
	_listed = ids.duplicate()
	Ui.clear(_list_box)
	_items.clear()
	_slots.clear()
	_save_lock = null
	_lock_note = null
	var ruled := false
	for action in ids:
		if action in LEAVING and not ruled:
			ruled = true
			if _list_box.get_child_count() > 0:
				var gap := rule()
				gap.color = Color(UiTheme.AMBER_DIM, 0.25)
				_list_box.add_child(Ui.spacer(0, 2))
				_list_box.add_child(gap)
				_list_box.add_child(Ui.spacer(0, 2))
		_list_box.add_child(_slot(action))
		if action == SAVE:
			_list_box.add_child(_save_note())


## A slot holds one item and lets it slide (the items fly in the first time): a plain Control keeps the item where it
## is put, which a container would not.
func _slot(action: String) -> Control:
	var slot := Control.new()
	slot.name = "Slot_" + action
	slot.custom_minimum_size.y = ITEM_HEIGHT
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := _item(action)
	slot.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slots[action] = slot
	return slot


func _item(action: String) -> Button:
	var button := Ui.button(item_text(action), _pick.bind(action))
	button.name = "Item_" + action
	style_item(button)
	button.focus_entered.connect(_on_focus.bind(action))
	button.mouse_entered.connect(_hover.bind(button))
	_items[action] = button
	if action == SAVE:
		_save_lock = mark("lock", 26.0)
		button.add_child(_save_lock)
		_save_lock.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_save_lock.offset_left = -48
		_save_lock.offset_right = -22
		_save_lock.offset_top = -13
		_save_lock.offset_bottom = 13
	return button


## The kind line under a locked Save: saving is something the player will build.
func _save_note() -> Control:
	var words := small(Text.t("You will build saving yourself. Ask Vell at the Archive."), true)
	words.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lock_note = Ui.hbox([Ui.spacer(20, 0), words], 0)
	return _lock_note


# --- opening and closing -------------------------------------------------------------------------------------------


func is_open() -> bool:
	return _open


## What the menu shows about the tinker, read from the town's state: their name and figure, the map they are on, how
## long they have played, the step to do now, and whether their own save is written yet (lesson 2). `extra` adds what
## the player's parts give: `items` (their menu_items), `first_time` (the items fly in), `place` (their place_of; used
## when it is not empty) and `clock` (their clock's words, "18:40 · evening", shown under the place).
static func about(state: Dictionary, catalog: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var look: Dictionary = state.get("look", {}) if state.get("look", {}) is Dictionary else {}
	var maps: Dictionary = catalog.get("maps", {})
	var place := String((maps.get(String(state.get("map", "")), {}) as Dictionary).get("name", ""))
	var info := {
		"name": String(state.get("name", "")),
		"figure": OverworldArt.player_character(look) if not look.is_empty() else null,
		"place": Text.t(place) if place != "" else "",
		"played": float(state.get("played_seconds", 0.0)),
		"quest": Quests.current(catalog.get("quests", {}), state.get("flags", {})),
		"can_save": LessonHost.can_save(state),
		"items": ITEMS.duplicate(),
		"first_time": false,
		"clock": "",
	}
	for key: String in extra:
		if key == "place" and String(extra[key]) == "":
			continue
		info[key] = extra[key]
	return info


## Opens over the town. `info`: {name, figure (the tinker's CharacterSheet, or null for a plain figure), place, clock,
## played (seconds), quest (Quests.current, or {}), can_save, items (the ids to list, in order), first_time}.
func open(info: Dictionary) -> void:
	_open = true
	_covered = false
	_leaving = false
	_fill(info)
	_close_settings(true)
	_card.visible = true
	_card.modulate.a = 1.0
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	if _items.has(CONTINUE):
		_focus_item(CONTINUE)
	elif not _listed.is_empty():
		_focus_item(_listed[0])
	if bool(info.get("first_time", false)):
		_fly_in()


func _fill(info: Dictionary) -> void:
	_build_items(shown_items(info.get("items")))
	save_locked = not bool(info.get("can_save", false))
	_figure.set_sheet(info.get("figure") as CharacterSheet)
	var who := String(info.get("name", ""))
	_name.text = who if who != "" else Text.t("Tinker")
	_place.text = String(info.get("place", ""))
	_place.visible = _place.text != ""
	_clock.text = String(info.get("clock", ""))
	_clock.visible = _clock.text != ""
	_played.text = Text.f("Time played: %s", [duration(float(info.get("played", 0.0)))])
	var quest: Dictionary = info.get("quest", {})
	if quest.is_empty():
		_quest_title.text = Text.t("All done for now")
		_quest_step.text = Text.t("Lanternroot is yours to explore.")
	else:
		_quest_title.text = Text.t(String(quest.title))
		var step := Text.t(String(quest.text))
		var progress := String(quest.get("progress", ""))
		_quest_step.text = step if progress == "" else "%s  (%s)" % [step, progress]
	_status.text = ""
	_status.visible = false
	if _fly != null and _fly.is_valid():
		_fly.kill()
	for slot: Control in _slots.values():
		_rest_slot(slot)
	if _save_lock != null:
		_save_lock.visible = save_locked
		_lock_note.visible = save_locked
		var save := _items[SAVE] as Button
		if save_locked:
			save.add_theme_color_override("font_color", OverworldStyle.MUTED)
		else:
			save.remove_theme_color_override("font_color")
			save.add_theme_color_override("font_color", INK)


static func _rest_slot(slot: Control) -> void:
	var button := slot.get_child(0) as Control
	button.offset_left = 0.0
	button.offset_right = 0.0
	slot.modulate.a = 1.0


## The first time the menu opens (Concept/v0.4/01 section 5.2): the items fly in one by one, in the player's order, each
## sliding in from the right with a fade and a soft click.
func _fly_in() -> void:
	if _fly != null and _fly.is_valid():
		_fly.kill()
	_fly = create_tween().set_parallel()
	for index in _listed.size():
		var slot := _slots[_listed[index]] as Control
		var button := slot.get_child(0) as Control
		slot.modulate.a = 0.0
		button.offset_left = FLY_FROM
		button.offset_right = FLY_FROM
		var delay := index * FLY_GAP
		_fly.tween_callback(Sound.play.bind("sfx-card-place", 0.4)).set_delay(delay)
		for property: String in ["offset_left", "offset_right"]:
			_fly.tween_property(button, property, 0.0, FLY_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(
				Tween.EASE_OUT
			)
		_fly.tween_property(slot, "modulate:a", 1.0, FLY_TIME * 0.7).set_delay(delay)


## Closes the menu, with the cancel sound (Esc, B, Start) or quietly (an item that opens something else).
func close(cancel := true) -> void:
	if not _open:
		return
	_open = false
	_covered = false
	_close_settings(true)
	if _fly != null and _fly.is_valid():
		_fly.kill()
	if cancel:
		Sound.play("sfx-whiff", 0.3)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.fade_out(self, func() -> void: visible = _open)
	closed.emit()


## The quest log is over the menu (true) or has closed (false). The menu waits under it, its card hidden.
func cover(on: bool) -> void:
	if not _open:
		return
	_covered = on
	_card.visible = not on
	if not on:
		pop_in(_card)
		_focus_item(_last)


## What the menu says after something it asked for (the save), under the list, in `colour`.
func show_status(text: String, colour := INK) -> void:
	_status.text = text
	_status.visible = text != ""
	_status.add_theme_color_override("font_color", colour)


## The words under the list now (for tests and the town).
func status_text() -> String:
	return _status.text if _status.visible else ""


## Whether the kind line under a locked Save is showing.
func lock_note_shown() -> bool:
	return _lock_note.visible


## The menu's item for `action`, for tests and for the town.
func item(action: String) -> Button:
	return _items.get(action) as Button


# --- choosing -----------------------------------------------------------------------------------------------------


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
	if _save_lock == null:
		return
	Sound.play("sfx-whiff", 0.3, 0.8)
	_lock_note.visible = true
	if _nudge != null and _nudge.is_valid():
		_nudge.kill()
	_save_lock.rotation = 0.0
	_nudge = create_tween()
	for angle: float in [0.3, -0.3, 0.18, -0.12, 0.0]:
		_nudge.tween_property(_save_lock, "rotation", angle, 0.05)


# --- settings -------------------------------------------------------------------------------------------------------


## The title's own settings, over the town in a Lanternroot panel. Its Back, or Esc, comes back to the menu.
func _open_settings() -> void:
	_settings = settings_in(_settings_page, _close_settings.bind(false))
	_card.visible = false


## The title's settings panel in a Lanternroot frame, shown in `page` (a full-screen CenterContainer the caller owns),
## with the first button in focus. `on_close` is called when its Back is pressed. Shared by the pocket menu.
static func settings_in(page: CenterContainer, on_close: Callable) -> FoundrySettingsPanel:
	var settings := FoundrySettingsPanel.make()
	settings.closed.connect(on_close)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", panel_style())
	frame.add_child(settings)
	page.add_child(frame)
	page.visible = true
	pop_in(frame)
	(
		(func() -> void:
			var buttons := settings.find_children("*", "Button", true, false) if is_instance_valid(settings) else []
			if not buttons.is_empty():
				(buttons[0] as Control).grab_focus())
		. call_deferred()
	)
	return settings


## Puts the settings away: saved, and `page` emptied and hidden.
static func close_settings_in(page: CenterContainer) -> void:
	Settings.save_file()
	Ui.clear(page)
	page.visible = false


## Whether the settings panel is up (for tests and the town's input).
func settings_open() -> bool:
	return _settings != null


func _close_settings(quiet := false) -> void:
	if _settings == null:
		return
	_settings = null
	close_settings_in(_settings_page)
	if quiet:
		return
	Sound.play("sfx-whiff", 0.3)
	_card.visible = true
	pop_in(_card)
	_focus_item(SETTINGS)


# --- input ----------------------------------------------------------------------------------------------------------


## While the menu is open nothing reaches the town. Esc, B or Start goes back one step: out of the settings, or out of
## the menu. A key with no focus to move (a click on the dim took it) gives the focus back to the last item.
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
