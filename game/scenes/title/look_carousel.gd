class_name LookCarousel
extends VBoxContainer
## A wheel of cosmetic options for one loadout slot (ADR-0037), turned like the skin wheel: the option being browsed
## stands large in the middle and plays its preview live (a circle writing itself, a bolt flying, an impact landing,
## the move's pose), its neighbours smaller and dimmer. Previous/Next, the mouse wheel or a click on a side card turn
## it; turning only browses (`browsed`); the room's own button wears the option.

signal browsed(id: String)

## [distance from the middle, card size, brightness] for each place on the wheel.
const PLACES: Array[Array] = [
	[0.0, Vector2(186, 214), 1.0],
	[146.0, Vector2(120, 146), 0.5],
	[236.0, Vector2(86, 106), 0.24],
	[310.0, Vector2(70, 86), 0.0],
]
const WHEEL := Vector2(520, 224)
const TURN_SECONDS := 0.28

var slot := ""
var options: Array[Dictionary] = []
var at := 0
var worn := ""
var _wheel: Control
var _cards: Array[Control] = []
var _arts: Array[LookArt] = []
var _dots: HBoxContainer


static func make(for_slot: String, browsed_id: String, worn_id: String, unplayable: Array = []) -> LookCarousel:
	var carousel := LookCarousel.new()
	carousel.slot = for_slot
	carousel.worn = worn_id
	carousel.options = Cosmetics.options(for_slot)
	for i in carousel.options.size():
		if carousel.options[i].id == browsed_id:
			carousel.at = i
	carousel._build(unplayable)
	return carousel


func _build(unplayable: Array) -> void:
	add_theme_constant_override("separation", 8)
	_wheel = Control.new()
	_wheel.custom_minimum_size = WHEEL
	_wheel.clip_contents = true
	_wheel.gui_input.connect(_on_wheel)
	add_child(_wheel)
	for i in options.size():
		var card := _card(options[i], i, String(options[i].id) in unplayable)
		_cards.append(card)
		_wheel.add_child(card)
	_dots = Ui.hbox([], 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(
		Ui.hbox(
			[
				FoundryUi.button(FoundryUi.text("Previous", "前へ"), turn.bind(-1)),
				Ui.expand(_dots),
				FoundryUi.button(FoundryUi.text("Next", "次へ"), turn.bind(1))
			],
			8
		)
	)
	arrange(false)


func current() -> Dictionary:
	return options[at] if not options.is_empty() else {}


func _card(option: Dictionary, index: int, unplayable: bool) -> Control:
	var card := Control.new()
	card.clip_contents = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(index))
	var back := ColorRect.new()
	back.color = Color(0.03, 0.05, 0.06, 0.92)
	var art := LookArt.make(slot, option)
	var band := ColorRect.new()
	band.color = Color(UiTheme.GROUND, 0.84)
	band.anchor_top = 1.0
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -34
	var title := Ui.sized(Ui.label(Cosmetics.text(String(option.name)), "Subheading"), 15)
	(title as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(title as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(title as Label).clip_text = true
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band.add_child(title)
	var frame := Panel.new()
	frame.name = "Frame"
	for node: Control in [back, art, frame]:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for node: Control in [back, art, band, frame]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(node)
	if unplayable:
		var note := Ui.panel(
			Ui.tint(Ui.sized(Ui.label(FoundryUi.text("3D SKINS", "3Dのみ"), "Faint"), 11), UiTheme.MUTED), "Chip"
		)
		note.position = Vector2(8, 8)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(note)
	_arts.append(art)
	return card


## Puts every card in its place (gliding there when `animate`); only the middle one plays its preview.
func arrange(animate := true) -> void:
	var count := options.size()
	var middle := WHEEL * 0.5
	for i in count:
		var offset := wrapi(i - at, -count / 2, count - count / 2)
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
		var border := UiTheme.AMBER if offset == 0 else (UiTheme.TEAL if options[i].id == worn else UiTheme.LINE)
		(card.get_node("Frame") as Panel).add_theme_stylebox_override(
			"panel", UiTheme.box(Color.TRANSPARENT, border, 2 if offset == 0 else 1, 10)
		)
		_arts[i].set_live(offset == 0)
		if animate and not Settings.reduced_motion:
			var tween := card.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "position", centre - size * 0.5, TURN_SECONDS)
			tween.tween_property(card, "size", size, TURN_SECONDS)
			tween.tween_property(card, "modulate", tint, TURN_SECONDS)
		else:
			card.position = centre - size * 0.5
			card.size = size
			card.modulate = tint
	Ui.clear(_dots)
	for i in count:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(22, 4) if i == at else Vector2(8, 4)
		dot.color = UiTheme.AMBER if i == at else (UiTheme.TEAL if options[i].id == worn else UiTheme.LINE)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(dot)


func turn(by: int) -> void:
	if options.is_empty():
		return
	at = wrapi(at + by, 0, options.size())
	arrange()
	browsed.emit(String(options[at].id))


func set_worn(id: String) -> void:
	worn = id
	arrange(false)


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index != at:
			turn(wrapi(index - at, -options.size() / 2, options.size() - options.size() / 2))
		else:
			browsed.emit(String(options[at].id))
		accept_event()
	else:
		_on_wheel(event)


func _on_wheel(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				turn(-1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				turn(1)
				accept_event()
