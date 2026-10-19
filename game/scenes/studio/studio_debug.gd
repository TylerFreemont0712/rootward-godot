class_name StudioDebug
extends PanelContainer
## The developer inspector (Concept/v0.3/10, S7): F3 in Play shows it on the right of the town, which shrinks beside it
## (nothing is covered). **See:** where the player is, the quests and their steps, the flags, the lessons, each thing's
## fields and the boots' code, and an event log: talk opened and closed, flags set and cleared, quest steps done, a
## thing's code run with its input, output, errors and time, warps taken, pokes, content reloaded. **Poke:** teleport
## (Ctrl-click the town), set and clear flags, complete or reopen a quest step, jump to a quest, reset a thing, run a
## thing's code again with chosen inputs, reload content (and on its own when a file changes). Pokes change only the
## play-test state (Play draft), never content, and every poke is logged. DebugPokes holds the rules and DebugLog the
## log; this shows them and sends the pokes through the overworld (its `poke_state` and `teleport`).

const WIDTH := 400
## How many of the newest events the Events tab lists.
const SHOWN_EVENTS := 80
## How often the panel reads the state again, and the content files' times (seconds).
const REFRESH := 0.25
const WATCH := 1.0
const TABS: Array[String] = ["state", "events"]
const CODE_SIZE := 12

## The event log (DebugLog), for the run.
var book: Dictionary = DebugLog.empty()
var tab := "state"
## The Events tab shows these kinds ([] for all).
var kinds: Array[String] = []
## Whether content files are watched, and reloaded when one changes.
var watching := true

var _studio: StudioMode
var _began := 0
var _body: VBoxContainer
var _tab_buttons: Dictionary = {}
var _mode_line: Label
var _draft_button: Button
var _signature := ""
var _since := 0.0
var _watched_since := 0.0
var _stamps: Dictionary = {}
## The state as last seen, to tell what changed: its flags, its map, and whether a talk was open (and with whom).
var _flags: Dictionary = {}
var _map := ""
var _cell := Vector2i(-1, -1)
var _talking := false
var _primed := false
var _hooked: Object
var _rerun: ConfirmationDialog
var _rerun_text: TextEdit
var _rerun_thing: Dictionary = {}


func _init(studio: StudioMode) -> void:
	_studio = studio
	name = "Debug"
	visible = false
	custom_minimum_size.x = WIDTH
	add_theme_stylebox_override("panel", StudioStyle.box(Vector2(10, 8)))
	var column := Ui.vbox([], 5)
	add_child(column)
	var title := Ui.label(StudioText.t("debug_title"), "Subheading")
	title.add_theme_font_size_override("font_size", 17)
	column.add_child(Ui.hbox([title, Ui.spacer(), StudioStyle.caption(StudioText.t("debug_key"))], 6))
	_mode_line = StudioStyle.line("", UiTheme.MUTED)
	_mode_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_mode_line)
	_draft_button = StudioStyle.button(StudioText.t("debug_draft_on"), func() -> void: _studio.set_play_draft(true), false, StudioText.t("debug_draft_tip"))
	_draft_button.name = "PlayDraft"
	column.add_child(_draft_button)
	var row := Ui.hbox([], 3)
	for one: String in TABS:
		var button := StudioStyle.button(StudioText.t("debug_tab_" + one), func() -> void: show_tab(one), one == tab)
		button.name = "Tab_" + one
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_buttons[one] = button
		row.add_child(button)
	column.add_child(row)
	_body = Ui.vbox([], 4)
	_body.name = "Body"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := Ui.scroll(_body)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rerun = ConfirmationDialog.new()
	_rerun.name = "Rerun"
	_rerun.title = StudioText.t("debug_rerun_title")
	_rerun.ok_button_text = StudioText.t("debug_rerun_ok")
	_rerun_text = TextEdit.new()
	_rerun_text.custom_minimum_size = Vector2(520, 260)
	_rerun_text.add_theme_font_override("font", UiTheme.code_font())
	_rerun_text.add_theme_font_size_override("font_size", 13)
	_rerun.add_child(_rerun_text)
	_rerun.confirmed.connect(func() -> void: rerun(_rerun_thing, _rerun_text.text))
	add_child(_rerun)


