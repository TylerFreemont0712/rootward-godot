extends Control
## A run set up for a screenshot, then the run screen over it. ROOTWARD_SHOT picks the moment:
##   map (default), fight, table (a Shardrun hand half played), cast, volley (the bolts, without the code), storm (a
##   heavy spark spell on two foes: lightning called down), turn, reward, treasure, rest, forge, end, code,
##   dev (a sandbox run with its tools open), and for the program Shardrun: draft (the paradigms), pack (a draft
##   pack), write (a card played into the Program, its code mid-rune; use ROOTWARD_SHOT_AFTER_MS), race (a foe quicker
##   than the Program acts first), hover (a hand card pointed at, with its details), log (the ".log" window), relics
##   (a guardian's tiered relics offered), gitlog (the run history as `git log`, from sample finished runs), layer (a
##   sandbox run jumped to ROOTWARD_SHOT_LAYER, the deepest by default: its map, or a fight there with the foes below).
##   ROOTWARD_SHOT_SCROLL holds a map shot's view that many pixels down its layer (0: the guardian at the top);
##   ROOTWARD_SHOT_DRAWER=closed folds its route drawer, ROOTWARD_SHOT_DECK=1 opens the deck over it, and
##   ROOTWARD_SHOT_TURNS ends that many turns of a fight first
## ROOTWARD_SHOT_PARADIGM picks the paradigm a program run drafts (when it is offered). ROOTWARD_SHOT_CARDS (ids, comma
## separated) makes a fight's Program exactly those cards, in a sandbox run with mana to spare; ROOTWARD_SHOT_RELICS
## (ids) grants those relics first, in such a run (the header's relics, rung by tier). ROOTWARD_SHOT_FOES (ids) puts
## those foes in the fight instead (ROOTWARD_SHOT_KIND: fight, elite or boss), and ROOTWARD_SHOT_HAND (ids) adds those
## cards to the hand:
##   ROOTWARD_SHOT=fight ROOTWARD_SHOT_KIND=boss ROOTWARD_SHOT_FOES=deadlock-lock-a,deadlock-lock-b \
##       ROOTWARD_SHOT_CARDS=salvo,merge-strike scripts/screenshot.sh res://tools/shardrun_shot.tscn shots/locks.png 60
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
	if shot == "trial":
		await _show_trial(language)
		return
	# ROOTWARD_SHOT_PLAYSTYLE=spellbook shows Spellforge, =deck the card Shardrun; the program Shardrun otherwise.
	var playstyle := OS.get_environment("ROOTWARD_SHOT_PLAYSTYLE")
	Game.use(playstyle if playstyle != "" else "program")
	var session := Game.session
	session.saves.delete_run("spellbook")
	var chosen := OS.get_environment("ROOTWARD_SHOT_CARDS")
	# The dev commands that set a shot up need a sandbox run.
	var staged := chosen != "" or OS.get_environment("ROOTWARD_SHOT_FOES") != ""
	staged = staged or OS.get_environment("ROOTWARD_SHOT_HAND") != ""
	staged = staged or OS.get_environment("ROOTWARD_SHOT_RELICS") != ""
	session.start(language if language != "" else "python", "beginner", "screenshot", shot == "dev" or staged)
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
		"fight", "cast", "volley", "turn", "code", "dev", "table", "pile", "hover", "log", "enemy_tip", "relic_tip":
			await bot.play_until("battle")
			var foes := OS.get_environment("ROOTWARD_SHOT_FOES").split(",", false)
			if not foes.is_empty():
				var kind := OS.get_environment("ROOTWARD_SHOT_KIND")
				await bot.send({"type": "dev-spawn", "kind": kind if kind != "" else "fight", "foes": Array(foes)})
			for id in OS.get_environment("ROOTWARD_SHOT_HAND").split(",", false):
				await bot.send({"type": "dev-grant-shard", "shard_id": id})
			if chosen != "":
				var ids := chosen.split(",", false)
				for id in ids:
					await bot.send({"type": "dev-grant-shard", "shard_id": id})
				await bot.send({"type": "dev-set", "mana": 9})
				var table := CardTable.of(session.state, session.catalog)
				var spell: Dictionary = table.spells[0]
				spell.shards = Array(ids)
				for id in ids:
					(table.hand as Array).erase(id)
				await bot.send(CardTable.command(table))
			elif ShardrunRules.is_deck(session.state) and shot in ["cast", "volley", "code"]:
				await bot.send(bot._deal_hand(session.state))
			elif ShardrunRules.is_deck(session.state) and shot == "log":
				# A whole turn played, so the log has a cast, the foes' answer and the next turn in it.
				await bot.send(bot._deal_hand(session.state))
				await bot.send({"type": "cast", "spell_id": "spell-1"})
			elif ShardrunRules.is_deck(session.state) and shot in ["table", "hover"]:
				# Two cards played into the first spell, the rest still in hand.
				var table := CardTable.of(session.state, session.catalog)
				for i in 2:
					table = CardTable.tap(table, {"zone": "hand", "index": 0}, table.spells[0].id)
				await bot.send(CardTable.command(table))
		"layer":
			# A sandbox run jumped to a layer (ROOTWARD_SHOT_LAYER, 0 first; the deepest by default) and its map, or
			# with ROOTWARD_SHOT_FOES a fight there (ROOTWARD_SHOT_KIND).
			session.start(language if language != "" else "python", "beginner", "screenshot", true)
			await bot.play_until("battle")
			var depth := (session.catalog.config.layers as Array).size() - 1
			var layer := (
				int(OS.get_environment("ROOTWARD_SHOT_LAYER")) if OS.has_environment("ROOTWARD_SHOT_LAYER") else depth
			)
			await bot.send({"type": "dev-goto-layer", "layer": layer})
			var foes := OS.get_environment("ROOTWARD_SHOT_FOES").split(",", false)
			if not foes.is_empty():
				var kind := OS.get_environment("ROOTWARD_SHOT_KIND")
				await bot.send({"type": "dev-spawn", "kind": kind if kind != "" else "fight", "foes": Array(foes)})
		"reward":
			await bot.play_until("reward")
		"relics":
			# A guardian beaten in a sandbox run: its reward offers epic and legendary relics.
			session.start(language if language != "" else "python", "beginner", "screenshot", true)
			await bot.play_until("battle")
			await bot.send({"type": "dev-spawn", "kind": "boss", "foes": ["kiln-warden"]})
			await bot.send({"type": "dev-end-battle", "outcome": "win"})
		"gitlog":
			_show_git_log(session)
			return
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
	if session.state.get("sandbox", false):
		for relic_id in OS.get_environment("ROOTWARD_SHOT_RELICS").split(",", false):
			await bot.send({"type": "dev-grant-relic", "relic_id": relic_id})
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


