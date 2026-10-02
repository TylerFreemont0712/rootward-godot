class_name FoundryLibraryPanel
extends ArchivePanel
## The Living Archive: shelf navigation, illustrated entries and encounter-aware bestiary in its own room.

var _role := "all"
var _layer := "all"
var _browse: ScrollContainer
var _shelves: Dictionary = {}
var _art: FoundryLibraryArt


static func make(catalog: Dictionary, artwork: FoundryLibraryArt = null) -> FoundryLibraryPanel:
	var panel := FoundryLibraryPanel.new()
	panel._art = artwork if artwork != null else FoundryLibraryArt.new()
	panel._catalog = catalog
	panel._language = Settings.language
	panel.theme_type_variation = "Overlay"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.theme = FoundryUi.theme()
	panel.theme.default_font_size = 18
	for variation: String in ["Heading", "Subheading", "Muted", "Faint", "Button", "PrimaryButton", "QuietButton"]:
		panel.theme.set_font_size(
			"font_size",
			variation,
			24 if variation == "Heading" else (14 if variation == "Faint" else (16 if variation == "Muted" else 18))
		)
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(1520, 760)
	var column := Ui.vbox(
		[
			FoundryUi.heading(
				FoundryUi.text("CATALOGUE / FIELD NOTES", "図鑑 / 観察ノート"),
				_kind_name(_kind),
				func() -> void: closed.emit()
			),
			FoundryUi.rule()
		],
		8
	)
	var sidebar := Ui.vbox([], 6)
	sidebar.custom_minimum_size.x = 176
	sidebar.add_child(Ui.label(FoundryUi.text("COLLECTIONS", "コレクション"), "Faint"))
	var symbols := {"cards": "◆", "relics": "✦", "foes": "◇", "bosses": "♜", "glossary": "≡"}
	for kind: String in ["cards", "relics", "foes", "bosses", "glossary"]:
		var choose := Ui.choice(_kind_name(kind), _kind == kind, _choose_shelf.bind(kind, _mode))
		choose.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choose.custom_minimum_size.y = 32
		choose.tooltip_text = "%s  %s" % [symbols[kind], _kind_name(kind)]
		sidebar.add_child(choose)
	sidebar.add_child(Ui.spacer(0, 14))
	sidebar.add_child(FoundryUi.rule())
	sidebar.add_child(Ui.label(FoundryUi.text("JOURNEY", "冒険モード"), "Faint"))
	for mode: String in ["program", "spellbook"]:
		sidebar.add_child(
			Ui.choice("Shardrun" if mode == "program" else "Spellforge", _mode == mode, _choose_shelf.bind(_kind, mode))
		)
	sidebar.add_child(Ui.expand(Ui.spacer(0, 1), true))
	sidebar.add_child(
		Ui.label(
			FoundryUi.text("Study a shard.\nRead an intent.\nPrepare a journey.", "シャードを調べる。\n敵の意図を読む。\n冒険に備える。"),
			"Faint",
			true
		)
	)
	_search = LineEdit.new()
	_search.placeholder_text = FoundryUi.text("Search names, effects or locations…", "名前・効果・場所を検索…")
	_search.text = _query
	_search.custom_minimum_size.y = 28
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(
		func(value: String) -> void:
			_query = value
			_refresh()
	)
	var catalogue := Ui.vbox(
		[Ui.hbox([_search, FoundryUi.button(FoundryUi.text("Reset", "リセット"), _reset_filters, false, true)], 8)], 8
	)
	catalogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var filters := Ui.hbox([], 8)
	if _kind == "cards":
		var rarity_changed := func(value: String) -> void:
			_rarity = value
			_refresh()
		filters.add_child(
			_picker(
				["all", "common", "uncommon", "rare", "epic", "legendary", "boss"],
				_rarity,
				FoundryUi.text("All rarities", "すべてのレア度"),
				rarity_changed
			)
		)
		if _mode == "program":
			var roles: Array[String] = ["all"]
			roles.append_array(RoleBadge.ROLES.keys())
			var role_changed := func(value: String) -> void:
				_role = value
				_refresh()
			filters.add_child(_picker(roles, _role, FoundryUi.text("All roles", "すべての役割"), role_changed))
	elif _kind in ["foes", "bosses"]:
		var layers := OptionButton.new()
		layers.add_item(FoundryUi.text("All layers", "すべての層"))
		var ids: Array[String] = ["all"]
		var routes := FoundryBestiary.layers(_catalog, _mode)
		for i in routes.size():
			ids.append(routes[i].id)
			layers.add_item(FoundryUi.text("Layer %d · %s", "第%d層 · %s") % [i + 1, routes[i].name])
		layers.selected = maxi(0, ids.find(_layer))
		layers.item_selected.connect(
			func(index: int) -> void:
				_layer = ids[index]
				_refresh()
		)
		filters.add_child(layers)
		filters.add_child(
			Ui.expand(
				Ui.label(
					FoundryUi.text(
						"Guardian pools" if _kind == "bosses" else "Hallways & elites",
						"守護者の候補" if _kind == "bosses" else "通常の敵・エリート"
					),
					"Faint"
				)
			)
		)
	if filters.get_child_count() > 0:
		catalogue.add_child(filters)
	else:
		filters.free()
	_count = Ui.label("", "Faint")
	catalogue.add_child(_count)
	_list = Ui.vbox([], 4)
	_browse = Ui.scroll(_list)
	_browse.follow_focus = true
	_browse.custom_minimum_size.x = 310
	_details = Ui.vbox([], 8)
	var details := Ui.scroll(_details)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var specimen := Ui.panel(details, "Sunken")
	specimen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := Ui.hbox([_browse, specimen], 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalogue.add_child(body)
	var content := Ui.hbox([sidebar, catalogue], 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	add_child(column)
	_refresh()


func _choose_shelf(kind: String, mode: String) -> void:
	_shelves[_mode + "/" + _kind] = {
		"query": _query, "selected": _selected, "role": _role, "rarity": _rarity, "layer": _layer
	}
	_kind = kind
	_mode = mode
	var saved: Dictionary = _shelves.get(mode + "/" + kind, {})
	_query = saved.get("query", "")
	_selected = saved.get("selected", "")
	_role = saved.get("role", "all")
	_rarity = saved.get("rarity", "all")
	_layer = saved.get("layer", "all")
	_upgraded = false
	_rebuild()


func _reset_filters() -> void:
	_query = ""
	_role = "all"
	_rarity = "all"
	_layer = "all"
	_rebuild()
	FoundryUi.focus.call_deferred(_search)


static func _picker(ids: Array[String], current: String, all_label: String, changed: Callable) -> OptionButton:
	var picker := OptionButton.new()
	for id in ids:
		picker.add_item(all_label if id == "all" else id.capitalize())
	picker.selected = maxi(0, ids.find(current))
	picker.item_selected.connect(func(index: int) -> void: changed.call(ids[index]))
	return picker


func _kind_name(kind: String) -> String:
	return (
		{
			"cards": FoundryUi.text("Shards", "シャード"),
			"relics": FoundryUi.text("Relics", "遺物"),
			"foes": FoundryUi.text("Creatures", "通常の敵"),
			"bosses": FoundryUi.text("Bosses", "ボス"),
			"glossary": FoundryUi.text("Concepts", "概念")
		}
		. get(kind, kind.capitalize())
	)


func _entries() -> Dictionary:
	if _kind in ["foes", "bosses"]:
		return FoundryBestiary.entries(_catalog, _mode, _kind == "bosses", _layer)
	var entries := super._entries()
	if _kind != "cards" or _mode != "program" or _role == "all":
		return entries
	var matching := {}
	for id: String in entries:
		if entries[id].get("role", "") == _role:
			matching[id] = entries[id]
	return matching


func _refresh() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focused := focus_owner != null and _list.is_ancestor_of(focus_owner)
	var scroll := _browse.scroll_vertical
	Ui.clear(_list)
	var shown: Array[Dictionary] = []
	for item: Dictionary in _entries().values():
		if _kind == "cards" and String(item.id).ends_with("-plus"):
			continue
		if _kind == "cards" and _rarity != "all" and item.get("rarity", "") != _rarity:
			continue
		var haystack := (
			"%s %s %s %s %s %s"
			% [
				item.name,
				item.get("summary", ""),
				item.get("keywords", []),
				item.get("role", ""),
				item.get("paradigm", ""),
				FoundryBestiary.location_text(item)
			]
		)
		if _query != "" and not _query.to_lower() in haystack.to_lower():
			continue
		shown.append(item)
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name).naturalnocasecmp_to(b.name) < 0)
	_count.text = FoundryUi.text("%d entries · select to inspect", "%d件 · 選んで調べる") % shown.size()
	if shown.is_empty():
		Ui.clear(_details)
		_details.add_child(Ui.label(FoundryUi.text("An empty shelf", "見つからなかったよ"), "Heading"))
		_details.add_child(
			Ui.label(
				FoundryUi.text("Try another name or reset your filters.", "別の名前を探すか、フィルターをリセットしてね。"), "Muted", true
			)
		)
		return
	if not shown.any(func(item: Dictionary) -> bool: return item.id == _selected):
		_selected = shown[0].id
		_upgraded = false
	var selected_row: Button
	for item in shown:
		var row := FoundryUi.button(
			item.name,
			func() -> void:
				_selected = item.id
				_upgraded = false
				_refresh(),
			item.id == _selected
		)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(310, 38)
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var art_id := _entry_art(item)
		row.set_meta("art_id", art_id)
		row.icon = _art.textures.get(art_id)
		row.add_theme_constant_override("icon_max_width", 28)
		row.tooltip_text = (
			"%s\n%s"
			% [
				item.name,
				FoundryBestiary.location_text(item) if _kind in ["foes", "bosses"] else item.get("summary", "")
			]
		)
		_list.add_child(row)
		if item.id == _selected:
			selected_row = row
			_show_entry(item)
	_browse.set_deferred("scroll_vertical", scroll)
	if focused:
		FoundryUi.focus.call_deferred(selected_row)


