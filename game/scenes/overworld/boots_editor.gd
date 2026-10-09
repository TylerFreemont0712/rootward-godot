class_name BootsEditor
extends Control
## Where the player writes their own movement (ADR-0061). Two ways, one program:
##   Blocks: rules like "when → is pressed, change x by 1", with the real code they make shown underneath, so blocks
##           are a way into code rather than a different thing;
##   Code:   the same function typed by hand, in Python or JavaScript.
## "Try them" hands the program to the town, which runs it in the sandbox (BootsRun) and reports back here.

signal tried(state: Dictionary)
signal closed

const KEY_LABELS := {"up": "↑  up", "down": "↓  down", "left": "←  left", "right": "→  right"}

var state: Dictionary = {}

var _mode := OverworldState.BLOCKS
var _blocks: Array = []
var _rows: VBoxContainer
var _preview: CodeEdit
var _code: CodeEdit
var _blocks_page: Control
var _code_page: Control
var _blocks_tab: Button
var _code_tab: Button
var _hint: Label
var _report: Label
var _language := BootsCode.PYTHON


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.05, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.1, 0.075, 0.06, 0.97), UiTheme.AMBER_DIM, 2, 16, Vector2(32, 26))
	)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1240, 780)
	panel.position = Vector2(-620, -390)
	add_child(panel)
	var column := Ui.vbox([], 14)
	panel.add_child(column)

	var title := Ui.label(Text.t("Your boots"), "Heading")
	var close := Ui.button(Text.t("Close"), _close)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks_tab = Ui.button(Text.t("Blocks"), _show.bind(OverworldState.BLOCKS))
	_code_tab = Ui.button(Text.t("Code"), _show.bind(OverworldState.CODE))
	column.add_child(Ui.hbox([title, spacer, _blocks_tab, _code_tab, close], 10))
	_hint = Ui.label("", "Narration", true)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color("#d6f57a"))
	column.add_child(_hint)

	_blocks_page = Ui.vbox([], 12)
	_blocks_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size = Vector2(0, 250)
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows = Ui.vbox([], 10)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(_rows)
	_blocks_page.add_child(scroller)
	var add := Ui.button(Text.t("+ Add a rule"), _add_rule)
	add.add_theme_font_size_override("font_size", 22)
	_blocks_page.add_child(Ui.hbox([add]))
	_blocks_page.add_child(Ui.label(Text.t("The code your blocks make:"), "Muted"))
	_preview = LanternEditor.make(BootsCode.PYTHON)
	_preview.editable = false
	_preview.custom_minimum_size = Vector2(0, 200)
	_blocks_page.add_child(_preview)
	column.add_child(_blocks_page)

	_code_page = Ui.vbox([], 10)
	_code_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code = LanternEditor.make(BootsCode.PYTHON)
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, 460)
	_code_page.add_child(_code)
	column.add_child(_code_page)

	_report = Ui.label("", "Muted", true)
	_report.add_theme_font_size_override("font_size", 20)
	var try := Ui.button(Text.t("Try them  ▶"), _try, "PrimaryButton")
	try.add_theme_font_size_override("font_size", 24)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(Ui.hbox([_report, gap, try], 12))


func open(with: Dictionary, hint := "") -> void:
	state = with.duplicate(true)
	_language = String(state.get("language", BootsCode.PYTHON))
	_preview.syntax_highlighter = LanternEditor.highlighter(_language)
	_code.syntax_highlighter = LanternEditor.highlighter(_language)
	_blocks = (state.boots.blocks as Array).duplicate(true)
	var typed := String((state.boots.code as Dictionary).get(_language, ""))
	_code.text = typed if typed.strip_edges() != "" else BootsCode.starter(_language)
	_hint.text = hint
	_hint.visible = hint != ""
	_report.text = ""
	_rebuild_rows()
	_show(String(state.boots.mode))
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


## What the town found when it ran the boots: shown under the editor, red for an error.
func report(text: String, ok: bool) -> void:
	_report.text = text
	_report.add_theme_color_override("font_color", UiTheme.PASS if ok else UiTheme.FAIL)


