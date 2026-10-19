class_name StudioMode
extends Control
## Lanternroot Studio's mode controller (ADR-0066, Concept/v0.3/10-lanternroot-studio.md): F2 edits the town in the
## same view it is played in, F1 plays. The overworld mounts it only when `available()`; while `editing` is true the
## overworld neither walks, talks, counts time nor opens menus, and the Studio drives the camera.
##
## Edit shows the top bar, tools, inspector and status panels around the town. Active tabs share one lower workspace;
## the PixelView shrinks to the space between them, and StudioOverlay draws above the town. A click
## picks what is drawn under the cursor (StudioPick), Shift adds, a box on open ground selects what it touches, Tab
## cycles through what is stacked there, and a drag moves the selection (StudioArrange). Phase S1 edits: every change is
## a command on the map's draft (StudioWork), undone with Ctrl+Z; the draft is saved on its own (drafts_dir) and the
## content files are never written (Publish, phase S2, does that).

const TILE := OverworldScale.TILE
## More objects than this changed at once (a big paste, a rebase): the whole town is drawn again.
const MAX_CHANGED := 300
## The overlays' switches when a run starts. The Studio remembers changes to them for the run.
const DEFAULT_OPTIONS := {
	"grid": true, "footprints": false, "solid": false, "doors": true, "talk": false, "labels": true, "player": true
}
static var drafts_dir := StudioFiles.DRAFTS
## Content root may be a temporary copy when a scene test mounts the Studio.
static var content_dir := ContentLoader.ROOT
## Where the save goes while a draft is played (Play draft), so the real save is never written.
static var playtest_dir := "user://studio/playtest/"
static var _remembered: Dictionary = DEFAULT_OPTIONS.duplicate()

var editing := false
## The index (in the map's `objects`) of the selected object (the last one picked when several are); -1 for none.
var selection := -1
## Whether the town plays the draft (Play draft): F1 then shows the drafted map.
var play_draft := false
var work: StudioWork
var arrange: StudioArrange
var publish_tools: StudioPublishTools
var context_menu: StudioContextMenu
## Resizing by remaking: the handles, the question, the queue and Run remakes (Concept/v0.3/10, section 7.7).
var remaking: StudioRemaking
var asset_reviews: StudioAssetReviews
## The Land tab (S5): its hand, and the Map size dialog.
var land: StudioLandTool
var map_size: StudioMapSize
## Create a separate outdoor map scene as a draft.
var area_dialog: StudioAreaDialog
## Link door and Link warp (S6).
var link: StudioLink
## The developer inspector (S7): F3 in Play.
var debug: StudioDebug
## Make it a thing (S8).
var thing_dialog: StudioThingDialog
## The quest editor (S9): what it edits, and the Quests tab's panel.
var quests: StudioQuestWork
var quest_panel: StudioQuestPanel
## The tab in use: "objects" or "land" (StudioTopBar.TABS).
var tab := "objects"
## The overlays' switches by name (StudioTools.OVERLAYS), as StudioOverlay reads them.
var overlay_options: Dictionary = {}

var _overworld: Control
## What the overworld hands over when it mounts the Studio: its PixelView ("view"), TownMapView ("map"), Camera2D
## ("camera"), the player's Walker ("player"), Callables for the map shown now ("current"), whether the town is idle
## ("idle") and the content ("catalog"), the keys it holds down ("held", shared, so the Studio can let go of them),
## and the play HUD to hide while editing ("hud").
var _parts: Dictionary = {}
## The HUD nodes hidden while editing, with whether each was visible, to give back on Play.
var _hud_shown: Dictionary = {}
var _overlay: StudioOverlay
var _camera: StudioCamera
var _pick := StudioPick.new()
var _chrome: Control
var _catcher: Control
var _top: StudioTopBar
var _tools: StudioTools
var _inspector: StudioInspector
var _status: StudioStatusBar
var _place_panel: StudioPlacePanel
var _build_panel: StudioBuildPanel
var _land_panel: StudioLandPanel
var _people_panel: StudioPeoplePanel
var _draft_tag: PanelContainer
var _confirm: ConfirmationDialog
## Placing someone who stands on another map asks first (S6): the question, and what to place when it is answered yes.
var _move_confirm: ConfirmationDialog
var _move_pending: Dictionary = {}
var _delete_pending: Array[int] = []
var _delete_map := ""
var _delete_session: StudioSession
var _delete_history: StudioHistory
var _place_on := true
var _selection: StudioSelection
var _keys: StudioKeys
var _shown_map: Dictionary = {}
var _names: Dictionary = {}
## Everything under the cursor, front-most first, and the cursor (a point on the catcher; where it is on the town).
var _stack: Array[int] = []
var _cursor := Vector2(-1, -1)
var _polled := Vector2(-1, -1)
var _cursor_inside := false
var _hover_cell := Vector2i.ZERO
var _hover_world := Vector2.ZERO
var _look := ""
var _dragging := false
## The draft's status text is waiting for the next frame (_update_panels).
var _draft_text_pending := false
## Whether the catalog showed before the Land tab hid it (it comes back with Objects).
var _place_before_land := true
## A start facing is only a preview until Apply facing or Set start commits it.
var _start_facing_choice := ""
## Keep the Objects shelf choice while routing through Land, People or Quests.
var _restore_object_shelf := false
## Return target when People & Doors opens a person's dialogue.
var _person_return := {}
## Whether the developer inspector showed when Edit began (it comes back with Play).
var _debug_before_edit := false
## The play HUD's right-hand nodes moved aside for the inspector: node -> [offset_left, offset_right] as they were.
var _hud_moved: Dictionary = {}
## Per-stage microseconds of the last changes, summed, filled only while `profiling` (tools/studio_place_bench.gd).
var profiling := false
var stage_usec: Dictionary = {}


func _init(overworld: Control = null, parts: Dictionary = {}) -> void:
	_overworld = overworld
	_parts = parts
	name = "Studio"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if _parts.is_empty():
		return
	overlay_options = _remembered.duplicate()
	work = StudioWork.new(self)
	_selection = StudioSelection.new(self)
	_keys = StudioKeys.new(self)
	_overlay = StudioOverlay.new()
	_overlay.visible = false
	_overlay.set_options(overlay_options)
	pixel_view().viewport.add_child(_overlay)
	_camera = StudioCamera.new(pixel_view(), camera())
	arrange = StudioArrange.new(self)
	land = StudioLandTool.new(self)
	_build_chrome()
	_build_draft_tag()
	context_menu = StudioContextMenu.new(self)
	add_child(context_menu)
	publish_tools = StudioPublishTools.new(self, _top)
	add_child(publish_tools)
	link = StudioLink.new(self)
	add_child(link)
	if _parts.has("state"):
		debug = StudioDebug.new(self)
		_dock(debug, [1.0, 0.0, 1.0, 1.0], [-StudioDebug.WIDTH, 0, 0, 0])
		add_child(debug)
	remaking = StudioRemaking.new(self)
	add_child(remaking)
	remaking.changed.connect(_remakes_changed)
	_tools.run_remakes_pressed.connect(func() -> void: remaking.run())
	_remakes_changed()
	asset_reviews = StudioAssetReviews.new(self)
	add_child(asset_reviews)
	asset_reviews.changed.connect(_reviews_changed)
	_tools.asset_updates_pressed.connect(func() -> void: asset_reviews.open_reviews())
	_reviews_changed()


func _exit_tree() -> void:
	# The drafts are kept, and the town goes back to the files: the catalog outlives this screen.
	if work != null:
		work.flush()
		work.set_play_draft(false)
		work.restore_files()


## The Studio added to the overworld when it is available; null otherwise (and nothing is added).
static func mount(overworld: Control, parts: Dictionary) -> StudioMode:
	if not available():
		return null
	# The Land tab repaints the ground in place: its pieces' images stay in memory (GroundLayer.repaint).
	GroundLayer.keep_images = true
	var made := StudioMode.new(overworld, parts)
	overworld.add_child(made)
	return made


func pixel_view() -> PixelView:
	return _parts.get("view") as PixelView


func map_view() -> TownMapView:
	return _parts.get("map") as TownMapView


func camera() -> Camera2D:
	return _parts.get("camera") as Camera2D


func player() -> Walker:
	return _parts.get("player") as Walker


## The map shown now, as OverworldMap.build made it (width, height, ground, objects, solid, warps, people...).
func current_map() -> Dictionary:
	var current: Variant = _parts.get("current")
	return (current as Callable).call() if current is Callable else {}


## Whether the Studio exists in this run: never in an exported build, only with the toggle (Settings.studio, or
## ROOTWARD_STUDIO=1 for one launch), and only where the content files can be written.
static func available() -> bool:
	if OS.has_feature("template"):
		return false
	if not (Settings.studio or OS.get_environment("ROOTWARD_STUDIO") == "1"):
		return false
	return _content_writable()


