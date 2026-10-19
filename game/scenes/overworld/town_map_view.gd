class_name TownMapView
extends Node2D
## One map of the overworld on screen (ADR-0061): its ground, and everything standing on it, sorted by where it meets
## the ground so whatever is lower on the screen is drawn in front. Townspeople are Walkers kept by id, so the screen
## can turn them toward the player and knows the cells they stand on.

const TILE := OverworldScale.TILE

var map: Dictionary = {}
var ground: GroundLayer
## Flat, walkable art (rugs, doormats, steps and bridges) draws above terrain but below every walker and standing prop.
var underfoot: Node2D
## Everything that stands: buildings, props, people, the player, Hotaru. Sorted by y.
var things: Node2D
var people: Dictionary = {}

var _catalog: Dictionary = {}
## The nodes made for each of map.objects, by index, and what they were made with (see update_objects).
var _nodes: Array[Array] = []
var _lit := true
var _dark_groups: Array = []
var _open: Dictionary = {}
var _shown := false
var _gates: Array[TownGate] = []


func _init(catalog: Dictionary) -> void:
	_catalog = catalog


func _ready() -> void:
	ground = GroundLayer.new()
	add_child(ground)
	underfoot = Node2D.new()
	underfoot.name = "Underfoot"
	add_child(underfoot)
	things = Node2D.new()
	things.y_sort_enabled = true
	add_child(things)


func _process(_delta: float) -> void:
	if _gates.is_empty():
		return
	var occupied := {}
	for child: Node in things.get_children():
		if child is Walker:
			var walker := child as Walker
			occupied[walker.cell] = true
			# LEARN: cell is the destination as soon as a step starts. Also retain the feet's current tile until
			# the body clears it, so a closing leaf cannot snap through someone walking out.
			if walker.moving:
				occupied[Vector2i(((walker.position - Vector2(0, TILE / 2.0)) / TILE).floor())] = true
	for gate: TownGate in _gates:
		gate.update_occupancy(occupied)


## Shows a map. Lamps (props with a lit frame) are lit, except those in `dark_groups` (the lane before lesson 3). `open`
## holds the cells of the things that are open now (TownThings.open_cells); see _add_thing.
func show_map(shown: Dictionary, lit := true, dark_groups: Array = [], open: Dictionary = {}) -> void:
	# LEARN: baking the ground costs three quarters of a second on the town, and a map's objects never change it. A map
	# with the same ground as the one shown keeps the baked pictures, so editing a thing does not repaint every tile.
	var same_ground := _same_ground(shown)
	map = shown
	if same_ground:
		ground.map = map
	else:
		ground.show_map(map)
	for child in underfoot.get_children():
		_discard(underfoot, child)
	for child in things.get_children():
		if child is Walker and child.has_meta("player"):
			continue
		if child is HotaruSprite:
			continue
		_discard(things, child)
	people.clear()
	_gates.clear()
	_nodes.clear()
	for index in (map.objects as Array).size():
		_make(index, lit, dark_groups, open)
	_lit = lit
	_dark_groups = dark_groups
	_open = open
	_shown = true


