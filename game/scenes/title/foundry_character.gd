class_name FoundryCharacterPanel
extends SkinSelectionPanel
## A fitting room and rehearsal desk. Browsing is temporary; only Use this skin saves equipment.

const CLASSES: Array[Dictionary] = [
	{"id": "artificer", "name": "Artificer", "available": true, "skins": ["vesper", "emberfox", "shibu", "dummy"]}
]
var selected_class := "artificer"
var rehearsal: FoundryRehearsal
var _portrait: TextureRect
var _controls: VBoxContainer
var _tab := "Motion"
var _timeline: HSlider
var _status: Label
var _pause: Button


static func make() -> FoundryCharacterPanel:
	var panel := FoundryCharacterPanel.new()
	panel.theme = FoundryUi.theme()
	panel.theme.default_font_size = 18
	panel.theme.set_font_size("font_size", "Heading", 24)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel._build()
	return panel


func _ready() -> void:
	_arrange(false)


func _build() -> void:
	custom_minimum_size = Vector2(1520, 760)
	_looks = looks().filter(
		func(look: Dictionary) -> bool: return look.id in CLASSES[0].skins or look.id not in Settings.CHARACTER_SKINS
	)
	for i in _looks.size():
		if _looks[i].id == Settings.character_skin:
			_at = i
	var column := Ui.vbox(
		[FoundryUi.heading("WARDROBE / REHEARSAL", FoundryUi.text("Character", "キャラクター"), _close), FoundryUi.rule()], 12
	)
	var wardrobe := Ui.vbox([], 10)
	wardrobe.custom_minimum_size.x = 240
	wardrobe.add_child(Ui.label(FoundryUi.text("CLASS", "クラス"), "Faint"))
	for entry: Dictionary in CLASSES:
		wardrobe.add_child(Ui.choice(entry.name, selected_class == entry.id, func() -> void: selected_class = entry.id))
	wardrobe.add_child(Ui.label(FoundryUi.text("More classes will arrive later.", "新しいクラスはこれから。"), "Muted", true))
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.custom_minimum_size = Vector2(240, 232)
	_portrait.gui_input.connect(_on_wheel)
	wardrobe.add_child(Ui.panel(_portrait, "Card"))
	_name = Ui.label("", "Heading", true)
	_epithet = Ui.label("", "Faint", true)
	_note = Ui.label("", "Muted", true)
	wardrobe.add_child(_name)
	wardrobe.add_child(_epithet)
	wardrobe.add_child(
		Ui.hbox(
			[
				FoundryUi.button(FoundryUi.text("Previous", "前へ"), _turn.bind(-1)),
				Ui.spacer(),
				FoundryUi.button(FoundryUi.text("Next", "次へ"), _turn.bind(1))
			],
			8
		)
	)
	_equip = FoundryUi.button("", _equip_current, true)
	wardrobe.add_child(_equip)
	wardrobe.add_child(_note)
	wardrobe.add_child(
		Ui.label(FoundryUi.text("Browsing never changes your equipped skin.", "試着だけでは、保存したすがたは変わらないよ。"), "Muted", true)
	)
	rehearsal = FoundryRehearsal.new()
	rehearsal.custom_minimum_size = Vector2(690, 580)
	rehearsal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rehearsal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rehearsal.skin_ready.connect(_build_controls)
	var stage := Ui.vbox([Ui.label(FoundryUi.text("THE PRACTICE RING", "練習の魔法陣"), "Faint"), rehearsal], 8)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_controls = Ui.vbox([], 14)
	_controls.custom_minimum_size.x = 430
	var desk := Ui.scroll(_controls)
	desk.custom_minimum_size.x = 430
	var body := Ui.hbox([wardrobe, stage, desk], 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	add_child(column)
	_arrange(false)


func _arrange(_animate := true) -> void:
	var look := _looks[_at]
	_name.text = look.name
	_epithet.text = look.epithet
	_note.text = FoundryUi.text("Try a move, inspect a pose, or write a circle in the air.", "動きやポーズ、空中の魔法陣を試してみよう。")
	_portrait.texture = load(look.portrait) as Texture2D if ResourceLoader.exists(look.portrait) else null
	_equip.text = (
		FoundryUi.text("Current skin", "今のすがた")
		if look.id == Settings.character_skin
		else FoundryUi.text("Use this skin", "このすがたにする")
	)
	_equip.disabled = look.id == Settings.character_skin
	if rehearsal.is_inside_tree():
		rehearsal.set_skin(look.id)


func _equip_current() -> void:
	var id: String = _looks[_at].id
	if id == Settings.character_skin:
		return
	Settings.character_skin = id
	Game.remember_avatar()
	Settings.save_file()
	_equip.text = FoundryUi.text("Current skin", "今のすがた")
	_equip.disabled = true
	skin_selected.emit(id)


func _build_controls() -> void:
	Ui.clear(_controls)
	_timeline = null
	_status = null
	_pause = null
	var tabs := Ui.hbox([], 8)
	for tab: String in ["Motion", "Spells", "View"]:
		var choose := func() -> void:
			_tab = tab
			_build_controls()
		tabs.add_child(
			Ui.choice(FoundryUi.text(tab, {"Motion": "動き", "Spells": "呪文", "View": "見え方"}[tab]), _tab == tab, choose)
		)
	_controls.add_child(tabs)
	_controls.add_child(FoundryUi.rule())
	if _tab == "Motion":
		_motion_controls()
	elif _tab == "Spells":
		_spell_controls()
	else:
		_view_controls()
	_controls.add_child(
		Ui.label(FoundryUi.text("Rehearsal options affect this stage only.", "練習の設定は、この場所だけに反映されるよ。"), "Muted", true)
	)


func _motion_controls() -> void:
	_controls.add_child(Ui.label(FoundryUi.text("Animation", "アニメーション"), "Subheading"))
	var clips := rehearsal.clips()
	var picker := OptionButton.new()
	for id: String in clips:
		picker.add_item(id.replace("-", " ").capitalize())
	picker.selected = maxi(0, clips.find(rehearsal.clip))
	picker.disabled = clips.is_empty()
	picker.item_selected.connect(func(index: int) -> void: rehearsal.play(clips[index]))
	_controls.add_child(picker)
	_controls.add_child(
		FoundryUi.button(
			FoundryUi.text("Play animation", "動きを再生"), func() -> void: rehearsal.play(rehearsal.clip), true
		)
	)
	_playback_controls()
	_controls.add_child(
		Ui.hbox(
			[
				FoundryUi.button(FoundryUi.text("‹ Frame", "‹ コマ"), rehearsal.step.bind(-1)),
				FoundryUi.button(FoundryUi.text("Frame ›", "コマ ›"), rehearsal.step.bind(1))
			],
			8
		)
	)
	_timeline = HSlider.new()
	_timeline.min_value = 0.0
	_timeline.max_value = maxf(0.01, rehearsal.duration())
	_timeline.step = 1.0 / 30.0
	_timeline.value_changed.connect(rehearsal.seek)
	_controls.add_child(_timeline)
	_status = Ui.label("", "Code", true)
	_controls.add_child(_status)
	var reset_pose := func() -> void:
		rehearsal.play(StageCharacter.IDLE)
		rehearsal.seek(0.0)
	_controls.add_child(FoundryUi.button(FoundryUi.text("Reset pose", "ポーズを戻す"), reset_pose))


func _playback_controls() -> void:
	_pause = FoundryUi.button("", func() -> void: rehearsal.set_paused(not rehearsal.paused))
	_controls.add_child(_pause)
	_controls.add_child(Ui.label(FoundryUi.text("Playback speed", "再生速度"), "Faint"))
	var speeds := Ui.hbox([], 6)
	for speed: float in [0.25, 0.5, 1.0, 1.5]:
		var set_speed := func() -> void:
			rehearsal.speed = speed
			_build_controls()
		speeds.add_child(Ui.choice("%sx" % str(speed), is_equal_approx(speed, rehearsal.speed), set_speed))
	_controls.add_child(speeds)
	var toggle_loop := func() -> void:
		rehearsal.looping = not rehearsal.looping
		_build_controls()
	_controls.add_child(Ui.choice(FoundryUi.text("Loop animation", "くり返す"), rehearsal.looping, toggle_loop))


func _spell_controls() -> void:
	_controls.add_child(Ui.label(FoundryUi.text("Cast animation", "詠唱の動き"), "Subheading"))
	var casts := rehearsal.clips().filter(func(id: String) -> bool: return id.begins_with("cast-"))
	var choose := OptionButton.new()
	for id: String in casts:
		choose.add_item(id.replace("-", " ").capitalize())
	choose.disabled = casts.is_empty()
	choose.item_selected.connect(func(index: int) -> void: rehearsal.clip = casts[index])
	choose.selected = maxi(0, casts.find(rehearsal.clip))
	if rehearsal.clip not in casts and not casts.is_empty():
		rehearsal.clip = casts[0]
	_controls.add_child(choose)
	_controls.add_child(
		_picker(
			FoundryUi.text("Circle tier", "魔法陣の段階"),
			["I · Simple", "II · Inscribed", "III · Layered", "IV · Grand"],
			rehearsal.tier,
			func(index: int) -> void: rehearsal.tier = index
		)
	)
	_controls.add_child(
		_picker(
			FoundryUi.text("Element", "属性"),
			["Arcane", "Fire", "Frost", "Spark"],
			["none", "fire", "frost", "spark"].find(rehearsal.element),
			func(index: int) -> void: rehearsal.element = ["none", "fire", "frost", "spark"][index]
		)
	)
	var toggle_circles := func() -> void:
		rehearsal.circles = not rehearsal.circles
		_build_controls()
	_controls.add_child(Ui.choice(FoundryUi.text("Show cast circles", "詠唱の魔法陣を表示"), rehearsal.circles, toggle_circles))
	var cast := FoundryUi.button(
		FoundryUi.text("Test spell", "呪文を試す"), func() -> void: rehearsal.play(rehearsal.clip), true
	)
	cast.disabled = casts.is_empty()
	_controls.add_child(cast)
	_controls.add_child(FoundryUi.button(FoundryUi.text("Circle only", "魔法陣だけ試す"), rehearsal.preview_circle))
	_playback_controls()
	_controls.add_child(
		Ui.label(
			FoundryUi.text(
				"The same circles and moves used on the journey, with harmless practice bolts.",
				"冒険と同じ動きと魔法陣。練習の光なので、ダメージはないよ。"
			),
			"Muted",
			true
		)
	)


func _view_controls() -> void:
	_controls.add_child(Ui.label(FoundryUi.text("Inspect the silhouette", "すがたをよく見る"), "Subheading"))
	var set_angle := func(index: int) -> void:
		rehearsal.view_angle = [35.0, 0.0, 90.0, 180.0][index]
		rehearsal._fit()
	var view := _picker(
		FoundryUi.text("Camera angle", "見る角度"),
		["Three-quarter", "Front", "Side", "Back"],
		[35.0, 0.0, 90.0, 180.0].find(rehearsal.view_angle),
		set_angle
	)
	(view.get_child(1) as OptionButton).disabled = rehearsal.hero.character == null
	_controls.add_child(view)
	_controls.add_child(
		Ui.label(FoundryUi.text("Painted skins keep their drawn viewpoint.", "描かれたすがたは、絵の角度で表示されるよ。"), "Muted", true)
	)
	var zoom := HSlider.new()
	zoom.min_value = 0.7
	zoom.max_value = 1.2
	zoom.step = 0.05
	zoom.value = rehearsal.zoom
	zoom.value_changed.connect(
		func(value: float) -> void:
			rehearsal.zoom = value
			rehearsal._fit()
	)
	_controls.add_child(Ui.label(FoundryUi.text("Zoom", "大きさ"), "Faint"))
	_controls.add_child(zoom)
	for entry: Array in [["Floor guides", "床の目印", "marks"], ["High contrast", "背景を暗く", "contrast"]]:
		var toggle_view := func() -> void:
			rehearsal.set(entry[2], not bool(rehearsal.get(entry[2])))
			rehearsal.queue_redraw()
			_build_controls()
		_controls.add_child(Ui.choice(FoundryUi.text(entry[0], entry[1]), bool(rehearsal.get(entry[2])), toggle_view))


static func _picker(title: String, names: Array, index: int, changed: Callable) -> Control:
	var picker := OptionButton.new()
	for label: String in names:
		picker.add_item(label)
	picker.selected = maxi(0, index)
	picker.item_selected.connect(changed)
	return Ui.vbox([Ui.label(title, "Faint"), picker], 6)


func _process(_delta: float) -> void:
	if _pause != null:
		_pause.text = FoundryUi.text("Resume", "再開") if rehearsal.paused else FoundryUi.text("Pause", "一時停止")
	if _timeline != null:
		_timeline.max_value = maxf(0.01, rehearsal.duration())
		if not _timeline.has_focus():
			_timeline.set_value_no_signal(minf(rehearsal._elapsed, rehearsal.duration()))
	if _status != null:
		_status.text = (
			"%s\n%.2f / %.2f s" % [rehearsal.clip, minf(rehearsal._elapsed, rehearsal.duration()), rehearsal.duration()]
		)
