extends GdUnitTestSuite


func test_no_filters_returns_entries_sorted_by_display_name_then_art_id() -> void:
	var entries: Dictionary = {
		"oak-z": {"name": "Oak", "kind": "prop"},
		"barrel": {"name": "Barrel", "kind": "prop"},
		"oak-a": {"name": "Oak", "kind": "prop"},
	}

	assert_array(StudioCatalogFilter.query(entries)).is_equal(["barrel", "oak-a", "oak-z"])


func test_search_matches_all_words_across_id_tags_category_and_subcategory() -> void:
	var entries: Dictionary = {
		"oak_tree": {
			"name": "Oak",
			"kind": "prop",
			"category": "nature",
			"subcategory": "bushes_and_flowers",
			"tags": ["round", "leafy"],
		}
	}

	assert_array(StudioCatalogFilter.query(entries, {"text": "OAK ROUND bushes flowers"})).is_equal(["oak_tree"])
	assert_array(StudioCatalogFilter.query(entries, {"text": "oak absent"})).is_empty()


func test_category_subcategory_place_kind_and_text_filters_combine() -> void:
	var entries: Dictionary = {
		"barrel": {
			"name": "Barrel",
			"kind": "prop",
			"category": "farm_and_work",
			"subcategory": "containers",
			"place": ["outdoor"],
			"tags": ["wood", "storage"],
		},
		"bed": {
			"name": "Bed",
			"kind": "prop",
			"category": "furniture",
			"subcategory": "beds",
			"place": ["indoor"],
			"tags": ["wood", "sleep"],
		},
		"cottage": {
			"name": "Cottage",
			"kind": "building",
			"category": "buildings",
			"subcategory": "homes",
			"place": ["outdoor"],
			"tags": ["wood", "home"],
		},
	}
	var filters: Dictionary = {
		"text": "wood",
		"category": "Farm and work",
		"subcategory": "containers",
		"place": "OUTDOOR",
		"kind": "prop",
	}

	assert_array(StudioCatalogFilter.query(entries, filters)).is_equal(["barrel"])
	assert_array(StudioCatalogFilter.query(entries, {"category": "buildings", "kind": "prop"})).is_empty()


func test_search_can_find_category_and_subcategory_ids_with_underscores() -> void:
	var entries: Dictionary = {
		"barrel": {
			"name": "Barrel",
			"kind": "prop",
			"category": "farm_and_work",
			"subcategory": "containers",
		}
	}

	assert_array(StudioCatalogFilter.query(entries, {"text": "farm work containers"})).is_equal(["barrel"])


func test_missing_tags_and_place_are_optional_and_safe() -> void:
	var entries: Dictionary = {"bare": {"name": "Bare", "kind": "prop"}}

	assert_array(StudioCatalogFilter.query(entries, {"text": "bare"})).is_equal(["bare"])
	assert_array(StudioCatalogFilter.query(entries, {"place": "indoor"})).is_empty()


func test_malformed_entries_and_optional_fields_do_not_crash() -> void:
	var entries: Dictionary = {
		"bad-tags-place": {"name": "A Name", "kind": "prop", "tags": "wood", "place": "outdoor"},
		"bad-name": {"name": 42, "kind": "prop", "tags": [42, null]},
		"not-an-entry": "broken",
		"null-entry": null,
		3: {"name": "Non-string id", "kind": "prop"},
	}

	assert_array(StudioCatalogFilter.query(entries)).is_equal(["bad-tags-place", "bad-name"])
	assert_array(StudioCatalogFilter.query(entries, {"place": "outdoor"})).is_empty()


func test_query_does_not_mutate_entries_or_filters() -> void:
	var entries: Dictionary = {
		"barrel": {
			"name": "Barrel",
			"kind": "prop",
			"tags": ["wood", "storage"],
			"place": ["outdoor"],
		}
	}
	var filters: Dictionary = {"text": "wood", "place": "outdoor"}
	var entries_before: Dictionary = entries.duplicate(true)
	var filters_before: Dictionary = filters.duplicate(true)

	StudioCatalogFilter.query(entries, filters)

	assert_dict(entries).is_equal(entries_before)
	assert_dict(filters).is_equal(filters_before)


