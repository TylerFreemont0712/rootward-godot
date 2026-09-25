class_name FoeView
extends VBoxContainer
## One foe on the stage: what it will do next, its sprite at its size, and a card with its HP, shield, weaknesses and
## trait. It shows the numbers it is given (`show_foe`), so the stage can play a volley hit by hit before the new state
## is drawn.

## A foe's sprite, square, by its size in content (in the 1920x1080 design canvas).
const SIZES := {"small": 112.0, "medium": 150.0, "large": 195.0, "huge": 405.0, "colossal": 425.0}
const INTENT_GLYPHS := {"strike": "⚔", "multi": "⚔", "shield": "◈", "stoke": "▲", "heal": "✚"}

var uid := ""
var foe: Dictionary = {}
## The picture moves (recoil, lunge) inside a plain holder, which the box lays out; moving the picture itself would be
## undone the next time the box sorts its children.
var sprite: Control
var _holder: Control
var _intent: Label
var _name: Label
var _bar: ProgressBar
var _hp: Label
var _shield: Label
var _tags: HFlowContainer
var _card: PanelContainer


static func create(foe_state: Dictionary, catalog: Dictionary) -> FoeView:
	var view := FoeView.new()
	view.uid = foe_state.uid
	var content: Dictionary = catalog.foes.get(foe_state.id, {})
	view._build(foe_state, String(content.get("size", "medium")), String(content.get("flavor", "")))
	view.show_foe(foe_state)
	return view


func _build(foe_state: Dictionary, size_name: String, flavor: String) -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent = Ui.label("", "Muted")
	var intent := Ui.panel(_intent, "Chip")
	intent.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(intent)
	var side := float(SIZES.get(size_name, SIZES.medium))
	_holder = Control.new()
	_holder.custom_minimum_size = Vector2(side, side)
	_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite = Ui.picture("foes/" + String(foe_state.sprite), Vector2(side, side), foe_state.name)
	sprite.mouse_filter = Control.MOUSE_FILTER_PASS
	sprite.tooltip_text = flavor
	_holder.add_child(sprite)
	add_child(_holder)
	_name = Ui.label(foe_state.name, "")
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(150, 10)
	_hp = Ui.label("", "Faint")
	_shield = Ui.tint(Ui.label("", "Muted"), UiTheme.TEAL) as Label
	_tags = Ui.flow([], 4)
	var hp_row := Ui.hbox([_bar, _hp], 6)
	_card = Ui.panel(Ui.vbox([Ui.hbox([_name, Ui.spacer(), _shield]), hp_row, _tags], 3), "Card")
	_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.custom_minimum_size.x = 200
	add_child(_card)


## Draws these numbers: HP, shield, intent, weaknesses (which can shift from turn to turn).
func show_foe(foe_state: Dictionary) -> void:
	foe = foe_state
	var alive := int(foe_state.hp) > 0
	_bar.max_value = maxi(1, int(foe_state.max))
	_bar.value = int(foe_state.hp)
	_hp.text = "%d/%d" % [int(foe_state.hp), int(foe_state.max)]
	_shield.text = "◈ %d" % int(foe_state.shield) if int(foe_state.shield) > 0 else ""
	var kind := ShardrunViews.intent_kind(foe_state)
	_intent.text = "%s  %s" % [INTENT_GLYPHS.get(kind, "·"), ShardrunViews.intent_text(foe_state)]
	var danger := kind in ["strike", "multi"]
	_intent.add_theme_color_override("font_color", UiTheme.FAIL.lightened(0.2) if danger else UiTheme.TEXT)
	(_intent.get_parent() as Control).visible = alive
	Ui.clear(_tags)
	for element: String in foe_state.get("weak", []):
		_tags.add_child(_tag("weak: " + element, UiTheme.element(element), "Takes extra damage from %s." % element))
	for element: String in foe_state.get("resist", []):
		_tags.add_child(_tag("resists " + element, UiTheme.MUTED, "Takes less damage from %s." % element))
	var described := ShardrunViews.trait_view(foe_state)
	if not described.is_empty():
		_tags.add_child(_tag(described.name, UiTheme.WARN, described.text))
	if foe_state.has("pattern"):
		var element: String = foe_state.pattern
		_tags.add_child(_tag("now: " + element, UiTheme.element(element), "This turn, %s hits in full." % element))
	if foe_state.get("stoked", false):
		_tags.add_child(_tag("stoked", UiTheme.ELEMENTS.fire, "Its next strike hits twice as hard."))


