class_name StudioAreaDialog
extends ConfirmationDialog
## Create a separate outdoor map draft, add it to the area's picker, and switch there ready to edit.

var _studio: StudioMode
var _name_field: LineEdit
var _id_field: LineEdit
var _width: SpinBox
var _height: SpinBox
var _start_x: SpinBox
var _start_y: SpinBox
var _facing: OptionButton
var _ground: OptionButton
var _summary: Label
var _grounds: Array[String] = []
var _facings: Array[String] = ["down", "up", "left", "right"]
var _auto_id := true
var _writing_id := false


func _init(studio: StudioMode) -> void:
	_studio = studio
	name = "NewArea"
	title = StudioText.t("area_dialog_title")
	ok_button_text = StudioText.t("area_create")
	size = Vector2i(560, 360)
	min_size = Vector2i(500, 300)
	unresizable = true
	var form := GridContainer.new()
	form.columns = 2
	form.add_child(StudioStyle.line(StudioText.t("area_name")))
	_name_field = LineEdit.new()
	_name_field.name = "AreaName"
	_name_field.max_length = 80
	_name_field.custom_minimum_size.x = 320
	_name_field.text_changed.connect(_name_changed)
	form.add_child(_name_field)
	form.add_child(StudioStyle.line(StudioText.t("area_id")))
	_id_field = LineEdit.new()
	_id_field.name = "AreaId"
	_id_field.max_length = StudioAreaFactory.MAX_ID_LENGTH
	_id_field.custom_minimum_size.x = 320
	_id_field.text_changed.connect(_id_changed)
	form.add_child(_id_field)
	_width = _dimension("AreaWidth")
	_height = _dimension("AreaHeight")
	form.add_child(StudioStyle.line(StudioText.t("area_size")))
	var width_row := Ui.hbox([_width, StudioStyle.line(StudioText.t("area_by")), _height], 8)
	form.add_child(width_row)
	_start_x = _dimension("AreaStartX", 0, StudioAreaFactory.MAX_DIMENSION - 1)
	_start_y = _dimension("AreaStartY", 0, StudioAreaFactory.MAX_DIMENSION - 1)
	form.add_child(StudioStyle.line(StudioText.t("area_start")))
	form.add_child(Ui.hbox([_start_x, StudioStyle.line(StudioText.t("area_by")), _start_y], 8))
	_facing = OptionButton.new()
	_facing.name = "AreaFacing"
	for direction: String in _facings:
		_facing.add_item(StudioText.t("area_face_" + direction))
	_facing.item_selected.connect(func(_index: int) -> void: _plan())
	form.add_child(StudioStyle.line(StudioText.t("area_facing")))
	form.add_child(_facing)
	form.add_child(StudioStyle.line(StudioText.t("area_ground")))
	_ground = OptionButton.new()
	_ground.name = "AreaGround"
	_ground.item_selected.connect(func(_index: int) -> void: _plan())
	form.add_child(_ground)
	var help := StudioStyle.caption(StudioText.t("new_area_help"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.x = 420
	var size_note := StudioStyle.caption(StudioText.f("area_size_limit", [StudioAreaFactory.MAX_DIMENSION]))
	_summary = StudioStyle.line("")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size = Vector2(420, 0)
	add_child(Ui.vbox([help, size_note, form, _summary], 10))
	confirmed.connect(_confirm)


func _dimension(node_name: String, minimum := StudioAreaFactory.MIN_DIMENSION, maximum := StudioAreaFactory.MAX_DIMENSION) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.custom_minimum_size.x = 110
	spin.value_changed.connect(func(_value: float) -> void: _plan())
	return spin


## Open with an unused title/id, a comfortable outdoor size, and the map's first walkable surface.
func open() -> void:
	_auto_id = true
	_name_field.clear()
	_name_field.insert_text_at_caret(StudioText.t("area_default_name"))
	_name_field.caret_column = _name_field.text.length()
	_width.set_value_no_signal(40)
	_height.set_value_no_signal(30)
	_start_x.set_value_no_signal(2)
	_start_y.set_value_no_signal(2)
	_facing.select(0)
	_grounds.clear()
	_ground.clear()
	var terrain: Dictionary = _studio.catalog().get("terrain", {})
	for kind: String in terrain:
		var surface: Dictionary = terrain[kind]
		if String(surface.get("paint", "")) == "outdoor" and bool(surface.get("walk", false)):
			_grounds.append(kind)
			_ground.add_item(kind.replace("_", " ").capitalize())
	var meadow := _grounds.find("meadow")
	var grass := _grounds.find("grass")
	_ground.select(meadow if meadow >= 0 else (grass if grass >= 0 else 0))
	_update_id()
	_plan()
	popup_centered(size)


func _name_changed(_value: String) -> void:
	if _auto_id:
		_update_id()
	_plan()


func _id_changed(_value: String) -> void:
	if not _writing_id:
		_auto_id = false
		_plan()


func _update_id() -> void:
	var taken: Array[String] = []
	for row: Dictionary in _studio.map_list():
		taken.append(String(row.get("id", "")))
	_writing_id = true
	_id_field.clear()
	var generated := StudioAreaFactory.unique_id(_name_field.text, taken)
	_id_field.insert_text_at_caret(generated)
	_id_field.caret_column = generated.length()
	_writing_id = false


func _plan() -> void:
	if _auto_id:
		_update_id()
	_set_start_limits()
	if _grounds.is_empty():
		_summary.text = StudioText.t("area_no_ground")
		get_ok_button().disabled = true
		return
	var id := _id_field.text
	for row: Dictionary in _studio.map_list():
		if String(row.get("id", "")) == id:
			_summary.text = StudioText.t("area_duplicate_id")
			get_ok_button().disabled = true
			return
	var title_text := _name_field.text
	var size := Vector2i(int(_width.value), int(_height.value))
	var ground_kind := _grounds[clampi(_ground.selected, 0, _grounds.size() - 1)]
	var start_cell := Vector2i(int(_start_x.value), int(_start_y.value))
	var facing := _facings[clampi(_facing.selected, 0, _facings.size() - 1)]
	var result := StudioAreaFactory.create_data(id, title_text, size, ground_kind, _studio.catalog().terrain, start_cell, facing)
	if not bool(result.get("ok", false)):
		_summary.text = String(result.get("error", StudioText.t("area_invalid")))
		get_ok_button().disabled = true
		return
	var start_data: Array = result.data.start
	_summary.text = StudioText.f(
		"area_summary",
		[size.x, size.y, size.x * size.y, int(start_data[0]), int(start_data[1]), StudioText.t("area_face_" + facing), ground_kind.replace("_", " ")]
	)
	get_ok_button().disabled = false


func _confirm() -> void:
	_plan()
	if get_ok_button().disabled:
		return
	var size := Vector2i(int(_width.value), int(_height.value))
	var kind := _grounds[clampi(_ground.selected, 0, _grounds.size() - 1)] if not _grounds.is_empty() else ""
	var start := Vector2i(int(_start_x.value), int(_start_y.value))
	var facing := _facings[clampi(_facing.selected, 0, _facings.size() - 1)]
	var result := StudioAreaFactory.create_data(_id_field.text, _name_field.text, size, kind, _studio.catalog().terrain, start, facing)
	if not bool(result.get("ok", false)):
		_summary.text = String(result.get("error", StudioText.t("area_invalid")))
		get_ok_button().disabled = true
		return
	if not _studio.work.create_map(_id_field.text, result.data):
		_summary.text = StudioText.t("area_create_failed")
		get_ok_button().disabled = true
		return
	hide()
	if _studio.go_to_map(_id_field.text):
		_studio.set_tab("land")
		_studio.say(StudioText.f("area_created", [_name_field.text.strip_edges()]), false)


func _set_start_limits() -> void:
	_start_x.max_value = int(_width.value) - 1
	_start_y.max_value = int(_height.value) - 1
	_start_x.set_value_no_signal(minf(_start_x.value, _start_x.max_value))
	_start_y.set_value_no_signal(minf(_start_y.value, _start_y.max_value))
