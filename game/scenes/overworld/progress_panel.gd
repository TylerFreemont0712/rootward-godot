class_name ProgressPanel
extends Control
## One Lanternroot character's progress (ADR-0061), over the character screen: who they are and how long they have
## played, their quests (done ones ticked, the open one with its steps, the ones still to come as "???"), their boots
## (the language, Builder or Scribe, the keys they know, and the code itself, big enough to read) and the townspeople
## they have met (the others wait in the dark). Back, Esc or a pad's B closes it.
##
##   var progress := ProgressPanel.new()
##   add_child(progress)
##   progress.open(state, catalog)
##   progress.closed.connect(_focus_card)

signal closed

const PORTRAIT := 112.0
const PORTRAIT_COLUMNS := 4
const COLUMN_WIDTH := 420.0
const COLUMN_HEIGHT := 560.0
## How far Up and Down scroll the quests.
const SCROLL_STEP := 90

var state: Dictionary = {}

var _panel: PanelContainer
var _quests: ScrollContainer
var _back: Button
var _closing := false


func _ready() -> void:
	theme = OverworldStyle.menu_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = FrontPanel.SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func open(saved: Dictionary, catalog: Dictionary) -> void:
	state = saved
	_closing = false
	for child in get_children():
		if child is not ColorRect:
			remove_child(child)
			child.queue_free()
	var column := Ui.vbox([], 16)
	_panel = FrontPanel.panel(column)
	FrontPanel.centre(self, _panel)
	column.add_child(_header())
	var flags := CharacterDigest.flags_of(saved)
	(
		column
		. add_child(
			(
				Ui
				. hbox(
					[
						_section(Text.t("Quests"), _quest_list(catalog.get("quests", {}), flags)),
						_section(Text.t("Boots"), _boots()),
						_section(Text.t("Townspeople"), _townspeople(catalog.get("townsfolk", {}), flags)),
					],
					16
				)
			)
		)
	)
	_back = FrontPanel.button(Text.t("Back"), close)
	_back.custom_minimum_size.x = 200
	var help := FrontPanel.keys(Text.t("Up and down: scroll the quests   Esc: back"))
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(Ui.hbox([_back, help], 20))
	FrontPanel.reveal(self, _panel)
	_back.grab_focus.call_deferred()


func close() -> void:
	if _closing or not visible:
		return
	_closing = true
	FrontPanel.cancelled()
	FrontPanel.conceal(self, closed.emit)


func _header() -> Control:
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override(
		"panel", UiTheme.box(CharacterCreator.GRASS, CharacterCreator.GRASS_EDGE, 3, 12, Vector2(22, 14))
	)
	# The selected complete player sheet shown in the overworld, at the screen's 2x.
	var preview := WalkPreview.new()
	preview.name = "Figure"
	preview.zoom = CharacterStand.ZOOM
	preview.set_look(state.get("look", {}) if state.get("look", {}) is Dictionary else {})
	stage.add_child(preview)
	var title := FrontPanel.heading(CharacterCard.name_of(state))
	var kind := Ui.label(CharacterCard.class_line(state))
	kind.add_theme_color_override("font_color", OverworldStyle.MUTED)
	var times := FrontPanel.small(
		Text.f("Time in town: %s", [CharacterCard.played_for(state)]) + "   ·   " + CharacterCard.last_played(state)
	)
	var words := Ui.vbox([title, kind, times], 4)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	return Ui.hbox([stage, words], 24)


## A column of the panel: a small heading over its content, in a quieter box than the panel's own.
func _section(title: String, content: Control) -> Control:
	var heading := Ui.label(title, "Subheading")
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.025), UiTheme.LINE, 2, 12, Vector2(20, 16)))
	box.custom_minimum_size = Vector2(COLUMN_WIDTH, COLUMN_HEIGHT)
	box.add_child(Ui.vbox([heading, content], 12))
	return box


