class_name LessonHost
extends Control
## Lanternroot's lessons after the boots (ADR-0061): lesson 2 writes the player's own save, lesson 3 lights the lane.
## The overworld opens a lesson when a talk asks for it (a node with open "lesson:<id>"), and hears back through
## state_changed. The host keeps the lesson's record in the state (state.lessons.<id>: the blocks, the code typed, the
## program that passed), sets the lesson's flags, and speaks for Hotaru when a lesson ends:
##
##   memory: passing sets memory-written. From then on the menu's Save runs the player's own save on where they stand
##           (save_now, state.memory, saved-once), and Continue puts them where it says (restore).
##   lamps:  passing sets lamps-written; closing the editor lights the lane's lamps one at a time, then sets lamps-lit
##           (the overworld draws the lane dark until then).

## The lesson changed the town (a flag, the player's saved memory, the lamps): the overworld saves it and redraws.
signal state_changed(state: Dictionary)
## The menu's Save finished: the state to keep, and what Hotaru says about it. When the save could not run, the state
## comes back unchanged and `last_save_ok` is false.
signal saved(state: Dictionary, message: String)

## Hotaru's kind word about where Continue woke the player, when their save could not be used (Lessons.restore's note).
## Set by restore, said by the host once the town is on screen.
static var pending_note := ""
## Set when the overworld leaves for the letters screen: coming back from there is not a Continue, and keeps the place.
static var _back_from_letters := false

## Whether the last save_now worked.
var last_save_ok := false

var _state: Dictionary = {}
var _editor: LessonEditor
var _voice: DialogueBox
var _lighting := false
var _saving := false
## The lesson passed during this opening of the editor (Hotaru says what comes next when it closes).
var _passed_now := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_editor = LessonEditor.new()
	_editor.passed.connect(_on_passed)
	_editor.closed.connect(_on_closed)
	add_child(_editor)
	_voice = DialogueBox.new()
	add_child(_voice)
	_tell_pending_note.call_deferred()


func _exit_tree() -> void:
	# LEARN: the overworld is rebuilt when the letters screen comes back to it, and its _ready runs restore again. That
	# trip is not a Continue, so the host notes it on the way out (the overworld has just set returns_to) and restore
	# leaves the place alone once.
	if LanternrootScreen.returns_to == Game.OVERWORLD:
		_back_from_letters = true


## Opens lesson `id` ("memory", "lamps") over the town.
func open_lesson(id: String, state: Dictionary) -> void:
	if not id in Lessons.IDS:
		push_warning("there is no lesson %s" % id)
		return
	_state = state.duplicate(true)
	_passed_now = false
	_editor.open(id, _state)


## True while a lesson's editor is open, Hotaru is speaking for it, or the lane is lighting: the town does not walk.
func busy() -> bool:
	return _editor.is_open() or _voice.busy or _lighting


## Whether the lesson's editor is open: the coding music plays then.
func editing() -> bool:
	return _editor.is_open()


## Whether the menu's Save works yet: only once the player has written their own save (lesson 2).
static func can_save(state: Dictionary) -> bool:
	return bool((state.get("flags", {}) as Dictionary).get("memory-written", false))


## Saves with the player's own save program, run in the sandbox (on a thread) on where they stand now. What it gives
## back becomes state.memory, and saved-once is set. Emits saved when done.
func save_now(state: Dictionary) -> void:
	var kept := Lessons.record(state, Lessons.MEMORY)
	var source := String(kept.get("source", ""))
	if not can_save(state) or source.strip_edges() == "":
		last_save_ok = false
		saved.emit(state, Text.t("Your save isn't written yet. Vell at the Archive can help."))
		return
	if _saving:
		return
	_saving = true
	var language := String(kept.get("language", state.get("language", Lessons.PYTHON)))
	var player := Lessons.player_of(state)
	var ran: Dictionary = await Background.run(func() -> Dictionary: return LessonRun.save(language, source, player))
	_saving = false
	last_save_ok = bool(ran.ok)
	if not last_save_ok:
		saved.emit(state, Text.f("Your save tripped: %s", [String(ran.message)]))
		return
	var out := state.duplicate(true)
	out.memory = ran.kept
	saved.emit(Lessons.with_flags(out, ["saved-once"]), LessonWords.saved(ran.kept))


## The state as Continue starts it. Before lesson 2 the town keeps the player's place for them; after it, the place is
## what the player's own save kept (state.memory), or home when it cannot be used, with a note Hotaru says.
static func restore(state: Dictionary) -> Dictionary:
	pending_note = ""
	if _back_from_letters:
		_back_from_letters = false
		return state
	var maps: Dictionary = OverworldScreen.catalog_of().get("maps", {})
	var restored := Lessons.restore(state, maps, OverworldScreen.START_MAP)
	pending_note = String(restored.note)
	return restored.state


# --- a lesson ends ----------------------------------------------------------------------------------------------------


