class_name StudioWork
extends RefCounted
## What Lanternroot Studio does to a map in phase S1 (ADR-0066, Concept/v0.3/10, section 7): the sessions (one draft per
## map), and every edit as a command through the history: move, nudge, place, duplicate, copy and paste, delete, flip,
## turn, and set a field. After each command the map is rebuilt from the doc and put in the shared catalog (so Play
## walks it), the town is redrawn, and the draft is saved two seconds later. The Studio (StudioMode) holds the picture
## and the mouse; this decides nothing about them.
##
##   studio.work.move([sid], Vector2i(3, 0))    # {ok, reason}: refused, with the reason, when it does not fit
##   studio.work.undo()
##
## Nothing here writes a content file: drafts only, in StudioMode.drafts_dir.

const SAVE_AFTER := 2.0
## The fields a new thing, a pasted one or a picked-up one does not carry over (they name one thing).
const NOT_COPIED: Array[String] = ["id", "program", "solid_unless", "to"]
## A field set to its default is erased instead, so the file stays as short as it was.
const DEFAULTS := {"solid": true, "sink": 0, "text": "", "name": ""}

## What Ctrl+C took: the objects as their file says them, kept for the run (and across maps).
static var clipboard: Array[Dictionary] = []

var _studio: StudioMode
var _sessions: Dictionary = {}
var _session: StudioSession
var _countdown := -1.0
## The maps whose catalog entry is the draft's (to put back the file's when the draft is not played).
var _swapped: Dictionary = {}
var _store_root := ""
var _thing_files: StudioThings
var _world_transactions: StudioWorldTransaction
var _schedule_history: StudioHistory
var _schedule_base: StudioDoc
var transaction_recovery: Dictionary = {"ok": true, "recovered": false, "error": ""}
## What the last successful build was made from (see _build), and the schema of one object of a map.
var _base: Dictionary = {}
static var _item_schema: Dictionary = {}
## The cursor can redraw many times without changing cells. Keep the last immutable plan until its inputs change.
var _boundary_doc: StudioDoc
var _boundary_key := ""
var _boundary_preview: Dictionary = {}


func _init(studio: StudioMode) -> void:
	_studio = studio
	_world_transactions = StudioWorldTransaction.new(StudioMode.drafts_dir)
	transaction_recovery = _world_transactions.recovery


# --- sessions -----------------------------------------------------------------------------------------------------


## Starts editing a map: its session, from the draft when there is one. False when the map's file cannot be read.
func open(id: String) -> bool:
	if not bool(transaction_recovery.get("ok", false)):
		_studio.say(String(transaction_recovery.get("error", "A previous world transaction needs recovery.")), true)
		return false
	_sync_schedules_from_draft()
	_session = _session_of(id)
	if _session == null:
		return false
	_restore_saved_world_action(_session)
	if _session.changes() > 0:
		refresh()
	else:
		_prime()
	return true


## Builds the doc once without drawing it, so the first edit after opening is drawn by its changes alone, like every
## later one: the town on screen is the content's map, which is the doc as it stands (it has no changes).
func _prime() -> void:
	var built := _build(_session.doc())
	if bool(built.get("ok", false)) and not _base.is_empty():
		_base["map"] = _studio.current_map()


func session() -> StudioSession:
	return _session


## Map id -> session, shared with Publish so the edits it reviews are the edits on screen.
func sessions() -> Dictionary:
	return _sessions


func doc() -> StudioDoc:
	return _session.doc() if _session != null else StudioDoc.new()


func _session_of(id: String) -> StudioSession:
	if not _sessions.has(id):
		var made := StudioSession.open(id, StudioMode.drafts_dir, _studio.content_root())
		if made == null:
			return null
		_sessions[id] = made
	return _sessions[id]


## The object at this index of the map, as its file says it (no defaults filled in), or {}.
func raw(index: int) -> Dictionary:
	var objects: Array = doc().data.get("objects", [])
	return (objects[index] as Dictionary).duplicate(true) if index >= 0 and index < objects.size() else {}


func sid_at(index: int) -> int:
	var sids := doc().sids
	return sids[index] if index >= 0 and index < sids.size() else -1


func index_of(sid: int) -> int:
	return doc().index_of_sid(sid)


# --- doing, undoing, saving ---------------------------------------------------------------------------------------


## Applies a command to the draft. {ok, ...} as StudioCommands.apply; a refused command changes nothing.
func command(command_data: Dictionary) -> Dictionary:
	if not bool(transaction_recovery.get("ok", false)):
		return {"ok": false, "error": String(transaction_recovery.get("error", "A previous world transaction needs recovery."))}
	if _session == null:
		return {"ok": false, "error": "no map is being edited"}
	var map_picker_changed := _changes_map_links(command_data, doc())
	var t := Time.get_ticks_usec()
	var connected := StudioBoundary.connected_command(doc(), command_data, StudioAssets.entries())
	var result := _session.do(connected)
	_studio.lap("apply", t)
	if result.ok:
		_changed()
		_elsewhere(result.done)
		if map_picker_changed:
			_studio.clear_map_names()
	else:
		_studio.say(String(result.error), true)
	return result


func undo() -> bool:
	if _session == null:
		return false
	var transaction_id := _session.history.transaction_id_for_undo()
	if transaction_id != "":
		var plan := _plan_for_history(transaction_id)
		if plan.is_empty():
			_studio.say("This world action cannot be safely undone because its transaction record is unavailable.", true)
			return false
		if not _world_undo_redo(plan, false):
			return false
		_studio.say("Undid: " + String(plan.get("label", "the world action")), false)
		return true
	var labels := _session.history.labels()
	var applied := _session.history.peek_undo()
	var map_picker_changed := _changes_map_links(applied, _session.doc())
	if _session.undo():
		_changed()
		_moved_cells(applied)
		_elsewhere(applied)
		if map_picker_changed:
			_studio.clear_map_names()
		_studio.say("Undid: " + (labels.back() if not labels.is_empty() else "a change"), false)
		return true
	return false


func redo() -> bool:
	if _session == null:
		return false
	var transaction_id := _session.history.transaction_id_for_redo()
	if transaction_id != "":
		var plan := _plan_for_history(transaction_id)
		if plan.is_empty():
			_studio.say("This world action cannot be safely redone because its transaction record is unavailable.", true)
			return false
		if not _world_undo_redo(plan, true):
			return false
		_studio.say("Redid: " + String(plan.get("label", "the world action")), false)
		return true
	var applied := _session.history.peek_redo()
	var map_picker_changed := _changes_map_links(applied, _session.doc())
	if _session.redo():
		_changed()
		_moved_cells(applied)
		_elsewhere(applied)
		if map_picker_changed:
			_studio.clear_map_names()
		_studio.say("Redid the change", false)
		return true
	return false


func _changed() -> void:
	refresh()
	_countdown = SAVE_AFTER


## Reachability labels only depend on entrance links, so object placement does not rescan every map.
func _changes_map_links(command_data: Dictionary, before: StudioDoc) -> bool:
	match String(command_data.get("type", "")):
		"batch":
			for nested: Variant in command_data.get("commands", []):
				if nested is Dictionary and _changes_map_links(nested, before):
					return true
		"set":
			return String(command_data.get("key", "")) == "to"
		"add":
			var object: Variant = command_data.get("object", {})
			return object is Dictionary and (object as Dictionary).get("to") is Dictionary
		"remove":
			return before.object_of_sid(int(command_data.get("sid", -1))).has("to")
	return false


## Rebuilds the map from the doc, puts it in the catalog, and has the Studio redraw. False when the data does not fit
## the map schema (the town stays as it was, and the status bar says why).
func refresh() -> bool:
	var t := Time.get_ticks_usec()
	var built := _build(_session.doc())
	_studio.lap("build", t)
	if not built.ok:
		_studio.say("The draft does not fit the map schema: " + String((built.errors as Array).front()), true)
		return false
	_studio.catalog().maps[_session.map_id] = built.map
	_swapped[_session.map_id] = true
	_studio.map_rebuilt(built.map, built)
	return true


## What StudioSession.build makes, from the last build when it was of the same map: the objects the doc did not change
## keep their checked form (the schema check is nearly all of the cost), and only the new and the changed are checked.
## The result also says what changed (`changes`: StudioPick.changes plus `base_map`, the map the last build made, which
## the picture must still be showing for the change to be the whole story); no `changes` means everything is new.
# LEARN: the check of one object depends on that object alone, so a checked object stays good for as long as the object
# it was made from is equal to the new one. The doc is never changed in place (a command works on a copy), so keeping
# the old objects as they were is enough to tell.
func _build(doc: StudioDoc) -> Dictionary:
	var objects: Array = doc.data.get("objects", [])
	var terrain: Dictionary = _studio.catalog().terrain
	var changes := {}
	if not _base.is_empty() and String(_base.path) == _session.path:
		changes = StudioPick.changes(_base.sids, _base.raw, doc.sids, objects)
	var diagnostics: Array[Dictionary] = []
	var head := doc.data.duplicate()
	head["objects"] = []
	var checked := ContentLoader._checked(OverworldContent.map_schema(), head, _session.path, "", diagnostics)
	var errors: Array[String] = []
	var list: Array = []
	if checked.is_empty() or not (doc.data.get("objects", []) is Array):
		return _unbuilt(doc)
	if _item_schema.is_empty():
		_item_schema = (OverworldContent.map_schema().fields.objects as Dictionary).item
	for index: int in objects.size():
		var kept: int = changes.old_of_new[index] if not changes.is_empty() else -1
		if kept >= 0:
			list.append((_base.checked as Array)[kept])
		else:
			list.append(Schema._check(_item_schema, objects[index], "objects[%d]" % index, errors))
	if not errors.is_empty():
		return _unbuilt(doc)
	checked["objects"] = list
	var made := OverworldMap.build(checked, terrain)
	var result := {"ok": true, "map": made.map, "errors": made.errors, "problems": made.problems, "diagnostics": diagnostics}
	if not changes.is_empty():
		changes["base_map"] = _base.map
		result["changes"] = changes
	_base = {"path": _session.path, "sids": doc.sids.duplicate(), "raw": objects, "checked": list, "map": made.map}
	return result


## The build that says what is wrong, for a doc that does not fit the schema (the slow, whole check). The last build is
## forgotten, since the picture no longer follows the doc.
func _unbuilt(doc: StudioDoc) -> Dictionary:
	_base = {}
	return StudioSession.build_data(doc.data, _session.path, _studio.catalog().terrain)


