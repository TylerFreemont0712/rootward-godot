class_name StudioPublishDialog
extends Window
## A concrete Publish review: changes in words, the whole world's problems, and a deliberate warning/conflict choice.
## The Studio owns the service calls and supplies a refreshed review after Rebase or a failed publish.

signal publish_requested(accept_warnings: bool, keep_paths: Array[String])
signal rebase_requested(map_id: String)
signal jump_requested(map_id: String, cell: Vector2i, sid: int)
signal dismissed


var report: Dictionary = {}
var problems_panel: StudioProblemsPanel
var publish_button: Button
var warnings_checkbox: CheckBox

var _summary: Label
var _changes: VBoxContainer
var _feedback: Label
var _kept_hashes: Dictionary = {}


func _init() -> void:
	name = "StudioPublishDialog"
	title = StudioText.t("publish_title")
	visible = false
	borderless = true
	unresizable = true
	transient = true
	exclusive = true
	size = Vector2i(820, 620)
	min_size = Vector2i(560, 400)
	theme = UiTheme.shared()
	close_requested.connect(_dismiss)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StudioStyle.box(Vector2(18, 14)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var column := Ui.vbox([], 8)
	panel.add_child(column)
	var heading := StudioStyle.line(StudioText.t("publish_title"), UiTheme.AMBER)
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	var intro := Ui.label(StudioText.t("publish_intro"), "Muted", true)
	intro.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	column.add_child(intro)
	_summary = StudioStyle.line("")
	column.add_child(_summary)
	column.add_child(StudioStyle.rule())
	_changes = Ui.vbox([], 6)
	var scroll := Ui.scroll(_changes)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	problems_panel = StudioProblemsPanel.new()
	problems_panel.custom_minimum_size.y = 160
	problems_panel.jump_requested.connect(func(id: String, cell: Vector2i, sid: int) -> void:
		jump_requested.emit(id, cell, sid)
	)
	problems_panel.close_requested.connect(func() -> void: problems_panel.hide())
	column.add_child(problems_panel)
	warnings_checkbox = CheckBox.new()
	warnings_checkbox.text = StudioText.t("publish_accept_warnings")
	warnings_checkbox.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	warnings_checkbox.toggled.connect(func(_accepted: bool) -> void: _update_confirm())
	column.add_child(warnings_checkbox)
	_feedback = Ui.label("", "", true)
	_feedback.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	_feedback.add_theme_color_override("font_color", UiTheme.FAIL)
	_feedback.visible = false
	column.add_child(_feedback)
	var hint := Ui.label(StudioText.t("publish_backup_hint"), "Muted", true)
	hint.add_theme_font_size_override("font_size", 12)
	column.add_child(hint)
	publish_button = StudioStyle.button(StudioText.t("publish_confirm"), _confirm, true)
	var cancel := StudioStyle.button(StudioText.t("publish_cancel"), _dismiss)
	column.add_child(Ui.hbox([Ui.spacer(), cancel, publish_button], 8))


func show_review(review_data: Dictionary) -> void:
	_kept_hashes.clear()
	render_review(review_data)
	popup_centered(size)


## Refreshes an open review. Keep choices survive only while the reviewed disk hashes are identical.
func render_review(review_data: Dictionary) -> void:
	report = review_data
	_feedback.visible = false
	Ui.clear(_changes)
	var changes: Array = report.get("changes", [])
	var conflicts: Array = report.get("conflicts", [])
	_summary.text = StudioText.t("publish_summary") % [changes.size(), int(report.get("error_count", 0)),
		int(report.get("warning_count", 0)), conflicts.size()]
	_changes.add_child(StudioStyle.caption(StudioText.t("publish_changes")))
	for change: Dictionary in changes:
		_changes.add_child(StudioStyle.line(String(change.file).get_file() + " · " + String(change.summary)))
		for line: String in change.get("lines", []):
			var label := Ui.label("  " + line, "Muted", true)
			label.add_theme_font_size_override("font_size", StudioStyle.SMALL)
			_changes.add_child(label)
	if changes.is_empty():
		_changes.add_child(StudioStyle.line(StudioText.t("publish_none"), UiTheme.MUTED))
	var current_keeps: Dictionary = {}
	for conflict: Dictionary in conflicts:
		var path := String(conflict.file)
		var hash_now := String(conflict.get("current_hash", ""))
		if String(_kept_hashes.get(path, "")) == hash_now and hash_now != "":
			current_keeps[path] = hash_now
	_kept_hashes = current_keeps
	for conflict: Dictionary in conflicts:
		_add_conflict(conflict)
	var found: Array[Dictionary] = []
	found.assign(report.get("problems", []))
	problems_panel.show_problems(found)
	problems_panel.visible = not found.is_empty()
	warnings_checkbox.set_pressed_no_signal(false)
	warnings_checkbox.visible = int(report.get("warning_count", 0)) > 0
	_update_confirm()


func show_failure(message: String) -> void:
	_feedback.text = message
	_feedback.visible = true


func keep_paths() -> Array[String]:
	var paths: Array[String] = []
	paths.assign(_kept_hashes.keys())
	paths.sort()
	return paths


func _add_conflict(conflict: Dictionary) -> void:
	var path := String(conflict.file)
	var id := String(conflict.get("map_id", path.get_file().get_basename()))
	var hash_now := String(conflict.get("current_hash", ""))
	var row := Ui.vbox([], 4)
	var notice := Ui.label(StudioText.t("publish_conflict") % path.get_file(), "", true)
	notice.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	notice.add_theme_color_override("font_color", UiTheme.AMBER)
	row.add_child(notice)
	var keep := StudioStyle.button(StudioText.t("publish_keep"), Callable(), _kept_hashes.has(path), StudioText.t("publish_keep_tip"))
	keep.toggle_mode = true
	keep.set_pressed_no_signal(_kept_hashes.has(path))
	keep.toggled.connect(func(chosen: bool) -> void:
		if chosen:
			_kept_hashes[path] = hash_now
		else:
			_kept_hashes.erase(path)
		StudioStyle.choose(keep, chosen)
		_update_confirm()
	)
	var rebase_button := StudioStyle.button(StudioText.t("publish_rebase"),
		func() -> void: rebase_requested.emit(id), false, StudioText.t("publish_rebase_tip"))
	row.add_child(Ui.hbox([keep, rebase_button, Ui.spacer()], 6))
	_changes.add_child(Ui.panel(row))


func _update_confirm() -> void:
	var unresolved := false
	for conflict: Dictionary in report.get("conflicts", []):
		if not _kept_hashes.has(String(conflict.file)):
			unresolved = true
	var warnings := int(report.get("warning_count", 0)) > 0
	publish_button.disabled = int(report.get("error_count", 0)) > 0 or unresolved \
		or (report.get("changes", []) as Array).is_empty() or (warnings and not warnings_checkbox.button_pressed)


func _confirm() -> void:
	if not publish_button.disabled:
		publish_requested.emit(warnings_checkbox.button_pressed, keep_paths())


func _dismiss() -> void:
	hide()
	dismissed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_dismiss()
		set_input_as_handled()
