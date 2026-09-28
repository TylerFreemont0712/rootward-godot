extends GdUnitTestSuite
## The Shardrun rules' pure functions against their recorded results (game/test/fixtures/shardrun-pure.json), over a
## catalog frozen for the rules tests (shardrun-catalog.json), so the content can change without them.

var catalog: Dictionary
var pure: Dictionary


func before() -> void:
	catalog = Fixtures.load_json("shardrun-catalog")
	pure = Fixtures.load_json("shardrun-pure")


func after() -> void:
	if Fixtures.updating():
		Fixtures.save_json("shardrun-pure", pure)


## `got` against the result recorded under `key` in `holder` (or recorded there, when re-recording).
func _check(holder: Dictionary, key: String, got: Variant, what: String, snaked := false) -> void:
	var difference := Fixtures.expect(holder, key, got, "$", snaked)
	assert_str(difference).override_failure_message("%s: %s" % [what, difference]).is_empty()


func test_ids_sort_as_recorded() -> void:
	var shards := ShardrunCatalog.sorted_values(catalog.shards).map(func(s: Dictionary) -> String: return s.id)
	_check(pure.sorted, "shards", shards, "shards")
	var relics := ShardrunCatalog.sorted_values(catalog.relics).map(func(r: Dictionary) -> String: return r.id)
	_check(pure.sorted, "relics", relics, "relics")


func test_maps_match() -> void:
	for case: Dictionary in pure.maps:
		var layer: Dictionary = catalog.config.layers[int(case.layer)]
		var map := ShardrunMap.generate(case.seed, int(case.layer), layer)
		var where := "%s layer %d" % [case.seed, case.layer]
		_check(case, "map", map, where)
		for next: Dictionary in case.next:
			var rooms := ShardrunMap.next_rooms(map, next.position).map(func(n: Dictionary) -> String: return n.id)
			_check(next, "rooms", rooms, "%s next from %s" % [where, next.position])
		var nodes := {}
		for node: Dictionary in map.nodes:
			nodes[node.id] = node
		for encounter: Dictionary in case.encounters:
			var foes := ShardrunRules.encounter_for(case.seed, nodes[encounter.node], layer)
			_check(encounter, "foes", foes, "%s encounter %s" % [where, encounter.node])


func test_work_and_billing_match() -> void:
	for case: Dictionary in pure.work_units:
		var units := ShardrunRules.work_units(case.complexity, case.given)
		_check(case, "units", units, "work %s %s" % [case.complexity, case.given])
	for case: Dictionary in pure.bill_work:
		var mana := ShardrunRules.bill_work(case.units, case.curve, catalog.balance)
		_check(case, "mana", mana, "bill %s %s" % [case.curve, case.units])
	for case: Dictionary in pure.pipeline_work:
		_check(case, "units", ShardrunRules.pipeline_work(case.steps, catalog), "pipeline %s" % [case.steps])


func test_clamps_and_bolts_match() -> void:
	for case: Dictionary in pure.foe_hp:
		var raw: float = {"Infinity": INF, "NaN": NAN}.get(case.raw, case.raw) if case.raw is String else case.raw
		_check(case, "hp", ShardrunRules.foe_hp(raw, catalog.balance), "foe hp %s" % case.raw)
	for case: Dictionary in pure.normalize:
		var bolts := ShardrunRules.normalize_bolts(case.raw, catalog.balance, int(case.cap))
		_check(case, "result", bolts, "normalize %s" % [case.raw])


func test_relic_modifiers_and_derived_numbers_match() -> void:
	for case: Dictionary in pure.modifiers:
		var state: Dictionary = case.state
		var where := "%s %s layer %d" % [state.relics, state.playstyle, state.layer]
		_check(case, "modifiers", ShardrunRules.relic_modifiers(state, catalog), where, true)
		_check(case, "mana_per_turn", ShardrunRules.mana_per_turn(state, catalog), where + " mana")
		_check(case, "bolt_cap", ShardrunRules.bolt_cap(state, catalog), where + " cap")
		_check(case, "bolt_power_bonus", ShardrunRules.bolt_power_bonus(state, catalog), where + " power")
		_check(case, "hand_size", ShardrunRules.hand_size(state, catalog), where + " hand")
		_check(case, "hold_limit", ShardrunRules.hold_limit(state, catalog), where + " hold")
