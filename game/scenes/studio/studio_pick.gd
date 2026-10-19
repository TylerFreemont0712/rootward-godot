class_name StudioPick
extends RefCounted
## What is under a point of the town (Lanternroot Studio, ADR-0066): the drawn pictures first, front-most first, then
## the footprints of what has no picture (a warp). TownMapView tags every node it makes for a map object with the
## object's index (`object_index`), so a tree's crown far above its footprint still picks the tree.
##
##   var pick := StudioPick.new()
##   pick.rebuild(map_view, map)        # once per map (see `is_stale`), not per click
##   pick.update(map_view, map, new_of_old, made)   # after an edit: only the objects that changed (see `update`)
##   pick.at(world_point)               # object indexes, front-most first
##
## "Front" is how the town is drawn: flat pictures (underfoot) are behind every standing thing, and among the standing
## the one whose feet are lower (the larger y) is in front; at equal feet the one of the later object is (and, within an
## object, the node added later).

const TILE := OverworldScale.TILE
## A pixel of a picture with more alpha than this counts as drawn; clicking a see-through corner picks what is behind.
const DRAWN := 0.1
const NO_BOX := Rect2()

## Textures' images, by texture, for the see-through test. null for a texture whose pixels cannot be read.
static var _images: Dictionary = {}

## Every drawn rectangle of one object, by the object's index: the same Dictionaries `_picture_cells` holds.
var _by_object: Dictionary = {}
var _pictures: Dictionary = {}
var _picture_cells: Dictionary = {}
var _cells: Dictionary = {}
var _objects: Array = []
var _signature := ""


## What `rebuild` saw of the view, to tell when it has changed (another map, nodes added or removed).
static func signature_of(view: TownMapView) -> String:
	if view == null or view.things == null:
		return ""
	return "%s|%d|%d" % [view.map.get("id", ""), view.things.get_child_count(), view.underfoot.get_child_count()]


func is_stale(view: TownMapView) -> bool:
	return signature_of(view) != _signature


## Reads the drawn rectangle of every node made for a map object, and the cells every object covers.
func rebuild(view: TownMapView, map: Dictionary) -> void:
	_by_object.clear()
	_pictures.clear()
	_picture_cells.clear()
	_cells.clear()
	_objects = map.get("objects", [])
	_signature = signature_of(view)
	if view.things == null:
		return
	var entries: Array[Dictionary] = []
	for layer: int in 2:
		var parent: Node2D = view.underfoot if layer == 0 else view.things
		var seen: Dictionary = {}
		for child: Node in parent.get_children():
			if child.is_queued_for_deletion() or not child.has_meta("object_index") or not child is Node2D:
				continue
			var node := child as Node2D
			var index := int(node.get_meta("object_index"))
			var number := int(seen.get(index, 0))
			seen[index] = number + 1
			entries.append_array(_entries_of(node, index, layer, number))
	entries.sort_custom(_in_front)
	# LEARN: a picture can reach far beyond its footprint. Index its rectangle too, so a hover only checks pictures
	# near the cursor while still picking a tree's crown and transparent corners correctly.
	for entry: Dictionary in entries:
		_keep(entry)
		_add_to_cells(entry, false)
	for index: int in _objects.size():
		_add_footprint(index)


## After an edit that changed a few objects: forgets the pictures of the ones that are gone or changed and reads the ones
## made for the new and changed, instead of reading the whole town again. `new_of_old` has, for each object the index
## held, its index in `map.objects` (or -1: gone or changed), and `made` the indexes of `map.objects` whose pictures were
## made now (TownMapView.update_objects tells both). The answers are the ones `rebuild` would give. False, and nothing
## changed, when the lists do not fit what the index holds.
func update(view: TownMapView, map: Dictionary, new_of_old: PackedInt32Array, made: PackedInt32Array) -> bool:
	if view.things == null or new_of_old.size() != _objects.size():
		return false
	var shifted := false
	var last := -1
	for old_index: int in new_of_old.size():
		var now := new_of_old[old_index]
		if now < 0:
			continue
		if now <= last:
			return false
		last = now
		shifted = shifted or now != old_index
	for old_index: int in new_of_old.size():
		if new_of_old[old_index] < 0:
			_forget(old_index)
	if shifted:
		_renumber(new_of_old)
	_objects = map.get("objects", [])
	for index: int in made:
		_read(view, index)
		_add_footprint(index)
	_signature = signature_of(view)
	return true


