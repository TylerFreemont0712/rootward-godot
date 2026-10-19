extends GdUnitTestSuite

## Where the way out of a new room leads: the lobby of Lanternroot, in front of the building's door.
const BACK: Dictionary = {"map": "lanternroot", "at": [5, 4], "facing": "down"}
const TERRAIN: Dictionary = {"wall": {"walk": false}, "floor": {"walk": true}, "void": {"walk": false}}
const COTTAGE: Dictionary = {"kind": "building", "art": "cottage", "at": [4, 2], "size": [3, 2], "door": [1, 1]}


func _room() -> Dictionary:
	return StudioDoors.room_template("cottage", "Pell's cottage", BACK)


# --- the room template ---------------------------------------------------------------------------------------------


func test_an_eleven_by_eight_room_has_walls_floor_and_a_void_row_with_one_way_out() -> void:
	assert_that(StudioDoors.ROOM_SIZE).is_equal(Vector2i(11, 8))
	assert_dict(StudioDoors.ROOM_LEGEND).is_equal({"W": "wall", "f": "floor", "v": "void"})
	var room := _room()
	assert_array(room.ground).is_equal(
		[
			"WWWWWWWWWWW",
			"WWWWWWWWWWW",
			"fffffffffff",
			"fffffffffff",
			"fffffffffff",
			"fffffffffff",
			"fffffffffff",
			"vvvvvfvvvvv",
		]
	)
	assert_array(room.keys()).is_equal(["id", "name", "interior", "legend", "ground", "start", "facing", "objects"])
	assert_str(room.id).is_equal("cottage")
	assert_str(room.name).is_equal("Pell's cottage")
	assert_bool(room.interior).is_true()


func test_the_room_starts_in_the_middle_facing_up_with_the_doormat_and_the_way_out_below() -> void:
	var room := _room()
	assert_array(room.start).is_equal([5, 6])
	assert_str(room.facing).is_equal("up")
	assert_array(room.objects).is_equal(
		[
			{"kind": "prop", "art": "doormat", "at": [5, 7], "solid": false, "draw_layer": "ground"},
			{"kind": "warp", "at": [5, 7], "to": {"map": "lanternroot", "at": [5, 4], "facing": "down"}},
		]
	)


func test_a_six_by_five_room_puts_its_middle_at_column_three() -> void:
	var room := StudioDoors.room_template("hut", "Hut", BACK, Vector2i(6, 5))
	assert_array(room.ground).is_equal(["WWWWWW", "WWWWWW", "ffffff", "ffffff", "vvvfvv"])
	assert_array(room.start).is_equal([3, 3])
	assert_array(room.objects[1].at).is_equal([3, 4])


func test_the_smallest_room_is_three_by_four() -> void:
	var room := StudioDoors.room_template("tiny", "Tiny", BACK, Vector2i(3, 4))
	assert_array(room.ground).is_equal(["WWW", "WWW", "fff", "vfv"])
	assert_array(room.start).is_equal([1, 2])


func test_a_room_too_small_for_walls_a_floor_row_and_a_way_out_is_refused() -> void:
	assert_dict(StudioDoors.room_template("x", "X", BACK, Vector2i(2, 4))).is_empty()
	assert_dict(StudioDoors.room_template("x", "X", BACK, Vector2i(3, 3))).is_empty()
	assert_dict(StudioDoors.room_template("x", "X", BACK, Vector2i(1, 1))).is_empty()


func test_the_way_out_keeps_its_own_copy_of_the_back_link() -> void:
	var back := BACK.duplicate(true)
	var room := StudioDoors.room_template("cottage", "Pell's cottage", back)
	back["map"] = "somewhere-else"
	assert_str(room.objects[1].to.map).is_equal("lanternroot")


func test_the_room_builds_with_no_errors_and_its_start_and_way_out_can_be_walked_on() -> void:
	var room := _room()
	var built := OverworldMap.build(room, TERRAIN)
	assert_array(built.errors).is_empty()
	var map: Dictionary = built.map
	var way_out := OverworldMap.cell_of([5, 7])
	assert_bool(OverworldMap.blocked(map, OverworldMap.cell_of(room.start))).is_false()
	assert_bool(OverworldMap.blocked(map, way_out)).is_false()
	assert_str(OverworldMap.warp_at(map, way_out).map).is_equal("lanternroot")


