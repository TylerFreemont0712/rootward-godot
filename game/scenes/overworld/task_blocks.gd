class_name TaskBlocks
extends PanelContainer
## The Builder's side of a v0.4 task (Concept/v0.4/02, section 3): the task's real code lines in the player's language,
## with a chip in place of each {slot} and a switch beside each [toggle] group of lines. It is a fill-in of the real
## program, never a different language:
##
##   ┌ ○── When a key is pressed, open something │  def shortcut(key):
##   │                                           │      if key == [ "escape" ⌄ ]:
##   │                                           │          return [ "menu" ⌄ ]
##   │ ●── Open the bag on a key                 │      return None
##
## A slot is an OptionButton chip showing Tasks.choice_label for each of its choices; a toggle is a CheckButton that
## dims its lines (alpha 0.35) while it is off. A slot or toggle whose `stage` is above the open stage is hidden, and
## so are the lines of a hidden toggle (a hidden slot on a shown line is plain code, its chosen choice).
##
##   var blocks := TaskBlocks.new()
##   blocks.setup(task, record.blocks, "python", stage)
##   blocks.changed.connect(func(now: Dictionary) -> void: ...)   # {slots: {id: index}, toggles: [ids on]}
##
## Arrows move between the chips and switches, Enter opens a chip or flips a switch.

signal changed(blocks: Dictionary)

const CODE_COLOUR := Color("#f3e6c8")
const CHIP_COLOUR := Color("#ffd58a")
const SWITCH_WIDTH := 290.0
const LINE_HEIGHT := 30.0
## How faded the lines of a switch that is off are.
const DIM := 0.35
const SWITCH_SIZE := Vector2i(52, 28)
const SLOT := "\\{(\\w+)\\}"

static var _switch_icons: Dictionary = {}

## The slot's chips (OptionButton) by slot id, one each, and the toggles' switches (CheckButton) by toggle id: only the
## ones the open stage shows.
var chips: Dictionary = {}
var switches: Dictionary = {}

var _task: Dictionary = {}
var _language := Tasks.PYTHON
var _stage := 0
var _blocks: Dictionary = {}
## Every chip of a slot (a slot may sit on several lines and then has the same choice everywhere).
var _chips_of: Dictionary = {}
## The lines box of each toggle group, dimmed with the switch, and its panel, edged amber with the switch.
var _group_lines: Dictionary = {}
var _group_panels: Dictionary = {}
var _line_count := 0
var _column: VBoxContainer


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UiTheme.box(Color(0.07, 0.05, 0.04, 0.6), LessonBlocks.EDGE, 1, 10, Vector2(12, 10))
	box.border_width_left = 6
	box.border_color = UiTheme.AMBER_DIM
	add_theme_stylebox_override("panel", box)
	_column = Ui.vbox([], 8)
	add_child(_column)


## Lays the task's lines out for `blocks` ({slots: {id: index}, toggles: [ids on]}) in `language` at `stage`.
func setup(task: Dictionary, blocks: Dictionary, language: String, stage: int) -> void:
	_task = task
	_language = language
	_stage = stage
	_blocks = normalized(task, blocks)
	_rebuild()


## The blocks as the player has them now.
func blocks() -> Dictionary:
	return _blocks.duplicate(true)


## How many lines of code the blocks show (the lines of hidden or switched-off groups count: they are there, dimmed).
func lines_shown() -> int:
	return _line_count


func is_slot_shown(id: String) -> bool:
	return chips.has(id)


func is_toggle_shown(id: String) -> bool:
	return switches.has(id)


## Picks choice `index` of slot `id` (what a click on the chip's menu does).
func choose(id: String, index: int) -> void:
	if not _chips_of.has(id):
		return
	for chip: OptionButton in _chips_of[id]:
		chip.select(index)
	_choose(id, index)


## Turns toggle `id` on or off (what the switch does).
func set_toggle(id: String, on: bool) -> void:
	if switches.has(id):
		(switches[id] as CheckButton).button_pressed = on


## The first chip or switch that can take the focus.
func first_focus() -> Control:
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button.focus_mode != Control.FOCUS_NONE and button.is_visible_in_tree():
			return button
	return null


func _design() -> Dictionary:
	return _task.get("blocks", {}) if _task.get("blocks", {}) is Dictionary else {}


