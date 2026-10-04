class_name ArchivePanel
extends PanelContainer
## A reference built from the live catalogs, so every new card, upgrade and relic is immediately discoverable.

signal closed

var _catalog: Dictionary
var _mode := "program"
var _kind := "cards"
var _query := ""
var _rarity := "all"
var _language := "python"
var _selected := ""
var _upgraded := false
var _list: VBoxContainer
var _details: VBoxContainer
var _count: Label
var _search: LineEdit


static func create(catalog: Dictionary) -> ArchivePanel:
	var panel := ArchivePanel.new()
	panel._catalog = catalog
	panel._language = Settings.language
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(1240, 820)
	var heading := Ui.vbox(
		[
			Ui.tint(Ui.label(Text.t("THE ARCHIVES"), "Heading"), UiTheme.AMBER),
			Ui.label(Text.t("Every function. Every artifact. A place to plan your next combination."), "Muted", true)
		],
		4
	)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Ui.button(Text.t("Close  ×"), func() -> void: closed.emit())
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var column := Ui.vbox([Ui.hbox([heading, close])], 16)
	var tabs := Ui.hbox([], 8)
	for kind: String in ["cards", "relics", "glossary"]:
		var choose := func() -> void:
			_kind = kind
			_selected = ""
			_rebuild()
		tabs.add_child(Ui.choice(_kind_name(kind), _kind == kind, choose))
	tabs.add_child(Ui.spacer())
	for mode: String in ["program", "spellbook"]:
		var choose := func() -> void:
			_mode = mode
			_selected = ""
			_rebuild()
		tabs.add_child(
			Ui.choice(Text.t("Shardrun") if mode == "program" else Text.t("Spellforge"), _mode == mode, choose)
		)
	column.add_child(tabs)
	_search = LineEdit.new()
	_search.placeholder_text = Text.t("Search names, effects, elements or keywords…")
	_search.text = _query
	_search.custom_minimum_size.y = 44
	_search.text_changed.connect(
		func(value: String) -> void:
			_query = value
			_refresh()
	)
	column.add_child(_search)
	if _kind == "cards":
		var rarities := Ui.hbox([], 6)
		for rarity: String in ["all", "common", "uncommon", "rare", "boss"]:
			var choose := func() -> void:
				_rarity = rarity
				_rebuild()
			rarities.add_child(Ui.choice(Text.t(rarity.capitalize()), _rarity == rarity, choose))
		column.add_child(rarities)
	_count = Ui.label("", "Faint")
	column.add_child(_count)
	_list = Ui.vbox([], 5)
	var browse := Ui.scroll(_list)
	browse.custom_minimum_size.x = 350
	browse.size_flags_horizontal = Control.SIZE_FILL
	_details = Ui.vbox([], 14)
	var detail_scroll := Ui.scroll(_details)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := Ui.hbox([browse, detail_scroll], 24)
	body.custom_minimum_size.y = 530
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	add_child(column)
	_refresh()


func _entries() -> Dictionary:
	if _kind == "glossary":
		var entries := {}
		for keyword: String in _catalog.programs.config.keywords:
			entries[keyword] = {"id": keyword, "name": keyword, "summary": _catalog.programs.config.keywords[keyword]}
		var foes: Dictionary = _catalog.foes.duplicate()
		foes.merge(_catalog.programs.foes)
		for foe: Dictionary in foes.values():
			var described := ShardrunViews.trait_view(foe)
			if not described.is_empty():
				entries[described.name] = {"id": described.name, "name": described.name, "summary": described.text}
		entries["weakness"] = {
			"id": "weakness",
			"name": Text.t("Weakness"),
			"summary":
			Text.t("This foe takes extra damage from bolts of the listed element. Relics can increase the bonus.")
		}
		var resistance := (
			"This foe takes less damage from bolts of the listed element. "
			+ "Change the element to avoid its resistance."
		)
		entries["resistance"] = {
			"id": "resistance", "name": Text.t("Resistance"), "summary": Text.sentences(resistance)
		}
		return entries
	if _mode == "program":
		return _catalog.programs.cards if _kind == "cards" else _catalog.programs.relics
	return _catalog.shards if _kind == "cards" else _catalog.relics


