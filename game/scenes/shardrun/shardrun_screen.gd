class_name ShardrunScreen
extends Control
## The run: a header with the Maintainer's Integrity and relics, and below it where the Maintainer is: between rooms
## (the map, a room, the spellbook), in a fight, or at the end. Every button ends in `send`, which asks the session
## (the rules) and then plays what happened; nothing on this screen decides an outcome.

var session: ShardrunSession
var _busy := false
var _backdrop: TextureRect
var _header: PanelContainer
var _body: Control
var _overlay: Control
var _toast: PanelContainer
var _toast_tween: Tween
var _fight: FightView
var _chronicle: Label
var _coach: TrialCoach
var _trial_targets: Dictionary = {}


func _ready() -> void:
	theme = UiTheme.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Game.boot():
		Game.go(Game.TITLE)
		return
	session = Game.trial_session if Game.trial_active else Game.session
	if session == null or not session.has_run():
		Game.go(Game.TITLE)
		return
	_build()
	_show(session.state)
	_refresh_coach()
	if _fight != null:
		_fight.write_entries(session.state.log)
		_fight.refresh_previews()


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = UiTheme.GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_backdrop.modulate = Color(0.28, 0.25, 0.23)
	add_child(_backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	_header = PanelContainer.new()
	_header.theme_type_variation = "Header"
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(Ui.vbox([_header, _body], 10))
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_toast = Ui.panel(Ui.label("", "", true), "Overlay")
	_toast.visible = false
	add_child(_toast)
	if Game.trial_active:
		_coach = TrialCoach.new()
		_coach.wants.connect(send)
		_coach.skipped.connect(_skip_trial)
		add_child(_coach)


# --- Showing a state ------------------------------------------------------------------------------------------------


func _show(state: Dictionary) -> void:
	_fight = null
	_trial_targets.clear()
	Ui.clear(_body)
	_show_header(state)
	var layer := ShardrunRules.layer_of(state, session.catalog)
	_backdrop.texture = Art.texture("backgrounds/" + String(layer.backdrop))
	var view: Control
	if state.status in Shardrun.ENDED:
		view = _ending(state)
		_trial_targets["score"] = view
		Sound.music("music-title")
	elif state.status == "draft":
		var draft := DraftView.create(session)
		draft.wants.connect(send)
		view = draft
		Sound.music(layer.get("music", "music-salvage"))
	elif state.status == "battle":
		_fight = FightView.create(session)
		_fight.wants.connect(send)
		view = _fight
		_trial_targets["hand"] = _fight._table
		_trial_targets["program"] = _fight._program
		_trial_targets["code"] = _fight._program
		_trial_targets["foe"] = _fight.stage
		var boss: bool = state.battle.kind == "boss"
		Sound.music(
			layer.get("boss_music", "music-guardian") if boss else layer.get("battle_music", "music-battle-salvage")
		)
	else:
		view = _between(state)
		var resting: bool = state.status == "rest"
		Sound.music(layer.get("rest_music", "music-rest") if resting else layer.get("music", "music-salvage"))
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(view)


func _show_header(state: Dictionary) -> void:
	Ui.clear(_header)
	var mode := String(Game.PLAYSTYLES.get(state.get("playstyle", "spellbook"), "Spellforge")).to_upper()
	if Game.trial_active:
		mode = "PIP'S TRIAL"
	var heading := mode + (" / ARTIFICER" if state.get("playstyle", "") == "deck" else "")
	var logo := Ui.tint(Ui.label(heading, "Subheading"), UiTheme.SHARD) as Label
	# A program run's paradigm, in its own colour: the colour its cards wear.
	var paradigm := ProgramDraft.paradigm_of(session.catalog, String(state.get("paradigm", "")))
	var school := Ui.sized(Ui.label("", "Subheading"), 24) as Label
	if state.get("playstyle", "") == "program" and not paradigm.is_empty():
		school.text = "/ " + String(paradigm.name).to_upper()
		school.add_theme_color_override("font_color", Color(paradigm.colour))
	var integrity: Control
	if state.status == "battle" and state.has("battle"):
		# In a fight the Maintainer's Integrity stands over them on the stage; up here, the turn.
		var battle: Dictionary = state.battle
		integrity = Ui.label("TURN %d  ·  %s" % [int(battle.turn), String(battle.kind).to_upper()], "Subheading")
	else:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(170, 14)
		bar.max_value = maxi(1, int(state.integrity_max))
		bar.value = int(state.integrity)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var numbers := Ui.label("%d/%d" % [int(state.integrity), int(state.integrity_max)])
		integrity = Ui.hbox([Ui.label("INTEGRITY", "Faint"), bar, numbers], 8)
	var layer := ShardrunRules.layer_of(state, session.catalog)
	var layers: Array = session.catalog.config.layers
	var meta := (
		"%s (%d/%d) · %s · %s"
		% [layer.name, int(state.layer) + 1, layers.size(), session.difficulty().get("name", ""), state.language]
	)
	if Game.trial_active:
		meta = "4 STOPS · %s · %s" % [session.difficulty().get("name", ""), state.language]
	var relics := Ui.hbox([], 4)
	for relic_id: String in state.relics:
		relics.add_child(Cards.relic_icon(session.catalog.relics.get(relic_id, {"name": relic_id, "summary": ""})))
	var buttons := (
		Ui
		. hbox(
			[
				(
					Ui.button("Deck", _open_deck)
					if ShardrunRules.is_deck(state) and not state.status in Shardrun.ENDED
					else Ui.spacer()
				),
				Ui.button("Stats", _open_stats),
				Ui.button("Menu", _open_run_menu, "PrimaryButton"),
			],
			6
		)
	)
	if state.get("sandbox", false) and not state.status in Shardrun.ENDED:
		buttons.add_child(Ui.button("Dev", _open_dev))
		logo.text += " · DEV"
	var title := Ui.hbox([logo, school], 8)
	var row := Ui.hbox([title, integrity, Ui.label(meta, "Muted"), relics, Ui.spacer(), buttons], 18)
	_header.add_child(row)


func _between(state: Dictionary) -> Control:
	var left := Ui.vbox([], 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.7 if ShardrunRules.is_deck(state) else 1.25
	var on_map: bool = not state.status in ["reward", "rest", "forge"]
	if not on_map:
		var room := RoomPanel.create(session)
		_trial_targets["relic"] = room
		_trial_targets["forge"] = room
		_trial_targets["rest"] = room
		room.wants.connect(send)
		var scroll := Ui.scroll(room)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(Ui.expand(Ui.panel(scroll, ""), true))
	else:
		var map := MapView.new()
		_trial_targets["guardian"] = map._rail
		_trial_targets["deck"] = map._deck
		map.show_deck = ShardrunRules.is_deck(state)
		map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		map.enter_pressed.connect(func(node_id: String) -> void: send({"type": "enter", "node_id": node_id}))
		map.deck_pressed.connect(_open_deck)
		left.add_child(Ui.expand(Ui.panel(map, "Sunken"), true))
		map.show_map(state, session.catalog)
		var next_rooms := ShardrunMap.next_rooms(state.map, state.position)
		_trial_targets["map"] = map._rooms.get(next_rooms[0].id, map) if not next_rooms.is_empty() else map
	_chronicle = Ui.label(_story(state.log), "Muted", true)
	left.add_child(_chronicle)
	# A deck run's map fills the screen: the deck opens from its pile, the next rooms sit in the map's route drawer.
	if ShardrunRules.is_deck(state) and on_map:
		return left
	var right: PanelContainer
	if ShardrunRules.is_deck(state):
		right = Ui.panel(Ui.scroll(DeckPanel.create(session)), "")
		right.custom_minimum_size.x = 480
	else:
		var bench := Workbench.create(session)
		bench.wants.connect(send)
		bench.notice.connect(toast)
		bench.explore.connect(_explore)
		right = Ui.panel(bench, "")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return Ui.hbox([left, right], 12)


func _ending(state: Dictionary) -> Control:
	var return_home := func() -> void: Game.go(Game.TITLE)
	var buttons := (
		Ui
		. hbox(
			[
				Ui.button("Return to title" if Game.trial_active else "A new run", return_home, "PrimaryButton"),
			],
			8
		)
	)
	var column := Ui.vbox([RunSummary.ending(state), Ui.label(_story(state.log), "Narration", true)], 16)
	var history := [] if Game.trial_active else session.saves.load_history()
	if not history.is_empty() and String(history[0].get("seed", "")) == String(state.seed):
		# What git prints after a commit: the run is in the history now (the title's git log shows them all).
		var record: Dictionary = history[0]
		var committed := (
			"[main %s] %s\n%s"
			% [RunHistory.short_hash(record), RunHistory.subject(record), RunHistory.diffstat(record)]
		)
		column.add_child(Ui.tint(Ui.label(committed, "Muted"), UiTheme.TEAL))
	column.add_child(buttons)
	var panel := Ui.panel(column, "Overlay")
	panel.custom_minimum_size = Vector2(820, 0)
	return Ui.centered_scroll(panel)


static func _story(entries: Array) -> String:
	var texts: PackedStringArray = []
	for entry: Dictionary in entries:
		if entry.has("text"):
			texts.append(entry.text)
	return " ".join(texts)


# --- Commands -------------------------------------------------------------------------------------------------------


## Asks the rules to do `command`, then plays what happened. Refusals are shown and change nothing.
func send(command: Dictionary) -> void:
	if _busy:
		return
	_set_busy(true)
	var result: Dictionary = await session.command(command)
	if not is_inside_tree():
		return
	if not result.ok:
		toast(result.error.message)
		_set_busy(false)
		return
	await _present(result, command)
	_refresh_coach()
	_set_busy(false)


func _present(result: Dictionary, command: Dictionary) -> void:
	var before: Dictionary = result.before
	var after: Dictionary = result.state
	if (
		command.type == "trial-next"
		or (
			Game.trial_active
			and int(after.get("trial", {}).get("failures", 0)) > int(before.get("trial", {}).get("failures", 0))
		)
	):
		_show(after)
		if _fight != null:
			_fight.refresh_previews()
		return
	if String(command.type).begins_with("dev-"):
		# A dev command can replace the whole fight (a spawn), so the screen is drawn afresh rather than played.
		_show(after)
		toast(_story(after.log))
		if _fight != null:
			_fight.write_entries(after.log)
			_fight.refresh_previews()
		return
	if before.status == "battle" and _fight != null:
		await _fight.present(result)
		if after.status == "battle":
			_show_header(after)
			_fight.refresh_previews()
			return
		await get_tree().create_timer(0.4).timeout
		_show(after)
		return
	_cue(command, after)
	_show(after)
	if after.status == "battle" and _fight != null:
		_fight.set_busy(true)
		await _fight.present({"before": after, "state": after, "replay": {}})
		_fight.set_busy(false)
		_fight.refresh_previews()


## A sound for what a command between rooms did.
static func _cue(command: Dictionary, after: Dictionary) -> void:
	var kinds: Array = after.log.map(func(entry: Dictionary) -> String: return entry.kind)
	match command.type:
		"enter":
			Sound.play("sfx-step", 0.7)
			if after.status == "reward":
				Sound.play("cue-treasure", 0.6)
		"rest":
			Sound.play("sfx-heal", 0.8)
		"forge", "widen", "bind", "pick-paradigm":
			Sound.play("sfx-forge", 0.8)
		"claim-relic", "claim-spell":
			Sound.play("sfx-relic", 0.8)
		"take":
			Sound.play("sfx-coins", 0.7)
		"open-chest":
			Sound.play(
				"sfx-curse" if "relic" in kinds and after.get("reward", {}).has("cursed_relic") else "sfx-open", 0.8
			)
		"arrange", "purge", "draft-card":
			Sound.play("sfx-card-place", 0.5)


func is_busy() -> bool:
	return _busy


func _set_busy(value: bool) -> void:
	_busy = value
	if _fight != null:
		_fight.set_busy(value)


func _refresh_coach() -> void:
	if _coach == null or session == null or not session.has_run():
		return
	var step := TrialRules.current(session.state, session.trial_content)
	var target: Control = _trial_targets.get(step.get("anchor", ""), _body)
	_coach.show_step(session.state, target)


func _skip_trial() -> void:
	Game.skip_trial()
	Game.go(Game.TITLE)


# --- Overlays -------------------------------------------------------------------------------------------------------


func toast(text: String) -> void:
	(_toast.get_child(0) as Label).text = text
	_toast.visible = true
	_toast.modulate = Color.WHITE
	_toast.size = Vector2(minf(620.0, size.x - 40.0), 0)
	_toast.size = _toast.get_combined_minimum_size()
	_toast.position = Vector2((size.x - _toast.size.x) * 0.5, size.y - _toast.size.y - 28)
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate", Color(1, 1, 1, 0), 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


func _open(panel: Control) -> void:
	_close_overlay()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(
		func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				_close_overlay()
	)
	_overlay.add_child(dim)
	var page := Ui.centered_scroll(panel)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(page.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A click beside the panel (on the dimmed screen) closes it, as a click on the dim itself would.
	page.gui_input.connect(
		func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				_close_overlay()
	)
	_overlay.add_child(page)


func _close_overlay() -> void:
	Ui.clear(_overlay)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _overlay.get_child_count() > 0:
		_close_overlay()
		get_viewport().set_input_as_handled()


func _open_options() -> void:
	var options := OptionsPanel.create()
	options.closed.connect(_close_overlay)
	_open(options)


func _open_run_menu() -> void:
	var state := session.state
	var column := (
		Ui
		. vbox(
			[
				Ui.hbox([Ui.label("RUN MENU", "Heading"), Ui.spacer(), Ui.button("Close", _close_overlay)], 12),
				Ui.label(
					"%s · Artificer · %s" % [Game.PLAYSTYLES.get(state.playstyle, "Shardrun"), state.language], "Muted"
				),
				Ui.panel(
					Ui.vbox(
						[
							Ui.label("The run is saved after every move.", "Muted"),
							Ui.label("Return to title whenever you want to continue later.", "Faint")
						],
						5
					),
					"Sunken"
				),
			],
			12
		)
	)
	var tools_row := Ui.hbox(
		[Ui.button("Stats", _open_stats), Ui.button("Battle look", _open_skins), Ui.button("Options", _open_options)], 8
	)
	if ShardrunRules.is_deck(state):
		tools_row.add_child(Ui.button("Deck", _open_deck))
	tools_row.add_child(Ui.button("Archives", _open_archive))
	column.add_child(tools_row)
	var actions := Ui.hbox(
		[Ui.button("Return to title", func() -> void: Game.go(Game.TITLE), "PrimaryButton"), Ui.spacer()], 8
	)
	if Game.trial_active:
		actions.add_child(Ui.button("Skip Trial", _skip_trial, "DangerButton"))
	elif not state.status in Shardrun.ENDED:
		actions.add_child(Ui.button("Abandon run", _confirm_abandon, "DangerButton"))
	column.add_child(actions)
	var panel := Ui.panel(column, "Overlay")
	panel.custom_minimum_size.x = 620
	_open(panel)


func _open_archive() -> void:
	var archive := ArchivePanel.create(Game.display_catalog())
	archive.closed.connect(_close_overlay)
	_open(archive)


func _open_skins() -> void:
	var wardrobe := SkinSelectionPanel.create()
	wardrobe.skin_selected.connect(_set_battle_skin)
	wardrobe.closed.connect(_close_overlay)
	_open(wardrobe)


func _set_battle_skin(id: String) -> void:
	if _fight != null and is_instance_valid(_fight.stage.hero):
		_fight.stage.hero.set_skin(id)
		_fight.set_skin(id)


func _open_dev() -> void:
	var drawer := DevDrawer.create(session)
	drawer.closed.connect(_close_overlay)
	drawer.wants.connect(
		func(command: Dictionary) -> void:
			await send(command)
			if _overlay.get_child_count() > 0:
				_open_dev()
	)
	_open(drawer)


func _open_deck() -> void:
	var close := Ui.button("Close", _close_overlay)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	var panel := Ui.panel(Ui.vbox([DeckPanel.create(session, true), close], 12), "Overlay")
	panel.custom_minimum_size = Vector2(1180, 0)
	_open(panel)


func _open_stats() -> void:
	var panel := Ui.panel(RunSummary.stats_panel(session.state), "Overlay")
	panel.custom_minimum_size = Vector2(700, 0)
	_open(panel)


func _confirm_abandon() -> void:
	var text := "Climb back out? The run ends here and is scored as it stands; the shards stay behind."
	var abandon := func() -> void:
		_close_overlay()
		send({"type": "abandon"})
	var yes := Ui.button("Abandon this run", abandon, "DangerButton")
	var no := Ui.button("Keep going", _close_overlay, "PrimaryButton")
	var column := Ui.vbox([Ui.label("Abandon the run?", "Heading"), Ui.label(text, "", true), Ui.hbox([no, yes])], 14)
	var panel := Ui.panel(column, "Overlay")
	panel.custom_minimum_size = Vector2(560, 0)
	_open(panel)


func _explore(spell_id: String) -> void:
	var spell := Shardrun.spell_by_id(session.state, spell_id)
	var base := int(session.catalog.balance.base_bolt_power)
	var note := {"note": "This is the whole spell as one function. Cast it in a fight to watch it run, line by line."}
	var view := CodeView.create(session.state.language, spell, session.catalog.shards, base, note, "explore", "normal")
	view.custom_minimum_size = Vector2(1040, 820)
	view.finished.connect(_close_overlay)
	_open(view)
