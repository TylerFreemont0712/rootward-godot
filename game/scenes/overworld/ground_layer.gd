class_name GroundLayer
extends Node2D
## A map's ground (ADR-0061): grass (or a floor) under every cell, then each other ground on top as a dual grid, its
## tiles half a tile off the map's grid so each covers the corners of four cells (pipeline/pixel/terrain.py). Water
## ripples through its frames. Baked once per map into pictures for each ripple frame (three while water shows), so a
## ripple swaps pictures instead of redrawing every tile. An interior is drawn alone on black (ADR-0064).
##
## The baked ground is cut into square pieces (CHUNK pixels a side). Lanternroot Studio paints the ground a few cells at
## a time (Concept/v0.3/10, section 7.8): `repaint(shown, cells)` paints again only the cells around the changed ones,
## into the pieces they touch, and uploads those pieces alone, so a brush stroke costs a millisecond or two instead of
## the three quarters of a second a whole bake takes.

const TILE := OverworldScale.TILE
## A signed 64-bit mask holds fifteen four-corner surfaces with room for the sign bit. Additional surfaces use another
## plane, so adding paintable terrain does not silently drop later layers.
const MASK_LAYERS := 15
const MASK_PLANES := 2
## Legacy atlas order. Current art declares its own layer order and variants in terrain.json.
const OVERLAYS: Array[String] = ["flowers", "path", "cobble", "water"]
const RIPPLE := 0.45
## The dual grid's tiles reach half a tile past the map's edges, so the pictures start that far out.
const MARGIN := TILE / 2
## The side of one piece of the baked ground, in pixels: eight tiles.
const CHUNK := TILE * 8
## What an empty pixel of a new Image holds.
const CLEAR := Color(0, 0, 0, 0)
## The flat colour of each ground, drawn when the art is missing.
const PLAIN := {
	"grass": "#86c45a", "meadow": "#6ca84e", "dry_grass": "#9a9450", "forest_floor": "#6a6838",
	"moss": "#4f8a5e", "root_floor": "#60402e", "fern_moss": "#4f8a5e", "glow_moss": "#355f4c",
	"flowers": "#86c45a", "soil": "#60402e", "tilled_soil": "#8e5c3c",
	"path": "#dcb27c", "brick_path": "#a0502e", "stone_path": "#7c7480", "wood_path": "#7a5236",
	"sand": "#dcc092", "gravel": "#7c7480", "cobble": "#c2bab2", "water": "#4494d0",
	"floor": "#a8744a", "wall": "#e8d8bc", "void": "#000000",
}

## Whether the pieces' images stay in memory after a bake, so a repaint changes them in place. Lanternroot Studio turns
## it on; without it a repaint reads a piece back from the GPU the first time it touches it.
static var keep_images := false

var map: Dictionary = {}

var _layout: Dictionary = {}
## The terrain atlas as an Image at this world's tile, kept for repaints; null when the art is missing.
var _source: Image
## How many ripple frames the bake has.
var _frames := 1
## The pieces: {at: Vector2i (pixels in the picture), textures: Array (one ImageTexture per frame), images: Array (the
## same as Images, or empty until a repaint needs them)}.
var _chunks: Array[Dictionary] = []
var _across := 0
var _indoors := false
var _under := Vector2i(0, 1)
var _bases: Dictionary = {}
var _frame := 0
var _clock := 0.0
var _overlays: Array[String] = []
var _salts: Dictionary = {}


func show_map(shown: Dictionary) -> void:
	map = shown
	_chunks.clear()
	_source = null
	if not map.is_empty():
		var art := OverworldArt.terrain()
		_layout = art.layout
		_bake(art.texture as Texture2D)
	queue_redraw()


func _process(delta: float) -> void:
	if _frames < 2:
		return
	_clock += delta
	if _clock >= RIPPLE:
		_clock = 0.0
		_frame = (_frame + 1) % _frames
		queue_redraw()


