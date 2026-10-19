class_name OverworldScreen
extends Control
## Lanternroot's overworld (ADR-0061): a small top-down town you walk on your own code. The arrow keys (or WASD, or a
## pad) are passed to the player's `on_key` through the table BootsRun made from it; Space talks to whoever you face, or
## runs the thing in front of you (ThingHost); X opens that thing's code; B opens your boots; Esc (or a pad's Start)
## opens the menu (PauseMenu) and its quest log (QuestLog). Hotaru, a
## firefly, floats beside you and says what your boots are doing; the tracker (QuestTracker) says what to do next.
## Rules live in game/core/overworld/; this screen draws the town and sends it keys.

const START_MAP := "home"
## The town outdoors; every other map is indoors, for the music.
const TOWN_MAP := "lanternroot"
const MUSIC_TOWN := "music-lanternroot-town"
const MUSIC_INDOORS := "music-lanternroot-home"
const MUSIC_CODING := "music-lanternroot-lesson"
## What the mode played before its own tracks; it plays wherever one is not made yet.
const MUSIC_BEFORE := "music-rest"
## How long "Hotaru is reading your boots..." stays up: until the table lands, with this as the longest it may wait.
const READING_HOLD := 120.0
## How long Hotaru's notice mark stays up after a quest is finished.
const NOTICE_TIME := 4.0
const DIRECTIONS := {
	KEY_UP: "up",
	KEY_W: "up",
	KEY_DOWN: "down",
	KEY_S: "down",
	KEY_LEFT: "left",
	KEY_A: "left",
	KEY_RIGHT: "right",
	KEY_D: "right"
}
const PAD := {
	JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down", JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right"
}

static var _catalog_cache: Dictionary = {}

var catalog: Dictionary = {}
var state: Dictionary = {}
var table: Dictionary = {}

var _store: OverworldStore
var _view: PixelView
var _map: TownMapView
var _camera: Camera2D
var _player: Walker
var _hotaru: HotaruSprite
var _talk: DialogueBox
var _boots: BootsEditor
var _creator: CharacterCreator
## The music track asked for last (_update_music).
var _music_wanted := ""
var _lessons: LessonHost
var _things: ThingTown
var _menu: PauseMenu
var _log: QuestLog
var _tracker: QuestTracker
## Lanternroot Studio (ADR-0066), mounted only when StudioMode.available(); null otherwise.
var _studio: StudioMode
## Esc came mid-step: the menu opens when the step lands, unless the step starts something (a door, a talk).
var _menu_wanted := false
var _notice_serial := 0
var _bubble: PanelContainer
var _bubble_text: Label
var _prompt: Label
var _fade: ColorRect
var _held: Array[String] = []
var _busy := false
var _told := {}
var _table_source := ""
## Each boots run takes a serial; only the newest run's answer may become the table (a late one is dropped).
var _table_serial := 0
var _reading := false
var _quest_wanted := ""
var _bubble_tween: Tween
## Play draft owns a copy of the character. The original comes back before its save folder does.
var _studio_play_state: Dictionary = {}
var _studio_play_table: Dictionary = {}
var _studio_play_source := ""
var _studio_play_told: Dictionary = {}
## v0.4, the parts of the game the player builds: their code answering the game's questions (PartsRuntime).
var _parts: PartsRuntime
## Where the parts get built: a talk's "task:<id>" opens its editor (TaskHost, TaskEditor).
var _tasks: TaskHost
## The parts' panels (v0.4): Hotaru's pocket menu (before the player's own), the Options page, the music box, the bag,
## the Workbench, the full map, the credits, and the title's settings opened from Options.
var _pocket: PocketMenu
var _options_page: OptionsPage
var _music_panel: MusicPanel
var _bag_panel: BagPanel
var _workbench: WorkbenchPanel
var _full_map: FullMap
## Chapter 3: Nym's shop, the rain over the town, and Hotaru's glow as it eases to the player's glow().
var _shop_panel: ShopPanel
var _rain: RainLayer
var _glow_now := -1.0
var _credits: CreditsRoll
var _settings_page: CenterContainer
## The day's tint over the town (the clock part): CanvasModulate in the town's own viewport, never over the UI.
var _tint: CanvasModulate
## Seconds of play not yet a whole town minute.
var _clock_carry := 0.0
## Whether the lane's lamps are drawn glowing now (evening and night, once lit): -1 until the town is drawn.
var _glow_shown := -1
## The talk open now, and who it is with: a talk's "give:" asks again when the giving is done.
var _last_talk: Dictionary = {}
var _last_speaker: Dictionary = {}


func _ready() -> void:
	Game.boot()
	theme = FoundryUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog = catalog_of()
	_store = OverworldStore.for_profile()
	_build()
	var parts := {"view": _view, "map": _map, "camera": _camera, "player": _player, "current": _current}
	parts.merge({"held": _held, "idle": _idle, "hud": [_tracker, _prompt, _bubble], "catalog": catalog_of})
	parts["store"] = _store
	parts["playtest_begin"] = _studio_begin_playtest
	parts["playtest_end"] = _studio_end_playtest
	parts["reload_content"] = _studio_reload_content
	parts["show_map"] = _studio_show_map
	# The developer inspector (Studio S7): what it reads, and the pokes it makes on the play-test state.
	parts["state"] = func() -> Dictionary: return state
	parts["poke_state"] = _studio_poke_state
	parts["teleport"] = _studio_teleport
	parts["things"] = func() -> ThingHost: return _things.host
	parts["talk"] = _talk
	_studio = StudioMode.mount(self, parts)
	_parts = PartsRuntime.new()
	_parts.name = "Parts"
	add_child(_parts)
	_parts.setup(catalog, func() -> Dictionary: return state)
	_parts.problem.connect(_on_part_problem)
	_parts.changed.connect(_on_part_changed)
	var saved := _store.load_state()
	var home: Dictionary = catalog.maps.get(START_MAP, {})
	var fresh := OverworldState.fresh(START_MAP, home.get("start", Vector2i.ZERO), "down", BootsCode.PYTHON)
	state = OverworldState.normalized(saved, fresh) if not saved.is_empty() else fresh
	state = LessonHost.restore(state)
	if not catalog.maps.has(String(state.map)):
		# A map that is gone (a room made in the Studio and reverted, say) sends the player home, and keeps what they did.
		state = OverworldState.moved(state, START_MAP, home.get("start", Vector2i.ZERO), "down")
	_enter_map(String(state.map), OverworldState.cell(state), String(state.facing))
	_parts.refresh()
	_tracker.set_parts(_parts.progress_of, _parts.place_at)
	_tracker.set_tracked(String(state.get("tracked", "")))
	_tracker.follow(catalog.quests, Parts.facts(state))
	_show_minimap()
	DialogueBox.set_text_speed(String(_options().get("text_speed", "normal")))
	if (state.look as Dictionary).is_empty():
		_creator.open(catalog.looks)
	else:
		_player.set_sheet(OverworldArt.player_character(state.look))
		_after_creator()


static func catalog_of() -> Dictionary:
	if _catalog_cache.is_empty():
		var loaded := OverworldContent.load_world()
		for diagnostic: Dictionary in loaded.diagnostics:
			push_error(ContentLoader.describe(diagnostic))
		_catalog_cache = loaded.catalog
	return _catalog_cache


## Keep the shared catalog Dictionary alive: the map renderer and Studio both hold it.
func _studio_reload_content() -> void:
	var root := _studio.content_root() if _studio != null else ContentLoader.ROOT
	var loaded := OverworldContent.load_world(root)
	for diagnostic: Dictionary in loaded.diagnostics:
		push_error(ContentLoader.describe(diagnostic))
	_catalog_cache.clear()
	_catalog_cache.merge(loaded.catalog, true)
	catalog = _catalog_cache
	# The things' files are a new Dictionary now: the runner reads the new one.
	_things.host.setup(catalog.things, func() -> Dictionary: return state)
	_tracker.follow(catalog.quests, state.flags)
	_refresh_table(true)


func _studio_show_map(id: String) -> void:
	if not catalog.maps.has(id):
		return
	var map: Dictionary = catalog.maps[id]
	_enter_map(id, map.start, String(map.get("facing", "down")))


## A poke of the developer inspector (Studio S7): the state becomes `next` (flags, things), is saved where the
## play-test saves, and the town and the tracker follow it.
func _studio_poke_state(next: Dictionary) -> void:
	state = next
	_save()
	_draw_map()
	_tracker.follow(catalog.quests, state.flags)


## Ctrl-click in Play (Studio S7): the player is put on `cell` of `map_id`, facing as they were. False where nobody can
## stand.
func _studio_teleport(map_id: String, cell: Vector2i) -> bool:
	var map: Dictionary = catalog.maps.get(map_id, {})
	if map.is_empty() or OverworldMap.blocked(map, cell, {}, TownThings.open_cells(map, state.get("things", {}))):
		return false
	_held.clear()
	_enter_map(map_id, cell, String(state.facing))
	return true


func _studio_begin_playtest(wanted: Vector2i = Vector2i(-1, -1)) -> void:
	if not _studio_play_state.is_empty():
		return
	# LEARN: redirecting a file writer does not isolate the state it will eventually write.
	_studio_play_state = state.duplicate(true)
	_studio_play_table = table.duplicate(true)
	_studio_play_source = _table_source
	_studio_play_told = _told.duplicate(true)
	state = state.duplicate(true)
	_held.clear()
	var map := _current()
	var cell: Vector2i = map.get("start", OverworldState.cell(state))
	if not OverworldMap.blocked(map, wanted):
		cell = wanted
	_enter_map(String(state.map), cell, String(state.facing))


