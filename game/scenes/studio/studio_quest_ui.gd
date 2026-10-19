class_name StudioQuestUi
extends RefCounted
## The controls the quest editor is made of (Concept/v0.3/10, S9): text boxes that commit when they are left or
## submitted (one undo step for a typed line, not one for every key), choices that keep a value the list lacks, a flag
## box with the flags of the town to pick from, and the small things around them. Each editable control carries a
## `fid` (meta): the same control in the next build of a view has the same fid, so the focus can be put back where it
## was after the view is rebuilt for a change.

## While true, a text box that loses focus commits nothing: a view is taking its controls down.
static var muted := false

const FIELD_HEIGHT := 28


## Lets go of the keyboard focus inside `root`, so a text box being edited commits before something else happens.
static func settle(root: Node) -> void:
	if root == null or not root.is_inside_tree():
		return
	var owner := root.get_viewport().gui_get_focus_owner()
	if owner != null and (owner == root or root.is_ancestor_of(owner)):
		owner.release_focus()


## Takes the children of a container down without any text box in them committing.
static func clear(box: Node) -> void:
	muted = true
	Ui.clear(box)
	muted = false


## Which text box has the focus under `root` (its fid and caret), for restore after the view is built again.
static func remember(root: Node) -> Dictionary:
	if root == null or not root.is_inside_tree():
		return {}
	var owner := root.get_viewport().gui_get_focus_owner()
	if owner == null or not root.is_ancestor_of(owner) or not owner.has_meta("fid"):
		return {}
	var out := {"fid": String(owner.get_meta("fid")), "caret": 0}
	if owner is LineEdit:
		out["caret"] = (owner as LineEdit).caret_column
	return out


## Puts the focus back on the control with the same fid, when the new build has one.
static func restore(root: Node, saved: Dictionary) -> void:
	if saved.is_empty():
		return
	var found := find(root, String(saved.fid))
	if found == null:
		return
	found.grab_focus()
	if found is LineEdit:
		(found as LineEdit).caret_column = int(saved.get("caret", 0))


## The control under `root` with this fid, or null.
static func find(root: Node, fid: String) -> Control:
	if root is Control and root.has_meta("fid") and String(root.get_meta("fid")) == fid:
		return root as Control
	for child: Node in root.get_children():
		var found := find(child, fid)
		if found != null:
			return found
	return null


static func _small(control: Control) -> void:
	control.add_theme_font_size_override("font_size", StudioStyle.SMALL)


## A one-line text box. `on_commit` gets the text when Enter is pressed or the box is left, if it changed.
static func line(value: String, on_commit: Callable, fid: String, hint := "") -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = hint
	edit.set_meta("fid", fid)
	edit.custom_minimum_size.y = FIELD_HEIGHT
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.select_all_on_focus = false
	_small(edit)
	var kept: Array[String] = [value]
	var commit := func(text: String) -> void:
		if muted or text == kept[0]:
			return
		kept[0] = text
		on_commit.call(text)
	edit.text_submitted.connect(commit)
	edit.focus_exited.connect(func() -> void: commit.call(edit.text))
	return edit


## A text box of a few lines (a summary, a line of talk). It commits when it is left.
static func area(value: String, on_commit: Callable, fid: String, rows := 2) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = value
	edit.set_meta("fid", fid)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.scroll_fit_content_height = true
	edit.custom_minimum_size.y = 12 + 20 * rows
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_small(edit)
	var kept: Array[String] = [value]
	edit.focus_exited.connect(
		func() -> void:
			if muted or edit.text == kept[0]:
				return
			kept[0] = edit.text
			on_commit.call(edit.text)
	)
	return edit


## A choice among `values` (shown as `labels`, the values themselves when there are none). A value the list lacks is
## kept and marked, so a talk that leads nowhere shows it.
static func choice(values: Array[String], labels: Array[String], value: String, on_pick: Callable, fid: String) -> OptionButton:
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.set_meta("fid", fid)
	option.fit_to_longest_item = false
	option.clip_text = true
	option.custom_minimum_size = Vector2(120, FIELD_HEIGHT)
	_small(option)
	option.get_popup().add_theme_font_size_override("font_size", StudioStyle.SMALL)
	var shown: Array[String] = values.duplicate()
	for i: int in values.size():
		option.add_item(labels[i] if i < labels.size() else (values[i] if values[i] != "" else "-"))
	if not value in shown:
		shown.append(value)
		option.add_item(StudioText.t("quest_missing") % value)
	option.select(shown.find(value))
	option.item_selected.connect(func(index: int) -> void: on_pick.call(shown[index]))
	return option


