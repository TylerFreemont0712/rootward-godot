extends GdUnitTestSuite
## People, markers and the inspector's S6 sections (Concept/v0.3/10, sections 6, 8 and 9.4), on the mounted Studio: the
## catalog lists the townspeople and the Warp and Start cards with pictures, a person's ghost stands where the Walker
## draws them, selecting a person, a door or a warp fills the inspector's sections and their buttons send their signals,
## and with nothing selected the inspector shows the map and its two fields. Content, drafts and saves are isolated
## copies.

const TEST_ROOT := "user://studio_test/people"
const TOWN := "lanternroot"
const LOOK := {"outfit": "outfit/tunic", "hair": "hair/short", "colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal", "second": "cloth_cream", "accent": "cloth_orange"}}
const BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}
const WIDTH := 20
const HEIGHT := 16
## Indexes into the fixture's objects.
const PERSON := 0
const HOUSE := 1
const WARP := 2
const SHUT := 3

var screen: OverworldScreen
var studio: StudioMode
var _root := ""
var _old_drafts := ""
var _old_playtest := ""
var _old_content := ""
var _old_env := ""
var _old_catalog: Dictionary = {}


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	_old_drafts = StudioMode.drafts_dir
	_old_playtest = StudioMode.playtest_dir
	_old_content = StudioMode.content_dir
	_old_env = OS.get_environment("ROOTWARD_STUDIO")
	_old_catalog = OverworldScreen._catalog_cache
	StudioMode.drafts_dir = _root.path_join("drafts")
	StudioMode.playtest_dir = _root.path_join("playtest")
	StudioMode.content_dir = _root.path_join("content")
	_copy_tree("res://content/packs/core/overworld", StudioMode.content_dir.path_join("packs/core/overworld"))
	OS.set_environment("ROOTWARD_STUDIO", "1")
	Game.reset(_root.path_join("saves"))
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()
	assert_bool(StudioFiles.write_content(_path(TOWN), JsoncWriter.map_text("// People fixture\n", _fixture()))).is_true()
	OverworldScreen._catalog_cache = OverworldContent.load_world(StudioMode.content_dir).catalog
	var state := OverworldState.fresh(TOWN, Vector2i(2, 2), "down", BootsCode.JAVASCRIPT)
	state.look = LOOK.duplicate(true)
	state.name = "Land tester"
	state.flags = BEATS.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _frames(4)
	studio = screen.get("_studio") as StudioMode
	studio.set_editing(true)
	await _frames(2)
	await _frames(2)
	await _frames(1)


func after_test() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	Sound.silence()
	await _frames(6)
	Background.finish_all()
	Game.reset()
	StudioMode.drafts_dir = _old_drafts
	StudioMode.playtest_dir = _old_playtest
	StudioMode.content_dir = _old_content
	OverworldScreen._catalog_cache = _old_catalog
	StudioAssets.reload()
	OS.set_environment("ROOTWARD_STUDIO", _old_env)
	_remove_tree(_root)


func _path(id: String) -> String:
	return StudioSession.path_of(id, StudioMode.content_dir)


## A grass town 20 x 16 with Marta (the innkeeper), a house that leads to its room, a warp, and a shop with no door link.
func _fixture() -> Dictionary:
	var rows: Array[String] = []
	for y: int in HEIGHT:
		rows.append(".".repeat(WIDTH))
	return {"id": TOWN, "name": "People test", "legend": {".": "grass"}, "ground": rows, "start": [2, 2], "facing": "down", "objects": [
		{"kind": "person", "id": "innkeeper", "at": [3, 3], "facing": "left"},
		{"kind": "building", "art": "home", "at": [8, 2], "size": [6, 6], "door": [3, 5], "to": {"map": "home", "at": [5, 6], "facing": "up"}},
		{"kind": "warp", "at": [2, 10], "to": {"map": "home", "at": [3, 4], "facing": "down"}},
		{"kind": "building", "art": "shop", "at": [12, 9], "size": [6, 6], "door": [3, 5]},
	]}


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().process_frame


func _button(name: String) -> Button:
	return studio.inspector().find_child(name, true, false) as Button


