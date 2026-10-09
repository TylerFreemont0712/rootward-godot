class_name DialogueBox
extends Control
## Talking in Lanternroot (ADR-0061), drawn at full resolution over the pixel world, like a light novel: the world
## dims, the speaker's portrait slides in on the left, a name plate, and the words type out with a soft blip. Space,
## Enter, Z or a click finishes the line or goes on; choices appear when a node has them. The talk itself is Talk's.
##
##   box.open(talk, person, flags)      # a conversation; `ended(flags, opens)` when it is over
##   box.say(lines, person)             # a few lines with no talk behind them (a sign, Hotaru's remarks)

signal ended(flags: Dictionary, opens: Array[String])

const CHARS_PER_SECOND := 42.0
const PORTRAIT := 384.0
const BOX_HEIGHT := 230.0
const HOTARU := {"name": "Hotaru", "portrait": "hotaru", "voice": 1.45}

var busy := false

var _talk: Dictionary = {}
var _person: Dictionary = {}
var _flags: Dictionary = {}
var _opens: Array[String] = []
var _node := ""
var _lines: Array[Dictionary] = []
var _line := 0
var _typing := false
var _shown := 0.0
var _blip := 0

var _dim: ColorRect
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name: Label
var _name_plate: PanelContainer
var _text: RichTextLabel
var _choices: VBoxContainer
var _more: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.03, 0.06, 0.35)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_click)
	add_child(_dim)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override(
		"panel", UiTheme.box(Color("#1a1410"), UiTheme.AMBER_DIM, 3, 10, Vector2(6, 6))
	)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_frame.add_child(_portrait)
	add_child(_portrait_frame)

	var box := PanelContainer.new()
	box.name = "Box"
	box.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.1, 0.075, 0.06, 0.94), UiTheme.AMBER_DIM, 2, 14, Vector2(36, 26))
	)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 48
	box.offset_right = -48
	box.offset_top = -BOX_HEIGHT - 36
	box.offset_bottom = -36
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var inside := Ui.vbox([], 10)
	box.add_child(inside)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("normal_font_size", 30)
	_text.add_theme_color_override("default_color", Color("#f3e6c8"))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inside.add_child(_text)
	_choices = Ui.vbox([], 8)
	inside.add_child(_choices)
	_more = Ui.label("▼", "Muted")
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inside.add_child(_more)

	_name_plate = PanelContainer.new()
	_name_plate.add_theme_stylebox_override("panel", UiTheme.box(Color("#2a2119"), UiTheme.AMBER, 2, 8, Vector2(20, 6)))
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = Ui.label("", "Subheading")
	_name_plate.add_child(_name)
	add_child(_name_plate)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var bottom := size.y - BOX_HEIGHT - 36
	_portrait_frame.position = Vector2(64, bottom - PORTRAIT - 4)
	_name_plate.position = Vector2(64 + PORTRAIT + 28, bottom - 30)


## A conversation from content. `person` is the townsperson ({name, portrait, voice}).
func open(talk: Dictionary, person: Dictionary, flags: Dictionary) -> void:
	_talk = talk
	_person = person
	_flags = flags.duplicate()
	_opens.clear()
	_start()
	_enter(Talk.opening(talk, _flags))


## A few lines with no talk behind them: each {text, speaker ("hotaru", or "" for `person`), mood}.
func say(lines: Array[Dictionary], person: Dictionary = {}, flags: Dictionary = {}) -> void:
	_talk = {}
	_person = person
	_flags = flags.duplicate()
	_opens.clear()
	_start()
	_node = ""
	_lines = lines
	_line = 0
	_show_line()


func _start() -> void:
	busy = true
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func _enter(id: String) -> void:
	if id == "" or Talk.node(_talk, id).is_empty():
		_finish()
		return
	_node = id
	_flags = Talk.remember(_talk, id, _flags)
	var opens := String(Talk.node(_talk, id).get("open", ""))
	if opens != "":
		_opens.append(opens)
	_lines = Talk.lines(_talk, id)
	_line = 0
	_show_line()


func _speaker(line: Dictionary) -> Dictionary:
	return HOTARU if String(line.speaker) == "hotaru" else _person


func _show_line() -> void:
	for child in _choices.get_children():
		child.queue_free()
	var line: Dictionary = _lines[_line]
	var who := _speaker(line)
	var shown_name := String(who.get("name", ""))
	_name.text = Text.t(shown_name)
	_name_plate.visible = shown_name != ""
	var face := OverworldArt.portrait(String(who.get("portrait", "")))
	var had := _portrait.texture
	_portrait.texture = face
	_portrait_frame.visible = face != null
	if face != null and face != had:
		_portrait_frame.modulate.a = 0.0
		var from := _portrait_frame.position
		_portrait_frame.position = from - Vector2(36, 0)
		var slide := create_tween().set_parallel()
		slide.tween_property(_portrait_frame, "position", from, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
		slide.tween_property(_portrait_frame, "modulate:a", 1.0, 0.18)
	if String(line.mood) == "happy" and face != null:
		var hop := create_tween()
		hop.tween_property(_portrait, "position:y", -10.0, 0.08)
		hop.tween_property(_portrait, "position:y", 0.0, 0.12)
	_text.text = Text.t(String(line.text))
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_more.visible = false


func _process(delta: float) -> void:
	if not _typing:
		return
	var before := int(_shown)
	_shown += delta * CHARS_PER_SECOND
	var total := _text.get_total_character_count()
	_text.visible_characters = mini(int(_shown), total)
	if int(_shown) != before:
		_blip += 1
		if _blip % 3 == 0:
			var who := _speaker(_lines[_line])
			Sound.play("sfx-card-flick-1", 0.18, float(who.get("voice", 1.0)) * randf_range(0.95, 1.05))
	if int(_shown) >= total:
		_end_typing()


func _end_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	if _line == _lines.size() - 1:
		_offer_choices()
	_more.visible = _choices.get_child_count() == 0


func _offer_choices() -> void:
	if _talk.is_empty():
		return
	var first: Button = null
	for choice in Talk.choices(_talk, _node, _flags):
		var button := Ui.button(Text.t(choice.text), _choose.bind(choice.goto))
		button.add_theme_font_size_override("font_size", 24)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_choices.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus.call_deferred()


func _choose(goto: String) -> void:
	Sound.play("sfx-card-place-1", 0.4)
	_enter(goto)


## Space, Enter or Z: finish the line, or go on.
func advance() -> void:
	if not busy:
		return
	if _typing:
		_end_typing()
		return
	if _choices.get_child_count() > 0:
		return
	if _line < _lines.size() - 1:
		_line += 1
		_show_line()
		return
	var next := Talk.next(_talk, _node) if not _talk.is_empty() else ""
	if next != "":
		_enter(next)
	else:
		_finish()


func _finish() -> void:
	busy = false
	_typing = false
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.12)
	fade.tween_callback(func() -> void: visible = false)
	ended.emit(_flags, _opens.duplicate())


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		advance()
