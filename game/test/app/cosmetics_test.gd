extends GdUnitTestSuite
## The shipped cosmetic catalogue (content/cosmetics.jsonc, ADR-0037): sound, every option backed by a real clip or
## sheet, translated, and the loadout saved with the profile like the skin.

const ROOT := "user://test-cosmetics"
## The three legendary looks (docs/LEGENDARY_LOOKS.md), each in its slot.
const LEGENDARY_OPTIONS := {
	"circle": "legendary-orrery",
	"bolt": "legendary-constellation",
	"impact": "legendary-singularity",
}

var _old_path := ""


func before_test() -> void:
	_clear(ROOT)
	Game.reset(ROOT)
	# Choosing a profile saves the settings: they go to this suite's folder, never the player's own file.
	_old_path = Settings.path
	Settings.path = ROOT + "/settings.json"


func after_test() -> void:
	Background.finish_all()
	Settings.loadout = {}
	Settings.path = _old_path
	Game.reset(ROOT)
	_clear(ROOT)


func test_the_catalogue_is_sound() -> void:
	assert_array(CosmeticRules.check(Cosmetics.catalog())).is_empty()
	for slot: String in CosmeticRules.SLOTS:
		assert_int(Cosmetics.options(slot).size()).override_failure_message(slot).is_greater_equal(2)


func test_every_move_is_in_the_library_and_every_sheet_is_drawn() -> void:
	var moves: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StageCharacter.MOVES_META)).clips
	for slot: String in ["idle", "cast_light", "cast_heavy"]:
		for entry in Cosmetics.options(slot):
			assert_bool(moves.has(entry.clip)).override_failure_message(entry.clip).is_true()
			if slot != "idle":
				assert_that(moves[entry.clip].get("release")).override_failure_message(entry.clip).is_not_null()
	# A look the game draws itself (CosmeticRules.is_drawn) has no sheet to check.
	for entry: Dictionary in Cosmetics.options("bolt"):
		if CosmeticRules.is_drawn("bolt", entry):
			continue
		var sheets := SpellAnim.has(entry.sprite) and SpellAnim.has(entry.strong)
		assert_bool(sheets).override_failure_message(entry.id).is_true()
	for entry: Dictionary in Cosmetics.options("impact"):
		if CosmeticRules.is_drawn("impact", entry):
			continue
		assert_bool(SpellAnim.has(entry.sprite)).override_failure_message(entry.id).is_true()
		assert_float(float(SpellAnim.facts_of(entry.sprite).impact)).is_greater(0.0)


func test_every_draw_is_a_known_draw() -> void:
	assert_array(CosmeticRules.BOLT_DRAWS).contains(["constellation"])
	assert_array(CosmeticRules.IMPACT_DRAWS).contains(["black-hole"])
	for slot: String in ["bolt", "impact"]:
		for option: Dictionary in Cosmetics.options(slot):
			if option.has("draw"):
				var known := CosmeticRules.draws_of(slot)
				assert_array(known).override_failure_message(String(option.id)).contains([option.draw])


func test_every_name_and_note_has_its_japanese() -> void:
	var japanese: Dictionary = ContentLocale.load_overlay("ja").strings
	for slot: String in CosmeticRules.SLOTS:
		for entry in Cosmetics.options(slot):
			for field: String in ["name", "note"]:
				assert_bool(japanese.has(entry[field])).override_failure_message(entry[field]).is_true()


func test_the_loadout_is_remembered_per_profile() -> void:
	assert_bool(Game.boot()).is_true()
	# Booting reads the settings from the player's file and points saving there again: point it back here.
	Settings.path = ROOT + "/settings.json"
	var first := String(Game.profile.id)
	Settings.loadout = {"circle": "clockwork", "cast_heavy": "skyward-call"}
	Game.remember_avatar()
	var second: Dictionary = Game.profiles.create("Yuki", "ja", "shibu")
	assert_bool(Game.select_profile(String(second.profile.id))).is_true()
	assert_str(Cosmetics.look("circle").id).is_equal("codex")
	assert_bool(Game.select_profile(first)).is_true()
	assert_str(Cosmetics.look("circle").id).is_equal("clockwork")
	assert_str(Cosmetics.look("cast_heavy").clip).is_equal("cast-skyward")


func test_settings_keep_only_string_choices_for_known_slots() -> void:
	var clean := Settings.clean_loadout({"circle": "rootglass", "bolt": 4, "hat": "tall"})
	assert_dict(clean).is_equal({"circle": "rootglass"})
	assert_dict(Settings.clean_loadout("nonsense")).is_empty()


