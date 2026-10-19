extends GdUnitTestSuite
## The player's language (ADR-0047): keys translate whole, formats before they are filled, and the rules' English
## sentences by matching the overlays' formats, with the names inside translated too.


func after_test() -> void:
	Text.setup("en")


func test_english_is_left_as_it_is() -> void:
	Text.setup("en")
	assert_str(Text.t("Amplify")).is_equal("Amplify")
	assert_str(Text.sentence("Tally Wisp takes 9.")).is_equal("Tally Wisp takes 9.")


func test_a_key_translates_and_an_unknown_line_stays_english() -> void:
	Text.setup("ja")
	assert_str(Text.t("Amplify")).is_equal("増幅")
	assert_str(Text.t("Not a line anyone translated")).is_equal("Not a line anyone translated")


func test_adult_japanese_uses_complete_translations_and_preserves_unknown_text() -> void:
	Text.setup("ja", "kanji")
	assert_str(Text.t("a dictionary")).is_equal("辞書")
	assert_str(Text.t("Japanese reading")).is_equal("日本語の表記")
	assert_str(Text.t("the recursion went too deep")).is_equal("再帰呼び出しが深すぎます")
	assert_str(Text.t("That sounds like a lot of writing.")).is_equal("ずいぶん書くことが多そうですね。")
	assert_str(Text.f("Time played: %s", ["まち"])).is_equal("プレイ時間：まち")
	assert_str(Text.apply_japanese_reading("まちがって いろいろ")).is_equal("まちがって いろいろ")
	assert_str(Text.apply_japanese_reading("`かず` \"まち\" codeWord")).is_equal("`かず` \"まち\" codeWord")
	assert_str(Text.apply_japanese_reading("中心 行動 山札")).is_equal("中心 行動 山札")
	assert_str(Text.apply_japanese_reading("なまえ")).is_equal("なまえ")
	assert_str(Text.t("Your name")).is_equal("名前を入力")
	assert_str(Text.t("Name")).is_equal("名前")
	Text.setup("ja", "hiragana")
	assert_str(Text.apply_japanese_reading("数 色 時間 番人 町 整数 行 辞書")).is_equal(
		"かず いろ じかん ばんにん まち せいすう ぎょう じしょ")
	assert_str(Text.apply_japanese_reading("60文字までだよ")).is_equal("60もじまでだよ")
	assert_str(Text.apply_japanese_reading("番人（ばんにん）")).is_equal("ばんにん")
	assert_str(Text.apply_japanese_reading("中心 行動 山札")).is_equal("中心 行動 山札")


func test_adult_edition_covers_story_places_lessons_and_formatted_results() -> void:
	Text.setup("ja", "kanji")
	assert_str(Text.t("North Green")).is_equal("北の緑地")
	assert_str(Text.t("Pinecone")).is_equal("松ぼっくり")
	assert_str(Text.t("An old piece of code. Read it from the top, one line at a time, and keep track of what each name holds.")).is_equal(
		"古いコードだよ。上から一行ずつ読み、各変数に何が入っているか追ってみよう。"
	)
	assert_str(Text.t("There is a new name in the Book of Makers. Yours.")).is_equal(
		"作り手の本に、新たな名前が記されたぞ。君の名前じゃ。"
	)
	assert_str(Text.f("Bought %s for %d coins.", ["まつぼっくり", 3])).is_equal("まつぼっくりを3コインで購入しました。")
	assert_str(Text.t("night")).is_equal("夜")


