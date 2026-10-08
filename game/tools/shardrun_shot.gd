extends Control
## A run set up for a screenshot, then the run screen over it. ROOTWARD_SHOT picks the moment:
##   map (default), fight, table (a Shardrun hand half played), cast, volley (the bolts, without the code), storm (a
##   heavy spark spell on two foes: lightning called down), turn, reward, treasure, rest, forge, end, code,
##   dev (a sandbox run with its tools open), and for the program Shardrun: draft (the paradigms),
##   focus (all three focuses), pack (a draft
##   pack), write (a card played into the Program, its code mid-rune; use ROOTWARD_SHOT_AFTER_MS), race (a foe quicker
##   than the Program acts first), hover (a hand card pointed at, with its details), log (the ".log" window), relics
##   (a guardian's tiered relics offered), gitlog (the run history as `git log`, from sample finished runs), layer (a
##   sandbox run jumped to ROOTWARD_SHOT_LAYER, the deepest by default: its map, or a fight there with the foes below).
##   ROOTWARD_SHOT_SCROLL holds a map shot's view that many pixels down its layer (0: the entry at the top);
##   ROOTWARD_SHOT_DRAWER=closed folds its route drawer, ROOTWARD_SHOT_DECK=1 opens the deck over it, and
##   ROOTWARD_SHOT_TURNS ends that many turns of a fight first
## ROOTWARD_SHOT_LOCALE=ja shoots the run in Japanese.
## ROOTWARD_SHOT_PARADIGM picks the paradigm a program run drafts (when it is offered). ROOTWARD_SHOT_CARDS (ids, comma
## separated) makes a fight's Program exactly those cards, in a sandbox run with mana to spare; ROOTWARD_SHOT_RELICS
## (ids) grants those relics first, in such a run (the header's relics, rung by tier). ROOTWARD_SHOT_FOES (ids) puts
## those foes in the fight instead (ROOTWARD_SHOT_KIND: fight, elite or boss), and ROOTWARD_SHOT_HAND (ids) adds those
## cards to the hand:
##   ROOTWARD_SHOT=fight ROOTWARD_SHOT_KIND=boss ROOTWARD_SHOT_FOES=deadlock-lock-a,deadlock-lock-b \
##       ROOTWARD_SHOT_CARDS=salvo,merge-strike scripts/screenshot.sh res://tools/shardrun_shot.tscn shots/locks.png 60
## It plays in its own save folder, so the player's run is never touched:
##   ROOTWARD_SHOT=cast scripts/screenshot.sh res://tools/shardrun_shot.tscn shots/cast.png 90
## ROOTWARD_SHOT_EXPAND=1 stretches the Program's code panel upward, as its Expand button does.
## ROOTWARD_SHOT_SKIN wears a battle skin for the shot (not saved). ROOTWARD_SHOT_AFTER_MS catches the moment that many
## milliseconds after the action, in real time (a headless run draws frames far faster than 60 a second):
##   ROOTWARD_SHOT=volley ROOTWARD_SHOT_SKIN=vesper ROOTWARD_SHOT_AFTER_MS=700 scripts/screenshot.sh \
##       res://tools/shardrun_shot.tscn shots/vesper-volley.png 1
## ROOTWARD_SHOT_CAPACITY=6 gives the Program six slots, to cast the grand circle's six shards.
## ROOTWARD_SHOT_LOADOUT wears cosmetic looks (ADR-0037), slot=id pairs: "circle=rootglass,impact=starfall".

## The legendary hooks (docs/LEGENDARY_LOOKS.md): ROOTWARD_SHOT_AFTER_VOLLEY_MS=n and ROOTWARD_SHOT_AFTER_IMPACT_MS=n
## catch the moment n ms after a cast's first bolt, or after a black hole's blow lands, and print the state behind the
## frame.
## ROOTWARD_SHOT_CASTS=2 (with the volley hook) plays the same spell again in the next turn, and the frame is of that
## second cast; the first cast's state is printed too, so the two casts' routes can be compared.
signal shot_ready

const SAVES := "user://shot-saves"