## `blocks` with every slot and toggle present: what a record may lack falls back to the task's fresh blocks.
static func normalized(task: Dictionary, blocks: Dictionary) -> Dictionary:
	var fresh := Tasks.fresh_blocks(task)
	var slots: Dictionary = fresh.slots
	var kept: Variant = blocks.get("slots", {})
	if kept is Dictionary:
		for id: String in slots:
			if (kept as Dictionary).has(id):
				slots[id] = int((kept as Dictionary)[id])
	var toggles: Array = []
	var asked: Variant = blocks.get("toggles", fresh.toggles)
	if asked is Array:
		for id: Variant in asked:
			if not String(id) in toggles:
				toggles.append(String(id))
	return {"slots": slots, "toggles": toggles}


func _rebuild() -> void:
	Ui.clear(_column)
	chips.clear()
	switches.clear()
	_chips_of.clear()
	_group_lines.clear()
	_group_panels.clear()
	_line_count = 0
	var design := _design()
	var toggles: Dictionary = design.get("toggles", {})
	var raw_lines: Array = (design.get("lines", {}) as Dictionary).get(_language, []) if design.get("lines", {}) is Dictionary else []
	# Consecutive lines of the same toggle make one group; a toggle that is not shown yet hides its lines.
	var groups: Array[Dictionary] = []
	for raw: Variant in raw_lines:
		var line := String(raw)
		var toggle := Tasks.line_toggle(line)
		if toggle != "":
			if not toggles.has(toggle) or not Tasks.shows_at(toggles[toggle], _stage):
				continue
			line = line.substr(toggle.length() + 2)
		if groups.is_empty() or String(groups[-1].toggle) != toggle:
			groups.append({"toggle": toggle, "lines": []})
		(groups[-1].lines as Array).append(line)
	for group in groups:
		_column.add_child(_group_row(String(group.toggle), group.lines))


func _group_row(toggle: String, lines: Array) -> Control:
	var body := Ui.vbox([], 2)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line: Variant in lines:
		body.add_child(_line(String(line)))
		_line_count += 1
	if toggle == "":
		return Ui.hbox([Ui.spacer(SWITCH_WIDTH + 9.0, 0), body], 12)
	var design: Dictionary = (_design().toggles as Dictionary)[toggle]
	var switch := _switch(toggle, Text.t(String(design.get("label", toggle))))
	switch.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var panel := PanelContainer.new()
	panel.add_child(Ui.hbox([switch, body], 12))
	_group_lines[toggle] = body
	_group_panels[toggle] = panel
	switches[toggle] = switch
	_paint_group(toggle)
	return panel


## One line of code: its indentation, then its text and chips side by side.
func _line(line: String) -> Control:
	var indent := 0
	while indent < line.length() and line[indent] == " ":
		indent += 1
	var row := Ui.hbox([], 0)
	row.custom_minimum_size.y = LINE_HEIGHT
	var font := UiTheme.code_font()
	if indent > 0:
		# (a spacer of no size would expand, so none is added for an unindented line)
		row.add_child(Ui.spacer(font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, OverworldStyle.EDITOR_CODE).x * indent, 0))
	var pattern := RegEx.create_from_string(SLOT)
	var rest := line.substr(indent)
	var from := 0
	for found in pattern.search_all(rest):
		row.add_child(_text(rest.substr(from, found.get_start() - from)))
		var id := found.get_string(1)
		var slots: Dictionary = _design().get("slots", {})
		if slots.has(id) and Tasks.shows_at(slots[id], _stage):
			row.add_child(_chip(id))
		else:
			row.add_child(_text(Tasks.choice_code(slots.get(id, {}), int((_blocks.slots as Dictionary).get(id, 0)), _language)))
		from = found.get_end()
	row.add_child(_text(rest.substr(from)))
	return row


func _text(text: String) -> Control:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.code_font())
	label.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_CODE)
	label.add_theme_color_override("font_color", CODE_COLOUR)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _chip(id: String) -> Control:
	var slot: Dictionary = (_design().slots as Dictionary)[id]
	var chip := OptionButton.new()
	var choices: Array = slot.get("choices", [])
	for i in choices.size():
		chip.add_item(Tasks.choice_label(slot, i, _language), i)
	chip.select(clampi(int((_blocks.slots as Dictionary).get(id, 0)), 0, maxi(choices.size() - 1, 0)))
	chip.tooltip_text = Text.t(String(slot.get("label", id)))
	chip.focus_mode = Control.FOCUS_ALL
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.add_theme_font_override("font", UiTheme.code_font(600))
	chip.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_CODE)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		chip.add_theme_color_override(colour, CHIP_COLOUR)
	var pad := Vector2(8, 1)
	chip.add_theme_stylebox_override("normal", UiTheme.box(Color("#2a1f12"), UiTheme.AMBER_DIM, 1, 6, pad))
	chip.add_theme_stylebox_override("hover", UiTheme.box(Color("#3a2a15"), UiTheme.AMBER, 1, 6, pad))
	chip.add_theme_stylebox_override("pressed", UiTheme.box(Color("#3a2a15"), UiTheme.AMBER, 1, 6, pad))
	chip.add_theme_stylebox_override("hover_pressed", UiTheme.box(Color("#3a2a15"), UiTheme.AMBER, 1, 6, pad))
	var menu := chip.get_popup()
	menu.add_theme_font_override("font", UiTheme.code_font())
	menu.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_CODE)
	chip.item_selected.connect(func(index: int) -> void: _chosen(id, index, chip))
	if not chips.has(id):
		chips[id] = chip
	if not _chips_of.has(id):
		_chips_of[id] = []
	(_chips_of[id] as Array).append(chip)
	return chip


