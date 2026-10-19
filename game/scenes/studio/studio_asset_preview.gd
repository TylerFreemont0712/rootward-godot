class_name StudioAssetPreview
extends PanelContainer
## One small picture of the asset being browsed or selected. It uses the game's preferred world art and shows only
## the same default state shown in town. Footprint metadata never stretches a picture; TextureRect preserves its aspect ratio.

var asset_id := ""
var object_data: Dictionary = {}
var display_name := ""
var footprint := Vector2i.ONE
var missing_art := true
var source_size := Vector2.ZERO
var frame_size := Vector2.ZERO
var picture: TextureRect

var _name_label: Label
var _details: Label
var _category: Label
var _placeholder: Label
var _picture_box: Control


func _init() -> void:
	name = "AssetPreview"
	custom_minimum_size.x = 220
	size_flags_horizontal = Control.SIZE_FILL
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(6, 4)))
	var body := Ui.vbox([], 3)
	add_child(body)
	body.add_child(StudioStyle.caption(StudioText.t("asset_preview")))
	var image_box := PanelContainer.new()
	image_box.custom_minimum_size = Vector2(88, 100)
	image_box.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.LINE_SOFT, 1, 0, Vector2.ZERO))
	_picture_box = Control.new()
	_picture_box.custom_minimum_size = Vector2(88, 100)
	image_box.add_child(_picture_box)
	_picture_box.resized.connect(_fit_picture)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture_box.add_child(picture)
	_placeholder = Ui.label("", "Faint", true)
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.add_theme_font_size_override("font_size", 12)
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_box.add_child(_placeholder)
	_name_label = Ui.label("", "", true)
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.max_lines_visible = 2
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_details = StudioStyle.caption("")
	_details.clip_text = true
	_category = Ui.label("", "Muted", true)
	_category.add_theme_font_size_override("font_size", 12)
	_category.max_lines_visible = 3
	_category.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var words := Ui.vbox([_name_label, _details, _category], 2)
	words.custom_minimum_size.x = 112
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(Ui.hbox([image_box, words], 6))
	clear_preview()


func preview_asset(art: String, object: Dictionary = {}) -> void:
	asset_id = art
	object_data = object.duplicate(true)
	var entry := StudioAssets.entry_of(art)
	display_name = String(object.get("name", entry.get("name", art)))
	var kind := String(object.get("kind", entry.get("kind", "prop")))
	var size_data: Variant = object.get("size", entry.get("size", [1, 1]))
	footprint = size_data if size_data is Vector2i else OverworldMap.cell_of(size_data)
	_name_label.text = display_name
	_name_label.tooltip_text = display_name + " · " + art
	var kind_text := StudioText.t("browser_" + kind) if kind in StudioAssets.KINDS else kind.capitalize()
	_details.text = kind_text + " · " + StudioText.t("asset_preview_footprint") % [footprint.x, footprint.y]
	_category.text = _metadata(entry)
	_category.tooltip_text = _category.text
	var source: Texture2D = null
	# A remake not made yet shows its source's picture (OverworldArt.stand_ins), as the town draws it.
	var drawn := TownMapView._drawn_art({"art": art})
	if kind == "building":
		source = OverworldArt.building(drawn)
	elif kind == "prop" or kind == "sign":
		source = OverworldArt.prop(drawn)
	elif kind in ["person", "warp", "start"]:
		# A townsperson's front frame, or a marker's icon: the catalog card's own picture.
		source = StudioThumbs.thumb(art, kind)
		drawn = ""
	missing_art = source == null
	picture.flip_h = bool(object.get("flip", false))
	picture.texture = null
	source_size = Vector2.ZERO
	frame_size = Vector2.ZERO
	if source != null:
		source_size = source.get_size()
		var frames := OverworldArt.frames(drawn) if drawn != "" else 1
		frame_size = Vector2(source_size.x / float(frames), source_size.y)
		if frames > 1:
			var first := AtlasTexture.new()
			first.atlas = source
			first.region = Rect2(Vector2(frame_size.x * OverworldArt.preview_frame(drawn, object), 0), frame_size)
			first.filter_clip = true
			picture.texture = first
		else:
			picture.texture = source
	_placeholder.text = StudioText.t("asset_preview_missing")
	_placeholder.visible = missing_art
	picture.visible = not missing_art
	_fit_picture()


## The preview uses the same proportions as the placed instance, including a deliberately resized picture.
func _fit_picture() -> void:
	if picture == null or _picture_box == null:
		return
	var box := _picture_box.size
	var stretch := TownMapView._stretch(object_data) if not object_data.is_empty() else Vector2.ONE
	if stretch == Vector2.ONE or frame_size == Vector2.ZERO:
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2.ZERO
		picture.size = box
		return
	var drawn := frame_size * stretch
	var ratio := minf(box.x / maxf(drawn.x, 1), box.y / maxf(drawn.y, 1))
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.size = drawn * ratio
	picture.position = (box - picture.size) / 2.0


func clear_preview() -> void:
	asset_id = ""
	object_data = {}
	display_name = ""
	footprint = Vector2i.ONE
	missing_art = true
	source_size = Vector2.ZERO
	frame_size = Vector2.ZERO
	picture.texture = null
	picture.flip_h = false
	picture.visible = false
	_placeholder.visible = true
	_placeholder.text = StudioText.t("asset_preview_empty")
	_name_label.text = ""
	_details.text = ""
	_category.text = ""


func _metadata(entry: Dictionary) -> String:
	var place_words: Array[String] = []
	for place: String in entry.get("place", []):
		place_words.append(StudioText.t("browser_" + place))
	var category_id := String(entry.get("category", ""))
	var subcategory_id := String(entry.get("subcategory", ""))
	var category_name := StudioText.t("asset_preview_unknown")
	var subcategory_name := ""
	for category: Dictionary in StudioAssets.categories():
		if String(category.get("id", "")) != category_id:
			continue
		category_name = String(category.get("name", category_id))
		for subcategory: Dictionary in category.get("subcategories", []):
			if String(subcategory.get("id", "")) == subcategory_id:
				subcategory_name = String(subcategory.get("name", subcategory_id))
	var path := category_name + (" / " + subcategory_name if subcategory_name != "" else "")
	return " · ".join(place_words) + "\n" + path if not place_words.is_empty() else path
