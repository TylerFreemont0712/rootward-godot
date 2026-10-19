class_name StudioProblemsPanel
extends PanelContainer
## The whole world's errors and warnings. A row asks the Studio to open its map and select its object or cell.

signal jump_requested(map_id: String, cell: Vector2i, sid: int)
signal close_requested


var problems: Array[Dictionary] = []
var error_count := 0
var warning_count := 0

var _heading: Label
var _rows: VBoxContainer


func _init() -> void:
	name = "StudioProblems"
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(12, 10)))
	custom_minimum_size = Vector2(360, 150)
	var body := Ui.vbox([], 6)
	add_child(body)
	_heading = StudioStyle.line(StudioText.t("problems"))
	var close_button := StudioStyle.button(StudioText.t("close"), func() -> void: close_requested.emit())
	var top := Ui.hbox([_heading, Ui.spacer(), close_button], 6)
	body.add_child(top)
	_rows = Ui.vbox([], 4)
	var scroll := Ui.scroll(_rows)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	show_problems([])


func show_problems(found: Array[Dictionary]) -> void:
	problems = found.duplicate(true)
	error_count = 0
	warning_count = 0
	Ui.clear(_rows)
	for problem: Dictionary in problems:
		var is_error := String(problem.get("severity", "error")) == "error"
		if is_error:
			error_count += 1
		else:
			warning_count += 1
		var tag := StudioText.t("problems_error" if is_error else "problems_warning")
		var file := String(problem.get("file", ""))
		var id := String(problem.get("map_id", file.get_file().get_basename()))
		var message := String(problem.get("message", ""))
		var cell: Vector2i = problem.get("cell", Vector2i(-1, -1))
		var sid := int(problem.get("sid", -1))
		var row := StudioStyle.button("%s  %s: %s" % [tag, file.get_file(), message],
			func() -> void: jump_requested.emit(id, cell, sid))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 12)
		row.add_theme_color_override("font_color", UiTheme.FAIL if is_error else UiTheme.AMBER)
		row.tooltip_text = file + "\n" + message
		_rows.add_child(row)
	_heading.text = StudioText.t("problems") + " · " + StudioText.t("problems_counts") % [error_count, warning_count]
	if problems.is_empty():
		_rows.add_child(StudioStyle.line(StudioText.t("problems_none"), UiTheme.MUTED))