func _select_people_filter(wanted: String) -> void:
	var filter := studio.people_panel().find_child("PersonFilter", true, false) as OptionButton
	for index: int in filter.item_count:
		if String(filter.get_item_metadata(index)) == wanted:
			filter.select(index)
			filter.item_selected.emit(index)
			return
	assert_bool(false).override_failure_message("people filter %s is present" % wanted).is_true()


func _people_filter_label(wanted: String) -> String:
	var filter := studio.people_panel().find_child("PersonFilter", true, false) as OptionButton
	for index: int in filter.item_count:
		if String(filter.get_item_metadata(index)) == wanted:
			return filter.get_item_text(index)
	return ""


func _people_ids() -> Array[String]:
	var ids: Array[String] = []
	for art: String in StudioAssets.placeable():
		if String(StudioAssets.entry_of(art).get("kind", "")) == "person":
			ids.append(art)
	return ids


func test_the_catalog_lists_every_townsperson_and_the_two_markers_with_pictures() -> void:
	var townsfolk: Dictionary = OverworldScreen.catalog_of().townsfolk
	var people := _people_ids()
	assert_int(people.size()).override_failure_message("a card for every townsperson").is_equal(townsfolk.size())
	for id: String in people:
		var thumb := StudioThumbs.thumb(id, "person")
		assert_object(thumb).override_failure_message("a picture for %s" % id).is_not_null()
		assert_bool(thumb.get_width() <= StudioThumbs.SIZE and thumb.get_height() <= StudioThumbs.SIZE).is_true()
		assert_str(StudioThumbs.source(id, "person")).is_equal("new")
	var ids := StudioAssets.placeable()
	for marker: String in ["marker-warp", "marker-start"]:
		assert_bool(marker in ids).override_failure_message(marker + " is listed").is_true()
		var entry := StudioAssets.entry_of(marker)
		assert_str(String(entry.category)).is_equal("markers")
		assert_array(entry.place).is_equal(["indoor", "outdoor"])
		var thumb := StudioThumbs.thumb(marker, String(entry.kind))
		assert_object(thumb).override_failure_message(marker + " has an icon").is_not_null()
		assert_int(thumb.get_width() % 2 + thumb.get_height() % 2).override_failure_message("enlarged 2x, whole pixels").is_equal(0)
		assert_str(StudioThumbs.source(marker, String(entry.kind))).is_equal("new")
	assert_str(String(StudioAssets.entry_of("marker-warp").kind)).is_equal("warp")
	assert_str(String(StudioAssets.entry_of("marker-start").subcategory)).is_equal("start")
	# The catalog file itself does not have them, and the panel files them under their own tab.
	assert_str(FileAccess.get_file_as_string(StudioAssets.PATH)).not_contains("marker-warp")
	assert_bool(StudioAssets.categories().any(func(category: Dictionary) -> bool: return category.id == "markers")).is_true()
	assert_object(studio.place_panel().find_child("Card_pell", true, false)).is_not_null()
	assert_object(studio.place_panel().find_child("Card_marker-start", true, false)).is_not_null()


func test_templates_for_people_and_markers_and_none_of_them_flip() -> void:
	assert_dict(StudioAssets.template("pell")).is_equal({"kind": "person", "id": "pell", "facing": "down"})
	assert_dict(StudioAssets.template("marker-warp")).is_equal({"kind": "warp"})
	assert_dict(StudioAssets.template("marker-start")).is_equal({"kind": "start"})
	assert_dict(StudioAssets.template("barrel")).is_equal({"kind": "prop", "art": "barrel"})
	for object: Dictionary in [{"kind": "person", "id": "pell"}, {"kind": "warp"}, {"kind": "start"}]:
		assert_bool(StudioAssets.can_flip(object)).is_false()


