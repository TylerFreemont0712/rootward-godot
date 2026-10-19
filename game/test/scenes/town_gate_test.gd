extends GdUnitTestSuite
## Real map views and Walkers exercise automatic passages, wide footprints, overlapping users and programmed locks.

var view: TownMapView
var player: Walker
var _reduced_motion := false


func before_test() -> void:
	_reduced_motion = Settings.reduced_motion
	Settings.reduced_motion = false
	view = TownMapView.new({})
	add_child(view)


func after_test() -> void:
	view.free()
	Settings.reduced_motion = _reduced_motion
	await get_tree().process_frame
	await get_tree().process_frame


func _show(art := "gate", size := Vector2i.ONE, fields: Dictionary = {}) -> TownGate:
	var object := {"kind": "prop", "art": art, "at": [3, 3], "size": [size.x, size.y], "solid": false}
	object.merge(fields, true)
	var built := OverworldMap.build(
		{
			"id": "passages",
			"ground": ["........", "........", "........", "........", "........", "........", "........", "........"],
			"legend": {".": "grass"},
			"objects": [object]
		},
		{"grass": {"walk": true}}
	)
	assert_array(built.errors).is_empty()
	view.show_map(built.map)
	player = Walker.new()
	player.set_meta("player", true)
	view.things.add_child(player)
	player.place(Vector2i(3, 4))
	return view.nodes_of(0)[0] as TownGate


func test_gate_rests_closed_opens_on_its_tile_and_closes_after_leaving() -> void:
	var gate := _show()
	view._process(0)
	assert_bool(gate.opened).is_false()
	player.place(Vector2i(3, 3))
	view._process(0)
	assert_bool(gate.opened).is_true()
	gate._process(TownGate.SWING_TIME)
	assert_float(gate.progress).is_equal(1.0)
	view._process(0)
	assert_bool(gate.opened).is_true()
	player.place(Vector2i(3, 2))
	view._process(0)
	gate._process(TownGate.SWING_TIME)
	assert_bool(gate.opened).is_false()
	assert_float(gate.progress).is_equal(0.0)


func test_both_cells_of_a_wide_horizontal_gate_keep_one_passage_open() -> void:
	var gate := _show("gate-wide-2", Vector2i(2, 1))
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(4, 3)]:
		player.place(cell)
		view._process(0)
		assert_bool(gate.opened).is_true()
		assert_bool(OverworldMap.blocked(view.map, cell)).is_false()
	assert_int(view.nodes_of(0).size()).is_equal(1)


func test_both_cells_of_a_vertical_gate_open_and_adjacent_cells_do_not() -> void:
	var gate := _show("gate-wide-2-v", Vector2i(1, 2))
	for cell: Vector2i in [Vector2i(3, 3), Vector2i(3, 4)]:
		player.place(cell)
		view._process(0)
		assert_bool(gate.opened).is_true()
	player.place(Vector2i(4, 4))
	view._process(0)
	assert_bool(gate.opened).is_false()


func test_npc_holds_gate_open_after_player_leaves_until_last_user_leaves() -> void:
	var gate := _show("gate-wide-2", Vector2i(2, 1))
	var npc := Walker.new()
	view.things.add_child(npc)
	npc.place(Vector2i(4, 3))
	player.place(Vector2i(3, 3))
	view._process(0)
	player.place(Vector2i(3, 4))
	view._process(0)
	assert_bool(gate.opened).is_true()
	npc.place(Vector2i(4, 4))
	view._process(0)
	assert_bool(gate.opened).is_false()


func test_walking_in_opens_before_arrival_and_walking_out_waits_for_feet_to_clear() -> void:
	var gate := _show()
	player.walk_to(Vector2i(3, 3), "up")
	view._process(0)
	assert_bool(gate.opened).is_true()
	await player.arrived
	player.walk_to(Vector2i(3, 2), "up")
	view._process(0)
	assert_bool(gate.opened).is_true()
	await player.arrived
	view._process(0)
	assert_bool(gate.opened).is_false()


func test_programmed_gate_obeys_open_state_instead_of_occupancy() -> void:
	var gate := _show("gate-wide-2", Vector2i(2, 1), {"solid": true, "program": {"hook": "on_use"}})
	player.place(Vector2i(3, 3))
	view._process(0)
	assert_bool(gate.opened).is_false()
	assert_bool(OverworldMap.blocked(view.map, Vector2i(3, 3))).is_true()
	var shown := view.map
	view.show_map(shown, true, [], {Vector2i(3, 3): true, Vector2i(4, 3): true})
	gate = view.nodes_of(0)[0] as TownGate
	player.place(Vector2i(3, 4))
	view._process(0)
	assert_bool(gate.opened).is_true()
	var update := view.update_objects(shown, PackedInt32Array([0]), PackedInt32Array(), true, [], {})
	assert_bool(update.get("ok", false)).is_true()
	gate = view.nodes_of(0)[0] as TownGate
	assert_bool(gate.opened).is_false()


func test_solid_gate_does_not_become_an_automatic_unlocked_passage() -> void:
	var gate := _show("gate", Vector2i.ONE, {"solid": true})
	player.place(Vector2i(3, 3))
	view._process(0)
	assert_bool(gate.automatic).is_false()
	assert_bool(gate.opened).is_false()


func test_swing_uses_intermediate_frames_and_reverses_without_snapping() -> void:
	var gate := _show()
	gate.set_process(false)
	gate.opened = true
	gate._process(TownGate.SWING_TIME / 2)
	var sprite := gate.get_child(0) as Sprite2D
	assert_float(sprite.region_rect.position.x).is_greater(0)
	assert_float(sprite.region_rect.position.x).is_less(sprite.texture.get_width() - sprite.region_rect.size.x)
	var halfway := gate.progress
	gate.opened = false
	gate._process(TownGate.SWING_TIME / 4)
	assert_float(gate.progress).is_greater(0)
	assert_float(gate.progress).is_less(halfway)
	Settings.reduced_motion = true
	gate._process(0.001)
	assert_float(gate.progress).is_equal(0.0)


func test_deleting_a_gate_during_its_swing_drops_occupancy_tracking() -> void:
	var gate := _show()
	player.place(Vector2i(3, 3))
	view._process(0)
	gate._process(TownGate.SWING_TIME / 2.0)
	var shown := view.map.duplicate(true)
	shown.objects = []
	var update := view.update_objects(shown, PackedInt32Array([-1]), PackedInt32Array())
	assert_bool(update.get("ok", false)).is_true()
	view._process(0)
	assert_array(view.get("_gates")).is_empty()
	assert_array(view.nodes_of(0)).is_empty()


func test_catalog_and_placement_previews_show_closed_gate_but_lamps_stay_lit() -> void:
	for art: String in [
		"gate",
		"gate_v",
		"gate-wide-2",
		"gate-wide-3",
		"gate-wide-2-v",
		"expand-arched_wood_gate",
		"expand-arched_wood_gate_v",
		"expand-iron_garden_gate",
		"expand-iron_garden_gate_v"
	]:
		assert_int(OverworldArt.preview_frame(art)).override_failure_message(art).is_equal(0)
		assert_int(OverworldArt.frames(art)).override_failure_message(art).is_equal(13)
	assert_int(OverworldArt.preview_frame("lamppost")).is_equal(OverworldArt.frames("lamppost") - 1)
