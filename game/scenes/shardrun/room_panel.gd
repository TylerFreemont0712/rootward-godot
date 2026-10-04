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
		"shop":
			var registry := RegistryView.create(run_session)
			registry.wants.connect(func(command: Dictionary) -> void: panel.wants.emit(command))
			panel.add_child(registry)
		"issue":
			var issue := IssueView.create(run_session)
			issue.wants.connect(func(command: Dictionary) -> void: panel.wants.emit(command))
			panel.add_child(issue)
	return panel


func _ask(command: Dictionary) -> Callable:
	return func() -> void: wants.emit(command)


func _reward() -> void:
	var state := session.state
	var catalog := session.catalog
	var reward: Dictionary = state.get("reward", {})
	if state.get("playstyle", "") != "program":
		_legacy_reward(state, catalog, reward)
		return
	var title := Text.t("An opened cache")
	if reward.has("shards"):
		title = Text.t("Shards in the rubble")
	elif reward.has("chest"):
		title = Text.t("A sealed cache")
	elif reward.has("cursed_relic"):
		title = Text.t("A curse has bound itself")
	add_child(Ui.hbox([Ui.label(title, "Heading"), Ui.spacer(), _wallet(int(state.get("cycles", 0)))], 12))
	var choices := Ui.vbox([], 10)
	var payout: VBoxContainer
	if reward.has("receipt") or reward.has("script"):
		payout = Ui.vbox([], 10)
	if reward.has("receipt"):
		payout.add_child(_receipt(reward.receipt, int(state.get("cycles", 0))))
	if reward.has("script"):
		payout.add_child(_script_reward(String(reward.script)))
	if reward.has("chest"):
		var chance := roundi(float(reward.chest.curse_chance) * 100.0)
		var warning := run_on(
			[
				Text.f(
					"Curse chance: %d%%. Opening may bind a cursed relic instead of offering helpful relics.", [chance]
				),
				Text.t("Leaving it unopened is safe.")
			]
		)
		var chest_copy := Ui.vbox(
			[
				Ui.label(warning, "Narration", true),
				Ui.label(Text.t("At a rest, you can cleanse one cursed relic instead of healing."), "Muted", true)
			],
			4
		)
		var open := Ui.button(Text.t("Open the cache"), _ask({"type": "open-chest"}), "PrimaryButton")
		choices.add_child(
			Ui.panel(
				Ui.hbox(
					[Ui.picture("shardrun/map-prop-treasure", Vector2(72, 72), "◇"), Ui.expand(chest_copy), open], 12
				)
			)
		)
	if reward.has("cursed_relic"):
		choices.add_child(
			Ui.label(Text.t("The curse is already bound to you. Leaving does not remove it."), "Narration", true)
		)
		var curse: Dictionary = catalog.relics.get(
			reward.cursed_relic, {"id": reward.cursed_relic, "name": "?", "summary": "", "rarity": ""}
		)
		choices.add_child(Cards.relic(curse, null, Vector2(64, 64)))
	if reward.has("spell"):
		var offered: Dictionary = reward.spell
		var text := Text.f(
			"The guardian's core holds a spell of its own: %s, with %d empty slots.",
			[Text.t(offered.name), int(offered.capacity)]
		)
		choices.add_child(
			Ui.panel(
				Ui.hbox(
					[
						Ui.picture("shardrun/map-boss", Vector2(72, 72), "✦"),
						Ui.expand(Ui.label(text, "Narration", true)),
						Ui.button(
							Text.f("Claim %s", [Text.t(offered.name)]), _ask({"type": "claim-spell"}), "PrimaryButton"
						)
					],
					12
				)
			)
		)
	if reward.has("relics"):
		var relics: Array = reward.relics
		choices.add_child(Ui.label(Text.t("A relic") if relics.size() == 1 else Text.t("Choose a relic"), "Subheading"))
		var row := Ui.flow([], 8)
		for relic_id: String in relics:
			var relic: Dictionary = catalog.relics.get(relic_id, {})
			var claim := Ui.button(
				Text.t("Claim"), _ask({"type": "claim-relic", "relic_id": relic_id}), "PrimaryButton"
			)
			var face := Cards.relic(relic, claim, Vector2(64, 64))
			face.custom_minimum_size.x = 310
			row.add_child(face)
		choices.add_child(row)
	if reward.has("shards"):
		var deck := ShardrunRules.is_deck(state)
		choices.add_child(
			Ui.label(Text.t("Add one card to your deck") if deck else Text.t("Take one shard"), "Subheading")
		)
		var joins := (
			Text.t("It is shuffled into your deck for every fight from now on.")
			if deck
			else Text.t("It joins your spare shards; slot it into a spell before the next fight.")
		)
		choices.add_child(Ui.label(joins, "Muted", true))
		var cards := Ui.flow([], 8)
		for shard_id: String in reward.shards:
			var shard: Dictionary = catalog.shards.get(shard_id, {})
			var name := Text.t(shard.get("name", shard_id))
			var verb := Text.f("Add %s to the deck", [name]) if deck else Text.f("Take %s", [name])
			var take := Ui.button(verb, _ask({"type": "take", "shard_id": shard_id}))
			take.theme_type_variation = "PrimaryButton"
			var face := CardFace.create(shard_id, catalog, state.language, session.show_summaries(), CardFace.Size.DECK)
			face.draggable = false
			var option := Ui.vbox([face, Ui.label(Text.t(String(shard.get("summary", ""))), "Muted", true), take], 6)
			option.custom_minimum_size.x = 204
			cards.add_child(Ui.panel(option, "Card"))
		choices.add_child(cards)
		var skip := Text.t("Skip the cards") if deck else Text.t("Skip the shards")
		if ProgramRewards.applies(state):
			skip = Text.f("Skip the cards (+%d cycles)", [ProgramCycles.skip_pay(state, catalog)])
		choices.add_child(Ui.hbox([Ui.button(skip, _ask({"type": "take", "shard_id": null}))]))
	var body := Ui.hbox([], 14)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.size_flags_stretch_ratio = 2.4
	body.add_child(choices)
	if payout != null:
		payout.custom_minimum_size.x = 350
		payout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		payout.size_flags_stretch_ratio = 1.0
		body.add_child(payout)
	add_child(Ui.expand(body, true))
	var leave := Text.t("Leave it unopened") if reward.has("chest") else Text.t("Leave the rest and move on")
	add_child(Ui.hbox([Ui.button(leave, _ask({"type": "leave"}), "PrimaryButton")]))


