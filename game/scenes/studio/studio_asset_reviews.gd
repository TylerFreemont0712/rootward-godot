class_name StudioAssetReviews
extends Node
## A persistent art review list, opened from catalog cards or placed instances. The real remake queue accepts a new
## prompt variant only when its source has a restylable blockout. Imported artwork keeps its brief for later work.

signal changed

enum Action { FLAG, EDIT, RESOLVE }

var path := ""
var records: Dictionary = {}
var menu: PopupMenu
var dialog: Window

var _studio: StudioMode
var _menu_art := ""
var _art := ""
var _ids: Array[String] = []
var _list: ItemList
var _preview: StudioAssetPreview
var _notes: TextEdit
var _prompt: LineEdit
var _help: Label
var _generate: Button
var _save: Button
var _resolve: Button


func _init(studio: StudioMode = null) -> void:
	_studio = studio
	name = "AssetReviews"


func _ready() -> void:
	if path == "":
		path = StudioMode.drafts_dir.trim_suffix("/").get_base_dir().path_join("asset_updates.json")
	load_reviews()
	menu = PopupMenu.new()
	menu.name = "AssetReviewMenu"
	menu.hide_on_item_selection = false
	menu.id_pressed.connect(_activate)
	menu.popup_hide.connect(func() -> void: _menu_art = "")
	add_child(menu)
	_build_dialog()


func load_reviews() -> void:
	var data: Variant = StudioFiles.read_record(path)
	if data is Dictionary and data.get("assets") is Dictionary:
		records = data.assets.duplicate(true)


func pending() -> Array[String]:
	return StudioAssetReview.pending(records)


func _persist(next: Dictionary) -> bool:
	if not StudioFiles.write_record(path, {"version": 1, "assets": next}):
		if _studio != null:
			_studio.say(StudioText.t("review_save_failed"), true)
		return false
	records = next
	changed.emit()
	return true


func flag(art: String) -> bool:
	var entry := StudioAssets.entry_of(art)
	if not String(entry.get("kind", "")) in StudioAssets.KINDS:
		return false
	var details := {"name": String(entry.get("name", art)), "kind": String(entry.kind), "map": "", "at": null}
	if _studio != null:
		var object := _studio.object_at(_studio.selection)
		if String(object.get("art", "")) != art:
			for placed: Dictionary in _studio.current_map().get("objects", []):
				if String(placed.get("art", "")) == art:
					object = placed
					break
		if String(object.get("art", "")) == art:
			details["map"] = String(_studio.current_map().get("id", ""))
			var at := OverworldMap.cell_of(object.get("at", [0, 0]))
			details["at"] = [at.x, at.y]
	return _persist(StudioAssetReview.put(records, art, details, Time.get_datetime_string_from_system()))


func resolve(art: String) -> bool:
	return _persist(StudioAssetReview.resolve(records, art, Time.get_datetime_string_from_system()))


func open_menu(art: String, point: Vector2) -> void:
	if not String(StudioAssets.entry_of(art).get("kind", "")) in StudioAssets.KINDS:
		return
	if _studio != null:
		_studio.clear_held()
	_menu_art = art
	menu.clear()
	if art in pending():
		menu.add_item(StudioText.t("review_edit"), Action.EDIT)
		menu.add_item(StudioText.t("review_resolve"), Action.RESOLVE)
	else:
		menu.add_item(StudioText.t("review_flag"), Action.FLAG)
	menu.popup(Rect2i(Vector2i(point), Vector2i(230, 0)))


func _activate(action: int) -> void:
	if not menu.visible or menu.get_item_index(action) < 0:
		return
	var art := _menu_art
	menu.hide()
	match action:
		Action.FLAG:
			if flag(art):
				_studio.say(StudioText.t("review_flagged") % StudioAssets.name_of(art), false)
		Action.EDIT:
			open_reviews(art)
		Action.RESOLVE:
			resolve(art)


func modal_open() -> bool:
	return (menu != null and menu.visible) or (dialog != null and dialog.visible)


func dismiss() -> void:
	menu.hide()
	dialog.hide()


func _build_dialog() -> void:
	dialog = Window.new()
	dialog.name = "AssetUpdateList"
	dialog.title = StudioText.t("review_title")
	dialog.visible = false
	dialog.borderless = true
	dialog.unresizable = true
	dialog.transient = true
	dialog.exclusive = true
	dialog.size = Vector2i(960, 780)
	dialog.theme = UiTheme.shared()
	dialog.close_requested.connect(func() -> void: dialog.hide())
	dialog.window_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
			dialog.set_input_as_handled()
			dialog.hide()
	)
	add_child(dialog)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StudioStyle.box(Vector2(18, 14)))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(panel)
	var body := Ui.vbox([], 12)
	panel.add_child(body)
	body.add_child(Ui.label(StudioText.t("review_title"), "Heading"))
	body.add_child(Ui.label(StudioText.t("review_intro"), "Muted", true))
	_list = ItemList.new()
	_list.name = "ReviewList"
	_list.custom_minimum_size = Vector2(240, 420)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int) -> void: _show(_ids[index]))
	_preview = StudioAssetPreview.new()
	_preview.custom_minimum_size.x = 400
	_notes = TextEdit.new()
	_notes.name = "ReviewNotes"
	_notes.placeholder_text = StudioText.t("review_notes_hint")
	_notes.custom_minimum_size = Vector2(480, 110)
	_notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt = LineEdit.new()
	_prompt.name = "ReplacementPrompt"
	_prompt.max_length = 160
	_prompt.placeholder_text = StudioText.t("review_prompt_hint")
	_help = Ui.label("", "Muted", true)
	_help.custom_minimum_size.x = 480
	_save = StudioStyle.button(StudioText.t("review_save"), _save_fields)
	_save.name = "SaveReview"
	_resolve = StudioStyle.button(StudioText.t("review_resolve"), _resolve_current)
	_resolve.name = "ResolveReview"
	_generate = StudioStyle.button(StudioText.t("review_queue"), _queue_replacement)
	_generate.name = "QueueReplacement"
	var details := Ui.vbox([
		_preview, Ui.label(StudioText.t("review_notes"), "Subheading"), _notes,
		Ui.label(StudioText.t("review_prompt"), "Subheading"), _prompt, _help,
		Ui.flow([_save, _resolve, _generate], 8),
	], 8)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(Ui.hbox([_list, details], 16))
	body.add_child(Ui.hbox([Ui.spacer(), StudioStyle.button(StudioText.t("close"), func() -> void: dialog.hide())], 8))
	_prompt.text_changed.connect(func(_value: String) -> void: _refresh_generate())


