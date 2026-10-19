class_name StudioContextMenu
extends PopupMenu
## Actions for the placed objects under a right click. Session ids and the map are captured when this opens;
## changing the selection cannot redirect an action, and closing or replacing the history invalidates it.

enum Action { COPY, DUPLICATE, FLIP, DELETE, PASTE, RESIZE, REVIEW }

var _studio: StudioMode
var _map_id := ""
var _session: StudioSession
var _history: StudioHistory
var _sids: Array[int] = []
var _paste_cell := Vector2i.ZERO
var _paste_objects: Array[Dictionary] = []
var _armed := false


func _init(studio: StudioMode = null) -> void:
	_studio = studio
	name = "ObjectContextMenu"
	# The action controls closing, so popup_hide cannot clear its captured targets before id_pressed runs.
	hide_on_item_selection = false
	id_pressed.connect(activate)
	popup_hide.connect(_forget)
	add_theme_font_size_override("font_size", StudioStyle.SMALL)
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(8, 6)))


## The cursor has already been refreshed from the right click on the world Control. `screen_point` is in the popup
## base's coordinates (Control.get_screen_transform), which is what PopupMenu.popup expects, embedded or not.
func open_at(screen_point: Vector2) -> bool:
	dismiss()
	if _studio == null or not _studio.editing or _studio.work.session() == null:
		return false
	_studio.start_select()
	var stack := _studio.stack()
	if not stack.is_empty():
		if not _studio.is_selected(stack[0]):
			_studio.select(stack[0])
		_sids = _studio.selected_sids()
	elif _studio.cursor_over_map() and not StudioWork.clipboard.is_empty():
		_paste_cell = _studio.cursor_cell()
		_paste_objects = StudioWork.clipboard.duplicate(true)
	else:
		return false
	_map_id = String(_studio.current_map().get("id", ""))
	_session = _studio.work.session()
	_history = _session.history
	clear()
	if _sids.is_empty():
		add_item(StudioText.t("context_paste"), Action.PASTE)
	else:
		var copyable := false
		var flippable := true
		for sid: int in _sids:
			var object := _studio.work.doc().object_of_sid(sid)
			copyable = copyable or String(object.get("kind", "")) != "person"
			flippable = flippable and StudioAssets.can_flip(object)
		add_item(StudioText.t("context_copy"), Action.COPY)
		set_item_disabled(get_item_index(Action.COPY), not copyable)
		add_item(StudioText.t("context_duplicate"), Action.DUPLICATE)
		set_item_disabled(get_item_index(Action.DUPLICATE), not copyable)
		if flippable:
			add_item(StudioText.t("context_flip"), Action.FLIP)
		if _sids.size() == 1:
			var object := _studio.work.doc().object_of_sid(_sids[0])
			if String(object.get("kind", "")) in ["building", "prop"]:
				add_item(StudioText.t("context_resize"), Action.RESIZE)
		var can_review := false
		for sid: int in _sids:
			var object := _studio.work.doc().object_of_sid(sid)
			can_review = can_review or String(object.get("kind", "")) in ["building", "prop"]
		if can_review:
			add_item(StudioText.t("review_flag"), Action.REVIEW)
		add_separator()
		add_item(StudioText.t("context_delete"), Action.DELETE)
	_armed = true
	popup(Rect2i(Vector2i(screen_point), Vector2i(180, 0)))
	return true


## Menu events are valid only while this exact popup remains open on the captured map and history.
func activate(action: int) -> bool:
	var index := get_item_index(action)
	if not _armed or not visible or index < 0 or is_item_disabled(index):
		return false
	if not _valid_targets():
		dismiss()
		_studio.say(StudioText.t("context_stale"), true)
		return false
	var sids := _sids.duplicate()
	var cell := _paste_cell
	var copied := _paste_objects.duplicate(true)
	dismiss()
	match action:
		Action.COPY:
			_studio.work.copy(sids)
		Action.DUPLICATE:
			var made := _studio.work.duplicate(sids)
			if not made.is_empty():
				_studio.select_sids(made)
		Action.FLIP:
			_studio.work.flip(sids)
		Action.DELETE:
			_studio.request_delete(sids)
		Action.RESIZE:
			_studio.focus_object_size()
		Action.REVIEW:
			for sid: int in sids:
				var object := _studio.work.doc().object_of_sid(sid)
				_studio.asset_reviews.flag(String(object.get("art", "")))
			_studio.say(StudioText.t("review_saved"), false)
		Action.PASTE:
			var previous := StudioWork.clipboard
			StudioWork.clipboard = copied
			var made := _studio.work.paste(cell)
			StudioWork.clipboard = previous
			if not made.is_empty():
				_studio.select_sids(made)
	return true


func dismiss() -> void:
	hide()
	_forget()


func _valid_targets() -> bool:
	if not _studio.editing or String(_studio.current_map().get("id", "")) != _map_id:
		return false
	if _studio.work.session() != _session or _session.history != _history:
		return false
	for sid: int in _sids:
		if _studio.work.index_of(sid) < 0:
			return false
	return true


func _forget() -> void:
	_armed = false
	_sids.clear()
	_paste_objects.clear()
	_session = null
	_history = null
	_map_id = ""
