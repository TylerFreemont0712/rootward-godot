class_name StudioStatusBar
extends PanelContainer
## The status bar (Concept/v0.3/10, section 6): the cell under the cursor, its ground, what stands there, and the zoom.

signal problems_pressed
var error_count := 0
var warning_count := 0

## What is shown, for the tests.
var cell_text := ""
var ground_text := ""
var here_text := ""
var zoom_text := ""
## The last thing the Studio had to say about an edit ("overlaps the well", "Moved 3 things"); "" for nothing.
var message_text := ""

var _cell: Label
var _ground: Label
var _here: Label
var _zoom: Label
var _message: Label
var _problems: Button
var _hint: Label


func _init() -> void:
	name = "StatusBar"
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(10, 2)))
	_cell = StudioStyle.line("")
	_cell.custom_minimum_size.x = 130
	_ground = StudioStyle.line("", UiTheme.MUTED)
	_ground.custom_minimum_size.x = 120
	_here = StudioStyle.line("")
	_zoom = StudioStyle.line("", UiTheme.AMBER)
	_message = StudioStyle.line("", UiTheme.WARN)
	_problems = StudioStyle.button("", func() -> void: problems_pressed.emit())
	_hint = StudioStyle.line(StudioText.t("hint"), UiTheme.FAINT)
	_hint.add_theme_font_size_override("font_size", 12)
	add_child(Ui.hbox([_cell, _ground, _here, _message, Ui.spacer(), _hint, _problems, _zoom], 10))
	show_cursor("", "", "")
	show_zoom("")
	show_problems(0, 0)


func show_problems(errors: int, warnings: int) -> void:
	error_count = errors
	warning_count = warnings
	_problems.text = StudioText.t("problems_counts") % [errors, warnings]
	_problems.add_theme_color_override("font_color", UiTheme.FAIL if errors > 0 else UiTheme.AMBER if warnings > 0 else UiTheme.MUTED)


## `cell` and `ground` are empty when the cursor is not over the town.
func show_cursor(cell: String, ground: String, here: String) -> void:
	cell_text = ("cell " + cell) if cell != "" else ""
	ground_text = ("ground " + ground) if ground != "" else ""
	here_text = ("here: " + here) if here != "" else ""
	_cell.text = cell_text
	_ground.text = ground_text
	_here.text = here_text


func show_zoom(text: String) -> void:
	zoom_text = ("zoom " + text) if text != "" else ""
	_zoom.text = zoom_text


## A line about an edit, in the warning colour when it is a problem and the plain one when it is news.
func show_message(text: String, problem := false) -> void:
	message_text = text
	_message.text = text
	_message.add_theme_color_override("font_color", UiTheme.WARN if problem else UiTheme.PASS)


## The keys line for the tab in use ("hint" for Objects, "land_hint" for Land).
func show_hint(key: String) -> void:
	_hint.text = StudioText.t(key)
