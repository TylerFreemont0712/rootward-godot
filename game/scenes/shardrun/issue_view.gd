class_name IssueView
extends VBoxContainer
## An Issue (ProgramIssues): a problem posted on a tracker, with a few ways to answer it. The stage the rules are in
## decides what is shown: the choices, a pick of your cards, a paradigm, three cards on offer, a focus, a question
## about your own code (run for real in the sandbox), and finally what happened.

signal wants(command: Dictionary)

var session: ShardrunSession
## The cards ticked in a pick, before the player confirms.
var _selected: Array[String] = []


static func create(run_session: ShardrunSession) -> IssueView:
	var view := IssueView.new()
	view.session = run_session
	view.add_theme_constant_override("separation", 12)
	view._build()
	return view


func _ask(command: Dictionary) -> Callable:
	return func() -> void: wants.emit(command)


func _build() -> void:
	Ui.clear(self)
	var state := session.state
	var issue: Dictionary = state.issue
	var def := ProgramIssues.definition(state, session.catalog)
	add_child(_tracker_bar(issue, def))
	add_child(_body(def, issue))
	match String(issue.stage):
		"choose":
			_choices(state, def)
		"pick":
			_pick(issue)
		"paradigm":
			_paradigms(issue)
		"offer":
			_offer(issue)
		"focus":
			_focuses(state, issue)
		"quiz":
			_quiz(issue)
		"result":
			_result(issue)


## "● Open  #342  Title" and its labels, the way an issue looks on a tracker.
func _tracker_bar(issue: Dictionary, def: Dictionary) -> Control:
	var state_chip := Ui.tint(
		Ui.label("● " + Text.t("Open" if issue.stage != "result" else "Closed"), "Subheading"),
		UiTheme.TEAL if issue.stage != "result" else UiTheme.FAINT
	)
	var title := Ui.label(Text.t(String(def.get("title", def.get("name", "")))), "Heading", true)
	var number := Ui.label("#%d" % int(issue.get("number", 1)), "Faint")
	var chips := Ui.hbox([], 6)
	for label: String in def.get("labels", []):
		chips.add_child(Ui.panel(Ui.tint(Ui.label(Text.t(label), "Faint"), UiTheme.AMBER), "Sunken"))
	return Ui.vbox([Ui.hbox([state_chip, number], 10), title, chips], 4)


func _body(def: Dictionary, issue: Dictionary) -> Control:
	var picture := Ui.picture("shardrun/" + String(def.get("picture", "")), Vector2(168, 168), "!")
	var words := Ui.vbox(
		[
			Ui.label(Text.t(String(def.get("name", ""))), "Subheading"),
			Ui.label(Text.t(String(def.get("text", ""))), "Narration", true)
		],
		6
	)
	return Ui.hbox([picture, Ui.expand(words)], 16)


func _choices(state: Dictionary, def: Dictionary) -> void:
	var choices: Array = def.choices
	for index in choices.size():
		var choice: Dictionary = choices[index]
		var affordable := ProgramIssues.can_choose(state, choice)
		var button := Ui.button(
			Text.t(String(choice.label)), _ask({"type": "issue-choose", "index": index}), "PrimaryButton"
		)
		button.disabled = not affordable
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(Ui.panel(button, "Card"))


func _pick(issue: Dictionary) -> void:
	var pick: Dictionary = issue.pick
	var needed := 1 if pick.purpose == "keep" else int(pick.count)
	var optional: bool = pick.purpose == "remove-basic"
	add_child(
		Ui.label(
			(
				Text.f("Pick %d card(s) from your deck.", [needed])
				if not optional
				else Text.f("Pick up to %d cards from your deck.", [needed])
			),
			"Subheading"
		)
	)
	var row := Ui.flow([], 8)
	for id: String in pick.options:
		var card: Dictionary = session.catalog.shards.get(id, {})
		var chosen := id in _selected
		var count := (session.state.deck as Array).count(id)
		var label := Text.t(String(card.get("name", id))) + ("  ×%d" % count if count > 1 else "")
		row.add_child(Ui.choice(label, chosen, _toggle.bind(id, needed)))
	add_child(row)
	var confirm := Ui.button(
		Text.t("Confirm"),
		func() -> void: wants.emit({"type": "issue-pick", "card_ids": _selected.duplicate()}),
		"PrimaryButton"
	)
	confirm.disabled = _selected.size() > needed or (_selected.size() < needed and not optional)
	add_child(Ui.hbox([confirm]))


func _toggle(id: String, needed: int) -> void:
	if id in _selected:
		_selected.erase(id)
	elif _selected.size() < needed:
		_selected.append(id)
	else:
		_selected.pop_front()
		_selected.append(id)
	_build()


func _paradigms(issue: Dictionary) -> void:
	add_child(Ui.label(Text.t("Choose a paradigm."), "Subheading"))
	var row := Ui.flow([], 8)
	for id: String in issue.paradigms:
		var paradigm := ProgramDraft.paradigm_of(session.catalog, id)
		var button := Ui.button(
			Text.t(String(paradigm.name)), _ask({"type": "issue-paradigm", "paradigm_id": id}), "PrimaryButton"
		)
		button.add_theme_color_override("font_color", Color(paradigm.colour))
		row.add_child(button)
	add_child(row)