func test_a_person_ghost_stands_where_the_walker_draws_them() -> void:
	var at := Vector2i(7, 5)
	var parts := StudioGhost.parts({"kind": "person", "id": "innkeeper", "at": at, "facing": "left"})
	assert_int(parts.size()).is_equal(1)
	var part := parts[0]
	assert_object(part.texture).is_not_null()
	var townsfolk: Dictionary = OverworldScreen.catalog_of().townsfolk
	var sheet := OverworldArt.character(townsfolk.innkeeper.look)
	var walker := Walker.new(sheet)
	add_child(walker)
	walker.place(at, "left")
	var sprite := walker.get("_sprite") as Sprite2D
	var drawn := Rect2(walker.position + sprite.position, sprite.region_rect.size * sprite.scale)
	assert_vector((part.rect as Rect2).position).override_failure_message("same corner as the Walker's picture").is_equal(drawn.position)
	assert_vector((part.rect as Rect2).size).is_equal(drawn.size)
	assert_bool(bool(part.flip)).is_equal(sprite.flip_h)
	assert_vector((part.region as Rect2).position).is_equal(sprite.region_rect.position)
	# The picture's ground row on the Walker's feet, centred on the cell.
	var rect := part.rect as Rect2
	assert_float(rect.position.x + floorf(rect.size.x / 2.0)).is_equal(walker.position.x)
	assert_float(rect.position.y + roundf(sheet.ground * sheet.scale)).is_equal(walker.position.y)
	walker.queue_free()
	for kind: String in ["warp", "start"]:
		assert_array(StudioGhost.parts({"kind": kind, "at": at})).is_empty()


func test_selecting_a_person_shows_their_name_talk_file_and_quest_mentions() -> void:
	studio.select(PERSON)
	await _frames(1)
	var inspector := studio.inspector()
	assert_str(" | ".join(inspector.lines)).contains("name: Marta")
	assert_str(" | ".join(inspector.lines)).contains("talk: " + StudioMode.content_dir.path_join("packs/core/overworld/talk/innkeeper.jsonc"))
	assert_str(" | ".join(inspector.lines)).override_failure_message("a quest step that Marta's talk completes").contains("Say hello to Marta")
	var name_label := inspector.find_child("PersonName", true, false) as Label
	assert_str(name_label.text).is_equal("Marta, Keeper of the Warm Hearth")
	assert_str((inspector.find_child("PersonTalk", true, false) as Label).text).is_equal("Talk: talk/innkeeper.jsonc")
	var open := _button("OpenTalk")
	assert_bool(open.is_visible_in_tree()).is_true()
	assert_bool(open.disabled).override_failure_message("the talk file exists").is_false()
	assert_bool(_button("LinkDoor").is_visible_in_tree()).is_false()
	# A file that is not there cannot be opened, and a person with no mentions says so.
	inspector.show_person({"name": "Nobody", "title": "", "talk_file": "res://nope/talk.jsonc", "mentions": []})
	assert_bool(open.disabled).is_true()
	assert_str(" | ".join(inspector.lines)).contains("No quest mentions them yet.")
	var mentions := inspector.find_child("Mentions", true, false)
	assert_int(mentions.get_child_count()).is_equal(2)
	# Selecting a building or nothing takes the person's section away.
	studio.select(HOUSE)
	assert_bool(inspector.find_child("Person", true, false).visible).is_false()


func test_a_door_shows_where_it_leads_and_which_buttons_it_offers() -> void:
	var inspector := studio.inspector()
	studio.select(HOUSE)
	await _frames(1)
	assert_str((inspector.find_child("LeadsTo", true, false) as Label).text).is_equal("Leads to: Your house at 5, 6 — Arrive facing up")
	assert_str(_button("LinkDoor").text).is_equal("Link door…")
	assert_bool(_button("LinkDoor").is_visible_in_tree()).is_true()
	assert_bool(_button("MakeInterior").visible).override_failure_message("it already leads somewhere").is_false()
	assert_bool(_button("Unlink").is_visible_in_tree()).is_true()
	assert_bool(_button("GoThere").is_visible_in_tree()).is_true()
	# A shop with no `to` can be given a room, and has nowhere to go or to unlink.
	studio.select(SHUT)
	await _frames(1)
	assert_str((inspector.find_child("LeadsTo", true, false) as Label).text).is_equal("Leads nowhere: the door stays shut")
	assert_bool(_button("MakeInterior").is_visible_in_tree()).is_true()
	assert_bool(_button("Unlink").visible).is_false()
	assert_bool(_button("GoThere").visible).is_false()


