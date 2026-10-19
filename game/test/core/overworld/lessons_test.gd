extends GdUnitTestSuite
## Lanternroot's lessons 2 and 3 as pure rules (ADR-0061): blocks become a save or a light_all in Python and
## JavaScript, a run is judged case by case with a reason the screen can put into words, and Continue puts the player
## where their own save says, or at home with a note when the save forgot something.

const TERRAIN := {"grass": {"walk": true}, "water": {"walk": false}, "void": {"walk": false}}
const TOWN := {
	"id": "lanternroot",
	"legend": {".": "grass", "~": "water"},
	"ground": ["......", "....~~", "......"],
	"start": [0, 0],
	"objects":
	[
		{"kind": "sign", "at": [5, 0], "text": "Lanternroot"},
		{"kind": "person", "id": "pip", "at": [3, 2]},
		{"kind": "prop", "art": "lamppost", "at": [4, 0], "group": "lane", "name": "North"},
		{"kind": "prop", "art": "lamppost", "at": [1, 2], "group": "lane"},
		{"kind": "prop", "art": "lamppost", "at": [0, 0], "group": "lane"},
		{"kind": "prop", "art": "lamppost", "at": [2, 0]},
	],
}
const HOME := {"id": "home", "legend": {".": "grass"}, "ground": ["....", "...."], "start": [2, 1], "facing": "up"}


func _maps() -> Dictionary:
	return {
		"lanternroot": OverworldMap.build(TOWN, TERRAIN).map,
		"home": OverworldMap.build(HOME, TERRAIN).map,
	}


## A town with a shut gate across (3, 1) and (4, 1): solid until its open field is set, as the content makes it.
func _gate_maps() -> Dictionary:
	var gate := {
		"kind": "prop",
		"id": "cabbage-gate",
		"solid_unless": "open",
		"at": [3, 1],
		"size": [2, 1],
		"program": {"hook": "on_use", "fields": {"open": {"type": "bool", "default": false}}, "raises": []},
	}
	var town := {
		"id": "lanternroot",
		"legend": {".": "grass"},
		"ground": ["......", "......", "......"],
		"start": [0, 0],
		"objects": [gate],
	}
	return {"lanternroot": OverworldMap.build(town, TERRAIN).map, "home": OverworldMap.build(HOME, TERRAIN).map}


func _state(flags: Dictionary, memory: Variant = null) -> Dictionary:
	var state := OverworldState.fresh("lanternroot", Vector2i(1, 1), "left", "python")
	state.flags = flags
	if memory != null:
		state.memory = memory
	return state


# --- code from blocks ---------------------------------------------------------------------------------------------


func test_save_blocks_keep_the_chosen_fields_in_order() -> void:
	var python := Lessons.save_source(["map", "x", "nonsense", "y"], "python")
	assert_str(python).is_equal(
		(
			'def save(player):\n    return {\n        "x": player["x"],\n'
			+ '        "y": player["y"],\n        "map": player["map"],\n    }\n'
		)
	)
	var javascript := Lessons.save_source(["facing", "name"], "javascript")
	assert_str(javascript).is_equal(
		"function save(player) {\n  return {\n    facing: player.facing,\n    name: player.name,\n  };\n}\n"
	)


func test_a_save_with_no_fields_returns_nothing_kept() -> void:
	assert_str(Lessons.save_source([], "python")).is_equal("def save(player):\n    return {}\n")
	assert_str(Lessons.save_source([], "javascript")).is_equal("function save(player) {\n  return {};\n}\n")


func test_lamp_blocks_make_a_loop_only_when_the_loop_is_there() -> void:
	assert_str(Lessons.lamps_source({}, "python")).is_equal("def light_all(lamps):\n    pass\n")
	assert_str(Lessons.lamps_source({"first": true}, "python")).is_equal(
		'def light_all(lamps):\n    lamps[0]["lit"] = True\n'
	)
	assert_str(Lessons.lamps_source({"loop": true}, "python")).is_equal(
		"def light_all(lamps):\n    for lamp in lamps:\n        pass\n"
	)
	assert_str(Lessons.lamps_source({"loop": true, "inside": true}, "python")).is_equal(
		'def light_all(lamps):\n    for lamp in lamps:\n        lamp["lit"] = True\n'
	)
	# "Light it" on its own has no lamp to light: without the loop it makes nothing.
	assert_str(Lessons.lamps_source({"inside": true}, "python")).is_equal("def light_all(lamps):\n    pass\n")
	(
		assert_str(Lessons.lamps_source({"first": true, "loop": true, "inside": true}, "javascript"))
		. is_equal(
			"function lightAll(lamps) {\n  lamps[0].lit = true;\n  for (const lamp of lamps) {\n    lamp.lit = true;\n  }\n}\n"
		)
	)


