class_name StudioPeoplePanel
extends PanelContainer
## People, Entrances and Map start in the shared lower Studio workspace.
## The panel is a view: persistent changes are delegated to StudioMode and StudioWork.

signal place_person_requested(id: String)
signal place_warp_requested
signal locate_person_requested(map_id: String, index: int, id: String, expected: Dictionary)
signal entrance_action_requested(action: String, map_id: String, index: int, expected: Dictionary)
signal room_draft_action_requested(action: String, room: Dictionary)
signal start_requested
signal start_facing_requested(facing: String)
signal start_facing_apply_requested

const VIEW_IDS: Array[String] = ["people", "entrances", "start"]
const PERSON_FILTERS: Array[String] = ["all", "on_map", "elsewhere", "unplaced"]
const ENTRANCE_FILTERS: Array[String] = ["all", "linked", "unlinked", "problems"]
const CARD_WIDTH := 280
const CARD_HEIGHT := 108

var _studio: StudioMode
var _view := "people"
var _person_filter := "all"
var _entrance_filter := "all"
var _search_by_view := {"people": "", "entrances": ""}
var _selected_key := ""
var _placing_id := ""
var _index_revision := 0
var _indexed_revision := -1
var _indexed_map_id := ""
var _people_rows: Array[Dictionary] = []
var _entrance_rows: Array[Dictionary] = []
var _room_draft_rows: Array[Dictionary] = []
var _tabs: Dictionary = {}
var _filter: OptionButton
var _search: LineEdit
var _place_transition: Button
var _scroll: ScrollContainer
var _cards: HFlowContainer
var _empty: Label


func _init(studio: StudioMode) -> void:
	_studio = studio
	name = "PeopleDoorsPanel"
	custom_minimum_size.y = StudioStyle.PLACE
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(10, 6)))
	var column := Ui.vbox([], 4)
	add_child(column)
	column.add_child(_header())
	_scroll = ScrollContainer.new()
	_scroll.name = "PeopleDoorsCards"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards = Ui.flow([], 5) as HFlowContainer
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards)
	column.add_child(_scroll)
	_empty = StudioStyle.caption("")
	_empty.name = "EmptyState"
	_empty.visible = false
	column.add_child(_empty)
	# The editor may mount before StudioWork opens its first map and quest documents. `_load_map` performs the first
	# refresh after those dependencies are ready.


func _header() -> Control:
	var row := Ui.hbox([], 5)
	row.name = "PeopleDoorsViews"
	for view_id: String in VIEW_IDS:
		var button := StudioStyle.button(
			StudioText.t("people_view_" + view_id), func() -> void: choose_view(view_id), view_id == _view
		)
		button.name = "View_" + view_id
		_tabs[view_id] = button
		row.add_child(button)
	_filter = OptionButton.new()
	_filter.name = "PersonFilter"
	_filter.focus_mode = Control.FOCUS_NONE
	_filter.item_selected.connect(func(index: int) -> void:
		if _view == "people":
			_person_filter = String(_filter.get_item_metadata(index))
		else:
			_entrance_filter = String(_filter.get_item_metadata(index))
		_refresh()
	)
	_filter.custom_minimum_size.x = 120
	row.add_child(_filter)
	_search = LineEdit.new()
	_search.name = "PeopleSearch"
	_search.placeholder_text = StudioText.t("people_search")
	_search.clear_button_enabled = true
	_search.focus_mode = Control.FOCUS_CLICK
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size = Vector2(180, 24)
	_search.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	_search.text_changed.connect(func(text: String) -> void:
		_search_by_view[_view] = text.strip_edges().to_lower()
		_refresh()
	)
	row.add_child(_search)
	_place_transition = StudioStyle.button(
		StudioText.t("people_place_transition"), func() -> void: place_warp_requested.emit()
	)
	_place_transition.name = "PlaceTransition"
	_place_transition.visible = false
	row.add_child(_place_transition)
	_set_filter_options()
	return row


func choose_view(which: String) -> void:
	if not VIEW_IDS.has(which):
		return
	_view = which
	for view_id: String in VIEW_IDS:
		StudioStyle.choose(_tabs[view_id], view_id == _view)
	_filter.visible = _view in ["people", "entrances"]
	_search.visible = _view in ["people", "entrances"]
	_place_transition.visible = _view == "entrances"
	_search.text = String(_search_by_view.get(_view, ""))
	_set_filter_options()
	_refresh()


