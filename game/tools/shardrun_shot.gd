extends Control
## A run set up for a screenshot, then the run screen over it. ROOTWARD_SHOT picks the moment:
##   map (default), fight, table (a Shardrun hand half played), cast, volley (the bolts, without the code), storm (a
##   heavy spark spell on two foes: lightning called down), turn, reward, treasure, rest, forge, end, code,
##   dev (a sandbox run with its tools open), and for the program Shardrun: draft (the paradigms), pack (a draft
##   pack), write (a card played into the Program, its code mid-rune; use ROOTWARD_SHOT_AFTER_MS), race (a foe quicker
##   than the Program acts first)
## ROOTWARD_SHOT_PARADIGM picks the paradigm a program run drafts (when it is offered).
## It plays in its own save folder, so the player's run is never touched:
##   ROOTWARD_SHOT=cast scripts/screenshot.sh res://tools/shardrun_shot.tscn shots/cast.png 90
## ROOTWARD_SHOT_SKIN wears a battle skin for the shot (not saved). ROOTWARD_SHOT_AFTER_MS catches the moment that many
## milliseconds after the action, in real time (a headless run draws frames far faster than 60 a second):
##   ROOTWARD_SHOT=volley ROOTWARD_SHOT_SKIN=vesper ROOTWARD_SHOT_AFTER_MS=700 scripts/screenshot.sh \
##       res://tools/shardrun_shot.tscn shots/vesper-volley.png 1

signal shot_ready

const SAVES := "user://shot-saves"


func _ready() -> void:
	var shot := OS.get_environment("ROOTWARD_SHOT")
	var language := OS.get_environment("ROOTWARD_SHOT_LANGUAGE")
	Game.reset(SAVES)
	Game.boot()
	# ROOTWARD_SHOT_PLAYSTYLE=spellbook shows Spellforge, =deck the card Shardrun; the program Shardrun otherwise.
	var playstyle := OS.get_environment("ROOTWARD_SHOT_PLAYSTYLE")
	Game.use(playstyle if playstyle != "" else "program")
	var session := Game.session
	session.saves.delete_run("spellbook")
	session.start(language if language != "" else "python", "beginner", "screenshot", shot == "dev")
	var bot := ShardrunBot.new(session)
	bot.paradigm = OS.get_environment("ROOTWARD_SHOT_PARADIGM")
	match shot:
		"draft":
			pass
		"pack":
			await bot.send(await bot.next_command())
		"write":
			# Two cards already in the Program; the shot plays a third and catches its code being written.
			await bot.play_until("battle")
			var table := CardTable.of(session.state, session.catalog)
			for i in 2:
				table = CardTable.tap(table, {"zone": "hand", "index": 0}, table.spells[0].id)
			await bot.send(CardTable.command(table))
		"boss":
			session.start(language if language != "" else "python", "beginner", "screenshot", true)
			await bot.play_until("battle")
			await bot.send({"type": "dev-spawn", "kind": "boss", "foes": ["kiln-warden"]})
		"race":
			# A program slower than a race-condition imp (tempo 16): the imp strikes before the bolts land.
			session.start(language if language != "" else "python", "beginner", "screenshot", true)
			await bot.play_until("battle")
			await bot.send({"type": "dev-spawn", "kind": "fight", "foes": ["race-condition-imp", "tally-wisp"]})
			await bot.send(bot._deal_hand(session.state))
		"storm":
			# A heavy spark spell against two foes: lightning called down on both, a wave across the floor.
			session.start(language if language != "" else "python", "beginner", "screenshot", true)
			await bot.play_until("battle")
			await bot.send({"type": "dev-spawn", "kind": "fight", "foes": ["tally-wisp", "off-by-one-goblin"]})
			for shard: String in ["arc", "fork", "fork", "scatter"]:
				await bot.send({"type": "dev-grant-shard", "shard_id": shard})
			var table := CardTable.of(session.state, session.catalog)
			var spell: Dictionary = table.spells[0]
			spell.shards = ["arc", "fork", "fork", "scatter"]
			for shard: String in spell.shards:
				(table.hand as Array).erase(shard)
			await bot.send(CardTable.command(table))
		"fight", "cast", "volley", "turn", "code", "dev", "table", "pile":
			await bot.play_until("battle")
			if ShardrunRules.is_deck(session.state) and shot in ["cast", "volley", "code"]:
				await bot.send(bot._deal_hand(session.state))
			elif ShardrunRules.is_deck(session.state) and shot == "table":
				# Two cards played into the first spell, the rest still in hand.
				var table := CardTable.of(session.state, session.catalog)
				for i in 2:
					table = CardTable.tap(table, {"zone": "hand", "index": 0}, table.spells[0].id)
				await bot.send(CardTable.command(table))
		"reward":
			await bot.play_until("reward")
		"treasure":
			bot.prefer = "treasure"
			await bot.play_until("reward", 200)
			while session.in_progress() and not (session.state.get("reward", {}) as Dictionary).has("chest"):
				await bot.send(bot._reward_move(session.state))
				await bot.play_until("reward", bot.steps + 200)
		"rest", "forge":
			bot.prefer = shot
			await bot.play_until(shot, 200)
		"end":
			await bot.play(2000)
		"map":
			await bot.play_until("reward")
			await bot.send(bot._reward_move(session.state))
			await bot.play_until("map", 10)
	var skin := OS.get_environment("ROOTWARD_SHOT_SKIN")
	if skin in Settings.CHARACTER_SKINS:
		Settings.character_skin = skin
	var screen: Control = (load(Game.SHARDRUN) as PackedScene).instantiate()
	add_child(screen)
	for i in 10:
		await get_tree().process_frame
	var after_ms := int(OS.get_environment("ROOTWARD_SHOT_AFTER_MS"))
	if after_ms > 0:
		_act(shot, screen)
		await get_tree().create_timer(after_ms / 1000.0).timeout
		set_meta("shot_ready", true)
		shot_ready.emit()
		return
	set_meta("shot_ready", true)
	shot_ready.emit()
	_act(shot, screen)


func _act(shot: String, screen: Control) -> void:
	match shot:
		"cast":
			Settings.code_speed = "normal"
			screen.call("send", {"type": "cast", "spell_id": "spell-1"})
		"volley", "storm", "race":
			# ROOTWARD_SHOT_SPELL picks the spell (spell-2 is the Ward).
			Settings.code_speed = "off"
			var spell := OS.get_environment("ROOTWARD_SHOT_SPELL")
			screen.call("send", {"type": "cast", "spell_id": spell if spell != "" else "spell-1"})
		"turn":
			screen.call("send", {"type": "end-turn"})
		"write":
			var session := Game.session
			var table := CardTable.of(session.state, session.catalog)
			table = CardTable.tap(table, {"zone": "hand", "index": 0}, table.spells[0].id)
			screen.call("send", CardTable.command(table))
		"code":
			screen.call("_explore", "spell-1")
		"dev":
			screen.call("_open_dev")
		"pile":
			var fight := screen.get("_fight") as FightView
			if fight != null:
				var table := fight.get("_table") as DeckTable
				if table != null:
					table.call("_open_pile", "draw")
