extends GdUnitTestSuite
## The style tables of a legendary look (docs/LEGENDARY_LOOKS.md, "Styles by role and cast"). The expected values are
## the contract's, written out here, so these tests do not read the very tables they check.

const ELEMENT := Color(0.1, 0.2, 0.3)
const APPROX := 0.000001
## Every role a bolt may carry: the six styled roles, the utility role, no role, and a role no table knows.
const ALL_ROLES: Array[String] = [
	"strike", "guard", "source", "shape", "order", "import", "utility", "", "unknown-role"
]
const SIGNATURE_CARDS: Array[String] = ["radix-sort", "quickselect", "memo-ward"]
const SPREAD := {"strike": 0.24, "guard": 0.14, "source": 0.30, "shape": 0.22, "order": 0.12, "import": 0.26}
const TINT := {
	"strike": "#ff9a3c",
	"guard": "#5ff2d0",
	"source": "#9dff5c",
	"shape": "#b98cff",
	"order": "#6fd6ff",
	"import": "#ffe066",
}
## Rider seeds worked out apart from the code: FNV-1a over the joined text's bytes, finished by the splitmix32 finaliser
## and masked to 31 bits, in Python.
const SEED_4_3_RADIX := 1203133307
const SEED_0_0_EMPTY := 1643974343
const SEED_12_1_FORK := 822409384


func test_unit_is_in_zero_to_one_for_any_seed_and_k() -> void:
	for seed_value: int in [0, 1, 123456, 0x7FFFFFFF, -7]:
		for k: int in range(0, 32):
			var value := LegendaryLook.unit(seed_value, k)
			var label := "seed %d, k %d gave %f" % [seed_value, k, value]
			assert_bool(value >= 0.0 and value < 1.0).override_failure_message(label).is_true()


func test_unit_is_deterministic() -> void:
	for k: int in range(0, 16):
		assert_float(LegendaryLook.unit(42, k)).is_equal(LegendaryLook.unit(42, k))


func test_unit_differs_by_k_and_by_seed() -> void:
	var values: Array[float] = []
	for k: int in range(0, 16):
		values.append(LegendaryLook.unit(42, k))
	assert_int(_distinct_count(values)).is_equal(16)
	assert_bool(LegendaryLook.unit(1, 0) != LegendaryLook.unit(2, 0)).is_true()


func test_unit_spreads_across_the_range() -> void:
	var low := false
	var high := false
	for k: int in range(0, 200):
		var value := LegendaryLook.unit(7, k)
		low = low or value < 0.1
		high = high or value > 0.9
	assert_bool(low and high).override_failure_message("200 draws never reached both ends of [0, 1)").is_true()


func test_rider_seed_is_a_non_negative_31_bit_number() -> void:
	for card: String in ["", "fork-bomb", "radix-sort", "strike-card"]:
		for index: int in range(0, 20):
			var value := LegendaryLook.rider_seed(3, index, card)
			var label := "%s / %d = %d" % [card, index, value]
			assert_bool(value >= 0 and value <= 0x7FFFFFFF).override_failure_message(label).is_true()


func test_rider_seed_is_the_worked_hash() -> void:
	# Fixed answers: a change to the hash, or to how the three parts are joined, fails here.
	assert_int(LegendaryLook.rider_seed(4, 3, "radix-sort")).is_equal(SEED_4_3_RADIX)
	assert_int(LegendaryLook.rider_seed(0, 0, "")).is_equal(SEED_0_0_EMPTY)
	assert_int(LegendaryLook.rider_seed(12, 1, "fork-bomb")).is_equal(SEED_12_1_FORK)


func test_rider_seed_repeats_for_the_same_inputs() -> void:
	for index: int in range(0, 8):
		var first := LegendaryLook.rider_seed(5, index, "quickselect")
		assert_int(LegendaryLook.rider_seed(5, index, "quickselect")).is_equal(first)


func test_rider_seed_differs_by_index() -> void:
	var seeds: Array[int] = []
	for index: int in range(0, 10):
		seeds.append(LegendaryLook.rider_seed(4, index, "radix-sort"))
	assert_int(_distinct_count(seeds)).is_equal(10)


