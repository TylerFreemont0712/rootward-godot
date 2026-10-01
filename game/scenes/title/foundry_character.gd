class_name FoundryCharacterPanel
extends SkinSelectionPanel
## The front-end class selector contains a cosmetic carousel. Battle keeps its original wardrobe panel.

const CLASSES: Array[Dictionary] = [
	{"id": "artificer", "name": "Artificer", "available": true, "skins": ["vesper", "emberfox", "shibu", "dummy"]}
]

var selected_class := "artificer"


static func make() -> FoundryCharacterPanel:
	var panel := FoundryCharacterPanel.new()
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(1010, 550)
	_looks = looks().filter(
		func(look: Dictionary) -> bool: return look.id in CLASSES[0].skins or look.id not in Settings.CHARACTER_SKINS
	)
	_cards = []
	for i in _looks.size():
		if _looks[i].id == Settings.character_skin:
			_at = i
	var column := Ui.vbox(
		[
			FoundryUi.heading("CHARACTER / SKINS", FoundryUi.text("Choose your appearance", "すがたを選ぶ"), _close),
			FoundryUi.rule()
		],
		10
	)
	var classes := Ui.vbox([Ui.label(FoundryUi.text("CLASS", "クラス"), "Faint")], 10)
	classes.custom_minimum_size.x = 180
	for entry: Dictionary in CLASSES:
		var choose := func() -> void: selected_class = entry.id
		var control := Ui.choice(entry.name, selected_class == entry.id, choose)
		control.disabled = not entry.available
		classes.add_child(control)
	classes.add_child(
		Ui.label(
			FoundryUi.text("Build spells from real programs. Find your own way down.", "本物のプログラムで呪文を作り、自分の道を見つけよう。"),
			"Muted",
			true
		)
	)
	classes.add_child(FoundryUi.rule())
	classes.add_child(Ui.label(FoundryUi.text("More classes will arrive later.", "新しいクラスはこれから。"), "Faint", true))
	classes.add_child(Ui.spacer(0, 20))
	classes.add_child(
		Ui.label(
			FoundryUi.text("Your skin stays with your player. Appearance only.", "すがたはプレイヤーごとに保存。強さは変わらないよ。"),
			"Muted",
			true
		)
	)
	_stage = Control.new()
	_stage.size = STAGE
	_stage.scale = Vector2.ONE * 0.66
	_stage.clip_contents = true
	_stage.gui_input.connect(_on_wheel)
	for i in _looks.size():
		var card := _card(_looks[i], i)
		_cards.append(card)
		_stage.add_child(card)
	_epithet = Ui.label("", "Faint")
	_name = Ui.label("", "Heading")
	_note = Ui.label("", "Muted", true)
	_note.custom_minimum_size.x = 720
	for label: Label in [_epithet, _name, _note]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equip = FoundryUi.button("", _equip_current, true)
	_equip.custom_minimum_size.x = 190
	_dots = Ui.hbox([], 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	var turning := Ui.hbox([FoundryUi.button("‹", _turn.bind(-1)), _dots, FoundryUi.button("›", _turn.bind(1))], 24)
	turning.alignment = BoxContainer.ALIGNMENT_CENTER
	# LEARN: containers measure unscaled minimums. A wrapper reserves the wheel's actual scaled footprint.
	var stage_space := Control.new()
	stage_space.custom_minimum_size = STAGE * 0.66
	stage_space.add_child(_stage)
	var identity := Ui.vbox([_epithet, _name], 2)
	var footer := Ui.hbox([Ui.expand(identity), _equip], 12)
	var wheel := Ui.vbox([stage_space, turning, footer, _note], 8)
	column.add_child(Ui.hbox([classes, wheel], 18))
	add_child(column)
	_arrange(false)


func _card(look: Dictionary, index: int) -> Control:
	var card := super._card(look, index)
	# The base card's badge is fixed at creation; the front-end stays open when equipping, so its footer shows status.
	if card.get_child_count() > 4:
		var badge := card.get_child(4)
		card.remove_child(badge)
		badge.free()
	return card


func _arrange(animate := true) -> void:
	super._arrange(animate)
	var look := _looks[_at]
	var notes := {
		"vesper": FoundryUi.text("A crescent hat and a spell written in starlight.", "三日月の帽子と、星明かりで書く呪文。"),
		"emberfox": FoundryUi.text("A field coat, amber eyes, and a bright ember tail.", "琥珀色の目、旅のコート、明るい炎のしっぽ。"),
		"shibu": FoundryUi.text("A hovering caster with a palm full of magic.", "ふわりと浮かぶ術師。その手には魔法が。"),
		"dummy": FoundryUi.text("A simple mannequin to explore the movements of a spell.", "呪文の動きを見るためのシンプルな人形。"),
	}
	_note.text = notes.get(look.id, FoundryUi.text("A look from your local collection.", "この端末のコレクション。"))
	_equip.text = (
		FoundryUi.text("Current skin", "今のすがた")
		if look.id == Settings.character_skin
		else FoundryUi.text("Use this skin", "このすがたにする")
	)


func _equip_current() -> void:
	var id: String = _looks[_at].id
	if id == Settings.character_skin:
		return
	Settings.character_skin = id
	Game.remember_avatar()
	Settings.save_file()
	_arrange(false)
	skin_selected.emit(id)
