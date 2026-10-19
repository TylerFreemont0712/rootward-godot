class_name BootsEditor
extends Control
## Where the player writes their own movement (ADR-0061), in one of two styles. One program either way:
##   Builder: rules as blocks ("when → is pressed, change x by 1") on the left, and the real code they make on the
##            right, rewritten as each block changes (the lines that changed glow for a moment). Blocks are a way into
##            code, not a different thing.
##   Scribe:  the same function typed by hand, in one wide code panel that starts from the blocks' code.
## The Builder / Scribe switch in the header writes the style into `state.boots.style`, which travels with the boots.
## The language switch picks Python or JavaScript, and `language_chosen` says which was chosen. "Try them" (or
## Ctrl+Enter) hands the program to the town, which runs it in the sandbox (BootsRun) and reports back here.
## What the player edits is a draft, kept in the state as `boots.draft` (BootsDraft), until "Try them" makes it the
## program the town runs. Closing the editor, or switching language or style, keeps the draft, so unrun work is never
## lost.
##
##   ┌ YOUR BOOTS ─────────────── [Builder|Scribe]  [Python|JavaScript]  [Close] ┐
##   │ (x→ y↓)  the hint, in green; under it, which way x and y go               │
##   │ Blocks  What each key does          Python  The code your blocks make      │
##   │ ┌ When [→ right] is pressed:   ✕ ┐  ┌ 1 def on_key(key, player):       ┐ │
##   │ │     change [x across] by [+1]  │  │ 2     if key == "right":         │ │
##   │ └────────────────────────────────┘  │ 3         player.x += 1          │ │
##   │ [+ Add a rule]                      └──────────────────────────────────┘ │
##   │ what the town found; "Not run yet" while there is a draft    [Try them ▶] │
##   └───────────────────────────────────────────────────────────────────────────┘

signal tried(state: Dictionary)
signal closed
signal language_chosen(language: String)

## The panel's size in the design's units. The canvas is about 2180 x 1230 of them at the 0.88 stretch, whatever the
## window, so the panel fits a 1280x720 window as it fits 1920x1080, with the town showing round its edge.
const PANEL_SIZE := Vector2(1660, 1090)
const SHADE := Color(0.04, 0.03, 0.05, 0.55)
const HINT_COLOUR := Color("#d6f57a")

var state: Dictionary = {}

## The draft's mode, from the style on screen: Builder edits blocks, Scribe edits code (BootsDraft.mode_of).
var _mode := OverworldState.BLOCKS
var _style := OverworldState.BUILDER
var _blocks: Array = []
## The draft's code for each language, as typed. An empty one runs (and shows) its starter.
var _codes: Dictionary = {}
var _language := BootsCode.PYTHON
## The rule whose card has the focus (its lines are lit in the code), or -1.
var _lit_row := -1

var _panel: PanelContainer
var _rows: VBoxContainer
var _add: Button
var _blocks_column: Control
## Builder's code column: the code the blocks make, read-only.
var _preview: BootsCodePanel
## Scribe's code panel: the code the player types.
var _typed: BootsCodePanel
var _style_buttons: Dictionary = {}
var _language_buttons: Dictionary = {}
var _hint: Label
var _report: Label
var _draft_note: Label
var _try_button: Button


func _ready() -> void:
	theme = OverworldStyle.editor_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", OverworldStyle.panel_box())
	_panel.custom_minimum_size = PANEL_SIZE
	centre.add_child(_panel)
	_panel.add_child(Ui.vbox([_header(), _guide(), _body(), _footer()], 10))
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## Opens on `with` (the town's state, copied). `hint` is Hotaru's line for this opening, shown in green at the top.
func open(with: Dictionary, hint := "") -> void:
	state = with.duplicate(true)
	_language = String(state.get("language", BootsCode.PYTHON))
	# The editor picks up where the player left off: the draft if there is unrun work, else the program that runs.
	var program := BootsDraft.of(state.boots)
	_blocks = program["blocks"] as Array
	_codes = program["code"] as Dictionary
	# Typed code that runs opens in Scribe whatever the style says (an older save has none), since Builder would put
	# the blocks in its place the moment it opened.
	var scribe := String((state.boots as Dictionary).get("style", "")) == OverworldState.SCRIBE
	_style = OverworldState.SCRIBE if scribe or String(program.mode) == OverworldState.CODE else OverworldState.BUILDER
	state.boots.style = _style
	_lit_row = -1
	_typed.hints.sync()
	_apply_language()
	_load_code()
	set_hint(hint)
	_report.text = ""
	_rebuild_rows()
	_preview.mark(BootsCodePanel.NOTHING)
	_show()
	_commit()
	visible = true
	OverworldStyle.pop_in(self, _panel)
	_focus_first.call_deferred()


