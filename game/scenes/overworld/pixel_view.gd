class_name PixelView
extends Control
## The overworld drawn small and shown big (ADR-0061, ADR-0064): the world renders into its own viewport, 1280 x 720
## at 2x on a 2560 x 1440 laptop (32 x 18 tiles of 40 px), shown at a whole-number scale, keeping pixels crisp. The
## scale is the whole number nearest the window's fit, so 1080p gets 2x and 960 x 540, and 4K gets 3x and 1280 x 720.
## The viewport grows by whole pixels to fill windows of other shapes, so there are no bars at the sides.
##
## LEARN: the game's canvas is stretched to the window (canvas_items with a scale), so a Control's size is not in
## screen pixels. `get_final_transform()` gives the canvas-to-window scale; dividing by it turns a size in screen
## pixels back into canvas units, which is how the picture lands on exact screen pixels.

# The fit is made against this base: 2560 x 1440 is exactly 2x and shows the same 32 x 18 tiles the 512 x 288 base
# showed at 16 px. PixelView enlarges each art pixel by a whole number.
const BASE := OverworldScale.VIEW

var viewport: SubViewport
## How many screen pixels one art pixel is, now.
var scale_factor := 1

var _shown: TextureRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	viewport = SubViewport.new()
	viewport.size = BASE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	_shown = TextureRect.new()
	_shown.texture = viewport.get_texture()
	_shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shown.stretch_mode = TextureRect.STRETCH_SCALE
	_shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shown)
	resized.connect(_fit)
	get_viewport().size_changed.connect(_fit)
	_fit.call_deferred()


func _fit() -> void:
	var to_window := get_viewport().get_final_transform().get_scale().x
	if to_window <= 0.0:
		to_window = 1.0
	var pixels := size * to_window
	# The nearest whole scale: 1.5 (1080p) rounds up to 2, so the view stays near the base's amount of town either way.
	scale_factor = maxi(1, roundi(minf(pixels.x / BASE.x, pixels.y / BASE.y)))
	# A float just over an exact fit must not add a whole art pixel to the world.
	var world := Vector2i(ceili(pixels.x / scale_factor - 0.001), ceili(pixels.y / scale_factor - 0.001))
	viewport.size = world
	var shown := Vector2(world * scale_factor)
	_shown.size = shown / to_window
	# Centred, on whole screen pixels: a half pixel off would smear every art pixel's edge.
	_shown.position = Vector2(floorf((pixels.x - shown.x) / 2.0), floorf((pixels.y - shown.y) / 2.0)) / to_window


## Where a point of the world (in art pixels, relative to the viewport) is on this Control.
func to_screen(world_point: Vector2) -> Vector2:
	var to_window := get_viewport().get_final_transform().get_scale().x
	var camera := viewport.get_canvas_transform()
	return _shown.position + (camera * world_point) * scale_factor / to_window


## The exact inverse of to_screen: the point of the world (in art pixels) under `screen_point`, a point on this Control.
## Lanternroot Studio uses it to turn the mouse into a place in the town (ADR-0066).
func to_world(screen_point: Vector2) -> Vector2:
	var to_window := get_viewport().get_final_transform().get_scale().x
	var camera := viewport.get_canvas_transform()
	return camera.affine_inverse() * ((screen_point - _shown.position) * to_window / scale_factor)
