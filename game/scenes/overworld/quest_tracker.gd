class_name QuestTracker
extends Control
## Clicking the current quest opens its instructions without requiring a built menu.
signal requested(id: String)
## Lanternroot's quest tracker (ADR-0061, made richer in v0.4, Concept/v0.4/01 section 9.1): a card at the top right
## that says what to do next. The giver's round portrait sits in an amber ring beside the quest's title (in small amber
## capitals) and its "2 / 4" step count, with the quest's progress under them: pips, a ring for the step under way, or,
## once the player has written `progress`, a bar with the player's percent at its end. Under that is the step to do now
## (Quests.current over the town's flags), its count when the step counts ("3 / 6") and, when the step has a pin, an
## arrow toward it with the distance in tiles and the pin's place. When the step changes, the old one is ticked and
## slides away and the new one slides in. When a quest is finished, a toast at the top says so.
##
## The minimap (Minimap) hangs under the card, right-aligned: the tracker owns where the card goes, so the two stack in
## one column (a VBoxContainer anchored top right) and the card growing taller moves the map down with it. They show
## and hide together. The town tells the tracker the flags after every change, where the player is, and the key (H):
##
##   tracker.setup(catalog)                       # the townsfolk's portraits, the maps' names
##   tracker.follow(quests, flags)                # the quests this change finished (their toasts are queued)
##   tracker.set_tracked(id)                      # the quest the player chose in the log ("" for the first open one)
##   tracker.set_parts(progress_of, place_at)     # progress_of(done, total) -> int (-1: not built), place_at(map, cell) -> String
##   tracker.locate(map_id, cell)                 # the player moved
##   tracker.set_shown(on)                        # hidden while a talk, an editor, a lesson or the menu is open
##   tracker.toggle_hidden()                      # H: hides and shows the whole tracker, minimap included
##   tracker.minimap()                            # the Minimap, for show_map, set_people, set_enabled
##
## A change that comes while the card is hidden waits: the flourish plays when the card is shown again.

const WIDTH := 440.0
const MARGIN := Vector2(36, 30)
const TOAST_TOP := 30.0
## How long a toast stays up, and how long the ticked step stays before it slides away.
const TOAST_HOLD := 3.4
const TICK_HOLD := 0.5
const SLIDE := 44.0
## The round portrait and its ring, the progress bar's height and how long it takes to reach a new value.
const PORTRAIT := 46.0
const BAR_HEIGHT := 12.0
const BAR_TIME := 0.4
## The width of a pip and the gap after it.
const PIP := 18.0
## The indent of the lines under the step: the width of its checkbox and the space after it.
const INDENT := 34.0
## The key of a step the card has never drawn, and of "every quest is done".
const NEVER := "?"
const ALL_DONE := ""
const NONE := Vector2i(-1, -1)
const HOTARU := "hotaru"
## The eight ways the arrow points, clockwise from east (the screen's y grows downward).
const ARROWS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

static var _title_face: FontVariation

var _quests: Dictionary = {}
var _flags: Dictionary = {}
var _following := false
var _wanted: Dictionary = {}
var _drawn := NEVER
var _shown := false
var _hidden := false
var _card_on := false
var _busy := false
var _toasts: Array[String] = []
var _toasting := false

var _catalog: Dictionary = {}
var _tracked := ""
var _progress_of := Callable()
var _place_at := Callable()
var _map_id := ""
var _cell := NONE
var _located := false
var _clock := ""
var _bar_percent := -1
var _bar_value := 0.0
var _bar_motion: Tween
var _title_source := ""
var _arrow := ""

var _stack: VBoxContainer
var _card: PanelContainer
var _head: Control
var _portrait: Control
var _title: Label
var _steps: Label
var _area: VBoxContainer
var _pips: Control
var _bar_box: Control
var _bar: Control
var _percent: Label
var _row: Control
var _mark: Control
var _step: Label
var _progress_row: Control
var _progress: Label
var _dir_row: Control
var _dir_arrow: Control
var _dir_label: Label
var _minimap: Minimap
var _toast: PanelContainer
var _toast_text: Label
var _fade: Tween
var _toast_motion: Tween


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_card()
	_build_toast()