static func _content_writable() -> bool:
	return StudioFiles.can_write(content_dir)


func content_root() -> String:
	return String(_parts.get("content_root", content_dir))


func overlay() -> StudioOverlay:
	return _overlay


func pick() -> StudioPick:
	return _pick


## What the overworld handed over (see `_parts`).
func parts() -> Dictionary:
	return _parts


## A thing of the map as OverworldMap.build made it (cells as Vector2i), or {} for an index that is not there.
func object_at(index: int) -> Dictionary:
	var objects: Array = current_map().get("objects", [])
	return objects[index] as Dictionary if index >= 0 and index < objects.size() else {}


func inspector() -> StudioInspector:
	return _inspector


func place_panel() -> StudioPlacePanel:
	if tab == "build" and _build_panel != null:
		return _build_panel.catalog
	return _place_panel


func build_panel() -> StudioBuildPanel:
	return _build_panel


func people_panel() -> StudioPeoplePanel:
	return _people_panel


func status_bar() -> StudioStatusBar:
	return _status


func studio_camera() -> StudioCamera:
	return _camera


# --- play and edit ------------------------------------------------------------------------------------------------


func set_editing(on: bool) -> void:
	if on == editing:
		return
	if _overlay == null:
		editing = on
		return
	if on:
		_enter()
	else:
		_leave()


func _enter() -> void:
	var map := current_map()
	if debug != null and debug.visible:
		_debug_before_edit = true
		debug.set_shown(false)
		_dock_debug()
	# The camera first: it remembers the play view's scale, which the panels are about to change.
	_camera.begin(OverworldMap.size_of(map))
	editing = true
	_route_workspace()
	_chrome.visible = true
	_overlay.visible = true
	_top.set_editing(true)
	_draft_tag.visible = false
	# The play HUD (the quest card, the "Space: talk" prompt, Hotaru's bubble) stays out of the editor's way.
	for node: Variant in _parts.get("hud", []):
		if node is CanvasItem:
			_hud_shown[node] = (node as CanvasItem).visible
			(node as CanvasItem).visible = false
	# The maps made here and not published yet go in the catalog, so the picker lists them and their doors lead there.
	work.open_new_maps()
	# The map's session: its draft when it has one, and then the town shows the draft.
	work.open(String(map.get("id", "")))
	_load_map(current_map())
	_camera.fit_map()
	_camera.apply()
	_refresh_hover()
	_update_panels()
	if publish_tools != null:
		publish_tools.schedule()


func _leave() -> void:
	if asset_reviews != null:
		asset_reviews.dismiss()
	# A map that is only a draft cannot be played from the files: playing it plays the draft, so the real save never
	# names a map that is not there.
	if not play_draft and work.is_new_map(String(current_map().get("id", ""))):
		set_play_draft(true)
		say(StudioText.t("play_draft_new_map"), false)
	context_menu.dismiss()
	_cancel_delete()
	_cancel_move()
	link.cancel()
	arrange.stop_placing()
	arrange.cancel()
	land.cancel()
	map_size.hide()
	area_dialog.hide()
	thing_dialog.hide()
	editing = false
	select(-1)
	work.flush()
	if not play_draft:
		work.restore_files()
		redraw_town()
	_camera.end()
	_dock_view(false)
	if _debug_before_edit:
		_debug_before_edit = false
		debug.set_shown(true)
		_dock_debug()
	_chrome.visible = false
	_overlay.visible = false
	_top.set_editing(false)
	_draft_tag.visible = play_draft
	_keys.held.clear()
	_dragging = false
	# Arrow keys let go while editing never reached the overworld, which would keep walking on them.
	var held: Variant = _parts.get("held")
	if held is Array:
		(held as Array).clear()
	for node: Variant in _hud_shown:
		if is_instance_valid(node):
			(node as CanvasItem).visible = bool(_hud_shown[node])
	_hud_shown.clear()


## The town shrinks to the space between the panels while editing, and fills the window again for play.
func _dock_view(edit: bool) -> void:
	var view := pixel_view()
	view.offset_left = StudioStyle.LEFT if edit else 0
	view.offset_top = StudioStyle.TOP if edit else 0
	view.offset_right = -StudioStyle.RIGHT if edit else 0
	view.offset_bottom = -_bottom() if edit else 0
	if _catcher != null:
		_dock(_catcher, [0.0, 0.0, 1.0, 1.0], [StudioStyle.LEFT, StudioStyle.TOP, -StudioStyle.RIGHT, -_bottom()])


## The height the status bar and the active lower workspace take under the town.
func _bottom() -> int:
	if link != null and link.active:
		return StudioStyle.BOTTOM + StudioStyle.PLACE
	var descriptor: Dictionary = StudioTopBar.DESCRIPTORS.get(tab, {})
	var shelf := String(descriptor.get("shelf", ""))
	var shelf_shown := shelf in ["land", "people", "build"] or (shelf == "objects" and _place_on)
	return StudioStyle.BOTTOM + (StudioStyle.PLACE if shelf_shown else 0)


func place_list_shown() -> bool:
	return _place_on


func set_place_list(on: bool) -> void:
	_place_on = on
	_route_workspace()


## Applies one workspace descriptor to every dock and to the town's usable viewport.
func _route_workspace() -> void:
	var descriptor: Dictionary = StudioTopBar.DESCRIPTORS.get(tab, {})
	if descriptor.is_empty():
		return
	var shelf := String(descriptor.get("shelf", ""))
	var linking := link != null and link.active
	if linking:
		shelf = "link"
	if link != null:
		link.panel().visible = linking
	if _top != null:
		_top.set_tab(tab)
		_top.set_linking(linking)
	if _tools != null:
		_tools.visible = not linking
		_tools.show_tab(tab)
		_tools.show_place_list(_place_on)
	if _place_panel != null:
		_place_panel.visible = shelf == "objects" and _place_on
	if _land_panel != null:
		_land_panel.visible = shelf == "land"
	if _people_panel != null:
		_people_panel.visible = shelf == "people"
	if _build_panel != null:
		_build_panel.visible = shelf == "build"
	if _inspector != null:
		_inspector.visible = bool(descriptor.get("inspector", true)) and not linking
	if quest_panel != null:
		quest_panel.visible = shelf == "quests"
	if _status != null:
		_status.show_hint("link_keys" if linking else "land_hint" if tab == "land" else "hint")
	_dock_view(editing)


## Play draft: F1 plays with the draft in the town and the save pointed away; off, the files' town and the real save.
func set_play_draft(on: bool) -> void:
	if on == play_draft:
		return
	play_draft = on
	work.set_play_draft(on)
	if editing and work.session() != null:
		# The map being edited is the draft whether or not it is played.
		work.open(String(current_map().get("id", "")))
		work.refresh()
	elif not editing:
		redraw_town()
	_top.set_play_draft(on)
	_draft_tag.visible = on and not editing


## The town drawn again from the map in the catalog, the way play draws it (lit lamps, open gates).
func redraw_town() -> void:
	if _overworld != null and _overworld.has_method("_draw_map"):
		_overworld.call("_draw_map")
	else:
		map_view().show_map(current_map())


# --- the panels ---------------------------------------------------------------------------------------------------