# --- ids -----------------------------------------------------------------------------------------------------------


func test_room_id_turns_a_title_into_a_safe_lower_case_id() -> void:
	var none: Array[String] = []
	assert_str(StudioDoors.room_id("Pell's cottage", none)).is_equal("pell-s-cottage")
	assert_str(StudioDoors.room_id("  --Hello,   World!! ", none)).is_equal("hello-world")
	assert_str(StudioDoors.room_id("Room 2", none)).is_equal("room-2")
	assert_str(StudioDoors.room_id("__x__", none)).is_equal("x")


func test_room_id_is_room_when_nothing_is_left_of_the_name() -> void:
	var none: Array[String] = []
	assert_str(StudioDoors.room_id("", none)).is_equal("room")
	assert_str(StudioDoors.room_id("!!!", none)).is_equal("room")
	assert_str(StudioDoors.room_id("日本語", none)).is_equal("room")


func test_room_id_takes_the_first_free_number_when_the_id_is_taken() -> void:
	var one: Array[String] = ["pell-s-cottage"]
	assert_str(StudioDoors.room_id("Pell's cottage", one)).is_equal("pell-s-cottage-2")
	var two: Array[String] = ["pell-s-cottage", "pell-s-cottage-2"]
	assert_str(StudioDoors.room_id("Pell's cottage", two)).is_equal("pell-s-cottage-3")
	var gap: Array[String] = ["pell-s-cottage-2"]
	assert_str(StudioDoors.room_id("Pell's cottage", gap)).is_equal("pell-s-cottage")


# --- doors -----------------------------------------------------------------------------------------------------------


func test_the_door_is_the_corner_plus_its_offset_and_the_front_is_the_cell_below_it() -> void:
	assert_that(StudioDoors.door_cell(COTTAGE)).is_equal(Vector2i(5, 3))
	assert_that(StudioDoors.front_of(COTTAGE)).is_equal(Vector2i(5, 4))


func test_make_interior_builds_a_room_whose_way_out_lands_in_front_of_the_building() -> void:
	var none: Array[String] = []
	var made := StudioDoors.make_interior(COTTAGE, "lanternroot", none, "Pell's cottage")
	assert_bool(made.ok).is_true()
	assert_str(made.room_id).is_equal("cottage")
	assert_dict(made.to).is_equal({"map": "cottage", "at": [5, 6], "facing": "up"})
	var room: Dictionary = made.room
	assert_str(room.name).is_equal("Pell's cottage")
	assert_dict(room.objects[1].to).is_equal({"map": "lanternroot", "at": [5, 4], "facing": "down"})


func test_make_interior_numbers_the_room_when_its_id_is_taken() -> void:
	var taken: Array[String] = ["cottage"]
	var made := StudioDoors.make_interior(COTTAGE, "lanternroot", taken, "Pell's cottage")
	assert_bool(made.ok).is_true()
	assert_str(made.room_id).is_equal("cottage-2")
	assert_str(made.to.map).is_equal("cottage-2")


func test_make_interior_refuses_an_object_that_is_not_a_building() -> void:
	var none: Array[String] = []
	var prop := {"kind": "prop", "art": "barrel", "at": [1, 1]}
	var made := StudioDoors.make_interior(prop, "lanternroot", none, "Barrel")
	assert_bool(made.ok).is_false()
	assert_str(made.error).is_equal("only a building has a door")


func test_make_interior_refuses_a_door_that_already_leads_somewhere() -> void:
	var none: Array[String] = []
	var linked := COTTAGE.duplicate(true)
	linked["to"] = {"map": "inn", "at": [1, 1]}
	var made := StudioDoors.make_interior(linked, "lanternroot", none, "Pell's cottage")
	assert_bool(made.ok).is_false()
	assert_str(made.error).is_equal("its door already leads to inn")