## How a draft's objects changed from one doc to the next, by session id (a sid names one object whatever its index):
## {new_of_old, old_of_new, made, count}. `new_of_old` has, for each old object, its new index, or -1 when it is gone or
## changed; `old_of_new` the reverse (-1 for a new or changed object); `made` the new indexes of the new and changed
## objects, which need their pictures made; `count` how many objects are gone or made. Empty when the kept objects do
## not keep their order (nothing in the Studio does that, but then a whole redraw is the answer).
static func changes(old_sids: Array[int], old_objects: Array, new_sids: Array[int], new_objects: Array) -> Dictionary:
	var new_of_old := PackedInt32Array()
	new_of_old.resize(old_sids.size())
	new_of_old.fill(-1)
	var old_of_new := PackedInt32Array()
	old_of_new.resize(new_sids.size())
	old_of_new.fill(-1)
	var made := PackedInt32Array()
	var by_sid: Dictionary = {}
	var same_list := old_sids == new_sids
	if not same_list:
		for old_index: int in old_sids.size():
			by_sid[old_sids[old_index]] = old_index
	var last := -1
	var gone := old_sids.size()
	for new_index: int in new_sids.size():
		var old_index: int = new_index if same_list else int(by_sid.get(new_sids[new_index], -1))
		if old_index >= 0 and old_objects[old_index] == new_objects[new_index]:
			if old_index <= last:
				return {}
			last = old_index
			new_of_old[old_index] = new_index
			old_of_new[new_index] = old_index
			gone -= 1
		else:
			made.append(new_index)
	return {"new_of_old": new_of_old, "old_of_new": old_of_new, "made": made, "count": gone + made.size()}


## Whether the index was made from what `view` shows now: no node has come or gone since, and it is of the same objects.
func shows(view: TownMapView) -> bool:
	return not is_stale(view) and is_same(_objects, view.map.get("objects"))


