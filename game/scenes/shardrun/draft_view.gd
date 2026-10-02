class_name DraftView
extends VBoxContainer
## A program run's draft (ADR-0012): first the paradigms on offer, each with its speed class and signature cards, then
## one pack at a time, each card with its real code. The deck so far is on the right. Every choice is a command; the
## rules check it (ProgramDraft).

signal wants(command: Dictionary)

var session: ShardrunSession


static func create(run_session: ShardrunSession) -> DraftView:
	var view := DraftView.new()
	view.session = run_session
	view._build()
	return view


func _build() -> void:
	add_theme_constant_override("separation", 12)
	var state := session.state
	var draft: Dictionary = state.draft
	var choosing := String(state.get("paradigm", "")) == ""
	var main := Ui.vbox([], 12)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 3.0
	if choosing:
		main.add_child(Ui.label("Choose how your program thinks", "Heading"))
		var line := "A paradigm is a way of solving problems. Its cards are real algorithms; "
		main.add_child(Ui.label(line + "its speed decides who acts first.", "Muted", true))
		var row := Ui.hbox([], 12)
		for id: String in draft.offers:
			row.add_child(_paradigm(ProgramDraft.paradigm_of(session.catalog, id)))
		main.add_child(row)
	else:
		var paradigm := ProgramDraft.paradigm_of(session.catalog, state.paradigm)
		var heading := "Pack %d of %d" % [int(draft.round) + 1, int(draft.rounds)]
		(
			main
			. add_child(
				(
					Ui
					. hbox(
						[
							Ui.label(heading, "Heading"),
							Ui.spacer(),
							Ui.tint(Ui.label(String(paradigm.name).to_upper(), "Subheading"), Color(paradigm.colour)),
						]
					)
				)
			)
		)
		main.add_child(
			Ui.label(
				"Take one card. Its code is what it does; the order you play cards in is the program.", "Muted", true
			)
		)
		var row := Ui.hbox([], 12)
		for card_id: String in draft.pack:
			row.add_child(_pick(card_id))
		main.add_child(row)
	var deck := Ui.panel(Ui.scroll(DeckPanel.create(session)), "")
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.size_flags_stretch_ratio = 1.4
	var body := Ui.hbox([Ui.panel(Ui.scroll(main), ""), deck], 12)
	(body.get_child(0) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(body.get_child(0) as Control).size_flags_stretch_ratio = 3.0
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)


## A paradigm on offer: its name in its colour, its speed class large, what it is, and its signature cards.
func _paradigm(paradigm: Dictionary) -> Control:
	var colour := Color(paradigm.colour)
	var name := Ui.tint(Ui.sized(Ui.label(String(paradigm.name).to_upper(), "Heading"), 32), colour)
	var tier := Ui.tint(Ui.sized(Ui.label(paradigm.tier, ""), 47), colour.lightened(0.2))
	(tier as Label).add_theme_font_override("font", UiTheme.crt_font())
	var summary := Ui.sized(Ui.label(paradigm.summary, "Muted", true), 14)
	var cards := Ui.hbox([], 8)
	for card_id: String in paradigm.signature:
		var face := CardFace.create(
			card_id, session.catalog, session.state.language, session.show_summaries(), CardFace.Size.DECK
		)
		face.draggable = false
		cards.add_child(face)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	var choose := Ui.button(
		"Choose %s" % paradigm.name,
		func() -> void: wants.emit({"type": "pick-paradigm", "paradigm_id": paradigm.id}),
		"PrimaryButton"
	)
	var column := Ui.vbox([name, tier, summary, Ui.label("SIGNATURE CARDS", "Faint"), cards, Ui.spacer(), choose], 10)
	column.custom_minimum_size.y = 470
	var tile := Ui.panel(column, "Card")
	var look := UiTheme.box(Color("#15101c").lerp(colour, 0.05), colour.darkened(0.3), 2, 12, Vector2(16, 14))
	look.shadow_color = Color(colour, 0.2)
	look.shadow_size = 8
	tile.add_theme_stylebox_override("panel", look)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


## A card in the pack: the card, its code, and Take.
func _pick(card_id: String) -> Control:
	var card: Dictionary = session.catalog.shards.get(card_id, {})
	var take := Ui.button(
		"Take %s" % card.get("name", card_id),
		func() -> void: wants.emit({"type": "draft-card", "card_id": card_id}),
		"PrimaryButton"
	)
	var face := Cards.shard(card, session.state.language, session.show_summaries(), 0, take)
	face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return face