func _ground(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= int(map.width) or y >= int(map.height):
		return ""
	return (map.ground as PackedStringArray)[y * int(map.width) + x]


func _tile(row: int, column: int) -> Rect2i:
	return Rect2i(column * TILE, row * TILE, TILE, TILE)


func _draw() -> void:
	if bool(map.get("interior", false)):
		# Beyond the room's walls is black, as far as any view can reach.
		var reach := Vector2(OverworldScale.VIEW)
		var room := Vector2(int(map.width), int(map.height)) * TILE
		draw_rect(Rect2(-reach, room + reach * 2.0), Color.BLACK)
	for chunk: Dictionary in _chunks:
		var textures: Array = chunk.textures
		draw_texture(textures[_frame % textures.size()], Vector2(chunk.at) - Vector2(MARGIN, MARGIN))


## The size of the whole baked picture: the map's cells and half a tile round them.
func _extent() -> Vector2i:
	return Vector2i(int(map.width) + 1, int(map.height) + 1) * TILE


## Paints the whole ground into one picture per ripple frame (the same tiles, in the same order, that were drawn cell by
## cell before), then cuts it into pieces. Without the art, a flat block per cell.
# LEARN: Image.blend_rect alpha-blends like the canvas does, and the lint keeps every ground pixel fully opaque or fully
# clear, so a baked picture matches the tile-by-tile draw exactly. Then one texture draw replaces every tile draw.
func _bake(atlas: Texture2D) -> void:
	if atlas != null and not _layout.is_empty():
		_source = atlas.get_image()
	if _source != null:
		_source.convert(Image.FORMAT_RGBA8)
		_fit_to_tile(_source)
	var extent := _extent()
	_read_bases()
	_frames = _frame_count() if _source != null else 1
	_frame = _frame % _frames
	# The base tiles are the same in every frame: painted once, then copied for each frame before its corners.
	var base := Image.create_empty(extent.x, extent.y, false, Image.FORMAT_RGBA8)
	if _source == null:
		_paint_plain(base)
	else:
		for y in int(map.height):
			for x in int(map.width):
				_paint_base(base, _source, Vector2i(x, y), Vector2i.ZERO)
	var order := _overlay_order()
	# LEARN: every layer needs four corner bits. Keep each signed mask below its sign bit and store a second plane when
	# more than fifteen surfaces are present, so the latest layers remain visible too.
	var masks := PackedInt64Array()
	if _source != null and not order.is_empty():
		masks.resize((int(map.width) + 1) * (int(map.height) + 1) * MASK_PLANES)
		for vy in int(map.height) + 1:
			for vx in int(map.width) + 1:
				var index := (vy * (int(map.width) + 1) + vx) * MASK_PLANES
				var corner := Vector2i(vx, vy)
				masks[index] = _masks_at(corner, 0)
				masks[index + 1] = _masks_at(corner, 1)
	var pictures: Array[Image] = []
	for frame in _frames:
		var picture: Image = base if frame == _frames - 1 else base.duplicate()
		if not masks.is_empty():
			for vy in int(map.height) + 1:
				for vx in int(map.width) + 1:
					var index := (vy * (int(map.width) + 1) + vx) * MASK_PLANES
					var first := masks[index]
					var second := masks[index + 1]
					if first != 0 or second != 0:
						_paint_corners(picture, Vector2i(vx, vy), first, second, frame, Vector2i.ZERO, order)
		pictures.append(picture)
	_across = ceili(float(extent.x) / CHUNK)
	for cy in ceili(float(extent.y) / CHUNK):
		for cx in _across:
			var at := Vector2i(cx, cy) * CHUNK
			var area := Rect2i(at, Vector2i(mini(CHUNK, extent.x - at.x), mini(CHUNK, extent.y - at.y)))
			var textures: Array = []
			var images: Array = []
			for picture: Image in pictures:
				var piece := picture.get_region(area)
				textures.append(ImageTexture.create_from_image(piece))
				if keep_images:
					images.append(piece)
			_chunks.append({"at": at, "textures": textures, "images": images})


## Ground art drawn for another tile (16 px, before ADR-0064) is enlarged to this world's tile. Every tile edge lands on
## a whole pixel (16 x 2.5 = 40), so the atlas's rows and columns still line up.
func _fit_to_tile(source: Image) -> void:
	var factor := OverworldScale.upscale(OverworldScale.drawn_tile(_layout))
	if is_equal_approx(factor, 1.0):
		return
	var size := Vector2i((Vector2(source.get_size()) * factor).round())
	source.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)


## One picture per frame of the most ripples a shown overlay has: three while there is water, otherwise one.
func _frame_count() -> int:
	return frame_count_of(map, _layout)


