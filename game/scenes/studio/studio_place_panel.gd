class_name StudioPlacePanel
extends PanelContainer
## The Studio's catalog (Concept/v0.3/10, sections 6 and 8): views and category tabs with the search box, a row of
## subcategory tabs, a row of filter chips, and two visible rows of picture cards. The filtering is the pure
## `StudioCatalogFilter`; this panel only holds the choices and shows the cards that pass. Hover previews a picture;
## only a left click starts placement.

signal chosen(art: String)
signal asset_context_requested(art: String, point: Vector2)

const ROW := 22
const FONT := 13
## Chip groups, each any-of inside, and the filter key they feed: [key, value, label key, tip key].
const CHIPS: Array[Array] = [
	["places", "outdoor", "chip_outdoor", ""], ["places", "indoor", "chip_indoor", ""],
	["footprints", "1x1", "chip_1x1", ""], ["footprints", "2x1", "chip_2x1", ""], ["footprints", "1x2", "chip_1x2", ""],
	["footprints", "2x2", "chip_2x2", ""], ["footprints", "bigger", "chip_bigger", ""],
	["solidity", "solid", "chip_solid", ""], ["solidity", "walkable", "chip_walkable", ""],
	["flat", "", "chip_flat", "chip_flat_tip"], ["code", "", "chip_code", "chip_code_tip"],
	["sources", "new", "chip_new", "chip_new_tip"], ["sources", "old", "chip_old", "chip_old_tip"],
]
## Where a new group of chips starts (a small gap before it).
const GROUP_STARTS: Array[String] = ["footprints", "solidity", "flat", "code", "sources"]
const ARRAY_KEYS: Array[String] = ["places", "footprints", "solidity", "sources"]

## The art ids placed most recently, newest first. It lives for the run, so a rebuilt panel remembers.
static var recent: Array[String] = []

## The entries now listed, retained for the Arrange tests: "Barrel   barrel   1 x 1".
var shown: Array[String] = []
var preview: StudioAssetPreview

var _search: LineEdit
var _results: Label
var _flow: HFlowContainer
var _scroll: ScrollContainer
var _empty: Label
var _sub_row: HBoxContainer
var _tabs: Dictionary = {}
var _sub_tabs: Dictionary = {}
var _chip_buttons: Array[Dictionary] = []
var _tree: Array[Dictionary] = []
var _entries: Dictionary = {}
var _cards: Dictionary = {}
var _ids: Array[String] = []
var _placed: Array[String] = []
var _view := "all"
var _category := ""
var _subcategory := ""
var _kind := ""
var _on: Dictionary = {}
var _hover_art := ""
var _placing := ""
var _updates: Array[String] = []
var _scope: Dictionary = {}
var _compact_header := false


func _init(scope: Dictionary = {}, compact_header := false) -> void:
	_scope = scope.duplicate(true)
	_compact_header = compact_header
	name = "PlacePanel"
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(10, 6)))
	custom_minimum_size.y = StudioStyle.PLACE
	for art: String in StudioAssets.placeable():
		var entry := StudioAssets.entry_of(art).duplicate()
		entry["source"] = StudioThumbs.source(art, String(entry.get("kind", "prop")))
		_entries[art] = entry
	_tree = StudioCatalog.tree(StudioAssets.categories(), _entries)
	preview = StudioAssetPreview.new()
	var sections: Array[Control] = [_build_head()]
	if not _compact_header:
		sections.append(_build_sub_row())
	sections.append_array([_build_chips(), _build_cards()])
	var browser := Ui.vbox(sections, 3)
	browser.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(Ui.hbox([browser, preview], 10))
	_make_cards()
	_refresh()


func _build_head() -> Control:
	var row := Ui.hbox([], 3)
	row.name = "ViewRow"
	for view: Array in [["all", "catalog_all", ""], ["recent", "catalog_recent", "catalog_recent_tip"],
			["placed", "catalog_placed", "catalog_placed_tip"]]:
		var view_id: String = view[0]
		row.add_child(_tab("Tab_" + view_id, StudioText.t(view[1]), StudioText.t(view[2]) if view[2] != "" else "",
				func() -> void: _choose_view(view_id), _tabs, view_id))
	row.add_child(VSeparator.new())
	for category: Dictionary in _tree:
		if _compact_header:
			break
		var category_id := String(category.id)
		row.add_child(_tab("Tab_" + category_id, String(category.name), "",
				func() -> void: _choose_category(category_id), _tabs, "category:" + category_id))
	row.add_child(Ui.spacer())
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = StudioText.t("place_search")
	_search.clear_button_enabled = true
	_search.focus_mode = Control.FOCUS_CLICK
	_search.custom_minimum_size = Vector2(190, ROW)
	_search.add_theme_font_size_override("font_size", FONT)
	var edit := UiTheme.box(UiTheme.PANEL_2, UiTheme.LINE, 1, 3, Vector2(6, 1))
	_search.add_theme_stylebox_override("normal", edit)
	_search.add_theme_stylebox_override("focus", UiTheme.box(UiTheme.PANEL_2, UiTheme.AMBER_DIM, 1, 3, Vector2(6, 1)))
	_search.text_changed.connect(_on_search)
	_search.text_submitted.connect(func(_text: String) -> void: _search.release_focus())
	row.add_child(_search)
	_results = StudioStyle.caption("")
	_results.custom_minimum_size.x = 84
	_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_results)
	var reset := StudioStyle.button(StudioText.t("browser_reset"), reset_filters)
	_compact(reset, false)
	row.add_child(reset)
	return row


