class_name BootsCodePanel
extends VBoxContainer
## A column of code in the boots editor (ADR-0061): the language's name over a code editor with line numbers. Builder
## shows the code the blocks make in one (read-only, never takes the focus, so the arrow keys stay with the blocks);
## Scribe types in another (editable). The code is drawn large and bright, since a child reads it.
##
##   panel.show_code(BootsCode.source(blocks, "python"), true)   # new code; the lines that changed glow for a moment
##   panel.mark(Vector2i(1, 3))                                   # lights lines 1 and 2 (0-based, end excluded)

## The glow on lines that just changed, as it starts, and how long it takes to fade.
const FLASH := 0.42
const FLASH_TIME := 0.9
## The soft light on the lines of the block that has the focus.
const MARK := 0.16
const NOTHING := Vector2i(-1, -1)
const TEXT_COLOUR := Color("#f3e6c8")

var editor: CodeEdit
var language := BootsCode.PYTHON
## The glossary beside the code, once enable_hints has been called.
var hints: CodeHints

var _heading_row: HBoxContainer

var _title: Label
var _caption: Label
var _marked := NOTHING
var _flashed := NOTHING
var _flash := 0.0
var _tween: Tween


func _init(editable: bool) -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title = Ui.label("")
	_caption = Ui.label("", "Muted")
	_heading_row = heading(_title, _caption)
	add_child(_heading_row)
	editor = _make_editor(editable)
	add_child(editor)


## Gives the column a Hints button at the right of its heading and a glossary (CodeGlossary, for `program`: "boots",
## "memory", "lamps") that opens beside the code. For a column the player types in; a column that is only read has none.
func enable_hints(program: String) -> void:
	if hints != null:
		return
	hints = CodeHints.install(_heading_row, editor, program)
	hints.set_language(language)


## A column's heading: its name in amber, then a line of small print beside it, sitting on one baseline. The blocks
## column wears the same heading, so the two columns read as a pair.
static func heading(title: Label, caption: Label) -> HBoxContainer:
	title.add_theme_font_override("font", OverworldStyle.body_font(600))
	title.add_theme_color_override("font_color", UiTheme.AMBER)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for label: Label in [title, caption]:
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return Ui.hbox([title, caption], 12)


## The language this column shows, and the line under its name. The highlighting, indent and comments follow it.
func set_language(to: String, caption: String) -> void:
	language = to
	if hints != null:
		hints.set_language(to)
	var python := to == BootsCode.PYTHON
	_title.text = language_name(to)
	_caption.text = caption
	editor.syntax_highlighter = LanternEditor.highlighter(to)
	editor.indent_size = 4 if python else 2
	editor.indent_automatic_prefixes = [":"] if python else ["{", "[", "("]
	editor.delimiter_comments = ["#"] if python else ["//"]


## Shows `text`. With `flash`, the lines that differ from what was shown glow and fade, so the player sees where their
## change landed; with nothing new (a rule taken away), the line where the removed ones were glows instead.
func show_code(text: String, flash := false) -> void:
	var before := editor.text
	if text == before:
		return
	editor.text = text
	editor.clear_undo_history()
	_flashed = NOTHING
	if flash:
		_flashed = changed_lines(before, text)
		if _flashed.y <= _flashed.x:
			var at := mini(_flashed.x, editor.get_line_count() - 1)
			_flashed = Vector2i(at, at + 1)
		_start_flash()
	_paint()


## Lights `lines` (start, end excluded) softly, or nothing with NOTHING.
func mark(lines: Vector2i) -> void:
	if lines == _marked:
		return
	_marked = lines
	_paint()


## The lines of `after` that are not in `before`, as [start, end): what is left once the lines both share at the top
## and at the bottom are set aside. Empty (start == end) when lines were only taken away.
static func changed_lines(before: String, after: String) -> Vector2i:
	var was := before.split("\n")
	var now := after.split("\n")
	var top := 0
	while top < was.size() and top < now.size() and was[top] == now[top]:
		top += 1
	var bottom := 0
	while (
		bottom < was.size() - top
		and bottom < now.size() - top
		and was[was.size() - 1 - bottom] == now[now.size() - 1 - bottom]
	):
		bottom += 1
	return Vector2i(top, now.size() - bottom)


## A language's name as the player reads it. Each is a literal Text.t call, so the locale check can find it.
static func language_name(of: String) -> String:
	return Text.t("JavaScript") if of == BootsCode.JAVASCRIPT else Text.t("Python")


func _make_editor(editable: bool) -> CodeEdit:
	var made := LanternEditor.make(language)
	made.editable = editable
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	made.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_CODE)
	made.add_theme_constant_override("line_spacing", 2)
	# LEARN: a TextEdit that is not editable draws its words in font_readonly_color, half transparent by default, and
	# caps the highlighter's colours to that alpha too. The code the blocks make is for reading, so both stay solid.
	made.add_theme_color_override("font_color", TEXT_COLOUR)
	made.add_theme_color_override("font_readonly_color", TEXT_COLOUR)
	made.add_theme_color_override("line_number_color", UiTheme.MUTED)
	var well := UiTheme.box(LanternEditor.BACKGROUND, UiTheme.LINE, 1, 8, Vector2(10, 6))
	made.add_theme_stylebox_override("normal", well)
	made.add_theme_stylebox_override("read_only", well)
	made.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	made.indent_wrapped_lines = true
	made.scroll_past_end_of_file = false
	if not editable:
		# Read-only: nothing to put a caret in, and no focus to trap the arrow keys a pad or keyboard walks with.
		made.focus_mode = Control.FOCUS_NONE
		made.highlight_current_line = false
		made.context_menu_enabled = false
		made.caret_blink = false
		made.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return made


func _start_flash() -> void:
	if _tween != null:
		_tween.kill()
	_flash = FLASH
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_flash, FLASH, 0.0, FLASH_TIME)


func _set_flash(amount: float) -> void:
	_flash = amount
	_paint()


## Each line's background: the stronger of the fading glow (changed lines) and the soft light (the block in focus).
func _paint() -> void:
	for line in editor.get_line_count():
		var alpha := 0.0
		if line >= _marked.x and line < _marked.y:
			alpha = MARK
		if line >= _flashed.x and line < _flashed.y:
			alpha = maxf(alpha, _flash)
		editor.set_line_background_color(line, Color(UiTheme.AMBER, alpha))
