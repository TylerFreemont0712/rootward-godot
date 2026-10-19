extends GdUnitTestSuite
## B01 classification fixture: metadata owns construction groups, even when the displayed name is misleading.


func _fixture() -> Dictionary:
	return {
		"shell": {"kind": "building", "name": "An oak", "category": "buildings", "subcategory": "homes"},
		"rail": {"kind": "prop", "name": "A house door", "category": "street", "subcategory": "fences_and_gates", "family": "fence"},
		"opening": {"kind": "prop", "name": "A wall", "category": "street", "subcategory": "fences_and_gates", "family": "gate"},
		"arch": {"kind": "prop", "category": "street", "subcategory": "fences_and_gates", "family": "expand-gate"},
		"seat": {"kind": "prop", "category": "furniture", "place": ["indoor"]},
		"mat": {"kind": "prop", "category": "furniture", "place": ["indoor"], "solid": false, "draw_layer": "ground"},
		"tree": {"kind": "prop", "name": "Gate wall house", "category": "nature", "place": ["outdoor"]},
		"person": {"kind": "person", "category": "people"},
		"unknown": {"kind": "prop", "name": "Fence"},
	}


func test_build_classification_uses_kind_category_and_exact_family_metadata() -> void:
	var expected := {"shell": "building", "rail": "boundary", "opening": "gate", "arch": "gate", "seat": "furniture", "mat": "furniture", "tree": "", "person": "", "unknown": ""}
	var entries := _fixture()
	var before := entries.duplicate(true)
	for id: String in expected:
		assert_str(StudioBuildCatalog.group(entries[id])).override_failure_message(id).is_equal(String(expected[id]))
	assert_dict(entries).is_equal(before)


func test_scope_precedes_recent_search_and_on_map_lists_without_mutating_either() -> void:
	var entries := _fixture()
	var filters := {"ids": ["tree", "rail", "opening", "shell"], "order": ["tree", "rail", "opening", "shell"]}
	var scope := {"build_groups": ["building", "gate"]}
	var before := filters.duplicate(true)
	assert_array(StudioCatalogFilter.query(entries, filters, scope)).is_equal(["opening", "shell"])
	assert_array(StudioCatalogFilter.query(entries, {"text": "house"}, scope)).is_empty()
	assert_array(StudioCatalogFilter.query(entries, {"ids": ["tree"]}, scope)).is_empty()
	assert_dict(filters).is_equal(before)
	assert_dict(scope).is_equal({"build_groups": ["building", "gate"]})
	assert_int(StudioCatalogFilter.query(entries).size()).is_equal(entries.size())


func test_real_catalog_has_complete_construction_views_and_preserves_template_defaults() -> void:
	var entries := StudioAssets.entries()
	var counts := {}
	for id: String in entries:
		var entry: Dictionary = entries[id]
		var group := StudioBuildCatalog.group(entry)
		counts[group] = int(counts.get(group, 0)) + 1
		if String(entry.get("kind", "")) == "building":
			assert_str(group).is_equal("building")
		if String(entry.get("subcategory", "")) == "fences_and_gates":
			assert_bool(group in ["gate", "boundary"]).override_failure_message(id).is_true()
	for group: String in ["building", "boundary", "gate", "furniture"]:
		assert_int(int(counts.get(group, 0))).override_failure_message(group).is_greater(0)
	for id: String in ["gate", "gate-wide-2", "gate-wide-3", "gate-wide-2-v", "expand-arched_wood_gate", "expand-iron_garden_gate"]:
		assert_str(StudioBuildCatalog.group(entries[id])).override_failure_message(id).is_equal("gate")
	assert_bool(bool(StudioAssets.template("rug").get("solid", true))).is_false()
	assert_str(String(StudioAssets.template("rug").draw_layer)).is_equal("ground")
	assert_bool(bool(StudioAssets.template("chair").get("solid", true))).is_true()
