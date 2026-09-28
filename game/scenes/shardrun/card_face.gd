class_name CardFace
extends Control
## A card as a card: a painted frame in its paradigm's colour (cards/frame, tinted by ui/card_tint.gdshader), its cost
## in the mana orb, its name on the banner, its picture in the window, and its speed on the plate. Only that: what it
## does is shown beside it while it is pointed at (CardDetail). A missing frame falls back to one drawn in code.
##
## It can be dragged (Godot's own drag and drop) and dropped onto: its table decides what a move means, through the
## `moved` and `pressed` Callables it is given. `spot` is where the card sits ({zone, index, spell?}).

enum Size { HAND, SLOT, DECK }

## The frame's own proportions (480 x 664), at three sizes in the design canvas.
const SIZES := {Size.HAND: Vector2(164, 227), Size.SLOT: Vector2(122, 169), Size.DECK: Vector2(140, 194)}
## Where the frame has room for each part, as shares of its size ([left, top, right, bottom]; the orb [x, y, radius
## of the width]). The pipeline writes the same numbers beside the frame (layouts.CARD); these are its fallback.
const GEOMETRY := {
	"art": [0.075, 0.108, 0.925, 0.635],
	"banner": [0.14, 0.052, 0.94, 0.132],
	"orb": [0.13, 0.088, 0.105],
	"plate": [0.2, 0.655, 0.8, 0.715],
	"lower": [0.1, 0.74, 0.9, 0.95],
	"radius": [0.07],
}
## The colour of the element a shard gives its bolts, for an old shard's frame; a program card takes its paradigm's.
const ELEMENT_FRAME := {"fire": "#ff9147", "frost": "#82d8ff", "spark": "#ffe066"}
const TINT := preload("res://ui/card_tint.gdshader")
const FRAME := "cards/frame"
const DETAIL_DELAY := 0.08

static var _geometry: Dictionary = {}

var shard_id := ""
var spot: Dictionary = {}
var shard: Dictionary = {}
var language := "python"
## The card's colour: its paradigm's (a program card), its element's or its rarity's (an old shard).
var colour := UiTheme.SHARD
## Called with (from spot, to spot) when a card is dropped on this one, and with (spot, button) when it is clicked.
var moved: Callable
var pressed: Callable
var draggable := true
## Whether pointing at it shows what it does (CardDetail).
var details := true
var _summaries := true
var _catalog: Dictionary = {}
var _tags: Array[String] = []
var _label := ""
var _armed := false
var _dragging := false
var _detail: CardDetail
var _hover_time := -1.0
var _art: Control
var _frame: TextureRect
var _role: RoleBadge
var _keywords: KeywordChips
var _name: Label
var _cost: Label
var _speed: Label


static func create(
	id: String, catalog: Dictionary, run_language: String, summaries: bool, size_kind: Size, at := {}
) -> CardFace:
	var card := CardFace.new()
	card.shard_id = id
	card.spot = at
	card.shard = catalog.shards.get(id, {"id": id, "name": id, "rarity": "common"})
	card.language = run_language
	card._summaries = summaries
	card._catalog = catalog
	card._describe(catalog)
	card._build(size_kind)
	return card


## An empty place a card can be dropped into (the Program's open slot, the hold's free place).
static func slot(at: Dictionary, label: String, size_kind: Size) -> CardFace:
	var card := CardFace.new()
	card.spot = at
	card.draggable = false
	card.details = false
	card._label = label
	card.custom_minimum_size = SIZES[size_kind]
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	return card


static func geometry() -> Dictionary:
	if _geometry.is_empty():
		_geometry = GEOMETRY.duplicate(true)
		var path := Art.ROOT + FRAME + ".json"
		if FileAccess.file_exists(path):
			var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if written is Dictionary:
				_geometry.merge(written, true)
	return _geometry


static func box(name: String, card_size: Vector2) -> Rect2:
	var shares: Array = geometry()[name]
	var from := Vector2(float(shares[0]) * card_size.x, float(shares[1]) * card_size.y)
	return Rect2(from, Vector2(float(shares[2]) * card_size.x, float(shares[3]) * card_size.y) - from)


## The card's colour and what kind of card it is, in words: a program card's role and paradigm, a shard's rarity.
func _describe(catalog: Dictionary) -> void:
	var rarity := UiTheme.rarity(shard.get("rarity", "common"))
	colour = Color(ELEMENT_FRAME.get(element_of(shard), rarity.to_html()))
	if shard.has("paradigm"):
		var paradigm := ProgramDraft.paradigm_of(catalog, String(shard.paradigm)) if catalog.has("programs") else {}
		colour = Color(paradigm.get("colour", "#8d8fa0"))
		_tags.append(String(paradigm.get("name", "Neutral")))
		if shard.has("needs"):
			_tags.append("needs %s bolts" % shard.needs)
		if shard.has("makes"):
			_tags.append("leaves them %s" % shard.makes)
	else:
		_tags.append(String(shard.get("rarity", "common")).capitalize())


