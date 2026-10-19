extends GdUnitTestSuite
## The catalog cards' hover and left-click behaviour, and the preview card's one undistorted picture in the dock.
## (The tabs, chips and views are tested in studio_catalog_panel_test.gd.)
## The catalog and real pictures are read only. No game state, saves, drafts or content files are written.

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


func test_only_left_click_chooses_an_asset_and_updates_preview() -> void:
	_panel.search_for("barr")
	assert_str(_panel.matching_ids()[0]).is_equal("barrel")
	var card := _card("barrel")
	card.gui_input.emit(_click(MOUSE_BUTTON_RIGHT))
	card.gui_input.emit(_click(MOUSE_BUTTON_MIDDLE))
	assert_array(_chosen).is_empty()
	assert_str(_panel.preview.asset_id).is_equal("")
	card.gui_input.emit(_click(MOUSE_BUTTON_LEFT))
	assert_array(_chosen).is_equal(["barrel"])
	assert_str(_panel.preview.asset_id).is_equal("barrel")


func test_hover_previews_without_placing_and_survives_a_selection_clear() -> void:
	_panel.search_for("barr")
	await _frames(2)
	var card := _card("barrel")
	card.mouse_entered.emit()
	assert_array(_chosen).is_empty()
	assert_str(_panel.preview.asset_id).is_equal("barrel")
	assert_dict(_panel.preview.object_data).is_empty()
	_panel.clear_preview()
	assert_str(_panel.preview.asset_id).is_equal("barrel")
	card.mouse_exited.emit()
	_panel.clear_preview()
	assert_str(_panel.preview.asset_id).is_equal("")


func test_search_finds_category_words_and_reset_recovers_no_results() -> void:
	_panel.search_for("farm and work")
	assert_bool("barrel" in _panel.matching_ids()).is_true()
	assert_bool("bed" in _panel.matching_ids()).is_false()
	_panel.set_filters({"category": "furniture", "place": "indoor", "kind": "prop", "text": "nothing-like-this-asset"})
	assert_array(_panel.matching_ids()).is_empty()
	assert_array(_panel.shown).is_empty()
	_button(StudioText.t("browser_reset")).pressed.emit()
	assert_array(_panel.matching_ids()).is_equal(StudioAssets.placeable())


func test_missing_art_uses_a_plain_placeholder_and_can_be_cleared() -> void:
	_panel.preview_asset("not-a-real-picture", {"kind": "building", "size": [3, 4], "name": "Lost house"})
	assert_bool(_panel.preview.missing_art).is_true()
	assert_object(_panel.preview.picture.texture).is_null()
	assert_that(_panel.preview.frame_size).is_equal(Vector2.ZERO)
	assert_that(_panel.preview.footprint).is_equal(Vector2i(3, 4))
	assert_str(_panel.preview.display_name).is_equal("Lost house")
	_panel.clear_preview()
	assert_str(_panel.preview.asset_id).is_equal("")
	assert_that(_panel.preview.footprint).is_equal(Vector2i.ONE)


func test_a_framed_prop_previews_its_town_default_frame_with_nearest_filtering() -> void:
	var art := "lamppost"
	var source := OverworldArt.prop(art)
	var frames := OverworldArt.frames(art)
	assert_object(source).is_not_null()
	assert_int(frames).is_greater(1)
	_panel.preview_asset(art)
	var first := _panel.preview.picture.texture as AtlasTexture
	assert_object(first).is_not_null()
	assert_bool(is_same(first.atlas, source)).is_true()
	assert_that(first.region.position).is_equal(Vector2(source.get_width() / float(frames) * OverworldArt.preview_frame(art), 0))
	assert_that(first.region.size).is_equal(Vector2(source.get_width() / float(frames), source.get_height()))
	assert_int(_panel.preview.picture.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_int(_panel.preview.picture.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_bool(first.filter_clip).is_true()


func test_world_selection_previews_real_size_and_flip_without_mutating_the_instance() -> void:
	var object := {"kind": "prop", "art": "barrel", "at": [12, 5], "size": [2, 1], "flip": true, "id": "selected-barrel"}
	var before := object.duplicate(true)
	_panel.preview_asset("barrel", object)
	assert_str(_panel.preview.asset_id).is_equal("barrel")
	assert_that(_panel.preview.footprint).is_equal(Vector2i(2, 1))
	assert_bool(_panel.preview.picture.flip_h).is_true()
	assert_bool(is_same(_panel.preview.picture.texture, OverworldArt.prop("barrel"))).is_true()
	assert_that(_panel.preview.frame_size).is_equal(OverworldArt.prop("barrel").get_size())
	assert_dict(object).is_equal(before)
	_panel.preview.object_data.id = "changed-preview-copy"
	assert_str(object.id).is_equal("selected-barrel")
	assert_array(_chosen).is_empty()


func test_building_preview_uses_the_game_renderer_and_fits_the_current_dock() -> void:
	_panel.preview_asset("home", {"kind": "building", "size": Vector2i(6, 6), "name": "Selected home"})
	await _frames(3)
	assert_bool(is_same(_panel.preview.picture.texture, OverworldArt.building("home"))).is_true()
	assert_str(_panel.preview.display_name).is_equal("Selected home")
	assert_that(_panel.preview.footprint).is_equal(Vector2i(6, 6))
	assert_float(_panel.get_combined_minimum_size().y).is_less_equal(float(StudioStyle.PLACE))
	assert_float(_panel.get_combined_minimum_size().x).is_less_equal(1440.0)


func _card(art: String) -> StudioCatalogCard:
	return _panel.find_child("Card_" + art, true, false) as StudioCatalogCard


func _click(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _button(text: String) -> Button:
	for node: Node in _panel.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame
