extends GdUnitTestSuite
## StudioCatalog: the catalog's coverage problems, footprint classes, the category tree, families and the Recent list.
## Plain data in, plain data out; the real catalog is checked against the art in test/content/catalog_test.gd.


func test_line_pairs_require_both_directions_and_matching_single_cell_props() -> void:
	var assets := {
		"wall": _entry("Wall", "prop", "nature", "rocks"),
		"wall_v": _entry("Wall vertical", "prop", "nature", "rocks"),
	}
	assets.wall["line"] = {"horizontal": "wall", "vertical": "wall_v"}
	var pictures := _pictures(["wall", "wall_v"])
	assert_array(StudioCatalog.coverage(assets, _categories(), pictures, _people())).is_empty()
	assets.wall.line.vertical = "missing"
	assert_array(StudioCatalog.coverage(assets, _categories(), pictures, _people())).is_equal(["wall: line vertical names no entry"])
	assets.wall.line.vertical = "wall_v"
	assets.wall_v["size"] = [2, 1]
	assert_array(StudioCatalog.coverage(assets, _categories(), pictures, _people())).is_equal(["wall: line vertical must name a 1 x 1 prop"])
	assets.wall.line = "broken"
	assert_array(StudioCatalog.coverage(assets, _categories(), pictures, _people())).is_equal(["wall: line must name horizontal and vertical pieces"])


static func _entry(name: String, kind: String, category: String, subcategory: String) -> Dictionary:
	return {"name": name, "kind": kind, "category": category, "subcategory": subcategory, "place": ["outdoor"]}


static func _categories() -> Array:
	return [
		{"id": "buildings", "name": "Buildings", "subcategories": [{"id": "civic", "name": "Civic"}]},
		{
			"id": "nature",
			"name": "Nature",
			"subcategories": [{"id": "trees", "name": "Trees"}, {"id": "rocks", "name": "Rocks"}],
		},
		{"id": "street", "name": "Street", "subcategories": [{"id": "signs", "name": "Signs"}]},
		{"id": "people", "name": "People", "subcategories": [{"id": "townsfolk", "name": "Townsfolk"}]},
	]


static func _pictures(world: Array = [], props: Array = [], buildings: Array = []) -> Dictionary:
	return {"world": world, "props": props, "buildings": buildings}