## The buttons on an inspector of their own, so the Studio's own answers to the signals do not interfere.
func test_the_links_buttons_send_their_signals_with_the_sid_and_the_place() -> void:
	var inspector := StudioInspector.new()
	add_child(inspector)
	var got: Array = []
	inspector.link_requested.connect(func(s: int) -> void: got.append(["link", s]))
	inspector.make_interior_requested.connect(func(s: int) -> void: got.append(["make", s]))
	inspector.unlink_requested.connect(func(s: int) -> void: got.append(["unlink", s]))
	inspector.go_to_requested.connect(func(map_id: String, cell: Vector2i) -> void: got.append(["go", map_id, cell]))
	var leads := {"map": "home", "name": "Your house", "at": Vector2i(5, 6), "facing": "up"}
	inspector.show_object("Home", {"kind": "building", "art": "home"}, 1, 1, 7)
	inspector.show_links(7, {"kind": "building", "leads": leads, "can_make": false})
	for button_name: String in ["LinkDoor", "Unlink", "GoThere"]:
		(inspector.find_child(button_name, true, false) as Button).pressed.emit()
	assert_array(got).is_equal([["link", 7], ["unlink", 7], ["go", "home", Vector2i(5, 6)]])
	got.clear()
	inspector.show_object("Shop", {"kind": "building", "art": "shop"}, 1, 1, 9)
	inspector.show_links(9, {"kind": "building", "leads": {}, "can_make": true})
	(inspector.find_child("MakeInterior", true, false) as Button).pressed.emit()
	assert_array(got).is_equal([["make", 9]])
	inspector.queue_free()


func test_a_warp_offers_link_and_go_there_but_no_unlink_or_interior() -> void:
	studio.select(WARP)
	await _frames(1)
	var inspector := studio.inspector()
	assert_str(_button("LinkDoor").text).is_equal("Link warp…")
	assert_str((inspector.find_child("LeadsTo", true, false) as Label).text).is_equal("Leads to: Your house at 3, 4 — Arrive facing down")
	assert_bool(_button("Unlink").visible).is_false()
	assert_bool(_button("MakeInterior").visible).is_false()
	assert_bool(_button("GoThere").is_visible_in_tree()).is_true()
	# A prop has none of these sections.
	studio.work.command({"type": "add", "object": {"kind": "prop", "art": "barrel", "at": [16, 2]}, "index": -1})
	studio.select(4)
	await _frames(1)
	assert_bool(inspector.find_child("Links", true, false).visible).is_false()


func test_nothing_selected_shows_the_map_and_its_name_and_facing_fields() -> void:
	studio.select(PERSON)
	studio.select(-1)
	await _frames(1)
	var inspector := studio.inspector()
	assert_bool(inspector.delete_button.visible).is_false()
	assert_array(inspector.lines).contains(["name: People test", "id: lanternroot", "size: 20 x 16", "kind: outdoors", "start: 2, 2", "facing: down"])
	var edit := inspector.find_child("MapName", true, false) as LineEdit
	var facing := inspector.find_child("MapFacing", true, false) as OptionButton
	assert_bool(edit.is_visible_in_tree()).is_true()
	assert_str(edit.text).is_equal("People test")
	assert_int(facing.selected).is_equal(0)
	# The fields send their changes from an inspector of their own (the Studio's own answer would rebuild this one).
	var own := StudioInspector.new()
	add_child(own)
	own.show_map({"id": "m", "name": "People test", "size": Vector2i(20, 16), "interior": false, "start": Vector2i(2, 2), "facing": "down"})
	var own_edit := own.find_child("MapName", true, false) as LineEdit
	var own_facing := own.find_child("MapFacing", true, false) as OptionButton
	var changes: Array = []
	own.map_field_changed.connect(func(key: String, value: Variant) -> void: changes.append([key, value]))
	own_edit.text = "Pell's map"
	own_edit.text_submitted.emit(own_edit.text)
	own_facing.select(1)
	own_facing.item_selected.emit(1)
	assert_array(changes).is_equal([["name", "Pell's map"], ["facing", "up"]])
	# Losing focus with the same text says nothing more; an empty name is put back.
	own_edit.focus_exited.emit()
	own_edit.text = ""
	own_edit.text_submitted.emit("")
	assert_str(own_edit.text).is_equal("Pell's map")
	assert_int(changes.size()).is_equal(2)
	own.queue_free()
	# Selecting something takes the map's section away, and clear() still empties the inspector.
	studio.select(HOUSE)
	assert_bool(edit.is_visible_in_tree()).is_false()
	inspector.clear()
	assert_array(inspector.lines).is_empty()