func _studio_end_playtest() -> void:
	if _studio_play_state.is_empty():
		return
	state = _studio_play_state
	_studio_play_state = {}
	table = _studio_play_table
	_studio_play_table = {}
	_table_source = _studio_play_source
	_told = _studio_play_told
	_studio_play_told = {}
	# A boots job launched in the draft must not replace the restored table when it finishes.
	_table_serial += 1
	_reading = false
	_held.clear()
	if _map.is_inside_tree() and _player.is_inside_tree():
		_draw_map()
		_player.place(OverworldState.cell(state), String(state.facing))
		_player.set_sheet(OverworldArt.player_character(state.look))
		_hotaru.settle()
		_tracker.follow(catalog.quests, state.flags)
		_hush()


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = Color("#1c1a30")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	_view = PixelView.new()
	add_child(_view)
	_map = TownMapView.new(catalog)
	_view.viewport.add_child(_map)
	_camera = Camera2D.new()
	_map.add_child(_camera)
	_camera.make_current()
	_tint = CanvasModulate.new()
	_tint.color = Color.WHITE
	_view.viewport.add_child(_tint)
	_player = Walker.new()
	_player.set_meta("player", true)
	_player.arrived.connect(_on_arrived)
	_map.things.add_child(_player)
	# Hotaru is drawn over the town, after its things, so a house never hides her.
	_hotaru = HotaruSprite.new()
	_hotaru.target = _player
	_map.add_child(_hotaru)
	# The rain falls over the town and under every panel (it is added before them).
	_rain = RainLayer.new()
	add_child(_rain)

	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.1, 0.075, 0.06, 0.92), Color("#9ed84e"), 2, 12, Vector2(18, 12))
	)
	_bubble.position = Vector2(40, 36)
	_bubble.custom_minimum_size = Vector2(0, 0)
	_bubble.visible = false
	var face := TextureRect.new()
	face.texture = OverworldArt.portrait("hotaru")
	face.custom_minimum_size = Vector2(56, 56)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubble_text = Ui.label("", "", true)
	_bubble_text.custom_minimum_size = Vector2(440, 0)
	_bubble_text.add_theme_font_override("font", OverworldStyle.body_font())
	_bubble_text.add_theme_font_size_override("font_size", OverworldStyle.BODY)
	_bubble_text.add_theme_color_override("font_color", Color("#f3e6c8"))
	_bubble.add_child(Ui.hbox([face, _bubble_text], 14))
	add_child(_bubble)

	_prompt = Ui.label("", "Muted")
	_prompt.add_theme_font_override("font", OverworldStyle.body_font())
	_prompt.add_theme_font_size_override("font_size", OverworldStyle.LABEL)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-200, -70)
	_prompt.custom_minimum_size = Vector2(400, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	var keys := Ui.label(Text.t("Arrows: walk   Space: talk   B: boots   Esc: menu"), "Faint")
	keys.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.position = Vector2(-560, -36)
	add_child(keys)

	_talk = DialogueBox.new()
	_talk.ended.connect(_on_talk_ended)
	add_child(_talk)
	_boots = BootsEditor.new()
	_boots.tried.connect(_on_boots_tried)
	_boots.closed.connect(_on_boots_closed)
	_boots.language_chosen.connect(_on_language_chosen)
	add_child(_boots)
	_things = ThingTown.new(self)
	add_child(_things.host)
	_lessons = LessonHost.new()
	_lessons.state_changed.connect(_on_lesson_state)
	_lessons.saved.connect(_on_lesson_saved)
	add_child(_lessons)
	_tasks = TaskHost.new()
	_tasks.setup(catalog)
	_tasks.state_changed.connect(_on_task_state)
	_tasks.built.connect(_on_part_built)
	add_child(_tasks)
	_creator = CharacterCreator.new()
	_creator.done.connect(_on_creator_done)
	add_child(_creator)
	_menu = PauseMenu.new()
	_menu.chosen.connect(_on_menu_chosen)
	_menu.closed.connect(_on_menu_closed)
	add_child(_menu)
	_log = QuestLog.new()
	_log.closed.connect(_on_panel_closed)
	_log.track.connect(_on_track)
	add_child(_log)
	_pocket = PocketMenu.new()
	_pocket.chosen.connect(_on_pocket_chosen)
	_pocket.closed.connect(_on_pocket_closed)
	add_child(_pocket)
	_options_page = OptionsPage.new()
	_options_page.changed.connect(_on_option_changed)
	_options_page.open_music.connect(_open_music_panel)
	_options_page.more_settings.connect(_open_more_settings)
	_options_page.closed.connect(_on_panel_closed)
	add_child(_options_page)
	_music_panel = MusicPanel.new()
	_music_panel.play.connect(_on_music_play)
	_music_panel.set_town_track.connect(_on_town_track)
	_music_panel.closed.connect(_on_music_closed)
	add_child(_music_panel)
	_bag_panel = BagPanel.new()
	_bag_panel.closed.connect(_on_panel_closed)
	_bag_panel.tidy.connect(_on_bag_tidy)
	add_child(_bag_panel)
	_shop_panel = ShopPanel.new()
	_shop_panel.sell.connect(_on_shop_sell)
	_shop_panel.buy.connect(_on_shop_buy)
	_shop_panel.closed.connect(_on_panel_closed)
	add_child(_shop_panel)
	_workbench = WorkbenchPanel.new()
	_workbench.open_part.connect(_on_workbench_part)
	_workbench.history_viewed.connect(func(_id: String) -> void: _set_flag("history-viewed"))
	_workbench.closed.connect(_on_panel_closed)
	add_child(_workbench)
	_full_map = FullMap.new()
	_full_map.closed.connect(_on_panel_closed)
	add_child(_full_map)
	_settings_page = CenterContainer.new()
	_settings_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_page.visible = false
	add_child(_settings_page)
	# The tracker's toast is drawn over the menu (a save from the menu can finish a quest); its card hides under one.
	_tracker = QuestTracker.new()
	_tracker.requested.connect(_open_quest_details)
	add_child(_tracker)
	_tracker.setup(catalog)
	_tracker.minimap().open_full.connect(_open_full_map)
	_credits = CreditsRoll.new()
	_credits.finished.connect(_on_credits_finished)
	add_child(_credits)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


# --- maps ---------------------------------------------------------------------------------------------------------


func _current() -> Dictionary:
	return catalog.maps.get(String(state.map), {})


func _enter_map(id: String, cell: Vector2i, facing: String) -> void:
	state = OverworldState.moved(state, id, cell, facing)
	_draw_map()
	# Interiors are the town's scale (ADR-0064): a room is drawn alone, centred on black, with no zoom.
	_camera.zoom = Vector2.ONE
	_player.place(cell, String(state.facing))
	_hotaru.facing = _player.facing
	_hotaru.settle()
	_aim_camera(true)
	_refresh_table()
	if _tracker != null:
		_show_minimap()
		_apply_weather()
		_update_tint(0.0, true)
		_move_people()


## The music for where the player is and what they are doing (Concept/v0.3/13-soundtrack-solid.md): coding (the
## boots, a lesson or a thing's code open), the town, or indoors. A track not made yet falls back to the place's, and
## in the end to the old one, so the town never goes quiet. It changes only when the wanted track does.
func _update_music() -> void:
	var place := MUSIC_TOWN if String(state.get("map", "")) == TOWN_MAP else MUSIC_INDOORS
	# The music box (v0.4): the track the player chose plays in town and indoors, not in the code editors.
	var chosen := String((state.get("options", {}) as Dictionary).get("track", "")) if state.get("options") is Dictionary else ""
	if chosen != "" and Parts.built(state, Parts.MUSIC):
		place = chosen
	var coding: bool = _boots.visible or _lessons.editing() or _things.host.editing() or _tasks.editing()
	var wanted := MUSIC_CODING if coding else place
	if wanted == _music_wanted:
		return
	_music_wanted = wanted
	Sound.music_first([wanted, place, MUSIC_BEFORE])


func _aim_camera(snap := false) -> void:
	var map := _current()
	var world := Vector2(OverworldMap.size_of(map) * TownMapView.TILE)
	var view := Vector2(_view.viewport.size) / _camera.zoom
	var want := _player.position + Vector2(0, -TownMapView.TILE / 2.0)
	for axis in 2:
		if world[axis] <= view[axis]:
			want[axis] = world[axis] / 2.0
		else:
			want[axis] = clampf(want[axis], view[axis] / 2.0, world[axis] - view[axis] / 2.0)
	_camera.position = want.round()
	if snap:
		_camera.reset_smoothing()


func _process(delta: float) -> void:
	if _studio != null and _studio.editing:
		return
	_update_music()
	_aim_camera()
	_update_prompt()
	_tracker.set_shown(
		not (
			_talk.busy or _boots.visible or _creator.visible or _lessons.busy() or _things.busy() or _tasks.busy()
			or _paused()
		)
	)
	_update_tint(delta)
	_update_glow(delta)
	if _paused():
		return
	state.played_seconds = float(state.get("played_seconds", 0.0)) + delta
	_tick_clock(delta)
	if _menu_wanted and not _player.moving:
		_menu_wanted = false
		if _idle():
			_open_menu()
	if _quest_wanted != "" and not _player.moving and _idle():
		var id := _quest_wanted
		_quest_wanted = ""
		_show_quest_log(id)
	if not _idle() or _player.moving:
		return
	if _held.is_empty() and _next_beat():
		return
	if not _held.is_empty():
		_step(_held[-1])


## The menu (or the quest log over it) is open: the town waits, and no time is played.
func _paused() -> bool:
	return (
		_menu.is_open() or _log.is_open() or _pocket.is_open() or _panel_open() or _credits.is_rolling()
		or _settings_page.visible
	)


## One of the parts' panels is open over the town.
func _panel_open() -> bool:
	return (
		_options_page.is_open() or _music_panel.is_open() or _bag_panel.is_open() or _workbench.is_open()
		or _full_map.is_open() or _shop_panel.is_open()
	)


## Nothing is open over the town and no door is under way: the player can walk, talk and open things.
func _idle() -> bool:
	return not (
		_busy or _talk.busy or _boots.visible or _creator.visible or _lessons.busy() or _things.busy() or _tasks.busy()
		or _paused()
	)


# --- input --------------------------------------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if _studio != null and _studio.editing:
		return
	var direction := ""
	var pressed := false
	if event is InputEventKey and not (event as InputEventKey).echo:
		direction = String(DIRECTIONS.get((event as InputEventKey).keycode, ""))
		pressed = event.is_pressed()
	elif event is InputEventJoypadButton:
		direction = String(PAD.get((event as InputEventJoypadButton).button_index, ""))
		pressed = event.is_pressed()
	if direction != "":
		_held.erase(direction)
		if pressed:
			_held.append(direction)
		get_viewport().set_input_as_handled()
		return
	if not event.is_pressed() or (event is InputEventKey and (event as InputEventKey).echo):
		return
	if _talk.busy:
		if _is_accept(event):
			_talk.advance()
			get_viewport().set_input_as_handled()
		return
	if not _idle():
		return
	if _is_accept(event):
		_interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).keycode in [KEY_B, KEY_TAB]:
		_open_boots()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_X:
		_things.edit_ahead()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
		_open_boots()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X:
		_things.edit_ahead()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_H:
		_tracker.toggle_hidden()
		get_viewport().set_input_as_handled()
	elif _is_menu_key(event):
		_open_menu(event is InputEventJoypadButton)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and _shortcut_of(event as InputEventKey) != "":
		_open_panel(_shortcut_of(event as InputEventKey))
		get_viewport().set_input_as_handled()


