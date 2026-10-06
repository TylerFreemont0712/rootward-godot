class_name LanternWorkbench
extends PanelContainer
## The tinker's workbench (ADR-0055): the town's files in tabs and an editor on the left; on the right the letter, its
## examples, the hint ladder, and what the last run of its tests found. It owns no rules: the screen gives it a town
## and a letter, and it asks the screen to run tests, take a hint, restore a file, or go back to town.

signal run_requested
signal hint_requested
signal restore_requested(module: String)
signal back_requested
signal add_file_requested

var editor: CodeEdit
var module := ""
var letter_id := ""

var _catalog: Dictionary
var _town: Dictionary
var _tabs: HBoxContainer
var _letter_box: VBoxContainer
var _results: VBoxContainer
var _run_button: Button
var _hint_button: Button
var _restore_button: Button
var _status: Label
## The text each tab holds while another is shown, so switching tabs loses nothing before it is saved.
var _drafts := {}
## The module the editor holds now ("" before the first is shown).
var _shown := ""


static func make() -> LanternWorkbench:
	var bench := LanternWorkbench.new()
	bench.theme_type_variation = "Overlay"
	return bench


func open(catalog: Dictionary, town: Dictionary, letter: String, at_module: String) -> void:
	_catalog = catalog
	_town = town
	letter_id = letter
	_drafts = (town.files as Dictionary).duplicate()
	module = at_module
	_shown = ""
	_build()
	_show_module(at_module)


## The town after the player's edits: every tab's text, ready to save or run.
func files() -> Dictionary:
	_drafts[module] = editor.text
	return _drafts.duplicate()


## Refreshes the town this bench reads (after a hint or a run) without touching the editor.
func set_town(town: Dictionary) -> void:
	_town = town
	_fill_letter()


func set_busy(busy: bool) -> void:
	_run_button.disabled = busy
	_run_button.text = Text.t("The watch is checking...") if busy else Text.t("Run the tests")


## What the tests found: one row per case, the advice for each failure, the error line marked in the editor.
func show_results(report: Dictionary, lit: bool) -> void:
	Ui.clear(_results)
	var results: Array = report.results
	var passed := results.filter(func(r: Dictionary) -> bool: return r.status == "pass").size()
	var heading := Text.f("%d of %d tests passed", [passed, results.size()])
	_results.add_child(Ui.tint(Ui.label(heading, "Subheading"), UiTheme.PASS if lit else UiTheme.TEXT))
	if lit:
		_results.add_child(_lit_banner())
	var marked := false
	for result: Dictionary in results:
		_results.add_child(_result_row(result))
		if not marked and result.status == "error" and int(result.line) > 0:
			marked = true
			if String(result.file).get_basename() == module:
				LanternEditor.mark_error(editor, int(result.line))
	if not marked:
		LanternEditor.mark_error(editor, 0)
	_status.text = ""