func _build(size_kind: Size) -> void:
	custom_minimum_size = SIZES[size_kind]
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_art = Ui.picture(ShardrunViews.art(shard, shard_id), Vector2(64, 64), "◆")
	add_child(_art)
	var texture := Art.texture(FRAME)
	if texture != null:
		_frame = TextureRect.new()
		_frame.texture = texture
		_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame.stretch_mode = TextureRect.STRETCH_SCALE
		_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var tint := ShaderMaterial.new()
		tint.shader = TINT
		tint.set_shader_parameter("tint", colour)
		_frame.material = tint
		add_child(_frame)
	if RoleBadge.ROLES.has(String(shard.get("role", ""))):
		# Over the frame's lower panel, so it is drawn after (above) the frame.
		_role = RoleBadge.create(String(shard.role))
		add_child(_role)
	if not (shard.get("keywords", []) as Array).is_empty():
		_keywords = KeywordChips.create(shard.keywords)
		add_child(_keywords)
	_name = _text(UiTheme.ui_font(600), Color("#f4ead2"))
	_cost = _text(UiTheme.ui_font(600), Color.WHITE)
	_speed = _text(UiTheme.ui_font(600), colour.lightened(0.45))
	_name.text = shard.get("name", shard_id)
	_cost.text = str(int(shard.get("cost", 0)))
	_speed.text = ShardrunViews.complexity(shard)
	for child in get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	_layout()