## Shows a tab: "state" or "events".
func show_tab(which: String) -> void:
	tab = which
	for one: String in _tab_buttons:
		StudioStyle.choose(_tab_buttons[one], one == tab)
	_signature = ""
	rebuild()


## The panel is shown or hidden (F3): shown, it reads the state at once.
func set_shown(on: bool) -> void:
	visible = on
	if on:
		_signature = ""
		rebuild()


## Every frame: what changed since the last one goes in the log, and the panel follows when it is shown. The log is kept
## whether or not the panel shows, so opening it later still tells what happened.
func poll(delta: float) -> void:
	var state := _state()
	if state.is_empty():
		return
	_hook_things()
	if not _primed:
		_primed = true
		_began = Time.get_ticks_msec()
		_remember(state)
		_stamps = _content_stamps()
		return
	_events_of(state)
	_remember(state)
	if not visible:
		return
	_since += delta
	if _since >= REFRESH:
		_since = 0.0
		var now := _signature_of(state)
		if now != _signature:
			rebuild()
	_watched_since += delta
	if watching and _watched_since >= WATCH:
		_watched_since = 0.0
		_watch()


## A line in the log.
func note(kind: String, text: String, data: Dictionary = {}) -> void:
	book = DebugLog.add(book, kind, text, data, Time.get_ticks_msec())
	if visible and tab == "events":
		rebuild()


## Whether pokes may change the state now: only the play-test state (Play draft), never the real save.
func can_poke() -> bool:
	return _studio.play_draft


## Ctrl-click in Play: the player is put on the cell clicked (a poke).
func _input(event: InputEvent) -> void:
	if not visible or _studio.editing or not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed or not click.ctrl_pressed:
		return
	# A click on the panel itself is the panel's; anywhere else is the town (teleport says when it is off the map).
	if get_global_rect().has_point(click.position):
		return
	var view := _studio.pixel_view()
	var point := view.get_global_transform().affine_inverse() * click.position
	get_viewport().set_input_as_handled()
	teleport(Vector2i((view.to_world(point) / OverworldScale.TILE).floor()))


## Puts the player on `cell` of the map they are on. False when pokes are off or nobody can stand there.
func teleport(cell: Vector2i) -> bool:
	var map := String(_state().get("map", ""))
	if not _refuse_unless_draft():
		return false
	var moved: Callable = _studio.parts().get("teleport", Callable())
	if not moved.is_valid() or not bool(moved.call(map, cell)):
		_studio.say(StudioText.t("debug_teleport_no") % [cell.x, cell.y], true)
		return false
	note("poke", StudioText.t("debug_teleported") % [map, cell.x, cell.y], {"map": map, "cell": [cell.x, cell.y]})
	return true


# --- pokes ----------------------------------------------------------------------------------------------------------


## The flags after `change` (a Callable from flags to flags), as one poke named `text`. False when pokes are off.
func poke_flags(change: Callable, text: String) -> bool:
	if not _refuse_unless_draft():
		return false
	var next := _state().duplicate(true)
	next["flags"] = change.call(next.get("flags", {}))
	return _poke(next, text)


func complete_step(quest: String, step: int) -> bool:
	var quests := _quests()
	return poke_flags(func(flags: Dictionary) -> Dictionary: return DebugPokes.complete_step(quests, quest, step, flags), StudioText.t("debug_poke_done") % [_quest_title(quest), step + 1])


func reopen_step(quest: String, step: int) -> bool:
	var quests := _quests()
	return poke_flags(func(flags: Dictionary) -> Dictionary: return DebugPokes.reopen_step(quests, quest, step, flags), StudioText.t("debug_poke_reopened") % [_quest_title(quest), step + 1])