func set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


## What the town found when it ran the boots: shown beside Try them, green when it went well, red for an error.
func report(text: String, ok: bool) -> void:
	_report.text = text
	_report.add_theme_color_override("font_color", UiTheme.PASS if ok else UiTheme.FAIL)


# --- the layout -------------------------------------------------------------------------------------------------------


## The title, the two switches (style and language) and Close.
func _header() -> Control:
	var title := Ui.label(Text.t("Your boots"), "Heading")
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var styles := _switch(
		[
			_switch_button(
				_style_buttons,
				OverworldState.BUILDER,
				Text.t("Builder"),
				Text.t("Build with blocks, and see the code they make."),
				_pick_style
			),
			_switch_button(
				_style_buttons, OverworldState.SCRIBE, Text.t("Scribe"), Text.t("Type the code yourself."), _pick_style
			),
		]
	)
	var languages := _switch(
		[
			_switch_button(
				_language_buttons, BootsCode.PYTHON, BootsCodePanel.language_name(BootsCode.PYTHON), "", _pick_language
			),
			_switch_button(
				_language_buttons,
				BootsCode.JAVASCRIPT,
				BootsCodePanel.language_name(BootsCode.JAVASCRIPT),
				"",
				_pick_language
			),
		]
	)
	var close := Ui.button(Text.t("Close"), _close)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(96, 0)
	return Ui.hbox([title, Ui.spacer(), styles, Ui.spacer(6, 0), languages, Ui.spacer(6, 0), close], 10)


## A pair of buttons in a sunken well, one of them chosen (amber): a switch.
static func _switch(buttons: Array) -> Control:
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", OverworldStyle.well_box(Vector2(4, 4), 10))
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.add_child(Ui.hbox(buttons, 3))
	return well


## One side of a switch, kept in `group` under `id`; pressing it calls `on_pick` with the id.
static func _switch_button(group: Dictionary, id: String, text: String, tip: String, on_pick: Callable) -> Button:
	var button := Ui.choice(text, false, on_pick.bind(id))
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(100, 0)
	group[id] = button
	return button


## The chosen side of a switch is pressed and amber, the other plain.
static func _sync_switch(group: Dictionary, chosen: String) -> void:
	for id: String in group:
		var button := group[id] as Button
		button.set_pressed_no_signal(id == chosen)
		button.theme_type_variation = "PrimaryButton" if id == chosen else ""


