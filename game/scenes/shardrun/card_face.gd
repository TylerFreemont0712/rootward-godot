class_name CardFace
extends Control
## A program card uses Rootglass, a paradigm crest, a colour-coded role and a seeded, cosmetic edge finish. Older
## Spellforge cards keep the painted frame. The picture and cost sit on the face; the code and full explanation appear
## beside it while pointed at (CardDetail). A missing frame falls back to one drawn in code.
##
## It can be dragged (Godot's own drag and drop) and dropped onto: its table decides what a move means, through the
## `moved` and `pressed` Callables it is given. `spot` is where the card sits ({zone, index, spell?}).

enum Size { HAND, SLOT, DECK, DRAFT, FOCUS, REWARD }

## The frame's own proportions (480 x 664), at the sizes used around the game.
const SIZES := {
	Size.HAND: Vector2(194, 274),
	Size.SLOT: Vector2(122, 171),
	Size.DECK: Vector2(140, 196),
	Size.DRAFT: Vector2(204, 288),
	Size.FOCUS: Vector2(228, 322),
	Size.REWARD: Vector2(291, 411)
}
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
const COMPLEXITY_COLOURS := {
	"constant": "#20543d",
	"logarithmic": "#175d60",
	"linear": "#6a4d11",
	"linearithmic": "#315638",
	"quadratic": "#563276",
	"exponential": "#842f34",
	"pseudo": "#294c6b",
}
const ROOTGLASS_FRAME := "cards/rootglass"
const ROOTGLASS_ART_SCALE := 0.48
const ROOTGLASS_ART_LIFT := 0.06
const TINT := preload("res://ui/card_tint.gdshader")
const FRAME := "cards/frame"
const DETAIL_DELAY := 0.08
const ROOTGLASS_GEOMETRY := {
	"art": [0.0667, 0.1389, 0.9333, 0.8294],
	"title": [0.217, 0.0275, 0.797, 0.1275],
	"orb": [0.1167, 0.0833, 0.0778],
	"role": [0.1333, 0.619, 0.45, 0.702],
	"feature": [0.48, 0.619, 0.9, 0.702],
	"complexity": [0.14, 0.765, 0.55, 0.86],
	"speed": [0.55, 0.765, 0.89, 0.86],
	"radius": [0.07],
}

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
var _rootglass := false
var _tags: Array[String] = []
var _label := ""
var _armed := false
var _dragging := false
var _detail: CardDetail
var _hover_time := -1.0
var _art: Control
var _frame: TextureRect
var _role: RoleBadge
var _crest: CardCrest
var _keywords: KeywordChips
var _feature: Label
var _complexity: Label
var _wear: CardWear
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


## The Mutator edited this card for the fight (ADR-0026): a chip on its face, the edit among its tags, and the code its
## details show is the mutant's, the code that will run.
func mark_mutant(battle: Dictionary) -> void:
	var mutant: Dictionary = (battle.get("mutants", {}) as Dictionary).get(shard_id, {})
	if mutant.is_empty():
		return
	shard = shard.duplicate(true)
	(shard.code as Dictionary)[language] = ProgramGuardians.code_of(shard, language, battle)
	_tags.append(Text.f("MUTANT: %s", [Text.t(String(mutant.get("name", "edited")))]))
	var chip := Ui.panel(Ui.sized(Ui.tint(Ui.label(Text.t("MUTANT"), ""), UiTheme.FAIL), 11), "Chip")
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	# Over the art's top right corner, clear of the cost (top left) and the name.
	chip.size = chip.get_combined_minimum_size()
	var window := _box("art", custom_minimum_size)
	chip.position = Vector2(window.end.x - chip.size.x - 2.0, window.position.y + 2.0)


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
	_rootglass = shard.has("role")
	var rarity := UiTheme.rarity(shard.get("rarity", "common"))
	colour = Color(ELEMENT_FRAME.get(element_of(shard), rarity.to_html()))
	if shard.has("paradigm"):
		var paradigm := ProgramDraft.paradigm_of(catalog, String(shard.paradigm)) if catalog.has("programs") else {}
		colour = Color(paradigm.get("colour", "#8d8fa0"))
		_tags.append(Text.t(String(paradigm.get("name", "Neutral"))))
		if shard.has("needs"):
			_tags.append(Text.f("needs %s bolts", [Text.t(String(shard.needs))]))
		if shard.has("makes"):
			_tags.append(Text.f("leaves them %s", [Text.t(String(shard.makes))]))
	else:
		_tags.append(Text.t(String(shard.get("rarity", "common")).capitalize()))