## Spellforge and the card run keep their original reward layout; the compact ledger belongs to program runs.
func _legacy_reward(state: Dictionary, catalog: Dictionary, reward: Dictionary) -> void:
	var title := Text.t("An opened cache")
	if reward.has("shards"):
		title = Text.t("Shards in the rubble")
	elif reward.has("chest"):
		title = Text.t("A sealed cache")
	elif reward.has("cursed_relic"):
		title = Text.t("A curse has bound itself")
	add_child(Ui.label(title, "Heading"))
	if reward.has("script"):
		add_child(_script_reward(String(reward.script)))
	if reward.has("chest"):
		var chance := roundi(float(reward.chest.curse_chance) * 100.0)
		var warning := run_on(
			[
				Text.f(
					"Curse chance: %d%%. Opening may bind a cursed relic instead of offering helpful relics.", [chance]
				),
				Text.t("Leaving it unopened is safe.")
			]
		)
		add_child(Ui.label(warning, "Narration", true))
		add_child(Ui.label(Text.t("At a rest, you can cleanse one cursed relic instead of healing."), "Muted", true))
		add_child(Ui.hbox([Ui.button(Text.t("Open the cache"), _ask({"type": "open-chest"}), "PrimaryButton")]))
	if reward.has("cursed_relic"):
		add_child(Ui.label(Text.t("The curse is already bound to you. Leaving does not remove it."), "Narration", true))
		add_child(Cards.relic(catalog.relics.get(reward.cursed_relic, {"name": "?", "summary": "", "rarity": ""})))
	if reward.has("spell"):
		var offered: Dictionary = reward.spell
		var text := Text.f(
			"The guardian's core holds a spell of its own: %s, with %d empty slots.",
			[Text.t(offered.name), int(offered.capacity)]
		)
		add_child(Ui.label(text, "Narration", true))
		add_child(
			Ui.hbox(
				[Ui.button(Text.f("Claim %s", [Text.t(offered.name)]), _ask({"type": "claim-spell"}), "PrimaryButton")]
			)
		)
	if reward.has("relics"):
		var relics: Array = reward.relics
		add_child(Ui.label(Text.t("A relic") if relics.size() == 1 else Text.t("Choose a relic"), "Subheading"))
		var row := Ui.hbox([], 10)
		for relic_id: String in relics:
			var relic: Dictionary = catalog.relics.get(relic_id, {})
			var claim := Ui.button(
				Text.t("Claim"), _ask({"type": "claim-relic", "relic_id": relic_id}), "PrimaryButton"
			)
			row.add_child(Ui.expand(Cards.relic(relic, claim)))
		add_child(row)
	if reward.has("shards"):
		var deck := ShardrunRules.is_deck(state)
		add_child(Ui.label(Text.t("Add one card to your deck") if deck else Text.t("Take one shard"), "Subheading"))
		var joins := (
			Text.t("It is shuffled into your deck for every fight from now on.")
			if deck
			else Text.t("It joins your spare shards; slot it into a spell before the next fight.")
		)
		add_child(Ui.label(joins, "Muted", true))
		var column := Ui.vbox([], 10)
		for shard_id: String in reward.shards:
			var shard: Dictionary = catalog.shards.get(shard_id, {})
			var name := Text.t(shard.get("name", shard_id))
			var verb := Text.f("Add %s to the deck", [name]) if deck else Text.f("Take %s", [name])
			var take := Ui.button(verb, _ask({"type": "take", "shard_id": shard_id}))
			take.theme_type_variation = "PrimaryButton"
			column.add_child(Cards.shard(shard, state.language, session.show_summaries(), 12, take, true))
		add_child(column)
		var skip := Text.t("Skip the cards") if deck else Text.t("Skip the shards")
		add_child(Ui.hbox([Ui.button(skip, _ask({"type": "take", "shard_id": null}))]))
	var leave := Text.t("Leave it unopened") if reward.has("chest") else Text.t("Leave the rest and move on")
	add_child(Ui.hbox([Ui.button(leave, _ask({"type": "leave"}))]))


