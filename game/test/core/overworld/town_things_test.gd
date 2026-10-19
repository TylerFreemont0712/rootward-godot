extends GdUnitTestSuite
## Things that take code (ADR-0061, TownThings): what one use may change and what it may not, judged from the answers a
## run gives. The sandbox's side (what the code really returns) is in test/sandbox/thing_run_test.gd.

## A gate with three declared fields: a bool, a whole number from 0 to 9 and a text of up to 60 characters. It may raise
## one flag.
const GATE := {
	"kind": "prop",
	"id": "root-gate",
	"solid_unless": "open",
	"at": [4, 1],
	"size": [2, 1],
	"program":
	{
		"hook": "on_use",
		"fields":
		{
			"open": {"type": "bool", "default": false},
			"level": {"type": "whole", "min": 0, "max": 9, "default": 2},
			"note": {"type": "text", "default": "shut"},
		},
		"raises": ["gate-open"],
	},
}

## A small town: a wall on (2, 0), and the gate on (4, 1) and (5, 1).
const TERRAIN := {"grass": {"walk": true}, "wall": {"walk": false}}
const TOWN := {
	"id": "test-town",
	"legend": {".": "grass", "#": "wall"},
	"ground": ["..#...", "......", "......"],
	"start": [0, 0],
	"objects": [GATE],
}


## What ThingRun gives back when the code ran to the end and returned `value`.
func _ran(value: Variant) -> Dictionary:
	return {"status": "ok", "ok": true, "value": value, "kind": "", "message": "", "line": 0, "printed": ""}


func _map() -> Dictionary:
	var built := OverworldMap.build(TOWN, TERRAIN)
	assert_array(built.errors).is_empty()
	return built.map


func test_fields_are_the_defaults_until_something_is_saved() -> void:
	assert_dict(TownThings.fields_of(GATE, {})).is_equal({"open": false, "level": 2, "note": "shut"})


func test_saved_values_overlay_the_defaults_and_undeclared_names_are_left_out() -> void:
	var fields := TownThings.fields_of(GATE, {"open": true, "level": 7, "note": "ajar", "gone": 1})
	assert_dict(fields).is_equal({"open": true, "level": 7, "note": "ajar"})


func test_a_saved_value_that_no_longer_fits_falls_back_to_the_default() -> void:
	var fields := TownThings.fields_of(GATE, {"open": 1, "level": 12, "note": "x".repeat(61)})
	assert_dict(fields).is_equal({"open": false, "level": 2, "note": "shut"})


func test_a_thing_without_a_program_has_no_fields() -> void:
	assert_dict(TownThings.fields_of({"kind": "sign", "text": "Hi"}, {"open": true})).is_empty()


func test_the_request_carries_the_declared_fields_the_keys_the_text_and_the_player_only() -> void:
	var player := {"x": 4, "y": 1, "map": "test-town", "facing": "right", "name": "Tinker", "flags": {"a": true}}
	var keys: Array[String] = ["right", "up"]
	var args := TownThings.use_input(
		GATE, {"open": true, "level": 2, "note": "x", "secret": 1}, player, keys, "A gate."
	)
	assert_dict(args.thing).is_equal(
		{
			"id": "root-gate",
			"fields": {"open": true, "level": 2, "note": "x"},
			"keys": ["right", "up"],
			"text": "A gate."
		}
	)
	assert_dict(args.player).is_equal({"x": 4, "y": 1, "map": "test-town", "facing": "right", "name": "Tinker"})


func test_a_plain_answer_sets_its_field_and_says_its_words() -> void:
	var verdict := TownThings.judge_use(GATE, _ran({"set": {"open": true}, "say": "The gate creaks open."}), false)
	assert_bool(verdict.ok).is_true()
	assert_str(verdict.reason).is_equal("")
	assert_dict(verdict.changes).is_equal({"open": true})
	assert_str(verdict.say).is_equal("The gate creaks open.")
	assert_array(verdict.dropped).is_empty()
	assert_array(verdict.raised).is_empty()


