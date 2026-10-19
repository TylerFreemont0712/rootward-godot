extends GdUnitTestSuite
## The Studio's full catalog panel (Concept/v0.3/10, S3): category and subcategory tabs, chips, the views, the
## cards and their thumbnails, against the real catalog and pictures. Nothing is written anywhere.

var _panel: StudioPlacePanel
var _chosen: Array[String] = []
var _old_entries: Dictionary = {}
var _old_categories: Array[Dictionary] = []
var _old_loaded_from := ""
var _old_textures: Dictionary = {}
var _old_indexes: Dictionary = {}


func before_test() -> void:
	_old_entries = StudioAssets._entries
	_old_categories = StudioAssets._categories
	_old_loaded_from = StudioAssets._loaded_from
	_old_textures = OverworldArt._textures.duplicate()
	_old_indexes = OverworldArt._indexes.duplicate()
	StudioAssets.entries(StudioAssets.PATH)
	StudioThumbs.clear()
	StudioPlacePanel.recent = []
	_chosen.clear()
	_panel = auto_free(StudioPlacePanel.new()) as StudioPlacePanel
	_panel.theme = UiTheme.shared()
	_panel.size = Vector2(1440, StudioStyle.PLACE)
	_panel.chosen.connect(func(art: String) -> void: _chosen.append(art))
	add_child(_panel)
	await _frames(3)


func after_test() -> void:
	StudioPlacePanel.recent = []
	StudioThumbs.clear()
	StudioAssets._entries = _old_entries
	StudioAssets._categories = _old_categories
	StudioAssets._loaded_from = _old_loaded_from
	OverworldArt._textures = _old_textures
	OverworldArt._indexes = _old_indexes


## The spec's acceptance: typing "barr" finds the barrel (and its remakes at other sizes, all barrels, after it).
func test_typing_barr_finds_the_barrel() -> void:
	_panel.search_for("barr")
	var found := _panel.matching_ids()
	assert_str(found[0]).is_equal("barrel")
	assert_array(_panel.shown).has_size(found.size())
	# The 2026-10-15 catalog expansion added more barrels (a small lidded cask): each match says "barr" somewhere.
	for art: String in found:
		var said := (art + " " + StudioAssets.name_of(art)).to_lower()
		assert_bool(said.contains("barr")).override_failure_message(art).is_true()


func test_the_old_and_40_px_chips_split_the_catalog_by_picture_age() -> void:
	var old: Array[String] = []
	var fresh: Array[String] = []
	for art: String in StudioAssets.placeable():
		var kind := String(StudioAssets.entry_of(art).kind)
		var folder := "buildings" if kind == "building" else "props"
		# People and the markers are drawn for the 40 px tile (S6), so they are never "old".
		if kind in ["building", "prop"] and OverworldArt.art_scale(folder, art) > 1.0:
			old.append(art)
		else:
			fresh.append(art)
	assert_int(old.size() + fresh.size()).is_equal(StudioAssets.placeable().size())
	_chip("sources_old", true)
	assert_array(_panel.matching_ids()).contains_exactly_in_any_order(old)
	_chip("sources_old", false)
	_chip("sources_new", true)
	assert_array(_panel.matching_ids()).contains_exactly_in_any_order(fresh)
	_chip("sources_old", true)
	assert_array(_panel.matching_ids()).contains_exactly_in_any_order(StudioAssets.placeable())


func test_category_tabs_are_the_trees_categories_in_order() -> void:
	var expected: Array[String] = []
	var placeable: Dictionary = {}
	for art: String in StudioAssets.placeable():
		placeable[art] = StudioAssets.entry_of(art)
	for category: Dictionary in StudioCatalog.tree(StudioAssets.categories(), placeable):
		expected.append("Tab_" + String(category.id))
	var found: Array[String] = []
	for node: Node in _panel.find_child("ViewRow", true, false).get_children():
		if node is Button and node.name.begins_with("Tab_") and not node.name in ["Tab_all", "Tab_recent", "Tab_placed"]:
			found.append(String(node.name))
	assert_array(found).is_equal(expected)
	assert_bool("Tab_interactive" in found).is_false()
	assert_bool("Tab_people" in found and "Tab_markers" in found).override_failure_message("S6 adds people and markers").is_true()
	assert_bool("Tab_nature" in found and "Tab_furniture" in found).is_true()