func _show(mode: String) -> void:
	_mode = mode
	_blocks_page.visible = mode == OverworldState.BLOCKS
	_code_page.visible = mode == OverworldState.CODE
	_blocks_tab.theme_type_variation = "PrimaryButton" if mode == OverworldState.BLOCKS else ""
	_code_tab.theme_type_variation = "PrimaryButton" if mode == OverworldState.CODE else ""
	if mode == OverworldState.CODE and _blocks_changed_code():
		# Moving to code carries the blocks over, so typing starts from what the blocks already do.
		_code.text = BootsCode.source(_blocks, _language)
	if mode == OverworldState.CODE:
		_code.grab_focus.call_deferred()


func _blocks_changed_code() -> bool:
	var typed := String((state.boots.code as Dictionary).get(_language, ""))
	return typed.strip_edges() == "" and not _blocks.is_empty()


func _rebuild_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for i in _blocks.size():
		_rows.add_child(_row(i))
	if _blocks.is_empty():
		_rows.add_child(
			Ui.label(Text.t("No rules yet. Add one, and your boots will know what to do with a key."), "Muted", true)
		)
	_preview.text = BootsCode.source(_blocks, _language)


func _row(index: int) -> Control:
	var block: Dictionary = _blocks[index]
	var action: Dictionary = (
		(block.get("do", [{}]) as Array)[0] if not (block.get("do", []) as Array).is_empty() else {}
	)
	var key := _picker(
		BootsRules.KEYS.map(func(k: String) -> String: return Text.t(KEY_LABELS[k])),
		BootsRules.KEYS.find(String(block.get("key", "right")))
	)
	key.item_selected.connect(func(i: int) -> void: _change(index, "key", BootsRules.KEYS[i]))
	var axis := _picker(["x", "y"], BootsCode.AXES.find(String(action.get("change", "x"))))
	axis.item_selected.connect(func(i: int) -> void: _change(index, "change", BootsCode.AXES[i]))
	var amounts: Array = BootsCode.AMOUNTS.map(func(n: int) -> String: return "%+d" % n)
	var by := _picker(amounts, BootsCode.AMOUNTS.find(int(action.get("by", 1))))
	by.item_selected.connect(func(i: int) -> void: _change(index, "by", BootsCode.AMOUNTS[i]))
	var remove := Ui.button("✕", _remove.bind(index))
	var row := Ui.hbox([_word("When"), key, _word("is pressed:"), _word("change"), axis, _word("by"), by, remove], 12)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UiTheme.box(Color("#2a2119"), Color("#5a4630"), 1, 10, Vector2(16, 10)))
	holder.add_child(row)
	return holder


func _word(english: String) -> Label:
	var word := Ui.label(Text.t(english))
	word.add_theme_font_size_override("font_size", 24)
	return word


func _picker(options: Array, chosen: int) -> OptionButton:
	var picker := OptionButton.new()
	for option: Variant in options:
		picker.add_item(String(option))
	picker.select(maxi(0, chosen))
	picker.add_theme_font_size_override("font_size", 24)
	return picker


func _change(index: int, field: String, value: Variant) -> void:
	var block: Dictionary = _blocks[index]
	if field == "key":
		block.key = value
	else:
		if (block.get("do", []) as Array).is_empty():
			block.do = [{"change": "x", "by": 1}]
		block.do[0][field] = value
	_preview.text = BootsCode.source(_blocks, _language)


func _add_rule() -> void:
	var taken := _blocks.map(func(b: Dictionary) -> String: return String(b.get("key", "")))
	var key := "right"
	for k: String in ["right", "down", "left", "up"]:
		if not k in taken:
			key = k
			break
	_blocks.append(BootsCode.rule(key, "x", 1))
	Sound.play("sfx-card-place-1", 0.4)
	_rebuild_rows()


func _remove(index: int) -> void:
	_blocks.remove_at(index)
	_rebuild_rows()


func _try() -> void:
	if _mode == OverworldState.BLOCKS:
		state = OverworldState.with_blocks(state, _blocks)
	else:
		state = OverworldState.with_code(state, _code.text)
	_report.text = Text.t("Hotaru is trying your boots on…")
	_report.add_theme_color_override("font_color", UiTheme.MUTED)
	tried.emit(state)


func _close() -> void:
	visible = false
	closed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
