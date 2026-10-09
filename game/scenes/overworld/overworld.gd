class_name OverworldScreen
extends Control
## Lanternroot's overworld (ADR-0061): a small top-down town you walk on your own code. The arrow keys (or WASD, or a
## pad) are passed to the player's `on_key` through the table BootsRun made from it; Space talks to whoever you face;
## B opens your boots. Hotaru, a firefly, floats beside you and says what your boots are doing.
## Rules live in game/core/overworld/; this screen draws the town and sends it keys.

const START_MAP := "home"
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
var _bubble: PanelContainer
var _bubble_text: Label
var _prompt: Label
var _fade: ColorRect
var _held: Array[String] = []
var _busy := false
var _told := {}
var _table_source := ""


func _ready() -> void:
	Game.boot()
	theme = FoundryUi.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog = catalog_of()
	_store = OverworldStore.for_profile()
	_build()
	Sound.music("music-rest")
	var saved := _store.load_state()
	var language := (
		Settings.language if Settings.language in [BootsCode.PYTHON, BootsCode.JAVASCRIPT] else BootsCode.PYTHON
	)
	var home: Dictionary = catalog.maps.get(START_MAP, {})
	var fresh := OverworldState.fresh(START_MAP, home.get("start", Vector2i.ZERO), "down", language)
	state = OverworldState.normalized(saved, fresh) if not saved.is_empty() else fresh
	if not catalog.maps.has(String(state.map)):
		state = fresh
	_enter_map(String(state.map), OverworldState.cell(state), String(state.facing))
	if (state.look as Dictionary).is_empty():
		_creator.open(catalog.looks)
	else:
		_player.set_sheet(OverworldArt.sheet(state.look))
		_after_creator()


static func catalog_of() -> Dictionary:
	if _catalog_cache.is_empty():
		var loaded := OverworldContent.load_world()
		for diagnostic: Dictionary in loaded.diagnostics:
			push_error(ContentLoader.describe(diagnostic))
		_catalog_cache = loaded.catalog
	return _catalog_cache


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
	_player = Walker.new()
	_player.set_meta("player", true)
	_player.arrived.connect(_on_arrived)
	_map.things.add_child(_player)
	_hotaru = HotaruSprite.new()
	_hotaru.target = _player
	_map.things.add_child(_hotaru)

	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override(
		"panel", UiTheme.box(Color(0.1, 0.075, 0.06, 0.92), Color("#9ed84e"), 2, 12, Vector2(18, 12))
	)
	_bubble.position = Vector2(40, 36)
	_bubble.custom_minimum_size = Vector2(0, 0)
	_bubble.visible = false
	var face := TextureRect.new()
	face.texture = OverworldArt.portrait("hotaru")
	face.custom_minimum_size = Vector2(72, 72)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bubble_text = Ui.label("", "", true)
	_bubble_text.custom_minimum_size = Vector2(620, 0)
	_bubble_text.add_theme_font_size_override("font_size", 24)
	_bubble_text.add_theme_color_override("font_color", Color("#f3e6c8"))
	_bubble.add_child(Ui.hbox([face, _bubble_text], 14))
	add_child(_bubble)

	_prompt = Ui.label("", "Muted")
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-200, -70)
	_prompt.custom_minimum_size = Vector2(400, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_prompt)
	var keys := Ui.label(Text.t("Arrows: walk   Space: talk   B: boots   Esc: leave"), "Faint")
	keys.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	keys.position = Vector2(-560, -36)
	add_child(keys)

	_talk = DialogueBox.new()
	_talk.ended.connect(_on_talk_ended)
	add_child(_talk)
	_boots = BootsEditor.new()
	_boots.tried.connect(_on_boots_tried)
	_boots.closed.connect(_on_boots_closed)
	add_child(_boots)
	_creator = CharacterCreator.new()
	_creator.done.connect(_on_creator_done)
	add_child(_creator)
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
	var map := _current()
	_map.show_map(map)
	_player.place(cell, String(state.facing))
	_hotaru.facing = _player.facing
	_hotaru.settle()
	_aim_camera(true)
	_refresh_table()


func _aim_camera(snap := false) -> void:
	var map := _current()
	var world := Vector2(OverworldMap.size_of(map) * TownMapView.TILE)
	var view := Vector2(_view.viewport.size)
	var want := _player.position + Vector2(0, -8)
	for axis in 2:
		if world[axis] <= view[axis]:
			want[axis] = world[axis] / 2.0
		else:
			want[axis] = clampf(want[axis], view[axis] / 2.0, world[axis] - view[axis] / 2.0)
	_camera.position = want.round()
	if snap:
		_camera.reset_smoothing()


func _process(_delta: float) -> void:
	_aim_camera()
	_update_prompt()
	if _busy or _talk.busy or _boots.visible or _creator.visible or _player.moving:
		return
	if not _held.is_empty():
		_step(_held[-1])


# --- input --------------------------------------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
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
	if _boots.visible or _creator.visible or _busy:
		return
	if _is_accept(event):
		_interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).keycode in [KEY_B, KEY_TAB]:
		_open_boots()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_Y:
		_open_boots()
	elif event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()


func _is_accept(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_E]
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	return false


# --- walking on the player's own code -----------------------------------------------------------------------------


