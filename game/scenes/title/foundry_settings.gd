class_name FoundrySettingsPanel
extends OptionsPanel
## Front-end settings reuse the persistence and volume controls, with a separate layout and live motion updates.

signal changed


static func make() -> FoundrySettingsPanel:
	var panel := FoundrySettingsPanel.new()
	panel._tab = "Display"
	panel.theme_type_variation = "Overlay"
	panel.theme = FoundryUi.theme()
	panel.theme.default_font_size = 18
	panel.theme.set_font_size("font_size", "Heading", 24)
	panel.theme.set_font_size("font_size", "Muted", 16)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(1520, 760)
	var column := Ui.vbox(
		[FoundryUi.heading("STATION PREFERENCES", FoundryUi.text("Settings", "設定"), _close), FoundryUi.rule()], 12
	)
	var sidebar := Ui.vbox([], 10)
	sidebar.custom_minimum_size.x = 208
	sidebar.add_child(Ui.label(FoundryUi.text("TUNE THE STATION", "駅を整える"), "Faint"))
	var names := {
		"Display": FoundryUi.text("Display", "画面"),
		"Fonts": FoundryUi.text("Fonts & text", "文字とフォント"),
		"Audio": FoundryUi.text("Audio", "音"),
		"Battle": FoundryUi.text("Spell playback", "呪文の再生")
	}
	for tab: String in ["Display", "Fonts", "Audio", "Battle"]:
		var choose := func() -> void:
			_tab = tab
			_rebuild()
		var control := Ui.choice(names[tab], _tab == tab, choose)
		control.alignment = HORIZONTAL_ALIGNMENT_LEFT
		control.custom_minimum_size = Vector2(208, 42)
		sidebar.add_child(control)
	sidebar.add_child(Ui.expand(Ui.spacer(), true))
	sidebar.add_child(
		Ui.label(FoundryUi.text("Your station.\nYour pace.\nYour lettering.", "自分の駅。\n自分の速さ。\n自分の文字。"), "Muted", true)
	)
	var page := Ui.vbox([], 22)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(Ui.label(names[_tab], "Heading"))
	page.add_child(Ui.label(FoundryUi.text("Changes save automatically.", "変更は自動で保存されるよ。"), "Muted"))
	var reading := Ui.scroll(page)
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := Ui.hbox([sidebar, FoundryUi.rule(), reading], 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	add_child(column)
	column = page
	if _tab == "Fonts":
		_font_choices(column)
		return
	if _tab == "Audio":
		column.add_child(
			_setting(
				FoundryUi.text("Music", "音楽"),
				FoundryUi.text("The sound of the station and the journey below.", "駅と、その下に続く旅の音楽。"),
				_slider(Settings.music_volume, _set_music)
			)
		)
		column.add_child(
			_setting(
				FoundryUi.text("Sound effects", "効果音"),
				FoundryUi.text("Cards, spells and small discoveries.", "カード、呪文、小さな発見の音。"),
				_slider(Settings.sound_volume, _set_sound)
			)
		)
		column.add_child(
			Ui.hbox(
				[
					FoundryUi.button(
						FoundryUi.text("Test sound", "音を試す"), func() -> void: Sound.play("sfx-card-place", 0.7)
					)
				]
			)
		)
	elif _tab == "Display":
		var fullscreen := func(on: bool) -> void:
			Settings.fullscreen = on
			Settings.apply_display()
		column.add_child(
			_setting(
				FoundryUi.text("Fullscreen", "全画面"),
				FoundryUi.text("Give the foundry a little more room.", "工房を大きく表示する。"),
				_on_off(Settings.fullscreen, fullscreen)
			)
		)
		column.add_child(
			_setting(
				FoundryUi.text("Reduce motion", "動きを減らす"),
				FoundryUi.text(
					"Still lanterns, a resting character and immediate menu changes.", "灯りとキャラクターの動きを止め、メニューをすぐに切り替える。"
				),
				_on_off(Settings.reduced_motion, func(on: bool) -> void: Settings.reduced_motion = on)
			)
		)
		column.add_child(
			Ui.label(
				FoundryUi.text("Tab moves between controls. Enter selects. Escape returns.", "Tabで移動、Enterで選択、Escで戻る。"),
				"Muted",
				true
			)
		)
	else:
		column.add_child(
			_setting(
				FoundryUi.text("Code playback speed", "コードの再生速度"),
				FoundryUi.text("Choose the pace of a spell's code before it fires.", "呪文が発動する前のコードの速さ。"),
				_speeds()
			)
		)
		column.add_child(
			_setting(
				FoundryUi.text("Spell predictions", "呪文の予測"),
				FoundryUi.text("Show damage and block where your challenge allows it.", "難しさの設定に応じて、ダメージと防御を予測する。"),
				_on_off(Settings.predictions, func(on: bool) -> void: Settings.predictions = on)
			)
		)
		column.add_child(
			_setting(
				FoundryUi.text("Impact shake", "衝撃の揺れ"),
				FoundryUi.text("A small shake on heavy hits.", "強い攻撃で少し画面を揺らす。"),
				_on_off(Settings.shake, func(on: bool) -> void: Settings.shake = on)
			)
		)


func _font_choices(column: VBoxContainer) -> void:
	var choices := Ui.vbox([], 12)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(Ui.label(FoundryUi.text("Choose the voice of your journey", "冒険の文字を選ぼう"), "Subheading"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for id: String in UiFonts.CHOICES:
		var spec: Array = UiFonts.CHOICES[id]
		var pick := Ui.choice(String(spec[0]), Settings.font_style == id, _choose_font.bind(id))
		pick.name = "Font_" + id
		pick.custom_minimum_size = Vector2(330, 40)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.add_theme_font_override("font", UiTheme.code_font(600) if id == "default" else UiFonts.face(id, 600))
		var note := Ui.label(FoundryUi.text(spec[1], spec[2]), "Muted", true)
		var sample := Ui.vbox([pick, note], 6)
		sample.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(Ui.panel(sample, "Card"))
	choices.add_child(grid)
	choices.add_child(
		Ui.label(
			FoundryUi.text(
				"Menus, cards and stories use your selected face. Code keeps its familiar spacing.",
				"メニュー、カード、物語の文字が変わるよ。コードの文字幅はそのまま。"
			),
			"Muted",
			true
		)
	)
	choices.add_child(
		FoundryUi.button(FoundryUi.text("Restore current font", "今のフォントに戻す"), _choose_font.bind("default"), false, true)
	)
	var preview := Ui.panel(_font_preview(), "Sunken")
	preview.custom_minimum_size.x = 410
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(Ui.hbox([choices, preview], 24))


func _choose_font(id: String) -> void:
	if not UiFonts.CHOICES.has(id):
		return
	Settings.font_style = id
	UiTheme.refresh_fonts()
	_saved()
	_rebuild()


func _font_preview() -> VBoxContainer:
	return (
		Ui
		. vbox(
			[
				Ui.label(FoundryUi.text("LIVE PREVIEW", "プレビュー"), "Faint"),
				Ui.label(FoundryUi.text("Beneath the Rootward", "根の下へ続く旅"), "Heading", true),
				FoundryUi.rule(),
				Ui.label(FoundryUi.text("A lantern in the dark", "暗闇を照らす灯り"), "Subheading", true),
				Ui.label(
					FoundryUi.text(
						(
							"Beyond the copper gates, roots remember every journey. "
							+ "Gather a shard, follow the light and write your own spell."
						),
						"真鍮の門の向こうで、根は冒険を覚えている。シャードを集め、灯りを追い、自分の呪文を書こう。"
					),
					"",
					true
				),
				Ui.tint(Ui.label("HP 72 / 100    Mana 3    Layer IV", "", true), UiTheme.TEAL),
				Ui.panel(Ui.label(FoundryUi.text("Continue the journey  ›", "冒険を続ける  ›"), "Subheading"), "Card"),
				FoundryUi.rule(),
				Ui.label(FoundryUi.text("Source / unchanged spacing", "コード / 変わらない文字幅"), "Faint"),
				Ui.label("def amplify(bolts):\n    return power + 3", "Code"),
				Ui.label("Aa Bb 0123456789 · λ ◆ →\n旅のヒントを見つけよう。", "Muted", true),
			],
			16
		)
	)


func _setting(title: String, note: String, control: Control) -> Control:
	var words := Ui.vbox([Ui.label(title, "Subheading"), Ui.label(note, "Muted", true)], 4)
	words.custom_minimum_size.x = 440
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.vbox([Ui.hbox([words, control], 10), FoundryUi.rule()], 10)


func _on_off(value: bool, apply: Callable) -> Control:
	var row := Ui.hbox([], 8)
	for on: bool in [true, false]:
		var choose := func() -> void:
			apply.call(on)
			_saved()
			_rebuild()
		row.add_child(Ui.choice(FoundryUi.text("On", "オン") if on else FoundryUi.text("Off", "オフ"), value == on, choose))
	return row


func _saved() -> void:
	super._saved()
	changed.emit()


func _rebuild() -> void:
	FoundryUi.rebuild(self, _build)


func _slider(value: float, apply: Callable) -> Control:
	var row := super._slider(value, apply)
	(row.get_child(0) as Control).custom_minimum_size.x = 280
	(row.get_child(1) as Control).custom_minimum_size.x = 50
	return row
