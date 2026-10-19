class_name StudioArrange
extends RefCounted
## The mouse in Edit (Concept/v0.3/10, section 7.2 and 7.3): a press on a thing picks it up (a drag moves the selection
## as a ghost snapped to whole cells, green where it fits and red where it does not), a press on empty ground starts a
## box that selects what it touches, Shift adds and removes, and in place mode a click puts the chosen picture down.
## The decisions about fitting are StudioFit's and the edits StudioWork's; this keeps what the hand is doing.

const TILE := OverworldScale.TILE
## A drag shorter than this many screen pixels is a click.
const DRAG_PIXELS := 4.0

## The object (a template without `at`) place mode puts down, or {} when not placing. Shift-drag lays a row of them.
var placing: Dictionary = {}
## The catalog card it came from (a person's id, a marker's "marker-warp"), or "" for an eyedropped copy.
var placing_card := ""
## What the left button is doing: "" (nothing), "move" (a selection is being carried), "box" or "row" (Shift-drag in
## place mode), "resize" (a footprint handle), "door" (a building's door handle) or "start" (the map's start flag).
var mode := ""
## The whole cells the carried selection has been moved by, and whether it fits there.
var delta := Vector2i.ZERO
var fits := true
## Explicit area selection starts a rectangle even over an object, instead of picking that object up.
var area_select := false
var area_filter := "all"

var _studio: StudioMode
var _hit := -1
var _row_start := Vector2i.ZERO
var _row_axis := ""
var _preview_hidden: Array[Node2D] = []
## Set when a row was just placed: the next ghost update leaves the status bar's news about it alone.
var _keep_message := false
var _press_cell := Vector2i.ZERO
var _press_screen := Vector2.ZERO
var _press_world := Vector2.ZERO
var _shift := false
var _dragged := false
var _carried: Array[int] = []
## A footprint handle being dragged (mode "resize"): which one, the thing's sid, and the size it proposes.
var _resize_kind := ""
var _resize_sid := -1
var resize_size := Vector2i.ONE
## The door handle (mode "door"): the building's sid and the door it proposes. The start flag (mode "start"): its cell.
var _door_sid := -1
var door_at := Vector2i.ZERO
var start_at := Vector2i.ZERO


func _init(studio: StudioMode) -> void:
	_studio = studio


## Place mode: puts down copies of `template` where the cursor is, until Esc (a person, the start and a warp once).
## `card` is the catalog card it came from.
func start_placing(template: Dictionary, card := "") -> void:
	cancel()
	area_select = false
	placing = template
	placing_card = card
	_studio.placing_changed()
	_studio.say(_placing_hint(), false)
	update()


func stop_placing() -> void:
	_restore_preview()
	if placing.is_empty():
		return
	placing = {}
	placing_card = ""
	if mode == "row":
		mode = ""
	_studio.placing_changed()
	_studio.overlay().ghosts = []
	_studio.overlay().queue_redraw()


## Variants can be chosen before putting a piece down as well as on a selection already standing on the map.
func cycle_variant(step: int) -> void:
	var art := StudioCatalog.variant_of(StudioAssets.entries(), String(placing.get("art", "")), step)
	if art.is_empty():
		return
	var next := placing.duplicate(true)
	next["art"] = art
	next.erase("art_size")
	next.erase("art_shape")
	var entry := StudioAssets.entry_of(art)
	next["size"] = entry.get("size", [1, 1])
	if String(next.get("kind", "")) == "building":
		next["door"] = entry.get("door", next.get("door", [0, 0]))
	if not StudioAssets.can_flip(next):
		next.erase("flip")
	var row_active := mode == "row"
	var axis := _row_axis
	start_placing(next, art)
	if row_active:
		# LEARN: a preview has no command yet. Choosing a variant must preserve the held mouse gesture until release.
		mode = "row"
		_row_axis = axis
		update()


## Lets go of whatever the button was doing (Esc during a drag).
func cancel() -> void:
	_restore_preview()
	mode = ""
	_row_axis = ""
	_resize_kind = ""
	_resize_sid = -1
	_door_sid = -1
	if _studio.overlay() != null:
		_studio.overlay().door_drag = Vector2i(-1, -1)
		_studio.overlay().start_drag = Vector2i(-1, -1)
	delta = Vector2i.ZERO
	_hit = -1
	_carried = []
	_studio.overlay().ghosts = []
	_studio.overlay().box = Rect2()
	_studio.overlay().area_footprints = []
	_studio.overlay().box_count = -1
	_studio.overlay().queue_redraw()


