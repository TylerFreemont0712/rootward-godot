class_name StudioTopBar
extends PanelContainer
## The top bar (Concept/v0.3/10, section 6): the map picker (every map, rooms and maps not published yet included),
## Play and Edit, active workspace tabs and the draft's state. DESCRIPTORS is the shared routing table for mounted tabs.

signal play_pressed
signal edit_pressed
signal undo_pressed
signal redo_pressed
signal publish_pressed
signal revert_pressed
## The Play draft switch was turned: whether it is on now.
signal play_draft_toggled(on: bool)
## A tab was clicked: its stable workspace ID.
signal tab_chosen(tab: String)
## A map was chosen in the picker: its id.
signal map_chosen(id: String)
## The plus button beside the map picker was pressed.
signal new_area_pressed

## Tabs with mounted workspaces, by the name the Studio uses.
const TABS := {"objects": "tab_objects", "build": "tab_build", "land": "tab_land", "people": "tab_people", "quests": "tab_quests"}
## One routing table for every workspace, including the ones that are not mounted yet. Keeping ownership here lets
## StudioMode, the top bar and the left tools make the same visibility decision without treating a tab name as a mode.
const DESCRIPTORS := {
	"objects": {
		"id": "objects", "title": "tab_objects", "shelf": "objects",
		"tools": ["select", "place", "area", "catalog"], "history": "map", "inspector": true, "enabled": true,
	},
	"land": {
		"id": "land", "title": "tab_land", "shelf": "land",
		"tools": ["paint", "resize"], "history": "map", "inspector": true, "enabled": true,
	},
	"people": {
		"id": "people", "title": "tab_people", "shelf": "people",
		"tools": ["select", "place", "link", "navigate"], "history": "map", "inspector": true, "enabled": true,
	},
	"build": {
		"id": "build", "title": "tab_build", "shelf": "build",
		"tools": ["select", "place", "build"], "history": "map", "inspector": true, "enabled": true,
	},
	"quests": {
		"id": "quests", "title": "tab_quests", "shelf": "quests",
		"tools": ["quest_edit"], "history": "quest", "inspector": false, "enabled": true,
	},
}

var _picker: OptionButton
var _new_area: Button
## The picker's maps, in its order, and what it says for each (for the tests).
var map_ids: Array[String] = []
var map_labels: Array[String] = []
var _play: Button
var _edit: Button
var _undo: Button
var _redo: Button
var _draft_switch: Button
var _draft: Label
var _publish: Button
var _revert: Button
var _draft_on := false
var _tabs: Dictionary = {}
## What the draft label says, for the tests.
var draft_text := ""
var _linking := false
var _history_state := [false, false]
var _publish_state := [false, false]


func _init() -> void:
	name = "TopBar"
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(10, 5)))
	_picker = OptionButton.new()
	_picker.name = "MapPicker"
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.custom_minimum_size.x = 210
	_picker.clip_text = true
	_picker.add_theme_font_size_override("font_size", 15)
	_picker.tooltip_text = StudioText.t("map_picker_tip")
	_picker.item_selected.connect(_picked)
	_new_area = StudioStyle.button(
		"+", func() -> void: new_area_pressed.emit(), false, StudioText.t("area_add_tip")
	)
	_new_area.name = "NewArea"
	_new_area.custom_minimum_size.x = 28
	_play = StudioStyle.button(
		StudioText.t("play"), func() -> void: play_pressed.emit(), false, StudioText.t("play_tip")
	)
	_edit = StudioStyle.button(
		StudioText.t("edit"), func() -> void: edit_pressed.emit(), true, StudioText.t("edit_tip")
	)
	var tabs: Array = [Ui.spacer(14, 0)]
	for tab: String in ["objects", "build", "land", "people", "quests"]:
		var descriptor: Dictionary = DESCRIPTORS[tab]
		var enabled := bool(descriptor.enabled)
		var button := StudioStyle.button(StudioText.t(String(descriptor.title)), Callable(), tab == "objects")
		button.name = "Tab_" + tab
		button.disabled = not enabled
		button.tooltip_text = "" if enabled else StudioText.t("tab_later")
		if enabled:
			button.pressed.connect(func() -> void: tab_chosen.emit(tab))
			_tabs[tab] = button
		tabs.append(button)
	_draft = StudioStyle.line(StudioText.t("draft_none"), UiTheme.MUTED)
	_undo = StudioStyle.button(
		StudioText.t("undo"), func() -> void: undo_pressed.emit(), false, StudioText.t("undo_tip")
	)
	_redo = StudioStyle.button(
		StudioText.t("redo"), func() -> void: redo_pressed.emit(), false, StudioText.t("redo_tip")
	)
	_draft_switch = StudioStyle.button(
		StudioText.t("play_draft"), _toggle_draft, false, StudioText.t("play_draft_tip")
	)
	_publish = StudioStyle.button(StudioText.t("publish"), func() -> void: publish_pressed.emit(), true)
	_revert = StudioStyle.button(StudioText.t("revert"), func() -> void: revert_pressed.emit())
	var row := Ui.hbox(
		[_picker, _new_area, _play, _edit] + tabs + [Ui.spacer(), _draft, Ui.spacer(10, 0), _undo, _redo, _draft_switch, _revert, _publish], 6
	)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(row)


