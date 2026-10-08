class_name ForgeMeltView
extends VBoxContainer
## Melting a card (the forge's Melt): the deck as its cards, the chosen one ringed in red with what the melt does to the
## deck written out. Confirming plays the rune circle over that card, then sends the one command the rules judge.

signal wants(command: Dictionary)

var session: ShardrunSession
var _grid: ForgeCardGrid
var _chosen := ""
var _note: Label
var _actions: HBoxContainer
var _confirm: Button
var _busy := false


static func create(run_session: ShardrunSession) -> ForgeMeltView:
	var view := ForgeMeltView.new()
	view.session = run_session
	view.add_theme_constant_override("separation", 12)
	view._build()
	return view


func _build() -> void:
	var deck: Array = session.state.deck
	var usable := {}
	for id: String in deck:
		usable[id] = true
	add_child(Ui.label(Text.t("Melt a card down"), "Subheading"))
	add_child(
		Ui.label(
			Text.f(
				"Melting destroys one copy for good. Your deck goes from %d to %d cards.",
				[deck.size(), deck.size() - 1]
			),
			"Narration",
			true
		)
	)
	_grid = ForgeCardGrid.create(session, deck, usable, UiTheme.FAIL, CardFace.Size.DRAFT)
	_grid.picked.connect(pick)
	add_child(_grid)
	_note = Ui.label(Text.t("Choose a card to melt. The rest of the deck is unchanged."), "Muted", true)
	add_child(_note)
	_confirm = Ui.button("", confirm, "PrimaryButton")
	# Melting is the one destructive choice here: its button says so in the danger colour.
	_confirm.add_theme_color_override("font_color", UiTheme.FAIL)
	var keep := Ui.button(Text.t("Keep it"), _unchoose)
	# Nothing is confirmed until a card is chosen: the actions wait for it.
	_actions = Ui.hbox([_confirm, keep], 10)
	_actions.visible = false
	add_child(_actions)


## Chooses the card to melt: it is ringed, and the confirm button names it.
func pick(shard_id: String) -> void:
	if _busy:
		return
	_chosen = shard_id
	_grid.select(shard_id)
	var card: Dictionary = session.catalog.shards.get(shard_id, {})
	var card_name := Text.t(String(card.get("name", shard_id)))
	_note.text = Text.f("%s will be melted: one copy leaves your deck for good.", [card_name])
	_confirm.text = Text.f("Melt %s", [card_name])
	_confirm.disabled = false
	_actions.visible = true


func _unchoose() -> void:
	if _busy:
		return
	_chosen = ""
	_grid.select("")
	_note.text = Text.t("Choose a card to melt. The rest of the deck is unchanged.")
	_actions.visible = false


## Melts the chosen card: the rune circle covers it, then the command goes out.
func confirm() -> void:
	if _busy or _chosen == "":
		return
	_busy = true
	_grid.lock()
	_confirm.disabled = true
	var tween := ForgeAnimation.melt(_grid.holder_of(_chosen), _grid.face_of(_chosen))
	if tween != null:
		await tween.finished
	if not is_inside_tree():
		return
	wants.emit({"type": "purge", "shard_id": _chosen})
