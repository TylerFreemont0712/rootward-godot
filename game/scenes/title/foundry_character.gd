class_name FoundryCharacterPanel
extends SkinSelectionPanel
## A fitting room and rehearsal desk. Browsing is temporary; only Use this skin saves equipment.

const CLASSES: Array[Dictionary] = [
	{
		"id": "artificer",
		"name": "Artificer",
		"ja": "工匠",
		"available": true,
		"skins": ["vesper", "emberfox", "shibu", "dummy"]
	},
	{"id": "ward-duelist", "name": "Ward Duelist", "ja": "結界の決闘者", "available": false},
	{"id": "storm-cartographer", "name": "Storm Cartographer", "ja": "嵐の地図師", "available": false},
	{"id": "ember-alchemist", "name": "Ember Alchemist", "ja": "残り火の錬金術師", "available": false},
	{"id": "thorn-compiler", "name": "Thorn Compiler", "ja": "茨のコンパイラ", "available": false},
	{"id": "rootglass-lancer", "name": "Rootglass Lancer", "ja": "根硝子の槍使い", "available": false},
	{"id": "star-thread-witch", "name": "Star-Thread Witch", "ja": "星糸の魔女", "available": false},
	{"id": "comet-scribe", "name": "Comet Scribe", "ja": "彗星の書記", "available": false},
	{"id": "pocket-shardrunner", "name": "Pocket Shardrunner", "ja": "小さなシャードランナー", "available": false},
]
const WHEEL_SCALE := 0.52
var selected_class := "artificer"
var rehearsal: FoundryRehearsal
var _controls: VBoxContainer
var _tab := "Skins"
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
	var classes := Ui.vbox([Ui.label(FoundryUi.text("CLASS", "クラス"), "Faint")], 8)
	classes.custom_minimum_size.x = 220
	for entry: Dictionary in CLASSES:
		classes.add_child(_class_button(entry))
	classes.add_child(Ui.label(FoundryUi.text("More classes will arrive later.", "新しいクラスはこれから。"), "Muted", true))

	rehearsal = FoundryRehearsal.new()
	rehearsal.custom_minimum_size = Vector2(650, 580)
	rehearsal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rehearsal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rehearsal.skin_ready.connect(_refresh_rehearsal_controls)
	var stage := Ui.vbox([Ui.label(FoundryUi.text("THE PRACTICE RING", "練習の魔法陣"), "Faint"), rehearsal], 8)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_controls = Ui.vbox([], 14)
	_controls.custom_minimum_size.x = 602
	var desk := Ui.scroll(_controls)
	desk.custom_minimum_size.x = 602
	var body := Ui.hbox([classes, stage, desk], 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	add_child(column)
	_arrange(false)


func _class_button(entry: Dictionary) -> Button:
	var control := Ui.choice(String(entry.name), selected_class == entry.id, func() -> void: selected_class = entry.id)
	control.disabled = not entry.available
	control.clip_text = true
	control.custom_minimum_size = Vector2(220, 48)
	control.tooltip_text = (
		FoundryUi.text("Available", "選べるクラス") if entry.available else FoundryUi.text("Coming later", "今後追加予定")
	)
	# LEARN: retain accessible button text while an icon and wrapped label supply its compact visible contents.
	for state: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"
	]:
		control.add_theme_color_override(state, Color.TRANSPARENT)
	var icon := Ui.picture("menus/classes/" + String(entry.id), Vector2(24, 24))
	icon.modulate = Color.WHITE if entry.available else Color(1, 1, 1, 0.45)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Ui.sized(Ui.label(FoundryUi.text(entry.name, entry.ja), "", true), 14)
	label.add_theme_color_override("font_color", UiTheme.TEXT if entry.available else UiTheme.MUTED)
	var contents := Ui.hbox([icon, Ui.expand(label)], 10)
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.offset_left = 8
	contents.offset_right = -8
	contents.offset_top = 4
	contents.offset_bottom = -4
	control.add_child(contents)
	HoverInfo._ignore_mouse(contents)
	return control