func _build_chrome() -> void:
	_chrome = Control.new()
	_chrome.name = "Chrome"
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.visible = false
	add_child(_chrome)
	# The town's own controls (the overworld's background) would swallow the mouse before _unhandled_input saw it, so
	# the world has a Control of its own over the view, and it hears the mouse.
	_catcher = Control.new()
	_catcher.name = "World"
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.gui_input.connect(_world_input)
	_dock(_catcher, [0.0, 0.0, 1.0, 1.0], [StudioStyle.LEFT, StudioStyle.TOP, -StudioStyle.RIGHT, -_bottom()])
	_chrome.add_child(_catcher)
	_top = StudioTopBar.new()
	_top.play_pressed.connect(set_editing.bind(false))
	_top.edit_pressed.connect(set_editing.bind(true))
	_top.undo_pressed.connect(func() -> void:
		if tab == "quests":
			quest_panel.undo()
		else:
			work.undo())
	_top.redo_pressed.connect(func() -> void:
		if tab == "quests":
			quest_panel.redo()
		else:
			work.redo())
	_top.play_draft_toggled.connect(set_play_draft)
	_top.tab_chosen.connect(set_tab)
	_top.map_chosen.connect(func(id: String) -> void: go_to_map(id))
	_top.new_area_pressed.connect(open_new_area)
	_dock(_top, [0.0, 0.0, 1.0, 0.0], [0, 0, 0, StudioStyle.TOP])
	_tools = StudioTools.new(overlay_options)
	_tools.option_changed.connect(set_overlay)
	_tools.place_list_toggled.connect(set_place_list)
	_tools.select_pressed.connect(start_select)
	_tools.area_select_pressed.connect(start_area_select)
	_tools.area_filter_chosen.connect(set_area_filter)
	_dock(_tools, [0.0, 0.0, 0.0, 1.0], [0, StudioStyle.TOP, StudioStyle.LEFT, -StudioStyle.BOTTOM])
	_inspector = StudioInspector.new()
	_inspector.delete_requested.connect(request_delete)
	_inspector.field_changed.connect(func(sid: int, key: String, value: Variant) -> void: work.set_field(sid, key, value))
	_inspector.size_changed.connect(func(sid: int, size: Vector2i) -> void: work.resize_object(sid, size))
	_inspector.link_requested.connect(link_door)
	_inspector.make_interior_requested.connect(func(sid: int) -> void: make_interior(sid))
	_inspector.unlink_requested.connect(unlink_door)
	_inspector.go_to_requested.connect(func(map_id: String, cell: Vector2i) -> void:
		var object := work.raw(selection)
		var target: Dictionary = object.get("to", {})
		go_to_arrival(map_id, cell, String(target.get("facing", "down")))
	)
	_inspector.map_field_changed.connect(func(key: String, value: Variant) -> void: work.set_map_field(key, value))
	_inspector.make_thing_requested.connect(func(sid: int) -> void: thing_dialog.open(sid))
	_inspector.edit_talk_requested.connect(edit_person_talk)
	_inspector.edit_person_quest_requested.connect(edit_person_quest)
	_dock(_inspector, [1.0, 0.0, 1.0, 1.0], [-StudioStyle.RIGHT, StudioStyle.TOP, 0, -StudioStyle.BOTTOM])
	_status = StudioStatusBar.new()
	_dock(_status, [0.0, 1.0, 1.0, 1.0], [0, -StudioStyle.BOTTOM, 0, 0])
	_place_panel = StudioPlacePanel.new()
	_place_panel.chosen.connect(start_place)
	_place_panel.asset_context_requested.connect(func(art: String, point: Vector2) -> void: asset_reviews.open_menu(art, point))
	_dock(
		_place_panel,
		[0.0, 1.0, 1.0, 1.0],
		[StudioStyle.LEFT, -StudioStyle.BOTTOM - StudioStyle.PLACE, -StudioStyle.RIGHT, -StudioStyle.BOTTOM]
	)
	_build_panel = StudioBuildPanel.new()
	_build_panel.visible = false
	_build_panel.catalog.chosen.connect(start_place)
	_build_panel.catalog.asset_context_requested.connect(func(art: String, point: Vector2) -> void: asset_reviews.open_menu(art, point))
	_build_panel.group_chosen.connect(func(_group: String) -> void:
		arrange.stop_placing()
		arrange.cancel())
	_build_panel.paint_floor_requested.connect(paint_room_floor)
	_dock(_build_panel, [0.0, 1.0, 1.0, 1.0],
		[StudioStyle.LEFT, -StudioStyle.BOTTOM - StudioStyle.PLACE, -StudioStyle.RIGHT, -StudioStyle.BOTTOM])
	_land_panel = StudioLandPanel.new()
	_land_panel.visible = false
	_land_panel.ground_chosen.connect(set_ground)
	_land_panel.brush_chosen.connect(set_brush)
	_land_panel.land_tool_chosen.connect(set_land_tool)
	_land_panel.map_size_pressed.connect(open_map_size)
	_dock(
		_land_panel,
		[0.0, 1.0, 1.0, 1.0],
		[StudioStyle.LEFT, -StudioStyle.BOTTOM - StudioStyle.PLACE, -StudioStyle.RIGHT, -StudioStyle.BOTTOM]
	)
	_people_panel = StudioPeoplePanel.new(self)
	_people_panel.visible = false
	_people_panel.place_person_requested.connect(start_place)
	_people_panel.place_warp_requested.connect(func() -> void: start_place("marker-warp"))
	_people_panel.locate_person_requested.connect(locate_person)
	_people_panel.entrance_action_requested.connect(people_entrance_action)
	_people_panel.room_draft_action_requested.connect(people_room_draft_action)
	_people_panel.start_requested.connect(func() -> void: start_place("marker-start"))
	_people_panel.start_facing_requested.connect(set_start_facing)
	_people_panel.start_facing_apply_requested.connect(apply_start_facing)
	_dock(
		_people_panel,
		[0.0, 1.0, 1.0, 1.0],
		[StudioStyle.LEFT, -StudioStyle.BOTTOM - StudioStyle.PLACE, -StudioStyle.RIGHT, -StudioStyle.BOTTOM]
	)
	for panel: Control in [_top, _tools, _inspector, _status, _place_panel, _build_panel, _land_panel, _people_panel]:
		_chrome.add_child(panel)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Delete"
	_confirm.confirmed.connect(_confirm_delete)
	_confirm.canceled.connect(_cancel_delete)
	_chrome.add_child(_confirm)
	_move_confirm = ConfirmationDialog.new()
	_move_confirm.name = "MovePerson"
	_move_confirm.title = StudioText.t("person_move_title")
	_move_confirm.confirmed.connect(_confirm_move)
	_move_confirm.canceled.connect(_cancel_move)
	_chrome.add_child(_move_confirm)
	map_size = StudioMapSize.new(self)
	_chrome.add_child(map_size)
	area_dialog = StudioAreaDialog.new(self)
	_chrome.add_child(area_dialog)
	thing_dialog = StudioThingDialog.new(self)
	_chrome.add_child(thing_dialog)
	quests = StudioQuestWork.new(self)
	quest_panel = StudioQuestPanel.new(self)
	quest_panel.return_to_person_requested.connect(return_to_person)
	_dock(quest_panel, [0.0, 0.0, 1.0, 1.0], [0, StudioStyle.TOP, 0, -StudioStyle.BOTTOM])
	_chrome.add_child(quest_panel)
	_route_workspace()


## The small "DRAFT" tag over the town while a draft is played.
func _build_draft_tag() -> void:
	_draft_tag = PanelContainer.new()
	_draft_tag.name = "DraftTag"
	_draft_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draft_tag.visible = false
	_draft_tag.add_theme_stylebox_override("panel", UiTheme.box(Color("#1a1410"), UiTheme.AMBER, 1, 3, Vector2(8, 2)))
	var label := Ui.label(StudioText.t("draft_tag"), "Muted")
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UiTheme.AMBER)
	_draft_tag.add_child(label)
	_dock(_draft_tag, [1.0, 0.0, 1.0, 0.0], [-86, 10, -12, 34])
	add_child(_draft_tag)


static func _dock(node: Control, anchors: Array, offsets: Array) -> void:
	node.anchor_left = anchors[0]
	node.anchor_top = anchors[1]
	node.anchor_right = anchors[2]
	node.anchor_bottom = anchors[3]
	node.offset_left = offsets[0]
	node.offset_top = offsets[1]
	node.offset_right = offsets[2]
	node.offset_bottom = offsets[3]


## Switches an overlay on or off; the choice is kept for the run.
func set_overlay(option: String, on: bool) -> void:
	overlay_options[option] = on
	_remembered[option] = on
	if _tools != null:
		_tools.show_option(option, on)
	if _overlay != null:
		_overlay.set_options(overlay_options)


## A map is on screen: what to pick from, what to draw over it, and what to call it.
func _load_map(map: Dictionary) -> void:
	_shown_map = map
	_start_facing_choice = ""
	_pick.rebuild(map_view(), map)
	_overlay.talks = talk_ids()
	_overlay.set_map(map, _map_names(), _entrance_diagnostics(map))
	_top.set_maps(map_list(), String(map.get("id", "")))
	_place_panel.set_placed(placed_arts(map))
	_build_panel.catalog.set_placed(placed_arts(map))
	_build_panel.show_map(bool(map.get("interior", false)))
	select(-1)
	land.cancel()
	land.fit_to_map()
	if tab == "land":
		_show_land()
	if _people_panel != null:
		_people_panel.refresh()


## The pictures standing on `map` (buildings and props), each once: the catalog's "On this map" view.
static func placed_arts(map: Dictionary) -> Array[String]:
	var arts: Array[String] = []
	for object: Dictionary in map.get("objects", []):
		var art := String(object.get("art", ""))
		if art != "" and String(object.get("kind", "")) in StudioAssets.KINDS and not art in arts:
			arts.append(art)
	return arts


func _map_names() -> Dictionary:
	if _names.is_empty():
		for id: String in catalog().maps:
			_names[id] = String((catalog().maps[id] as Dictionary).get("name", id))
	return _names


func clear_map_names() -> void:
	_names.clear()
	if _top != null and not _shown_map.is_empty():
		_top.set_maps(map_list(), String(_shown_map.get("id", "")))


## The name a map is shown by (its id when it has none).
func map_title(id: String) -> String:
	return String(_map_names().get(id, id))


