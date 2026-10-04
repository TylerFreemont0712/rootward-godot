class_name RegistryView
extends VBoxContainer
## The Registry (ProgramShop), kept by Semver the owl: cards, relics and scripts on shelves, three services, a wallet of
## cycles. Each purchase is a command; the rules say what it costs and whether it can be done. A service that needs a
## card of yours opens a picker here first (no command until you choose).

signal wants(command: Dictionary)

const LINES := [
	"Every package is signed. Mostly.",
	"Breaking changes are extra.",
	"No refunds after git push.",
	"Pinned versions are a love language.",
	"Mind the drawers: they are labelled in semver.",
]

var session: ShardrunSession
## "" (the shelves), or the service waiting for a card or a paradigm: uninstall, refactor, pip-install.
var _picking := ""


static func create(run_session: ShardrunSession) -> RegistryView:
	var view := RegistryView.new()
	view.session = run_session
	view.add_theme_constant_override("separation", 12)
	view._build()
	return view


func _ask(command: Dictionary) -> Callable:
	return func() -> void: wants.emit(command)


func _build() -> void:
	Ui.clear(self)
	var state := session.state
	var shop: Dictionary = state.shop
	add_child(_header(state, shop))
	if shop.has("pip"):
		_pip(shop.pip)
		add_child(Ui.hbox([Ui.button(Text.t("Leave the Registry"), _ask({"type": "leave-shop"}))]))
		return
	if _picking != "":
		_picker(state)
		return
	add_child(Ui.label(Text.t("CARDS"), "Faint"))
	add_child(_shelf_cards(state, shop))
	add_child(Ui.label(Text.t("RELICS"), "Faint"))
	add_child(_shelf_relics(state, shop))
	if not (shop.scripts as Array).is_empty():
		add_child(Ui.label(Text.t("SCRIPTS"), "Faint"))
		add_child(_shelf_scripts(state, shop))
	add_child(Ui.label(Text.t("SERVICES"), "Faint"))
	add_child(_services(state))
	add_child(Ui.hbox([Ui.button(Text.t("Leave the Registry"), _ask({"type": "leave-shop"}), "PrimaryButton")]))


func _header(state: Dictionary, shop: Dictionary) -> Control:
	var line: String = LINES[Rng.hash_string(String(shop.room)) % LINES.size()]
	var owl := Ui.picture("shardrun/semver", Vector2(112, 112), "🦉")
	var words := (
		Ui
		. vbox(
			[
				Ui.label(Text.t("The Registry"), "Heading"),
				Ui.tint(Ui.label(Text.f('Semver: "%s"', [Text.t(line)]), "Narration", true), UiTheme.AMBER),
			],
			4
		)
	)
	var wallet := Ui.hbox(
		[Ui.picture("shardrun/cycles", Vector2(30, 30), "⟳"), Ui.label("%d" % int(state.get("cycles", 0)), "Heading")],
		6
	)
	return Ui.hbox([owl, Ui.expand(words), wallet], 16)


func _price_button(label: String, price: int, command: Dictionary, state: Dictionary) -> Button:
	var button := Ui.button(Text.f("%s  ·  %d cycles", [label, price]), _ask(command), "PrimaryButton")
	button.disabled = int(state.get("cycles", 0)) < price
	return button


func _sold() -> Control:
	return Ui.tint(Ui.label(Text.t("Sold"), "Faint"), UiTheme.FAINT)


func _shelf_cards(state: Dictionary, shop: Dictionary) -> Control:
	var row := Ui.flow([], 10)
	var items: Array = shop.cards
	for index in items.size():
		var item: Dictionary = items[index]
		var card: Dictionary = session.catalog.shards[item.id]
		var price := ProgramShop.price_of(state, "cards", item, session.catalog)
		var action: Control
		if item.get("sold", false):
			action = _sold()
		else:
			var label := Text.t("On sale") if item.get("sale", false) else Text.t("Buy")
			action = _price_button(label, price, {"type": "buy", "shelf": "cards", "index": index}, state)
		var face := Cards.shard(card, state.language, session.show_summaries(), 7, action, false)
		face.custom_minimum_size.x = 330
		row.add_child(face)
	return row


func _shelf_relics(state: Dictionary, shop: Dictionary) -> Control:
	var row := Ui.flow([], 10)
	var items: Array = shop.relics
	for index in items.size():
		var item: Dictionary = items[index]
		var relic: Dictionary = session.catalog.relics[item.id]
		var action: Control
		if item.get("sold", false):
			action = _sold()
		else:
			var price := ProgramShop.price_of(state, "relics", item, session.catalog)
			action = _price_button(Text.t("Buy"), price, {"type": "buy", "shelf": "relics", "index": index}, state)
		var face := Cards.relic(relic, action)
		face.custom_minimum_size.x = 330
		row.add_child(face)
	return row


