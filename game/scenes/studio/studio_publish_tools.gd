class_name StudioPublishTools
extends Control
## The Publish loop mounted on the Studio: live problems, review, conflict choices, revert and reload.
## Passive checks have their own service so they cannot authorize a Keep choice in an older modal review.

var publisher := StudioPublish.new()
var review_data: Dictionary = {}
var dialog: StudioPublishDialog
var problems_panel: StudioProblemsPanel
var last_result: Dictionary = {}

## How long after the newest change the draft is written, on a worker thread. The timed save of StudioWork (two seconds)
## then finds nothing left to write.
const DRAFT_AFTER := 1.0
## How long after the newest change the live check starts.
const CHECK_AFTER := 0.2

var _studio: StudioMode
var _top: StudioTopBar
var _live := StudioPublish.new()
var _check := StudioLiveCheck.new(_live)
var _problems_window: Window
var _revert_dialog: ConfirmationDialog
var _revert_session: StudioSession
var _pending := -1.0
var _draft_in := -1.0
var _landing := false


func _init(studio: StudioMode = null, top: StudioTopBar = null) -> void:
	_studio = studio
	_top = top
	name = "PublishTools"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if _studio == null:
		return
	for service: StudioPublish in [publisher, _live]:
		service.content_root = _studio.content_root()
		service.drafts_dir = StudioMode.drafts_dir
	dialog = StudioPublishDialog.new()
	dialog.publish_requested.connect(confirm_publish)
	dialog.rebase_requested.connect(rebase)
	dialog.jump_requested.connect(jump)
	add_child(dialog)
	_problems_window = Window.new()
	_problems_window.title = StudioText.t("problems")
	_problems_window.size = Vector2i(760, 400)
	_problems_window.transient = true
	_problems_window.exclusive = true
	_problems_window.visible = false
	_problems_window.close_requested.connect(_problems_window.hide)
	add_child(_problems_window)
	problems_panel = StudioProblemsPanel.new()
	problems_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	problems_panel.jump_requested.connect(jump)
	problems_panel.close_requested.connect(_problems_window.hide)
	_problems_window.add_child(problems_panel)
	_revert_dialog = ConfirmationDialog.new()
	_revert_dialog.title = StudioText.t("revert_title")
	_revert_dialog.dialog_text = StudioText.t("revert_confirm")
	_revert_dialog.confirmed.connect(confirm_revert)
	_revert_dialog.canceled.connect(func() -> void: _revert_session = null)
	add_child(_revert_dialog)
	_top.publish_pressed.connect(open_publish)
	_top.revert_pressed.connect(request_revert)
	_studio.status_bar().problems_pressed.connect(open_problems)
	_top.set_publish_state(false, false)


func _exit_tree() -> void:
	# A task still in the pool is collected here, while this node can: a freed RefCounted cannot wait for its own.
	_check.discard()
	if _studio != null and _studio.work != null:
		settle_drafts()


## Something changed: the live check runs once things have been quiet for a moment, and so does the draft write.
## The remakes not made yet: a thing or entry waiting for one reviews as a warning (StudioPublish.remakes_waiting).
func set_remakes_waiting(ids: Array[String]) -> void:
	for service: StudioPublish in [publisher, _live]:
		service.remakes_waiting = ids.duplicate()
	schedule()


func schedule() -> void:
	if _landing:
		return
	_pending = CHECK_AFTER
	_draft_in = DRAFT_AFTER
	_check.invalidate()


## Whether no check is waiting to start or running (the status bar shows the newest answer).
func idle() -> bool:
	return _pending < 0.0 and not _check.busy()


func _process(delta: float) -> void:
	if _studio == null or _studio.work == null:
		return
	_poll_check()
	_poll_drafts(delta)
	if not _studio.editing or _pending < 0.0:
		return
	_pending = maxf(_pending - delta, 0.0)
	if _pending <= 0.0 and not _check.busy():
		_pending = -1.0
		_start_check()


## The check on a worker thread over a snapshot of the sessions. The frame only pays for the snapshot.
func _start_check() -> void:
	var current := _studio.work.session()
	_check.start(_studio.work.sessions(), current.map_id if current != null else "")


func _poll_check() -> void:
	var done := _check.poll()
	# An answer older than the newest change is dropped: schedule() has already queued the check that replaces it.
	if not done.is_empty() and bool(done.fresh):
		_apply(done.report, int(done.current_changes) > 0)