func test_rider_seed_differs_by_card_and_by_cast() -> void:
	var by_card: Array[int] = []
	for card: String in ["", "radix-sort", "quickselect", "memo-ward", "fork-bomb", "strike-card"]:
		by_card.append(LegendaryLook.rider_seed(4, 0, card))
	assert_int(_distinct_count(by_card)).is_equal(6)
	var by_cast: Array[int] = []
	for cast_serial: int in range(1, 7):
		by_cast.append(LegendaryLook.rider_seed(cast_serial, 0, "radix-sort"))
	assert_int(_distinct_count(by_cast)).is_equal(6)


func test_the_signature_cards_are_radix_sort_quickselect_and_memo_ward() -> void:
	for card: String in SIGNATURE_CARDS:
		assert_bool(LegendaryLook.is_signature(card)).override_failure_message(card).is_true()
	for card: String in ["radix", "fork-bomb", "fire", "Radix-Sort", "", "memo ward"]:
		assert_bool(LegendaryLook.is_signature(card)).override_failure_message(card).is_false()


func test_each_role_has_its_spread() -> void:
	for role: String in SPREAD:
		var expected: float = SPREAD[role]
		assert_float(LegendaryLook.spread_of(role)).override_failure_message(role).is_equal_approx(expected, APPROX)
		var style := LegendaryLook.bolt_style(role, "", 1, ELEMENT)
		assert_float(float(style["spread"])).override_failure_message(role).is_equal_approx(expected, APPROX)


func test_a_role_with_no_spread_takes_the_default() -> void:
	for role: String in ["utility", "", "unknown-role"]:
		var style := LegendaryLook.bolt_style(role, "", 1, ELEMENT)
		assert_float(LegendaryLook.spread_of(role)).override_failure_message(role).is_equal_approx(0.20, APPROX)
		assert_float(float(style["spread"])).override_failure_message(role).is_equal_approx(0.20, APPROX)


func test_a_bolt_style_has_exactly_its_four_keys() -> void:
	var style := LegendaryLook.bolt_style("strike", "radix-sort", 0, ELEMENT)
	assert_int(style.size()).is_equal(4)
	for key: String in ["count", "spread", "prism", "colour"]:
		assert_bool(style.has(key)).override_failure_message(key).is_true()


func test_a_signature_card_hits_five_star_points_for_every_role_and_seed() -> void:
	for card: String in SIGNATURE_CARDS:
		for role: String in ALL_ROLES:
			for seed_value: int in range(0, 6):
				var style := LegendaryLook.bolt_style(role, card, seed_value, ELEMENT)
				var label := "%s / %s, seed %d" % [role, card, seed_value]
				assert_int(int(style["count"])).override_failure_message(label).is_equal(5)


func test_any_other_bolt_hits_four_or_five_star_points_by_its_seed() -> void:
	# The count reads bit 2 of the seed (see LegendaryLook.bolt_style), the bit the prism rule does not read.
	for role: String in ALL_ROLES:
		for card: String in ["", "fork-bomb", "strike-card"]:
			for seed_value: int in range(0, 12):
				var style := LegendaryLook.bolt_style(role, card, seed_value, ELEMENT)
				var label := "%s / %s, seed %d" % [role, card, seed_value]
				assert_int(int(style["count"])).override_failure_message(label).is_equal(4 + ((seed_value >> 2) & 1))


func test_a_negative_seed_still_takes_a_valid_count_and_prism_rule() -> void:
	# Negative seeds follow the same rules: -4 and -8 are prism seeds (their two lowest bits are 0) with bit 2 set and
	# clear; -3 is no prism, and its bit 2 is set.
	var five := LegendaryLook.bolt_style("", "fork-bomb", -4, ELEMENT)
	assert_int(int(five["count"])).is_equal(5)
	assert_bool(bool(five["prism"])).is_true()
	var four := LegendaryLook.bolt_style("", "fork-bomb", -8, ELEMENT)
	assert_int(int(four["count"])).is_equal(4)
	assert_bool(bool(four["prism"])).is_true()
	var odd := LegendaryLook.bolt_style("", "fork-bomb", -3, ELEMENT)
	assert_int(int(odd["count"])).is_equal(5)
	assert_bool(bool(odd["prism"])).is_false()


