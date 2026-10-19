class_name StudioGhost
extends RefCounted
## Where an object's picture is drawn (Concept/v0.3/10, section 7.2), for the ghost of a thing being moved or placed:
## the same arithmetic as TownMapView._standing (the picture's bottom middle on the footprint's bottom middle, enlarged
## for older art, sunk, flipped), so the ghost is the picture the thing will have.
##
##   for part in StudioGhost.parts(object):       # object: built-style, `at` and `size` as Vector2i
##       draw_texture_rect_region(part.texture, part.rect, part.region)

const TILE := OverworldScale.TILE


## The pieces to draw: {rect (world pixels), texture, region (the part of the texture), flip}. A picture that is
## missing gives one piece with no texture: the plain block on the footprint. A person gives one piece:
## the sheet's frame for their facing, placed as the Walker draws it. Warps and the start give none (the overlay draws
## their block).
static func parts(object: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var art := TownMapView._drawn_art(object)
	var kind := String(object.get("kind", ""))
	var texture: Texture2D
	var enlarged := 1.0
	match kind:
		"person":
			return _person(object)
		"building":
			texture = OverworldArt.building(art)
			enlarged = OverworldArt.art_scale("buildings", art)
		"prop", "sign":
			texture = OverworldArt.prop(art)
			enlarged = OverworldArt.art_scale("props", art)
		_:
			return out
	var frames := 1 if kind == "building" else OverworldArt.frames(art)
	var at: Vector2i = object.get("at", Vector2i.ZERO)
	var size: Vector2i = object.get("size", Vector2i.ONE)
	if object.has("program") and not object.has("art_size"):
		var entry: Dictionary = OverworldArt.index("world").get(art, {})
		var drawn := OverworldMap.cell_of(entry.get("footprint", [1, 1]))
		if drawn != size:
			for y: int in size.y:
				for x: int in size.x:
					out.append(_part(texture, at + Vector2i(x, y), Vector2i.ONE, frames, object, enlarged))
			return out
	out.append(_part(texture, at, size, frames, object, enlarged))
	return out


static func _part(
	texture: Texture2D, at: Vector2i, size: Vector2i, frames: int, object: Dictionary, enlarged: float
) -> Dictionary:
	var feet := Vector2((at.x + size.x / 2.0) * TILE, (at.y + size.y) * TILE)
	if texture == null:
		return {"rect": Rect2(feet - Vector2(size.x * TILE / 2.0, size.y * TILE), Vector2(size) * TILE)}
	var width := texture.get_width() / maxi(1, frames)
	var stretch := TownMapView._stretch(object)
	var corner := (Vector2(-width / 2.0, -texture.get_height()) * enlarged * stretch).floor()
	corner.y += roundf(float(object.get("sink", 0)) * enlarged * stretch.y)
	return {
		"rect": Rect2(feet + corner, Vector2(width, texture.get_height()) * enlarged * stretch),
		"texture": texture,
		"region": Rect2(width * OverworldArt.preview_frame(String(object.get("art", "")), object), 0, width, texture.get_height()),
		"flip": bool(object.get("flip", false)),
	}


## A person standing on `at`: the Walker's arithmetic (feet at the cell's bottom middle, one pixel up; the frame's ground
## row on the feet; centred, the half-width rounded down), so the ghost is where the person will stand.
static func _person(object: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at: Vector2i = object.get("at", Vector2i.ZERO)
	var townsfolk: Dictionary = OverworldScreen.catalog_of().get("townsfolk", {})
	var person: Variant = townsfolk.get(String(object.get("id", "")))
	var sheet: CharacterSheet = null
	if person is Dictionary:
		sheet = OverworldArt.character((person as Dictionary).get("look", {}))
	if sheet == null or sheet.texture == null:
		out.append({"rect": Rect2(Vector2(at) * TILE, Vector2.ONE * TILE)})
		return out
	var facing := String(object.get("facing", "down"))
	var frame := Vector2(sheet.frame) * sheet.scale
	var corner := Vector2(-floorf(frame.x / 2.0), -roundf(sheet.ground * sheet.scale))
	out.append(
		{
			"rect": Rect2(Walker.feet(at) + corner, frame),
			"texture": sheet.texture,
			"region": Rect2(sheet.rect(facing, CharacterSheet.STAND)),
			"flip": sheet.flipped(facing),
		}
	)
	return out
