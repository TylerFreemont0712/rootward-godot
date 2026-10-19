class_name CharacterSelectLineup
extends Control
## The row of characters on Lanternroot's character screen: a strip of the town's cobbles across the lower middle,
## each saved character standing on it (CharacterStand, 2x, breathing, facing down) with their name beneath, and a
## last spot with a dim silhouette and a "+" for making someone new. The chosen one steps a little forward into a warm
## pool of lantern light, with Hotaru bobbing at their shoulder; the others dim. The light, Hotaru and the row slide to
## whoever is chosen next. Rows longer than the window slide so the chosen one stays in view.
##
##   lineup.set_slots(looks, names, start_look, 0)   # the looks of the characters, newest first; the New spot is added
##   lineup.hovered.connect(_choose)                 # the mouse moved over a spot
##   lineup.picked.connect(_pick)                    # a spot was clicked
##
## It draws and animates only: which spot is chosen, and what the choice does, are the screen's.

## A spot was hovered (the mouse moved onto it) or clicked.
signal hovered(index: int)
signal picked(index: int)

## Design pixels between two characters' middles.
const SLOT := 250.0
## How far the feet sit down the lineup's height (a share of it) and how far the chosen one steps forward.
const FEET := 0.8
const FORWARD := 14.0
## Design pixels per art pixel of the town's ground: its tile is 40 px, drawn 2x like the people.
const GROUND_ZOOM := 2.0
const TILE := OverworldScale.TILE
const EDGE := 80.0
const DIM := Color(0.6, 0.56, 0.7)
## How far above the feet the New spot's "+" floats (its circle's middle).
const PLUS_ABOVE := 186.0
const WARM := Color("#ffcf7a")
## The colour the strip fades into at its edges: the backdrop's own dark.
const SHADE := Color(0.06, 0.045, 0.075)
## Hotaru is drawn at the world's scale now (32 x 32 art pixels), at half the zoom her old 16 px frame had: as large on screen.
const HOTARU_ZOOM := 2.0
const HOTARU_FRAME := 32
const HOTARU_BEAT := 0.14
const NAME_SIZE := 28

var chosen := -1
var slots: Array[Slot] = []

var _floor: Control
var _pool: Control
var _stands: Control
var _over: Control
var _pictures: Dictionary = {}
var _left := 0.0
var _light_x := 0.0
var _hotaru := Vector2.ZERO
var _clock := 0.0


## One spot on the strip.
class Slot:
	extends RefCounted
	var stand: CharacterStand
	var label: Label
	var is_new := false
	## 0 for a spot waiting, 1 for the chosen one: eased toward its target every frame.
	var focus := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_floor = _layer()
	_floor.draw.connect(_draw_floor)
	_pool = _layer()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pool.material = additive
	_pool.draw.connect(_draw_pool)
	_stands = _layer()
	_over = _layer()
	_over.draw.connect(_draw_over)
	resized.connect(_on_resized)


func _ready() -> void:
	get_viewport().size_changed.connect(_floor.queue_redraw)


func _layer() -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	return layer


## Puts the characters on the strip: `looks` and `names` in order (newest first), then the New spot, standing as a
## silhouette of `start_look`. Spot `pick` is chosen at once, with no slide.
func set_slots(
	looks: Array[Dictionary], names: Array[String], start_look: Dictionary, pick := 0
) -> void:
	for slot in slots:
		slot.stand.queue_free()
		slot.label.queue_free()
	slots.clear()
	for i in looks.size():
		_add(OverworldArt.player_character(looks[i]), names[i], false, i)
	_add(OverworldArt.player_character(start_look), Text.t("New character"), true, looks.size())
	chosen = clampi(pick, 0, slots.size() - 1)
	for i in slots.size():
		slots[i].focus = 1.0 if i == chosen else 0.0
	_left = _left_target()
	_light_x = _centre_of(chosen)
	_hotaru = _hotaru_home()
	_place()


