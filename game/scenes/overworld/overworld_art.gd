class_name OverworldArt
extends RefCounted
## The overworld's pictures (ADR-0061), made by `scripts/pixel.sh` into `res://assets/overworld/`:
##
##   palette.json                 the colour ramps every picture is drawn from
##   tiles/terrain.png + .json    ground tiles: base rows and the dual-grid edges of each ground
##   characters/<part>.png        parts of a character (a body, an outfit, hair...), each a 3 x 3 sheet of 25 x 35
##                                frames (facing down, up, left; standing, step a, step b) in the slots' default colours
##   hotaru.png                   the firefly: rows facing down, up, left; columns wings up, wings down
##   world/<id>.png + world.json  buildings, trees, props and furniture made by pipeline/world (ADR-0064) at
##                                this world's scale; a picture here is drawn before the older one of that name
##   buildings/<id>.png, props/<id>.png, with props.json: the older pictures, drawn for 16 px tiles unless their index
##                                says otherwise, and enlarged to this world (OverworldScale.upscale)
##   portraits/<id>.png           the townspeople's faces
##   cast/<id>.png + cast.json    sheets drawn by pipeline/animation/cast.py (ADR-0063): every facing, stop and idle,
##                                each made for one look, which the index records
##   player/<model>.png + player.json   complete 64 x 96 male/female walk and idle sheets (ADR-0071)
##
## Cast members use their exact authored sheet when available. Players use complete male/female 64 x 96 animation
## sheets with all four directions. The legacy parts composer is reserved for NPC fallback.

const ROOT := "res://assets/overworld/"
const CAST := ROOT + "cast/"
const PLAYER := ROOT + "player/"
const FRAME := Vector2i(25, 35)
const LAYERS: Array[String] = ["body", "outfit", "face", "hair", "hat", "item"]

static var _palette: Dictionary = {}
static var _sheets: Dictionary = {}
static var _textures: Dictionary = {}
static var _characters: Dictionary = {}
static var _cast_index: Dictionary = {}
static var _cast_loaded := false
static var _indexes: Dictionary = {}
static var _character_parts: Dictionary = {}
static var _player_index: Dictionary = {}
## Remakes not made yet (Lanternroot Studio, Concept/v0.3/10 section 7.7): remake id -> {source, from: [w, h]}. A map
## object whose art is such an id is drawn with the source's picture stretched to its footprint until its own exists.
static var stand_ins: Dictionary = {}


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
	return _newest("buildings", art)


static func prop(art: String) -> Texture2D:
	return _newest("props", art)


## The picture pipeline/world made for `art` when there is one, else the older one in `folder`.
static func _newest(folder: String, art: String) -> Texture2D:
	return texture(picture_path(folder, art))


## The file `building` (folder "buildings") or `prop` (folder "props") draws `art` from: pipeline/world's picture when
## there is one, else the older one. The file may not exist; the Studio's thumbnails read it.
static func picture_path(folder: String, art: String) -> String:
	if _has_world_picture(art):
		return ROOT + "world/%s.png" % art
	return ROOT + "%s/%s.png" % [folder, art]


## Forgets the pictures and the world index for `ids` (a remake just made them), so the next draw loads them anew.
static func forget(ids: Array[String]) -> void:
	_indexes.erase("world")
	for id: String in ids:
		stand_ins.erase(id)
		for folder: String in ["world", "buildings", "props"]:
			_textures.erase(ROOT + "%s/%s.png" % [folder, id])


## How many frames side by side a prop's picture has (a lamp's second is lit).
static func frames(art: String) -> int:
	var entry: Variant = index("world").get(art, index("props").get(art, {}))
	return maxi(1, int((entry as Dictionary).get("frames", 1))) if entry is Dictionary else 1


## Gate animation metadata comes from the world spec, so future door art can use the same passage behavior.
static func swing(art: String) -> Dictionary:
	return (index("world").get(art, {}) as Dictionary).get("swing", {})


## Match the town's resting display. Gates start closed; a lamp's last frame is lit.
static func preview_frame(art: String, object: Dictionary = {}) -> int:
	return 0 if object.has("program") or not swing(art).is_empty() else frames(art) - 1


## A folder's picture index (`world/world.json`, `props/props.json`): id -> {frames, size, tile}. Empty when the
## folder has none.
static func index(folder: String) -> Dictionary:
	if not _indexes.has(folder):
		var path := ROOT + "%s/%s.json" % [folder, folder]
		var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var parsed: Variant = JSON.parse_string(text) if text != "" else null
		_indexes[folder] = parsed if parsed is Dictionary else {}
	return _indexes[folder]


## How much larger than drawn a building or prop is shown: 1 when it was drawn for this world's tile (ADR-0064). A
## picture from pipeline/world counts first, as `building` and `prop` draw it first.
static func art_scale(folder: String, art: String) -> float:
	var entry: Variant = index("world").get(art) if _has_world_picture(art) else index(folder).get(art, {})
	return OverworldScale.upscale(OverworldScale.drawn_tile(entry if entry is Dictionary else {}))


static func _has_world_picture(art: String) -> bool:
	return index("world").has(art) and ResourceLoader.exists(ROOT + "world/%s.png" % art)


static func portrait(id: String) -> Texture2D:
	return texture(ROOT + "portraits/%s.png" % id)


