class_name OptionsPanel
extends PanelContainer
## The player's options, saved the moment they change (Settings). Presentation only: none of them changes a rule.

signal closed
var _tab := "Battle"


static func create() -> OptionsPanel:
	var panel := OptionsPanel.new()
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(800, 560)
	var column := Ui.vbox([Ui.hbox([Ui.label("OPTIONS", "Heading"), Ui.spacer(), Ui.button("Close  ×", _close)])], 20)
	column.add_child(Ui.label("Make the Machine feel like home. Changes save automatically.", "Muted", true))
	var tabs := Ui.hbox([], 8)
	for tab: String in ["Battle", "Audio", "Display"]:
		var choose := func() -> void:
			_tab = tab
			_rebuild()
		tabs.add_child(Ui.choice(tab, _tab == tab, choose))
	column.add_child(tabs)
	add_child(column)
	if _tab == "Audio":
		column.add_child(_row("Music volume", _slider(Settings.music_volume, _set_music)))
		column.add_child(_row("Sound effects", _slider(Settings.sound_volume, _set_sound)))
		column.add_child(Ui.button("Test sound", func() -> void: Sound.play("sfx-card-place", 0.7)))
		return
	if _tab == "Display":
		var display := func(on: bool) -> void:
			Settings.fullscreen = on
			Settings.apply_display()
		column.add_child(_row("Fullscreen", _on_off(Settings.fullscreen, display)))
		column.add_child(
			_row(
				"Reduce motion",
				_on_off(Settings.reduced_motion, func(on: bool) -> void: Settings.reduced_motion = on),
				"Calmer transitions and no shard flourishes. Background motion updates when you reopen the title."
			)
		)
		column.add_child(Ui.label("The arena and its creatures resize with the window.", "Muted", true))
		return
	column.add_child(
		_row(
			"Code playback speed",
			_speeds(),
			"The code plays on the work surface below the arena before the spell fires."
		)
	)
	column.add_child(
		_row(
			"Show what a spell will do before you cast it",
			_on_off(Settings.predictions, func(on: bool) -> void: Settings.predictions = on),
			"Its bolts, damage and block against the foes in front of you. The Programmer difficulty hides them anyway."
		)
	)
	column.add_child(
		_row("Shake the stage on heavy hits", _on_off(Settings.shake, func(on: bool) -> void: Settings.shake = on))
	)


func _row(title: String, control: Control, note := "") -> Control:
	var row := Ui.vbox([Ui.label(title, ""), control], 4)
	if note != "":
		row.add_child(Ui.label(note, "Faint", true))
	return row


func _speeds() -> Control:
	var names := {"off": "Off", "slow": "Slow", "normal": "Normal", "fast": "Fast"}
	var row := Ui.hbox([], 6)
	for speed: String in Settings.CODE_SPEEDS:
		var choose := func() -> void:
			Settings.code_speed = speed
			_saved()
			_rebuild()
		row.add_child(Ui.choice(names[speed], Settings.code_speed == speed, choose))
	return row


func _on_off(value: bool, apply: Callable) -> Control:
	var row := Ui.hbox([], 6)
	for on: bool in [true, false]:
		var choose := func() -> void:
			apply.call(on)
			_saved()
			_rebuild()
		row.add_child(Ui.choice("On" if on else "Off", value == on, choose))
	return row


func _slider(value: float, apply: Callable) -> Control:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 20)
	var percent := Ui.label("%d%%" % roundi(value * 100.0), "Subheading")
	percent.custom_minimum_size.x = 70
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(
		func(to: float) -> void:
			apply.call(to)
			percent.text = "%d%%" % roundi(to * 100.0)
			_saved()
	)
	return Ui.hbox([slider, percent], 18)


func _set_music(to: float) -> void:
	Settings.music_volume = to
	Sound.set_volumes(Settings.music_volume, Settings.sound_volume)


func _set_sound(to: float) -> void:
	Settings.sound_volume = to
	Sound.set_volumes(Settings.music_volume, Settings.sound_volume)


func _saved() -> void:
	Settings.save_file()


func _rebuild() -> void:
	Ui.clear(self)
	_build()


func _close() -> void:
	Settings.save_file()
	closed.emit()
