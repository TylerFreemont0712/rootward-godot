class_name BootsEditor
extends Control
## Where the player writes their own movement (ADR-0061). Two ways, one program:
##   Blocks: rules like "when → is pressed, change x by 1", with the real code they make shown underneath, so blocks
##           are a way into code rather than a different thing;
##   Code:   the same function typed by hand, in Python or JavaScript.
## "Try them" hands the program to the town, which runs it in the sandbox (BootsRun) and reports back here. The
## language picker in the header switches between Python and JavaScript, and `language_chosen` says which was chosen.
## What the player edits is a draft, kept in the state as `boots.draft`, until "Try them" makes it the program the town
## runs. Closing the editor or switching language keeps the draft, so code typed and not yet run is never lost.

signal tried(state: Dictionary)
signal closed
signal language_chosen(language: String)

var state: Dictionary = {}

var _mode := OverworldState.BLOCKS
var _blocks: Array = []
## The draft's code for each language, as typed. An empty one runs (and shows) its starter.
var _codes: Dictionary = {}
var _rows: VBoxContainer
var _preview: CodeEdit
var _code: CodeEdit
var _blocks_page: Control
var _code_page: Control
var _blocks_tab: Button
var _code_tab: Button
var _language_buttons: Dictionary = {}
var _hint: Label
var _report: Label
var _draft_note: Label
var _language := BootsCode.PYTHON


func _ready() -> void:
	theme = OverworldStyle.theme()
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
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks_tab = Ui.button(Text.t("Blocks"), _pick_tab.bind(OverworldState.BLOCKS))
	_code_tab = Ui.button(Text.t("Code"), _pick_tab.bind(OverworldState.CODE))
	var close := Ui.button(Text.t("Close"), _close)
	column.add_child(
		Ui.hbox(
			[
				title,
				spacer,
				_language_button(BootsCode.PYTHON, Text.t("Python")),
				_language_button(BootsCode.JAVASCRIPT, Text.t("JavaScript")),
				_blocks_tab,
				_code_tab,
				close
			],
			10
		)
	)
	_draft_note = Ui.label(Text.t("Not run yet. Press Try them to run these."), "Muted")
	_draft_note.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	_draft_note.visible = false
	column.add_child(_draft_note)
	column.add_child(Ui.label(Text.t("x is across (right makes x bigger), y is down (down makes y bigger)."), "Muted"))
	_hint = Ui.label("", "Narration", true)
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
	_blocks_page.add_child(Ui.hbox([Ui.button(Text.t("+ Add a rule"), _add_rule)]))
	_blocks_page.add_child(Ui.label(Text.t("The code your blocks make:"), "Muted"))
	_preview = _make_code(BootsCode.PYTHON)
	_preview.editable = false
	_preview.custom_minimum_size = Vector2(0, 200)
	_blocks_page.add_child(_preview)
	column.add_child(_blocks_page)

	_code_page = Ui.vbox([], 10)
	_code_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code = _make_code(BootsCode.PYTHON)
	_code.text_changed.connect(_on_code_edited)
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, 460)
	_code_page.add_child(_code)
	column.add_child(_code_page)

	_report = Ui.label("", "Muted", true)
	_report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var try := Ui.button(Text.t("Try them  ▶"), _try, "PrimaryButton")
	column.add_child(Ui.hbox([_report, try], 12))


func open(with: Dictionary, hint := "") -> void:
	state = with.duplicate(true)
	_language = String(state.get("language", BootsCode.PYTHON))
	# The editor picks up where the player left off: the draft if there is unrun work, else the program that runs.
	var program := BootsDraft.of(state.boots)
	_mode = String(program.mode)
	_blocks = program["blocks"] as Array
	_codes = program["code"] as Dictionary
	_apply_language()
	_load_code()
	_hint.text = hint
	_hint.visible = hint != ""
	_report.text = ""
	_rebuild_rows()
	_show(_mode)
	_commit()
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