func _wallet(cycles: int) -> Control:
	var wallet := Ui.hbox(
		[Ui.picture("shardrun/cycles", Vector2(34, 34), "⟳"), Ui.label("%d" % cycles, "Subheading")], 6
	)
	wallet.tooltip_text = Text.t("Cycles: what you earn for kills, and spend at the Registry.")
	return wallet


## A compact payout panel keeps the individual kill math visible without pushing the card choices down the room.
func _receipt(receipt: Dictionary, wallet: int) -> Control:
	var lines := Ui.flow([], 6)
	for line: Dictionary in receipt.lines:
		var label := Text.t(String(line.label))
		var amount := "+%d" % int(line.amount) if line.kind == "bonus" else "%d" % int(line.amount)
		var chip := Ui.hbox([Ui.label(label, "Faint"), Ui.tint(Ui.label(amount, "Subheading"), UiTheme.TEAL)], 8)
		lines.add_child(Ui.panel(chip, "Sunken"))
	var summary := Ui.label(Text.f("cycles %d   (total %d)", [int(receipt.total), wallet]), "Subheading")
	var body := Ui.vbox(
		[
			Ui.hbox(
				[
					Ui.picture("shardrun/cycles", Vector2(34, 34), "⟳"),
					Ui.label("$ time ./main", "Faint"),
					Ui.spacer(),
					summary
				],
				8
			),
			lines
		],
		6
	)
	return Ui.panel(body, "Card")