func _process(_delta: float) -> void:
	_art.poll()
	if not is_visible_in_tree():
		return
	var viewport_rect := _browse.get_global_rect()
	for child: Node in _list.get_children():
		var row := child as Button
		if row == null or not viewport_rect.intersects(row.get_global_rect()):
			continue
		var art_id: String = row.get_meta("art_id", "")
		if art_id.is_empty():
			continue
		if _art.textures.has(art_id):
			row.icon = _art.textures[art_id]
		else:
			_art.request(art_id)


func _entry_art(item: Dictionary) -> String:
	if _kind in ["foes", "bosses"]:
		return "foes/" + String(item.get("sprite", item.id))
	if _kind == "relics":
		return "shardrun/relic-" + String(item.get("icon", item.id))
	return ShardrunViews.art(item) if _kind == "cards" else "menus/icons/library"


func _show_entry(base: Dictionary) -> void:
	if _kind not in ["foes", "bosses"]:
		super._show_entry(base)
		if _kind == "cards":
			(_details.get_child(0).get_child(0) as Control).custom_minimum_size = Vector2(80, 80)
		elif _kind == "relics":
			(_details.get_child(0) as Control).custom_minimum_size = Vector2(96, 96)
		return
	Ui.clear(_details)
	_details.add_child(
		Ui.tint(
			Ui.label(
				FoundryUi.text(
					"GUARDIAN DOSSIER" if base.boss else "FIELD OBSERVATION", "守護者の記録" if base.boss else "観察の記録"
				),
				"Faint"
			),
			UiTheme.TEAL
		)
	)
	var art := Ui.picture(_entry_art(base), Vector2(196, 190), "◇")
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var identity := Ui.vbox(
		[
			Ui.label(base.name, "Heading", true),
			Ui.tint(Ui.label(FoundryBestiary.location_text(base), "Muted", true), UiTheme.AMBER),
			Ui.label(base.get("flavor", ""), "Muted", true)
		],
		8
	)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_child(Ui.hbox([art, identity], 12))
	_details.add_child(FoundryUi.rule())
	var traits := ShardrunViews.trait_view(base)
	if not traits.is_empty():
		_details.add_child(Ui.label(traits.name, "Subheading", true))
		_details.add_child(Ui.label(traits.text, "", true))
	_details.add_child(
		Ui.label(
			(
				FoundryUi.text("Base health: %d · increases with layer and difficulty", "基本HP: %d · 層と難易度で増加")
				% int(base.get("hp", 0))
			),
			"Faint",
			true
		)
	)
	for key: String in ["weak", "resist"]:
		var elements: Array = base.get(key, [])
		if not elements.is_empty():
			var label := FoundryUi.text("Weakness", "弱点") if key == "weak" else FoundryUi.text("Resistance", "耐性")
			_details.add_child(Ui.label("%s · %s" % [label, ", ".join(elements)], "Muted", true))
	if base.boss:
		var companions: Array[String] = []
		var effective := ProgramRules.catalog_for(_catalog) if _mode == "program" else _catalog
		for location: Dictionary in base.locations:
			for id: String in location.group:
				if id != base.id and effective.foes.has(id) and not String(effective.foes[id].name) in companions:
					companions.append(effective.foes[id].name)
		if not companions.is_empty():
			_details.add_child(
				Ui.label(FoundryUi.text("Encountered with: %s", "一緒に現れる敵: %s") % ", ".join(companions), "Muted", true)
			)
		_details.add_child(
			Ui.label(
				FoundryUi.text(
					"One guardian encounter is drawn from this layer's pool each journey.", "この層の候補から、冒険ごとに守護者の戦闘が選ばれる。"
				),
				"Faint",
				true
			)
		)


func _rebuild() -> void:
	FoundryUi.rebuild(self, _build)