func test_extra_keys_are_dropped_and_named() -> void:
	var answer := {"set": {"open": true}, "x": 99, "player": {"x": 99}, "things": {}, "flags": {"gate-open": true}}
	var verdict := TownThings.judge_use(GATE, _ran(answer), false)
	assert_dict(verdict.changes).is_equal({"open": true})
	assert_array(verdict.dropped).contains_exactly_in_any_order(["x", "player", "things", "flags"])


func test_a_set_of_a_field_the_thing_does_not_declare_is_dropped() -> void:
	var verdict := TownThings.judge_use(GATE, _ran({"set": {"name": "x", "x": 3, "open": true}}), false)
	assert_dict(verdict.changes).is_equal({"open": true})
	assert_array(verdict.dropped).contains_exactly_in_any_order(["name", "x"])


func test_a_value_of_the_wrong_type_or_out_of_bounds_is_dropped() -> void:
	var verdict := TownThings.judge_use(GATE, _ran({"set": {"open": 1, "level": 12, "note": "x".repeat(61)}}), false)
	assert_dict(verdict.changes).is_empty()
	assert_array(verdict.dropped).contains_exactly_in_any_order(["open", "level", "note"])


func test_a_whole_number_must_be_whole_within_its_bounds_and_not_a_bool() -> void:
	var whole := TownThings.judge_use(GATE, _ran({"set": {"level": 9.0}}), false)
	assert_dict(whole.changes).is_equal({"level": 9})
	assert_int(int(whole.changes["level"])).is_equal(9)
	for value: Variant in [10, -1, 2.5, true]:
		var refused := TownThings.judge_use(GATE, _ran({"set": {"level": value}}), false)
		assert_array(refused.dropped).override_failure_message("%s" % [value]).contains_exactly(["level"])


func test_text_is_kept_up_to_sixty_characters() -> void:
	var fits := TownThings.judge_use(GATE, _ran({"set": {"note": "x".repeat(60)}}), false)
	assert_str(String(fits.changes["note"])).has_length(60)
	var too_long := TownThings.judge_use(GATE, _ran({"set": {"note": "x".repeat(61)}}), false)
	assert_array(too_long.dropped).contains_exactly(["note"])


func test_say_is_cut_to_a_hundred_and_twenty_characters() -> void:
	var verdict := TownThings.judge_use(GATE, _ran({"say": "a".repeat(200)}), false)
	assert_bool(verdict.ok).is_true()
	assert_str(verdict.say).has_length(120)


func test_words_that_are_not_text_are_dropped_and_say_nothing() -> void:
	var verdict := TownThings.judge_use(GATE, _ran({"say": 5}), false)
	assert_bool(verdict.ok).is_true()
	assert_str(verdict.say).is_empty()
	assert_array(verdict.dropped).contains_exactly(["say"])


func test_raises_keeps_only_the_flags_the_program_lists_once_each() -> void:
	var verdict := TownThings.judge_use(GATE, _ran({"raises": ["gate-open", "other", "gate-open"]}), false)
	assert_array(verdict.raised).contains_exactly(["gate-open"])
	assert_array(verdict.dropped).contains_exactly(["other"])


func test_nothing_given_back_is_a_quiet_answer_that_changes_nothing() -> void:
	var verdict := TownThings.judge_use(GATE, _ran(null), false)
	assert_bool(verdict.ok).is_true()
	assert_dict(verdict.changes).is_empty()
	assert_str(verdict.say).is_empty()


func test_an_answer_that_is_not_a_dictionary_is_refused() -> void:
	for value: Variant in [5, "The gate says hi.", [1, 2]]:
		var verdict := TownThings.judge_use(GATE, _ran(value), false)
		assert_bool(verdict.ok).override_failure_message("%s" % [value]).is_false()
		assert_str(verdict.reason).is_equal("not-dict")
		assert_dict(verdict.changes).is_empty()