func _shelf_scripts(state: Dictionary, shop: Dictionary) -> Control:
	var row := Ui.flow([], 10)
	var items: Array = shop.scripts
	for index in items.size():
		var item: Dictionary = items[index]
		var script: Dictionary = session.catalog.programs.scripts[item.id]
		var ring := UiTheme.rarity(String(script.rarity))
		var head := (
			Ui
			. hbox(
				[
					Ui.picture("shardrun/script-" + String(script.id), Vector2(44, 44), "📜"),
					Ui.vbox(
						[
							Ui.tint(Ui.label(Text.t(script.name), "Subheading"), ring),
							Ui.label(Text.t(script.rarity), "Faint")
						],
						0
					),
				],
				10
			)
		)
		var body := Ui.vbox([head, Ui.label(Text.t(script.summary), "", true)], 8)
		if item.get("sold", false):
			body.add_child(_sold())
		else:
			var price := ProgramShop.price_of(state, "scripts", item, session.catalog)
			body.add_child(
				_price_button(Text.t("Buy"), price, {"type": "buy", "shelf": "scripts", "index": index}, state)
			)
		var panel := Ui.panel(body, "Card")
		panel.custom_minimum_size.x = 330
		row.add_child(panel)
	return row


func _services(state: Dictionary) -> Control:
	var row := Ui.flow([], 10)
	var catalog := session.catalog
	var services := [
		["uninstall", "uninstall", "Remove a card from your deck."],
		["refactor", "refactor", "Rework a card of yours into its + version."],
		["pip-install", "pip install", "Name a paradigm and choose one of three of its cards."],
	]
	if "tech-debt" in state.relics:
		services.append(["repay", "repay debt", "Settle your technical debt."])
	for service: Array in services:
		var price := ProgramShop.service_price(state, String(service[0]), catalog)
		var button := Ui.button(
			Text.f("%s  ·  %d cycles", [Text.t(String(service[1])), price]),
			_service_pressed.bind(String(service[0])),
			"PrimaryButton"
		)
		button.disabled = int(state.get("cycles", 0)) < price
		var body := Ui.vbox(
			[
				Ui.label(Text.t(String(service[1])), "Subheading"),
				Ui.label(Text.t(String(service[2])), "Muted", true),
				button
			],
			8
		)
		var panel := Ui.panel(body, "Card")
		panel.custom_minimum_size.x = 330
		row.add_child(panel)
	return row


func _service_pressed(kind: String) -> void:
	if kind == "repay":
		wants.emit({"type": "shop-service", "kind": "repay"})
		return
	_picking = kind
	_build()


## A picker for the card or paradigm a service needs; Back returns to the shelves without a command.
func _picker(state: Dictionary) -> void:
	add_child(Ui.label(Text.f("%s: choose", [Text.t(_picking.replace("-", " "))]), "Subheading"))
	var row := Ui.flow([], 8)
	if _picking == "pip-install":
		for paradigm: Dictionary in ProgramRules.config_of(session.catalog).paradigms:
			var button := Ui.button(
				Text.t(String(paradigm.name)),
				_ask({"type": "shop-service", "kind": "pip-install", "paradigm": paradigm.id})
			)
			button.add_theme_color_override("font_color", Color(paradigm.colour))
			row.add_child(button)
	else:
		var seen := {}
		for id: String in state.deck:
			if seen.has(id):
				continue
			seen[id] = true
			var card: Dictionary = session.catalog.shards.get(id, {})
			if _picking == "refactor" and not (card.get("forge", {}) as Dictionary).has("into"):
				continue
			var count := (state.deck as Array).count(id)
			var label := Text.t(String(card.get("name", id))) + ("  ×%d" % count if count > 1 else "")
			row.add_child(Ui.button(label, _ask({"type": "shop-service", "kind": _picking, "card_id": id})))
	add_child(row)
	add_child(Ui.hbox([Ui.button(Text.t("Back"), _back)]))


func _back() -> void:
	_picking = ""
	_build()


func _pip(pip: Dictionary) -> void:
	add_child(Ui.label(Text.f("pip install: three packages of %s", [Text.t(pip.paradigm)]), "Subheading"))
	var row := Ui.flow([], 10)
	for id: String in pip.cards:
		var card: Dictionary = session.catalog.shards[id]
		var take := Ui.button(
			Text.f("Add %s to the deck", [Text.t(card.name)]),
			_ask({"type": "pip-take", "card_id": id}),
			"PrimaryButton"
		)
		var face := Cards.shard(card, session.state.language, session.show_summaries(), 7, take, false)
		face.custom_minimum_size.x = 330
		row.add_child(face)
	add_child(row)