func show_person(id: String) -> void:
	_selected_key = "person:" + id + ":"
	choose_view("people")
	var card := _cards.get_node_or_null("Person_" + id) as Control
	if card != null:
		StudioQuestUi.show_control(_scroll, card)


## Refreshes from the current sessions and current catalog. Search, filter, tab and scroll position stay in memory.
func refresh() -> void:
	_index_revision += 1
	# Keep invalidation cheap while Objects/Land/Link owns the shelf. set_tab refreshes before People is used again.
	if is_visible_in_tree():
		_refresh()


func mark_placing(id: String) -> void:
	_placing_id = id
	for child: Node in _cards.get_children():
		var card := child as Control
		var person_id := card.name.trim_prefix("Person_")
		var place := card.find_child("Place_" + person_id, true, false) as Button
		if place != null:
			StudioStyle.choose(place, id != "" and person_id == id)


func _refresh() -> void:
	if _cards == null or not is_instance_valid(_cards):
		return
	var scroll_before := _scroll.scroll_vertical
	Ui.clear(_cards)
	var map_id := String(_studio.current_map().get("id", ""))
	_index_if_needed(map_id)
	match _view:
		"people":
			_show_people(map_id)
		"entrances":
			_show_entrances()
		"start":
			_show_start()
	_empty.visible = _cards.get_child_count() == 0
	if _empty.visible:
		_empty.text = StudioText.t("people_empty_" + _view)
	call_deferred("_restore_scroll", scroll_before)


