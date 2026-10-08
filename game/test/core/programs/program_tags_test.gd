extends GdUnitTestSuite
## The program tag (docs/LEGENDARY_LOOKS.md): a program bolt carries the card that cast it and that card's role.
## normalize checks both (a role must be one of ProgramSchemas.ROLES, a card a card id, else ""), the tags survive the
## landing and reach every hit (an overflow too), and they come from the bolt, never from its index. A bolt with no tag,
## a relic's, has both tags as "" on its hits.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramCatalogs.without_initiative(ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog))


func _fight(effects: Array = []) -> Dictionary:
	catalog = catalog.duplicate(true)
	catalog.relics["test-tags"] = {"effects": effects}
	var state := Shardrun.start(
		catalog, {"seed": "tags", "playstyle": "program", "language": "javascript", "difficulty": "beginner"}
	)
	state.relics = ["test-tags"]
	var foes := ShardrunBattle.foe_states(state, ["race-condition-imp", "tally-wisp"], "tags", catalog)
	for foe: Dictionary in foes:
		foe.hp = 20
		foe.max = 20
		foe.shield = 0
		foe.weak = []
		foe.resist = []
		foe.erase("trait")
		foe.intents = [{"kind": "strike", "power": 1, "tempo": 10000}]
	ShardrunBattle.start_with(state, "fight", foes, catalog)
	state.battle.mana = 20
	state.spells[0].shards = ["amplify"]
	return state


func _play(state: Dictionary, bolts: Array) -> void:
	ProgramRules.play(state, state.battle, state.spells[0], {"ok": true, "bolts": bolts, "work": []}, catalog, true)


func _hits(state: Dictionary) -> Array:
	return (state.log as Array).filter(func(entry: Dictionary) -> bool: return entry.kind == "hit")


func test_normalize_keeps_a_valid_card_and_role_and_empties_the_rest() -> void:
	var raw := [
		{"power": 3, "card": "amplify", "role": "shape"},
		{"power": 4, "card": 7, "role": "bogus"},
		{"power": 5, "card": "", "role": ""},
		{"power": 6},
		{"power": 7, "card": "Knapsack-Strike", "role": "Strike"},
	]
	var expected := [
		{"power": 3, "element": "none", "card": "amplify", "role": "shape"},
		{"power": 4, "element": "none", "card": "", "role": ""},
		{"power": 5, "element": "none", "card": "", "role": ""},
		{"power": 6, "element": "none"},
		{"power": 7, "element": "none", "card": "", "role": ""},
	]
	assert_array(ProgramRules.normalize(raw, catalog)).is_equal(expected)


func test_a_card_id_is_lower_case_letters_digits_and_hyphens() -> void:
	for card: String in ["amplify", "b-tree-plus", "import-heapq-2"]:
		assert_str(ProgramRules.card_tag(card)).is_equal(card)
	for card: String in ["Amplify", "a_b", "a.b", "a b", "a/b", "amplify\n", ""]:
		assert_str(ProgramRules.card_tag(card)).override_failure_message(card).is_equal("")
	assert_str(ProgramRules.card_tag(7)).is_equal("")
	assert_str(ProgramRules.card_tag(null)).is_equal("")


func test_a_role_is_one_of_the_seven_roles_and_nothing_else() -> void:
	assert_int(ProgramSchemas.ROLES.size()).is_equal(7)
	for role: String in ProgramSchemas.ROLES:
		assert_str(ProgramRules.role_tag(role)).is_equal(role)
	for role: String in ["Shape", "shape ", "bogus", ""]:
		assert_str(ProgramRules.role_tag(role)).override_failure_message(role).is_equal("")
	assert_str(ProgramRules.role_tag(3)).is_equal("")


func test_a_hit_names_the_card_and_the_role_of_the_bolt_that_landed() -> void:
	var state := _fight()
	_play(state, [{"power": 4, "element": "none", "foe": 0, "card": "knapsack-strike", "role": "strike"}])
	var hits := _hits(state)
	assert_array(hits).has_size(1)
	var hit: Dictionary = hits[0]
	assert_str(hit.card).is_equal("knapsack-strike")
	assert_str(hit.role).is_equal("strike")


func test_a_bad_tag_never_reaches_a_hit() -> void:
	var state := _fight()
	_play(state, [{"power": 4, "element": "none", "foe": 0, "card": "Knapsack Strike", "role": "strike"}])
	var hits := _hits(state)
	assert_array(hits).has_size(1)
	var hit: Dictionary = hits[0]
	assert_str(hit.card).is_equal("")
	assert_str(hit.role).is_equal("strike")


func test_a_relic_bolt_with_no_card_lands_with_both_tags_empty_strings() -> void:
	var state := _fight()
	_play(state, [{"power": 4, "element": "none", "foe": 0}])
	var hits := _hits(state)
	assert_array(hits).has_size(1)
	var hit: Dictionary = hits[0]
	assert_int(typeof(hit.card)).is_equal(TYPE_STRING)
	assert_str(hit.card).is_equal("")
	assert_int(typeof(hit.role)).is_equal(TYPE_STRING)
	assert_str(hit.role).is_equal("")


func test_an_overflow_hit_names_the_card_that_overflowed() -> void:
	var state := _fight([{"kind": "overkill-flows"}])
	_play(state, [{"power": 40, "element": "none", "card": "quickselect", "role": "strike"}])
	var flowed: Array = _hits(state).filter(func(hit: Dictionary) -> bool: return hit.get("flowed", false) == true)
	assert_array(flowed).has_size(1)
	var overflow: Dictionary = flowed[0]
	assert_str(overflow.card).is_equal("quickselect")
	assert_str(overflow.role).is_equal("strike")


func test_the_tag_follows_its_bolt_when_a_withdrawal_moves_the_landing() -> void:
	var state := _fight()
	# The first bolt asks the index for a bolt it does not find, so it never lands and the second moves up to index 0.
	_play(
		state,
		[
			{"power": 9, "element": "none", "from_index": true, "card": "divide", "role": "shape"},
			{"power": 4, "element": "none", "foe": 0, "card": "knapsack-strike", "role": "strike"},
		]
	)
	var hits := _hits(state)
	assert_array(hits).has_size(1)
	var hit: Dictionary = hits[0]
	assert_int(int(hit.bolt)).is_equal(0)
	assert_str(hit.card).is_equal("knapsack-strike")
	assert_str(hit.role).is_equal("strike")


func test_the_spellforge_bolt_keys_are_what_they_were() -> void:
	assert_array(ShardrunRules.BOLT_KEYS).is_equal(["power", "element", "target", "pierce", "ward", "mult"])