func test_the_kind_filter_lists_only_people_or_only_markers() -> void:
	var panel := studio.place_panel()
	panel.set_filters({"kind": "person"})
	assert_array(panel.matching_ids()).contains_exactly_in_any_order(_people_ids())
	panel.set_filters({"kind": "marker"})
	assert_array(panel.matching_ids()).contains_exactly_in_any_order(["marker-warp", "marker-start"])
	panel.set_filters({"kind": "warp"})
	assert_array(panel.matching_ids()).is_equal(["marker-warp"])
	panel.set_filters({"kind": "prop"})
	for art: String in panel.matching_ids():
		assert_str(String(StudioAssets.entry_of(art).kind)).is_equal("prop")
	panel.reset_filters()
	assert_array(panel.matching_ids()).is_equal(StudioAssets.placeable())


func test_people_workspace_search_filters_and_subviews_keep_their_own_state() -> void:
	var panel := studio.people_panel()
	var canonical_before := FileAccess.get_file_as_string(_path(TOWN))
	studio.set_tab("people")
	panel.choose_view("people")
	await _frames(1)
	assert_bool(panel.visible).is_true()
	assert_object(panel.find_child("Person_innkeeper", true, false)).is_not_null()
	assert_bool(panel.find_child("PlaceTransition", true, false).visible).is_false()
	var search := panel.find_child("PeopleSearch", true, false) as LineEdit
	search.text = "marta"
	search.text_changed.emit(search.text)
	assert_object(panel.find_child("Person_innkeeper", true, false)).is_not_null()
	assert_int(panel._cards.get_child_count()).override_failure_message("search narrows the roster to Marta").is_equal(1)
	panel.choose_view("entrances")
	assert_bool(panel.find_child("PlaceTransition", true, false).visible).is_true()
	assert_int(panel._cards.get_child_count()).is_equal(3)
	panel.choose_view("start")
	assert_bool(search.visible).is_false()
	studio.set_tab("land")
	studio.set_tab("people")
	assert_str(panel._view).is_equal("start")
	panel.choose_view("people")
	assert_bool(String(panel._search_by_view.get("people", "")) == "marta").override_failure_message(
		"the People query is retained separately from the other subviews"
	).is_true()
	assert_bool(search.text.begins_with("marta")).override_failure_message(
		"the People query is restored to its search box"
	).is_true()
	search.text = ""
	_select_people_filter("on_map")
	assert_object(panel.find_child("Person_innkeeper", true, false)).is_not_null()
	assert_int(panel._cards.get_child_count()).override_failure_message("on-map filter shows only authored people on this map").is_equal(1)
	assert_str(FileAccess.get_file_as_string(_path(TOWN))).is_equal(canonical_before)