# --- quests --------------------------------------------------------------------------------------------------------


func _quest_list(quests: Dictionary, flags: Dictionary) -> Control:
	var list := Ui.vbox([], 14)
	var entries := Quests.entries(quests, flags)
	var done := 0
	for entry in entries:
		if String(entry.status) == Quests.DONE:
			done += 1
		list.add_child(_quest(entry))
	_quests = Ui.scroll(list)
	_quests.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var count := FrontPanel.small(Text.f("%d of %d done", [done, entries.size()]))
	var column := Ui.vbox([count, _quests], 8)
	# The list takes the column's height; without the flag the column shrinks to the count and the list is never seen.
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return column


func _quest(entry: Dictionary) -> Control:
	var status := String(entry.status)
	var locked := status == Quests.LOCKED
	var title := Ui.label("???" if locked else Text.t(String(entry.title)))
	title.add_theme_font_override("font", OverworldStyle.body_font(600))
	title.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	title.add_theme_color_override("font_color", OverworldStyle.MUTED if locked else UiTheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var head := Ui.hbox([ProgressMark.of(status), title, _status_chip(status)], 10)
	var rows := Ui.vbox([head], 6)
	if locked:
		rows.add_child(_indent(FrontPanel.small(Text.t("Still to come."))))
		return rows
	if String(entry.summary) != "" and status == Quests.OPEN:
		rows.add_child(_indent(FrontPanel.small(Text.t(String(entry.summary)), true)))
	for step: Dictionary in entry.steps:
		var ticked := bool(step.done)
		var words := Ui.label(Text.t(String(step.text)), "", true)
		words.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
		words.add_theme_color_override("font_color", OverworldStyle.MUTED if ticked else UiTheme.TEXT)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_child(_indent(Ui.hbox([ProgressMark.of("tick" if ticked else "todo", 20.0), words], 8)))
	return rows


func _status_chip(status: String) -> Control:
	var text := Text.t("Done")
	var colour := UiTheme.PASS
	if status == Quests.OPEN:
		text = Text.t("Now")
		colour = UiTheme.AMBER
	elif status == Quests.LOCKED:
		text = Text.t("Later")
		colour = OverworldStyle.MUTED
	var label := Ui.label(text)
	label.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	label.add_theme_color_override("font_color", colour)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(colour, 0.12), Color(colour, 0.7), 1, 10, Vector2(10, 2))
	)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(label)
	return chip


func _indent(control: Control) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_child(control)
	return margin


# --- boots ---------------------------------------------------------------------------------------------------------


func _boots() -> Control:
	var boots: Dictionary = state.get("boots", {}) if state.get("boots", {}) is Dictionary else {}
	var language := String(state.get("language", BootsCode.PYTHON))
	var style := String(boots.get("style", OverworldState.BUILDER))
	var how := (
		Text.t("Builds with blocks, and reads their code.")
		if style != OverworldState.SCRIBE
		else Text.t("Types the code by hand.")
	)
	var line := FrontPanel.small(
		"%s · %s" % [BootsCodePanel.language_name(language), CharacterCard.style_name(style)] + "   " + how, true
	)
	var keys := Ui.hbox([], 8)
	var taught := CharacterDigest.keys_taught(state)
	for key in BootsRules.KEYS:
		keys.add_child(_key_chip(key, key in taught))
	var from := (
		Text.t("The code your boots run (you typed it):")
		if CharacterDigest.typed(state)
		else Text.t("The code your blocks make:")
	)
	var column := Ui.vbox(
		[line, FrontPanel.small(Text.t("Keys your boots know:")), keys, FrontPanel.small(from), _code(language)], 10
	)
	# The code takes what the column has left: without the flag it stays the height of its line.
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return column


static func key_word(key: String) -> String:
	match key:
		"up":
			return Text.t("up")
		"down":
			return Text.t("down")
		"left":
			return Text.t("left")
	return Text.t("right")