## Brings the pictures up to date after an edit that changed a few of the map's objects, without making them all again
## (Lanternroot Studio, Concept/v0.3/10 section 9.9). `new_of_old` has, for each object of the map shown now, its index
## in `shown`, or -1 when it is gone or has changed (its pictures are made again); `made` lists the indexes of `shown`
## that need new pictures (the new and the changed ones). The pictures keep the order a whole `show_map` would give them.
## Returns {ok, new_of_old, made} (the same as asked, plus the objects whose open or shut look changed), or {} when
## this needs a whole show_map: nothing shown yet, other ground, lamps lit another way, or lists that do not fit.
func update_objects(
	shown: Dictionary,
	new_of_old: PackedInt32Array,
	made: PackedInt32Array,
	lit := true,
	dark_groups: Array = [],
	open: Dictionary = {}
) -> Dictionary:
	if not _shown or lit != _lit or dark_groups != _dark_groups or not _same_ground(shown):
		return {}
	var objects: Array = shown.objects
	if new_of_old.size() != _nodes.size() or new_of_old.size() != (map.objects as Array).size():
		return {}
	var gone := new_of_old.duplicate()
	var wanted := PackedInt32Array()
	wanted.append_array(made)
	if open != _open:
		# A thing that opened or shut since is drawn again (see _add_thing).
		var before: Array = map.objects
		for old_index: int in before.size():
			var thing: Dictionary = before[old_index]
			if gone[old_index] >= 0 and thing.has("program") and _open.has(thing.at) != open.has(thing.at):
				wanted.append(gone[old_index])
				gone[old_index] = -1
	wanted.sort()
	var kept := 0
	for index: int in gone:
		kept += 1 if index >= 0 else 0
	if kept + wanted.size() != objects.size():
		return {}
	# What the old objects' pictures become: dropped, or kept under the object's new index.
	var next_nodes: Array[Array] = []
	for index in objects.size():
		next_nodes.append([])
	for old_index: int in gone.size():
		var new_index := gone[old_index]
		for node: Node2D in _nodes[old_index]:
			if new_index < 0:
				if node is TownGate:
					_gates.erase(node)
				_discard(node.get_parent(), node)
				if node is Walker and people.get(String(node.get_meta("person", ""))) == node:
					people.erase(String(node.get_meta("person")))
			elif new_index != old_index:
				node.set_meta("object_index", new_index)
		if new_index >= 0:
			next_nodes[new_index] = _nodes[old_index]
	_nodes = next_nodes
	map = shown
	ground.map = shown
	for index: int in wanted:
		_make(index, lit, dark_groups, open, true)
	_open = open
	return {"ok": true, "new_of_old": gone, "made": wanted}


## Shows `shown`'s ground by painting again only the cells whose ground differs from what is baked (Lanternroot Studio's
## brushes, Concept/v0.3/10 section 7.8); the objects are not touched. True when the ground on screen is now `shown`'s;
## false when it needs a whole show_map (another size or kind of place, or water coming or going).
func paint_ground(shown: Dictionary) -> bool:
	if ground.map.is_empty() or not ground.can_repaint(shown):
		return false
	return ground.repaint(shown, ground.changed_cells(shown))


## The same, when the caller knows which cells may differ (`cells`, a stroke's new ones): nothing is compared.
func paint_ground_cells(shown: Dictionary, cells: Array[Vector2i]) -> bool:
	if ground.map.is_empty() or not ground.can_repaint(shown):
		return false
	return ground.repaint(shown, cells)


## The nodes made for map.objects[index] (none for a shut gate with one frame, and so on).
func nodes_of(index: int) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if index >= 0 and index < _nodes.size():
		out.assign(_nodes[index])
	return out


## Takes a node out of the tree at once and frees it, so a picture made again never stands beside the old one, and the
## order of the children is only ever the live pictures'.
static func _discard(parent: Node, child: Node) -> void:
	if parent != null and child.get_parent() == parent:
		parent.remove_child(child)
	child.queue_free()


## Whether `shown` has the ground the ground layer has baked (cells, size and whether it is a room).
func _same_ground(shown: Dictionary) -> bool:
	var baked := ground.map
	return (
		not baked.is_empty()
		and baked.get("interior", false) == shown.get("interior", false)
		and baked.get("width", -1) == shown.get("width", -2)
		and baked.get("height", -1) == shown.get("height", -2)
		and baked.get("ground") == shown.get("ground")
	)


## Makes the pictures of map.objects[index] and keeps them. With `placed`, they are moved from the end of the children to
## where the objects before and after them stand, so the order is the same as when every object is made in turn.
func _make(index: int, lit: bool, dark_groups: Array, open: Dictionary, placed := false) -> void:
	var object: Dictionary = map.objects[index]
	var standing_before := things.get_child_count()
	var flat_before := underfoot.get_child_count()
	_add_object(object, lit, dark_groups, open)
	var made: Array[Node2D] = []
	_tag(things, standing_before, index, made)
	_tag(underfoot, flat_before, index, made)
	if placed:
		_seat(things, standing_before, index)
		_seat(underfoot, flat_before, index)
		_nodes[index] = made
	else:
		_nodes.append(made)