## The maps the picker offers: the town and the other outdoor maps first, then the rooms, each by name; {id, name,
## room, new} each.
func map_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var unlinked_rooms: Dictionary = {}
	for room: Dictionary in StudioPeopleIndex.unlinked_room_drafts(catalog().maps, work.new_map_ids()):
		unlinked_rooms[String(room.get("id", ""))] = true
	for id: String in catalog().maps:
		var map: Dictionary = catalog().maps[id]
		out.append({
			"id": id,
			"name": String(map.get("name", id)),
			"room": bool(map.get("interior", false)),
			"new": work.is_new_map(id),
			"unlinked_room_draft": unlinked_rooms.has(id),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.room) != bool(b.room):
			return not bool(a.room)
		return String(a.name).naturalnocasecmp_to(String(b.name)) < 0
	)
	return out


## Shows another map to edit (the picker, Go there, a link): the player is put on it, its session opens, and the camera
## looks at `cell` (the map's start when it is not on the map). False when there is no such map.
func go_to_map(id: String, cell := Vector2i(-1, -1)) -> bool:
	if not catalog().maps.has(id):
		return false
	work.flush()
	if String(current_map().get("id", "")) != id:
		var show_map: Callable = _parts.get("show_map", Callable())
		if not show_map.is_valid():
			return false
		show_map.call(id)
		work.open(id)
		_load_map(current_map())
	var map := current_map()
	var at: Vector2i = cell if OverworldMap.inside(map, cell) else map.get("start", Vector2i.ZERO)
	if _camera != null:
		_camera.map_changed(OverworldMap.size_of(map), (Vector2(at) + Vector2(0.5, 0.5)) * TILE)
	_refresh_hover()
	if link != null:
		link.map_changed()
	return true


## Read-only destination navigation shares the link/Publish validator and leaves a visible arrival arrow.
func go_to_arrival(map_id: String, cell: Vector2i, facing := "down") -> bool:
	var target := {"map": map_id, "at": cell, "facing": facing}
	var state := StudioPeopleIndex.link_state("warp", target, catalog().get("maps", {}))
	if state != "valid":
		say(StudioText.t("people_link_state_" + state), true)
		return false
	if not go_to_map(map_id, cell):
		return false
	select(-1)
	link.mark_arrival(cell, facing)
	return true


## The cell of a thing of a map (a building's door, else where it stands), for the camera to look at; (-1, -1) when it
## is not there.
func cell_of_sid(map_id: String, sid: int) -> Vector2i:
	var session: StudioSession = work.sessions().get(map_id)
	if session == null:
		return Vector2i(-1, -1)
	var object := session.doc().object_of_sid(sid)
	if object.is_empty():
		return Vector2i(-1, -1)
	if String(object.get("kind", "")) == "building":
		return StudioDoors.door_cell(object)
	return OverworldMap.cell_of(object.get("at", [-1, -1]))


## Each townsperson's talk (person id -> talk id), for the overlay of talk links.
func talk_ids() -> Dictionary:
	var out := {}
	var townsfolk: Dictionary = catalog().get("townsfolk", {})
	for id: String in townsfolk:
		out[id] = String((townsfolk[id] as Dictionary).get("talk", id))
	return out


## The shared content catalog: the same Dictionary the overworld plays from, so a map put in its `maps` is walked.
func catalog() -> Dictionary:
	var shared: Variant = _parts.get("catalog")
	return (shared as Callable).call() if shared is Callable else OverworldScreen.catalog_of()


## Work put a new map in the catalog (after a command, an undo or the draft loading): draw it, pick from it, and keep
## what is selected selected.
func map_rebuilt(map: Dictionary, built: Dictionary) -> void:
	_shown_map = map
	var t := Time.get_ticks_usec()
	# A few objects changed: only their pictures and their place in the pick index are made again (StudioWork._build
	# says which). Anything else, or anything the pictures do not follow, draws the whole town.
	var change := _drawn_change(map, built.get("changes", {}))
	if change.is_empty():
		redraw_town()
	t = lap("town", t)
	if change.is_empty() or not _pick.update(map_view(), map, change.new_of_old, change.made):
		_pick.rebuild(map_view(), map)
	t = lap("pick", t)
	_overlay.set_map(map, _map_names(), _entrance_diagnostics(map))
	_overlay.remaking_boxes = _remaking_boxes(map)
	t = lap("overlay", t)
	_place_panel.set_placed(placed_arts(map))
	_build_panel.catalog.set_placed(placed_arts(map))
	_build_panel.show_map(bool(map.get("interior", false)))
	t = lap("set_placed", t)
	_selection.refresh()
	t = lap("selection", t)
	_refresh_hover()
	t = lap("hover", t)
	_update_panels()
	if _people_panel != null:
		_people_panel.refresh()
	t = lap("panels", t)
	if publish_tools != null:
		publish_tools.schedule()
	lap("schedule", t)


## Draws the objects of `changes` (StudioWork._build) again, and only those, when the town on screen is the map they are
## relative to and the pick index follows it. {new_of_old, made} as the view settled them, or {} for a whole redraw.
func _drawn_change(map: Dictionary, changes: Dictionary) -> Dictionary:
	var view := map_view()
	if changes.is_empty() or int(changes.count) > MAX_CHANGED or not _pick.shows(view):
		return {}
	if not is_same(view.map, changes.base_map):
		return {}
	# Painted ground (the Land tab) is drawn by repainting the cells round the changed ones, before the objects.
	if not view.paint_ground(map):
		return {}
	if _overworld != null and _overworld.has_method("_draw_map_changed"):
		return _overworld.call("_draw_map_changed", changes.new_of_old, changes.made)
	return view.update_objects(map, changes.new_of_old, changes.made)


## Adds the time since `since` (Time.get_ticks_usec) to `stage` while `profiling` (tools/studio_place_bench.gd), and
## returns now, so the next stage can start from it.
func lap(stage: String, since: int) -> int:
	var now := Time.get_ticks_usec()
	if profiling:
		stage_usec[stage] = int(stage_usec.get(stage, 0)) + now - since
	return now


func _entrance_diagnostics(map: Dictionary) -> Array[Dictionary]:
	var id := String(map.get("id", ""))
	return StudioPeopleIndex.entrances(id, work.map_data(id), catalog().get("maps", {}))


## The draft's state and the history, in the top bar and the history list.
func _update_panels() -> void:
	if _top == null or work == null:
		return
	refresh_history_owner()
	# LEARN: the draft's "N changes" needs a diff of the whole map (about 8 ms on the town), and nothing waits on it, so
	# it is written on the next frame: an edit's own frame stays short, and several edits in one frame pay for it once.
	if not _draft_text_pending and is_inside_tree():
		_draft_text_pending = true
		get_tree().process_frame.connect(_show_draft_text, CONNECT_ONE_SHOT)
	elif not is_inside_tree():
		_show_draft_text()


## Header buttons and keyboard shortcuts must agree about which document owns Undo.
func refresh_history_owner() -> void:
	if _top == null or work == null:
		return
	var session := work.session()
	var history: StudioHistory = session.history if session != null else null
	if tab == "quests" and quest_panel != null:
		history = quests.history(quest_panel.edit_key())
	_top.set_history(history != null and history.can_undo(), history != null and history.can_redo())
	var labels: Array[String] = []
	if history != null:
		labels = history.labels()
	_tools.history.show_labels(labels)


func _show_draft_text() -> void:
	_draft_text_pending = false
	if _top == null or work == null:
		return
	var session := work.session()
	_top.set_draft_text(session.status() if session != null else StudioText.t("draft_none"))


## The handle of the one selected thing under `world` ({kind, sid}), or {} (Concept/v0.3/10, section 7.7).
func handle_at(world: Vector2) -> Dictionary:
	for handle: Dictionary in _handles():
		if (handle.rect as Rect2).has_point(world):
			return handle
	return {}


## The handles to draw: the one selected thing's, when it can be remade at another size.
func handle_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for handle: Dictionary in _handles():
		if String(handle.kind) != "start":
			rects.append(handle.rect)
	return rects


## The handles there are now: the map's start (while doors and warps show), the door of one selected building, and the
## footprint handles of one selected thing that can be remade at another size. {kind, rect, sid} each.
func _handles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not arrange.placing.is_empty() or arrange.area_select or land_tab() or (link != null and link.active):
		return out
	if overlay_options.get("doors", false):
		var start: Vector2i = current_map().get("start", Vector2i(-1, -1))
		out.append({"kind": "start", "rect": StudioOverlay.flag_rect(start), "sid": -1})
	var sids := selected_sids()
	if sids.size() != 1:
		return out
	var index := work.index_of(sids[0])
	var object := object_at(index)
	if object.is_empty():
		return out
	if String(object.get("kind", "")) == "building":
		out.append({"kind": "door", "rect": StudioOverlay.door_rect(object.get("door_cell", Vector2i.ZERO)), "sid": sids[0]})
	if remaking == null or not remaking.can_resize(work.raw(index)):
		return out
	for handle: Dictionary in remaking.handles_for(object, zoom()):
		handle["sid"] = sids[0]
		out.append(handle)
	return out