func test_nature_subcategory_tabs_are_its_used_subcategories() -> void:
	_tab("Tab_nature").pressed.emit()
	var used: Dictionary = {}
	for art: String in StudioAssets.placeable():
		var entry := StudioAssets.entry_of(art)
		if entry.category == "nature":
			used[entry.subcategory] = true
	var found: Array[String] = []
	for node: Node in _panel.find_child("SubRow", true, false).get_children():
		if node is Button and node.name != "Sub_all":
			found.append(String(node.name).trim_prefix("Sub_"))
	assert_array(found).contains_exactly_in_any_order(used.keys())
	assert_bool("bushes_and_flowers" in found).is_true()
	assert_object(_panel.find_child("Sub_all", true, false)).is_not_null()
	_tab("Tab_furniture").pressed.emit()
	assert_object(_panel.find_child("Sub_bushes_and_flowers", true, false)).is_null()


func test_acceptance_bushes_outdoor_and_indoor_furniture() -> void:
	_tab("Tab_nature").pressed.emit()
	(_panel.find_child("Sub_bushes_and_flowers", true, false) as Button).pressed.emit()
	_chip("places_outdoor", true)
	# Since the 2026-10-15 expansion the bushes include shrubs, hedges and planters: the four first ones, and only
	# outdoor bushes and flowers.
	var bushes := _panel.matching_ids()
	assert_array(bushes).contains(["bush", "bush2", "flowerbed", "flowerpot"])
	for art: String in bushes:
		assert_str(String(StudioAssets.entry_of(art).subcategory)).is_equal("bushes_and_flowers")
		assert_bool("outdoor" in StudioAssets.entry_of(art).get("place", [])).override_failure_message(art).is_true()
	_panel.reset_filters()
	_tab("Tab_furniture").pressed.emit()
	_chip("places_indoor", true)
	var furniture := _panel.matching_ids()
	assert_array(furniture).contains(["bed", "chair", "desk"])
	for art: String in furniture:
		assert_bool("indoor" in StudioAssets.entry_of(art).get("place", [])).override_failure_message(art).is_true()
	assert_array(_chosen).is_empty()


func test_choosing_another_category_clears_the_subcategory() -> void:
	_tab("Tab_nature").pressed.emit()
	(_panel.find_child("Sub_trees", true, false) as Button).pressed.emit()
	assert_str(_panel.filters().subcategory).is_equal("trees")
	assert_bool("oak" in _panel.matching_ids()).is_true()
	assert_bool("barrel" in _panel.matching_ids()).is_false()
	_tab("Tab_furniture").pressed.emit()
	assert_str(_panel.filters().subcategory).is_equal("")
	assert_bool("bed" in _panel.matching_ids()).is_true()
	assert_bool("oak" in _panel.matching_ids()).is_false()


func test_footprint_solidity_and_flat_chips_behave_as_the_query_does() -> void:
	_chip("footprints_2x1", true)
	var wide := _panel.matching_ids()
	assert_array(wide).is_not_empty()
	for art: String in wide:
		assert_array(StudioAssets.entry_of(art).size).is_equal([2, 1])
	_chip("footprints_2x1", false)
	_chip("footprints_bigger", true)
	var big := _panel.matching_ids()
	assert_bool("home" in big).is_true()
	for art: String in big:
		assert_str(StudioCatalog.footprint_class(StudioAssets.entry_of(art).size)).is_equal("bigger")
	_chip("footprints_bigger", false)
	_chip("solidity_walkable", true)
	var walkable := _panel.matching_ids()
	assert_array(walkable).is_not_empty()
	for art: String in walkable:
		assert_bool(bool(StudioAssets.entry_of(art).get("solid", true))).is_false()
	_chip("solidity_solid", true)
	assert_array(_panel.matching_ids()).is_equal(StudioAssets.placeable())
	_panel.reset_filters()
	_chip("flat", true)
	var flat := _panel.matching_ids()
	assert_array(flat).is_not_empty()
	for art: String in flat:
		assert_str(String(StudioAssets.entry_of(art).get("draw_layer", ""))).is_equal("ground")
	assert_array(StudioCatalogFilter.query(_entries(), {"flat": true})).is_equal(flat)