func test_make_interior_refuses_a_room_too_small_for_a_room() -> void:
	var none: Array[String] = []
	var made := StudioDoors.make_interior(COTTAGE, "lanternroot", none, "Tiny", Vector2i(2, 4))
	assert_bool(made.ok).is_false()
	assert_str(made.error).is_equal("a room needs at least 3 x 4 cells")


func test_door_along_slides_the_door_along_the_bottom_row_and_clamps_it_to_the_building() -> void:
	assert_that(StudioDoors.door_along(COTTAGE, Vector2i(5, 2))).is_equal(Vector2i(1, 1))
	assert_that(StudioDoors.door_along(COTTAGE, Vector2i(9, 0))).is_equal(Vector2i(2, 1))
	assert_that(StudioDoors.door_along(COTTAGE, Vector2i(-5, 9))).is_equal(Vector2i(0, 1))
	assert_that(StudioDoors.door_along(COTTAGE, Vector2i(6, 3))).is_equal(Vector2i(2, 1))


# --- links -----------------------------------------------------------------------------------------------------------


func _linking_data() -> Dictionary:
	return {
		"objects":
		[
			{"kind": "warp", "at": [5, 7], "to": {"map": "cottage", "at": [5, 6], "facing": "up"}},
			"junk",
			{"kind": "prop", "art": "barrel", "at": [1, 1]},
			{"kind": "warp", "at": [0, 0], "to": {"map": "cottage", "at": [4, 6], "facing": "up"}},
			{"kind": "warp", "at": [0, 1], "to": {"map": "inn", "at": [5, 6], "facing": "up"}},
			{"kind": "building", "art": "shed", "at": [6, 2], "to": {"map": "cottage", "at": [5, 6], "facing": "down"}},
		]
	}


func test_links_to_finds_only_the_links_into_that_map_at_that_cell() -> void:
	assert_array(StudioDoors.links_to(_linking_data(), "cottage", Vector2i(5, 6))).is_equal([0, 5])
	assert_array(StudioDoors.links_to(_linking_data(), "cottage", Vector2i(0, 0))).is_empty()


func test_retarget_moves_only_the_matching_links_and_keeps_their_other_keys() -> void:
	var sids: Array[int] = [11, 12, 13, 14, 15, 16]
	var command := StudioDoors.retarget(_linking_data(), sids, "cottage", Vector2i(5, 6), Vector2i(6, 6))
	assert_str(command.name).is_equal("Follow the door of cottage")
	assert_array(command.commands).is_equal(
		[
			{"type": "set", "sid": 11, "key": "to", "value": {"map": "cottage", "at": [6, 6], "facing": "up"}},
			{"type": "set", "sid": 16, "key": "to", "value": {"map": "cottage", "at": [6, 6], "facing": "down"}},
		]
	)


func test_retarget_is_empty_when_nothing_links_there_or_nothing_moves() -> void:
	var sids: Array[int] = [11, 12, 13, 14, 15, 16]
	assert_dict(StudioDoors.retarget(_linking_data(), sids, "cottage", Vector2i(1, 1), Vector2i(2, 2))).is_empty()
	assert_dict(StudioDoors.retarget(_linking_data(), sids, "cottage", Vector2i(5, 6), Vector2i(5, 6))).is_empty()


func test_retarget_skips_a_link_that_has_no_session_id() -> void:
	var sids: Array[int] = [11]
	var command := StudioDoors.retarget(_linking_data(), sids, "cottage", Vector2i(5, 6), Vector2i(6, 6))
	assert_int(command.commands.size()).is_equal(1)
	assert_int(command.commands[0].sid).is_equal(11)


func test_link_command_takes_a_cell_or_an_array_and_unlink_erases_the_to() -> void:
	var from_cell := StudioDoors.link_command(7, {"map": "cottage", "at": Vector2i(5, 6), "facing": "up"})
	var up := {"map": "cottage", "at": [5, 6], "facing": "up"}
	assert_dict(from_cell).is_equal({"type": "set", "sid": 7, "key": "to", "value": up})
	var from_array := StudioDoors.link_command(7, {"map": "cottage", "at": [5, 6]})
	var unfaced := {"map": "cottage", "at": [5, 6], "facing": ""}
	assert_dict(from_array).is_equal({"type": "set", "sid": 7, "key": "to", "value": unfaced})
	assert_dict(StudioDoors.unlink_command(7)).is_equal({"type": "set", "sid": 7, "key": "to", "value": null})


