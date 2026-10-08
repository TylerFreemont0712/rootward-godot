class_name ForgeRoom
extends VBoxContainer
## The forge (ADR-0018, redrawn): its choices first, as doors (melt a card, refactor one, widen a spell or the Program,
## bind a new spell), then the door opened in full. Every choice still ends in the one command the rules judge.

signal wants(command: Dictionary)

## The door to open straight away ("melt", "improve", "widen" or "bind"): the screenshot tool sets it to show a stage.
static var open_door := ""

var session: ShardrunSession
var _stage: VBoxContainer
var _door := ""


static func create(run_session: ShardrunSession) -> ForgeRoom:
	var room := ForgeRoom.new()
	room.session = run_session
	room.add_theme_constant_override("separation", 14)
	room._door = open_door
	room._build()
	return room


func _build() -> void:
	add_child(Ui.label(Text.t("An abandoned forge"), "Heading"))
	add_child(Ui.label(_narration(), "Narration", true))
	_stage = Ui.vbox([], 14)
	add_child(_stage)
	_render()


## The doors, or the door opened in full. Rebuilt whenever the door changes.
func _render() -> void:
	Ui.clear(_stage)
	var options := ShardrunViews.forge_options(session.state, session.catalog)
	if _door == "":
		_stage.add_child(_doors(options))
	else:
		_stage.add_child(Ui.hbox([Ui.button(Text.t("Back"), _open.bind(""))]))
		_stage.add_child(_expanded(_door, options))
	_stage.add_child(Ui.hbox([Ui.button(Text.t("Leave the forge as it is"), _leave)]))


func _narration() -> String:
	var state := session.state
	if state.playstyle == "program":
		return Text.t(
			"Do one thing here: refactor a card, melt a card out of your deck, or widen your Program by a slot."
		)
	var deck := ShardrunRules.is_deck(state)
	var thing := "card" if deck else "shard"
	var text := (
		"Do one thing here: rework a %s (upgrade it, or repair a broken one), widen a spell by one slot, " % thing
	)
	text += "melt a card out of your deck, " if deck else ""
	text += "or bind a new spell to your book."
	# Too long for one literal on a line: the whole sentence is the overlay's key.
	return Text.sentence(text)


func _doors(options: Dictionary) -> Control:
	var doors := Ui.flow([], 14)
	doors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ShardrunRules.is_deck(session.state):
		doors.add_child(_melt_door())
	doors.add_child(_improve_door(options))
	doors.add_child(_widen_door(options))
	if not (options.bind as Dictionary).is_empty():
		doors.add_child(_bind_door(options.bind))
	var anvil := Ui.picture("shardrun/map-forge", Vector2(200, 200), "⚒")
	anvil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.hbox([anvil, doors], 24)


func _melt_door() -> Control:
	var deck: Array = session.state.deck
	var smallest := int(session.catalog.balance.deck.min_cards)
	var can := deck.size() > smallest
	var note := (
		Text.f("Deck: %d → %d cards", [deck.size(), deck.size() - 1])
		if can
		else Text.f("Your deck is already as thin as it can be (%d cards).", [smallest])
	)
	var body := Text.t("Destroy one card from your deck for good. A thinner deck deals its best cards more often.")
	return _door_card("✕", Text.t("Melt a card down"), body, note, UiTheme.FAIL, can, _open.bind("melt"))


func _improve_door(options: Dictionary) -> Control:
	var count := (options.shards as Array).size()
	var can := count > 0
	var note := (
		Text.f("Cards with a better version: %d", [count]) if can else Text.t("No card here has a better version.")
	)
	var body := Text.t("Rewrite a card into its better version: the same card, changed in place.")
	return _door_card("↑", Text.t("Refactor a card"), body, note, UiTheme.TEAL, can, _open.bind("improve"))