func test_chips_in_one_group_are_any_of_and_groups_combine() -> void:
	_chip("places_outdoor", true)
	_chip("places_indoor", true)
	assert_array(_panel.filters().places).is_equal(["outdoor", "indoor"])
	var both := _panel.matching_ids()
	_chip("places_indoor", false)
	var outdoor := _panel.matching_ids()
	assert_int(outdoor.size()).is_less_equal(both.size())
	_chip("footprints_1x1", true)
	for art: String in _panel.matching_ids():
		assert_bool(art in outdoor).is_true()
		assert_array(StudioAssets.entry_of(art).get("size", [1, 1])).is_equal([1, 1])
	assert_bool(_chip_button("footprints_1x1").theme_type_variation == "PrimaryButton").is_true()


func test_typing_on_a_category_searches_every_category() -> void:
	_tab("Tab_furniture").pressed.emit()
	assert_bool("oak" in _panel.matching_ids()).is_false()
	_panel.search_for("oak")
	assert_str(_panel.filters().view).is_equal("all")
	assert_str(_panel.filters().category).is_equal("")
	assert_bool("oak" in _panel.matching_ids()).is_true()


func test_recent_lists_the_last_used_first_and_says_so_when_empty() -> void:
	_tab("Tab_recent").pressed.emit()
	assert_array(_panel.matching_ids()).is_empty()
	assert_str(_empty().text).is_equal(StudioText.t("catalog_recent_empty"))
	assert_bool(_empty().visible).is_true()
	_panel.note_used("barrel")
	_panel.note_used("oak")
	_panel.note_used("barrel")
	assert_array(_panel.matching_ids()).is_equal(["barrel", "oak"])
	assert_bool(_empty().visible).is_false()
	assert_array(StudioPlacePanel.recent).is_equal(["barrel", "oak"])
	_panel.search_for("oak")
	assert_array(_panel.matching_ids()).is_equal(["oak"])
	assert_str(_panel.filters().view).is_equal("recent")


func test_on_this_map_lists_what_stands_there() -> void:
	_tab("Tab_placed").pressed.emit()
	assert_str(_empty().text).is_equal(StudioText.t("catalog_placed_empty"))
	_panel.set_placed(["oak", "barrel"])
	assert_array(_panel.matching_ids()).contains_exactly_in_any_order(["oak", "barrel"])
	assert_array(_panel.shown).has_size(2)
	_panel.set_placed([])
	assert_array(_panel.matching_ids()).is_empty()
	assert_bool(_empty().visible).is_true()
	assert_str(_empty().text).is_equal(StudioText.t("catalog_placed_empty"))