# --- the left button ----------------------------------------------------------------------------------------------


## The button went down at `screen` (a point on the world Control) with the cursor already at `cell` / `world`.
func press(screen: Vector2, shift: bool, free: bool) -> void:
	_shift = shift
	_press_screen = screen
	_press_cell = _studio.cursor_cell()
	_press_world = _studio.cursor_world()
	_dragged = false
	if area_select and placing.is_empty():
		mode = "box"
		update()
		return
	if placing.is_empty() and not shift:
		var handle := _studio.handle_at(_press_world)
		if not handle.is_empty() and String(handle.kind) == "door":
			mode = "door"
			_door_sid = int(handle.sid)
			door_at = OverworldMap.cell_of(_studio.work.raw(_studio.work.index_of(_door_sid)).get("door", [0, 0]))
			return
		if not handle.is_empty() and String(handle.kind) == "start":
			mode = "start"
			start_at = _press_cell
			return
		if not handle.is_empty():
			mode = "resize"
			_resize_kind = String(handle.kind)
			_resize_sid = int(handle.sid)
			resize_size = OverworldMap.cell_of(_studio.object_at(_studio.work.index_of(_resize_sid)).get("size", [1, 1]))
			return
	if not placing.is_empty():
		var once := String(placing.get("kind", "")) in ["person", "start", "warp"]
		if not once and (shift or StudioRow.is_line(placing, StudioAssets.entries())):
			# A row: nothing is put down until the button is let go.
			mode = "row"
			_row_start = _press_cell
			_row_axis = ""
			update()
			return
		var template := placing.duplicate(true)
		var placed := _studio.work.place(template, _press_cell, free)
		if placed.ok:
			_studio.note_placed(placing_card if placing_card != "" else String(placing.get("art", "")))
		_studio.after_place(template, placed)
		return
	var stack := _studio.stack()
	_hit = stack[0] if not stack.is_empty() else -1
	if _hit >= 0:
		if shift:
			_studio.toggle_selected(_hit)
			_hit = -1
			return
		if not _studio.is_selected(_hit):
			_studio.select(_hit)
		mode = "move"
		_carried = _studio.selected_sids()
	else:
		mode = "box"
		if not shift:
			_studio.select(-1)


## The cursor moved (or the keys that matter changed): the ghost or the box follows.
func update() -> void:
	_restore_preview()
	var overlay := _studio.overlay()
	if overlay == null:
		return
	if not placing.is_empty():
		_update_place(overlay)
		return
	match mode:
		"resize":
			_show_resize(overlay)
		"door":
			_show_door(overlay)
		"start":
			start_at = _studio.cursor_cell()
			overlay.start_drag = start_at
			overlay.queue_redraw()
			_studio.say(StudioText.t("start_hint") % [start_at.x, start_at.y], false)
		"move":
			var still := (_studio.cursor_screen() - _press_screen).length() < DRAG_PIXELS
			if not _dragged and still and _studio.cursor_cell() == _press_cell:
				return
			_dragged = true
			delta = _studio.cursor_cell() - _press_cell
			_show_carried(overlay)
		"box":
			var box := _box_rect()
			_dragged = area_select or _dragged or box.size.length() * _studio.zoom() >= DRAG_PIXELS
			overlay.box = box if _dragged else Rect2()
			if area_select:
				var sids := _studio.sids_in_area(box, area_filter)
				overlay.area_footprints = []
				for sid: int in sids:
					var footprint := StudioPick.footprint(_studio.object_at(_studio.work.index_of(sid)))
					overlay.area_footprints.append(Rect2(Vector2(footprint.position) * TILE, Vector2(footprint.size) * TILE))
				overlay.box_count = sids.size()
				_studio.say(StudioText.t("area_preview") % sids.size(), false)
			overlay.queue_redraw()


