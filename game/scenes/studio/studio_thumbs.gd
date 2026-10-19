class_name StudioThumbs
extends RefCounted
## The catalog cards' pictures (Concept/v0.3/10, section 8.4): each catalog picture reduced to one small texture, kept
## in memory only (making one measured about 0.2 ms, so nothing is written to disk). The town's default sheet state,
## trimmed to what is drawn, scaled by a whole number so the pixels stay square, and no larger than SIZE.

const SIZE := 64

static var _cache: Dictionary = {}


## The picture `OverworldArt.building` (kind "building") or `OverworldArt.prop` (any other kind) draws for `art`, as a
## thumbnail of at most SIZE x SIZE; null when there is no picture or nothing is drawn in it.
static func thumb(art: String, kind: String) -> Texture2D:
	var key := kind + ":" + art
	if not _cache.has(key):
		_cache[key] = _make(art, kind)
	return _cache[key] as Texture2D


## "new" when the picture was drawn for the town's 40 px tile, "old" when it is enlarged until it is remade.
static func source(art: String, kind: String) -> String:
	if kind in ["person", "warp", "start"]:
		return "new"
	var folder := "buildings" if kind == "building" else "props"
	return "new" if OverworldArt.art_scale(folder, art) <= 1.0 else "old"


## Forgets every thumbnail (tests that swap the picture caches).
static func clear() -> void:
	_cache.clear()


static func _make(art: String, kind: String) -> Texture2D:
	match kind:
		"person":
			return _person(art)
		"warp":
			return _reduced(_warp_icon())
		"start":
			return _reduced(_start_icon())
	var texture := OverworldArt.building(art) if kind == "building" else OverworldArt.prop(art)
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var frame_width := maxi(1, image.get_width() / OverworldArt.frames(art))
	return _reduced(image.get_region(Rect2i(frame_width * OverworldArt.preview_frame(art), 0, frame_width, image.get_height())))


## A townsperson's front-facing standing frame (the look is in the content catalog's townsfolk).
static func _person(id: String) -> Texture2D:
	var townsfolk: Dictionary = OverworldScreen.catalog_of().get("townsfolk", {})
	var person: Variant = townsfolk.get(id)
	if not person is Dictionary:
		return null
	var sheet := OverworldArt.character((person as Dictionary).get("look", {}))
	if sheet == null or sheet.texture == null:
		return null
	var image := sheet.texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var rect := sheet.rect("down", CharacterSheet.STAND)
	if not Rect2i(Vector2i.ZERO, image.get_size()).encloses(rect):
		return null
	return _reduced(image.get_region(rect))


## Trims `image` to what is drawn and scales it by a whole number to fit SIZE; null when nothing is drawn.
static func _reduced(image: Image) -> Texture2D:
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	image = image.get_region(used)
	var longer := maxi(image.get_width(), image.get_height())
	if longer <= SIZE:
		var factor := SIZE / longer
		if factor > 1:
			image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	else:
		var divisor := ceili(float(longer) / SIZE)
		image.resize(
			maxi(1, roundi(float(image.get_width()) / divisor)),
			maxi(1, roundi(float(image.get_height()) / divisor)),
			Image.INTERPOLATE_LANCZOS
		)
	return ImageTexture.create_from_image(image)


## A teal doorway with an arrow through it, 32 x 32 in hand-placed pixels.
static func _warp_icon() -> Image:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var frame := Color("#1f6f6f")
	var inside := Color("#0d2f33")
	var light := Color("#7fe0d0")
	image.fill_rect(Rect2i(6, 3, 20, 26), frame)
	image.fill_rect(Rect2i(8, 5, 16, 24), inside)
	# The doorway's round top: cut the corners.
	for corner: Vector2i in [Vector2i(6, 3), Vector2i(7, 3), Vector2i(6, 4), Vector2i(24, 3), Vector2i(25, 3), Vector2i(25, 4)]:
		image.set_pixelv(corner, Color(0, 0, 0, 0))
	# The arrow: a shaft and a head pointing right.
	image.fill_rect(Rect2i(10, 15, 9, 3), light)
	for step: int in 4:
		image.fill_rect(Rect2i(18 + step, 13 + step, 1, 7 - 2 * step), light)
	return image


## An amber flag on a pole, 32 x 32.
static func _start_icon() -> Image:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	var pole := Color("#6b4a2a")
	var cloth := Color("#e8a33a")
	var edge := Color("#a8661a")
	image.fill_rect(Rect2i(8, 3, 2, 26), pole)
	image.fill_rect(Rect2i(6, 28, 6, 2), pole)
	image.fill_rect(Rect2i(10, 4, 16, 11), cloth)
	image.fill_rect(Rect2i(10, 13, 16, 2), edge)
	# A swallowtail notch cut into the flag's free end.
	for k: int in 5:
		image.fill_rect(Rect2i(21 + k, 9 - k, 1, 2 * k + 1), Color(0, 0, 0, 0))
	return image