func test_thumbnails_fit_64_px_and_a_framed_lamp_shows_its_first_frame() -> void:
	for art: String in _panel.matching_ids():
		var picture := _card(art).picture
		if picture.texture == null:
			continue
		assert_int(picture.texture.get_width()).is_between(1, 64)
		assert_int(picture.texture.get_height()).is_between(1, 64)
		assert_int(picture.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
		assert_int(picture.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_CENTERED)
	var sheet := OverworldArt.prop("lamppost")
	var frames := OverworldArt.frames("lamppost")
	assert_int(frames).is_greater(1)
	var first := sheet.get_image().get_region(Rect2i(0, 0, sheet.get_width() / frames, sheet.get_height()))
	var used := first.get_used_rect()
	var thumb := _card("lamppost").picture.texture
	var scale := float(thumb.get_height()) / float(used.size.y)
	assert_float(float(thumb.get_width())).is_between(used.size.x * scale - 1.0, used.size.x * scale + 1.0)
	assert_float(float(thumb.get_width())).is_less(float(sheet.get_width()) * scale / frames * 1.5)
	assert_bool(StudioThumbs.source("lamppost", "prop") in ["new", "old"]).is_true()


func test_hovering_previews_and_a_left_click_chooses_once() -> void:
	_panel.search_for("barr")
	await _frames(2)
	var card := _card("barrel")
	card.mouse_entered.emit()
	assert_str(_panel.preview.asset_id).is_equal("barrel")
	assert_array(_chosen).is_empty()
	_panel.clear_preview()
	assert_str(_panel.preview.asset_id).is_equal("barrel")
	card.mouse_exited.emit()
	_panel.clear_preview()
	assert_str(_panel.preview.asset_id).is_equal("")
	card.gui_input.emit(_click(MOUSE_BUTTON_RIGHT))
	card.gui_input.emit(_click(MOUSE_BUTTON_MIDDLE))
	assert_array(_chosen).is_empty()
	card.gui_input.emit(_click(MOUSE_BUTTON_LEFT))
	assert_array(_chosen).is_equal(["barrel"])
	assert_str(_panel.preview.asset_id).is_equal("barrel")


func test_the_card_being_placed_gets_the_amber_border() -> void:
	_panel.mark_placing("barrel")
	assert_bool(_card("barrel").is_placing()).is_true()
	assert_bool(_card("oak").is_placing()).is_false()
	_panel.mark_placing("")
	assert_bool(_card("barrel").is_placing()).is_false()


func test_cards_are_made_once_and_only_the_matching_ones_show() -> void:
	var before := _panel.find_children("Card_*", "", true, false).size()
	assert_int(before).is_equal(StudioAssets.placeable().size())
	_panel.search_for("barr")
	_panel.search_for("")
	assert_int(_panel.find_children("Card_*", "", true, false).size()).is_equal(before)
	_panel.search_for("barr")
	var visible_cards := 0
	for node: Node in _panel.find_children("Card_*", "", true, false):
		visible_cards += 1 if (node as Control).visible else 0
	assert_int(visible_cards).is_equal(_panel.matching_ids().size())


func test_the_panel_fits_the_dock() -> void:
	var minimum := _panel.get_combined_minimum_size()
	assert_float(minimum.y).is_less_equal(float(StudioStyle.PLACE))
	assert_float(minimum.x).is_less_equal(1440.0)
	_tab("Tab_furniture").pressed.emit()
	await _frames(2)
	assert_float(_panel.get_combined_minimum_size().y).is_less_equal(float(StudioStyle.PLACE))
	assert_float(_panel.get_combined_minimum_size().x).is_less_equal(1440.0)


func test_old_callers_filter_keys_still_work() -> void:
	_panel.set_filters({"category": "nature", "subcategory": "bushes_and_flowers", "place": "outdoor", "kind": "prop"})
	assert_array(_panel.matching_ids()).contains(["bush", "bush2", "flowerbed", "flowerpot"])
	assert_array(_panel.filters().places).is_equal(["outdoor"])
	assert_str(_panel.filters().kind).is_equal("prop")
	_panel.set_filters({"kind": "building"})
	assert_array(_panel.matching_ids()).is_empty()
	assert_str(_empty().text).is_equal(StudioText.t("browser_no_results"))


func test_reset_shows_every_placeable_entry() -> void:
	_panel.set_filters({"category": "nature", "text": "oak", "footprints": ["2x2"], "flat": true})
	_panel.reset_filters()
	assert_array(_panel.matching_ids()).is_equal(StudioAssets.placeable())
	assert_array(_panel.shown).has_size(StudioAssets.placeable().size())
	assert_str(_panel.filters().view).is_equal("all")
	assert_str(_panel.filters().text).is_equal("")
	assert_bool(_chip_button("flat").button_pressed).is_false()
	var search := _panel.find_child("Search", true, false) as LineEdit
	search.grab_focus()
	_panel.release_keyboard()
	assert_bool(search.has_focus()).is_false()


func _entries() -> Dictionary:
	var entries: Dictionary = {}
	for art: String in StudioAssets.placeable():
		entries[art] = StudioAssets.entry_of(art)
	return entries


func _tab(node_name: String) -> Button:
	var found := _panel.find_child(node_name, true, false) as Button
	assert_object(found).is_not_null()
	return found


func _chip_button(suffix: String) -> Button:
	var found := _panel.find_child("Chip_" + suffix, true, false) as Button
	assert_object(found).is_not_null()
	return found


func _chip(suffix: String, on: bool) -> void:
	_chip_button(suffix).button_pressed = on


func _card(art: String) -> StudioCatalogCard:
	var found := _panel.find_child("Card_" + art, true, false) as StudioCatalogCard
	assert_object(found).is_not_null()
	return found


func _empty() -> Label:
	return _panel.find_child("CardArea", true, false).get_child(1) as Label


func _click(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame
