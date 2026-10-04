extends GdUnitTestSuite

var catalog: Dictionary
var state: Dictionary
var foe: Dictionary


func before_test() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)
	state = {"relics": [], "battle": {}}
	foe = {"id": "test", "intents": [], "intent_index": 0}


func test_attack_input_separates_per_hit_damage_from_repetitions() -> void:
	foe.intents = [{"kind": "multi", "power": 4, "times": 3, "tempo": 20}]
	var seen := ProgramIntents.describe(foe, state, catalog)
	assert_dict(seen).is_equal({"kind": "attack", "damage": 4, "hits": 3, "tempo": 20})
	foe.intents = [{"kind": "strike", "power": 4}]
	foe.stoked = true
	assert_int(int(ProgramIntents.describe(foe, state, catalog).damage)).is_equal(8)


func test_guardian_input_uses_current_counters_and_echo() -> void:
	foe.intents = [{"kind": "loop", "power": 2, "start": 2}]
	foe.loop = 5
	assert_int(int(ProgramIntents.describe(foe, state, catalog).hits)).is_equal(5)
	foe.intents = [{"kind": "count", "power": 30, "wrap": 256}]
	foe.counted = 4
	assert_int(int(ProgramIntents.describe(foe, state, catalog).damage)).is_zero()
	foe.intents = [{"kind": "reprint", "power": 3, "max": 4}]
	foe.echo = {"bolts": 9}
	assert_int(int(ProgramIntents.describe(foe, state, catalog).hits)).is_equal(4)


func test_non_attack_and_disabled_foes_have_no_damage() -> void:
	foe.intents = [{"kind": "shield", "amount": 7}]
	assert_int(int(ProgramIntents.describe(foe, state, catalog).damage)).is_zero()
	foe.intents = [{"kind": "throw", "power": 5}]
	foe.trace = 2
	assert_int(int(ProgramIntents.describe(foe, state, catalog).damage)).is_equal(7)
	foe.stunned = true
	assert_int(int(ProgramIntents.describe(foe, state, catalog).damage)).is_zero()