func _build(size_kind: Size) -> void:
	custom_minimum_size = SIZES[size_kind]
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_art = Ui.picture(ShardrunViews.art(shard, shard_id), Vector2(64, 64), "◆")
	if _rootglass and _art is TextureRect:
		(_art as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_art)
	var frame_id := ROOTGLASS_FRAME if _rootglass else FRAME
	var texture := Art.texture(frame_id)
	if texture != null:
		_frame = TextureRect.new()
		_frame.texture = texture
		_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frame.stretch_mode = TextureRect.STRETCH_SCALE
		_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if not _rootglass:
			var tint := ShaderMaterial.new()
			tint.shader = TINT
			tint.set_shader_parameter("tint", colour)
			_frame.material = tint
		add_child(_frame)
	if _rootglass:
		var paradigm_id := String(shard.get("paradigm", "neutral"))
		var crest_colour := colour if shard.has("paradigm") else Color("#d9c796")
		_crest = CardCrest.create(paradigm_id, crest_colour)
		add_child(_crest)
	if RoleBadge.ROLES.has(String(shard.get("role", ""))):
		# The role pill is the first label in Rootglass's shared rules plaque.
		_role = RoleBadge.create(String(shard.role), _rootglass)
		add_child(_role)
	if not _rootglass and not (shard.get("keywords", []) as Array).is_empty():
		_keywords = KeywordChips.create(shard.keywords)
		add_child(_keywords)
	_name = _text(UiTheme.ui_font(600), Color("#fff0d8"), 4 if _rootglass else 5)
	_cost = _text(UiTheme.ui_font(600), Color("#fff0c3") if _rootglass else Color.WHITE, 1 if _rootglass else 5)
	_speed = _text(
		UiTheme.ui_font(600), Color("#26362e") if _rootglass else colour.lightened(0.45), 1 if _rootglass else 5
	)
	_name.text = Text.t(shard.get("name", shard_id))
	_cost.text = str(int(shard.get("cost", 0)))
	_speed.text = ShardrunViews.complexity(shard)
	if _rootglass:
		_feature = _text(UiTheme.ui_font(600), _feature_colour(), 1)
		_feature.text = _feature_text()
		_complexity = _text(UiTheme.ui_font(600), _complexity_colour(), 1)
		_complexity.text = String(shard.get("complexity", "linear")).to_upper()
		_wear = CardWear.create(colour if shard.has("paradigm") else UiTheme.AMBER)
		add_child(_wear)
	for child in get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	_layout()