func _on_passed(kept: Dictionary) -> void:
	_passed_now = true
	_state = Lessons.with_record(_state, _editor.lesson, kept)
	var flag := "lamps-written" if _editor.lesson == Lessons.LAMPS else "memory-written"
	_state = Lessons.with_flags(_state, [flag])
	state_changed.emit(_state)


func _on_closed(kept: Dictionary) -> void:
	var id := _editor.lesson
	_state = Lessons.with_record(_state, id, kept)
	state_changed.emit(_state)
	var flags: Dictionary = _state.get("flags", {})
	if id == Lessons.LAMPS and bool(kept.get("passed", false)) and not bool(flags.get("lamps-lit", false)):
		_light_the_lane()
	elif id == Lessons.MEMORY and _passed_now and not bool(flags.get("saved-once", false)):
		_hotaru(
			[
				Text.t("Your save is written! But it only keeps things when you use it."),
				Text.t("Press Esc for the menu, then choose Save. Then the town will remember us."),
			]
		)


## The lane's lamps light one after another in the town on screen, each with a chime a little higher than the last;
## then lamps-lit is set, and the overworld draws the whole lane lit.
func _light_the_lane() -> void:
	_lighting = true
	var lamps: Array[Sprite2D] = []
	var view := _town_view()
	if view != null:
		lamps = lane_sprites(view, OverworldState.cell(_state))
	var sequence := create_tween()
	sequence.tween_interval(0.4)
	for i in lamps.size():
		sequence.tween_callback(_light.bind(lamps[i], i))
		sequence.tween_interval(0.32)
	sequence.tween_interval(0.3)
	sequence.tween_callback(_lane_lit)


func _light(lamp: Sprite2D, index: int) -> void:
	if not is_instance_valid(lamp):
		return
	var width := lamp.region_rect.size.x
	lamp.region_rect.position.x = lamp.texture.get_width() - width
	lamp.modulate = Color(1.9, 1.7, 1.3)
	lamp.create_tween().tween_property(lamp, "modulate", Color.WHITE, 0.45)
	Sound.play("sfx-chime", 0.3, 0.9 + 0.07 * index)


func _lane_lit() -> void:
	_state = Lessons.with_flags(_state, ["lamps-lit"])
	state_changed.emit(_state)
	_lighting = false
	Sound.play("sfx-pass", 0.4)
	_hotaru(
		[
			Text.t("Look! Every lamp on the lane, awake at once!"),
			Text.t("One loop, and the whole lane listened. Let's go and tell Lumen!"),
		]
	)


## The town map on screen, beside the host in the overworld; null when there is none (a test, a lone editor).
func _town_view() -> TownMapView:
	var screen := get_parent()
	if screen == null:
		return null
	for found in screen.find_children("*", "Node2D", true, false):
		if found is TownMapView:
			return found
	return null


## The pictures of the lane's lamps in `view`, in the order they light: nearest `from` first (Lessons.lane_from). A
## lamp stands on its footprint's bottom middle (TownMapView._standing), which is how its picture is found.
static func lane_sprites(view: TownMapView, from: Vector2i) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for lamp in Lessons.lane_from(view.map, from):
		var at := OverworldMap.cell_of(lamp.get("at", [0, 0]))
		var footprint := OverworldMap.cell_of(lamp.get("size", [1, 1]))
		var spot := Vector2((at.x + footprint.x / 2.0) * TownMapView.TILE, (at.y + footprint.y) * TownMapView.TILE)
		for child in view.things.get_children():
			# A redraw (show_map) leaves the old pictures in the tree until the frame ends: they are skipped.
			if child.is_queued_for_deletion() or not child is Node2D:
				continue
			if not (child as Node2D).position.is_equal_approx(spot):
				continue
			var picture := child.get_child(0) if child.get_child_count() > 0 else null
			if picture is Sprite2D and (picture as Sprite2D).region_enabled:
				out.append(picture as Sprite2D)
				break
	return out


# --- Hotaru -----------------------------------------------------------------------------------------------------------


func _hotaru(texts: Array[String]) -> void:
	var lines: Array[Dictionary] = []
	for text in texts:
		lines.append({"text": text, "speaker": "hotaru", "mood": "happy" if lines.is_empty() else ""})
	var flags: Dictionary = _state.get("flags", {})
	_voice.say(lines, {}, flags)


## Once the town is on screen: why Continue woke the player at home, if it did.
func _tell_pending_note() -> void:
	var note := pending_note
	pending_note = ""
	var said := LessonWords.restore_note(note)
	if said == "":
		return
	var next := (
		Text.t("Press Esc and choose Save, and the town will keep our place.")
		if note == "no-memory"
		else Text.t("A save needs x, y and map to find us. Vell can help us fix it.")
	)
	var texts: Array[String] = [said, next]
	var wait := create_tween()
	wait.tween_interval(0.6)
	wait.tween_callback(_hotaru.bind(texts))


func _unhandled_input(event: InputEvent) -> void:
	if not _voice.busy or not event.is_pressed() or event.is_echo():
		return
	if _is_accept(event):
		_voice.advance()
		get_viewport().set_input_as_handled()


static func _is_accept(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z, KEY_E]
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	return false