## Every node made for map.objects[index] knows it (`object_index`), so Lanternroot Studio can tell what was clicked,
## even on a tree's crown far above its footprint (ADR-0066).
static func _tag(parent: Node, from: int, index: int, made: Array[Node2D]) -> void:
	for i in range(from, parent.get_child_count()):
		var node := parent.get_child(i) as Node2D
		node.set_meta("object_index", index)
		made.append(node)


## Moves the nodes `parent` got from child `from` on (the pictures of object `index`) to just after the last picture of
## the nearest object before it that has one here, or just before the first of the nearest one after it.
func _seat(parent: Node2D, from: int, index: int) -> void:
	var count := parent.get_child_count() - from
	if count <= 0:
		return
	var at := -1
	var back := index - 1
	while back >= 0 and at < 0:
		for node: Node2D in _nodes[back]:
			if node.get_parent() == parent:
				at = maxi(at, node.get_index() + 1)
		back -= 1
	if at < 0:
		var ahead := index + 1
		while ahead < _nodes.size() and at < 0:
			for node: Node2D in _nodes[ahead]:
				if node.get_parent() == parent:
					at = node.get_index() if at < 0 else mini(at, node.get_index())
			ahead += 1
	if at < 0 or at >= from:
		return
	for k in count:
		parent.move_child(parent.get_child(from + k), at + k)


func _add_object(object: Dictionary, lit: bool, dark_groups: Array, open: Dictionary) -> void:
	match String(object.kind):
		"building":
			var building := _drawn_art(object)
			var enlarged := OverworldArt.art_scale("buildings", building)
			# A walker on an open door shares the facade's last footprint row. Sort that walker in front of the house,
			# while the row immediately behind the wall still sorts behind it. Keep the sprite in its original position.
			var door_sort_offset := -TILE / 2.0 if object.has("to") else 0.0
			things.add_child(
				_standing(OverworldArt.building(building), object, 0, 1, enlarged, _stretch(object), door_sort_offset)
			)
		"prop", "sign":
			var art := _drawn_art(object)
			var frames := OverworldArt.frames(art)
			if not OverworldArt.swing(art).is_empty():
				var gate := TownGate.new()
				gate.configure(object, OverworldArt.prop(art), frames, object.has("program") and open.has(object.at))
				things.add_child(gate)
				_gates.append(gate)
			elif object.has("program"):
				_add_thing(OverworldArt.prop(art), object, frames, open)
			else:
				var dark := String(object.get("group", "")) in dark_groups
				var frame := frames - 1 if lit and not dark and frames > 1 else 0
				_add_picture(OverworldArt.prop(art), object, frame, frames)
		"person":
			_add_person(object)


## The picture an object is drawn with: its own art, or, for a remake not made yet (OverworldArt.stand_ins), its source's.
static func _drawn_art(object: Dictionary) -> String:
	var art := String(object.get("art", "sign"))
	var stand_in: Variant = OverworldArt.stand_ins.get(art)
	return String((stand_in as Dictionary).get("source", art)) if stand_in is Dictionary else art


## How much a stand-in picture is stretched to fill its remake's footprint (1 x 1 for anything else).
static func _stretch(object: Dictionary) -> Vector2:
	var stand_in: Variant = OverworldArt.stand_ins.get(String(object.get("art", "")))
	if not stand_in is Dictionary and not object.has("art_size"):
		return Vector2.ONE
	var from := OverworldMap.cell_of(stand_in.get("from", [1, 1]) if stand_in is Dictionary else object.art_size)
	var size := OverworldMap.cell_of(object.get("size", [1, 1]))
	return Vector2(float(size.x) / maxf(1.0, from.x), float(size.y) / maxf(1.0, from.y))