func test_a_non_signature_prism_bolt_can_have_five_stars() -> void:
	# Seed 4 is a prism bolt with bit 2 set: five stars. Seed 0 is a prism bolt with bit 2 clear: four.
	var five := LegendaryLook.bolt_style("", "fork-bomb", 4, ELEMENT)
	assert_bool(bool(five["prism"])).is_true()
	assert_int(int(five["count"])).is_equal(5)
	var four := LegendaryLook.bolt_style("", "fork-bomb", 0, ELEMENT)
	assert_bool(bool(four["prism"])).is_true()
	assert_int(int(four["count"])).is_equal(4)


func test_prism_bolts_take_both_four_and_five_stars() -> void:
	var counts: Array[int] = []
	for seed_value: int in range(0, 64, 4):
		var style := LegendaryLook.bolt_style("", "fork-bomb", seed_value, ELEMENT)
		counts.append(int(style["count"]))
	assert_bool(counts.has(4) and counts.has(5)).override_failure_message(str(counts)).is_true()


func test_bolts_of_one_cast_do_not_alternate_their_stars() -> void:
	# Consecutive bolts must not alternate their stars in a fixed pattern; the finaliser keeps the counts mixed.
	var counts: Array[int] = []
	var prisms: Array[bool] = []
	for index: int in range(0, 16):
		var seed_value := LegendaryLook.rider_seed(4, index, "fork-bomb")
		var style := LegendaryLook.bolt_style("", "fork-bomb", seed_value, ELEMENT)
		counts.append(int(style["count"]))
		prisms.append(bool(style["prism"]))
	var repeats := 0
	for i: int in range(1, counts.size()):
		if counts[i] == counts[i - 1]:
			repeats += 1
	assert_bool(repeats > 0).override_failure_message("star counts alternate: %s" % str(counts)).is_true()
	assert_bool(counts.has(4) and counts.has(5)).override_failure_message("one count only: %s" % str(counts)).is_true()
	var period_four := true
	for i: int in range(0, 12):
		if prisms[i] != prisms[i + 4]:
			period_four = false
	assert_bool(period_four).override_failure_message("prism repeats every four: %s" % str(prisms)).is_false()


func test_a_signature_card_is_prismatic_whatever_the_seed() -> void:
	for card: String in SIGNATURE_CARDS:
		for role: String in ALL_ROLES:
			for seed_value: int in range(0, 4):
				var style := LegendaryLook.bolt_style(role, card, seed_value, ELEMENT)
				assert_bool(bool(style["prism"])).override_failure_message("%s / %s" % [role, card]).is_true()


func test_one_other_bolt_in_four_is_prismatic() -> void:
	for card: String in ["", "fork-bomb", "strike-card"]:
		for role: String in ALL_ROLES:
			for seed_value: int in range(0, 12):
				var style := LegendaryLook.bolt_style(role, card, seed_value, ELEMENT)
				var label := "%s / %s, seed %d" % [role, card, seed_value]
				assert_bool(bool(style["prism"])).override_failure_message(label).is_equal(seed_value % 4 == 0)


func test_each_role_takes_its_tint() -> void:
	for role: String in TINT:
		var style := LegendaryLook.bolt_style(role, "", 1, ELEMENT)
		assert_that(style["colour"]).override_failure_message(role).is_equal(Color(String(TINT[role])))


func test_a_bolt_with_no_role_keeps_the_element_colour() -> void:
	for role: String in ["utility", "", "unknown-role"]:
		for card: String in ["", "fork-bomb", "radix-sort", "quickselect"]:
			var style := LegendaryLook.bolt_style(role, card, 2, ELEMENT)
			assert_that(style["colour"]).override_failure_message("%s / %s" % [role, card]).is_equal(ELEMENT)


func test_a_signature_bolt_takes_its_role_spread_and_tint_with_five_stars() -> void:
	# A strike cast by radix-sort: the strike's spread and tint, five star points, and prismatic as a signature is.
	var style := LegendaryLook.bolt_style("strike", "radix-sort", 0, ELEMENT)
	assert_int(int(style["count"])).is_equal(5)
	assert_float(float(style["spread"])).is_equal_approx(0.24, APPROX)
	assert_bool(bool(style["prism"])).is_true()
	assert_that(style["colour"]).is_equal(Color("#ff9a3c"))


func test_a_prism_core_is_the_warm_white() -> void:
	assert_that(LegendaryLook.PRISM_CORE).is_equal(Color("#fff6e0"))