## Five entries, in display-name order: barrel, bed, cottage, fence_v, sign. Each new key has something to pass and
## something to fail.
static func _sample() -> Dictionary:
	return {
		"barrel":
		{
			"name": "Barrel",
			"kind": "prop",
			"category": "farm_and_work",
			"subcategory": "containers",
			"place": ["outdoor"],
			"size": [1, 1],
			"draw_layer": "ground",
			"interactive": ["hook"],
			"source": "new",
		},
		"bed":
		{
			"name": "Bed",
			"kind": "prop",
			"category": "furniture",
			"subcategory": "beds",
			"place": ["indoor"],
			"size": [2, 1],
			"draw_layer": "over",
			"solid": true,
			"source": "new",
		},
		"cottage":
		{
			"name": "Cottage",
			"kind": "building",
			"category": "buildings",
			"subcategory": "homes",
			"place": ["outdoor", "indoor"],
			"size": [5, 5],
			"solid": false,
			"source": "old",
		},
		"fence_v":
		{
			"name": "Fence",
			"kind": "prop",
			"category": "street",
			"subcategory": "fences_and_gates",
			"place": ["outdoor"],
			"size": [3, 1],
			"solid": false,
			"interactive": {"lever": true},
			"source": "new",
		},
		"sign":
		{
			"name": "Sign",
			"kind": "prop",
			"category": "street",
			"subcategory": "signs_and_boards",
			"place": ["outdoor"],
			"size": [1, 2],
			"draw_layer": "ground",
			"solid": false,
			"interactive": "",
		},
	}


func test_places_key_passes_entries_that_list_any_of_the_values() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"places": ["indoor"]})).is_equal(["bed", "cottage"])
	assert_array(StudioCatalogFilter.query(entries, {"places": ["OUTDOOR"]})).is_equal(
		["barrel", "cottage", "fence_v", "sign"]
	)
	assert_array(StudioCatalogFilter.query(entries, {"places": ["indoor", "outdoor"]})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"places": ["attic"]})).is_empty()


func test_places_key_ignores_empty_and_non_array_values() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"places": []})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"places": "indoor"})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"places": null})).has_size(5)


func test_footprints_key_matches_the_footprint_class_any_of() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"footprints": ["1x1"]})).is_equal(["barrel"])
	assert_array(StudioCatalogFilter.query(entries, {"footprints": ["2x1", "1x2"]})).is_equal(["bed", "sign"])
	assert_array(StudioCatalogFilter.query(entries, {"footprints": ["bigger"]})).is_equal(["cottage", "fence_v"])
	assert_array(StudioCatalogFilter.query(entries, {"footprints": []})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"footprints": "bigger"})).has_size(5)


func test_footprints_key_treats_a_missing_size_as_one_by_one() -> void:
	var entries: Dictionary = {"plain": {"name": "Plain"}, "wide": {"name": "Wide", "size": [4, 1]}}

	assert_array(StudioCatalogFilter.query(entries, {"footprints": ["1x1"]})).is_equal(["plain"])
	assert_array(StudioCatalogFilter.query(entries, {"footprints": ["bigger"]})).is_equal(["wide"])


func test_solidity_key_is_walkable_only_when_solid_is_false() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"solidity": ["walkable"]})).is_equal(
		["cottage", "fence_v", "sign"]
	)
	assert_array(StudioCatalogFilter.query(entries, {"solidity": ["solid"]})).is_equal(["barrel", "bed"])
	assert_array(StudioCatalogFilter.query(entries, {"solidity": ["solid", "walkable"]})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"solidity": "walkable"})).has_size(5)


func test_solidity_key_reads_only_a_boolean_false_as_walkable() -> void:
	var entries: Dictionary = {"zero": {"name": "Zero", "solid": 0}}

	assert_array(StudioCatalogFilter.query(entries, {"solidity": ["walkable"]})).is_empty()
	assert_array(StudioCatalogFilter.query(entries, {"solidity": ["solid"]})).is_equal(["zero"])


func test_flat_key_keeps_only_ground_layer_entries() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"flat": true})).is_equal(["barrel", "sign"])
	assert_array(StudioCatalogFilter.query(entries, {"flat": false})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"flat": "yes"})).has_size(5)


func test_code_key_keeps_entries_with_a_non_empty_interactive_field() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"code": true})).is_equal(["barrel", "fence_v"])
	assert_array(StudioCatalogFilter.query(entries, {"code": false})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"code": "true"})).has_size(5)


func test_code_key_rejects_empty_and_non_collection_interactive_values() -> void:
	var entries: Dictionary = {
		"empty-list": {"name": "A", "interactive": []},
		"empty-object": {"name": "B", "interactive": {}},
		"blank-text": {"name": "C", "interactive": "   "},
		"zero": {"name": "D", "interactive": 0},
		"null": {"name": "E", "interactive": null},
		"text": {"name": "F", "interactive": "gate"},
	}

	assert_array(StudioCatalogFilter.query(entries, {"code": true})).is_equal(["text"])


func test_sources_key_matches_the_source_the_caller_adds() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"sources": ["new"]})).is_equal(
		["barrel", "bed", "fence_v"]
	)
	assert_array(StudioCatalogFilter.query(entries, {"sources": ["old"]})).is_equal(["cottage"])
	assert_array(StudioCatalogFilter.query(entries, {"sources": ["NEW"]})).is_equal(["barrel", "bed", "fence_v"])
	assert_array(StudioCatalogFilter.query(entries, {"sources": ["old", "new"]})).is_equal(
		["barrel", "bed", "cottage", "fence_v"]
	)
	assert_array(StudioCatalogFilter.query(entries, {"sources": []})).has_size(5)


