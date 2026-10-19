class_name CodeHints
extends PanelContainer
## The hints beside a Scribe's code (ADR-0061): a glossary of what the function is given, what it gives back and the
## words of the language the task needs (CodeGlossary). A "Hints" button at the right of the code column's heading
## opens it as a side column next to the code, inside the same panel, so the panel does not change size; closed, the code
## takes the whole width again. Each section's title folds its entries open and shut. Nothing here takes the keyboard
## focus, so the code editor keeps its caret and Esc and Ctrl+Enter work as before.
##
##   var hints := CodeHints.install(heading, editor, "boots")   # the button joins `heading`, the column joins `editor`'s row
##   hints.set_language("python")                               # when the language changes
##
## Open or closed is kept for the run (a static), so the next editor opens as the last one was left.

## How wide the column is, in the design's units.
const WIDTH := 400.0
const TERM_COLOUR := Color("#f3e6c8")
const OPEN_MARK := "▾"
const SHUT_MARK := "▸"

## Whether the hints were open when the player last chose, for the run.
static var remembered_open := false

## The "Hints" button the column's heading holds.
var toggle: Button

var _program := ""
## The v0.4 task whose glossary shows (install_for_task), and the stage; empty for the boots and the lessons.
var _task: Dictionary = {}
var _stage := 0
var _language := CodeGlossary.PYTHON
var _entries: VBoxContainer
## Each section's title, folded shut (true) or open (absent); kept across a language change.
var _folded: Dictionary = {}


## Puts a Hints button at the end of `heading` and the hint column beside `editor` (the editor moves into a row with
## it). Returns the column. `program` is a CodeGlossary program: "boots", "memory", "lamps".
static func install(heading: HBoxContainer, editor: CodeEdit, program: String) -> CodeHints:
	var hints := CodeHints.new(program)
	var column := editor.get_parent()
	var at := editor.get_index()
	column.remove_child(editor)
	var row := Ui.hbox([editor, hints], 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	column.move_child(row, at)
	heading.add_child(hints.toggle)
	return hints


## The same for a v0.4 task: the glossary is built from the task's own data (CodeGlossary.sections_for_task) at `stage`.
static func install_for_task(heading: HBoxContainer, editor: CodeEdit, task: Dictionary, stage: int) -> CodeHints:
	var hints := install(heading, editor, "task:%s" % String(task.get("id", "")))
	hints.use_task(task, stage)
	return hints


## Shows the glossary of `task` at `stage` from now on.
func use_task(task: Dictionary, stage: int) -> void:
	_task = task
	_stage = stage
	_build()


func _init(program: String) -> void:
	_program = program
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", OverworldStyle.well_box(Vector2(10, 8), 10))
	_entries = Ui.vbox([], 8)
	var scroll := Ui.scroll(_entries)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	toggle = _make_toggle()
	_set_open(remembered_open)
	_build()


## The language the glossary speaks (its terms and examples are that language's).
func set_language(language: String) -> void:
	if language == _language:
		return
	_language = language
	_build()


## Takes the remembered state again: an editor that is opened again shows the hints as the last editor left them.
func sync() -> void:
	_set_open(remembered_open)


## Whether the column is showing.
func is_open() -> bool:
	return visible


func _make_toggle() -> Button:
	var button := Button.new()
	button.text = Text.t("Hints")
	button.toggle_mode = true
	# The code editor keeps the focus: the button is for the mouse (the glossary is read, not typed in).
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = Text.t("Open or close the hints: what your function gets, and words you can use.")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_SMALL)
	var quiet := UiTheme.box(UiTheme.PANEL_2, UiTheme.LINE, 1, 7, Vector2(12, 3))
	var warm := UiTheme.box(UiTheme.PANEL_3, UiTheme.AMBER_DIM, 1, 7, Vector2(12, 3))
	var on := UiTheme.box(Color("#2a1f12"), UiTheme.AMBER, 1, 7, Vector2(12, 3))
	button.add_theme_stylebox_override("normal", quiet)
	button.add_theme_stylebox_override("hover", warm)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on)
	button.add_theme_color_override("font_pressed_color", UiTheme.AMBER)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.AMBER)
	button.toggled.connect(_set_open)
	return button


func _set_open(on: bool) -> void:
	remembered_open = on
	visible = on
	toggle.set_pressed_no_signal(on)


## The sections, each a title that folds and its entries.
func _build() -> void:
	Ui.clear(_entries)
	var sections := (
		CodeGlossary.sections_for_task(_task, _stage, _language)
		if not _task.is_empty()
		else CodeGlossary.sections(_program, _language)
	)
	for section: Dictionary in sections:
		var title := String(section.title)
		var body := Ui.vbox([], 9)
		for entry: Dictionary in section.entries:
			body.add_child(_entry(entry))
		body.visible = not _folded.get(title, false)
		_entries.add_child(_header(title, body))
		_entries.add_child(body)


## A section's title as a button across the column; pressing it folds the entries under it.
func _header(title: String, body: Control) -> Button:
	var header := Button.new()
	header.focus_mode = Control.FOCUS_NONE
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.add_theme_font_override("font", OverworldStyle.body_font(600))
	header.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_TEXT)
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		header.add_theme_color_override(colour, UiTheme.AMBER)
	var flat := UiTheme.box(Color(UiTheme.AMBER, 0.07), Color.TRANSPARENT, 0, 6, Vector2(8, 3))
	var lit := UiTheme.box(Color(UiTheme.AMBER, 0.16), Color.TRANSPARENT, 0, 6, Vector2(8, 3))
	for state: String in ["normal", "pressed"]:
		header.add_theme_stylebox_override(state, flat)
	for state: String in ["hover", "hover_pressed"]:
		header.add_theme_stylebox_override(state, lit)
	var relabel := func() -> void: header.text = "%s  %s" % [OPEN_MARK if body.visible else SHUT_MARK, title]
	header.pressed.connect(
		func() -> void:
			body.visible = not body.visible
			_folded[title] = not body.visible
			relabel.call()
	)
	relabel.call()
	return header


## One entry: the term in the code face, what it means in words, and a small example in a code well.
func _entry(entry: Dictionary) -> Control:
	var term := _wrapped(String(entry.term), UiTheme.code_font(600), OverworldStyle.EDITOR_SMALL + 1, TERM_COLOUR, true)
	var parts: Array = [term]
	var meaning := _wrapped(
		String(entry.meaning), OverworldStyle.body_font(), OverworldStyle.EDITOR_SMALL, UiTheme.TEXT
	)
	parts.append(meaning)
	var example := String(entry.get("example", ""))
	if example != "":
		var shown := _wrapped(example, UiTheme.code_font(), OverworldStyle.EDITOR_SMALL - 1, OverworldStyle.MUTED, true)
		var well := PanelContainer.new()
		well.add_theme_stylebox_override(
			"panel", UiTheme.box(LanternEditor.BACKGROUND, UiTheme.LINE_SOFT, 1, 6, Vector2(8, 3))
		)
		well.add_child(shown)
		parts.append(well)
	return Ui.vbox(parts, 3)


static func _wrapped(text: String, font: Font, size: int, colour: Color, code := false) -> Label:
	var label := Ui.label(text, "", true)
	# Code has no spaces worth breaking at, so it breaks anywhere; words break between words.
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY if code else TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label