func _ready() -> void:
	var shot := OS.get_environment("ROOTWARD_SHOT")
	var language := OS.get_environment("ROOTWARD_SHOT_LANGUAGE")
	# ROOTWARD_SHOT_FORGE=melt|improve|widen|bind opens that door of the forge in full (forge_room.gd).
	ForgeRoom.open_door = OS.get_environment("ROOTWARD_SHOT_FORGE")
	Game.reset(SAVES)
	Game.boot()
	# ROOTWARD_SHOT_CIRCLE=<circle id> wears that circle (token-stream, codex, ring-bloom...) for the moment shot.
	if OS.get_environment("ROOTWARD_SHOT_CIRCLE") != "":
		var worn := Cosmetics.loadout()
		worn["circle"] = OS.get_environment("ROOTWARD_SHOT_CIRCLE")
		Settings.loadout = worn
	var face := OS.get_environment("ROOTWARD_FONT")
	# ROOTWARD_SHOT_BOLT=<bolt id> and ROOTWARD_SHOT_IMPACT=<impact id> wear those looks the same way:
	# legendary-constellation draws the cast's volley, legendary-singularity the black hole (docs/LEGENDARY_LOOKS.md).
	if OS.get_environment("ROOTWARD_SHOT_BOLT") != "":
		var worn_bolt := Cosmetics.loadout()
		worn_bolt["bolt"] = OS.get_environment("ROOTWARD_SHOT_BOLT")
		Settings.loadout = worn_bolt
	if OS.get_environment("ROOTWARD_SHOT_IMPACT") != "":
		var worn_impact := Cosmetics.loadout()
		worn_impact["impact"] = OS.get_environment("ROOTWARD_SHOT_IMPACT")
		Settings.loadout = worn_impact
	# ROOTWARD_SHOT_REDUCED=1 shoots the moment with reduced motion (a 0.12 s trace, no origin bursts or sparks), and =0
	# with it off, whatever the player's settings file says. Unset, the setting is left as it is.
	if OS.get_environment("ROOTWARD_SHOT_REDUCED") != "":
		Settings.reduced_motion = OS.get_environment("ROOTWARD_SHOT_REDUCED") == "1"
	if UiFonts.CHOICES.has(face):
		Settings.font_style = face
		UiTheme.refresh_fonts()
	if shot == "trial":
		await _show_trial(language)
		return
	# The shots' profile is kept between runs, so its language is set every time: ROOTWARD_SHOT_LOCALE=ja shoots the
	# run in Japanese (ADR-0047), English otherwise.
	Game.profile.preferred_language = "ja" if OS.get_environment("ROOTWARD_SHOT_LOCALE") == "ja" else "en"
	Game.profiles.save_profile(Game.profile)
	Text.setup(String(Game.profile.preferred_language))
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
	var shot_seed := "screenshot"
	var requested := OS.get_environment("ROOTWARD_SHOT_PARADIGM")
	if playstyle != "spellbook" and playstyle != "deck" and requested != "":
		for suffix in 100:
			var candidate := "screenshot-%d" % suffix
			var config := ProgramRules.config_of(session.catalog)
			var ids: Array = config.paradigms.map(func(p: Dictionary) -> String: return p.id)
			var offers := Rng.create(candidate, "paradigms").shuffled(ids).slice(0, int(config.draft.paradigms_offered))
			if requested in offers:
				shot_seed = candidate
				break
	session.start(language if language != "" else "python", "beginner", shot_seed, shot == "dev" or staged)
	var bot := ShardrunBot.new(session)
	bot.paradigm = OS.get_environment("ROOTWARD_SHOT_PARADIGM")
	match shot:
		"draft":
			pass
		"focus":
			await bot.send(await bot.next_command())
		"pack":
			await bot.send(await bot.next_command())
			if not (session.state.draft.get("focus_offers", []) as Array).is_empty():
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
				# ROOTWARD_SHOT_CAPACITY widens the Program (a spell holds up to six cards) for the grand circle.
				if OS.has_environment("ROOTWARD_SHOT_CAPACITY"):
					session.state.spells[0].capacity = int(OS.get_environment("ROOTWARD_SHOT_CAPACITY"))
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
		"registry":
			# A Registry in a sandbox run, with cycles to spend (ROOTWARD_SHOT_CYCLES, 400 by default).
			await _into_sandbox_room(session, bot, language)
			session.state.cycles = (
				int(OS.get_environment("ROOTWARD_SHOT_CYCLES")) if OS.has_environment("ROOTWARD_SHOT_CYCLES") else 400
			)
			ProgramShop.enter(session.state, {"id": "l0-r7-c1"}, session.catalog)
		"issue":
			# An Issue (ROOTWARD_SHOT_ISSUE, a coffee machine by default), after ROOTWARD_SHOT_CHOICE choices of it.
			await _into_sandbox_room(session, bot, language)
			session.state.cycles = 300
			var issue_id := (
				OS.get_environment("ROOTWARD_SHOT_ISSUE")
				if OS.has_environment("ROOTWARD_SHOT_ISSUE")
				else "coffee-machine"
			)
			session.state.status = "issue"
			session.state.issue = {"id": issue_id, "stage": "choose", "lines": [], "number": 342}
			if OS.has_environment("ROOTWARD_SHOT_CHOICE"):
				await bot.send({"type": "issue-choose", "index": int(OS.get_environment("ROOTWARD_SHOT_CHOICE"))})
		"gitlog":
			_show_git_log(session)
			return
		"treasure":
			bot.prefer = "treasure"
			await bot.play_until("reward", 200)
			while session.in_progress() and not (session.state.get("reward", {}) as Dictionary).has("chest"):
				await bot.send(bot._reward_move(session.state))
				await bot.play_until("reward", bot.steps + 200)
		"forge":
			# The forge set up directly: a bot's run rarely reaches one within a shot's steps (as the forge tests do).
			session.state.status = "forge"
		"rest":
			bot.prefer = shot
			await bot.play_until(shot, 200)
		"end":
			await bot.play(2000)
		"map":
			await bot.play_until("reward")
			await bot.send(bot._reward_move(session.state))
			await bot.play_until("map", 10)
	if OS.has_environment("ROOTWARD_SHOT_SCRIPTS"):
		var belt: Array = []
		belt.assign(OS.get_environment("ROOTWARD_SHOT_SCRIPTS").split(",", false))
		session.state.belt = belt
	if OS.has_environment("ROOTWARD_SHOT_SCRIPT_DROP") and (session.state.get("reward", {}) as Dictionary).size() > 0:
		session.state.reward.script = OS.get_environment("ROOTWARD_SHOT_SCRIPT_DROP")
	if session.state.get("sandbox", false):
		for relic_id in OS.get_environment("ROOTWARD_SHOT_RELICS").split(",", false):
			await bot.send({"type": "dev-grant-relic", "relic_id": relic_id})
	# Explicit memory snapshots keep the shot reproducible without touching the player's save.
	if session.state.status == "battle":
		if OS.has_environment("ROOTWARD_SHOT_INDEX"):
			session.state.battle.index = JSON.parse_string(OS.get_environment("ROOTWARD_SHOT_INDEX"))
		if OS.has_environment("ROOTWARD_SHOT_DP"):
			session.state.battle.dp = JSON.parse_string(OS.get_environment("ROOTWARD_SHOT_DP"))
			session.state.battle.turn = 3
	var skin := OS.get_environment("ROOTWARD_SHOT_SKIN")
	if skin in Settings.all_skins():
		Settings.character_skin = skin
	for pair in OS.get_environment("ROOTWARD_SHOT_LOADOUT").split(",", false):
		var parts := pair.split("=")
		if parts.size() == 2:
			Settings.loadout[parts[0].strip_edges()] = parts[1].strip_edges()
	var screen: Control = (load(Game.SHARDRUN) as PackedScene).instantiate()
	add_child(screen)
	for i in 10:
		await get_tree().process_frame
	if OS.get_environment("ROOTWARD_SHOT_EXPAND") == "1":
		for panel: ProgramCode in screen.find_children("*", "ProgramCode", true, false):
			panel.set_expanded(true, false)
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


	# ROOTWARD_SHOT_AFTER_VOLLEY_MS=n catches the moment n ms after the cast's first legendary volley exists (its first
	# bolt has just launched). The sandbox returns the bolts after a delay that varies, so AFTER_MS cannot time it.
	var after_volley := int(OS.get_environment("ROOTWARD_SHOT_AFTER_VOLLEY_MS"))
	if after_volley > 0:
		_act(shot, screen)
		if not await _wait_for_volley(screen):
			return
		if int(OS.get_environment("ROOTWARD_SHOT_CASTS")) >= 2:
			await get_tree().create_timer(after_volley / 1000.0).timeout
			_report_legendary(screen)
			if not await _second_cast(screen, session):
				return
		await get_tree().create_timer(after_volley / 1000.0).timeout
		_report_legendary(screen)
		set_meta("shot_ready", true)
		shot_ready.emit()
		return
	# ROOTWARD_SHOT_AFTER_IMPACT_MS=n catches the moment n ms after a black hole's blow lands (0.3 s into its 1.2 s
	# timeline), so its shock ring and jets are read at a known progress. It prints the legendary state, as the volley
	# hook does.
	var after_impact := int(OS.get_environment("ROOTWARD_SHOT_AFTER_IMPACT_MS"))
	if after_impact > 0:
		_act(shot, screen)
		if not await _wait_for_impact(screen):
			return
		await get_tree().create_timer(after_impact / 1000.0).timeout
		_report_legendary(screen)
		set_meta("shot_ready", true)
		shot_ready.emit()
		return
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
				if step.has("ordered_cards") or step.has("cards_exact"):
					await _trial_ordered(run, step.get("ordered_cards", step.get("cards_exact", [])))
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
		"forge":
			# ROOTWARD_SHOT_PICK=<card id> chooses that card in the open forge stage (a melt or a refactor).
			var picked := OS.get_environment("ROOTWARD_SHOT_PICK")