static func frame_count_of(shown: Dictionary, layout: Dictionary) -> int:
	var count := 1
	var overlays: Dictionary = layout.get("overlay", {})
	for kind: String in layout.get("order", OVERLAYS):
		if overlays.has(kind) and (shown.get("ground", PackedStringArray()) as PackedStringArray).has(kind):
			count = maxi(count, int(overlays[kind].get("frames", 1)))
	return count


## The base tile of one cell, drawn at `offset` (the piece's corner in the whole picture, subtracted). Outdoors grass is
## under everything, so a path's rounded corners show grass. Indoors each cell is its own base: floor, wall or the dark
## beyond the room. Copied, not blended: a base tile covers its cell, and copying is cheaper (the bake and a repaint
## both copy, so they agree to the byte).
func _paint_base(picture: Image, source: Image, cell: Vector2i, offset: Vector2i) -> void:
	var row := _under.x
	var count := _under.y
	if _indoors:
		var own: Variant = _bases.get(_ground(cell.x, cell.y))
		if own is Vector2i:
			row = (own as Vector2i).x
			count = (own as Vector2i).y
	# A cell's variant comes from its place, so the same map always looks the same.
	var variant := _variant("floor" if _indoors else "grass", cell, count)
	picture.blit_rect(source, _tile(row, variant), cell * TILE + Vector2i(MARGIN, MARGIN) - offset)


## The base rows, read once per bake: the ground under everything (row, variants) and each indoor ground's own.
func _read_bases() -> void:
	var base: Dictionary = _layout.get("base", {})
	_indoors = bool(map.get("interior", false))
	var under: Dictionary = base.get("floor" if _indoors else "grass", {})
	_under = Vector2i(int(under.get("row", 0)), maxi(1, int(under.get("count", 1))))
	_bases = {}
	_salts = {}
	_overlays.assign(_layout.get("order", OVERLAYS))
	for kind: String in base:
		_bases[kind] = Vector2i(int(base[kind].get("row", 0)), maxi(1, int(base[kind].get("count", 1))))


## The overlay grounds drawn on this map, as indexes into the atlas's layer order: those with art that the map has.
func _overlay_order() -> Array[int]:
	var out: Array[int] = []
	var drawn: Dictionary = _layout.get("overlay", {})
	for k in _overlays.size():
		if drawn.has(_overlays[k]) and (map.ground as PackedStringArray).has(_overlays[k]):
			out.append(k)
	return out


## Which dual-grid tile each overlay ground needs at a corner of the map's grid, four bits per ground of _overlays (in
## its order): which of the four cells round the corner are that ground (0: nothing drawn).
# LEARN: the four cells are read once per corner, not once per ground and frame. GDScript's per-tile work, not the
# pixel copying, was most of a bake: with this, the base painted once for every frame, and base tiles copied rather than
# blended, the town's bake went from about 0.7 s to about 0.23 s (headless, measured with a probe).
func _masks_at(corner: Vector2i, plane: int) -> int:
	var a := _ground(corner.x - 1, corner.y - 1)
	var b := _ground(corner.x, corner.y - 1)
	var c := _ground(corner.x - 1, corner.y)
	var d := _ground(corner.x, corner.y)
	if a == b and b == c and c == d and not a in _overlays:
		return 0
	var out := 0
	var first := plane * MASK_LAYERS
	for k in range(first, mini(_overlays.size(), first + MASK_LAYERS)):
		var kind := _overlays[k]
		var bits := int(a == kind) | int(b == kind) << 1 | int(c == kind) << 2 | int(d == kind) << 3
		out |= bits << ((k - first) * 4)
	return out


## The overlay tiles of one corner, `packed` as _masks_at gives them, in atlas order (later ones cover earlier ones).
func _paint_corners(
	picture: Image,
	corner: Vector2i,
	first: int,
	second: int,
	frame: int,
	offset: Vector2i,
	order: Array[int]
) -> void:
	var overlays: Dictionary = _layout.get("overlay", {})
	for k in order:
		var plane := int(k / MASK_LAYERS)
		var shift := (k % MASK_LAYERS) * 4
		var packed := first if plane == 0 else second
		var mask := (packed >> shift) & 15
		if mask == 0:
			continue
		var kind := _overlays[k]
		var overlay: Dictionary = overlays[kind]
		var frames := maxi(1, int(overlay.get("frames", 1)))
		var variant := _variant(kind, corner, maxi(1, int(overlay.get("variants", 1))))
		var row := int(overlay.row) + variant * frames + frame % frames
		picture.blend_rect(_source, _tile(row, mask), corner * TILE - offset)


