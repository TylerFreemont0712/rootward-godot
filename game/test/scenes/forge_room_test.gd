extends GdUnitTestSuite
## The forge as a player meets it: its doors, then the card melted or changed in the deck, through the run screen. The
## motion is skipped (ForgeAnimation.instant); the tests check what each choice sends and what the deck becomes.

const ROOT := "user://test-forge-saves"

var screen: ShardrunScreen


func before_test() -> void:
	BattleStage.instant = true
	ForgeAnimation.instant = true
	Game.reset(ROOT)
	Game.boot()
	Settings.code_speed = "off"
	Game.use("program")
	Game.session.saves.delete_run("program")
	Game.session.start(SandboxJob.JAVASCRIPT, "beginner", "forge-test")
	Game.session.state.status = "forge"


func after_test() -> void:
	ForgeAnimation.instant = false
	ForgeRoom.open_door = ""
	Background.finish_all()
	if is_instance_valid(screen):
		screen.queue_free()
	BattleStage.instant = false
	Game.session.saves.delete_run("program")
	Game.reset()
	# LEARN: queue_free completes at frame end; let screen and UI children leave before gdUnit counts orphans.
	await _settle()


func _settle() -> void:
	for i in 6:
		await get_tree().process_frame


func _open() -> void:
	screen = (load(Game.SHARDRUN) as PackedScene).instantiate() as ShardrunScreen
	add_child(screen)
	await get_tree().process_frame


func _first(kind: String) -> Node:
	for node: Node in screen.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().get_global_name() == kind:
			return node
	return null


func _labels_reading(text: String) -> Array:
	return screen.find_children("*", "Label", true, false).filter(
		func(node: Node) -> bool: return (node as Label).text == text
	)


func _buttons_reading(text: String) -> Array:
	return screen.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return (node as Button).text == text
	)


func _until_idle() -> void:
	while screen.is_busy():
		await get_tree().process_frame


func test_the_forge_opens_on_its_doors() -> void:
	await _open()
	assert_bool(_first("ForgeRoom") != null).is_true()
	assert_bool(_labels_reading(Text.t("Melt a card down")).is_empty()).is_false()
	assert_bool(_labels_reading(Text.t("Refactor a card")).is_empty()).is_false()
	assert_bool(_buttons_reading(Text.t("Choose")).is_empty()).is_false()


func test_melting_takes_the_chosen_card_out_of_the_deck() -> void:
	var session := Game.session
	var target: String = (session.state.deck as Array)[0]
	await _open()
	var before := (session.state.deck as Array).duplicate()
	(_first("ForgeRoom") as ForgeRoom)._open("melt")
	var melt := _first("ForgeMeltView") as ForgeMeltView
	melt.pick(target)
	await melt.confirm()
	await _until_idle()
	var after: Array = session.state.deck
	assert_int(after.size()).is_equal(before.size() - 1)
	assert_int(after.count(target)).is_equal(before.count(target) - 1)
	# A forge choice ends the room: the run goes back to the map (after_room).
	assert_str(session.state.status).is_equal("map")


func test_refactoring_turns_the_card_into_its_better_version() -> void:
	var session := Game.session
	(session.state.deck as Array)[0] = "fork"
	await _open()
	var before := (session.state.deck as Array).duplicate()
	(_first("ForgeRoom") as ForgeRoom)._open("improve")
	var improve := _first("ForgeView") as ForgeView
	improve.pick("fork")
	await improve.refactor()
	await _until_idle()
	var after: Array = session.state.deck
	assert_int(after.count("fork")).is_equal(before.count("fork") - 1)
	assert_int(after.count("fork-plus")).is_equal(before.count("fork-plus") + 1)


func test_the_chosen_card_is_ringed_and_the_others_step_back() -> void:
	var session := Game.session
	var deck: Array = session.state.deck
	var target: String = deck[0]
	var other := ""
	for id: String in deck:
		if id != target:
			other = id
			break
	assert_str(other).is_not_empty()
	await _open()
	(_first("ForgeRoom") as ForgeRoom)._open("melt")
	var grid := (_first("ForgeMeltView") as ForgeMeltView).get("_grid") as ForgeCardGrid
	(_first("ForgeMeltView") as ForgeMeltView).pick(target)
	var ring := grid.holder_of(target).get_child(1) as Panel
	assert_bool(ring.visible).is_true()
	assert_bool((grid.holder_of(other).get_child(1) as Panel).visible).is_false()
	assert_float(grid.face_of(other).modulate.a).is_equal_approx(0.62, 0.001)
	assert_float(grid.face_of(target).modulate.a).is_equal_approx(1.0, 0.001)


func test_a_thin_deck_says_it_cannot_melt() -> void:
	var session := Game.session
	var smallest := int(session.catalog.balance.deck.min_cards)
	session.state.deck = (session.state.deck as Array).slice(0, smallest)
	await _open()
	var note := Text.f("Your deck is already as thin as it can be (%d cards).", [smallest])
	assert_bool(_labels_reading(note).is_empty()).is_false()
