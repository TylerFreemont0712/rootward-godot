class_name ProgramMemoryView
extends HBoxContainer
## The Index shelf and Table are saved fight state, never a second prediction of the cast.

var _index: HBoxContainer
var _table: Label


func _init() -> void:
	add_theme_constant_override("separation", 12)
	_index = Ui.hbox([], 8)
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table = Ui.label("", "Muted")
	_table.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_table.add_theme_font_override("font", UiTheme.crt_font())
	add_child(_index)
	add_child(_table)


func show_memory(state: Dictionary, catalog: Dictionary) -> void:
	for child in _index.get_children():
		_index.remove_child(child)
		child.queue_free()
	var battle: Dictionary = state.get("battle", {})
	var m := ProgramRelics.modifiers(state, catalog)
	visible = bool(m.index) or bool(m.table)
	_index.visible = bool(m.index)
	_table.visible = bool(m.table)
	if m.index:
		_index.add_child(Ui.label(Text.t("Index"), "Faint"))
		var bank: Array = battle.get("index", [])
		for bolt: Dictionary in bank:
			var gem := Ui.label("◆ %d" % int(bolt.power), "Subheading")
			gem.add_theme_color_override("font_color", UiTheme.element(String(bolt.element)))
			_index.add_child(gem)
		if bank.is_empty():
			_index.add_child(Ui.label("[ ]", "Faint"))
		_index.tooltip_text = Text.f(
			"Sorted Index: %d / %d bolts. The seed takes the strongest.", [bank.size(), int(m.index_size)]
		)
	if m.table:
		var values: PackedStringArray = []
		for row: Variant in battle.get("dp", []):
			values.append(str(int(row)))
		_table.text = "dp = [%s]" % ", ".join(values)
		_table.tooltip_text = Text.t("The Table remembers each program's landed damage.")