func _skin_controls() -> void:
	_controls.add_child(Ui.label(FoundryUi.text("Choose your appearance", "すがたを選ぶ"), "Subheading"))
	_stage = Control.new()
	_stage.size = STAGE
	_stage.scale = Vector2.ONE * WHEEL_SCALE
	_stage.clip_contents = true
	_stage.gui_input.connect(_on_wheel)
	for i in _looks.size():
		var card := _card(_looks[i], i)
		_cards.append(card)
		_stage.add_child(card)
	var space := Control.new()
	space.custom_minimum_size = STAGE * WHEEL_SCALE
	space.add_child(_stage)
	_controls.add_child(space)
	_dots = Ui.hbox([], 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls.add_child(
		Ui.hbox(
			[
				FoundryUi.button(FoundryUi.text("Previous", "前へ"), _turn.bind(-1)),
				Ui.expand(_dots),
				FoundryUi.button(FoundryUi.text("Next", "次へ"), _turn.bind(1))
			],
			8
		)
	)
	_name = Ui.label("", "Heading", true)
	_epithet = Ui.label("", "Faint", true)
	_note = Ui.label("", "Muted", true)
	_equip = FoundryUi.button("", _equip_current, true)
	for node: Control in [_name, _epithet, _note, _equip]:
		_controls.add_child(node)
	_controls.add_child(
		Ui.label(FoundryUi.text("Browsing never changes your equipped skin.", "試着だけでは、保存したすがたは変わらないよ。"), "Muted", true)
	)
	_arrange(false)


func _card(look: Dictionary, index: int) -> Control:
	var card := super._card(look, index)
	# The room stays open when equipping; its footer supplies the live equipment status.
	if card.get_child_count() > 4:
		var badge := card.get_child(4)
		card.remove_child(badge)
		badge.free()
	return card


func _arrange(animate := true) -> void:
	var look := _looks[_at]
	if _stage != null:
		super._arrange(animate)
		_note.text = FoundryUi.text(
			"Turn the carousel, then try this skin on the practice ring.", "カルーセルで選び、練習の魔法陣で動きを試そう。"
		)
		_equip.text = (
			FoundryUi.text("Current skin", "今のすがた")
			if look.id == Settings.character_skin
			else FoundryUi.text("Use this skin", "このすがたにする")
		)
	if rehearsal.is_inside_tree() and (rehearsal.hero == null or rehearsal.hero.preview_skin != look.id):
		rehearsal.set_skin(look.id)


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_at = index
		_arrange()
		accept_event()
	else:
		_on_wheel(event)


func _unhandled_key_input(event: InputEvent) -> void:
	if _tab == "Skins":
		super._unhandled_key_input(event)
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _equip_current() -> void:
	var id: String = _looks[_at].id
	if id == Settings.character_skin:
		return
	Settings.character_skin = id
	Game.remember_avatar()
	Settings.save_file()
	_arrange(false)
	skin_selected.emit(id)


func _refresh_rehearsal_controls() -> void:
	# Keep the wheel alive during a skin change so its cards finish gliding into place.
	if _tab != "Skins" or _stage == null:
		_build_controls()


func _build_controls() -> void:
	Ui.clear(_controls)
	_cards.clear()
	_stage = null
	_equip = null
	_timeline = null
	_status = null
	_pause = null
	var tabs := Ui.hbox([], 8)
	for tab: String in ["Skins", "Motion", "Spells", "View"]:
		var choose := func() -> void:
			_tab = tab
			_build_controls()
		tabs.add_child(
			Ui.choice(
				FoundryUi.text(tab, {"Skins": "すがた", "Motion": "動き", "Spells": "呪文", "View": "見え方"}[tab]),
				_tab == tab,
				choose
			)
		)
	_controls.add_child(tabs)
	_controls.add_child(FoundryUi.rule())
	if _tab == "Skins":
		_skin_controls()
	elif _tab == "Motion":
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