## The footprints of the things waiting for their remake, hatched by the overlay.
func _remaking_boxes(map: Dictionary) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	var waiting := remaking.waiting() if remaking != null else [] as Array[String]
	if waiting.is_empty():
		return boxes
	for object: Dictionary in map.get("objects", []):
		if String(object.get("art", "")) in waiting:
			var box := StudioPick.footprint(object)
			boxes.append(Rect2(Vector2(box.position) * TILE, Vector2(box.size) * TILE))
	return boxes


## The queue or a run changed: the tools column's button and line, and the hatching.
func _remakes_changed() -> void:
	if remaking == null or remaking.remakes == null:
		return
	_tools.show_remakes(remaking.waiting().size(), remaking.remakes.running, remaking.remakes.last_line)
	_place_panel.reload_assets(not remaking.remakes.running)
	if _build_panel != null:
		_build_panel.catalog.reload_assets(not remaking.remakes.running)
	if _overlay != null and not _shown_map.is_empty():
		_overlay.remaking_boxes = _remaking_boxes(_shown_map)
		_overlay.queue_redraw()


func _reviews_changed() -> void:
	var ids := asset_reviews.pending()
	_tools.show_updates(ids.size())
	_place_panel.set_updates(ids)
	if _build_panel != null:
		_build_panel.catalog.set_updates(ids)


func clear_held() -> void:
	_keys.held.clear()


func focus_object_size() -> void:
	_inspector.focus_size()


## The draft was saved (or changed): the top bar says how many changes and when.
func draft_changed() -> void:
	_update_panels()
	if publish_tools != null:
		publish_tools.schedule()


## A line in the status bar about the last edit; `problem` makes it a warning.
func say(text: String, problem := false) -> void:
	if _status != null:
		_status.show_message(text, problem)


# --- input --------------------------------------------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE or _modal_open():
		return
	if text_editor_focused():
		# LineEdit/TextEdit can consume Escape during GUI input, before `_unhandled_input` gets a chance to release focus.
		get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()


func _modal_open() -> bool:
	return (
		(asset_reviews != null and asset_reviews.modal_open())
		or (context_menu != null and context_menu.visible)
		or (_confirm != null and _confirm.visible)
		or (_move_confirm != null and _move_confirm.visible)
		or (publish_tools != null and publish_tools.modal_open())
		or (map_size != null and map_size.visible)
		or (area_dialog != null and area_dialog.visible)
		or (thing_dialog != null and thing_dialog.visible)
	)


func _unhandled_input(event: InputEvent) -> void:
	if asset_reviews != null and asset_reviews.modal_open():
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			asset_reviews.dismiss()
		get_viewport().set_input_as_handled()
		return
	if context_menu != null and context_menu.visible:
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			context_menu.dismiss()
		get_viewport().set_input_as_handled()
		return
	if _confirm != null and _confirm.visible:
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_delete()
		get_viewport().set_input_as_handled()
		return
	if _move_confirm != null and _move_confirm.visible:
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_move()
		get_viewport().set_input_as_handled()
		return
	if publish_tools != null and publish_tools.modal_open():
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			publish_tools.cancel_modal()
		get_viewport().set_input_as_handled()
		return
	if map_size != null and map_size.visible:
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			map_size.hide()
		get_viewport().set_input_as_handled()
		return
	if area_dialog != null and area_dialog.visible:
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			area_dialog.hide()
		get_viewport().set_input_as_handled()
		return
	if thing_dialog != null and thing_dialog.visible:
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			thing_dialog.hide()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if text_editor_focused():
		# Escape first closes text focus. A second Escape can then cancel the map gesture beneath it; never do both at once.
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()
		return
	if key.pressed and not key.echo and key.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		if key.keycode == KEY_F3 and not editing:
			toggle_debug()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_F2 and not editing and not _blocked():
			set_editing(true)
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_F1 and editing:
			set_editing(false)
			get_viewport().set_input_as_handled()
		return
	if editing and _keys.handle(key):
		get_viewport().set_input_as_handled()


## The town is mid-way through something (a door, a talk, the boots, a menu): not the moment to stop it.
func _blocked() -> bool:
	var idle: Variant = _parts.get("idle")
	return idle is Callable and not bool((idle as Callable).call())


func _world_input(event: InputEvent) -> void:
	if asset_reviews != null and asset_reviews.modal_open():
		_catcher.accept_event()
		return
	if context_menu.visible or _confirm.visible or _move_confirm.visible or map_size.visible or area_dialog.visible or thing_dialog.visible or link.menu_open() or (publish_tools != null and publish_tools.modal_open()) or (remaking != null and remaking.asking()):
		_catcher.accept_event()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			var from := _view_point(motion.position - motion.relative)
			var to := _view_point(motion.position)
			_camera.pan(pixel_view().to_world(from) - pixel_view().to_world(to))
		_set_cursor(motion.position)
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		match click.button_index:
			MOUSE_BUTTON_LEFT:
				if click.pressed:
					# The search box lets go of the keyboard when the town is clicked.
					get_viewport().gui_release_focus()
				_set_cursor(click.position)
				var free := click.alt_pressed or Input.is_key_pressed(KEY_ALT)
				if link.active:
					if click.pressed:
						link.click(_hover_cell, _catcher.get_screen_transform() * click.position)
				elif land_tab():
					if click.pressed:
						land.press(_hover_cell, click.shift_pressed)
					else:
						land.release()
				elif click.pressed:
					arrange.press(click.position, click.shift_pressed, free)
				else:
					arrange.release(free)
			MOUSE_BUTTON_RIGHT:
				if click.pressed and not land_tab() and not link.active:
					get_viewport().gui_release_focus()
					_set_cursor(click.position)
					_keys.held.clear()
					_dragging = false
					# LEARN: a popup's position is in its embedder's coordinates: canvas units when the root embeds
					# subwindows (the default), screen pixels when it is a native window. The window stretches
					# (canvas_items at 0.88), so the viewport's screen transform put the menu at the cursor times the
					# content scale. A Control's get_screen_transform goes through the popup base transform: right both ways.
					context_menu.open_at(_catcher.get_screen_transform() * click.position)
			MOUSE_BUTTON_MIDDLE:
				_dragging = click.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if click.pressed:
					_camera.step(1, _view_point(click.position))
			MOUSE_BUTTON_WHEEL_DOWN:
				if click.pressed:
					_camera.step(-1, _view_point(click.position))
		_catcher.accept_event()


## A point on the world Control as a point on the PixelView (they cover the same rectangle, but do not rely on it).
func _view_point(on_catcher: Vector2) -> Vector2:
	return pixel_view().get_global_transform().affine_inverse() * (_catcher.get_global_transform() * on_catcher)


# --- the cursor ---------------------------------------------------------------------------------------------------


func _set_cursor(on_catcher: Vector2) -> void:
	_cursor = on_catcher
	_refresh_hover()


## The cursor on the world Control, and the cell and the world point it is over (also off the map).
func cursor_screen() -> Vector2:
	return _cursor


func cursor_cell() -> Vector2i:
	return _hover_cell


func cursor_world() -> Vector2:
	return _hover_world


## Whether the cursor is over the town and on the map.
func cursor_over_map() -> bool:
	return _cursor_inside and OverworldMap.inside(current_map(), _hover_cell)


## Everything under the cursor, front-most first, as object indexes.
func stack() -> Array[int]:
	return _stack


## Screen pixels per art pixel.
func zoom() -> float:
	return _camera.screen_zoom()


## What the cursor is over, for the status bar, the label and Tab.
func _refresh_hover() -> void:
	_cursor_inside = _catcher != null and Rect2(Vector2.ZERO, _catcher.size).has_point(_cursor)
	_stack = []
	_overlay.hover_cell_shown = false
	_overlay.hover_label = ""
	var map := current_map()
	var world := pixel_view().to_world(_view_point(_cursor))
	var cell := Vector2i((world / TILE).floor())
	_hover_world = world
	_hover_cell = cell
	if not _cursor_inside:
		_status.show_cursor("", "", "")
		_overlay.queue_redraw()
		_tool_update()
		return
	_stack = _pick.at(world)
	var objects: Array = map.get("objects", [])
	if not _stack.is_empty():
		_overlay.hover_label = StudioPick.describe(objects[_stack[0]])
	_overlay.hover_point = world
	_overlay.hover_cell = cell
	_overlay.hover_cell_shown = OverworldMap.inside(map, cell)
	if OverworldMap.inside(map, cell):
		var here: Array[String] = []
		for index: int in _pick.objects_at_cell(cell).slice(0, 3):
			here.append(StudioPick.describe(objects[index]))
		_status.show_cursor(
			"%d, %d" % [cell.x, cell.y],
			OverworldMap.terrain_at(map, cell),
			", ".join(here) if not here.is_empty() else StudioText.t("nothing_here")
		)
	else:
		_status.show_cursor(StudioText.t("off_map"), "", "")
	_overlay.queue_redraw()
	_tool_update()


