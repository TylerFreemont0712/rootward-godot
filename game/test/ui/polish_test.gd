extends GdUnitTestSuite
## Regression coverage for tooltips escaping arena clipping, proportional creatures, and the live reference.


func test_hover_window_stays_on_screen_and_dies_with_its_source() -> void:
	var source := PanelContainer.new()
	source.position = get_viewport().get_visible_rect().size - Vector2(60, 50)
	source.custom_minimum_size = Vector2(40, 30)
	var info := HoverInfo.attach(source, "Deadlock", "Hit both locks with the same program.")
	add_child(source)
	source.mouse_entered.emit()
	await get_tree().create_timer(0.25).timeout
	var panel := info.get("_panel") as PanelContainer
	assert_object(panel).is_not_null()
	if panel != null:
		assert_float(panel.position.x).is_greater_equal(0.0)
		assert_float(panel.position.y).is_greater_equal(0.0)
		assert_float(panel.get_rect().end.x).is_less_equal(get_viewport().get_visible_rect().size.x)
	source.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(HoverInfo.active).is_null()


func test_creature_grows_with_arena_and_respects_available_width() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var foe := {
		"id": "tally-wisp",
		"uid": "wisp",
		"name": "Wisp",
		"sprite": "tally-wisp",
		"hp": 20,
		"max": 20,
		"shield": 0,
		"intent_index": 0,
		"intents": [],
		"weak": ["fire"],
		"resist": []
	}
	var view := FoeView.create(foe, catalog)
	add_child(view)
	view.fit_arena(400, 500)
	var small := view.sprite.size
	view.fit_arena(800, 1000)
	assert_float(view.sprite.size.y).is_equal_approx(small.y * 2.0, 0.1)
	view.fit_arena(800, 120)
	assert_float(view.sprite_width()).is_less_equal(120.1)
	view.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func test_archive_filters_new_constants_and_exposes_upgrades() -> void:
	var catalog: Dictionary = ContentLoader.load_shardrun().catalog
	var archive := ArchivePanel.create(catalog)
	add_child(archive)
	archive.set("_query", "constant")
	archive.set("_role", "const")
	archive.call("_refresh")
	var list := archive.get("_list") as VBoxContainer
	assert_int(list.get_child_count()).is_equal(4)
	archive.set("_upgraded", true)
	archive.call("_show_entry", catalog.programs.cards["fire-constant"])
	var labels := archive.find_children("*", "Label", true, false)
	assert_bool(labels.any(func(label: Label) -> bool: return label.text == "Ember Constant+")).is_true()
	archive.set("_query", "no-such-card-123")
	archive.call("_refresh")
	assert_int(list.get_child_count()).is_equal(0)
	archive.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