func _is_accept(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_E]
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	return false


## Esc opens the menu, and so does a pad's Start (its B stays "back", as in every menu).
func _is_menu_key(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.is_action_pressed("ui_cancel")
	return event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START


# --- walking on the player's own code -----------------------------------------------------------------------------


func _step(key: String) -> void:
	var map := _current()
	var people := _map.people_cells()
	var open := TownThings.open_cells(map, state.get("things", {}))
	var blocked := func(cell: Vector2i) -> bool: return OverworldMap.blocked(map, cell, people, open)
	var step := BootsRules.move(table, key, _player.cell, OverworldMap.size_of(map), blocked)
	match String(step.kind):
		"walk":
			_player.walk_to(step.to, String(step.facing))
			_hotaru.facing = String(step.facing)
			Sound.play("sfx-step", 0.22, randf_range(0.9, 1.1))
		"bump":
			_held.clear()
			_player.bump(String(step.facing))
			_hotaru.facing = String(step.facing)
			state = OverworldState.moved(state, String(state.map), _player.cell, String(step.facing))
			Sound.play("sfx-whiff", 0.25, 0.8)
			_tell("bump", Text.t("Bonk! Something is in the way."))
		"still":
			_held.erase(key)
			_tell("still-" + key, Text.f("Your boots don't know the %s key yet. Press B to teach them.", [Text.t(key)]))
		"empty":
			_held.clear()
			if _reading:
				_hotaru_says(_reading_text(), READING_HOLD)
			else:
				_hotaru_says(_boots_problem())
		"error":
			_held.clear()
			var error: Dictionary = step.error
			Sound.play("sfx-glitch", 0.3)
			_hotaru_says(
				Text.f("Your boots tripped on line %d: %s", [int(error.line), "%s: %s" % [error.kind, error.message]])
			)
		"far":
			_held.clear()
			_player.face(String(step.facing))
			_tell("far", Text.t("Whoa! Boots only take one step at a time: change x or y by 1."))
		"outside":
			_held.clear()
			_tell("outside", Text.t("That step would take you right off the map!"))


func _on_arrived(cell: Vector2i) -> void:
	state = OverworldState.moved(state, String(state.map), cell, _player.facing)
	_tracker.locate(String(state.map), cell)
	var warp := OverworldMap.warp_at(_current(), cell)
	if not warp.is_empty():
		_go_through(warp)
		return
	_things.step_on(cell)
	_beat_after_step()


func _go_through(warp: Dictionary) -> void:
	_busy = true
	_held.clear()
	Sound.play("sfx-open", 0.4)
	var out := create_tween()
	out.tween_property(_fade, "modulate:a", 1.0, 0.18)
	await out.finished
	var facing := String(warp.facing) if String(warp.facing) != "" else _player.facing
	var from := String(state.map)
	_enter_map(String(warp.map), warp.at, facing)
	_save()
	var back := create_tween()
	back.tween_property(_fade, "modulate:a", 0.0, 0.22)
	await back.finished
	_busy = false
	_beat_on_enter(from)


## The boots table for this map. Made again only when the code or the map's size changes, or when the player tries them
## (`force`). It is made on a thread, so the town keeps drawing while the sandbox runs, and each run takes a serial: a
## late answer never overwrites a newer one. True when this run's table is the one the town walks on now.
func _refresh_table(force := false) -> bool:
	var source := OverworldState.boots_source(state)
	var map_size := OverworldMap.size_of(_current())
	var key := "%s|%s|%s" % [state.language, map_size, source]
	if key == _table_source and not force:
		return true
	_table_source = key
	_table_serial += 1
	var serial := _table_serial
	var language := String(state.language)
	_reading = true
	_hotaru_says(_reading_text(), READING_HOLD)
	var made: Dictionary = await Background.run(func() -> Dictionary: return BootsRun.run(language, source, map_size))
	if serial != _table_serial:
		return false
	table = made
	_reading = false
	_remember_boots()
	if _bubble_text.text == _reading_text():
		_hush()
	return true


func _reading_text() -> String:
	return Text.t("Hotaru is reading your boots...")


## What Hotaru says when a key cannot be walked: the table's own message when its code failed or timed out, else
## that the boots are empty.
func _boots_problem() -> String:
	var status := String(table.get("status", ""))
	var message := String(table.get("message", ""))
	if (status in ["failed", "broken", "timeout"]) and message != "":
		return Text.t(message)
	return Text.t("Your boots are empty! Press B to open them.")


# --- boots --------------------------------------------------------------------------------------------------------


func _open_boots(hint := "") -> void:
	# Not mid-step: a step that lands under the open editor would run a talk or a door behind it.
	if _player.moving:
		return
	_held.clear()
	Sound.play("sfx-open", 0.35)
	var shown := hint
	# The first time the editor opens, it explains the one rule the boots start with (saved as a flag, in the state).
	if shown == "" and not _flag("boots-hint-seen"):
		_set_flag("boots-hint-seen")
		shown = Text.t("Your first rule: when right is pressed, x goes up by 1. Press Try them, then walk right.")
	_boots.open(state, shown if shown != "" else _boots_hint())


func _boots_hint() -> String:
	var taught := BootsRules.taught(table)
	if taught.is_empty():
		return Text.t("Each rule says what one key does. x is how far across you are; y is how far down.")
	var missing: Array[String] = []
	for key in BootsRules.KEYS:
		if not key in taught:
			missing.append(Text.t(key))
	if missing.is_empty():
		return Text.t("All four ways! You can change them however you like.")
	return Text.f("Your boots know %d of the four keys. Still to teach: %s.", [taught.size(), ", ".join(missing)])


func _on_boots_tried(tried: Dictionary) -> void:
	# Only the editor's boots, as a copy: a step can land while the editor is open (its state is from when it opened),
	# and the editor keeps changing its own state when the player picks a language.
	var already_knew_all := _flag("all-ways")
	state = OverworldState.with_boots_of(state, tried)
	_save()
	var current: bool = await _refresh_table(true)
	if not current:
		return
	var taught := BootsRules.taught(table)
	if String(table.status) == "ok":
		var message := Text.f(
			"Your boots know: %s.", [", ".join(taught.map(func(k: String) -> String: return Text.t(k)))]
		)
		if taught.is_empty():
			message = Text.t("Your boots loaded, but no key moves you yet.")
		if bool(table.remembers):
			message += (
				" "
				+ Text.t(
					"They remember things between steps; each step should depend only on the key and where you stand."
				)
			)
		_boots.report(message, not taught.is_empty())
		Sound.play("sfx-pass" if not taught.is_empty() else "sfx-chime", 0.4)
		_boots.set_hint(_boots_hint())
		_beat_after_boots(taught, already_knew_all)
	else:
		_boots.report(Text.t(String(table.message)), false)
		Sound.play("sfx-glitch", 0.3)


func _on_boots_closed() -> void:
	_held.clear()
	# Only the editor's boots are taken: a step can land while the editor is open, and the town keeps its place for it.
	state = OverworldState.with_boots_of(state, _boots.state)
	_save()


## The editor's language picker: the same blocks, in another language. Each language keeps the code typed for it, and
## the blocks are not touched. The table is made again for the new language.
func _on_language_chosen(language: String) -> void:
	if language == String(state.language) or not (language in [BootsCode.PYTHON, BootsCode.JAVASCRIPT]):
		return
	# The editor's boots carry the code typed in the language it left; the town's place and flags stay as they are.
	state = OverworldState.with_boots_of(OverworldState.with_language(state, language), _boots.state)
	_save()
	_refresh_table()


# --- talking --------------------------------------------------------------------------------------------------------


func _interact() -> void:
	var ahead := OverworldMap.ahead(_player.cell, _player.facing)
	var thing := OverworldMap.thing_at(_current(), ahead)
	if _things.use_if_code(thing):
		return
	var who := _map.person_at(ahead)
	if who != "":
		var person: Dictionary = catalog.townsfolk.get(who, {})
		(_map.people[who] as Walker).face(_opposite(_player.facing))
		_open_talk(catalog.talk.get(String(person.talk), {}), _speaker(person))
		return
	# A thing that opens a part's panel (the Workbench desk, the music box, Pell's map table), and one that gives an
	# item to the bag (an apple tree, the cabbage plot).
	var over := thing if not thing.is_empty() else OverworldMap.prop_over(_current(), ahead)
	if over.has("opens"):
		if _open_from_thing(over):
			return
		if thing.is_empty() and over.has("text"):
			_talk.say([{"text": String(over.text), "speaker": "", "mood": ""}], {"name": ""}, Parts.facts(state))
			return
	var pickup := _pickup_under(thing, ahead)
	if not pickup.is_empty():
		_pick(pickup)
		return
	# A thing with a talk (the noticeboard) opens it, with nobody's name plate; a thing with only text says that.
	var talk: Dictionary = catalog.talk.get(String(thing.get("talk", "")), {})
	if not talk.is_empty():
		_open_talk(talk, {})
		return
	if thing.has("text"):
		_talk.say([{"text": String(thing.text), "speaker": "", "mood": ""}], {"name": ""}, Parts.facts(state))


## A talk, with the town's facts beside its flags (the bag's counts, v0.4), kept so a "give:" can ask again.
func _open_talk(talk: Dictionary, speaker: Dictionary) -> void:
	_last_talk = talk
	_last_speaker = speaker
	_talk.open(talk, speaker, Parts.facts(state))


func _speaker(person: Dictionary) -> Dictionary:
	return {"name": person.get("name", ""), "portrait": person.get("portrait", ""), "voice": person.get("voice", 1.0)}


func _opposite(facing: String) -> String:
	return {"up": "down", "down": "up", "left": "right", "right": "left"}.get(facing, "down")


func _on_talk_ended(flags: Dictionary, opens: Array[String]) -> void:
	# The talk saw the bag's counts as facts beside the flags; only the flags are kept.
	state = OverworldState.remembered(state, flags)
	_save()
	if "boots" in opens:
		_open_boots()
	elif "letters" in opens:
		_open_letters()
	for opened in opens:
		if opened.begins_with("lesson:"):
			_held.clear()
			_lessons.open_lesson(opened.substr("lesson:".length()), state)
		elif opened.begins_with("give:"):
			var parts := opened.split(":")
			_give(parts[1] if parts.size() > 1 else "", int(parts[2]) if parts.size() > 2 else 1)
		else:
			_open_part_panel(opened)


## A lesson changed the town (a flag, the saved memory, the lamps): keep it, and draw the lamps as they are now.
func _on_lesson_state(changed: Dictionary) -> void:
	_take_lesson_state(changed)
	_save()
	_draw_map()


## The menu's Save ran the player's own save (lesson 2): keep what it gave, and say how it went.
func _on_lesson_saved(saved: Dictionary, message: String) -> void:
	_take_lesson_state(saved)
	_save()
	var words := message if message != "" else Text.t("Saved!")
	if _menu.is_open():
		_menu.show_status(words, UiTheme.PASS if _lessons.last_save_ok else OverworldStyle.MUTED)
	elif _pocket.is_open():
		_pocket.show_status(words, UiTheme.PASS if _lessons.last_save_ok else OverworldStyle.MUTED)
	else:
		_hotaru_says(words)


## A lesson's copy of the town, made when it opened: the town keeps its own boots and the time played since.
func _take_lesson_state(changed: Dictionary) -> void:
	var played := float(state.get("played_seconds", 0.0))
	state = OverworldState.remembered(OverworldState.with_boots_of(changed, state), state.flags)
	state.played_seconds = maxf(played, float(state.get("played_seconds", 0.0)))


## The lamps that stay dark: the lane's, until lesson 3 lights them.
func _dark_groups() -> Array:
	return [] if _flag("lamps-lit") else ["lane"]


## The letters are on Lanternroot's workbench (ADR-0055). The state is saved (by the talk's end); the letters screen's
## back control comes back here.
func _open_letters() -> void:
	_busy = true
	_held.clear()
	LanternrootScreen.returns_to = Game.OVERWORLD
	Game.go(Game.LANTERNROOT)


func _update_prompt() -> void:
	if not _idle():
		_prompt.text = ""
		return
	var ahead := OverworldMap.ahead(_player.cell, _player.facing)
	var who := _map.person_at(ahead)
	var thing := OverworldMap.thing_at(_current(), ahead)
	if who != "":
		_prompt.text = Text.f("Space: talk to %s", [Text.t(String(catalog.townsfolk.get(who, {}).get("name", "")))])
	elif _things.active(thing):
		_prompt.text = Text.t("Space: use it   X: its code")
	elif _pickup_ahead(thing) != "":
		_prompt.text = Text.f("Space: pick %s", [Text.t(String((catalog.get("items", {}) as Dictionary).get(_pickup_ahead(thing), {}).get("name", "")))])
	elif thing.has("text") or thing.has("talk"):
		_prompt.text = Text.t("Space: read")
	else:
		_prompt.text = ""


# --- things that take code ----------------------------------------------------------------------------------------


## The town as it is drawn now: its things, with the gates that are open shown open.
func _draw_map() -> void:
	_map.show_map(_current(), true, _dark_groups(), TownThings.open_cells(_current(), state.get("things", {})))
	# The town's pictures were made again: the lamps' glow is set again on the next frame.
	_glow_shown = -1


## `_draw_map` for an edit in Lanternroot Studio that changed a few objects: only theirs are made again
## (TownMapView.update_objects). {} when the whole town has to be drawn again.
func _draw_map_changed(new_of_old: PackedInt32Array, made: PackedInt32Array) -> Dictionary:
	var open := TownThings.open_cells(_current(), state.get("things", {}))
	return _map.update_objects(_current(), new_of_old, made, true, _dark_groups(), open)


# --- Hotaru's remarks ---------------------------------------------------------------------------------------------


## A remark Hotaru makes once (until the map changes): `id` keeps her from repeating herself.
func _tell(id: String, text: String, always := false) -> void:
	if _told.has(id) and not always:
		return
	_told[id] = true
	_hotaru_says(text)


## Hotaru's words in the bubble over the town. A new remark replaces the one on screen (they never stack). It stays for
## `hold` seconds, or for a length that suits the words when `hold` is negative.
func _hotaru_says(text: String, hold := -1.0) -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_text.text = text
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.15)
	tween.tween_interval(hold if hold >= 0.0 else clampf(text.length() * 0.06, 3.0, 7.0))
	tween.tween_property(_bubble, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: _bubble.visible = false)
	_bubble_tween = tween


