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
	if reward.has("cursed_relic"):
		title = Text.t("A curse has bound itself")
	elif reward.has("receipt"):
		title = Text.t("Victory spoils")
	elif not reward.has("relics"):
		if reward.has("shards"):
			title = Text.t("Shards in the rubble")
		elif reward.has("chest"):
			title = Text.t("A sealed cache")
	add_child(Ui.hbox([Ui.label(title, "Heading"), Ui.spacer(), _wallet(int(state.get("cycles", 0)))], 12))
	if reward.has("receipt") or reward.has("script"):
		var keepsakes := Ui.hbox([], 12)
		if reward.has("receipt"):
			keepsakes.add_child(Ui.expand(_receipt(reward.receipt)))
		if reward.has("script"):
			keepsakes.add_child(Ui.expand(_script_reward(String(reward.script))))
		add_child(keepsakes)
	if reward.has("cursed_relic"):
		_add_forced_relic(reward, catalog)
	elif reward.has("relics"):
		_add_relic_choices(reward, catalog)
	elif reward.has("shards"):
		_add_card_choices(state, reward, catalog)
	elif reward.has("chest"):
		_add_chest(reward)
	elif reward.has("spell"):
		_add_spell(reward)
	else:
		add_child(Ui.label(Text.t("The cache is empty."), "Narration", true))


## Relics and cards get one focused, generously sized stage at a time. Taking or skipping it leaves the next reward
## in the state, so a guardian's relic choice naturally leads into its card choice.
func _choice_stage(contents: Control) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.y = 460
	center.add_child(contents)
	var stage := Ui.panel(center, "Overlay")
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override(
		"panel", UiTheme.box(Color("#090710", 0.32), Color(0, 0, 0, 0), 0, 12, Vector2(20, 18))
	)
	add_child(stage)