## Each place chooses an authored texture, independently of painting order, ripple frame and the gameplay RNG.
## Mixing both coordinates avoids the diagonal stripes of a simple x + y modulo pattern. Seeds are cached per kind.
func _variant(kind: String, cell: Vector2i, count: int) -> int:
	if count <= 1:
		return 0
	if not _salts.has(kind):
		_salts[kind] = Rng.hash_string(kind)
	var seed := int(_salts[kind]) ^ Rng.imul(cell.x & Rng.MASK, 0x1f123bb5) ^ Rng.imul(cell.y & Rng.MASK, 0x5f356495)
	return Rng.mix32(seed) % count


func _paint_plain(picture: Image) -> void:
	for y in int(map.height):
		for x in int(map.width):
			_paint_plain_cell(picture, Vector2i(x, y), Vector2i.ZERO)


func _paint_plain_cell(picture: Image, cell: Vector2i, offset: Vector2i) -> void:
	var colour := Color(String(PLAIN.get(_ground(cell.x, cell.y), "#2a1d2b")))
	picture.fill_rect(Rect2i(cell * TILE + Vector2i(MARGIN, MARGIN) - offset, Vector2i(TILE, TILE)), colour)


# --- repainting (Lanternroot Studio) --------------------------------------------------------------------------------


## Whether `shown` can be drawn by repainting cells: a ground is baked, and `shown` is the same size, the same kind of
## place and needs as many ripple frames. Otherwise it takes a whole show_map.
func can_repaint(shown: Dictionary) -> bool:
	return (
		not _chunks.is_empty()
		and not map.is_empty()
		and shown.get("width", -1) == map.get("width", -2)
		and shown.get("height", -1) == map.get("height", -2)
		and shown.get("interior", false) == map.get("interior", false)
		and (_source == null or frame_count_of(shown, _layout) == _frames)
	)


