class_name StudioCatalogCard
extends PanelContainer
## One picture in the Studio's catalog (Concept/v0.3/10, section 8.4): a small thumbnail with its name, its footprint
## in the corner and a badge for how old its drawing is. It reports the mouse and a left click; it decides nothing.

signal hovered(art: String)
signal unhovered(art: String)
signal picked(art: String)
signal context_requested(art: String, point: Vector2)

const WIDTH := 90
const HEIGHT := 86

var art := ""
var kind := "prop"
var display_name := ""
var footprint := Vector2i.ONE
var source := ""
var picture: TextureRect
var _placeholder: Label
var _loaded := false
var _hover := false
var _placing := false
var _needs_update := false


## `entry` is the catalog entry, with the `source` ("new" or "old") the panel added.
func _init(art_id := "", entry := {}) -> void:
	art = art_id
	name = "Card_" + art_id
	kind = String(entry.get("kind", "prop"))
	display_name = String(entry.get("name", art_id))
	var size_data: Variant = entry.get("size", [1, 1])
	footprint = Vector2i(1, 1)
	if size_data is Array and (size_data as Array).size() == 2:
		footprint = Vector2i(maxi(1, int(size_data[0])), maxi(1, int(size_data[1])))
	source = String(entry.get("source", ""))
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	# PASS, not STOP: a STOP control swallows the mouse wheel, so the cards would not scroll their list.
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = StudioText.t("catalog_card_tip") % [display_name, art, footprint.x, footprint.y]
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	add_child(body)
	picture = TextureRect.new()
	picture.name = "Picture"
	picture.position = Vector2((WIDTH - StudioThumbs.SIZE) / 2.0, 3)
	picture.size = Vector2(StudioThumbs.SIZE, StudioThumbs.SIZE)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(picture)
	_placeholder = _corner("?", UiTheme.FAINT, 18)
	_placeholder.position = picture.position
	_placeholder.size = picture.size
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.visible = false
	body.add_child(_placeholder)
	var feet := _corner("%d×%d" % [footprint.x, footprint.y], UiTheme.MUTED, 10)
	feet.name = "Footprint"
	feet.position = Vector2(3, 1)
	body.add_child(feet)
	var badge := _corner(
		StudioText.t("badge_old") if source == "old" else StudioText.t("badge_new"),
		UiTheme.AMBER if source == "old" else UiTheme.FAINT,
		10
	)
	badge.name = "Badge"
	badge.position = Vector2(WIDTH - 41, 1)
	badge.size = Vector2(38, 12)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(badge)
	var title := _corner(display_name, UiTheme.TEXT, 12)
	title.name = "Name"
	title.position = Vector2(2, 68)
	title.size = Vector2(WIDTH - 4, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	body.add_child(title)
	_restyle()
	mouse_entered.connect(func() -> void:
		_hover = true
		_restyle()
		hovered.emit(art)
	)
	mouse_exited.connect(func() -> void:
		_hover = false
		_restyle()
		unhovered.emit(art)
	)
	gui_input.connect(_input_event)


## Shows or hides the card. The thumbnail is made the first time the card is shown.
func present(on: bool) -> void:
	visible = on
	if on and not _loaded:
		_loaded = true
		picture.texture = StudioThumbs.thumb(art, kind)
		_placeholder.visible = picture.texture == null


## The amber border of the picture being placed.
func set_placing(on: bool) -> void:
	_placing = on
	_restyle()


func is_placing() -> bool:
	return _placing


func invalidate_picture() -> void:
	_loaded = false


func set_needs_update(on: bool) -> void:
	_needs_update = on
	var badge := find_child("Badge", true, false) as Label
	badge.text = "Update" if on else StudioText.t("badge_old" if source == "old" else "badge_new")
	badge.add_theme_color_override("font_color", UiTheme.AMBER if on or source == "old" else UiTheme.FAINT)
	_restyle()


## The line the panel lists for this card: "Barrel   barrel   1 x 1".
func listing() -> String:
	return "%s   %s   %d x %d" % [display_name, art, footprint.x, footprint.y]


func _input_event(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(art)
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		context_requested.emit(art, get_screen_transform() * click.position)
		accept_event()


func _restyle() -> void:
	var border := UiTheme.AMBER if _placing else (UiTheme.AMBER_DIM if _hover or _needs_update else UiTheme.LINE_SOFT)
	var background := UiTheme.PANEL_3 if _hover else UiTheme.PANEL_2
	add_theme_stylebox_override("panel", UiTheme.box(background, border, 2 if _placing else 1, 3, Vector2.ZERO))


static func _corner(text: String, colour: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label
