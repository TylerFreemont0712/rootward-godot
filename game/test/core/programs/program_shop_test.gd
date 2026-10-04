extends GdUnitTestSuite
## The Registry (ProgramShop): its stock is drawn from the seed, prices and purchases are cycles, and its services
## remove, refactor or fetch cards.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _shop(seed := "registry", cycles := 1000) -> Dictionary:
	var options := {"seed": seed, "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.erase("draft")
	state.paradigm = "greedy"
	state.focus = "heap"
	state.deck = ["salvo", "salvo", "fork", "amplify", "ward", "ward", "round-robin", "kindle", "sweep", "take-max"]
	state.cycles = cycles
	ProgramShop.enter(state, {"id": "l0-r7-c1"}, catalog)
	return state


func _step(state: Dictionary, command: Dictionary) -> Dictionary:
	var result := Shardrun.step(state, command, catalog)
	assert_bool(result.ok).override_failure_message("%s: %s" % [command, result.get("error", "")]).is_true()
	return result.state if result.ok else state


func test_the_stock_is_five_cards_three_relics_and_scripts_with_one_card_on_sale() -> void:
	var shop: Dictionary = _shop().shop
	assert_int((shop.cards as Array).size()).is_equal(5)
	assert_int((shop.relics as Array).size()).is_equal(3)
	assert_int((shop.scripts as Array).size()).is_equal(3)
	(
		assert_int((shop.cards as Array).filter(func(item: Dictionary) -> bool: return item.get("sale", false)).size())
		. is_equal(1)
	)
	var ids := (shop.cards as Array).map(func(item: Dictionary) -> String: return item.id)
	assert_int(ids.size()).is_equal(5)
	var distinct := {}
	for id: String in ids:
		distinct[id] = true
	assert_int(distinct.size()).is_equal(5)


func test_the_cards_are_two_of_your_paradigm_a_neutral_and_one_from_another() -> void:
	for n in 40:
		var state := _shop("mix-%d" % n)
		var groups := (state.shop.cards as Array).map(
			func(item: Dictionary) -> String: return ProgramRewards._group_of(catalog.shards[item.id], state)
		)
		assert_int(groups.filter(func(g: String) -> bool: return g == "own").size()).is_greater_equal(2)
		assert_int(groups.filter(func(g: String) -> bool: return g == "neutral").size()).is_greater_equal(1)
		assert_int(groups.filter(func(g: String) -> bool: return g == "other").size()).is_greater_equal(1)


func test_the_same_room_always_stocks_the_same_shelves() -> void:
	assert_dict(_shop("same").shop).is_equal(_shop("same").shop)
	assert_bool(_shop("same").shop == _shop("other").shop).is_false()


func test_buying_a_card_spends_cycles_and_empties_its_shelf_slot() -> void:
	var state := _shop()
	var item: Dictionary = state.shop.cards[0]
	var price := ProgramShop.price_of(state, "cards", item, catalog)
	state = _step(state, {"type": "buy", "shelf": "cards", "index": 0})
	assert_int(int(state.cycles)).is_equal(1000 - price)
	assert_array(state.deck).contains([item.id])
	assert_bool(Shardrun.step(state, {"type": "buy", "shelf": "cards", "index": 0}, catalog).ok).is_false()


func test_an_empty_wallet_buys_nothing() -> void:
	var state := _shop("poor", 0)
	var result := Shardrun.step(state, {"type": "buy", "shelf": "relics", "index": 0}, catalog)
	assert_bool(result.ok).is_false()
	assert_str(result.error.code).is_equal("too-expensive")


func test_a_bought_relic_joins_the_run_and_a_script_goes_on_the_belt() -> void:
	var state := _shop()
	var relic: String = state.shop.relics[0].id
	state = _step(state, {"type": "buy", "shelf": "relics", "index": 0})
	assert_array(state.relics).contains([relic])
	var script: String = state.shop.scripts[0].id
	state = _step(state, {"type": "buy", "shelf": "scripts", "index": 0})
	assert_array(state.belt).contains([script])


func test_uninstall_costs_more_each_time_and_never_thins_the_deck_past_its_minimum() -> void:
	var state := _shop()
	assert_int(ProgramShop.service_price(state, "uninstall", catalog)).is_equal(75)
	state = _step(state, {"type": "shop-service", "kind": "uninstall", "card_id": "kindle"})
	assert_int(ProgramShop.service_price(state, "uninstall", catalog)).is_equal(100)
	assert_array(state.deck).not_contains(["kindle"])
	assert_int(int(state.cycles)).is_equal(1000 - 75)
	state.deck = ["salvo", "salvo", "ward", "amplify", "fork"]
	var result := Shardrun.step(state, {"type": "shop-service", "kind": "uninstall", "card_id": "fork"}, catalog)
	assert_bool(result.ok).is_false()


func test_refactor_forges_a_card_into_its_plus() -> void:
	var state := _step(_shop(), {"type": "shop-service", "kind": "refactor", "card_id": "salvo"})
	assert_array(state.deck).contains(["salvo-plus"])
	assert_int(int(state.cycles)).is_equal(1000 - 90)


func test_pip_install_offers_three_cards_of_the_paradigm_you_name_and_you_take_one() -> void:
	var state := _step(_shop(), {"type": "shop-service", "kind": "pip-install", "paradigm": "dynamic"})
	var pip: Dictionary = state.shop.pip
	assert_int((pip.cards as Array).size()).is_equal(3)
	for id: String in pip.cards:
		assert_str(catalog.shards[id].paradigm).is_equal("dynamic")
	var take := String(pip.cards[1])
	state = _step(state, {"type": "pip-take", "card_id": take})
	assert_array(state.deck).contains([take])
	assert_bool(state.shop.has("pip")).is_false()
	assert_int(int(state.cycles)).is_equal(1000 - 60)


func test_leaving_the_registry_returns_to_the_map() -> void:
	var state := _step(_shop(), {"type": "leave-shop"})
	assert_str(state.status).is_equal("map")
	assert_bool(state.has("shop")).is_false()