## Hotaru stops talking at once.
func _hush() -> void:
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble.visible = false


# --- the story's beats --------------------------------------------------------------------------------------------


func _flag(name: String) -> bool:
	return bool((state.flags as Dictionary).get(name, false))


func _set_flag(name: String) -> void:
	var flags: Dictionary = (state.flags as Dictionary).duplicate()
	flags[name] = true
	state = OverworldState.flagged(state, flags)
	_save()


func _hotaru_talk(id: String) -> void:
	var talk: Dictionary = catalog.talk.get(id, {})
	if not talk.is_empty():
		_open_talk(talk, {})


func _after_creator() -> void:
	if not _flag("woke"):
		_set_flag("woke")
		_hotaru_talk("hotaru-wake")


func _beat_after_step() -> void:
	if not _flag("first-step"):
		_set_flag("first-step")
		_hotaru_talk("hotaru-first-step")


func _remember_boots() -> void:
	var milestones := BootsRules.milestones(table, state.flags)
	var remembered := OverworldState.remembered(state, milestones)
	if remembered.flags != state.flags:
		state = remembered
		_save()


func _beat_after_boots(taught: Array[String], already_knew_all: bool) -> void:
	if taught.size() == BootsRules.KEYS.size() and not already_knew_all:
		_boots.visible = false
		_hotaru_talk("hotaru-all-ways")


func _beat_on_enter(from: String) -> void:
	if String(state.map) == "lanternroot" and not _flag("left-home"):
		_set_flag("left-home")
		_hotaru_talk("hotaru-town")
	elif from != String(state.map):
		_told.clear()


func _on_creator_done(look: Dictionary, chosen_name: String) -> void:
	if not Game.profile.is_empty():
		Game.profile.japanese_reading = _creator.japanese_reading
		Game.profiles.save_profile(Game.profile)
	state.look = look
	state.name = chosen_name
	_player.set_sheet(OverworldArt.player_character(look))
	_save()
	_after_creator()


## Keeps the town's place for the player (before lesson 2 and after it; the player's own save is the menu's Save), and
## lets the tracker see the flags as they are now.
func _save() -> void:
	_store.save_state(state)
	_follow_quests()


## The tracker follows the flags. A quest just finished gets its toast, and Hotaru shows her notice for a while.
func _follow_quests() -> void:
	_pin_minimap()
	if _tracker.follow(catalog.quests, Parts.facts(state)).is_empty():
		return
	_hotaru.notice(true)
	_notice_serial += 1
	get_tree().create_timer(NOTICE_TIME).timeout.connect(_end_notice.bind(_notice_serial))


func _end_notice(serial: int) -> void:
	if serial == _notice_serial:
		_hotaru.notice(false)


# --- the parts of the game the player builds (Concept/v0.4) --------------------------------------------------------


