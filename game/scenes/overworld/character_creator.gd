class_name CharacterCreator
extends Control
## Make your own character (ADR-0061), before the first morning in Lanternroot: a name, hair and its colour, skin,
## clothes and their colours, and one extra (glasses, goggles, a hat). The preview turns and walks, so the choice is
## seen the way the town will see it. Choices come from content (`overworld/looks.jsonc`); the picture is the same
## parts the townspeople are built from.

signal done(look: Dictionary, chosen_name: String)

const TURN := 1.1
const STRIDE := 0.22

var look: Dictionary = {}
var options: Dictionary = {}

var _name: LineEdit
var _preview: TextureRect
var _atlas: AtlasTexture
var _labels: Dictionary = {}
var _clock := 0.0
var _facing := 0


func _ready() -> void:
	theme = OverworldStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.08, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


## The English name of an option, translated. Each one is a literal Text.t call, so the locale check can find it; an id
## it does not know is shown as it is.
static func label_of(id: String) -> String:
	match id:
		"hair/short":
			return Text.t("Short")
		"hair/long":
			return Text.t("Long")
		"hair/bun":
			return Text.t("Bun")
		"hair/spiky":
			return Text.t("Spiky")
		"hair/fluffy":
			return Text.t("Fluffy")
		"hair/braid":
			return Text.t("Braid")
		"outfit/tunic":
			return Text.t("Tunic")
		"outfit/dress":
			return Text.t("Dress and apron")
		"outfit/coat":
			return Text.t("Warm coat")
		"outfit/vest":
			return Text.t("Vest")
		"outfit/robe":
			return Text.t("Robe")
		"hat/goggles":
			return Text.t("Goggles")
		"hat/leaves":
			return Text.t("Leaf crown")
		"hat/wide":
			return Text.t("Wide hat")
		"hat/hood":
			return Text.t("Hood")
		"face/glasses":
			return Text.t("Glasses")
		"", "none":
			return Text.t("Nothing")
	return id


func open(choices: Dictionary) -> void:
	options = choices
	look = (choices.get("start", {}) as Dictionary).duplicate(true)
	if not look.has("colours"):
		look.colours = {}
	_build()
	_refresh()
	visible = true


