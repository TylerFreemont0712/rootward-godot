class_name StudioFlagBrowser
extends VBoxContainer
## The quest editor's Flags view (Concept/v0.3/10, S9): every flag the town uses, with where it is set (talk nodes,
## things, lessons) and where it is read (quest steps, talk conditions, unlocks), and the ones nothing sets or nothing
## reads marked. An entry is a link: `entry_chosen` says which one was pressed, and the panel goes there.

## A set-by or read-by entry (StudioQuests.flag_index's) was pressed.
signal entry_chosen(entry: Dictionary)

## The flags listed now, in order (for the tests), after the search.
var shown: Array[String] = []
var search: LineEdit
var _studio: StudioMode
var _work: StudioQuestWork
var _summary: Label
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _problems_only: CheckBox


func _init(studio: StudioMode) -> void:
	_studio = studio
	_work = studio.quests
	name = "FlagBrowser"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	search = StudioQuestUi.line("", func(_text: String) -> void: pass, "flags.search", StudioText.t("flags_search"))
	search.name = "FlagSearch"
	search.custom_minimum_size.x = 320
	search.size_flags_horizontal = Control.SIZE_FILL
	search.text_changed.connect(func(_text: String) -> void: rebuild())
	_problems_only = CheckBox.new()
	_problems_only.text = StudioText.t("flags_only_problems")
	_problems_only.focus_mode = Control.FOCUS_NONE
	_problems_only.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	_problems_only.toggled.connect(func(_on: bool) -> void: rebuild())
	_summary = StudioStyle.line("", UiTheme.MUTED)
	add_child(Ui.hbox([StudioQuestUi.heading(StudioText.t("flags_title")), search, _problems_only, _summary], 14))
	var head := Ui.hbox([_column(StudioText.t("flags_flag"), 300), _column(StudioText.t("flags_set_by"), 0), _column(StudioText.t("flags_read_by"), 0)], 12)
	add_child(head)
	add_child(StudioStyle.rule())
	_rows = Ui.vbox([], 4)
	_scroll = Ui.scroll(_rows)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)


static func _column(text: String, width: int) -> Control:
	var label := StudioQuestUi.field_name(text, width)
	if width == 0:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## The flag index now, the search applied, the list built again.
func rebuild() -> void:
	var index := _work.flags()
	var orphans := StudioQuests.orphans(index)
	var never_set: Array = orphans.never_set
	var never_read: Array = orphans.never_read
	var scroll := _scroll.scroll_vertical
	var saved := StudioQuestUi.remember(self)
	StudioQuestUi.clear(_rows)
	shown.clear()
	var wanted := search.text.strip_edges().to_lower()
	for flag: String in StudioQuests.sorted_flags(index):
		var entry: Dictionary = index[flag]
		var is_orphan := flag in never_set or flag in never_read
		if _problems_only.button_pressed and not is_orphan:
			continue
		if wanted != "" and not _matches(flag, entry, wanted):
			continue
		shown.append(flag)
		_rows.add_child(_row(flag, entry, flag in never_set, flag in never_read))
	_summary.text = StudioText.t("flags_summary") % [index.size(), never_set.size(), never_read.size()]
	if shown.is_empty():
		_rows.add_child(StudioStyle.line(StudioText.t("flags_none"), UiTheme.MUTED))
	StudioQuestUi.restore(self, saved)
	StudioQuestUi.keep_scroll(_scroll, scroll)


static func _matches(flag: String, entry: Dictionary, wanted: String) -> bool:
	if wanted in flag.to_lower():
		return true
	for role: String in [StudioQuests.SET_BY, StudioQuests.READ_BY]:
		for where: Dictionary in entry[role]:
			if wanted in StudioQuests.where_text(where).to_lower():
				return true
	return false


func _row(flag: String, entry: Dictionary, unset: bool, unread: bool) -> Control:
	var colour := UiTheme.FAIL if unset else (UiTheme.WARN if unread else UiTheme.TEXT)
	var name_label := StudioStyle.line(flag, colour)
	name_label.name = "Flag_" + flag
	var tag := StudioStyle.caption(StudioText.t("flags_never_set") if unset else (StudioText.t("flags_never_read") if unread else ""))
	tag.add_theme_color_override("font_color", colour)
	var first := Ui.vbox([name_label, tag], 0)
	first.custom_minimum_size.x = 300
	var row := Ui.hbox([first, _entries(flag, StudioQuests.SET_BY, entry), _entries(flag, StudioQuests.READ_BY, entry)], 12)
	return Ui.vbox([row, StudioStyle.rule()], 2)


## The links of one side: set-by or read-by.
func _entries(flag: String, role: String, entry: Dictionary) -> Control:
	var column := Ui.vbox([], 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list: Array = entry[role]
	if list.is_empty():
		column.add_child(StudioStyle.line("-", UiTheme.FAINT))
	for i: int in list.size():
		var where: Dictionary = list[i]
		var words := StudioQuests.where_text(where)
		if String(where.get("kind", "")) == StudioQuests.LESSON:
			column.add_child(StudioStyle.line(words, UiTheme.MUTED))
			continue
		var link := StudioQuestUi.link(words, func() -> void: entry_chosen.emit(where), StudioText.t("flags_jump_tip"))
		link.name = "%s_%s_%d" % ["Set" if role == StudioQuests.SET_BY else "Read", flag, i]
		column.add_child(link)
	return column
