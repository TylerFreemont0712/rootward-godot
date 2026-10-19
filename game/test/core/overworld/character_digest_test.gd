extends GdUnitTestSuite
## One character at a glance (ADR-0061): quests done, townspeople met, the keys the boots know (exactly from blocks;
## typed code counts once the town has seen all four ways work), the code the boots run, time played and days ago.

const QUESTS := {
	"boots": {"order": 1, "steps": [{"text": "Step.", "done": {"flag": "first-step"}}]},
	"hello": {"order": 2, "after": ["boots"], "steps": [{"text": "Meet Marta.", "done": {"flag": "met-innkeeper"}}]},
	"memory": {"order": 3, "after": ["hello"], "steps": [{"text": "Save.", "done": {"flag": "saved-once"}}]},
}
const TOWNSFOLK := {"innkeeper": {}, "pip": {}, "guard": {}}


func _state(blocks: Array, flags := {}) -> Dictionary:
	var state := OverworldState.fresh("home", Vector2i(2, 3), "down", BootsCode.PYTHON)
	state.boots.blocks = blocks
	state.flags = flags
	return state


func test_quests_done_counts_only_finished_quests() -> void:
	assert_int(CharacterDigest.quests_done(QUESTS, {})).is_equal(0)
	assert_int(CharacterDigest.quests_done(QUESTS, {"first-step": true, "met-innkeeper": true})).is_equal(2)
	# A quest whose step holds but whose quest before it is not done is still locked, not done.
	assert_int(CharacterDigest.quests_done(QUESTS, {"saved-once": true})).is_equal(0)


func test_met_lists_the_townspeople_met_in_content_order() -> void:
	var met := CharacterDigest.met(TOWNSFOLK, {"met-guard": true, "met-innkeeper": true, "met-nobody": true})
	assert_array(met).contains_exactly(["innkeeper", "guard"])
	assert_array(CharacterDigest.met(TOWNSFOLK, {"met-pip": false})).is_empty()


func test_keys_taught_from_blocks_are_exact() -> void:
	var blocks := [
		BootsCode.rule("right", "x", 1),
		BootsCode.rule("up", "y", -1),
		{"key": "left", "do": [{"change": "x", "by": 0}]},
		{"key": "jump", "do": [{"change": "y", "by": 1}]},
	]
	assert_array(CharacterDigest.keys_taught(_state(blocks))).contains_exactly(["up", "right"])
	assert_array(CharacterDigest.keys_taught(_state([]))).is_empty()


func test_typed_code_counts_all_four_only_once_seen_working() -> void:
	var state := OverworldState.with_code(_state([]), "def on_key(key, player):\n    pass\n")
	assert_bool(CharacterDigest.typed(state)).is_true()
	assert_array(CharacterDigest.keys_taught(state)).is_empty()
	state.flags = {"all-ways": true}
	assert_array(CharacterDigest.keys_taught(state)).contains_exactly(BootsRules.KEYS)


func test_source_is_the_code_the_boots_run() -> void:
	var state := _state([BootsCode.rule("right", "x", 1)])
	assert_str(CharacterDigest.source(state)).is_equal(BootsCode.source(state.boots.blocks, BootsCode.PYTHON))
	var typed := OverworldState.with_code(state, "def on_key(key, player):\n    player.x += 1\n")
	assert_str(CharacterDigest.source(typed)).is_equal("def on_key(key, player):\n    player.x += 1\n")
	assert_str(CharacterDigest.source({})).is_equal("")


func test_played_is_hours_and_minutes() -> void:
	assert_that(CharacterDigest.played({"played_seconds": 4000})).is_equal(Vector2i(1, 6))
	assert_that(CharacterDigest.played({})).is_equal(Vector2i.ZERO)
	assert_that(CharacterDigest.played({"played_seconds": -5})).is_equal(Vector2i.ZERO)


func test_days_ago_counts_calendar_days_in_local_time() -> void:
	var noon := 86400.0 * 100 + 43200.0
	assert_int(CharacterDigest.days_ago(noon - 3600.0, noon)).is_equal(0)
	assert_int(CharacterDigest.days_ago(noon - 86400.0, noon)).is_equal(1)
	# 23:30 yesterday is one day ago at 00:30, though only an hour has passed; nine hours east shifts the day.
	var after_midnight := 86400.0 * 100 + 1800.0
	assert_int(CharacterDigest.days_ago(after_midnight - 3600.0, after_midnight)).is_equal(1)
	assert_int(CharacterDigest.days_ago(after_midnight - 3600.0, after_midnight, 540)).is_equal(0)
	assert_int(CharacterDigest.days_ago(noon + 100.0, noon)).is_equal(0)
