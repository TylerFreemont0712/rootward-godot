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
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 3.0
	if choosing:
		main.add_child(Ui.label(Text.t("Choose how your program thinks"), "Heading"))
		main.add_child(Ui.label(Text.t("Hover a paradigm name for its description."), "Muted", true))
		var row := Ui.hbox([], 12)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for id: String in draft.offers:
			row.add_child(_paradigm(ProgramDraft.paradigm_of(session.catalog, id)))
		main.add_child(row)
	elif not (draft.get("focus_offers", []) as Array).is_empty():
		var paradigm := ProgramDraft.paradigm_of(session.catalog, state.paradigm)
		main.add_child(Ui.label(Text.t("Choose your focus"), "Heading"))
		main.add_child(
			Ui.label(
				Text.t("Your focus adds a rule and a signature card. All three are yours to choose from."),
				"Muted",
				true
			)
		)
		var row := Ui.hbox([], 12)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for id: String in draft.focus_offers:
			row.add_child(_focus(paradigm, ProgramDraft.focus_of(session.catalog, paradigm.id, id)))
		main.add_child(row)
	else:
		var paradigm := ProgramDraft.paradigm_of(session.catalog, state.paradigm)
		var heading := Text.f("Pack %d of %d", [int(draft.round) + 1, int(draft.rounds)])
		(
			main
			. add_child(
				(
					Ui
					. hbox(
						[
							Ui.label(heading, "Heading"),
							Ui.spacer(),
							Ui.tint(
								Ui.label(Text.t(String(paradigm.name)).to_upper(), "Subheading"), Color(paradigm.colour)
							),
						]
					)
				)
			)
		)
		main.add_child(
			Ui.label(
				Text.t("Take one card. Its code is what it does; the order you play cards in is the program."),
				"Muted",
				true
			)
		)
		var row := Ui.hbox([], 12)
		for card_id: String in draft.pack:
			row.add_child(_pick(card_id))
		main.add_child(row)
	var deck_scroll := Ui.scroll(DeckPanel.create(session))
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var deck := Ui.panel(deck_scroll, "")
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.size_flags_stretch_ratio = 1.4
	deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var main_scroll := Ui.scroll(main)
	main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var main_panel := Ui.panel(main_scroll, "")
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_stretch_ratio = 3.0
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := Ui.hbox([main_panel, deck], 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)


## A paradigm on offer: its name in its colour, its speed class large, what it is, and its signature cards.
func _paradigm(paradigm: Dictionary) -> Control:
	var colour := Color(paradigm.colour)
	var name := Ui.tint(Ui.sized(Ui.label(Text.t(String(paradigm.name)).to_upper(), "Heading"), 29), colour)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	HoverInfo.attach(name, Text.t(String(paradigm.name)), Text.t(String(paradigm.summary)), "", colour)
	var tier := Ui.tint(Ui.sized(Ui.label(paradigm.tier, ""), 42), colour.lightened(0.2))
	(tier as Label).add_theme_font_override("font", UiTheme.crt_font())
	var law: Dictionary = session.catalog.relics.get(String(paradigm.get("law", "")), {})
	var cards := Ui.hbox([], 8)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	for card_id: String in paradigm.signature:
		var face := CardFace.create(
			card_id, session.catalog, session.state.language, session.show_summaries(), CardFace.Size.DRAFT
		)
		face.draggable = false
		cards.add_child(face)
	var choose := Ui.button(
		Text.f("Choose %s", [Text.t(paradigm.name)]),
		func() -> void: wants.emit({"type": "pick-paradigm", "paradigm_id": paradigm.id}),
		"PrimaryButton"
	)
	var contents: Array[Control] = [name, tier, _relic_slot(law, Vector2(54, 54), 142)]
	var push_button := Ui.spacer()
	push_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.append_array([Ui.label(Text.t("SIGNATURE CARDS"), "Faint"), cards, push_button, choose])
	var column := Ui.vbox(contents, 10)
	column.custom_minimum_size.y = 570
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tile := Ui.panel(column, "Card")
	var look := UiTheme.box(Color("#15101c").lerp(colour, 0.05), colour.darkened(0.3), 2, 12, Vector2(16, 14))
	look.shadow_color = Color(colour, 0.2)
	look.shadow_size = 8
	tile.add_theme_stylebox_override("panel", look)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tile


## A card in the pack: the card, its code, and Take.
func _pick(card_id: String) -> Control:
	var card: Dictionary = session.catalog.shards.get(card_id, {})
	var take := Ui.button(
		Text.f("Take %s", [Text.t(card.get("name", card_id))]),
		func() -> void: wants.emit({"type": "draft-card", "card_id": card_id}),
		"PrimaryButton"
	)
	var face := Cards.shard(card, session.state.language, session.show_summaries(), 0, take)
	face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return face


## A focus shows its associated relic before its signature card and rule.
func _focus(paradigm: Dictionary, focus: Dictionary) -> Control:
	var colour := Color(paradigm.colour)
	var relic: Dictionary = session.catalog.relics.get(String(focus.get("relic", "")), {})
	var name := Ui.tint(Ui.sized(Ui.label(Text.t(focus.name), "Heading"), 29), colour)
	var tag := Ui.tint(Ui.label(focus.tag, "Subheading"), colour.lightened(0.2))
	tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var face := CardFace.create(
		focus.signature, session.catalog, session.state.language, session.show_summaries(), CardFace.Size.HAND
	)
	face.draggable = false
	var face_stage := CenterContainer.new()
	face_stage.custom_minimum_size.y = CardFace.SIZES[CardFace.Size.HAND].y + 16.0
	face_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	face_stage.add_child(face)
	var choose := Ui.button(
		Text.f("Choose %s", [Text.t(focus.name)]),
		func() -> void: wants.emit({"type": "pick-focus", "focus_id": focus.id}),
		"PrimaryButton"
	)
	var items: Array[Control] = [
		name,
		tag,
		Ui.label(Text.t(focus.rule), "Muted", true),
		_relic_slot(relic, Vector2(54, 54), 142),
		face_stage,
		Ui.label(Text.t(focus.plays_like), "Muted", true),
		Ui.spacer(),
		choose
	]
	var column := Ui.vbox(items, 10)
	column.custom_minimum_size.y = 650
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tile := Ui.panel(column, "Card")
	tile.add_theme_stylebox_override(
		"panel", UiTheme.box(Color("#15101c").lerp(colour, 0.05), colour.darkened(0.3), 2, 12, Vector2(16, 14))
	)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tile


## Keeps each paradigm and focus relic in the same visual slot even when its rule text wraps differently.
func _relic_slot(relic: Dictionary, icon_size: Vector2, height: float) -> Control:
	var slot := CenterContainer.new()
	slot.custom_minimum_size.y = height
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not relic.is_empty():
		var face := Cards.relic(relic, null, icon_size)
		face.custom_minimum_size.x = 300
		slot.add_child(face)
	return slot