## Writes the drafts of the sessions with edits on worker threads, and tells the Studio when one has landed.
func _poll_drafts(delta: float) -> void:
	var sessions := _studio.work.sessions()
	var landed := false
	var open_edits := false
	for id: String in sessions:
		var session: StudioSession = sessions[id]
		landed = session.poll_write() or landed
	if _draft_in >= 0.0 and _studio.editing:
		_draft_in -= delta
		if _draft_in <= 0.0:
			_draft_in = -1.0
			for id: String in sessions:
				var session: StudioSession = sessions[id]
				if session.unsaved:
					session.save_later()
	for id: String in sessions:
		var session: StudioSession = sessions[id]
		open_edits = open_edits or session.unsaved
	if landed:
		# The docs are the ones already checked: let the top bar say "saved", but do not start another check.
		_landing = true
		_studio.draft_changed()
		_landing = false
		if open_edits and _draft_in < 0.0:
			_draft_in = DRAFT_AFTER


## Waits for every draft write in flight, so a later write, a discard or a publish cannot be overtaken by one.
func settle_drafts() -> void:
	for id: String in _studio.work.sessions():
		(_studio.work.sessions()[id] as StudioSession).settle()


## The synchronous check: the answer is in the status bar when this returns. Used when someone asked (Problems, Publish,
## Revert, a rebase); the check after a change runs on a worker thread instead.
func refresh_now() -> Dictionary:
	_pending = -1.0
	_check.invalidate()
	var report := _live.review(_studio.work.sessions())
	var current := _studio.work.session()
	_apply(report, current != null and current.changes() > 0)
	return review_data


func _apply(report: Dictionary, revertable: bool) -> void:
	review_data = report
	var problems: Array[Dictionary] = []
	problems.assign(review_data.problems)
	if problems != problems_panel.problems:
		problems_panel.show_problems(problems)
	_studio.status_bar().show_problems(int(review_data.error_count), int(review_data.warning_count))
	_top.set_publish_state(not (review_data.changes as Array).is_empty(), revertable)


func open_problems() -> void:
	_studio.cancel_for_modal()
	refresh_now()
	_problems_window.popup_centered()


func open_publish() -> void:
	_studio.cancel_for_modal()
	_studio.work.flush()
	dialog.show_review(publisher.review(_studio.work.sessions()))


func confirm_publish(accept_warnings: bool, keep_paths: Array[String]) -> Dictionary:
	settle_drafts()
	last_result = publisher.publish(_studio.work.sessions(), accept_warnings, keep_paths)
	if not bool(last_result.ok):
		dialog.render_review(publisher.review(_studio.work.sessions()))
		dialog.show_failure(String(last_result.error))
		refresh_now()
		return last_result
	_studio.work.sessions().merge(last_result.sessions, true)
	var published_paths: Array[String] = []
	published_paths.assign(last_result.get("files", []))
	_studio.work.published(published_paths)
	# A clean session may have been opened before an external edit. Reload those from today's files too.
	for id: String in _studio.work.sessions():
		var session: StudioSession = _studio.work.sessions()[id]
		if session.changes() == 0:
			publisher.revert(session)
	if _studio.play_draft:
		_studio.set_play_draft(false)
	var reload_content: Callable = _studio.parts().get("reload_content", Callable())
	if reload_content.is_valid():
		reload_content.call()
	_studio.clear_map_names()
	_studio.work.open(String(_studio.current_map().get("id", "")))
	_studio.work.refresh()
	_studio.select(-1)
	dialog.hide()
	refresh_now()
	var names: Array[String] = []
	for path: String in last_result.files:
		names.append(path.get_file())
	_studio.say(StudioText.t("published") % ", ".join(names))
	if not (last_result.get("cleanup_errors", []) as Array).is_empty():
		_studio.say(StudioText.t("published_cleanup") % ", ".join(last_result.cleanup_errors), true)
	return last_result


func rebase(id: String) -> Dictionary:
	settle_drafts()
	var report_sessions: Dictionary = dialog.report.get("sessions", {})
	var session: StudioSession = report_sessions.get(id)
	last_result = publisher.rebase(session)
	if bool(last_result.ok):
		_studio.work.sessions()[id] = session
		if _studio.work.session() == session:
			_studio.clear_map_names()
			_studio.work.refresh()
		dialog.render_review(publisher.review(_studio.work.sessions()))
	else:
		var messages: Array[String] = []
		for conflict: Dictionary in last_result.get("conflicts", []):
			messages.append("%s · #%s · %s: %s\n  draft %s · disk %s" % [
				String(conflict.get("file", "")).get_file(), str(conflict.get("sid", "map")),
				String(conflict.get("field", "")), String(conflict.get("message", "")),
				JSON.stringify(conflict.get("draft")), JSON.stringify(conflict.get("current")),
			])
		dialog.show_failure(String(last_result.get("error", "\n".join(messages))))
	refresh_now()
	return last_result


