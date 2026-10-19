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
		[
			FoundryUi.heading(FoundryUi.text("STATION PREFERENCES", "駅の設定"), FoundryUi.text("Settings", "設定"), _close),
			FoundryUi.rule()
		],
		12
	)
	var sidebar := Ui.vbox([], 10)
	sidebar.custom_minimum_size.x = 208
	sidebar.add_child(Ui.label(FoundryUi.text("TUNE THE STATION", "駅を整える"), "Faint"))
	var names := {
		"Display": FoundryUi.text("Display", "画面"),
		"Graphics": FoundryUi.text("Graphics", "描画"),
		"Fonts": FoundryUi.text("Fonts & text", "文字とフォント"),
		"Audio": FoundryUi.text("Audio", "音"),
		"Battle": FoundryUi.text("Spell playback", "呪文の再生")
	}
	var tab_names: Array[String] = ["Display", "Graphics", "Fonts", "Audio", "Battle"]
	if StudioFiles.can_write(StudioMode.content_dir):
		names["Developer"] = StudioText.t("developer")
		tab_names.append("Developer")
	if not names.has(_tab):
		_tab = "Display"
	for tab: String in tab_names:
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
	elif _tab == "Developer":
		column.add_child(_setting(
			StudioText.t("studio_name"), StudioText.t("studio_settings_tip"),
			_on_off(Settings.studio, func(on: bool) -> void: Settings.studio = on)
		))
	elif _tab == "Graphics":
		_graphics_tab(column)
	elif _tab == "Display":
		_display_tab(column)
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


func _display_tab(column: VBoxContainer) -> void:
	var set_window := func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply_display()
	var window_note := FoundryUi.text(
		"Fullscreen is a borderless window the size of the screen, so switching to other programs stays smooth.",
		"全画面は、画面と同じ大きさの枠なしウィンドウ。ほかのアプリへの切り替えもなめらか。"
	)
	var modes := [[false, FoundryUi.text("Windowed", "ウィンドウ")], [true, FoundryUi.text("Fullscreen", "全画面")]]
	column.add_child(
		_setting(FoundryUi.text("Window", "ウィンドウ"), window_note, _pick(modes, Settings.fullscreen, set_window))
	)
	var set_size := func(size: Vector2i) -> void:
		Settings.window_size = size
		Settings.apply_display()
	var sizes: Array = [[Graphics.DEFAULT_WINDOW, FoundryUi.text("Default", "標準")]]
	for size in Graphics.WINDOW_SIZES:
		sizes.append([size, "%d × %d" % [size.x, size.y]])
	var size_note := FoundryUi.text(
		"Used when the game is not fullscreen. A size that does not fit the screen is shrunk to fit.",
		"全画面でないときの大きさ。画面に入らないときは、小さくして合わせるよ。"
	)
	column.add_child(
		_setting(FoundryUi.text("Window size", "ウィンドウの大きさ"), size_note, _pick(sizes, Settings.window_size, set_size))
	)
	if DisplayServer.get_screen_count() > 1:
		var set_screen := func(index: int) -> void:
			Settings.screen = index
			Settings.apply_display()
		var screens: Array = [[-1, FoundryUi.text("Automatic", "自動")]]
		for index in DisplayServer.get_screen_count():
			var size := DisplayServer.screen_get_size(index)
			var name := FoundryUi.text("Screen %d · %d×%d", "画面%d · %d×%d") % [index + 1, size.x, size.y]
			screens.append([index, name])
		column.add_child(
			_setting(
				FoundryUi.text("Screen", "表示する画面"),
				FoundryUi.text("Which screen the game opens on.", "ゲームを表示するモニター。"),
				_pick(screens, Settings.screen, set_screen)
			)
		)
	var set_scale := func(scale: float) -> void:
		Settings.ui_scale = scale
		Graphics.apply_ui_scale()
	var scales := [
		[0.8, FoundryUi.text("Compact", "小さめ")],
		[0.88, FoundryUi.text("Standard", "標準")],
		[1.0, FoundryUi.text("Large", "大きめ")]
	]
	column.add_child(
		_setting(
			FoundryUi.text("Interface size", "画面の部品の大きさ"),
			FoundryUi.text("Everything on screen, larger or smaller.", "画面の文字や部品を、大きく、または小さくする。"),
			_pick(scales, Settings.ui_scale, set_scale)
		)
	)
	var motion_note := FoundryUi.text(
		"Still lanterns, a resting character and immediate menu changes.", "灯りとキャラクターの動きを止め、メニューをすぐに切り替える。"
	)
	var set_motion := func(on: bool) -> void: Settings.reduced_motion = on
	column.add_child(
		_setting(FoundryUi.text("Reduce motion", "動きを減らす"), motion_note, _on_off(Settings.reduced_motion, set_motion))
	)
	var keys := FoundryUi.text("Tab moves between controls. Enter selects. Escape returns.", "Tabで移動、Enterで選択、Escで戻る。")
	column.add_child(Ui.label(keys, "Muted", true))


