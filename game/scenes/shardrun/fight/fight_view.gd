class_name FightView
extends VBoxContainer
## A fight: the stage above, and below it the Maintainer's numbers and the spellbook. It asks for commands (`wants`)
## and plays what they did (`present`); ShardrunScreen sends them. Keys: 1 to 4 cast, E ends the turn, Space or a click
## on the stage skips ahead.

signal wants(command: Dictionary)

var session: ShardrunSession
var stage: BattleStage
var cards: Dictionary = {}
var busy := false
var _state: Dictionary = {}
var _previews: Dictionary = {}
var _integrity_bar: ProgressBar
var _integrity: Label
var _block: Label
var _mana: Label
var _incoming: Label
var _end_turn: Button
## Everything the rules logged in this fight, each with the turn it happened on, for the ".log" window.
var _entries: Array[Dictionary] = []
var _log_turn := 1
var _portrait: TextureRect
var _portrait_name: Label
var _code: CodeView
var _bottom: HBoxContainer
var _work_area: Control
var _surface: Control
## The Shardrun's hand and card slots, in a deck run; null in Spellforge.
var _table: DeckTable
## A program run's code, always in view beside the table (ADR-0012); null otherwise.
var _program: ProgramCode


static func create(run_session: ShardrunSession) -> FightView:
	var view := FightView.new()
	view.session = run_session
	view._build()
	return view


func _build() -> void:
	add_theme_constant_override("separation", 10)
	var state := session.state
	stage = BattleStage.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.gui_input.connect(_on_stage_input)
	add_child(stage)
	var bottom: HBoxContainer
	if ShardrunRules.is_deck(state):
		_table = DeckTable.create(session)
		_table.wants.connect(func(command: Dictionary) -> void: _ask(command))
		cards = _table.cards
		for card: SpellCard in cards.values():
			card.cast_pressed.connect(func(spell_id: String) -> void: _ask({"type": "cast", "spell_id": spell_id}))
			card.code_pressed.connect(_explore)
		_work_area = _table
		bottom = Ui.hbox([_hero_panel(), _make_surface(_work_area)], 10)
		if state.playstyle == "program":
			# The code is the program itself, so it is always on the table rather than behind a button.
			_program = ProgramCode.create(session)
			for card: SpellCard in cards.values():
				card.hide_code()
			bottom.add_child(_program)
	else:
		_work_area = _spellbook(state)
		bottom = Ui.hbox([_hero_panel(), _make_surface(_work_area)], 10)
		# The spellbook takes the height its cards need (two to a row), and the stage takes the rest.
		var rows := ceili((state.spells as Array).size() / 2.0)
		bottom.custom_minimum_size.y = maxf(250.0, 20.0 + rows * 168.0)
	_bottom = bottom
	add_child(bottom)
	var layer := ShardrunRules.layer_of(state, session.catalog)
	var boss: bool = state.battle.kind == "boss"
	stage.set_backdrop(layer.get("boss_backdrop", layer.backdrop) if boss else layer.backdrop)
	stage.set_foes(state.battle.foes, session.catalog, true, boss)
	show_state(state)


func _make_surface(content: Control) -> Control:
	_surface = Control.new()
	_surface.clip_contents = true
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_surface.custom_minimum_size = content.get_combined_minimum_size()
	_surface.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.minimum_size_changed.connect(
		func() -> void: _surface.custom_minimum_size = content.get_combined_minimum_size()
	)
	return _surface


## The Maintainer's panel: their portrait, End turn, and the fight's log. Their numbers stand over them on the stage
## (`_status`), and what the foes will deal over the foes.
func _hero_panel() -> Control:
	_end_turn = Ui.button("End turn  [E]", func() -> void: _ask({"type": "end-turn"}), "PrimaryButton")
	var log_button := Ui.button(".log", func() -> void: BattleLog.open(self, _entries))
	log_button.tooltip_text = "Everything that happened in this fight, turn by turn."
	log_button.add_theme_font_size_override("font_size", 13)
	log_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var column := Ui.vbox([_avatar(), _end_turn, Ui.spacer(), log_button], 8)
	(column.get_child(2) as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel := Ui.panel(column, "")
	panel.custom_minimum_size.x = 214
	stage.set_status(_status())
	_incoming = Ui.tint(Ui.label("", "Subheading"), UiTheme.FAIL.lightened(0.2)) as Label
	_incoming.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_incoming.add_theme_constant_override("outline_size", 6)
	stage.set_incoming(_incoming)
	return panel


## Integrity, block and mana in a small plate over the Maintainer's head, where the eye already is.
func _status() -> Control:
	_integrity_bar = ProgressBar.new()
	_integrity_bar.show_percentage = false
	_integrity_bar.custom_minimum_size = Vector2(150, 12)
	_integrity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_integrity_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_integrity = Ui.label("", "")
	_block = Ui.tint(Ui.label("", ""), UiTheme.TEAL) as Label
	_mana = Ui.tint(Ui.label("", ""), UiTheme.SHARD.lightened(0.15)) as Label
	for label: Label in [_integrity, _block, _mana]:
		label.add_theme_font_size_override("font_size", 14)
	var rows := Ui.vbox([Ui.hbox([_integrity_bar, _integrity], 6), Ui.hbox([_block, Ui.spacer(), _mana], 10)], 2)
	var plate := Ui.panel(rows, "")
	plate.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.05, 0.04, 0.06, 0.78), UiTheme.LINE, 1, 8, Vector2(10, 6))
	)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size.x = 250
	return plate