func release(free: bool) -> void:
	var overlay := _studio.overlay()
	match mode:
		"resize":
			var index := _studio.work.index_of(_resize_sid)
			var now := OverworldMap.cell_of(_studio.object_at(index).get("size", [1, 1]))
			if index >= 0 and resize_size != now:
				_studio.work.resize_object(_resize_sid, resize_size, free)
		"door":
			var index := _studio.work.index_of(_door_sid)
			if index >= 0 and door_at != OverworldMap.cell_of(_studio.work.raw(index).get("door", [0, 0])):
				_studio.work.slide_door(_door_sid, door_at)
		"start":
			if start_at != _press_cell:
				_studio.work.set_start(start_at, free)
		"row":
			if not placing.is_empty():
				_place_row(free)
		"move":
			if _dragged and delta != Vector2i.ZERO:
				_studio.work.move(_carried, delta, free)
			elif not _dragged and not _shift and _studio.selected_sids().size() > 1 and _hit >= 0:
				# A click on one of several: that one alone.
				_studio.select(_hit)
		"box":
			if _dragged and overlay.box.has_area():
				_studio.select_in(overlay.box, _shift, area_filter if area_select else "all")
				if area_select:
					_studio.say(StudioText.t("area_selected") % _studio.selected_sids().size(), false)
	cancel()
	_studio.refresh_hover()


func _box_rect() -> Rect2:
	if not area_select:
		return Rect2(_press_world, Vector2.ZERO).expand(_studio.cursor_world())
	var now := _studio.cursor_cell()
	var first := Vector2i(mini(_press_cell.x, now.x), mini(_press_cell.y, now.y))
	var last := Vector2i(maxi(_press_cell.x, now.x), maxi(_press_cell.y, now.y))
	return Rect2(Vector2(first) * TILE, Vector2(last - first + Vector2i.ONE) * TILE)


# --- ghosts -------------------------------------------------------------------------------------------------------


## A footprint handle dragged: the thing as a ghost at the size the cursor proposes, green where it fits.
func _show_resize(overlay: StudioOverlay) -> void:
	var index := _studio.work.index_of(_resize_sid)
	var object := _studio.object_at(index)
	if object.is_empty():
		return
	var at: Vector2i = object.at
	resize_size = StudioRemaking.dragged_size(_resize_kind, at, object.size, _studio.cursor_cell())
	var resized := StudioResize.object_at_size(_studio.work.raw(index), resize_size)
	var built := object.duplicate(true)
	if bool(resized.ok):
		built.merge(resized.object, true)
	built["at"] = at
	built["size"] = resize_size
	var fit := _studio.work.fit_objects([built], [index])
	fits = bool(fit.ok)
	overlay.ghosts = [_ghost(built, fits)]
	overlay.queue_redraw()
	_studio.say(StudioText.t("resize_hint") % [resize_size.x, resize_size.y] if fits else String(fit.reason), not fits)


## The door handle dragged along the building's bottom row: where the door would be.
func _show_door(overlay: StudioOverlay) -> void:
	var object := _studio.object_at(_studio.work.index_of(_door_sid))
	if object.is_empty():
		return
	door_at = StudioDoors.door_along(object, _studio.cursor_cell())
	overlay.door_drag = (object.at as Vector2i) + door_at
	overlay.queue_redraw()
	_studio.say(StudioText.t("door_hint") % [door_at.x + 1, (object.size as Vector2i).x], false)


## The carried selection, shifted by `delta`, with whether it fits there.
func _show_carried(overlay: StudioOverlay) -> void:
	var items: Array[Dictionary] = []
	var indexes: Array[int] = []
	var ghosts: Array[Dictionary] = []
	for sid: int in _carried:
		var index := _studio.work.index_of(sid)
		var object := _studio.object_at(index)
		if object.is_empty():
			continue
		indexes.append(index)
		var moved := object.duplicate()
		moved.at = (object.at as Vector2i) + delta
		items.append(moved)
	var fit := _studio.work.fit_objects(items, indexes)
	for sid: int in _carried:
		var raw := _studio.work.raw(_studio.work.index_of(sid))
		if String(raw.get("kind", "")) != "person":
			continue
		var schedule: Variant = _studio.catalog().get("schedules", {}).get(String(raw.get("id", "")), {})
		var scheduled := schedule is Dictionary and not (schedule as Dictionary).is_empty()
		if scheduled and String(_studio.current_map().get("id", "")) != "lanternroot":
			fit = {
				"ok": false,
				"reason": StudioText.f("people_scheduled_cross_map_blocked", [String(raw.get("id", ""))]),
			}
			break
		if scheduled and _carried.size() != 1:
			fit = {"ok": false, "reason": StudioText.f("people_scheduled_move_blocked", [String(raw.get("id", ""))])}
			break
		if not bool(fit.get("ok", false)):
			continue
		fit = _studio.work.person_move_fit(
			String(raw.get("id", "")), OverworldMap.cell_of(raw.get("at", [0, 0])) + delta, indexes, scheduled
		)
		if not bool(fit.get("ok", false)):
			break
	fits = bool(fit.ok)
	for moved: Dictionary in items:
		ghosts.append(_ghost(moved, fits))
	overlay.ghosts = ghosts
	overlay.queue_redraw()
	if delta != Vector2i.ZERO:
		_studio.say(String(fit.reason) if not fits else "", not fits)


