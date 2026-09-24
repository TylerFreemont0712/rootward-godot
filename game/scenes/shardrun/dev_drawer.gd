class_name DevDrawer
extends PanelContainer
## The tools of a sandbox run (old ADR-0013): grant or remove any shard and relic, set Integrity and mana, spawn any
## foes, end a fight, jump to a layer, add a spell. Each is a dev command the rules check like any other (ShardrunDev);
## a run that is not a sandbox refuses them all. For trying a build or a foe without playing up to it.

signal wants(command: Dictionary)
signal closed

const KINDS: Array[String] = ["fight", "elite", "boss"]

var session: ShardrunSession
var _shard: OptionButton
var _relic: OptionButton
var _foe: OptionButton
var _count: SpinBox
var _kind: OptionButton
var _integrity: SpinBox
var _mana: SpinBox
var _layer: OptionButton
var _spell_name: LineEdit
var _capacity: SpinBox


static func create(run_session: ShardrunSession) -> DevDrawer:
	var drawer := DevDrawer.new()
	drawer.session = run_session
	drawer.theme_type_variation = "Overlay"
	drawer._build()
	return drawer


func _build() -> void:
	custom_minimum_size = Vector2(760, 0)
	var catalog := session.catalog
	var state := session.state
	var close := Ui.button("Close", func() -> void: closed.emit())
	var column := Ui.vbox([Ui.hbox([Ui.label("Sandbox tools", "Heading"), Ui.spacer(), close])], 12)
	column.add_child(Ui.label("A sandbox run scores like any other, but nothing here is a rule you earned.", "Faint"))

	_shard = _options(ShardrunCatalog.sorted_values(catalog.shards), "name")
	var grant_shard := func() -> void: _ask({"type": "dev-grant-shard", "shard_id": _picked(_shard)})
	var remove_shard := func() -> void: _ask({"type": "dev-remove-shard", "shard_id": _picked(_shard)})
	column.add_child(_row("Shard", [_shard, Ui.button("Grant", grant_shard), Ui.button("Remove", remove_shard)]))

	_relic = _options(ShardrunCatalog.sorted_values(catalog.relics), "name")
	var grant_relic := func() -> void: _ask({"type": "dev-grant-relic", "relic_id": _picked(_relic)})
	var remove_relic := func() -> void: _ask({"type": "dev-remove-relic", "relic_id": _picked(_relic)})
	column.add_child(_row("Relic", [_relic, Ui.button("Grant", grant_relic), Ui.button("Remove", remove_relic)]))

	_integrity = _number(0, int(state.integrity_max), int(state.integrity))
	var set_integrity := func() -> void: _ask({"type": "dev-set", "integrity": int(_integrity.value)})
	var numbers: Array = [_integrity, Ui.button("Set Integrity", set_integrity)]
	if state.has("battle"):
		_mana = _number(0, 99, int(state.battle.mana))
		numbers.append_array(
			[_mana, Ui.button("Set mana", func() -> void: _ask({"type": "dev-set", "mana": int(_mana.value)}))]
		)
	column.add_child(_row("Numbers", numbers))

	var foes := ShardrunCatalog.sorted_values(catalog.foes)
	foes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.hp) < float(b.hp))
	_foe = _options(foes, "name")
	_count = _number(1, 3, 1)
	_kind = OptionButton.new()
	for kind in KINDS:
		_kind.add_item(kind)
	var spawn := func() -> void:
		var ids: Array = []
		for i in int(_count.value):
			ids.append(_picked(_foe))
		_ask({"type": "dev-spawn", "kind": KINDS[_kind.selected], "foes": ids})
	column.add_child(_row("Spawn", [_foe, Ui.label("×", "Muted"), _count, _kind, Ui.button("Spawn", spawn)]))

	if state.has("battle"):
		var win := func() -> void: _ask({"type": "dev-end-battle", "outcome": "win"})
		var lose := func() -> void: _ask({"type": "dev-end-battle", "outcome": "lose"})
		column.add_child(
			_row("Fight", [Ui.button("Win it", win, "PrimaryButton"), Ui.button("Lose it", lose, "DangerButton")])
		)

	_layer = _options(catalog.config.layers, "name")
	_layer.selected = int(state.layer)
	var go := func() -> void: _ask({"type": "dev-goto-layer", "layer": _layer.selected})
	column.add_child(_row("Layer", [_layer, Ui.button("Go there", go)]))

	_spell_name = LineEdit.new()
	_spell_name.text = "Test"
	_spell_name.custom_minimum_size.x = 160
	_capacity = _number(1, int(catalog.balance.max_spell_capacity), 4)
	var add := func() -> void:
		_ask({"type": "dev-grant-spell", "name": _spell_name.text, "capacity": int(_capacity.value)})
	column.add_child(_row("Spell", [_spell_name, _capacity, Ui.button("Add a spell", add)]))
	add_child(column)


func _ask(command: Dictionary) -> void:
	wants.emit(command)


func _row(title: String, controls: Array) -> Control:
	var label := Ui.label(title, "Muted")
	label.custom_minimum_size.x = 90
	var row := Ui.hbox([label], 8)
	for control: Control in controls:
		row.add_child(control)
	return row


## A drop-down of content items by `field`, each remembering its id.
static func _options(items: Array, field: String) -> OptionButton:
	var button := OptionButton.new()
	button.custom_minimum_size.x = 240
	for item: Dictionary in items:
		button.add_item(String(item.get(field, item.get("id", "?"))))
		button.set_item_metadata(button.item_count - 1, item.get("id", ""))
	return button


static func _picked(button: OptionButton) -> String:
	return String(button.get_item_metadata(button.selected)) if button.selected >= 0 else ""


static func _number(low: int, high: int, value: int) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.value = value
	box.custom_minimum_size.x = 90
	return box