## A script a fight left behind: take it, dropping one of the belt's when it is full.
func _script_reward(id: String) -> Control:
	var state := session.state
	var script: Dictionary = session.catalog.programs.scripts.get(id, {})
	if script.is_empty():
		return Ui.spacer()
	var full := (state.get("belt", []) as Array).size() >= ProgramScripts.belt_size(state, session.catalog)
	var text := Ui.vbox(
		[
			Ui.label(Text.t("A script"), "Faint"),
			Ui.tint(Ui.label(Text.t(script.name), "Subheading"), UiTheme.rarity(String(script.rarity))),
			Ui.label(Text.t(script.summary), "Muted", true)
		],
		2
	)
	var actions := Ui.flow([], 6)
	if not full:
		actions.add_child(
			Ui.button(Text.f("Take %s", [Text.t(script.name)]), _ask({"type": "take-script"}), "PrimaryButton")
		)
	else:
		text.add_child(Ui.label(Text.t("Your belt is full. Drop one script to take it."), "Muted", true))
		var belt: Array = state.belt
		for index in belt.size():
			var held: Dictionary = session.catalog.programs.scripts.get(belt[index], {})
			actions.add_child(
				Ui.button(
					Text.f("Drop %s", [Text.t(String(held.get("name", belt[index])))]),
					_ask({"type": "take-script", "drop_index": index})
				)
			)
	return Ui.panel(
		Ui.hbox([Ui.picture("shardrun/script-" + id, Vector2(72, 72), "📜"), Ui.expand(text), actions], 10), "Card"
	)


func _rest() -> void:
	var state := session.state
	var heal := ShardrunViews.rest_heal(state, session.catalog)
	add_child(Ui.hbox([Ui.picture("shardrun/map-prop-rest", Vector2(126, 126), ""), _rest_text(heal)], 16))
	for relic: Dictionary in ShardrunViews.cursed_relics(state, session.catalog):
		var cleanse := Ui.button(
			Text.f("Cleanse %s instead of healing", [Text.t(relic.name)]),
			_ask({"type": "cleanse-relic", "relic_id": relic.id})
		)
		add_child(Ui.hbox([cleanse]))
	# Dead Code Elimination: a rest may also remove a card.
	if ProgramRelics.modifiers(state, session.catalog).rest_purge and not state.get("rest_purged", false):
		add_child(Ui.label(Text.t("Dead Code Elimination: remove a card before you rest."), "Subheading"))
		var seen := {}
		var row := Ui.flow([], 8)
		for id: String in state.deck:
			if seen.has(id):
				continue
			seen[id] = true
			var name := Text.t(String((session.catalog.shards.get(id, {}) as Dictionary).get("name", id)))
			row.add_child(Ui.button(name, _ask({"type": "purge", "shard_id": id})))
		add_child(row)


func _rest_text(heal: int) -> Control:
	var text := run_on(
		[
			Text.f("The hum of the Machine is almost soothing. Rest to recover %d Integrity.", [heal]),
			Text.t("Rearrange your spells first if you like; resting moves you on.")
		]
	)
	var rest := Ui.button(Text.f("Rest (+%d Integrity)", [heal]), _ask({"type": "rest"}), "PrimaryButton")
	return Ui.expand(
		Ui.vbox([Ui.label(Text.t("A quiet alcove"), "Heading"), Ui.label(text, "Narration", true), Ui.hbox([rest])])
	)


