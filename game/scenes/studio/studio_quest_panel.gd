class_name StudioQuestPanel
extends PanelContainer
## The quest editor (Concept/v0.3/10, S9), the Quests tab: three views over the town (the Studio hides it while the tab
## shows). Quests: the quests in order with their steps (StudioQuestList). Flags: every flag, where it is set and read,
## with jumps (StudioFlagBrowser). Talk: a person's talk file as nodes (StudioTalkEditor). It edits through
## StudioQuestWork, so a change is a command with Undo and Redo, a draft that Publish writes, and something Play draft
## plays. Under the three tabs it says what is drafted.

signal return_to_person_requested

## The three views, by the name `show_sub` takes.
const SUBS: Array[String] = ["quests", "flags", "talk"]

## The view shown now.
var sub := "quests"
var quest_list: StudioQuestList
var flag_browser: StudioFlagBrowser
var talk_editor: StudioTalkEditor
## What the drafted line says, for the tests.
var drafted_text := ""

var _studio: StudioMode
var _work: StudioQuestWork
var _tabs: Dictionary = {}
var _undo: Button
var _redo: Button
var _drafted: Label
var _person_return: Button
var _last_key := "quests"
var _pending := false


func _init(studio: StudioMode) -> void:
	_studio = studio
	_work = studio.quests
	name = "Quests"
	visible = false
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(14, 10)))
	var column := Ui.vbox([], 8)
	add_child(column)
	var bar := Ui.hbox([], 8)
	for which: String in SUBS:
		var button := StudioStyle.button(StudioText.t("quest_sub_" + which), func() -> void: show_sub(which), which == sub)
		button.name = "Sub_" + which
		_tabs[which] = button
		bar.add_child(button)
	_person_return = StudioStyle.button(
		StudioText.t("people_return_to_person"), func() -> void: return_to_person_requested.emit()
	)
	_person_return.name = "ReturnToPerson"
	_person_return.visible = false
	bar.add_child(_person_return)
	_drafted = StudioStyle.line("", UiTheme.MUTED)
	_drafted.name = "Drafted"
	_drafted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drafted.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_undo = StudioStyle.button(StudioText.t("quest_undo"), func() -> void: undo(), false, StudioText.t("quest_undo_tip"))
	_undo.name = "Undo"
	_redo = StudioStyle.button(StudioText.t("quest_redo"), func() -> void: redo(), false, StudioText.t("quest_redo_tip"))
	_redo.name = "Redo"
	bar.add_child(_drafted)
	bar.add_child(_undo)
	bar.add_child(_redo)
	column.add_child(bar)
	column.add_child(StudioStyle.rule())
	quest_list = StudioQuestList.new(studio)
	flag_browser = StudioFlagBrowser.new(studio)
	talk_editor = StudioTalkEditor.new(studio)
	for view: Control in [quest_list, flag_browser, talk_editor]:
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(view)
	flag_browser.entry_chosen.connect(jump)
	_work.changed.connect(_changed)
	_show_views()


## The tab was chosen: the panel reads the docs again and shows.
func open() -> void:
	visible = true
	refresh()


func close() -> void:
	StudioQuestUi.settle(self)
	visible = false


func show_person_return(on: bool) -> void:
	_person_return.visible = on


## The doc being edited: the quests, the talk file of the Talk view, and on the Flags view the one changed last.
func edit_key() -> String:
	if sub == "talk" and talk_editor.file != "":
		return talk_editor.key()
	if sub == "flags":
		return _last_key
	return "quests"


func show_sub(which: String) -> void:
	if not which in SUBS:
		return
	StudioQuestUi.settle(self)
	sub = which
	refresh()


## Shows a quest of the Quests view (and a step of it, edged in amber).
func show_quest(id: String, step := -1) -> void:
	StudioQuestUi.settle(self)
	sub = "quests"
	quest_list.chosen = id
	quest_list.step_marked = step
	refresh()


## Shows a node of a talk file in the Talk view; `where` ("start 1", "choice 0") is the rule or choice to edge in amber.
func show_talk(id: String, at_node := "", where := "") -> void:
	StudioQuestUi.settle(self)
	sub = "talk"
	talk_editor.choose_file(id, at_node, where)
	refresh()