func _update_place(overlay: StudioOverlay) -> void:
	if mode == "row":
		_keep_message = false
		_show_row(overlay)
		return
	if not _studio.cursor_over_map():
		overlay.ghosts = []
		overlay.queue_redraw()
		return
	if StudioBoundary.supported(placing, StudioAssets.entries()):
		_show_connected(overlay, placing, [_studio.cursor_cell()])
		return
	var object := placing.duplicate(true)
	var size := OverworldMap.cell_of(object.get("size", [1, 1]))
	var built := object.duplicate()
	built["at"] = StudioWork.footing(size, _studio.cursor_cell())
	built["size"] = size
	var fit: Dictionary
	var kind := String(object.get("kind", ""))
	if kind == "person":
		var schedules: Dictionary = _studio.catalog().get("schedules", {})
		var schedule: Variant = schedules.get(String(object.get("id", "")), {})
		var allow_reanchor := schedule is Dictionary and not (schedule as Dictionary).is_empty()
		var state := StudioPeopleIndex.person_cell_state(
			_studio.current_map(), String(object.get("id", "")), _studio.cursor_cell(), schedules, allow_reanchor
		)
		fit = {"ok": state == "valid", "reason": _studio.work._person_cell_error(state) if state != "valid" else ""}
	elif kind == "start":
		var state := StudioPeopleIndex.cell_state(_studio.current_map(), _studio.cursor_cell())
		fit = {"ok": state == "valid", "reason": _studio.work._person_cell_error(state) if state != "valid" else ""}
	else:
		fit = _studio.work.placement_fit(built)
	fits = bool(fit.ok)
	overlay.ghosts = [_ghost(built, fits)]
	overlay.queue_redraw()
	if _keep_message:
		_keep_message = false
		return
	_keep_message = false
	_studio.say(String(fit.reason) if not fits else _placing_hint(), not fits)


## The cursor cells of the row from where Shift went down to the cursor.
func _row_cells() -> Array[Vector2i]:
	return StudioRow.cells(_row_start, _row_end(), OverworldMap.cell_of(placing.get("size", [1, 1])))


func _row_template() -> Dictionary:
	return StudioRow.oriented(placing, _row_start, _row_end(), StudioAssets.entries())


func _row_end() -> Vector2i:
	var cursor := _studio.cursor_cell()
	if not StudioRow.is_line(placing, StudioAssets.entries()):
		return cursor
	var across := cursor - _row_start
	if across == Vector2i.ZERO:
		_row_axis = ""
	elif _row_axis == "":
		# LEARN: latch the first deliberate direction. Crossing a diagonal later must not turn the whole preview.
		_row_axis = "horizontal" if absi(across.x) >= absi(across.y) else "vertical"
	return Vector2i(cursor.x, _row_start.y) if _row_axis == "horizontal" else Vector2i(_row_start.x, cursor.y)


func turn_placing() -> void:
	if String(placing.get("kind", "")) == "person":
		var facing_cycle: Array[String] = ["down", "left", "up", "right"]
		var current := String(placing.get("facing", "down"))
		var next := (facing_cycle.find(current) + 1) % facing_cycle.size()
		placing["facing"] = facing_cycle[next]
		_studio.say(StudioText.t("people_facing") % StudioText.t("link_face_" + facing_cycle[next]), false)
		update()
		return
	if not StudioRow.is_line(placing, StudioAssets.entries()):
		return
	var pair: Dictionary = StudioAssets.entry_of(String(placing.art)).line
	placing["art"] = String(pair.vertical) if String(placing.art) == String(pair.horizontal) else String(pair.horizontal)
	placing_card = String(placing.art)
	if mode == "row" and _row_axis != "":
		_row_axis = "vertical" if _row_axis == "horizontal" else "horizontal"
	_studio.placing_changed()
	update()