## Hotaru's hint in green, and under it which way x and y go, beside a small drawing of the two.
func _guide() -> Control:
	_hint = Ui.label("", "", true)
	_hint.add_theme_color_override("font_color", HINT_COLOUR)
	var axes := Ui.label(Text.t("x is across (right makes x bigger), y is down (down makes y bigger)."), "Muted", true)
	var words := Ui.vbox([_hint, axes], 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	return Ui.hbox([BootsBlocks.axis_glyph(), words], 14)


## Builder's two columns (the blocks, and the code they make) and Scribe's one wide code panel, side by side; the
## style shows one or the other.
func _body() -> Control:
	_rows = Ui.vbox([], 8)
	_add = Ui.button(Text.t("+ Add a rule"), _add_rule)
	_add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", OverworldStyle.well_box(Vector2(10, 10), 10))
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	well.add_child(Ui.scroll(Ui.vbox([_rows, _add], 10)))
	var heading := BootsCodePanel.heading(Ui.label(Text.t("Blocks")), Ui.label(Text.t("What each key does"), "Muted"))
	_blocks_column = Ui.vbox([heading, well], 6)
	_blocks_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_blocks_column.size_flags_stretch_ratio = 0.8
	_preview = BootsCodePanel.new(false)
	_typed = BootsCodePanel.new(true)
	_typed.enable_hints("boots")
	_typed.editor.text_changed.connect(_on_code_edited)
	var body := Ui.hbox([_blocks_column, _preview, _typed], 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return body


## What the town found and whether there is unrun work, beside Try them.
func _footer() -> Control:
	_report = Ui.label("", "", true)
	_draft_note = Ui.label(Text.t("Not run yet. Press Try them to run these."), "Muted", true)
	_draft_note.add_theme_color_override("font_color", UiTheme.WARN)
	_draft_note.visible = false
	var status := Ui.vbox([_report, _draft_note], 4)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.alignment = BoxContainer.ALIGNMENT_CENTER
	status.custom_minimum_size = Vector2(0, 44)
	_try_button = Ui.button(Text.t("Try them  ▶"), _try, "PrimaryButton")
	_try_button.tooltip_text = Text.t("Ctrl+Enter")
	_try_button.custom_minimum_size = Vector2(190, 44)
	_try_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.hbox([status, _try_button], 14)


## Builder: the first rule's key (or "+ Add a rule"). Scribe: the code, ready to type in.
func _focus_first() -> void:
	if not visible:
		return
	if _style == OverworldState.SCRIBE:
		_typed.editor.grab_focus()
	else:
		_focus_row(0)


## The focus on rule `index`'s first picker, or on "+ Add a rule" when there is no such rule.
func _focus_row(index: int) -> void:
	if not visible:
		return
	for card: Node in _rows.get_children():
		if card.has_meta("row") and int(card.get_meta("row")) == index:
			BootsBlocks.first_picker(card as Control).grab_focus()
			return
	_add.grab_focus()


# --- the switches -----------------------------------------------------------------------------------------------------


## The player chose a language. The code on screen is kept in the draft for the language they leave; the one they choose
## shows its draft code, or its starter. The draft is written into the state before the owner hears the choice.
func _pick_language(language: String) -> void:
	if language == _language:
		_sync_switch(_language_buttons, _language)
		return
	_stash_code()
	_language = language
	state.language = language
	_apply_language()
	_load_code()
	_preview.mark(_lines_of(_lit_row))
	_commit()
	Sound.play("sfx-card-flick-1", 0.3)
	language_chosen.emit(language)


## The player chose a style. Scribe shows what was typed in this language, or else carries the blocks' code over, so
## typing starts from what the blocks already do; Builder shows the blocks. The style goes into the boots at once (it
## is how the player likes to build, not part of the program), and the draft follows the style's mode.
func _pick_style(style: String) -> void:
	if style == _style:
		_sync_switch(_style_buttons, _style)
		return
	_stash_code()
	_style = style
	state.boots.style = style
	if style == OverworldState.SCRIBE:
		_load_code()
	_show()
	_commit()
	Sound.play("sfx-card-flick-1", 0.3)


## Everything that differs between Python and JavaScript, in both code panels: the name over the code, the highlighting,
## the indent and the comment marks; and the blocks' code in the new language.
func _apply_language() -> void:
	_sync_switch(_language_buttons, _language)
	_preview.set_language(_language, Text.t("The code your blocks make"))
	_typed.set_language(_language, Text.t("Type your code here. Ctrl+Enter tries it."))
	_preview.show_code(BootsCode.source(_blocks, _language))


## Scribe's panel shows what was typed in this language; with nothing typed, the code the blocks make (or the starter).
func _load_code() -> void:
	var typed := String(_codes.get(_language, ""))
	if typed.strip_edges() == "":
		typed = BootsCode.source(_blocks, _language) if not _blocks.is_empty() else CodeComments.localized(BootsCode.starter(_language))
	_typed.editor.text = typed
	_typed.editor.clear_undo_history()


## Shows the style's side: Builder's blocks and their code, or Scribe's one wide panel. The style is the draft's mode.
func _show() -> void:
	var scribe := _style == OverworldState.SCRIBE
	_mode = OverworldState.CODE if scribe else OverworldState.BLOCKS
	_blocks_column.visible = not scribe
	_preview.visible = not scribe
	_typed.visible = scribe
	_sync_switch(_style_buttons, _style)


# --- the blocks -------------------------------------------------------------------------------------------------------


func _rebuild_rows() -> void:
	Ui.clear(_rows)
	for i in _blocks.size():
		_rows.add_child(BootsBlocks.card(_blocks[i], i, _change, _remove))
	if _blocks.is_empty():
		_rows.add_child(
			Ui.label(Text.t("No rules yet. Add one, and your boots will know what to do with a key."), "Muted", true)
		)
	_lit_row = -1


## The code column, rewritten from the blocks. With `flash`, the lines that changed glow for a moment.
func _refresh_code(flash: bool) -> void:
	_preview.show_code(BootsCode.source(_blocks, _language), flash)
	_preview.mark(_lines_of(_lit_row))


## The lines of the code that rule `row` makes, as [start, end): the ones that are there with the rule and not without.
func _lines_of(row: int) -> Vector2i:
	if row < 0 or row >= _blocks.size():
		return BootsCodePanel.NOTHING
	var without := _blocks.duplicate(true)
	without.remove_at(row)
	var lines := BootsCodePanel.changed_lines(
		BootsCode.source(without, _language), BootsCode.source(_blocks, _language)
	)
	return lines if lines.y > lines.x else BootsCodePanel.NOTHING


## The rule whose card holds the focus is lit, and so are its lines in the code.
func _on_focus_changed(control: Control) -> void:
	if not visible or control == null or not is_ancestor_of(control):
		return
	_light(BootsBlocks.row_of(control) if _rows.is_ancestor_of(control) else -1)


func _light(row: int) -> void:
	if row == _lit_row:
		return
	_lit_row = row
	for card: Node in _rows.get_children():
		if card is PanelContainer and card.has_meta("row"):
			var lit := int(card.get_meta("row")) == row
			(card as PanelContainer).add_theme_stylebox_override("panel", BootsBlocks.style(lit))
	_preview.mark(_lines_of(row))


func _change(index: int, field: String, value: Variant) -> void:
	var block: Dictionary = _blocks[index]
	if field == "key":
		block.key = value
	else:
		if not block.get("do") is Array or (block.do as Array).is_empty():
			block.do = [{"change": "x", "by": 1}]
		((block.do as Array)[0] as Dictionary)[field] = value
	Sound.play("sfx-card-flick-1", 0.3)
	_refresh_code(true)
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
	_refresh_code(true)
	_commit()
	_focus_row.call_deferred(_blocks.size() - 1)


func _remove(index: int) -> void:
	_blocks.remove_at(index)
	Sound.play("sfx-whiff", 0.25)
	_rebuild_rows()
	_refresh_code(true)
	_commit()
	_focus_row.call_deferred(mini(index, _blocks.size() - 1))


# --- trying, closing and the draft ------------------------------------------------------------------------------------


## "Try them": the draft becomes the program that runs. The state the town gets has no draft left, only the program
## (and the style, which travels with the boots).
func _try() -> void:
	_stash_code()
	var out := state.duplicate(true)
	var boots: Dictionary = out.boots
	var program := _draft()
	boots.mode = program.mode
	boots.blocks = program.blocks
	boots.code = program.code
	boots.style = _style
	boots.erase("draft")
	state = out
	_refresh_draft_note()
	_report.text = Text.t("Hotaru is trying your boots on…")
	_report.add_theme_color_override("font_color", OverworldStyle.MUTED)
	Sound.play("sfx-card-place-1", 0.4)
	tried.emit(state)


## Closing keeps the draft in the state, so the next opening starts from it. It is at once: the town reads `visible`
## as "the editor is open", so a fade here would hold the player still for its length.
func _close() -> void:
	_stash_code()
	_commit()
	visible = false
	Sound.play("sfx-whiff", 0.3)
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


## Scribe's text is the code of the language on screen. Leaving it (for another language or style, for Try them or for
## the door) keeps what the player typed in the draft. The blocks' code or the starter, untouched, is not theirs and is
## kept as nothing typed (BootsDraft.typed). Builder shows no typed code to keep.
func _stash_code() -> void:
	if _mode == OverworldState.CODE:
		_codes[_language] = BootsDraft.typed(_unlocalized(_typed.editor.text), _blocks, _language)


## The starter as the game writes it when `text` is the starter shown in the player's language (CodeComments): an
## untouched starter is not the player's code in either language.
func _unlocalized(text: String) -> String:
	var starter := BootsCode.starter(_language)
	return starter if text.strip_edges() == CodeComments.localized(starter).strip_edges() else text


## Typing in Scribe writes into the draft as it happens.
func _on_code_edited() -> void:
	# LEARN: setting CodeEdit.text from code does not emit text_changed, but typing does, a frame later. So loading a
	# program, or the blocks carried over into Scribe, never reaches this handler; only what the player typed is written.
	_codes[_language] = BootsDraft.typed(_unlocalized(_typed.editor.text), _blocks, _language)
	_commit()


# --- keys -------------------------------------------------------------------------------------------------------------


## Ctrl+Enter tries the boots from anywhere in the editor. It is read before the controls see it, since the code panel
## would otherwise take it as a new line.
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.ctrl_pressed and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_try()


## Esc, or B on a pad, closes the editor (an open picker's list takes Esc first, and closes itself). A on a pad presses
## what has the focus.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var pad := _pad_button(event)
	if event.is_action_pressed("ui_cancel") or pad == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		_close()
	elif pad == JOY_BUTTON_A:
		_press_focused()


## The pad button just pressed, or -1 for any other event.
static func _pad_button(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.is_pressed():
		return (event as InputEventJoypadButton).button_index
	return -1


# LEARN: Godot's ui_accept is only keys (Enter, Space), so a pad's A reaches no button by itself. The editor presses the
# focused control for it: a button is pressed, and a picker steps to its next choice, since a pad cannot work the list a
# picker opens (that list is a window of its own, which this editor's keys never reach).
func _press_focused() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		return
	get_viewport().set_input_as_handled()
	if focused is OptionButton:
		var picker := focused as OptionButton
		var next := (picker.selected + 1) % maxi(1, picker.item_count)
		picker.select(next)
		picker.item_selected.emit(next)
	elif focused is BaseButton:
		(focused as BaseButton).pressed.emit()
