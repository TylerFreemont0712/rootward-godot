extends GdUnitTestSuite
## The things in Lanternroot driven the way a player drives them (ADR-0061, Concept/v0.3/09): real key events go to the
## screen. Space on the cabbage-plot gate runs its code, which opens the gate once the boots know all four ways; X opens
## that code in the editor, where a Run that breaks says its line and keeps the gate shut; Space on the crossroads sign
## says its words. Each case needs the sandbox runtime (scripts/fetch-sandbox.sh); without it the case is skipped, and
## gdUnit shows the reason. The driver follows overworld_flow_test.gd, and keeps its own copy of the helpers.

const ROOT := "user://test-town-things-flow"
const TOWN := "lanternroot"
const GATE := "cabbage-gate"
const SIGN := "crossroads-sign"
## Where the player stands to face the gate: the cell south of the gate's west tile, facing up. Walkable, and free.
const BY_GATE := Vector2i(4, 45)
## Where the player stands to face the crossroads signpost, which stands at (11, 20), facing up.
const BY_SIGN := Vector2i(11, 21)
## The gate's code as a player might leave it: a NameError on line 2.
const BROKEN := 'def on_use(thing, player):\n    return {"set": {"open": nope}}\n'
## The part of the starters' words that each case looks for, for the shut gate and the open gate.
const SHUT_WORDS := "stays shut"
const OPEN_WORDS := "swings open"
const THREE: Array[String] = ["right", "down", "up"]
const FOUR: Array[String] = ["right", "down", "up", "left"]
## Each key's rule as BootsCode.rule takes it: its axis and its step.
const WAYS := {"right": ["x", 1], "down": ["y", 1], "up": ["y", -1], "left": ["x", -1]}
const LOOK := {
	"outfit": "outfit/tunic",
	"hair": "hair/short",
	"colours":
	{
		"skin": "skin_peach",
		"hair": "hair_brown",
		"main": "cloth_teal",
		"second": "cloth_cream",
		"accent": "cloth_orange"
	},
}
## Every beat has played before the case starts, so no talk opens over it.
const ALL_BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}

var screen: OverworldScreen
var _catalog: Dictionary = {}


func before() -> void:
	_catalog = OverworldContent.load_world().catalog


func before_test() -> void:
	Game.reset(ROOT)
	Game.boot()
	Game.profile.needs_name = false
	Game.profile.preferred_language = "en"
	Game.profiles.save_profile(Game.profile)
	Game.select_profile(String(Game.profile.id), false)
	OverworldStore.for_profile().delete_state()


func after_test() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	# As Game.quit does: the music stops, and the audio server gets frames to let its streams go.
	Sound.silence()
	await _wait(0.1)
	Background.finish_all()
	OverworldStore.for_profile().delete_state()
	Game.reset()


func test_space_at_the_shut_gate_says_it_is_shut_and_the_player_stays_on_the_near_side(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(BY_GATE, "up", _boots_with(THREE))
	(
		assert_array(BootsRules.taught(screen.table))
		. override_failure_message("the boots should know three ways")
		. contains_exactly_in_any_order(THREE)
	)
	await _press_space()
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("the player stepped past the shut gate")
		. is_equal(BY_GATE)
	)
	(
		assert_bool(_bubble_shows(SHUT_WORDS))
		. override_failure_message("Hotaru should say the gate is shut, and says: %s" % _bubble_text())
		. is_true()
	)
	assert_bool(_gate_open(screen.state)).override_failure_message("the gate opened with three ways").is_false()