func _build() -> void:
	for child in get_children():
		if child is not ColorRect:
			child.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.1, 0.075, 0.06, 0.97), UiTheme.AMBER_DIM, 2, 16, Vector2(40, 32))
	)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1360, 820)
	panel.position = Vector2(-680, -410)
	add_child(panel)
	var columns := Ui.hbox([], 48)
	panel.add_child(columns)

	var left := Ui.vbox([], 16)
	left.add_child(Ui.label(Text.t("Who are you?"), "Heading"))
	left.add_child(Ui.label(Text.t("The new tinker of Lanternroot. Make yourself!"), "Muted", true))
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.box(Color("#86c45a"), Color("#3f7040"), 3, 12, Vector2(24, 24)))
	_atlas = AtlasTexture.new()
	_preview = TextureRect.new()
	_preview.texture = _atlas
	_preview.custom_minimum_size = Vector2(16 * 18, 24 * 18)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(_preview)
	left.add_child(stage)
	columns.add_child(left)

	var right := Ui.vbox([], 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = LineEdit.new()
	_name.placeholder_text = Text.t("Your name")
	_name.max_length = 12
	_name.custom_minimum_size = Vector2(420, 0)
	right.add_child(_row(Text.t("Name"), _name))
	right.add_child(_row(Text.t("Hair"), _cycler("hair", options.get("hair", []))))
	right.add_child(_row(Text.t("Hair colour"), _swatches("hair", options.get("hair_colour", []))))
	right.add_child(_row(Text.t("Skin"), _swatches("skin", options.get("skin", []))))
	right.add_child(_row(Text.t("Clothes"), _cycler("outfit", options.get("outfit", []))))
	right.add_child(_row(Text.t("Clothes colour"), _swatches("main", options.get("cloth", []))))
	right.add_child(_row(Text.t("Trim colour"), _swatches("second", options.get("cloth", []))))
	var extras: Array = []
	extras.append_array(options.get("hat", []))
	for face: Variant in options.get("face", []):
		if String(face) != "none":
			extras.append(face)
	right.add_child(_row(Text.t("Something extra"), _cycler("extra", extras)))
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(gap)
	var random := Ui.button(Text.t("Surprise me"), _surprise)
	var finish := Ui.button(Text.t("That's me!  ▶"), _finish, "PrimaryButton")
	right.add_child(Ui.hbox([random, finish], 16))
	columns.add_child(right)


func _row(text: String, control: Control) -> Control:
	var label := Ui.label(text, "Muted")
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	return Ui.hbox([label, control], 12)


func _cycler(slot: String, choices: Array) -> Control:
	var shown := Ui.label("")
	shown.custom_minimum_size = Vector2(260, 0)
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_labels[slot] = shown
	var back := Ui.button("◀", _turn.bind(slot, choices, -1))
	var next := Ui.button("▶", _turn.bind(slot, choices, 1))
	return Ui.hbox([back, shown, next], 8)


func _swatches(slot: String, ramps: Array) -> Control:
	var row := Ui.flow([], 6)
	row.custom_minimum_size = Vector2(700, 0)
	for ramp: Variant in ramps:
		var colours := OverworldArt.ramp(String(ramp))
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(44, 44)
		var colour := colours[1] if colours.size() > 1 else Color.GRAY
		swatch.add_theme_stylebox_override("normal", UiTheme.box(colour, Color("#2a1d2b"), 2, 8))
		swatch.add_theme_stylebox_override("hover", UiTheme.box(colour, UiTheme.AMBER, 3, 8))
		swatch.add_theme_stylebox_override("pressed", UiTheme.box(colour, Color.WHITE, 3, 8))
		swatch.add_theme_stylebox_override("focus", UiTheme.box(Color.TRANSPARENT, UiTheme.TEAL, 2, 8))
		swatch.pressed.connect(_colour.bind(slot, String(ramp)))
		row.add_child(swatch)
	return row


func _value(slot: String) -> String:
	if slot == "extra":
		return String(look.get("hat", look.get("face", "none")))
	return String(look.get(slot, ""))


func _turn(slot: String, choices: Array, by: int) -> void:
	if choices.is_empty():
		return
	var at := choices.find(_value(slot))
	var chosen := String(choices[posmod(at + by, choices.size())])
	if slot == "extra":
		look.erase("hat")
		look.erase("face")
		if chosen.begins_with("hat/"):
			look.hat = chosen
		elif chosen.begins_with("face/"):
			look.face = chosen
	else:
		look[slot] = chosen
	Sound.play("sfx-card-flick-2", 0.3)
	_refresh()


func _colour(slot: String, ramp: String) -> void:
	look.colours[slot] = ramp
	if slot == "main" and String(look.get("hat", "")) in ["hat/hood", "hat/wide"]:
		look.colours.accent = ramp
	Sound.play("sfx-card-flick-1", 0.3)
	_refresh()


func _surprise() -> void:
	look.hair = _any("hair", "hair/short")
	look.outfit = _any("outfit", "outfit/tunic")
	look.erase("hat")
	look.erase("face")
	if randf() < 0.5:
		var extra := _any("hat", "none")
		if extra != "none":
			look.hat = extra
	look.colours = {
		"hair": _any("hair_colour", "hair_brown"),
		"skin": _any("skin", "skin_peach"),
		"main": _any("cloth", "cloth_blue"),
		"second": _any("cloth", "cloth_cream"),
		"accent": _any("cloth", "cloth_red"),
	}
	Sound.play("sfx-chime", 0.35)
	_refresh()


func _any(list: String, fallback: String) -> String:
	var choices: Array = options.get(list, [])
	return String(choices[randi() % choices.size()]) if not choices.is_empty() else fallback


func _refresh() -> void:
	for slot: String in _labels:
		(_labels[slot] as Label).text = label_of(_value(slot))
	_atlas.atlas = OverworldArt.sheet(look)
	_show_frame()


func _show_frame() -> void:
	var facings: Array[String] = ["down", "left", "up", "right"]
	var facing := facings[_facing % facings.size()]
	var pose: int = [0, 1, 0, 2][int(_clock / STRIDE) % 4]
	_atlas.region = Rect2(OverworldArt.frame_rect(facing, pose))
	_preview.flip_h = facing == "right"


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if _clock >= TURN * 4:
		_clock = 0.0
	_facing = int(_clock / TURN)
	_show_frame()


func _finish() -> void:
	var chosen := _name.text.strip_edges()
	Sound.play("sfx-pass", 0.4)
	visible = false
	done.emit(look.duplicate(true), chosen if chosen != "" else Text.t("Tinker"))