## Waits until a legendary volley is under the screen. After 15 s with none, the shot stops with an error (false).
func _wait_for_volley(screen: Control) -> bool:
	var started := Time.get_ticks_msec()
	while _volley_of(screen) == null:
		if Time.get_ticks_msec() - started > 15000:
			push_error("no legendary volley within 15 s: the cast did not land")
			get_tree().quit(2)
			return false
		await get_tree().process_frame
	return true


## Casts the same spell again in the next turn, once the first cast has played: the turn ends, the cards of the chosen
## spell go back into its program (the first cast spent them, as the CARDS staging set them up), and the spell is cast.
## So both casts run the same card. False (the shot stops) when a step does not happen.
func _second_cast(screen: Control, session: ShardrunSession) -> bool:
	var first_id := _volley_id(screen)
	if not await _until_idle(screen):
		return false
	await screen.call("send", {"type": "end-turn"})
	if not await _until_idle(screen):
		return false
	print("legendary-shot: second cast in turn %d" % int(session.state.battle.turn))
	var ids := OS.get_environment("ROOTWARD_SHOT_CARDS").split(",", false)
	if not ids.is_empty():
		# The dev commands rebuild the fight, and a fresh stage counts its casts from 0. The serial is read before them and
		# written back after them, so the next cast takes the next serial, as it does in a fight that is not rebuilt.
		var serial := _cast_serial_of(screen)
		for id: String in ids:
			await screen.call("send", {"type": "dev-grant-shard", "shard_id": id})
		await screen.call("send", {"type": "dev-set", "mana": 9})
		var table := CardTable.of(session.state, session.catalog)
		var program_now: Dictionary = table.spells[0]
		program_now.shards = Array(ids)
		for id: String in ids:
			(table.hand as Array).erase(id)
		await screen.call("send", CardTable.command(table))
		_set_cast_serial(screen, serial)
		print("legendary-shot: cast serial %d kept across the restage" % serial)
		if not await _until_idle(screen):
			return false
	var spell := OS.get_environment("ROOTWARD_SHOT_SPELL")
	# Not awaited, as the first cast's send is not: the cast plays on while the shot waits for its volley to appear.
	screen.call("send", {"type": "cast", "spell_id": spell if spell != "" else "spell-1"})
	return await _wait_for_new_volley(screen, first_id)


