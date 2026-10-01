class_name SkinSelectionPanel
extends PanelContainer
## The wardrobe: the battle looks on a turning wheel, as a champion's skins are browsed in League of Legends. The look
## being browsed stands large in the middle with its neighbours smaller and dimmer on each side; the arrows, the mouse
## wheel, the left and right keys or a click on a side card turn the wheel, and Equip puts on the one in the middle.
## The chosen look is remembered in Settings.

signal closed
signal skin_selected(id: String)

## The wheel's stage, and where each place on it stands: [distance from the middle, card size, brightness].
const STAGE := Vector2(1120, 470)
const PLACES: Array[Array] = [
	[0.0, Vector2(320, 450), 1.0],
	[270.0, Vector2(220, 316), 0.5],
	[455.0, Vector2(160, 228), 0.26],
	[560.0, Vector2(120, 170), 0.0],
]
const TURN_SECONDS := 0.32
## The shipped looks, in the wheel's order: [id, name, epithet, note, portrait].
const LOOKS: Array[Array] = [
	[
		"vesper",
		"Vesper",
		"Star-Script Witch",
		"A crescent hat, a plum capelet, and a palm strike that writes in starlight. Drawn, not modelled.",
		"res://assets/sprites/vesper/profile.png",
	],
	[
		"emberfox",
		"Emberfox",
		"Salvage Runner",
		"Amber eyes, a teal field coat, and one bright ember tail.",
		"res://characters/emberfox/emberfox_front.png",
	],
	[
		"shibu",
		"Shibu",
		"Hovering Caster · 3D trial",
		"A VRoid model on the new move set: she drives her palms through the circle at the foes.",
		"res://assets/portraits/shibu.png",
	],
	[
		"dummy",
		"Motion Dummy",
		"Animation lab · plain mannequin",
		"A jointed mannequin on the same skeleton as every 3D skin, for judging the moves with nothing to hide behind.",
		"res://assets/portraits/dummy.png",
	],
]

## [{id, name, epithet, note, portrait}] in the wheel's order.
var _looks: Array[Dictionary] = []
var _cards: Array[Control] = []
var _at := 0
var _stage: Control
var _epithet: Label
var _name: Label
var _note: Label
var _equip: Button
var _dots: HBoxContainer


static func create() -> SkinSelectionPanel:
	var panel := SkinSelectionPanel.new()
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


static func looks() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for look: Array in LOOKS:
		found.append({"id": look[0], "name": look[1], "epithet": look[2], "note": look[3], "portrait": look[4]})
	# Reference skins on this machine only (git-ignored, never shipped), for comparing looks in a real fight.
	for id in Settings.all_skins():
		if not id in Settings.CHARACTER_SKINS:
			(
				found
				. append(
					{
						"id": id,
						"name": id.capitalize(),
						"epithet": "Local reference · not shipped",
						"note": "A model kept on this machine to study its look; it plays the same moves.",
						"portrait": Settings.LOCAL_SKINS + id + "/portrait.png",
					}
				)
			)
	return found


func _build() -> void:
	_looks = looks()
	for i in _looks.size():
		if _looks[i].id == Settings.character_skin:
			_at = i
	var header := Ui.hbox(
		[
			Ui.vbox([Ui.label("FIELD WARDROBE", "Faint"), Ui.label("Choose your battle look", "Heading")], 2),
			Ui.spacer(),
			Ui.button("Close", _close)
		],
		12
	)
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.clip_contents = true
	_stage.gui_input.connect(_on_wheel)
	for i in _looks.size():
		var card := _card(_looks[i], i)
		_cards.append(card)
		_stage.add_child(card)
	_epithet = Ui.label("", "Faint")
	_name = Ui.label("", "Heading")
	_note = Ui.label("", "Muted", true)
	_note.custom_minimum_size.x = 620
	for label: Label in [_epithet, _name, _note]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equip = Ui.button("", _equip_current, "PrimaryButton")
	_equip.custom_minimum_size.x = 220
	_dots = Ui.hbox([], 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	var turning := Ui.hbox([Ui.button("‹", _turn.bind(-1)), _dots, Ui.button("›", _turn.bind(1))], 18)
	turning.alignment = BoxContainer.ALIGNMENT_CENTER
	var details := Ui.vbox([turning, _epithet, _name, _note, _centred(_equip)], 6)
	add_child(Ui.vbox([header, _stage, details], 10))
	_arrange(false)


func _centred(node: Control) -> Control:
	var row := Ui.hbox([node])
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	return row


## A card on the wheel: the portrait, covered, with the look's name on a dark band and its frame on top.
func _card(look: Dictionary, index: int) -> Control:
	var card := Control.new()
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(index))
	var back := ColorRect.new()
	back.color = UiTheme.PANEL_2
	var portrait := TextureRect.new()
	var path: String = look.portrait
	portrait.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var band := ColorRect.new()
	band.color = Color(UiTheme.GROUND, 0.82)
	band.anchor_top = 1.0
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -40
	var title := Ui.label(String(look.name), "Subheading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size", 20)
	band.add_child(title)
	var frame := Panel.new()
	frame.name = "Frame"
	for node: Control in [back, portrait, frame]:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for node: Control in [back, portrait, band, frame]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(node)
	if look.id == Settings.character_skin:
		var badge := Ui.panel(Ui.tint(Ui.label("EQUIPPED", "Faint"), UiTheme.TEAL), "Chip")
		badge.position = Vector2(10, 10)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
	return card


