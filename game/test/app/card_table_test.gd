extends GdUnitTestSuite
## The Shardrun table: moves and clicks make exactly the tables the rules' `compose` accepts.

var catalog: Dictionary
var state: Dictionary


func before() -> void:
	catalog = ContentLoader.load_shardrun().catalog


func before_test() -> void:
	state = Shardrun.start(
		catalog, {"seed": "table", "language": "python", "difficulty": "beginner", "playstyle": "deck"}
	)
	# Into the first fight, so there is a hand.
	var node: Dictionary = ShardrunMap.next_rooms(state.map, state.position)[0]
	state = Shardrun.step(state, {"type": "enter", "node_id": node.id}, catalog).state


func _accepted(table: Dictionary) -> Dictionary:
	assert_bool(table.is_empty()).override_failure_message("the move was refused").is_false()
	var result := Shardrun.step(state, CardTable.command(table), catalog)
	assert_bool(result.ok).override_failure_message(str(result.get("error", ""))).is_true()
	return result.state


func test_a_fight_deals_a_hand_into_an_empty_table() -> void:
	var table := CardTable.of(state, catalog)
	assert_int((table.hand as Array).size()).is_greater(0)
	for spell: Dictionary in table.spells:
		assert_array(spell.shards).is_empty()


func test_a_click_plays_a_card_into_the_target_spell() -> void:
	var table := CardTable.of(state, catalog)
	var card: String = table.hand[0]
	var second: String = table.spells[1].id
	var next := _accepted(CardTable.tap(table, {"zone": "hand", "index": 0}, second))
	assert_array(next.spells[1].shards).is_equal([card])
	assert_array(next.spells[0].shards).is_empty()


func test_a_full_target_sends_the_card_to_the_next_spell_with_room() -> void:
	var table := CardTable.of(state, catalog)
	var first: String = table.spells[0].id
	for i in int(table.spells[0].capacity):
		table.hand.append("amplify")
		table.spells[0].shards.append("amplify")
	table.hand.resize((table.hand as Array).size() - int(table.spells[0].capacity))
	var moved := CardTable.tap(table, {"zone": "hand", "index": 0}, first)
	assert_int((moved.spells[1].shards as Array).size()).is_equal(1)


func test_order_matters_and_cards_can_be_reordered_within_a_spell() -> void:
	var table := CardTable.of(state, catalog)
	var a: String = table.hand[0]
	var b: String = table.hand[1]
	var spell: String = table.spells[0].id
	table = CardTable.tap(table, {"zone": "hand", "index": 0}, spell)
	table = CardTable.tap(table, {"zone": "hand", "index": 0}, spell)
	assert_array(table.spells[0].shards).is_equal([a, b])
	table = CardTable.move(
		table, {"zone": "spell", "spell": spell, "index": 1}, {"zone": "spell", "spell": spell, "index": 0}
	)
	assert_array(table.spells[0].shards).is_equal([b, a])
	_accepted(table)


func test_a_card_in_a_spell_goes_back_to_the_hand_on_a_click() -> void:
	var table := CardTable.of(state, catalog)
	var spell: String = table.spells[0].id
	var size := (table.hand as Array).size()
	table = CardTable.tap(table, {"zone": "hand", "index": 0}, spell)
	table = CardTable.tap(table, {"zone": "spell", "spell": spell, "index": 0})
	assert_int((table.hand as Array).size()).is_equal(size)
	assert_array(table.spells[0].shards).is_empty()


func test_the_hold_keeps_as_many_cards_as_its_limit() -> void:
	var table := CardTable.of(state, catalog)
	var limit := int(table.hold_limit)
	for i in limit:
		table = CardTable.toggle_hold(table, {"zone": "hand", "index": 0})
	assert_int((table.held as Array).size()).is_equal(limit)
	assert_dict(CardTable.toggle_hold(table, {"zone": "hand", "index": 0})).is_empty()
	_accepted(table)


func test_a_spent_spell_is_shut() -> void:
	var table := CardTable.of(state, catalog)
	table.spells[0].spent = true
	(
		assert_dict(
			CardTable.move(
				table, {"zone": "hand", "index": 0}, {"zone": "spell", "spell": table.spells[0].id, "index": 0}
			)
		)
		. is_empty()
	)
	assert_str(CardTable.target(table, table.spells[0].id)).is_equal(table.spells[1].id)