## The day's tint for each of the player's phases (time_of_day), blended in over about twenty town minutes.
## How grey a cloudy or rainy day turns the town's tint, and how fast Hotaru's glow eases to the next second's value.
const WEATHER_GREY := Color("#9aa3b5")
const GLOW_EASE := 6.0
## Waiting for the rain wakes the town at eight in the morning.
const RAIN_MORNING := 8 * 60
const TINTS := {
	"morning": Color("#fff6e8"), "afternoon": Color("#ffffff"), "evening": Color("#ffd9bf"), "night": Color("#8c9ef2")
}
## Town minutes per second played: a day is 24 minutes.
const CLOCK_RATE := 1.0
## Where the clock starts when it is first built: 17:00, an hour before evening.
const CLOCK_FIRST_MINUTE := 1020
## How fast the tint follows its phase (a time constant, in seconds).
const TINT_EASE := 4.0
## A lit lamp of the lane, from evening.
const LAMP_GLOW := Color(1.25, 1.2, 1.1)


## A part's code went wrong for the game (once per problem): Hotaru says so.
func _on_part_problem(_part: String, words: String) -> void:
	_hotaru_says(words)


## A part's tables landed: what shows them is drawn again.
func _on_part_changed(part: String) -> void:
	match part:
		Parts.MAP:
			_show_minimap()
		Parts.PROGRESS:
			_tracker.set_parts(_parts.progress_of, _parts.place_at)
		Parts.CLOCK:
			_tracker.set_clock(_parts.clock_text_at(int(state.get("clock", OverworldState.START_MINUTE))))
			_apply_weather()
			_update_tint(0.0, true)
		Parts.WEATHER:
			_apply_weather()
			_update_tint(0.0, true)
		Parts.HOURS:
			_move_people()


## A phase of the day (what the player's time_of_day() gives) in the player's language; anything else as it is.
static func phase_word(phase: String) -> String:
	match phase:
		"morning":
			return Text.t("morning")
		"afternoon":
			return Text.t("afternoon")
		"evening":
			return Text.t("evening")
		"night":
			return Text.t("night")
	return phase


## The town's clock runs once the clock part is built: a town minute for each second played (not while paused).
func _tick_clock(delta: float) -> void:
	if not Parts.built(state, Parts.CLOCK):
		return
	_clock_carry += delta * CLOCK_RATE
	if _clock_carry < 1.0:
		return
	var whole := int(_clock_carry)
	_clock_carry -= whole
	var before := int(state.get("clock", OverworldState.START_MINUTE))
	state.clock = posmod(before + whole, Parts.DAY_MINUTES)
	# A new day at midnight (the weather follows the day); a new hour moves the townsfolk who keep hours.
	if int(state.clock) < before:
		state.day = int(state.get("day", 0)) + 1
		_weather_changed()
	if floori(int(state.clock) / 60.0) != floori(before / 60.0):
		_move_people()
	_tracker.set_clock(_parts.clock_text_at(int(state.clock)))
	if String(state.map) == TOWN_MAP and _parts.phase_at(int(state.clock)) == "evening" and not _flag("clock-evening"):
		_set_flag("clock-evening")


## The town's tint follows the player's time of day; indoors it is softer. Before the clock is built it is always day.
## `snap` sets it at once (a map entered, the clock's table landed); otherwise it eases over a few seconds.
func _update_tint(delta: float, snap := false) -> void:
	var phase := _parts.phase_at(int(state.get("clock", OverworldState.START_MINUTE)))
	var want: Color = TINTS.get(phase, Color.WHITE)
	if String(state.get("map", "")) != TOWN_MAP:
		want = want.lerp(Color.WHITE, 0.5)
	elif _rain != null and _rain.weather() in ["cloud", "rain"]:
		# A grey day (the player's weather()): the town a little greyer, a rainy one a little more.
		want = want.lerp(WEATHER_GREY, 0.22 if _rain.weather() == "cloud" else 0.3)
	_tint.color = want if snap else _tint.color.lerp(want, clampf(delta / TINT_EASE, 0.0, 1.0))
	# The lane's lit lamps glow brighter from evening (Concept/v0.4/01, section 10).
	var glow := 1 if _flag("lamps-lit") and phase in ["evening", "night"] else 0
	if glow != _glow_shown:
		_glow_shown = glow
		for lamp in LessonHost.lane_sprites(_map, OverworldState.cell(state)):
			lamp.modulate = LAMP_GLOW if glow == 1 else Color.WHITE


## The pickup of the prop on `cell` ahead: the solid thing there, else a walkable prop over the cell (a crop row);
## {} when it gives nothing.
func _pickup_under(thing: Dictionary, cell: Vector2i) -> Dictionary:
	var prop := thing if not thing.is_empty() else OverworldMap.prop_over(_current(), cell)
	if prop.is_empty():
		return {}
	var footprint := Rect2i(OverworldMap.cell_of(prop.get("at", [-1, -1])), OverworldMap.cell_of(prop.get("size", [1, 1])))
	return Bag.pickup_at(catalog.get("pickups", {}), String(state.map), footprint)


## The item the prop ahead would give, when the bag is built and it has grown back: "" otherwise.
func _pickup_ahead(thing: Dictionary) -> String:
	if not Parts.built(state, Parts.BAG):
		return ""
	var pickup := _pickup_under(thing, OverworldMap.ahead(_player.cell, _player.facing))
	if pickup.is_empty():
		return ""
	if not Bag.ripe(state, String(state.map), OverworldMap.cell_of(pickup.at), float(pickup.get("regrow", 240.0))):
		return ""
	return String(pickup.item)


## Picks what a prop gives into the bag with the player's own add(). Before the bag is built Hotaru only wishes.
func _pick(pickup: Dictionary) -> void:
	var item := String(pickup.item)
	var item_name := _item_name(item)
	if not Parts.built(state, Parts.BAG):
		_tell("no-bag", Text.t("Ooh, we could pick that! But where would we put it? Nym makes bags... well, Nym codes bags."))
		return
	var at := OverworldMap.cell_of(pickup.at)
	if not Bag.ripe(state, String(state.map), at, float(pickup.get("regrow", 240.0))):
		_hotaru_says(Text.t("We picked that already. It'll grow back soon."))
		return
	_busy = true
	_held.clear()
	var added: Dictionary = await _parts.bag_add(item)
	_busy = false
	if not bool(added.ok):
		Sound.play("sfx-glitch", 0.3)
		_hotaru_says(String(added.words) + " " + Text.t("Your bag's code is in the Workbench."))
		return
	var first := not _flag("picked-" + item)
	state.bag = added.bag
	state = Bag.picked(state, String(state.map), at, item)
	_save()
	Sound.play("sfx-chime", 0.35, 1.1)
	_hotaru_says(Text.f("%s, into the bag! (%d now)", [item_name, Bag.count(state.bag, item)]))
	if first:
		_tracker.set_shown(true)


## A talk's "give:<item>:<n>": the player's own remove() takes them out of the bag, all or nothing; then "gave-<item>"
## is set and the same talk is asked again, so its start rules see it.
func _give(item: String, count: int) -> void:
	if item == "" or count < 1:
		return
	_busy = true
	var taken: Dictionary = await _parts.bag_remove(item, count)
	_busy = false
	if not bool(taken.ok):
		Sound.play("sfx-glitch", 0.3)
		_hotaru_says(String(taken.words))
		return
	state.bag = taken.bag
	_set_flag("gave-" + item)
	Sound.play("sfx-pass", 0.35)
	if not _last_talk.is_empty():
		_open_talk(_last_talk, _last_speaker)


## Hotaru's beats (Concept/v0.4/03, "Hooks for the conductor"): when its condition first holds, her talk once; the talk
## sets its own `told` flag. Each is [condition, talk id, told flag].
const BEATS: Array = [
	[{"flag": "pocket-menu-seen"}, "hotaru-pocket-menu", "pocket-menu-told"],
	[{"flag": "menu-opened"}, "hotaru-own-menu", "own-menu-told"],
	[{"flag": "lamps-lit"}, "hotaru-lamps-lit", "lamps-lit-told"],
	[{"flag": "makers-told"}, "hotaru-wink", "wink-told"],
	[{"flag": "volume-tried"}, "hotaru-first-volume", "volume-told"],
	[{"count": "picked-", "at_least": 1}, "hotaru-first-pick", "first-pick-told"],
	[{"flag": "music-played"}, "hotaru-first-song", "music-told"],
	[{"flag": "map-opened"}, "hotaru-map-opened", "map-told"],
	[{"flag": "clock-evening"}, "hotaru-evening", "evening-told"],
	# Chapter 3: once Orin has said the town is still, Hotaru asks for a glow of her own.
	# LEARN: rows with the same told flag are one beat, an "or" without an "any" in the conditions: whichever holds
	# first fires, and its talk sets the flag that skips the rest. So she still asks after Pip's or Brisk's first
	# success when the player went to them before Orin.
	[{"all": [{"flag": "credits-rolled"}, {"flag": "town-still-told"}]}, "hotaru-glow", "glow-asked"],
	[{"flag": "count-built"}, "hotaru-glow", "glow-asked"],
	[{"flag": "drills-double"}, "hotaru-glow", "glow-asked"],
]


## Starts the first beat that is due (the town is idle and nothing else is speaking). True when one started.
func _next_beat() -> bool:
	if _bubble.visible or _tasks.banner().busy():
		return false
	for beat: Array in BEATS:
		var told := String(beat[2])
		if _flag(told) or not catalog.talk.has(String(beat[1])):
			continue
		if Quests.holds(beat[0], state.flags):
			_hotaru_talk(String(beat[1]))
			return true
	return false


## The player's own options (state.options), {} for an old save.
func _options() -> Dictionary:
	return state.get("options", {}) if state.get("options") is Dictionary else {}


## The minimap under the tracker: shown once the map part is built, in the player's colours, with the people, the
## tracked step's pin and where the player stands.
func _show_minimap() -> void:
	var minimap := _tracker.minimap()
	var on := Parts.built(state, Parts.MAP)
	minimap.set_enabled(on)
	if not on:
		return
	minimap.show_map(_current(), _parts.map_colours())
	var people: Array[Vector2i] = []
	people.assign(_map.people_cells().keys())
	minimap.set_people(people)
	_pin_minimap()
	_tracker.locate(String(state.map), OverworldState.cell(state))
	_tracker.set_clock(_parts.clock_text_at(int(state.get("clock", OverworldState.START_MINUTE))))