func _add_relic_choices(reward: Dictionary, catalog: Dictionary) -> void:
	var relics: Array = reward.relics
	var row := Ui.hbox([], 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for relic_id: String in relics:
		var relic: Dictionary = catalog.relics.get(relic_id, {})
		var face := Cards.relic(relic, null, Vector2(92, 92))
		face.custom_minimum_size = Vector2(320, 190)
		face.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		face.gui_input.connect(_on_relic_choice_input.bind(face, _ask({"type": "claim-relic", "relic_id": relic_id})))
		_pass_child_input(face)
		row.add_child(face)
	var actions := (
		Ui
		. hbox(
			[
				Ui.button(Text.t("Skip"), _ask({"type": "skip-relics"})),
			],
			10
		)
	)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var column := Ui.vbox(
		[
			Ui.label(Text.t("Choose a relic") if relics.size() > 1 else Text.t("A relic"), "Subheading"),
			Ui.label(Text.t("Click a relic to choose it."), "Muted", true),
			row,
			actions
		],
		20
	)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_choice_stage(column)


func _add_forced_relic(reward: Dictionary, catalog: Dictionary) -> void:
	var relic_id := String(reward.cursed_relic)
	var relic: Dictionary = catalog.relics.get(
		relic_id, {"id": relic_id, "name": "?", "summary": "", "rarity": "", "cursed": true}
	)
	var face := Cards.relic(relic, null, Vector2(112, 112))
	face.custom_minimum_size = Vector2(430, 190)
	var actions := Ui.hbox(
		[
			Ui.button(Text.t("Skip"), Callable(), ""),
			Ui.button(Text.t("Keep going"), _ask({"type": "ack-cursed-relic"}), "PrimaryButton")
		],
		10
	)
	(actions.get_child(0) as Button).disabled = true
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var column := Ui.vbox(
		[
			Ui.label(Text.t("The curse is already bound to you. Leaving does not remove it."), "Narration", true),
			face,
			actions
		],
		18
	)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_choice_stage(column)


func _add_card_choices(state: Dictionary, reward: Dictionary, catalog: Dictionary) -> void:
	var deck := ShardrunRules.is_deck(state)
	var row := Ui.hbox([], 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for shard_id: String in reward.shards:
		var face := CardFace.create(shard_id, catalog, state.language, session.show_summaries(), CardFace.Size.REWARD)
		face.draggable = false
		face.pressed = _select_reward_card.bind({"type": "take", "shard_id": shard_id})
		_lift_reward_card(face)
		var option := Ui.vbox([face], 8)
		option.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(option)
	var skip := Text.t("Skip the cards") if deck else Text.t("Skip the shards")
	if ProgramRewards.applies(state):
		skip = Text.f("Skip the cards (+%d cycles)", [ProgramCycles.skip_pay(state, catalog)])
	var actions := Ui.hbox([Ui.button(skip, _ask({"type": "take", "shard_id": null}))])
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var heading := Ui.label(Text.t("Add one card to your deck") if deck else Text.t("Take one shard"), "Subheading")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var instruction := Ui.label(Text.t("Hover to read a card's code; click it to choose."), "Muted", true)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var intro := Ui.vbox([heading, instruction], 6)
	var card_gap := Control.new()
	card_gap.custom_minimum_size.y = 24
	var column := Ui.vbox([intro, card_gap, row, actions], 12)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_choice_stage(column)


func _select_reward_card(_spot: Dictionary, button: int, command: Dictionary) -> void:
	if button == MOUSE_BUTTON_LEFT:
		wants.emit(command)


func _pass_child_input(control: Control) -> void:
	for child: Node in control.get_children():
		if child is Control:
			if child.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				child.mouse_filter = Control.MOUSE_FILTER_PASS
				child.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_pass_child_input(child)


func _on_relic_choice_input(event: InputEvent, face: Control, command: Callable) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	face.accept_event()
	command.call()


func _lift_reward_card(face: CardFace) -> void:
	face.pivot_offset = face.custom_minimum_size * 0.5
	var motion: Array[Tween] = []
	var hover := func(over: bool) -> void:
		if not motion.is_empty() and motion[0].is_valid():
			motion[0].kill()
		var tween := face.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion.assign([tween])
		tween.tween_property(face, "scale", Vector2.ONE * (1.05 if over else 1.0), 0.12)
	face.mouse_entered.connect(hover.bind(true))
	face.mouse_exited.connect(hover.bind(false))


func _add_chest(reward: Dictionary) -> void:
	var chance := roundi(float(reward.chest.curse_chance) * 100.0)
	var warning := run_on(
		[
			Text.f("Curse chance: %d%%. Opening may bind a cursed relic instead of offering helpful relics.", [chance]),
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
	var actions := Ui.hbox(
		[
			Ui.button(Text.t("Leave it unopened"), _ask({"type": "leave"})),
			Ui.button(Text.t("Open the cache"), _ask({"type": "open-chest"}), "PrimaryButton")
		],
		10
	)
	var contents := Ui.vbox([Ui.picture("shardrun/map-prop-treasure", Vector2(112, 112), "◇"), chest_copy, actions], 16)
	contents.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_choice_stage(contents)


func _add_spell(reward: Dictionary) -> void:
	var offered: Dictionary = reward.spell
	var description := Text.f(
		"The guardian's core holds a spell of its own: %s, with %d empty slots.",
		[Text.t(offered.name), int(offered.capacity)]
	)
	var contents := Ui.vbox(
		[
			Ui.picture("shardrun/map-boss", Vector2(112, 112), "✦"),
			Ui.label(description, "Narration", true),
			Ui.hbox(
				[
					Ui.button(Text.t("Skip"), _ask({"type": "skip-spell"})),
					Ui.button(
						Text.f("Claim %s", [Text.t(offered.name)]), _ask({"type": "claim-spell"}), "PrimaryButton"
					)
				],
				10
			)
		],
		16
	)
	contents.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_choice_stage(contents)


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
func _receipt(receipt: Dictionary) -> Control:
	var lines := Ui.flow([], 6)
	for line: Dictionary in receipt.lines:
		var label := Text.t(String(line.label))
		var amount := "+%d" % int(line.amount) if line.kind == "bonus" else "%d" % int(line.amount)
		var chip := Ui.hbox([Ui.label(label, "Faint"), Ui.tint(Ui.label(amount, "Subheading"), UiTheme.TEAL)], 8)
		lines.add_child(Ui.panel(chip, "Sunken"))
	var summary := Ui.label(Text.f("cycles %d earned", [int(receipt.total)]), "Subheading")
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
	actions.add_child(Ui.button(Text.t("Skip"), _ask({"type": "skip-script"})))
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


func _forge() -> void:
	var forge := ForgeRoom.create(session)
	forge.wants.connect(func(command: Dictionary) -> void: wants.emit(command))
	add_child(forge)


## Sentences translated one by one, run together as the language writes them (Japanese leaves no space between).
static func run_on(parts: Array[String]) -> String:
	return ("" if Text.japanese() else " ").join(parts)
