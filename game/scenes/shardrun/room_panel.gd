class_name RoomPanel
extends VBoxContainer
## The rooms that are not fights: what a won fight or a cache leaves (shards, relics, a guardian's spell), a rest,
## and a forge. Each choice is one command; the rules say what it does.

signal wants(command: Dictionary)

var session: ShardrunSession


static func create(run_session: ShardrunSession) -> RoomPanel:
	var panel := RoomPanel.new()
	panel.session = run_session
	panel.add_theme_constant_override("separation", 12)
	match run_session.state.status:
		"reward":
			panel._reward()
		"rest":
			panel._rest()
		"forge":
			panel._forge()
	return panel


func _ask(command: Dictionary) -> Callable:
	return func() -> void: wants.emit(command)


func _reward() -> void:
	var state := session.state
	var catalog := session.catalog
	var reward: Dictionary = state.get("reward", {})
	var title := "An opened cache"
	if reward.has("shards"):
		title = "Shards in the rubble"
	elif reward.has("chest"):
		title = "A sealed cache"
	elif reward.has("cursed_relic"):
		title = "A curse has bound itself"
	add_child(Ui.label(title, "Heading"))
	if reward.has("chest"):
		var chance := roundi(float(reward.chest.curse_chance) * 100.0)
		var warning := (
			"Curse chance: %d%%. Opening may bind a cursed relic instead of offering helpful relics. " % chance
			+ "Leaving it unopened is safe."
		)
		add_child(Ui.label(warning, "Narration", true))
		add_child(Ui.label("At a rest, you can cleanse one cursed relic instead of healing.", "Muted", true))
		add_child(Ui.hbox([Ui.button("Open the cache", _ask({"type": "open-chest"}), "PrimaryButton")]))
	if reward.has("cursed_relic"):
		add_child(Ui.label("The curse is already bound to you. Leaving does not remove it.", "Narration", true))
		add_child(Cards.relic(catalog.relics.get(reward.cursed_relic, {"name": "?", "summary": "", "rarity": ""})))
	if reward.has("spell"):
		var offered: Dictionary = reward.spell
		var text := (
			"The guardian's core holds a spell of its own: %s, with %d empty slots."
			% [offered.name, int(offered.capacity)]
		)
		add_child(Ui.label(text, "Narration", true))
		add_child(Ui.hbox([Ui.button("Claim %s" % offered.name, _ask({"type": "claim-spell"}), "PrimaryButton")]))
	if reward.has("relics"):
		var relics: Array = reward.relics
		add_child(Ui.label("A relic" if relics.size() == 1 else "Choose a relic", "Subheading"))
		var row := Ui.hbox([], 10)
		for relic_id: String in relics:
			var relic: Dictionary = catalog.relics.get(relic_id, {})
			var claim := Ui.button("Claim", _ask({"type": "claim-relic", "relic_id": relic_id}), "PrimaryButton")
			row.add_child(Ui.expand(Cards.relic(relic, claim)))
		add_child(row)
	if reward.has("shards"):
		var deck := ShardrunRules.is_deck(state)
		add_child(Ui.label("Add one card to your deck" if deck else "Take one shard", "Subheading"))
		var joins := (
			"It is shuffled into your deck for every fight from now on."
			if deck
			else ("It joins your spare shards; slot it into a spell before the next fight.")
		)
		add_child(Ui.label(joins, "Muted", true))
		# One shard to a row, its code beside it at full width: the code is what the choice is about.
		var column := Ui.vbox([], 10)
		for shard_id: String in reward.shards:
			var shard: Dictionary = catalog.shards.get(shard_id, {})
			var verb := "Add %s to the deck" if deck else "Take %s"
			var take := Ui.button(verb % shard.get("name", shard_id), _ask({"type": "take", "shard_id": shard_id}))
			take.theme_type_variation = "PrimaryButton"
			column.add_child(Cards.shard(shard, state.language, session.show_summaries(), 12, take, true))
		add_child(column)
		var skip := "Skip the cards" if deck else "Skip the shards"
		add_child(Ui.hbox([Ui.button(skip, _ask({"type": "take", "shard_id": null}))]))
	var leave := "Leave it unopened" if reward.has("chest") else "Leave the rest and move on"
	add_child(Ui.hbox([Ui.button(leave, _ask({"type": "leave"}))]))