func _add(figure: CharacterSheet, title: String, is_new: bool, index: int) -> void:
	var slot := Slot.new()
	slot.is_new = is_new
	slot.stand = CharacterStand.new(figure)
	slot.stand.silhouette = is_new
	slot.stand.breathing = not Settings.reduced_motion
	# Neighbours do not breathe in step.
	slot.stand.clock = float(index * 7 % 10) / 10.0 * Walker.BREATH
	_stands.add_child(slot.stand)
	slot.label = Ui.label(title)
	slot.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	slot.label.custom_minimum_size.x = SLOT - 16.0
	slot.label.size.x = SLOT - 16.0
	slot.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.label.add_theme_font_size_override("font_size", NAME_SIZE)
	slot.label.add_theme_constant_override("outline_size", 5)
	slot.label.add_theme_color_override("font_outline_color", Color(SHADE, 0.95))
	_stands.add_child(slot.label)
	slots.append(slot)


## Chooses a spot: the light, Hotaru and the row slide to it over a moment.
func choose(index: int) -> void:
	if slots.is_empty():
		return
	chosen = clampi(index, 0, slots.size() - 1)


## Where the light's centre is now, along the row (it eases to the chosen spot).
func light_x() -> float:
	return _light_x


## The middle of a spot, in the lineup's own pixels (the row's slide included).
func centre_of(index: int) -> Vector2:
	return Vector2(_left + (index + 0.5) * SLOT, _feet())


func _centre_of(index: int) -> float:
	return _left + (index + 0.5) * SLOT


func _feet() -> float:
	return roundf(size.y * FEET)


func _left_target() -> float:
	var total := slots.size() * SLOT
	if total <= size.x - 2.0 * EDGE:
		return (size.x - total) / 2.0
	return clampf(size.x / 2.0 - (chosen + 0.5) * SLOT, size.x - EDGE - total, EDGE)


func _on_resized() -> void:
	_left = _left_target()
	_floor.queue_redraw()
	_place()


func _process(delta: float) -> void:
	if slots.is_empty():
		return
	var ease_by := 1.0 if Settings.reduced_motion else 1.0 - exp(-delta * 11.0)
	_clock += delta
	for i in slots.size():
		slots[i].focus = lerpf(slots[i].focus, 1.0 if i == chosen else 0.0, ease_by)
	_left = lerpf(_left, _left_target(), ease_by)
	_light_x = lerpf(_light_x, _centre_of(chosen), ease_by)
	_hotaru = _hotaru.lerp(
		_hotaru_home(), 1.0 if Settings.reduced_motion else 1.0 - exp(-delta * 6.0)
	)
	_place()
	_pool.queue_redraw()
	_over.queue_redraw()


## Where Hotaru hovers: up by the chosen figure's shoulder, bobbing.
func _hotaru_home() -> Vector2:
	var bob := 0.0 if Settings.reduced_motion else sin(_clock * 2.6) * 7.0
	var tall := 190.0
	if chosen >= 0 and chosen < slots.size():
		tall = slots[chosen].stand.feet_y() * 0.8
	return Vector2(_centre_of(maxi(chosen, 0)) + 78.0, _feet() - tall + bob)


func _place() -> void:
	var feet := _feet()
	for i in slots.size():
		var slot := slots[i]
		var middle := _centre_of(i)
		var lift := slot.focus * FORWARD
		slot.stand.position = Vector2(
			roundf(middle - slot.stand.size.x / 2.0), roundf(feet + lift - slot.stand.feet_y())
		)
		if slot.is_new:
			slot.stand.modulate = Color(1, 1, 1, lerpf(0.85, 1.0, slot.focus))
		else:
			slot.stand.modulate = DIM.lerp(Color.WHITE, slot.focus)
		slot.label.position = Vector2(roundf(middle - slot.label.size.x / 2.0), feet + 22.0 + lift)
		slot.label.add_theme_color_override(
			"font_color",
			(
				OverworldStyle.MUTED.lerp(UiTheme.AMBER, slot.focus)
				if not slot.is_new
				else UiTheme.AMBER_DIM.lerp(UiTheme.AMBER, slot.focus)
			)
		)


# --- the mouse -----------------------------------------------------------------------------------------------------


