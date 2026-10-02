extends GdUnitTestSuite
## The shipped cosmetic catalogue (content/cosmetics.jsonc, ADR-0037): sound, every option backed by a real clip or
## sheet, translated, and the loadout saved with the profile like the skin.

const ROOT := "user://test-cosmetics"


func before_test() -> void:
	_clear(ROOT)
	Game.reset(ROOT)


func after_test() -> void:
	Background.finish_all()
	Settings.loadout = {}
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
	for entry in Cosmetics.options("bolt"):
		(
			assert_bool(SpellAnim.has(entry.sprite) and SpellAnim.has(entry.strong))
			. override_failure_message(entry.id)
			. is_true()
		)
	for entry in Cosmetics.options("impact"):
		assert_bool(SpellAnim.has(entry.sprite)).override_failure_message(entry.id).is_true()
		assert_float(float(SpellAnim.facts_of(entry.sprite).impact)).is_greater(0.0)


func test_every_name_and_note_has_its_japanese() -> void:
	var japanese: Dictionary = ContentLocale.load_overlay("ja").strings
	for slot: String in CosmeticRules.SLOTS:
		for entry in Cosmetics.options(slot):
			for field: String in ["name", "note"]:
				assert_bool(japanese.has(entry[field])).override_failure_message(entry[field]).is_true()


func test_the_loadout_is_remembered_per_profile() -> void:
	assert_bool(Game.boot()).is_true()
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


static func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		_clear(path.path_join(name))
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