## A flag: a text box to type it in, and a menu button listing the flags of the town to pick one.
static func flag_field(value: String, flags: Array[String], on_commit: Callable, fid: String) -> Control:
	var edit := line(value, on_commit, fid, StudioText.t("quest_flag_hint"))
	edit.custom_minimum_size.x = 260
	edit.size_flags_horizontal = Control.SIZE_FILL
	var menu := MenuButton.new()
	menu.text = "v"
	menu.focus_mode = Control.FOCUS_NONE
	menu.flat = false
	menu.tooltip_text = StudioText.t("quest_flag_pick")
	menu.custom_minimum_size = Vector2(FIELD_HEIGHT, FIELD_HEIGHT)
	_small(menu)
	var popup := menu.get_popup()
	popup.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	for i: int in flags.size():
		popup.add_item(flags[i], i)
	popup.id_pressed.connect(
		func(id: int) -> void:
			edit.text = flags[id]
			edit.text_submitted.emit(flags[id])
	)
	var row := Ui.hbox([edit, menu], 2)
	row.size_flags_horizontal = Control.SIZE_FILL
	return row


## A button for the editor's rows; `name` lets a test find it.
static func button(text: String, on_pressed: Callable, node_name := "", tip := "") -> Button:
	var node := StudioStyle.button(text, on_pressed, false, tip)
	if node_name != "":
		node.name = node_name
	return node


## A flat button that reads as a link (the flag browser's jumps).
static func link(text: String, on_pressed: Callable, tip := "") -> Button:
	var node := StudioStyle.button(text, on_pressed, false, tip)
	node.flat = true
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_color_override("font_color", UiTheme.TEAL)
	node.add_theme_color_override("font_hover_color", UiTheme.AMBER)
	return node


static func heading(text: String) -> Label:
	var node := Ui.label(text, "Subheading")
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_color_override("font_color", UiTheme.AMBER)
	return node


## A field's name, in a fixed width so a column of them lines up.
static func field_name(text: String, width := 92) -> Label:
	var node := StudioStyle.line(text, UiTheme.MUTED)
	node.custom_minimum_size.x = width
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return node


## A box around one row of a list (a step, a line, a choice).
static func card(content: Control, highlighted := false) -> PanelContainer:
	var node := PanelContainer.new()
	var edge := UiTheme.AMBER if highlighted else UiTheme.LINE
	node.add_theme_stylebox_override("panel", UiTheme.box(Color("#211a14"), edge, 2 if highlighted else 1, 0, Vector2(10, 8)))
	node.add_child(content)
	return node


## Scrolls a ScrollContainer to where it was once the new content has been laid out (a frame later).
static func keep_scroll(scroll: ScrollContainer, value: int) -> void:
	if value <= 0 or not scroll.is_inside_tree():
		return
	await scroll.get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


## Scrolls to a control of the scroll's content once it has been laid out.
static func show_control(scroll: ScrollContainer, control: Control) -> void:
	if not scroll.is_inside_tree():
		return
	await scroll.get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(control):
		scroll.ensure_control_visible(control)


## The flags of the town to pick from: every flag in the index, a count's prefix ("met-*") left out, sorted.
static func flag_names(work: StudioQuestWork) -> Array[String]:
	var out: Array[String] = []
	for flag: String in StudioQuests.sorted_flags(work.flags()):
		if not flag.ends_with(StudioQuests.PREFIX):
			out.append(flag)
	return out


## Who can speak or give a quest: "" (nobody / the person spoken to), Hotaru, and the townsfolk.
static func people(studio: StudioMode, with_nobody := true) -> Array[String]:
	var out: Array[String] = []
	if with_nobody:
		out.append("")
	out.append("hotaru")
	for id: String in studio.catalog().get("townsfolk", {}):
		out.append(id)
	return out