func request_revert() -> void:
	_studio.cancel_for_modal()
	_revert_session = _studio.work.session()
	if _revert_session != null and _revert_session.changes() > 0:
		var impact := _studio.work.revert_impact(_revert_session)
		_revert_dialog.dialog_text = String(impact.get("message", StudioText.t("revert_confirm")))
		_revert_dialog.get_ok_button().disabled = not bool(impact.get("can_revert", false))
		_revert_dialog.popup_centered(Vector2i(500, 160))


func modal_open() -> bool:
	return dialog != null and (dialog.visible or _problems_window.visible or _revert_dialog.visible)


func cancel_modal() -> void:
	dialog.hide()
	_problems_window.hide()
	_revert_dialog.hide()
	_revert_dialog.dialog_text = StudioText.t("revert_confirm")
	_revert_dialog.get_ok_button().disabled = false
	_revert_session = null


func confirm_revert() -> Dictionary:
	settle_drafts()
	var reverted := _revert_session
	var coordinated := _studio.work.revert_coordinated_action(_revert_session)
	if not bool(coordinated.get("ok", false)):
		last_result = {"ok": false, "error": String(coordinated.get("error", "The coordinated action could not be reverted."))}
		_revert_session = null
		_revert_dialog.hide()
		_studio.say(String(last_result.error), true)
		refresh_now()
		return last_result
	last_result = publisher.revert(_revert_session)
	_revert_session = null
	_revert_dialog.hide()
	_revert_dialog.dialog_text = StudioText.t("revert_confirm")
	_revert_dialog.get_ok_button().disabled = false
	if bool(last_result.ok) and bool(last_result.get("removed", false)):
		# A map made here and never published is gone: back to a map whose door led there, or to the start map.
		var gone := reverted.map_id
		var back := _way_back(gone)
		_studio.arrange.stop_placing()
		_studio.arrange.cancel()
		_studio.select(-1)
		# Forgotten first: going to another map saves every draft, and the room's must not be written again.
		_studio.work.forget_map(gone)
		_studio.go_to_map(String(back.map), back.cell)
		_studio.work.open(String(back.map))
		_studio.work.refresh()
		_studio.say(StudioText.t("reverted_new_map") % gone)
	elif bool(last_result.ok):
		_studio.arrange.stop_placing()
		_studio.arrange.cancel()
		_studio.select(-1)
		_studio.work.refresh()
		_studio.say(StudioText.t("reverted"))
	else:
		_studio.say(String(last_result.error), true)
	refresh_now()
	return last_result


func jump(id: String, cell: Vector2i, sid: int) -> void:
	if not _studio.catalog().maps.has(id):
		return
	dialog.hide()
	_problems_window.hide()
	_studio.work.flush()
	if String(_studio.current_map().get("id", "")) != id:
		var show_map: Callable = _studio.parts().get("show_map", Callable())
		if not show_map.is_valid():
			return
		show_map.call(id)
		_studio.work.open(id)
		_studio._load_map(_studio.current_map())
		_studio.studio_camera().map_changed(OverworldMap.size_of(_studio.current_map()), Vector2(cell) * OverworldScale.TILE)
	if sid > 0:
		_studio.select_sids([sid])
	if cell != Vector2i(-1, -1):
		_studio.focus((Vector2(cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE)
	schedule()


## Where to go when the map `gone` is reverted away: the first other map with a door into it, at that door, else the
## overworld's start map at its start. {map, cell}.
func _way_back(gone: String) -> Dictionary:
	var ids: Array[String] = []
	ids.assign(_studio.catalog().maps.keys())
	ids.sort()
	for id: String in ids:
		if id == gone:
			continue
		var map: Dictionary = _studio.catalog().maps[id]
		for cell: Vector2i in map.get("warps", {}):
			if String((map.warps[cell] as Dictionary).map) == gone:
				return {"map": id, "cell": cell}
	var gone_map: Variant = _studio.catalog().maps.get(gone, {})
	if gone_map is Dictionary:
		var objects: Variant = (gone_map as Dictionary).get("objects", [])
		if objects is Array:
			for value: Variant in objects:
				if not value is Dictionary or String((value as Dictionary).get("kind", "")) != "warp":
					continue
				var target: Variant = (value as Dictionary).get("to", {})
				if target is Dictionary and String((target as Dictionary).get("map", "")) != gone:
					return {
						"map": String((target as Dictionary).get("map", "")),
						"cell": OverworldMap.cell_of((target as Dictionary).get("at", [0, 0])),
					}
	return {"map": OverworldScreen.START_MAP, "cell": Vector2i(-1, -1)}