## The minimap's star: the tracked step's pin when it is on this map.
func _pin_minimap() -> void:
	var minimap := _tracker.minimap()
	var step := Quests.current(catalog.quests, Parts.facts(state), String(state.get("tracked", "")))
	var pin: Dictionary = step.get("at", {}) if step.get("at") is Dictionary else {}
	if not pin.is_empty() and String(pin.get("map", "")) == String(state.map):
		minimap.set_pin(OverworldMap.cell_of(pin.get("at", [-1, -1])))
	else:
		minimap.set_pin(Vector2i(-1, -1))


## The name of a key as the player's shortcut() knows it ("escape", "i", "7"), when it is one it is asked about and
## the key opens something by their code; "" otherwise.
func _shortcut_of(event: InputEventKey) -> String:
	if not event.pressed or event.echo or not Parts.built(state, Parts.SHORTCUTS):
		return ""
	var name := ""
	if event.keycode >= KEY_A and event.keycode <= KEY_Z:
		name = char(event.keycode).to_lower()
	elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
		name = char(event.keycode)
	if name == "" or not name in Parts.SHORTCUT_KEYS:
		return ""
	return _parts.shortcut(name)


## Opens a panel by its name (a shortcut, a menu item, a talk, a thing): only once its part is built; else Hotaru says
## who can help. `from_menu`: the menu is covered and comes back when it closes.
func _open_panel(panel: String, from_menu := false) -> void:
	var needs := {"bag": Parts.BAG, "map": Parts.MAP, "music": Parts.MUSIC, "options": Parts.OPTIONS}
	if needs.has(panel) and not Parts.built(state, String(needs[panel])):
		var who := {"bag": "Nym", "map": "Pell", "music": "Marta", "options": "Seren"}
		_hotaru_says(Text.f("That isn't built yet. %s can help!", [String(who[panel])]))
		if from_menu:
			_menu.cover(false)
		return
	_held.clear()
	match panel:
		"menu":
			if Parts.built(state, Parts.MENU):
				_open_real_menu()
			else:
				_open_menu()
		"quests":
			# The log opens over the player's own menu (it covers it, and Esc goes back to it).
			if not _menu.is_open() and Parts.built(state, Parts.MENU):
				_open_real_menu()
			_on_menu_chosen(PauseMenu.QUESTS)
		"workbench":
			_workbench.set_history(_parts.changed_lines if Parts.built(state, Parts.HISTORY) else Callable())
			_workbench.open(catalog, state)
		"bag":
			_open_bag()
		"map":
			_open_full_map()
		"music":
			_open_music_panel()
		"options":
			_open_options()


## A panel opened from the menu closed: the menu comes back.
func _on_panel_closed() -> void:
	if _menu.is_open():
		_menu.cover(false)
	if _pocket.is_open():
		_pocket.cover(false)
	_held.clear()


## The HUD works from the beginning, before the player has built menu shortcuts.
func _open_quest_details(id: String) -> void:
	if not _idle() or not catalog.quests.has(id):
		return
	_held.clear()
	if _player.moving:
		_quest_wanted = id
		return
	_show_quest_log(id)


func _show_quest_log(focus_id := "") -> void:
	var current := Quests.current(catalog.quests, Parts.facts(state), String(state.get("tracked", "")))
	_log.open(
		Quests.entries(catalog.quests, Parts.facts(state)), catalog.townsfolk,
		focus_id if focus_id != "" else String(current.get("id", "")), String(state.get("tracked", "")),
		Parts.built(state, Parts.PROGRESS), _parts.progress_of
	)


func _on_track(id: String) -> void:
	state.tracked = id
	_tracker.set_tracked(id)
	_save()


func _on_pocket_chosen(action: String) -> void:
	match action:
		"quests":
			_pocket.cover(true)
			_show_quest_log()
		"boots":
			_pocket.close(false)
			_open_boots()
		"save":
			_pocket.show_status(Text.t("Saving..."), OverworldStyle.MUTED)
			_lessons.save_now(state)
		"fix":
			_pocket.close(false)
			_open_task(Parts.SHORTCUTS)
		"title":
			_leave_to(Game.TITLE)
		"quit":
			_busy = true
			_save()
			Game.quit()


func _on_pocket_closed() -> void:
	_held.clear()


func _open_options() -> void:
	var music := int(_options().get("music", roundi(Settings.music_volume * 10.0)))
	var sound := int(_options().get("sound", roundi(Settings.sound_volume * 10.0)))
	var track_id := String(_options().get("track", ""))
	var title := String((catalog.get("tracks", {}) as Dictionary).get(track_id, {}).get("title", "")) if track_id != "" else Text.t("Lanternroot's own")
	var values := {
		"music": clampi(music, 0, 10), "sound": clampi(sound, 0, 10),
		"text_speed": String(_options().get("text_speed", "normal")), "track": title, "fullscreen": Settings.fullscreen,
	}
	_options_page.open(_parts.options_rows(), values, _parts.volume_at, _parts.volume_curve())


## A row of the player's Options page changed: the volumes go through their volume(), and everything is kept.
func _on_option_changed(setting: String, value: Variant) -> void:
	var options := _options().duplicate()
	match setting:
		"music", "sound":
			var notch := int(value)
			var loud := _parts.volume_at(notch)
			if loud < 0.0:
				return
			options[setting] = notch
			if setting == "music":
				Settings.music_volume = loud
			else:
				Settings.sound_volume = loud
				Sound.play("sfx-chime", 0.6)
			Sound.set_volumes(Settings.music_volume, Settings.sound_volume)
			Settings.save_file()
			if not _flag("volume-tried"):
				state.options = options
				_set_flag("volume-tried")
		"text_speed":
			options.text_speed = String(value)
			DialogueBox.set_text_speed(String(value))
		"fullscreen":
			Settings.fullscreen = bool(value)
			Settings.apply_display()
			Settings.save_file()
	state.options = options
	_save()


## The title's whole settings panel, from the Options page's "More settings…".
func _open_more_settings() -> void:
	_options_page.close()
	PauseMenu.settings_in(_settings_page, _close_more_settings)


func _close_more_settings() -> void:
	PauseMenu.close_settings_in(_settings_page)
	_open_options()


## The music box: the player's titles() of the track list, played with Enter, the next by their next_track().
func _open_music_panel() -> void:
	if _options_page.is_open():
		_options_page.close()
	var ids: Array[String] = []
	for track: Dictionary in _parts.track_list():
		ids.append(String(track.id))
	var titles: Array[String] = await _parts.titles()
	_music_panel.open(titles, ids, _music_wanted, String(_options().get("track", "")), _parts.next_index)


func _on_music_play(id: String) -> void:
	Sound.music(id)
	if not _flag("music-played"):
		_set_flag("music-played")


func _on_town_track(id: String) -> void:
	var options := _options().duplicate()
	options.track = id
	state.options = options
	_save()


## The music box closed: the town plays what it should again (the chosen track, or the place's own).
func _on_music_closed() -> void:
	_music_wanted = ""
	_on_panel_closed()


## A part chosen on the Workbench: the lessons from before open their own editors; a task opens its editor.
func _on_workbench_part(id: String) -> void:
	_workbench.close_panel()
	if _menu.is_open():
		_menu.close(false)
	match id:
		"boots":
			_open_boots()
		"save":
			_lessons.open_lesson(Lessons.MEMORY, state)
		"lamps":
			_lessons.open_lesson(Lessons.LAMPS, state)
		_:
			_open_task(id)


## The whole map, drawn with the player's map_colour(), with the places named.
func _open_full_map() -> void:
	if not Parts.built(state, Parts.MAP):
		return
	var people: Array[Vector2i] = []
	people.assign(_map.people_cells().keys())
	var step := Quests.current(catalog.quests, Parts.facts(state), String(state.get("tracked", "")))
	var pin: Dictionary = step.get("at", {}) if step.get("at") is Dictionary else {}
	var pin_cell := Vector2i(-1, -1)
	if not pin.is_empty() and String(pin.get("map", "")) == String(state.map):
		pin_cell = OverworldMap.cell_of(pin.get("at", [-1, -1]))
	var places: Array = (catalog.get("places", {}) as Dictionary).get(String(state.map), [])
	_full_map.set_colour_names(_parts.map_colour_names())
	_full_map.open(_current(), _parts.map_colours(), places, OverworldState.cell(state), people, pin_cell)
	if not _flag("map-opened"):
		_set_flag("map-opened")


## The credits: the player's credits() lines over the town at night; the town's own when theirs cannot be used.
func _roll_credits() -> void:
	_held.clear()
	var maker := String(state.get("name", "")) if String(state.get("name", "")) != "" else Text.t("Tinker")
	var names := built_part_names()
	var lines: Array[String] = await _parts.credits_lines(maker, names)
	if lines.is_empty():
		lines.append(Text.t("Lanternroot"))
		lines.append(Text.f("Made by %s", [maker]))
		lines.append_array(names)
	_credits.roll(lines, maker)


func _on_credits_finished() -> void:
	if not _flag("credits-rolled"):
		_set_flag("credits-rolled")
	_music_wanted = ""


