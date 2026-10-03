extends GdUnitTestSuite
## The look on the moves and spells (ADR-0037): a loadout of option ids, anything unknown reading as the default.

const CATALOG := {
	"idle":
	[
		{"id": "calm", "name": "Calm", "note": "", "clip": "idle-breathe"},
		{"id": "lamp", "name": "Lamp", "note": "", "clip": "idle-lantern"}
	],
	"cast_light": [{"id": "snap", "name": "Snap", "note": "", "clip": "cast-light"}],
	"cast_heavy":
	[
		{"id": "push", "name": "Push", "note": "", "clip": "cast-heavy"},
		{"id": "sky", "name": "Sky", "note": "", "clip": "cast-skyward"}
	],
	"circle": [{"id": "codex", "name": "Codex", "note": "", "style": "codex"}],
	"bolt": [{"id": "lance", "name": "Lance", "note": "", "sprite": "bolt-lance", "strong": "bolt-orb", "path": "arc"}],
	"impact": [{"id": "code", "name": "Code", "note": "", "sprite": "hit-heavy"}],
}


func test_defaults_are_each_slots_first_option() -> void:
	var chosen := CosmeticRules.defaults(CATALOG)
	assert_dict(chosen).contains_key_value("idle", "calm")
	assert_dict(chosen).contains_key_value("cast_heavy", "push")
	assert_int(chosen.size()).is_equal(CosmeticRules.SLOTS.size())


func test_sanitize_keeps_known_choices_and_drops_the_rest() -> void:
	var clean := CosmeticRules.sanitize({"idle": "lamp", "cast_heavy": "gone", "bolt": 3, "extra": "x"}, CATALOG)
	assert_str(clean.idle).is_equal("lamp")
	assert_str(clean.cast_heavy).is_equal("push")
	assert_str(clean.bolt).is_equal("lance")
	assert_bool(clean.has("extra")).is_false()
	assert_dict(CosmeticRules.sanitize(null, CATALOG)).is_equal(CosmeticRules.defaults(CATALOG))


func test_a_skin_without_the_chosen_move_plays_its_own() -> void:
	var loadout := {"cast_heavy": "sky", "idle": "lamp"}
	var library: Array = ["idle-breathe", "idle-lantern", "cast-heavy", "cast-skyward"]
	assert_str(CosmeticRules.clip(CATALOG, loadout, "cast_heavy", library)).is_equal("cast-skyward")
	# A drawn skin with two clips answers with its own.
	var drawn: Array = ["idle-breathe", "cast-light"]
	assert_str(CosmeticRules.clip(CATALOG, loadout, "cast_heavy", drawn)).is_equal("cast-heavy")
	assert_str(CosmeticRules.clip(CATALOG, loadout, "idle", drawn)).is_equal("idle-breathe")
	assert_bool(CosmeticRules.playable(CATALOG.idle[1], drawn)).is_false()


func test_check_names_what_is_wrong() -> void:
	assert_array(CosmeticRules.check(CATALOG)).is_empty()
	var broken := CATALOG.duplicate(true)
	broken.circle = [{"id": "x", "name": "X", "note": "", "style": "plaid"}]
	broken.idle = [broken.idle[1]]
	broken.erase("impact")
	var problems := CosmeticRules.check(broken)
	assert_array(problems).contains(["circle.x: unknown style", "impact: no options"])
	assert_bool(problems.any(func(p: String) -> bool: return p.begins_with("idle: the default"))).is_true()


func test_only_construction_casts_may_override_their_circle_with_a_known_style() -> void:
	var catalog := CATALOG.duplicate(true)
	var entry := {"id": "loom", "name": "Loom", "note": "", "clip": "idle-breathe", "circle_style": "script-loom"}
	catalog.cast_light.append(entry)
	assert_array(CosmeticRules.check(catalog)).contains(["cast_light.loom: unknown construction style"])
	entry.construction = "shards"
	assert_array(CosmeticRules.check(catalog)).is_empty()
	entry.circle_style = "unknown"
	assert_array(CosmeticRules.check(catalog)).contains(["cast_light.loom: unknown construction style"])