func _build_sub_row() -> Control:
	_sub_row = Ui.hbox([], 3)
	_sub_row.name = "SubRow"
	_sub_row.custom_minimum_size.y = ROW
	_sub_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var updates := _tab("UpdatesView", StudioText.t("review_view"), StudioText.t("review_empty"),
		func() -> void: _choose_view("updates"), _tabs, "updates")
	return Ui.hbox([_sub_row, updates], 6)


func _build_chips() -> Control:
	var row := Ui.hbox([], 3)
	row.name = "ChipRow"
	var last := ""
	for chip: Array in CHIPS:
		var key: String = chip[0]
		if key != last and GROUP_STARTS.has(key):
			row.add_child(Ui.spacer(8, 0))
		last = key
		var value: String = chip[1]
		var button := Button.new()
		button.name = "Chip_%s%s" % [key, "_" + value if value != "" else ""]
		button.text = StudioText.t(chip[2])
		button.tooltip_text = StudioText.t(chip[3]) if chip[3] != "" else ""
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.toggled.connect(func(on: bool) -> void:
			_on[_chip_key(key, value)] = on
			_compact(button, on)
			_fill()
		)
		_compact(button, false)
		row.add_child(button)
		_chip_buttons.append({"key": key, "value": value, "button": button})
	return row


func _build_cards() -> Control:
	_flow = Ui.flow([], 4)
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll = ScrollContainer.new()
	_scroll.name = "Cards"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.custom_minimum_size.y = StudioCatalogCard.HEIGHT
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.tooltip_text = StudioText.t("place_tip")
	_scroll.add_child(_flow)
	_empty = Ui.label("", "Muted")
	_empty.add_theme_font_size_override("font_size", FONT)
	_empty.custom_minimum_size.y = StudioCatalogCard.HEIGHT
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var area := Ui.vbox([_scroll, _empty], 0)
	area.name = "CardArea"
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return area



## One card per placeable picture, made once; the panel only shows, hides and reorders them afterwards.
func _make_cards() -> void:
	for art: String in _entries:
		if _cards.has(art):
			continue
		var card := StudioCatalogCard.new(art, _entries[art])
		card.visible = false
		card.hovered.connect(_card_hovered)
		card.unhovered.connect(func(left: String) -> void:
			if _hover_art == left:
				_hover_art = ""
		)
		card.picked.connect(_picked)
		card.context_requested.connect(func(id: String, point: Vector2) -> void: asset_context_requested.emit(id, point))
		_flow.add_child(card)
		_cards[art] = card


