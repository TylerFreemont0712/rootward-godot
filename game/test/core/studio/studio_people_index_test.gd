extends GdUnitTestSuite


func _room(room_id := "pell-room", back := {"map": "lanternroot", "at": [5, 4], "facing": "down"}) -> Dictionary:
	return StudioDoors.room_template(room_id, "Pell's room", back)


func _maps(room: Dictionary) -> Dictionary:
	return {
		"lanternroot": {
			"objects": [
				{"kind": "building", "art": "cottage-pell", "at": [4, 2], "size": [3, 2], "door": [1, 1]},
			]
		},
		String(room.get("id", "pell-room")): room,
	}


func test_unlinked_room_draft_matches_the_unique_unlinked_building_at_its_return_cell() -> void:
	var room := _room()
	var maps := _maps(room)
	var ids: Array[String] = ["pell-room"]
	var drafts := StudioPeopleIndex.unlinked_room_drafts(maps, ids)
	assert_int(drafts.size()).is_equal(1)
	assert_str(String(drafts[0].id)).is_equal("pell-room")
	assert_str(String(drafts[0].building_map)).is_equal("lanternroot")
	assert_int(int(drafts[0].building_index)).is_equal(0)
	assert_dict(drafts[0].building).is_equal(maps.lanternroot.objects[0])
	assert_dict(drafts[0].return).is_equal({"map": "lanternroot", "at": [5, 4], "facing": "down"})


func test_ambiguous_building_match_keeps_the_room_locate_only() -> void:
	var room := _room()
	var maps := _maps(room)
	(maps.lanternroot.objects as Array).append(
		{"kind": "building", "art": "another-cottage", "at": [4, 2], "size": [3, 2], "door": [1, 1]}
	)
	var ids: Array[String] = ["pell-room"]
	var drafts := StudioPeopleIndex.unlinked_room_drafts(maps, ids)
	assert_int(drafts.size()).is_equal(1)
	assert_str(String(drafts[0].building_map)).is_empty()
	assert_int(int(drafts[0].building_index)).is_equal(-1)


func test_a_room_with_an_incoming_link_or_without_a_new_map_session_is_not_an_unlinked_draft() -> void:
	var room := _room()
	var maps := _maps(room)
	var incoming := {"objects": [{"kind": "warp", "at": [1, 1], "to": {"map": "pell-room", "at": [5, 6]}}]}
	maps["other-map"] = incoming
	var ids: Array[String] = ["pell-room"]
	assert_array(StudioPeopleIndex.unlinked_room_drafts(maps, ids)).is_empty()
	assert_array(StudioPeopleIndex.unlinked_room_drafts(maps, [])).is_empty()


func test_incoming_links_reports_the_source_object_for_revert_protection() -> void:
	var maps := {
		"town": {"objects": [{"kind": "building", "art": "home", "to": {"map": "room", "at": [5, 6]}}]},
		"room": {"objects": [{"kind": "warp", "to": {"map": "town", "at": [4, 5]}}]},
	}
	var incoming := StudioPeopleIndex.incoming_links(maps, "room")
	assert_int(incoming.size()).is_equal(1)
	assert_str(String(incoming[0].map)).is_equal("town")
	assert_dict(incoming[0].source).is_equal(maps.town.objects[0])
