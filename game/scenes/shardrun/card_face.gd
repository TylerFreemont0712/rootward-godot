class_name CardFace
extends PanelContainer
## A shard as a card, the way the Shardrun deals it: work cost, complexity, its picture, its name in its rarity's
## colour, and what it does in plain words (Beginner) or its function's name (Programmer). Hovering shows its code.
##
## It can be dragged (Godot's own drag and drop) and dropped onto: its table decides what a move means, through the
## `moved` and `pressed` Callables it is given. `spot` is where the card sits ({zone, index, spell?}).

enum Size { HAND, SLOT, DECK }

const SIZES := {Size.HAND: Vector2(138, 178), Size.SLOT: Vector2(96, 118), Size.DECK: Vector2(128, 178)}
## The colour of the element a shard gives its bolts, for the card's frame; shards that give none keep their rarity's.
const ELEMENT_FRAME := {"fire": "#ff9147", "frost": "#82d8ff", "spark": "#ffe066"}

var shard_id := ""
## A program card's paradigm colour (ADR-0012), for its frame; transparent for a shard, whose frame is its element's.
var paradigm_colour := Color.TRANSPARENT
var spot: Dictionary = {}
var shard: Dictionary = {}
var language := "python"
## Called with (from spot, to spot) when a card is dropped on this one, and with (spot, button) when it is clicked.
var moved: Callable
var pressed: Callable
var draggable := true
var _armed := false
var _dragging := false


static func create(
	id: String, catalog: Dictionary, run_language: String, summaries: bool, size_kind: Size, at := {}
) -> CardFace:
	var card := CardFace.new()
	card.shard_id = id
	card.spot = at
	card.shard = catalog.shards.get(id, {"id": id, "name": id, "rarity": "common"})
	if card.shard.has("paradigm") and catalog.has("programs"):
		var paradigm := ProgramDraft.paradigm_of(catalog, String(card.shard.paradigm))
		if not paradigm.is_empty():
			card.paradigm_colour = Color(paradigm.colour)
	card.language = run_language
	card._build(summaries, size_kind)
	return card


## An empty place a card can be dropped into (a spell's open slot, the hold's free place).
static func slot(at: Dictionary, label: String, size_kind: Size) -> CardFace:
	var card := CardFace.new()
	card.spot = at
	card.draggable = false
	card.custom_minimum_size = SIZES[size_kind]
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.22), UiTheme.LINE, 1, 8, Vector2(6, 6)))
	var text := Ui.tint(Ui.label(label, "Faint", true), UiTheme.FAINT)
	(text as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	(text as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(text)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	return card


func _build(summaries: bool, size_kind: Size) -> void:
	custom_minimum_size = SIZES[size_kind]
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rarity := UiTheme.rarity(shard.get("rarity", "common"))
	var frame := Color(ELEMENT_FRAME.get(element_of(shard), rarity.to_html()))
	if paradigm_colour.a > 0.0:
		frame = paradigm_colour
	var face := UiTheme.box(Color("#241b17"), frame.darkened(0.15), 2, 10, Vector2(7, 6))
	face.shadow_color = Color(0, 0, 0, 0.45)
	face.shadow_size = 4
	add_theme_stylebox_override("panel", face)
	var small := size_kind == Size.SLOT
	var cost := int(shard.get("cost", 0))
	# A shard's cost is extra work; a program card's is mana (ADR-0012).
	var price := ("%d◆" % cost) if shard.has("paradigm") else ("+%d" % cost if cost > 0 else "·")
	var gem := Ui.tint(Ui.label(price, "Faint"), UiTheme.SHARD)
	var big_o := Ui.label(ShardrunViews.complexity(shard), "Faint")
	var top := Ui.hbox([gem, Ui.spacer(), big_o], 2)
	var art_size := Vector2(40, 40) if small else Vector2(56, 56)
	var art := Ui.picture(ShardrunViews.art(shard, shard_id), art_size, "◆")
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var name := Ui.tint(
		Ui.label(shard.get("name", shard_id), "" if small else "Subheading", true), rarity.lightened(0.2)
	)
	(name as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var column := Ui.vbox([top, art, name], 2 if small else 4)
	if not small:
		var words: String = (
			shard.get("summary", "") if summaries else "%s(bolts, battle)" % shard.get("function", shard_id)
		)
		var text := Ui.label(words, "Muted", true)
		(text as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# The face keeps to four lines; the whole summary (and the code) is in the tooltip.
		(text as Label).max_lines_visible = 3
		(text as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_theme_font_size_override("font_size", 12)
		column.add_child(text)
	var curse: Dictionary = shard.get("curse", {})
	if not curse.is_empty():
		column.add_child(Ui.tint(Ui.label("cursed", "Faint"), UiTheme.SHARD))
	add_child(column)
	for child in column.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = shard.get("name", shard_id)


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


# LEARN: a Control can draw its own tooltip: when tooltip_text is not empty, Godot asks _make_custom_tooltip for a
# Control to show instead of the plain text. Here it is the shard's real code, coloured, which is the point of a card.
func _make_custom_tooltip(_for_text: String) -> Object:
	if shard_id == "":
		return null
	var title := Ui.tint(
		Ui.label("%s · %s" % [shard.get("name", shard_id), ShardrunViews.complexity(shard)], "Subheading"),
		UiTheme.rarity(shard.get("rarity", "common"))
	)
	var box := Ui.vbox([title, Cards.code(shard, language, 8)], 5)
	if shard.has("summary"):
		box.add_child(Ui.label(shard.summary, "Muted", true))
	box.custom_minimum_size.x = 340
	return Ui.panel(box, "Overlay")


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
	var ghost := CardFace.create(shard_id, Game.catalog, language, false, Size.HAND)
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
