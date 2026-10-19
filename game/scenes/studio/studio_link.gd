class_name StudioLink
extends Node
## Link door and Link warp (Concept/v0.3/10, section 7.9): the door or the warp is chosen first (the inspector's Link
## button, or a warp just placed), then any map in the picker, then a click on the cell to arrive on, then the way to
## face there, from a small menu at the cursor. The link is written in the map the door stands in, as one change, and
## the Studio goes back there. Esc lets go, and goes back too.

const FACINGS: Array[String] = ["down", "up", "left", "right"]

## Whether a link is being made, and for what: the map and the sid of the door or warp, and what to call it.
var active := false
var from_map := ""
var sid := -1
var what := ""
## The cell clicked and its map, waiting for the facing (Vector2i(-1, -1) before a click).
var chosen := Vector2i(-1, -1)
var chosen_map := ""
var current_facing := ""
## True only for a newly placed warp that remains a draft preview until a target is accepted.
var provisional := false
var stage := "idle"

var _source: Dictionary = {}
var _source_session: StudioSession
var _source_cell := Vector2i(-1, -1)
var _preview_facing := "down"
var _panel: PanelContainer
var _source_label: Label
var _instruction: Label
var _validity: Label
var _maps: OptionButton
var _checked_map: Dictionary = {}
var _checked_cell := Vector2i(-999, -999)
var _checked_result: Dictionary = {}
var _menu_epoch := 0

var _studio: StudioMode
var _menu: PopupMenu


