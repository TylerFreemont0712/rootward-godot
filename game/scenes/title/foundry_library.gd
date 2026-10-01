class_name FoundryLibraryPanel
extends ArchivePanel
## The station's library adds a bestiary while retaining the live archive's search, code and refactor inspectors.

var _role := "all"


static func make(catalog: Dictionary) -> FoundryLibraryPanel:
	var panel := FoundryLibraryPanel.new()
	panel._catalog = catalog
	panel._language = Settings.language
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(940, 570)
	var column := Ui.vbox(
		[
			FoundryUi.heading(
				"THE STATION LIBRARY",
				FoundryUi.text("Knowledge for the journey", "旅のための知識"),
				func() -> void: closed.emit()
			),
			FoundryUi.rule()
		],
		10
	)
	var tabs := Ui.hbox([], 10)
	for kind: String in ["cards", "relics", "foes", "glossary"]:
		var choose := func() -> void:
			_kind = kind
			_selected = ""
			_rarity = "all"
			_rebuild()
		tabs.add_child(Ui.choice(_kind_name(kind), _kind == kind, choose))
	tabs.add_child(Ui.spacer())
	for mode: String in ["program", "spellbook"]:
		var choose := func() -> void:
			_mode = mode
			_selected = ""
			_rebuild()
		tabs.add_child(Ui.choice("Shardrun" if mode == "program" else "Spellforge", _mode == mode, choose))
	column.add_child(tabs)
	_search = LineEdit.new()
	_search.placeholder_text = FoundryUi.text("Search the shelves…", "図鑑を検索…")
	_search.text = _query
	_search.custom_minimum_size.y = 34
	_search.text_changed.connect(
		func(value: String) -> void:
			_query = value
			_refresh()
	)
	column.add_child(_search)
	if _kind == "cards":
		var rarities := Ui.hbox([], 8)
		var rarity_ids: Array[String] = ["all", "common", "uncommon", "rare", "epic", "legendary", "boss"]
		var rarity_picker := OptionButton.new()
		for rarity: String in rarity_ids:
			rarity_picker.add_item(
				FoundryUi.text("All rarities", "すべてのレア度") if rarity == "all" else rarity.capitalize()
			)
		rarity_picker.selected = maxi(0, rarity_ids.find(_rarity))
		rarity_picker.item_selected.connect(
			func(index: int) -> void:
				_rarity = rarity_ids[index]
				_refresh()
		)
		rarities.add_child(rarity_picker)
		if _mode == "program":
			rarities.add_child(Ui.spacer())
			var roles := OptionButton.new()
			var role_ids: Array[String] = ["all"]
			for id: String in RoleBadge.ROLES:
				role_ids.append(id)
			for id in role_ids:
				roles.add_item(FoundryUi.text("All roles", "すべての役割") if id == "all" else id.capitalize())
			roles.selected = maxi(0, role_ids.find(_role))
			roles.item_selected.connect(
				func(index: int) -> void:
					_role = role_ids[index]
					_selected = ""
					_refresh()
			)
			rarities.add_child(roles)
		column.add_child(rarities)
	_count = Ui.label("", "Faint")
	column.add_child(_count)
	_list = Ui.vbox([], 6)
	var browse := Ui.scroll(_list)
	browse.custom_minimum_size.x = 255
	_details = Ui.vbox([], 12)
	var details := Ui.scroll(_details)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := Ui.hbox([browse, details], 16)
	body.custom_minimum_size.y = 290
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	add_child(column)
	_refresh()


func _kind_name(kind: String) -> String:
	var names := {
		"cards": FoundryUi.text("Shards", "シャード"),
		"relics": FoundryUi.text("Relics", "遺物"),
		"foes": FoundryUi.text("Creatures", "敵"),
		"glossary": FoundryUi.text("Concepts", "概念"),
	}
	return names.get(kind, kind.capitalize())


func _entries() -> Dictionary:
	if _kind != "foes":
		var entries := super._entries()
		if _kind != "cards" or _mode != "program" or _role == "all":
			return entries
		var matching := {}
		for id: String in entries:
			if entries[id].get("role", "") == _role:
				matching[id] = entries[id]
		return matching
	var creatures: Dictionary = _catalog.foes.duplicate(true)
	if _mode == "program":
		creatures.merge(_catalog.programs.foes, true)
	for creature: Dictionary in creatures.values():
		var trait_view := ShardrunViews.trait_view(creature)
		creature.summary = trait_view.get(
			"text", creature.get("flavor", FoundryUi.text("A creature of the Machine.", "機械の中に住む敵。"))
		)
	return creatures


func _show_entry(base: Dictionary) -> void:
	if _kind != "foes":
		super._show_entry(base)
		if _kind == "cards":
			var art := _details.get_child(0).get_child(0) as Control
			art.custom_minimum_size = Vector2(96, 96)
		elif _kind == "relics":
			(_details.get_child(0) as Control).custom_minimum_size = Vector2(96, 96)
		return
	Ui.clear(_details)
	var art := Ui.picture("foes/" + String(base.get("sprite", base.id)), Vector2(240, 190), "◇")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_details.add_child(art)
	_details.add_child(Ui.label(base.name, "Heading"))
	_details.add_child(Ui.label(base.summary, "", true))
	var traits := ShardrunViews.trait_view(base)
	if not traits.is_empty():
		_details.add_child(Ui.label(traits.name, "Subheading"))
	var facts := FoundryUi.text("Base health: %d", "基本HP: %d") % int(base.get("hp", 0))
	_details.add_child(Ui.label(facts, "Muted"))
	for key: String in ["weak", "resist"]:
		var elements: Array = base.get(key, [])
		if not elements.is_empty():
			_details.add_child(Ui.label("%s · %s" % [key.capitalize(), ", ".join(elements)], "Muted", true))
	_details.add_child(FoundryUi.rule())
	_details.add_child(
		Ui.label(
			FoundryUi.text("Observe its intent. Choose your program's order with care.", "敵の行動を見て、プログラムの順番を考えよう。"),
			"Muted",
			true
		)
	)


func _rebuild() -> void:
	FoundryUi.rebuild(self, _build)
