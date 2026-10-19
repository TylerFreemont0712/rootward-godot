class_name StudioHistoryList
extends VBoxContainer
## The history list (Concept/v0.3/10, section 6): the names of the changes that stand, newest first, so an undo is a
## look at the top line. It lives at the foot of the tools column.

## How many lines show.
const SHOWN := 12

## The lines now shown, newest first, for the tests.
var lines: Array[String] = []

var _rows: VBoxContainer


func _init() -> void:
	name = "History"
	add_theme_constant_override("separation", 2)
	add_child(StudioStyle.caption(StudioText.t("history")))
	_rows = Ui.vbox([], 1)
	add_child(_rows)
	show_labels([])


## `labels` are StudioHistory.labels(): the changes that stand, oldest first.
func show_labels(labels: Array[String]) -> void:
	Ui.clear(_rows)
	lines.clear()
	for i: int in range(labels.size() - 1, maxi(labels.size() - SHOWN, 0) - 1, -1):
		lines.append(labels[i])
		var row := StudioStyle.line(labels[i], UiTheme.TEXT if i == labels.size() - 1 else UiTheme.MUTED)
		row.add_theme_font_size_override("font_size", 12)
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_rows.add_child(row)
	if labels.is_empty():
		var none := StudioStyle.line(StudioText.t("history_none"), UiTheme.FAINT)
		none.add_theme_font_size_override("font_size", 12)
		_rows.add_child(none)
