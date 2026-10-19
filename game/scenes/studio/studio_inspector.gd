class_name StudioInspector
extends PanelContainer
## The inspector (Concept/v0.3/10, section 6): the selected object's fields, one a line, then its raw JSON as its
## content file says it. The raw JSON stays read-only; in S1 a few fields are controls (text and name as text boxes,
## solid as a checkbox, sink as a number, facing and draw layer as choices), and each change is announced as
## `field_changed` for the Studio to make a `set` command of.

## A control was changed: the sid of the object it was shown for, the field, and the value (null to erase it).
signal field_changed(sid: int, key: String, value: Variant)
signal delete_requested
## Where a door or warp leads (S6): the buttons of the links section, for the Studio to act on.
signal link_requested(sid: int)
signal make_interior_requested(sid: int)
signal unlink_requested(sid: int)
signal go_to_requested(map_id: String, cell: Vector2i)
signal edit_talk_requested(person_id: String)
signal edit_person_quest_requested(person_id: String, quest_id: String, step: int)
## A field of the map itself was changed (shown when nothing is selected): "name" or "facing".
signal map_field_changed(key: String, value: Variant)
## Make it a thing (S8): the prop with this sid should take code.
signal make_thing_requested(sid: int)
signal size_changed(sid: int, size: Vector2i)

## The fields that can be changed, by kind of object.
const EDITABLE := {
	"building": ["name", "text", "sink"],
	"prop": ["text", "solid", "sink", "draw_layer"],
	"sign": ["text"],
	"person": ["facing"],
}
const EDITABLE_NAMES: Array[String] = ["text", "name", "solid", "sink", "facing", "draw_layer"]
const FACINGS: Array[String] = ["down", "up", "left", "right"]
const LAYERS: Array[String] = ["none", "ground"]

## What is shown, for the tests: "key: value" a line, and the raw JSON.
var lines: Array[String] = []
var raw_json := ""
var delete_button: Button

var _body: VBoxContainer
var _title: Label
var _stack: Label
var _fields: GridContainer
var _json: Label
var _empty: Label
## The S6 sections: where a door leads, a person's talk and quests, and the map itself.
var _links_box: VBoxContainer
var _links_text: Label
var _link_button: Button
var _make_button: Button
var _unlink_button: Button
var _go_button: Button
var _links_sid := -1
var _links_info: Dictionary = {}
var _person_box: VBoxContainer
var _person_name: Label
var _person_id_text: Label
var _person_location: Label
var _person_diagnostic: Label
var _person_talk: Label
var _person_talk_id: Label
var _person_schedule: Label
var _open_button: Button
var _person_mentions: VBoxContainer
var _talk_file := ""
var _person_id := ""
var _map_box: VBoxContainer
var _map_summary: Label
var _map_name: LineEdit
var _map_was := ""
var _map_start: Label
var _map_facing: OptionButton
## The S8 section: a prop that takes code (its id, hook, lock, fields), or Make it a thing for one that does not.
var _thing_box: VBoxContainer
var _thing_text: Label
var _thing_button: Button
var _thing_sid := -1
## What the object views show and the map view hides: the rule, the raw JSON heading and the raw JSON.
var _json_parts: Array[Control] = []
var _size_box: VBoxContainer
var _size_width: SpinBox
var _size_depth: SpinBox
var _size_sid := -1
var _original_size := Vector2i.ONE