func jump_to(quest: String) -> bool:
	var quests := _quests()
	return poke_flags(func(flags: Dictionary) -> Dictionary: return DebugPokes.jump_to(quests, quest, flags), StudioText.t("debug_poke_jumped") % _quest_title(quest))


func set_flag(flag: String) -> bool:
	if flag.strip_edges() == "":
		return false
	var wanted := flag.strip_edges()
	return poke_flags(func(flags: Dictionary) -> Dictionary: return DebugPokes.set_flag(flags, wanted), StudioText.t("debug_poke_set") % wanted)


func clear_flag(flag: String) -> bool:
	return poke_flags(func(flags: Dictionary) -> Dictionary: return DebugPokes.clear_flag(flags, flag), StudioText.t("debug_poke_cleared") % flag)


## A thing goes back to how it starts: its saved fields and kept code are forgotten.
func reset_thing(thing_id: String) -> bool:
	if not _refuse_unless_draft():
		return false
	var next := _state().duplicate(true)
	var things: Dictionary = next.get("things", {})
	things.erase(thing_id)
	next["things"] = things
	return _poke(next, StudioText.t("debug_poke_reset") % thing_id)


## Opens the re-run dialog for a thing, with the input a run would get now.
func ask_rerun(thing: Dictionary) -> void:
	var host := _host()
	if host == null:
		return
	_rerun_thing = thing
	_rerun_text.text = JSON.stringify(host.input_of(thing, [] as Array[String]), "  ", false)
	_rerun.popup_centered()


## Runs a thing's code on `input_text` (JSON) without changing the town, and logs what it gave back.
func rerun(thing: Dictionary, input_text: String) -> Dictionary:
	var host := _host()
	var args: Variant = JSON.parse_string(input_text)
	if host == null or not args is Dictionary:
		note("thing", StudioText.t("debug_rerun_bad"), {})
		return {}
	var id := String(thing.get("id", ""))
	var result: Dictionary = await host.try_with(thing, args)
	if result.is_empty():
		return result
	note("thing", _ran_text(id, args, result.run, result.verdict, int(result.usec)) + " " + StudioText.t("debug_rerun_note"), {"id": id, "input": args, "run": result.run, "verdict": result.verdict})
	return result


## Reads the content files again (Studio's reload), then the drafts on top when they are played.
func reload_content(why := "") -> void:
	var reload: Callable = _studio.parts().get("reload_content", Callable())
	if not reload.is_valid():
		return
	reload.call()
	_studio.clear_map_names()
	if _studio.play_draft:
		_studio.work.set_play_draft(true)
	_studio.redraw_town()
	_stamps = _content_stamps()
	note("content", StudioText.t("debug_reloaded") + (" (%s)" % why if why != "" else ""), {})


func _refuse_unless_draft() -> bool:
	if can_poke():
		return true
	_studio.say(StudioText.t("debug_needs_draft"), true)
	return false


func _poke(next: Dictionary, text: String) -> bool:
	var apply: Callable = _studio.parts().get("poke_state", Callable())
	if not apply.is_valid():
		return false
	apply.call(next)
	note("poke", text, {})
	_signature = ""
	rebuild()
	return true


# --- what changed -----------------------------------------------------------------------------------------------------


func _remember(state: Dictionary) -> void:
	_flags = (state.get("flags", {}) as Dictionary).duplicate()
	_map = String(state.get("map", ""))
	_cell = OverworldState.cell(state)
	_talking = _talk_open()


