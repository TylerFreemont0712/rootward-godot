extends GdUnitTestSuite
## Links between things (Concept/v0.3/10, S8; TownWires): which things a step, a use or a change reaches, what an
## on_change thing's code is told, and what is wrong with the links on a map. Plain Dictionaries and Arrays only.


## A plate the player steps onto: two cells wide and not solid, linked to the things named in `links`.
func _plate(id: String, at: Vector2i, links: Array) -> Dictionary:
	return {
		"kind": "prop",
		"id": id,
		"solid": false,
		"at": at,
		"size": Vector2i(2, 1),
		"program": {"hook": "on_step", "fields": {}, "raises": [], "links": links},
	}


## A door that answers on_change: one cell wide, two tall and solid, with a bool field `open`.
func _door(id: String) -> Dictionary:
	return {
		"kind": "prop",
		"id": id,
		"solid": true,
		"at": Vector2i(6, 1),
		"size": Vector2i(1, 2),
		"program": {"hook": "on_change", "fields": {"open": {"type": "bool", "default": false}}, "raises": []},
	}


## A sign that answers on_use, on a cell of its own.
func _sign(id: String) -> Dictionary:
	return {
		"kind": "prop",
		"id": id,
		"at": Vector2i(1, 1),
		"size": Vector2i(1, 1),
		"program": {"hook": "on_use", "fields": {}, "raises": []},
	}


## A prop with no program: a rock. It can be linked to, but it answers nothing.
func _rock(id: String) -> Dictionary:
	return {"kind": "prop", "id": id, "at": Vector2i(7, 7), "size": Vector2i(1, 1)}


## The ids of a list of things, in their order.
func _ids(things: Array) -> Array:
	var out := []
	for thing: Dictionary in things:
		out.append(thing["id"])
	return out


func test_each_hook_has_its_snake_case_and_camel_case_names() -> void:
	assert_array(TownWires.entries("on_use")).is_equal(["on_use", "onUse"])
	assert_array(TownWires.entries("on_step")).is_equal(["on_step", "onStep"])
	assert_array(TownWires.entries("on_change")).is_equal(["on_change", "onChange"])


func test_an_unknown_hook_has_no_names() -> void:
	assert_array(TownWires.entries("on_fall")).is_empty()
	assert_array(TownWires.entries("")).is_empty()


func test_there_are_three_hooks_and_a_chain_of_eight_links() -> void:
	assert_array(TownWires.HOOKS).is_equal(["on_use", "on_step", "on_change"])
	assert_int(TownWires.MAX_CHAIN).is_equal(8)


func test_hook_of_is_the_programs_hook_or_empty_without_a_program() -> void:
	assert_str(TownWires.hook_of(_plate("plate-1", Vector2i(2, 3), []))).is_equal("on_step")
	assert_str(TownWires.hook_of(_rock("rock"))).is_equal("")
	assert_str(TownWires.hook_of({"id": "odd", "program": {"fields": {}}})).is_equal("")


func test_links_of_are_the_programs_links_as_strings() -> void:
	var thing := {"program": {"hook": "on_step", "links": ["door-1", 3, "door-2"]}}
	assert_array(TownWires.links_of(thing)).is_equal(["door-1", "door-2"])
	assert_array(TownWires.links_of({"program": {"hook": "on_step"}})).is_empty()
	assert_array(TownWires.links_of({"program": {"links": "door-1"}})).is_empty()


func test_a_plate_answers_for_each_cell_it_covers_and_no_other() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["door-1"])]
	assert_array(_ids(TownWires.step_targets(objects, Vector2i(2, 3)))).is_equal(["plate-1"])
	assert_array(_ids(TownWires.step_targets(objects, Vector2i(3, 3)))).is_equal(["plate-1"])
	assert_array(TownWires.step_targets(objects, Vector2i(4, 3))).is_empty()
	assert_array(TownWires.step_targets(objects, Vector2i(2, 4))).is_empty()


func test_step_targets_keep_object_order_and_skip_the_other_hooks() -> void:
	var objects := [
		_plate("plate-b", Vector2i(2, 3), []),
		_sign("sign-1"),
		_plate("plate-a", Vector2i(1, 3), []),
	]
	var sign := _sign("sign-2")
	sign["at"] = Vector2i(2, 3)
	objects.append(sign)
	assert_array(_ids(TownWires.step_targets(objects, Vector2i(2, 3)))).is_equal(["plate-b", "plate-a"])


func test_change_targets_follow_the_links_in_their_order() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["door-2", "door-1"]), _door("door-1"), _door("door-2")]
	assert_array(_ids(TownWires.change_targets(objects, "plate-1"))).is_equal(["door-2", "door-1"])


func test_a_link_to_an_id_not_on_the_map_is_skipped() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["ghost", "door-1"]), _door("door-1")]
	assert_array(_ids(TownWires.change_targets(objects, "plate-1"))).is_equal(["door-1"])


func test_only_things_that_answer_on_change_are_targets() -> void:
	var objects := [
		_plate("plate-1", Vector2i(2, 3), ["sign-1", "plate-2", "rock"]),
		_sign("sign-1"),
		_plate("plate-2", Vector2i(5, 3), []),
		_rock("rock"),
	]
	assert_array(TownWires.change_targets(objects, "plate-1")).is_empty()