func _text(font: Font, tint: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	# No padding from the theme: the frame's boxes are the margins.
	label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_child(label)
	return label


## Every part where the frame has room for it, at the card's current size.
func _layout() -> void:
	if _name == null:
		return
	var card_size := custom_minimum_size
	if _frame != null:
		_frame.position = Vector2.ZERO
		_frame.size = card_size
	var window := box("art", card_size)
	# The picture sits a little above the window's middle, well clear of the speed plate under the window.
	var side := minf(window.size.x, window.size.y) * 0.64
	_art.custom_minimum_size = Vector2(side, side)
	_art.size = Vector2(side, side)
	_art.position = window.get_center() - Vector2(side, side) * 0.5 - Vector2(0, window.size.y * 0.05)
	# The name may stand a little taller than the banner: its outline keeps it readable over the frame.
	var banner := box("banner", card_size).grow_individual(0, card_size.y * 0.012, 0, card_size.y * 0.012)
	_place(_name, Rect2(banner.position + Vector2(banner.size.x * 0.07, 0), banner.size * Vector2(0.9, 1.0)))
	_fit(_name, banner.size.y * 0.78, banner.size.x * 0.84)
	var shares: Array = geometry().orb
	var radius := float(shares[2]) * card_size.x
	var orb := Rect2(
		Vector2(float(shares[0]) * card_size.x, float(shares[1]) * card_size.y) - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0
	)
	# The digit sits on a dark disc inside the crystal: on the bright facets alone a 1 read as a T.
	_place(_cost, orb.grow(-radius * 0.22))
	_cost.add_theme_font_size_override("font_size", int(radius * 1.3))
	var disc := UiTheme.box(Color(0.1, 0.04, 0.2, 0.82), Color(1, 1, 1, 0.35), 1, int(radius), Vector2.ZERO)
	_cost.add_theme_stylebox_override("normal", disc)
	var plate := box("plate", card_size)
	_place(_speed, plate)
	_fit(_speed, plate.size.y * 1.2, plate.size.x * 0.92)
	if _role != null:
		# A pill in the middle of the lower panel, over its filigree, leaving the ornament's ends to either side.
		var lower := box("lower", card_size)
		var pill := Vector2(lower.size.x * 0.78, lower.size.y * 0.5)
		_role.position = lower.get_center() - pill * 0.5
		_role.size = pill
		_role.queue_redraw()
	if _keywords != null:
		# Along the bottom of the picture's window, under the picture.
		var chips := Vector2(window.size.x * 0.96, maxf(13.0, window.size.y * 0.14))
		_keywords.position = Vector2(window.get_center().x - chips.x * 0.5, window.end.y - chips.y * 1.15)
		_keywords.size = chips
		_keywords.queue_redraw()
	queue_redraw()


static func _place(label: Label, rect: Rect2) -> void:
	label.position = rect.position
	label.size = rect.size


## The largest font size up to `most` at which the label's text fits `width`.
static func _fit(label: Label, most: float, width: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := int(most)
	while font_size > 8 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _draw() -> void:
	var card_size := custom_minimum_size
	if shard_id == "":
		# An empty slot: a dashed outline and its label.
		var rect := Rect2(Vector2.ONE * 3.0, card_size - Vector2.ONE * 6.0)
		draw_style_box(UiTheme.box(Color(0, 0, 0, 0.25), Color(UiTheme.LINE, 0.9), 1, 10), rect)
		var font := UiTheme.ui_font()
		var at := Vector2(0, card_size.y * 0.5 + 5)
		draw_string(font, at, _label, HORIZONTAL_ALIGNMENT_CENTER, card_size.x, 12, UiTheme.FAINT)
		return
	var radius := float(geometry().radius[0]) * card_size.x
	# Behind the frame's window: a dark glow in the card's colour, for its picture to stand in.
	var window := box("art", card_size)
	draw_style_box(UiTheme.box(Color("#0c0b12"), Color.TRANSPARENT, 0, int(radius * 0.4)), window)
	var centre := window.get_center()
	for ring in 6:
		var reach := window.size.x * (0.5 - ring * 0.07)
		draw_circle(centre, reach, Color(colour, 0.05 + ring * 0.018))
	if _frame != null:
		return
	# No painted frame: a plain one in code, so a missing asset never breaks the table.
	var body := UiTheme.box(Color("#262833").lerp(colour, 0.18), colour.darkened(0.1), 3, int(radius))
	draw_style_box(body, Rect2(Vector2.ZERO, card_size))
	draw_style_box(UiTheme.box(Color.TRANSPARENT, Color("#c49a45"), 2, int(radius * 0.4)), window.grow(2.0))
	var banner := box("banner", card_size)
	draw_rect(banner, Color("#3c3f4c").lerp(colour, 0.3))
	draw_style_box(UiTheme.box(Color("#1b1d24"), Color("#c49a45"), 1, 6), box("plate", card_size))
	var shares: Array = geometry().orb
	var orb := Vector2(float(shares[0]) * card_size.x, float(shares[1]) * card_size.y)
	draw_circle(orb, float(shares[2]) * card_size.x * 1.15, Color("#c49a45"))
	draw_circle(orb, float(shares[2]) * card_size.x, Color("#3a2466"))


## The element a shard gives its bolts, read from its first worked example ("" when it gives none).
static func element_of(item: Dictionary) -> String:
	for example: Dictionary in item.get("examples", []):
		var given: Array = example.get("bolts", [])
		var expect: Array = example.get("expect", [])
		if expect.is_empty() or not expect[0] is Dictionary:
			continue
		var element: String = (expect[0] as Dictionary).get("element", "none")
		var before: String = (given[0] as Dictionary).get("element", "none") if not given.is_empty() else "none"
		if element != "none" and element != before:
			return element
		return ""
	return ""


# --- Pointing at it -------------------------------------------------------------------------------------------------


func _hover(on: bool) -> void:
	if not details or shard_id == "":
		return
	_hover_time = 0.0 if on else -1.0
	set_process(on)
	if not on and _detail != null:
		_detail.queue_free()
		_detail = null


## LEARN: a top-level child is placed in the canvas's own coordinates and escapes its parents' clipping, so a card deep
## inside a clipped table can still show its details over the whole screen; it is freed with the card.
func _process(delta: float) -> void:
	if _hover_time < 0.0:
		set_process(false)
		return
	_hover_time += delta
	if _detail == null and _hover_time >= DETAIL_DELAY and not _dragging:
		var forge: Dictionary = shard.get("forge", {})
		var into: String = (_catalog.shards.get(forge.get("into", ""), {}) as Dictionary).get(
			"name", forge.get("into", "")
		)
		var meanings: Dictionary = (
			(_catalog.get("programs", {}) as Dictionary).get("config", {}).get("keywords", {})
			if _catalog.has("programs")
			else {}
		)
		_detail = CardDetail.create(shard, shard_id, language, _summaries, colour, _tags, into, meanings)
		_detail.top_level = true
		_detail.z_index = 100
		_detail.z_as_relative = false
		add_child(_detail)
	if _detail != null:
		var shown := get_global_transform() * Rect2(Vector2.ZERO, size)
		_detail.place_beside(shown, get_viewport().get_visible_rect().size)


# --- Clicking and dragging ------------------------------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	# LEARN: a click commits on release. If it committed on press, the rules would redraw and free the source card
	# before Godot had enough mouse movement to start _get_drag_data.
	var click := event as InputEventMouseButton
	if click == null or not pressed.is_valid():
		return
	if click.button_index == MOUSE_BUTTON_RIGHT and click.pressed:
		pressed.call(spot, MOUSE_BUTTON_RIGHT)
		accept_event()
	elif click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
		_armed = true
		_dragging = false
		accept_event()
	elif click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		if _armed and not _dragging and Rect2(Vector2.ZERO, size).has_point(click.position):
			pressed.call(spot, MOUSE_BUTTON_LEFT)
		_armed = false
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable or shard_id == "" or not moved.is_valid():
		return null
	_dragging = true
	_armed = false
	_hover(false)
	var ghost := CardFace.create(shard_id, _catalog, language, false, Size.HAND)
	ghost.details = false
	ghost.modulate = Color(1, 1, 1, 0.96)
	ghost.rotation_degrees = -6.0
	ghost.scale = Vector2.ONE * 1.08
	set_drag_preview(ghost)
	modulate = Color(1, 1, 1, 0.28)
	return {"card_spot": spot}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return moved.is_valid() and data is Dictionary and (data as Dictionary).has("card_spot")


func _drop_data(_at: Vector2, data: Variant) -> void:
	moved.call((data as Dictionary).card_spot, spot)


func _notification(what: int) -> void:
	# A drag that ended anywhere gives the card its colour back (a successful move redraws the table anyway).
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE
		_dragging = false
