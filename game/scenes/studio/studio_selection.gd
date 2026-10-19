class_name StudioSelection
extends RefCounted
## What is selected in Edit (Concept/v0.3/10, section 7.2): objects by session id, so a selection survives the rebuilds
## every command causes (an index can move when something before it is deleted; a sid never does). It also shows the
## selection: outlines over the town and the fields in the inspector.

## The sids of what is selected, in the order picked; the last is the one the inspector shows when it is alone.
var sids: Array[int] = []

var _studio: StudioMode


func _init(studio: StudioMode) -> void:
	_studio = studio


## Selects the object at this index of the map's `objects`, or nothing with -1.
func select(index: int) -> void:
	var picked: Array[int] = []
	if index >= 0 and index < (_studio.current_map().get("objects", []) as Array).size():
		var sid := _studio.work.sid_at(index)
		if sid >= 0:
			picked.append(sid)
	set_sids(picked)


func set_sids(list: Array[int]) -> void:
	sids = list.duplicate()
	refresh()


func has(index: int) -> bool:
	return _studio.work.sid_at(index) in sids


## Shift-click: adds the object to the selection, or takes it out when it is in.
func toggle(index: int) -> void:
	var sid := _studio.work.sid_at(index)
	if sid < 0:
		return
	if sid in sids:
		sids.erase(sid)
	else:
		sids.append(sid)
	refresh()


## The map indexes of what is selected, in the order picked.
func indexes() -> Array[int]:
	var out: Array[int] = []
	for sid: int in sids:
		var index := _studio.work.index_of(sid)
		if index >= 0:
			out.append(index)
	return out


## Selects everything whose cells the rectangle (world pixels) touches; `add` keeps what was selected.
func select_in(rect: Rect2, add := false, filter := "all") -> void:
	var picked: Array[int] = []
	if add:
		picked = sids.duplicate()
	for sid: int in in_area(rect, filter):
		if sid not in picked:
			picked.append(sid)
	set_sids(picked)


## Uses footprints rather than crowns, so a tree leaning over the rectangle is kept unless its planted cell is touched.
func in_area(rect: Rect2, filter := "all") -> Array[int]:
	var tile := float(OverworldScale.TILE)
	var picked: Array[int] = []
	var seen: Dictionary = {}
	var entries := StudioAssets.entries()
	var map := _studio.current_map()
	var bounds := Rect2(Vector2.ZERO, Vector2(int(map.get("width", 0)), int(map.get("height", 0))) * tile)
	var area := rect.abs().intersection(bounds)
	if not area.has_area():
		return picked
	var first := Vector2i((area.position / tile).floor())
	var last := Vector2i(((area.end - Vector2.ONE * 0.01) / tile).floor())
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1):
			for index: int in _studio.pick().objects_at_cell(Vector2i(x, y)):
				if seen.has(index):
					continue
				seen[index] = true
				if not _matches_area_filter(_studio.object_at(index), filter, entries):
					continue
				var sid := _studio.work.sid_at(index)
				if sid >= 0:
					picked.append(sid)
	return picked


func _matches_area_filter(object: Dictionary, filter: String, entries: Dictionary) -> bool:
	if filter == "all":
		return true
	if String(object.get("kind", "")) != "prop":
		return false
	if filter == "props":
		return true
	var entry: Dictionary = entries.get(String(object.get("art", "")), {})
	return filter == "trees" and String(entry.get("category", "")) == "nature" and String(entry.get("subcategory", "")) == "trees"


