class_name StudioThingDialog
extends ConfirmationDialog
## Make it a thing (Concept/v0.3/10, S8): what a prop needs to take code. Its id (a free one suggested), its name, when
## its code runs (Space's on_use, a step's on_step, or a link's on_change), the things its changes reach (links), the
## flag that unlocks it (none: always), the flags its code may raise, its fields (as JSON, for now), three hints, and
## its starter code in Python and JavaScript (a template that says its name). OK hands it to StudioWork.make_thing; a
## refusal is shown here and the dialog stays open.

var sid := -1
## What the last OK said when it was refused ("" when it went through).
var problem := ""

var _studio: StudioMode
var _id: LineEdit
var _name: LineEdit
var _unlock: LineEdit
var _hook: OptionButton
var _links: LineEdit
var _raises: LineEdit
var _fields: TextEdit
var _hints: Array[LineEdit] = []
var _python: CodeEdit
var _javascript: CodeEdit
var _problem: Label


func _init(studio: StudioMode) -> void:
	_studio = studio
	name = "MakeThing"
	title = StudioText.t("thing_dialog_title")
	ok_button_text = StudioText.t("thing_dialog_ok")
	dialog_hide_on_ok = false
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	_id = _line(grid, "thing_id", "Id")
	_name = _line(grid, "thing_name", "Name")
	grid.add_child(StudioStyle.line(StudioText.t("thing_hook"), UiTheme.MUTED))
	_hook = OptionButton.new()
	_hook.name = "Hook"
	for hook: String in TownThings.HOOKS:
		_hook.add_item(StudioText.t("thing_hook_" + hook))
	_hook.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	grid.add_child(_hook)
	_links = _line(grid, "thing_links", "Links")
	_links.placeholder_text = StudioText.t("thing_links_hint")
	_unlock = _line(grid, "thing_unlock", "Unlock")
	_unlock.placeholder_text = StudioText.t("thing_unlock_hint")
	_raises = _line(grid, "thing_raises", "Raises")
	_raises.placeholder_text = StudioText.t("thing_raises_hint")
	for i: int in 3:
		_hints.append(_line(grid, "thing_hint", "Hint%d" % (i + 1)))
		_hints[i].placeholder_text = Text.t(StudioThings.DEFAULT_HINTS[i])
	_fields = TextEdit.new()
	_fields.name = "Fields"
	_fields.custom_minimum_size = Vector2(0, 54)
	_fields.add_theme_font_override("font", UiTheme.code_font())
	_fields.add_theme_font_size_override("font_size", 13)
	grid.add_child(StudioStyle.line(StudioText.t("thing_fields"), UiTheme.MUTED))
	grid.add_child(_fields)
	_python = _code("Python")
	_javascript = _code("JavaScript")
	_problem = StudioStyle.line("", UiTheme.AMBER)
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var codes := Ui.hbox([_column("Python", _python), _column("JavaScript", _javascript)], 10)
	var column := Ui.vbox([grid, codes, _problem], 8)
	column.custom_minimum_size = Vector2(820, 0)
	add_child(column)
	confirmed.connect(_confirmed)


## Opens for the prop with `prop_sid`, its id suggested and its starters the templates.
func open(prop_sid: int) -> void:
	sid = prop_sid
	problem = ""
	_problem.text = ""
	var object := _studio.work.raw(_studio.work.index_of(sid))
	var art := String(object.get("art", "thing"))
	var title_text := StudioAssets.name_of(art)
	_id.text = _studio.work.suggest_thing_id(art)
	_name.text = title_text
	_unlock.text = ""
	_hook.select(0)
	_links.text = ""
	_raises.text = ""
	_fields.text = "{}"
	for line: LineEdit in _hints:
		line.text = ""
	_python.text = StudioThings.STARTER_PY % title_text.c_escape()
	_javascript.text = StudioThings.STARTER_JS % title_text.c_escape()
	popup_centered()


## What OK hands to StudioWork.make_thing: {id, name, hints, python, javascript, fields, raises, unlocked_by}; an
## `error` instead when a part cannot be read.
func spec() -> Dictionary:
	var fields: Variant = JSON.parse_string(_fields.text) if _fields.text.strip_edges() != "" else {}
	if not fields is Dictionary:
		return {"error": StudioText.t("thing_fields_bad")}
	var raises: Array[String] = []
	for flag: String in _raises.text.split(",", false):
		if flag.strip_edges() != "":
			raises.append(flag.strip_edges())
	var hints: Array[String] = []
	for line: LineEdit in _hints:
		hints.append(line.text.strip_edges())
	var links: Array[String] = []
	for id: String in _links.text.split(",", false):
		if id.strip_edges() != "":
			links.append(id.strip_edges())
	var out := {
		"id": _id.text.strip_edges(), "name": _name.text.strip_edges(), "hints": hints,
		"python": _python.text, "javascript": _javascript.text, "fields": fields, "raises": raises,
		"hook": TownThings.HOOKS[maxi(0, _hook.selected)], "links": links,
	}
	if _unlock.text.strip_edges() != "":
		out["unlocked_by"] = {"flag": _unlock.text.strip_edges()}
	return out


## Sets a part of the dialog, for the tests: "id", "name", "unlock", "raises", "python", "javascript", "fields",
## "links", or "hook" (on_use, on_step, on_change).
func set_part(part: String, text: String) -> void:
	match part:
		"id":
			_id.text = text
		"name":
			_name.text = text
		"unlock":
			_unlock.text = text
		"raises":
			_raises.text = text
		"python":
			_python.text = text
		"javascript":
			_javascript.text = text
		"fields":
			_fields.text = text
		"links":
			_links.text = text
		"hook":
			_hook.select(maxi(0, TownThings.HOOKS.find(text)))


func _confirmed() -> void:
	var wanted := spec()
	if wanted.has("error"):
		problem = String(wanted.error)
	else:
		var made := _studio.work.make_thing(sid, wanted)
		problem = "" if bool(made.ok) else String(made.get("error", ""))
	_problem.text = problem
	if problem == "":
		hide()


func _line(grid: GridContainer, key: String, node_name: String) -> LineEdit:
	grid.add_child(StudioStyle.line(StudioText.t(key), UiTheme.MUTED))
	var edit := LineEdit.new()
	edit.name = node_name
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	grid.add_child(edit)
	return edit


func _code(language: String) -> CodeEdit:
	var edit := CodeEdit.new()
	edit.name = language
	edit.custom_minimum_size = Vector2(400, 170)
	edit.add_theme_font_override("font", UiTheme.code_font())
	edit.add_theme_font_size_override("font_size", 13)
	edit.gutters_draw_line_numbers = true
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.syntax_highlighter = LanternEditor.highlighter(BootsCode.PYTHON if language == "Python" else BootsCode.JAVASCRIPT)
	return edit


func _column(language: String, edit: CodeEdit) -> Control:
	var column := Ui.vbox([StudioStyle.caption(language), edit], 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return column