func test_reading_mode_refreshes_auto_translated_controls_from_immutable_catalog() -> void:
	var key := "Your menu_items() didn't give a menu the town can use, so the menu is in the town's order for now."
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	add_child(label)
	Text.setup("ja", "kanji")
	label.text = key
	await get_tree().process_frame
	assert_str(label.text).is_equal(key) # Godot retains the source string; translation happens at draw time.
	assert_str(String(TranslationServer.translate(key))).is_equal(
		"menu_items() が有効なメニューを返さなかったため、現在は町の標準の順番で表示しています。"
	)
	Text.setup("ja", "hiragana")
	await get_tree().process_frame
	assert_str(label.text).is_equal(key)
	assert_str(String(TranslationServer.translate(key))).is_equal(
		"きみの menu_items() は、まちが つかえる メニューを かえして くれなかったよ。だから、いまは まちの じゅんばんで メニューが でるよ。"
	)
	Text.setup("ja", "kanji")
	await get_tree().process_frame
	assert_str(label.text).is_equal(key)
	assert_str(String(TranslationServer.translate(key))).is_equal(
		"menu_items() が有効なメニューを返さなかったため、現在は町の標準の順番で表示しています。"
	)
	label.queue_free()


func test_reviewed_hiragana_corpus_and_town_catalog_sample() -> void:
	Text.setup("ja", "hiragana")
	var parsed := Jsonc.parse_file("res://content/japanese_hiragana_readings.jsonc")
	assert_bool(parsed.get("ok", false)).is_true()
	var mismatches: Array[String] = []
	for pair: Dictionary in parsed.value:
		var actual := Text.apply_japanese_reading(String(pair.kanji))
		if actual != String(pair.hiragana):
			mismatches.append(String(pair.kanji) + " => " + actual + " (expected " + String(pair.hiragana) + ")")
	assert_array(mismatches).is_empty()
	assert_str(Text.t("The town is glad you came.")).is_equal("むらは きみが きてくれて、よろこんで おるぞ。")
	Text.setup("ja", "kanji")
	assert_str(Text.t("The town is glad you came.")).is_equal("村は君が来てくれて、喜んでおるぞ。")
	Text.setup("ja", "hiragana")
	var residuals: Array[String] = []
	var locale_dir := DirAccess.open("res://content/packs/core/locales/ja")
	for filename: String in locale_dir.get_files():
		if not filename.begins_with("overworld") or not filename.ends_with(".jsonc"):
			continue
		var locale_file := Jsonc.parse_file("res://content/packs/core/locales/ja/" + filename)
		for entry: Dictionary in locale_file.value:
			var rendered := Text.apply_japanese_reading(String(entry["to"]))
			for codepoint: int in rendered.to_utf32_buffer():
				if codepoint >= 0x4E00 and codepoint <= 0x9FFF:
					residuals.append(String(entry["en"]) + " => " + rendered)
					break
	assert_array(residuals).is_empty()


func test_a_sentence_is_matched_to_its_format_and_its_names_translated() -> void:
	Text.setup("ja")
	assert_str(Text.sentence("Tally Wisp takes 9.")).is_equal("%sに9ダメージ。" % Text.t("Tally Wisp"))
	assert_str(Text.t("Tally Wisp")).is_not_equal("Tally Wisp")


func test_numbered_slots_put_the_values_in_the_translations_order() -> void:
	Text.setup("ja")
	var line := Text.sentence("Tally Wisp moves first: 28 ops is faster than your 111.")
	assert_str(line).is_equal("%sが先に動いた！ 28 opsは、きみの111より速い。" % Text.t("Tally Wisp"))


func test_a_log_line_of_several_sentences_is_translated_one_by_one() -> void:
	Text.setup("ja")
	var line := Text.sentences("Tally Wisp takes 9. Tally Wisp breaks apart. Something left in English.")
	var wisp := Text.t("Tally Wisp")
	assert_str(line).is_equal("%sに9ダメージ。%sはくだけ散った。Something left in English." % [wisp, wisp])


func test_a_format_is_translated_before_it_is_filled() -> void:
	assert_str(Text.fill("{2} / {1}", [1, 2])).is_equal("2 / 1")
	assert_str(Text.fill("%d of %d", [1, 2])).is_equal("1 of 2")
	assert_array(Text.split_sentences("A. B! C? D")).is_equal(["A.", "B!", "C?", "D"])