func _placing_hint() -> String:
	var key := "placing_line" if StudioRow.is_line(placing, StudioAssets.entries()) else "placing"
	return StudioText.t(key) % StudioDiff.name_of(placing)


## One ghost per piece of the row, each green or red by its own fit.
func _show_row(overlay: StudioOverlay) -> void:
	var template := _row_template()
	var size := OverworldMap.cell_of(placing.get("size", [1, 1]))
	var cells := _row_cells()
	var ghosts: Array[Dictionary] = []
	var skipped := 0
	if StudioBoundary.supported(template, StudioAssets.entries()):
		_show_connected(overlay, template, cells)
		return
	for cell: Vector2i in cells:
		var built := template.duplicate()
		built["at"] = StudioWork.footing(size, cell)
		built["size"] = size
		var ok := bool(_studio.work.placement_fit(built).ok)
		skipped += 0 if ok else 1
		ghosts.append(_ghost(built, ok))
	fits = skipped == 0
	overlay.ghosts = ghosts
	overlay.queue_redraw()
	if skipped == 0:
		_studio.say(StudioText.t("row_preview") % cells.size(), false)
	else:
		_studio.say(StudioText.t("row_fits") % [cells.size() - skipped, cells.size()], true)


func _show_connected(overlay: StudioOverlay, template: Dictionary, cells: Array[Vector2i]) -> void:
	var plan := _studio.work.boundary_plan(template, cells, Input.is_key_pressed(KEY_ALT))
	var ghosts: Array[Dictionary] = []
	for candidate: Dictionary in plan.candidates:
		ghosts.append(_ghost(StudioWork._built_like(candidate.object, Vector2i.ZERO), true))
		_hide_preview(int(candidate.index))
	for edit: Dictionary in plan.edits:
		if int(edit.index) >= 0 and OverworldMap.cell_of(edit.object.at) not in cells:
			ghosts.append(_ghost(StudioWork._built_like(edit.object, Vector2i.ZERO), true))
			_hide_preview(int(edit.index))
	for rejected: Dictionary in plan.rejected:
		ghosts.append(_ghost(rejected, false))
	overlay.ghosts = ghosts
	overlay.queue_redraw()
	fits = (plan.rejected as Array).is_empty()
	var direction := _row_axis.capitalize() if _row_axis != "" else "Connected"
	var message := StudioText.t("boundary_preview") % [cells.size(), direction] if mode == "row" else _placing_hint()
	if not fits:
		message = String(plan.get("reason", message))
	if _keep_message:
		_keep_message = false
		return
	_studio.say(message, not fits)


func _hide_preview(index: int) -> void:
	if index < 0:
		return
	for node: Node2D in _studio.map_view().nodes_of(index):
		if node.visible:
			_preview_hidden.append(node)
			node.hide()


func _restore_preview() -> void:
	for node: Node2D in _preview_hidden:
		if is_instance_valid(node):
			node.show()
	_preview_hidden.clear()


## The button is up on a row: one piece when it was a click, else the row as one change. Place mode goes on.
func _place_row(free: bool) -> void:
	var cells := _row_cells()
	var template := _row_template()
	var result := _studio.work.place(template, cells[0], free) if cells.size() == 1 else _studio.work.place_row(template, cells, free)
	if bool(result.get("ok", false)):
		placing = template
		var remembered := StudioBoundary.group(template, StudioAssets.entries()) if StudioBoundary.is_fence(template, StudioAssets.entries()) else String(template.get("art", ""))
		_studio.note_placed(remembered)
	_keep_message = true


static func _ghost(object: Dictionary, ok: bool) -> Dictionary:
	var box := StudioPick.footprint(object)
	return {
		"footprint": Rect2(Vector2(box.position) * TILE, Vector2(box.size) * TILE),
		"ok": ok,
		"parts": StudioGhost.parts(object),
	}