static func hotaru() -> Texture2D:
	return texture(ROOT + "hotaru.png")


static func terrain() -> Dictionary:
	var layout_text := FileAccess.get_file_as_string(ROOT + "tiles/terrain.json")
	var layout: Variant = JSON.parse_string(layout_text) if layout_text != "" else null
	return {"texture": texture(ROOT + "tiles/terrain.png"), "layout": layout if layout is Dictionary else {}}


## How a townsperson's look is drawn: the exact cast sheet when there is one, else a single composed parts sheet.
static func character(look: Dictionary) -> CharacterSheet:
	var key := JSON.stringify(canonical_look(look), "", true)
	if _characters.has(key):
		return _characters[key]
	var made: CharacterSheet = null
	var file := cast_file(cast_index(), look)
	var cast_texture := texture(CAST + file) if file != "" else null
	# Other named townspeople keep their individually restyled cast sheets when an exact match exists.
	if file != "" and file != "player.png":
		if cast_texture != null:
			made = CharacterSheet.cast(cast_texture, cast_index())
	if made == null and file != "player.png":
		made = legacy_character(look)
	_characters[key] = made
	return made


## Players use complete authored sheets. Old saved part choices select the default model; no player path composes
## or falls back to the 25 x 35 parts.
static func player_character(look: Dictionary) -> CharacterSheet:
	var model := player_model(look)
	var key := "player:" + model
	if _characters.has(key):
		return _characters[key]
	var layout := player_index()
	var models: Dictionary = layout.get("models", {})
	var entry: Dictionary = models.get(model, {})
	var file := String(entry.get("file", ""))
	var made := CharacterSheet.cast(texture(PLAYER + file) if file != "" else null, layout)
	_characters[key] = made
	return made


static func player_model(look: Dictionary) -> String:
	return "female" if String(look.get("model", "male")) == "female" else "male"


static func player_index() -> Dictionary:
	if _player_index.is_empty():
		var path := PLAYER + "player.json"
		var source := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var parsed: Variant = JSON.parse_string(source)
		_player_index = parsed if parsed is Dictionary else {
			"frame": [64, 96], "ground": 93, "tile": 40,
			"rows": ["down", "up", "left", "right"], "columns": ["stop"],
		}
	return _player_index


## One composed parts sheet for a townsperson without an exact cast sheet.
static func legacy_character(look: Dictionary) -> CharacterSheet:
	return CharacterSheet.parts(sheet(look), FRAME)


## The legacy NPC character-part index (res://assets/overworld/characters/parts.json): available ids.
static func character_parts_index() -> Dictionary:
	if _character_parts.is_empty():
		var path := ROOT + "characters/parts.json"
		var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var parsed: Variant = JSON.parse_string(text) if text != "" else null
		_character_parts = parsed if parsed is Dictionary else {}
	return _character_parts


## The cast's index (pipeline/animation/cast.py): the frame, the ground row, the rows and columns, and every sheet with
## the look it was made from. Empty when there is none.
static func cast_index() -> Dictionary:
	if not _cast_loaded:
		_cast_loaded = true
		var path := CAST + "cast.json"
		var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var parsed: Variant = JSON.parse_string(text) if text != "" else null
		_cast_index = parsed if parsed is Dictionary else {}
	return _cast_index


## The file of the cast sheet in `index` made for `look`, or "" when none matches. Looks match by what they show, so an
## unused part ("none") and a colour left at its default do not count as differences.
static func cast_file(index: Dictionary, look: Dictionary) -> String:
	var wanted := JSON.stringify(canonical_look(look), "", true)
	var sheets: Dictionary = index.get("sheets", {}) if index.get("sheets", {}) is Dictionary else {}
	for id: String in sheets:
		var entry: Dictionary = sheets[id]
		if JSON.stringify(canonical_look(entry.get("look", {})), "", true) == wanted:
			return String(entry.get("file", ""))
	return ""


## A look as it shows: the parts it wears (the body when none is named), and every colour slot's ramp, defaults filled.
static func canonical_look(look: Dictionary) -> Dictionary:
	var out := {}
	for layer in LAYERS:
		var part := String(look.get(layer, "body/base" if layer == "body" else ""))
		if part != "" and part != "none":
			out[layer] = part
	var given: Dictionary = look.get("colours", {}) if look.get("colours", {}) is Dictionary else {}
	var slots: Dictionary = palette().get("slots", {})
	var colours := {}
	for slot: String in slots:
		colours[slot] = String(given.get(slot, slots[slot]))
	out["colours"] = colours
	return out


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
	recolour(out, look.get("colours", {}))
	return out


## Swaps each slot's default shades for the chosen ramp's. Parts are drawn in fixed default ramps (palette.json
## "slots"), so a colour says which slot and which shade it is. The 25 x 35 parts use three shades of a ramp.
static func recolour(image: Image, colours: Dictionary, shades := 3) -> void:
	var swap := {}
	var slots: Dictionary = palette().get("slots", {})
	for slot: String in colours:
		if not slots.has(slot):
			continue
		var from := ramp(String(slots[slot]))
		var to := ramp(String(colours[slot]))
		if to.is_empty():
			continue
		for shade in mini(shades, from.size()):
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