## Goes to a place of the flag browser's index: a quest step, a talk node, or a thing on a map (which closes the
## panel and shows the thing, selected, in the Objects tab).
func jump(entry: Dictionary) -> void:
	var kind := String(entry.get("kind", ""))
	if kind == StudioQuests.QUEST:
		show_quest(String(entry.get("id", "")), int(entry.get("step", -1)))
	elif kind == StudioQuests.TALK:
		show_talk(String(entry.get("id", "")), String(entry.get("node", "")), String(entry.get("where", "")))
	elif kind == StudioQuests.THING or kind == StudioQuests.UNLOCK:
		show_thing(String(entry.get("map", "")), String(entry.get("id", "")))


## The Objects tab on a map, with the thing of that id selected and in view. False when the map has no such thing.
func show_thing(map_id: String, id: String) -> bool:
	StudioQuestUi.settle(self)
	_studio.set_tab("objects")
	if not _studio.go_to_map(map_id):
		return false
	var objects: Array = _studio.work.doc().data.get("objects", [])
	for index: int in objects.size():
		var object: Dictionary = objects[index]
		if String(object.get("id", "")) != id:
			continue
		_studio.select_sids([_studio.work.sid_at(index)])
		var cell := OverworldMap.cell_of(object.get("at", [0, 0]))
		_studio.focus((Vector2(cell) + Vector2(0.5, 0.5)) * OverworldScale.TILE)
		return true
	return false


func undo() -> bool:
	StudioQuestUi.settle(self)
	var done := _work.undo(edit_key())
	refresh()
	return done


func redo() -> bool:
	StudioQuestUi.settle(self)
	var done := _work.redo(edit_key())
	refresh()
	return done


## A key while the Quests tab shows: true when the panel used it (Ctrl+Z, Ctrl+Y and Ctrl+Shift+Z on the doc being
## edited). A text box that has the focus keeps its own keys.
func key(event: InputEventKey) -> bool:
	if not visible or not (event.ctrl_pressed or event.meta_pressed):
		return false
	if event.keycode not in [KEY_Z, KEY_Y]:
		return false
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused is LineEdit or focused is TextEdit:
		return false
	if event.pressed and not event.echo:
		if event.keycode == KEY_Y or event.shift_pressed:
			redo()
		else:
			undo()
	return true


# --- drawing ---------------------------------------------------------------------------------------------------------


## The shown view and the header, built again from the docs now.
func refresh() -> void:
	_pending = false
	_show_views()
	match sub:
		"quests":
			quest_list.rebuild()
		"flags":
			flag_browser.rebuild()
		"talk":
			talk_editor.rebuild()
	_header()


func _show_views() -> void:
	quest_list.visible = sub == "quests"
	flag_browser.visible = sub == "flags"
	talk_editor.visible = sub == "talk"
	for which: String in SUBS:
		StudioStyle.choose(_tabs[which], which == sub)


## A doc changed: the view is built again once the frame's work is done (a text box that committed because focus left it
## is not taken down in the middle of that).
func _changed(key_changed: String) -> void:
	_last_key = key_changed
	if not visible or _pending:
		return
	_pending = true
	_flush.call_deferred()


func _flush() -> void:
	if _pending:
		refresh()


func _header() -> void:
	var edited := _work.history(edit_key())
	_undo.disabled = edited == null or not edited.can_undo()
	_redo.disabled = edited == null or not edited.can_redo()
	_studio.refresh_history_owner()
	drafted_text = drafted_line()
	_drafted.text = drafted_text


## What is drafted, in words: "quests.jsonc and 2 talk files changed; Publish writes them."
func drafted_line() -> String:
	var keys := _work.drafted_keys()
	if keys.is_empty():
		return StudioText.t("quest_drafted_none")
	var what: Array[String] = []
	if "quests" in keys:
		what.append("quests.jsonc")
	var talk_count := keys.size() - what.size()
	if talk_count == 1:
		var only := ""
		for each: String in keys:
			if each != "quests":
				only = each.trim_prefix("talk/")
		what.append(StudioText.t("quest_drafted_talk_one") % only)
	elif talk_count > 1:
		what.append(StudioText.t("quest_drafted_talk_many") % talk_count)
	return StudioText.t("quest_drafted") % (StudioText.t("quest_and").join(PackedStringArray(what)))