## The tab's tool follows the cursor: the Land tab's brush, or the arrange tool's ghost.
func _tool_update() -> void:
	if link != null and link.active:
		link.update()
	elif land_tab():
		land.update()
	else:
		arrange.update()


## For the arrange tool: look at what the cursor is over again.
func refresh_hover() -> void:
	_refresh_hover()


func cancel_for_modal() -> void:
	_keys.held.clear()
	arrange.cancel()


## Where the cursor would be in the world, in art pixels (for the tests and the screenshots).
func world_at(on_catcher: Vector2) -> Vector2:
	return pixel_view().to_world(_view_point(on_catcher))


func _process(delta: float) -> void:
	if debug != null:
		debug.poll(delta)
	work.tick(delta)
	if not editing:
		return
	var map := current_map()
	if not is_same(map, _shown_map):
		_load_map(map)
		_camera.map_changed(OverworldMap.size_of(map), player().position + Vector2(0, -TILE / 2.0))
	elif _pick.is_stale(map_view()):
		_pick.rebuild(map_view(), map)
	var moved := _pan(delta)
	var seen := [camera().position, camera().zoom, pixel_view().size]
	_camera.apply()
	_overlay.set_zoom(camera().zoom.x)
	_overlay.player_feet = player().position
	_status.show_zoom(_zoom_text())
	# The mouse itself, for when it moves over the panels (which keep the world from hearing it).
	var mouse := get_viewport().get_mouse_position()
	if mouse != _polled:
		_polled = mouse
		_cursor = _catcher.get_global_transform().affine_inverse() * mouse
		moved = true
	if moved or seen != [camera().position, camera().zoom, pixel_view().size]:
		_refresh_hover()


## Pans by the keys held; true when it moved.
func _pan(delta: float) -> bool:
	var way := Vector2.ZERO
	for code: int in _keys.held:
		if _keys.held[code]:
			way += StudioKeys.PAN_KEYS[code]
	if way == Vector2.ZERO:
		return false
	_camera.pan(way.normalized() * _camera.pan_speed(_keys.fast) * delta)
	return true


func _zoom_text() -> String:
	var zoom_now := _camera.screen_zoom()
	var text := "%dx" % roundi(zoom_now) if is_equal_approx(zoom_now, roundf(zoom_now)) else "%.2fx" % zoom_now
	return text + " " + StudioText.t("overview") if _camera.overview else text


# --- selecting ----------------------------------------------------------------------------------------------------


## Everything drawn or standing at `point` (world pixels), front-most first, as object indexes.
func pick_at(point: Vector2) -> Array[int]:
	return _pick.at(point)


## Selects the object at this index of the map's `objects`, or nothing with -1.
func select(index: int) -> void:
	_selection.select(index)


## Selects these objects (by session id).
func select_sids(sids: Array[int]) -> void:
	_selection.set_sids(sids)


func is_selected(index: int) -> bool:
	return _selection.has(index)


## Shift-click: adds the object to the selection, or takes it out when it is in.
func toggle_selected(index: int) -> void:
	_selection.toggle(index)


func selected_sids() -> Array[int]:
	return _selection.sids.duplicate()


## The map indexes of what is selected, in the order picked.
func selected_indexes() -> Array[int]:
	return _selection.indexes()


## Selects everything whose cells the rectangle (world pixels) touches; `add` keeps what was selected.
func select_in(rect: Rect2, add := false, filter := "all") -> void:
	_selection.select_in(rect, add, filter)


func sids_in_area(rect: Rect2, filter := "all") -> Array[int]:
	return _selection.in_area(rect, filter)


## The built object that is selected, or {}.
func selected_object() -> Dictionary:
	return object_at(selection)


## Tab: the next of the things stacked under the cursor.
func cycle() -> void:
	if _stack.is_empty():
		return
	select(_stack[(_stack.find(selection) + 1) % _stack.size()])


## Puts a point of the world in the middle of the view.
func focus(point: Vector2) -> void:
	_camera.focus(point)


# --- editing ------------------------------------------------------------------------------------------------------


## Moves the selection by whole cells; `free` (Alt) moves it even where it does not fit. {ok, reason}.
func move_selection(by: Vector2i, free := false) -> Dictionary:
	return work.move(selected_sids(), by, free)


## An arrow key with something selected: one cell (four with Shift).
func nudge(by: Vector2i, free := false) -> Dictionary:
	return move_selection(by, free)


## Ctrl+D. The copies are selected.
func duplicate_selection() -> void:
	var made := work.duplicate(selected_sids())
	if not made.is_empty():
		select_sids(made)


## Ctrl+V at the cursor's cell (or the player's, with the cursor off the town). The pasted things are selected.
func paste_at_cursor(free := false) -> void:
	var cell := _hover_cell if cursor_over_map() else player().cell
	var made := work.paste(cell, free)
	if not made.is_empty():
		select_sids(made)


## Del: deletes the selection, asking first about things that have an id.
func request_delete(targets: Array[int] = []) -> void:
	if not editing or work.session() == null or arrange.mode == "box":
		return
	var sids := selected_sids() if targets.is_empty() else targets.duplicate()
	for sid: int in sids:
		if work.index_of(sid) < 0:
			say(StudioText.t("context_stale"), true)
			return
	var result := work.delete(sids, false)
	if bool(result.get("needs_confirm", false)):
		_delete_pending = sids
		_delete_map = String(current_map().get("id", ""))
		_delete_session = work.session()
		_delete_history = _delete_session.history
		_confirm.dialog_text = StudioText.t("confirm_delete") % ", ".join(PackedStringArray(result.names))
		_confirm.popup_centered()


func _confirm_delete() -> void:
	var sids := _delete_pending.duplicate()
	var valid := editing and String(current_map().get("id", "")) == _delete_map and work.session() == _delete_session
	valid = valid and _delete_session != null and _delete_session.history == _delete_history
	for sid: int in sids:
		valid = valid and work.index_of(sid) >= 0
	_cancel_delete()
	if not valid:
		say(StudioText.t("context_stale"), true)
		return
	work.delete(sids, true)


func _cancel_delete() -> void:
	_delete_pending.clear()
	_delete_map = ""
	_delete_session = null
	_delete_history = null
	_confirm.hide()


## Deletes the selection; people and things with an id only when `confirmed`.
func delete_selection(confirmed := false) -> Dictionary:
	return work.delete(selected_sids(), confirmed)


## Place mode with a copy of the picture chosen from the list.
func start_place(art: String) -> void:
	place_panel().release_keyboard()
	link.cancel()
	var template := StudioAssets.template(art)
	if String(template.get("kind", "")) == "start" and StudioLink.FACINGS.has(_start_facing_choice):
		template["facing"] = _start_facing_choice
	arrange.start_placing(template, art)


func start_select() -> void:
	arrange.stop_placing()
	arrange.cancel()
	arrange.area_select = false
	_tools.show_object_tool(false, arrange.area_filter)
	_status.show_hint("hint")
	_selection.refresh()


func start_area_select() -> void:
	if tab != "objects":
		return
	_place_panel.release_keyboard()
	link.cancel()
	arrange.stop_placing()
	arrange.cancel()
	arrange.area_select = true
	_tools.show_object_tool(true, arrange.area_filter)
	_status.show_hint("area_hint")
	_selection.refresh()
	say(StudioText.t("area_help"), false)


func set_area_filter(filter: String) -> void:
	if filter not in ["all", "props", "trees"]:
		return
	arrange.area_filter = filter
	_tools.show_object_tool(arrange.area_select, filter)
	arrange.update()


## Place mode started or stopped: the catalog marks the card being placed ("" for none).
func placing_changed() -> void:
	if _place_panel != null:
		_place_panel.mark_placing(arrange.placing_card if arrange.placing_card != "" else String(arrange.placing.get("art", "")))
	if _build_panel != null:
		_build_panel.catalog.mark_placing(arrange.placing_card if arrange.placing_card != "" else String(arrange.placing.get("art", "")))
	if _people_panel != null:
		var person_id := String(arrange.placing.get("id", "")) if tab == "people" and String(arrange.placing.get("kind", "")) == "person" else ""
		_people_panel.mark_placing(person_id)
	if _tools != null:
		_tools.show_object_tool(arrange.area_select, arrange.area_filter)
	if _status != null and not land_tab():
		_status.show_hint("area_hint" if arrange.area_select else "hint")