## The log's lines for what changed since the last frame: flags, quest steps, the map (a warp), a talk.
func _events_of(state: Dictionary) -> void:
	var flags: Dictionary = state.get("flags", {})
	if flags != _flags:
		var changed := DebugPokes.flag_changes(_flags, flags)
		# LEARN: `changed.set` would be the Dictionary's own set() method (a Callable), not the key "set": a key that
		# shares a name with a method is read with brackets (docs/LEARNING_LOG.md, 2026-10-14).
		for flag: String in changed["set"]:
			note("flag", StudioText.t("debug_flag_set") % flag, {"flag": flag, "set": true})
		for flag: String in changed["cleared"]:
			note("flag", StudioText.t("debug_flag_cleared") % flag, {"flag": flag, "set": false})
		for step: Dictionary in DebugPokes.step_changes(_quests(), _flags, flags):
			var text := StudioText.t("debug_step_done" if bool(step.done) else "debug_step_undone")
			note("quest", text % [String(step.title), int(step.step) + 1, String(step.text)], step)
	var map := String(state.get("map", ""))
	if map != _map:
		var cell := OverworldState.cell(state)
		note("warp", StudioText.t("debug_warp") % [_map, _cell.x, _cell.y, map, cell.x, cell.y], {"from": _map, "to": map})
	var talking := _talk_open()
	if talking != _talking:
		var who := _talker()
		note("talk", StudioText.t("debug_talk_open") % who if talking else StudioText.t("debug_talk_closed"), {"who": who})


## A thing's code ran in the town (Space, or the editor's Run).
func _thing_ran(id: String, input: Dictionary, run: Dictionary, verdict: Dictionary, usec: int) -> void:
	note("thing", _ran_text(id, input, run, verdict, usec), {"id": id, "input": input, "run": run, "verdict": verdict, "usec": usec})


## "cabbage-gate ran in 41.2 ms: in {...} → out {...}", with the error or what was refused when there was one.
static func _ran_text(id: String, input: Dictionary, run: Dictionary, verdict: Dictionary, usec: int) -> String:
	var text := StudioText.t("debug_ran") % [id, usec / 1000.0, DebugLog.value_text(input, 60), DebugLog.value_text(run.get("value"), 60)]
	if not bool(verdict.get("ok", false)):
		var why := String(run.get("error", verdict.get("reason", "")))
		text += " " + StudioText.t("debug_ran_failed") % [DebugLog.value_text(why, 80), int(verdict.get("line", 0))]
	elif not (verdict.get("dropped", []) as Array).is_empty():
		text += " " + StudioText.t("debug_ran_dropped") % ", ".join(PackedStringArray(verdict.dropped))
	return text


func _hook_things() -> void:
	var host := _host()
	if host != null and _hooked != host:
		_hooked = host
		host.ran.connect(_thing_ran)


func _watch() -> void:
	var now := _content_stamps()
	for path: String in now:
		if int(_stamps.get(path, -1)) != int(now[path]):
			reload_content(path.get_file())
			return
	if now.size() != _stamps.size():
		reload_content()


## The modified time of every overworld content file, by path.
func _content_stamps() -> Dictionary:
	var out := {}
	var packs := _studio.content_root().path_join("packs")
	for pack: String in StudioFiles.list_dirs(packs):
		var root := packs.path_join(pack).path_join("overworld")
		for folder: String in ["", "maps", "talk", "things"]:
			var dir := root.path_join(folder) if folder != "" else root
			for file: String in StudioFiles.list_files(dir, ".jsonc"):
				var path := dir.path_join(file)
				out[path] = FileAccess.get_modified_time(path)
	return out


# --- the panel ------------------------------------------------------------------------------------------------------


func rebuild() -> void:
	if not visible:
		return
	var state := _state()
	_signature = _signature_of(state)
	_mode_line.text = StudioText.t("debug_mode_draft" if can_poke() else "debug_mode_real")
	_draft_button.visible = not can_poke()
	Ui.clear(_body)
	if tab == "events":
		_events_tab()
		return
	if state.is_empty():
		return
	_player_part(state)
	_quests_part(state)
	_flags_part(state)
	_things_part(state)
	_lessons_part(state)
	_boots_part(state)
	_content_part()


func _player_part(state: Dictionary) -> void:
	var cell := OverworldState.cell(state)
	_heading("debug_player")
	_text(StudioText.t("debug_where") % [String(state.get("map", "")), cell.x, cell.y, String(state.get("facing", ""))])
	_text(StudioText.t("debug_teleport_hint"), UiTheme.MUTED)


