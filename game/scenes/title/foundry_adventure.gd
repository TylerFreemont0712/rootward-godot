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


static func make() -> FoundryAdventurePanel:
	var panel := FoundryAdventurePanel.new()
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(1030, 760)
	var column := Ui.vbox(
		[
			FoundryUi.heading(
				"DEPARTURE / SURFACE STATION", FoundryUi.text("Adventure", "冒険"), func() -> void: closed.emit()
			),
			FoundryUi.rule()
		],
		14
	)
	column.add_child(
		Ui.label(
			FoundryUi.text("The lift is waiting. Prepare your next descent.", "リフトが待っている。次の冒険の準備をしよう。"), "Muted", true
		)
	)
	var modes := Ui.hbox([], 12)
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
		_skin_name() + FoundryUi.text(" · Choose class & skin", " · クラスとすがたを選ぶ"),
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
				FoundryUi.text("No descent underway. A fresh journey awaits.", "冒険はまだ始まっていない。新しい旅が待っているよ。"), "Faint"
			)
		)
	var runtime := Ui.hbox([Ui.label(FoundryUi.text("LANGUAGE", "言語"), "Faint"), Ui.spacer()], 8)
	var usable := Game.languages()
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
	column.add_child(runtime)
	var challenge := Ui.hbox([Ui.label(FoundryUi.text("CHALLENGE", "難しさ"), "Faint"), Ui.spacer()], 8)
	for difficulty: Dictionary in Game.display_catalog().config.difficulties:
		var choose := func() -> void:
			Settings.difficulty = difficulty.id
			Game.remember_profile_settings()
			Settings.save_file()
			_rebuild()
		var control := Ui.choice(difficulty.name, Settings.difficulty == difficulty.id, choose)
		control.tooltip_text = difficulty.summary
		challenge.add_child(control)
	column.add_child(challenge)
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
						"The spell runtime is unavailable. Install it with scripts/fetch-sandbox.sh.",
						"呪文を動かす環境がないよ。scripts/fetch-sandbox.shでインストールしてね。"
					),
					"Muted",
					true
				),
				UiTheme.FAIL
			)
		)
	column.add_child(FoundryUi.rule())
	var trial_open: bool = (
		Game.trial_session != null
		and Game.trial_session.has_run()
		and not Game.trial_session.state.get("trial", {}).get("done", false)
	)
	var pip := (
		FoundryUi.text("Continue Pip's travels", "ピップの旅のつづき")
		if trial_open
		else FoundryUi.text("Pip's travels", "ピップの旅")
	)
	column.add_child(
		FoundryUi.action(
			pip,
			FoundryUi.text("A guided first descent · 10–15 minutes", "案内つきの最初の冒険 · 10〜15分"),
			func() -> void: trial_requested.emit()
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
			]
		)
	)
	add_child(column)


func refresh() -> void:
	_rebuild()


func _rebuild() -> void:
	FoundryUi.rebuild(self, _build)


static func _skin_name() -> String:
	for look: Dictionary in SkinSelectionPanel.looks():
		if look.id == Settings.character_skin:
			return look.name
	return Settings.character_skin.capitalize()
