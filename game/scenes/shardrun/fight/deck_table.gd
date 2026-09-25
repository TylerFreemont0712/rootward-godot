class_name DeckTable
extends VBoxContainer
## The Shardrun's table in a fight (the deck playstyle): the spells as rows of card slots, and under them the draw
## pile, the hand, the hold and the discard pile. A click plays a hand card into the targeted spell (or takes a played
## card back), a right click holds it for the next turn, and any card can be dragged to any place. Every move becomes a
## `compose` command for the rules (CardTable); nothing here decides whether it is allowed.

signal wants(command: Dictionary)
## A spell was clicked: its cards are the ones a click plays into, and its code is the one to read.
signal targeted(spell_id: String)

var session: ShardrunSession
## SpellCards by spell id, shared with FightView (which shows their previews and wires Cast).
var cards: Dictionary = {}
var target := ""
var busy := false
var _table: Dictionary = {}
var _turn := -1
var _spell_row: HBoxContainer
var _slots: Dictionary = {}
var _hand: HandView
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
		if (session.state.spells as Array).size() == 1:
			# One spell (a program run's Program): its cards on the left, what it will do and its run button beside them.
			card.side_by_side()
		if session.state.get("playstyle") == "program":
			card.run_label = "▶  python program.py" if session.state.language == "python" else "▶  node program.js"
		card.gui_input.connect(_on_spell_input.bind(spell.id))
		var slots := Ui.hbox([], 6)
		card.set_slots(slots)
		_slots[spell.id] = slots
		cards[spell.id] = card
		_spell_row.add_child(card)
	add_child(_spell_row)
	_hint = Ui.label("", "Faint")
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	add_child(_hint)
	_draw_count = Ui.label("", "Faint")
	_discard_count = Ui.label("", "Faint")
	_hand = HandView.new()
	_hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand.dropped = func(from: Dictionary) -> void:
		_move(from, {"zone": "hand", "index": (_table.hand as Array).size()})
	_hold = Ui.hbox([], 6)
	var draw := _pile("Draw", _draw_count)
	var discard := _pile("Discard", _discard_count)
	var hold := Ui.vbox([Ui.label("HOLD", "Faint"), _hold], 4)
	hold.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(Ui.hbox([draw, _hand, hold, discard], 12))


func _pile(title: String, count: Label) -> Control:
	var back := Button.new()
	back.custom_minimum_size = Vector2(84, 116)
	back.add_theme_stylebox_override(
		"normal", UiTheme.box(Color("#2c1f3a"), UiTheme.SHARD.darkened(0.3), 2, 10, Vector2(6, 6))
	)
	back.add_theme_stylebox_override("hover", UiTheme.box(Color("#46315e"), UiTheme.SHARD, 2, 10, Vector2(6, 6)))
	back.tooltip_text = "Open %s pile" % title.to_lower()
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back.pressed.connect(_open_pile.bind(title.to_lower()))
	# The pile is a card lying face down: the painted card back, or the emblem when there is none.
	var art := Art.texture("cards/back")
	var face := Ui.picture(
		"cards/back" if art != null else "brand/shardrun", Vector2(84, 116) if art != null else Vector2(48, 48), "◆"
	)
	face.position = Vector2.ZERO if art != null else Vector2(18, 20)
	face.size = Vector2(84, 116) if art != null else Vector2(48, 48)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(face)
	if art != null:
		back.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		back.add_theme_stylebox_override("hover", UiTheme.box(Color(1, 1, 1, 0.08), UiTheme.SHARD, 2, 10))
	var column := Ui.vbox([Ui.label(title.to_upper(), "Faint"), back, count], 4)
	column.size_flags_vertical = Control.SIZE_SHRINK_END
	return column