func _init() -> void:
	name = "Inspector"
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(10, 8)))
	custom_minimum_size.x = StudioStyle.RIGHT
	var column := Ui.vbox([], 6)
	add_child(column)
	column.add_child(StudioStyle.caption(StudioText.t("inspector")))
	delete_button = StudioStyle.button(StudioText.t("delete_selected"), func() -> void: delete_requested.emit(), false, StudioText.t("delete_selected_tip"))
	delete_button.name = "DeleteSelected"
	column.add_child(delete_button)
	_empty = Ui.label(StudioText.t("nothing_selected"), "Muted", true)
	_empty.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	column.add_child(_empty)
	_title = Ui.label("", "Subheading", true)
	_title.add_theme_font_size_override("font_size", 17)
	_stack = StudioStyle.line("", UiTheme.MUTED)
	_fields = GridContainer.new()
	_fields.columns = 2
	_fields.add_theme_constant_override("h_separation", 10)
	_fields.add_theme_constant_override("v_separation", 2)
	_json = Ui.label("", "Code", true)
	_json.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_json.add_theme_font_override("font", UiTheme.code_font())
	_json.add_theme_font_size_override("font_size", 12)
	_json.add_theme_color_override("font_color", UiTheme.MUTED)
	_build_links()
	_build_person()
	_build_map()
	_build_thing()
	_build_size()
	_json_parts = [StudioStyle.rule(), StudioStyle.caption(StudioText.t("raw_json")), _json]
	_body = Ui.vbox([_title, _stack, _size_box, _fields, _links_box, _person_box, _thing_box, _map_box], 6)
	for part: Control in _json_parts:
		_body.add_child(part)
	var scroll := Ui.scroll(_body)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	clear()


func clear() -> void:
	lines.clear()
	raw_json = ""
	_show_sections(false, false, false)
	_empty.visible = true
	_body.get_parent().visible = false
	set_selection_count(0)


## Acts on placed instances; the catalog and its pictures are separate from the selection.
func set_selection_count(count: int) -> void:
	delete_button.disabled = count <= 0
	delete_button.visible = count > 0


## Shows an object of the map: `content` is StudioPick.content_of(object); `place` of `count` says which of the
## things under the cursor it is.
func show_object(heading: String, content: Dictionary, place := 1, count := 1, sid := 0) -> void:
	set_selection_count(1)
	_empty.visible = false
	_body.get_parent().visible = true
	_show_sections(false, false, false)
	_title.text = heading
	_show_size(content, sid)
	_stack.visible = count > 1
	_stack.text = StudioText.t("stack_of") % [place, count]
	Ui.clear(_fields)
	lines.clear()
	var editable: Array = EDITABLE.get(String(content.get("kind", "")), [])
	for key: String in content:
		var value := _show(key, content[key])
		lines.append("%s: %s" % [key, value])
		if key in editable:
			_add_row(key, _control(sid, key, content[key]))
		else:
			var value_label := Ui.label(value, "", true)
			value_label.add_theme_font_size_override("font_size", StudioStyle.SMALL)
			value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_add_row(key, value_label)
	# A field the object does not have yet can be added: a prop gets its text here.
	for key: String in editable:
		if not content.has(key):
			_add_row(key, _control(sid, key, null))
	var variant := StudioInspector.variant_line(String(content.get("art", "")))
	if variant != "":
		var variant_label := Ui.label(variant, "Muted", true)
		variant_label.name = "Variant"
		variant_label.add_theme_font_size_override("font_size", StudioStyle.SMALL)
		variant_label.tooltip_text = StudioText.t("variant_tip")
		_add_row("variant", variant_label)
	raw_json = StudioInspector.json(content, true)
	_json.text = raw_json


## Which of its family's variants `art` is ("Ivy, 2 of 4"), or "" when its family has no other.
static func variant_line(art: String) -> String:
	var entries := StudioAssets.entries()
	var raw_entry: Variant = entries.get(art)
	if not raw_entry is Dictionary:
		return ""
	var entry: Dictionary = raw_entry
	var members: Array[String] = []
	members.assign(StudioCatalog.families(entries).get(String(entry.get("family", "")), []))
	if members.size() < 2:
		return ""
	return StudioText.t("variant_of") % [String(entry.get("variant", art)), members.find(art) + 1, members.size()]


