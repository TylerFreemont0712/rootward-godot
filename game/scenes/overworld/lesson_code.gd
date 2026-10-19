class_name LessonCode
extends VBoxContainer
## The code column of a lesson (ADR-0061): the language's name over a code editor with line numbers, drawn compact
## and bright like the boots' code (OverworldStyle.EDITOR_CODE). A Builder reads the code their blocks make here
## (read-only, it never takes the focus, so the arrow keys stay with the blocks); a Scribe types in it, and can open a
## glossary beside it (enable_hints). When the blocks change the code, the lines that changed glow and fade, so the
## player sees where their tick landed.
##
##   column.show_code(Lessons.source(id, blocks, "python"), true)
##   column.mark_error(2)   # lights line 2 red; 0 clears

const TEXT_COLOUR := Color("#f3e6c8")
const FLASH := 0.42
const FLASH_TIME := 0.9

var editor: CodeEdit
## The glossary beside the code, once enable_hints has been called.
var hints: CodeHints

var _heading_row: HBoxContainer
var _title: Label
var _caption: Label
var _flashed := Vector2i(-1, -1)
var _error_line := 0
var _tween: Tween


func _init(editable: bool) -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title = Ui.label("")
	_title.add_theme_font_override("font", OverworldStyle.body_font(600))
	_title.add_theme_color_override("font_color", UiTheme.AMBER)
	_caption = Ui.label("", "Muted")
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_heading_row = Ui.hbox([_title, _caption], 12)
	add_child(_heading_row)
	editor = _make_editor(editable)
	add_child(editor)


## Gives the column a Hints button at the right of its heading and a glossary for `program` (a lesson's id) that opens
## beside the code. For a Scribe's column; the code a Builder only reads has none.
func enable_hints(program: String, language: String) -> void:
	if hints != null:
		return
	hints = CodeHints.install(_heading_row, editor, program)
	hints.set_language(language)


## The same for a v0.4 task (TaskEditor): the glossary is the task's own at `stage`.
func enable_task_hints(task: Dictionary, stage: int, language: String) -> void:
	if hints != null:
		return
	hints = CodeHints.install_for_task(_heading_row, editor, task, stage)
	hints.set_language(language)


## The language shown, and the small line beside its name. The highlighting, indent and comments follow it.
func set_language(language: String, caption: String) -> void:
	var python := language != Lessons.JAVASCRIPT
	if hints != null:
		hints.set_language(language)
	_title.text = Text.t("Python") if python else Text.t("JavaScript")
	_caption.text = caption
	editor.syntax_highlighter = LanternEditor.highlighter(language)
	editor.indent_size = 4 if python else 2
	editor.indent_automatic_prefixes = [":"] if python else ["{", "[", "("]
	editor.delimiter_comments = ["#"] if python else ["//"]


## Shows `text`; with `flash`, the lines that differ from what was there glow for a moment.
func show_code(text: String, flash := false) -> void:
	var before := editor.text
	if text == before:
		return
	editor.text = text
	_error_line = 0
	_flashed = Vector2i(-1, -1)
	if flash:
		_flashed = changed_lines(before, text)
		if _flashed.y <= _flashed.x:
			var at := mini(_flashed.x, editor.get_line_count() - 1)
			_flashed = Vector2i(at, at + 1)
		if _tween != null:
			_tween.kill()
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_method(_paint, FLASH, 0.0, FLASH_TIME)
	_paint(0.0)


## Lights line `line` (1-based) red, where the code tripped; 0 clears it.
func mark_error(line: int) -> void:
	_error_line = line if line > 0 and line <= editor.get_line_count() else 0
	_paint(0.0)
	if _error_line > 0 and editor.editable:
		editor.set_caret_line(_error_line - 1)
		editor.center_viewport_to_caret()


## The lines of `after` not in `before`, as [start, end): what is left once the lines both share at the top and the
## bottom are set aside.
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


func _paint(flash: float) -> void:
	for line in editor.get_line_count():
		var colour := Color(UiTheme.AMBER, 0.0)
		if line >= _flashed.x and line < _flashed.y:
			colour = Color(UiTheme.AMBER, flash)
		if line == _error_line - 1:
			colour = LanternEditor.ERROR_LINE
		editor.set_line_background_color(line, colour)


static func _make_editor(editable: bool) -> CodeEdit:
	var made := LanternEditor.make(Lessons.PYTHON)
	made.editable = editable
	made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	made.size_flags_vertical = Control.SIZE_EXPAND_FILL
	made.add_theme_font_size_override("font_size", OverworldStyle.EDITOR_CODE)
	made.add_theme_constant_override("line_spacing", 2)
	# LEARN: a TextEdit that is not editable draws its words in font_readonly_color, half transparent by default. The
	# code a Builder's blocks make is for reading, so it stays solid.
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
		made.focus_mode = Control.FOCUS_NONE
		made.highlight_current_line = false
		made.context_menu_enabled = false
		made.caret_blink = false
		made.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return made