func _key_chip(key: String, known: bool) -> Control:
	var arrows := {"up": "↑", "down": "↓", "left": "←", "right": "→"}
	var label := Ui.label("%s %s" % [arrows.get(key, ""), key_word(key)])
	label.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	label.add_theme_color_override("font_color", UiTheme.AMBER if known else UiTheme.FAINT)
	var chip := PanelContainer.new()
	var edge := UiTheme.AMBER_DIM if known else UiTheme.LINE
	chip.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(UiTheme.AMBER, 0.1) if known else Color(0, 0, 0, 0), edge, 1, 10, Vector2(10, 4))
	)
	chip.add_child(label)
	return chip


func _code(language: String) -> Control:
	var view := LanternEditor.make(language)
	view.text = CharacterDigest.source(state)
	view.editable = false
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	view.add_theme_constant_override("line_spacing", 6)
	# Not editable draws in font_readonly_color, half transparent by default: the code here is for reading, so solid.
	view.add_theme_color_override("font_color", BootsCodePanel.TEXT_COLOUR)
	view.add_theme_color_override("font_readonly_color", BootsCodePanel.TEXT_COLOUR)
	view.add_theme_color_override("line_number_color", UiTheme.MUTED)
	var well := UiTheme.box(LanternEditor.BACKGROUND, UiTheme.LINE, 1, 10, Vector2(12, 10))
	view.add_theme_stylebox_override("normal", well)
	view.add_theme_stylebox_override("read_only", well)
	view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	view.indent_wrapped_lines = true
	view.scroll_past_end_of_file = false
	view.focus_mode = Control.FOCUS_NONE
	view.highlight_current_line = false
	view.context_menu_enabled = false
	view.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return view


# --- townspeople ---------------------------------------------------------------------------------------------------


func _townspeople(townsfolk: Dictionary, flags: Dictionary) -> Control:
	var met := CharacterDigest.met(townsfolk, flags)
	var grid := GridContainer.new()
	grid.columns = PORTRAIT_COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	for id: String in townsfolk:
		grid.add_child(_person(townsfolk[id], id in met))
	var count := FrontPanel.small(Text.f("%d of %d met", [met.size(), townsfolk.size()]))
	return Ui.vbox([count, grid], 10)


func _person(person: Dictionary, known: bool) -> Control:
	var face := TextureRect.new()
	face.texture = OverworldArt.portrait(String(person.get("portrait", "")))
	face.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Not met yet: only a shape in the dark, and no name.
	face.modulate = Color.WHITE if known else Color(0.16, 0.14, 0.2)
	var frame := PanelContainer.new()
	var edge := UiTheme.AMBER_DIM if known else UiTheme.LINE
	frame.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.3), edge, 2, 10, Vector2(4, 4)))
	frame.add_child(face)
	var name_label := Ui.label(Text.t(String(person.get("name", ""))) if known else "???")
	name_label.add_theme_font_size_override("font_size", OverworldStyle.SMALL)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT if known else UiTheme.FAINT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size.x = PORTRAIT
	if known:
		frame.tooltip_text = (
			"%s, %s" % [Text.t(String(person.get("name", ""))), Text.t(String(person.get("title", "")))]
		)
	return Ui.vbox([frame, name_label], 2)


## Up and down scroll the quests. They are read before the controls see them: Back is the panel's only control, so
## there is nowhere for the focus to go anyway.
func _input(event: InputEvent) -> void:
	if not visible or _closing or _quests == null:
		return
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("ui_down", true):
		_quests.scroll_vertical += SCROLL_STEP if event.is_action_pressed("ui_down", true) else -SCROLL_STEP
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if FrontPanel.is_back(event):
		close()
	elif FrontPanel.pad_button(event) == JOY_BUTTON_A:
		FrontPanel.press_focused(get_viewport())
	else:
		return
	get_viewport().set_input_as_handled()