## Several things are selected: how many, and what they are. No fields (a field of several is a later phase).
func show_many(names: Array[String]) -> void:
	set_selection_count(names.size())
	_empty.visible = false
	_body.get_parent().visible = true
	_show_sections(false, false, false)
	_title.text = StudioText.t("selected_many") % names.size()
	_stack.visible = false
	Ui.clear(_fields)
	lines.assign(names)
	for name_text: String in names.slice(0, 12):
		var label := StudioStyle.line(name_text, UiTheme.MUTED)
		_fields.add_child(Ui.spacer())
		_fields.add_child(label)
	raw_json = ""
	_json.text = ""


# --- S6: where a door leads, a person, and the map ---


## Shows the links section under the object just shown with `show_object`. `info` = {"kind": "building" | "warp",
## "leads": {} or {"map", "name", "at": Vector2i, "facing"}, "can_make": bool}.
func show_links(sid: int, info: Dictionary) -> void:
	_links_sid = sid
	_links_info = info.duplicate(true)
	var kind := String(info.get("kind", "building"))
	var leads: Dictionary = info.get("leads", {})
	var where := ""
	if leads.is_empty():
		_links_text.text = StudioText.t("links_nowhere" if kind == "building" else "links_nowhere_warp")
		where = _links_text.text
	else:
		var at: Vector2i = leads.get("at", Vector2i.ZERO)
		where = StudioText.f("links_where", [String(leads.get("name", leads.get("map", ""))), at.x, at.y, String(leads.get("facing", "down"))])
		_links_text.text = StudioText.f("links_leads", [where])
	_link_button.text = StudioText.t("link_door" if kind == "building" else "link_warp")
	_make_button.visible = bool(info.get("can_make", false))
	_unlink_button.visible = not leads.is_empty() and kind == "building"
	_go_button.visible = not leads.is_empty()
	lines.append("leads: " + where)
	_links_box.visible = true


## Shows the selected townsperson's read-only details: identity, talk file and id, schedule, and quest mentions.
func show_person(info: Dictionary) -> void:
	_talk_file = String(info.get("talk_file", ""))
	_person_id = String(info.get("id", ""))
	var who := String(info.get("name", ""))
	var title := String(info.get("title", ""))
	var talk_id := String(info.get("talk_id", _person_id))
	_person_name.text = Text.t(who) + (", " + Text.t(title) if title != "" else "")
	_person_id_text.text = StudioText.f("people_person_id", [_person_id])
	var authored_cell: Vector2i = info.get("at", Vector2i.ZERO)
	_person_location.text = StudioText.f("people_authored_location", [
		String(info.get("map", "")), authored_cell.x, authored_cell.y,
		StudioText.t("link_face_" + String(info.get("facing", "down"))),
	])
	_person_location.visible = info.has("at")
	_person_talk.text = StudioText.t("person_talk") % ("talk/" + _talk_file.get_file() if _talk_file != "" else "-")
	_person_talk_id.text = StudioText.f("people_talk_id", [talk_id])
	var talk_available := bool(info.get("talk_available", false))
	_open_button.disabled = _person_id == "" or not talk_available
	_person_diagnostic.visible = not talk_available
	_open_button.tooltip_text = StudioText.t("person_open_tip") if talk_available else StudioText.t("people_talk_missing")
	_person_talk.add_theme_color_override("font_color", UiTheme.MUTED if talk_available else UiTheme.WARN)
	var schedule: Dictionary = info.get("schedule", {})
	_person_schedule.visible = not schedule.is_empty()
	_person_schedule.text = StudioText.t("people_scheduled_note") if not schedule.is_empty() else ""
	var schedule_spots := PackedStringArray()
	for spot: String in ["home", "work", "inn"]:
		if not schedule.has(spot):
			continue
		var cell := OverworldMap.cell_of(schedule[spot])
		schedule_spots.append(StudioText.f("people_schedule_spot", [StudioText.t("people_schedule_" + spot), cell.x, cell.y]))
	_person_schedule.tooltip_text = " · ".join(schedule_spots)
	Ui.clear(_person_mentions)
	var mentions: Array[String] = []
	mentions.assign(info.get("mentions", []))
	var references: Array = info.get("quest_references", [])
	_person_mentions.add_child(StudioStyle.caption(StudioText.t("person_quests")))
	if mentions.is_empty():
		_person_mentions.add_child(_small(StudioText.t("person_no_quests"), UiTheme.MUTED))
	if references.is_empty():
		for mention: String in mentions:
			_person_mentions.add_child(_small(mention, UiTheme.TEXT))
	for reference: Dictionary in references:
		var quest_id := String(reference.id)
		var step := int(reference.step)
		var label := Text.t(String(reference.title)) + ": " + Text.t(String(reference.get("text", "")))
		if String(reference.role) == "giver":
			label = StudioText.f("people_gives_quest", [Text.t(String(reference.title))])
		var jump := StudioQuestUi.link(label, func() -> void:
			edit_person_quest_requested.emit(_person_id, quest_id, step))
		jump.name = "PersonQuest_%s_%d" % [quest_id, step]
		jump.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_person_mentions.add_child(jump)
	lines.append("name: " + who)
	lines.append("title: " + title)
	lines.append("id: " + _person_id)
	if info.has("at"):
		lines.append("location: " + _person_location.text)
	lines.append("talk: " + _talk_file)
	lines.append("talk id: " + talk_id)
	if not schedule.is_empty():
		lines.append("schedule: " + " · ".join(schedule_spots))
	for mention: String in mentions:
		lines.append("quest: " + mention)
	if mentions.is_empty():
		lines.append("quest: " + StudioText.t("person_no_quests"))
	_person_box.visible = true