## The draft's saving clock: saves two seconds after the last change.
func tick(delta: float) -> void:
	if _countdown < 0.0:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		flush()


## Saves every draft with changes the file does not hold. True when all were written.
func flush() -> bool:
	_countdown = -1.0
	var all := true
	for id: String in _sessions:
		var session: StudioSession = _sessions[id]
		if session.unsaved:
			all = session.save() and all
	_studio.draft_changed()
	return all


## The files' maps go back in the catalog in place of the draft's (when the draft is not played).
func restore_files() -> void:
	var terrain: Dictionary = _studio.catalog().terrain
	for id: String in _swapped:
		var built := StudioSession.build_file(id, terrain, _studio.content_root())
		if built.ok:
			_studio.catalog().maps[id] = built.map
	_swapped.clear()


## Play draft: the draft maps of every map that has a draft go in the catalog and the save is pointed elsewhere; off, the
## files' maps come back and the save is the real one again.
func set_play_draft(on: bool) -> void:
	if on:
		flush()
		var maps_folder := _studio.content_root().path_join("packs/core/overworld/maps") + "/"
		for path: String in StudioFiles.list_drafts(StudioMode.drafts_dir):
			if path.begins_with(maps_folder) and path.ends_with(".jsonc"):
				var made := _session_of(path.get_file().get_basename())
				if made != null and made.changes() > 0:
					var built := made.build(_studio.catalog().terrain)
					if built.ok:
						_studio.catalog().maps[made.map_id] = built.map
						_swapped[made.map_id] = true
		put_drafted_things()
		_sync_schedules_from_draft()
		if _studio.quests != null:
			_studio.quests.put_in_catalog()
	else:
		restore_files()
		_sync_schedules_from_draft(false)
		if _studio.quests != null:
			_studio.quests.put_in_catalog(false)
	point_store(on)


## Published world actions no longer belong to draft undo. Reset the hidden schedule history along with the map sessions.
func published(paths: Array[String]) -> void:
	var histories := {}
	for value: Variant in _sessions.values():
		if value is StudioSession:
			histories[String((value as StudioSession).path)] = (value as StudioSession).history
	if _schedule_history != null:
		histories[_schedule_path()] = _schedule_history
	_world_transactions.published(paths, histories)
	if paths.has(_schedule_path()):
		var source := StudioFiles.read_text(_schedule_path())
		var parsed := StudioDoc.parse(_schedule_path(), "schedules", source)
		if bool(parsed.get("ok", false)):
			_schedule_base = parsed.doc as StudioDoc
			_schedule_history = StudioHistory.new(parsed.doc as StudioDoc)
		_thing_files = StudioThings.new(StudioMode.drafts_dir, _studio.content_root())
		_sync_schedules_from_draft()


## While the draft is played, the save goes to a folder of its own, so a play-test never writes the real save.
func point_store(on: bool) -> void:
	var store: Variant = _studio.parts().get("store")
	if not store is OverworldStore:
		return
	if on and _store_root == "":
		_store_root = (store as OverworldStore).root
		(store as OverworldStore).root = StudioMode.playtest_dir
		var begin: Callable = _studio.parts().get("playtest_begin", Callable())
		if begin.is_valid():
			var cell := _studio.cursor_cell() if _studio.cursor_over_map() else OverworldMap.cell_of(_studio.current_map().get("start", [0, 0]))
			begin.call(cell)
	elif not on and _store_root != "":
		var finish: Callable = _studio.parts().get("playtest_end", Callable())
		if finish.is_valid():
			finish.call()
		(store as OverworldStore).root = _store_root
		_store_root = ""


# --- edits --------------------------------------------------------------------------------------------------------


## Moves objects (by their sids) by whole cells. `free` (Alt) may override ordinary footprint conflicts; person moves
## still require a valid walkable cell, avoid transitions and keep NPC identity unique. {ok, reason}.
func move(sids: Array[int], by: Vector2i, free := false) -> Dictionary:
	if sids.is_empty() or by == Vector2i.ZERO:
		return {"ok": false, "reason": ""}
	var items: Array[Dictionary] = []
	var indexes: Array[int] = []
	var scheduled_id := ""
	var scheduled_target := Vector2i.ZERO
	var scheduled_facing := "down"
	for sid: int in sids:
		var index := index_of(sid)
		var object := _studio.object_at(index)
		if object.is_empty():
			return {"ok": false, "reason": "that is no longer there"}
		if String(object.get("kind", "")) == "person":
			var person_id := String(object.get("id", ""))
			var schedule: Variant = _studio.catalog().get("schedules", {}).get(person_id, {})
			if schedule is Dictionary and not (schedule as Dictionary).is_empty():
				if String(_session.doc().data.get("id", "")) != "lanternroot":
					var reason := StudioText.f("people_scheduled_cross_map_blocked", [person_id])
					_studio.say(reason, true)
					return {"ok": false, "reason": reason}
				if sids.size() != 1:
					var reason := StudioText.f("people_scheduled_move_blocked", [person_id])
					_studio.say(reason, true)
					return {"ok": false, "reason": reason}
				scheduled_id = person_id
				scheduled_target = OverworldMap.cell_of(object.get("at", [0, 0])) + by
				scheduled_facing = String(object.get("facing", "down"))
		indexes.append(index)
		var moved := object.duplicate()
		moved.at = (object.at as Vector2i) + by
		items.append(moved)
	if scheduled_id != "":
		return place_person(scheduled_id, scheduled_target, scheduled_facing, free)
	for item: Dictionary in items:
		if String(item.get("kind", "")) != "person":
			continue
		var person_fit := person_move_fit(
			String(item.get("id", "")), OverworldMap.cell_of(item.get("at", [0, 0])), indexes
		)
		if not bool(person_fit.get("ok", false)):
			var reason := String(person_fit.get("reason", ""))
			_studio.say(reason, true)
			return {"ok": false, "reason": reason}
	var fit := fit_objects(items, indexes)
	if not fit.ok and not free:
		_studio.say(String(fit.reason), true)
		return {"ok": false, "reason": fit.reason}
	var result := command({"type": "move", "sids": sids, "by": [by.x, by.y]})
	if not result.ok:
		return {"ok": false, "reason": String(result.error)}
	if fit.ok:
		_studio.say("Moved %s" % _things(sids.size()), false)
	else:
		_studio.say("Placed anyway: " + String(fit.reason), true)
	return {"ok": true, "reason": String(fit.reason)}


## Puts a new object down: `template` is what StudioAssets.template makes (or an eyedropped copy), `cell` the cell the
## cursor is in, which is the bottom-middle cell of the footprint. {ok, reason, sid}. A person stands in one place
## (place_person), the start is the map's own (set_start), and a new warp leads to this map's start until it is linked.
func place(template: Dictionary, cell: Vector2i, free := false) -> Dictionary:
	if StudioBoundary.supported(template, StudioAssets.entries()):
		var joined := place_boundary(template, [cell], free)
		joined["sid"] = (joined.placed as Array)[0] if not (joined.placed as Array).is_empty() else -1
		return joined
	match String(template.get("kind", "")):
		"person":
			return place_person(String(template.get("id", "")), cell, String(template.get("facing", "down")), free)
		"start":
			return set_start(cell, free, String(template.get("facing", "")))
		"warp":
			if not template.has("to"):
				var start: Vector2i = _studio.current_map().get("start", Vector2i.ZERO)
				template = template.duplicate(true)
				template["to"] = {"map": _session.map_id, "at": [start.x, start.y], "facing": ""}
	var object := template.duplicate(true)
	var at := footing(_size_of(object), cell)
	object["at"] = [at.x, at.y]
	object = _keyed(object)
	var fit := placement_fit(_built_like(object, Vector2i.ZERO))
	if not fit.ok and not free:
		_studio.say(String(fit.reason), true)
		return {"ok": false, "reason": fit.reason, "sid": -1}
	var result := command({"type": "add", "object": object, "index": -1})
	if not result.ok:
		return {"ok": false, "reason": String(result.error), "sid": -1}
	_studio.say(("Placed %s" % _name(object)) if fit.ok else "Placed anyway: " + String(fit.reason), not fit.ok)
	var added := _added_sids(result.done)
	return {"ok": true, "reason": String(fit.reason), "sid": added[0] if not added.is_empty() else -1}


## Puts a row of new objects down as one change (one undo step): `cells` are cursor cells as `place` takes them (see
## StudioRow). Each piece is checked alone; the ones that do not fit are left out unless `free`. {ok, placed (the new
## sids), total}. The selection stays as it was.
func place_row(template: Dictionary, cells: Array[Vector2i], free := false) -> Dictionary:
	if StudioBoundary.supported(template, StudioAssets.entries()):
		return place_boundary(template, cells, free)
	if String(template.get("kind", "")) in ["person", "start", "warp"]:
		# One of these is not put down in rows: the last cell is where it goes.
		var one := place(template, cells.back(), free)
		var sids: Array[int] = []
		if bool(one.ok) and int(one.get("sid", -1)) > 0:
			sids.append(int(one.sid))
		return {"ok": bool(one.ok), "placed": sids, "total": 1}
	var commands: Array = []
	var first := {}
	for cell: Vector2i in cells:
		var object := template.duplicate(true)
		var at := footing(_size_of(object), cell)
		object["at"] = [at.x, at.y]
		object = _keyed(object)
		var fit := placement_fit(_built_like(object, Vector2i.ZERO))
		if not fit.ok and not free:
			continue
		if first.is_empty():
			first = object
		commands.append({"type": "add", "object": object, "index": -1})
	var placed: Array[int] = []
	var total := cells.size()
	if commands.is_empty():
		_studio.say(StudioText.t("row_none"), true)
		return {"ok": false, "placed": placed, "total": total}
	var one := commands.size() == 1
	var label := "Place a row of %d %s" % [commands.size(), _name(first)]
	var result := command(commands[0] if one else {"type": "batch", "name": label, "commands": commands})
	if not result.ok:
		return {"ok": false, "placed": placed, "total": total}
	placed = _added_sids(result.done)
	var all := placed.size() == total
	_studio.say(StudioText.t("row_placed" if all else "row_skipped") % [placed.size(), total], not all)
	return {"ok": true, "placed": placed, "total": total}