func test_source_picks_the_lesson_and_ignores_blocks_of_the_wrong_shape() -> void:
	assert_str(Lessons.source(Lessons.MEMORY, {"loop": true}, "python")).is_equal(Lessons.save_source([], "python"))
	assert_str(Lessons.source(Lessons.LAMPS, ["x"], "python")).is_equal(Lessons.lamps_source({}, "python"))
	assert_that(Lessons.fresh_blocks(Lessons.MEMORY)).is_equal([])
	assert_that(Lessons.fresh_blocks(Lessons.LAMPS)).is_equal({"first": false, "loop": false, "inside": false})


func test_starters_name_the_function_and_do_nothing_yet() -> void:
	assert_str(Lessons.starter(Lessons.MEMORY, "python")).starts_with("def save(player):").ends_with("return {}\n")
	assert_str(Lessons.starter(Lessons.MEMORY, "javascript")).starts_with("function save(player) {")
	assert_str(Lessons.starter(Lessons.LAMPS, "python")).starts_with("def light_all(lamps):").ends_with("pass\n")
	assert_str(Lessons.starter(Lessons.LAMPS, "javascript")).starts_with("function lightAll(lamps) {")
	assert_str(Lessons.typed_or_starter(Lessons.LAMPS, "  \n", "python")).is_equal(
		Lessons.starter(Lessons.LAMPS, "python")
	)
	assert_str(Lessons.entry(Lessons.LAMPS, "javascript")).is_equal("lightAll")


# --- cases --------------------------------------------------------------------------------------------------------


func test_the_cases_are_three_players_or_three_lanes() -> void:
	var players := Lessons.cases(Lessons.MEMORY, "Mio")
	assert_int(players.size()).is_equal(3)
	assert_str(String(players[0].name)).is_equal("Mio")
	assert_array(players.map(func(p: Dictionary) -> String: return p.map)).contains(["home", "lanternroot"])
	var lanes := Lessons.cases(Lessons.LAMPS)
	assert_array(lanes.map(func(l: Array) -> int: return l.size())).contains_exactly([0, 1, 5])
	assert_bool(lanes[2].all(func(lamp: Dictionary) -> bool: return not lamp.lit)).is_true()


func test_the_lane_lights_from_the_lamp_nearest_the_player() -> void:
	var map: Dictionary = _maps().lanternroot
	var from_east := Lessons.lane_from(map, Vector2i(5, 1))
	var cells := from_east.map(func(lamp: Dictionary) -> Vector2i: return OverworldMap.cell_of(lamp.at))
	assert_array(cells).contains_exactly([Vector2i(4, 0), Vector2i(1, 2), Vector2i(0, 0)])
	var from_west := Lessons.lane_from(map, Vector2i(0, 1))
	cells = from_west.map(func(lamp: Dictionary) -> Vector2i: return OverworldMap.cell_of(lamp.at))
	assert_array(cells).contains_exactly([Vector2i(0, 0), Vector2i(1, 2), Vector2i(4, 0)])
	# From (2, 1), (0, 0) and (4, 0) are both three steps away: they keep reading order.
	var between := Lessons.lane_from(map, Vector2i(2, 1))
	cells = between.map(func(lamp: Dictionary) -> Vector2i: return OverworldMap.cell_of(lamp.at))
	assert_array(cells).contains_exactly([Vector2i(1, 2), Vector2i(0, 0), Vector2i(4, 0)])
	assert_array(Lessons.lane_from(_maps().home, Vector2i.ZERO)).is_empty()


func test_the_lane_names_come_from_the_map_in_reading_order() -> void:
	var names := Lessons.lane_names(_maps().lanternroot)
	assert_array(names).contains_exactly(["Moss", "North", "Ember"])
	assert_array(Lessons.lane(2, names)).is_equal([{"name": "Moss", "lit": false}, {"name": "North", "lit": false}])