## The entries of a node's pieces. `number` is the node's place among the nodes made for its object in its layer.
static func _entries_of(node: Node2D, index: int, layer: int, number: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var part_number := 0
	for part: Dictionary in _parts(node):
		out.append(
			{
				"index": index,
				"rect": part.rect,
				"sprite": part.sprite,
				"layer": layer,
				"y": node.position.y,
				"seq": number * 16 + part_number
			}
		)
		part_number += 1
	return out


## Reads the pictures of object `index` from the nodes the view made for it.
func _read(view: TownMapView, index: int) -> void:
	var entries: Array[Dictionary] = []
	var numbers := [0, 0]
	for node: Node2D in view.nodes_of(index):
		var layer := 0 if node.get_parent() == view.underfoot else 1
		entries.append_array(_entries_of(node, index, layer, numbers[layer]))
		numbers[layer] += 1
	for entry: Dictionary in entries:
		_keep(entry)
		_add_to_cells(entry, true)


## Notes an entry under its object and in the object's picture rectangle.
func _keep(entry: Dictionary) -> void:
	var index: int = entry.index
	var rect: Rect2 = entry.rect
	if not _by_object.has(index):
		_by_object[index] = []
	(_by_object[index] as Array).append(entry)
	_pictures[index] = (_pictures[index] as Rect2).merge(rect) if _pictures.has(index) else rect


## The cells a rectangle touches, in world tiles.
static func _cells_of_rect(rect: Rect2) -> Rect2i:
	var first := Vector2i((rect.position / TILE).floor())
	var last := Vector2i(((rect.end - Vector2.ONE * 0.01) / TILE).floor())
	return Rect2i(first, last - first + Vector2i.ONE)


## Puts an entry in the list of every cell its picture reaches. When `sorted`, in its place among the entries there
## already (`rebuild` adds them front-most first, so each goes last).
func _add_to_cells(entry: Dictionary, sorted: bool) -> void:
	var box := _cells_of_rect(entry.rect)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var cell := Vector2i(x, y)
			if not _picture_cells.has(cell):
				_picture_cells[cell] = []
			var list: Array = _picture_cells[cell]
			var at := list.size()
			if sorted:
				at = 0
				while at < list.size() and not _in_front(entry, list[at] as Dictionary):
					at += 1
			list.insert(at, entry)


## The cells an object's footprint covers list its index, in file order.
func _add_footprint(index: int) -> void:
	var box := footprint(_objects[index] as Dictionary)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var cell := Vector2i(x, y)
			if not _cells.has(cell):
				_cells[cell] = []
			var list: Array = _cells[cell]
			var at := list.size()
			while at > 0 and int(list[at - 1]) > index:
				at -= 1
			list.insert(at, index)


## Takes object `index` (of the objects the index holds) out: its pictures, its rectangle and its footprint.
func _forget(index: int) -> void:
	for entry: Dictionary in _by_object.get(index, []):
		var box := _cells_of_rect(entry.rect)
		for y: int in range(box.position.y, box.end.y):
			for x: int in range(box.position.x, box.end.x):
				var cell := Vector2i(x, y)
				var list: Array = _picture_cells.get(cell, [])
				for at: int in list.size():
					if is_same(list[at], entry):
						list.remove_at(at)
						break
				if list.is_empty():
					_picture_cells.erase(cell)
	_by_object.erase(index)
	_pictures.erase(index)
	var feet := footprint(_objects[index] as Dictionary)
	for y: int in range(feet.position.y, feet.end.y):
		for x: int in range(feet.position.x, feet.end.x):
			var cell := Vector2i(x, y)
			var list: Array = _cells.get(cell, [])
			list.erase(index)
			if list.is_empty():
				_cells.erase(cell)


## The objects that stay are numbered anew (`new_of_old`, none of them gone any more).
func _renumber(new_of_old: PackedInt32Array) -> void:
	var by_object := {}
	var pictures := {}
	for old_index: int in new_of_old.size():
		var now := new_of_old[old_index]
		if now < 0 or not _by_object.has(old_index):
			continue
		for entry: Dictionary in _by_object[old_index]:
			entry.index = now
		by_object[now] = _by_object[old_index]
		pictures[now] = _pictures[old_index]
	_by_object = by_object
	_pictures = pictures
	for cell: Vector2i in _cells:
		var list: Array = _cells[cell]
		for at: int in list.size():
			list[at] = new_of_old[int(list[at])]


## Everything under `point` (world pixels), front-most first: pictures that are drawn there, then the footprints of
## objects with no picture there (a warp has none), the lower feet first.
func at(point: Vector2) -> Array[int]:
	var found: Array[int] = []
	for entry: Dictionary in _picture_cells.get(Vector2i((point / TILE).floor()), []):
		var index: int = entry.index
		if index in found:
			continue
		if (entry.rect as Rect2).has_point(point) and _is_drawn(entry, point):
			found.append(index)
	var behind: Array[int] = []
	for index: int in objects_at_cell(Vector2i((point / TILE).floor())):
		if not index in found:
			behind.append(index)
	behind.sort_custom(_lower_feet)
	return found + behind


## The objects whose footprint covers `cell`, in file order.
func objects_at_cell(cell: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for index: int in _cells.get(cell, []):
		out.append(index)
	return out


## The rectangle all of an object's pictures cover, in world pixels; an empty Rect2 when it has no picture.
func picture_rect(index: int) -> Rect2:
	return _pictures.get(index, NO_BOX)


## The cells an object stands on: its `at` and `size`; a person or a warp is one cell whatever the file says.
static func footprint(object: Dictionary) -> Rect2i:
	var at: Vector2i = object.get("at", Vector2i.ZERO)
	if String(object.get("kind", "")) in ["person", "warp"]:
		return Rect2i(at, Vector2i.ONE)
	return Rect2i(at, object.get("size", Vector2i.ONE))


## A short name for the status bar and the hover label: "inn (building)", "pip (person)", "warp to home".
static func describe(object: Dictionary) -> String:
	var kind := String(object.get("kind", ""))
	match kind:
		"person":
			return "%s (person)" % object.get("id", "?")
		"warp":
			return "warp to %s" % (object.get("to", {}) as Dictionary).get("map", "?")
	var text := "%s (%s)" % [object.get("art", "?"), kind]
	if object.has("id"):
		text += " " + String(object.id)
	return text


## The object as its content file would say it: cells as [x, y], whole numbers as integers, and without the index and
## the door cell that OverworldMap.build adds. A new Dictionary; the map is not touched.
static func content_of(object: Dictionary) -> Dictionary:
	var out := {}
	for key: String in object:
		if key in ["index", "door_cell"]:
			continue
		out[key] = _plain(object[key])
	return out


static func _plain(value: Variant) -> Variant:
	if value is Vector2i:
		var cell := value as Vector2i
		return [cell.x, cell.y]
	if value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	if value is Dictionary:
		var copy := {}
		for key: Variant in value:
			copy[key] = _plain(value[key])
		return copy
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(_plain(item))
		return items
	return value


## The pieces a node was drawn with: {rect (world pixels), sprite (a Sprite2D to test the pixels of, or null)}.
static func _parts(node: Node2D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: Node in node.get_children():
		if part is Sprite2D:
			var sprite := part as Sprite2D
			if sprite.texture == null:
				continue
			var size := sprite.region_rect.size if sprite.region_enabled else sprite.texture.get_size()
			out.append({"rect": sprite.get_global_transform() * Rect2(Vector2.ZERO, size), "sprite": sprite})
		elif part.get("box") is Rect2:
			# TownMapView's plain block, drawn where a picture is missing.
			out.append({"rect": node.get_global_transform() * (part.get("box") as Rect2), "sprite": null})
	if out.is_empty() and node is Walker:
		var tall := OverworldScale.PERSON.y * 0.8
		var width := OverworldScale.PERSON.x * 0.5
		var figure := Rect2(Vector2(-width / 2.0, -tall), Vector2(width, tall))
		out.append({"rect": node.get_global_transform() * figure, "sprite": null})
	return out


## Front-most first: standing things before flat ones, then lower feet, then the later object, then the later node.
static func _in_front(a: Dictionary, b: Dictionary) -> bool:
	if a.layer != b.layer:
		return a.layer > b.layer
	if not is_equal_approx(a.y, b.y):
		return a.y > b.y
	if a.index != b.index:
		return a.index > b.index
	return a.seq > b.seq


func _lower_feet(a: int, b: int) -> bool:
	return _feet(a) > _feet(b)


func _feet(index: int) -> int:
	var box := footprint(_objects[index] as Dictionary)
	return box.end.y


## Whether the picture has a drawn pixel under `point`. True when the pixels cannot be read (no sprite, no image).
func _is_drawn(entry: Dictionary, point: Vector2) -> bool:
	var sprite: Sprite2D = entry.sprite
	if sprite == null or not is_instance_valid(sprite):
		return true
	var image := _image_of(sprite.texture)
	if image == null:
		return true
	var local := sprite.get_global_transform().affine_inverse() * point
	if sprite.region_enabled:
		local += sprite.region_rect.position
	var x := floori(local.x)
	var y := floori(local.y)
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return true
	return image.get_pixel(x, y).a > DRAWN


static func _image_of(texture: Texture2D) -> Image:
	if texture is AtlasTexture:
		return null
	var key := texture.get_instance_id()
	if not _images.has(key):
		var image := texture.get_image()
		if image != null and (image.is_empty() or image.is_compressed()):
			image = null
		_images[key] = image
	return _images[key]