## Walkable boundary art still occupies a placement footprint. Keep wide-gate ghosts and final fit identical.
func placement_fit(built: Dictionary) -> Dictionary:
	var entries := StudioAssets.entries()
	if not StudioBoundary.group(built, entries).is_empty():
		if not StudioBoundary.gate_fits(built, built.at, doc().data.get("objects", []), entries):
			return {"ok": false, "reason": "Turn the gate to match a straight fence run; junctions need a fence post."}
	return fit_objects([built])


## A gate is walkable in Play but still occupies space in Edit. Protect every cell, including wide openings.
func fit_objects(items: Array[Dictionary], ignore: Array[int] = []) -> Dictionary:
	var probes: Array[Dictionary] = []
	var entries := StudioAssets.entries()
	var objects: Array = doc().data.get("objects", [])
	for item: Dictionary in items:
		var probe := item.duplicate()
		if not StudioBoundary.group(item, entries).is_empty():
			probe["solid"] = true
			var box := StudioPick.footprint(item)
			for y: int in range(box.position.y, box.end.y):
				for x: int in range(box.position.x, box.end.x):
					for index: int in _studio.pick().objects_at_cell(Vector2i(x, y)):
						if index in ignore:
							continue
						var old: Dictionary = objects[index]
						if old.has("id") or old.has("program") or not StudioBoundary.group(old, entries).is_empty():
							return {"ok": false, "reason": "overlaps the %s" % StudioFit.name_of(old)}
		probes.append(probe)
	return StudioFit.check(_studio.current_map(), _studio.pick(), probes, ignore)


## Checks a person drag against its destination's walkability and transition rules while ignoring the people in the
## carried selection. Global identity checks still include every draft map, so Alt cannot move a duplicate NPC.
func person_move_fit(person_id: String, cell: Vector2i, ignore: Array[int], allow_reanchor := false) -> Dictionary:
	var locations := StudioDoors.standing(map_documents(), person_id)
	if locations.size() > 1:
		return {"ok": false, "reason": StudioText.f("people_duplicate_blocked", [person_id])}
	var candidate := _studio.current_map().duplicate(true)
	var ignored_indexes := {}
	var ignored_ids := {}
	var objects: Array = doc().data.get("objects", [])
	for index: int in ignore:
		if index < 0 or index >= objects.size() or not objects[index] is Dictionary:
			continue
		var object: Dictionary = objects[index]
		ignored_indexes[index] = true
		if String(object.get("kind", "")) != "person":
			continue
		var ignored_id := String(object.get("id", ""))
		if ignored_id != "":
			ignored_ids[ignored_id] = true
	var people: Array = []
	for value: Variant in candidate.get("people", []):
		if value is Dictionary and not ignored_ids.has(String((value as Dictionary).get("id", ""))):
			people.append(value)
	candidate["people"] = people
	var solid: Dictionary = candidate.get("solid", {}).duplicate()
	for occupied: Variant in solid.keys():
		if ignored_indexes.has(int(solid[occupied])):
			solid.erase(occupied)
	candidate["solid"] = solid
	var schedules: Dictionary = _studio.catalog().get("schedules", {})
	var state := StudioPeopleIndex.person_cell_state(candidate, person_id, cell, schedules, allow_reanchor)
	return {"ok": state == "valid", "reason": "" if state == "valid" else _person_cell_error(state)}


## Preview and commit share the same fitted connection plan, including edits to the existing endpoint's neighbors.
func boundary_plan(template: Dictionary, cells: Array[Vector2i], free := false) -> Dictionary:
	var entries := StudioAssets.entries()
	var key := JSON.stringify(template) + str(cells) + str(free) + str(entries.hash())
	if _boundary_doc == doc() and _boundary_key == key:
		return _boundary_preview
	var objects: Array = doc().data.get("objects", [])
	var proposed := StudioBoundary.plan(template, cells, objects, entries)
	var accepted: Array[Vector2i] = []
	var rejected: Array[Dictionary] = []
	var reason := ""
	var ignore: Array[int] = []
	ignore.assign(proposed.ignore)
	for candidate: Dictionary in proposed.candidates:
		var object: Dictionary = candidate.object
		var built := _built_like(object, Vector2i.ZERO)
		# A walkable gate still needs a clear placement cell. Its final collision flag must not let it overlap a
		# barrel or erase a protected named/programmed thing while painting an opening into an existing fence.
		var fit := fit_objects([built], ignore)
		if not StudioBoundary.gate_fits(template, built.at, objects, entries):
			fit = {"ok": false, "reason": "Turn the gate to match a straight fence run; junctions need a fence post."}
		if fit.ok or free:
			accepted.append(OverworldMap.cell_of(object.at))
		else:
			rejected.append(built)
			reason = String(fit.reason)
	var planned := StudioBoundary.plan(template, accepted, objects, entries)
	planned["accepted"] = accepted
	planned["rejected"] = rejected
	planned["total"] = cells.size()
	planned["reason"] = reason
	_boundary_doc = doc()
	_boundary_key = key
	_boundary_preview = planned
	return planned


func place_boundary(template: Dictionary, cells: Array[Vector2i], free := false) -> Dictionary:
	var plan := boundary_plan(template, cells, free)
	var commands: Array = []
	var placed: Array[int] = []
	for edit: Dictionary in plan.edits:
		var object: Dictionary = edit.object
		var index := int(edit.index)
		if index < 0:
			commands.append({"type": "add", "object": _keyed(object), "index": -1})
		else:
			var before := raw(index)
			for key: String in ["art", "solid", "flip"]:
				if before.get(key) != object.get(key):
					commands.append({"type": "set", "sid": sid_at(index), "key": key, "value": object.get(key)})
	if (plan.accepted as Array).is_empty():
		_studio.say(String(plan.get("reason", StudioText.t("row_none"))), true)
		return {"ok": false, "placed": placed, "total": cells.size()}
	if not commands.is_empty():
		var result := command({"type": "batch", "name": "Draw connected boundary", "commands": commands})
		if not result.ok:
			return {"ok": false, "placed": placed, "total": cells.size()}
		placed = _added_sids(result.done)
	var all := (plan.rejected as Array).is_empty()
	_studio.say(StudioText.t("row_placed" if all else "row_skipped") % [(plan.accepted as Array).size(), cells.size()], not all)
	return {"ok": true, "placed": placed, "total": cells.size()}


## The cell of the top-left corner of a footprint of `size` whose bottom-middle cell is `cell`.
static func footing(size: Vector2i, cell: Vector2i) -> Vector2i:
	return cell - Vector2i(size.x / 2, size.y - 1)


## Deletes objects. Ones with an `id` (people, things) are not deleted until `confirmed`: the result then says so
## ({ok: false, needs_confirm: true, names}), and the Studio asks.
func delete(sids: Array[int], confirmed := false) -> Dictionary:
	var named: Array[String] = []
	var scheduled_selected: Dictionary = {}
	var schedules: Dictionary = _studio.catalog().get("schedules", {})
	for sid: int in sids:
		var object := raw(index_of(sid))
		if object.has("id") or object.has("program") or String(object.get("kind", "")) == "person":
			named.append(String(object.get("id", _name(object))))
		if String(object.get("kind", "")) == "person":
			var person_id := String(object.get("id", ""))
			if schedules.has(person_id):
				scheduled_selected[person_id] = int(scheduled_selected.get(person_id, 0)) + 1
	if not scheduled_selected.is_empty():
		var world := map_documents()
		for person_id: String in scheduled_selected:
			var remaining := 0
			for location: Dictionary in StudioDoors.standing(world, person_id):
				var location_map := String(location.get("map", ""))
				var location_index := int(location.get("index", -1))
				if location_map == _session.map_id and sids.has(sid_at(location_index)):
					continue
				remaining += 1
			if remaining == 0:
				var reason := StudioText.f("people_scheduled_delete_blocked", [person_id])
				_studio.say(reason, true)
				return {"ok": false, "reason": reason}
	if not named.is_empty() and not confirmed:
		return {"ok": false, "needs_confirm": true, "names": named}
	if sids.is_empty():
		return {"ok": false}
	var commands: Array = []
	for sid: int in sids:
		commands.append({"type": "remove", "sid": sid})
	var label := "Remove %s" % (_name(raw(index_of(sids[0]))) if sids.size() == 1 else _things(sids.size()))
	var result := command(commands[0] if commands.size() == 1 else {"type": "batch", "name": label, "commands": commands})
	if result.ok:
		_studio.say("Deleted %s" % _things(sids.size()), false)
	return {"ok": result.ok}


## Flips props left to right (sets `flip`, or erases it to flip back). Buildings, signs and people refuse, with a
## message. Returns how many flipped.
func flip(sids: Array[int]) -> int:
	var commands: Array = []
	var refused := ""
	for sid: int in sids:
		var object := raw(index_of(sid))
		if not StudioAssets.can_flip(object):
			refused = _name(object)
			continue
		commands.append({"type": "set", "sid": sid, "key": "flip", "value": null if bool(object.get("flip", false)) else true})
	if commands.is_empty():
		_studio.say("%s cannot be flipped" % refused, true)
		return 0
	var one := commands.size() == 1
	var label := "Flip %s" % _things(commands.size())
	command(commands[0] if one else {"type": "batch", "name": label, "commands": commands})
	if refused != "":
		_studio.say("Flipped %d; %s cannot be flipped" % [commands.size(), refused], true)
	else:
		_studio.say("Flipped %s" % _things(commands.size()), false)
	return commands.size()