func open_reviews(art := "") -> void:
	if _studio != null:
		_studio.start_select()
		_studio.clear_held()
	_refresh_list(art)
	dialog.popup_centered(Vector2i(960, 780))


func _refresh_list(prefer := "") -> void:
	_ids = pending()
	_list.clear()
	for art: String in _ids:
		_list.add_item(String(records[art].get("name", art)) + "  ·  " + art)
	var index := _ids.find(prefer)
	if index < 0 and not _ids.is_empty():
		index = 0
	if index >= 0:
		_list.select(index)
		_show(_ids[index])
	else:
		_art = ""
		_preview.clear_preview()
		_notes.text = ""
		_prompt.text = ""
		_help.text = StudioText.t("review_empty")
		_refresh_generate()
	_save.disabled = _art == ""
	_resolve.disabled = _art == ""


func _show(art: String) -> void:
	_art = art
	_preview.preview_asset(art)
	var record: Dictionary = records.get(art, {})
	_notes.text = String(record.get("notes", ""))
	_prompt.text = String(record.get("prompt", ""))
	_help.text = StudioText.t("review_pipeline" if _can_generate(art) else "review_later")
	_refresh_generate()


func _can_generate(art: String) -> bool:
	var spec := StudioRemaking.spec_of(art)
	return StudioRemake.can_remake(spec) and bool(spec.get("restyle", true))


func _refresh_generate() -> void:
	if _generate == null:
		return
	var words := _prompt.text.strip_edges().split(" ", false)
	_generate.disabled = _art == "" or not _can_generate(_art) or words.size() < 3
	if _studio != null and _studio.remaking != null:
		_generate.disabled = _generate.disabled or _studio.remaking.remakes.running


func _save_fields() -> bool:
	if _art == "":
		return false
	var next := StudioAssetReview.put(records, _art, {"notes": _notes.text, "prompt": _prompt.text.strip_edges()}, Time.get_datetime_string_from_system())
	var ok := _persist(next)
	if ok and _studio != null:
		_studio.say(StudioText.t("review_saved"), false)
	return ok


func _resolve_current() -> void:
	if _save_fields() and resolve(_art):
		_refresh_list()


func _queue_replacement() -> void:
	if _generate.disabled or not _save_fields():
		return
	var result := queue_replacement(_art, _prompt.text.strip_edges())
	_help.text = StudioText.t("review_queued") % String(result.get("id", "")) if result.ok else String(result.error)


## Reuse the real pipeline bridge with a fresh spec and catalog variant. Imported/canvas-authored assets stay listed.
func queue_replacement(art: String, prompt: String) -> Dictionary:
	if _studio == null or not _can_generate(art):
		return {"ok": false, "error": StudioText.t("review_later")}
	if prompt.strip_edges().split(" ", false).size() < 3 or prompt.length() > 160:
		return {"ok": false, "error": StudioText.t("review_prompt_hint")}
	var remaking := _studio.remaking
	if remaking.remakes.running:
		return {"ok": false, "error": StudioText.t("remake_running")}
	var id := StudioAssetReview.replacement_id(art, prompt)
	var spec := StudioRemaking.spec_of(art).duplicate(true)
	spec["id"] = id
	spec["what"] = prompt.strip_edges()
	var entry := remaking.catalog.entry(art)
	var replacement := StudioRemake.family_entry(art, entry)
	replacement["name"] = String(entry.get("name", art)) + " (update)"
	replacement["variant"] = "Updated art"
	remaking.catalog.set_entry(art, StudioRemake.family_entry(art, entry))
	remaking.catalog.set_entry(id, replacement)
	if not remaking.catalog.save():
		return {"ok": false, "error": StudioText.t("review_save_failed")}
	remaking._show_draft()
	var size := OverworldMap.cell_of(spec.get("footprint", [1, 1]))
	remaking.remakes.request(id, art, size, StudioRemake.spec_text(spec, art))
	remaking._register_stand_ins()
	remaking.changed.emit()
	var next := StudioAssetReview.put(records, art, {"prompt": prompt.strip_edges(), "replacement": id}, Time.get_datetime_string_from_system())
	if not _persist(next):
		return {"ok": false, "error": StudioText.t("review_save_failed")}
	return {"ok": true, "id": id}
