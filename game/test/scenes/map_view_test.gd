extends GdUnitTestSuite
## The layer map as a scroll: taller than its window, gliding where the wheel asks, opening a new layer on its guardian,
## and a guardian on the rail for every layer.

var catalog: Dictionary
var map: MapView
var motion := false


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func before_test() -> void:
	motion = Settings.reduced_motion
	Settings.reduced_motion = false
	MapView._left_at.clear()


func after_test() -> void:
	Settings.reduced_motion = motion
	if is_instance_valid(map):
		map.free()


func _open(state: Dictionary) -> MapView:
	map = MapView.new()
	map.size = Vector2(1300, 820)
	add_child(map)
	map.show_map(state, catalog)
	map.size = Vector2(1300, 820)
	return map


func _start(seed: String) -> Dictionary:
	var options := {"seed": seed, "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.status = "map"
	return state


func _step_in(state: Dictionary) -> Dictionary:
	var first: Dictionary = ShardrunMap.next_rooms(state.map, null)[0]
	state.position = first.id
	state.visited = [first.id]
	return state


func test_only_the_rooms_you_can_walk_into_are_enabled() -> void:
	var state := _step_in(_start("map-rooms"))
	_open(state)
	var open := {}
	for node: Dictionary in ShardrunMap.next_rooms(state.map, state.position):
		open[node.id] = true
	var rooms: Dictionary = map.get("_rooms")
	assert_int(rooms.size()).is_equal((state.map.nodes as Array).size())
	for id: String in rooms:
		assert_bool((rooms[id] as Button).disabled).override_failure_message(id).is_equal(not open.has(id))


func test_the_map_is_taller_than_its_window_and_the_wheel_glides_up() -> void:
	_open(_step_in(_start("map-wheel")))
	assert_float(map.max_scroll()).is_greater(0.0)
	map.jump_to(map.max_scroll())
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.factor = 1.0
	map.call("_on_view_input", wheel)
	var target := map.max_scroll() - MapView.WHEEL_STEP
	assert_float(map.scroll_target()).is_equal_approx(target, 0.01)
	# Part of the way there after a frame, and there after a second: a glide, not a jump.
	map.call("_process", 1.0 / 60.0)
	var partway: float = map.get("_scroll")
	assert_float(partway).is_less(map.max_scroll())
	assert_float(partway).is_greater(target)
	map.call("_process", 1.0)
	assert_float(map.get("_scroll")).is_equal_approx(target, 0.5)


func test_the_view_never_scrolls_past_either_end() -> void:
	_open(_step_in(_start("map-clamp")))
	map.scroll_to(-500.0)
	assert_float(map.scroll_target()).is_equal(0.0)
	map.scroll_to(1e6)
	assert_float(map.scroll_target()).is_equal(map.max_scroll())


func test_a_new_layer_opens_on_its_guardian_then_glides_down_to_the_start() -> void:
	_open(_start("map-intro"))
	assert_float(map.scroll_target()).is_equal(0.0)
	map.call("_process", MapView.INTRO_HOLD + 0.1)
	assert_float(map.scroll_target()).is_equal(map.max_scroll())


func test_with_reduced_motion_a_new_layer_opens_at_the_start() -> void:
	Settings.reduced_motion = true
	_open(_start("map-calm"))
	assert_float(map.get("_scroll")).is_equal(map.max_scroll())


func test_the_rail_shows_a_guardian_for_every_layer() -> void:
	var state := _start("map-rail")
	state.layer = 1
	_open(state)
	var rail: GuardianRail = map.get("_rail")
	var layers: Array = catalog.config.layers
	assert_int(rail.guardians.size()).is_equal(layers.size())
	assert_str(String(rail.guardians[1].where)).is_equal("current")
