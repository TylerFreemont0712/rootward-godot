class_name SpellCard
extends PanelContainer
## One spell in a fight: its shards in the order they run, what it will do (when the difficulty and the options say
## so), its price, and Cast. The numbers come from the very sandbox run the cast will use.

signal cast_pressed(spell_id: String)
signal code_pressed(spell_id: String)

var spell: Dictionary = {}
## Its place in the book, and the key that casts it.
var number := 1
var _cost: Label
var _preview: Label
var _cast: Button
var _code: Button


static func create(index: int, run_spell: Dictionary, catalog: Dictionary) -> SpellCard:
	var card := SpellCard.new()
	card.spell = run_spell
	card.number = index
	card.theme_type_variation = "Card"
	card._build(index, catalog)
	return card


func _build(index: int, catalog: Dictionary) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := Ui.panel(Ui.label(str(index), "Faint"), "Chip")
	_cost = Ui.tint(Ui.label("", "Subheading"), UiTheme.SHARD) as Label
	var header := Ui.hbox([badge, Ui.label(spell.name, "Subheading"), Ui.spacer(), _cost], 8)
	var chain := Ui.flow([], 4)
	chain.add_child(Ui.tint(Ui.label("●", "Muted"), UiTheme.ELEMENTS.none))
	for shard_id: String in spell.shards:
		var shard: Dictionary = catalog.shards.get(shard_id, {})
		chain.add_child(Ui.label("→", "Faint"))
		var chip := Ui.hbox(
			[Ui.picture("shardrun/shard-" + shard_id, Vector2(20, 20), "◆"), Ui.label(shard.get("name", shard_id))], 4
		)
		var holder := Ui.panel(chip, "Chip")
		holder.tooltip_text = "%s · %s" % [shard.get("name", shard_id), ShardrunViews.complexity(shard)]
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		chain.add_child(holder)
	if (spell.shards as Array).is_empty():
		chain.add_child(Ui.label("one plain bolt", "Faint"))
	_preview = Ui.label("Reading the shards…", "Muted", true)
	_code = Ui.button("</> Code", func() -> void: code_pressed.emit(spell.id))
	_cast = Ui.button("Cast  [%d]" % index, func() -> void: cast_pressed.emit(spell.id), "PrimaryButton")
	_cast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(Ui.vbox([header, chain, _preview, Ui.hbox([_code, _cast], 8)], 8))


## Shows a run view (ShardrunViews.spell_run_view), or {} while it is still running. `spent` greys the card out.
func show_preview(view: Dictionary, spent: bool, mana: int) -> void:
	_cast.disabled = spent
	if view.is_empty():
		_cost.text = ""
		_preview.text = "Reading the shards…"
		_preview.remove_theme_color_override("font_color")
		_cast.text = "Spent this turn" if spent else "Cast  [%d]" % number
		return
	var cost := int(view.cost)
	_cost.text = "%d ◆" % cost
	if spent:
		_cast.text = "Spent this turn"
	elif cost > mana:
		_cast.text = "Needs %d mana" % cost
		_cast.disabled = true
	else:
		_cast.text = "Cast  [%d]" % number
	if view.has("misfire"):
		_preview.text = "Misfire: %s" % view.misfire.reason
		_preview.add_theme_color_override("font_color", UiTheme.FAIL)
		return
	_preview.remove_theme_color_override("font_color")
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


func set_busy(busy: bool) -> void:
	_cast.disabled = busy or _cast.text.begins_with("Spent") or _cast.text.begins_with("Needs")
	_code.disabled = busy