func _restore_scroll(value: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value


func _set_filter_options(counts: Dictionary = {}) -> void:
	if _filter == null:
		return
	var ids: Array[String] = PERSON_FILTERS if _view == "people" else ENTRANCE_FILTERS
	var selected := _person_filter if _view == "people" else _entrance_filter
	_filter.clear()
	for id: String in ids:
		var title := StudioText.t("people_filter_" + id)
		if counts.has(id):
			title = StudioText.f("people_filter_count", [title, int(counts[id])])
		_filter.add_item(title)
		_filter.set_item_metadata(_filter.item_count - 1, id)
		if id == selected:
			_filter.select(_filter.item_count - 1)


func _index_if_needed(map_id: String) -> void:
	if _indexed_revision == _index_revision and _indexed_map_id == map_id:
		return
	_indexed_revision = _index_revision
	_indexed_map_id = map_id
	var maps := _studio.work.map_documents()
	var catalog := _studio.catalog()
	_people_rows = StudioPeopleIndex.people(
		catalog.get("townsfolk", {}), maps, catalog.get("schedules", {})
	)
	_entrance_rows = StudioPeopleIndex.entrances(
		map_id, _studio.work.map_data(map_id), catalog.get("maps", {})
	)
	_room_draft_rows = StudioPeopleIndex.unlinked_room_drafts(maps, _studio.work.new_map_ids())


func _show_people(current_map: String) -> void:
	var rows := _people_rows
	var counts := {"all": rows.size(), "on_map": 0, "elsewhere": 0, "unplaced": 0}
	for person: Dictionary in rows:
		var locations: Array = person.get("locations", [])
		var on_map := false
		var elsewhere := false
		for value: Variant in locations:
			if not value is Dictionary:
				continue
			if String((value as Dictionary).get("map", "")) == current_map:
				on_map = true
			else:
				elsewhere = true
		if on_map:
			counts["on_map"] = int(counts.on_map) + 1
		if elsewhere:
			counts["elsewhere"] = int(counts.elsewhere) + 1
		if locations.is_empty():
			counts["unplaced"] = int(counts.unplaced) + 1
	_set_filter_options(counts)
	var shown := 0
	for person: Dictionary in rows:
		var locations: Array = person.get("locations", [])
		var on_map := false
		var elsewhere := false
		for location_value: Variant in locations:
			if not location_value is Dictionary:
				continue
			if String((location_value as Dictionary).get("map", "")) == current_map:
				on_map = true
			else:
				elsewhere = true
		if _person_filter == "on_map" and not on_map:
			continue
		if _person_filter == "elsewhere" and not elsewhere:
			continue
		if _person_filter == "unplaced" and not locations.is_empty():
			continue
		if not _matches_person(person):
			continue
		_cards.add_child(_person_card(person))
		shown += 1
	_empty.visible = shown == 0


func _matches_person(person: Dictionary) -> bool:
	var search_text := String(_search_by_view.get("people", ""))
	if search_text.is_empty():
		return true
	var haystack := "%s %s %s %s" % [
		String(person.get("id", "")), String(person.get("name", "")),
		String(person.get("title", "")), String(person.get("talk", "")),
	]
	haystack = haystack.to_lower()
	for word: String in search_text.split(" ", false):
		if not haystack.contains(word):
			return false
	return true


func _person_card(person: Dictionary) -> Control:
	var id := String(person.get("id", ""))
	var card := PanelContainer.new()
	card.name = "Person_" + id
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var locations: Array = person.get("locations", [])
	var selected := _selected_key.begins_with("person:" + id + ":")
	card.add_theme_stylebox_override(
		"panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.AMBER if selected else UiTheme.LINE, 2 if selected else 1, 3, Vector2(5, 4))
	)
	var info := Ui.vbox([], 2)
	var top := Ui.hbox([], 6)
	var portrait := TextureRect.new()
	portrait.name = "Portrait_" + id
	portrait.custom_minimum_size = Vector2(StudioThumbs.SIZE, StudioThumbs.SIZE)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = StudioThumbs.thumb(id, "person")
	if portrait.texture == null:
		var fallback := StudioStyle.caption("?")
		fallback.custom_minimum_size = Vector2(StudioThumbs.SIZE, StudioThumbs.SIZE)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top.add_child(fallback)
	else:
		top.add_child(portrait)
	var body := Ui.vbox([], 2)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Ui.hbox([], 5)
	var name := StudioStyle.caption(String(person.get("name", id)))
	name.add_theme_color_override("font_color", UiTheme.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name)
	if bool(person.get("scheduled", false)):
		title.add_child(StudioStyle.caption(StudioText.t("people_scheduled")))
	body.add_child(title)
	var subtitle := String(person.get("title", ""))
	body.add_child(StudioStyle.caption(subtitle if subtitle != "" else id))
	if bool(person.get("unknown", false)):
		var warning := StudioStyle.caption(StudioText.t("people_unknown"))
		warning.add_theme_color_override("font_color", UiTheme.WARN)
		body.add_child(warning)
	elif bool(person.get("scheduled", false)):
		var schedule_note := StudioStyle.caption(StudioText.t("people_scheduled_note"))
		schedule_note.add_theme_color_override("font_color", UiTheme.MUTED)
		body.add_child(schedule_note)
	if locations.is_empty():
		body.add_child(StudioStyle.caption(StudioText.t("people_unplaced")))
	else:
		for location_value: Variant in locations:
			if not location_value is Dictionary:
				continue
			var location: Dictionary = location_value
			var location_map := String(location.get("map", ""))
			var cell := OverworldMap.cell_of(location.get("at", [0, 0]))
			var label := StudioText.f("people_location_line", [_studio.map_title(location_map), cell.x, cell.y])
			if locations.size() > 1:
				label = StudioText.f("people_duplicate_location", [label])
			var location_key := "person:%s:%s:%d:%d" % [id, location_map, cell.x, cell.y]
			var locate_action := func() -> void:
				_selected_key = location_key
				locate_person_requested.emit(location_map, int(location.index), id, location.get("source", {}))
			var locate := StudioStyle.button(
				label, locate_action, _selected_key == location_key,
				StudioText.t("people_locate_tip")
			)
			locate.name = "Locate_" + id + "_" + location_map
			locate.alignment = HORIZONTAL_ALIGNMENT_LEFT
			locate.custom_minimum_size.y = 22
			body.add_child(locate)
		var schedule_text := _schedule_summary(person.get("schedule", {}))
		if schedule_text != "":
			var schedule := StudioStyle.caption(schedule_text)
			schedule.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			schedule.tooltip_text = schedule_text
			body.add_child(schedule)
	top.add_child(body)
	info.add_child(top)
	var actions := Ui.hbox([], 4)
	var place_action := func() -> void:
		_selected_key = "person:" + id + ":"
		place_person_requested.emit(id)
	var place := StudioStyle.button(StudioText.t("people_place_here"), place_action, _placing_id == id)
	place.name = "Place_" + id
	place.custom_minimum_size.y = 22
	if locations.size() > 1:
		place.disabled = true
		place.tooltip_text = StudioText.t("people_duplicate_repair")
	elif bool(person.get("unknown", false)):
		place.disabled = true
		place.tooltip_text = StudioText.t("people_unknown")
	elif bool(person.get("scheduled", false)):
		if String(_studio.current_map().get("id", "")) != "lanternroot":
			place.disabled = true
			place.tooltip_text = StudioText.f("people_scheduled_cross_map_blocked", [String(person.get("name", id))])
		elif not locations.is_empty():
			place.tooltip_text = StudioText.t("people_scheduled_move_note")
	actions.add_child(place)
	var talk := StudioStyle.button(StudioText.t("people_edit_talk"), func() -> void: _studio.edit_person_talk(id))
	talk.name = "Talk_" + id
	talk.custom_minimum_size.y = 22
	var talk_id := String(person.get("talk", id))
	var talk_available := _studio.quests.talk_available(talk_id)
	talk.disabled = bool(person.get("unknown", false)) or not talk_available
	if bool(person.get("unknown", false)):
		talk.tooltip_text = StudioText.t("people_unknown")
	elif not talk_available:
		talk.tooltip_text = StudioText.t("people_talk_missing")
		var missing_talk := StudioStyle.caption(StudioText.t("people_talk_missing"))
		missing_talk.add_theme_color_override("font_color", UiTheme.WARN)
		missing_talk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(missing_talk)
	actions.add_child(talk)
	info.add_child(actions)
	card.add_child(info)
	return card


func _schedule_summary(raw: Variant) -> String:
	if not raw is Dictionary:
		return ""
	var schedule: Dictionary = raw
	var spots := PackedStringArray()
	for key: String in ["home", "work", "inn"]:
		if not schedule.has(key):
			continue
		var cell := OverworldMap.cell_of(schedule[key])
		spots.append(StudioText.f("people_schedule_spot", [StudioText.t("people_schedule_" + key), cell.x, cell.y]))
	return " · ".join(spots)


func _show_entrances() -> void:
	var rows := _entrance_rows
	var drafts := _room_draft_rows
	var counts := {"all": rows.size() + drafts.size(), "linked": 0, "unlinked": drafts.size(), "problems": 0}
	for entrance: Dictionary in rows:
		var state := String(entrance.get("state", "missing"))
		if not (entrance.get("target", {}) as Dictionary).is_empty():
			counts["linked"] = int(counts.linked) + 1
		elif state in ["closed", "missing"]:
			counts["unlinked"] = int(counts.unlinked) + 1
		if not (entrance.get("problem", {}) as Dictionary).is_empty():
			counts["problems"] = int(counts.problems) + 1
	_set_filter_options(counts)
	for entrance: Dictionary in rows:
		if not _matches_entrance(entrance):
			continue
		_cards.add_child(_entrance_card(entrance))
	for room: Dictionary in drafts:
		if _matches_room_draft(room):
			_cards.add_child(_room_draft_card(room))


func _matches_room_draft(room: Dictionary) -> bool:
	if _entrance_filter not in ["all", "unlinked"]:
		return false
	var search_text := String(_search_by_view.get("entrances", ""))
	if search_text.is_empty():
		return true
	var haystack := "%s %s %s" % [
		String(room.get("id", "")), String(room.get("name", "")), StudioText.t("people_room_draft"),
	]
	return haystack.to_lower().contains(search_text)


func _room_draft_card(room: Dictionary) -> Control:
	var room_id := String(room.get("id", ""))
	var card := PanelContainer.new()
	card.name = "RoomDraft_" + room_id
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.LINE, 1, 3, Vector2(5, 4)))
	var content := Ui.vbox([], 2)
	content.add_child(StudioStyle.caption(StudioText.f("people_room_draft_title", [String(room.get("name", room_id))])))
	var detail := StudioStyle.caption(StudioText.t("people_room_draft"))
	detail.add_theme_color_override("font_color", UiTheme.WARN)
	content.add_child(detail)
	var actions := Ui.hbox([], 4)
	var locate := StudioStyle.button(StudioText.t("people_room_locate"), func() -> void:
		room_draft_action_requested.emit("locate", room.duplicate(true)))
	locate.name = "RoomDraftLocate_" + room_id
	locate.custom_minimum_size.y = 22
	actions.add_child(locate)
	var reconnectable := String(room.get("building_map", "")) != "" and int(room.get("building_index", -1)) >= 0
	var reconnect := StudioStyle.button(StudioText.t("people_room_reconnect"), func() -> void:
		room_draft_action_requested.emit("reconnect", room.duplicate(true)))
	reconnect.name = "RoomDraftReconnect_" + room_id
	reconnect.custom_minimum_size.y = 22
	reconnect.disabled = not reconnectable
	if not reconnectable:
		reconnect.tooltip_text = StudioText.t("people_room_reconnect_unavailable")
	actions.add_child(reconnect)
	content.add_child(actions)
	card.add_child(content)
	return card


