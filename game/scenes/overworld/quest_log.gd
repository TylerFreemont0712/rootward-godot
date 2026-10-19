class_name QuestLog
extends Control
## A compact quest card from the start, with the current instructions and independently completed steps.
## The progress coding task unlocks an expanded journal: scrollable active/history list and the player's bars.
## Future quests stay hidden. Track chooses the HUD's quest; closing restores whichever menu was underneath.

signal closed
## The player chose to follow this quest in the tracker (the Track button, or T).
signal track(id: String)

const PORTRAIT := 56.0
const HOTARU := "hotaru"
## The giver's round portrait in the list, and how far from the button's right edge it sits.
const FACE := 32.0
const FACE_INSET := 12.0

var _open := false
var _entries: Array[Dictionary] = []
var _people: Dictionary = {}
var _buttons: Array[Button] = []
var _shown := -1
var _tracked := ""
var _hush := false
var _last := 0
var _card: PanelContainer
var _count: Label
var _list: VBoxContainer
var _back: Button
var _page: VBoxContainer
var _motion: Tween
var _left: Control
var _divider: Control
var _page_scroll: ScrollContainer
var _chooser: OptionButton
var _journal: Button
var _upgrade_note: Label
var _expanded := false
var _journal_unlocked := false
var _visible_indexes: Array[int] = []
var _progress_of := Callable()


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.05, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style())
	centre.add_child(_card)
	var heading := Ui.label(Text.t("Quests"), "Heading")
	heading.add_theme_color_override("font_color", UiTheme.AMBER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = PauseMenu.small("")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_list = Ui.vbox([], 4)
	_back = Ui.button(Text.t("Back"), close)
	PauseMenu.style_item(_back, OverworldStyle.LABEL, 56.0)
	_back.focus_entered.connect(_on_back_focus)
	_back.mouse_entered.connect(_hover.bind(_back))
	var back_mark := _mark_on(_back, "back")
	back_mark.draw.connect(_draw_back_arrow.bind(back_mark))
	var list_scroll := ScrollContainer.new()
	list_scroll.follow_focus = true
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	_left = Ui.vbox([list_scroll], 4)
	_left.custom_minimum_size.x = 300
	_page = Ui.vbox([], 12)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_scroll = ScrollContainer.new()
	_page_scroll.name = "QuestDetails"
	_page_scroll.follow_focus = true
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.add_child(_page)
	_divider = PauseMenu.divider()
	var body := Ui.hbox([_left, _divider, _page_scroll], 20)
	_chooser = OptionButton.new()
	_chooser.name = "QuestChoice"
	_chooser.custom_minimum_size.y = 44
	_chooser.item_selected.connect(func(index: int) -> void: _show(_chooser.get_item_id(index)))
	_journal = Ui.button(Text.t("Expand journal"), _toggle_journal)
	_journal.name = "ExpandJournal"
	_upgrade_note = PauseMenu.small(Text.t("Pip can help you build a larger quest journal."), true)
	var help := PauseMenu.help_line(Text.t("T: track   Esc: back"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 40
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card.add_child(Ui.vbox([
		Ui.hbox([heading, _count, _journal], 12), PauseMenu.rule(), _chooser, body,
		_upgrade_note, PauseMenu.rule(), Ui.hbox([_back, help], 18)
	], 12))


func is_open() -> bool:
	return _open


## Opens over the menu, the quest `focus_id` (the one under way) chosen, or the first.
## `tracked_id` is the quest the tracker follows now (the quest under way when the player never chose one).
func open(
	entries: Array[Dictionary], people: Dictionary, focus_id := "", tracked_id := "",
	journal_unlocked := false, progress_of := Callable()
) -> void:
	_open = true
	_entries = entries
	_people = people
	_tracked = tracked_id if tracked_id != "" else focus_id
	_journal_unlocked = journal_unlocked
	_progress_of = progress_of
	_expanded = _expanded and journal_unlocked
	_layout()
	_fill_list()
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	var chosen := _visible_indexes[0] if not _visible_indexes.is_empty() else -1
	for i in _entries.size():
		if String(_entries[i].id) == focus_id and i in _visible_indexes:
			chosen = i
	_show(chosen)
	_focus(chosen)


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


## The page on show: the index of its quest in the log (for tests).
func shown() -> int:
	return _shown


## The quest the log marks as tracked.
func tracked() -> String:
	return _tracked


## Follows the quest on the page, if it is open (the Track button, or T): tells the town, and marks it.
func track_shown() -> void:
	if _shown < 0 or _shown >= _entries.size():
		return
	var entry := _entries[_shown]
	if String(entry.status) != Quests.OPEN:
		return
	var id := String(entry.id)
	_tracked = id
	Sound.play("sfx-chime", 0.3, 1.2)
	track.emit(id)
	_fill_list()
	_show(_shown)
	_focus(_shown)


# --- the list -----------------------------------------------------------------------------------------------------


func _layout() -> void:
	_left.visible = _expanded
	_divider.visible = _expanded
	_chooser.visible = not _expanded
	_journal.visible = _journal_unlocked
	_journal.text = Text.t("Compact view") if _expanded else Text.t("Expand journal")
	_upgrade_note.visible = not _journal_unlocked
	_page_scroll.custom_minimum_size = Vector2(500, 490) if _expanded else Vector2(620, 350)
	_page.custom_minimum_size.x = 470 if _expanded else 590
	_card.reset_size()


func _toggle_journal() -> void:
	if not _journal_unlocked:
		return
	_expanded = not _expanded
	_layout()
	_fill_list()
	var chosen := _shown if _shown in _visible_indexes else (_visible_indexes[0] if not _visible_indexes.is_empty() else -1)
	_show(chosen)
	_focus(chosen)


func _fill_list() -> void:
	Ui.clear(_list)
	_buttons.clear()
	_buttons.resize(_entries.size())
	_visible_indexes.clear()
	_chooser.clear()
	var done := 0
	var known := 0
	for i: int in _entries.size():
		var entry := _entries[i]
		if String(entry.status) == Quests.LOCKED:
			continue
		known += 1
		if String(entry.status) == Quests.DONE:
			done += 1
			if not _expanded:
				continue
		_visible_indexes.append(i)
	# When there is nothing under way, the compact card can still show the most recent completed quest.
	if _visible_indexes.is_empty():
		for i: int in range(_entries.size() - 1, -1, -1):
			if String(_entries[i].status) == Quests.DONE:
				_visible_indexes.append(i)
				break
	for i: int in _visible_indexes:
		var entry := _entries[i]
		_chooser.add_item(Text.t(String(entry.title)), i)
		var button := Ui.button(Text.t(String(entry.title)), Callable())
		button.name = "Quest_" + String(entry.id)
		PauseMenu.style_item(button, OverworldStyle.LABEL, 56.0)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_mark_on(button, _mark_kind(String(entry.status)))
		_face_on(button, String(entry.get("giver", "")), String(entry.id) == _tracked and String(entry.status) == Quests.OPEN)
		button.focus_entered.connect(_on_focus.bind(i))
		button.mouse_entered.connect(_hover.bind(button))
		button.pressed.connect(_on_focus.bind(i))
		_list.add_child(button)
		_buttons[i] = button
	_count.text = Text.f("%d of %d done", [done, known]) if _expanded else Text.f("%d under way", [known - done])
	if not _visible_indexes.is_empty():
		var first: Button = _buttons[_visible_indexes[0]]
		var last: Button = _buttons[_visible_indexes[-1]]
		first.focus_neighbor_top = _back.get_path()
		_back.focus_neighbor_bottom = first.get_path() if _expanded else _chooser.get_path()
		last.focus_neighbor_bottom = _back.get_path()
		_back.focus_neighbor_top = last.get_path() if _expanded else _chooser.get_path()

static func _mark_kind(status: String) -> String:
	match status:
		Quests.DONE:
			return "done"
		Quests.OPEN:
			return "open"
	return "locked"


## A mark drawn at the left of a list button, in the room `style_item`'s indent leaves.
func _mark_on(button: Button, kind: String) -> Control:
	var mark := PauseMenu.mark(kind, 26.0)
	button.add_child(mark)
	mark.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	mark.offset_left = 18
	mark.offset_right = 44
	mark.offset_top = -13
	mark.offset_bottom = 13
	return mark


## The giver's small round portrait at the right of a list button, with a small amber star on it for the tracked quest.
func _face_on(button: Button, giver: String, tracked: bool) -> void:
	var person: Dictionary = _people.get(giver, {})
	var id := HOTARU if giver == "" or giver == HOTARU else String(person.get("portrait", ""))
	var who := "Hotaru" if giver == "" or giver == HOTARU else String(person.get("name", giver))
	var face := Control.new()
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	face.offset_right = -FACE_INSET
	face.offset_left = -FACE_INSET - FACE
	face.offset_top = -FACE / 2.0
	face.offset_bottom = FACE / 2.0
	face.draw.connect(
		func() -> void:
			QuestTracker.draw_face(face, face.size / 2.0, face.size.x / 2.0, id, who)
			# The tracked quest wears a small amber star at the corner of its giver's face.
			if tracked:
				Minimap.draw_star(face, Vector2(face.size.x - 2.0, 3.0), 9.0, UiTheme.AMBER)
	)
	button.add_child(face)
	# Room on the right for the face, so a long title is trimmed before it reaches it.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		(button.get_theme_stylebox(state) as StyleBoxFlat).content_margin_right = FACE + FACE_INSET + 10.0


## A five-pointed amber star: the mark of the tracked quest.
static func _draw_star(star: Control) -> void:
	var points := PackedVector2Array()
	var centre := star.size / 2.0
	for i in 10:
		var length := 9.0 if i % 2 == 0 else 4.0
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * length)
	star.draw_colored_polygon(points, UiTheme.AMBER)


## Back's mark: a small arrow pointing left.
func _draw_back_arrow(mark: Control) -> void:
	var middle := mark.size / 2.0
	var tip := Vector2(4, middle.y)
	var colour := UiTheme.AMBER_DIM
	mark.draw_line(tip, Vector2(mark.size.x - 4, middle.y), colour, 3.0, true)
	mark.draw_polyline(PackedVector2Array([tip + Vector2(9, -8), tip, tip + Vector2(9, 8)]), colour, 3.0, true)


func _focus(index: int) -> void:
	if index not in _visible_indexes:
		_back.grab_focus()
		return
	_hush = true
	_chooser.select(_visible_indexes.find(index))
	if _expanded:
		_buttons[index].grab_focus()
	else:
		_chooser.grab_focus()
	_hush = false

func _on_focus(index: int) -> void:
	_last = index
	if not _hush:
		Sound.play("sfx-card-flick-1", 0.3)
	_show(index)


func _on_back_focus() -> void:
	if not _hush:
		Sound.play("sfx-card-flick-1", 0.3)


func _hover(button: Button) -> void:
	if _open and not button.has_focus():
		button.grab_focus()


# --- the page -----------------------------------------------------------------------------------------------------


## The page of quest `index`: the giver's portrait, the title and who asked, the status, the summary and the steps.
func _show(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_shown = index
	if index in _visible_indexes:
		_chooser.select(_visible_indexes.find(index))
	_page_scroll.scroll_vertical = 0
	Ui.clear(_page)
	var entry := _entries[index]
	var status := String(entry.status)
	var locked := status == Quests.LOCKED
	var title := Ui.label("???" if locked else Text.t(String(entry.title)), "Heading", true)
	title.add_theme_color_override("font_color", OverworldStyle.MUTED if locked else UiTheme.AMBER)
	var who := PauseMenu.small(_giver_line(String(entry.get("giver", ""))) if not locked else "", true)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var about := Ui.vbox([title, Ui.hbox([who, _status_chip(status)], 12)], 8)
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	about.alignment = BoxContainer.ALIGNMENT_CENTER
	_page.add_child(Ui.hbox([_portrait(String(entry.get("giver", "")), locked), about], 24))
	_page.add_child(PauseMenu.rule())
	if locked:
		var hidden := Ui.label(Text.t("Finish the quests before this one to find out what it is."), "", true)
		hidden.add_theme_color_override("font_color", OverworldStyle.MUTED)
		_page.add_child(hidden)
		pop(_page)
		return
	var summary := Ui.label(Text.t(String(entry.summary)), "", true)
	summary.add_theme_color_override("font_color", PauseMenu.INK)
	_page.add_child(summary)
	var next: Dictionary = entry.get("next_step", {})
	if status == Quests.OPEN and not next.is_empty():
		var instructions := Ui.vbox([], 6)
		instructions.name = "Instructions"
		instructions.add_child(PauseMenu.small(Text.t("What to do")))
		instructions.add_child(Ui.label(Text.t(String(next.get("text", ""))), "", true))
		var hint := String(next.get("hint", ""))
		if hint != "":
			instructions.add_child(PauseMenu.small(Text.t(hint), true))
		_page.add_child(instructions)
	if _expanded and _progress_of.is_valid():
		var finished := 0
		for step: Dictionary in entry.steps:
			finished += 1 if bool(step.done) else 0
		var percent := int(_progress_of.call(finished, (entry.steps as Array).size()))
		if percent >= 0:
			var bar := ProgressBar.new()
			bar.name = "QuestProgress"
			bar.custom_minimum_size.y = 22
			bar.value = clampi(percent, 0, 100)
			_page.add_child(bar)
	var steps := Ui.vbox([], 10)
	var under_way := true
	for step: Dictionary in entry.steps:
		var done := bool(step.done)
		var now := not done and under_way and status == Quests.OPEN
		if not done:
			under_way = false
		steps.add_child(_step_row(String(step.text), done, now))
	_page.add_child(PauseMenu.small(Text.t("To finish this quest")))
	_page.add_child(steps)
	if status == Quests.OPEN:
		_page.add_child(Ui.expand(Ui.spacer(), true))
		_page.add_child(_track_row(String(entry.id)))
	pop(_page)


## The foot of an open quest's page: "Tracking" (a star and the words) when the tracker follows it, else the Track button.
func _track_row(id: String) -> Control:
	if id == _tracked:
		var star := Control.new()
		star.custom_minimum_size = Vector2(22, 22)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.draw.connect(func() -> void: _draw_star(star))
		var words := Ui.label(Text.t("Tracking this quest"))
		words.name = "Tracking"
		words.add_theme_font_override("font", OverworldStyle.body_font(600))
		words.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
		words.add_theme_color_override("font_color", UiTheme.AMBER)
		return Ui.hbox([star, words], 10)
	var button := Ui.button(Text.t("Track"), track_shown, "PrimaryButton")
	button.name = "Track"
	button.custom_minimum_size = Vector2(190, 48)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return Ui.hbox([button, PauseMenu.small(Text.t("or press T"))], 14)


## Fades the page in, so a change of quest reads as a turn of the page.
static func pop(page: Control) -> void:
	page.modulate.a = 0.0
	page.create_tween().tween_property(page, "modulate:a", 1.0, 0.12)


func _giver_line(giver: String) -> String:
	if giver == HOTARU or giver == "":
		return Text.t("From Hotaru")
	var person: Dictionary = _people.get(giver, {})
	return Text.f("From %s", [Text.t(String(person.get("name", giver)))])


func _portrait(giver: String, locked: bool) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override(
		"panel", UiTheme.box(Color("#1a1410"), Color(UiTheme.AMBER_DIM, 0.8), 2, 10, Vector2(6, 6))
	)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var id := (
		HOTARU if giver == "" or giver == HOTARU else String((_people.get(giver, {}) as Dictionary).get("portrait", ""))
	)
	face.texture = OverworldArt.portrait(id) if id != "" else null
	if locked:
		# A quest still hidden shows its giver as a shadow.
		face.modulate = Color(0, 0, 0, 0.75)
	frame.add_child(face)
	if face.texture == null or locked:
		var lock := PauseMenu.mark("locked", 56.0)
		face.add_child(lock)
		lock.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	return frame


func _status_chip(status: String) -> Control:
	var words := Text.t("Not yet")
	var colour := OverworldStyle.MUTED
	if status == Quests.DONE:
		words = Text.t("Done")
		colour = UiTheme.PASS
	elif status == Quests.OPEN:
		words = Text.t("Under way")
		colour = UiTheme.AMBER
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(colour, 0.14), Color(colour, 0.8), 2, 16, Vector2(14, 2))
	)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Ui.label(words)
	label.add_theme_font_override("font", OverworldStyle.body_font(600))
	label.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	label.add_theme_color_override("font_color", colour)
	chip.add_child(label)
	return chip


## A step: ticked and quiet when done, ringed and bright when it is the one to do now, a plain box when it is to come.
func _step_row(text: String, done: bool, now: bool) -> Control:
	var words := Ui.label(Text.t(text), "", true)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	if now:
		words.add_theme_font_override("font", OverworldStyle.body_font(600))
		words.add_theme_color_override("font_color", PauseMenu.INK)
	else:
		words.add_theme_color_override("font_color", OverworldStyle.MUTED)
	var mark := PauseMenu.mark("done" if done else ("open" if now else "todo"), 26.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return Ui.hbox([mark, words], 14)


# --- input --------------------------------------------------------------------------------------------------------


## While the log is open nothing reaches the menu or the town. Esc, B or Start goes back to the menu.
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
	var key := event as InputEventKey
	if key != null and key.keycode == KEY_T:
		track_shown()
		return
	if get_viewport().gui_get_focus_owner() == null:
		_focus(_last)