func test_a_run_that_failed_gives_its_reason_and_its_line() -> void:
	var broken := {"status": "broken", "ok": false, "value": null, "kind": "SyntaxError", "line": 2, "printed": ""}
	var verdict := TownThings.judge_use(GATE, broken, false)
	assert_bool(verdict.ok).is_false()
	assert_str(verdict.reason).is_equal("broken")
	assert_int(verdict.line).is_equal(2)
	for status: String in ["timeout", "oom", "failed"]:
		var failed := {"status": status, "ok": false, "value": null, "kind": "", "line": 0, "printed": ""}
		assert_str(TownThings.judge_use(GATE, failed, false).reason).is_equal(status)
	var raised := {"status": "ok", "ok": false, "value": null, "kind": "NameError", "line": 3, "printed": ""}
	var error := TownThings.judge_use(GATE, raised, false)
	assert_str(error.reason).is_equal("error")
	assert_int(error.line).is_equal(3)
	assert_dict(error.changes).is_empty()


func test_a_closure_under_the_player_is_refused_and_nothing_else_is() -> void:
	var closing := _ran({"set": {"open": false}, "say": "The gate shuts."})
	var refused := TownThings.judge_use(GATE, closing, true)
	assert_bool(refused.ok).is_false()
	assert_str(refused.reason).is_equal("occupied")
	assert_dict(refused.changes).is_empty()
	assert_str(refused.say).is_empty()
	assert_bool(TownThings.judge_use(GATE, closing, false).ok).is_true()
	assert_dict(TownThings.judge_use(GATE, _ran({"set": {"open": true}}), true).changes).is_equal({"open": true})


func test_with_changes_writes_one_thing_and_leaves_the_rest_and_the_input() -> void:
	var state := {
		"flags": {"x": true},
		"things": {"root-gate": {"fields": {"level": 5}}, "sign": {"fields": {"level": 3}}},
	}
	var out := TownThings.with_changes(state, "root-gate", {"open": true})
	assert_dict(out.things["root-gate"]["fields"]).is_equal({"level": 5, "open": true})
	assert_dict(out.things["sign"]).is_equal({"fields": {"level": 3}})
	assert_dict(out.flags).is_equal({"x": true})
	assert_dict(state.things["root-gate"]["fields"]).is_equal({"level": 5})


func test_with_changes_makes_the_things_entry_when_there_is_none() -> void:
	var out := TownThings.with_changes({}, "root-gate", {"open": true})
	assert_dict(out.things).is_equal({"root-gate": {"fields": {"open": true}}})


func test_open_cells_are_the_footprint_of_a_thing_that_is_open() -> void:
	var map := _map()
	assert_dict(TownThings.open_cells(map, {})).is_empty()
	assert_dict(TownThings.open_cells(map, {"root-gate": {"fields": {"open": false}}})).is_empty()
	var open := TownThings.open_cells(map, {"root-gate": {"fields": {"open": true}}})
	assert_dict(open).is_equal({Vector2i(4, 1): true, Vector2i(5, 1): true})


func test_blocked_lets_an_open_gate_through_and_keeps_walls_people_and_the_edge() -> void:
	var map := _map()
	var open := TownThings.open_cells(map, {"root-gate": {"fields": {"open": true}}})
	assert_bool(TownThings.blocked(map, Vector2i(4, 1))).is_true()
	assert_bool(TownThings.blocked(map, Vector2i(4, 1), {}, open)).is_false()
	assert_bool(TownThings.blocked(map, Vector2i(5, 1), {}, open)).is_false()
	assert_bool(TownThings.blocked(map, Vector2i(2, 0), {}, open)).is_true()
	assert_bool(TownThings.blocked(map, Vector2i(4, 1), {Vector2i(4, 1): true}, open)).is_true()
	assert_bool(TownThings.blocked(map, Vector2i(9, 9), {}, open)).is_true()


func test_a_good_program_has_no_problems_and_a_sign_needs_none() -> void:
	assert_array(TownThings.problems([GATE, {"kind": "sign", "at": [0, 0], "text": "Hi"}])).is_empty()


func test_two_things_with_one_id_are_a_problem() -> void:
	var found := TownThings.problems([GATE, GATE])
	assert_array(found).contains_exactly(["two things are called root-gate"])