func _matches_entrance(entrance: Dictionary) -> bool:
	var state := String(entrance.get("state", "missing"))
	var has_target := not (entrance.get("target", {}) as Dictionary).is_empty()
	match _entrance_filter:
		"linked":
			if not has_target:
				return false
		"unlinked":
			if has_target or state not in ["closed", "missing"]:
				return false
		"problems":
			if (entrance.get("problem", {}) as Dictionary).is_empty():
				return false
	var search_text := String(_search_by_view.get("entrances", ""))
	if search_text.is_empty():
		return true
	var target: Dictionary = entrance.get("target", {})
	var cell: Vector2i = entrance.get("cell", Vector2i.ZERO)
	var haystack := "%s %s %s %s" % [
		String(entrance.get("name", "")), String(entrance.get("art", "")),
		String(target.get("map", "")), state,
	]
	haystack += " %s %d %d" % [_studio.map_title(String(entrance.get("map", ""))), cell.x, cell.y]
	return haystack.to_lower().contains(search_text)


func _entrance_card(entrance: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Entrance_%d" % int(entrance.get("index", -1))
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	var map_id := String(entrance.map)
	var index := int(entrance.index)
	var selected := _selected_key == _entrance_key(entrance)
	card.add_theme_stylebox_override(
		"panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.AMBER if selected else UiTheme.LINE, 2 if selected else 1, 3, Vector2(5, 4))
	)
	var content := Ui.vbox([], 2)
	var cell: Vector2i = entrance.cell
	var title := StudioText.f("people_entrance_title", [
		StudioText.t("people_entrance_" + String(entrance.kind)),
		StudioAssets.name_of(String(entrance.art)), cell.x, cell.y,
	])
	content.add_child(StudioStyle.caption(title))
	var target: Dictionary = entrance.get("target", {})
	var state := String(entrance.get("state", "missing"))
	var destination := ""
	if not target.is_empty():
		var target_at := OverworldMap.cell_of(target.get("at", [0, 0]))
		var facing := String(target.get("facing", ""))
		var facing_label := StudioText.t("link_face_" + facing) if facing != "" else StudioText.t("people_current_facing")
		destination = StudioText.f(
			"people_destination_line",
			[
				_studio.map_title(String(target.get("map", ""))), target_at.x, target_at.y,
				facing_label,
			]
		)
	var status := StudioText.t("people_link_state_" + state)
	if destination != "":
		status = StudioText.f("people_link_destination", [status, destination])
	var problem: Dictionary = entrance.get("problem", {})
	if problem.is_empty():
		content.add_child(StudioStyle.caption(status))
	else:
		var diagnostic := StudioQuestUi.link("! " + status, func() -> void: _emit_entrance("locate", entrance))
		diagnostic.name = "EntranceProblem_" + str(index)
		diagnostic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		diagnostic.add_theme_color_override("font_color", UiTheme.WARN)
		diagnostic.tooltip_text = StudioText.t("people_problem_locate")
		content.add_child(diagnostic)
	var actions := Ui.flow([], 3) as HFlowContainer
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var locate := StudioStyle.button(StudioText.t("people_locate"), func() -> void:
		_emit_entrance("locate", entrance))
	locate.name = "EntranceLocate_" + str(index)
	locate.custom_minimum_size.y = 22
	actions.add_child(locate)
	var link_label := StudioText.t("people_repair_link") if not problem.is_empty() else StudioText.t("people_link_change") if not target.is_empty() else StudioText.t("people_link")
	var link_button := StudioStyle.button(link_label, func() -> void:
		_emit_entrance("link", entrance))
	link_button.name = "EntranceLink_" + str(index)
	link_button.custom_minimum_size.y = 22
	actions.add_child(link_button)
	if state == "valid":
		var is_building_room := String(entrance.kind) == "building" and bool(entrance.get("interior", false))
		var go_label := StudioText.t("people_open_room") if is_building_room else StudioText.t("people_go_to")
		var go := StudioStyle.button(go_label, func() -> void:
			_emit_entrance("go", entrance))
		go.name = "EntranceGo_" + str(index)
		go.custom_minimum_size.y = 22
		actions.add_child(go)
	if String(entrance.kind) == "building":
		if target.is_empty():
			var make := StudioStyle.button(StudioText.t("people_make_room"), func() -> void:
				_emit_entrance("make_room", entrance))
			make.name = "EntranceRoom_" + str(index)
			make.custom_minimum_size.y = 22
			actions.add_child(make)
		else:
			var unlink := StudioStyle.button(StudioText.t("people_unlink"), func() -> void:
				_emit_entrance("unlink", entrance))
			unlink.name = "EntranceUnlink_" + str(index)
			unlink.custom_minimum_size.y = 22
			actions.add_child(unlink)
	else:
		var remove := StudioStyle.button(StudioText.t("people_delete_warp"), func() -> void:
			_emit_entrance("delete", entrance))
		remove.name = "EntranceDelete_" + str(index)
		remove.custom_minimum_size.y = 22
		actions.add_child(remove)
	content.add_child(actions)
	card.add_child(content)
	return card


func _emit_entrance(action: String, entrance: Dictionary) -> void:
	var map_id := String(entrance.get("map", ""))
	var index := int(entrance.get("index", -1))
	_selected_key = _entrance_key(entrance)
	entrance_action_requested.emit(action, map_id, index, entrance.get("source", {}))


func _entrance_key(entrance: Dictionary) -> String:
	var cell: Vector2i = entrance.get("cell", Vector2i.ZERO)
	return "entrance:%s:%s:%s:%d:%d" % [
		String(entrance.get("map", "")), String(entrance.get("kind", "")), String(entrance.get("art", "")), cell.x, cell.y,
	]


func _show_start() -> void:
	var map := _studio.current_map()
	var start := OverworldMap.cell_of(map.get("start", [0, 0]))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_2, UiTheme.LINE, 1, 3, Vector2(8, 6)))
	var content := Ui.vbox([], 4)
	var current_facing := String(map.get("facing", "down"))
	content.add_child(StudioStyle.caption(StudioText.t("people_start_label")))
	content.add_child(StudioStyle.caption(
		StudioText.f("people_start_current", [start.x, start.y, StudioText.t("link_face_" + current_facing)])
	))
	content.add_child(StudioStyle.caption(StudioText.t("people_start_help")))
	var actions := Ui.flow([], 4) as HFlowContainer
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var facing := OptionButton.new()
	facing.name = "StartFacing"
	facing.focus_mode = Control.FOCUS_NONE
	var facing_choice := _studio.start_facing_choice()
	var selected_facing := facing_choice if StudioLink.FACINGS.has(facing_choice) else current_facing
	actions.add_child(StudioStyle.caption(StudioText.t("people_start_facing_label")))
	for direction: String in StudioLink.FACINGS:
		facing.add_item(StudioText.t("link_face_" + direction))
		facing.set_item_metadata(facing.item_count - 1, direction)
	for option: int in facing.item_count:
		if String(facing.get_item_metadata(option)) == selected_facing:
			facing.select(option)
	facing.item_selected.connect(func(option: int) -> void:
		start_facing_requested.emit(String(facing.get_item_metadata(option)))
	)
	actions.add_child(facing)
	var apply_facing := StudioStyle.button(
		StudioText.t("people_apply_facing"), func() -> void: start_facing_apply_requested.emit()
	)
	apply_facing.name = "ApplyStartFacing"
	apply_facing.disabled = selected_facing == current_facing
	actions.add_child(apply_facing)
	var locate := StudioStyle.button(StudioText.t("people_locate"), func() -> void:
		_studio.focus((Vector2(start) + Vector2(0.5, 0.5)) * OverworldScale.TILE))
	locate.name = "LocateStart"
	actions.add_child(locate)
	var set_start_button := StudioStyle.button(StudioText.t("people_set_start"), func() -> void: start_requested.emit())
	set_start_button.name = "SetStart"
	actions.add_child(set_start_button)
	content.add_child(actions)
	card.add_child(content)
	_cards.add_child(card)