## Waits until the fight is not presenting a command. False after 30 s: the shot stops with an error.
func _until_idle(screen: Control) -> bool:
	var started := Time.get_ticks_msec()
	while screen.call("is_busy"):
		if Time.get_ticks_msec() - started > 30000:
			push_error("the fight stayed busy for 30 s")
			get_tree().quit(2)
			return false
		await get_tree().process_frame
	return true


## Waits until a legendary volley other than the one with instance id `first_id` is under the screen. False after 30 s:
## the shot stops with an error.
func _wait_for_new_volley(screen: Control, first_id: int) -> bool:
	var started := Time.get_ticks_msec()
	while _volley_id(screen) == 0 or _volley_id(screen) == first_id:
		if Time.get_ticks_msec() - started > 30000:
			push_error("no second legendary volley within 30 s: the second cast did not land")
			get_tree().quit(2)
			return false
		await get_tree().process_frame
	return true


## The newest cast's volley (ConstellationVolley) under the screen, or null while it has not started. Children are kept
## in the order they were added, so the last volley found is the newest.
static func _volley_of(screen: Node) -> Node:
	var newest: Node = null
	for node: Node in _nodes_of(screen, "ConstellationVolley"):
		newest = node
	return newest


## The newest cast's volley as an instance id, or 0 while none is under the screen. An id does not hold a freed volley,
## so a volley can be told from a later one after the first has been freed.
static func _volley_id(screen: Node) -> int:
	var volley := _volley_of(screen)
	return volley.get_instance_id() if volley != null else 0


## The fight's cast serial (BattleStage counts its casts), or 0 while no fight is shown.
static func _cast_serial_of(screen: Node) -> int:
	var fight := screen.get("_fight") as FightView
	return int(fight.stage.get("_cast_serial")) if fight != null else 0