func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_TRANSLATION_CHANGED and _drawn != NEVER and _step != null:
		_draw_now()
		_refresh_line()


func _build_card() -> void:
	# One column, anchored at the top right: the card, then the minimap under it, right-aligned.
	_stack = VBoxContainer.new()
	_stack.name = "Stack"
	_stack.add_theme_constant_override("separation", 10)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stack.offset_right = -MARGIN.x
	_stack.offset_left = -MARGIN.x - WIDTH
	_stack.offset_top = MARGIN.y
	_stack.custom_minimum_size.x = WIDTH
	add_child(_stack)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style(Vector2(18, 12)))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_card.tooltip_text = Text.t("Click for quest instructions")
	_card.gui_input.connect(_card_input)
	_card.custom_minimum_size.x = WIDTH
	_card.visible = false
	_card.modulate.a = 0.0
	_stack.add_child(_card)
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	_minimap.size_flags_horizontal = Control.SIZE_SHRINK_END
	_minimap.set_shown(false)
	_stack.add_child(_minimap)

	_portrait = Control.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.set_meta("id", HOTARU)
	_portrait.draw.connect(_draw_portrait)
	_title = Ui.label("")
	_title.add_theme_font_override("font", _face())
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", UiTheme.AMBER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_steps = Ui.label("")
	_steps.add_theme_font_override("font", OverworldStyle.body_font(600))
	_steps.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_steps.add_theme_color_override("font_color", OverworldStyle.MUTED)
	var title_row := Ui.hbox([_title, _steps], 8)
	_pips = Control.new()
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(40, BAR_HEIGHT)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_percent = Ui.label("")
	_percent.add_theme_font_override("font", OverworldStyle.body_font(600))
	_percent.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_percent.add_theme_color_override("font_color", UiTheme.AMBER)
	_bar_box = Ui.hbox([_bar, _percent], 8)
	_bar_box.visible = false
	_area = Ui.vbox([_pips, _bar_box], 0)
	var titles := Ui.vbox([title_row, _area], 4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_head = Ui.hbox([_portrait, titles], 12)

	_mark = PauseMenu.mark("todo", 22.0)
	_mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_mark.custom_minimum_size.y = 28.0
	_step = Ui.label("", "", true)
	_step.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	_step.add_theme_color_override("font_color", PauseMenu.INK)
	_step.add_theme_constant_override("line_spacing", -5)
	_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress = Ui.label("")
	_progress.add_theme_font_override("font", OverworldStyle.body_font(600))
	_progress.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_progress.add_theme_color_override("font_color", UiTheme.AMBER)
	_progress.resized.connect(func() -> void: _progress.pivot_offset = _progress.size / 2.0)
	_progress_row = Ui.hbox([Ui.spacer(INDENT, 0), _progress], 0)
	_progress_row.visible = false
	_dir_arrow = Control.new()
	_dir_arrow.custom_minimum_size = Vector2(22, 22)
	_dir_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dir_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dir_arrow.draw.connect(_draw_arrow)
	_dir_label = Ui.label("")
	_dir_label.add_theme_font_override("font", OverworldStyle.body_font(600))
	_dir_label.add_theme_font_size_override("font_size", OverworldStyle.HINT)
	_dir_label.add_theme_color_override("font_color", OverworldStyle.MUTED)
	_dir_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_dir_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dir_row = Ui.hbox([_dir_arrow, _dir_label], 12)
	_dir_row.visible = false
	_row = Ui.vbox([Ui.hbox([_mark, _step], 12), _progress_row, _dir_row], 2)
	_card.add_child(Ui.vbox([_head, _row], 8))


func _card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var id := String(_wanted.get("id", ""))
		if id != "" and _card_on and _shown and not _hidden:
			_card.accept_event()
			requested.emit(id)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	var style := PauseMenu.panel_style(Vector2(26, 14))
	style.border_color = UiTheme.AMBER
	_toast.add_theme_stylebox_override("panel", style)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = TOAST_TOP
	_toast.visible = false
	add_child(_toast)
	_toast_text = Ui.label("")
	_toast_text.add_theme_font_override("font", OverworldStyle.body_font(600))
	_toast_text.add_theme_font_size_override("font_size", OverworldStyle.BODY)
	_toast_text.add_theme_color_override("font_color", PauseMenu.INK)
	_toast.add_child(Ui.hbox([PauseMenu.mark("done", 32.0), _toast_text], 14))


## The title's letters: the body face in its semibold, spaced a little, which with capitals reads as small capitals.
static func _face() -> Font:
	if _title_face == null:
		_title_face = FontVariation.new()
		_title_face.base_font = OverworldStyle.body_font(600)
		_title_face.spacing_glyph = 1
	return _title_face


# --- what the town tells it ----------------------------------------------------------------------------------------


## The townsfolk (their portraits) and the maps (their names), for the giver's face and "In Lanternroot".
func setup(catalog: Dictionary) -> void:
	_catalog = catalog
	_minimap.setup(catalog)
	if _drawn != NEVER:
		_refresh_portrait()
		_refresh_direction()


## The minimap under the card: the town gives it the map (`show_map`), the people and `set_enabled(true)`.
func minimap() -> Minimap:
	return _minimap


## The quest the player chose to follow in the log; "" follows the first open one. A tracked quest that is not open is
## ignored (Quests.current).
func set_tracked(id: String) -> void:
	if id == _tracked:
		return
	_tracked = id
	if _following:
		_wanted = Quests.current(_quests, _flags, _tracked)
		_catch_up()


## The parts the player has built: `progress_of(done, total)` gives the percent (-1 while the part is not built) and
## `place_at(map_id, cell)` gives a place's name ("" for none). Either may be an empty Callable.
func set_parts(progress_of: Callable, place_at: Callable) -> void:
	_progress_of = progress_of
	_place_at = place_at
	if _drawn != NEVER:
		_refresh_area()
		_refresh_direction()
	_refresh_line()


## The clock's text for the line under the minimap ("" while the clock is not built).
func set_clock(text: String) -> void:
	_clock = text
	_refresh_line()


## The player is on `cell` of `map_id`: the arrow, the distance and the minimap follow.
func locate(map_id: String, cell: Vector2i) -> void:
	_located = true
	var moved := map_id != _map_id or cell != _cell
	_map_id = map_id
	_cell = cell
	_minimap.set_player(cell)
	if moved:
		_refresh_direction()
		_refresh_line()


## The town's flags after a change. Returns the quests this change finished (none the first time: those were done
## before the town was shown). Their toasts are queued; the card catches up now, or when it is next shown.
func follow(quests: Dictionary, flags: Dictionary) -> Array[String]:
	var done: Array[String] = []
	if _following:
		done = Quests.finished(quests, _flags, flags)
	_quests = quests
	_flags = flags.duplicate()
	_following = true
	_wanted = Quests.current(quests, flags, _tracked)
	for id in done:
		var title := String((quests.get(id, {}) as Dictionary).get("title", id))
		_toasts.append(Text.f("Quest complete: %s", [Text.t(title)]))
	if _drawn == NEVER:
		_draw_now()
	else:
		_catch_up()
	_next_toast()
	return done


## Shows or hides the card (a short fade). A step that changed while it was hidden flourishes once it is back.
func set_shown(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	_apply_shown()


## H: hides the whole tracker (the card and the minimap, not a toast) or shows it again. Stays hidden through the
## town's own showing and hiding (a menu opening and closing).
func toggle_hidden() -> void:
	set_hidden(not _hidden)


func set_hidden(on: bool) -> void:
	if on == _hidden:
		return
	_hidden = on
	_apply_shown()


func is_hidden() -> bool:
	return _hidden


## Whether the card is on show: the town wants it and the player has not hidden it.
func is_shown() -> bool:
	return _shown and not _hidden


func _apply_shown() -> void:
	var on := _shown and not _hidden
	_minimap.set_shown(on)
	if on == _card_on:
		return
	_card_on = on
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if on:
		_card.visible = true
		_fade = OverworldStyle.pop_in(_card, _card)
		_fade.chain().tween_callback(_catch_up)
	else:
		_fade = OverworldStyle.fade_out(_card, func() -> void: _card.visible = _card_on)


## The step on the card (for tests and the town): its words as drawn.
func step_text() -> String:
	return _step.text


## The quest's title as the town knows it (the card draws it in capitals).
func title_text() -> String:
	return _title_source


## "2 / 4": the steps done of the quest's steps; "" when every quest is done.
func steps_text() -> String:
	return _steps.text


## The count of a counting step ("3 / 6"), or "" when the step does not count.
func count_text() -> String:
	return _progress.text if _progress_row.visible else ""


## The toast on screen now, or "" when there is none.
func toast_text() -> String:
	return _toast_text.text if _toast.visible else ""


## The percent the bar shows (the target it is moving to), or -1 when the card shows pips.
func bar_percent() -> int:
	return _bar_percent if _bar_box.visible else -1


func pips_showing() -> bool:
	return _pips.visible and _area.visible


## The direction line's words ("14 tiles · Warm Hearth Row"), or "" when the step has no pin or the player is unknown.
func direction_text() -> String:
	return _dir_label.text if _dir_row.visible else ""


## Which way the arrow points ("e", "se", ... "ne"), "here" on the pin, "away" for a pin on another map, or "".
func direction_arrow() -> String:
	return _arrow if _dir_row.visible else ""


## The way from `from` toward `to`, one of ARROWS ("e", "se", "s", ...), or "" when they are the same cell. The nearest
## of the eight directions to the true bearing, the way the screen is laid out (down is south).
static func arrow_of(from: Vector2i, to: Vector2i) -> String:
	var delta := to - from
	if delta == Vector2i.ZERO:
		return ""
	var eighth := int(round(atan2(float(delta.y), float(delta.x)) / (PI / 4.0)))
	return ARROWS[posmod(eighth, 8)]


# --- drawing the step -------------------------------------------------------------------------------------------------


func _key_of(quest: Dictionary) -> String:
	return ALL_DONE if quest.is_empty() else "%s:%d" % [quest.id, int(quest.step)]


## Puts the wanted step on the card at once, with no flourish.
func _draw_now() -> void:
	_drawn = _key_of(_wanted)
	if _wanted.is_empty():
		_title_source = Text.t("All done for now")
		_step.text = Text.t("Lanternroot is yours to explore.")
		_steps.text = ""
		PauseMenu.set_mark(_mark, "done")
	else:
		_title_source = Text.t(String(_wanted.title))
		_step.text = Text.t(String(_wanted.text))
		_steps.text = "%d / %d" % [int(_wanted.done), int(_wanted.total)]
		PauseMenu.set_mark(_mark, "todo")
	_title.text = _title_source.to_upper()
	_set_progress(String(_wanted.get("progress", "")))
	_refresh_portrait()
	_refresh_area()
	_refresh_direction()


## The card catches up with the town: a new step flourishes (when the card is shown), a new count pulses.
func _catch_up() -> void:
	if _busy:
		return
	if _key_of(_wanted) == _drawn:
		# A later step can finish while the current instruction stays the same. Refresh its count and bar too.
		_steps.text = "" if _wanted.is_empty() else "%d / %d" % [int(_wanted.done), int(_wanted.total)]
		_refresh_area()
		var progress := String(_wanted.get("progress", ""))
		if progress != _progress.text:
			_set_progress(progress)
			_pulse(_progress)
		_refresh_direction()
		return
	if not _card_on or not is_inside_tree():
		return
	_flourish()


func _set_progress(progress: String) -> void:
	_progress.text = progress
	_progress_row.visible = progress != ""


## The giver's face in the ring: Hotaru when every quest is done or the quest has no giver of its own.
func _refresh_portrait() -> void:
	var giver := String(_wanted.get("giver", ""))
	var id := HOTARU
	var who := "Hotaru"
	if giver != "" and giver != HOTARU:
		var person: Dictionary = (_catalog.get("townsfolk", {}) as Dictionary).get(giver, {})
		id = String(person.get("portrait", ""))
		who = String(person.get("name", giver))
	_portrait.set_meta("id", id)
	_portrait.set_meta("name", who)
	_portrait.queue_redraw()


## Pips until the player's `progress` is built and gives a percent, then a bar (which moves to a new value in 0.4 s).
func _refresh_area() -> void:
	_area.visible = not _wanted.is_empty()
	if _wanted.is_empty():
		_bar_percent = -1
		return
	var percent := -1
	if _progress_of.is_valid():
		percent = int(_progress_of.call(int(_wanted.done), int(_wanted.total)))
	if percent < 0:
		_bar_percent = -1
		_bar_box.visible = false
		_pips.visible = true
		_pips.custom_minimum_size = Vector2(_pip_count() * PIP, PIP)
		_pips.queue_redraw()
		return
	percent = clampi(percent, 0, 100)
	_pips.visible = false
	_bar_box.visible = true
	_percent.text = "%d%%" % percent
	var target := percent / 100.0
	var first := _bar_percent < 0
	_bar_percent = percent
	if _bar_motion != null and _bar_motion.is_valid():
		_bar_motion.kill()
	if first or Settings.reduced_motion or not is_inside_tree() or not _card_on:
		_bar_value = target
		_bar.queue_redraw()
		return
	_bar_motion = create_tween()
	_bar_motion.tween_method(_set_bar_value, _bar_value, target, BAR_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_bar_value(value: float) -> void:
	_bar_value = value
	_bar.queue_redraw()


## The direction line: only for a step with a pin, once the player's map is known. A pin in another place says which.
func _refresh_direction() -> void:
	var pin: Dictionary = _wanted.get("at", {})
	if _wanted.is_empty() or pin.is_empty() or not _located:
		_dir_row.visible = false
		_minimap.set_pin(NONE)
		return
	var pin_map := String(pin.get("map", ""))
	var target := OverworldMap.cell_of(pin.get("at", [0, 0]))
	if pin_map != "" and pin_map != _map_id:
		_minimap.set_pin(NONE)
		_arrow = "away"
		_dir_label.text = _elsewhere(pin_map)
	else:
		_minimap.set_pin(target)
		var delta := target - _cell
		_arrow = arrow_of(_cell, target)
		var place := String(_place_at.call(_map_id, target)) if _place_at.is_valid() else ""
		if _arrow == "":
			_arrow = "here"
			_dir_label.text = Text.t("Right here")
		else:
			var steps := absi(delta.x) + absi(delta.y)
			_dir_label.text = Text.t("1 tile") if steps == 1 else Text.f("%d tiles", [steps])
		if place != "":
			_dir_label.text += " · " + Text.t(place)
	_dir_row.visible = true
	_dir_arrow.queue_redraw()


## "In Lanternroot", "At home": where a pin on another map is, from the map's name in the catalog.
func _elsewhere(map_id: String) -> String:
	var map: Dictionary = (_catalog.get("maps", {}) as Dictionary).get(map_id, {})
	var named := Text.t(String(map.get("name", map_id)))
	if map_id == "home":
		return Text.t("At home")
	if bool(map.get("interior", false)):
		return Text.f("Inside %s", [named])
	return Text.f("In %s", [named])


## The line under the minimap: where the player is (the player's `place_at`) and the clock.
func _refresh_line() -> void:
	var place := ""
	if _located and _place_at.is_valid():
		place = String(_place_at.call(_map_id, _cell))
	_minimap.set_line(Text.t(place), _clock)


## The old step is ticked, holds a moment, and slides away to the right; the new one rises into its place. A new
## quest's title goes and comes with it. Anything that changed meanwhile is caught up at the end.
func _flourish() -> void:
	_busy = true
	var new_quest := _wanted.is_empty() or not _drawn.begins_with(String(_wanted.id) + ":")
	# A typed array built by appending: a ternary of two untyped literals is an Array, which does not fit Array[Control].
	var parts: Array[Control] = [_row]
	if new_quest:
		parts.append(_head)
	var homes: Array[Vector2] = []
	for part in parts:
		homes.append(part.position)
	PauseMenu.set_mark(_mark, "done")
	Sound.play("sfx-chime", 0.25, 1.2)
	var tween := create_tween()
	tween.tween_property(_mark, "scale", Vector2.ONE * 1.35, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_mark, "scale", Vector2.ONE, 0.16)
	tween.tween_interval(TICK_HOLD)
	# LEARN: in a parallel Tween every new tweener joins the step before it; chain() starts a new step, and the
	# tweeners after it join that one. So each phase opens with chain() and its other tweeners run beside it.
	tween.set_parallel()
	tween.chain().tween_interval(0.0)
	for i in parts.size():
		tween.tween_property(parts[i], "position:x", homes[i].x + SLIDE, 0.22).set_ease(Tween.EASE_IN)
		tween.tween_property(parts[i], "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(_draw_now)
	tween.chain().tween_interval(0.0)
	for i in parts.size():
		tween.tween_property(parts[i], "position", homes[i], 0.28).from(homes[i] + Vector2(0, 14)).set_ease(
			Tween.EASE_OUT
		)
		tween.tween_property(parts[i], "modulate:a", 1.0, 0.28)
	tween.chain().tween_callback(
		func() -> void:
			_busy = false
			_catch_up()
	)


func _pulse(control: Control) -> void:
	if not is_inside_tree():
		return
	control.scale = Vector2.ONE * 1.3
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _pip_count() -> int:
	return 0 if _wanted.is_empty() else int(_wanted.total)


## A later completed step keeps its own pip; completion count is not a prefix of the checklist.
func pip_state(index: int) -> String:
	if _wanted.is_empty() or index < 0 or index >= _pip_count():
		return ""
	var quest: Dictionary = _quests.get(String(_wanted.id), {})
	var steps: Array = quest.get("steps", [])
	if index < steps.size() and Quests.holds((steps[index] as Dictionary).get("done", {}), _flags):
		return "done"
	return "current" if index == int(_wanted.step) else "pending"


## A pip for each of the quest's steps: filled for a done step, a ring with a dot for the step under way, a faint ring
## for the steps to come.
func _draw_pips() -> void:
	var total := _pip_count()
	for i in total:
		var centre := Vector2(PIP / 2.0 + i * PIP, _pips.size.y / 2.0)
		var status := pip_state(i)
		if status == "done":
			_pips.draw_circle(centre, 6.0, UiTheme.AMBER)
		elif status == "current":
			_pips.draw_arc(centre, 6.0, 0.0, TAU, 20, UiTheme.AMBER, 2.0, true)
			_pips.draw_circle(centre, 2.5, UiTheme.AMBER)
		else:
			_pips.draw_arc(centre, 6.0, 0.0, TAU, 20, Color(UiTheme.AMBER_DIM, 0.7), 2.0, true)


## The bar: a dark track with a thin amber edge, filled with the panel's amber up to the player's percent.
func _draw_bar() -> void:
	var area := Rect2(Vector2.ZERO, _bar.size)
	UiTheme.box(Color(0, 0, 0, 0.4), Color(UiTheme.AMBER_DIM, 0.8), 1, int(BAR_HEIGHT / 2.0)).draw(_bar.get_canvas_item(), area)
	var inner := area.grow(-2.0)
	var width := maxf(inner.size.y, inner.size.x * _bar_value) if _bar_value > 0.0 else 0.0
	if width <= 0.0:
		return
	var fill := Rect2(inner.position, Vector2(width, inner.size.y))
	UiTheme.box(UiTheme.AMBER, Color.TRANSPARENT, 0, int(inner.size.y / 2.0)).draw(_bar.get_canvas_item(), fill)
	# A glint along the top edge of the fill, so it reads as a lit bar rather than a flat one.
	_bar.draw_line(fill.position + Vector2(inner.size.y / 2.0, 1.5), fill.position + Vector2(maxf(fill.size.x - inner.size.y / 2.0, inner.size.y / 2.0), 1.5), Color(1, 1, 1, 0.3), 1.5)


## The giver's face in a round frame with an amber ring: the portrait clipped to a circle, or the giver's initial.
func _draw_portrait() -> void:
	draw_face(_portrait, _portrait.size / 2.0, minf(_portrait.size.x, _portrait.size.y) / 2.0, String(_portrait.get_meta("id", "")), String(_portrait.get_meta("name", "?")))


## A round portrait on `canvas`: a dark disc, the face of the portrait `id` clipped to a circle inside an amber ring, or
## `name`'s first letter when the picture is missing. The quest log's list uses it too.
static func draw_face(canvas: CanvasItem, centre: Vector2, radius: float, id: String, name: String) -> void:
	var inner := radius - maxf(2.0, radius * 0.14)
	canvas.draw_circle(centre, radius, Color("#1a1410"))
	var texture := OverworldArt.portrait(id) if id != "" else null
	if texture != null:
		# The face is the middle nine tenths of the picture, laid on a circle polygon through its UVs.
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 40:
			var unit := Vector2.from_angle(TAU * i / 40.0)
			points.append(centre + unit * inner)
			uvs.append(Vector2(0.5, 0.48) + unit * 0.46)
		canvas.draw_colored_polygon(points, Color.WHITE, uvs, texture)
	else:
		canvas.draw_circle(centre, inner, Color(UiTheme.AMBER_DIM, 0.3))
		var initial := name.substr(0, 1).to_upper()
		var font := OverworldStyle.body_font(600)
		var font_size := int(radius * 1.1)
		var size := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		canvas.draw_string(font, centre + Vector2(-size.x / 2.0, size.y / 4.0), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.AMBER)
	canvas.draw_arc(centre, radius - maxf(1.0, radius * 0.07), 0.0, TAU, 48, UiTheme.AMBER, maxf(1.5, radius * 0.13), true)


## The arrow of the direction line, drawn so it reads in any font: a shaft and a head toward the pin; a ring on the pin
## itself; a small door for a pin on another map.
func _draw_arrow() -> void:
	var centre := _dir_arrow.size / 2.0
	match _arrow:
		"here":
			_dir_arrow.draw_arc(centre, 6.0, 0.0, TAU, 20, UiTheme.AMBER, 2.0, true)
			_dir_arrow.draw_circle(centre, 2.5, UiTheme.AMBER)
		"away":
			var door := Rect2(centre - Vector2(5, 7), Vector2(10, 14))
			UiTheme.box(Color(UiTheme.AMBER, 0.2), UiTheme.AMBER, 2, 3).draw(_dir_arrow.get_canvas_item(), door)
			_dir_arrow.draw_circle(centre + Vector2(2, 1), 1.3, UiTheme.AMBER)
		"":
			pass
		_:
			var way := Vector2.from_angle(ARROWS.find(_arrow) * PI / 4.0)
			var side := way.orthogonal()
			var tip := centre + way * 10.0
			var neck := centre + way * 2.0
			_dir_arrow.draw_line(centre - way * 8.0, neck, UiTheme.AMBER, 3.5, true)
			_dir_arrow.draw_colored_polygon(PackedVector2Array([tip, neck + side * 7.0, neck - side * 7.0]), UiTheme.AMBER)


# --- the toast ----------------------------------------------------------------------------------------------------


## The next queued toast drops in from the top, holds, and fades; then the one after it.
func _next_toast() -> void:
	if _toasting or _toasts.is_empty() or not is_inside_tree():
		return
	_toasting = true
	_toast_text.text = _toasts.pop_front()
	_toast.visible = true
	Sound.play("sfx-pass", 0.45)
	if _toast_motion != null and _toast_motion.is_valid():
		_toast_motion.kill()
	_toast.modulate.a = 0.0
	_toast_motion = create_tween()
	_toast_motion.set_parallel()
	_toast_motion.tween_property(_toast, "modulate:a", 1.0, 0.2)
	(
		_toast_motion
		. tween_property(_toast, "offset_top", TOAST_TOP, 0.3)
		. from(TOAST_TOP - 24.0)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_toast_motion.chain().tween_interval(TOAST_HOLD)
	_toast_motion.chain().tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_motion.chain().tween_callback(
		func() -> void:
			_toast.visible = false
			_toasting = false
			_next_toast()
	)