func test_only_a_prop_can_run_code() -> void:
	var building := {"kind": "building", "id": "hall", "program": GATE.program}
	var found := TownThings.problems([building])
	assert_str(String(found[0])).contains("only a prop can run code")


func test_solid_unless_needs_a_program_and_a_bool_field() -> void:
	var bare := {"kind": "prop", "id": "stone", "solid_unless": "open"}
	assert_str(String(TownThings.problems([bare])[0])).contains("no program")
	var no_field := {"kind": "prop", "id": "stone", "solid_unless": "open", "program": {"hook": "on_use"}}
	assert_str(String(TownThings.problems([no_field])[0])).contains("not a bool field")


func test_a_field_must_have_a_known_type_bounds_and_a_fitting_default() -> void:
	var program := {"hook": "on_use", "fields": {}, "raises": []}
	var kinds := {"type": "float", "default": 1}
	var bounds := {"type": "whole", "default": 1}
	var upside_down := {"type": "whole", "min": 5, "max": 1, "default": 3}
	var bad_bool := {"type": "bool", "default": 1}
	var no_default := {"type": "bool"}
	var pick := {"kind": "prop", "id": "pick", "program": program}
	for field: Dictionary in [kinds, bounds, upside_down, bad_bool, no_default]:
		program.fields = {"f": field}
		assert_array(TownThings.problems([pick])).override_failure_message(str(field)).is_not_empty()
	program.fields = {"f": {"type": "whole", "min": 0, "max": 3, "default": 2}}
	assert_array(TownThings.problems([pick])).is_empty()


func test_the_hook_must_be_one_of_the_three_and_raises_must_be_names() -> void:
	var wrong_hook := {"kind": "prop", "id": "a", "program": {"hook": "on_jump", "fields": {}, "raises": []}}
	assert_str(String(TownThings.problems([wrong_hook])[0])).contains("on_use, on_step, on_change")
	for hook: String in TownThings.HOOKS:
		var right := {"kind": "prop", "id": "a", "program": {"hook": hook, "fields": {}, "raises": []}}
		assert_array(TownThings.problems([right])).override_failure_message(hook).is_empty()
	var bad_raises := {"kind": "prop", "id": "b", "program": {"hook": "on_use", "fields": {}, "raises": "gate"}}
	assert_str(String(TownThings.problems([bad_raises])[0])).contains("raises")


# --- unlocks (Studio S8) ----------------------------------------------------------------------------------------------


func _locked(condition: Variant) -> Dictionary:
	var thing: Dictionary = GATE.duplicate(true)
	thing.program["unlocked_by"] = condition
	return thing


func test_a_thing_without_unlocked_by_is_always_unlocked() -> void:
	assert_bool(TownThings.unlocked(GATE, {})).is_true()
	assert_bool(TownThings.unlocked({"kind": "prop", "art": "barrel"}, {})).is_true()


func test_a_thing_unlocks_when_its_condition_holds() -> void:
	var thing := _locked({"flag": "met-innkeeper"})
	assert_bool(TownThings.unlocked(thing, {})).is_false()
	assert_bool(TownThings.unlocked(thing, {"met-innkeeper": true})).is_true()
	var counted := _locked({"count": "met-", "at_least": 2})
	assert_bool(TownThings.unlocked(counted, {"met-a": true})).is_false()
	assert_bool(TownThings.unlocked(counted, {"met-a": true, "met-b": true})).is_true()


func test_an_unlocked_by_that_is_not_a_condition_is_a_problem() -> void:
	for bad: Variant in ["met-innkeeper", {}, {"all": "x"}, {"all": [{"what": 1}]}]:
		var problems := TownThings.problems([_locked(bad)])
		assert_bool(problems.any(func(text: String) -> bool: return text.contains("unlocked by something that is not a condition"))).override_failure_message(str(bad)).is_true()
	assert_array(TownThings.problems([_locked({"all": [{"flag": "a"}, {"not": "b"}]})])).is_empty()
