class_name SkinSelectionPanel
extends PanelContainer
## A small wardrobe for the battle looks. The chosen look is remembered in Settings.

signal closed
signal skin_selected(id: String)


static func create() -> SkinSelectionPanel:
	var panel := SkinSelectionPanel.new()
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(1200, 0)
	var header := Ui.hbox(
		[
			Ui.vbox([Ui.label("FIELD WARDROBE", "Faint"), Ui.label("Choose your battle look", "Heading")], 2),
			Ui.spacer(),
			Ui.button("Close", _close)
		],
		12
	)
	var cards := (
		Ui
		. hbox(
			[
				_skin_card(
					"emberfox",
					"Emberfox",
					"Salvage Runner",
					"Amber eyes, a teal field coat, and one bright ember tail.",
					"res://characters/emberfox/emberfox_front.png"
				),
				_skin_card(
					"vesper",
					"Vesper",
					"Star-Script Witch",
					"A crescent hat, a plum capelet, and a palm strike that writes in starlight. Drawn, not modelled.",
					"res://assets/sprites/vesper/profile.png"
				),
				_skin_card(
					"shibu",
					"Shibu",
					"Hovering Caster · 3D trial",
					"A VRoid model on the new move set: she floats, spins up into the air and drives her palms at the foes.",
					"res://assets/portraits/shibu.png"
				),
			],
			14
		)
	)
	add_child(
		(
			Ui
			. vbox(
				[
					header,
					(
						Ui
						. label(
							"Three looks for your hero. They share the same rules; your choice appears in fights and on your run card.",
							"Muted",
							true
						)
					),
					cards
				],
				14
			)
		)
	)


func _skin_card(id: String, title: String, epithet: String, note: String, portrait_path: String) -> Control:
	var portrait := TextureRect.new()
	portrait.texture = load(portrait_path) as Texture2D if ResourceLoader.exists(portrait_path) else null
	portrait.custom_minimum_size = Vector2(330, 260)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chosen := Settings.character_skin == id
	var title_label := Ui.label(title, "Subheading")
	var card := (
		Ui
		. vbox(
			[
				portrait,
				Ui.label(epithet.to_upper(), "Faint"),
				title_label,
				Ui.label(note, "Muted", true),
				Ui.button(
					"Equipped" if chosen else "Choose this skin", _choose.bind(id), "PrimaryButton" if chosen else ""
				),
			],
			7
		)
	)
	card.custom_minimum_size = Vector2(360, 0)
	var plate := Ui.panel(card, "Card")
	if chosen:
		plate.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.TEAL, 2, 10, Vector2(14, 11)))
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return plate


func _choose(id: String) -> void:
	Settings.character_skin = id
	Game.remember_avatar()
	Settings.save_file()
	skin_selected.emit(id)
	closed.emit()


func _close() -> void:
	closed.emit()