## Shows the selection: its outlines over the town and its fields in the inspector. The sids that are no longer in the
## map (deleted, or undone away) drop out.
func refresh() -> void:
	var tile := float(OverworldScale.TILE)
	var now := indexes()
	var kept: Array[int] = []
	for index: int in now:
		kept.append(_studio.work.sid_at(index))
	sids = kept
	_studio.selection = now.back() if not now.is_empty() else -1
	var overlay := _studio.overlay()
	if overlay == null:
		return
	var feet: Array[Rect2] = []
	var pictures: Array[Rect2] = []
	for index: int in now:
		var box := StudioPick.footprint(_studio.object_at(index))
		feet.append(Rect2(Vector2(box.position) * tile, Vector2(box.size) * tile))
		var picture := _studio.pick().picture_rect(index)
		if picture.has_area():
			pictures.append(picture)
	overlay.selected_footprints = feet
	overlay.selected_pictures = pictures
	overlay.handles = _studio.handle_rects()
	var inspector := _studio.inspector()
	var panel := _studio.place_panel()
	if now.is_empty():
		inspector.show_map(_map_info())
		panel.clear_preview()
	elif now.size() == 1:
		var object := _studio.object_at(now[0])
		var raw := _studio.work.raw(now[0])
		if String(object.get("art", "")) != "":
			panel.preview_asset(String(object.art), raw)
		elif String(object.get("kind", "")) == "person":
			panel.preview_asset(String(object.get("id", "")), raw)
		else:
			panel.clear_preview()
		var stack := _studio.stack()
		var place := stack.find(now[0])
		inspector.show_object(
			StudioPick.describe(object),
			raw,
			place + 1 if place >= 0 else 1,
			maxi(1, stack.size()),
			sids[0]
		)
		match String(object.get("kind", "")):
			"building", "warp":
				inspector.show_links(sids[0], _links_info(object, raw))
			"person":
				inspector.show_person(_person_info(String(object.get("id", "")), raw))
			"prop":
				inspector.show_thing(sids[0], raw)
	else:
		panel.clear_preview()
		var names: Array[String] = []
		for index: int in now:
			names.append(StudioPick.describe(_studio.object_at(index)))
		inspector.show_many(names)
	overlay.queue_redraw()


## What the inspector's links section shows for a building or a warp: where its raw `to` leads, and whether an interior
## can be made for it (a building that leads nowhere).
func _links_info(object: Dictionary, raw: Dictionary) -> Dictionary:
	var kind := String(object.get("kind", "building"))
	var leads: Dictionary = {}
	var to: Variant = raw.get("to")
	if to is Dictionary and String((to as Dictionary).get("map", "")) != "":
		var map_id := String((to as Dictionary).map)
		var maps: Dictionary = _studio.catalog().get("maps", {})
		var target: Variant = maps.get(map_id)
		var shown := String((target as Dictionary).get("name", map_id)) if target is Dictionary else map_id
		var facing := String((to as Dictionary).get("facing", ""))
		leads = {
			"map": map_id,
			"name": shown if shown != "" else map_id,
			"at": OverworldMap.cell_of((to as Dictionary).get("at", [0, 0])),
			"facing": StudioText.t("link_face_" + facing) if facing != "" else StudioText.t("people_current_facing"),
		}
	return {"kind": kind, "leads": leads, "can_make": kind == "building" and leads.is_empty()}


## What the inspector's person section shows: the townsperson's name and title, their talk file, and the lines of the
## quests and talk that mention them (StudioDoors.mentions).
func _person_info(id: String, placement: Dictionary) -> Dictionary:
	var catalog := _studio.catalog()
	var townsfolk: Dictionary = catalog.get("townsfolk", {})
	var person: Dictionary = townsfolk.get(id, {})
	var talk_id := String(person.get("talk", id))
	var talk_file := _studio.content_root().path_join("packs/core/overworld/talk").path_join(talk_id + ".jsonc")
	var talk := _studio.quests.data("talk/" + talk_id)
	var quests := _studio.quests.data("quests")
	var mentions: Array[String] = StudioDoors.mentions(id, quests, talk)
	var schedules: Dictionary = catalog.get("schedules", {})
	var raw_schedule: Variant = schedules.get(id, {})
	var schedule: Dictionary = raw_schedule if raw_schedule is Dictionary else {}
	return {
		"id": id,
		"name": String(person.get("name", id)),
		"title": String(person.get("title", "")),
		"map": _studio.map_title(String(_studio.current_map().get("id", ""))),
		"at": OverworldMap.cell_of(placement.get("at", [0, 0])),
		"facing": String(placement.get("facing", "down")),
		"talk_id": talk_id,
		"talk_file": talk_file,
		"talk_available": townsfolk.has(id) and _studio.quests.talk_available(talk_id),
		"schedule": schedule.duplicate(true),
		"mentions": mentions,
		"quest_references": StudioDoors.quest_references(id, quests, talk),
	}


## What the inspector's map section shows, from the map being edited.
func _map_info() -> Dictionary:
	var current := _studio.current_map()
	return {
		"id": String(current.get("id", "")),
		"name": String(current.get("name", current.get("id", ""))),
		"size": Vector2i(int(current.get("width", 0)), int(current.get("height", 0))),
		"interior": bool(current.get("interior", false)),
		"start": current.get("start", Vector2i.ZERO),
		"facing": String(current.get("facing", "down")),
	}
