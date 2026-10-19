extends GdUnitTestSuite
## The menu and options judges (Concept/v0.4/01, sections 5.2 and 5.3): every reason each judge gives, and the answers it
## passes. A judge gives one verdict per case, so each test runs one case through the judge.

const BUILT := ["quests", "workbench", "save", "settings", "characters", "title"]
const GOOD_MENU := ["continue", "quests", "workbench", "save", "settings", "characters", "title", "quit"]
const GOOD_ROWS := [
	{"setting": "music", "label": "Songs"},
	{"setting": "sound", "label": "Noises"},
]


func _menu(built: Array, got: Variant) -> Dictionary:
	return MenuJudges.menu_items([{"args": [built]}], [{"ok": true, "value": got}])[0]


func _rows(got: Variant) -> Dictionary:
	return MenuJudges.options_rows([{"args": []}], [{"ok": true, "value": got}])[0]


# --- menu_items ---------------------------------------------------------------------------------------------------


func test_a_menu_that_holds_the_town_passes() -> void:
	var verdict := _menu(BUILT, GOOD_MENU)
	assert_bool(verdict.ok).is_true()
	assert_str(verdict.reason).is_equal(TaskJudges.RIGHT)


func test_a_menu_that_is_not_a_list_is_refused() -> void:
	var verdict := _menu(BUILT, "continue")
	assert_str(verdict.reason).is_equal("not-list")
	assert_str(verdict.got).is_equal("continue")


func test_a_menu_must_start_with_continue() -> void:
	var verdict := _menu(BUILT, ["quests"] + GOOD_MENU.slice(1))
	assert_str(verdict.reason).is_equal("first")
	assert_str(verdict.want).is_equal("continue")
	assert_str(verdict.got).is_equal("quests")


func test_an_empty_menu_does_not_start_with_continue() -> void:
	var verdict := _menu(BUILT, [])
	assert_str(verdict.reason).is_equal("first")
	assert_bool((verdict.got as Array).is_empty()).is_true()


func test_a_menu_must_end_with_quit() -> void:
	var verdict := _menu(BUILT, GOOD_MENU.slice(0, GOOD_MENU.size() - 1) + ["title"])
	assert_str(verdict.reason).is_equal("last")
	assert_str(verdict.want).is_equal("quit")
	assert_str(verdict.got).is_equal("title")


func test_an_item_the_town_built_must_be_on_the_menu() -> void:
	# Two items are left out: the judge names the first of them, in the town's order.
	var left_out := ["continue", "quests", "workbench", "settings", "characters", "title", "quit"]
	var verdict := _menu(BUILT, left_out)
	assert_str(verdict.reason).is_equal("missing")
	assert_str(verdict.name).is_equal("save")


func test_an_item_on_the_menu_only_once() -> void:
	var twice := ["continue", "quests", "workbench", "save", "save", "settings", "characters", "title", "quit"]
	var verdict := _menu(BUILT, twice)
	assert_str(verdict.reason).is_equal("twice")
	assert_str(verdict.name).is_equal("save")


func test_continue_is_on_the_menu_once() -> void:
	var verdict := _menu(BUILT, ["continue", "continue"] + GOOD_MENU.slice(1))
	assert_str(verdict.reason).is_equal("twice")
	assert_str(verdict.name).is_equal("continue")


func test_the_menu_holds_only_what_the_town_built() -> void:
	var stranger := ["continue", "quests", "workbench", "save", "settings", "characters", "title", "bag", "quit"]
	var verdict := _menu(BUILT, stranger)
	assert_str(verdict.reason).is_equal("unknown")
	assert_str(verdict.name).is_equal("bag")


func test_a_short_town_passes_with_continue_and_quit() -> void:
	assert_str(_menu(["settings"], ["continue", "settings", "quit"]).reason).is_equal(TaskJudges.RIGHT)


func test_menu_items_gives_one_verdict_per_case() -> void:
	var cases := [{"args": [["settings"]]}, {"args": [["settings"]]}]
	var results := [{"ok": true, "value": ["continue", "settings", "quit"]}, {"ok": true, "value": ["settings"]}]
	var verdicts := MenuJudges.menu_items(cases, results)
	assert_int(verdicts.size()).is_equal(2)
	assert_bool(verdicts[0].ok).is_true()
	assert_str(verdicts[1].reason).is_equal("first")