func test_an_entry_with_no_source_never_passes_a_sources_filter() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"sources": ["new", "old"]})).not_contains(["sign"])
	assert_array(StudioCatalogFilter.query(entries, {"sources": ["new", "old"]})).has_size(4)


func test_ids_key_restricts_the_result_to_the_listed_art_ids() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"ids": ["sign", "barrel"]})).is_equal(["barrel", "sign"])
	assert_array(StudioCatalogFilter.query(entries, {"ids": ["barrel", "bed"], "text": "bed"})).is_equal(["bed"])
	assert_array(StudioCatalogFilter.query(entries, {"ids": [7, "sign"]})).is_equal(["sign"])


func test_an_empty_ids_key_shows_nothing_but_a_non_array_ids_key_is_ignored() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"ids": []})).is_empty()
	assert_array(StudioCatalogFilter.query(entries, {"ids": "barrel"})).has_size(5)
	assert_array(StudioCatalogFilter.query(entries, {"ids": null})).has_size(5)


func test_ids_are_matched_exactly_not_normalised() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"ids": ["fence v"]})).is_empty()
	assert_array(StudioCatalogFilter.query(entries, {"ids": ["fence_v"]})).is_equal(["fence_v"])


func test_order_key_puts_listed_ids_first_and_the_rest_in_the_default_order() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"order": ["sign", "cottage"]})).is_equal(
		["sign", "cottage", "barrel", "bed", "fence_v"]
	)
	assert_array(StudioCatalogFilter.query(entries, {"order": ["unknown-id", "fence_v"]})).is_equal(
		["fence_v", "barrel", "bed", "cottage", "sign"]
	)
	assert_array(StudioCatalogFilter.query(entries, {"order": ["bed", "bed", "sign"]})).is_equal(
		["bed", "sign", "barrel", "cottage", "fence_v"]
	)


func test_an_empty_or_non_array_order_key_keeps_the_default_order() -> void:
	var entries := _sample()
	var default_order := ["barrel", "bed", "cottage", "fence_v", "sign"]

	assert_array(StudioCatalogFilter.query(entries, {"order": []})).is_equal(default_order)
	assert_array(StudioCatalogFilter.query(entries, {"order": "sign"})).is_equal(default_order)


func test_order_applies_after_the_filters_pass() -> void:
	var entries := _sample()

	assert_array(StudioCatalogFilter.query(entries, {"kind": "prop", "order": ["sign", "cottage"]})).is_equal(
		["sign", "barrel", "bed", "fence_v"]
	)


func test_new_keys_combine_with_each_other_and_with_the_old_keys() -> void:
	var entries := _sample()

	var outdoor_small_new := {
		"kind": "prop",
		"places": ["outdoor"],
		"footprints": ["1x1", "1x2"],
		"flat": true,
		"sources": ["new"],
	}
	assert_array(StudioCatalogFilter.query(entries, outdoor_small_new)).is_equal(["barrel"])
	var walkable_takes_code := {"solidity": ["walkable"], "places": ["outdoor"], "code": true}
	assert_array(StudioCatalogFilter.query(entries, walkable_takes_code)).is_equal(["fence_v"])
	var indoor_and_old := {"places": ["indoor"], "sources": ["old"]}
	assert_array(StudioCatalogFilter.query(entries, indoor_and_old)).is_equal(["cottage"])
	var text_and_new := {"text": "fence", "sources": ["new"], "footprints": ["bigger"], "kind": "prop"}
	assert_array(StudioCatalogFilter.query(entries, text_and_new)).is_equal(["fence_v"])


func test_malformed_values_for_the_new_keys_are_ignored() -> void:
	var entries := _sample()
	var filters := {
		"places": "indoor",
		"footprints": 3,
		"solidity": null,
		"flat": "yes",
		"code": "true",
		"sources": {"new": true},
		"ids": 42,
		"order": "sign",
	}

	assert_array(StudioCatalogFilter.query(entries, filters)).is_equal(
		["barrel", "bed", "cottage", "fence_v", "sign"]
	)


func test_the_new_keys_do_not_mutate_entries_or_filters() -> void:
	var entries := _sample()
	var filters := {
		"places": ["outdoor"],
		"footprints": ["1x1"],
		"solidity": ["walkable"],
		"flat": true,
		"code": true,
		"sources": ["new"],
		"ids": ["barrel", "fence_v", "sign"],
		"order": ["sign", "barrel"],
	}
	var entries_before: Dictionary = entries.duplicate(true)
	var filters_before: Dictionary = filters.duplicate(true)

	assert_array(StudioCatalogFilter.query(entries, filters)).is_empty()

	assert_dict(entries).is_equal(entries_before)
	assert_dict(filters).is_equal(filters_before)
