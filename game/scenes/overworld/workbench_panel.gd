class_name WorkbenchPanel
extends Control
## The Workbench (Concept/v0.4/01, section 7): every part of the game the player has built, or is going to. At the top
## is the Lantern Engine, a chain of gears, one for each part: a built part's gear turns slowly, a missing part is an
## empty socket. Under it a grid of part cards, three across: the lessons from before (the boots, the save, the lamps)
## and then each task. Choosing a card shows the program that runs for it (read-only) in a side panel, with an Open
## button.
##
##   workbench.open(catalog, state)       # catalog: OverworldScreen.catalog_of(); state: the overworld's state
##   open_part(id)                        # Open: "boots", "save", "lamps" or a task's id
##   closed                               # Esc, B or Close
##
## Each card: the part's name, a gear (amber and lit when built, dim when not), the giver's round portrait, the
## function as the player writes it, the status ("Built", "Stage 2 of 3", "Stage 2 waits: Nym has an idea", "Not yet:
## ask Mira") and what the part does once built. Arrows, Enter, Esc and the mouse all work.
##
## Chapter 3 (Concept/v0.4/05, 2.11): with set_history(changed), a built task whose record keeps two or more versions says
## which lines changed since the version before, and a Before button shows that version. history_viewed(id) is emitted
## when that line is shown.

signal open_part(id: String)
signal closed
signal history_viewed(id: String)

const SIZE := Vector2(1900, 1060)
const SIDE_WIDTH := 560.0
const CARD_HEIGHT := 150.0
const FACE := 44.0
const BUILT_COLOUR := Color("#d6f57a")
const ENGINE_GEAR_SPACING := 76.0
const ENGINE_ROW_HEIGHT := 112.0
const ENGINE_EDGE := 54.0
const ENGINE_MAX_COLUMNS := 18
## The people the lessons from before came from (their quests' givers), when a quest has none to name.
const HOTARU := "hotaru"

var _open := false
var _catalog: Dictionary = {}
var _state: Dictionary = {}
var _language := Tasks.PYTHON
var _entries: Array[Dictionary] = []
## The cards by part id, for keys and tests.
var cards: Dictionary = {}
var _shown := -1
var _last := 0
var _motion: Tween

var _card: PanelContainer
var _count: Label
var _engine: EngineView
var _grid: GridContainer
var _name: Label
var _status: Label
var _does: Label
var _code: LessonCode
var _empty: Label
var _note: Label
var _open_button: Button
## Check again (Concept/v0.4/01, section 7): every case of every stage the part has passed, run on its program.
var _check_button: Button
var _check_line: Label
var _checking := false
## Chapter 3's history: the live comparison, the line and button under Check again, and which version is on show.
var _changed: Callable
var _history_line: Label
var _history_button: Button
var _viewing_before := false
var _history_token := 0
var _compared: Dictionary = {}


