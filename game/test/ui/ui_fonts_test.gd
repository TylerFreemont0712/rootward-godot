extends GdUnitTestSuite
## Font preferences survive old/new saves and retain source spacing while UI themes update in place.

var _old_face := ""
var _old_path := ""


func before_test() -> void:
	_old_face = Settings.font_style
	_old_path = Settings.path
	Settings.path = "user://test-font-preferences.json"


func after_test() -> void:
	Settings.font_style = _old_face
	Settings.path = _old_path
	UiTheme.refresh_fonts()
	DirAccess.remove_absolute("user://test-font-preferences.json")


func test_each_candidate_is_bundled_and_updates_live_themes_without_changing_code_spacing() -> void:
	var shared := UiTheme.shared()
	var front := FoundryUi.theme()
	var heading_size := front.get_font_size("font_size", "Heading")
	var source := UiTheme.code_font()
	for id: String in UiFonts.CHOICES:
		Settings.font_style = id
		UiTheme.refresh_fonts()
		assert_object(UiTheme.shared()).is_same(shared)
		assert_object(shared.default_font).is_same(UiTheme.ui_font())
		assert_object(front.default_font).is_same(UiTheme.ui_font())
		assert_int(front.get_font_size("font_size", "Heading")).is_equal(heading_size)
		assert_object(shared.get_font("font", "Code")).is_same(source)
		assert_object(shared.get_font("font", "CodeEdit")).is_same(source)
		assert_bool(UiTheme.ui_font().has_char("λ".unicode_at(0))).is_true()
		if id != "default":
			assert_bool(UiTheme.ui_font().has_char("旅".unicode_at(0))).is_true()
			assert_object(UiFonts.face(id)).is_not_null()
			assert_object(UiFonts.face(id, 600)).is_not_null()
			assert_object(UiTheme.ui_font()).is_not_same(source)
	assert_float(source.get_char_size("i".unicode_at(0), 18).x).is_equal(source.get_char_size("M".unicode_at(0), 18).x)


func test_preferences_round_trip_and_old_or_invalid_saved_fonts_keep_the_original() -> void:
	for id: String in UiFonts.CHOICES:
		Settings.font_style = id
		Settings.save_file()
		Settings.font_style = "invalid"
		Settings.load_file(Settings.path)
		assert_str(Settings.font_style).is_equal(id)
	for saved: Dictionary in [{}, {"font_style": "unavailable"}, {"font_style": 123}]:
		var file := FileAccess.open(Settings.path, FileAccess.WRITE)
		file.store_string(JSON.stringify(saved))
		file.close()
		Settings.font_style = "cinzel"
		Settings.load_file(Settings.path)
		assert_str(Settings.font_style).is_equal("default")
		assert_object(UiTheme.ui_font()).is_same(UiTheme.code_font())


func test_source_views_keep_their_monospaced_override_under_a_decorative_theme() -> void:
	Settings.font_style = "lora"
	UiTheme.refresh_fonts()
	var box := auto_free(Cards.code({"code": {"python": "def spell():\n    return 3"}}, "python")) as Control
	var source := box.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	assert_object(source.get_theme_font("normal_font")).is_same(UiTheme.code_font())
	var rune := auto_free(RuneCode.new()) as RuneCode
	assert_object(rune.get("_font")).is_same(UiTheme.code_font())