## ROOTWARD_SHOT=trial plays real commands up to ROOTWARD_SHOT_TRIAL_STEP, then captures its chapter or lesson.
func _show_trial(language: String) -> void:
	Game.profile.preferred_language = "ja" if language == "ja" else "en"
	Game.profiles.save_profile(Game.profile)
	var target := OS.get_environment("ROOTWARD_SHOT_TRIAL_STEP")
	if target == "":
		target = "hello"
	Game.start_trial()
	var run := Game.trial_session
	for turn in 110:
		var step := TrialRules.current(run.state, run.trial_content)
		if step.id == target or run.state.trial.done:
			break
		match step.event:
			"coach-next":
				await run.command({"type": "trial-next"})
			"enter":
				var rooms := ShardrunMap.next_rooms(run.state.map, run.state.position)
				await run.command({"type": "enter", "node_id": rooms[0].id})
			"compose":
				if step.has("ordered_cards"):
					await _trial_ordered(run, step.ordered_cards)
				else:
					await _trial_place(run, String(step.get("required_card", "")))
			"cast":
				await run.command({"type": "cast", "spell_id": "spell-1"})
			"battle-won":
				if (run.state.spells[0].shards as Array).is_empty():
					await _trial_place(run)
				await run.command({"type": "cast", "spell_id": "spell-1"})
			"claim-relic":
				await run.command({"type": "claim-relic", "relic_id": run.state.reward.relics[0]})
			"forge":
				await run.command({"type": "forge", "shard_id": "fib-surge"})
			"rest":
				await run.command({"type": "rest"})
			_:
				break
	var screen: Control = (load(Game.SHARDRUN) as PackedScene).instantiate()
	add_child(screen)
	for i in 12:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()


func _trial_place(run: ShardrunSession, required := "") -> void:
	var hand: Array = run.state.battle.hand.duplicate()
	if hand.is_empty():
		await run.command({"type": "end-turn"})
		return
	var chosen := required if required in hand else "fire-constant" if "fire-constant" in hand else String(hand[0])
	hand.erase(chosen)
	await run.command({"type": "compose", "spells": [{"id": "spell-1", "shards": [chosen]}], "hand": hand, "held": []})