## The Maintainer's portrait in the look they wear: a painted bust (portraits/<skin>), or the skin's own small face.
func _avatar() -> Control:
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait.custom_minimum_size = Vector2(176, 176)
	_portrait_name = Ui.tint(Ui.label("", "Faint"), UiTheme.SHARD.lightened(0.2)) as Label
	_portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var frame := PanelContainer.new()
	var look := UiTheme.box(Color("#0e0a14"), UiTheme.SHARD.darkened(0.2), 2, 10, Vector2(3, 3))
	look.shadow_color = Color(UiTheme.SHARD, 0.25)
	look.shadow_size = 6
	frame.add_theme_stylebox_override("panel", look)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_child(_portrait)
	set_skin(Settings.character_skin)
	return Ui.vbox([frame, _portrait_name], 4)


## Shows the portrait of the look the Maintainer wears (the wardrobe can change it mid-fight).
func set_skin(id: String) -> void:
	if _portrait == null:
		return
	var texture := Art.texture("portraits/" + id)
	if texture == null:
		texture = Art.texture("sprites/%s/profile" % id)
	var local := Settings.LOCAL_SKINS + id + "/portrait.png"
	if texture == null and ResourceLoader.exists(local):
		texture = load(local) as Texture2D
	_portrait.texture = texture
	_portrait_name.text = id.to_upper()


