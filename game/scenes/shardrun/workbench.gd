class_name Workbench
extends VBoxContainer
## The spellbook between fights: each spell's slots in the order its shards run, and the spare shards. Drag a shard to
## move it (or click it, then click where it goes); every move is one `arrange` command (Arrangement). The inspector
## below shows the shard under the pointer: what it does, and its code.

signal wants(command: Dictionary)
signal notice(text: String)
signal explore(spell_id: String)

var session: ShardrunSession
var _picked: Dictionary = {}
var _chips: Array[ShardChip] = []
var _books: VBoxContainer
var _inspector: VBoxContainer
var _inspected := ""


static func create(run_session: ShardrunSession) -> Workbench:
	var bench := Workbench.new()
	bench.session = run_session
	bench._build()
	return bench


func _build() -> void:
	add_theme_constant_override("separation", 8)
	var hint := "Drag shards between spells and spares. "
	hint += "A spell runs its shards left to right, starting from one plain bolt."
	add_child(Ui.hbox([Ui.label("Spellbook", "Heading")], 12))
	add_child(Ui.label(hint, "Muted", true))
	_books = Ui.vbox([], 8)
	var scroll := Ui.scroll(_books)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.2
	add_child(scroll)
	_inspector = Ui.vbox([], 6)
	var inspector := Ui.scroll(_inspector)
	inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(inspector)
	show_run(session.state)


func show_run(state: Dictionary) -> void:
	_picked = {}
	_chips.clear()
	Ui.clear(_books)
	var spells: Array = state.spells
	for index in spells.size():
		_books.add_child(_spell_row(index + 1, spells[index]))
	_books.add_child(_spares(state.inventory))
	var first := _inspected
	if first == "" or not _owned(state, first):
		first = spells[0].shards[0] if not (spells[0].shards as Array).is_empty() else ""
	_inspect(first)


func _spell_row(number: int, spell: Dictionary) -> Control:
	var shards: Array = spell.shards
	var filled := "%d/%d slots" % [shards.size(), int(spell.capacity)]
	var code := Ui.button("</> Code", func() -> void: explore.emit(spell.id))
	var header := Ui.hbox(
		[
			Ui.panel(Ui.label(str(number), "Faint"), "Chip"),
			Ui.label(spell.name, "Subheading"),
			Ui.label(filled, "Faint")
		]
	)
	header.add_child(Ui.spacer())
	header.add_child(code)
	var slots := Ui.flow([], 6)
	slots.add_child(Ui.tint(Ui.label("●", "Muted"), UiTheme.ELEMENTS.none))
	for i in int(spell.capacity):
		slots.add_child(Ui.label("→", "Faint"))
		var at := {"spell": spell.id, "index": i}
		if i < shards.size():
			slots.add_child(_chip(ShardChip.filled(at, shards[i], _shard(shards[i]))))
		else:
			slots.add_child(_chip(ShardChip.empty({"spell": spell.id, "index": shards.size()})))
	return Ui.panel(Ui.vbox([header, slots], 8), "Card")


func _spares(inventory: Array) -> Control:
	var flow := Ui.flow([], 6)
	for i in inventory.size():
		flow.add_child(_chip(ShardChip.filled({"spell": "", "index": i}, inventory[i], _shard(inventory[i]))))
	flow.add_child(_chip(ShardChip.empty({"spell": "", "index": inventory.size()}, "put back here")))
	var title := "Spare shards (%d)" % inventory.size()
	return Ui.panel(Ui.vbox([Ui.label(title, "Subheading"), flow], 8), "Card")


func _chip(chip: ShardChip) -> ShardChip:
	chip.chosen.connect(_on_chosen)
	chip.dropped.connect(_move)
	chip.hovered.connect(_on_hovered)
	_chips.append(chip)
	return chip


func _on_hovered(shard_id: String) -> void:
	if _picked.is_empty():
		_inspect(shard_id)


func _on_chosen(place: Dictionary) -> void:
	var chip := _chip_at(place)
	if _picked.is_empty():
		if chip != null and chip.shard_id != "":
			_picked = place
			_inspect(chip.shard_id)
			notice.emit("Now click where %s should go." % chip.text)
		_mark()
		return
	var from := _picked
	_picked = {}
	_mark()
	if from == place:
		return
	_move(from, place, chip != null and chip.shard_id != "")


func _move(from: Dictionary, onto: Dictionary, onto_shard: bool) -> void:
	if from == onto:
		return
	var move := Arrangement.move(session.state, from, onto, onto_shard)
	if not move.ok:
		notice.emit(move.message)
		_mark()
		return
	wants.emit(move.command)


func _mark() -> void:
	for chip in _chips:
		chip.set_pressed_no_signal(not _picked.is_empty() and chip.place == _picked and chip.shard_id != "")


## The chip at a place; several empty slots of one spell share a place (the end of its list), so a filled one wins.
func _chip_at(place: Dictionary) -> ShardChip:
	var found: ShardChip = null
	for chip in _chips:
		if chip.place == place:
			if chip.shard_id != "":
				return chip
			found = chip
	return found


func _inspect(shard_id: String) -> void:
	_inspected = shard_id
	Ui.clear(_inspector)
	if shard_id == "":
		_inspector.add_child(Ui.label("Point at a shard to read it.", "Faint"))
		return
	var shard := _shard(shard_id)
	_inspector.add_child(Cards.shard(shard, session.state.language, session.show_summaries()))


func _shard(shard_id: String) -> Dictionary:
	return session.catalog.shards.get(shard_id, {"id": shard_id, "name": shard_id, "rarity": "common"})


static func _owned(state: Dictionary, shard_id: String) -> bool:
	if shard_id in state.inventory:
		return true
	for spell: Dictionary in state.spells:
		if shard_id in spell.shards:
			return true
	return false