func test_ids_already_visited_are_not_followed_and_visited_is_not_changed() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["door-1", "door-2"]), _door("door-1"), _door("door-2")]
	var visited := {"plate-1": true, "door-1": true}
	assert_array(_ids(TownWires.change_targets(objects, "plate-1", visited))).is_equal(["door-2"])
	assert_dict(visited).is_equal({"plate-1": true, "door-1": true})


func test_a_thing_linked_twice_is_reached_once() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["door-1", "door-1"]), _door("door-1")]
	assert_array(_ids(TownWires.change_targets(objects, "plate-1"))).is_equal(["door-1"])


func test_a_source_that_is_not_on_the_map_reaches_nothing() -> void:
	var objects := [_door("door-1")]
	assert_array(TownWires.change_targets(objects, "plate-1")).is_empty()


func test_source_of_merges_the_changes_over_the_fields_and_the_changes_win() -> void:
	var fields := {"open": false, "level": 2}
	var source := TownWires.source_of("plate-1", fields, {"open": true})
	assert_dict(source).is_equal({"id": "plate-1", "fields": {"open": true, "level": 2}, "changed": ["open"]})
	assert_dict(fields).is_equal({"open": false, "level": 2})


func test_the_changed_names_are_sorted() -> void:
	var source := TownWires.source_of("plate-1", {"open": false}, {"open": true, "note": "x", "level": 3})
	assert_array(source.changed).is_equal(["level", "note", "open"])
	assert_dict(source.fields).is_equal({"open": true, "level": 3, "note": "x"})


func test_source_of_with_no_changes_copies_the_fields_and_changes_nothing() -> void:
	var source := TownWires.source_of("door-1", {"open": true}, {})
	assert_dict(source).is_equal({"id": "door-1", "fields": {"open": true}, "changed": []})


func test_with_source_writes_the_source_into_the_thing_and_leaves_the_input_alone() -> void:
	var input := {"thing": {"id": "door-1", "fields": {"open": false}}, "player": {"x": 1, "y": 2}}
	var source := {"id": "plate-1", "fields": {"open": true}, "changed": ["open"]}
	var out := TownWires.with_source(input, source)
	assert_dict(out.thing).is_equal({"id": "door-1", "fields": {"open": false}, "source": source})
	assert_dict(out.player).is_equal({"x": 1, "y": 2})
	assert_dict(input).is_equal({"thing": {"id": "door-1", "fields": {"open": false}}, "player": {"x": 1, "y": 2}})


func test_with_source_makes_the_thing_when_the_input_has_none() -> void:
	var out := TownWires.with_source({"player": {}}, {"id": "plate-1", "fields": {}, "changed": []})
	assert_dict(out.thing).is_equal({"source": {"id": "plate-1", "fields": {}, "changed": []}})


func test_a_plate_to_a_door_has_no_problems() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["door-1"]), _door("door-1"), _rock("rock")]
	assert_array(TownWires.problems(objects)).is_empty()


func test_a_hook_that_is_not_one_of_the_three_is_named() -> void:
	var objects := [
		{"kind": "prop", "id": "odd", "at": Vector2i(2, 3), "size": Vector2i(1, 1), "program": {"hook": "on_fall"}}
	]
	assert_array(TownWires.problems(objects)).is_equal(
		["odd has a hook on_fall that is not on_use, on_step or on_change"]
	)


func test_a_link_to_an_id_not_on_the_map_is_named() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["ghost"])]
	assert_array(TownWires.problems(objects)).is_equal(["plate-1 links to ghost, which is not a thing on this map"])


func test_a_thing_that_links_to_itself_is_named() -> void:
	var door := _door("door-1")
	door["program"]["links"] = ["door-1"]
	assert_array(TownWires.problems([door])).is_equal(["door-1 links to itself"])


func test_a_link_to_a_thing_that_does_not_answer_on_change_is_named() -> void:
	var objects := [_plate("plate-1", Vector2i(2, 3), ["sign-1", "rock"]), _sign("sign-1"), _rock("rock")]
	assert_array(TownWires.problems(objects)).is_equal(
		[
			"plate-1 links to sign-1, which does not answer on_change",
			"plate-1 links to rock, which does not answer on_change",
		]
	)


func test_an_on_step_thing_that_is_solid_is_named_and_a_missing_solid_counts_as_solid() -> void:
	var missing := {
		"kind": "prop", "id": "plate-1", "at": Vector2i(2, 3), "size": Vector2i(2, 1),
		"program": {"hook": "on_step", "fields": {}, "raises": [], "links": []},
	}
	var explicit := _plate("plate-2", Vector2i(5, 3), [])
	explicit["solid"] = true
	assert_array(TownWires.problems([missing])).is_equal(
		["plate-1 answers on_step but is solid, so nobody can step onto it"]
	)
	assert_array(TownWires.problems([explicit])).is_equal(
		["plate-2 answers on_step but is solid, so nobody can step onto it"]
	)


func test_links_that_are_not_a_list_of_thing_ids_are_named() -> void:
	var text := _plate("plate-1", Vector2i(2, 3), [])
	text["program"]["links"] = "door-1"
	var mixed := _plate("plate-2", Vector2i(5, 3), ["door-1", 4])
	var objects := [text, mixed, _door("door-1")]
	assert_array(TownWires.problems(objects)).is_equal(
		["plate-1 has links that are not a list of thing ids", "plate-2 has links that are not a list of thing ids"]
	)


func test_a_thing_without_a_program_has_no_problems_of_its_own() -> void:
	assert_array(TownWires.problems([_rock("rock"), {"id": "bare", "solid": true}])).is_empty()