## A ground-layer picture never covers a Walker, even when the Walker stands on its cell.
func _add_picture(texture: Texture2D, object: Dictionary, frame: int, frames: int) -> void:
	var parent: Node2D = underfoot if String(object.get("draw_layer", "")) == "ground" else things
	var enlarged := OverworldArt.art_scale("props", _drawn_art(object))
	parent.add_child(_standing(texture, object, frame, frames, enlarged, _stretch(object)))


## A programmed thing uses its full authored footprint when the asset matches; older one-tile art repeats per cell.
## Open shows the last authored frame, or nothing for an older single-frame asset.
func _add_thing(texture: Texture2D, object: Dictionary, frames: int, open: Dictionary) -> void:
	var at: Vector2i = object.at
	var footprint: Vector2i = object.size
	var is_open := open.has(at)
	if is_open and frames <= 1:
		return
	var frame := frames - 1 if is_open else 0
	var entry: Dictionary = OverworldArt.index("world").get(String(object.art), {})
	var drawn: Array = entry.get("footprint", [1, 1])
	if Vector2i(int(drawn[0]), int(drawn[1])) == footprint or object.has("art_size"):
		things.add_child(_standing(texture, object, frame, frames, OverworldArt.art_scale("props", String(object.art)), _stretch(object)))
		return
	for y in footprint.y:
		for x in footprint.x:
			var tile := object.duplicate()
			tile.at = at + Vector2i(x, y)
			tile.size = Vector2i.ONE
			things.add_child(
				_standing(texture, tile, frame, frames, OverworldArt.art_scale("props", String(object.art)))
			)


func _add_person(object: Dictionary) -> void:
	var id := String(object.id)
	var person: Dictionary = (_catalog.get("townsfolk", {}) as Dictionary).get(id, {})
	var walker := Walker.new(OverworldArt.character(person.get("look", {})))
	walker.set_meta("person", id)
	things.add_child(walker)
	walker.place(object.at, String(object.get("facing", "down")))
	people[id] = walker


## The cells townspeople stand on now, for OverworldMap.blocked.
func people_cells() -> Dictionary:
	var cells := {}
	for id: String in people:
		cells[(people[id] as Walker).cell] = id
	return cells


func person_at(cell: Vector2i) -> String:
	for id: String in people:
		if (people[id] as Walker).cell == cell:
			return id
	return ""


## A thing stands on its footprint: the picture's bottom middle sits on the footprint's bottom middle, and the node's
## position (what the y-sort reads) is that point. `enlarged` is how much larger than drawn the picture is shown (art
## drawn for 16 px tiles, ADR-0064); a map's `sink` is in the picture's own pixels, so it is enlarged with it.
func _standing(
	texture: Texture2D,
	object: Dictionary,
	frame: int,
	frames: int,
	enlarged := 1.0,
	stretch := Vector2.ONE,
	sort_y_offset := 0.0
) -> Node2D:
	var at: Vector2i = object.at
	var footprint: Vector2i = object.size
	var base := Node2D.new()
	base.position = Vector2((at.x + footprint.x / 2.0) * TILE, (at.y + footprint.y) * TILE + sort_y_offset)
	if texture == null:
		var plain := _Plain.new()
		plain.box = Rect2(-footprint.x * TILE / 2.0, -footprint.y * TILE, footprint.x * TILE, footprint.y * TILE)
		plain.position.y = -sort_y_offset
		base.add_child(plain)
		return base
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	var width := texture.get_width() / maxi(1, frames)
	if frames > 1:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(frame * width, 0, width, texture.get_height())
	sprite.scale = Vector2.ONE * enlarged * stretch
	sprite.flip_h = bool(object.get("flip", false))
	sprite.position = (Vector2(-width / 2.0, -texture.get_height()) * enlarged * stretch).floor()
	sprite.position.y += roundf(float(object.get("sink", 0)) * enlarged * stretch.y) - sort_y_offset
	base.add_child(sprite)
	return base


## Where a picture is missing: a plain block on the footprint, so the map still reads.
class _Plain:
	extends Node2D
	var box: Rect2

	func _draw() -> void:
		draw_rect(box, Color("#c4ac90"))
		draw_rect(box, Color("#2a1d2b"), false, 1.0)