# --- options_rows -------------------------------------------------------------------------------------------------


func test_rows_for_music_and_sound_pass() -> void:
	assert_str(_rows(GOOD_ROWS).reason).is_equal(TaskJudges.RIGHT)


func test_every_setting_may_have_a_row() -> void:
	var all := [
		{"setting": "music", "label": "Songs"},
		{"setting": "sound", "label": "Noises"},
		{"setting": "text_speed", "label": "Words"},
		{"setting": "track", "label": "Song list"},
		{"setting": "fullscreen", "label": "Big screen"},
	]
	assert_str(_rows(all).reason).is_equal(TaskJudges.RIGHT)


func test_a_label_of_twenty_four_characters_is_fine() -> void:
	var rows := [{"setting": "music", "label": "abcdefghijklmnopqrstuvwx"}, {"setting": "sound", "label": "Noises"}]
	assert_str(_rows(rows).reason).is_equal(TaskJudges.RIGHT)


func test_a_label_is_judged_after_it_is_stripped() -> void:
	var rows := [{"setting": "music", "label": "  Songs  "}, {"setting": "sound", "label": "Noises"}]
	assert_str(_rows(rows).reason).is_equal(TaskJudges.RIGHT)


func test_the_options_must_be_a_list() -> void:
	var verdict := _rows({"setting": "music", "label": "Songs"})
	assert_str(verdict.reason).is_equal("not-list")


func test_every_row_is_a_dictionary_with_a_setting_and_a_label() -> void:
	var verdict := _rows([GOOD_ROWS[0], "sound"])
	assert_str(verdict.reason).is_equal("not-row")
	assert_int(verdict.index).is_equal(1)


func test_a_row_without_a_label_is_not_a_row() -> void:
	var verdict := _rows([{"setting": "music"}, GOOD_ROWS[1]])
	assert_str(verdict.reason).is_equal("not-row")
	assert_int(verdict.index).is_equal(0)


func test_a_setting_the_page_does_not_know() -> void:
	var rows := [GOOD_ROWS[0], {"setting": "volume", "label": "Loud"}, GOOD_ROWS[1]]
	var verdict := _rows(rows)
	assert_str(verdict.reason).is_equal("unknown-setting")
	assert_str(verdict.name).is_equal("volume")


func test_a_label_that_is_empty_after_strip() -> void:
	var rows := [{"setting": "music", "label": "   "}, GOOD_ROWS[1]]
	var verdict := _rows(rows)
	assert_str(verdict.reason).is_equal("label-empty")
	assert_str(verdict.name).is_equal("music")


func test_a_label_of_more_than_twenty_four_characters() -> void:
	var long := "abcdefghijklmnopqrstuvwxy"
	var rows := [GOOD_ROWS[0], {"setting": "sound", "label": long}]
	var verdict := _rows(rows)
	assert_str(verdict.reason).is_equal("label-long")
	assert_str(verdict.name).is_equal("sound")
	assert_str(verdict.got).is_equal(long)


func test_a_setting_has_one_row() -> void:
	var rows := [GOOD_ROWS[0], {"setting": "music", "label": "Tunes"}, GOOD_ROWS[1]]
	var verdict := _rows(rows)
	assert_str(verdict.reason).is_equal("twice")
	assert_str(verdict.name).is_equal("music")


func test_music_and_sound_are_needed() -> void:
	assert_str(_rows([GOOD_ROWS[1]]).reason).is_equal("needs")
	assert_str(_rows([GOOD_ROWS[1]]).name).is_equal("music")
	assert_str(_rows([GOOD_ROWS[0]]).reason).is_equal("needs")
	assert_str(_rows([GOOD_ROWS[0]]).name).is_equal("sound")
	assert_str(_rows([]).name).is_equal("music")


func test_options_rows_gives_one_verdict_per_case() -> void:
	var verdicts := MenuJudges.options_rows([{"args": []}], [{"ok": true, "value": GOOD_ROWS}])
	assert_int(verdicts.size()).is_equal(1)
	assert_str(verdicts[0].reason).is_equal(TaskJudges.RIGHT)