## A code editor in the game's look, at the overworld's code size.
static func _make_code(language: String) -> CodeEdit:
	var editor := LanternEditor.make(language)
	editor.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	return editor


func _language_button(language: String, label: String) -> Button:
	var button := Ui.choice(label, language == _language, _pick_language.bind(language))
	_language_buttons[language] = button
	return button


## The player chose a language. The code on screen is kept in the draft for the language they leave; the one they choose
## shows its draft code, or its starter. The draft is written into the state before the owner hears the choice.
func _pick_language(language: String) -> void:
	if language == _language:
		_sync_language()
		return
	_stash_code()
	_language = language
	state.language = language
	_apply_language()
	_load_code()
	_commit()
	Sound.play("sfx-card-flick-2", 0.3)
	language_chosen.emit(language)


## Everything that differs between Python and JavaScript: the highlighting, the indent and the comment marks.
func _apply_language() -> void:
	var python := _language == BootsCode.PYTHON
	_sync_language()
	_preview.syntax_highlighter = LanternEditor.highlighter(_language)
	_code.syntax_highlighter = LanternEditor.highlighter(_language)
	_code.indent_size = 4 if python else 2
	_code.indent_automatic_prefixes = [":"] if python else ["{", "[", "("]
	_code.delimiter_comments = ["#"] if python else ["//"]
	_preview.text = BootsCode.source(_blocks, _language)


## The language buttons show the one in use: it is pressed and amber, the other is plain.
func _sync_language() -> void:
	for language: String in _language_buttons:
		var button := _language_buttons[language] as Button
		button.set_pressed_no_signal(language == _language)
		button.theme_type_variation = "PrimaryButton" if language == _language else ""


## The Code tab shows what was typed in this language; with nothing typed, the code the blocks make (or the starter).
func _load_code() -> void:
	var typed := String(_codes.get(_language, ""))
	if typed.strip_edges() != "":
		_code.text = typed
	elif not _blocks.is_empty():
		_code.text = BootsCode.source(_blocks, _language)
	else:
		_code.text = BootsCode.starter(_language)


## Shows one tab: its page, and its button in amber.
func _show(mode: String) -> void:
	_mode = mode
	_blocks_page.visible = mode == OverworldState.BLOCKS
	_code_page.visible = mode == OverworldState.CODE
	_blocks_tab.theme_type_variation = "PrimaryButton" if mode == OverworldState.BLOCKS else ""
	_code_tab.theme_type_variation = "PrimaryButton" if mode == OverworldState.CODE else ""
	if mode == OverworldState.CODE:
		_code.grab_focus.call_deferred()


## The player chose a tab. Moving to Code from Blocks carries the blocks over when nothing is typed for this
## language, so typing starts from what the blocks already do. The tab becomes the draft's mode; the program that
## runs keeps its own until Try them.
func _pick_tab(mode: String) -> void:
	if mode == OverworldState.CODE and _mode != OverworldState.CODE and _blocks_changed_code():
		_code.text = BootsCode.source(_blocks, _language)
	_show(mode)
	_commit()


func _blocks_changed_code() -> bool:
	var typed := String(_codes.get(_language, ""))
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
		BootsRules.KEYS.map(func(k: String) -> String: return _key_name(k)),
		BootsRules.KEYS.find(String(block.get("key", "right")))
	)
	key.item_selected.connect(func(i: int) -> void: _change(index, "key", BootsRules.KEYS[i]))
	var axis := _picker(
		BootsCode.AXES.map(func(a: String) -> String: return _axis_name(a)),
		BootsCode.AXES.find(String(action.get("change", "x")))
	)
	axis.item_selected.connect(func(i: int) -> void: _change(index, "change", BootsCode.AXES[i]))
	var amounts: Array = BootsCode.AMOUNTS.map(func(n: int) -> String: return "%+d" % n)
	var by := _picker(amounts, BootsCode.AMOUNTS.find(int(action.get("by", 1))))
	by.item_selected.connect(func(i: int) -> void: _change(index, "by", BootsCode.AMOUNTS[i]))
	var remove := Ui.button("✕", _remove.bind(index))
	var row := Ui.hbox([_word("when"), key, _word("pressed"), _word("change"), axis, _word("by"), by, remove], 12)
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", UiTheme.box(Color("#2a2119"), Color("#5a4630"), 1, 10, Vector2(16, 10)))
	holder.add_child(row)
	return holder


