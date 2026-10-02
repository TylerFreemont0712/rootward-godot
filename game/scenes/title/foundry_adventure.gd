class_name FoundryAdventurePanel
extends PanelContainer
## A departure desk, before handing off to the existing run. It never builds or changes the Shardrun interface.

signal closed
signal character_requested
signal records_requested
signal help_requested
signal start_requested(sandbox: bool)
signal continue_requested
signal trial_requested

const MODES: Array[Dictionary] = [
	{"id": "program", "name": "Shardrun"},
	{"id": "spellbook", "name": "Spellforge"},
	{"id": "deck", "name": "Card Shardrun"},
]

var _tab := "descent"


static func make() -> FoundryAdventurePanel:
	var panel := FoundryAdventurePanel.new()
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(700, 440)
	var column := Ui.vbox(
		[
			FoundryUi.heading(
				"DEPARTURE / SURFACE STATION", FoundryUi.text("Adventure", "冒険"), func() -> void: closed.emit()
			),
			FoundryUi.rule()
		],
		8
	)
	var tabs := Ui.hbox([], 8)
	for tab: String in ["descent", "pip"]:
		var choose := func() -> void:
			_tab = tab
			_rebuild()
		tabs.add_child(
			Ui.choice(
				FoundryUi.text("Descent", "冒険へ") if tab == "descent" else FoundryUi.text("Pip's travels", "ピップの旅"),
				_tab == tab,
				choose
			)
		)
	column.add_child(tabs)
	if _tab == "pip":
		_tutorial(column)
	else:
		_descent(column)
	add_child(column)


func _descent(column: VBoxContainer) -> void:
	var modes := Ui.hbox([], 8)
	for mode: Dictionary in MODES:
		if mode.id == "deck" and not (Game.sessions.deck as ShardrunSession).in_progress():
			continue
		var choose := func() -> void:
			Game.use(mode.id)
			Settings.save_file()
			_rebuild()
		modes.add_child(Ui.choice(mode.name, Settings.playstyle == mode.id, choose))
	column.add_child(modes)
	var character := FoundryUi.action(
		FoundryUi.text("Artificer", "クラフター"),
		_skin_name() + FoundryUi.text(" · Class & skin", " · クラスとすがた"),
		func() -> void: character_requested.emit()
	)
	column.add_child(character)
	var session := Game.session
	if session.saves.problem != "":
		column.add_child(Ui.tint(Ui.label(session.saves.problem, "Muted", true), UiTheme.WARN))
	if session.in_progress():
		var where: String = ShardrunRules.layer_of(session.state, session.catalog).name
		var summary := (
			"%s · %s · %d/%d HP"
			% [
				where,
				String(session.state.language).capitalize(),
				int(session.state.integrity),
				int(session.state.integrity_max)
			]
		)
		column.add_child(
			FoundryUi.action(
				FoundryUi.text("Continue descent", "冒険のつづき"), summary, func() -> void: continue_requested.emit(), true
			)
		)
	else:
		column.add_child(
			Ui.label(
				FoundryUi.text("The lift is waiting. Prepare your next descent.", "リフトが待っている。次の冒険の準備をしよう。"),
				"Muted",
				true
			)
		)
	var usable := Game.languages()
	var runtime := Ui.hbox([], 8)
	for language: String in SandboxJob.LANGUAGES:
		var choose := func() -> void:
			Settings.language = language
			Game.remember_profile_settings()
			Settings.save_file()
			_rebuild()
		var control := Ui.choice(
			"Python" if language == "python" else "JavaScript", Settings.language == language, choose
		)
		control.disabled = language not in usable
		runtime.add_child(control)
	var challenge := OptionButton.new()
	var difficulties: Array = Game.display_catalog().config.difficulties
	for difficulty: Dictionary in difficulties:
		challenge.add_item(difficulty.name)
		if difficulty.id == Settings.difficulty:
			challenge.selected = challenge.item_count - 1
	challenge.item_selected.connect(
		func(index: int) -> void:
			Settings.difficulty = difficulties[index].id
			Game.remember_profile_settings()
			Settings.save_file()
	)
	var preferences := Ui.hbox(
		[
			Ui.vbox([Ui.label(FoundryUi.text("LANGUAGE", "言語"), "Faint"), runtime], 4),
			Ui.spacer(),
			Ui.vbox([Ui.label(FoundryUi.text("CHALLENGE", "難しさ"), "Faint"), challenge], 4)
		],
		16
	)
	column.add_child(preferences)
	column.add_child(FoundryUi.rule())
	var start := FoundryUi.button(
		FoundryUi.text("Begin a new descent", "新しい冒険を始める"),
		func() -> void: start_requested.emit(false),
		not session.in_progress()
	)
	start.disabled = Settings.language not in usable
	var actions := Ui.hbox([start], 10)
	if Game.dev_tools():
		var sandbox := FoundryUi.button(
			FoundryUi.text("Sandbox run", "実験モード"), func() -> void: start_requested.emit(true), false, true
		)
		sandbox.disabled = start.disabled
		actions.add_child(sandbox)
	column.add_child(actions)
	if usable.is_empty():
		column.add_child(
			Ui.tint(
				Ui.label(
					FoundryUi.text(
						"Spell runtime unavailable: scripts/fetch-sandbox.sh", "呪文の環境がないよ: scripts/fetch-sandbox.sh"
					),
					"Muted",
					true
				),
				UiTheme.FAIL
			)
		)
	column.add_child(
		Ui.hbox(
			[
				FoundryUi.button(
					FoundryUi.text("Records", "記録"), func() -> void: records_requested.emit(), false, true
				),
				FoundryUi.button(
					FoundryUi.text("Field guide", "遊び方"), func() -> void: help_requested.emit(), false, true
				)
			],
			12
		)
	)


func _tutorial(column: VBoxContainer) -> void:
	column.add_child(Ui.label(FoundryUi.text("An optional first journey", "はじめての旅を、好きなときに"), "Heading"))
	column.add_child(
		Ui.label(
			FoundryUi.text(
				(
					"Travel with Pip to learn how shards become spells. Follow a short guided descent, "
					+ "then return to your own adventure whenever you like."
				),
				"ピップと旅をして、シャードから呪文を作る方法を学ぼう。短い案内つきの冒険のあと、好きなときに自分の冒険へ戻れるよ。"
			),
			"Muted",
			true
		)
	)
	column.add_child(
		Ui.label(
			FoundryUi.text("10–15 minutes · Saved separately from your adventure", "10〜15分 · 冒険とは別に保存"), "Faint", true
		)
	)
	var active: bool = (
		Game.trial_session != null
		and Game.trial_session.has_run()
		and not Game.trial_session.state.get("trial", {}).get("done", false)
	)
	column.add_child(
		FoundryUi.button(
			(
				FoundryUi.text("Continue tutorial", "チュートリアルのつづき")
				if active
				else FoundryUi.text("Start tutorial", "チュートリアルを始める")
			),
			func() -> void: trial_requested.emit(),
			true
		)
	)


func refresh() -> void:
	_rebuild()


func _rebuild() -> void:
	FoundryUi.rebuild(self, _build)


static func _skin_name() -> String:
	for look: Dictionary in SkinSelectionPanel.looks():
		if look.id == Settings.character_skin:
			return look.name
	return Settings.character_skin.capitalize()