## Puts every card in its place on the wheel (gliding there when `animate`) and shows the middle one's details.
func _arrange(animate := true) -> void:
	var count := _looks.size()
	var middle := STAGE * 0.5
	for i in count:
		var offset := wrapi(i - _at, -count / 2, count - count / 2)
		var place: Array = PLACES[mini(absi(offset), PLACES.size() - 1)]
		var size: Vector2 = place[1]
		var centre := middle + Vector2(signf(offset) * float(place[0]), 0.0)
		var card := _cards[i]
		card.z_index = 10 - absi(offset)
		card.mouse_filter = (
			Control.MOUSE_FILTER_STOP if absi(offset) < PLACES.size() - 1 else Control.MOUSE_FILTER_IGNORE
		)
		var shade := float(place[2])
		var tint := Color(shade, shade, shade, 1.0 if shade > 0.0 else 0.0)
		var frame := card.get_node("Frame") as Panel
		var equipped: bool = _looks[i].id == Settings.character_skin
		var border := UiTheme.AMBER if offset == 0 else (UiTheme.TEAL if equipped else UiTheme.LINE)
		frame.add_theme_stylebox_override("panel", UiTheme.box(Color.TRANSPARENT, border, 2 if offset == 0 else 1, 10))
		if animate and not Settings.reduced_motion:
			var tween := card.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "position", centre - size * 0.5, TURN_SECONDS)
			tween.tween_property(card, "size", size, TURN_SECONDS)
			tween.tween_property(card, "modulate", tint, TURN_SECONDS)
		else:
			card.position = centre - size * 0.5
			card.size = size
			card.modulate = tint
	var look := _looks[_at]
	_epithet.text = String(look.epithet).to_upper()
	_name.text = look.name
	_note.text = look.note
	var worn: bool = look.id == Settings.character_skin
	_equip.text = "Equipped" if worn else "Equip " + String(look.name)
	_equip.disabled = worn
	Ui.clear(_dots)
	for i in count:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(22, 4) if i == _at else Vector2(8, 4)
		dot.color = UiTheme.AMBER if i == _at else UiTheme.LINE
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(dot)


func _turn(by: int) -> void:
	_at = wrapi(_at + by, 0, _looks.size())
	_arrange()


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index == _at:
			_equip_current()
		else:
			_at = index
			_arrange()
		accept_event()
	else:
		_on_wheel(event)


func _on_wheel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				_turn(-1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				_turn(1)
				accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_turn(-1)
	elif event.is_action_pressed("ui_right"):
		_turn(1)
	elif event.is_action_pressed("ui_accept"):
		_equip_current()
	elif event.is_action_pressed("ui_cancel"):
		_close()
	else:
		return
	get_viewport().set_input_as_handled()


func _equip_current() -> void:
	var id: String = _looks[_at].id
	if id == Settings.character_skin:
		return
	Settings.character_skin = id
	Game.remember_avatar()
	Settings.save_file()
	skin_selected.emit(id)
	closed.emit()


func _close() -> void:
	closed.emit()
