extends GdUnitTestSuite
## Buildings sort by their physical wall edge. A reachable door must put the walker in front without moving the sprite;
## roof margins and the wall row behind the door still put a walker behind the artwork.

var view: TownMapView


func before_test() -> void:
	var world := OverworldContent.load_world()
	view = TownMapView.new(world.catalog)
	add_child(view)
	view.show_map(world.catalog.maps.lanternroot)


func after_test() -> void:
	if is_instance_valid(view):
		view.free()


func test_open_home_door_sorts_walker_in_front_and_preserves_building_pixels() -> void:
	var home: Dictionary = world_object("home")
	var node := standing_node_for("home")
	var sprite := node.get_child(0) as Sprite2D
	var tile := float(OverworldScale.TILE)
	var door_feet := Walker.feet(Vector2i(13, 44))
	var rear_wall_feet := Walker.feet(Vector2i(13, 43))
	var back_margin_feet := Walker.feet(Vector2i(13, 40))
	assert_float(node.position.y).is_less(float(door_feet.y))
	assert_float(node.position.y).is_greater(float(rear_wall_feet.y))
	assert_float(node.position.y).is_greater(float(back_margin_feet.y))
	assert_float(node.position.y + sprite.position.y).is_equal_approx(
		float(home.at[1] + home.size[1]) * tile - sprite.texture.get_height() * sprite.scale.y,
		0.01
	)


func world_object(art: String) -> Dictionary:
	for object: Dictionary in view.map.objects:
		if String(object.get("art", "")) == art:
			return object
	return {}


func standing_node_for(art: String) -> Node2D:
	var objects: Array = view.map.objects
	var index: int = objects.find(world_object(art))
	for child: Node2D in view.things.get_children():
		if int(child.get_meta("object_index", -1)) == index:
			return child
	return null