func _rest() -> void:
	var state := session.state
	var heal := ShardrunViews.rest_heal(state, session.catalog)
	add_child(Ui.hbox([Ui.picture("shardrun/map-prop-rest", Vector2(126, 126), ""), _rest_text(heal)], 16))
	for relic: Dictionary in ShardrunViews.cursed_relics(state, session.catalog):
		var cleanse := Ui.button(
			"Cleanse %s instead of healing" % relic.name, _ask({"type": "cleanse-relic", "relic_id": relic.id})
		)
		add_child(Ui.hbox([cleanse]))


func _rest_text(heal: int) -> Control:
	var text := "The hum of the Machine is almost soothing. Rest to recover %d Integrity. " % heal
	text += "Rearrange your spells first if you like; resting moves you on."
	var rest := Ui.button("Rest (+%d Integrity)" % heal, _ask({"type": "rest"}), "PrimaryButton")
	return Ui.expand(
		Ui.vbox([Ui.label("A quiet alcove", "Heading"), Ui.label(text, "Narration", true), Ui.hbox([rest])])
	)


## A Shardrun's forge can melt a card down: a thinner deck deals its best cards more often (never below the minimum).
func _melt(state: Dictionary, catalog: Dictionary) -> void:
	var deck: Array = state.get("deck", [])
	var smallest := int(catalog.balance.deck.min_cards)
	add_child(Ui.label("Melt a card down", "Subheading"))
	if deck.size() <= smallest:
		add_child(Ui.label("Your deck is already as thin as it can be (%d cards)." % smallest, "Muted"))
		return
	var row := Ui.flow([], 8)
	var seen := {}
	for shard_id: String in deck:
		if seen.has(shard_id):
			continue
		seen[shard_id] = true
		var shard: Dictionary = catalog.shards.get(shard_id, {})
		var count := deck.count(shard_id)
		var label := "Melt %s%s" % [shard.get("name", shard_id), " (1 of %d)" % count if count > 1 else ""]
		row.add_child(Ui.button(label, _ask({"type": "purge", "shard_id": shard_id})))
	add_child(row)


func _forge() -> void:
	var state := session.state
	var catalog := session.catalog
	var options := ShardrunViews.forge_options(state, catalog)
	add_child(Ui.label("An abandoned forge", "Heading"))
	var deck := ShardrunRules.is_deck(state)
	var thing := "card" if deck else "shard"
	var text := (
		"Do one thing here: rework a %s (upgrade it, or repair a broken one), widen a spell by one slot, " % thing
	)
	text += "melt a card out of your deck, " if deck else ""
	text += "or widen your Program by a slot." if state.playstyle == "program" else "or bind a new spell to your book."
	add_child(Ui.label(text, "Narration", true))
	if deck:
		_melt(state, catalog)
	if not (options.shards as Array).is_empty():
		add_child(Ui.label("Rework a %s" % thing, "Subheading"))
		var row := Ui.flow([], 8)
		for shard_id: String in options.shards:
			var shard: Dictionary = catalog.shards.get(shard_id, {})
			var into: Dictionary = catalog.shards.get(shard.forge.into, {})
			var verb := String(shard.forge.get("verb", "upgrade")).capitalize()
			var button := Ui.button(
				"%s %s → %s" % [verb, shard.name, into.get("name", shard.forge.into)],
				_ask({"type": "forge", "shard_id": shard_id})
			)
			button.tooltip_text = into.get("summary", "")
			row.add_child(button)
		add_child(row)
	if not (options.spells as Array).is_empty():
		add_child(Ui.label("Widen a spell", "Subheading"))
		var row := Ui.flow([], 8)
		for spell_id: String in options.spells:
			var spell := Shardrun.spell_by_id(state, spell_id)
			var label := "Widen %s to %d slots" % [spell.name, int(spell.capacity) + 1]
			row.add_child(Ui.button(label, _ask({"type": "widen", "spell_id": spell_id})))
		add_child(row)
	var bind: Dictionary = options.bind
	if not bind.is_empty():
		add_child(Ui.label("Bind a new spell", "Subheading"))
		add_child(
			Ui.label(
				"An empty spell with %d slots, ready for the spare shards you carry." % int(bind.capacity), "Muted"
			)
		)
		add_child(Ui.hbox([Ui.button("Bind %s" % bind.name, _ask({"type": "bind"}), "PrimaryButton")]))
	add_child(Ui.hbox([Ui.button("Leave the forge as it is", _ask({"type": "forge", "shard_id": null}))]))
