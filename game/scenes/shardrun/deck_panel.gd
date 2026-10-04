class_name DeckPanel
extends VBoxContainer
## A Shardrun's deck as cards, one of each kind with how many the deck holds, and the code of any card on hover. In a
## fight it also lists the draw pile (sorted, so its order stays hidden), the discard pile and what is held.


static func create(session: ShardrunSession, in_fight := false) -> DeckPanel:
	var panel := DeckPanel.new()
	panel._build(session, in_fight)
	return panel


func _build(session: ShardrunSession, in_fight: bool) -> void:
	add_theme_constant_override("separation", 12)
	var state := session.state
	var deck: Array = state.get("deck", [])
	var spells := ("、" if Text.japanese() else ", ").join(
		PackedStringArray(
			(state.spells as Array).map(
				func(s: Dictionary) -> String: return Text.f("%s (%d slots)", [Text.t(s.name), int(s.capacity)])
			)
		)
	)
	var hand := ShardrunRules.hand_size(state, session.catalog)
	add_child(Ui.label(Text.f("YOUR DECK · %d CARDS", [deck.size()]), "Faint"))
	var text := RoomPanel.run_on(
		[
			Text.f("Every fight shuffles the deck and deals %d cards a turn.", [hand]),
			Text.f("Play them into %s; the order you play them in is the order they run.", [spells]),
			Text.t("Hover a card to read its code.")
		]
	)
	add_child(Ui.label(text, "Muted", true))
	add_child(_grid(deck, session))
	var battle: Dictionary = state.get("battle", {})
	if not in_fight or battle.is_empty():
		return
	var piles := [
		[Text.t("DRAW PILE (sorted)"), battle.draw],
		[Text.t("DISCARD PILE"), battle.discard],
		[Text.t("HELD"), battle.held]
	]
	for part: Array in piles:
		var cards: Array = part[1]
		add_child(Ui.label("%s · %d" % [part[0], cards.size()], "Faint"))
		if not cards.is_empty():
			add_child(_grid(cards, session))


static func _grid(ids: Array, session: ShardrunSession) -> Control:
	var counts := {}
	for id: String in ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var order: Array = counts.keys()
	order.sort_custom(
		func(a: String, b: String) -> bool:
			var ra := ["common", "uncommon", "rare", "legendary"].find(
				session.catalog.shards.get(a, {}).get("rarity", "")
			)
			var rb := ["common", "uncommon", "rare", "legendary"].find(
				session.catalog.shards.get(b, {}).get("rarity", "")
			)
			return ra < rb if ra != rb else a < b
	)
	var flow := Ui.flow([], 10)
	for id: String in order:
		var face := CardFace.create(
			id, session.catalog, session.state.language, session.show_summaries(), CardFace.Size.DECK
		)
		var count := int(counts[id])
		var badge := Ui.panel(Ui.tint(Ui.label("×%d" % count, "Subheading"), UiTheme.SHARD), "Chip")
		badge.visible = count > 1
		flow.add_child(Ui.vbox([face, badge], 2))
	return flow