## Something was put down from place mode: the catalog's Recent view lists it first.
func note_placed(art: String) -> void:
	if _place_panel != null and art != "":
		_place_panel.note_used(art)
		if _build_panel != null:
			_build_panel.catalog.note_used(art)


## E: place mode with a copy of the thing under the cursor (not its id).
func eyedrop() -> void:
	if _stack.is_empty():
		return
	var object := work.raw(_stack[0])
	if object.is_empty() or String(object.get("kind", "")) == "person":
		say("a person stands in one place", true)
		return
	var template := StudioWork.copy_of(object)
	template.erase("at")
	arrange.start_placing(template)


# --- the Land tab (S5) ----------------------------------------------------------------------------------------------


## Switches the edit tab: "objects" (select, move, place) or "land" (paint the ground, size the map). The Land tab
## lets go of the selection and hides the catalog, which come back with Objects.
func set_tab(which: String) -> void:
	var descriptor: Dictionary = StudioTopBar.DESCRIPTORS.get(which, {})
	if descriptor.is_empty() or not bool(descriptor.get("enabled", false)):
		return
	if which != tab:
		get_viewport().gui_release_focus()
		context_menu.dismiss()
		link.cancel()
		arrange.stop_placing()
		arrange.cancel()
		land.cancel()
		if not (descriptor.get("tools", []) as Array).has("area"):
			arrange.area_select = false
		if tab == "quests":
			quest_panel.close()
		if which in ["land", "quests"]:
			select(-1)
			if tab == "objects":
				_place_before_land = _place_on
				_restore_object_shelf = true
			elif tab in ["land", "quests"]:
				_restore_object_shelf = true
		elif which == "objects" and _restore_object_shelf:
			_place_on = _place_before_land
			_restore_object_shelf = false
		tab = which
		_route_workspace()
	_status.show_hint("land_hint" if tab == "land" else "area_hint" if arrange.area_select else "hint")
	_overlay.brush = Rect2()
	if tab == "land":
		land.fit_to_map()
		_show_land()
	if tab == "quests":
		quest_panel.open()
	if tab == "people":
		_people_panel.refresh()
	if tab in ["objects", "build"]:
		place_panel().refresh_browsing()
	_selection.refresh()
	refresh_history_owner()
	_refresh_hover()


## Whether the Land tab is the one in use while editing.
func land_tab() -> bool:
	return editing and tab == "land"


## Floor painting is the existing Land brush; rugs and furniture remain object placements in Build.
func paint_room_floor() -> void:
	if not bool(current_map().get("interior", false)):
		say(StudioText.t("build_floor_interior"), true)
		return
	set_tab("land")
	set_ground("floor")
	set_land_tool("brush")


## True while a text editor owns keyboard input; global Studio shortcuts must not consume its keys.
func text_editor_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit


## Selects a particular authored person location by map and current object index.
func locate_person(map_id: String, index: int, person_id: String, expected: Dictionary = {}) -> void:
	if not go_to_map(map_id):
		say(StudioText.f("people_map_missing", [map_id]), true)
		return
	var object := work.raw(index)
	if (
		String(object.get("kind", "")) != "person"
		or String(object.get("id", "")) != person_id
		or (not expected.is_empty() and object != expected)
	):
		_people_panel.refresh()
		say(StudioText.t("people_location_stale"), true)
		return
	var sid := work.sid_at(index)
	select_sids([sid])
	var cell := OverworldMap.cell_of(object.get("at", [0, 0]))
	focus((Vector2(cell) + Vector2(0.5, 0.5)) * TILE)
	_people_panel.refresh()


## Runs a People & Doors action on the entrance at the source map/index, after resolving that source afresh.
func people_entrance_action(action: String, map_id: String, index: int, expected: Dictionary = {}) -> void:
	if not go_to_map(map_id):
		say(StudioText.f("people_map_missing", [map_id]), true)
		return
	var object := work.raw(index)
	var kind := String(object.get("kind", ""))
	if kind not in ["building", "warp"] or (not expected.is_empty() and object != expected):
		_people_panel.refresh()
		say(StudioText.t("people_entrance_stale"), true)
		return
	var sid := work.sid_at(index)
	match action:
		"locate":
			select_sids([sid])
			var cell := StudioDoors.door_cell(object) if kind == "building" else OverworldMap.cell_of(object.get("at", [0, 0]))
			focus((Vector2(cell) + Vector2(0.5, 0.5)) * TILE)
		"link":
			link_door(sid)
		"make_room":
			make_interior(sid)
		"unlink":
			unlink_door(sid)
		"delete":
			select_sids([sid])
			request_delete([sid])
		"go":
			var target: Variant = object.get("to", {})
			if not target is Dictionary:
				say(StudioText.t("people_link_state_missing"), true)
				return
			var destination := String((target as Dictionary).get("map", ""))
			var arrival := OverworldMap.cell_of((target as Dictionary).get("at", [0, 0]))
			var state := StudioPeopleIndex.link_state(kind, target, catalog().get("maps", {}))
			if state != "valid":
				say(StudioText.t("people_link_state_" + state), true)
			else:
				var destination_data: Variant = catalog().maps.get(destination, {})
				var destination_is_room := destination_data is Dictionary and bool((destination_data as Dictionary).get("interior", false))
				if kind == "building" and destination_is_room:
					set_tab("objects")
				go_to_arrival(destination, arrival, String((target as Dictionary).get("facing", "down")))
	if _people_panel != null:
		_people_panel.refresh()


## Locate or reconnect an unlinked room draft. Both snapshots are checked again after navigation, before any link changes.
func people_room_draft_action(action: String, expected: Dictionary) -> void:
	var room_id := String(expected.get("id", ""))
	var expected_room: Variant = expected.get("source", {})
	if room_id == "" or not expected_room is Dictionary:
		_people_panel.refresh()
		say(StudioText.t("people_room_draft_stale"), true)
		return
	var latest := _unlinked_room_draft(room_id)
	if latest.is_empty() or latest.get("source", {}) != expected_room:
		_people_panel.refresh()
		say(StudioText.t("people_room_draft_stale"), true)
		return
	var room: Dictionary = expected_room
	var start := OverworldMap.cell_of(room.get("start", [0, 0]))
	if action == "locate":
		set_tab("objects")
		if not go_to_map(room_id, start):
			say(StudioText.t("people_room_draft_stale"), true)
		return
	if action != "reconnect":
		return
	var building_map := String(expected.get("building_map", ""))
	var building_index := int(expected.get("building_index", -1))
	var expected_building: Variant = expected.get("building", {})
	var return_target: Variant = expected.get("return", {})
	if (
		building_map == "" or building_index < 0 or not expected_building is Dictionary
		or not return_target is Dictionary or String((return_target as Dictionary).get("map", "")) != building_map
	):
		_people_panel.refresh()
		say(StudioText.t("people_room_reconnect_unavailable"), true)
		return
	set_tab("objects")
	if not go_to_map(building_map):
		_people_panel.refresh()
		say(StudioText.t("people_room_draft_stale"), true)
		return
	var building := work.raw(building_index)
	var fresh_room := work.map_data(room_id)
	var fresh_draft := _unlinked_room_draft(room_id)
	var return_cell := OverworldMap.cell_of((return_target as Dictionary).get("at", [0, 0]))
	if (
		building != expected_building or String(building.get("kind", "")) != "building" or building.has("to")
		or StudioDoors.front_of(building) != return_cell or fresh_room != expected_room
		or not work.is_new_map(room_id) or fresh_draft.is_empty()
		or fresh_draft.get("building_map", "") != building_map
		or int(fresh_draft.get("building_index", -1)) != building_index
		or fresh_draft.get("building", {}) != expected_building
	):
		_people_panel.refresh()
		say(StudioText.t("people_room_draft_stale"), true)
		return
	var sid := work.sid_at(building_index)
	if sid < 0 or not work.link(sid, StudioDoors.way_in(fresh_room)):
		_people_panel.refresh()
		say(StudioText.t("people_room_draft_stale"), true)
		return
	go_to_arrival(room_id, start, "up")
	say(StudioText.f("people_room_reconnected", [String(building.get("name", building.get("art", room_id)))]), false)


func _unlinked_room_draft(room_id: String) -> Dictionary:
	for room: Dictionary in StudioPeopleIndex.unlinked_room_drafts(work.map_documents(), work.new_map_ids()):
		if String(room.get("id", "")) == room_id:
			return room
	return {}


func set_start_facing(facing: String) -> void:
	if not StudioLink.FACINGS.has(facing):
		return
	_start_facing_choice = facing
	if _people_panel != null:
		_people_panel.refresh()


func start_facing_choice() -> String:
	return _start_facing_choice


