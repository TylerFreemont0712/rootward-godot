extends GdUnitTestSuite
## The program tag through the C++ harness (docs/LEGENDARY_LOOKS.md): a program run's bolts carry the card that returned
## them and that card's role, as program_tags_test.gd checks for Python and JavaScript. C++ cards are built ahead of
## time (scripts/build-cpp.sh), so every test first asks for that build. A test cannot give a built card new code, so
## forged bolts stand in for what a card might write, and the real import import-heapq stands in for a hook.

var cards: Dictionary


func before() -> void:
	cards = ContentLoader.load_shardrun().catalog.programs.cards


func _program(ids: Array) -> Dictionary:
	var list: Array[Dictionary] = []
	for id: String in ids:
		list.append(cards[id])
	return {"id": "p", "shards": list}


## A program run's input as the program path sends it (app/spell_runs.gd input_for): counted, with execution rules when
## `executed`. One foe, so knapsack-strike has something to aim at.
func _run_input(counted: bool, executed: bool) -> Dictionary:
	var foe := {"name": "A", "hp": 12, "max": 12, "shield": 0, "weak": [], "resist": []}
	var input := {
		"bolts": [{"power": 3, "element": "none"}, {"power": 4, "element": "fire"}, {"power": 9, "element": "none"}],
		"battle": {"turn": 1, "me": {"hp": 30, "max": 30, "block": 0, "mana": 5}, "foes": [foe], "imports": ["math"]},
		"limit": 64,
		"trace_limit": 8,
		"count": counted,
		"module": "program",
	}
	if executed:
		input.execution = {}
	return input


## The same program run with import-heapq hooked around every strike card, before or after it.
func _hooked_input(when: String) -> Dictionary:
	var input := _run_input(true, true)
	input.hooks = [{"card": cards["import-heapq"], "when": when, "role": "strike"}]
	return input


func _without_tags(bolts: Array) -> Array:
	var out: Array = []
	for bolt: Dictionary in bolts:
		var plain := bolt.duplicate()
		plain.erase("card")
		plain.erase("role")
		out.append(plain)
	return out


## Each bolt as "card/role", so two harnesses can be compared without comparing the order of their keys.
func _tags(bolts: Array) -> Array:
	return bolts.map(func(bolt: Dictionary) -> String: return "%s/%s" % [bolt.get("card", "-"), bolt.get("role", "-")])


func _powers(bolts: Array) -> Array:
	return bolts.map(func(bolt: Dictionary) -> int: return int(bolt.power))


## The tags of the run's final volley, then of the volley after each step of its trace.
func _tags_by_step(run: Dictionary) -> Array:
	var steps: Array = [_tags(run.bolts)]
	for step: Dictionary in run.trace:
		steps.append(_tags(step.bolts))
	return steps


func test_a_cpp_program_run_stamps_each_bolt_with_the_card_that_returned_it() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["amplify", "divide", "knapsack-strike"])]
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_bool((run.bolts as Array).is_empty()).is_false()
	for bolt: Dictionary in run.bolts:
		assert_str(bolt.card).is_equal("knapsack-strike")
		assert_str(bolt.role).is_equal(cards["knapsack-strike"].role)
		# The card's own fields survive the stamp: knapsack-strike aimed every bolt at the foe.
		assert_bool(bolt.has("foe")).is_true()


func test_each_step_of_the_cpp_trace_names_the_card_that_produced_its_bolts() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["amplify", "divide"])]
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_str(run.trace[0].shard).is_equal("amplify")
	assert_int((run.trace[0].bolts as Array).size()).is_equal(3)
	for bolt: Dictionary in run.trace[0].bolts:
		assert_str(bolt.card).is_equal("amplify")
		assert_str(bolt.role).is_equal(cards.amplify.role)
	for bolt: Dictionary in run.trace[1].bolts:
		assert_str(bolt.card).is_equal("divide")


func test_counting_alone_stamps_nothing_in_cpp() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["amplify"])]
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, false)).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_int((run.bolts as Array).size()).is_equal(3)
	for bolt: Dictionary in run.bolts:
		assert_bool(bolt.has("card")).is_false()
		assert_bool(bolt.has("role")).is_false()


func test_a_stamped_cpp_run_returns_the_bolts_an_unstamped_one_does() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["amplify", "divide", "knapsack-strike"])]
	var stamped: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	var plain: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, false)).p
	assert_bool(stamped.ok).override_failure_message(str(stamped.get("reason"))).is_true()
	assert_bool(plain.ok).override_failure_message(str(plain.get("reason"))).is_true()
	assert_str(JsJson.stringify(_without_tags(stamped.bolts))).is_equal(JsJson.stringify(plain.bolts))


func test_a_bolt_that_no_card_returned_keeps_no_tags_in_cpp() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [{"id": "p", "shards": []}]
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_int((run.bolts as Array).size()).is_equal(3)
	for bolt: Dictionary in run.bolts:
		assert_bool(bolt.has("card")).is_false()
		assert_bool(bolt.has("role")).is_false()


# LEARN: a test cannot give a built C++ card new code, so a bolt that arrives with a card and a role of its own stands
# in for one a card returned. The stamp must replace both, whichever card they came from.
func test_the_stamp_replaces_a_card_and_role_a_bolt_arrived_with() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var input := _run_input(true, true)
	input.bolts = [{"power": 3, "element": "none", "card": "forged", "role": "guard"}]
	var spells: Array[Dictionary] = [_program(["amplify"])]
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, input).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_int((run.bolts as Array).size()).is_equal(1)
	assert_str(run.bolts[0].card).is_equal("amplify")
	assert_str(run.bolts[0].role).is_equal(cards.amplify.role)


