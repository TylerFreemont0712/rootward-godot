extends GdUnitTestSuite
## A cast played on the stage in real time, the way a player sees it: every hit of its volley must reach the bars before
## the playback moves on. It guards the "foe left at a tenth of its HP until the end" bug: in a heavy cast, bolts
## launched after the falling blow on their foe had freed itself died on a type check against the freed animation, so
## their damage never showed and only the final redraw revealed the truth.

const ROOT := "user://test-playback-saves"

var screen: ShardrunScreen
var _played := false


func before_test() -> void:
	BattleStage.instant = false
	Game.reset(ROOT)
	Game.boot()
	Settings.code_speed = "off"
	Game.use("program")
	Game.session.saves.delete_run("program")
	Game.session.start(SandboxJob.JAVASCRIPT, "beginner", "playback-test", true)


func after_test() -> void:
	Background.finish_all()
	if is_instance_valid(screen):
		screen.queue_free()
	Game.session.saves.delete_run("program")
	Game.reset()


## Into a fight against a Fork Bomb with a long heavy program in main.py, on screen; returns the fight view.
func _ready_to_cast() -> FightView:
	var session := Game.session
	var bot := ShardrunBot.new(session)
	await bot.play_until("battle")
	await bot.send({"type": "dev-spawn", "kind": "fight", "foes": ["fork-bomb"]})
	var cards := ["salvo", "fork", "round-robin"]
	for id: String in cards:
		await bot.send({"type": "dev-grant-shard", "shard_id": id})
	await bot.send({"type": "dev-set", "mana": 9})
	var table := CardTable.of(session.state, session.catalog)
	table.spells[0].shards = cards.duplicate()
	for id: String in cards:
		(table.hand as Array).erase(id)
	await bot.send(CardTable.command(table))
	screen = (load(Game.SHARDRUN) as PackedScene).instantiate() as ShardrunScreen
	add_child(screen)
	await get_tree().process_frame
	return screen.get("_fight") as FightView


func _play(player: LogPlayer, entries: Array) -> void:
	await player.play(entries)
	_played = true


func _assert_bars_match(player: LogPlayer, result: Dictionary) -> void:
	for foe: Dictionary in result.state.battle.foes:
		var shown := int(player.shown.foes[foe.uid].hp)
		(
			assert_int(shown)
			. override_failure_message("the bar shows %d, the rules dealt it down to %d" % [shown, int(foe.hp)])
			. is_equal(int(foe.hp))
		)


func test_every_hit_of_a_long_heavy_volley_reaches_the_bar() -> void:
	var fight := await _ready_to_cast()
	var result: Dictionary = await Game.session.command({"type": "cast", "spell_id": "spell-1"})
	var hits := (result.state.log as Array).filter(func(entry: Dictionary) -> bool: return entry.kind == "hit")
	# Long enough that its last bolts launch after the first falling blow has played out and freed itself.
	assert_int(hits.size()).is_greater_equal(16)
	var player := LogPlayer.new(fight.stage, result.before)
	await player.play(result.state.log)
	_assert_bars_match(player, result)


func test_skipping_in_the_middle_of_a_volley_still_lands_every_hit_first() -> void:
	var fight := await _ready_to_cast()
	var result: Dictionary = await Game.session.command({"type": "cast", "spell_id": "spell-1"})
	var player := LogPlayer.new(fight.stage, result.before)
	_played = false
	_play(player, result.state.log)
	# The player clicks while bolts are in the air: the rest play at once, and the ones flying still land first.
	await get_tree().create_timer(2.0).timeout
	fight.stage.fast = true
	var give_up := Time.get_ticks_msec() + 15000
	while not _played and Time.get_ticks_msec() < give_up:
		await get_tree().process_frame
	assert_bool(_played).is_true()
	_assert_bars_match(player, result)


func test_the_cast_writes_the_circle_of_its_shards_a_layer_for_each() -> void:
	var fight := await _ready_to_cast()
	var result: Dictionary = await Game.session.command({"type": "cast", "spell_id": "spell-1"})
	var player := LogPlayer.new(fight.stage, result.before)
	for spell: Dictionary in result.before.get("spells", []):
		var cards: Array[Dictionary] = []
		for id: String in spell.shards:
			cards.append(Game.session.catalog.shards.get(id, {"id": id}))
		player.cast_cards[spell.id] = cards
	_played = false
	_play(player, result.state.log)
	var circle: MagicCircle = null
	var give_up := Time.get_ticks_msec() + 5000
	while circle == null and Time.get_ticks_msec() < give_up:
		await get_tree().process_frame
		for node: Node in fight.stage._fx.get_children():
			if node is MagicCircle:
				circle = node as MagicCircle
	assert_object(circle).is_not_null()
	# Three cards (salvo, fork, round-robin): the second tier, three layers, whatever the volley deals.
	assert_int(circle.tier).is_equal(1)
	assert_int(circle.layers.size()).is_equal(3)
	(
		assert_array(circle.layers.map(func(layer: Dictionary) -> String: return layer.id))
		. is_equal(["salvo", "fork", "round-robin"])
	)
	fight.stage.fast = true
	give_up = Time.get_ticks_msec() + 15000
	while not _played and Time.get_ticks_msec() < give_up:
		await get_tree().process_frame
	assert_bool(_played).is_true()