func _offer(issue: Dictionary) -> void:
	add_child(Ui.label(Text.t("Take one card."), "Subheading"))
	var row := Ui.flow([], 10)
	for id: String in issue.offer.cards:
		var card: Dictionary = session.catalog.shards[id]
		var shown := id
		if bool(issue.offer.refactored) and (card.get("forge", {}) as Dictionary).has("into"):
			shown = String(card.forge.into)
		var face_card: Dictionary = session.catalog.shards[shown]
		var take := Ui.button(
			Text.f("Take %s", [Text.t(String(face_card.name))]),
			_ask({"type": "issue-take", "card_id": id}),
			"PrimaryButton"
		)
		var face := Cards.shard(face_card, session.state.language, session.show_summaries(), 7, take, false)
		face.custom_minimum_size.x = 330
		row.add_child(face)
	add_child(row)
	add_child(Ui.hbox([Ui.button(Text.t("Take nothing"), _ask({"type": "issue-take", "card_id": null}))]))


func _focuses(state: Dictionary, issue: Dictionary) -> void:
	add_child(Ui.label(Text.t("Choose another focus. The signature card you hold stays."), "Subheading"))
	var paradigm := ProgramDraft.paradigm_of(session.catalog, String(state.paradigm))
	var row := Ui.flow([], 10)
	for id: String in issue.focuses:
		var focus := ProgramDraft.focus_of(session.catalog, String(paradigm.id), id)
		var relic: Dictionary = session.catalog.relics.get(String(focus.relic), {})
		var button := Ui.button(
			Text.t(String(focus.name)), _ask({"type": "issue-focus", "focus_id": id}), "PrimaryButton"
		)
		row.add_child(
			Ui.panel(Ui.vbox([button, Ui.label(Text.t(String(relic.get("summary", ""))), "Muted", true)], 6), "Card")
		)
	add_child(row)


## A question about your own deck, run for real. While the sandbox is still running it, a note says so.
func _quiz(issue: Dictionary) -> void:
	var quiz: Dictionary = issue.quiz
	if not quiz.ready:
		add_child(Ui.label(Text.t("Running your card in the sandbox..."), "Muted"))
		return
	var plan: Dictionary = quiz.plan
	var card: Dictionary = session.catalog.shards.get(String(quiz.get("card", "")), {})
	var name := Text.t(String(card.get("name", "")))
	match String(plan.kind):
		"rubber-duck":
			add_child(
				Ui.label(Text.f("What does %s return for the bolts %s?", [name, str(quiz.input)]), "Subheading", true)
			)
			add_child(_code(String(card.code[session.state.language])))
		"off-by-one":
			add_child(
				Ui.label(
					Text.f("How many bolts does %s return for the powers %s?", [name, str(quiz.input)]),
					"Subheading",
					true
				)
			)
			add_child(_code(String(card.code[session.state.language])))
		"oracle":
			add_child(
				Ui.label(
					Text.f(
						"The test: %s on %s must return %s. Which version passes?",
						[name, str(quiz.input), str(quiz.expected)]
					),
					"Subheading",
					true
				)
			)
		"stack-overflow", "stack-overflow-blind":
			add_child(Ui.label(Text.f("A forum answer for %s. Copy it into your deck?", [name]), "Subheading", true))
			if String(quiz.code) != "":
				add_child(_code(String(quiz.code)))
				if not (quiz.diff as Dictionary).is_empty():
					var diff: Dictionary = quiz.diff
					add_child(
						Ui.tint(
							Ui.label(
								Text.f(
									"Line %d was changed: %s  →  %s",
									[
										int(diff.line) + 1,
										String(diff.before).strip_edges(),
										String(diff.after).strip_edges()
									]
								),
								"Muted",
								true
							),
							UiTheme.AMBER
						)
					)
		"big-o":
			add_child(
				Ui.label(Text.f("On %d bolts, which of your cards does less work?", [int(quiz.n)]), "Subheading", true)
			)
		"halt":
			add_child(
				Ui.label(
					Text.f(
						"Will %s finish within this layer's budget of %d operations, on %d bolts?",
						[name, int(quiz.budget), int(quiz.n)]
					),
					"Subheading",
					true
				)
			)
	var options: Array = quiz.options
	if quiz.has("versions"):
		var columns := Ui.hbox([], 10)
		var versions: Array = quiz.versions
		for index in versions.size():
			var button := Ui.button(
				Text.f("Version %s", [char(65 + index)]),
				_ask({"type": "issue-answer", "index": index}),
				"PrimaryButton"
			)
			columns.add_child(Ui.expand(Ui.vbox([button, _code(String(versions[index]))], 6)))
		add_child(columns)
		return
	var row := Ui.flow([], 8)
	for index in options.size():
		row.add_child(
			Ui.button(
				_option_text(String(options[index])), _ask({"type": "issue-answer", "index": index}), "PrimaryButton"
			)
		)
	add_child(row)


func _option_text(option: String) -> String:
	match option:
		"finishes":
			return Text.t("It finishes")
		"times-out":
			return Text.t("It times out")
		"same":
			return Text.t("The same")
		"copy":
			return Text.t("Copy it")
		"walk-away":
			return Text.t("Walk away")
	var card: Dictionary = session.catalog.shards.get(option, {})
	return Text.t(String(card.get("name", option)))


func _code(source: String) -> Control:
	var label := Label.new()
	label.text = source
	label.add_theme_font_override("font", UiTheme.code_font())
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	return Ui.panel(label, "Sunken")


func _result(issue: Dictionary) -> void:
	for line: String in issue.lines:
		add_child(Ui.label("› " + Text.sentences(line), "", true))
	add_child(Ui.hbox([Ui.button(Text.t("Close the issue"), _ask({"type": "issue-leave"}), "PrimaryButton")]))