func _quests_part(state: Dictionary) -> void:
	_heading("debug_quests")
	var flags: Dictionary = state.get("flags", {})
	for entry: Dictionary in Quests.entries(_quests(), flags):
		var id := String(entry.id)
		var title := StudioStyle.line("%s  (%s)" % [String(entry.title), String(entry.status)], UiTheme.AMBER if String(entry.status) == Quests.OPEN else UiTheme.TEXT)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		var jump := _small(StudioText.t("debug_jump"), func() -> void: jump_to(id), StudioText.t("debug_jump_tip"))
		jump.name = "Jump_" + id
		_body.add_child(Ui.hbox([title, jump], 4))
		var steps: Array = entry.steps
		for i: int in steps.size():
			var step: Dictionary = steps[i]
			var done := bool(step.done)
			var words := StudioStyle.line(("✓ " if done else "○ ") + String(step.text), UiTheme.TEXT if done else UiTheme.MUTED)
			words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var index := i
			var button := _small(StudioText.t("debug_reopen" if done else "debug_done"), func() -> void:
				if done:
					reopen_step(id, index)
				else:
					complete_step(id, index)
			)
			button.name = "Step_%s_%d" % [id, i]
			_body.add_child(Ui.hbox([Ui.spacer(8, 0), words, button], 4))


func _flags_part(state: Dictionary) -> void:
	_heading("debug_flags")
	var flags: Dictionary = state.get("flags", {})
	var names: Array[String] = []
	for flag: String in flags:
		if bool(flags[flag]):
			names.append(flag)
	names.sort()
	for flag: String in names:
		var label := StudioStyle.line(flag)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gone := _small("✕", func() -> void: clear_flag(flag), StudioText.t("debug_clear_tip"))
		gone.name = "Clear_" + flag
		_body.add_child(Ui.hbox([label, gone], 4))
	var entry := LineEdit.new()
	entry.name = "NewFlag"
	entry.placeholder_text = StudioText.t("debug_new_flag")
	entry.add_theme_font_size_override("font_size", StudioStyle.SMALL)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.focus_mode = Control.FOCUS_CLICK
	entry.text_submitted.connect(func(text: String) -> void: set_flag(text))
	_body.add_child(Ui.hbox([entry, _small(StudioText.t("debug_set"), func() -> void: set_flag(entry.text))], 4))


## The things on this map that take code: each one's fields as the town keeps them, Reset and Run again.
func _things_part(state: Dictionary) -> void:
	var things: Array[Dictionary] = []
	for object: Dictionary in _studio.current_map().get("objects", []):
		if ThingHost.takes_code(object) and String(object.get("id", "")) != "":
			things.append(object)
	if things.is_empty():
		return
	_heading("debug_things")
	var saved: Dictionary = state.get("things", {})
	for thing: Dictionary in things:
		var id := String(thing.id)
		var entry: Dictionary = saved.get(id, {}) if saved.get(id, {}) is Dictionary else {}
		var fields := TownThings.fields_of(thing, entry.get("fields", {}) if entry.get("fields", {}) is Dictionary else {})
		var name_label := StudioStyle.line(id, UiTheme.AMBER)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var reset := _small(StudioText.t("debug_reset"), func() -> void: reset_thing(id), StudioText.t("debug_reset_tip"))
		reset.name = "Reset_" + id
		var again := _small(StudioText.t("debug_rerun"), func() -> void: ask_rerun(thing), StudioText.t("debug_rerun_tip"))
		again.name = "Rerun_" + id
		_body.add_child(Ui.hbox([name_label, reset, again], 4))
		_code(DebugLog.value_text(fields, 200))


func _lessons_part(state: Dictionary) -> void:
	_heading("debug_lessons")
	for id: String in Lessons.IDS:
		var record := Lessons.record(state, id)
		var passed := bool(record.get("passed", false))
		_text("%s: %s" % [id, StudioText.t("debug_passed" if passed else "debug_not_passed")], UiTheme.TEXT if passed else UiTheme.MUTED)


func _boots_part(state: Dictionary) -> void:
	_heading("debug_boots")
	_text(String(state.get("language", "")), UiTheme.MUTED)
	_code(OverworldState.boots_source(state))