func test_space_at_the_gate_with_four_ways_opens_it_sets_its_flags_and_saves_it(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(BY_GATE, "up", _boots_with(FOUR))
	assert_array(BootsRules.taught(screen.table)).contains_exactly_in_any_order(FOUR)
	await _press_space()
	(
		assert_bool(_bubble_shows(OPEN_WORDS))
		. override_failure_message("Hotaru should say the gate swings open, and says: %s" % _bubble_text())
		. is_true()
	)
	var flags: Dictionary = screen.state.flags
	(
		assert_bool(bool(flags.get("first-action", false)))
		. override_failure_message("the first answer should set first-action")
		. is_true()
	)
	(
		assert_bool(bool(flags.get("cabbage-gate-open", false)))
		. override_failure_message("opening the gate should set cabbage-gate-open")
		. is_true()
	)
	assert_bool(_gate_open(screen.state)).override_failure_message("the town's state says the gate is shut").is_true()
	(
		assert_array(_open_cells(screen.state).keys())
		. override_failure_message("both tiles of the open gate should be walkable")
		. contains(_gate_cells())
	)
	var saved := _saved()
	assert_bool(_gate_open(saved)).override_failure_message("the open field is not in the saved file").is_true()
	(
		assert_bool(bool((saved.get("flags", {}) as Dictionary).get("cabbage-gate-open", false)))
		. override_failure_message("cabbage-gate-open is not in the saved file")
		. is_true()
	)
	# The first answer's line from Hotaru is said now, and the quest that waits on the boots is the next one.
	var talk := screen.get("_talk") as DialogueBox
	assert_bool(talk.busy).override_failure_message("the first answer should start Hotaru's line").is_true()
	(
		assert_str(String(Quests.current(_catalog.quests, flags).get("id", "")))
		. override_failure_message("with the boots taught, the hello quest should be the next one")
		. is_equal("hello")
	)


func test_the_player_walks_through_the_gate_once_it_is_open(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(BY_GATE, "up", _boots_with(FOUR))
	await _press_space()
	await _advance_talk()
	# The gate's west tile is the one straight up from the player, and the cell past it is open path.
	var through := BY_GATE + Vector2i(0, -1)
	await _walk(KEY_UP)
	await _wait(0.2)
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("the player did not walk into the open gate")
		. is_equal(through)
	)
	await _walk(KEY_UP)
	await _wait(0.2)
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("the player did not walk through the open gate")
		. is_equal(through + Vector2i(0, -1))
	)


