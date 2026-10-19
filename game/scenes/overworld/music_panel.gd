class_name MusicPanel
extends Control
## The town's Music panel, the music box's tunes (Concept/v0.4/01 section 8.5). The titles are what the player's
## titles() gave, one row each, with a note beside the one that is playing. Enter plays the one in focus. "Next" (and R,
## and a pad's right shoulder) plays the one the player's next_track() names. "Play in town" makes the focused tune the
## town's track everywhere, and "Lanternroot's own" gives the places their own tracks back.
##
##   panel.open(titles, ids, playing_id, town_track_id, next_index)   # next_index(index, count) -> int, -1 when not built
##   panel.play.connect(func(id): Sound.music(id))
##   panel.set_town_track.connect(func(id): ...)                       # "" is Lanternroot's own

## A track was chosen to listen to now.
signal play(id: String)
## A track was chosen for the town ("" puts the places' own tracks back).
signal set_town_track(id: String)
signal closed

const LIST_WIDTH := 460.0
const LIST_MAX := 440.0
const INK := PauseMenu.INK

var _open := false
var _titles: Array[String] = []
var _ids: Array[String] = []
var _playing := ""
var _town := ""
var _next_index := Callable()
var _rows: Array[Button] = []
var _marks: Array[Label] = []
var _tags: Array[Label] = []
var _focused := 0
var _card: PanelContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _count: Label
var _empty: Label
var _next: Button
var _town_button: Button
var _own_button: Button
var _in_town: Label
var _motion: Tween


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
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style(Vector2(26, 20)))
	centre.add_child(_card)
	var heading := Ui.label(Text.t("Music box"), "Heading")
	heading.add_theme_color_override("font_color", UiTheme.AMBER)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count = PauseMenu.small("")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_list = Ui.vbox([], 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = Ui.scroll(_list)
	_scroll.follow_focus = true
	_empty = PauseMenu.small(Text.t("The music box has no tunes yet."), true)
	_empty.visible = false
	_next = Ui.button(Text.t("Next ▶"), _play_next, "PrimaryButton")
	_next.custom_minimum_size = Vector2(150, 44)
	_next.focus_entered.connect(_blip)
	_in_town = PauseMenu.small("", true)
	_in_town.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_in_town.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_town_button = Ui.button("", _set_town)
	_town_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_town_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_town_button.custom_minimum_size.y = 44
	_town_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_town_button.focus_entered.connect(_blip)
	_own_button = Ui.button(Text.t("Lanternroot's own"), _set_own)
	_own_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_own_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_own_button.custom_minimum_size.y = 44
	_own_button.focus_entered.connect(_blip)
	var help := PauseMenu.help_line(Text.t("Arrows: choose   Enter: play   R: next   Esc: back"))
	_card.add_child(
		Ui.vbox(
			[
				Ui.hbox([heading, _count], 12),
				PauseMenu.rule(),
				_scroll,
				_empty,
				PauseMenu.rule(),
				Ui.hbox([_next, _in_town], 16),
				Ui.vbox([_town_button, _own_button], 6),
				help
			],
			12
		)
	)


# --- opening and closing -------------------------------------------------------------------------------------------


func is_open() -> bool:
	return _open


## Opens over the town. `titles` and `ids` are the same length and order (the player's titles, and the tracks'
## ids); `playing` and `town_track` are ids ("" for none). `next_index(index, count)` is the player's next_track.
func open(titles: Array[String], ids: Array[String], playing: String, town_track: String, next_index: Callable) -> void:
	_titles = titles
	_ids = ids
	_playing = playing
	_town = town_track
	_next_index = next_index
	_build()
	_open = true
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	var start := _ids.find(_playing)
	_focus_row(maxi(start, 0))


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


func _build() -> void:
	Ui.clear(_list)
	_rows.clear()
	_marks.clear()
	_tags.clear()
	_focused = 0
	var count := mini(_titles.size(), _ids.size())
	_count.text = Text.f("%d tunes", [count]) if count != 1 else Text.t("1 tune")
	for index in count:
		var row := Ui.button(_titles[index], _pick.bind(index))
		row.name = "Row_" + _ids[index]
		PauseMenu.style_item(row, OverworldStyle.LABEL, 44.0)
		row.focus_entered.connect(_on_row_focus.bind(index))
		row.mouse_entered.connect(_hover.bind(row))
		var mark := Ui.label("♪")
		mark.add_theme_font_size_override("font_size", 26)
		mark.add_theme_color_override("font_color", UiTheme.AMBER)
		mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
		mark.offset_left = 16
		mark.offset_top = -17
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mark)
		var tag := PauseMenu.small(Text.t("in town"))
		tag.add_theme_font_size_override("font_size", OverworldStyle.HINT)
		tag.add_theme_color_override("font_color", UiTheme.AMBER_DIM)
		tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		tag.offset_right = -16
		tag.offset_top = -14
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tag)
		_list.add_child(row)
		_rows.append(row)
		_marks.append(mark)
		_tags.append(tag)
	_scroll.custom_minimum_size = Vector2(LIST_WIDTH, minf(maxf(count, 1) * 45.0 + 4.0, LIST_MAX))
	_scroll.visible = count > 0
	_empty.visible = count == 0
	_refresh()


