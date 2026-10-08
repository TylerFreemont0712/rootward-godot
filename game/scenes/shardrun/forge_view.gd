class_name ForgeView
extends VBoxContainer
## Refactoring a card (ADR-0018, redrawn): the cards that have a better version, the chosen one shown beside the version
## it turns into, with the refactor read as a diff (lines removed in red, added in green, as `git diff` shows them).
## Confirming plays the card changing from one to the other, then sends the one command the rules judge. A card's +
## keeps its function's name, so only the real change stands out.

signal wants(command: Dictionary)

var session: ShardrunSession
var _grid: ForgeCardGrid
var _detail: VBoxContainer
var _chosen := ""
var _busy := false


static func create(run_session: ShardrunSession) -> ForgeView:
	var view := ForgeView.new()
	view.session = run_session
	view.add_theme_constant_override("separation", 10)
	view._build()
	return view


func _build() -> void:
	var carried := _carried()
	var usable := {}
	for id: String in carried:
		usable[id] = _into(id) != ""
	add_child(Ui.label(Text.t("Refactor a card"), "Subheading"))
	add_child(
		Ui.label(
			Text.t("Every card has a better version. Pick one to read its diff: what the refactor removes and adds."),
			"Muted",
			true
		)
	)
	_grid = ForgeCardGrid.create(session, carried, usable, UiTheme.TEAL)
	_grid.picked.connect(pick)
	add_child(_grid)
	_detail = Ui.vbox([], 8)
	add_child(_detail)
	for id: String in carried:
		if usable[id]:
			pick(id)
			break


## Every card the forge can see: the deck's in a deck run, else the shards in the spells and the spare ones.
func _carried() -> Array:
	var state := session.state
	var source: Array = []
	if ShardrunRules.is_deck(state):
		source = state.deck
	else:
		for spell: Dictionary in state.spells:
			source.append_array(spell.shards)
		source.append_array(state.inventory)
	var carried: Array = []
	for id: String in source:
		if id != "" and session.catalog.shards.has(id):
			carried.append(id)
	return carried


## The id of a card's better version, or "" when it has none.
func _into(shard_id: String) -> String:
	var forge: Dictionary = (session.catalog.shards.get(shard_id, {}) as Dictionary).get("forge", {})
	return String(forge.get("into", ""))


## Chooses the card to refactor and lays out the change beside it.
func pick(shard_id: String) -> void:
	if _busy:
		return
	_chosen = shard_id
	_grid.select(shard_id)
	Ui.clear(_detail)
	var catalog := session.catalog
	var card: Dictionary = catalog.shards.get(shard_id, {})
	var forge: Dictionary = card.get("forge", {})
	var into_id := _into(shard_id)
	var into: Dictionary = catalog.shards.get(into_id, {})
	if into.is_empty():
		_detail.add_child(Ui.label(Text.t("This card has no better version."), "Muted", true))
		return
	var language := String(session.state.language)
	var summaries := session.show_summaries()
	var before := CardFace.create(shard_id, catalog, language, summaries, CardFace.Size.DRAFT)
	var after := CardFace.create(into_id, catalog, language, summaries, CardFace.Size.DRAFT)
	var pair := Ui.hbox([before, Ui.label("→", "Heading"), after], 18)
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_child(pair)
	var title := "%s → %s" % [Text.t(card.get("name", shard_id)), Text.t(into.get("name", into_id))]
	_detail.add_child(Ui.hbox([Ui.label(title, "Heading"), Ui.spacer(), Ui.label(_changes(card, into), "Faint")], 10))
	if summaries:
		_detail.add_child(Ui.label(Text.t(String(into.get("summary", ""))), "Narration", true))
	var before_code: String = (card.get("code", {}) as Dictionary).get(language, "")
	var after_code: String = (into.get("code", {}) as Dictionary).get(language, "")
	if into_id == shard_id + "-plus":
		# The + renames the function (both can sit in one program); the diff shows the refactor, not the rename.
		after_code = after_code.replace(
			SpellHarness.function_name(into, language), SpellHarness.function_name(card, language)
		)
	_detail.add_child(_code(CodeDiff.lines(before_code, after_code), language))
	var card_name := Text.t(card.get("name", shard_id))
	var verb := String(forge.get("verb", "upgrade"))
	var label := Text.f("Optimise %s", [card_name]) if verb == "optimize" else Text.f("Refactor %s", [card_name])
	_detail.add_child(Ui.hbox([Ui.button(label, refactor, "PrimaryButton")]))
	_detail.add_child(Ui.label(Text.t("One refactor per forge."), "Faint"))


## The card changes into its better version in place, then the command goes out.
func refactor() -> void:
	if _busy or _chosen == "":
		return
	_busy = true
	_grid.lock()
	var after := CardFace.create(
		_into(_chosen), session.catalog, String(session.state.language), session.show_summaries(), CardFace.Size.DECK
	)
	after.draggable = false
	var tween := ForgeAnimation.morph(_grid.holder_of(_chosen), _grid.face_of(_chosen), after)
	if tween != null:
		await tween.finished
	if not is_inside_tree():
		return
	wants.emit({"type": "forge", "shard_id": _chosen})


## What changes besides the code: "cost 2 → 1 · + __init__".
static func _changes(card: Dictionary, into: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(card.get("cost", 0)) != int(into.get("cost", 0)):
		parts.append(Text.f("cost %d → %d", [int(card.get("cost", 0)), int(into.get("cost", 0))]))
	var had: Array = card.get("keywords", [])
	var has: Array = into.get("keywords", [])
	for keyword: String in has:
		if not keyword in had:
			parts.append("+ %s" % keyword)
	for keyword: String in had:
		if not keyword in has:
			parts.append("− %s" % keyword)
	if ShardrunViews.complexity(card) != ShardrunViews.complexity(into):
		parts.append("%s → %s" % [ShardrunViews.complexity(card), ShardrunViews.complexity(into)])
	return " · ".join(parts)


## The diff as code: removed lines on red with "-", added ones on green with "+", the rest as they are.
static func _code(diff: Array[Dictionary], language: String) -> Control:
	var painted: PackedStringArray = []
	var changed := CodeDiff.changes(diff)
	if changed.removed == 0 and changed.added == 0:
		var same := Text.f(
			"%s The code is the same: the refactor is in what the card costs or does in the deck.",
			[CodeLanguage.comment(language)]
		)
		painted.append("[color=%s]%s[/color]" % [CodeColors.COMMENT, same])
	for line: Dictionary in diff:
		var text := String(line.text).replace("[", "[lb]")
		match String(line.kind):
			"removed":
				painted.append("[bgcolor=#4a1c24][color=#ff9a9a]- %s[/color][/bgcolor]" % text)
			"added":
				painted.append("[bgcolor=#173d2a][color=#9dffb8]+ %s[/color][/bgcolor]" % text)
			_:
				painted.append("  " + CodeColors.bbcode(String(line.text), language))
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	# Code is never translated (Text, ADR-0047).
	rich.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rich.add_theme_font_override("normal_font", UiTheme.code_font())
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_OFF
	rich.add_theme_font_size_override("normal_font_size", 14)
	rich.text = "\n".join(painted)
	var scroll := Ui.scroll(rich)
	# As tall as the diff, up to a screenful: a two-line refactor is not a wall of empty code.
	scroll.custom_minimum_size = Vector2(0, mini(320, 22 * painted.size() + 16))
	return Ui.panel(scroll, "Sunken")