func _spellbook(state: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var spells: Array = state.spells
	for index in spells.size():
		var card := SpellCard.create(index + 1, spells[index], session.catalog)
		card.cast_pressed.connect(func(spell_id: String) -> void: _ask({"type": "cast", "spell_id": spell_id}))
		card.code_pressed.connect(_explore)
		grid.add_child(card)
		cards[spells[index].id] = card
	var scroll := Ui.scroll(grid)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return scroll


## Draws a state's numbers: Integrity, block, mana, the foes, and which spells are spent.
func show_state(state: Dictionary) -> void:
	_state = state
	var battle: Dictionary = state.get("battle", {})
	if battle.is_empty():
		return
	_show_numbers(LogPlayer.numbers_of(state))
	var incoming := ShardrunViews.incoming(state)
	_incoming.text = "⚔ %d incoming" % incoming if incoming > 0 else ""
	stage.place_status()
	stage.show_foes(battle.foes)
	if state.get("playstyle", "") == "program":
		var tempos := {}
		for foe: Dictionary in battle.foes:
			tempos[foe.uid] = ProgramRules.tempo_of(foe, state, session.catalog)
		stage.show_tempos(tempos)
	if _table != null:
		_table.show_table(state)
	if _program != null:
		_program.show_program(state, _previews.get((state.spells as Array)[0].id, {}))
	for spell: Dictionary in state.spells:
		var card: SpellCard = cards.get(spell.id)
		if card != null:
			card.show_preview(_previews.get(spell.id, {}), spell.id in battle.cast, int(battle.mana))
	set_busy(busy)


func _show_numbers(numbers: Dictionary) -> void:
	_integrity_bar.max_value = maxi(1, int(numbers.integrity_max))
	_integrity_bar.value = int(numbers.integrity)
	_integrity.text = "%d/%d" % [int(numbers.integrity), int(numbers.integrity_max)]
	_block.text = "◈ %d" % int(numbers.block)
	var mana_max := ShardrunRules.mana_per_turn(_state, session.catalog)
	_mana.text = "%s %d/%d" % [_pips(int(numbers.mana), mana_max), int(numbers.mana), mana_max]


static func _pips(mana: int, most: int) -> String:
	var pips := ""
	for i in mini(most, 12):
		pips += "◆" if i < mana else "◇"
	return pips


## Draws the session's state at once, with the spells still reading, then fetches their previews from the sandbox (in
## the background) and shows them, unless the fight moved on in the meantime.
func refresh_previews() -> void:
	_previews = {}
	show_state(session.state)
	var revision: int = session.state.get("revision", 0)
	var previews: Dictionary = await session.previews(Settings.predictions)
	if not is_inside_tree() or previews.get("revision", -1) != revision or session.state.revision != revision:
		return
	_previews = previews.spells
	show_state(session.state)


## Plays what a command did: a cast's code first (at the chosen speed), then its log on the stage.
func present(result: Dictionary) -> void:
	stage.fast = false
	var before: Dictionary = result.before
	var player := LogPlayer.new(stage, before)
	for spell: Dictionary in before.get("spells", []):
		var cards: Array[Dictionary] = []
		for id: String in spell.shards:
			cards.append(session.catalog.shards.get(id, {"id": id}))
		player.cast_cards[spell.id] = cards
	player.numbers_changed.connect(func() -> void: _show_numbers(player.shown))
	var replay: Dictionary = result.get("replay", {})
	var entries: Array = result.state.log
	player.configure_replay(before, replay, session.catalog, entries)
	var construction := not replay.is_empty() and Settings.code_speed != "off" and player.uses_construction(entries)
	if construction:
		player.begin_construction(String(replay.spell_id), player.replay_element)
	if not replay.is_empty() and _program != null:
		# The optional circle is part of the code walk, so keep its stage readable while each call finishes.
		stage.dim(0.12 if construction else 0.45, 0.25)
		if construction:
			_program.shard_resolved.connect(player.resolve_shard)
			_program.import_resolved.connect(player.resolve_import)
		await _program.play_cast(replay.run, Settings.code_speed, construction)
		if construction:
			_program.shard_resolved.disconnect(player.resolve_shard)
			_program.import_resolved.disconnect(player.resolve_import)
		stage.dim(0.0, 0.25)
	elif not replay.is_empty() and Settings.code_speed != "off":
		var spell := Shardrun.spell_by_id(before, replay.spell_id)
		var view := _code_view(spell, replay.run, "cast")
		if construction:
			view.shard_resolved.connect(player.resolve_shard)
		await view.finished
		if construction:
			view.shard_resolved.disconnect(player.resolve_shard)
		_close_code(view)
	await player.play(entries)
	_write_log(player.lines)


func _explore(spell_id: String) -> void:
	var spell := Shardrun.spell_by_id(_state, spell_id)
	if spell.is_empty() or busy:
		return
	var view := _code_view(spell, _previews.get(spell_id, {}), "explore")
	await view.finished
	_close_code(view)


func _code_view(spell: Dictionary, run: Dictionary, mode: String) -> CodeView:
	if _code != null and is_instance_valid(_code):
		_code.queue_free()
	var base := int(session.catalog.balance.base_bolt_power)
	_code = CodeView.create(session.state.language, spell, session.catalog.shards, base, run, mode, Settings.code_speed)
	# Keep the lower work surface's measured height while its contents change. A changing minimum height used to
	# resize the arena during a cast, which looked like the camera slingshotting before the effect landed.
	_bottom.custom_minimum_size.y = maxf(_bottom.size.y, _bottom.get_combined_minimum_size().y)
	_work_area.hide()
	_surface.add_child(_code)
	_code.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return _code


## Code lives on the work surface below the stage. Restore the cards before the spell animation begins.
func _close_code(view: CodeView) -> void:
	if is_instance_valid(view):
		_surface.remove_child(view)
		view.queue_free()
	_work_area.show()


func _write_log(entries: Array[Dictionary]) -> void:
	for entry in entries:
		if entry.kind == "turn":
			_log_turn = int(entry.get("amount", _log_turn + 1))
		var kept := entry.duplicate()
		kept.turn_number = _log_turn
		_entries.append(kept)


func write_entries(entries: Array) -> void:
	var typed: Array[Dictionary] = []
	typed.assign(entries)
	_write_log(typed)


func set_busy(value: bool) -> void:
	busy = value
	_end_turn.disabled = value
	if _table != null:
		_table.set_busy(value)
	for card: SpellCard in cards.values():
		card.set_busy(value)


func _ask(command: Dictionary) -> void:
	if not busy:
		wants.emit(command)


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and busy:
		if _program != null:
			_program.skip()
			stage.fast = true
		elif _code != null and is_instance_valid(_code) and _code.mode == "cast" and _code.is_inside_tree():
			_code.skip()
		else:
			stage.fast = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE and busy:
		if _program != null:
			_program.skip()
			stage.fast = true
		elif _code != null and is_instance_valid(_code) and _code.mode == "cast" and _code.is_inside_tree():
			_code.skip()
		else:
			stage.fast = true
		return
	if busy:
		return
	if key.keycode == KEY_E:
		_ask({"type": "end-turn"})
	elif key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index := key.keycode - KEY_1
		var spells: Array = _state.get("spells", [])
		if index < spells.size():
			_ask({"type": "cast", "spell_id": spells[index].id})