func test_space_at_the_crossroads_sign_says_its_default_text(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(BY_SIGN, "up", _boots_with(FOUR))
	await _press_space()
	var words := String(_object_of(SIGN).get("text", ""))
	assert_str(words).override_failure_message("the sign has no default text").is_not_empty()
	(
		assert_bool(_bubble_shows(words))
		. override_failure_message("Hotaru should say the sign's text, and says: %s" % _bubble_text())
		. is_true()
	)
	assert_that(OverworldState.cell(screen.state)).override_failure_message("the sign moved the player").is_equal(
		BY_SIGN
	)


func test_x_opens_the_gates_code_and_a_run_that_breaks_says_its_line_and_keeps_the_gate_shut(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(BY_GATE, "up", _boots_with(FOUR))
	await _tap(KEY_X)
	var host := _things().host
	assert_bool(host.editing()).override_failure_message("X should open the gate's code").is_true()
	var editor := host.get("_editor") as ThingEditor
	var title := (editor.get("_title") as Label).text
	assert_str(title).override_failure_message("the editor should be named for the gate").is_equal(
		String(_catalog.things[GATE].name)
	)
	var panel := editor.get("_code") as BootsCodePanel
	(
		assert_bool(panel.editor.text.contains("def on_use"))
		. override_failure_message("the editor should open on the gate's starter")
		. is_true()
	)
	panel.show_code(BROKEN)
	# Ctrl+Enter is Run.
	_key(KEY_ENTER, true, true)
	_key(KEY_ENTER, false, true)
	var result := editor.get("_result") as Label
	var answered: bool = await _until(
		func() -> bool: return not bool(host.get("_running")) and not result.text.begins_with("Trying")
	)
	assert_bool(answered).override_failure_message("the run never answered: %s" % result.text).is_true()
	(
		assert_bool(result.text.contains("line 2"))
		. override_failure_message("a run that breaks should say its line: %s" % result.text)
		. is_true()
	)
	assert_bool(_gate_open(screen.state)).override_failure_message("a run that broke opened the gate").is_false()
	(
		assert_bool((screen.state.flags as Dictionary).has("cabbage-gate-open"))
		. override_failure_message("a run that broke raised cabbage-gate-open")
		. is_false()
	)
	(
		assert_array(_open_cells(screen.state).keys())
		. override_failure_message("the gate's tiles should stay shut")
		. is_empty()
	)
	# Esc closes the editor, and the code typed stays with the gate.
	await _tap(KEY_ESCAPE)
	assert_bool(host.editing()).override_failure_message("Esc should close the editor").is_false()
	var kept := _code_kept(_saved())
	assert_bool(kept.contains("nope")).override_failure_message("closing should keep the code typed").is_true()


func test_the_gate_stays_open_when_the_saved_town_is_read_back(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(BY_GATE, "up", _boots_with(FOUR))
	await _press_space()
	assert_bool(_gate_open(_saved())).override_failure_message("the open field is not in the saved file").is_true()
	screen.queue_free()
	await _wait(0.1)
	await _enter()
	assert_bool(_gate_open(screen.state)).override_failure_message("the reopened town lost the open field").is_true()
	assert_array(_open_cells(screen.state).keys()).override_failure_message("the reopened gate is shut").contains(
		_gate_cells()
	)
	await _walk(KEY_UP)
	await _wait(0.2)
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("the reopened player could not walk into the gate")
		. is_equal(BY_GATE + Vector2i(0, -1))
	)


## The town, opened on `cell` facing `facing`, with these boots. The state is saved first, so the town reads it back.
func _open(cell: Vector2i, facing: String, blocks: Array) -> void:
	var state := OverworldState.fresh(TOWN, cell, facing, BootsCode.PYTHON)
	state.look = LOOK.duplicate(true)
	state.name = "Tinker"
	state.flags = ALL_BEATS.duplicate(true)
	state.boots.blocks = blocks.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	await _enter()


## The overworld screen, reading its state from the save, with its boots read (on a thread).
func _enter() -> void:
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await get_tree().process_frame
	var read: bool = await _until(
		func() -> bool: return not bool(screen.get("_reading")) and BootsRules.ready(screen.table)
	)
	var reason := String(screen.table.get("message", "the boots were never read"))
	assert_bool(read).override_failure_message("the boots did not load: %s" % reason).is_true()


## The boots' rules for the keys given, in the order given.
func _boots_with(keys: Array[String]) -> Array:
	var blocks: Array = []
	for key: String in keys:
		var way: Array = WAYS[key]
		blocks.append(BootsCode.rule(key, String(way[0]), int(way[1])))
	return blocks


func _key(code: Key, down: bool, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.ctrl_pressed = ctrl
	get_tree().root.push_input(event)


## One press of a key that does not walk: down, held across a frame, and up.
func _tap(code: Key) -> void:
	_key(code, true)
	await get_tree().process_frame
	_key(code, false)
	await _wait(0.05)


## Space, once. The thing runs in the sandbox on a thread, and the case waits until its answer has landed in the town.
func _press_space() -> void:
	await _tap(KEY_SPACE)
	var answered: bool = await _until(func() -> bool: return not _things().busy())
	assert_bool(answered).override_failure_message("the thing did not answer Space").is_true()
	await _wait(0.1)


## Hotaru's talk goes on with Space, a line at a time. The first answer's line is two lines.
func _advance_talk() -> void:
	var talk := screen.get("_talk") as DialogueBox
	var presses := 0
	while talk.busy and presses < 12:
		await _tap(KEY_SPACE)
		presses += 1
	assert_bool(talk.busy).override_failure_message("Hotaru's talk did not end after %d presses" % presses).is_false()


## One press is one step: the key goes down, the walk starts, and the key comes up before the walk ends.
func _walk(code: Key) -> void:
	_key(code, true)
	var started: bool = await _until(func() -> bool: return _player().moving)
	_key(code, false)
	var ended: bool = await _until(func() -> bool: return not _player().moving)
	(
		assert_bool(started and ended)
		. override_failure_message("the player did not walk for %s" % OS.get_keycode_string(code))
		. is_true()
	)


## Waits, frame by frame, until `done` holds. Time, not frames: the sandbox and the walk take real time.
func _until(done: Callable, seconds := 20.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _player() -> Walker:
	return screen.get("_player") as Walker


func _things() -> ThingTown:
	return screen.get("_things") as ThingTown


## Whether Hotaru's bubble is up and says `words`.
func _bubble_shows(words: String) -> bool:
	var bubble := screen.get("_bubble") as PanelContainer
	return bubble.visible and _bubble_text().contains(words)


func _bubble_text() -> String:
	return (screen.get("_bubble_text") as Label).text


## The town's map as the content builds it, and the object on it with this id.
func _town() -> Dictionary:
	return _catalog.maps[TOWN]


func _object_of(id: String) -> Dictionary:
	for object: Dictionary in _town().objects:
		if String(object.get("id", "")) == id:
			return object
	return {}


## The tiles the gate covers, from its position and size on the map.
func _gate_cells() -> Array[Vector2i]:
	var gate := _object_of(GATE)
	var at := OverworldMap.cell_of(gate.get("at", [0, 0]))
	var size := OverworldMap.cell_of(gate.get("size", [1, 1]))
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			out.append(at + Vector2i(x, y))
	return out


## Whether the gate's open field is true in this state (the state's things, as the save keeps them).
func _gate_open(state: Dictionary) -> bool:
	var things: Dictionary = state.get("things", {})
	var entry: Dictionary = things.get(GATE, {})
	var fields: Dictionary = entry.get("fields", {})
	return bool(fields.get("open", false))


## The cells the town leaves walkable for its open things, as TownThings judges them (cell -> true).
func _open_cells(state: Dictionary) -> Dictionary:
	return TownThings.open_cells(_town(), state.get("things", {}))


func _code_kept(state: Dictionary) -> String:
	var things: Dictionary = state.get("things", {})
	var entry: Dictionary = things.get(GATE, {})
	var code: Dictionary = entry.get("code", {})
	return String(code.get("python", ""))


func _saved() -> Dictionary:
	return OverworldStore.for_profile().load_state()