## A bolt that arrives already naming this card still takes the card's role: the stamp replaces each key, not just the
## ones that differ from the card's.
func test_a_bolt_that_already_names_its_card_gets_the_cards_role() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var input := _run_input(true, true)
	input.bolts = [{"power": 3, "element": "none", "card": "amplify", "role": "forged"}]
	var spells: Array[Dictionary] = [_program(["amplify"])]
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, input).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_int((run.bolts as Array).size()).is_equal(1)
	assert_str(run.bolts[0].card).is_equal("amplify")
	assert_str(run.bolts[0].role).is_equal(cards.amplify.role)


func test_cpp_and_python_stamp_the_same_card_and_role_on_each_bolt() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["amplify", "divide", "knapsack-strike"])]
	var cpp: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	var python: Dictionary = SpellHarness.run(SandboxJob.PYTHON, spells, _run_input(true, true)).p
	assert_bool(cpp.ok).override_failure_message("cpp: %s" % str(cpp.get("reason"))).is_true()
	assert_bool(python.ok).override_failure_message("python: %s" % str(python.get("reason"))).is_true()
	assert_array(_tags(cpp.bolts)).is_equal(_tags(python.bolts))


func test_cpp_and_javascript_stamp_the_same_card_and_role_on_every_step() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["amplify", "divide", "knapsack-strike"])]
	var cpp: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	var javascript: Dictionary = SpellHarness.run(SandboxJob.JAVASCRIPT, spells, _run_input(true, true)).p
	assert_bool(cpp.ok).override_failure_message("cpp: %s" % str(cpp.get("reason"))).is_true()
	assert_bool(javascript.ok).override_failure_message("javascript: %s" % str(javascript.get("reason"))).is_true()
	assert_array(_tags_by_step(cpp)).is_equal(_tags_by_step(javascript))


func test_a_body_split_stamps_the_bolts_its_body_card_returns() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	# Reverse splits the volley, and reduce runs as its body on each half (as program_execution_test.gd sets it up).
	var reverse: Dictionary = cards.reverse.duplicate(true)
	reverse.splits = true
	var spells: Array[Dictionary] = [{"id": "p", "shards": [reverse, cards.reduce]}]
	var input := _run_input(true, false)
	input.execution = {"body": {"kind": "split", "depth": 1}}
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, input).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_bool((run.bolts as Array).is_empty()).is_false()
	for bolt: Dictionary in run.bolts:
		assert_str(bolt.card).is_equal("reduce")
		assert_str(bolt.role).is_equal(cards.reduce.role)


## import-heapq hands a volley back strongest first. Hooked around knapsack-strike, before or after it, it turns the
## unhooked volley [3, 4, 9] into [9, 4, 3], and every bolt it hands back keeps the strike card's tags.
func test_an_import_hooked_around_a_strike_card_keeps_the_strike_cards_tags() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["knapsack-strike"])]
	var plain: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	assert_array(_powers(plain.bolts)).is_equal([3, 4, 9])
	for when: String in ["before", "after"]:
		var hooked_run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _hooked_input(when)).p
		assert_bool(hooked_run.ok).override_failure_message("%s: %s" % [when, hooked_run.get("reason")]).is_true()
		assert_array(_powers(hooked_run.bolts)).override_failure_message(when).is_equal([9, 4, 3])
		for bolt: Dictionary in hooked_run.bolts:
			assert_str(bolt.card).override_failure_message(when).is_equal("knapsack-strike")
			assert_str(bolt.role).override_failure_message(when).is_equal("strike")


func test_cpp_and_python_agree_on_a_volley_an_import_hands_back() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var spells: Array[Dictionary] = [_program(["knapsack-strike"])]
	for when: String in ["before", "after"]:
		var cpp: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _hooked_input(when)).p
		var python: Dictionary = SpellHarness.run(SandboxJob.PYTHON, spells, _hooked_input(when)).p
		assert_bool(cpp.ok).override_failure_message("%s cpp: %s" % [when, cpp.get("reason")]).is_true()
		assert_bool(python.ok).override_failure_message("%s python: %s" % [when, python.get("reason")]).is_true()
		assert_array(_powers(cpp.bolts)).override_failure_message(when).is_equal(_powers(python.bolts))
		assert_array(_tags(cpp.bolts)).override_failure_message(when).is_equal(_tags(python.bolts))


## A Mutator's mutant is the card it was made from: its bolts carry the card's id and role, not the mutant's name.
func test_a_mutant_stamps_the_card_it_was_made_from() -> void:
	assert_bool(Sandbox.is_available(SandboxJob.CPP)).override_failure_message("run scripts/build-cpp.sh").is_true()
	var shard: Dictionary = cards.dedupe.duplicate(true)
	shard.mutant = 14
	var spells: Array[Dictionary] = [{"id": "p", "shards": [shard]}]
	var run: Dictionary = SpellHarness.run(SandboxJob.CPP, spells, _run_input(true, true)).p
	assert_bool(run.ok).override_failure_message(str(run.get("reason"))).is_true()
	assert_bool((run.bolts as Array).is_empty()).is_false()
	for bolt: Dictionary in run.bolts:
		assert_str(bolt.card).is_equal("dedupe")
		assert_str(bolt.role).is_equal(cards.dedupe.role)