func test_people_index_refreshes_after_objects_edits_undo_and_redo() -> void:
	var panel := studio.people_panel()
	var canonical_before := FileAccess.get_file_as_string(_path(TOWN))
	studio.set_tab("people")
	panel.choose_view("people")
	var person_id := ""
	for person: Dictionary in panel._people_rows:
		if bool(person.get("unknown", false)) or bool(person.get("scheduled", false)):
			continue
		if (person.get("locations", []) as Array).is_empty():
			person_id = String(person.id)
			break
	assert_bool(person_id != "").override_failure_message("fixture has an unplaced, unscheduled roster entry").is_true()
	var cell := Vector2i(-1, -1)
	for y: int in HEIGHT:
		for x: int in WIDTH:
			if StudioPeopleIndex.cell_state(studio.current_map(), Vector2i(x, y)) == "valid":
				cell = Vector2i(x, y)
				break
		if cell.x >= 0:
			break
	assert_bool(cell.x >= 0).is_true()
	studio.set_tab("objects")
	var placed := studio.work.place_person(person_id, cell, "left")
	assert_bool(placed.ok).override_failure_message("the ordinary work layer can add the authored person").is_true()
	studio.set_tab("people")
	_select_people_filter("on_map")
	assert_object(panel.find_child("Person_" + person_id, true, false)).override_failure_message(
		"the mounted view sees a map edit immediately"
	).is_not_null()
	assert_str(_people_filter_label("on_map")).ends_with("(2)")
	var indexed := panel._people_rows.filter(func(row: Dictionary) -> bool: return String(row.id) == person_id)
	assert_int(indexed.size()).is_equal(1)
	var found_cell := false
	for location: Dictionary in indexed[0].locations:
		if location.at == cell:
			found_cell = true
	assert_bool(found_cell).override_failure_message("the index carries the current authored cell").is_true()
	assert_bool(studio.work.undo()).is_true()
	assert_bool(panel.find_child("Person_" + person_id, true, false) == null).override_failure_message(
		"undo refreshes the on-map filter"
	).is_true()
	assert_str(_people_filter_label("on_map")).ends_with("(1)")
	assert_bool(studio.work.redo()).is_true()
	assert_object(panel.find_child("Person_" + person_id, true, false)).override_failure_message(
		"redo refreshes the authored location"
	).is_not_null()
	assert_str(_people_filter_label("on_map")).ends_with("(2)")
	assert_bool(studio.work.flush()).override_failure_message("draft is saved before opening a fresh work session").is_true()
	var reloaded := StudioWork.new(studio)
	studio.work = reloaded
	assert_bool(reloaded.open(TOWN)).override_failure_message("the draft reopens through the existing session loader").is_true()
	studio._load_map(studio.current_map())
	assert_object(panel.find_child("Person_" + person_id, true, false)).override_failure_message(
		"a freshly loaded draft rebuilds the mounted People index"
	).is_not_null()
	assert_str(_people_filter_label("on_map")).ends_with("(2)")
	assert_bool(studio.go_to_map("home")).override_failure_message("the map picker can change maps from People").is_true()
	assert_str(panel._indexed_map_id).is_equal("home")
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_str(panel._indexed_map_id).is_equal(TOWN)
	assert_object(panel.find_child("Person_" + person_id, true, false)).override_failure_message(
		"returning to the source map refreshes its draft-aware People view"
	).is_not_null()
	assert_str(FileAccess.get_file_as_string(_path(TOWN))).is_equal(canonical_before)


func test_people_entrances_refresh_when_a_room_is_created_and_when_returning_to_its_map() -> void:
	var panel := studio.people_panel()
	var canonical_before := FileAccess.get_file_as_string(_path(TOWN))
	studio.set_tab("people")
	panel.choose_view("entrances")
	var shop_rows := panel._entrance_rows.filter(func(row: Dictionary) -> bool: return String(row.get("art", "")) == "shop")
	assert_int(shop_rows.size()).is_equal(1)
	var shop: Dictionary = shop_rows[0]
	assert_str(String(shop.get("state", ""))).is_equal("closed")
	panel._emit_entrance("make_room", shop)
	var room_id := String(studio.current_map().get("id", ""))
	assert_bool(bool(studio.current_map().get("interior", false))).override_failure_message(
		"the mounted entrance action opens the newly created room"
	).is_true()
	assert_bool(studio.work.is_new_map(room_id)).is_true()
	assert_str(panel._indexed_map_id).is_equal(room_id)
	assert_int(panel._entrance_rows.size()).override_failure_message(
		"the new room's doormat entrance appears immediately"
	).is_equal(1)
	var listed := studio.map_list().filter(func(row: Dictionary) -> bool: return String(row.get("id", "")) == room_id)
	assert_int(listed.size()).override_failure_message("the new room appears in the map picker immediately").is_equal(1)
	assert_bool(studio.go_to_map(TOWN)).is_true()
	assert_str(panel._indexed_map_id).is_equal(TOWN)
	var returned_shop := panel._entrance_rows.filter(func(row: Dictionary) -> bool: return String(row.get("art", "")) == "shop")
	assert_int(returned_shop.size()).is_equal(1)
	assert_str(String(returned_shop[0].get("state", ""))).override_failure_message(
		"returning to the source refreshes the new room link status"
	).is_equal("valid")
	assert_bool(bool(returned_shop[0].get("interior", false))).is_true()
	assert_str(FileAccess.get_file_as_string(_path(TOWN))).is_equal(canonical_before)