func test_every_program_role_is_styled_or_the_utility_role() -> void:
	for role: String in ProgramSchemas.ROLES:
		var styled := SPREAD.has(role) or role == "utility"
		assert_bool(styled).override_failure_message(role).is_true()
	for role: String in SPREAD:
		assert_bool(ProgramSchemas.ROLES.has(role)).override_failure_message(role).is_true()


## The contract's base impact.
func _base() -> Dictionary:
	return {
		"bands": 6,
		"spin": 0.6,
		"tilt": 0.45,
		"jets": true,
		"lens": 0.6,
		"hue": 0.0,
		"photon_sides": 0,
		"arms": 0,
		"scanlines": false,
		"digits": 0,
		"split": false,
		"cells": false,
		"rings": 1,
	}


## The base impact with the given changes, as the contract words a role or a signature card.
func _impact(changes: Dictionary) -> Dictionary:
	var expected := _base()
	expected.merge(changes, true)
	return expected


## How many different values a list holds.
func _distinct_count(values: Array) -> int:
	var seen := {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()


func test_the_base_impact_is_the_contract_base() -> void:
	assert_dict(LegendaryLook.impact_style("", "")).is_equal(_base())
	assert_int(LegendaryLook.impact_style("", "").size()).is_equal(13)
	# The utility role and a role no table knows change nothing.
	assert_dict(LegendaryLook.impact_style("utility", "")).is_equal(_base())
	assert_dict(LegendaryLook.impact_style("unknown-role", "")).is_equal(_base())


func test_each_role_has_its_impact_variant() -> void:
	var variants := {
		"strike": {"tilt": 0.6, "bands": 4, "lens": 0.9, "hue": 0.04},
		"guard": {"rings": 3, "jets": false, "bands": 3, "lens": 1.0, "hue": 0.5},
		"source": {"arms": 4, "bands": 8, "spin": 1.0, "jets": false, "lens": 0.4, "hue": 0.3},
		"shape": {"photon_sides": 6, "jets": false, "bands": 6, "lens": 0.5, "hue": 0.7},
		"order": {"scanlines": true, "bands": 12, "jets": false, "lens": 0.3, "hue": 0.55},
		"import": {"arms": 2, "rings": 2, "lens": 0.5, "hue": 0.15},
	}
	for role: String in variants:
		var changes: Dictionary = variants[role]
		assert_dict(LegendaryLook.impact_style(role, "")).override_failure_message(role).is_equal(_impact(changes))


func test_each_signature_card_adds_its_feature() -> void:
	assert_dict(LegendaryLook.impact_style("", "radix-sort")).is_equal(_impact({"digits": 10}))
	assert_dict(LegendaryLook.impact_style("", "quickselect")).is_equal(_impact({"split": true, "jets": true}))
	assert_dict(LegendaryLook.impact_style("", "memo-ward")).is_equal(_impact({"cells": true, "rings": 2}))
	# An unknown role does not stop the card's feature.
	assert_dict(LegendaryLook.impact_style("unknown-role", "radix-sort")).is_equal(_impact({"digits": 10}))


func test_a_signature_card_wins_over_its_role_where_they_clash() -> void:
	# A guard turns the jets off and has three rings. quickselect turns the jets on; memo-ward has two rings.
	var guard_quickselect := {"rings": 3, "jets": true, "bands": 3, "lens": 1.0, "hue": 0.5, "split": true}
	assert_dict(LegendaryLook.impact_style("guard", "quickselect")).is_equal(_impact(guard_quickselect))
	var guard_memo := {"rings": 2, "jets": false, "bands": 3, "lens": 1.0, "hue": 0.5, "cells": true}
	assert_dict(LegendaryLook.impact_style("guard", "memo-ward")).is_equal(_impact(guard_memo))
	# A source and radix-sort do not clash: the source's changes, and the digits.
	var source_radix := {"arms": 4, "bands": 8, "spin": 1.0, "jets": false, "lens": 0.4, "hue": 0.3, "digits": 10}
	assert_dict(LegendaryLook.impact_style("source", "radix-sort")).is_equal(_impact(source_radix))


func test_an_impact_is_a_fresh_copy_the_caller_can_change() -> void:
	var strike := {"tilt": 0.6, "bands": 4, "lens": 0.9, "hue": 0.04}
	var changed := LegendaryLook.impact_style("strike", "")
	changed["bands"] = 99
	assert_dict(LegendaryLook.impact_style("strike", "")).is_equal(_impact(strike))