func _switch(toggle: String, label: String) -> CheckButton:
	var button := CheckButton.new()
	button.text = label
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(SWITCH_WIDTH, LINE_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", OverworldStyle.body_font(600))
	button.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(colour, UiTheme.TEXT)
	for state: String in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 8, Vector2(2, 2)))
	button.add_theme_icon_override("checked", _switch_icon(true))
	button.add_theme_icon_override("unchecked", _switch_icon(false))
	button.add_theme_icon_override("checked_disabled", _switch_icon(true))
	button.add_theme_icon_override("unchecked_disabled", _switch_icon(false))
	button.add_theme_constant_override("h_separation", 12)
	button.set_pressed_no_signal(toggle in (_blocks.toggles as Array))
	button.toggled.connect(func(on: bool) -> void: _toggled(toggle, on))
	return button


func _toggled(toggle: String, on: bool) -> void:
	var on_now: Array = _blocks.toggles
	if on and not toggle in on_now:
		on_now.append(toggle)
	elif not on:
		on_now.erase(toggle)
	_paint_group(toggle)
	Sound.play("sfx-card-place-1" if on else "sfx-card-flick-1", 0.35)
	changed.emit(blocks())


func _chosen(id: String, index: int, from: OptionButton) -> void:
	for chip: OptionButton in _chips_of.get(id, []):
		if chip != from:
			chip.select(index)
	_choose(id, index)


func _choose(id: String, index: int) -> void:
	(_blocks.slots as Dictionary)[id] = index
	Sound.play("sfx-card-flick-1", 0.35)
	changed.emit(blocks())


## A group's lines fade while its switch is off, and its panel is edged in amber while it is on.
func _paint_group(toggle: String) -> void:
	var on := toggle in (_blocks.toggles as Array)
	(_group_lines[toggle] as Control).modulate.a = 1.0 if on else DIM
	var panel := _group_panels[toggle] as PanelContainer
	var box := UiTheme.box(
		LessonBlocks.FILL_ON if on else Color(0.1, 0.075, 0.055, 0.7),
		UiTheme.AMBER_DIM if on else LessonBlocks.EDGE,
		1,
		8,
		Vector2(8, 6),
	)
	panel.add_theme_stylebox_override("panel", box)


## The switch's picture: a pill, amber with the knob at the right when on, dark with the knob at the left when off.
static func _switch_icon(on: bool) -> Texture2D:
	if _switch_icons.has(on):
		return _switch_icons[on]
	var width := SWITCH_SIZE.x
	var height := SWITCH_SIZE.y
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var radius := height / 2.0 - 1.0
	var left := Vector2(height / 2.0, height / 2.0)
	var right := Vector2(width - height / 2.0, height / 2.0)
	var knob_at := right if on else left
	var track := UiTheme.AMBER if on else Color("#3a2f22")
	var rim := UiTheme.AMBER_DIM if on else Color("#7a6648")
	var knob := Color("#2a1a0c") if on else Color("#cdbb98")
	for y in height:
		for x in width:
			var at := Vector2(x + 0.5, y + 0.5)
			var closest := Vector2(clampf(at.x, left.x, right.x), left.y)
			var d := at.distance_to(closest) - radius
			var colour := track.lerp(rim, clampf(d + 2.5, 0.0, 1.0))
			var k := clampf(0.5 - (at.distance_to(knob_at) - (radius - 4.0)), 0.0, 1.0)
			colour = colour.lerp(knob, k)
			colour.a = clampf(0.5 - d, 0.0, 1.0)
			image.set_pixel(x, y, colour)
	var made := ImageTexture.create_from_image(image)
	_switch_icons[on] = made
	return made