func _text(font: Font, tint: Color, outline := 5) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", outline)
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
	# In a spell's compressed queue, the title jitters and cannot be read; hand and held-card names remain visible.
	_name.visible = String(spot.get("zone", "")) != "spell"
	var card_size := custom_minimum_size
	if _frame != null:
		_frame.position = Vector2.ZERO
		_frame.size = card_size
	var window := _box("art", card_size)
	if _rootglass and _art is TextureRect:
		# Rootglass's transparent frame opening masks the art to its oval, including the textbox overlap at the bottom.
		# A slight inset keeps isolated icon subjects from being unnaturally chopped at the oval's edge.
		var art_size := window.size * ROOTGLASS_ART_SCALE
		_art.custom_minimum_size = art_size
		_art.size = art_size
		_art.position = window.get_center() - art_size * 0.5 - Vector2(0, window.size.y * ROOTGLASS_ART_LIFT)
	else:
		# A fallback glyph or an older frame keeps its smaller, centered picture.
		var side := minf(window.size.x, window.size.y) * (0.58 if _rootglass else 0.64)
		_art.custom_minimum_size = Vector2(side, side)
		_art.size = Vector2(side, side)
		var art_shift := Vector2(0, window.size.y * (0.05 if _rootglass else -0.05))
		_art.position = window.get_center() - Vector2.ONE * side * 0.5 + art_shift
	var title_box := (
		_box("title", card_size)
		if _rootglass
		else box("banner", card_size).grow_individual(0, card_size.y * 0.012, 0, card_size.y * 0.012)
	)
	if _rootglass:
		_place(_name, title_box)
		_fit_rootglass_title(_name, title_box)
	else:
		_place(
			_name, Rect2(title_box.position + Vector2(title_box.size.x * 0.07, 0), title_box.size * Vector2(0.9, 1.0))
		)
		_fit(_name, title_box.size.y * 0.78, title_box.size.x * 0.84)
	var shares: Array = _layout_shares("orb")
	var radius := float(shares[2]) * card_size.x
	var orb := Rect2(
		Vector2(float(shares[0]) * card_size.x, float(shares[1]) * card_size.y) - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0
	)
	# The digit sits on a dark disc inside the crystal: on the bright facets alone a 1 read as a T.
	_place(_cost, orb.grow(-radius * 0.22))
	_cost.add_theme_font_size_override("font_size", int(radius * (0.9 if _rootglass else 1.3)))
	if not _rootglass:
		var disc := UiTheme.box(Color(0.1, 0.04, 0.2, 0.82), Color(1, 1, 1, 0.35), 1, int(radius), Vector2.ZERO)
		_cost.add_theme_stylebox_override("normal", disc)
	if _rootglass:
		_crest.position = Vector2(card_size.x * 0.79, card_size.y * 0.045)
		_crest.size = Vector2(card_size.x * 0.14, card_size.y * 0.105)
		var role_rect := _box("role", card_size)
		_role.position = role_rect.position
		_role.size = role_rect.size
		_role.queue_redraw()
		_place(_feature, _box("feature", card_size))
		_fit(_feature, _feature.size.y * 0.52, _feature.size.x * 0.94, 6)
		_place(_complexity, _box("complexity", card_size))
		_fit(_complexity, _complexity.size.y * 0.56, _complexity.size.x * 0.94, 6)
		_place(_speed, _box("speed", card_size))
		_fit(_speed, _speed.size.y * 0.76, _speed.size.x * 0.94, 7)
		_wear.size = card_size
	else:
		var plate := box("plate", card_size)
		_place(_speed, plate)
		_fit(_speed, plate.size.y * 1.2, plate.size.x * 0.92)
	if _role != null:
		if not _rootglass:
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
	if _wear != null:
		_wear.position = Vector2.ZERO
		_wear.queue_redraw()
	queue_redraw()


static func _place(label: Label, rect: Rect2) -> void:
	label.position = rect.position
	label.size = rect.size


## The largest font size up to `most` at which the label's text fits `width`.
static func _fit(label: Label, most: float, width: float, minimum := 8) -> void:
	var font := label.get_theme_font("font")
	var font_size := int(most)
	while font_size > minimum and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _fit_rootglass_title(label: Label, title_box: Rect2) -> void:
	var title := label.text
	var font := label.get_theme_font("font")
	var max_single := int(title_box.size.y * 0.64)
	var single_size := 0
	for font_size in range(max_single, 5, -1):
		if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= title_box.size.x:
			single_size = font_size
			break
	# Keep familiar names on one line, but wrap longer ones before they collapse into tiny engraved text.
	if single_size >= 12:
		label.text = title
		label.add_theme_font_size_override("font_size", single_size)
		return
	var max_double := int(title_box.size.y * 0.4)
	for font_size in range(max_double, 5, -1):
		var lines := _best_title_break(title, font, font_size, title_box.size.x)
		if not lines.is_empty():
			label.text = "\n".join(lines)
			label.add_theme_font_size_override("font_size", font_size)
			# A wrapped title uses more vertical room; lift it slightly so its last line clears the art window's border.
			label.position.y -= title_box.size.y * 0.18
			label.add_theme_constant_override("line_spacing", -1)
			return
	label.text = title
	label.add_theme_font_size_override("font_size", maxi(6, single_size))