## Hands its card over to be shown as a guardian's health bar at the top of the arena: wider, with a thicker bar, the
## name larger and centred. The card keeps showing this foe's numbers wherever it is.
func take_card() -> Control:
	remove_child(_card)
	_card.custom_minimum_size.x = 640
	_bar.custom_minimum_size = Vector2(560, 18)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.theme_type_variation = "Heading"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The name alone takes the row's width, so it centres over the bar (the spacer beside it steps aside).
	(_name.get_parent().get_child(1) as Control).visible = false
	_tags.alignment = FlowContainer.ALIGNMENT_CENTER
	var look := UiTheme.box(Color(0.06, 0.04, 0.05, 0.86), UiTheme.FAIL.darkened(0.3), 2, 10, Vector2(18, 10))
	look.shadow_color = Color(UiTheme.FAIL, 0.2)
	look.shadow_size = 10
	_card.add_theme_stylebox_override("panel", look)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _card


func _tag(text: String, colour: Color, tip: String) -> Control:
	var tag := Ui.panel(Ui.sized(Ui.tint(Ui.label(text, ""), colour), 12), "Chip")
	tag.tooltip_text = tip
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	return tag


## The middle of the sprite, where bolts land, in the parent's coordinates.
func target_point() -> Vector2:
	return position + _holder.position + _holder.size * 0.5


## How far below the top of this view the foe's feet are (the bottom of its sprite): the stage stands it there.
func foot_offset() -> float:
	var intent := (get_child(0) as Control).get_combined_minimum_size().y
	return intent + get_theme_constant("separation") + _holder.custom_minimum_size.y


func sprite_width() -> float:
	return _holder.custom_minimum_size.x


## Where the foe stands, under the middle of its sprite: strikes hit the ground here.
func foot_point() -> Vector2:
	return position + _holder.position + Vector2(_holder.size.x * 0.5, _holder.size.y)


func top_point() -> Vector2:
	return position + _holder.position + Vector2(_holder.size.x * 0.5, _holder.size.y * 0.15)


## A white flash and a shake: it was hit.
func recoil(strength := 1.0) -> void:
	sprite.modulate = Color(3.0, 3.0, 3.0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.18)
	var shake := create_tween()
	var x := sprite.position.x
	var push := 6.0 * strength
	shake.tween_property(sprite, "position:x", x + push, 0.04)
	shake.tween_property(sprite, "position:x", x - push * 0.6, 0.05)
	shake.tween_property(sprite, "position:x", x, 0.06)


## It lunges at the Maintainer and back; the blow lands halfway.
func lunge(toward: Vector2, seconds := 0.45) -> void:
	var home := sprite.position
	var reach := (toward - target_point()).normalized() * 70.0
	var tween := create_tween()
	tween.tween_property(sprite, "position", home + reach * 0.3 - Vector2(0, 6), seconds * 0.35)
	tween.tween_property(sprite, "position", home + reach, seconds * 0.15)
	tween.tween_property(sprite, "position", home, seconds * 0.5).set_trans(Tween.TRANS_BACK)


func defeat() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.8)
	tween.tween_property(sprite, "position:y", sprite.position.y + 24, 0.8)
	tween.tween_property(_card, "modulate", Color(1, 1, 1, 0.35), 0.8)


func enter(delay: float) -> void:
	modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate", Color.WHITE, 0.4)


func dim_if_dead() -> void:
	if int(foe.get("hp", 1)) <= 0:
		sprite.modulate = Color(1, 1, 1, 0)
		_card.modulate = Color(1, 1, 1, 0.35)