func test_a_fight_plays_the_worn_moves_and_falls_back_on_a_drawn_skin() -> void:
	var hero: HeroView = auto_free(HeroView.new())
	hero.preview_skin = "dummy"
	hero.preview_loadout = {"idle": "lantern-bearer", "cast_heavy": "root-seal", "cast_light": "rune-trace"}
	hero.size = Vector2(300, 400)
	add_child(hero)
	assert_str(hero.character.idle_clip).is_equal("idle-lantern")
	hero.play_cast(true)
	assert_str(hero.character.current).is_equal("cast-slam")
	assert_bool(hero.character.is_cast("cast-slam")).is_true()
	hero.play_cast(false)
	assert_str(hero.character.current).is_equal("cast-trace")
	var drawn: HeroView = auto_free(HeroView.new())
	drawn.preview_skin = "vesper"
	drawn.preview_loadout = hero.preview_loadout
	add_child(drawn)
	assert_str(drawn.move_clip("cast_heavy")).is_equal("cast-heavy")
	assert_str(drawn.move_clip("idle")).is_equal("idle-breathe")


func test_the_legendary_looks_sit_in_their_slots_and_are_never_first() -> void:
	for slot: String in LEGENDARY_OPTIONS:
		var ids: Array = Cosmetics.options(slot).map(func(option: Dictionary) -> String: return String(option.id))
		assert_int(ids.find(LEGENDARY_OPTIONS[slot])).override_failure_message(slot).is_greater(0)
		var option := CosmeticRules.find(Cosmetics.catalog(), slot, String(LEGENDARY_OPTIONS[slot]))
		assert_bool(CosmeticRules.is_legendary(option)).override_failure_message(slot).is_true()
	# Only the three are legendary: every other look is an ordinary one.
	var legendary_ids: Array = LEGENDARY_OPTIONS.values()
	for slot: String in CosmeticRules.SLOTS:
		for option: Dictionary in Cosmetics.options(slot):
			var named := legendary_ids.has(String(option.id))
			assert_bool(CosmeticRules.is_legendary(option)).override_failure_message(String(option.id)).is_equal(named)


func test_the_legendary_looks_carry_the_fields_the_contract_names() -> void:
	var catalog := Cosmetics.catalog()
	assert_str(String(CosmeticRules.find(catalog, "circle", "legendary-orrery").style)).is_equal("orrery")
	var constellation := CosmeticRules.find(catalog, "bolt", "legendary-constellation")
	assert_str(String(constellation.draw)).is_equal("constellation")
	for field: String in ["sprite", "strong", "path"]:
		assert_bool(constellation.has(field)).override_failure_message(field).is_false()
	var singularity := CosmeticRules.find(catalog, "impact", "legendary-singularity")
	assert_str(String(singularity.draw)).is_equal("black-hole")
	assert_bool(singularity.has("sprite")).is_false()


func test_the_comet_is_renamed_to_the_constellation_bolt() -> void:
	var catalog := Cosmetics.catalog()
	for slot: String in CosmeticRules.SLOTS:
		assert_dict(CosmeticRules.find(catalog, slot, "legendary-comet")).override_failure_message(slot).is_empty()
	var bolt := CosmeticRules.find(catalog, "bolt", "legendary-constellation")
	assert_str(String(bolt.name)).is_equal("Constellation Bolt")
	assert_bool(CosmeticRules.is_legendary(bolt)).is_true()


func test_the_three_legendary_looks_pass_the_catalogue_check() -> void:
	var problems := CosmeticRules.check(Cosmetics.catalog())
	for id: String in LEGENDARY_OPTIONS.values():
		var named := problems.filter(func(problem: String) -> bool: return problem.contains(id))
		assert_array(named).override_failure_message(id).is_empty()


func test_the_legendary_looks_are_named_and_noted_in_japanese_as_the_contract_says() -> void:
	var japanese: Dictionary = ContentLocale.load_overlay("ja").strings
	var names := {
		"Orrery of the Codex": "コードの天球儀",
		"Constellation Bolt": "星座の光条",
		"Singularity Burst": "特異点の爆発",
	}
	for english: String in names:
		assert_str(String(japanese.get(english, ""))).override_failure_message(english).is_equal(names[english])
	for slot: String in LEGENDARY_OPTIONS:
		var option := CosmeticRules.find(Cosmetics.catalog(), slot, String(LEGENDARY_OPTIONS[slot]))
		for field: String in ["name", "note"]:
			var english := String(option[field])
			assert_int(String(japanese.get(english, "")).length()).override_failure_message(english).is_greater(0)


func test_a_legendary_name_is_magenta_and_an_ordinary_name_stays_amber() -> void:
	assert_that(UiTheme.LEGENDARY_NAME).is_equal(Color("#ff6ec7"))
	for slot: String in LEGENDARY_OPTIONS:
		var option := CosmeticRules.find(Cosmetics.catalog(), slot, String(LEGENDARY_OPTIONS[slot]))
		assert_that(UiTheme.name_colour(option)).override_failure_message(slot).is_equal(UiTheme.LEGENDARY_NAME)
	assert_that(UiTheme.name_colour(Cosmetics.options("circle")[0])).is_equal(UiTheme.AMBER)


static func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_clear(path.path_join(name))
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
