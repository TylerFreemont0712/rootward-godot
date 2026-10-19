extends GdUnitTestSuite
## The creator stages a reading preference, saves it with the character, and the ordinary Settings menu can change it.

const ROOT := "user://test-adult-japanese"

var creator: CharacterCreator
var screen: OverworldScreen
var settings_panel: FoundrySettingsPanel


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	Game.profile.preferred_language = "ja"
	Game.profile.japanese_reading = "hiragana"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()


func after_test() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	elif is_instance_valid(creator):
		creator.queue_free()
	if is_instance_valid(settings_panel):
		settings_panel.queue_free()
	Sound.silence()
	await _frames(5)
	Background.finish_all()
	Game.reset()
	Text.setup("en")


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _open_creator() -> void:
	creator = CharacterCreator.new()
	add_child(creator)
	creator.open(OverworldContent.load_world().catalog.looks, {}, "葵")
	await _frames(2)


func test_creator_asks_for_reading_and_switch_preserves_name_model_and_style() -> void:
	await _open_creator()
	var buttons: Dictionary = creator.get("_reading_buttons")
	assert_int(buttons.size()).is_equal(2)
	assert_str(creator.japanese_reading).is_equal("hiragana")
	creator._choose_model("female")
	creator._choose_style(OverworldState.SCRIBE)
	(buttons.kanji as Button).pressed.emit()
	await _frames(2)
	assert_str(creator.japanese_reading).is_equal("kanji")
	assert_str(Text.japanese_reading()).is_equal("kanji")
	assert_str((creator.get("_name") as LineEdit).text).is_equal("葵")
	assert_dict(creator.look).is_equal({"model": "female"})
	assert_str(creator.style).is_equal(OverworldState.SCRIBE)
	assert_str(Game.profile.japanese_reading).is_equal("hiragana")
	assert_str(Text.t("Who are you?")).is_equal("キャラクター作成")
	var current: Dictionary = creator.get("_reading_buttons")
	assert_str((current.kanji as Button).text).is_equal("漢字")
	assert_str((current.kanji as Button).theme_type_variation).is_equal("PrimaryButton")


func test_cancel_restores_previous_reading_without_changing_saved_profile() -> void:
	await _open_creator()
	creator.can_cancel = true
	creator._choose_reading("kanji")
	creator._cancel()
	assert_str(Text.japanese_reading()).is_equal("hiragana")
	assert_str(Game.profiles.get_profile(String(Game.profile.id)).japanese_reading).is_equal("hiragana")


func test_finishing_real_character_creation_persists_mode_across_profile_reload() -> void:
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(3)
	creator = screen.get("_creator") as CharacterCreator
	assert_bool(creator.visible).is_true()
	creator._choose_reading("kanji")
	(creator.get("_name") as LineEdit).text = "葵"
	creator._choose_model("female")
	creator._finish()
	await _frames(3)
	assert_str(Game.profile.japanese_reading).is_equal("kanji")
	assert_str(Game.profiles.get_profile(String(Game.profile.id)).japanese_reading).is_equal("kanji")
	assert_str(screen.state.name).is_equal("葵")
	assert_dict(screen.state.look).is_equal({"model": "female"})
	assert_bool(Game.select_profile(String(Game.profile.id), false)).is_true()
	assert_str(Text.japanese_reading()).is_equal("kanji")
	assert_str(Text.t("the recursion went too deep")).is_equal("再帰呼び出しが深すぎます")


func test_menu_settings_changes_and_saves_both_directions_after_creation() -> void:
	settings_panel = FoundrySettingsPanel.make()
	add_child(settings_panel)
	settings_panel.set("_tab", "Fonts")
	settings_panel._rebuild()
	settings_panel._choose_reading("kanji")
	await _frames(2)
	assert_str(Game.profiles.get_profile(String(Game.profile.id)).japanese_reading).is_equal("kanji")
	assert_str(Text.t("Japanese reading")).is_equal("日本語の表記")
	assert_str(Text.f("Time played: %s", ["まち"])).is_equal("プレイ時間：まち")
	settings_panel._choose_reading("hiragana")
	await _frames(2)
	assert_str(Game.profiles.get_profile(String(Game.profile.id)).japanese_reading).is_equal("hiragana")
	assert_str(Text.t("Japanese reading")).is_equal("にほんごの よみかた")


func test_english_creation_keeps_existing_choices_and_retains_reading_preference() -> void:
	Text.setup("en", "kanji")
	await _open_creator()
	assert_dict(creator.get("_reading_buttons")).is_empty()
	assert_str(creator.japanese_reading).is_equal("kanji")
	assert_int((creator.get("_model_buttons") as Dictionary).size()).is_equal(2)
	assert_str((creator.get("_name") as LineEdit).text).is_equal("葵")