func apply_start_facing() -> void:
	if not StudioLink.FACINGS.has(_start_facing_choice):
		return
	var chosen := _start_facing_choice
	if work.set_map_field("facing", chosen):
		say(StudioText.f("people_start_facing_set", [StudioText.t("link_face_" + chosen)]), false)
	_start_facing_choice = ""
	if _people_panel != null:
		_people_panel.refresh()


## Opens the existing in-game talk editor and remembers this NPC for a direct return action.
func edit_person_talk(person_id: String) -> void:
	var townsfolk: Dictionary = catalog().get("townsfolk", {})
	var talk_id := String(talk_ids().get(person_id, person_id))
	if not townsfolk.has(person_id) or not quests.talk_available(talk_id):
		say(StudioText.t("people_talk_missing"), true)
		return
	_remember_person(person_id)
	set_tab("quests")
	quest_panel.show_talk(talk_id)
	quest_panel.show_person_return(true)


func edit_person_quest(person_id: String, quest_id: String, step: int) -> void:
	if not quests.data("quests").has(quest_id):
		say(StudioText.t("people_quest_missing"), true)
		return
	_remember_person(person_id)
	set_tab("quests")
	quest_panel.show_quest(quest_id, step)
	quest_panel.show_person_return(true)


func _remember_person(person_id: String) -> void:
	var person_map := String(current_map().get("id", ""))
	var locations := StudioDoors.standing(work.map_documents(), person_id)
	var found_here := false
	for location: Dictionary in locations:
		if String(location.get("map", "")) == person_map:
			found_here = true
			break
	if not found_here and locations.size() == 1:
		person_map = String(locations[0].get("map", person_map))
	_person_return = {"map": person_map, "id": person_id, "placed": not locations.is_empty()}


func return_to_person() -> void:
	var target := _person_return.duplicate()
	_person_return.clear()
	quest_panel.show_person_return(false)
	set_tab("people")
	if target.is_empty() or not go_to_map(String(target.get("map", ""))):
		say(StudioText.t("people_return_missing"), true)
		return
	_people_panel.refresh()
	_people_panel.show_person(String(target.get("id", "")))
	var map_docs := work.map_documents()
	var matches := StudioDoors.standing(map_docs, String(target.get("id", ""))).filter(
		func(location: Dictionary) -> bool: return String(location.map) == String(target.map))
	if matches.size() == 1:
		var location: Dictionary = matches[0]
		var source_map: Dictionary = map_docs.get(String(location.map), {})
		var objects: Array = source_map.get("objects", [])
		var source: Dictionary = objects[int(location.index)] if int(location.index) >= 0 and int(location.index) < objects.size() else {}
		locate_person(String(location.map), int(location.index), String(target.id), source)
		return
	if matches.size() > 1:
		say(StudioText.f("people_duplicate_blocked", [StudioAssets.name_of(String(target.id))]), true)
	elif bool(target.get("placed", true)):
		say(StudioText.t("people_return_missing"), true)


func set_ground(kind: String) -> void:
	land.kind = kind
	_show_land()


func set_brush(size: int) -> void:
	land.size = size
	land.tool = "brush"
	_show_land()


func set_land_tool(tool: String) -> void:
	if tool in StudioLandTool.TOOLS:
		land.cancel()
		land.tool = tool
		_show_land()


## The Land tab's tools column shows what is chosen, and the brush under the cursor follows.
func _show_land() -> void:
	_land_panel.show_land(land.grounds(), land.kind, land.size, land.tool)
	land.update()


func open_map_size() -> void:
	land.cancel()
	map_size.open()


## Open the new-area form from the plus button beside the map picker.
func open_new_area() -> void:
	if link != null and link.active:
		return
	land.cancel()
	area_dialog.open()


## The map's cells moved by `shift` (a resize, its undo or its redo): the player stands where they stood, and the
## camera keeps looking at the same place.
func cells_moved(shift: Vector2i) -> void:
	var walker := player()
	if walker != null and is_instance_valid(walker):
		walker.place(walker.cell + shift, walker.facing)
	_camera.map_changed(OverworldMap.size_of(current_map()), _camera.centre + Vector2(shift * TILE))
	_refresh_hover()


# --- the developer inspector (S7) ------------------------------------------------------------------------------------


## F3 in Play: the developer inspector shows on the right of the town, or goes.
func toggle_debug() -> void:
	if debug == null or editing:
		return
	debug.set_shown(not debug.visible)
	_dock_debug()


## The town shrinks beside the inspector while it shows in Play, and the DRAFT tag moves out of its way.
func _dock_debug() -> void:
	if editing:
		return
	var shown := debug != null and debug.visible
	pixel_view().offset_right = -StudioDebug.WIDTH if shown else 0
	# The play HUD on the right (the quest card) moves aside with the town, and back.
	# A node stretched across the screen (the tracker, whose card sits in its top right) gives up its right edge; one
	# anchored to the right moves whole.
	for node: Variant in _parts.get("hud", []):
		if not node is Control or (node as Control).anchor_right < 1.0:
			continue
		var hud := node as Control
		if shown and not _hud_moved.has(hud):
			_hud_moved[hud] = [hud.offset_left, hud.offset_right]
			if hud.anchor_left >= 0.5:
				hud.offset_left -= StudioDebug.WIDTH
			hud.offset_right -= StudioDebug.WIDTH
		elif not shown and _hud_moved.has(hud):
			hud.offset_left = float(_hud_moved[hud][0])
			hud.offset_right = float(_hud_moved[hud][1])
			_hud_moved.erase(hud)
	_dock(_draft_tag, [1.0, 0.0, 1.0, 0.0], [-86 - (StudioDebug.WIDTH if shown else 0), 10, -12 - (StudioDebug.WIDTH if shown else 0), 34])


# --- people, doors and rooms (S6) -----------------------------------------------------------------------------------


## Something was put down from place mode (StudioArrange): a person, the start or a warp is placed once, so place mode
## stops; the person is selected, and a new warp goes straight on to Link warp. Someone who stands on another map is
## asked about first.
func after_place(template: Dictionary, result: Dictionary) -> void:
	var kind := String(template.get("kind", ""))
	if bool(result.get("needs_confirm", false)):
		_move_pending = {
			"id": String(template.get("id", "")),
			"facing": String(template.get("facing", "down")),
			"cell": OverworldMap.cell_of(result.get("cell", cursor_cell())),
			"map": String(current_map().get("id", "")),
			"source_map": String(result.get("map", "")),
			"source": result.get("source", {}),
		}
		var at := OverworldMap.cell_of(result.get("at", [0, 0]))
		_move_confirm.dialog_text = StudioText.f(
			"person_move_ask", [StudioAssets.name_of(_move_pending.id), map_title(String(result.map)), at.x, at.y]
		)
		_move_confirm.popup_centered()
		return
	if not bool(result.get("ok", false)) or not kind in ["person", "start", "warp"]:
		return
	arrange.stop_placing()
	if kind == "start":
		_start_facing_choice = ""
		if _people_panel != null:
			_people_panel.refresh()
	var sid := int(result.get("sid", -1))
	if sid > 0:
		select_sids([sid])
	if kind == "warp" and sid > 0:
		link.begin(sid, true)


func _confirm_move() -> void:
	var pending := _move_pending.duplicate()
	_cancel_move(false)
	if pending.is_empty() or String(current_map().get("id", "")) != String(pending.map):
		say(StudioText.t("context_stale"), true)
		return
	var placed := work.place_person(
		String(pending.id), pending.cell, String(pending.facing), true, true,
		pending.get("source", {}), String(pending.get("source_map", ""))
	)
	if bool(placed.ok):
		arrange.stop_placing()
		select_sids([int(placed.sid)])
	else:
		var reason := String(placed.get("reason", ""))
		say(reason if reason != "" else StudioText.t("context_stale"), true)
		_people_panel.refresh()


func _cancel_move(cancelled := true) -> void:
	var was_pending := not _move_pending.is_empty()
	_move_pending = {}
	if _move_confirm != null:
		_move_confirm.hide()
	if was_pending:
		arrange.stop_placing()
		if cancelled:
			say(StudioText.t("people_move_cancelled"), false)


## Make interior for a building (the inspector's button): its room is made and linked both ways, and shown, to furnish.
func make_interior(sid: int) -> bool:
	var made := work.make_interior(sid)
	if not bool(made.get("ok", false)):
		return false
	var room := String(made.room_id)
	go_to_map(room)
	say(StudioText.t("room_made") % map_title(room), false)
	return true


## Link door or Link warp (the inspector's button).
func link_door(sid: int) -> void:
	if link.active:
		return
	arrange.cancel()
	land.cancel()
	arrange.stop_placing()
	link.begin(sid)


func unlink_door(sid: int) -> void:
	if work.unlink(sid):
		say(StudioText.t("unlinked"), false)