func _graphics_tab(column: VBoxContainer) -> void:
	var set_vsync := func(mode: String) -> void:
		Settings.vsync = mode
		Graphics.apply_vsync()
	var vsync_note := FoundryUi.text(
		(
			"On keeps the picture free of tearing. Adaptive lets it tear only when the game falls behind the screen. "
			+ "Off draws as fast as it can."
		),
		"オンで画面のずれを防ぐ。アダプティブは、画面の速さに追いつけないときだけずれる。オフはできるだけ速く描く。"
	)
	var vsyncs := [
		["on", FoundryUi.text("On", "オン")],
		["adaptive", FoundryUi.text("Adaptive", "アダプティブ")],
		["off", FoundryUi.text("Off", "オフ")]
	]
	column.add_child(
		_setting(FoundryUi.text("Vertical sync", "垂直同期"), vsync_note, _pick(vsyncs, Settings.vsync, set_vsync))
	)
	var set_limit := func(limit: int) -> void:
		Settings.frame_limit = limit
		Graphics.apply_frame_cap()
	var limits: Array = []
	for limit in Graphics.FRAME_LIMITS:
		var label := str(limit)
		if limit == Graphics.AUTO:
			label = FoundryUi.text("Auto", "自動")
		elif limit == Graphics.UNLIMITED:
			label = FoundryUi.text("Unlimited", "無制限")
		limits.append([limit, label])
	var refresh := DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
	var limit_note := (
		FoundryUi.text(
			"Auto fits your screen: %d frames a second here. A lower limit keeps the machine cooler.",
			"自動は画面に合わせる（ここでは毎秒%dフレーム）。低くすると、熱がおさえられるよ。"
		)
		% Graphics.frame_cap(refresh)
	)
	column.add_child(
		_setting(FoundryUi.text("Frame limit", "フレーム数の上限"), limit_note, _pick(limits, Settings.frame_limit, set_limit))
	)
	var set_background := func(on: bool) -> void: Settings.background_slowdown = on
	column.add_child(
		_setting(
			FoundryUi.text("In the background", "裏にあるとき"),
			FoundryUi.text(
				"Slow down while another window is in front, so the game stays cool and quiet.",
				"ほかのウィンドウが前にあるときは動きをゆるめて、熱と音をおさえる。"
			),
			_on_off(Settings.background_slowdown, set_background)
		)
	)
	var set_counter := func(on: bool) -> void: Settings.show_fps = on
	column.add_child(
		_setting(
			FoundryUi.text("Frame-rate counter", "フレームレート表示"),
			FoundryUi.text("A small readout in the corner.", "隅に小さく表示する。"),
			_on_off(Settings.show_fps, set_counter)
		)
	)
	column.add_child(Ui.label(FoundryUi.text("NEEDS A RESTART", "再起動が必要"), "Faint"))
	var set_device := func(index: int) -> void: Settings.gpu_index = index
	var ordinals := [FoundryUi.text("1st", "1つ目"), FoundryUi.text("2nd", "2つ目"), FoundryUi.text("3rd", "3つ目")]
	var devices: Array = []
	for index in Graphics.GPU_INDEXES:
		devices.append([index, FoundryUi.text("Automatic", "自動") if index == Graphics.AUTO else ordinals[index]])
	var device_note := (
		FoundryUi.text(
			"Drawing on: %s. A laptop with two graphics chips lists both; if the picture flickers, try the other one.",
			"いま使っているGPU：%s。GPUが2つあるノートPCで画面がちらつくときは、もう一方を試してみて。"
		)
		% Graphics.running_description()
	)
	column.add_child(
		_setting(
			FoundryUi.text("Graphics device", "描画に使うGPU"), device_note, _pick(devices, Settings.gpu_index, set_device)
		)
	)
	var set_renderer := func(method: String) -> void: Settings.renderer = method
	var renderers := [
		["auto", FoundryUi.text("Automatic", "自動")],
		["forward_plus", "Forward+"],
		["mobile", "Mobile"],
		["gl_compatibility", "Compatibility"]
	]
	column.add_child(
		_setting(
			FoundryUi.text("Renderer", "描画方式"),
			FoundryUi.text(
				"Forward+ is the richest, Mobile is lighter, Compatibility (OpenGL) works on the most machines.",
				"Forward+は最も高機能、Mobileは軽め、Compatibility（OpenGL）は最も多くの環境で動く。"
			),
			_pick(renderers, Settings.renderer, set_renderer)
		)
	)
	if Graphics.restart_pending(OS.get_cmdline_args(), Settings.gpu_index, Settings.renderer):
		var restart := FoundryUi.text("Restart to use the new graphics device or renderer.", "新しいGPUや描画方式を使うには、再起動してね。")
		var again := FoundryUi.button(FoundryUi.text("Restart now", "今すぐ再起動"), Graphics.relaunch, true)
		column.add_child(Ui.hbox([Ui.label(restart, "Subheading"), again], 16))