# --- judging a save -----------------------------------------------------------------------------------------------


func _run(values: Array) -> Dictionary:
	var results: Array = []
	for value: Variant in values:
		results.append(value if value is Dictionary and value.has("kind") else {"ok": true, "value": value})
	return {"status": "ok", "results": results}


func test_a_save_passes_when_x_y_and_map_match_every_player() -> void:
	var players := Lessons.players("Mio")
	var kept: Array = players.map(func(p: Dictionary) -> Dictionary: return {"x": float(p.x), "y": p.y, "map": p.map})
	var checked := Lessons.check(Lessons.MEMORY, players, _run(kept))
	assert_bool(checked.ok).is_true()
	assert_array(checked.cases[0].kept).contains_exactly(["x", "y", "map"])
	assert_str(checked.cases[0].reason).is_equal("kept")


func test_a_save_says_what_went_wrong() -> void:
	var player := Lessons.player_at("home", Vector2i(2, 3), "down", "Mio")
	var reasons := {
		"nothing": null,
		"not-dict": [1, 2],
		"kept-nothing": {},
		"forgot": {"x": 2, "y": 3},
		"wrong": {"x": 2, "y": "3", "map": "home"},
	}
	for reason: String in reasons:
		var judged := Lessons.judge_save(player, {"ok": true, "value": reasons[reason]})
		assert_bool(judged.ok).is_false()
		assert_str(judged.reason).is_equal(reason)
	var forgot := Lessons.judge_save(player, {"ok": true, "value": {"name": "Mio"}})
	assert_array(forgot.missing).contains_exactly(["x", "y", "map"])
	var wrong := Lessons.judge_save(player, {"ok": true, "value": {"x": 2, "y": "3", "map": "home"}})
	assert_str(wrong.field).is_equal("y")
	assert_str(wrong.want).is_equal("3")
	assert_str(wrong.got).is_equal('"3"')
	var error := Lessons.judge_save(player, {"ok": false, "kind": "KeyError", "message": "'where'", "line": 2})
	assert_str(error.reason).is_equal("error")
	assert_int(error.line).is_equal(2)


func test_a_run_that_never_reached_the_cases_is_a_problem() -> void:
	var broken := {"status": "broken", "kind": "SyntaxError", "message": "invalid syntax", "line": 2, "results": []}
	var checked := Lessons.check(Lessons.MEMORY, Lessons.players(), broken)
	assert_bool(checked.ok).is_false()
	assert_str(checked.problem.reason).is_equal("broken")
	assert_int(checked.problem.line).is_equal(2)
	assert_str(Lessons.check(Lessons.LAMPS, Lessons.lanes(), {"status": "timeout"}).problem.reason).is_equal("timeout")
	assert_str(Lessons.check(Lessons.LAMPS, Lessons.lanes(), {"status": "odd"}).problem.reason).is_equal("failed")
	# A run that answered for fewer cases than it was given does not pass.
	assert_bool(Lessons.check(Lessons.LAMPS, Lessons.lanes(), _run([[]])).ok).is_false()


# --- judging a lane -----------------------------------------------------------------------------------------------


func test_a_lane_passes_when_every_lamp_is_lit_and_none_is_lost() -> void:
	var lamps := Lessons.lane(3)
	var lit: Array = lamps.map(func(l: Dictionary) -> Dictionary: return {"name": l.name, "lit": true})
	var judged := Lessons.judge_lane(lamps, {"ok": true, "value": lit})
	assert_bool(judged.ok).is_true()
	assert_int(judged.total).is_equal(3)
	assert_bool(Lessons.judge_lane([], {"ok": true, "value": []}).ok).is_true()