func _init(studio: StudioMode) -> void:
	_studio = studio
	name = "Link"
	_menu = PopupMenu.new()
	_menu.name = "Facing"
	for facing: String in FACINGS:
		_menu.add_item(StudioText.t("link_face_" + facing))
	_menu.id_pressed.connect(func(index: int) -> void: face(FACINGS[index]))
	_menu.id_focused.connect(
		func(index: int) -> void:
			_preview_facing = FACINGS[index]
			update()
	)
	_menu.popup_hide.connect(
		func() -> void:
			var epoch := _menu_epoch
			_forget_click.call_deferred(epoch)
	)
	_menu.window_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
				cancel()
	)
	add_child(_menu)
	_build_panel()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "LinkWorkspace"
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", StudioStyle.box())
	_studio._dock(
		_panel,
		[0.0, 1.0, 1.0, 1.0],
		[StudioStyle.LEFT, -StudioStyle.BOTTOM - StudioStyle.PLACE, -StudioStyle.RIGHT, -StudioStyle.BOTTOM]
	)
	_studio.get_node("Chrome").add_child(_panel)
	var scroll := ScrollContainer.new()
	_panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	_source_label = StudioStyle.line("")
	_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_source_label)
	var row := HBoxContainer.new()
	body.add_child(row)
	row.add_child(StudioStyle.line(StudioText.t("link_destination")))
	_maps = OptionButton.new()
	_maps.name = "LinkDestination"
	_maps.focus_mode = Control.FOCUS_NONE
	_maps.clip_text = true
	_maps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_maps.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	_maps.item_selected.connect(func(index: int) -> void: choose_map(String(_maps.get_item_metadata(index))))
	row.add_child(_maps)
	var stop := StudioStyle.button(StudioText.t("link_cancel"), cancel)
	stop.name = "CancelLink"
	row.add_child(stop)
	_instruction = StudioStyle.line("")
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_instruction)
	_validity = StudioStyle.line("")
	_validity.name = "LinkValidity"
	_validity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_validity)
	var note := StudioStyle.line(StudioText.t("link_one_way"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)


func panel() -> Control:
	return _panel


## Starts linking the door of a building, or a warp (by sid, on the map shown). False for anything else.
func begin(link_sid: int, is_provisional := false) -> bool:
	if active:
		return false
	var object := _studio.work.raw(_studio.work.index_of(link_sid))
	var kind := String(object.get("kind", ""))
	if not kind in ["building", "warp"]:
		return false
	_menu.hide()
	_studio.get_viewport().gui_release_focus()
	active = true
	provisional = is_provisional
	from_map = String(_studio.current_map().get("id", ""))
	_source = object.duplicate(true)
	_source_session = _studio.work.session()
	_source_cell = (
		StudioDoors.door_cell(object) if kind == "building" else OverworldMap.cell_of(object.get("at", [0, 0]))
	)
	sid = link_sid
	what = (
		StudioText.f("link_the_door", [StudioAssets.name_of(String(object.art))])
		if kind == "building"
		else StudioText.t("link_the_warp")
	)
	var old_target: Variant = object.get("to", {})
	current_facing = String((old_target as Dictionary).get("facing", "")) if old_target is Dictionary else ""
	chosen = Vector2i(-1, -1)
	chosen_map = ""
	stage = "choose_target_map"
	_source_label.text = StudioText.f(
		"link_source", [what, _studio.map_title(from_map), _source_cell.x, _source_cell.y]
	)
	_maps.clear()
	var ids: Array[String] = []
	ids.assign(_studio.catalog().get("maps", {}).keys())
	ids.sort()
	for id: String in ids:
		_maps.add_item(_studio.map_title(id))
		_maps.set_item_metadata(_maps.item_count - 1, id)
	map_changed()
	_studio._route_workspace()
	_studio.say(StudioText.f("link_hint", [what]), false)
	update()
	return true


func choose_map(map_id: String) -> bool:
	if not active:
		return false
	if not _studio.go_to_map(map_id):
		_validity.text = StudioText.t("people_link_state_missing_map")
		return false
	stage = "choose_target_cell"
	_instruction.text = StudioText.t("link_choose_cell")
	return true


## Navigation cancels only the pending cell/facing, retaining the original source and its snapshot.
func map_changed() -> void:
	if not active:
		clear_arrival()
		return
	_menu_epoch += 1
	_menu.hide()
	chosen = Vector2i(-1, -1)
	chosen_map = ""
	if stage != "choose_target_map":
		stage = "choose_target_cell"
	_instruction.text = StudioText.t("link_choose_map" if stage == "choose_target_map" else "link_choose_cell")
	var id := String(_studio.current_map().get("id", ""))
	for index: int in _maps.item_count:
		if String(_maps.get_item_metadata(index)) == id:
			_maps.select(index)
	_validity.text = StudioText.t("link_choose_cell")
	update()


func _source_valid() -> bool:
	return (
		_source_session != null
		and _studio.work.sessions().get(from_map) == _source_session
		and _source_session.doc().object_of_sid(sid) == _source
	)


## Lets go of the link (Esc), and goes back to the door's map.
func cancel() -> void:
	if not active:
		return
	var was_provisional := provisional
	var source_sid := sid
	var source_matches := _source_valid()
	var returned := _finish()
	provisional = false
	if not returned:
		_studio.say(StudioText.f("link_lost", [what]), true)
	elif was_provisional and not source_matches:
		_studio.say(StudioText.t("people_entrance_stale"), true)
	elif not was_provisional or _studio.work.cancel_provisional_warp(source_sid):
		_studio.say(StudioText.f("link_cancelled", [what]), false)
	else:
		_studio.say(StudioText.t("people_warp_cancel_failed"), true)


## Whether the facing menu is open.
func menu_open() -> bool:
	return _menu.visible


## What a click on `cell` of the map shown would do: {ok, reason}. The cell must be open ground, and not the door or a
## warp itself (arriving on one would send the player straight on).
func check(cell: Vector2i) -> Dictionary:
	var map := _studio.current_map()
	# The runtime map is replaced after edits. Reuse a hover result only for that exact immutable version and cell.
	if is_same(map, _checked_map) and cell == _checked_cell:
		return _checked_result
	var map_id := String(map.get("id", ""))
	var target := {"map": map_id, "at": [cell.x, cell.y], "facing": "down"}
	var state := StudioPeopleIndex.link_state("warp", target, _studio.catalog().get("maps", {}))
	if state == "valid":
		_checked_result = {"ok": true, "reason": ""}
		_checked_map = map
		_checked_cell = cell
		return _checked_result
	var reason_key := "link_blocked"
	match state:
		"off_map":
			reason_key = "link_off_map"
		"loop":
			reason_key = "link_on_door"
		"missing_map":
			reason_key = "people_link_state_missing_map"
		"invalid_facing":
			reason_key = "people_link_state_invalid_facing"
	_checked_map = map
	_checked_cell = cell
	_checked_result = {"ok": false, "reason": StudioText.t(reason_key)}
	return _checked_result


## A click on `cell` (the cursor's), at `screen` (where the menu opens, in its embedder's coordinates).
func click(cell: Vector2i, screen: Vector2) -> void:
	if not active:
		return
	var fit := check(cell)
	if not fit.ok:
		stage = "choose_target_cell"
		_validity.text = String(fit.reason)
		_studio.say(String(fit.reason), true)
		return
	chosen = cell
	chosen_map = String(_studio.current_map().get("id", ""))
	# Into a room you usually face up, away from the door; out in the town, down, away from the house.
	var usual := (
		current_facing
		if FACINGS.has(current_facing)
		else "up" if bool(_studio.current_map().get("interior", false)) else "down"
	)
	stage = "choose_facing"
	_preview_facing = usual
	_instruction.text = StudioText.t("link_choose_facing")
	_validity.text = StudioText.f("link_arrival", [_studio.map_title(chosen_map), cell.x, cell.y])
	_menu_epoch += 1
	_menu.popup(Rect2i(Vector2i(screen), Vector2i(170, 0)))
	_menu.set_focused_item(FACINGS.find(usual))
	update()


## The facing was chosen: the door or warp now leads to the clicked cell, facing `facing`.
func face(facing: String) -> void:
	if not active or chosen == Vector2i(-1, -1) or not FACINGS.has(facing):
		return
	if not _source_valid():
		cancel()
		_studio.say(StudioText.t("people_entrance_stale"), true)
		return
	var target := {"map": chosen_map, "at": chosen, "facing": facing}
	var fit_state := StudioPeopleIndex.link_state("warp", target, _studio.catalog().get("maps", {}))
	if fit_state != "valid":
		_menu_epoch += 1
		_menu.hide()
		chosen = Vector2i(-1, -1)
		stage = "choose_target_cell"
		_instruction.text = StudioText.t("link_choose_cell")
		_validity.text = StudioText.t("people_link_state_" + fit_state)
		_studio.say(StudioText.t("people_link_state_" + fit_state), true)
		update()
		return
	var destination_map := chosen_map
	var destination_cell := chosen
	var shown := _studio.map_title(destination_map)
	var was_provisional := provisional
	if not _finish():
		provisional = false
		_studio.say(StudioText.f("link_lost", [what]), true)
		return
	if _studio.work.link(sid, target):
		if was_provisional:
			_studio.work.combine_recent_changes(2, StudioText.t("people_place_linked_warp"))
		provisional = false
		_studio.say(
			StudioText.f(
				"link_done", [what, shown, destination_cell.x, destination_cell.y, StudioText.t("link_face_" + facing)]
			),
			false
		)
	elif was_provisional:
		provisional = false
		_studio.work.cancel_provisional_warp(sid)
		_studio.say(StudioText.f("link_lost", [what]), true)


## The outline under the cursor: green where a click would link, red where it would not.
func update() -> void:
	var overlay := _studio.overlay()
	if overlay == null:
		return
	if not active or not _studio.cursor_over_map():
		overlay.brush = Rect2()
	else:
		var cell := _studio.cursor_cell()
		overlay.brush = Rect2(Vector2(cell) * OverworldScale.TILE, Vector2.ONE * OverworldScale.TILE)
		var fit := check(cell)
		overlay.brush_colour = StudioOverlay.FITS if bool(fit.ok) else StudioOverlay.CLASHES
		if chosen.x < 0:
			_validity.text = StudioText.t("link_valid") if bool(fit.ok) else String(fit.reason)
	if active:
		overlay.link_source = (
			_source_cell if String(_studio.current_map().get("id", "")) == from_map else Vector2i(-1, -1)
		)
		overlay.link_arrival = chosen
		overlay.link_facing = _preview_facing
	overlay.queue_redraw()


func _forget_click(epoch: int) -> void:
	if active and epoch == _menu_epoch:
		chosen = Vector2i(-1, -1)
		stage = "choose_target_cell"
		_instruction.text = StudioText.t("link_choose_cell")
		update()


func clear_arrival() -> void:
	var overlay := _studio.overlay()
	if overlay != null:
		overlay.link_source = Vector2i(-1, -1)
		overlay.link_arrival = Vector2i(-1, -1)
		overlay.queue_redraw()


func mark_arrival(cell: Vector2i, facing: String) -> void:
	var overlay := _studio.overlay()
	overlay.link_arrival = cell
	overlay.link_facing = facing
	overlay.queue_redraw()


## Back to the door's map, with the door selected. False when that map is not there any more.
func _finish() -> bool:
	_menu_epoch += 1
	_menu.hide()
	active = false
	stage = "idle"
	chosen = Vector2i(-1, -1)
	clear_arrival()
	_studio._route_workspace()
	if _studio.overlay() != null:
		_studio.overlay().brush = Rect2()
		_studio.overlay().queue_redraw()
	if not _studio.go_to_map(from_map, _studio.cell_of_sid(from_map, sid)):
		return false
	if String(_studio.current_map().get("id", "")) != from_map or _studio.work.index_of(sid) < 0:
		return false
	_studio.select_sids([sid])
	return true