## Shows which tab is in use.
func set_tab(tab: String) -> void:
	for one: String in _tabs:
		StudioStyle.choose(_tabs[one], one == tab)


## The maps the picker offers ({id, name, room, new} each, in order) and the one shown now. The town comes first;
## a room says so, and a map not published yet says "new".
func set_maps(maps: Array[Dictionary], current: String) -> void:
	_picker.clear()
	map_ids.clear()
	map_labels.clear()
	for map: Dictionary in maps:
		var label := String(map.get("name", map.id))
		var notes: Array[String] = []
		if bool(map.get("room", false)):
			notes.append(StudioText.t("map_room"))
		if bool(map.get("new", false)):
			notes.append(StudioText.t("map_new"))
		if bool(map.get("unlinked_room_draft", false)):
			notes.append(StudioText.t("map_unlinked_room"))
		if not notes.is_empty():
			label += "  (" + ", ".join(notes) + ")"
		_picker.add_item(label)
		map_ids.append(String(map.id))
		map_labels.append(label)
	_picker.select(map_ids.find(current))


## The map shown now, when the picker has no list yet (its name alone).
func set_map_name(text: String) -> void:
	if map_ids.is_empty():
		_picker.clear()
		_picker.add_item(text)
		_picker.select(0)


func _picked(index: int) -> void:
	if index >= 0 and index < map_ids.size():
		map_chosen.emit(map_ids[index])


## The Play and Edit buttons show which one the game is in.
func set_editing(editing: bool) -> void:
	StudioStyle.choose(_play, not editing)
	StudioStyle.choose(_edit, editing)


func _toggle_draft() -> void:
	set_play_draft(not _draft_on)
	play_draft_toggled.emit(_draft_on)


## Shows the Play draft switch as on or off without telling anyone.
func set_play_draft(on: bool) -> void:
	_draft_on = on
	StudioStyle.choose(_draft_switch, on)


func set_draft_text(text: String) -> void:
	draft_text = text
	_draft.text = text


## Undo and Redo are dimmed when there is nothing to undo or redo.
func set_history(can_undo: bool, can_redo: bool) -> void:
	_history_state = [can_undo, can_redo]
	_undo.disabled = _linking or not can_undo
	_redo.disabled = _linking or not can_redo


func set_publish_state(changed: bool, can_revert: bool) -> void:
	_publish_state = [changed, can_revert]
	_publish.disabled = _linking or not changed
	_revert.disabled = _linking or not can_revert


func set_linking(on: bool) -> void:
	_linking = on
	_new_area.disabled = on
	_draft_switch.disabled = on
	set_history(bool(_history_state[0]), bool(_history_state[1]))
	set_publish_state(bool(_publish_state[0]), bool(_publish_state[1]))