func _refresh() -> void:
	Ui.clear(_list)
	var entries := _entries()
	var shown: Array[Dictionary] = []
	for item: Dictionary in entries.values():
		if _kind == "cards" and String(item.id).ends_with("-plus"):
			continue
		if _kind == "cards" and _rarity != "all" and item.get("rarity", "") != _rarity:
			continue
		var haystack := (
			"%s %s %s %s %s"
			% [item.name, item.summary, item.get("paradigm", ""), item.get("keywords", []), item.get("role", "")]
		)
		if _query != "" and not _query.to_lower() in haystack.to_lower():
			continue
		shown.append(item)
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name).naturalnocasecmp_to(b.name) < 0)
	_count.text = Text.f("%d %s · select an entry to inspect it", [shown.size(), _kind_name(_kind).to_lower()])
	if shown.is_empty():
		Ui.clear(_details)
		_details.add_child(Ui.label(Text.t("No matches. Try another name or clear your filters."), "Muted", true))
		return
	if not shown.any(func(item: Dictionary) -> bool: return item.id == _selected):
		_selected = shown[0].id
		_upgraded = false
	for item in shown:
		var row := Ui.button(
			Text.t(item.name),
			func() -> void:
				_selected = item.id
				_upgraded = false
				_refresh(),
			"PrimaryButton" if item.id == _selected else ""
		)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 46
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_list.add_child(row)
	_show_entry(entries[_selected])


func _show_entry(base: Dictionary) -> void:
	Ui.clear(_details)
	var item := base
	var upgrade_id: String = base.get("forge", {}).get("into", "")
	if _upgraded and _entries().has(upgrade_id):
		item = _entries()[upgrade_id]
	if _kind == "relics":
		_details.add_child(Ui.picture("shardrun/relic-" + String(item.get("icon", item.id)), Vector2(140, 140), "✦"))
		_details.add_child(Cards.relic(item))
		return
	if _kind == "glossary":
		_details.add_child(Ui.tint(Ui.label(Text.t(item.name), "Heading"), UiTheme.TEAL))
		_details.add_child(Ui.label(Text.t(item.summary), "", true))
		return
	var art := Ui.picture(ShardrunViews.art(item), Vector2(148, 148), "◆")
	var title := Ui.vbox([Ui.label(Text.t(item.name), "Heading"), Ui.label(Text.t(item.summary), "", true)], 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_child(Ui.hbox([art, title], 18))
	var facts := "%s  ·  %s" % [Text.t(String(item.rarity).capitalize()), ShardrunViews.complexity(item)]
	if item.has("role"):
		facts += Text.f("  ·  %d mana  ·  %s", [int(item.cost), RoleBadge.describe(item.role)])
	_details.add_child(Ui.tint(Ui.label(facts, "Muted", true), UiTheme.TEAL))
	for keyword: String in item.get("keywords", []):
		_details.add_child(
			Ui.label("%s: %s" % [keyword, Text.t(_catalog.programs.config.keywords.get(keyword, ""))], "Muted", true)
		)
	var controls := Ui.hbox([], 6)
	for language: String in SandboxJob.LANGUAGES:
		if not (item.get("code", {}) as Dictionary).has(language):
			continue
		var choose := func() -> void:
			_language = language
			_show_entry(base)
		controls.add_child(Ui.choice(CodeLanguage.display_name(language), _language == language, choose))
	if upgrade_id != "":
		controls.add_child(Ui.spacer())
		var toggle := func() -> void:
			_upgraded = not _upgraded
			_show_entry(base)
		controls.add_child(Ui.choice(Text.t("Refactored +"), _upgraded, toggle))
	_details.add_child(controls)
	_details.add_child(Cards.code(item, _language))


func _rebuild() -> void:
	Ui.clear(self)
	_build()


func _kind_name(kind: String) -> String:
	if kind == "cards":
		return Text.t("Shards")
	return Text.t(kind.capitalize())
