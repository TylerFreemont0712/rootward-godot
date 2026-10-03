extends GdUnitTestSuite
## Local ambient clocks: independent between rooms, frozen by reduced motion, and driven by rehearsal stepping.

var motion := false


func before_test() -> void:
	motion = Settings.reduced_motion
	Settings.reduced_motion = false


func after_test() -> void:
	Settings.reduced_motion = motion


func test_each_arena_has_its_own_motion_material() -> void:
	var ids := ["kernel", "interrupt-foundry", "heapworks", "sandbox"]
	for ring in 4:
		var room := DungeonBackdrop.new()
		room.show_scene("backgrounds/arena-ring-%d-%s" % [ring, ids[ring]])
		assert_object(room.texture).is_not_null()
		assert_int(room.ring).is_equal(ring)
		assert_int((room.material as ShaderMaterial).get_shader_parameter("ring")).is_equal(ring)
		room.free()


func test_reduced_motion_freezes_the_background_and_resuming_continues_it() -> void:
	var room := DungeonBackdrop.new()
	room.show_scene("backgrounds/arena-ring-2-heapworks")
	room.advance(2.0)
	Settings.reduced_motion = true
	room.advance(20.0)
	assert_float(room.elapsed).is_equal(2.0)
	assert_float((room.material as ShaderMaterial).get_shader_parameter("movement")).is_equal(0.0)
	Settings.reduced_motion = false
	room.advance(0.5)
	assert_float(room.elapsed).is_equal(2.5)
	assert_float((room.material as ShaderMaterial).get_shader_parameter("movement")).is_equal(1.0)
	room.free()


func test_two_rooms_do_not_share_their_material_or_clock() -> void:
	var left := DungeonBackdrop.new()
	var right := DungeonBackdrop.new()
	left.show_scene("backgrounds/map-machine-shaft", 3, true)
	right.show_scene("backgrounds/map-machine-shaft", 2, true)
	left.advance(3.0)
	assert_float(right.elapsed).is_equal(0.0)
	assert_bool(left.material == right.material).is_false()
	left.free()
	right.free()


func test_a_rehearsal_drives_scenery_with_its_own_clock() -> void:
	var stage := BattleStage.new()
	stage.local_clock = true
	stage.tempo = 0.5
	stage.set_backdrop("arena-ring-1-interrupt-foundry")
	var room: DungeonBackdrop = stage.get("_backdrop")
	assert_bool(room.automatic).is_false()
	stage.call("_process", 2.0)
	assert_float(room.elapsed).is_equal(1.0)
	stage.advance(0.25)
	assert_float(room.elapsed).is_equal(1.25)
	stage.free()
