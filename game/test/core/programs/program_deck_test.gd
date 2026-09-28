extends GdUnitTestSuite
## A program run's deck in a fight (ADR-0018): keywords, imports that hold for the fight, cards that make cards, and
## the fight's globals, through the rules' own commands.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramCatalogs.without_initiative(ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog))


func _step(state: Dictionary, command: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	assert_bool(result.ok).override_failure_message(str(result.get("error", ""))).is_true()
	return result.state if result.ok else state


## A fight against one sturdy foe that only strikes, with plenty of mana, from a deck of `deck`.
func _fight(deck: Array) -> Dictionary:
	var options := {"seed": "deck-test", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state = _step(state, {"type": "pick-paradigm", "paradigm_id": state.draft.offers[0]})
	while state.status == "draft":
		state = _step(state, {"type": "draft-card", "card_id": state.draft.pack[0]})
	state.deck = deck.duplicate()
	var fights := ShardrunMap.next_rooms(state.map, state.position).filter(
		func(node: Dictionary) -> bool: return node.kind == "fight"
	)
	state = _step(state, {"type": "enter", "node_id": (fights[0] as Dictionary).id})
	var foe: Dictionary = state.battle.foes[0]
	foe.hp = 500
	foe.max = 500
	foe.erase("trait")
	foe.weak = []
	foe.resist = []
	foe.intents = [{"kind": "strike", "power": 1}]
	foe.intent_index = 0
	state.battle.foes = [foe]
	state.battle.mana = 9
	return state


## Moves `cards` from the fight's piles into the hand (a card already in the hand stays where it is).
func _hand(state: Dictionary, cards: Array) -> Dictionary:
	var battle: Dictionary = state.battle
	for id: String in cards:
		if id in battle.hand:
			continue
		for pile: String in ["draw", "discard"]:
			var at := (battle[pile] as Array).find(id)
			if at >= 0:
				(battle[pile] as Array).remove_at(at)
				break
		(battle.hand as Array).append(id)
	return state


func _cast(state: Dictionary, program: Array, bolts: Array) -> Dictionary:
	var table := CardTable.of(state, catalog)
	for id: String in program:
		(table.hand as Array).erase(id)
	table.spells[0].shards = program.duplicate()
	state = _step(state, CardTable.command(table))
	var steps := ProgramDeck.steps(program, catalog)
	var work: Array = steps.map(func(id: String) -> Dictionary: return {"shard": id, "given": 3, "returned": 3})
	var outcome := {"ok": true, "bolts": bolts, "work": work}
	return _step(state, {"type": "cast", "spell_id": state.spells[0].id, "outcome": outcome})


func test_a_once_card_is_gone_for_the_rest_of_the_fight() -> void:
	var state := _hand(_fight(["reduce", "salvo", "ward", "amplify", "fork", "kindle"]), ["reduce"])
	state = _cast(state, ["reduce"], [{"power": 5}])
	assert_array(state.battle.gone).contains(["reduce"])
	assert_array(state.battle.discard).not_contains(["reduce"])
	assert_array(state.battle.hand).not_contains(["reduce"])


func test_a_const_card_stays_in_the_hand_and_a_volatile_one_leaves_it() -> void:
	var deck := ["literal", "power-set", "salvo", "ward", "amplify", "fork", "kindle", "chill"]
	var state := _hand(_fight(deck), ["literal", "power-set"])
	state = _step(state, {"type": "end-turn"})
	assert_array(state.battle.hand).contains(["literal"])
	assert_array(state.battle.gone).contains(["power-set"])
	assert_array(state.battle.hand).not_contains(["power-set"])


func test_an_init_card_is_always_in_the_opening_hand() -> void:
	var deck := ["salvo", "ward", "amplify", "fork", "kindle", "chill", "charge", "sweep", "reverse", "global-total"]
	for seed in 5:
		var state := _fight(deck)
		assert_array(state.battle.hand).contains(["global-total"])


func test_an_import_holds_for_the_rest_of_the_fight() -> void:
	var deck := ["import-numpy", "amplify", "salvo", "ward", "fork", "kindle"]
	var state := _hand(_fight(deck), ["import-numpy", "amplify"])
	# Before it is imported, a shape card does linear work; written at the top of this program, it is O(1) already.
	var trace := [{"shard": "amplify", "given": 9, "returned": 9}]
	assert_int(ProgramRules.stages(state, trace, catalog)[0].work).is_equal(9)
	state = _cast(state, ["import-numpy", "amplify"], [{"power": 5}])
	assert_array(state.battle.imports).is_equal(["import-numpy"])
	assert_array(state.battle.discard).not_contains(["import-numpy"])
	assert_int(ProgramRules.stages(state, trace, catalog)[0].work).is_equal(1)
	assert_array(ProgramDeck.modules(state, catalog)).is_equal(["numpy"])


func test_itertools_makes_brute_force_cheaper() -> void:
	var state := _fight(["pairwise", "import-itertools", "salvo", "ward"])
	var before := ProgramRelics.cost(state, ["pairwise"], catalog)
	state.battle.imports = ["import-itertools"]
	assert_int(ProgramRelics.cost(state, ["pairwise"], catalog)).is_equal(before - 1)


func test_a_global_counts_the_damage_landed_and_release_spends_it() -> void:
	var deck := ["global-total", "salvo", "release", "ward", "amplify", "fork", "kindle"]
	var state := _hand(_fight(deck), ["global-total", "salvo"])
	state = _cast(state, ["global-total", "salvo"], [{"power": 12}, {"power": 8}])
	assert_int(int(state.battle.globals.total)).is_equal(20)
	state = _hand(state, ["release"])
	state = _cast(state, ["release"], [{"power": 10}])
	# Release's own program counts first, then the total starts again.
	assert_int(int(state.battle.globals.total)).is_equal(0)


func test_higher_order_writes_two_lambdas_for_the_next_turn() -> void:
	var deck := ["higher-order", "salvo", "ward", "amplify", "fork", "kindle", "chill", "charge"]
	var state := _hand(_fight(deck), ["higher-order"])
	state = _cast(state, ["higher-order"], [{"power": 4}])
	var lambdas := (state.battle.hand as Array).filter(func(id: String) -> bool: return id == "lambda")
	assert_int(lambdas.size()).is_equal(2)
	# A lambda costs nothing and runs once.
	state = _cast(state, ["lambda"], [{"power": 6}])
	assert_array(state.battle.gone).contains(["lambda"])


func test_imports_are_lines_not_steps() -> void:
	assert_array(ProgramDeck.steps(["import-heapq", "salvo", "round-robin"], catalog)).is_equal(
		["salvo", "round-robin"]
	)
	assert_str(ProgramRules.speed_label(["import-heapq", "salvo"], catalog)).is_equal("O(n)")
	var lines := ProgramSource.lines("python", ["import-heapq", "salvo"], catalog, [], ["import-heapq"])
	assert_str(String(lines[0].text)).is_equal("import heapq")
	var calls := lines.filter(func(line: Dictionary) -> bool: return line.kind == "call")
	assert_int(calls.size()).is_equal(1)
	assert_int(int(calls[0].slot)).is_equal(0)


func test_hooks_change_the_order_the_lint_sees() -> void:
	# bisect sorts what every source makes, so Binary Execute needs no Merge Sort after Salvo.
	var bisect := [{"card": "import-bisect", "when": "after", "role": "source"}]
	assert_array(ProgramRules.lint(["salvo", "binary-execute"], catalog)).is_not_empty()
	assert_array(ProgramRules.lint(["salvo", "binary-execute"], catalog, bisect)).is_empty()
	# heapq hands every strike the strongest bolt first: a sorted volley is not sorted by the time Binary Execute runs.
	var heapq := [{"card": "import-heapq", "when": "before", "role": "strike"}]
	var warned := ProgramRules.lint(["salvo", "merge-sort", "binary-execute"], catalog, heapq)
	assert_int(warned.size()).is_equal(1)
	assert_str(String(warned[0].message)).contains("import heapq")
