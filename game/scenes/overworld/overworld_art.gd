class_name OverworldArt
extends RefCounted
## The overworld's pictures (ADR-0061), made by `scripts/pixel.sh` into `res://assets/overworld/`:
##
##   palette.json                 the colour ramps every picture is drawn from
##   tiles/terrain.png + .json    ground tiles: base rows and the dual-grid edges of each ground
##   characters/<part>.png        parts of a character (a body, an outfit, hair...), each a 3 x 3 sheet of 16 x 24
##                                frames (facing down, up, left; standing, step a, step b) in the slots' default colours
##   hotaru.png                   the firefly: rows facing down, up, left; columns wings up, wings down
##   buildings/<id>.png, props/<id>.png
##   portraits/<id>.png           the townspeople's faces
##
## A character's sheet is built once per look: its parts stacked, then each colour slot swapped for the ramp the look
## chooses. Anything missing falls back to a plain shape, so a missing picture never breaks the town.

const ROOT := "res://assets/overworld/"
const FRAME := Vector2i(16, 24)
const LAYERS: Array[String] = ["body", "outfit", "face", "hair", "hat", "item"]

static var _palette: Dictionary = {}
static var _sheets: Dictionary = {}
static var _textures: Dictionary = {}


static func palette() -> Dictionary:
	if _palette.is_empty():
		var text := FileAccess.get_file_as_string(ROOT + "palette.json")
		var parsed: Variant = JSON.parse_string(text) if text != "" else null
		_palette = parsed if parsed is Dictionary else {"ramps": {}, "slots": {}}
	return _palette


static func ramp(name: String) -> Array[Color]:
	var out: Array[Color] = []
	for hex: Variant in (palette().get("ramps", {}) as Dictionary).get(name, []):
		out.append(Color(String(hex)))
	return out


static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var found: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[path] = found
	return found


static func building(art: String) -> Texture2D:
	return texture(ROOT + "buildings/%s.png" % art)


static func prop(art: String) -> Texture2D:
	return texture(ROOT + "props/%s.png" % art)


static func portrait(id: String) -> Texture2D:
	return texture(ROOT + "portraits/%s.png" % id)


static func hotaru() -> Texture2D:
	return texture(ROOT + "hotaru.png")


static func terrain() -> Dictionary:
	var layout_text := FileAccess.get_file_as_string(ROOT + "tiles/terrain.json")
	var layout: Variant = JSON.parse_string(layout_text) if layout_text != "" else null
	return {"texture": texture(ROOT + "tiles/terrain.png"), "layout": layout if layout is Dictionary else {}}


## A character's sheet for `look` ({outfit, hair, hat, face, item, colours: {slot: ramp}}), built once and kept.
static func sheet(look: Dictionary) -> Texture2D:
	var key := JSON.stringify(look, "", true)
	if _sheets.has(key):
		return _sheets[key]
	var image := compose(look)
	var made: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_sheets[key] = made
	return made


static func compose(look: Dictionary) -> Image:
	var out: Image = null
	for layer in LAYERS:
		var part := String(look.get(layer, "body/base" if layer == "body" else ""))
		if part == "":
			continue
		var part_texture := texture(ROOT + "characters/%s.png" % part.replace("/", "-"))
		if part_texture == null:
			continue
		var image := part_texture.get_image()
		image.convert(Image.FORMAT_RGBA8)
		if out == null:
			out = image.duplicate()
		else:
			out.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	if out == null:
		return null
	_recolour(out, look.get("colours", {}))
	return out


## Swaps each slot's default shades for the chosen ramp's. Parts are drawn in fixed default ramps (palette.json
## "slots"), so a colour says which slot and which shade it is.
static func _recolour(image: Image, colours: Dictionary) -> void:
	var swap := {}
	var slots: Dictionary = palette().get("slots", {})
	for slot: String in colours:
		if not slots.has(slot):
			continue
		var from := ramp(String(slots[slot]))
		var to := ramp(String(colours[slot]))
		if to.is_empty():
			continue
		for shade in mini(3, from.size()):
			swap[from[shade].to_html(false)] = to[mini(shade, to.size() - 1)]
	if swap.is_empty():
		return
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a == 0.0:
				continue
			var hex := pixel.to_html(false)
			if swap.has(hex):
				image.set_pixel(x, y, swap[hex])


## The frame of a sheet for a facing and a pose (0 standing, 1 step a, 2 step b); right is left, mirrored.
static func frame_rect(facing: String, pose: int) -> Rect2i:
	var row := {"down": 0, "up": 1, "left": 2, "right": 2}.get(facing, 0) as int
	return Rect2i(Vector2i(pose * FRAME.x, row * FRAME.y), FRAME)