## A tab button of the views, categories or subcategories rows.
func _tab(node_name: String, text: String, tip: String, on_pressed: Callable, into: Dictionary, key: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(on_pressed)
	_compact(button, false)
	into[key] = button
	return button


## The compact look of a tab or chip: small type, a thin box, amber when it is the one in use.
func _compact(button: Button, on: bool) -> void:
	StudioStyle.choose(button, on)
	button.add_theme_font_size_override("font_size", FONT)
	button.custom_minimum_size.y = ROW
	var fill := Color("#2a1f12") if on else UiTheme.PANEL_2
	var edge := UiTheme.AMBER_DIM if on else UiTheme.LINE
	var lit := Color("#3a2a15") if on else UiTheme.PANEL_3
	var lit_edge := UiTheme.AMBER if on else UiTheme.AMBER_DIM
	var margin := Vector2(7, 1)
	button.add_theme_stylebox_override("normal", UiTheme.box(fill, edge, 1, 3, margin))
	for state: String in ["hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, UiTheme.box(lit, lit_edge, 1, 3, margin))
	button.add_theme_color_override("font_pressed_color", UiTheme.AMBER if on else UiTheme.TEXT)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.AMBER)


# --- choices ---


func _choose_view(view: String) -> void:
	_view = view
	_category = ""
	_subcategory = ""
	_refresh()


func _choose_category(category: String) -> void:
	if _view != "category" or _category != category:
		_subcategory = ""
	_view = "category"
	_category = category
	_refresh()


func _choose_subcategory(subcategory: String) -> void:
	_subcategory = subcategory
	_refresh()


## Typing while a category is chosen searches every category (spec 8.3); Recent and On this map search themselves.
func _on_search(text: String) -> void:
	if text.strip_edges() != "" and _view == "category":
		_view = "all"
		_category = ""
		_subcategory = ""
		_refresh()
	else:
		_fill()


func _picked(art: String) -> void:
	_hover_art = art
	preview.preview_asset(art)
	chosen.emit(art)


func _card_hovered(art: String) -> void:
	if art != _hover_art:
		_hover_art = art
		preview.preview_asset(art)


func _chip_key(key: String, value: String) -> String:
	return key + ":" + value


# --- showing ---


## Everything that follows from the choices: the tabs' looks, the subcategory row, the chips and the cards.
func _refresh() -> void:
	for key: String in _tabs:
		var on := key == _view or (_view == "category" and key == "category:" + _category)
		if key.begins_with("category:"):
			on = _view == "category" and key == "category:" + _category
		_compact(_tabs[key], on)
	_fill_sub_row()
	for chip: Dictionary in _chip_buttons:
		var button: Button = chip.button
		var on: bool = bool(_on.get(_chip_key(chip.key, chip.value), false))
		button.set_pressed_no_signal(on)
		_compact(button, on)
	_fill()


func _fill_sub_row() -> void:
	if _sub_row == null:
		return
	for child: Node in _sub_row.get_children():
		_sub_row.remove_child(child)
		child.queue_free()
	_sub_tabs.clear()
	if _view != "category":
		var tip := {"recent": "catalog_recent_tip", "placed": "catalog_placed_tip"}.get(_view, "place_tip") as String
		_sub_row.add_child(StudioStyle.caption(StudioText.t(tip)))
		return
	_sub_row.add_child(_tab("Sub_all", StudioText.t("catalog_all"), "", func() -> void: _choose_subcategory(""),
			_sub_tabs, ""))
	for category: Dictionary in _tree:
		if String(category.id) != _category:
			continue
		for subcategory: Dictionary in category.subcategories:
			var sub_id := String(subcategory.id)
			_sub_row.add_child(_tab("Sub_" + sub_id, String(subcategory.name), "",
					func() -> void: _choose_subcategory(sub_id), _sub_tabs, sub_id))
	for key: String in _sub_tabs:
		_compact(_sub_tabs[key], key == _subcategory)


func _fill(reset_scroll := true) -> void:
	var scroll_before := _scroll.scroll_vertical
	_ids = StudioCatalogFilter.query(_entries, filters(), _scope)
	shown.clear()
	_hover_art = ""
	var listed: Dictionary = {}
	for index: int in _ids.size():
		var card: StudioCatalogCard = _cards[_ids[index]]
		listed[_ids[index]] = true
		card.present(true)
		if card.get_index() != index:
			_flow.move_child(card, index)
		shown.append(card.listing())
	for art: String in _cards:
		if not listed.has(art):
			(_cards[art] as StudioCatalogCard).present(false)
	_scroll.scroll_vertical = 0 if reset_scroll else scroll_before
	var none := _ids.is_empty()
	_scroll.visible = not none
	_empty.visible = none
	_empty.text = _empty_text()
	_results.text = StudioText.t("browser_results") % _ids.size() if not none else StudioText.t("browser_no_results")


func _empty_text() -> String:
	if _view == "recent" and recent.is_empty() and _search.text.strip_edges() == "":
		return StudioText.t("catalog_recent_empty")
	if _view == "placed" and _placed.is_empty() and _search.text.strip_edges() == "":
		return StudioText.t("catalog_placed_empty")
	return StudioText.t("browser_no_results")


# --- the public face ---


## Scope belongs to the caller and survives Reset/category/search/Recent. It never changes entry identities.
func set_scope(scope: Dictionary) -> void:
	_scope = scope.duplicate(true)
	_refresh()


## Refresh shared Recent/review data when a shelf opens, retaining this panel's own scroll position.
func refresh_browsing() -> void:
	var scroll_before := _scroll.scroll_vertical
	_refresh()
	_scroll.set_deferred("scroll_vertical", scroll_before)


## The picture just placed or chosen, first in the Recent view.
func note_used(art: String) -> void:
	recent = StudioCatalog.remember(recent, art)
	if _view == "recent":
		_fill(false)


## The art ids standing on the current map, for the On this map view.
func set_placed(arts: Array[String]) -> void:
	_placed = arts.duplicate()
	if _view == "placed":
		_fill(false)


func set_updates(arts: Array[String]) -> void:
	_updates = arts.duplicate()
	for art: String in _cards:
		(_cards[art] as StudioCatalogCard).set_needs_update(art in _updates)
	if _view == "updates":
		_fill(false)


## New queued variants join the running catalog without closing the Studio or losing browsing filters.
func reload_assets(refresh_pictures := false) -> void:
	var added := false
	for art: String in StudioAssets.placeable():
		if _entries.has(art):
			continue
		var entry := StudioAssets.entry_of(art).duplicate()
		entry["source"] = StudioThumbs.source(art, String(entry.get("kind", "prop")))
		_entries[art] = entry
		added = true
	if not added and not refresh_pictures:
		return
	_make_cards()
	if refresh_pictures:
		for art: String in _cards:
			(_cards[art] as StudioCatalogCard).invalidate_picture()
	refresh_browsing()


## Gives one card the amber border of the picture being placed ("" clears it).
func mark_placing(art: String) -> void:
	_placing = art
	for card_art: String in _cards:
		(_cards[card_art] as StudioCatalogCard).set_placing(card_art == art)


func preview_asset(art: String, object: Dictionary = {}) -> void:
	preview.preview_asset(art, object)


## Map deselection keeps an active catalog hover visible while a click starts placement.
func clear_preview() -> void:
	if _hover_art != "":
		preview.preview_asset(_hover_art)
	else:
		preview.clear_preview()


## The whole dictionary the catalog filter is asked.
func filters() -> Dictionary:
	var values: Dictionary = {
		"view": _view, "text": _search.text, "category": _category if _view == "category" else "",
		"subcategory": _subcategory if _view == "category" else "", "kind": _kind,
		"places": _chosen_values("places"), "footprints": _chosen_values("footprints"),
		"solidity": _chosen_values("solidity"), "flat": _is_on("flat"), "code": _is_on("code"),
		"sources": _chosen_values("sources"),
	}
	if _view == "recent":
		values["ids"] = recent.duplicate()
		values["order"] = recent.duplicate()
	elif _view == "placed":
		values["ids"] = _placed.duplicate()
	elif _view == "updates":
		values["ids"] = _updates.duplicate()
	return values


## Sets any of: `view` ("all", "recent", "placed"), `category` (shows that category), `subcategory`, `text`, `place`
## (just that one place chip), `kind`, and the chip keys `places`, `footprints`, `solidity`, `sources` (arrays),
## `flat` and `code` (bools). Keys that are missing stay as they are.
func set_filters(values: Dictionary) -> void:
	if values.has("view"):
		_choose_view_quietly(String(values.view))
	if values.has("category"):
		var category := String(values.category)
		if category != "":
			_view = "category"
			_category = category
			_subcategory = ""
		elif _view == "category":
			_view = "all"
			_category = ""
			_subcategory = ""
	if values.has("subcategory"):
		_subcategory = String(values.subcategory)
	if values.has("kind"):
		_kind = String(values.kind)
	if values.has("text"):
		_search.text = String(values.text)
	if values.has("place"):
		_set_group("places", [String(values.place)] if String(values.place) != "" else [])
	for key: String in ARRAY_KEYS:
		if values.has(key):
			_set_group(key, values[key] as Array)
	for key: String in ["flat", "code"]:
		if values.has(key):
			_on[_chip_key(key, "")] = bool(values[key])
	_refresh()


func reset_filters() -> void:
	_view = "all"
	_category = ""
	_subcategory = ""
	_kind = ""
	_search.text = ""
	_on.clear()
	_refresh()


func matching_ids() -> Array[String]:
	return _ids.duplicate()


## Types into the search box, as existing tests do.
func search_for(text: String) -> void:
	_search.text = text
	_on_search(text)


func release_keyboard() -> void:
	if _search.has_focus():
		_search.release_focus()


func _choose_view_quietly(view: String) -> void:
	if view in ["all", "recent", "placed", "updates"]:
		_view = view
		_category = ""
		_subcategory = ""


func _set_group(key: String, values: Array) -> void:
	for chip: Dictionary in _chip_buttons:
		if chip.key == key:
			_on[_chip_key(key, chip.value)] = values.has(chip.value)


func _chosen_values(key: String) -> Array[String]:
	var out: Array[String] = []
	for chip: Dictionary in _chip_buttons:
		if chip.key == key and bool(_on.get(_chip_key(key, chip.value), false)):
			out.append(chip.value)
	return out


func _is_on(key: String) -> bool:
	return bool(_on.get(_chip_key(key, ""), false))
