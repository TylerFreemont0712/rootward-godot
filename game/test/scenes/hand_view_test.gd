extends GdUnitTestSuite
## The hand: a card leaving at the turn's end goes to the discard pile, even with another card pointed at.

const IDS: Array[String] = ["arc", "attune", "backdraft", "blood-price", "bulwark"]


func _make(id: String, index: int) -> CardFace:
	return CardFace.create(id, Game.catalog, "python", false, CardFace.Size.HAND, {"zone": "hand", "index": index})


func _hand() -> HandView:
	Game.boot()
	var host: Control = auto_free(Control.new())
	host.size = Vector2(1000, 300)
	var hand := HandView.new()
	hand.size = host.size
	hand.draw_point = func() -> Vector2: return Vector2(50, 150)
	hand.discard_point = func() -> Vector2: return Vector2(950, 150)
	host.add_child(hand)
	add_child(host)
	return hand


func test_every_card_of_the_old_hand_is_discarded_while_one_is_pointed_at() -> void:
	var hand := _hand()
	hand.show_hand(IDS, _make, true, {})
	await await_millis(300)
	var pointed := 3
	hand._point(hand.cards[pointed], true)
	var old: Array[CardFace] = hand.cards.duplicate()
	# Godot answers a pointed-at card turning IGNORE (as it leaves) with mouse_exited at once, mid-loop.
	var calls := [0]
	hand.discard_point = func() -> Vector2:
		calls[0] += 1
		if calls[0] == pointed + 1:
			old[pointed].mouse_exited.emit()
		return Vector2(950, 150)
	hand.show_hand(["adapt", "amplify", "apex", "arc", "attune"], _make, true, {})
	await await_millis(900)
	for face in old:
		assert_bool(is_instance_valid(face)).is_false()
	assert_int(hand.get_child_count()).is_equal(5)