# --- people and quests -----------------------------------------------------------------------------------------------


func test_standing_lists_the_person_on_every_map_in_id_order() -> void:
	var maps := {
		"lanternroot":
		{
			"objects":
			[
				{"kind": "person", "id": "marta", "at": [3, 4], "facing": "left"},
				{"kind": "person", "id": "orin", "at": [1, 1]},
			],
		},
		"inn":
		{
			"objects":
			[
				{"kind": "prop", "art": "table", "at": [0, 0]},
				{"kind": "person", "id": "marta", "at": [2, 2]},
			],
		},
		"archive": {"objects": []},
	}
	assert_array(StudioDoors.standing(maps, "marta")).is_equal(
		[
			{"map": "inn", "index": 1, "at": Vector2i(2, 2), "facing": "down"},
			{"map": "lanternroot", "index": 0, "at": Vector2i(3, 4), "facing": "left"},
		]
	)
	assert_array(StudioDoors.standing(maps, "nobody")).is_empty()


func _quests() -> Dictionary:
	return {
		"boots":
		{
			"order": 1,
			"title": "Your own two feet",
			"giver": "hotaru",
			"steps": [{"text": "Press Try them.", "done": {"flag": "first-step"}}],
		},
		"hello":
		{
			"order": 2,
			"title": "Hello, Lanternroot",
			"giver": "marta",
			"steps":
			[
				{"text": "Say hello to Marta at the Warm Hearth.", "done": {"flag": "met-marta"}},
				{"text": "Meet more of the town.", "done": {"count": "met-", "at_least": 6}},
			],
		},
		"memory":
		{
			"order": 3,
			"title": "Remember me",
			"giver": "archivist",
			"steps": [{"text": "Meet Vell.", "done": {"flag": "memory-asked"}}],
		},
	}


func test_mentions_names_what_a_person_gives_and_the_steps_her_talk_answers_each_line_once() -> void:
	# Two nodes set the same flag: the step is named once.
	var talk := {"nodes": {"hello": {"set": ["met-marta"]}, "bye": {"set": ["met-marta"]}}}
	assert_array(StudioDoors.mentions("marta", _quests(), talk)).is_equal(
		[
			"Gives Hello, Lanternroot",
			"Hello, Lanternroot: Say hello to Marta at the Warm Hearth.",
			"Hello, Lanternroot: Meet more of the town.",
		]
	)


func test_mentions_reads_flags_inside_all_and_not_conditions() -> void:
	var quests := {
		"gate":
		{
			"order": 1,
			"title": "The gate",
			"steps":
			[
				{"text": "Open it.", "done": {"all": [{"flag": "has-key"}, {"not": "gate-open"}]}},
				{"text": "Ask the guard.", "done": {"not": {"flag": "guard-asleep"}}},
				{"text": "Unrelated.", "done": {"flag": "elsewhere"}},
			],
		},
	}
	var talk := {"nodes": {"chat": {"set": ["has-key", "guard-asleep"]}}}
	assert_array(StudioDoors.mentions("guard", quests, talk)).is_equal(["The gate: Open it.", "The gate: Ask the guard."])


func test_mentions_lists_quests_by_their_order_then_by_id() -> void:
	var quests := {
		"zeta": {"order": 1, "title": "Zeta", "giver": "marta"},
		"alpha": {"order": 1, "title": "Alpha", "giver": "marta"},
		"early": {"order": 0, "title": "Early", "giver": "marta"},
	}
	assert_array(StudioDoors.mentions("marta", quests, {})).is_equal(["Gives Early", "Gives Alpha", "Gives Zeta"])


func test_a_person_with_no_talk_is_only_mentioned_as_a_giver() -> void:
	assert_array(StudioDoors.mentions("archivist", _quests(), {})).is_equal(["Gives Remember me"])
	assert_array(StudioDoors.mentions("nobody", _quests(), {})).is_empty()
