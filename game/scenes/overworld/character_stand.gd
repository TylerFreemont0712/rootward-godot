class_name CharacterStand
extends Control
## One character standing still, facing the player, as the town draws them but larger (ADR-0063, ADR-0064): the
## sheet's frame at a whole number of screen pixels per art pixel, nearest filtering, breathing on the idle column
## when the sheet has one. A sheet cut for this world (64 x 96) is shown 2x; one drawn for 16 px tiles (the old
## 25 x 35 parts) is shown at 2.5 x 2 = 5x, so it comes out about as tall. A `silhouette` is the same figure in
## one dark colour; with no picture at all, a plain figure stands instead, so a missing sheet never leaves a gap.
##
##   var stand := CharacterStand.new(OverworldArt.character(look))
##   stand.position = feet - Vector2(stand.size.x / 2.0, stand.feet_y())

## Design pixels per pixel of the town's own art: people are 2x the town's.
const ZOOM := 2.0
const SILHOUETTE := Color(0.8, 0.72, 0.95, 0.55)

var sheet: CharacterSheet
var facing := "down"
var silhouette := false:
	set(value):
		silhouette = value
		queue_redraw()
## Whether the figure breathes (the idle frame for part of each breath). Off under reduced motion.
var breathing := true
var clock := 0.0

var _pose := CharacterSheet.STAND
var _flat: Texture2D


func _init(figure: CharacterSheet = null) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_sheet(figure)


func set_sheet(figure: CharacterSheet) -> void:
	sheet = figure
	_flat = null
	custom_minimum_size = frame_size()
	size = custom_minimum_size
	queue_redraw()


## Whether a picture is drawn (false: the plain figure stands in).
func has_picture() -> bool:
	return sheet != null and sheet.texture != null


## The frame as shown, in design pixels.
func frame_size() -> Vector2:
	if sheet == null or sheet.frame == Vector2i.ZERO:
		return Vector2(OverworldScale.PERSON) * ZOOM
	return Vector2(sheet.frame) * sheet.scale * ZOOM


## How far down the control the feet are, in design pixels.
func feet_y() -> float:
	if sheet == null or sheet.frame == Vector2i.ZERO:
		return frame_size().y * 0.97
	return float(sheet.ground) * sheet.scale * ZOOM


func _ready() -> void:
	# A window of another size stretches the canvas by another amount: the whole-pixel size is worked out again.
	get_viewport().size_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if not breathing or Settings.reduced_motion or not has_picture():
		return
	if not is_visible_in_tree():
		return
	clock += delta
	if sheet.has_animation("idle"):
		queue_redraw()
		return
	if not sheet.breathes():
		return
	var pose := Walker.breath_pose(clock)
	if pose != _pose:
		_pose = pose
		queue_redraw()


## Screen pixels per design pixel here.
func _screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	return maxf(
		0.01,
		(
			get_viewport().get_final_transform().get_scale().x
			* get_global_transform_with_canvas().get_scale().x
		)
	)


func _draw() -> void:
	var on_screen := _screen_scale()
	var art_scale := sheet.scale if sheet != null else 1.0
	var pixel := maxf(1.0, roundf(art_scale * ZOOM * on_screen)) / on_screen
	var frame := (
		sheet.frame if sheet != null and sheet.frame != Vector2i.ZERO else OverworldScale.PERSON
	)
	var drawn := Vector2(frame) * pixel
	var ground := (
		float(sheet.ground) if sheet != null and sheet.frame != Vector2i.ZERO else frame.y * 0.97
	)
	var origin := Vector2(
		roundf((size.x - drawn.x) / 2.0 * on_screen) / on_screen, size.y - drawn.y
	)
	var feet := origin + Vector2(drawn.x / 2.0, ground * pixel)
	# A flat oval under the feet, as wide as about half the figure (the town's own shadow).
	draw_set_transform(feet + Vector2(0, -1), 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, drawn.x * 0.3, Color(0.05, 0.03, 0.08, 0.4))
	draw_set_transform(Vector2.ZERO)
	var tint := SILHOUETTE if silhouette else Color.WHITE
	if not has_picture():
		var body := Rect2(origin + drawn * Vector2(0.28, 0.12), drawn * Vector2(0.44, 0.84))
		draw_rect(body, tint if silhouette else Color("#e8d8bc"))
		return
	var picture := _flat_picture() if silhouette else sheet.texture
	var region := Rect2(sheet.rect(facing, _pose if sheet.breathes() else CharacterSheet.STAND))
	if sheet.has_animation("idle"):
		region = Rect2(sheet.animation_rect(facing, "idle", 0.0 if Settings.reduced_motion else clock))
	if sheet.flipped(facing):
		draw_set_transform(origin + Vector2(drawn.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(picture, Rect2(Vector2.ZERO, drawn), region, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect_region(picture, Rect2(origin, drawn), region, tint)


## The sheet with every pixel white and only its outline kept, so a tint colours the whole figure the same.
func _flat_picture() -> Texture2D:
	if _flat == null:
		var image := sheet.texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		for y in image.get_height():
			for x in image.get_width():
				image.set_pixel(x, y, Color(1, 1, 1, 1.0 if image.get_pixel(x, y).a > 0.5 else 0.0))
		_flat = ImageTexture.create_from_image(image)
	return _flat
