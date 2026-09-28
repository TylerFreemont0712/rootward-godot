class_name GitLogView
extends PanelContainer
## The run history as git prints it (RunHistory): `git log --oneline --decorate`, newest first, and a click on a line
## shows that run's `git show` under it. A terminal on a dark plate: hashes in amber, HEAD and tags in colour, the
## commit type coloured by how the run ended.

signal closed

const TYPE_COLOURS := {"feat": "#8fdc6b", "revert": "#e2584f", "chore": "#a58f6e"}
const HASH := "#f2a541"
const HEAD := "#5cc8b8"
const TAG := "#ffd166"
const PROMPT := "#8fdc6b"

var records: Array[Dictionary] = []
var _open := {}
var _text: RichTextLabel


static func create(history: Array[Dictionary]) -> GitLogView:
	var view := GitLogView.new()
	view.theme_type_variation = "Overlay"
	view.records = history
	view._build()
	return view


func _build() -> void:
	custom_minimum_size = Vector2(1040, 0)
	var shipped := records.filter(func(record: Dictionary) -> bool: return record.get("status", "") == "won").size()
	var head := Ui.hbox(
		[
			Ui.label("git log", "Heading"),
			Ui.label("%d runs · %d shipped" % [records.size(), shipped], "Faint"),
			Ui.spacer(),
			Ui.button("Close", func() -> void: closed.emit()),
		],
		14
	)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.add_theme_font_override("normal_font", UiTheme.ui_font())
	_text.add_theme_font_size_override("normal_font_size", 15)
	_text.meta_clicked.connect(_toggle)
	# A terminal does not underline its lines; the hand cursor over them says they can be clicked.
	_text.meta_underlined = false
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.03, 0.03, 0.04, 0.96), Color(1, 1, 1, 0.08), 1, 8, Vector2(18, 14))
	)
	var scroll := Ui.scroll(_text, true)
	scroll.custom_minimum_size = Vector2(0, 560)
	plate.add_child(scroll)
	var hint := Ui.label(
		"Click a line for its git show. Every finished Shardrun is a commit; nothing rewrites history.", "Faint"
	)
	add_child(Ui.vbox([head, plate, hint], 12))
	_render()


func _toggle(meta: Variant) -> void:
	var key := String(meta)
	if _open.has(key):
		_open.erase(key)
	else:
		_open[key] = true
	_render()


func _render() -> void:
	var lines: PackedStringArray = ["[color=%s]$[/color] git log --oneline --decorate" % PROMPT, ""]
	if records.is_empty():
		var fatal := "your current branch 'main' does not have any commits yet"
		lines.append("[color=%s]fatal:[/color] %s" % [TYPE_COLOURS.revert, fatal])
		var hint := "  (finish a Shardrun, won or lost, and it is committed here)"
		lines.append("[color=%s]%s[/color]" % [UiTheme.FAINT.to_html(), hint])
	for index in records.size():
		var record: Dictionary = records[index]
		var hash := RunHistory.short_hash(record)
		lines.append("[url=%s]%s[/url]" % [hash, _oneline(record, index == 0)])
		if _open.has(hash):
			for line in RunHistory.show(record, index == 0):
				lines.append("      " + _shown(line))
			lines.append("")
	_text.text = "\n".join(lines)


## A oneline entry in colour: the hash, the decoration, the commit type, the rest of the subject.
func _oneline(record: Dictionary, newest: bool) -> String:
	var subject := _escape(RunHistory.subject(record))
	var kind := subject.get_slice("(", 0)
	var colour: String = TYPE_COLOURS.get(kind, "#e9dcc0")
	subject = "[color=%s]%s[/color]%s" % [colour, kind, subject.substr(kind.length())]
	var decoration := ""
	var parts: Array[String] = []
	if newest:
		parts.append("[color=%s]HEAD -> main[/color]" % HEAD)
	if record.get("status", "") == "won":
		parts.append("[color=%s]tag: shipped[/color]" % TAG)
	if not parts.is_empty():
		decoration = "(%s) " % ", ".join(parts)
	return "[color=%s]%s[/color] %s%s" % [HASH, RunHistory.short_hash(record), decoration, subject]


## One line of `git show`, coloured as git colours it.
func _shown(line: String) -> String:
	var safe := _escape(line)
	if line.begins_with("commit "):
		return "[color=%s]%s[/color]" % [HASH, safe]
	if line.begins_with("Author:") or line.begins_with("Date:"):
		return "[color=%s]%s[/color]" % [UiTheme.MUTED.to_html(), safe]
	if line.contains("insertions(+)"):
		safe = safe.replace("insertions(+)", "[color=#8fdc6b]insertions(+)[/color]")
		return safe.replace("deletions(-)", "[color=#e2584f]deletions(-)[/color]")
	return safe


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