func _copy_tree(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)
	for directory: String in DirAccess.get_directories_at(source):
		_copy_tree(source.path_join(directory), target.path_join(directory))
	for file: String in DirAccess.get_files_at(source):
		assert_int(DirAccess.copy_absolute(source.path_join(file), target.path_join(file))).is_equal(OK)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func test_hidden_people_shelf_defers_card_rebuild_until_it_is_opened() -> void:
	studio.set_tab("people")
	var panel := studio.people_panel()
	var card := panel.find_child("Person_innkeeper", true, false)
	assert_object(card).is_not_null()
	var card_id := card.get_instance_id()
	var indexed := panel._indexed_revision
	studio.set_tab("objects")
	var person_sid := studio.work.sid_at(PERSON)
	assert_bool(studio.work.command({"type": "move", "sids": [person_sid], "by": [1, 0]}).ok).is_true()
	assert_int(panel._indexed_revision).is_equal(indexed)
	assert_int(panel.find_child("Person_innkeeper", true, false).get_instance_id()).is_equal(card_id)
	assert_int(panel._index_revision).is_greater(indexed)
	studio.set_tab("people")
	assert_int(panel._indexed_revision).is_equal(panel._index_revision)
	var row: Dictionary = panel._people_rows.filter(func(person: Dictionary) -> bool: return person.id == "innkeeper")[0]
	assert_vector(Vector2(row.locations[0].at)).is_equal(Vector2(4, 3))


func test_dialogue_return_commits_focused_text_and_keeps_map_and_dialogue_history_separate() -> void:
	studio.set_tab("people")
	studio.select(PERSON)
	var sid := studio.work.sid_at(PERSON)
	assert_bool(studio.work.set_field(sid, "facing", "up")).is_true()
	var canonical := StudioFiles.read_text(_path(TOWN))
	_button("OpenTalk").pressed.emit()
	await _frames(2)
	assert_str(studio.tab).is_equal("quests")
	assert_str(studio.quest_panel.talk_editor.file).is_equal("innkeeper")
	var editor := studio.quest_panel.talk_editor
	var node_id := editor.node
	var line := StudioQuestUi.find(editor, "line.0.text") as TextEdit
	assert_object(line).is_not_null()
	line.grab_focus()
	var original := line.text
	line.text = "P05 draft dialogue"
	(studio.quest_panel.find_child("ReturnToPerson", true, false) as Button).pressed.emit()
	await _frames(3)
	assert_str(studio.tab).is_equal("people")
	assert_str(String(studio.selected_object().get("id", ""))).is_equal("innkeeper")
	assert_str(String(studio.quests.data("talk/innkeeper").nodes[node_id].lines[0].text)).is_equal("P05 draft dialogue")
	assert_str(String(studio.selected_object().facing)).is_equal("up")
	assert_bool(studio.text_editor_focused()).is_false()
	studio.edit_person_talk("innkeeper")
	studio._top.undo_pressed.emit()
	await _frames(2)
	assert_str(String(studio.quests.data("talk/innkeeper").nodes[node_id].lines[0].text)).is_equal(original)
	assert_str(String(studio.work.raw(PERSON).facing)).is_equal("up")
	studio._top.redo_pressed.emit()
	await _frames(2)
	studio.return_to_person()
	studio._top.undo_pressed.emit()
	assert_str(String(studio.work.raw(PERSON).facing)).is_equal("left")
	assert_str(String(studio.quests.data("talk/innkeeper").nodes[node_id].lines[0].text)).is_equal("P05 draft dialogue")
	studio.set_play_draft(true)
	assert_str(String(studio.catalog().talk.innkeeper.nodes[node_id].lines[0].text)).is_equal("P05 draft dialogue")
	assert_str(StudioFiles.read_text(_path(TOWN))).is_equal(canonical)