func _ready() -> void:
	theme = OverworldStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.05, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", PauseMenu.panel_style(Vector2(26, 18)))
	_card.custom_minimum_size = SIZE
	centre.add_child(_card)
	var heading := Ui.label(Text.t("The Workbench"), "Heading")
	heading.add_theme_color_override("font_color", UiTheme.AMBER)
	_count = PauseMenu.small("")
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close := Ui.button(Text.t("Close"), close_panel)
	close.custom_minimum_size = Vector2(120, 0)
	var top := Ui.hbox([heading, _count, Ui.spacer(), close], 16)
	_engine = EngineView.new()
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := Ui.scroll(_grid)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := Ui.hbox([scroll, PauseMenu.divider(), _side()], 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var help := PauseMenu.help_line(Text.t("Arrows: choose   Enter: look at the code   Esc: back"))
	_card.add_child(Ui.vbox([top, _engine, PauseMenu.rule(), body, PauseMenu.rule(), help], 12))


## The side panel: the part chosen, what it does, the program that runs, and Open.
func _side() -> Control:
	_name = Ui.label("", "Heading", true)
	_name.add_theme_font_size_override("font_size", 30)
	_name.add_theme_color_override("font_color", UiTheme.AMBER)
	_status = Ui.label("", "", true)
	_status.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	_does = Ui.label("", "", true)
	_does.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	_code = LessonCode.new(false)
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty = Ui.label("", "Muted", true)
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	_empty.add_theme_color_override("font_color", OverworldStyle.MUTED)
	_note = PauseMenu.small(Text.t("Your newest try isn't used until it passes."), true)
	_open_button = Ui.button(Text.t("Open"), _open_shown, "PrimaryButton")
	_open_button.custom_minimum_size = Vector2(0, 46)
	_check_button = Ui.button(Text.t("Check again"), check_shown)
	_check_button.custom_minimum_size = Vector2(0, 40)
	_check_line = PauseMenu.small("", true)
	_history_line = PauseMenu.small("", true)
	_history_line.visible = false
	_history_button = Ui.button(Text.t("Before"), _toggle_history)
	_history_button.custom_minimum_size = Vector2(0, 40)
	_history_button.visible = false
	var column := Ui.vbox(
		[
			_name,
			_status,
			_does,
			_code,
			_empty,
			_note,
			_check_line,
			_check_button,
			_history_line,
			_history_button,
			_open_button,
		],
		8
	)
	column.custom_minimum_size.x = SIDE_WIDTH
	return column


func is_open() -> bool:
	return _open


## Gear centers in the responsive Lantern Engine. The count wraps into rows within the available width.
static func engine_layout(width: float, count: int) -> Dictionary:
	var usable := maxf(1.0, width - ENGINE_EDGE * 2.0)
	var columns := maxi(1, mini(ENGINE_MAX_COLUMNS, mini(count, int(floor((usable - 1.0) / ENGINE_GEAR_SPACING)) + 1))) if count > 0 else 1
	var centers: Array[Vector2] = []
	for i in count:
		var row := i / columns
		var first := row * columns
		var in_row := mini(columns, count - first)
		var span := float(in_row - 1) * ENGINE_GEAR_SPACING
		var left := (width - span) / 2.0
		centers.append(Vector2(left + float(i - first) * ENGINE_GEAR_SPACING, 54.0 + float(row) * ENGINE_ROW_HEIGHT))
	var rows := ceili(float(count) / float(columns)) if count > 0 else 0
	return {"centers": centers, "columns": columns, "rows": rows, "height": rows * ENGINE_ROW_HEIGHT + 80.0}


## Runs every case of every stage the shown part has passed on the program that runs, and says how it went: all of
## them still work, or the first that does not (in the game's words, TaskWords).
func check_shown() -> void:
	if _checking or _shown < 0 or _shown >= _entries.size():
		return
	var id := String(_entries[_shown].id)
	var task: Dictionary = (_catalog.get("tasks", {}) as Dictionary).get(id, {})
	var program := Parts.program(_state, id)
	if task.is_empty() or program.is_empty():
		return
	_checking = true
	_check_line.visible = true
	_check_line.text = Text.t("Checking...")
	_check_line.add_theme_color_override("font_color", OverworldStyle.MUTED)
	var stage := mini(Parts.passed(_state, id), Tasks.stage_count(task)) - 1
	var language := String(program.language)
	var source := String(program.source)
	var checked: Dictionary = await Background.run(func() -> Dictionary: return TaskRun.check(task, stage, language, source))
	_checking = false
	if not is_instance_valid(_check_line):
		return
	if bool(checked.get("ok", false)):
		_check_line.text = Text.f("Every check still passes (%d of %d).", [(checked.cases as Array).size(), (checked.cases as Array).size()])
		_check_line.add_theme_color_override("font_color", BUILT_COLOUR)
		Sound.play("sfx-pass", 0.3)
	else:
		var advised := Tasks.advice(task, stage, checked, language)
		_check_line.text = TaskWords.advice(task, stage, advised, language)
		_check_line.add_theme_color_override("font_color", OverworldStyle.MUTED)
		Sound.play("sfx-glitch", 0.25)


## The text under Check again (for tests and the screenshot tool).
func check_text() -> String:
	return _check_line.text if _check_line != null else ""


## Opens the Workbench over the town: the lessons from before, then each task of `catalog.tasks` in Parts.IDS' order,
## each as `state` has built it.
func open(catalog: Dictionary, state: Dictionary) -> void:
	_catalog = catalog
	_state = state
	_language = Tasks.JAVASCRIPT if String(state.get("language", Tasks.PYTHON)) == Tasks.JAVASCRIPT else Tasks.PYTHON
	_entries = _make_entries()
	_fill()
	_open = true
	visible = true
	Sound.play("sfx-open", 0.35)
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = OverworldStyle.pop_in(self, _card)
	_last = clampi(_last, 0, maxi(_entries.size() - 1, 0))
	_show(_last)
	_focus_card.call_deferred(_last)


func close_panel() -> void:
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


## The part ids on the grid, in order.
func part_ids() -> Array[String]:
	var out: Array[String] = []
	for entry in _entries:
		out.append(String(entry.id))
	return out


## One part's card, as data: {id, name, giver, built, status, line, signature, source, language}. {} for an unknown id.
func entry_of(id: String) -> Dictionary:
	for entry in _entries:
		if String(entry.id) == id:
			return entry
	return {}


## The status a part's card shows.
func status_of(id: String) -> String:
	return String(entry_of(id).get("status", ""))


## The id of the part whose page is on show ("" before any).
func shown_id() -> String:
	return String(_entries[_shown].id) if _shown >= 0 and _shown < _entries.size() else ""


## Shows the page of part `id` (what choosing its card does).
func choose(id: String) -> void:
	for i in _entries.size():
		if String(_entries[i].id) == id:
			_show(i)
			if _open and cards.has(id):
				(cards[id] as Button).grab_focus()
			return


# --- what is there to show --------------------------------------------------------------------------------------------


func _make_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in Parts.BUILT_BEFORE:
		out.append(_lesson_entry(id))
	var tasks: Dictionary = _catalog.get("tasks", {}) if _catalog.get("tasks", {}) is Dictionary else {}
	for id in Parts.IDS:
		if tasks.has(id):
			out.append(_task_entry(id, tasks[id]))
	return out


## The boots, the save and the lamps: their own editors open, and their flag says they are built.
func _lesson_entry(id: String) -> Dictionary:
	var flags: Dictionary = _state.get("flags", {}) if _state.get("flags", {}) is Dictionary else {}
	var built := bool(flags.get(String(Parts.BUILT_BEFORE[id]), false))
	var quest := {"boots": "boots", "save": "memory", "lamps": "lamps"}[id] as String
	var who := _person(String(((_catalog.get("quests", {}) as Dictionary).get(quest, {}) as Dictionary).get("giver", HOTARU)))
	var name := ""
	var signature := ""
	var line := ""
	var source := ""
	var language := _language
	match id:
		"boots":
			name = Text.t("Your Boots")
			signature = CodeGlossary.signature(CodeGlossary.BOOTS, _language)
			line = Text.t("You walk where your code says.")
			source = OverworldState.boots_source(_state)
		"save":
			name = Text.t("Your Save")
			signature = CodeGlossary.signature(Lessons.MEMORY, _language)
			line = Text.t("The town remembers where you were.")
			var record := Lessons.record(_state, Lessons.MEMORY)
			language = String(record.get("language", _language))
			source = String(record.get("source", ""))
			if source == "" and built:
				source = Lessons.source(Lessons.MEMORY, record.blocks, language)
		_:
			name = Text.t("The Lamp Lane")
			signature = CodeGlossary.signature(Lessons.LAMPS, _language)
			line = Text.t("Your code lights every lamp on the lane.")
			var record := Lessons.record(_state, Lessons.LAMPS)
			language = String(record.get("language", _language))
			source = String(record.get("source", ""))
			if source == "" and built:
				source = Lessons.source(Lessons.LAMPS, record.blocks, language)
	return {
		"id": id,
		"name": name,
		"giver": who.name,
		"portrait": who.portrait,
		"built": built,
		"status": Text.t("Built") if built else Text.f("Not yet: ask %s", [who.name]),
		"line": line if built else "",
		"signature": signature,
		"source": source if built else "",
		"language": language,
		"mode": "lesson",
	}


func _task_entry(id: String, task: Dictionary) -> Dictionary:
	var who := _person(String(task.get("giver", "")))
	var built := Parts.built(_state, id)
	var passed := Parts.passed(_state, id)
	var count := Tasks.stage_count(task)
	var status := Text.f("Not yet: ask %s", [who.name])
	if built:
		status = Text.t("Built")
		if passed < count:
			if Tasks.unlocked(task, passed, Parts.facts(_state)):
				status = Text.f("%s · Stage %d of %d", [status, passed + 1, count])
			else:
				var idea := _person(_idea_giver(task, passed, String(task.get("giver", ""))))
				status = Text.f("%s · Stage %d waits: %s has an idea", [status, passed + 1, idea.name])
	var program := Parts.program(_state, id)
	return {
		"id": id,
		"name": Text.t(String(task.get("name", id))),
		"giver": who.name,
		"portrait": who.portrait,
		"built": built,
		"status": status,
		"line": Text.t(String(task.get("built_line", ""))) if built else "",
		"signature": Tasks.signature(task, 0, _language),
		"source": String(program.get("source", "")),
		"language": String(program.get("language", _language)),
		"mode": "task",
	}


## {name, portrait} of a townsperson (Hotaru, who is not one of them, included).
func _person(id: String) -> Dictionary:
	var folk: Dictionary = _catalog.get("townsfolk", {}) if _catalog.get("townsfolk", {}) is Dictionary else {}
	if folk.has(id):
		var person: Dictionary = folk[id]
		return {"name": Text.t(String(person.get("name", id))), "portrait": String(person.get("portrait", id))}
	return {"name": Text.t("Hotaru") if id == HOTARU or id == "" else id.capitalize(), "portrait": id if id != "" else HOTARU}


## Who has the idea for stage `index`: the giver of the quest whose step sets the flag that unlocks it, else `fallback`.
func _idea_giver(task: Dictionary, index: int, fallback: String) -> String:
	var condition: Variant = Tasks.stage(task, index).get("unlocked_by", {})
	var flag := String((condition as Dictionary).get("flag", "")) if condition is Dictionary else ""
	var quests: Dictionary = _catalog.get("quests", {}) if _catalog.get("quests", {}) is Dictionary else {}
	if flag != "":
		for quest: Variant in quests.values():
			for step: Variant in (quest as Dictionary).get("steps", []):
				var done: Variant = (step as Dictionary).get("done", {})
				if done is Dictionary and String((done as Dictionary).get("flag", "")) == flag:
					return String((quest as Dictionary).get("giver", fallback))
	return fallback


# --- the page ---------------------------------------------------------------------------------------------------------


func _fill() -> void:
	Ui.clear(_grid)
	cards.clear()
	var built: Array[bool] = []
	for i in _entries.size():
		var button := _make_card(i)
		cards[String(_entries[i].id)] = button
		_grid.add_child(button)
		built.append(bool(_entries[i].built))
	var total := _entries.size()
	_count.text = Text.f("%d of %d parts built", [built.count(true), total])
	_engine.set_parts(built)


func _make_card(index: int) -> Button:
	var entry := _entries[index]
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("index", index)
	var built := bool(entry.built)
	var gear := Control.new()
	gear.custom_minimum_size = Vector2(54, 54)
	gear.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear.draw.connect(func() -> void: GearArt.draw(gear, gear.size / 2.0, 23.0, 0.0, built))
	var name := Ui.label(String(entry.name))
	name.add_theme_font_override("font", OverworldStyle.body_font(600))
	name.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT + 3)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	var signature := Ui.label(String(entry.signature))
	signature.add_theme_font_override("font", UiTheme.code_font())
	signature.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_SMALL + 1)
	signature.add_theme_color_override("font_color", OverworldStyle.MUTED)
	signature.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	signature.clip_text = true
	var titles := Ui.vbox([name, signature], 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var face := Control.new()
	face.custom_minimum_size = Vector2(FACE, FACE)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var portrait := String(entry.portrait)
	var giver := String(entry.giver)
	face.draw.connect(func() -> void: QuestTracker.draw_face(face, face.size / 2.0, FACE / 2.0 - 1.0, portrait, giver))
	var status := Ui.label(String(entry.status), "", true)
	status.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	status.add_theme_color_override("font_color", BUILT_COLOUR if built else OverworldStyle.MUTED)
	var line := Ui.label(String(entry.line), "Muted", true)
	line.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_SMALL)
	line.add_theme_color_override("font_color", OverworldStyle.MUTED)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inside := Ui.vbox([Ui.hbox([gear, titles, face], 12), status, line], 4)
	_hold(button, inside)
	button.focus_entered.connect(_show.bind(index))
	button.mouse_entered.connect(button.grab_focus)
	button.pressed.connect(_chosen.bind(index))
	_style_card(button, false)
	return button