## The spot under `at`, or -1: the figure's height above the feet and the name under them.
func slot_at(at: Vector2) -> int:
	var feet := _feet()
	if at.y < feet - PLUS_ABOVE - 34.0 or at.y > feet + 70.0:
		return -1
	var index := floori((at.x - _left) / SLOT)
	return index if index >= 0 and index < slots.size() else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := slot_at((event as InputEventMouseMotion).position)
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if index >= 0 else Control.CURSOR_ARROW
		)
		if index >= 0 and index != chosen:
			hovered.emit(index)
	elif event is InputEventMouseButton and event.is_pressed():
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			var index := slot_at(click.position)
			if index >= 0:
				accept_event()
				picked.emit(index)


# --- drawing -------------------------------------------------------------------------------------------------------


func _pixel_of(zoom: float) -> float:
	var on_screen := (
		maxf(0.01, get_viewport().get_final_transform().get_scale().x) if is_inside_tree() else 1.0
	)
	return maxf(1.0, roundf(zoom * on_screen)) / on_screen


## The strip's picture: two rows of the town's cobbles (its base tiles), baked at the art's own size so it can be drawn
## whole at a whole number of screen pixels, with no seam between tiles.
func _floor_picture(columns: int) -> Texture2D:
	var key := "floor%d" % columns
	if _pictures.has(key):
		return _pictures[key]
	var art := OverworldArt.terrain()
	var layout: Dictionary = art.layout
	var atlas: Texture2D = art.texture
	var made := Image.create_empty(columns * TILE, 2 * TILE, false, Image.FORMAT_RGBA8)
	var base: Dictionary = (layout.get("base", {}) as Dictionary).get("cobble", {})
	if atlas == null or base.is_empty():
		made.fill(Color(GroundLayer.PLAIN.cobble))
	else:
		var source := atlas.get_image()
		source.convert(Image.FORMAT_RGBA8)
		var factor := OverworldScale.upscale(OverworldScale.drawn_tile(layout))
		if not is_equal_approx(factor, 1.0):
			source.resize(
				int(source.get_width() * factor),
				int(source.get_height() * factor),
				Image.INTERPOLATE_NEAREST
			)
		var count := maxi(1, int(base.get("count", 1)))
		for y in 2:
			for x in columns:
				var variant := (x * 7 + y * 13 + (x * y) % 5) % count
				made.blend_rect(
					source,
					Rect2i(variant * TILE, int(base.get("row", 0)) * TILE, TILE, TILE),
					Vector2i(x * TILE, y * TILE)
				)
	var texture := ImageTexture.create_from_image(made)
	_pictures[key] = texture
	return texture


## A soft round light as a picture made here, whole at once: a radial fade from `colour` at the middle to nothing at the
## edge. Kept, since the lineup draws it every frame.
# LEARN: a GradientTexture2D is filled in a moment after it is made, so one made inside `_draw` shows as a solid white
# square the first time it is drawn. An ImageTexture made from an Image has its pixels at once.
func _radial(colour: Color, strength: float) -> Texture2D:
	var key := "radial%s%s" % [colour.to_html(), strength]
	if not _pictures.has(key):
		var edge := 128
		var image := Image.create_empty(edge, edge, false, Image.FORMAT_RGBA8)
		for y in edge:
			for x in edge:
				var away := (
					Vector2(x + 0.5 - edge / 2.0, y + 0.5 - edge / 2.0).length() / (edge / 2.0)
				)
				var fade := clampf(1.0 - away, 0.0, 1.0)
				image.set_pixel(x, y, Color(colour, strength * fade * fade))
		_pictures[key] = ImageTexture.create_from_image(image)
	return _pictures[key]


## A fade from `from` to `to` across a picture 1 px wide or tall, stretched when drawn; kept.
func _fade(from: Color, to: Color, vertical: bool) -> Texture2D:
	var key := "fade%s%s%s" % [from.to_html(), to.to_html(), vertical]
	if not _pictures.has(key):
		var steps := 64
		var image := Image.create_empty(
			1 if vertical else steps, steps if vertical else 1, false, Image.FORMAT_RGBA8
		)
		for i in steps:
			var mix := from.lerp(to, float(i) / (steps - 1))
			image.set_pixel(0 if vertical else i, i if vertical else 0, mix)
		var texture := ImageTexture.create_from_image(image)
		_pictures[key] = texture
	return _pictures[key]


