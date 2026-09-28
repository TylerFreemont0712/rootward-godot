extends GdUnitTestSuite
## Hand-made edge cases of the rules (foe traits, single relics, tiny custom catalogs): calls into the rules with their
## arguments and results (game/test/fixtures/shardrun-unit.json.gz, first recorded from the TypeScript engine's own
## unit tests), each made again here. Re-recording keeps the calls and records what this engine returns.

var recording: Dictionary
var catalogs: Array
var calls: Array


func before() -> void:
	recording = Fixtures.load_json_gz("shardrun-unit")
	catalogs = recording.catalogs.map(func(catalog: Variant) -> Variant: return _decode(catalog))
	calls = recording.calls


func after() -> void:
	if Fixtures.updating():
		Fixtures.save_json_gz("shardrun-unit", recording)


func test_every_recorded_call_matches() -> void:
	var failures: Array[String] = []
	var replayed := 0
	for i in calls.size():
		var call: Dictionary = calls[i]
		if call.has("threw"):
			continue
		var args: Array = (call.args as Array).map(func(arg: Variant) -> Variant: return _arg(arg))
		var got: Variant = _invoke(call.fn, args)
		if Fixtures.updating():
			call.result = _encode(got)
			replayed += 1
			continue
		var difference := Fixtures.diff(got, Fixtures.snake(_decode(call.get("result"))), call.fn)
		if difference != "":
			failures.append("call %d %s: %s" % [i, call.fn, difference])
		replayed += 1
	assert_int(replayed).is_greater(2000)
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 15))).is_empty()


func _arg(arg: Variant) -> Variant:
	if arg is Dictionary and (arg as Dictionary).has("$catalog"):
		return catalogs[int(arg["$catalog"])]
	return Fixtures.snake(_decode(arg))


func _invoke(fn: String, a: Array) -> Variant:
	match fn:
		"startShardrun":
			return Shardrun.start(a[0], a[1])
		"stepShardrun":
			return Shardrun.step(a[0], a[1], a[2])
		"previewCast":
			return ShardrunBattle.preview_cast(a[0], a[1], a[2], a[3])
		"previewBolts":
			return ShardrunBattle.preview_bolts(a[0], a[1], a[2])
		"billWork":
			return ShardrunRules.bill_work(a[0], a[1], a[2])
		"boltCap":
			return ShardrunRules.bolt_cap(a[0], a[1])
		"boltPowerBonus":
			return ShardrunRules.bolt_power_bonus(a[0], a[1])
		"manaPerTurn":
			return ShardrunRules.mana_per_turn(a[0], a[1])
		"handSize":
			return ShardrunRules.hand_size(a[0], a[1])
		"holdLimit":
			return ShardrunRules.hold_limit(a[0], a[1])
		"encounterFor":
			return ShardrunRules.encounter_for(a[0], a[1], a[2])
		"generateLayerMap":
			return ShardrunMap.generate(a[0], a[1], a[2])
		"nextRooms":
			return ShardrunMap.next_rooms(a[0], a[1])
		"matchesRelic":
			return RelicConditions.matches(a[0], a[1], a[2], a[3])
		"normalizeBolts":
			return ShardrunRules.normalize_bolts(a[0], a[1], a[2])
		"pipelineWork":
			return ShardrunRules.pipeline_work(a[0], a[1])
		"scoreShardrun":
			return ShardrunScore.score(a[0])
		"workUnits":
			return ShardrunRules.work_units(a[0], a[1])
	return "unknown function %s" % fn


## Non-finite numbers are written as {"$num": "Infinity"}; everything else is plain JSON.
static func _encode(value: Variant) -> Variant:
	if value is float and not is_finite(value):
		return {"$num": "NaN" if is_nan(value) else ("Infinity" if value > 0 else "-Infinity")}
	if value is Dictionary:
		var result := {}
		for key: Variant in value:
			result[key] = _encode(value[key])
		return result
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return _encode(item))
	return value


## A recorded value as the engine's: {"$num": ...} back to the non-finite float it stands for.
static func _decode(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.size() == 1 and dictionary.has("$num"):
			return {"Infinity": INF, "-Infinity": -INF, "NaN": NAN}[dictionary["$num"]]
		var result := {}
		for key: Variant in dictionary:
			result[key] = _decode(dictionary[key])
		return result
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return _decode(item))
	return value