func _content_part() -> void:
	_heading("debug_content")
	var reload := _small(StudioText.t("debug_reload"), func() -> void: reload_content(), StudioText.t("debug_reload_tip"))
	reload.name = "Reload"
	var watch := _small(StudioText.t("debug_watch"), Callable(), StudioText.t("debug_watch_tip"))
	watch.name = "Watch"
	StudioStyle.choose(watch, watching)
	watch.pressed.connect(func() -> void:
		watching = not watching
		StudioStyle.choose(watch, watching)
	)
	_body.add_child(Ui.hbox([reload, watch], 4))


func _events_tab() -> void:
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 3)
	chips.add_theme_constant_override("v_separation", 3)
	var all := _small(StudioText.t("debug_all"), func() -> void: _filter([] as Array[String]))
	StudioStyle.choose(all, kinds.is_empty())
	chips.add_child(all)
	for kind: String in DebugLog.KINDS:
		var chip := _small(StudioText.t("debug_kind_" + kind), func() -> void: _filter([kind] as Array[String]))
		chip.name = "Kind_" + kind
		StudioStyle.choose(chip, kinds.size() == 1 and kinds[0] == kind)
		chips.add_child(chip)
	_body.add_child(chips)
	var shown := DebugLog.latest(book, SHOWN_EVENTS, kinds)
	if shown.is_empty():
		_text(StudioText.t("debug_no_events"), UiTheme.MUTED)
	for entry: Dictionary in shown:
		var when := StudioStyle.caption(DebugLog.clock(int(entry.at), _began))
		when.custom_minimum_size.x = 46
		var kind := StudioStyle.caption(String(entry.kind))
		kind.custom_minimum_size.x = 44
		var words := StudioStyle.line(String(entry.text))
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_body.add_child(Ui.hbox([when, kind, words], 4))


func _filter(only: Array[String]) -> void:
	kinds = only
	rebuild()


func _heading(key: String) -> void:
	_body.add_child(Ui.spacer(0, 4))
	_body.add_child(StudioStyle.caption(StudioText.t(key)))


func _text(words: String, colour := UiTheme.TEXT) -> void:
	var label := StudioStyle.line(words, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)


func _code(text: String) -> void:
	var label := Ui.label(text, "Code", true)
	label.add_theme_font_override("font", UiTheme.code_font())
	label.add_theme_font_size_override("font_size", CODE_SIZE)
	label.add_theme_color_override("font_color", UiTheme.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_body.add_child(label)


func _small(text: String, on_pressed: Callable, tip := "") -> Button:
	var button := StudioStyle.button(text, on_pressed, false, tip)
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size.y = 22
	return button


# --- what it reads ----------------------------------------------------------------------------------------------------


func _state() -> Dictionary:
	var read: Variant = _studio.parts().get("state")
	return (read as Callable).call() if read is Callable else {}


func _host() -> ThingHost:
	var read: Variant = _studio.parts().get("things")
	return (read as Callable).call() as ThingHost if read is Callable else null


func _quests() -> Dictionary:
	return _studio.catalog().get("quests", {})


func _quest_title(id: String) -> String:
	return String((_quests().get(id, {}) as Dictionary).get("title", id))


func _talk_open() -> bool:
	var talk: Variant = _studio.parts().get("talk")
	return talk is DialogueBox and (talk as DialogueBox).busy


func _talker() -> String:
	var talk: Variant = _studio.parts().get("talk")
	if not talk is DialogueBox:
		return ""
	var person: Variant = (talk as DialogueBox).get("_person")
	return String((person as Dictionary).get("name", "")) if person is Dictionary else ""


## What the State tab shows depends on: when it changes, the tab is drawn again.
func _signature_of(state: Dictionary) -> String:
	var shown := [state.get("map"), state.get("cell"), state.get("facing"), state.get("flags"), state.get("things"), state.get("lessons"), state.get("language"), state.get("boots"), can_poke()]
	return str(shown)