func _build() -> void:
	Ui.clear(self)
	var back := FoundryUi.button(Text.t("‹ Back to town"), func() -> void: back_requested.emit(), false, true)
	_tabs = Ui.hbox([], 4)
	var add := FoundryUi.button(Text.t("+ New file"), func() -> void: add_file_requested.emit(), false, true)
	add.tooltip_text = Text.t("A file of your own becomes a workshop in town.")
	var top := Ui.hbox([back, Ui.spacer(16), _tabs, add], 8)
	editor = LanternEditor.make(String(_town.language))
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.custom_minimum_size = Vector2(900, 600)
	_status = Ui.label("", "Muted")
	var left := Ui.vbox([top, editor, _status], 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.55
	_letter_box = Ui.vbox([], 8)
	_run_button = FoundryUi.button(Text.t("Run the tests"), func() -> void: run_requested.emit(), true)
	_run_button.custom_minimum_size = Vector2(220, 44)
	_run_button.tooltip_text = Text.t("Ctrl+Enter")
	_hint_button = FoundryUi.button(Text.t("A hint"), func() -> void: hint_requested.emit())
	_restore_button = FoundryUi.button(
		Text.t("Last night's version"), func() -> void: restore_requested.emit(module), false, true
	)
	_restore_button.tooltip_text = Text.t("Put this file back the way the Night Watch last saw it.")
	_results = Ui.vbox([], 6)
	var right := (
		Ui
		. vbox(
			[
				_letter_box,
				Ui.hbox([_run_button, _hint_button, Ui.spacer(), _restore_button], 8),
				FoundryUi.rule(),
				_results,
			],
			10
		)
	)
	var scroll := Ui.scroll(right)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(560, 0)
	add_child(Ui.hbox([left, scroll], 18))
	_fill_letter()


func _show_module(name: String) -> void:
	if _shown != "":
		_drafts[_shown] = editor.text
	_shown = name
	module = name
	editor.text = String(_drafts.get(name, ""))
	editor.clear_undo_history()
	LanternEditor.mark_error(editor, 0)
	Ui.clear(_tabs)
	for each in LanternLayout.ordered_modules(_catalog, {"files": _drafts}):
		var tab := FoundryUi.button(LanternCode.file_name(each, _town.language), _show_module.bind(each), each == name)
		tab.add_theme_font_override("font", UiTheme.code_font())
		_tabs.add_child(tab)
	_restore_button.visible = (_town.yesterday as Dictionary).has(name)
	editor.grab_focus.call_deferred()


func _fill_letter() -> void:
	Ui.clear(_letter_box)
	if letter_id == "":
		_letter_box.add_child(
			Ui.label(Text.t("No letter is open. Edit freely, then ring the night bell."), "Muted", true)
		)
		_run_button.visible = false
		_hint_button.visible = false
		return
	var request: Dictionary = _catalog.requests[letter_id]
	var villager: Dictionary = _catalog.town.villagers[request.villager]
	var from := Ui.tint(
		Ui.label(Text.f("From %s, %s", [Text.t(villager.name), Text.t(villager.role)]).to_upper(), "Faint"),
		Color(villager.colour)
	)
	_letter_box.add_child(from)
	_letter_box.add_child(Ui.sized(Ui.label(Text.t(request.title), "Heading", true), 24))
	_letter_box.add_child(prose(Text.t(request.letter)))
	var function := LanternCode.function_name(request, _town.language)
	var signature := (
		"%s.%s(%s)"
		% [
			LanternCode.file_name(request.module, _town.language),
			function,
			_join(
				(request.params as Array).map(
					func(p: String) -> String: return LanternCode.function_name({"function": p}, _town.language)
				)
			)
		]
	)
	_letter_box.add_child(Ui.tint(Ui.label(Text.t("WHAT TO BUILD"), "Faint"), UiTheme.AMBER))
	_letter_box.add_child(code(signature))
	_letter_box.add_child(Ui.tint(Ui.label(Text.t("EXAMPLES"), "Faint"), UiTheme.AMBER))
	for example: Dictionary in request.examples:
		_letter_box.add_child(code(_example_line(function, example)))
	var checks: Array = request.checks
	if not checks.is_empty():
		var names := _join(checks.map(func(c: Dictionary) -> String: return Text.t(c.name)))
		_letter_box.add_child(Ui.label(Text.f("The Night Watch will also check: %s.", [names]), "Muted", true))
	var shown := int(_town.hints.get(letter_id, 0))
	var hints: Array = request.hints
	for i in shown:
		var hint := prose(Text.t(hints[i]))
		_letter_box.add_child(Ui.panel(Ui.vbox([Ui.label(Text.f("Hint %d", [i + 1]), "Faint"), hint], 4), "Card"))
	_hint_button.visible = true
	_hint_button.disabled = shown >= hints.size()
	_hint_button.text = (
		Text.f("A hint (%d left)", [hints.size() - shown]) if shown < hints.size() else Text.t("No more hints")
	)
	_run_button.visible = true
	var concepts := Ui.flow([], 6)
	for concept: String in request.concepts:
		concepts.add_child(Ui.panel(Ui.label(Text.t(concept), "Faint"), "Card"))
	_letter_box.add_child(concepts)


func _example_line(function: String, example: Dictionary) -> String:
	var args: Array[String] = []
	for arg: Variant in example.args:
		args.append(_literal(arg))
	return "%s(%s)  →  %s" % [function, ", ".join(args), _literal(example.expect)]


## A value as the player would type it in their language.
func _literal(value: Variant) -> String:
	var python: bool = _town.language == LanternCode.PYTHON
	match typeof(value):
		TYPE_STRING:
			return '"%s"' % value
		TYPE_BOOL:
			return ("True" if value else "False") if python else ("true" if value else "false")
		TYPE_NIL:
			return "None" if python else "null"
		TYPE_ARRAY:
			return "[%s]" % _join((value as Array).map(_literal))
		TYPE_DICTIONARY:
			var parts: Array[String] = []
			var dictionary: Dictionary = value
			for key: Variant in dictionary:
				parts.append(('"%s": %s' if python else "%s: %s") % [key, _literal(dictionary[key])])
			if parts.is_empty():
				return "{}"
			return ("{%s}" if python else "{ %s }") % ", ".join(parts)
	return JsJson.stringify(value)


func _result_row(result: Dictionary) -> Control:
	var marks := {"pass": ["✓", UiTheme.PASS], "fail": ["✗", UiTheme.FAIL], "error": ["!", UiTheme.FAIL]}
	var mark: Array = marks.get(result.status, ["…", UiTheme.WARN])
	var lines := Ui.vbox([], 2)
	var name := String(result.name)
	if name != "":
		lines.add_child(Ui.label(Text.t(name), "Faint"))
	lines.add_child(code(String(result.call) if result.call != "" else String(result.id)))
	match String(result.status):
		"pass":
			lines.add_child(prose(Text.f("gave back `%s`, as expected", [result.actual]), 15))
		"fail":
			lines.add_child(prose(Text.f("expected `%s`, but got `%s`", [result.expected, result.actual])))
		"error":
			var where := Text.f(" (%s, line %d)", [result.file, result.line]) if int(result.line) > 0 else ""
			lines.add_child(Ui.tint(code("%s: %s%s" % [result.error, result.message, where]), UiTheme.FAIL))
		_:
			lines.add_child(Ui.tint(code(Text.t(String(result.message))), UiTheme.MUTED))
	if String(result.printed) != "":
		lines.add_child(Ui.label(Text.t("It printed:"), "Faint"))
		lines.add_child(code(String(result.printed).strip_edges(false, true)))
	var advice := LanternAdvice.nudge(result, String(_town.language))
	if advice != "":
		lines.add_child(Ui.tint(Ui.label(Text.t(advice), "Muted", true), UiTheme.TEAL))
	var symbol := Ui.sized(Ui.tint(Ui.label(String(mark[0]), "Heading"), mark[1]), 22)
	symbol.custom_minimum_size.x = 24
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Ui.panel(Ui.hbox([symbol, lines], 10), "Card")


func _lit_banner() -> Control:
	var request: Dictionary = _catalog.requests[letter_id]
	var go := FoundryUi.button(Text.t("Back to town"), func() -> void: back_requested.emit(), true)
	var box := (
		Ui
		. vbox(
			[
				Ui.sized(Ui.tint(Ui.label(Text.t("✦ The lantern is lit!"), "Heading"), UiTheme.AMBER), 26),
				prose(Text.t(request.learn)),
				go,
			],
			8
		)
	)
	return Ui.panel(box, "Card")


## Prose with `code` in backticks shown in the code font: the UI font is small capitals, and code must keep its case.
static func prose(text: String, font_size := 17) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_font_override("mono_font", UiTheme.code_font())
	rich.add_theme_font_size_override("normal_font_size", font_size)
	rich.add_theme_font_size_override("mono_font_size", font_size - 1)
	rich.add_theme_color_override("default_color", UiTheme.TEXT)
	var parts := text.replace("[", "[lb]").split("`")
	var out := ""
	for i in parts.size():
		out += ("[color=#82d8ff][code]%s[/code][/color]" % parts[i]) if i % 2 == 1 else parts[i]
	rich.text = out
	rich.custom_minimum_size.x = 420
	return rich


static func code(text: String) -> Label:
	var label := Ui.label(text, "", true)
	label.add_theme_font_override("font", UiTheme.code_font())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(CodeColors.CALL))
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return label


static func _join(items: Array) -> String:
	var parts := PackedStringArray()
	for item: Variant in items:
		parts.append(str(item))
	return ", ".join(parts)


## LEARN: _input, not _unhandled_key_input: the CodeEdit has focus and would take Ctrl+Enter as "new line below" first.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not is_visible_in_tree() or key == null or not key.pressed:
		return
	if key.keycode == KEY_ENTER and key.ctrl_pressed and _run_button.visible and not _run_button.disabled:
		get_viewport().set_input_as_handled()
		run_requested.emit()
