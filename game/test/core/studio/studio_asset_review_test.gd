extends GdUnitTestSuite


func test_reflagging_one_asset_keeps_its_notes_prompt_and_creation_time() -> void:
	var first := StudioAssetReview.put({}, "inn", {"name": "Inn", "notes": "Roof is too bright", "prompt": "warm timber village inn"}, "day-one")
	var before := first.duplicate(true)
	var again := StudioAssetReview.put(first, "inn", {"map": "lanternroot", "at": [3, 4]}, "day-two")
	assert_dict(first).is_equal(before)
	assert_int(again.size()).is_equal(1)
	assert_str(again.inn.notes).is_equal("Roof is too bright")
	assert_str(again.inn.prompt).is_equal("warm timber village inn")
	assert_str(again.inn.created_at).is_equal("day-one")
	assert_str(again.inn.updated_at).is_equal("day-two")


func test_resolving_keeps_the_brief_and_reflagging_restores_it() -> void:
	var first := StudioAssetReview.put({}, "barrel", {"prompt": "weathered wooden village barrel"}, "one")
	var resolved := StudioAssetReview.resolve(first, "barrel", "two")
	assert_array(StudioAssetReview.pending(resolved)).is_empty()
	assert_str(resolved.barrel.prompt).is_equal(first.barrel.prompt)
	assert_array(StudioAssetReview.pending(first)).is_equal(["barrel"])
	var restored := StudioAssetReview.put(resolved, "barrel", {}, "three")
	assert_array(StudioAssetReview.pending(restored)).is_equal(["barrel"])
	assert_str(restored.barrel.created_at).is_equal("one")


func test_replacements_get_reproducible_new_ids_without_interpreting_prompt_text() -> void:
	var prompt := "warm timber cottage; $(touch should-not-run)"
	var id := StudioAssetReview.replacement_id("cottage", prompt)
	assert_str(id).starts_with("cottage-update-")
	assert_str(id).is_equal(StudioAssetReview.replacement_id("cottage", "  " + prompt + "  "))
	assert_str(id).is_not_equal(StudioAssetReview.replacement_id("cottage", "different timber cottage"))
	assert_bool(id.contains("$")).is_false()