## The cells whose ground differs between the baked map and `shown` (the same size), row by row.
func changed_cells(shown: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var now: PackedStringArray = map.get("ground", PackedStringArray())
	var then: PackedStringArray = shown.get("ground", PackedStringArray())
	if now == then:
		return out
	var width := int(map.width)
	for y in int(map.height):
		var start := y * width
		if now.slice(start, start + width) == then.slice(start, start + width):
			continue
		for x in width:
			if now[start + x] != then[start + x]:
				out.append(Vector2i(x, y))
	return out


## Shows `shown` (as can_repaint allows) by painting again the cells round `cells` (those whose ground changed): each
## one's base, then every dual-grid corner of them, into the pieces they touch. False, with nothing changed, when it
## cannot (then show_map does it).
# LEARN: a corner's tile depends only on the four cells round it, so a changed cell changes the tiles of its four corners,
# and those tiles cover half of each cell round it. Painting again the changed cells and the ring round them (base first,
# then all their corners) gives exactly what a whole bake would: a corner tile on the ring's outside edge is drawn over
# the same tile, and the ground's pixels are fully opaque or fully clear, so drawing it twice changes nothing.
func repaint(shown: Dictionary, cells: Array[Vector2i]) -> bool:
	if not can_repaint(shown):
		return false
	map = shown
	if cells.is_empty():
		return true
	var ring := {}
	for cell: Vector2i in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				ring[cell + Vector2i(dx, dy)] = true
	var corners := {}
	for cell: Vector2i in ring:
		for corner: Vector2i in [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]:
			corners[corner] = true
	# Which pieces each cell's tile and each corner's tile touch.
	var cells_in := {}
	var corners_in := {}
	for cell: Vector2i in ring:
		_bucket(cells_in, cell, Rect2i(cell * TILE + Vector2i(MARGIN, MARGIN), Vector2i(TILE, TILE)))
	for corner: Vector2i in corners:
		_bucket(corners_in, corner, Rect2i(corner * TILE, Vector2i(TILE, TILE)))
	var order := _overlay_order()
	var packed := {}
	if _source != null:
		for corner: Vector2i in corners:
			var masks := PackedInt64Array()
			masks.resize(MASK_PLANES)
			for plane in MASK_PLANES:
				masks[plane] = _masks_at(corner, plane)
			packed[corner] = masks
	var width := int(map.width)
	var height := int(map.height)
	for index: int in cells_in:
		var chunk: Dictionary = _chunks[index]
		var images := _images_of(chunk)
		if images.is_empty():
			return _rebake(shown)
		var offset: Vector2i = chunk.at
		for frame in images.size():
			var picture: Image = images[frame]
			for cell: Vector2i in cells_in[index]:
				if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
					# Off the map there is no base, only the edge's corner tiles: cleared, then drawn again.
					# LEARN: Color.TRANSPARENT is white with no alpha; a new Image is black with no alpha. Both show nothing,
					# but the repaint is meant to be the bake byte for byte, so it clears to the Image's own zero.
					picture.fill_rect(Rect2i(cell * TILE + Vector2i(MARGIN, MARGIN) - offset, Vector2i(TILE, TILE)), CLEAR)
				elif _source == null:
					_paint_plain_cell(picture, cell, offset)
				else:
					_paint_base(picture, _source, cell, offset)
			if _source != null:
				for corner: Vector2i in corners_in.get(index, []):
					var masks: PackedInt64Array = packed[corner]
					if masks[0] != 0 or masks[1] != 0:
						_paint_corners(picture, corner, masks[0], masks[1], frame, offset, order)
	# A corner tile can reach a piece none of the ring's cells reach (at a piece's edge): it is drawn there too.
	for index: int in corners_in:
		if cells_in.has(index) or _source == null:
			continue
		var chunk: Dictionary = _chunks[index]
		var images := _images_of(chunk)
		if images.is_empty():
			return _rebake(shown)
		for frame in images.size():
			for corner: Vector2i in corners_in[index]:
				var masks: PackedInt64Array = packed[corner]
				if masks[0] != 0 or masks[1] != 0:
					_paint_corners(images[frame], corner, masks[0], masks[1], frame, chunk.at, order)
	var touched := cells_in.keys()
	for index: int in corners_in:
		if not cells_in.has(index):
			touched.append(index)
	for index: int in touched:
		var chunk: Dictionary = _chunks[index]
		for frame in (chunk.images as Array).size():
			(chunk.textures[frame] as ImageTexture).update(chunk.images[frame])
		if not keep_images:
			chunk.images = []
	queue_redraw()
	return true


## Files `item` under every piece its tile `area` (pixels of the whole picture) overlaps.
func _bucket(buckets: Dictionary, item: Vector2i, area: Rect2i) -> void:
	var extent := _extent()
	var from := Vector2i(maxi(0, area.position.x), maxi(0, area.position.y)) / CHUNK
	var last := Vector2i(mini(extent.x, area.end.x) - 1, mini(extent.y, area.end.y) - 1)
	if last.x < 0 or last.y < 0:
		return
	last /= CHUNK
	for cy in range(from.y, last.y + 1):
		for cx in range(from.x, last.x + 1):
			var index := cy * _across + cx
			if index < 0 or index >= _chunks.size():
				continue
			if not buckets.has(index):
				buckets[index] = []
			(buckets[index] as Array).append(item)


## A piece's images: kept ones, or read back from its textures (kept from then on while this map shows).
func _images_of(chunk: Dictionary) -> Array:
	if (chunk.images as Array).size() == (chunk.textures as Array).size():
		return chunk.images
	var images: Array = []
	for texture: ImageTexture in chunk.textures:
		var image := texture.get_image()
		if image == null:
			return []
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	chunk.images = images
	return images


## The whole bake again, when the pieces cannot be read back.
func _rebake(shown: Dictionary) -> bool:
	show_map(shown)
	return true


## The ground as baked for `frame`, the pieces put back together (for tests).
func baked_picture(frame := 0) -> Image:
	var extent := _extent()
	var out := Image.create_empty(extent.x, extent.y, false, Image.FORMAT_RGBA8)
	for chunk: Dictionary in _chunks:
		var images := _images_of(chunk)
		if images.is_empty():
			return null
		var piece: Image = images[frame % images.size()]
		out.blit_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), chunk.at)
	return out
