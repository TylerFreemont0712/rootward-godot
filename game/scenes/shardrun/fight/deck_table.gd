class_name DeckTable
extends VBoxContainer
## The Shardrun's table in a fight (the deck playstyle): the spells as rows of card slots, and under them the draw
## pile, the hand, the hold and the discard pile. A click plays a hand card into the targeted spell (or takes a played
## card back), a right click holds it for the next turn, and any card can be dragged to any place. Every move becomes a
## `compose` command for the rules (CardTable); nothing here decides whether it is allowed.

signal wants(command: Dictionary)
## A spell was clicked: its cards are the ones a click plays into, and its code is the one to read.
signal targeted(spell_id: String)

const DEAL_STAGGER := 0.06

var session: ShardrunSession
## SpellCards by spell id, shared with FightView (which shows their previews and wires Cast).
var cards: Dictionary = {}
var target := ""
var busy := false
var _table: Dictionary = {}
var _turn := -1
var _spell_row: HBoxContainer
var _slots: Dictionary = {}
var _hand: HBoxContainer
var _hold: HBoxContainer
var _draw_count: Label
var _discard_count: Label
var _hint: Label


static func create(run_session: ShardrunSession) -> DeckTable:
	var table := DeckTable.new()
	table.session = run_session
	table._build()
	return table


func _build() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spell_row = Ui.hbox([], 10)
	for index in (session.state.spells as Array).size():
		var spell: Dictionary = session.state.spells[index]
		var card := SpellCard.create(index + 1, spell, session.catalog)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.gui_input.connect(_on_spell_input.bind(spell.id))
		var slots := Ui.hbox([], 6)
		card.set_slots(slots)
		_slots[spell.id] = slots
		cards[spell.id] = card
		_spell_row.add_child(card)
	add_child(_spell_row)
	_draw_count = Ui.label("", "Faint")
	_discard_count = Ui.label("", "Faint")
	_hand = Ui.hbox([], 8)
	_hand.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hold = Ui.hbox([], 6)
	var hand_zone := _DropZone.new()
	hand_zone.dropped = func(from: Dictionary) -> void:
		_move(from, {"zone": "hand", "index": (_table.hand as Array).size()})
	hand_zone.add_child(_hand)
	hand_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_zone.custom_minimum_size.y = CardFace.SIZES[CardFace.Size.HAND].y + 10
	var draw := _pile("Draw", _draw_count)
	var discard := _pile("Discard", _discard_count)
	var hold := Ui.vbox([Ui.label("HOLD", "Faint"), _hold], 4)
	add_child(Ui.hbox([draw, hand_zone, hold, discard], 12))
	_hint = Ui.label("", "Faint")
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	add_child(_hint)


func _pile(title: String, count: Label) -> Control:
	var back := PanelContainer.new()
	back.custom_minimum_size = Vector2(80, 108)
	back.add_theme_stylebox_override(
		"panel", UiTheme.box(Color("#2c1f3a"), UiTheme.SHARD.darkened(0.3), 2, 10, Vector2(6, 6))
	)
	var emblem := Ui.picture("brand/shardrun", Vector2(48, 48), "◆")
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_child(emblem)
	var column := Ui.vbox([Ui.label(title.to_upper(), "Faint"), back, count], 4)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return column