func test_a_lane_says_what_went_wrong() -> void:
	var lamps := Lessons.lane(3)
	var dark := Lessons.judge_lane(lamps, {"ok": true, "value": [_lamp("Moss", true), _lamp("Willow"), _lamp("Ember")]})
	assert_str(dark.reason).is_equal("dark")
	assert_int(dark.dark).is_equal(2)
	assert_int(dark.index).is_equal(1)
	var lost := Lessons.judge_lane(lamps, {"ok": true, "value": [_lamp("Moss", true)]})
	assert_str(lost.reason).is_equal("count")
	assert_int(lost.want).is_equal(3)
	var swapped := Lessons.judge_lane(lamps, {"ok": true, "value": [_lamp("Moss"), _lamp("Ember"), _lamp("Willow")]})
	assert_str(swapped.reason).is_equal("changed")
	assert_int(swapped.index).is_equal(1)
	var yes := Lessons.judge_lane([lamps[0]], {"ok": true, "value": [_lamp("Moss", 1.0)]})
	assert_str(yes.reason).is_equal("not-true")
	assert_str(yes.got).is_equal("1")
	assert_str(Lessons.judge_lane(lamps, {"ok": true, "value": "done"}).reason).is_equal("not-list")
	var error := Lessons.judge_lane([], {"ok": false, "kind": "IndexError", "message": "list index out of range"})
	assert_str(error.reason).is_equal("error")
	assert_bool(error.empty).is_true()


func test_advice_points_at_the_most_telling_mistake() -> void:
	var players := Lessons.players()
	var advise := func(id: String, values: Array) -> String:
		var given := players if id == Lessons.MEMORY else Lessons.lanes()
		return Lessons.advice(id, Lessons.check(id, given, _run(values)))
	var place := func(p: Dictionary) -> Dictionary: return {"x": p.x, "y": p.y}
	assert_str(advise.call(Lessons.MEMORY, players.map(place))).is_equal("forgot-map")
	assert_str(advise.call(Lessons.MEMORY, [{"name": "Mio"}, {}, {}])).is_equal("forgot")
	assert_str(advise.call(Lessons.MEMORY, [{}, {}, {}])).is_equal("empty")
	assert_str(advise.call(Lessons.MEMORY, [null, null, null])).is_equal("no-return")
	assert_str(advise.call(Lessons.MEMORY, players)).is_equal("passed")
	var oops := {"ok": false, "kind": "IndexError", "message": "list index out of range", "line": 2}
	var first_only: Array = [oops, [_lamp("Moss", true)], Lessons.lane(5).map(_first_lit)]
	assert_str(advise.call(Lessons.LAMPS, first_only)).is_equal("first-only")
	assert_str(advise.call(Lessons.LAMPS, [[], Lessons.lane(1), Lessons.lane(5)])).is_equal("all-dark")
	assert_str(advise.call(Lessons.LAMPS, [oops, [_lamp("Moss", true)], []])).is_equal("empty-lane")
	assert_str(advise.call(Lessons.LAMPS, [[], [], []])).is_equal("lost")
	var broken := {"status": "broken", "kind": "missing", "message": "there is no function save(player)"}
	assert_str(Lessons.advice(Lessons.MEMORY, Lessons.check(Lessons.MEMORY, players, broken))).is_equal("missing")
	assert_str(Lessons.advice(Lessons.LAMPS, Lessons.check(Lessons.LAMPS, [], {"status": "timeout"}))).is_equal(
		"timeout"
	)


func _first_lit(lamp: Dictionary) -> Dictionary:
	return {"name": lamp.name, "lit": lamp.name == Lessons.LAMP_NAMES[0]}


func _lamp(lamp_name: String, lit: Variant = false) -> Dictionary:
	return {"name": lamp_name, "lit": lit}


func test_values_are_shown_as_the_player_wrote_them() -> void:
	assert_str(Lessons.shown(3.0)).is_equal("3")
	assert_str(Lessons.shown(2.5)).is_equal("2.5")
	assert_str(Lessons.shown("home")).is_equal('"home"')
	assert_str(Lessons.shown(null)).is_equal("null")
	assert_str(Lessons.shown(true)).is_equal("true")
	assert_bool(Lessons.same(3, 3.0)).is_true()
	assert_bool(Lessons.same("3", 3)).is_false()


# --- restoring the player's place -----------------------------------------------------------------------------------


func test_before_lesson_two_the_place_is_kept_for_the_player() -> void:
	var state := _state({}, {"map": "home", "x": 0, "y": 0})
	var restored := Lessons.restore(state, _maps(), "home")
	assert_dict(restored.state).is_equal(state)
	assert_str(restored.note).is_equal("")


