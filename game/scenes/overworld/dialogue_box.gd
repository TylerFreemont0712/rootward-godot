class_name DialogueBox
extends Control
## Talking in Lanternroot (ADR-0061), drawn at full resolution over the pixel world, like a light novel: the world
## dims, the speaker's portrait slides in on the left, a name plate, and the words type out with a soft blip. Space,
## Enter, Z or a click finishes the line or goes on; choices appear when a node has them. The talk itself is Talk's.
##
##   box.open(talk, person, flags)      # a conversation; `ended(flags, opens)` when it is over
##   box.say(lines, person)             # a few lines with no talk behind them (a sign, Hotaru's remarks)
##
## The box is as tall as its words and choices need. It grows upward from the bottom of the window, and the portrait
## and name plate stay on its top edge, so a long line or a set of choices never runs off the screen.

signal ended(flags: Dictionary, opens: Array[String])

const CHARS_PER_SECOND := 42.0
const PORTRAIT := 384.0
const PORTRAIT_X := 64.0
const PORTRAIT_SLIDE := 36.0
const MARGIN := 36.0
## The box's height at the start of each line; the words and the choices then make it taller.
const BOX_HEIGHT := 230.0
const BLINK_SPEED := 4.0
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
var _blink := 0.0
var _fade: Tween
var _slide: Tween
var _hop: Tween

var _dim: ColorRect
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name: Label
var _name_plate: PanelContainer
var _box: PanelContainer
var _text: RichTextLabel
var _choices: VBoxContainer
var _more: Label


func _ready() -> void:
	theme = OverworldStyle.theme()
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

	_box = PanelContainer.new()
	_box.name = "Box"
	_box.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.1, 0.075, 0.06, 0.94), UiTheme.AMBER_DIM, 2, 14, Vector2(36, 26))
	)
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 48
	_box.offset_right = -48
	_box.offset_bottom = -MARGIN
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var inside := Ui.vbox([], 10)
	_box.add_child(inside)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("normal_font_size", OverworldStyle.BODY)
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
	_box.resized.connect(_layout)
	resized.connect(_layout)
	_layout()


## The portrait and the name plate follow the box's top edge, which moves as the box grows.
func _layout() -> void:
	var top := _box.position.y
	_portrait_frame.position = Vector2(PORTRAIT_X, top - PORTRAIT - 4)
	_name_plate.position = Vector2(PORTRAIT_X + PORTRAIT + 28, top - 30)


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
	# LEARN: a fade-out still running from the last talk would hide this one when it ends, so the old tween is killed
	# before a new talk starts. A tween is cancelled by killing it; its callbacks never run after that.
	_stop(_fade)
	modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.15)


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
	if _lines.is_empty():
		_finish()
		return
	_line = 0
	_show_line()


func _speaker(line: Dictionary) -> Dictionary:
	return HOTARU if String(line.speaker) == "hotaru" else _person


## A new line starts with the box at its usual height; its words and choices then grow it again.
func _fit_box() -> void:
	_box.offset_top = _box.offset_bottom - BOX_HEIGHT


func _show_line() -> void:
	# Removed at once, not at the end of the frame, so a choice from the last line is never still counted here.
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	_fit_box()
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
		_slide_in()
	if String(line.mood) == "happy" and face != null:
		_hop_portrait()
	_text.text = Text.t(String(line.text))
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_more.visible = false


func _slide_in() -> void:
	_stop(_slide)
	_portrait_frame.modulate.a = 0.0
	_portrait_frame.position.x = PORTRAIT_X - PORTRAIT_SLIDE
	_slide = create_tween().set_parallel()
	_slide.tween_property(_portrait_frame, "position:x", PORTRAIT_X, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	_slide.tween_property(_portrait_frame, "modulate:a", 1.0, 0.18)


func _hop_portrait() -> void:
	_stop(_hop)
	_hop = create_tween()
	_hop.tween_property(_portrait, "position:y", -10.0, 0.08)
	_hop.tween_property(_portrait, "position:y", 0.0, 0.12)


func _process(delta: float) -> void:
	if _more.visible:
		_blink += delta * BLINK_SPEED
		_more.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_blink))
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
	# The blinking marker says "press to go on"; a set of choices replaces it.
	_more.visible = _choices.get_child_count() == 0


func _offer_choices() -> void:
	if _talk.is_empty():
		return
	var first: Button = null
	for choice in Talk.choices(_talk, _node, _flags):
		var button := Ui.button(Text.t(String(choice.text)), _choose.bind(String(choice.goto)))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_stylebox_override("focus", _focus_frame())
		_choices.add_child(button)
		if first == null:
			first = button
	if first != null:
		first.grab_focus.call_deferred()


## The frame of the focused choice: thick and amber, so the one Enter picks is plain at a glance.
static func _focus_frame() -> StyleBoxFlat:
	return UiTheme.box(Color(UiTheme.AMBER, 0.14), UiTheme.AMBER, 3, 7, Vector2(20, 8))


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
	_stop(_fade)
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.12)
	_fade.tween_callback(_hide)
	ended.emit(_flags, _opens.duplicate())


## Hides the box once its fade has run, unless a new talk has begun in the meantime.
func _hide() -> void:
	if not busy:
		visible = false


static func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		advance()