## `[` and `]` (Concept/v0.3/10, section 7.7): swaps each thing for the previous (`step` -1) or next (+1) variant of
## its catalog family, as one change: its art, its size (written as a new placement would be) and, for a building, the
## variant's door, with its feet (the bottom-middle cell) where they were. A flip the variant does not allow goes.
## Things with no other variant are left; when the new footprints do not fit nothing changes and the status bar says
## why. Returns how many were swapped.
func swap_variant(sids: Array[int], step: int) -> int:
	var entries := StudioAssets.entries()
	var commands: Array = []
	var built: Array[Dictionary] = []
	var indexes: Array[int] = []
	var named := ""
	for sid: int in sids:
		var object := raw(index_of(sid))
		var art := StudioCatalog.variant_of(entries, String(object.get("art", "")), step)
		if object.is_empty() or art == "":
			continue
		var entry := StudioAssets.entry_of(art)
		var size := OverworldMap.cell_of(entry.get("size", [1, 1]))
		var at := StudioCatalog.keep_feet(OverworldMap.cell_of(object.get("at", [0, 0])), _size_of(object), size)
		var kind := String(object.get("kind", "prop"))
		var wanted := {"art": art, "at": [at.x, at.y], "size": null}
		if object.has("art_size"):
			var shaped := StudioResize.object_at_size(object, size)
			var shape: Dictionary = shaped.object if bool(shaped.ok) else object
			for key: String in ["solid_rows", "solid_cells"]:
				if shape.has(key) or object.has(key):
					wanted[key] = shape.get(key)
		wanted["art_size"] = null
		wanted["art_shape"] = null
		if kind == "building" or size != Vector2i.ONE:
			wanted["size"] = [size.x, size.y]
		if kind == "building":
			wanted["door"] = entry.get("door", object.get("door"))
		if bool(object.get("flip", false)) and not StudioAssets.can_flip({"kind": kind, "art": art}):
			wanted["flip"] = null
		for key: String in wanted:
			if wanted[key] != object.get(key):
				commands.append({"type": "set", "sid": sid, "key": key, "value": wanted[key]})
		var moved := object.duplicate(true)
		for key: String in wanted:
			if wanted[key] == null:
				moved.erase(key)
			else:
				moved[key] = wanted[key]
		built.append(_built_like(moved, Vector2i.ZERO))
		indexes.append(index_of(sid))
		named = "%s (%s)" % [StudioAssets.name_of(art), String(entry.get("variant", art))]
	if built.is_empty():
		_studio.say("no other variant to swap to", true)
		return 0
	var fit := StudioFit.check(_studio.current_map(), _studio.pick(), built, indexes)
	if not fit.ok:
		_studio.say("The variant does not fit: " + String(fit.reason), true)
		return 0
	var label := "Swap %s for a variant" % (_name(raw(index_of(sids[0]))) if built.size() == 1 else _things(built.size()))
	if not command(commands[0] if commands.size() == 1 else {"type": "batch", "name": label, "commands": commands}).ok:
		return 0
	_studio.say(("Now %s" % named) if built.size() == 1 else "Swapped %s" % _things(built.size()), false)
	return built.size()


## Turns people to their next facing (down, left, up, right). Returns how many turned.
func turn(sids: Array[int]) -> int:
	var order: Array[String] = ["down", "left", "up", "right"]
	var commands: Array = []
	for sid: int in sids:
		var object := raw(index_of(sid))
		if String(object.get("kind", "")) == "person":
			var next := order[(order.find(String(object.get("facing", "down"))) + 1) % order.size()]
			commands.append({"type": "set", "sid": sid, "key": "facing", "value": next})
	if commands.is_empty():
		return 0
	command(commands[0] if commands.size() == 1 else {"type": "batch", "name": "Turn %s" % _things(commands.size()), "commands": commands})
	return commands.size()


## Resizes one placed picture in tiles, preserving its art and identity. The whole edit, including return links
## following a building's door, is one undoable batch. `free` allows the same placement exceptions as moving.
## Returns {ok, object, error, reason}; an unchanged size or a stale sid changes no history.
func resize_object(sid: int, size: Vector2i, free := false) -> Dictionary:
	var object := raw(index_of(sid)) if _session != null else {}
	var resized := StudioResize.object_at_size(object, size)
	if object.is_empty():
		resized = {"ok": false, "object": {}, "error": "that object is no longer available"}
	if not bool(resized.ok):
		_studio.say(String(resized.error), true)
		resized["reason"] = String(resized.error)
		return resized
	var moved: Dictionary = resized.object
	var fit := fit_objects([_built_like(moved, Vector2i.ZERO)], [index_of(sid)])
	if not bool(fit.ok) and not free:
		var reason := "That size does not fit: " + String(fit.reason)
		_studio.say(reason, true)
		return {"ok": false, "object": {}, "error": reason, "reason": reason}
	var commands: Array = []
	for key: String in ["size", "art_size", "art_shape", "door", "solid_rows", "solid_cells"]:
		if object.get(key) != moved.get(key):
			commands.append({"type": "set", "sid": sid, "key": key, "value": moved.get(key)})
	var change := {"type": "batch", "name": "Resize %s to %d × %d" % [_name(object), size.x, size.y], "commands": commands}
	if String(object.get("kind", "")) == "building":
		var from := StudioDoors.front_of(object)
		var to := StudioDoors.front_of(moved)
		var own := StudioDoors.retarget(doc().data, doc().sids, _session.map_id, from, to)
		if not own.is_empty():
			commands.append(own)
		var there: Array = []
		var back: Array = []
		for id: String in _map_ids():
			var other := _session_of(id)
			if id == _session.map_id or other == null:
				continue
			var follow := StudioDoors.retarget(other.doc().data, other.doc().sids, _session.map_id, from, to)
			if follow.is_empty():
				continue
			there.append({"map": id, "command": follow})
			back.append({"map": id, "command": StudioCommands.apply(other.doc(), follow).undo})
		if not there.is_empty():
			change["elsewhere"] = there
			change["elsewhere_undo"] = back
	var result := command(change)
	if not bool(result.ok):
		var error := String(result.get("error", "the size could not be changed"))
		return {"ok": false, "object": {}, "error": error, "reason": error}
	_studio.say("%s is now %d × %d" % [_name(object), size.x, size.y], false)
	return {"ok": true, "object": moved, "error": "", "reason": ""}


## Sets (or, for null or a default, erases) one field of one object. False when it changes nothing.
func set_field(sid: int, key: String, value: Variant) -> bool:
	var object := raw(index_of(sid))
	if object.is_empty():
		return false
	var wanted: Variant = null if (DEFAULTS.has(key) and value == DEFAULTS[key]) else value
	if wanted == object.get(key):
		return false
	return bool(command({"type": "set", "sid": sid, "key": key, "value": wanted}).ok)


## Copies objects beside the originals (the first free place near them), and returns the new sids. People are not
## copied: a person stands in one place.
func duplicate(sids: Array[int], free := false) -> Array[int]:
	var objects := _copyable(sids)
	if objects.is_empty():
		return []
	var box := _box_of(objects)
	var around: Array[Vector2i] = [Vector2i(box.size.x, 0), Vector2i(0, box.size.y), Vector2i(-box.size.x, 0), Vector2i(0, -box.size.y)]
	for radius: int in range(1, 9):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) == radius:
					around.append(Vector2i(dx, dy))
	for step: Vector2i in around:
		if _fits(objects, step):
			return _add_all(objects, step, "Duplicate")
	if free:
		return _add_all(objects, around[0], "Duplicate")
	_studio.say("no free place beside it", true)
	return []


## Ctrl+C: remembers the objects (not people) for a paste.
func copy(sids: Array[int]) -> int:
	clipboard = _copyable(sids)
	if clipboard.is_empty():
		_studio.say("nothing to copy (a person stands in one place)", true)
	else:
		_studio.say("Copied %s" % _things(clipboard.size()), false)
	return clipboard.size()


## Ctrl+V: the copied objects with the middle of their bottom row at `cell`, positions relative to each other kept.
## Returns the new sids; none when it does not fit and `free` is off.
func paste(cell: Vector2i, free := false) -> Array[int]:
	if clipboard.is_empty():
		_studio.say("nothing copied yet", true)
		return []
	var box := _box_of(clipboard)
	var anchor := Vector2i(box.position.x + box.size.x / 2, box.end.y - 1)
	var step := cell - anchor
	if not free and not _fits(clipboard, step):
		var items: Array[Dictionary] = []
		for object: Dictionary in clipboard:
			items.append(_built_like(object, step))
		_studio.say(String(StudioFit.check(_studio.current_map(), _studio.pick(), items).reason), true)
		return []
	return _add_all(clipboard, step, "Paste")


