class_name FoundrySettingsPanel
extends OptionsPanel
## Front-end settings reuse the persistence and volume controls, with a separate layout and live motion updates.

signal changed


static func make() -> FoundrySettingsPanel:
	var panel := FoundrySettingsPanel.new()
	panel._tab = "Display"
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(1080, 680)
	var column := Ui.vbox(
		[FoundryUi.heading("THE CONTROL ROOM", FoundryUi.text("Settings", "設定"), _close), FoundryUi.rule()], 24
	)
	column.add_child(
		Ui.label(
			FoundryUi.text(
				"Make the station feel like home. Changes save automatically.", "居心地のいい場所にしよう。変更は自動で保存されるよ。"
			),
			"Muted",
			true
		)
	)
	var tabs := Ui.hbox([], 12)
	var names := {
		"Display": FoundryUi.text("Display", "画面"),
		"Audio": FoundryUi.text("Audio", "音"),
		"Battle": FoundryUi.text("Spell playback", "呪文の再生")
	}
	for tab: String in ["Display", "Audio", "Battle"]:
		var choose := func() -> void:
			_tab = tab
			_rebuild()
		var control := Ui.choice(names[tab], _tab == tab, choose)
		control.custom_minimum_size = Vector2(240, 48)
		tabs.add_child(control)
	column.add_child(tabs)
	column.add_child(Ui.spacer(0, 8))
	add_child(column)
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


func _setting(title: String, note: String, control: Control) -> Control:
	var words := Ui.vbox([Ui.label(title, "Subheading"), Ui.label(note, "Muted", true)], 8)
	words.custom_minimum_size.x = 430
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return Ui.vbox([Ui.hbox([words, control], 28), FoundryUi.rule()], 20)


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
