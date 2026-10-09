class_name TownMapView
extends Node2D
## One map of the overworld on screen (ADR-0061): its ground, and everything standing on it, sorted by where it meets
## the ground so whatever is lower on the screen is drawn in front. Townspeople are Walkers kept by id, so the screen
## can turn them toward the player and knows the cells they stand on.

const TILE := 16

var map: Dictionary = {}
var ground: GroundLayer
## Everything that stands: buildings, props, people, the player, Hotaru. Sorted by y.
var things: Node2D
var people: Dictionary = {}

var _catalog: Dictionary = {}
var _prop_sizes: Dictionary = {}


func _init(catalog: Dictionary) -> void:
	_catalog = catalog
	var text := FileAccess.get_file_as_string(OverworldArt.ROOT + "props/props.json")
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	_prop_sizes = parsed if parsed is Dictionary else {}


func _ready() -> void:
	ground = GroundLayer.new()
	add_child(ground)
	things = Node2D.new()
	things.y_sort_enabled = true
	add_child(things)


## Shows a map. Lamps (props with a lit frame) are lit, except those in `dark_groups` (the lane before lesson 3).
func show_map(shown: Dictionary, lit := true, dark_groups: Array = []) -> void:
	map = shown
	ground.show_map(map)
	for child in things.get_children():
		if child is Walker and child.has_meta("player"):
			continue
		if child is HotaruSprite:
			continue
		child.queue_free()
	people.clear()
	for object: Dictionary in map.objects:
		match String(object.kind):
			"building":
				things.add_child(_standing(OverworldArt.building(String(object.art)), object, 0, 1))
			"prop", "sign":
				var art := String(object.get("art", "sign"))
				var frames := int((_prop_sizes.get(art, {}) as Dictionary).get("frames", 1))
				var dark := String(object.get("group", "")) in dark_groups
				var frame := frames - 1 if lit and not dark and frames > 1 else 0
				things.add_child(_standing(OverworldArt.prop(art), object, frame, frames))
			"person":
				_add_person(object)


func _add_person(object: Dictionary) -> void:
	var id := String(object.id)
	var person: Dictionary = (_catalog.get("townsfolk", {}) as Dictionary).get(id, {})
	var walker := Walker.new(OverworldArt.sheet(person.get("look", {})))
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
## position (what the y-sort reads) is that point.
func _standing(texture: Texture2D, object: Dictionary, frame: int, frames: int) -> Node2D:
	var at: Vector2i = object.at
	var footprint: Vector2i = object.size
	var base := Node2D.new()
	base.position = Vector2((at.x + footprint.x / 2.0) * TILE, (at.y + footprint.y) * TILE)
	if texture == null:
		var plain := _Plain.new()
		plain.box = Rect2(-footprint.x * TILE / 2.0, -footprint.y * TILE, footprint.x * TILE, footprint.y * TILE)
		base.add_child(plain)
		return base
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	var width := texture.get_width() / maxi(1, frames)
	if frames > 1:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(frame * width, 0, width, texture.get_height())
	sprite.position = Vector2(-width / 2.0, -texture.get_height()).floor()
	sprite.position.y += int(object.get("sink", 0))
	base.add_child(sprite)
	return base


## Where a picture is missing: a plain block on the footprint, so the map still reads.
class _Plain:
	extends Node2D
	var box: Rect2

	func _draw() -> void:
		draw_rect(box, Color("#c4ac90"))
		draw_rect(box, Color("#2a1d2b"), false, 1.0)