## Draws the table from a state: the spells' cards, the hand (dealt in when the turn is new), the hold and the piles.
func show_table(state: Dictionary) -> void:
	var battle: Dictionary = state.get("battle", {})
	if battle.is_empty():
		return
	_table = CardTable.of(state, session.catalog)
	target = CardTable.target(_table, target)
	var summaries := session.show_summaries()
	for spell: Dictionary in _table.spells:
		var row: HBoxContainer = _slots.get(spell.id)
		if row == null:
			continue
		Ui.clear(row)
		for index in int(spell.capacity):
			var at := {"zone": "spell", "spell": spell.id, "index": index}
			if index < (spell.shards as Array).size():
				row.add_child(_card(spell.shards[index], at, CardFace.Size.SLOT, summaries))
			else:
				var empty := CardFace.slot(at, "spent" if spell.spent else "slot %d" % (index + 1), CardFace.Size.SLOT)
				empty.moved = _move
				row.add_child(empty)
		(cards[spell.id] as SpellCard).set_targeted(spell.id == target)
	var deal := int(battle.turn) != _turn
	_turn = int(battle.turn)
	Ui.clear(_hand)
	var hand: Array = _table.hand
	for index in hand.size():
		var holder := Control.new()
		holder.custom_minimum_size = CardFace.SIZES[CardFace.Size.HAND]
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := _card(hand[index], {"zone": "hand", "index": index}, CardFace.Size.HAND, summaries)
		holder.add_child(face)
		face.mouse_entered.connect(_lift.bind(face, -14.0))
		face.mouse_exited.connect(_lift.bind(face, 0.0))
		_hand.add_child(holder)
		if deal:
			_deal(face, index)
	Ui.clear(_hold)
	for index in int(_table.hold_limit):
		var at := {"zone": "hold", "index": index}
		if index < (_table.held as Array).size():
			_hold.add_child(_card(_table.held[index], at, CardFace.Size.SLOT, summaries))
		else:
			var free := CardFace.slot(at, "hold a card", CardFace.Size.SLOT)
			free.moved = _move
			_hold.add_child(free)
	_draw_count.text = "%d cards" % (battle.draw as Array).size()
	_discard_count.text = "%d cards" % (battle.discard as Array).size()
	_hint.text = _hint_text()


func _card(id: String, at: Dictionary, size_kind: CardFace.Size, summaries: bool) -> CardFace:
	var face := CardFace.create(id, session.catalog, session.state.language, summaries, size_kind, at)
	face.moved = _move
	face.pressed = _press
	return face


func _hint_text() -> String:
	if (_table.hand as Array).is_empty():
		return "Your hand is empty. Cast what you built, or end the turn to draw a new hand."
	var spell := _spell(target)
	if spell.is_empty():
		return "Both spells are full or spent: cast them, or end the turn. Right-click a card to hold it for next turn."
	return (
		(
			"Click a card to play it into %s, or drag it to a slot; cards run left to right. Right-click to hold one. "
			% spell.name
		)
		+ "A blank spell still casts one plain bolt."
	)


func _spell(id: String) -> Dictionary:
	for spell: Dictionary in _table.get("spells", []):
		if spell.id == id:
			return spell
	return {}


## A new hand is dealt: each card rises from below with a turn, one after another.
func _deal(face: CardFace, index: int) -> void:
	face.position = Vector2(-60, 120)
	face.rotation_degrees = -10.0
	face.modulate = Color(1, 1, 1, 0)
	face.pivot_offset = CardFace.SIZES[CardFace.Size.HAND] * 0.5
	var tween := face.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var delay := index * DEAL_STAGGER
	tween.tween_property(face, "position", Vector2.ZERO, 0.34).set_delay(delay)
	tween.tween_property(face, "rotation_degrees", 0.0, 0.34).set_delay(delay)
	tween.tween_property(face, "modulate", Color.WHITE, 0.18).set_delay(delay)
	if index == 0:
		Sound.play("sfx-card", 0.5)


func _lift(face: CardFace, height: float) -> void:
	if not is_instance_valid(face):
		return
	var tween := face.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(face, "position:y", height, 0.12)


func _press(at: Dictionary, button: int) -> void:
	if busy:
		return
	var next: Dictionary
	if button == MOUSE_BUTTON_RIGHT:
		next = CardTable.toggle_hold(_table, at)
	else:
		next = CardTable.tap(_table, at, target)
	_propose(next, at)


func _move(from: Dictionary, to: Dictionary) -> void:
	if busy:
		return
	_propose(CardTable.move(_table, from, to), to)


func _propose(next: Dictionary, at: Dictionary) -> void:
	if next.is_empty():
		return
	Sound.play("sfx-card", 0.55, randf_range(0.95, 1.08))
	if at.get("zone", "") == "spell":
		targeted.emit(String(at.spell))
	wants.emit(CardTable.command(next))


func _on_spell_input(event: InputEvent, spell_id: String) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		target = spell_id
		for id: String in cards:
			(cards[id] as SpellCard).set_targeted(id == spell_id and not _spell(id).get("spent", false))
		targeted.emit(spell_id)
		_hint.text = _hint_text()


func set_busy(value: bool) -> void:
	busy = value


## Anything dropped here that is a card goes to the end of the hand.
class _DropZone:
	extends PanelContainer

	var dropped: Callable

	func _init() -> void:
		add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.18), Color(0, 0, 0, 0), 0, 12, Vector2(8, 6)))

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("card_spot")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		dropped.call((data as Dictionary).card_spot)