static func _people(ids: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids:
		out.append(id)
	return out


func test_coverage_is_empty_when_every_picture_and_townsperson_has_one_valid_entry() -> void:
	var assets: Dictionary = {
		"hall": _entry("Hall", "building", "buildings", "civic"),
		"oak": _entry("Oak", "prop", "nature", "trees"),
		"rock": _entry("Rock", "prop", "nature", "rocks"),
		"pip": _entry("Pip", "person", "people", "townsfolk"),
		"gate": {"name": "Gate", "kind": "warp", "category": "street", "subcategory": "signs"},
	}
	var pictures := _pictures(["hall"], ["oak", "rock"], ["hall"])

	assert_array(StudioCatalog.coverage(assets, _categories(), pictures, _people(["pip"]))).is_empty()


func test_a_picture_with_no_entry_gives_one_line_per_folder_it_is_in() -> void:
	var assets: Dictionary = {"oak": _entry("Oak", "prop", "nature", "trees")}
	var pictures := _pictures(["bush"], ["oak", "bush"], [])

	assert_array(StudioCatalog.coverage(assets, _categories(), pictures, _people())).is_equal(
		["picture bush (props) has no catalog entry", "picture bush (world) has no catalog entry"]
	)


func test_a_townsperson_with_no_entry_is_a_problem() -> void:
	var assets: Dictionary = {"pip": _entry("Pip", "person", "people", "townsfolk")}

	assert_array(StudioCatalog.coverage(assets, _categories(), _pictures(), _people(["pip", "vell"]))).is_equal(
		["townsperson vell has no catalog entry"]
	)


func test_a_person_entry_that_is_not_a_townsperson_is_a_problem() -> void:
	var assets: Dictionary = {"ghost": _entry("Ghost", "person", "people", "townsfolk")}

	assert_array(StudioCatalog.coverage(assets, _categories(), _pictures(), _people())).is_equal(
		["ghost is a person entry but not a townsperson"]
	)


func test_a_building_prop_or_sign_must_name_a_picture_and_markers_need_none() -> void:
	var assets: Dictionary = {
		"lost": _entry("Lost", "prop", "nature", "trees"),
		"board": _entry("Board", "sign", "street", "signs"),
		"gate": _entry("Gate", "warp", "street", "signs"),
		"start": _entry("Start", "start", "street", "signs"),
		"trigger": _entry("Trigger", "trigger", "street", "signs"),
	}

	assert_array(StudioCatalog.coverage(assets, _categories(), _pictures([], ["board"]), _people())).is_equal(
		["lost names no picture"]
	)


func test_missing_or_empty_fields_are_named() -> void:
	var assets: Dictionary = {
		"no-name": {"kind": "prop", "category": "nature", "subcategory": "trees"},
		"blank-kind": {"name": "Blank", "kind": "", "category": "nature", "subcategory": "trees"},
		"no-category": {"name": "Nameless", "kind": "warp", "subcategory": "trees"},
		"no-subcategory": {"name": "Odd", "kind": "warp", "category": "nature", "subcategory": "  "},
	}

	assert_array(StudioCatalog.coverage(assets, _categories(), _pictures([], ["no-name"]), _people())).is_equal([
		"blank-kind: missing kind",
		"no-category: missing category",
		"no-name: missing name",
		"no-subcategory: missing subcategory",
	])


func test_unknown_categories_and_subcategories_are_named() -> void:
	var assets: Dictionary = {
		"oak": {"name": "Oak", "kind": "warp", "category": "forest", "subcategory": "trees"},
		"rock": {"name": "Rock", "kind": "warp", "category": "nature", "subcategory": "caves"},
	}

	assert_array(StudioCatalog.coverage(assets, _categories(), _pictures(), _people())).is_equal([
		"oak: unknown category forest",
		"rock: unknown subcategory caves in nature",
	])


func test_an_entry_that_is_not_an_object_is_named() -> void:
	var assets: Dictionary = {"broken": "oops", "null-entry": null}

	assert_array(StudioCatalog.coverage(assets, _categories(), _pictures(), _people())).is_equal(
		["broken: not an object", "null-entry: not an object"]
	)


func test_malformed_inputs_are_skipped_and_do_not_crash() -> void:
	var assets: Dictionary = {
		3: _entry("Non-string id", "prop", "nature", "trees"),
		"oak": 5,
		"tree": _entry("Tree", "prop", "nature", "trees"),
	}
	var pictures := {"world": "oak", "props": [3, "oak", "tree"], "buildings": null}
	var categories: Array = [5, {"id": 7}, {"id": "nature", "subcategories": "x"}]

	assert_array(StudioCatalog.coverage(assets, categories, pictures, _people())).is_equal(
		["oak: not an object", "tree: unknown subcategory trees in nature"]
	)


func test_footprint_class_names_the_four_small_footprints() -> void:
	assert_str(StudioCatalog.footprint_class([1, 1])).is_equal("1x1")
	assert_str(StudioCatalog.footprint_class([2.0, 1.0])).is_equal("2x1")
	assert_str(StudioCatalog.footprint_class([1, 2])).is_equal("1x2")
	assert_str(StudioCatalog.footprint_class([2, 2])).is_equal("2x2")
	assert_str(StudioCatalog.footprint_class(Vector2i(2, 1))).is_equal("2x1")


func test_any_other_valid_size_is_bigger() -> void:
	assert_str(StudioCatalog.footprint_class([3, 1])).is_equal("bigger")
	assert_str(StudioCatalog.footprint_class([5.0, 5.0])).is_equal("bigger")
	assert_str(StudioCatalog.footprint_class(Vector2i(1, 4))).is_equal("bigger")


func test_a_missing_or_malformed_size_is_one_by_one() -> void:
	var sizes: Array = [null, [], [2], [2, 2, 2], "2x2", [2.5, 1], [0, 2], [-1, 1], ["2", 2], [true, 1], Vector2i(0, 0)]
	for size: Variant in sizes:
		assert_str(StudioCatalog.footprint_class(size)).override_failure_message("size %s" % [size]).is_equal("1x1")


func test_tree_lists_categories_and_subcategories_that_have_entries_in_the_given_order() -> void:
	var categories: Array = [
		{
			"id": "street",
			"name": "Street",
			"subcategories": [{"id": "signs", "name": "Signs"}, {"id": "benches", "name": "Benches"}],
		},
		{"id": "nature", "name": "Nature", "subcategories": [{"id": "trees", "name": "Trees"}, {"id": "rocks", "name": "Rocks"}]},
		{"id": "empty", "name": "Empty", "subcategories": [{"id": "none", "name": "None"}]},
	]
	var entries: Dictionary = {
		"oak": _entry("Oak", "prop", "nature", "trees"),
		"oak2": _entry("Oak 2", "prop", "nature", "trees"),
		"sign": _entry("Sign", "prop", "street", "signs"),
	}

	assert_array(StudioCatalog.tree(categories, entries)).is_equal([
		{"id": "street", "name": "Street", "count": 1, "subcategories": [{"id": "signs", "name": "Signs", "count": 1}]},
		{"id": "nature", "name": "Nature", "count": 2, "subcategories": [{"id": "trees", "name": "Trees", "count": 2}]},
	])


func test_tree_names_default_to_the_id_and_entries_outside_the_tree_are_not_listed() -> void:
	var categories: Array = [{"id": "nature", "subcategories": [{"id": "trees"}]}]
	var entries: Dictionary = {
		"oak": _entry("Oak", "prop", "nature", "trees"),
		"lost": _entry("Lost", "prop", "elsewhere", "trees"),
		"bush": _entry("Bush", "prop", "nature", "bushes"),
	}

	assert_array(StudioCatalog.tree(categories, entries)).is_equal([
		{"id": "nature", "name": "nature", "count": 2, "subcategories": [{"id": "trees", "name": "trees", "count": 1}]},
	])


func test_families_list_variant_art_ids_in_entry_order_and_skip_entries_without_one() -> void:
	var entries: Dictionary = {
		"oak-z": {"name": "Round oak", "family": "oak"},
		"barrel": {"name": "Barrel"},
		"oak-a": {"name": "Tall oak", "family": "oak"},
		"cabbage": {"family": ""},
		"pine": {"family": "pine"},
	}

	assert_dict(StudioCatalog.families(entries)).is_equal({"oak": ["oak-z", "oak-a"], "pine": ["pine"]})


func test_variant_of_steps_through_the_family_and_wraps() -> void:
	var entries: Dictionary = {
		"cottage": {"family": "cottage"},
		"cottage-ivy": {"family": "cottage"},
		"cottage-6x6": {"family": "cottage"},
		"barrel": {"name": "Barrel"},
		"pine": {"family": "pine"},
	}

	assert_str(StudioCatalog.variant_of(entries, "cottage", 1)).is_equal("cottage-ivy")
	assert_str(StudioCatalog.variant_of(entries, "cottage-6x6", 1)).is_equal("cottage")
	assert_str(StudioCatalog.variant_of(entries, "cottage", -1)).is_equal("cottage-6x6")
	assert_str(StudioCatalog.variant_of(entries, "cottage-ivy", 2)).is_equal("cottage")
	assert_str(StudioCatalog.variant_of(entries, "barrel", 1)).is_equal("")
	assert_str(StudioCatalog.variant_of(entries, "pine", 1)).is_equal("")
	assert_str(StudioCatalog.variant_of(entries, "unknown", 1)).is_equal("")
	assert_str(StudioCatalog.variant_of(entries, "cottage", 0)).is_equal("")


func test_keep_feet_holds_the_bottom_middle_cell() -> void:
	# A 5 x 5 at (10, 10) stands on (12, 14); as 6 x 6 it must still stand there: (12 - 3, 14 - 5).
	assert_that(StudioCatalog.keep_feet(Vector2i(10, 10), Vector2i(5, 5), Vector2i(6, 6))).is_equal(Vector2i(9, 9))
	assert_that(StudioCatalog.keep_feet(Vector2i(9, 9), Vector2i(6, 6), Vector2i(5, 5))).is_equal(Vector2i(10, 10))
	assert_that(StudioCatalog.keep_feet(Vector2i(4, 7), Vector2i.ONE, Vector2i.ONE)).is_equal(Vector2i(4, 7))
	assert_that(StudioCatalog.keep_feet(Vector2i(4, 7), Vector2i.ONE, Vector2i(2, 1))).is_equal(Vector2i(3, 7))


func test_remember_puts_the_art_first_without_duplicates() -> void:
	var recent: Array[String] = ["oak", "barrel", "bed"]

	assert_array(StudioCatalog.remember(recent, "barrel")).is_equal(["barrel", "oak", "bed"])
	assert_array(StudioCatalog.remember(recent, "cart")).is_equal(["cart", "oak", "barrel", "bed"])
	assert_array(StudioCatalog.remember(recent, "oak")).is_equal(["oak", "barrel", "bed"])
	var messy: Array[String] = ["oak", "", "oak", "bed"]
	assert_array(StudioCatalog.remember(messy, "bed")).is_equal(["bed", "oak"])


func test_remember_keeps_at_most_the_limit_and_the_default_is_twelve() -> void:
	var recent: Array[String] = ["a", "b", "c"]

	assert_array(StudioCatalog.remember(recent, "z", 3)).is_equal(["z", "a", "b"])
	assert_array(StudioCatalog.remember(recent, "z", 1)).is_equal(["z"])
	var long: Array[String] = []
	for index: int in 20:
		long.append("art-%d" % index)
	var kept := StudioCatalog.remember(long, "new")
	assert_int(kept.size()).is_equal(12)
	assert_str(kept[0]).is_equal("new")
	assert_str(kept[11]).is_equal("art-10")


func test_remember_with_an_empty_art_returns_a_copy_and_never_changes_the_input() -> void:
	var recent: Array[String] = ["oak", "barrel"]

	var copy := StudioCatalog.remember(recent, "")
	assert_array(copy).is_equal(["oak", "barrel"])
	copy.append("bed")
	assert_array(recent).is_equal(["oak", "barrel"])
	StudioCatalog.remember(recent, "bed")
	assert_array(recent).is_equal(["oak", "barrel"])