## Writes the fight's cast serial back onto the fight's stage, after a dev command rebuilt the fight (see _second_cast).
static func _set_cast_serial(screen: Node, serial: int) -> void:
	var fight := screen.get("_fight") as FightView
	if fight != null:
		fight.stage.set("_cast_serial", serial)


## Waits until a black hole's blow has landed (its progress is past the impact). After 15 s with none, the shot stops.
func _wait_for_impact(screen: Control) -> bool:
	var started := Time.get_ticks_msec()
	while not _impact_landed(screen):
		if Time.get_ticks_msec() - started > 15000:
			push_error("no black-hole impact within 15 s: the cast did not land")
			get_tree().quit(2)
			return false
		await get_tree().process_frame
	return true


## Whether a black hole under the screen has reached its impact.
static func _impact_landed(screen: Node) -> bool:
	for hole: Node in _nodes_of(screen, "BlackHoleImpact"):
		if (hole as BlackHoleImpact).progress >= BlackHoleImpact.IMPACT_SHARE:
			return true
	return false


## The nodes under `screen` whose script is the class `script_name`, found as _volley_of finds them.
static func _nodes_of(screen: Node, script_name: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in screen.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().get_global_name() == script_name:
			found.append(node)
	return found


## Prints the legendary state behind a frame, in screenshot pixels: each circle's final star, the cast's origin, each
## bolt's age, landing, route end, head and stars, and each black hole's centre and progress. The window stretches the
## canvas (window/stretch/scale in project.godot), so a canvas point is not its pixel: every point goes through the
## viewport's final transform. It is read within a frame of the frame that is drawn.
static func _report_legendary(screen: Node) -> void:
	var to_pixels := screen.get_viewport().get_final_transform()
	for circle: Node in _nodes_of(screen, "MagicCircle"):
		var final_star: Vector2 = circle.call("final_node_global")
		print("legendary-shot: circle %s final star px %s" % [circle.get("style"), to_pixels * final_star])
	var volleys := _nodes_of(screen, "ConstellationVolley")
	for v in volleys.size():
		_report_volley(volleys[v] as Node2D, to_pixels, v)
	for hole: Node in _nodes_of(screen, "BlackHoleImpact"):
		var hole_node := hole as Node2D
		var progress: float = (hole as BlackHoleImpact).progress
		print("legendary-shot: black hole at px %s progress %.3f" % [to_pixels * hole_node.global_position, progress])


## Prints one volley (the `index`th under the screen, oldest first): its origin, then each bolt's age, landing, route
## end, head and stars. Two casts in one shot (ROOTWARD_SHOT_CASTS=2) give two volleys, so each line names its volley.
static func _report_volley(volley: Node2D, to_pixels: Transform2D, index: int) -> void:
	var origin: Callable = volley.get("_origin")
	if origin.is_valid():
		var origin_now: Vector2 = origin.call()
		print("legendary-shot: volley %d origin px %s" % [index, to_pixels * origin_now])
	var riders: Array = volley.get("_riders")
	for i in riders.size():
		var rider: Object = riders[i]
		var route: PackedVector2Array = volley.call("route_of", i)
		if route.is_empty():
			continue
		var head: Vector2 = ConstellationPath.point_on(route, rider.call("head"))
		var end_px := to_pixels * volley.to_global(route[route.size() - 1])
		var head_px := to_pixels * volley.to_global(head)
		var lands: float = rider.call("arrival_time")
		print(
			(
				"legendary-shot: volley %d bolt %d age %.3f lands %.3f end px %s head px %s stars %s"
				% [index, i, rider.get("age"), lands, end_px, head_px, rider.get("stars")]
			)
		)


			for node: Node in screen.find_children("*", "", true, false):
				if (
					picked != ""
					and node.get_script() != null
					and node.get_script().get_global_name() == "ForgeMeltView"
				):
					(node as ForgeMeltView).pick(picked)
				if picked != "" and node.get_script() != null and node.get_script().get_global_name() == "ForgeView":
					(node as ForgeView).pick(picked)
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
			# ROOTWARD_SHOT_SCROLL holds the map that far down (in pixels; 0 is the entry at the top).
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


## A sandbox run past its first fight, standing on the map, ready to be put into a room by the shot.
func _into_sandbox_room(session: ShardrunSession, bot: ShardrunBot, language: String) -> void:
	session.start(language if language != "" else "python", "beginner", "screenshot", true)
	await bot.play_until("battle")
	await bot.send({"type": "dev-end-battle", "outcome": "win"})
	if (session.state.get("reward", {}) as Dictionary).has("shards"):
		await bot.send({"type": "take", "shard_id": null})
	if session.state.status == "reward":
		await bot.send({"type": "leave"})