## The names of every part the player built, the lessons first, then the parts in the order they were built: what
## credits() is given.
func built_part_names() -> Array[String]:
	var out: Array[String] = []
	var lessons := {"boots": Text.t("Boots"), "save": Text.t("Save"), "lamps": Text.t("Lamps")}
	for id: String in Parts.BUILT_BEFORE:
		if _flag(String(Parts.BUILT_BEFORE[id])):
			out.append(String(lessons[id]))
	var parts: Array[String] = []
	for id in Parts.IDS:
		if Parts.built(state, id):
			parts.append(id)
	# The parts in the order they were built (a record keeps when, in seconds played); the Workbench's order breaks ties.
	parts.sort_custom(
		func(a: String, b: String) -> bool:
			var when_a := float(Parts.record(state, a).get("built_at", 0.0))
			var when_b := float(Parts.record(state, b).get("built_at", 0.0))
			return when_a < when_b if when_a != when_b else Parts.IDS.find(a) < Parts.IDS.find(b)
	)
	for id in parts:
		out.append(Text.t(String((catalog.get("tasks", {}) as Dictionary).get(id, {}).get("name", id))))
	return out


# --- chapter 3 (Concept/v0.4/05) -------------------------------------------------------------------------------------


## A talk's reward ("receive:<item>[:n]"): the item goes into the bag with the player's own add(), as a pickup does.
func _receive(item: String, count: int) -> void:
	if item == "" or count < 1:
		return
	var item_name := Text.t(String((catalog.get("items", {}) as Dictionary).get(item, {}).get("name", item)))
	if not Parts.built(state, Parts.BAG):
		_hotaru_says(Text.f("A gift: %s! But we have no bag to put it in yet.", [item_name]))
		return
	for i in count:
		var added: Dictionary = await _parts.bag_add(item)
		if not bool(added.ok):
			_hotaru_says(String(added.words))
			return
		state.bag = added.bag
	_save()
	Sound.play("sfx-chime", 0.4, 1.2)
	_hotaru_says(Text.f("%s, into the bag! (%d now)", [item_name, Bag.count(state.bag, item)]))


## The town's lanterns for Pip's count: every lamp and lantern on this map, lit once the lane is lit (the lane's own,
## and the rest from the start), each named by where it stands.
func _lanterns() -> Array:
	var out: Array = []
	for object: Dictionary in _current().get("objects", []):
		var art := String(object.get("art", ""))
		if not (art.contains("lamp") or art.contains("lantern")):
			continue
		var at := OverworldMap.cell_of(object.get("at", [0, 0]))
		var lit := _flag("lamps-lit") if String(object.get("group", "")) == "lane" else true
		out.append({"name": "%s at %d,%d" % [art, at.x, at.y], "lit": lit})
	return out


## Pip's tally board: the player's count() of the lanterns lit, said on the board.
func _read_tally() -> void:
	var lanterns := _lanterns()
	_busy = true
	var lit: int = await _parts.count_lit(lanterns)
	_busy = false
	var said := Text.f("Pip's board says: %d lanterns lit.", [lit]) if lit >= 0 else Text.t("Pip's board is blank. Its count needs fixing.")
	_talk.say([{"text": said, "speaker": "", "mood": ""}], {"name": ""}, Parts.facts(state))
	if lit >= 0 and not _flag("tally-read"):
		_set_flag("tally-read")


## Brisk's drill board: which of the three drills the player's tests caught.
func _read_drill_board() -> void:
	var lines: Array[Dictionary] = []
	var drills := {"drills-double": Text.t("Drill 1, double:"), "drills-total": Text.t("Drill 2, total:"), "drills-first": Text.t("Drill 3, first:")}
	for flag: String in drills:
		var caught := Text.t("caught!") if _flag(flag) else Text.t("not yet")
		lines.append({"text": "%s %s" % [String(drills[flag]), caught], "speaker": "", "mood": ""})
	_talk.say(lines, {"name": ""}, Parts.facts(state))


## The day's weather changed (a new day, or the weather part built): the town shows it, and Fern's quest notes rain.
func _weather_changed() -> void:
	_on_part_changed(Parts.WEATHER)


## The weather over the town, by the player's weather() for today. Indoors, and before the clock (no days yet), it is
## always fair. The first rain the player's code makes is noted (rain-seen).
func _apply_weather() -> void:
	if _rain == null:
		return
	var kind := ""
	if String(state.get("map", "")) == TOWN_MAP and Parts.built(state, Parts.CLOCK):
		kind = _parts.weather_on(int(state.get("day", 0)))
	_rain.set_weather(kind if kind in ["rain", "cloud"] else "")
	if kind == "rain" and not _flag("rain-seen"):
		_set_flag("rain-seen")


## Fern's "let's wait for the rain": the town sleeps to the morning of the next day the player's weather() says rains
## (within a week, as the weather task asks). Today counts when it already rains.
func _sleep_to_rain() -> void:
	var today := int(state.get("day", 0))
	for ahead in Parts.WEATHER_DAYS:
		if _parts.weather_on(today + ahead) != "rain":
			continue
		if ahead > 0:
			state.day = today + ahead
			state.clock = RAIN_MORNING
			_tracker.set_clock(_parts.clock_text_at(RAIN_MORNING))
			_hotaru_says(Text.f("Zzz... Day %d. Listen: rain!", [int(state.day) + 1]))
		_apply_weather()
		_update_tint(0.0, true)
		_save()
		return
	_hotaru_says(Text.t("Your weather() never says rain, so the grove waits."))


## Hotaru shines to the player's glow(), one value a second (the played seconds, looping a minute), eased so a blink
## is soft. Before the part is built (or when its table cannot answer) she breathes as she always did.
func _update_glow(delta: float) -> void:
	var want := _parts.glow_at(int(float(state.get("played_seconds", 0.0))))
	if want < 0.0:
		if _glow_now >= 0.0:
			_glow_now = -1.0
			_hotaru.set_brightness(-1.0)
		return
	_glow_now = want if _glow_now < 0.0 else lerpf(_glow_now, want, clampf(delta * GLOW_EASE, 0.0, 1.0))
	_hotaru.set_brightness(_glow_now)


## The bag, with the coins (once Nym's shop is being built, or there are coins) and Mira's total and tidy.
func _open_bag() -> void:
	var bag: Array = Bag.cleaned(state.get("bag", []))
	var coins := int(state.get("coins", 0))
	_bag_panel.set_coins(coins if coins > 0 or Parts.built(state, Parts.SHOP) else -1)
	_bag_panel.set_tidy_enabled(Parts.passed(state, Parts.TIDY) >= 2)
	_bag_panel.set_total(-1)
	_bag_panel.open(bag, catalog.get("items", {}))
	if Parts.built(state, Parts.TIDY):
		var total: int = await _parts.total_of(bag)
		if _bag_panel.is_open():
			_bag_panel.set_total(total)


## T in the bag: the player's tidy() sorts it, judged before the bag is replaced.
func _on_bag_tidy() -> void:
	var tidied: Dictionary = await _parts.tidy_bag(Bag.cleaned(state.get("bag", [])))
	if not bool(tidied.ok):
		_hotaru_says(String(tidied.words))
		return
	state.bag = tidied.bag
	_save()
	Sound.play("sfx-chime", 0.3, 1.3)
	if _bag_panel.is_open():
		_open_bag()
	if not _flag("bag-tidied"):
		_set_flag("bag-tidied")


## Nym's shop: sell from the bag at the player's prices, buy what Nym sells if the player's can_buy() says so.
func _open_shop() -> void:
	var shop: Dictionary = catalog.get("shop", {})
	_held.clear()
	_shop_panel.open(
		Bag.cleaned(state.get("bag", [])), catalog.get("items", {}), int(state.get("coins", 0)), shop.get("buys", {}),
		shop.get("sells", {}), _shop_price
	)


func _shop_price(item: String, count: int) -> int:
	return await _parts.price_of((catalog.get("shop", {}) as Dictionary).get("buys", {}), item, count)


func _item_name(item: String) -> String:
	return Text.t(String((catalog.get("items", {}) as Dictionary).get(item, {}).get("name", item)))


## Selling: the player's price() says the coins, then their remove() takes the items out, once for each.
func _on_shop_sell(item: String, count: int) -> void:
	var coins: int = await _shop_price(item, count)
	if coins < 0:
		_shop_panel.show_status(Text.t("Your price() can't price that yet."), false)
		return
	var removed: Dictionary = await _parts.bag_remove(item, count)
	if not bool(removed.ok):
		_shop_panel.show_status(String(removed.words), false)
		return
	state.bag = removed.bag
	state.coins = int(state.get("coins", 0)) + coins
	_save()
	Sound.play("sfx-chime", 0.4, 1.4)
	_shop_panel.set_state(state.bag, int(state.coins))
	_shop_panel.show_status(Text.f("Sold %d × %s for %d coins.", [count, _item_name(item), coins]), true)
	if not _flag("shop-sold"):
		_set_flag("shop-sold")


## Buying: the player's can_buy() decides, Nym counts the coins again (they never go below 0), and add() packs it.
func _on_shop_buy(item: String) -> void:
	var cost := int(((catalog.get("shop", {}) as Dictionary).get("sells", {}) as Dictionary).get(item, 0))
	var coins := int(state.get("coins", 0))
	var yes: Variant = await _parts.can_buy(coins, cost)
	if yes == null:
		_shop_panel.show_status(Text.t("Your can_buy() isn't ready yet. Nym can help."), false)
		return
	if not bool(yes):
		_shop_panel.show_status(Text.f("Your can_buy() says no: %d coins, and it costs %d.", [coins, cost]), false)
		return
	if coins < cost:
		_shop_panel.show_status(Text.f("Your can_buy() said yes, but Nym counts %d coins, and it costs %d.", [coins, cost]), false)
		return
	var added: Dictionary = await _parts.bag_add(item)
	if not bool(added.ok):
		_shop_panel.show_status(String(added.words), false)
		return
	state.bag = added.bag
	state.coins = coins - cost
	_save()
	Sound.play("sfx-chime", 0.4, 1.2)
	_shop_panel.set_state(state.bag, int(state.coins))
	_shop_panel.show_status(Text.f("Bought %s for %d coins.", [_item_name(item), cost]), true)
	if not _flag("shop-bought"):
		_set_flag("shop-bought")