func _draw_floor() -> void:
	var pixel := _pixel_of(GROUND_ZOOM)
	var columns := ceili(size.x / (TILE * pixel)) + 2
	var picture := _floor_picture(columns)
	var drawn := Vector2(columns * TILE, 2 * TILE) * pixel
	var feet := _feet()
	var top := feet - TILE * pixel
	var origin := Vector2((size.x - drawn.x) / 2.0, top)
	# Night: the cobbles in the dusk's tint, so the lantern's pool is what brightens them.
	_floor.draw_texture_rect(picture, Rect2(origin, drawn), false, Color(0.5, 0.45, 0.62))
	var edge := 70.0
	_floor.draw_texture_rect(
		_fade(Color(SHADE, 0.95), Color(SHADE, 0.0), true), Rect2(0, top - 1.0, size.x, edge), false
	)
	_floor.draw_texture_rect(
		_fade(Color(SHADE, 0.0), Color(SHADE, 0.97), true),
		Rect2(0, top + drawn.y - edge, size.x, edge + 1.0),
		false
	)
	var side := minf(300.0, size.x * 0.2)
	_floor.draw_texture_rect(
		_fade(Color(SHADE, 1.0), Color(SHADE, 0.0), false), Rect2(0, top, side, drawn.y), false
	)
	_floor.draw_texture_rect(
		_fade(Color(SHADE, 0.0), Color(SHADE, 1.0), false),
		Rect2(size.x - side, top, side, drawn.y),
		false
	)


## The lantern's pool on the cobbles, a warm glow behind the chosen figure, and Hotaru's own small light: all added.
func _draw_pool() -> void:
	var glow := _radial(WARM, 0.95)
	var feet := _feet()
	var spread := 360.0
	_pool.draw_set_transform(Vector2(_light_x, feet + 8.0), 0.0, Vector2(1.0, 0.34))
	_pool.draw_texture_rect(
		glow, Rect2(-spread, -spread, spread * 2.0, spread * 2.0), false, Color(1, 1, 1, 0.85)
	)
	_pool.draw_set_transform(Vector2.ZERO)
	var behind := 250.0
	_pool.draw_texture_rect(
		glow,
		Rect2(_light_x - behind, feet - 110.0 - behind, behind * 2.0, behind * 2.0),
		false,
		Color(1, 1, 1, 0.34)
	)
	var halo := _radial(Color("#d6f57a"), 0.8)
	_pool.draw_texture_rect(
		halo, Rect2(_hotaru - Vector2(64, 64), Vector2(128, 128)), false, Color(1, 1, 1, 0.55)
	)


func _draw_over() -> void:
	var feet := _feet()
	for i in slots.size():
		if not slots[i].is_new:
			continue
		# Clear of the silhouette's head, so the mark never covers the figure it stands for.
		var at := Vector2(_centre_of(i), feet - PLUS_ABOVE + slots[i].focus * FORWARD)
		var ink := Color(UiTheme.AMBER, lerpf(0.65, 1.0, slots[i].focus))
		_over.draw_circle(at, 30.0, Color(0.1, 0.07, 0.04, 0.78))
		_over.draw_arc(at, 30.0, 0.0, TAU, 40, ink, 3.0, true)
		_over.draw_line(at + Vector2(-15, 0), at + Vector2(15, 0), ink, 5.0)
		_over.draw_line(at + Vector2(0, -15), at + Vector2(0, 15), ink, 5.0)
	var picture := OverworldArt.hotaru()
	if picture == null:
		_over.draw_circle(_hotaru, 7.0, Color("#d6f57a"))
		return
	var pixel := _pixel_of(HOTARU_ZOOM)
	var drawn := Vector2(HOTARU_FRAME, HOTARU_FRAME) * pixel
	var wings := 0 if Settings.reduced_motion else int(_clock / HOTARU_BEAT) % 2
	var region := Rect2(wings * HOTARU_FRAME, 0, HOTARU_FRAME, HOTARU_FRAME)
	_over.draw_texture_rect_region(picture, Rect2((_hotaru - drawn / 2.0).round(), drawn), region)