func test_quest_jump_uses_draft_reference_and_returns_to_authored_person() -> void:
	studio.set_tab("people")
	assert_bool(studio.quests.do("quests", {"type": "set_at", "path": ["hello", "title"], "value": "Draft greeting"}).ok).is_true()
	studio.select(PERSON)
	var inspector := studio.inspector()
	var location := inspector.find_child("PersonLocation", true, false) as Label
	assert_str(location.text).contains("3, 3")
	var references := StudioDoors.quest_references("innkeeper", studio.quests.data("quests"), studio.quests.data("talk/innkeeper"))
	assert_bool(not references.is_empty()).is_true()
	var reference: Dictionary = references[0]
	var jump := inspector.find_child("PersonQuest_%s_%d" % [reference.id, reference.step], true, false) as Button
	assert_object(jump).is_not_null()
	assert_str(jump.text).contains("Draft greeting")
	jump.pressed.emit()
	await _frames(2)
	assert_str(studio.tab).is_equal("quests")
	assert_str(studio.quest_panel.quest_list.chosen).is_equal(String(reference.id))
	assert_int(studio.quest_panel.quest_list.step_marked).is_equal(int(reference.step))
	studio.return_to_person()
	assert_str(String(studio.selected_object().get("id", ""))).is_equal("innkeeper")


func test_missing_or_unreadable_dialogue_never_navigates_to_another_persons_talk() -> void:
	studio.set_tab("people")
	var path := studio.quests.path_of("talk/innkeeper")
	assert_bool(StudioFiles.write_content(path, "{broken")).is_true()
	studio.quests._docs.erase("talk/innkeeper")
	studio.select(PERSON)
	assert_bool(_button("OpenTalk").disabled).is_true()
	assert_bool(studio.inspector().find_child("PersonDiagnostic", true, false).visible).is_true()
	studio.edit_person_talk("innkeeper")
	assert_str(studio.tab).is_equal("people")
	assert_bool(studio._person_return.is_empty()).is_true()


func test_entrance_problem_locates_exact_source_and_overlay_shares_publish_code() -> void:
	var sid := studio.work.sid_at(HOUSE)
	assert_bool(studio.work.set_field(sid, "to", {"map": "missing-room", "at": [5, 6], "facing": "up"})).is_true()
	studio.set_tab("people")
	var panel := studio.people_panel()
	panel.choose_view("entrances")
	var problem := panel.find_child("EntranceProblem_" + str(HOUSE), true, false) as Button
	assert_object(problem).is_not_null()
	problem.pressed.emit()
	assert_array(studio.selected_sids()).is_equal([sid])
	var rows := studio.overlay().entrances.filter(func(row: Dictionary) -> bool: return int(row.index) == HOUSE)
	assert_int(rows.size()).is_equal(1)
	assert_str(String(rows[0].problem.code)).is_equal("missing_map")
	assert_str(String(rows[0].problem.map)).is_equal(TOWN)
	assert_int(int(rows[0].problem.index)).is_equal(HOUSE)
	assert_str((panel.find_child("EntranceLink_" + str(HOUSE), true, false) as Button).text).is_equal("Repair link…")


func test_return_to_unplaced_roster_and_ambiguous_person_never_selects_a_different_placement() -> void:
	studio.set_tab("people")
	var person_id := ""
	for row: Dictionary in studio.people_panel()._people_rows:
		if (row.locations as Array).is_empty() and studio.quests.talk_available(String(row.talk)):
			person_id = String(row.id)
			break
	assert_str(person_id).is_not_empty()
	studio.edit_person_talk(person_id)
	assert_str(studio.tab).is_equal("quests")
	studio.return_to_person()
	assert_str(studio.tab).is_equal("people")
	assert_int(studio.selection).is_equal(-1)
	assert_str(studio.people_panel()._selected_key).is_equal("person:" + person_id + ":")
	assert_object(studio.people_panel().find_child("Person_" + person_id, true, false)).is_not_null()
	assert_bool(studio.work.command({"type": "add", "index": -1,
		"object": {"kind": "person", "id": "innkeeper", "at": [4, 3], "facing": "down"}}).ok).is_true()
	studio.edit_person_talk("innkeeper")
	studio.return_to_person()
	assert_int(studio.selection).is_equal(-1)
	assert_str(studio.people_panel()._selected_key).is_equal("person:innkeeper:")