## A row of choices, one of them chosen: `options` is [[value, label], ...], and picking one calls `apply(value)`.
func _pick(options: Array, current: Variant, apply: Callable) -> Control:
	var row := Ui.flow([], 8)
	row.custom_minimum_size.x = 420
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for option: Array in options:
		var value: Variant = option[0]
		var choose := func() -> void:
			apply.call(value)
			_saved()
			_rebuild()
		row.add_child(Ui.choice(String(option[1]), value == current, choose))
	return row


func _font_choices(column: VBoxContainer) -> void:
	var reading_modes := [
		["hiragana", Text.t("Hiragana")],
		["kanji", Text.t("Kanji")]
	]
	column.add_child(
		_setting(
			Text.t("Japanese reading"),
			Text.t("Choose hiragana or standard Japanese with kanji. You can change this in Settings anytime."),
			_pick(reading_modes, String(Game.profile.get("japanese_reading", "hiragana")), _choose_reading)
		)
	)
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
		FoundryUi.button(
			FoundryUi.text("Use default font", "標準のフォントに戻す"), _choose_font.bind(Settings.DEFAULT_FONT), false, true
		)
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


func _choose_reading(mode: String) -> void:
	if mode not in ["hiragana", "kanji"] or Game.profile.is_empty():
		return
	Game.profile.japanese_reading = mode
	Game.profiles.save_profile(Game.profile)
	Text.setup(String(Game.profile.get("preferred_language", "en")), mode)


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
				Ui.tint(
					Ui.label(
						FoundryUi.text("HP 72 / 100    Mana 3    Layer IV", "HP 72 / 100    マナ 3    第4階層"), "", true
					),
					UiTheme.TEAL
				),
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
