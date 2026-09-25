class_name FightView
extends VBoxContainer
## A fight: the stage above, and below it the Maintainer's numbers and the spellbook. It asks for commands (`wants`)
## and plays what they did (`present`); ShardrunScreen sends them. Keys: 1 to 4 cast, E ends the turn, Space or a click
## on the stage skips ahead.

signal wants(command: Dictionary)

const LOG_COLOURS := {
	"hit": "#f2a541",
	"enemy": "#e2584f",
	"curse": "#b48cff",
	"ward": "#5cc8b8",
	"heal": "#8bc96a",
	"fizzle": "#6f5e46",
	"victory": "#8bc96a",
	"loss": "#e2584f",
}

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
var _turn: Label
var _incoming: Label
var _end_turn: Button
var _log: RichTextLabel
var _code: CodeView


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
	var bottom := Ui.hbox([_hero_panel(), _spellbook(state)], 10)
	# The spellbook takes the height its cards need (two to a row), and the stage takes the rest.
	var rows := ceili((state.spells as Array).size() / 2.0)
	bottom.custom_minimum_size.y = maxf(250.0, 20.0 + rows * 168.0)
	add_child(bottom)
	var layer := ShardrunRules.layer_of(state, session.catalog)
	var boss: bool = state.battle.kind == "boss"
	stage.set_backdrop(layer.get("boss_backdrop", layer.backdrop) if boss else layer.backdrop)
	stage.set_foes(state.battle.foes, session.catalog, true)
	show_state(state)


func _hero_panel() -> Control:
	_integrity_bar = ProgressBar.new()
	_integrity_bar.show_percentage = false
	_integrity_bar.custom_minimum_size = Vector2(0, 14)
	_integrity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_integrity = Ui.label("", "")
	_block = Ui.tint(Ui.label("", ""), UiTheme.TEAL) as Label
	_mana = Ui.tint(Ui.label("", ""), UiTheme.SHARD) as Label
	_turn = Ui.label("", "Muted")
	_incoming = Ui.tint(Ui.label("", "Muted"), UiTheme.FAIL.lightened(0.15)) as Label
	_end_turn = Ui.button("End turn  [E]", func() -> void: _ask({"type": "end-turn"}), "PrimaryButton")
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.custom_minimum_size = Vector2(0, 60)
	var integrity := Ui.hbox([Ui.label("INTEGRITY", "Faint"), _integrity_bar, _integrity], 8)
	var column := Ui.vbox([integrity, Ui.hbox([_block, Ui.spacer(), _mana]), _turn, _incoming, _end_turn, _log], 6)
	var panel := Ui.panel(column, "")
	panel.custom_minimum_size.x = 360
	return panel


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
	var mana_max := ShardrunRules.mana_per_turn(state, session.catalog)
	_mana.text = "%s  %d/%d mana" % [_pips(int(battle.mana), mana_max), int(battle.mana), mana_max]
	_turn.text = "Turn %d · %s" % [int(battle.turn), battle.kind]
	var incoming := ShardrunViews.incoming(state)
	_incoming.text = "Incoming: %d damage" % incoming if incoming > 0 else ""
	stage.show_foes(battle.foes)
	for spell: Dictionary in state.spells:
		var card: SpellCard = cards.get(spell.id)
		if card != null:
			card.show_preview(_previews.get(spell.id, {}), spell.id in battle.cast, int(battle.mana))
	set_busy(busy)


func _show_numbers(numbers: Dictionary) -> void:
	_integrity_bar.max_value = maxi(1, int(numbers.integrity_max))
	_integrity_bar.value = int(numbers.integrity)
	_integrity.text = "%d/%d" % [int(numbers.integrity), int(numbers.integrity_max)]
	_block.text = "◈ %d block" % int(numbers.block)


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
	player.numbers_changed.connect(func() -> void: _show_numbers(player.shown))
	var replay: Dictionary = result.get("replay", {})
	if not replay.is_empty() and Settings.code_speed != "off":
		var spell := Shardrun.spell_by_id(before, replay.spell_id)
		var view := _code_view(spell, replay.run, "cast")
		await view.finished
		_close_code_soon(view)
	await player.play(result.state.log)
	_write_log(player.lines)


func _explore(spell_id: String) -> void:
	var spell := Shardrun.spell_by_id(_state, spell_id)
	if spell.is_empty() or busy:
		return
	var view := _code_view(spell, _previews.get(spell_id, {}), "explore")
	await view.finished
	if is_instance_valid(view):
		view.queue_free()


func _code_view(spell: Dictionary, run: Dictionary, mode: String) -> CodeView:
	if _code != null and is_instance_valid(_code):
		_code.queue_free()
	var base := int(session.catalog.balance.base_bolt_power)
	_code = CodeView.create(session.state.language, spell, session.catalog.shards, base, run, mode, Settings.code_speed)
	stage.add_child(_code)
	# Between the Maintainer and the foes, as wide as the gap allows (never narrower than 720, so short lines stay
	# whole); with several foes it may cover the nearest while the code plays. It leaves before the bolts fly.
	var left := stage.hero.position.x + stage.hero.size.x + 16.0
	var right := stage.size.x - 16.0
	for view: FoeView in stage.foes.values():
		right = minf(right, view.position.x - 16.0)
	var width := clampf(right - left, 720.0, 1000.0)
	width = minf(width, stage.size.x - left - 16.0)
	_code.position = Vector2(left, 12)
	_code.size = Vector2(width, stage.size.y - 24)
	return _code


## A finished cast's code stays up a moment with its score, then fades while the bolts fly.
func _close_code_soon(view: CodeView) -> void:
	var tween := view.create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(view, "modulate", Color(1, 1, 1, 0), 0.4)
	tween.tween_callback(view.queue_free)


func _write_log(entries: Array[Dictionary]) -> void:
	for entry in entries:
		var colour: String = LOG_COLOURS.get(entry.kind, "#a58f6e")
		_log.append_text("[color=%s]%s[/color]\n" % [colour, String(entry.get("text", "")).replace("[", "[lb]")])


func write_entries(entries: Array) -> void:
	var typed: Array[Dictionary] = []
	typed.assign(entries)
	_write_log(typed)


func set_busy(value: bool) -> void:
	busy = value
	_end_turn.disabled = value
	for card: SpellCard in cards.values():
		card.set_busy(value)


func _ask(command: Dictionary) -> void:
	if not busy:
		wants.emit(command)


func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and busy:
		stage.fast = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE and busy:
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