func _word(id: String) -> Label:
	return Ui.label(_word_text(id))


## The words a rule is written in. Each is a literal Text.t call, so the locale check can find it.
static func _word_text(id: String) -> String:
	match id:
		"when":
			return Text.t("When")
		"pressed":
			return Text.t("is pressed:")
		"change":
			return Text.t("change")
		"by":
			return Text.t("by")
	return id


## A key as the picker shows it: an arrow, then its name. Each is a literal Text.t call, for the locale check.
static func _key_name(key: String) -> String:
	match key:
		"up":
			return Text.t("↑  up")
		"down":
			return Text.t("↓  down")
		"left":
			return Text.t("←  left")
		"right":
			return Text.t("→  right")
	return key


## An axis as the picker shows it: the code's name, then the direction in words (the help line says the same).
static func _axis_name(axis: String) -> String:
	match axis:
		"x":
			return Text.t("x  across")
		"y":
			return Text.t("y  down")
	return axis


func _picker(options: Array, chosen: int) -> OptionButton:
	var picker := OptionButton.new()
	for option: Variant in options:
		picker.add_item(String(option))
	picker.select(maxi(0, chosen))
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
	_commit()


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
	_commit()


func _remove(index: int) -> void:
	_blocks.remove_at(index)
	_rebuild_rows()
	_commit()


## "Try them": the draft becomes the program that runs. The state the town gets has no draft left, only the program.
func _try() -> void:
	_stash_code()
	var out := state.duplicate(true)
	var boots: Dictionary = out.boots
	var program := _draft()
	boots.mode = program.mode
	boots.blocks = program.blocks
	boots.code = program.code
	boots.erase("draft")
	state = out
	_refresh_draft_note()
	_report.text = Text.t("Hotaru is trying your boots on…")
	_report.add_theme_color_override("font_color", UiTheme.MUTED)
	tried.emit(state)


## Closing keeps the draft in the state, so the next opening starts from it.
func _close() -> void:
	_stash_code()
	_commit()
	visible = false
	closed.emit()


## The program as the editor holds it now, in the shape the draft is kept.
func _draft() -> Dictionary:
	var mode := BootsDraft.mode_of(_mode, _codes, _language)
	return {"mode": mode, "blocks": _blocks.duplicate(true), "code": _codes.duplicate(true)}


## Writes the draft into the state. It is kept while it would do something other than the program that runs, and dropped
## once it would not, so a draft in the state always means unrun work.
func _commit() -> void:
	var boots: Dictionary = state.boots
	var draft := _draft()
	if BootsDraft.same(draft, BootsDraft.program_of(boots)):
		boots.erase("draft")
	else:
		boots.draft = draft
	_refresh_draft_note()


func _refresh_draft_note() -> void:
	var boots: Dictionary = state.boots
	_draft_note.visible = boots.has("draft")


## The Code tab's text is the code of the language on screen. Leaving that tab (for another language, for Try them
## or for the door) keeps what the player typed in the draft. The blocks' code or the starter, untouched, is not
## theirs and is kept as nothing typed (BootsDraft.typed). Blocks mode shows no code to keep.
func _stash_code() -> void:
	if _mode == OverworldState.CODE:
		_codes[_language] = BootsDraft.typed(_code.text, _blocks, _language)


## Typing in the Code tab writes into the draft as it happens.
func _on_code_edited() -> void:
	# LEARN: setting CodeEdit.text from code does not emit text_changed, but typing does, a frame later. So loading a
	# program, or the blocks carried over into Code, never reaches this handler; only what the player typed is written.
	_codes[_language] = BootsDraft.typed(_code.text, _blocks, _language)
	_commit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
