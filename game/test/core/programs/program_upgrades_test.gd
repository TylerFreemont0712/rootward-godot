extends GdUnitTestSuite
## Every card's + version (ADR-0018, SHARDRUN_DESIGN 3.5): each card a deck can hold refactors at the forge into a
## card that exists, is never drafted itself, and keeps the card's picture.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func test_every_card_a_deck_can_hold_has_an_upgrade() -> void:
	var missing: Array[String] = []
	for card: Dictionary in catalog.shards.values():
		if String(card.id).ends_with("-plus") or card.id == "lambda":
			continue
		var forge: Dictionary = card.get("forge", {})
		if not catalog.shards.has(String(forge.get("into", ""))):
			missing.append(card.id)
	assert_array(missing).override_failure_message("no upgrade: %s" % [missing]).is_empty()


func test_an_upgrade_is_never_drafted_and_shows_its_cards_picture() -> void:
	for card: Dictionary in catalog.shards.values():
		if not String(card.id).ends_with("-plus"):
			continue
		var base := String(card.id).trim_suffix("-plus")
		assert_bool(bool(card.draftable)).override_failure_message(card.id).is_false()
		assert_str(ShardrunViews.art(card)).is_equal("shardrun/card-" + base)
		assert_str(String(card.name)).is_equal(String(catalog.shards[base].name) + "+")


func test_the_forge_refactors_a_card_of_the_deck() -> void:
	var options := {"seed": "upgrade-test", "language": "python", "difficulty": "beginner", "playstyle": "program"}
	var state := Shardrun.start(catalog, options)
	state.status = "forge"
	state.deck = ["salvo", "salvo", "amplify"]
	var result := Shardrun.step(state, {"type": "forge", "shard_id": "amplify"}, catalog)
	assert_bool(result.ok).is_true()
	assert_array(result.state.deck).is_equal(["salvo", "salvo", "amplify-plus"])