## The townsfolk who keep hours go where the player's where() says for this hour (Concept/v0.4/05, 2.8). A spot the
## player stands on waits an hour. The first move by the player's code is noted (hours-seen).
func _move_people() -> void:
	if not Parts.built(state, Parts.HOURS) or String(state.map) != TOWN_MAP:
		return
	var hour := floori(int(state.get("clock", OverworldState.START_MINUTE)) / 60.0)
	var schedules: Dictionary = catalog.get("schedules", {})
	var moved := false
	for person: String in schedules:
		if not _map.people.has(person):
			continue
		var spot := _parts.where_at(person, hour)
		if spot == "" or not (schedules[person] as Dictionary).has(spot):
			continue
		var cell := OverworldMap.cell_of(schedules[person][spot])
		var walker := _map.people[person] as Walker
		if walker.cell == cell or cell == _player.cell:
			continue
		walker.place(cell, "down")
		moved = true
	if moved and not _flag("hours-seen"):
		_set_flag("hours-seen")


## A panel a talk or a thing opens: "task:<id>", "workbench", "bag", "map", "music", "credits".
func _open_part_panel(what: String) -> void:
	if what.begins_with("task:"):
		_open_task(what.substr("task:".length()))
	elif what == "credits":
		_roll_credits()
	elif what == "clock":
		# The home's wall clock reads the time with the player's clock_text() (clock stage 2), else their phase.
		var minute := int(state.get("clock", OverworldState.START_MINUTE))
		var told := _parts.clock_text_at(minute)
		var said := Text.f("Tick, tock. It's %s.", [told]) if told != "" else Text.f("Tick, tock. It's %s.", [phase_word(_parts.phase_at(minute))])
		_talk.say([{"text": said, "speaker": "", "mood": ""}], {"name": ""}, Parts.facts(state))
	elif what.begins_with("receive:"):
		var bits := what.split(":")
		_receive(bits[1] if bits.size() > 1 else "", int(bits[2]) if bits.size() > 2 else 1)
	elif what == "tally":
		_read_tally()
	elif what == "lockbox":
		var lockbox := Text.t("A lockbox with a four-digit lock. Nix knows its secret.")
		if _flag("lockbox-opened"):
			lockbox = Text.t("The lockbox is open. Its key is yours now.")
		elif _flag("locks-strong"):
			lockbox = Text.t("Your lock holds. Nix has the code to open it.")
		_talk.say([{"text": lockbox, "speaker": "", "mood": ""}], {"name": ""}, Parts.facts(state))
	elif what == "drills":
		_read_drill_board()
	elif what == "shop":
		_open_shop()
	elif what == "next-rain":
		_sleep_to_rain()
	elif what in Parts.PANELS:
		_open_panel(what)


## A prop with "opens": its panel when that part is built, else its own text. True when it did something.
func _open_from_thing(thing: Dictionary) -> bool:
	var what := String(thing.get("opens", ""))
	var part := {"music": Parts.MUSIC, "map": Parts.MAP, "bag": Parts.BAG, "clock": Parts.CLOCK, "tally": Parts.COUNT}.get(what, "") as String
	if part != "" and not Parts.built(state, part):
		return false
	_open_part_panel(what)
	return true


func _open_task(id: String) -> void:
	_held.clear()
	Sound.play("sfx-open", 0.35)
	_tasks.open_task(id, state)


## A task changed its record or set a stage's flag: the town keeps both (its own place and time are its own).
func _on_task_state(changed: Dictionary) -> void:
	state.tasks = (changed.get("tasks", {}) as Dictionary).duplicate(true)
	state = OverworldState.remembered(state, changed.get("flags", {}))
	_save()
	_parts.refresh(_tasks.open_id())


## A part was built or improved (its editor closed after a stage passed): its tables are remade, and Hotaru says what
## to try.
func _on_part_built(id: String, stage: int) -> void:
	_parts.refresh(id)
	# The clock starts in the late afternoon the first time it is built, so the first evening comes in about a minute
	# (Lumen's next step is to see it).
	if id == Parts.CLOCK and stage == 0 and not _flag("clock-evening"):
		state.clock = CLOCK_FIRST_MINUTE
		_save()
	if stage > 0:
		return
	var said := {
		Parts.SHORTCUTS: Text.t("Your keys listen to you now! Mira has one more piece for the menu."),
		Parts.MENU: Text.t("Your very own menu! Press Esc and see it."),
		Parts.OPTIONS: Text.t("An Options page, all yours. It's in your menu."),
		Parts.BAG: Text.t("A bag! Let's find something to put in it. Apple trees?"),
		Parts.MAP: Text.t("Look up there! Pell's little map, in your colours."),
		Parts.PROGRESS: Text.t("Pip's bar fills up now! Open Quests and choose Expand journal to see your history."),
		Parts.CLOCK: Text.t("The town has a clock now. Wait and see what evening looks like!"),
	}
	if said.has(id):
		var wait := create_tween()
		wait.tween_interval(3.8)
		wait.tween_callback(_hotaru_says.bind(String(said[id])))


# --- the menu -----------------------------------------------------------------------------------------------------


## The menu over the town (Esc, or a pad's Start). Mid-step it waits for the step to land. It is the player's own menu
## once they built it (v0.4) and their shortcut() opens it on Esc (a pad's Start always opens it); until then it is
## Hotaru's pocket menu, which always has Settings and the ways out.
func _open_menu(pad := false) -> void:
	if _player.moving:
		_menu_wanted = true
		return
	_held.clear()
	var own := Parts.built(state, Parts.MENU) and (pad or _parts.escape_opens_menu())
	if not own:
		var broken := Parts.built(state, Parts.MENU) and Parts.built(state, Parts.SHORTCUTS)
		_pocket.open({"can_save": LessonHost.can_save(state), "note": "shortcut-broken" if broken else ""})
		if not _flag("pocket-menu-seen"):
			_set_flag("pocket-menu-seen")
		return
	_open_real_menu()


## The player's own menu: its items in the order their menu_items() gives, flying in the first time.
func _open_real_menu() -> void:
	var minute := int(state.get("clock", OverworldState.START_MINUTE))
	var clock := _parts.clock_text_at(minute)
	var phase := _parts.phase_at(minute)
	var extra := {
		"items": _parts.menu_items(),
		"first_time": not _flag("menu-opened"),
		"place": _parts.place_at(String(state.map), OverworldState.cell(state)),
		"clock": ("%s · %s" % [clock, phase_word(phase)]) if clock != "" and phase != "" else clock,
		"quest": Quests.current(catalog.quests, Parts.facts(state), String(state.get("tracked", ""))),
	}
	_menu.open(PauseMenu.about(state, catalog, extra))
	if not _flag("menu-opened"):
		_set_flag("menu-opened")


func _on_menu_closed() -> void:
	_held.clear()


func _on_menu_chosen(action: String) -> void:
	match action:
		"workbench", "bag", "map", "music", "options":
			_menu.cover(true)
			_open_panel(action, true)
		"credits":
			_menu.close(false)
			_roll_credits()
		PauseMenu.QUESTS:
			_menu.cover(true)
			_show_quest_log()
		PauseMenu.BOOTS:
			_menu.close(false)
			_open_boots()
		PauseMenu.SAVE:
			_menu.show_status(Text.t("Saving..."), OverworldStyle.MUTED)
			_lessons.save_now(state)
		PauseMenu.CHARACTERS:
			_leave_to(Game.CHARACTERS if ResourceLoader.exists(Game.CHARACTERS) else Game.TITLE)
		PauseMenu.TITLE:
			_leave_to(Game.TITLE)
		PauseMenu.QUIT:
			_busy = true
			_save()
			Game.quit()


## Leaves the town for another screen, its place kept.
func _leave_to(scene: String) -> void:
	_busy = true
	_held.clear()
	_save()
	Game.go(scene)


## For the screenshot tool (ROOTWARD_LANTERNTOWN_CALL): the menu with its quest log open.
func _shot_quests() -> void:
	_open_menu()
	_on_menu_chosen(PauseMenu.QUESTS)


## For the screenshot tool (ROOTWARD_LANTERNTOWN_CALL): each of v0.4's panels as the player opens it.
func _shot_bag() -> void:
	_open_panel("bag")


func _shot_options() -> void:
	_open_panel("options")


func _shot_music() -> void:
	_open_panel("music")


func _shot_workbench() -> void:
	_open_panel("workbench")


func _shot_fullmap() -> void:
	_open_panel("map")


func _shot_task_menu() -> void:
	_open_task(Parts.MENU)


func _shot_task_bag() -> void:
	_open_task(Parts.BAG)


func _shot_credits() -> void:
	_roll_credits()


## For the screenshot tool: the first apple of this map picked, as Space at its tree would.
func _shot_pick() -> void:
	for pickup: Dictionary in (catalog.get("pickups", {}) as Dictionary).get(String(state.map), []):
		if String(pickup.item) == "apple":
			_pick(pickup)
			return


## For the screenshot tool: the step under way is done (when a flag finishes it), as the town would mark it.
func _shot_step_done() -> void:
	var quest := Quests.current(catalog.quests, state.flags)
	if quest.is_empty():
		return
	var steps: Array = (catalog.quests[String(quest.id)] as Dictionary).get("steps", [])
	var flag := String(((steps[int(quest.step)] as Dictionary).get("done", {}) as Dictionary).get("flag", ""))
	if flag != "":
		_set_flag(flag)


func _exit_tree() -> void:
	# Straight to the store: the tracker is already out of the tree, so it is not told.
	if not state.is_empty() and _store != null:
		_store.save_state(state)