func _open_pile(which: String) -> void:
	var battle: Dictionary = session.state.get("battle", {})
	if battle.is_empty():
		return
	var cards_in_pile: Array = (battle.get(which, []) as Array).duplicate()
	var popup := PopupPanel.new()
	popup.title = "%s pile" % which.capitalize()
	popup.popup_hide.connect(popup.queue_free)
	add_child(popup)
	var heading := Ui.label("%s pile · %d cards" % [which.capitalize(), cards_in_pile.size()], "Heading")
	var note := Ui.label(
		(
			"Card types shown; draw order stays hidden."
			if which == "draw"
			else "Played and spent cards return here until the next shuffle."
		),
		"Muted",
		true
	)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	if which == "draw":
		cards_in_pile.sort()
	for id: String in cards_in_pile:
		var face := CardFace.create(
			id, session.catalog, session.state.language, session.show_summaries(), CardFace.Size.DECK
		)
		face.draggable = false
		grid.add_child(face)
	if cards_in_pile.is_empty():
		grid.add_child(Ui.label("This pile is empty.", "Muted"))
	var scroll := Ui.scroll(grid)
	scroll.custom_minimum_size = Vector2(760, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close := Ui.button("Close", popup.hide)
	var body := Ui.vbox([heading, note, scroll, close], 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := Ui.panel(body, "Overlay")
	popup.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.popup_centered(Vector2i(830, 510))


## Draws the table from a state: the spells' cards, the hand (dealt in when the turn is new), the hold and the piles.
func show_table(state: Dictionary) -> void:
	var battle: Dictionary = state.get("battle", {})
	if battle.is_empty():
		return
	var before := _table
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
				var face := _card(spell.shards[index], at, CardFace.Size.SLOT, summaries)
				row.add_child(face)
				if _changed(before, at, spell.shards[index]):
					_settle(face)
			else:
				var empty := CardFace.slot(at, "spent" if spell.spent else "slot %d" % (index + 1), CardFace.Size.SLOT)
				empty.moved = _move
				row.add_child(empty)
		(cards[spell.id] as SpellCard).set_targeted(spell.id == target)
	var deal := int(battle.turn) != _turn
	_turn = int(battle.turn)
	var faces: Array[CardFace] = []
	var hand: Array = _table.hand
	for index in hand.size():
		faces.append(_card(hand[index], {"zone": "hand", "index": index}, CardFace.Size.HAND, summaries))
	_hand.hold(faces, deal)
	Ui.clear(_hold)
	for index in int(_table.hold_limit):
		var at := {"zone": "hold", "index": index}
		if index < (_table.held as Array).size():
			var face := _card(_table.held[index], at, CardFace.Size.SLOT, summaries)
			_hold.add_child(face)
			if _changed(before, at, _table.held[index]):
				_settle(face)
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
	if spell.is_empty() and session.state.get("playstyle") == "program":
		return "Your Program is full: run it, or end the turn. Right-click a card to hold it for next turn."
	if spell.is_empty():
		return "Your spell is full or spent: cast it, or end the turn. Right-click a card to hold it for next turn."
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


## Newly played or reordered cards snap into the table with a short, readable landing beat.
func _settle(face: CardFace) -> void:
	face.pivot_offset = face.custom_minimum_size * 0.5
	face.position.y = -22.0
	face.scale = Vector2.ONE * 1.08
	face.modulate = Color(1, 1, 1, 0.65)
	var tween := face.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(face, "position:y", 0.0, 0.28)
	tween.tween_property(face, "scale", Vector2.ONE, 0.28)
	tween.tween_property(face, "modulate", Color.WHITE, 0.22)


func _changed(before: Dictionary, at: Dictionary, id: String) -> bool:
	if before.is_empty():
		return false
	var list: Array = []
	match String(at.zone):
		"hand":
			list = before.hand
		"hold":
			list = before.held
		"spell":
			for spell: Dictionary in before.spells:
				if spell.id == at.spell:
					list = spell.shards
					break
	return int(at.index) >= list.size() or list[int(at.index)] != id


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
