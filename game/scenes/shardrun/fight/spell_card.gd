class_name SpellCard
extends PanelContainer
## One spell in a fight: its shards in the order they run, what it will do (when the difficulty and the options say
## so), its price, and Cast. The numbers come from the very sandbox run the cast will use.

signal cast_pressed(spell_id: String)
signal code_pressed(spell_id: String)

var spell: Dictionary = {}
## Its place in the book, and the key that casts it.
var number := 1
## What the cast button says when it is ready ("▶ python program.py" for a Program); "" for "Cast [n]".
var run_label := ""
var _cost: Label
var _preview: Label
var _cast: Button
var _code: Button
var _chain: Control
var _header: HBoxContainer
var _side: VBoxContainer
var _busy := false
var _spent := false
var _affordable := true


static func create(index: int, run_spell: Dictionary, catalog: Dictionary) -> SpellCard:
	var card := SpellCard.new()
	card.spell = run_spell
	card.number = index
	card._build(index, catalog)
	card.set_targeted(false)
	return card


func _build(index: int, catalog: Dictionary) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := Ui.panel(Ui.label(str(index), "Faint"), "Chip")
	_cost = Ui.tint(Ui.label("", "Subheading"), UiTheme.SHARD) as Label
	var header := Ui.hbox([badge, Ui.label(spell.name, "Subheading"), Ui.spacer(), _cost], 8)
	_header = header
	var chain := Ui.flow([], 4)
	chain.add_child(Ui.tint(Ui.label("●", "Muted"), UiTheme.ELEMENTS.none))
	for shard_id: String in spell.shards:
		var shard: Dictionary = catalog.shards.get(shard_id, {})
		chain.add_child(Ui.label("→", "Faint"))
		var chip := Ui.hbox(
			[
				Ui.picture(ShardrunViews.art(shard, shard_id), Vector2(20, 20), "◆"),
				Ui.label(shard.get("name", shard_id))
			],
			4
		)
		var holder := Ui.panel(chip, "Chip")
		holder.tooltip_text = "%s · %s" % [shard.get("name", shard_id), ShardrunViews.complexity(shard)]
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		chain.add_child(holder)
	if (spell.shards as Array).is_empty():
		chain.add_child(Ui.label("one plain bolt", "Faint"))
	_chain = chain
	_preview = Ui.label("Reading the shards…", "Muted", true)
	_code = Ui.button("</> Code", func() -> void: code_pressed.emit(spell.id))
	_cast = Ui.button("Cast  [%d]" % index, func() -> void: cast_pressed.emit(spell.id), "PrimaryButton")
	_cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side = Ui.vbox([_preview, Ui.hbox([_code, _cast], 8)], 8)
	add_child(Ui.vbox([header, chain, _side], 8))


## Lays the spell out in a row: its cards on the left, and beside them one column with its name and price, what it will
## do, and its button. `note` (a hint, say) goes at the foot of that column.
func side_by_side(note: Control = null) -> void:
	var column := _chain.get_parent()
	var row := Ui.hbox([], 16)
	column.add_child(row)
	for part: Control in [_chain, _side]:
		part.reparent(row)
	_header.reparent(_side)
	_side.move_child(_header, 0)
	if note != null:
		_side.add_child(note)
	_chain.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_side.custom_minimum_size.x = 240
	_cast.custom_minimum_size.y = 46


## The run button reads as running the file (`label`), with the language's own mark as its icon.
func set_runner(label: String, icon: Texture2D) -> void:
	run_label = label
	_cast.text = label
	_cast.icon = icon
	_cast.add_theme_constant_override("icon_max_width", 22)
	_cast.add_theme_constant_override("h_separation", 10)


## A Shardrun spell shows card slots instead of its chain of shards (DeckTable fills them).
func set_slots(slots: Control) -> void:
	var parent := _chain.get_parent()
	var at := _chain.get_index()
	parent.remove_child(_chain)
	_chain.queue_free()
	parent.add_child(slots)
	parent.move_child(slots, at)
	_chain = slots


## The spell a click plays cards into is outlined in the shard colour. The outline is always there (in the line colour
## when not targeted), and the text keeps a margin well inside it, so targeting never moves or crowds anything.
func set_targeted(on: bool) -> void:
	var look := UiTheme.box(
		Color(0.1, 0.075, 0.07, 0.94), UiTheme.SHARD if on else UiTheme.LINE, 2, 10, Vector2(18, 14)
	)
	if on:
		look.shadow_color = Color(UiTheme.SHARD, 0.22)
		look.shadow_size = 8
	add_theme_stylebox_override("panel", look)


## Shows a run view (ShardrunViews.spell_run_view), or {} while it is still running. `spent` greys the card out.
func show_preview(view: Dictionary, spent: bool, mana: int) -> void:
	_spent = spent
	_affordable = true
	if view.is_empty():
		_cost.text = ""
		_preview.text = "Reading the shards…"
		_preview.remove_theme_color_override("font_color")
		_cast.text = "Spent this turn" if spent else _ready_text()
		_update_cast()
		return
	var cost := int(view.cost)
	_cost.text = "%d ◆" % cost
	if spent:
		_cast.text = "Spent this turn"
	elif cost > mana:
		_cast.text = "Needs %d◆" % cost
		_affordable = false
	else:
		_cast.text = _ready_text()
	_update_cast()
	if view.has("misfire"):
		_preview.text = "Misfire: %s" % view.misfire.reason
		_preview.add_theme_color_override("font_color", UiTheme.FAIL)
		return
	_preview.remove_theme_color_override("font_color")
	if view.get("program", false):
		_show_program(view)
		return
	if not view.has("result"):
		_preview.text = "Predictions hidden: read its code, or cast it and watch."
		return
	var result: Dictionary = view.result
	var bolts := int(result.bolts)
	var parts: Array[String] = ["%d %s" % [bolts, "bolt" if bolts == 1 else "bolts"]]
	if int(result.damage) > 0 or int(result.block) == 0:
		parts.append("%d damage" % int(result.damage))
	if int(result.block) > 0:
		parts.append("%d block" % int(result.block))
	if int(result.potential) > int(result.damage):
		parts.append("worth %d" % int(result.potential))
	_preview.text = " · ".join(parts)


## A program run shows its code beside the table all the time, so its spell has no Code button.
func hide_code() -> void:
	_code.hide()


## A Program's line: its speed and work, who beats it to the punch, and (if predictions show) what it will do.
func _show_program(view: Dictionary) -> void:
	if view.timeout:
		_preview.text = "Time limit exceeded: %d ops of %d. Nothing would land." % [int(view.work), int(view.budget)]
		_preview.add_theme_color_override("font_color", UiTheme.FAIL)
		return
	var parts: Array[String] = ["%s · %d ops" % [view.speed, int(view.work)]]
	var first := (view.race as Array).filter(func(entry: Dictionary) -> bool: return entry.first)
	if not first.is_empty():
		parts.append("⚡ %d %s first" % [first.size(), "foe acts" if first.size() == 1 else "foes act"])
	if view.has("result"):
		var result: Dictionary = view.result
		parts.append("%d damage" % int(result.damage))
		if int(result.block) > 0:
			parts.append("%d block" % int(result.block))
	_preview.text = " · ".join(parts)
	if not first.is_empty():
		_preview.add_theme_color_override("font_color", UiTheme.WARN)


func _ready_text() -> String:
	return run_label if run_label != "" else "Cast  [%d]" % number


func set_busy(busy: bool) -> void:
	_busy = busy
	_update_cast()
	_code.disabled = busy


func _update_cast() -> void:
	_cast.disabled = _busy or _spent or not _affordable
