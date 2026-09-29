extends GdUnitTestSuite
## What the map shows beyond its rooms: which rooms a path can still reach, and every layer's guardian.

var catalog: Dictionary


func before() -> void:
	catalog = ProgramRules.catalog_for(ContentLoader.load_shardrun().catalog)


func _start(seed: String) -> Dictionary:
	var options := {"seed": seed, "language": "python", "difficulty": "beginner", "playstyle": "program"}
	return Shardrun.start(catalog, options)


func test_every_room_is_reachable_before_the_first_step() -> void:
	var state := _start("reach-start")
	state.position = null
	var ahead := ShardrunViews.reachable(state)
	assert_int(ahead.size()).is_equal((state.map.nodes as Array).size())


func test_a_step_leaves_behind_the_rooms_no_path_climbs_to() -> void:
	var state := _start("reach-step")
	var first: Dictionary = ShardrunMap.next_rooms(state.map, null)[0]
	state.position = first.id
	var ahead := ShardrunViews.reachable(state)
	assert_bool(ahead.has(first.id)).is_false()
	assert_bool(ahead.has(ShardrunMap.boss_id(int(state.layer)))).is_true()
	for node: Dictionary in state.map.nodes:
		if int(node.row) == 0:
			assert_bool(ahead.has(node.id)).is_false()
	for node: Dictionary in ShardrunMap.next_rooms(state.map, first.id):
		assert_bool(ahead.has(node.id)).is_true()


func test_every_layer_shows_the_guardian_that_waits_there() -> void:
	var state := _start("guardians")
	state.layer = 1
	var shown := ShardrunViews.guardians(state, catalog)
	var layers: Array = catalog.config.layers
	assert_int(shown.size()).is_equal(layers.size())
	var wheres: Array = shown.map(func(guardian: Dictionary) -> String: return guardian.where)
	assert_str(wheres[0]).is_equal("beaten")
	assert_str(wheres[1]).is_equal("current")
	assert_str(wheres[-1]).is_equal("ahead")
	for index in layers.size():
		var boss := {"id": ShardrunMap.boss_id(index), "kind": "boss"}
		var waits := ShardrunRules.encounter_for(state.seed, boss, layers[index])
		var foes: Array = shown[index].foes
		assert_bool(foes.is_empty()).override_failure_message("layer %d" % index).is_false()
		assert_str(String(foes[0].id)).is_equal(String(waits[0]))