## Shows the map itself, for when nothing is selected. `info` = {"id", "name", "size": Vector2i, "interior": bool,
## "start": Vector2i, "facing"}. The Delete button stays hidden.
func show_map(info: Dictionary) -> void:
	set_selection_count(0)
	_empty.visible = false
	_body.get_parent().visible = true
	_show_sections(false, false, true)
	var map_name := String(info.get("name", info.get("id", "")))
	var size: Vector2i = info.get("size", Vector2i.ZERO)
	var start: Vector2i = info.get("start", Vector2i.ZERO)
	var facing := String(info.get("facing", "down"))
	var place := StudioText.t("map_room" if bool(info.get("interior", false)) else "map_outdoors")
	_title.text = StudioText.t("map_title") % map_name
	_stack.visible = false
	Ui.clear(_fields)
	_map_summary.text = "%s\n%d x %d, %s" % [String(info.get("id", "")), size.x, size.y, place]
	# A name being typed is not overwritten by the rebuilds a change causes.
	if not _map_name.has_focus():
		_map_name.text = map_name
		_map_was = map_name
	_map_start.text = StudioText.t("map_start") % [start.x, start.y]
	_map_facing.select(maxi(0, FACINGS.find(facing)))
	lines.assign(
		[
			"name: " + map_name,
			"id: " + String(info.get("id", "")),
			"size: %d x %d" % [size.x, size.y],
			"kind: " + place,
			"start: %d, %d" % [start.x, start.y],
			"facing: " + facing,
		]
	)
	raw_json = ""
	_json.text = ""


func _show_sections(links: bool, person: bool, map: bool) -> void:
	_size_box.visible = false
	_thing_box.visible = false
	_links_box.visible = links
	_person_box.visible = person
	_map_box.visible = map
	for part: Control in _json_parts:
		part.visible = not map