func _widen_door(options: Dictionary) -> Control:
	var spells: Array = options.spells
	var can := not spells.is_empty()
	var program: bool = session.state.playstyle == "program"
	var note := Text.t("Every spell is at its widest.")
	if spells.size() == 1:
		var spell := Shardrun.spell_by_id(session.state, spells[0])
		note = Text.f("Slots: %d → %d", [int(spell.capacity), int(spell.capacity) + 1])
	elif spells.size() > 1:
		note = Text.f("%d spells have room for a slot.", [spells.size()])
	var body := (
		Text.t("Give the Program one more slot for shards.")
		if program
		else Text.t("Give a spell one more slot for shards.")
	)
	var heading := Text.t("Widen the Program") if program else Text.t("Widen a spell")
	return _door_card("⊕", heading, body, note, UiTheme.AMBER, can, _open.bind("widen"))


func _bind_door(bind: Dictionary) -> Control:
	var body := Text.t("Add a spell to your book. It starts empty, ready for the shards you carry.")
	var note := Text.f("%d slots", [int(bind.capacity)])
	return _door_card("✦", Text.t("Bind a new spell"), body, note, UiTheme.SHARD, true, _open.bind("bind"))


func _door_card(
	glyph: String, heading: String, body: String, note: String, colour: Color, can: bool, choose: Callable
) -> Control:
	var title := Ui.hbox([Ui.tint(Ui.label(glyph, "Heading"), colour), Ui.label(heading, "Subheading")], 10)
	var open := Ui.button(Text.t("Choose"), choose, "PrimaryButton" if can else "")
	open.disabled = not can
	var column := Ui.vbox([title, Ui.label(body, "Muted", true), Ui.label(note, "Faint", true), open], 10)
	column.custom_minimum_size.x = 300
	var card := Ui.panel(column, "")
	var style := UiTheme.box(UiTheme.PANEL_2, colour, 2, 8, Vector2(16, 14))
	style.border_width_top = 6
	card.add_theme_stylebox_override("panel", style)
	return card


func _expanded(door: String, options: Dictionary) -> Control:
	match door:
		"melt":
			var melt := ForgeMeltView.create(session)
			melt.wants.connect(_forward)
			return _framed(melt, UiTheme.FAIL)
		"improve":
			var improve := ForgeView.create(session)
			improve.wants.connect(_forward)
			return _framed(improve, UiTheme.TEAL)
		"widen":
			return _framed(_widen_stage(options), UiTheme.AMBER)
		_:
			return _framed(_bind_stage(options.bind), UiTheme.SHARD)


## A stage in its door's colour: red for a melt, teal for a refactor, so the mode reads before a card is touched.
func _framed(content: Control, colour: Color) -> Control:
	var frame := Ui.panel(content, "")
	frame.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(colour.darkened(0.84), 0.92), colour, 2, 10, Vector2(18, 16))
	)
	return frame


func _widen_stage(options: Dictionary) -> Control:
	var column := Ui.vbox([], 10)
	var program: bool = session.state.playstyle == "program"
	column.add_child(Ui.label(Text.t("Widen the Program") if program else Text.t("Widen a spell"), "Subheading"))
	for spell_id: String in options.spells:
		var spell := Shardrun.spell_by_id(session.state, spell_id)
		var capacity := int(spell.capacity)
		var slots := Ui.label("◆".repeat(capacity) + "◇", "Subheading")
		var label := Text.f("Widen %s to %d slots", [Text.t(spell.name), capacity + 1])
		var widen := Ui.button(label, _ask({"type": "widen", "spell_id": spell_id}), "PrimaryButton")
		column.add_child(Ui.hbox([Ui.label(Text.t(spell.name), "Heading"), slots, Ui.spacer(), widen], 12))
	return column


func _bind_stage(bind: Dictionary) -> Control:
	var column := Ui.vbox([], 10)
	column.add_child(Ui.label(Text.t("Bind a new spell"), "Subheading"))
	var description := Text.f(
		"An empty spell with %d slots, ready for the spare shards you carry.", [int(bind.capacity)]
	)
	column.add_child(Ui.label(description, "Muted"))
	var bind_it := Text.f("Bind %s", [Text.t(bind.name)])
	column.add_child(Ui.hbox([Ui.button(bind_it, _ask({"type": "bind"}), "PrimaryButton")]))
	return column


func _open(door: String) -> void:
	_door = door
	_render()


func _forward(command: Dictionary) -> void:
	wants.emit(command)


func _leave() -> void:
	wants.emit({"type": "forge", "shard_id": null})


func _ask(command: Dictionary) -> Callable:
	return func() -> void: wants.emit(command)