## The objects (by sid) as their file says them, without people and with the fields that name one thing dropped.
func _copyable(sids: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sid: int in sids:
		var object := raw(index_of(sid))
		if object.is_empty() or String(object.get("kind", "")) == "person":
			continue
		out.append(copy_of(object))
	return out


## An object as a new thing: without the fields that name one thing (its id, its program).
static func copy_of(object: Dictionary) -> Dictionary:
	var out := object.duplicate(true)
	for key: String in NOT_COPIED:
		out.erase(key)
	return out


func _fits(objects: Array[Dictionary], step: Vector2i) -> bool:
	var items: Array[Dictionary] = []
	for object: Dictionary in objects:
		items.append(_built_like(object, step))
	return bool(StudioFit.check(_studio.current_map(), _studio.pick(), items).ok)


## Adds the objects, moved by `step`, as one change. Returns the new sids and selects them.
func _add_all(objects: Array[Dictionary], step: Vector2i, verb: String) -> Array[int]:
	var commands: Array = []
	for object: Dictionary in objects:
		var added := object.duplicate(true)
		var at := OverworldMap.cell_of(added.get("at", [0, 0])) + step
		added["at"] = [at.x, at.y]
		commands.append({"type": "add", "object": added, "index": -1})
	var one := commands.size() == 1
	var label := "%s %s" % [verb, _name(objects[0]) if one else _things(commands.size())]
	var result := command(commands[0] if one else {"type": "batch", "name": label, "commands": commands})
	var sids: Array[int] = []
	if result.ok:
		sids = _added_sids(result.done)
		_studio.say("%s: %s" % [verb, _things(sids.size())], false)
	return sids


## Connection corrections can wrap a single add or accompany several adds. Selection only wants the new objects.
static func _added_sids(done: Dictionary) -> Array[int]:
	var sids: Array[int] = []
	if String(done.get("type", "")) == "add":
		sids.append(int(done.sid))
	elif String(done.get("type", "")) == "batch":
		for item: Dictionary in done.commands:
			sids.append_array(_added_sids(item))
	return sids


# --- the land (S5) ------------------------------------------------------------------------------------------------


## Paints `cells` with the ground `kind` as one change (StudioLand.paint: the legend grows when it lacks the kind).
## `label` names the change in the history ("Paint cobble" without one). {ok, changed}. Water painted under something
## solid is allowed, and said as a warning (the live check lists it too).
func paint(cells: Array[Vector2i], kind: String, label := "") -> Dictionary:
	if _session == null:
		return {"ok": false, "changed": 0}
	var painted := StudioLand.paint(doc().data, cells, kind)
	if not painted.ok:
		return {"ok": false, "changed": 0}
	var change: Dictionary = painted.command
	if label != "":
		change["name"] = label
	if not command(change).ok:
		return {"ok": false, "changed": 0}
	var count := int(painted.changed)
	var words := "Painted %d %s of %s" % [count, "cell" if count == 1 else "cells", kind]
	if String(painted.added_char) != "":
		words += " (the legend now has %s for %s)" % [painted.added_char, kind]
	var wet := _wet_things(cells) if kind == StudioRules.WATER else 0
	if wet > 0:
		_studio.say(words + ": water under %s" % _things(wet), true)
	else:
		_studio.say(words, false)
	return {"ok": true, "changed": count}


## How many solid things stand on any of `cells` (water painted under them).
func _wet_things(cells: Array[Vector2i]) -> int:
	var map := _studio.current_map()
	var solid: Dictionary = map.get("solid", {})
	var under := {}
	for cell: Vector2i in cells:
		if solid.has(cell):
			under[solid[cell]] = true
	return under.size()


## What growing or shrinking the map by `edges` ({left, top, right, bottom}, positive grows) would do, without doing
## it: StudioLand.resize's {ok, size, dropped} (or {ok: false, error}), and `links`, how many doors of other maps lead
## into this one (they move with it).
func resize_plan(edges: Dictionary, fill_kind: String) -> Dictionary:
	if _session == null:
		return {"ok": false, "error": "no map is being edited"}
	var plan := StudioLand.resize(doc().data, doc().sids, edges, fill_kind, _session.map_id)
	var links := 0
	for id: String in _studio.catalog().maps:
		if id != _session.map_id:
			var other := _session_of(id)
			if other != null:
				links += StudioLand.links_into(other.doc().data, _session.map_id).size()
	plan["links"] = links
	return plan


## Grows or shrinks the map (Concept/v0.3/10, section 7.8): one change that moves every thing with its cells, drops the
## ones that fall off, moves the start and this map's own links; the doors of other maps that lead here follow in their
## own drafts. {ok, size, dropped} or {ok: false, error}.
func resize(edges: Dictionary, fill_kind: String) -> Dictionary:
	var plan := resize_plan(edges, fill_kind)
	if not plan.ok:
		_studio.say(String(plan.error), true)
		return plan
	var result := command(plan.command)
	if not result.ok:
		return {"ok": false, "error": String(result.error)}
	_moved_cells(plan.command)
	var size: Vector2i = plan.size
	var dropped := (plan.dropped as Array).size()
	var words := "The map is now %d x %d" % [size.x, size.y]
	_studio.say(words + ("; %s fell off" % _things(dropped) if dropped > 0 else ""), dropped > 0)
	return plan


## After a change that moved this map's cells (a resize, its undo or its redo: the batch's `shift`), the doors of the
## other maps that lead here move the same way, the player keeps standing where they were, and the camera follows.
func _moved_cells(applied: Dictionary) -> void:
	if not applied.has("shift"):
		return
	var shift := OverworldMap.cell_of(applied.shift)
	if shift == Vector2i.ZERO:
		return
	_follow(_session.map_id, shift)
	_studio.cells_moved(shift)


## Moves every door of another map that leads into `map_id` by `shift`, each map's as a change in its own draft, and
## puts those maps in the catalog so Play walks them. Returns how many doors moved.
func _follow(map_id: String, shift: Vector2i) -> int:
	var moved := 0
	for id: String in _studio.catalog().maps.keys():
		if id == map_id:
			continue
		var other := _session_of(id)
		if other == null:
			continue
		var follow := StudioLand.follow(other.doc().data, other.doc().sids, map_id, shift)
		if follow.is_empty() or not bool(other.do(follow).ok):
			continue
		moved += (follow.commands as Array).size()
		_rebuilt(id, other)
	if moved > 0:
		_countdown = SAVE_AFTER
	return moved


## What a step does to other maps (a batch's `elsewhere`, StudioCommands): each command applied to its map's own draft,
## and that map put in the catalog so Play walks it. Returns how many were applied.
func _elsewhere(applied: Dictionary) -> int:
	var count := 0
	var map_picker_changed := false
	for item: Variant in applied.get("elsewhere", []):
		var id := String((item as Dictionary).get("map", ""))
		var other := _session_of(id)
		if other == null or other == _session:
			continue
		var changes_links := _changes_map_links((item as Dictionary).get("command", {}), other.doc())
		if not bool(other.do((item as Dictionary).command).ok):
			_studio.say("%s could not follow this change" % id, true)
			continue
		count += 1
		map_picker_changed = map_picker_changed or changes_links
		_rebuilt(id, other)
	if count > 0:
		_countdown = SAVE_AFTER
	if map_picker_changed:
		_studio.clear_map_names()
	return count


## Another map's draft changed: it goes in the catalog, so Play walks it and doors find it.
func _rebuilt(id: String, other: StudioSession) -> void:
	var built := other.build(_studio.catalog().terrain)
	if built.ok:
		_studio.catalog().maps[id] = built.map
		_swapped[id] = true
		if _studio.people_panel() != null:
			_studio.people_panel().refresh()


# --- things that take code (S8) -----------------------------------------------------------------------------------


## The drafts of the things' files (made once, from the drafts folder).
func things() -> StudioThings:
	if _thing_files == null:
		_thing_files = StudioThings.new(StudioMode.drafts_dir, _studio.content_root())
	return _thing_files


## Stable document key for the schedule file, shared with the transaction plan and Publish's plain-file draft path.
func _schedule_path() -> String:
	return _studio.content_root().path_join("packs/core/overworld/schedules.jsonc")


## The schedule editor's history is a regular StudioDoc history, but its text remains in the existing files.json draft
## collection so Publish, conflict review and Play draft keep using the established file path.
func _schedule_history_for_edit() -> StudioHistory:
	if _schedule_history != null:
		return _schedule_history
	var path := _schedule_path()
	var source := StudioFiles.read_text(path)
	var base := StudioDoc.parse(path, "schedules", source)
	if not bool(base.get("ok", false)):
		return null
	_schedule_base = base.doc as StudioDoc
	var draft: Dictionary = things().files.get(path, {})
	var draft_text := String(draft.get("text", source))
	var parsed := StudioDoc.parse(path, "schedules", draft_text)
	if not bool(parsed.get("ok", false)):
		return null
	_schedule_history = StudioHistory.new(parsed.doc as StudioDoc)
	return _schedule_history


func _sync_schedules_from_draft(with_drafts := true) -> void:
	var drafts := things().drafts() if with_drafts else {}
	var loaded := OverworldContent.load_world(_studio.content_root(), drafts)
	var schedules: Dictionary = _studio.catalog().get("schedules", {})
	schedules.clear()
	schedules.merge(loaded.catalog.get("schedules", {}))
	_studio.catalog()["schedules"] = schedules


## Stores a target doc for each participating document. For the shared files.json, only the schedule entry changes;
## drafts for dialogue and things created later are carried forward untouched.
func _world_storage_updates(plan: Dictionary, forward: bool) -> Array[Dictionary]:
	var updates: Array[Dictionary] = []
	var file_drafts: Dictionary = things().files.duplicate(true)
	var has_schedule := false
	for change: Dictionary in plan.get("changes", []):
		var target: StudioDoc = change.after_doc if forward else change.before_doc
		if String(change.path) == _schedule_path():
			has_schedule = true
			var base_data: Dictionary = _schedule_base.data if _schedule_base != null else {}
			if target.data == base_data:
				file_drafts.erase(_schedule_path())
			else:
				var previous_file_draft: Dictionary = file_drafts.get(_schedule_path(), {})
				var base_hash := String(previous_file_draft.get("base_hash", _schedule_base.base_hash if _schedule_base != null else ""))
				file_drafts[_schedule_path()] = {
					"text": target.to_text(),
					"base_hash": base_hash,
				}
			continue
		var session := _session_for_path(String(change.path))
		if session == null:
			return []
		updates.append(
			{
				"path": StudioFiles.draft_path(session.path, session.drafts_dir),
				"exists": true,
				"text": StudioFiles.draft_text(target, session.base_text, session.base_doc.sids),
			}
		)
	if has_schedule:
		updates.append(
			{
				"path": StudioFiles.file_drafts_path(StudioMode.drafts_dir),
				"exists": not file_drafts.is_empty(),
				"text": StudioFiles.file_drafts_text(file_drafts),
			}
		)
	return updates


func _session_for_path(path: String) -> StudioSession:
	for value: Variant in _sessions.values():
		if value is StudioSession and String((value as StudioSession).path) == path:
			return value as StudioSession
	return null


func _histories_for_plan(plan: Dictionary) -> Dictionary:
	var histories := {}
	for change: Dictionary in plan.get("changes", []):
		var key := String(change.key)
		if String(change.path) == _schedule_path():
			var schedule_history := _schedule_history_for_edit()
			if schedule_history == null:
				return {}
			histories[key] = schedule_history
		else:
			var session := _session_for_path(String(change.path))
			if session == null:
				return {}
			histories[key] = session.history
	return histories


func _apply_world_change(actions: Array[Dictionary], label: String) -> Dictionary:
	if not bool(transaction_recovery.get("ok", false)):
		return {"ok": false, "error": String(transaction_recovery.get("error", "A previous world transaction needs recovery."))}
	if not flush():
		return {"ok": false, "error": "The participating map drafts could not be saved before this move."}
	if not things().save():
		return {"ok": false, "error": "The shared file drafts could not be saved before this move."}
	var transaction_id := "people-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var plan := StudioWorldPlan.build(transaction_id, label, actions)
	if not bool(plan.get("ok", false)):
		return plan
	var validation := _validate_world_plan(plan)
	if not bool(validation.get("ok", false)):
		return validation
	var histories := _histories_for_plan(plan)
	if histories.size() != (plan.changes as Array).size():
		return {"ok": false, "error": "A document in this world transaction is no longer open."}
	var updates := _world_storage_updates(plan, true)
	if updates.is_empty():
		return {"ok": false, "error": "The world transaction could not stage its draft payloads."}
	var applied := _world_transactions.apply(plan, histories, updates)
	if not bool(applied.get("ok", false)):
		transaction_recovery = {"ok": not bool(applied.get("recovery_required", false)), "error": String(applied.get("error", ""))}
		return applied
	_after_world_change(plan)
	return {"ok": true, "plan": plan, "id": transaction_id}


func _validate_world_plan(plan: Dictionary) -> Dictionary:
	var candidate_maps := map_documents()
	var candidate_schedules: Dictionary = _studio.catalog().get("schedules", {}).duplicate(true)
	var changed_schedules: Array[String] = []
	for change: Dictionary in plan.get("changes", []):
		var candidate: StudioDoc = change.after_doc
		if String(candidate.kind) == "map":
			var built := StudioSession.build_data(candidate.data, candidate.path, _studio.catalog().terrain)
			if not bool(built.get("ok", false)) or not (built.get("errors", []) as Array).is_empty():
				return {"ok": false, "error": "A map in this move does not pass validation."}
			candidate_maps[String(candidate.data.get("id", ""))] = candidate.data
		elif String(candidate.kind) == "schedules":
			var diagnostics: Array[Dictionary] = []
			var checked := ContentLoader._checked(
				OverworldContent.schedules_schema(), candidate.data.duplicate(true), candidate.path, "", diagnostics
			)
			if checked.is_empty():
				return {"ok": false, "error": "The new schedule work anchor does not pass the schedule schema."}
			var previous: StudioDoc = change.before_doc
			for id: String in candidate.data:
				if previous.data.get(id) != candidate.data.get(id):
					changed_schedules.append(id)
			candidate_schedules = candidate.data
	for person_id: String in changed_schedules:
		var raw_schedule: Variant = candidate_schedules.get(person_id, {})
		if not raw_schedule is Dictionary or (raw_schedule as Dictionary).is_empty():
			return {"ok": false, "error": "A scheduled person must keep an authored work anchor."}
		var locations := StudioDoors.standing(candidate_maps, person_id)
		if locations.size() != 1 or String(locations[0].map) != "lanternroot" \
		or OverworldMap.cell_of(locations[0].at) != OverworldMap.cell_of((raw_schedule as Dictionary).get("work", [-1, -1])):
			return {"ok": false, "error": "The scheduled work anchor and the person's map placement must move together."}
	var people := StudioPeopleIndex.people(
		_studio.catalog().get("townsfolk", {}), candidate_maps, candidate_schedules
	)
	for person: Dictionary in people:
		if (person.get("locations", []) as Array).size() > 1:
			return {"ok": false, "error": "A person would be placed on more than one map."}
	return {"ok": true}


func _after_world_change(plan: Dictionary) -> void:
	var affected_maps: Array[String] = []
	for change: Dictionary in plan.get("changes", []):
		if String(change.path) == _schedule_path():
			if _schedule_history != null:
				var schedules: Dictionary = _studio.catalog().get("schedules", {})
				schedules.clear()
				schedules.merge(_schedule_history.doc.data)
			_thing_files.files = StudioFiles.load_file_drafts(StudioMode.drafts_dir)
	for change: Dictionary in plan.get("changes", []):
		var path := String(change.path)
		if path == _schedule_path():
			continue
		var session := _session_for_path(path)
		if session == null:
			continue
		session.unsaved = false
		session.saved_at = StudioSession._clock_of(Time.get_datetime_string_from_system())
		affected_maps.append(session.map_id)
	_countdown = -1.0
	for id: String in affected_maps:
		var session := _session_of(id)
		if session == _session:
			refresh()
		elif session != null:
			_rebuilt(id, session)
	if _session != null:
		_restore_saved_world_action(_session)
	_studio.draft_changed()


func _world_undo_redo(plan: Dictionary, redo: bool) -> bool:
	var histories := _histories_for_plan(plan)
	if histories.size() != (plan.get("changes", []) as Array).size():
		_studio.say("A document in this world action is no longer open.", true)
		return false
	var updates := _world_storage_updates(plan, redo)
	if updates.is_empty():
		_studio.say("The world action could not stage its draft payloads.", true)
		return false
	var result := _world_transactions.redo(plan, histories, updates) if redo else _world_transactions.undo(plan, histories, updates)
	if not bool(result.get("ok", false)):
		if bool(result.get("recovery_required", false)):
			transaction_recovery = {"ok": false, "error": String(result.get("error", "A world transaction needs recovery."))}
		_studio.say(String(result.get("error", "The world action could not be applied.")), true)
		return false
	_after_world_change(plan)
	return true


func _plan_for_history(transaction_id: String) -> Dictionary:
	return _world_transactions.plan(transaction_id)


func _restore_saved_world_action(session: StudioSession) -> void:
	if session == null:
		return
	var groups := _world_transactions.groups_for_document(session.path)
	for index: int in range(groups.size() - 1, -1, -1):
		var record: Dictionary = groups[index]
		var transaction_id := String(record.get("id", ""))
		if not _world_transactions.plan(transaction_id).is_empty():
			continue
		var histories := {}
		var valid := true
		for participant: Variant in record.get("participants", []):
			if not participant is Dictionary:
				valid = false
				break
			var value: Dictionary = participant
			var key := String(value.get("key", ""))
			var path := String(value.get("path", key))
			if path == _schedule_path():
				var schedule_history := _schedule_history_for_edit()
				if schedule_history == null:
					valid = false
					break
				histories[key] = schedule_history
			else:
				var map_session := _session_for_path(path)
				if map_session == null:
					map_session = _session_of(path.get_file().get_basename())
				if map_session == null or map_session.path != path:
					valid = false
					break
				histories[key] = map_session.history
		if not valid:
			continue
		var restored := _world_transactions.restore_group(record, histories)
		if bool(restored.get("ok", false)):
			return


## Revert must not discard one side of an applied world transaction while leaving its counterpart behind.
func revert_impact(session: StudioSession) -> Dictionary:
	if session == null:
		return {"grouped": false, "can_revert": false, "message": "There is no map draft to revert."}
	_restore_saved_world_action(session)
	if session.is_new:
		var incoming := StudioPeopleIndex.incoming_links(map_documents(), session.map_id)
		if not incoming.is_empty():
			var sources: Array[String] = []
			for link: Dictionary in incoming.slice(0, 3):
				var source: Dictionary = link.get("source", {})
				var name := String(source.get("name", source.get("art", source.get("kind", "entrance"))))
				sources.append("%s · %s" % [_studio.map_title(String(link.map)), name])
			if incoming.size() > sources.size():
				sources.append("+%d" % (incoming.size() - sources.size()))
			return {
				"grouped": false,
				"can_revert": false,
				"message": StudioText.f("revert_new_map_linked", [", ".join(sources)]),
			}
		return {
			"grouped": false,
			"can_revert": true,
			"message": StudioText.f("revert_new_map_confirm", [String(session.doc().data.get("name", session.map_id))]),
		}
	var transaction_ids := session.history.transaction_ids_for_undo()
	for transaction_id: String in session.history.transaction_ids_for_redo():
		if not transaction_id in transaction_ids:
			transaction_ids.append(transaction_id)
	if transaction_ids.is_empty():
		var saved_groups := _world_transactions.groups_for_document(session.path)
		if not saved_groups.is_empty():
			return {
				"grouped": true,
				"can_revert": false,
				"message": "This map is linked to a saved world action whose exact document versions no longer match. Revert is blocked to protect the other document.",
			}
		return {"grouped": false, "can_revert": true, "message": StudioText.t("revert_confirm")}
	if transaction_ids.size() != 1:
		return {
			"grouped": true,
			"can_revert": false,
			"message": "This map has more than one coordinated move. Undo those moves in order before reverting it.",
		}
	var transaction_id: String = transaction_ids.back()
	var plan := _world_transactions.plan(transaction_id)
	if plan.is_empty():
		return {
			"grouped": true,
			"can_revert": false,
			"message": "This map belongs to a world action whose transaction record is unavailable. Revert is blocked to protect the other document.",
		}
	var histories := _histories_for_plan(plan)
	var applied: bool = session.history.transaction_id_for_undo() == transaction_id
	var undone: bool = session.history.transaction_id_for_redo() == transaction_id
	var can_revert: bool = applied or undone
	for change: Dictionary in plan.get("changes", []):
		var history: Variant = histories.get(String(change.key))
		can_revert = can_revert and history is StudioHistory
		if history is StudioHistory:
			var participant_history := history as StudioHistory
			can_revert = can_revert and (
				participant_history.transaction_id_for_undo() == transaction_id
				if applied
				else participant_history.transaction_id_for_redo() == transaction_id
			)
	var related: Array[String] = []
	for change: Dictionary in plan.get("changes", []):
		if String(change.path) != session.path:
			related.append(String(change.path).get_file())
	var related_text := ", ".join(related)
	var message := "Reverting this map also clears the coordinated action across %s. Continue?" % related_text
	if not can_revert:
		message = "Undo later changes in every affected document before reverting. " + message
	return {"grouped": true, "can_revert": can_revert, "message": message, "id": transaction_id, "plan": plan}


func revert_coordinated_action(session: StudioSession) -> Dictionary:
	var impact := revert_impact(session)
	if not bool(impact.get("can_revert", false)):
		return {"ok": false, "error": String(impact.get("message", "The world action cannot be safely reverted."))}
	if not bool(impact.get("grouped", false)):
		return {"ok": true, "grouped": false}
	var plan: Dictionary = impact.plan
	var transaction_id := String(impact.id)
	if _session.history.transaction_id_for_undo() == transaction_id and not _world_undo_redo(plan, false):
		return {"ok": false, "error": "The coordinated action could not be reversed."}
	_world_transactions.forget(transaction_id, _histories_for_plan(plan))
	return {"ok": true, "grouped": true}


## A free id for a new thing made from a prop showing `art`: the art's id when no thing has it, else with -2, -3...
func suggest_thing_id(art: String) -> String:
	var taken: Array[String] = []
	taken.assign(_studio.catalog().get("things", {}).keys())
	taken.append_array(things().ids())
	for id: String in _map_ids():
		var session := _session_of(id)
		if session == null:
			continue
		for object: Variant in session.doc().data.get("objects", []):
			if object is Dictionary and (object as Dictionary).has("id"):
				taken.append(String((object as Dictionary).id))
	return StudioDoors.room_id(art, taken)


## Make it a thing (Concept/v0.3/10, S8): the prop gets an id and a program (its hook, on_use unless `hook` says on_step
## or on_change; the fields its code may change; the flags it may raise; `links` and `unlocked_by` when given), as one change in this map; its three files are drafted
## (StudioThings) and the thing goes in the catalog, so Play draft runs it. `spec` is {id, name, hints, python,
## javascript, fields, raises, hook, links, unlocked_by}. {ok, id} or {ok: false, error}.
func make_thing(sid: int, spec: Dictionary) -> Dictionary:
	var object := raw(index_of(sid))
	var id := String(spec.get("id", "")).strip_edges()
	var error := ""
	if String(object.get("kind", "")) != "prop":
		error = "only a prop can take code"
	elif object.has("program"):
		error = "it takes code already"
	elif not RegEx.create_from_string(Schema.ID_PATTERN).search(id):
		error = "a thing's id is lower case words joined by - (like talking-barrel)"
	elif suggest_thing_id(id) != id or things().has_thing(id):
		error = "a thing called %s is there already" % id
	if error != "":
		_studio.say(error, true)
		return {"ok": false, "error": error}
	var hook := String(spec.get("hook", TownThings.HOOK))
	var program := {"hook": hook if hook in TownThings.HOOKS else TownThings.HOOK, "fields": spec.get("fields", {}), "raises": spec.get("raises", [])}
	if not (spec.get("links", []) as Array).is_empty():
		program["links"] = spec.links
	var unlock: Variant = spec.get("unlocked_by")
	if unlock is Dictionary and not (unlock as Dictionary).is_empty():
		program["unlocked_by"] = unlock
	var commands: Array = [
		{"type": "set", "sid": sid, "key": "id", "value": id, "index": 2},
		{"type": "set", "sid": sid, "key": "program", "value": program},
	]
	var label := "Make %s a thing" % _name(object)
	if not command({"type": "batch", "name": label, "commands": commands}).ok:
		return {"ok": false, "error": "the prop could not be changed"}
	var made := spec.duplicate(true)
	made["id"] = id
	made["name"] = String(spec.get("name", StudioAssets.name_of(String(object.get("art", id)))))
	things().make(made)
	things().save()
	_studio.catalog().get("things", {})[id] = things().record(id)
	_studio.say("%s takes code now: things/%s.jsonc and its starters are drafts until Publish" % [_name(object), id], false)
	return {"ok": true, "id": id}


## The drafted things go in the catalog (Play draft runs them).
func put_drafted_things() -> void:
	var catalog_things: Dictionary = _studio.catalog().get("things", {})
	for id: String in things().ids():
		var record := things().record(id)
		if not record.is_empty():
			catalog_things[id] = record


# --- people, doors and rooms (S6) ---------------------------------------------------------------------------------


## Puts a townsperson on `cell`, facing `facing`. A person stands in one place in the whole town: someone already on
## this map moves; someone on another map is asked about first ({ok: false, needs_confirm: true, map, at}), and with
## `confirmed` comes here and leaves there, as one change whose undo puts them back. {ok, reason, sid}.
func place_person(
	id: String, cell: Vector2i, facing := "down", _free := false, confirmed := false,
	expected_source: Dictionary = {}, expected_source_map := ""
) -> Dictionary:
	if _session == null or id == "" or not bool(transaction_recovery.get("ok", false)):
		return {"ok": false, "reason": "", "sid": -1}
	if not (_studio.catalog().get("townsfolk", {}) as Dictionary).has(id):
		return {"ok": false, "reason": StudioText.t("people_unknown"), "sid": -1}
	var maps := {}
	for map_id: String in _map_ids():
		var other := _session_of(map_id)
		if other != null:
			maps[map_id] = other.doc().data
	var locations := StudioDoors.standing(maps, id)
	if locations.size() > 1:
		var duplicate_error := StudioText.f("people_duplicate_blocked", [id])
		_studio.say(duplicate_error, true)
		return {"ok": false, "reason": duplicate_error, "sid": -1}
	if not expected_source.is_empty():
		var source_still_matches := false
		for location: Dictionary in locations:
			if expected_source_map != "" and String(location.map) != expected_source_map:
				continue
			var source_session := _session_of(String(location.map))
			var source_index := int(location.index)
			var source_objects: Array = source_session.doc().data.get("objects", []) if source_session != null else []
			if source_session == null or source_index < 0 or source_index >= source_objects.size():
				continue
			if source_objects[source_index] == expected_source:
				source_still_matches = true
				break
		if not source_still_matches:
			return {"ok": false, "reason": StudioText.t("context_stale"), "sid": -1}
	var schedules: Dictionary = _studio.catalog().get("schedules", {})
	var schedule: Variant = schedules.get(id, {})
	var scheduled := schedule is Dictionary and not (schedule as Dictionary).is_empty()
	if scheduled and _session.map_id != "lanternroot":
		var cross_map_error := StudioText.f("people_scheduled_cross_map_blocked", [id])
		_studio.say(cross_map_error, true)
		return {"ok": false, "reason": cross_map_error, "sid": -1}
	var here := -1
	var away: Dictionary = {}
	for spot: Dictionary in locations:
		if String(spot.map) == _session.map_id:
			here = int(spot.index)
		elif away.is_empty():
			away = spot
	if scheduled and not away.is_empty():
		var cross_map_error := StudioText.f("people_scheduled_cross_map_blocked", [id])
		_studio.say(cross_map_error, true)
		return {"ok": false, "reason": cross_map_error, "sid": -1}
	var state := StudioPeopleIndex.person_cell_state(
		_studio.current_map(), id, cell, schedules, scheduled
	)
	if state != "valid":
		var error := _person_cell_error(state)
		_studio.say(error, true)
		return {"ok": false, "reason": error, "sid": -1}
	var source_session: StudioSession
	var source: Dictionary = {}
	if not away.is_empty():
		source_session = _session_of(String(away.map))
		var source_objects: Array = source_session.doc().data.get("objects", []) if source_session != null else []
		var source_index := int(away.index)
		if source_session == null or source_index < 0 or source_index >= source_objects.size():
			return {"ok": false, "reason": StudioText.t("context_stale"), "sid": -1}
		source = source_objects[source_index].duplicate(true)
		if not expected_source.is_empty() and source != expected_source:
			return {"ok": false, "reason": StudioText.t("context_stale"), "sid": -1}
	if not away.is_empty() and not confirmed:
		return {
			"ok": false, "needs_confirm": true, "map": String(away.map), "at": away.at, "cell": cell,
			"source": source, "reason": "", "sid": -1,
		}
	var sid := sid_at(here) if here >= 0 else -1
	var current := raw(here) if here >= 0 else {}
	var map_command: Dictionary
	if here >= 0:
		map_command = _person_relocation_command(id, sid, current, cell, facing)
		if map_command.is_empty():
			return {"ok": true, "reason": "", "sid": sid}
	else:
		var object := {"kind": "person", "id": id, "at": [cell.x, cell.y], "facing": facing}
		map_command = {"type": "add", "object": object, "index": -1}
	var actions: Array[Dictionary] = [
		{"key": _session.path, "path": _session.path, "history": _session.history, "command": map_command}
	]
	var schedule_changes := false
	if scheduled:
		var current_work := OverworldMap.cell_of((schedule as Dictionary).get("work", [-1, -1]))
		schedule_changes = current_work != cell
		if schedule_changes:
			var schedule_history := _schedule_history_for_edit()
			if schedule_history == null:
				return {"ok": false, "reason": "The schedule document cannot be read.", "sid": -1}
			var schedule_command := {
				"type": "set_at", "path": [id, "work"], "value": [cell.x, cell.y],
			}
			actions.append(
				{"key": _schedule_path(), "path": _schedule_path(), "history": schedule_history, "command": schedule_command}
			)
	if not away.is_empty():
		if source_session == null or int(away.index) >= source_session.doc().sids.size():
			return {"ok": false, "reason": StudioText.t("context_stale"), "sid": -1}
		actions.append(
			{
				"key": source_session.path,
				"path": source_session.path,
				"history": source_session.history,
				"command": {"type": "remove", "sid": source_session.doc().sids[int(away.index)]},
			}
		)
	var needs_world_transaction := actions.size() > 1
	if needs_world_transaction:
		var label := "Move %s to %s" % [id, _session.map_id]
		var applied := _apply_world_change(actions, label)
		if not bool(applied.get("ok", false)):
			var reason := String(applied.get("error", "The coordinated move failed."))
			_studio.say(StudioText.f("people_move_validation_failed", [reason]), true)
			return {"ok": false, "reason": reason, "sid": -1}
	else:
		var result := command(map_command)
		if not bool(result.get("ok", false)):
			return {"ok": false, "reason": String(result.get("error", "")), "sid": -1}
		sid = int(result.get("sid", -1)) if result.has("sid") else int((result.get("done", {}) as Dictionary).get("sid", -1))
	if sid <= 0:
		sid = _person_sid(id, _session.doc())
	var placed_message := Text.f("Placed %s", [id])
	if not away.is_empty():
		placed_message = Text.f("Placed %s (moved from %s)", [id, String(away.map)])
	_studio.say(placed_message, false)
	return {"ok": true, "reason": "", "sid": sid}


func _person_relocation_command(id: String, sid: int, current: Dictionary, cell: Vector2i, facing: String) -> Dictionary:
	var commands: Array[Dictionary] = []
	var at := OverworldMap.cell_of(current.get("at", [0, 0]))
	if at != cell:
		var delta := cell - at
		commands.append({"type": "move", "sids": [sid], "by": [delta.x, delta.y]})
	if String(current.get("facing", "down")) != facing:
		commands.append({"type": "set", "sid": sid, "key": "facing", "value": facing})
	if commands.is_empty():
		return {}
	if commands.size() == 1:
		return commands[0]
	return {"type": "batch", "name": "Move person %s" % id, "commands": commands}


func _person_sid(id: String, person_doc: StudioDoc) -> int:
	var objects: Array = person_doc.data.get("objects", [])
	for index: int in objects.size():
		var object: Variant = objects[index]
		if object is Dictionary and String((object as Dictionary).get("kind", "")) == "person" \
		and String((object as Dictionary).get("id", "")) == id:
			return person_doc.sids[index]
	return -1


## The map's start (the Start marker): the cell a new game, or Play draft from the map, begins on. It must be open,
## walkable ground, never a transition cell. `{ok, reason, sid}` (sid -1: the start is not an object).
func set_start(cell: Vector2i, _free := false, facing := "") -> Dictionary:
	var map := _studio.current_map()
	var state := StudioPeopleIndex.cell_state(map, cell)
	if state != "valid":
		var reason := StudioText.t("people_cell_" + state)
		_studio.say(reason, true)
		return {"ok": false, "reason": reason, "sid": -1}
	var current_start := OverworldMap.cell_of(map.get("start", [0, 0]))
	var current_facing := String(map.get("facing", "down"))
	var target_facing := facing if OverworldMap.FACINGS.has(facing) else current_facing
	var commands: Array[Dictionary] = []
	if current_start != cell:
		commands.append({"type": "set_map", "key": "start", "value": [cell.x, cell.y]})
	if current_facing != target_facing:
		commands.append({"type": "set_map", "key": "facing", "value": target_facing})
	if commands.is_empty():
		return {"ok": true, "reason": "", "sid": -1}
	var result := command({"type": "batch", "name": "Set map start", "commands": commands})
	if result.ok:
		_studio.say(Text.f("The map's start is now %d, %d", [cell.x, cell.y]), false)
	return {"ok": bool(result.ok), "reason": "", "sid": -1}


func _person_cell_error(state: String) -> String:
	if state in ["off_map", "transition", "blocked", "scheduled_anchor", "scheduled_cross_map"]:
		return StudioText.t("people_cell_" + state)
	return StudioText.t("people_cell_blocked")


## Sets (or, with null, erases) a field of the map itself: its name, or the start's facing.
func set_map_field(key: String, value: Variant) -> bool:
	if _session == null or doc().data.get(key) == value:
		return false
	return bool(command({"type": "set_map", "key": key, "value": value}).ok)


## Makes a building's door (or a warp) lead to `target` ({map, at, facing}). False when it changes nothing.
func link(sid: int, target: Dictionary) -> bool:
	var object := raw(index_of(sid))
	if not String(object.get("kind", "")) in ["building", "warp"]:
		return false
	var state := StudioPeopleIndex.link_state("warp", target, _studio.catalog().get("maps", {}))
	if state != "valid":
		_studio.say(StudioText.t("people_link_state_" + state), true)
		return false
	var change := StudioDoors.link_command(sid, target)
	if object.get("to") == change.value:
		return false
	var label := "Link %s to %s" % [_name(object), String(target.map)]
	return bool(command({"type": "batch", "name": label, "commands": [change]}).ok)


## A warp created for the Link flow is provisional until its target is accepted. Cancel removes it, undoing the add
## itself when it is still the newest change so the canceled gesture leaves no history row.
func cancel_provisional_warp(sid: int) -> bool:
	if _session == null:
		return false
	var index := index_of(sid)
	var object := raw(index)
	if String(object.get("kind", "")) != "warp":
		return false
	var undo := _session.history.peek_undo()
	var removed := false
	if String(undo.get("type", "")) == "remove" and int(undo.get("sid", -1)) == sid:
		removed = _session.history.discard_latest()
		if removed:
			_session.unsaved = true
			_changed()
	else:
		removed = bool(command({"type": "remove", "sid": sid}).ok)
	if removed:
		_studio.select(-1)
	return removed


## Joins a provisional warp's add and accepted link into one undoable gesture.
func combine_recent_changes(count: int, label: String) -> bool:
	if _session == null or not _session.history.combine_latest(count, label):
		return false
	_studio._update_panels()
	return true


## A building's door leads nowhere again (it stays shut). A warp always leads somewhere, so it is not unlinked.
func unlink(sid: int) -> bool:
	var object := raw(index_of(sid))
	if String(object.get("kind", "")) != "building" or not object.has("to"):
		return false
	return bool(command({"type": "batch", "name": "Unlink %s" % _name(object), "commands": [StudioDoors.unlink_command(sid)]}).ok)


## Make interior (Concept/v0.3/10, 7.9): a new room for a building, 11 x 8 by default (its walls, floor, the doormat in
## the middle of the bottom wall), and the two links: the building's door leads in above the doormat, and the doormat's
## warp leads out below the door. The room is a new map with a draft of its own (Publish makes its file); the door's
## link is one change in this map, so undoing it leaves the room unlinked, never lost. {ok, room_id} or {ok, error}.
func make_interior(sid: int, size := StudioDoors.ROOM_SIZE) -> Dictionary:
	var object := raw(index_of(sid))
	var title := String(object.get("name", StudioAssets.name_of(String(object.get("art", "")))))
	var made := StudioDoors.make_interior(object, _session.map_id, _map_ids(), title, size)
	if not made.ok:
		_studio.say(String(made.error), true)
		return made
	var room_id := String(made.room_id)
	if not create_map(room_id, made.room):
		var failed := {"ok": false, "error": "a map called %s could not be made" % room_id}
		_studio.say(failed.error, true)
		return failed
	var label := "Make a room for %s" % title
	if not command({"type": "batch", "name": label, "commands": [StudioDoors.link_command(sid, made.to)]}).ok:
		return {"ok": false, "error": "the door could not be linked"}
	return {"ok": true, "room_id": room_id}


## Moves a building's door along its bottom row to `door` (an offset in its footprint). Whatever led to the cell below
## the old door, in this map or another (the way out of its room), follows to the cell below the new one.
func slide_door(sid: int, door: Vector2i) -> bool:
	var object := raw(index_of(sid))
	if String(object.get("kind", "")) != "building" or OverworldMap.cell_of(object.get("door", [0, 0])) == door:
		return false
	var moved := object.duplicate(true)
	moved["door"] = [door.x, door.y]
	var from := StudioDoors.front_of(object)
	var to := StudioDoors.front_of(moved)
	var commands: Array = [{"type": "set", "sid": sid, "key": "door", "value": [door.x, door.y]}]
	if object.get("art_shape") is Dictionary:
		var shape: Dictionary = (object.art_shape as Dictionary).duplicate(true)
		var size := _size_of(object)
		shape["door"] = [door.x, door.y]
		shape["door_size"] = [size.x, size.y]
		commands.append({"type": "set", "sid": sid, "key": "art_shape", "value": shape})
	var own := StudioDoors.retarget(doc().data, doc().sids, _session.map_id, from, to)
	if not own.is_empty():
		commands.append(own)
	var there: Array = []
	var back: Array = []
	for id: String in _map_ids():
		var other := _session_of(id)
		if id == _session.map_id or other == null:
			continue
		var follow := StudioDoors.retarget(other.doc().data, other.doc().sids, _session.map_id, from, to)
		if follow.is_empty():
			continue
		there.append({"map": id, "command": follow})
		back.append({"map": id, "command": StudioCommands.apply(other.doc(), follow).undo})
	var change := {"type": "batch", "name": "Move the door of %s" % _name(object), "commands": commands}
	if not there.is_empty():
		change["elsewhere"] = there
		change["elsewhere_undo"] = back
	return bool(command(change).ok)


## A new map, `data`, with a draft of its own and no file until Publish (StudioSession.create); it goes in the catalog
## at once, so doors can lead there and the picker lists it. False when the id is taken.
func create_map(id: String, data: Dictionary) -> bool:
	if not StudioAreaFactory.valid_id(id) or String(data.get("id", "")) != id:
		return false
	if _sessions.has(id) or _studio.catalog().maps.has(id):
		return false
	var made := StudioSession.create(id, data, StudioMode.drafts_dir, _studio.content_root())
	if made == null or not made.save():
		return false
	_sessions[id] = made
	_rebuilt(id, made)
	_studio.clear_map_names()
	return true


## The maps made in the Studio and not published yet (drafts with no file): they go in the catalog when editing starts,
## so the picker lists them and the doors that lead there work. Returns their ids.
func open_new_maps() -> Array[String]:
	var ids: Array[String] = []
	var maps_folder := _studio.content_root().path_join("packs/core/overworld/maps") + "/"
	for path: String in StudioFiles.list_drafts(StudioMode.drafts_dir):
		if not path.begins_with(maps_folder) or StudioFiles.exists(path):
			continue
		var id := path.get_file().get_basename()
		var made := _session_of(id)
		if made != null and made.is_new:
			_rebuilt(id, made)
			ids.append(id)
	if not ids.is_empty():
		_studio.clear_map_names()
	return ids


## Lets go of a map that is gone (a new map reverted): its session and its place in the catalog.
func forget_map(id: String) -> void:
	_sessions.erase(id)
	_swapped.erase(id)
	_studio.catalog().maps.erase(id)
	_studio.clear_map_names()
	if _session != null and _session.map_id == id:
		_session = null


## Whether the map `id` was made in the Studio and has no file yet.
func is_new_map(id: String) -> bool:
	var made: Variant = _sessions.get(id)
	return made is StudioSession and (made as StudioSession).is_new


## Draft-created maps only; existing maps are not opened just to build the map picker or People index.
func new_map_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _sessions:
		if is_new_map(id):
			ids.append(id)
	ids.sort()
	return ids


## Every map id there is: the catalog's (files and drafts), sorted.
func _map_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(_studio.catalog().maps.keys())
	for id: String in _sessions:
		if not id in ids:
			ids.append(id)
	ids.sort()
	return ids


## The raw, draft-aware map documents by ID, without changing the map currently being edited.
func map_documents() -> Dictionary:
	var out := {}
	for id: String in _map_ids():
		var session := _session_of(id)
		if session != null:
			out[id] = session.doc().data
	return out


## One raw draft-aware map, loaded without making it the active map. {} when unavailable.
func map_data(id: String) -> Dictionary:
	var session := _session_of(id)
	return session.doc().data if session != null else {}


## The session sid at `index` in another map, loaded without changing the active map; -1 if it is stale.
func map_sid_at(id: String, index: int) -> int:
	var session := _session_of(id)
	if session == null or index < 0 or index >= session.doc().sids.size():
		return -1
	return session.doc().sids[index]


# --- small helpers ------------------------------------------------------------------------------------------------


## A file's object as the map is built (cells as Vector2i, the defaults a check fills in), moved by `step`.
static func _built_like(object: Dictionary, step: Vector2i) -> Dictionary:
	var out := object.duplicate()
	out["at"] = OverworldMap.cell_of(object.get("at", [0, 0])) + step
	out["size"] = _size_of(object)
	return out


static func _size_of(object: Dictionary) -> Vector2i:
	return OverworldMap.cell_of(object.get("size", [1, 1]))


## The cells all of the objects cover, as a Rect2i.
static func _box_of(objects: Array[Dictionary]) -> Rect2i:
	var box := Rect2i()
	for i: int in objects.size():
		var one := StudioPick.footprint(_built_like(objects[i], Vector2i.ZERO))
		box = one if i == 0 else box.merge(one)
	return box


## An object's keys in the files' order: kind, art, id, at, size, door, then the rest as given.
static func _keyed(object: Dictionary) -> Dictionary:
	var out := {}
	for key: String in ["kind", "art", "id", "at", "size", "door"]:
		if object.has(key):
			out[key] = object[key]
	for key: String in object:
		if not out.has(key):
			out[key] = object[key]
	return out


static func _name(object: Dictionary) -> String:
	return StudioDiff.name_of(object)


static func _things(count: int) -> String:
	return "1 thing" if count == 1 else "%d things" % count
