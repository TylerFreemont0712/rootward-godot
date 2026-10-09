class_name PixelView
extends Control
## The overworld drawn small and shown big (ADR-0061): the world renders into its own viewport at about 320 x 180
## and is shown at a whole-number scale, so every art pixel is the same number of screen pixels and nothing blurs.
## The viewport grows by whole pixels to fill windows of other shapes, so there are no bars at the sides.
##
## LEARN: the game's canvas is stretched to the window (canvas_items with a scale), so a Control's size is not in
## screen pixels. `get_final_transform()` gives the canvas-to-window scale; dividing by it turns a size in screen
## pixels back into canvas units, which is how the picture lands on exact screen pixels.

const BASE := Vector2i(320, 180)

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
	scale_factor = maxi(1, floori(minf(pixels.x / BASE.x, pixels.y / BASE.y)))
	var world := Vector2i(ceili(pixels.x / scale_factor), ceili(pixels.y / scale_factor))
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
