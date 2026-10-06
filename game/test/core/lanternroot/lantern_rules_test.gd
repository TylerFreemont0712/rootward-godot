extends GdUnitTestSuite
## Lanternroot's rules (ADR-0055): letters by day and prerequisite, starters added once, lanterns lit by passing tests,
## change orders sharing a lantern, and the Night Watch darkening what broke and holding the day until it is fixed.

var catalog: Dictionary


func before() -> void:
	catalog = LanternContent.load_town().catalog


func _passing(cases: Array[Dictionary]) -> Array:
	return cases.map(func(c: Dictionary) -> Dictionary: return {"id": c.id, "status": "pass"})


func test_a_new_town_starts_on_day_one_with_its_three_letters() -> void:
	var town := LanternRules.new_town("python")
	var ids := LanternRules.letters(catalog, town).map(func(r: Dictionary) -> String: return r.id)
	assert_array(ids).contains_exactly(["lamp-oil", "loaves", "greeting"])
	assert_bool(LanternRules.day_done(catalog, town)).is_false()


func test_opening_a_letter_adds_its_starter_once_and_beside_other_functions() -> void:
	var town := LanternRules.open_letter(catalog, LanternRules.new_town("python"), "greeting")
	assert_str(town.files.post).contains("def greeting(name):")
	assert_array(town.read).contains(["greeting"])
	var again := LanternRules.open_letter(catalog, town, "greeting")
	assert_str(again.files.post).is_equal(town.files.post)
	var both := LanternRules.open_letter(catalog, again, "postage")
	assert_str(both.files.post).contains("def greeting(name):").contains("def postage(grams):")
	var js := LanternRules.open_letter(catalog, LanternRules.new_town("javascript"), "loaves")
	assert_str(js.files.bakery).contains("function loavesFor(guests)").contains("module.exports.loavesFor")


func test_a_letter_waits_for_its_day_and_what_it_requires() -> void:
	var town := LanternRules.new_town("python")
	town.day = 2
	var ids := LanternRules.letters(catalog, town).map(func(r: Dictionary) -> String: return r.id)
	assert_array(ids).contains(["market-total"]).not_contains(["postage", "bread-order"])
	town.solved = {"greeting": {"day": 1}, "loaves": {"day": 1}, "market-total": {"day": 2}}
	ids = LanternRules.letters(catalog, town).map(func(r: Dictionary) -> String: return r.id)
	assert_array(ids).contains(["postage", "bread-order"])


func test_passing_every_test_answers_the_letter_and_lights_its_lantern() -> void:
	var town := LanternRules.new_town("python")
	var cases := LanternRules.letter_cases(catalog, "loaves", "python")
	assert_int(cases.size()).is_equal(7)
	var failed := LanternRules.record_run(catalog, town, "loaves", [{"id": cases[0].id, "status": "fail"}])
	assert_bool(failed.lit).is_false()
	assert_bool(LanternRules.is_solved(failed.town, "loaves")).is_false()
	var passed := LanternRules.record_run(catalog, failed.town, "loaves", _passing(cases))
	assert_bool(passed.lit).is_true()
	assert_str(passed.town.lanterns.loaves).is_equal(LanternRules.LIT)
	assert_int(passed.town.runs.loaves).is_equal(2)


func test_a_change_order_shares_the_lantern_and_its_tests_stand_from_then_on() -> void:
	assert_str(LanternRules.lantern_of(catalog, "big-oven")).is_equal("loaves")
	var town := LanternReference.town(catalog, "python", 7)
	assert_str(LanternRules.standing(catalog, town).loaves).is_equal("loaves")
	town.solved["big-oven"] = {"day": 3}
	assert_str(LanternRules.standing(catalog, town).loaves).is_equal("big-oven")
	var ids := LanternRules.night_cases(catalog, town).map(func(c: Dictionary) -> String: return c.letter)
	assert_array(ids).contains(["big-oven"]).not_contains(["loaves"])