func _trial_ordered(run: ShardrunSession, cards: Array) -> void:
	var hand: Array = run.state.battle.hand.duplicate()
	for card: String in cards:
		hand.erase(card)
	await run.command(
		{"type": "compose", "spells": [{"id": "spell-1", "shards": cards.duplicate()}], "hand": hand, "held": []}
	)


## The run history over a dark stage, from a few finished runs made up for the picture (a win, losses, an abandon),
## the newest opened as its `git show`.
func _show_git_log(session: ShardrunSession) -> void:
	var endings := [
		["won", "greedy", 2, ""],
		["lost", "brute-force", 1, "Deadlock Golem"],
		["abandoned", "dynamic", 0, ""],
		["lost", "search-index", 2, "Root Daemon"],
		["won", "divide-conquer", 2, ""],
	]
	var records: Array[Dictionary] = []
	for index in endings.size():
		var ending: Array = endings[index]
		var state := session.state.duplicate(true)
		state.seed = "shot-%d" % index
		state.status = ending[0]
		state.paradigm = ending[1]
		state.layer = ending[2]
		state.stats.damage = 400 + index * 377
		state.stats.fights = 6 + index * 3
		state.stats.turns = 20 + index * 9
		state.integrity = 0 if ending[0] == "lost" else 31 + index
		state.visited = ["a", "b", "c", "d", "e", "f", "g"].slice(0, 3 + index)
		if ending[3] != "":
			state.battle = {"kind": "boss", "foes": [{"name": ending[3], "hp": 50}]}
		var day := "2026-09-%02dT%02d:1%d:00" % [24 + index, 9 + index * 2, index]
		records.push_front(RunHistory.entry(state, session.catalog, day, "vesper"))
	var dim := ColorRect.new()
	dim.color = UiTheme.GROUND
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var view := GitLogView.create(records)
	var page := Ui.centered_scroll(view)
	page.theme = UiTheme.shared()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	view.call("_toggle", RunHistory.short_hash(records[0]))
	for i in 5:
		await get_tree().process_frame
	set_meta("shot_ready", true)
	shot_ready.emit()


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
		"hover":
			# A card of the hand pointed at (the second, or ROOTWARD_SHOT_POINT's): it rises, straightens, grows, and
			# shows what it does.
			var fight := screen.get("_fight") as FightView
			var hand := fight.find_children("*", "HandView", true, false)
			var point := (
				int(OS.get_environment("ROOTWARD_SHOT_POINT")) if OS.has_environment("ROOTWARD_SHOT_POINT") else 1
			)
			if not hand.is_empty() and (hand[0] as HandView).cards.size() > point:
				var card: CardFace = (hand[0] as HandView).cards[point]
				hand[0].call("_point", card, true)
				card.call("_hover", true)
		"log":
			var fight := screen.get("_fight") as FightView
			BattleLog.open(fight, fight.get("_entries"))
		"pile":
			var fight := screen.get("_fight") as FightView
			if fight != null:
				var table := fight.get("_table") as DeckTable
				if table != null:
					table.call("_open_pile", "draw")
		"map", "layer":
			# ROOTWARD_SHOT_SCROLL holds the map that far down (in pixels; 0 is the guardian at the top).
			# ROOTWARD_SHOT_DRAWER=closed folds the route drawer away; ROOTWARD_SHOT_DECK=1 opens the deck over the map.
			for map: MapView in screen.find_children("*", "MapView", true, false):
				if OS.get_environment("ROOTWARD_SHOT_DRAWER") == "closed" and MapView.drawer_open:
					map.call("_flip_drawer")
				if OS.has_environment("ROOTWARD_SHOT_SCROLL"):
					map.jump_to(float(OS.get_environment("ROOTWARD_SHOT_SCROLL")))
			if OS.get_environment("ROOTWARD_SHOT_DECK") == "1":
				screen.call("_open_deck")
			# ROOTWARD_SHOT_TURNS ends that many turns first (a guardian's turns played out: a summon, a push).
			for i in int(OS.get_environment("ROOTWARD_SHOT_TURNS")):
				await screen.call("send", {"type": "end-turn"})
		"enemy_tip", "relic_tip":
			var desired := "Deadlock" if shot == "enemy_tip" else "Overclock"
			for tip: HoverInfo in screen.find_children("*", "HoverInfo", true, false):
				if desired.to_lower() in tip.title.to_lower():
					tip.show_now()
					break
