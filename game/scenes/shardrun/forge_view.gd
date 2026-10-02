class_name ForgeView
extends VBoxContainer
## A program run's forge (ADR-0018): upgrades are refactors. Pick a card of the deck and see what the refactor changes,
## as `git diff` shows it (lines removed in red, added in green), with its cost and keywords, then refactor it. A
## card's + keeps its function's name in the diff, so only the real change stands out.

signal wants(command: Dictionary)

var session: ShardrunSession
var _chosen := ""
var _picks: HFlowContainer
var _diff: VBoxContainer


static func create(run_session: ShardrunSession, card_ids: Array) -> ForgeView:
	var view := ForgeView.new()
	view.session = run_session
	view._build(card_ids)
	return view


func _build(card_ids: Array) -> void:
	add_theme_constant_override("separation", 8)
	add_child(Ui.label("Refactor a card", "Subheading"))
	add_child(
		Ui.label(
			"Every card has a better version. Pick one to read its diff: what the refactor removes and adds.",
			"Muted",
			true
		)
	)
	_picks = Ui.flow([], 6)
	add_child(_picks)
	_diff = Ui.vbox([], 6)
	add_child(_diff)
	for id: String in card_ids:
		var card: Dictionary = session.catalog.shards.get(id, {})
		var pick := Ui.button(String(card.get("name", id)), _choose.bind(id, card_ids))
		pick.toggle_mode = true
		pick.set_meta("card", id)
		_picks.add_child(pick)
	if not card_ids.is_empty():
		_choose(String(card_ids[0]), card_ids)


func _choose(id: String, card_ids: Array) -> void:
	_chosen = id
	for pick: Node in _picks.get_children():
		(pick as Button).set_pressed_no_signal(String(pick.get_meta("card", "")) == id)
	Ui.clear(_diff)
	var catalog := session.catalog
	var card: Dictionary = catalog.shards.get(id, {})
	var forge: Dictionary = card.get("forge", {})
	var into: Dictionary = catalog.shards.get(String(forge.get("into", "")), {})
	if into.is_empty():
		return
	var language := String(session.state.language)
	var verb := String(forge.get("verb", "upgrade"))
	var title := "%s → %s" % [card.get("name", id), into.get("name", forge.into)]
	var heading := Ui.hbox([Ui.label(title, "Heading"), Ui.spacer(), Ui.label(_changes(card, into), "Faint")], 10)
	_diff.add_child(heading)
	if session.show_summaries():
		_diff.add_child(Ui.label(String(into.get("summary", "")), "Narration", true))
	var before: String = (card.get("code", {}) as Dictionary).get(language, "")
	var after: String = (into.get("code", {}) as Dictionary).get(language, "")
	if String(forge.into) == id + "-plus":
		# The + renames the function (both can sit in one program); the diff shows the refactor, not the rename.
		after = after.replace(SpellHarness.function_name(into, language), SpellHarness.function_name(card, language))
	_diff.add_child(_code(CodeDiff.lines(before, after), language))
	var label := "%s %s" % ["Optimise" if verb == "optimize" else "Refactor", card.get("name", id)]
	var go := Ui.button(label, func() -> void: wants.emit({"type": "forge", "shard_id": id}), "PrimaryButton")
	_diff.add_child(Ui.hbox([go]))
	if card_ids.size() > 1:
		_diff.add_child(Ui.label("One refactor per forge.", "Faint"))


## What changes besides the code: "cost 2 → 1 · + __init__".
static func _changes(card: Dictionary, into: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(card.get("cost", 0)) != int(into.get("cost", 0)):
		parts.append("cost %d → %d" % [int(card.get("cost", 0)), int(into.get("cost", 0))])
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
		var same := (
			"%s The code is the same: the refactor is in what the card costs or does in the deck."
			% ("#" if language == "python" else "//")
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
