extends GdUnitTestSuite
## The Shardrun rules' pure functions against the TypeScript engine (tools/fixtures/shardrun.ts).

var catalog: Dictionary
var pure: Dictionary


func before() -> void:
	catalog = Fixtures.load_json("shardrun-catalog")
	pure = Fixtures.load_json("shardrun-pure")


func _check(got: Variant, want: Variant, what: String) -> void:
	var difference := Fixtures.diff(got, want)
	assert_str(difference).override_failure_message("%s: %s" % [what, difference]).is_empty()


func test_ids_sort_as_the_old_engine_sorted_them() -> void:
	_check(
		ShardrunCatalog.sorted_values(catalog.shards).map(func(s: Dictionary) -> String: return s.id),
		pure.sorted.shards,
		"shards"
	)
	_check(
		ShardrunCatalog.sorted_values(catalog.relics).map(func(r: Dictionary) -> String: return r.id),
		pure.sorted.relics,
		"relics"
	)


func test_maps_match() -> void:
	for case: Dictionary in pure.maps:
		var layer: Dictionary = catalog.config.layers[int(case.layer)]
		var map := ShardrunMap.generate(case.seed, int(case.layer), layer)
		var where := "%s layer %d" % [case.seed, case.layer]
		_check(map, case.map, where)
		for next: Dictionary in case.next:
			var rooms := ShardrunMap.next_rooms(map, next.position).map(func(n: Dictionary) -> String: return n.id)
			_check(rooms, next.rooms, "%s next from %s" % [where, next.position])
		var nodes := {}
		for node: Dictionary in map.nodes:
			nodes[node.id] = node
		for encounter: Dictionary in case.encounters:
			var foes := ShardrunRules.encounter_for(case.seed, nodes[encounter.node], layer)
			_check(foes, encounter.foes, "%s encounter %s" % [where, encounter.node])


func test_work_and_billing_match() -> void:
	for case: Dictionary in pure.work_units:
		_check(
			ShardrunRules.work_units(case.complexity, case.given),
			case.units,
			"work %s %s" % [case.complexity, case.given]
		)
	for case: Dictionary in pure.bill_work:
		_check(
			ShardrunRules.bill_work(case.units, case.curve, catalog.balance),
			case.mana,
			"bill %s %s" % [case.curve, case.units]
		)
	for case: Dictionary in pure.pipeline_work:
		_check(ShardrunRules.pipeline_work(case.steps, catalog), case.units, "pipeline %s" % [case.steps])


func test_clamps_and_bolts_match() -> void:
	for case: Dictionary in pure.foe_hp:
		var raw: float = {"Infinity": INF, "NaN": NAN}.get(case.raw, case.raw) if case.raw is String else case.raw
		_check(ShardrunRules.foe_hp(raw, catalog.balance), case.hp, "foe hp %s" % case.raw)
	for case: Dictionary in pure.normalize:
		_check(
			ShardrunRules.normalize_bolts(case.raw, catalog.balance, int(case.cap)),
			case.result,
			"normalize %s" % [case.raw]
		)


func test_relic_modifiers_and_derived_numbers_match() -> void:
	for case: Dictionary in pure.modifiers:
		var state: Dictionary = case.state
		var where := "%s %s layer %d" % [state.relics, state.playstyle, state.layer]
		_check(ShardrunRules.relic_modifiers(state, catalog), Fixtures.snake(case.modifiers), where)
		_check(ShardrunRules.mana_per_turn(state, catalog), case.mana_per_turn, where + " mana")
		_check(ShardrunRules.bolt_cap(state, catalog), case.bolt_cap, where + " cap")
		_check(ShardrunRules.bolt_power_bonus(state, catalog), case.bolt_power_bonus, where + " power")
		_check(ShardrunRules.hand_size(state, catalog), case.hand_size, where + " hand")
		_check(ShardrunRules.hold_limit(state, catalog), case.hold_limit, where + " hold")