func _build_size() -> void:
	_size_width = _dimension("ObjectWidth")
	_size_depth = _dimension("ObjectDepth")
	var row := Ui.hbox([
		Ui.vbox([_small(StudioText.t("object_width"), UiTheme.MUTED), _size_width], 3),
		Ui.vbox([_small(StudioText.t("object_depth"), UiTheme.MUTED), _size_depth], 3),
	], 10)
	var apply := StudioStyle.button(StudioText.t("object_resize"), func() -> void:
		size_changed.emit(_size_sid, Vector2i(int(_size_width.value), int(_size_depth.value))))
	apply.name = "ApplyObjectSize"
	var reset := StudioStyle.button(StudioText.t("object_reset"), func() -> void: size_changed.emit(_size_sid, _original_size))
	reset.name = "ResetObjectSize"
	_size_box = Ui.vbox([
		StudioStyle.caption(StudioText.t("object_size")), row, Ui.flow([apply, reset], 4),
		_small(StudioText.t("object_size_help"), UiTheme.MUTED), StudioStyle.rule(),
	], 5)
	_size_box.name = "ObjectSize"


func _dimension(node_name: String) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = 1
	spin.max_value = 128
	spin.step = 1
	spin.custom_minimum_size.x = 104
	spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
	spin.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	return spin


func _show_size(content: Dictionary, sid: int) -> void:
	_size_box.visible = String(content.get("kind", "")) in ["building", "prop"]
	if not _size_box.visible:
		return
	var same := _size_sid == sid
	_size_sid = sid
	var size := OverworldMap.cell_of(content.get("size", [1, 1]))
	_original_size = OverworldMap.cell_of(content.get("art_size", [size.x, size.y]))
	if not same or not _size_width.get_line_edit().has_focus():
		_size_width.value = size.x
	if not same or not _size_depth.get_line_edit().has_focus():
		_size_depth.value = size.y


func focus_size() -> void:
	if _size_box.visible:
		_size_width.get_line_edit().grab_focus()
		_size_width.get_line_edit().select_all()


func _build_links() -> void:
	_links_text = _small("", UiTheme.TEXT)
	_links_text.name = "LeadsTo"
	_link_button = StudioStyle.button("", func() -> void: link_requested.emit(_links_sid), false, StudioText.t("link_tip"))
	_link_button.name = "LinkDoor"
	_make_button = StudioStyle.button(StudioText.t("make_interior"), func() -> void: make_interior_requested.emit(_links_sid), false, StudioText.t("make_interior_tip"))
	_make_button.name = "MakeInterior"
	_unlink_button = StudioStyle.button(StudioText.t("unlink"), func() -> void: unlink_requested.emit(_links_sid), false, StudioText.t("unlink_tip"))
	_unlink_button.name = "Unlink"
	_go_button = StudioStyle.button(StudioText.t("go_there"), _go_there, false, StudioText.t("go_there_tip"))
	_go_button.name = "GoThere"
	_links_box = Ui.vbox(
		[StudioStyle.rule(), _links_text, Ui.flow([_link_button, _make_button, _unlink_button, _go_button], 4)], 4
	)
	_links_box.name = "Links"
	_links_box.visible = false


## Shows the thing section for a prop (S8), under the object just shown: for a prop that takes code its id, hook, what
## unlocks it and its fields; for one that does not, Make it a thing.
func show_thing(sid: int, raw: Dictionary) -> void:
	_thing_sid = sid
	var program: Variant = raw.get("program")
	if program is Dictionary:
		var kept := program as Dictionary
		var unlock: Variant = kept.get("unlocked_by")
		var words := StudioText.t("thing_takes") % [String(raw.get("id", "")), String(kept.get("hook", ""))]
		words += "\n" + StudioText.t("thing_unlocked_by") % (json(unlock) if unlock != null else StudioText.t("thing_always"))
		var links: Array = kept.get("links", []) if kept.get("links", []) is Array else []
		if not links.is_empty():
			words += "\n" + StudioText.t("thing_links_to") % ", ".join(PackedStringArray(links))
		_thing_text.text = words
		_thing_button.visible = false
		lines.append("thing: " + String(raw.get("id", "")))
	else:
		_thing_text.text = StudioText.t("thing_none")
		_thing_button.visible = true
	_thing_box.visible = true