## A Shardrun's forge can melt a card down: a thinner deck deals its best cards more often (never below the minimum).
func _melt(state: Dictionary, catalog: Dictionary) -> void:
	var deck: Array = state.get("deck", [])
	var smallest := int(catalog.balance.deck.min_cards)
	add_child(Ui.label(Text.t("Melt a card down"), "Subheading"))
	if deck.size() <= smallest:
		add_child(Ui.label(Text.f("Your deck is already as thin as it can be (%d cards).", [smallest]), "Muted"))
		return
	var row := Ui.flow([], 8)
	var seen := {}
	for shard_id: String in deck:
		if seen.has(shard_id):
			continue
		seen[shard_id] = true
		var shard: Dictionary = catalog.shards.get(shard_id, {})
		var count := deck.count(shard_id)
		var name := Text.t(shard.get("name", shard_id))
		var label := Text.f("Melt %s (1 of %d)", [name, count]) if count > 1 else Text.f("Melt %s", [name])
		row.add_child(Ui.button(label, _ask({"type": "purge", "shard_id": shard_id})))
	add_child(row)


func _forge() -> void:
	var state := session.state
	var catalog := session.catalog
	var options := ShardrunViews.forge_options(state, catalog)
	add_child(Ui.label(Text.t("An abandoned forge"), "Heading"))
	var deck := ShardrunRules.is_deck(state)
	var thing := "card" if deck else "shard"
	var text := (
		"Do one thing here: rework a %s (upgrade it, or repair a broken one), widen a spell by one slot, " % thing
	)
	text += "melt a card out of your deck, " if deck else ""
	text += "or bind a new spell to your book."
	# Too long for one literal on a line: the whole sentence is the overlay's key.
	text = Text.sentence(text)
	if state.playstyle == "program":
		text = Text.t(
			"Do one thing here: refactor a card, melt a card out of your deck, or widen your Program by a slot."
		)
	add_child(Ui.label(text, "Narration", true))
	if deck:
		_melt(state, catalog)
	if state.playstyle == "program" and not (options.shards as Array).is_empty():
		# A program run's upgrades are refactors, read as a diff (ADR-0018).
		var refactor := ForgeView.create(session, options.shards)
		refactor.wants.connect(func(command: Dictionary) -> void: wants.emit(command))
		add_child(refactor)
	elif not (options.shards as Array).is_empty():
		add_child(Ui.label(Text.t("Rework a card") if deck else Text.t("Rework a shard"), "Subheading"))
		var row := Ui.flow([], 8)
		for shard_id: String in options.shards:
			var shard: Dictionary = catalog.shards.get(shard_id, {})
			var into: Dictionary = catalog.shards.get(shard.forge.into, {})
			var verb := Text.t(String(shard.forge.get("verb", "upgrade")).capitalize())
			var button := Ui.button(
				"%s %s → %s" % [verb, Text.t(shard.name), Text.t(into.get("name", shard.forge.into))],
				_ask({"type": "forge", "shard_id": shard_id})
			)
			button.tooltip_text = Text.t(into.get("summary", ""))
			row.add_child(button)
		add_child(row)
	if not (options.spells as Array).is_empty():
		add_child(
			Ui.label(
				Text.t("Widen the Program") if state.playstyle == "program" else Text.t("Widen a spell"), "Subheading"
			)
		)
		var row := Ui.flow([], 8)
		for spell_id: String in options.spells:
			var spell := Shardrun.spell_by_id(state, spell_id)
			var label := Text.f("Widen %s to %d slots", [Text.t(spell.name), int(spell.capacity) + 1])
			row.add_child(Ui.button(label, _ask({"type": "widen", "spell_id": spell_id})))
		add_child(row)
	var bind: Dictionary = options.bind
	if not bind.is_empty():
		add_child(Ui.label(Text.t("Bind a new spell"), "Subheading"))
		add_child(
			Ui.label(
				Text.f("An empty spell with %d slots, ready for the spare shards you carry.", [int(bind.capacity)]),
				"Muted"
			)
		)
		add_child(Ui.hbox([Ui.button(Text.f("Bind %s", [Text.t(bind.name)]), _ask({"type": "bind"}), "PrimaryButton")]))
	add_child(Ui.hbox([Ui.button(Text.t("Leave the forge as it is"), _ask({"type": "forge", "shard_id": null}))]))


## Sentences translated one by one, run together as the language writes them (Japanese leaves no space between).
static func run_on(parts: Array[String]) -> String:
	return ("" if Text.japanese() else " ").join(parts)