## Puts `inside` in the button, filling it, and keeps the card at least CARD_HEIGHT and as tall as `inside` needs.
static func _hold(button: Button, inside: Control) -> void:
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in inside.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inside)
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 12
	inside.offset_right = -12
	inside.offset_top = 10
	inside.offset_bottom = -10
	var fit := func() -> void: button.custom_minimum_size = Vector2(0, maxf(CARD_HEIGHT, inside.get_combined_minimum_size().y + 20.0))
	inside.minimum_size_changed.connect(fit)
	fit.call()


## A card's look: dark with a thin edge, warm and amber when it is the one on show.
func _style_card(button: Button, on: bool) -> void:
	var pad := Vector2(10, 4)
	var fill := LessonBlocks.FILL_ON if on else Color("#211a13")
	var edge := UiTheme.AMBER if on else UiTheme.LINE
	for state: String in ["normal", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, UiTheme.box(fill, edge, 2 if on else 1, 10, pad))
	for state: String in ["hover", "hover_pressed"]:
		button.add_theme_stylebox_override(state, UiTheme.box(fill.lightened(0.05), UiTheme.AMBER_DIM, 2, 10, pad))
	button.add_theme_stylebox_override("focus", OverworldStyle.focus_box(10))


func _show(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_shown = index
	_last = index
	var entry := _entries[index]
	for id: String in cards:
		_style_card(cards[id] as Button, id == String(entry.id))
	_engine.select(index)
	_name.text = String(entry.name)
	_status.text = String(entry.status)
	_status.add_theme_color_override("font_color", BUILT_COLOUR if bool(entry.built) else OverworldStyle.MUTED)
	_does.text = String(entry.line)
	_does.visible = String(entry.line) != ""
	var source := String(entry.source)
	_code.visible = source != ""
	_empty.visible = source == ""
	_note.visible = source != ""
	if source != "":
		_code.set_language(String(entry.language), Text.t("The program that runs"))
		_code.show_code(source)
	else:
		_empty.text = Text.f("Nothing is built here yet. %s can help you start.", [entry.giver])
	_open_button.focus_neighbor_left = (cards[String(entry.id)] as Button).get_path()
	# Only a built task can be checked again (the lessons before the parts keep their own editors' checks).
	var task: Dictionary = (_catalog.get("tasks", {}) as Dictionary).get(String(entry.id), {})
	_check_button.visible = source != "" and not task.is_empty()
	_check_line.text = ""
	_check_line.visible = false
	_show_history(entry)


## Chapter 3 (Concept/v0.4/05, 2.11): `changed(old_lines, new_lines)` is the town's live comparison of two versions, a
## coroutine that returns the numbers of the lines that differ. Set it before the card is shown; without it, or with
## fewer than two versions, the history shows nothing.
func set_history(changed: Callable) -> void:
	_changed = changed
	if _open and _shown >= 0:
		_show(_shown)


func _show_history(entry: Dictionary) -> void:
	_history_token += 1
	_viewing_before = false
	_history_line.visible = false
	_history_button.visible = false
	var versions := _versions_of(entry)
	if versions.size() < 2 or not _changed.is_valid():
		return
	_history_button.text = Text.t("Before")
	_history_button.visible = true
	_history_line.visible = true
	_history_line.text = Text.t("Comparing the versions...")
	_compare(_history_token, String(entry.id), versions)


## The versions a built task's record keeps, oldest first; [] for a lesson, or a part that is not built.
func _versions_of(entry: Dictionary) -> Array:
	if String(entry.get("mode", "")) != "task" or not bool(entry.get("built", false)):
		return []
	var versions: Variant = Parts.record(_state, String(entry.id)).get("versions", [])
	if versions is Array:
		return versions
	return []


## Asks the town which lines differ between the last two versions, and says so. An answer already had is kept, so
## going back to a card does not ask again.
func _compare(token: int, id: String, versions: Array) -> void:
	var before := String(versions[-2])
	var now := String(versions[-1])
	var key := "%s\n%s\n%s" % [id, before, now]
	var found: Array = _compared.get(key, [])
	if not _compared.has(key):
		found = await _changed.call(_lines(before), _lines(now))
		_compared[key] = found
	if token != _history_token or not is_instance_valid(_history_line):
		return
	_history_line.text = _changed_words(found)
	history_viewed.emit(id)


func _lines(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		out.append(line)
	return out


func _changed_words(found: Array) -> String:
	var numbers := PackedStringArray()
	for line: Variant in found:
		numbers.append(str(int(line)))
	if numbers.is_empty():
		return Text.t("Nothing changed since the version before.")
	if numbers.size() == 1:
		return Text.f("Changed since the version before: line %s", [numbers[0]])
	return Text.f("Changed since the version before: lines %s", [", ".join(numbers)])


## The Before button: shows the version before on the code, and then the newest one again.
func _toggle_history() -> void:
	if _shown < 0 or _shown >= _entries.size():
		return
	var entry := _entries[_shown]
	var versions := _versions_of(entry)
	if versions.size() < 2:
		return
	_viewing_before = not _viewing_before
	_history_button.text = Text.t("Now") if _viewing_before else Text.t("Before")
	var caption := Text.t("The version before") if _viewing_before else Text.t("The program that runs")
	_code.set_language(String(entry.language), caption)
	_code.show_code(String(versions[-2]) if _viewing_before else String(versions[-1]))


## The comparison line on show ("" while it is hidden), for tests and the screenshot tool.
func history_text() -> String:
	return _history_line.text if _history_line.visible else ""


## The history button's word on show ("" while it is hidden): "Before", or "Now" while the version before is shown.
func history_button_text() -> String:
	return _history_button.text if _history_button.visible else ""


## A card was pressed (Enter, a click or the pad's A): its page is on show, and the Open button is ready.
func _chosen(index: int) -> void:
	_show(index)
	Sound.play("sfx-card-flick-1", 0.3)
	_open_button.grab_focus()


func _open_shown() -> void:
	if _shown < 0 or _shown >= _entries.size():
		return
	Sound.play("sfx-card-place-1", 0.4)
	open_part.emit(String(_entries[_shown].id))


func _focus_card(index: int) -> void:
	if not _open:
		return
	var id := String(_entries[index].id) if index < _entries.size() else ""
	if cards.has(id):
		(cards[id] as Button).grab_focus()


## Esc, B or Start goes back; no key reaches the town while the Workbench is open. A key with no focus to move gives it
## back to the card on show.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo():
		return
	var start := event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if event.is_action_pressed("ui_cancel") or start:
		close_panel()
		return
	if get_viewport().gui_get_focus_owner() == null:
		_focus_card(_last)


## The Lantern Engine: a gear for each part, chained in order. A built part's gear turns slowly (neighbours the other
## way, so their teeth mesh); a missing part is an empty socket. At the end of the chain a lantern glows brighter the
## more parts are built.
class EngineView:
	extends Control

	const SPACING := 86.0
	const RADIUS := 55.0
	const TURN := 0.55

	var _built: Array[bool] = []
	var _selected := -1
	var _time := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 124)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and not _built.is_empty():
			var layout := WorkbenchPanel.engine_layout(size.x, _built.size())
			var height := float(layout.height)
			if not is_equal_approx(custom_minimum_size.y, height):
				custom_minimum_size.y = height
				queue_redraw()

	func set_parts(built: Array[bool]) -> void:
		_built = built
		queue_redraw()

	func select(index: int) -> void:
		_selected = index
		queue_redraw()

	func _process(delta: float) -> void:
		if is_visible_in_tree() and not Settings.reduced_motion:
			_time += delta
			queue_redraw()

	func _draw() -> void:
		var count := _built.size()
		if count == 0:
			return
		var layout := WorkbenchPanel.engine_layout(size.x, count)
		var centers: Array = layout.centers
		var step := TAU / GearArt.TEETH
		var rows := int(layout.rows)
		for row in rows:
			var start := row * int(layout.columns)
			var end := mini(start + int(layout.columns), count)
			draw_line(centers[start], centers[end - 1], Color(UiTheme.AMBER_DIM, 0.35), 3.0, true)
		for i in count:
			var centre: Vector2 = centers[i]
			var direction := 1.0 if i % 2 == 0 else -1.0
			var phase := 0.0 if i % 2 == 0 else step / 2.0
			if _built[i]:
				GearArt.draw(self, centre, RADIUS * 0.86, phase + direction * _time * TURN, true)
			else:
				GearArt.draw_socket(self, centre, RADIUS * 0.86)
			if i == _selected:
				draw_arc(centre, RADIUS * 0.86 + 7.0, 0.0, TAU, 40, UiTheme.AMBER, 2.5, true)
		_draw_lantern(Vector2(size.x / 2.0, float(rows) * ENGINE_ROW_HEIGHT + 38.0), float(_built.count(true)) / count)

	func _draw_lantern(centre: Vector2, glow: float) -> void:
		var flicker := 1.0 + 0.04 * sin(_time * 5.0)
		draw_circle(centre, 40.0 * flicker, Color(UiTheme.AMBER, 0.05 + 0.12 * glow))
		draw_circle(centre, 28.0 * flicker, Color(UiTheme.AMBER, 0.08 + 0.2 * glow))
		var body := Rect2(centre + Vector2(-14, -18), Vector2(28, 36))
		UiTheme.box(Color(0.5, 0.3, 0.1, 0.25 + 0.7 * glow), UiTheme.AMBER_DIM, 2, 7).draw(get_canvas_item(), body)
		draw_circle(centre + Vector2(0, 2), 6.0 + 3.0 * glow, Color("#fff1c4", 0.4 + 0.6 * glow))
		draw_line(centre + Vector2(-10, -22), centre + Vector2(10, -22), UiTheme.AMBER_DIM, 3.0, true)
		draw_arc(centre + Vector2(0, -22), 8.0, PI, TAU, 10, UiTheme.AMBER_DIM, 2.0, true)