func test_the_night_watch_darkens_what_broke_and_holds_the_day() -> void:
	var town := LanternReference.town(catalog, "python", 3)
	var cases := LanternRules.night_cases(catalog, town)
	var results := _passing(cases)
	results[0].status = "error"
	var broken := LanternRules.night_watch(catalog, town, results)
	var lantern := LanternRules.lantern_of(catalog, String(cases[0].letter))
	assert_str(broken.town.lanterns[lantern]).is_equal(LanternRules.DARK)
	assert_array(broken.report.dark).contains_exactly([lantern])
	assert_int(broken.town.day).is_equal(1)
	assert_bool(broken.report.new_day).is_false()
	var fixed := LanternRules.night_watch(catalog, broken.town, _passing(cases))
	assert_array(fixed.report.relit).contains_exactly([lantern])
	assert_int(fixed.town.day).is_equal(2)
	assert_bool(fixed.report.new_day).is_true()
	assert_int((fixed.town.nights as Array).size()).is_equal(2)


func test_a_dark_lantern_is_relit_only_by_the_tests_that_stand_for_it() -> void:
	var town := LanternReference.town(catalog, "python", 8)
	town.lanterns.loaves = LanternRules.DARK
	var old := LanternRules.record_run(
		catalog, town, "loaves", _passing(LanternRules.letter_cases(catalog, "loaves", "python"))
	)
	assert_str(old.town.lanterns.loaves).is_equal(LanternRules.DARK)
	var current := LanternRules.record_run(
		catalog, town, "big-oven", _passing(LanternRules.letter_cases(catalog, "big-oven", "python"))
	)
	assert_bool(current.relit).is_true()
	assert_str(current.town.lanterns.loaves).is_equal(LanternRules.LIT)


func test_the_last_night_with_everything_answered_completes_the_town() -> void:
	var town := LanternReference.town(catalog, "python")
	var night := LanternRules.night_watch(catalog, town, _passing(LanternRules.night_cases(catalog, town)))
	assert_bool(night.town.complete).is_true()
	assert_int(night.town.day).is_equal(LanternRules.last_day(catalog))


func test_the_night_keeps_yesterday_and_a_file_can_be_put_back() -> void:
	var town := LanternReference.town(catalog, "python", 3)
	var night := LanternRules.night_watch(catalog, town, _passing(LanternRules.night_cases(catalog, town)))
	var changed := LanternRules.set_file(night.town, "post", "oops")
	var restored := LanternRules.restore(changed, "post")
	assert_bool(restored.ok).is_true()
	assert_str(restored.town.files.post).is_equal(town.files.post)
	assert_bool(LanternRules.restore(changed, "nowhere").ok).is_false()


func test_a_workshop_of_your_own_needs_a_good_free_name() -> void:
	var town := LanternRules.new_town("python")
	assert_bool(LanternRules.add_module(town, "helpers").ok).is_true()
	assert_bool(LanternRules.add_module(town, "Helpers").ok).is_false()
	assert_bool(LanternRules.add_module(town, "math").ok).is_false()
	var built: Dictionary = LanternRules.add_module(town, "helpers").town
	assert_bool(LanternRules.add_module(built, "helpers").ok).is_false()


func test_hints_climb_a_ladder_of_three() -> void:
	var town := LanternRules.new_town("python")
	for i in 5:
		town = LanternRules.take_hint(town, "loaves")
	assert_int(town.hints.loaves).is_equal(3)


func test_the_layout_reads_houses_lanterns_and_bridges_from_the_code() -> void:
	var town := LanternReference.town(catalog, "python")
	town = LanternRules.add_module(town, "helpers").town
	var layout := LanternLayout.of(catalog, town)
	var modules := (layout.houses as Array).map(func(h: Dictionary) -> String: return h.module)
	assert_array(modules).contains_exactly(["lamps", "bakery", "post", "market", "mill", "festival", "helpers"])
	var helpers: Dictionary = layout.houses[6]
	assert_bool(helpers.own).is_true()
	var bakery: Dictionary = layout.houses[1]
	assert_int((bakery.lanterns as Array).size()).is_equal(1)
	var bridges := (layout.bridges as Array).map(func(b: Dictionary) -> String: return "%s>%s" % [b.from, b.to])
	assert_array(bridges).contains_exactly_in_any_order(
		["market>bakery", "festival>bakery", "festival>lamps", "festival>post"]
	)
