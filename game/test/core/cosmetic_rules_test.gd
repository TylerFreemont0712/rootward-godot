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


func test_a_save_that_wore_the_loom_as_a_move_keeps_it_as_a_circle() -> void:
	var catalog := Cosmetics.catalog()
	var kept := CosmeticRules.sanitize(
		{"cast_light": "script-loom", "cast_heavy": "script-loom", "circle": "constellation"}, catalog
	)
	assert_str(kept.circle).is_equal("script-loom")
	# The moves it named no longer exist, so those slots read as their defaults.
	assert_str(kept.cast_light).is_equal("finger-snap")
	assert_str(kept.cast_heavy).is_equal("grand-push")
	var chosen := CosmeticRules.sanitize({"cast_light": "script-loom", "circle": "ring-bloom"}, catalog)
	assert_str(chosen.circle).is_equal("ring-bloom")
	var weave := CosmeticRules.sanitize({"cast_heavy": "shard-weave", "circle": "rootglass"}, catalog)
	assert_str(weave.circle).is_equal("rootglass")
	assert_str(weave.cast_heavy).is_equal("grand-push")


func test_no_move_carries_a_spell_animation() -> void:
	for slot: String in ["cast_light", "cast_heavy"]:
		for option in Cosmetics.options(slot):
			(
				assert_bool(option.has("construction") or option.has("circle_style"))
				. override_failure_message(option.id)
				. is_false()
			)
	for style: String in ["script-loom", "ring-bloom"]:
		var found := false
		for option in Cosmetics.options("circle"):
			found = found or option.style == style
		assert_bool(found).override_failure_message(style).is_true()