func _build_thing() -> void:
	_thing_text = _small("", UiTheme.TEXT)
	_thing_button = StudioStyle.button(StudioText.t("thing_make"), func() -> void: make_thing_requested.emit(_thing_sid), false, StudioText.t("thing_make_tip"))
	_thing_button.name = "MakeThing"
	_thing_box = Ui.vbox([StudioStyle.rule(), _thing_text, _thing_button], 4)
	_thing_box.name = "Thing"
	_thing_box.visible = false


func _go_there() -> void:
	var leads: Dictionary = _links_info.get("leads", {})
	if not leads.is_empty():
		go_to_requested.emit(String(leads.get("map", "")), leads.get("at", Vector2i.ZERO))


func _build_person() -> void:
	_person_name = _small("", UiTheme.TEXT)
	_person_name.name = "PersonName"
	_person_id_text = _small("", UiTheme.MUTED)
	_person_id_text.name = "PersonId"
	_person_location = _small("", UiTheme.MUTED)
	_person_location.name = "PersonLocation"
	_person_location.tooltip_text = StudioText.t("people_read_only")
	_person_diagnostic = _small(StudioText.t("people_talk_missing"), UiTheme.WARN)
	_person_diagnostic.name = "PersonDiagnostic"
	_person_talk = _small("", UiTheme.MUTED)
	_person_talk.name = "PersonTalk"
	_person_talk_id = _small("", UiTheme.MUTED)
	_person_talk_id.name = "PersonTalkId"
	_person_schedule = _small("", UiTheme.MUTED)
	_person_schedule.name = "PersonSchedule"
	_person_schedule.visible = false
	_open_button = StudioStyle.button(StudioText.t("people_edit_talk"), _open_talk, false, StudioText.t("person_open_tip"))
	_open_button.name = "OpenTalk"
	_person_mentions = Ui.vbox([], 2)
	_person_mentions.name = "Mentions"
	_person_box = Ui.vbox(
		[StudioStyle.rule(), _person_name, _person_id_text, _person_location, _person_talk, _person_talk_id, _person_schedule, _person_diagnostic, _open_button, _person_mentions], 4
	)
	_person_box.name = "Person"
	_person_name.tooltip_text = StudioText.t("people_read_only")
	_person_id_text.tooltip_text = StudioText.t("people_read_only")
	_person_talk_id.tooltip_text = StudioText.t("people_read_only")
	_person_box.visible = false


func _open_talk() -> void:
	if _person_id != "":
		edit_talk_requested.emit(_person_id)