static func _best_title_break(title: String, font: Font, font_size: int, width: float) -> PackedStringArray:
	var words := title.split(" ", false)
	if words.size() < 2:
		words = PackedStringArray()
		for character: String in title:
			words.append(character)
	var best := PackedStringArray()
	var best_width := INF
	for split_at in range(1, words.size()):
		var first := " ".join(words.slice(0, split_at))
		var second := " ".join(words.slice(split_at))
		var first_width := font.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var second_width := font.get_string_size(second, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var widest := maxf(first_width, second_width)
		if widest <= width and widest < best_width:
			best = PackedStringArray([first, second])
			best_width = widest
	return best


func _feature_text() -> String:
	for effect: Dictionary in shard.get("effects", []):
		if effect.get("kind", "") == "hook-before":
			return Text.t("BEFORE %s" % String(effect.get("role", "")).to_upper())
		if effect.get("kind", "") == "hook-after":
			return Text.t("AFTER %s" % String(effect.get("role", "")).to_upper())
		if effect.get("kind", "") == "index-size-add":
			return Text.f("INDEX +%d", [int(effect.get("size", 0))])
	if shard.has("needs"):
		return Text.t("NEEDS %s" % String(shard.needs).to_upper())
	if shard.has("makes"):
		return Text.t("MAKES %s" % String(shard.makes).to_upper())
	var keywords: Array = shard.get("keywords", [])
	if not keywords.is_empty():
		return String(keywords[0]).to_upper()
	return ""


func _feature_colour() -> Color:
	for effect: Dictionary in shard.get("effects", []):
		if effect.get("kind", "") in ["hook-before", "hook-after"]:
			return RoleBadge.colour_of("import").darkened(0.4)
		if effect.get("kind", "") == "index-size-add":
			return Color("#24574d")
	if shard.has("needs") or shard.has("makes"):
		return UiTheme.TEAL.darkened(0.45)
	var keywords: Array = shard.get("keywords", [])
	if not keywords.is_empty():
		return KeywordChips.colour_of(String(keywords[0])).darkened(0.35)
	return UiTheme.FAINT


func _complexity_colour() -> Color:
	return Color(COMPLEXITY_COLOURS.get(String(shard.get("complexity", "linear")), "#4a6b5b"))


func _layout_shares(name: String) -> Array:
	return (ROOTGLASS_GEOMETRY if _rootglass else geometry())[name]


func _box(name: String, card_size: Vector2) -> Rect2:
	var shares: Array = _layout_shares(name)
	var from := Vector2(float(shares[0]) * card_size.x, float(shares[1]) * card_size.y)
	return Rect2(from, Vector2(float(shares[2]) * card_size.x, float(shares[3]) * card_size.y) - from)


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
	var window := _box("art", card_size)
	draw_style_box(UiTheme.box(Color("#0c0b12"), Color.TRANSPARENT, 0, int(radius * 0.4)), window)
	var centre := window.get_center()
	for ring in 6:
		var reach := window.size.x * (0.5 - ring * 0.07)
		draw_circle(centre, reach, Color(colour, 0.05 + ring * 0.018))
	if _frame != null:
		return
	if _rootglass:
		var card_body := Rect2(Vector2.ZERO, card_size)
		draw_style_box(UiTheme.box(Color("#25332f"), Color("#cfbd8b"), 2, int(card_size.x * 0.11)), card_body)
		var halo := window.grow(card_size.x * 0.03)
		draw_arc(halo.get_center(), halo.size.x * 0.5, PI, TAU, 64, Color("#98b9a0"), 2.0, true)
		draw_arc(halo.get_center(), halo.size.x * 0.45, 0, TAU, 64, colour, 1.2, true)
		var plaque := Rect2(card_size.x * 0.055, card_size.y * 0.579, card_size.x * 0.89, card_size.y * 0.354)
		draw_style_box(UiTheme.box(Color("#c5cbb0"), Color("#cfbd8b"), 1, int(card_size.x * 0.06)), plaque)
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