## The notes, the "in town" tags and the buttons' words, from what is playing and what the town uses.
func _refresh() -> void:
	for index in _rows.size():
		_marks[index].visible = _ids[index] == _playing
		_tags[index].visible = _town != "" and _ids[index] == _town
	var next := _next_of_playing()
	_next.visible = next >= 0
	_next.disabled = _rows.is_empty()
	var at := _town_index()
	_in_town.text = (
		Text.f("In town: %s", [_titles[at]]) if at >= 0 else Text.t("In town: Lanternroot's own")
	)
	_town_button.text = Text.f("Play in town: %s", [_titles[_focused]]) if not _rows.is_empty() else ""
	_town_button.disabled = _rows.is_empty()
	_own_button.disabled = _town == ""


func _town_index() -> int:
	return _ids.find(_town) if _town != "" else -1


## The index the player's next_track names after the one playing: -1 when it is not built or gives nonsense. With
## nothing playing (or a tune this list does not hold) the first tune is next.
func _next_of_playing() -> int:
	if not _next_index.is_valid() or _rows.is_empty():
		return -1
	var now := _ids.find(_playing)
	var answer := int(_next_index.call(maxi(now, 0), _rows.size()))
	if answer < 0 or answer >= _rows.size():
		return -1
	return answer if now >= 0 else 0


# --- doing ---------------------------------------------------------------------------------------------------------


func _pick(index: int) -> void:
	if not _open or index < 0 or index >= _ids.size():
		return
	_start(index)


func _start(index: int) -> void:
	_playing = _ids[index]
	_refresh()
	play.emit(_playing)


## "Next": plays what the player's next_track says follows the tune that is playing.
func _play_next() -> void:
	var next := _next_of_playing()
	if not _open or next < 0:
		return
	Sound.play("sfx-card-place", 0.4)
	_start(next)
	_focus_row(next)


func _set_town() -> void:
	if _rows.is_empty():
		return
	Sound.play("sfx-card-place", 0.4)
	_town = _ids[_focused]
	_refresh()
	set_town_track.emit(_town)


func _set_own() -> void:
	Sound.play("sfx-card-place", 0.4)
	_town = ""
	_refresh()
	set_town_track.emit("")


func _focus_row(index: int) -> void:
	if index >= 0 and index < _rows.size():
		_rows[index].grab_focus()
	elif _next.visible:
		_next.grab_focus()
	else:
		_town_button.grab_focus()


func _on_row_focus(index: int) -> void:
	_focused = index
	_refresh()
	_blip()


func _blip() -> void:
	if _open:
		Sound.play("sfx-card-flick-1", 0.3)


func _hover(row: Button) -> void:
	if _open and not row.has_focus():
		row.grab_focus()


# --- looking at it (for tests and the town) --------------------------------------------------------------------------


## The id playing in the panel now (it moves when the player plays another).
func playing_id() -> String:
	return _playing


## The town's track as the panel shows it ("" for Lanternroot's own).
func town_id() -> String:
	return _town


## The titles on show, in order.
func shown_titles() -> Array[String]:
	var out: Array[String] = []
	for row in _rows:
		out.append(row.text)
	return out


## The row's button.
func row(index: int) -> Button:
	return _rows[index]


## Whether the note is beside this row.
func note_shown(index: int) -> bool:
	return _marks[index].visible


## The "Next" button, which is hidden while the player's next_track is not built.
func next_button() -> Button:
	return _next


func town_button() -> Button:
	return _town_button


func own_button() -> Button:
	return _own_button


# --- input ---------------------------------------------------------------------------------------------------------


## While the panel is open nothing reaches the town. Esc, B or Start goes back; R or a pad's right shoulder is Next.
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
	var shoulder := (
		event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER
	)
	if (key != null and key.keycode == KEY_R) or shoulder:
		_play_next()
		return
	if get_viewport().gui_get_focus_owner() == null:
		_focus_row(_focused)