func test_after_lesson_two_the_place_is_what_the_save_kept() -> void:
	var state := _state({"memory-written": true}, {"map": "lanternroot", "x": 2.0, "y": 1.0, "facing": "up"})
	var restored := Lessons.restore(state, _maps(), "home")
	assert_str(restored.note).is_equal("")
	assert_str(restored.state.map).is_equal("lanternroot")
	assert_that(OverworldState.cell(restored.state)).is_equal(Vector2i(2, 1))
	assert_str(restored.state.facing).is_equal("up")


func test_a_save_without_facing_keeps_the_way_the_player_faced() -> void:
	var state := _state({"memory-written": true}, {"map": "lanternroot", "x": 2, "y": 1})
	assert_str(Lessons.restore(state, _maps(), "home").state.facing).is_equal("left")


func test_a_save_that_forgot_something_wakes_the_player_at_home() -> void:
	var notes := {
		"no-memory": null,
		"forgot-map": {"x": 2, "y": 1},
		"unknown-map": {"map": "moon", "x": 2, "y": 1},
		"forgot-place": {"map": "lanternroot", "x": 2},
		"outside": {"map": "lanternroot", "x": 9, "y": 1},
		"blocked": {"map": "lanternroot", "x": 4, "y": 1},
	}
	for note: String in notes:
		var restored := Lessons.restore(_state({"memory-written": true}, notes[note]), _maps(), "home")
		assert_str(restored.note).override_failure_message(note).is_equal(note)
		assert_str(restored.state.map).is_equal("home")
		assert_that(OverworldState.cell(restored.state)).is_equal(Vector2i(2, 1))
		assert_str(restored.state.facing).is_equal("up")


func test_a_save_on_a_sign_or_a_townsperson_is_blocked() -> void:
	for cell: Array in [[5, 0], [3, 2], [4, 0]]:
		var memory := {"map": "lanternroot", "x": cell[0], "y": cell[1]}
		assert_str(Lessons.restore(_state({"memory-written": true}, memory), _maps(), "home").note).is_equal("blocked")
	var half := {"map": "lanternroot", "x": 1.5, "y": 1}
	assert_str(Lessons.restore(_state({"memory-written": true}, half), _maps(), "home").note).is_equal("forgot-place")


func test_a_save_on_an_open_gate_is_restored_and_on_a_shut_one_it_is_not() -> void:
	var maps := _gate_maps()
	var on_gate := {"map": "lanternroot", "x": 3, "y": 1, "facing": "up"}
	var open_state := _state({"memory-written": true}, on_gate)
	open_state.things = {"cabbage-gate": {"fields": {"open": true}}}
	var restored := Lessons.restore(open_state, maps, "home")
	assert_str(restored.note).is_equal("")
	assert_str(restored.state.map).is_equal("lanternroot")
	assert_that(OverworldState.cell(restored.state)).is_equal(Vector2i(3, 1))
	var woken := Lessons.restore(_state({"memory-written": true}, on_gate), maps, "home")
	assert_str(woken.note).is_equal("blocked")
	assert_str(woken.state.map).is_equal("home")


# --- the lesson's record --------------------------------------------------------------------------------------------


func test_a_record_is_filled_in_and_replaced_whole() -> void:
	var state := _state({})
	var fresh := Lessons.record(state, Lessons.LAMPS)
	assert_that(fresh.blocks).is_equal(Lessons.fresh_blocks(Lessons.LAMPS))
	assert_dict(fresh.code).is_empty()
	assert_bool(fresh.passed).is_false()
	fresh.passed = true
	fresh.source = "def light_all(lamps): pass\n"
	var kept := Lessons.with_record(state, Lessons.LAMPS, fresh)
	assert_bool(Lessons.record(kept, Lessons.LAMPS).passed).is_true()
	assert_dict(Lessons.record(kept, Lessons.MEMORY)).contains_key_value("blocks", [])
	assert_bool(state.has("lessons")).is_false()


func test_flags_are_added_and_the_player_is_read_from_the_state() -> void:
	var state := Lessons.with_flags(_state({"woke": true}), ["memory-written", "saved-once"])
	assert_dict(state.flags).is_equal({"woke": true, "memory-written": true, "saved-once": true})
	state.name = "Mio"
	assert_dict(Lessons.player_of(state)).is_equal(
		{"x": 1, "y": 1, "map": "lanternroot", "facing": "left", "name": "Mio"}
	)
