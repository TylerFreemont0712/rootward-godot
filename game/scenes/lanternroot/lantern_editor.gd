class_name LanternEditor
extends RefCounted
## The workbench's code editor: Godot's CodeEdit with line numbers, auto-indent, bracket pairs and the game's own code
## colours (CodeColors), so code reads the same here as on a Shardrun card.

const BACKGROUND := Color("#120e0a")
const ERROR_LINE := Color(0.89, 0.35, 0.31, 0.22)


static func make(language: String) -> CodeEdit:
	var editor := CodeEdit.new()
	editor.gutters_draw_line_numbers = true
	editor.auto_brace_completion_enabled = true
	editor.auto_brace_completion_highlight_matching = true
	editor.indent_automatic = true
	editor.indent_use_spaces = true
	editor.indent_size = 4 if language == LanternCode.PYTHON else 2
	editor.highlight_current_line = true
	editor.draw_tabs = false
	editor.scroll_past_end_of_file = true
	editor.minimap_draw = false
	editor.caret_blink = true
	editor.add_theme_font_size_override("font_size", 20)
	editor.add_theme_color_override("background_color", BACKGROUND)
	editor.add_theme_color_override("current_line_color", Color(1, 1, 1, 0.04))
	editor.add_theme_color_override("line_number_color", UiTheme.FAINT)
	editor.add_theme_color_override("font_color", UiTheme.TEXT)
	editor.add_theme_color_override("caret_color", UiTheme.AMBER)
	editor.add_theme_color_override("selection_color", Color(UiTheme.AMBER, 0.25))
	editor.syntax_highlighter = highlighter(language)
	if language == LanternCode.PYTHON:
		editor.indent_automatic_prefixes = [":"]
		editor.delimiter_comments = ["#"]
	else:
		editor.indent_automatic_prefixes = ["{", "[", "("]
		editor.delimiter_comments = ["//"]
	return editor


static func highlighter(language: String) -> CodeHighlighter:
	var colours := CodeHighlighter.new()
	colours.number_color = Color(CodeColors.NUMBER)
	colours.symbol_color = Color("#c9b593")
	colours.function_color = Color(CodeColors.CALL)
	colours.member_variable_color = UiTheme.TEXT
	for word: String in String(CodeColors.KEYWORDS.get(language, "")).split(" ", false):
		colours.add_keyword_color(word, Color(CodeColors.KEYWORD))
	var comment := "#" if language == LanternCode.PYTHON else "//"
	colours.add_color_region(comment, "", Color(CodeColors.COMMENT).lightened(0.25), true)
	for quote: String in ['"', "'"] + (["`"] if language != LanternCode.PYTHON else []):
		colours.add_color_region(quote, quote, Color(CodeColors.STRING))
	return colours


## Marks `line` (1-based; 0 clears) as where the last error happened, and moves the caret there.
static func mark_error(editor: CodeEdit, line: int) -> void:
	for i in editor.get_line_count():
		editor.set_line_background_color(i, Color(0, 0, 0, 0))
	if line > 0 and line <= editor.get_line_count():
		editor.set_line_background_color(line - 1, ERROR_LINE)
		editor.set_caret_line(line - 1)
		editor.center_viewport_to_caret()