func _build_map() -> void:
	_map_summary = _small("", UiTheme.MUTED)
	_map_summary.name = "MapSummary"
	_map_name = LineEdit.new()
	_map_name.name = "MapName"
	_map_name.focus_mode = Control.FOCUS_CLICK
	_map_name.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	_map_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var commit := func() -> void:
		var text := _map_name.text.strip_edges()
		if text == "":
			_map_name.text = _map_was
		elif text != _map_was:
			_map_was = text
			map_field_changed.emit("name", text)
	_map_name.text_submitted.connect(
		func(_text: String) -> void:
			commit.call()
			_map_name.release_focus()
	)
	_map_name.focus_exited.connect(func() -> void: commit.call())
	_map_start = _small("", UiTheme.MUTED)
	_map_start.name = "MapStart"
	_map_facing = OptionButton.new()
	_map_facing.name = "MapFacing"
	_map_facing.focus_mode = Control.FOCUS_NONE
	_map_facing.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	for choice: String in FACINGS:
		_map_facing.add_item(choice)
	_map_facing.item_selected.connect(func(index: int) -> void: map_field_changed.emit("facing", FACINGS[index]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	for row: Array in [
		[StudioText.t("map_name"), _map_name],
		[StudioText.t("map_start_label"), _map_start],
		[StudioText.t("edit_facing"), _map_facing],
	]:
		var name_label := StudioStyle.line(row[0], UiTheme.MUTED)
		name_label.custom_minimum_size.x = 56
		grid.add_child(name_label)
		grid.add_child(row[1] as Control)
	_map_box = Ui.vbox([_map_summary, grid], 6)
	_map_box.name = "MapSection"
	_map_box.visible = false


## A small wrapped line, for the S6 sections.
func _small(text: String, colour: Color) -> Label:
	var label := Ui.label(text, "", true)
	label.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	label.add_theme_color_override("font_color", colour)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _add_row(key: String, control: Control) -> void:
	var name_label := StudioStyle.line(StudioText.t("edit_" + key) if key in EDITABLE_NAMES else key, UiTheme.MUTED)
	name_label.custom_minimum_size.x = 56
	_fields.add_child(name_label)
	_fields.add_child(control)


## The control for an editable field, showing `value` (null when the object has none).
func _control(sid: int, key: String, value: Variant) -> Control:
	var emit := func(changed: Variant) -> void: field_changed.emit(sid, key, changed)
	match key:
		"solid":
			var box := CheckBox.new()
			box.button_pressed = bool(value) if value != null else true
			box.focus_mode = Control.FOCUS_NONE
			box.toggled.connect(func(on: bool) -> void: emit.call(on))
			return box
		"sink":
			var spin := SpinBox.new()
			spin.min_value = -64
			spin.max_value = 64
			spin.step = 1
			spin.value = int(value) if value != null else 0
			spin.get_line_edit().focus_mode = Control.FOCUS_CLICK
			spin.value_changed.connect(func(number: float) -> void: emit.call(int(number)))
			return spin
		"facing", "draw_layer":
			var choices := FACINGS if key == "facing" else LAYERS
			var option := OptionButton.new()
			option.focus_mode = Control.FOCUS_NONE
			for choice: String in choices:
				option.add_item(choice)
			var shown := String(value) if value != null else ("down" if key == "facing" else "none")
			option.select(maxi(0, choices.find(shown)))
			option.add_theme_font_size_override("font_size", StudioStyle.SMALL)
			option.item_selected.connect(
				func(index: int) -> void:
					emit.call(choices[index] if not (key == "draw_layer" and index == 0) else null)
			)
			return option
	var edit := LineEdit.new()
	edit.text = String(value) if value != null else ""
	edit.focus_mode = Control.FOCUS_CLICK
	edit.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var was := edit.text
	var commit := func() -> void:
		if edit.text != was:
			was = edit.text
			emit.call(edit.text if edit.text != "" else null)
	edit.text_submitted.connect(
		func(_text: String) -> void:
			commit.call()
			edit.release_focus()
	)
	edit.focus_exited.connect(func() -> void: commit.call())
	return edit


## A field's value for a line: cells as "x, y", sizes as "w x h", the rest as JSON.
static func _show(key: String, value: Variant) -> String:
	if value is String:
		return value
	if value is Array and (value as Array).size() == 2 and value[0] is int and value[1] is int:
		return ("%d x %d" if key == "size" else "%d, %d") % [value[0], value[1]]
	return json(value)


## JSON as the content files write it: ", " and ": " between items; one key a line at the top when `spread`.
static func json(value: Variant, spread := false) -> String:
	if value is Dictionary:
		var items: Array[String] = []
		for key: Variant in value:
			items.append("%s: %s" % [JSON.stringify(key), json(value[key])])
		if spread:
			return "{\n  " + ",\n  ".join(items) + "\n}"
		return "{" + ", ".join(items) + "}"
	if value is Array:
		var items: Array[String] = []
		for item: Variant in value:
			items.append(json(item))
		return "[" + ", ".join(items) + "]"
	return JSON.stringify(value)