func _step(key: String) -> void:
	var map := _current()
	var people := _map.people_cells()
	var blocked := func(cell: Vector2i) -> bool: return OverworldMap.blocked(map, cell, people)
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
			Sound.play("sfx-whiff", 0.25, 0.8)
		"still":
			_held.erase(key)
			_tell("still-" + key, Text.f("Your boots don't know the %s key yet. Press B to teach them.", [Text.t(key)]))
		"empty":
			_held.clear()
			_tell("empty", Text.t("Your boots are empty! Press B to open them."), true)
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
	var warp := OverworldMap.warp_at(_current(), cell)
	if not warp.is_empty():
		_go_through(warp)
		return
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


## The boots table for this map. Made again only when the code or the map's size changes; made on a thread, so the
## town keeps drawing while the sandbox runs.
func _refresh_table() -> void:
	var source := OverworldState.boots_source(state)
	var size := OverworldMap.size_of(_current())
	var key := "%s|%s|%s" % [state.language, size, source]
	if key == _table_source:
		return
	_table_source = key
	var language := String(state.language)
	table = await Background.run(func() -> Dictionary: return BootsRun.run(language, source, size))


# --- boots --------------------------------------------------------------------------------------------------------


func _open_boots(hint := "") -> void:
	_held.clear()
	Sound.play("sfx-open", 0.35)
	_boots.open(state, hint if hint != "" else _boots_hint())


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
	state = tried
	_save()
	await _refresh_table()
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
		_beat_after_boots(taught)
	else:
		_boots.report(Text.t(String(table.message)), false)
		Sound.play("sfx-glitch", 0.3)


func _on_boots_closed() -> void:
	_held.clear()


# --- talking --------------------------------------------------------------------------------------------------------


func _interact() -> void:
	var ahead := OverworldMap.ahead(_player.cell, _player.facing)
	var who := _map.person_at(ahead)
	if who != "":
		var person: Dictionary = catalog.townsfolk.get(who, {})
		(_map.people[who] as Walker).face(_opposite(_player.facing))
		_talk.open(catalog.talk.get(String(person.talk), {}), _speaker(person), state.flags)
		return
	var thing := OverworldMap.thing_at(_current(), ahead)
	if thing.has("text"):
		_talk.say([{"text": String(thing.text), "speaker": "", "mood": ""}], {"name": ""}, state.flags)


func _speaker(person: Dictionary) -> Dictionary:
	return {"name": person.get("name", ""), "portrait": person.get("portrait", ""), "voice": person.get("voice", 1.0)}


func _opposite(facing: String) -> String:
	return {"up": "down", "down": "up", "left": "right", "right": "left"}.get(facing, "down")


func _on_talk_ended(flags: Dictionary, opens: Array[String]) -> void:
	state = OverworldState.flagged(state, flags)
	_save()
	if "boots" in opens:
		_open_boots()


func _update_prompt() -> void:
	if _talk.busy or _boots.visible or _creator.visible:
		_prompt.text = ""
		return
	var ahead := OverworldMap.ahead(_player.cell, _player.facing)
	var who := _map.person_at(ahead)
	if who != "":
		_prompt.text = Text.f("Space: talk to %s", [Text.t(String(catalog.townsfolk.get(who, {}).get("name", "")))])
	elif OverworldMap.thing_at(_current(), ahead).has("text"):
		_prompt.text = Text.t("Space: read")
	else:
		_prompt.text = ""


# --- Hotaru's remarks ---------------------------------------------------------------------------------------------


## A remark Hotaru makes once (until the map changes): `id` keeps her from repeating herself.
func _tell(id: String, text: String, always := false) -> void:
	if _told.has(id) and not always:
		return
	_told[id] = true
	_hotaru_says(text)


func _hotaru_says(text: String) -> void:
	_bubble_text.text = text
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.15)
	tween.tween_interval(clampf(text.length() * 0.06, 3.0, 7.0))
	tween.tween_property(_bubble, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: _bubble.visible = false)


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
		_talk.open(talk, {}, state.flags)


func _after_creator() -> void:
	if not _flag("woke"):
		_hotaru_talk("hotaru-wake")


func _beat_after_step() -> void:
	if not _flag("first-step"):
		_set_flag("first-step")
		_hotaru_talk("hotaru-first-step")


func _beat_after_boots(taught: Array[String]) -> void:
	if taught.size() == BootsRules.KEYS.size() and not _flag("all-ways"):
		_set_flag("all-ways")
		_boots.visible = false
		_hotaru_talk("hotaru-all-ways")


func _beat_on_enter(from: String) -> void:
	if String(state.map) == "lanternroot" and not _flag("left-home"):
		_set_flag("left-home")
		_hotaru_talk("hotaru-town")
	elif from != String(state.map):
		_told.clear()


func _on_creator_done(look: Dictionary, chosen_name: String) -> void:
	state.look = look
	state.name = chosen_name
	_player.set_sheet(OverworldArt.sheet(look))
	_save()
	_after_creator()


func _save() -> void:
	_store.save_state(state)


func _leave() -> void:
	_save()
	Game.go(Game.TITLE)


func _exit_tree() -> void:
	if not state.is_empty() and _store != null:
		_save()
