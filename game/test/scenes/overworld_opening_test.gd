extends GdUnitTestSuite
## The opening, from the overworld with real key events (ADR-0061): a new tinker makes their character, Hotaru wakes
## them, the boots open and are tried, the first step is taken, the player teaches the boots the two keys the way to
## the door and the noticeboard need, the doormat takes them into town, and the noticeboard's four lines are read: that
## sets read-notices and ends the opening in town. The scene change does not run in a test: ScreenTransition is held
## busy, so Game.go returns at once, and the ending is asserted by the overworld's busy flag and the saved state.
## Each case needs the sandbox runtime (scripts/fetch-sandbox.sh); without it the case is skipped, and gdUnit shows why.
## Driven as the flow test is: Game.reset into a temporary save folder, the screen added to the tree, and keys pushed to
## the root of the tree.

const ROOT := "user://test-overworld-opening"
const HOME := "home"
const TOWN := "lanternroot"
const HOME_START := Vector2i(2, 3)
const FIRST_STEP := Vector2i(3, 3)
## How far one press of each key walks.
const DELTA := {KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0)}
## The most presses one talk is given: a line to finish typing and then the next, for each line, and a choice.
const PRESSES := 20
## The keys the walk to the noticeboard uses: right, down and up, which the boots know by then
## (asserted in (c) and (e)).
const WALK_KEYS: Array[Key] = [KEY_RIGHT, KEY_DOWN, KEY_UP]

var screen: OverworldScreen
## The town as its content says it is (ADR-0061): its start and its noticeboard are read from the map, not pinned here.
var _town: Dictionary = {}


func before() -> void:
	_town = OverworldContent.load_world().catalog.maps[TOWN]


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
	ScreenTransition.busy = false
	LanternrootScreen.returns_to = ""
	Game.reset()


func test_the_opening_runs_from_the_creator_to_the_letters(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	# The scene change stays out of the test: Game.go returns at once while the transition is held busy.
	ScreenTransition.busy = true
	await _new_town()
	var talk := screen.get("_talk") as DialogueBox
	var boots := screen.get("_boots") as BootsEditor

	# (a) A tinker with no look yet meets the creator; "That's me!" finishes it, and the look goes to the save.
	var creator := screen.get("_creator") as CharacterCreator
	assert_bool(creator.visible).override_failure_message("a town with no look opens the creator").is_true()
	_press_button(creator, "That's me")
	await _settle()
	(
		assert_bool((screen.state.look as Dictionary).is_empty())
		. override_failure_message("the look is kept once made")
		. is_false()
	)

	# (b) Hotaru's wake talk: Space advances it, and when it ends the boots editor opens.
	assert_bool(talk.busy).override_failure_message("the wake talk plays once the look is made").is_true()
	var opened: bool = await _advance_until(func() -> bool: return boots.visible)
	assert_bool(opened).override_failure_message("the wake talk should open the boots editor").is_true()
	assert_bool(talk.busy).override_failure_message("the editor opens when the talk is over").is_false()

	# (c) The one rule the boots start with: Try them, and the town reads it.
	await _try_the_boots(boots)
	var first_taught := BootsRules.taught(screen.table)
	(
		assert_bool(first_taught.has("right"))
		. override_failure_message("the first rule teaches right: %s" % [first_taught])
		. is_true()
	)
	await _close_editor(boots)

	# (d) One press of right, held for a frame, is one step to the right; the first step starts Hotaru's talk.
	await _step(KEY_RIGHT)
	assert_that(OverworldState.cell(screen.state)).override_failure_message("the first step lands on (3, 3)").is_equal(
		FIRST_STEP
	)
	assert_bool(talk.busy).override_failure_message("the first step starts hotaru-first-step").is_true()
	var talked: bool = await _advance_until(func() -> bool: return not talk.busy)
	assert_bool(talked).override_failure_message("the first-step talk should end").is_true()

	# (e) The way to the doormat and the way to the noticeboard need down and up. Hotaru asks the player to teach the
	# other keys (press B), so the player does: two rules in the editor, then Try them.
	_tap(KEY_B)
	await _settle()
	assert_bool(boots.visible).override_failure_message("B opens the boots editor").is_true()
	await _add_a_rule(boots, "down", "y", 1)
	await _add_a_rule(boots, "up", "y", -1)
	await _try_the_boots(boots)
	var taught := BootsRules.taught(screen.table)
	(
		assert_bool(taught.has("down") and taught.has("up"))
		. override_failure_message("the boots should know down and up now: %s" % [taught])
		. is_true()
	)
	await _close_editor(boots)

	# (f) To the doormat at (5, 7): right twice, then down four times. The last step is onto the mat, and the door takes
	# the player into town.
	await _step(KEY_RIGHT)
	await _step(KEY_RIGHT)
	for _i in 4:
		await _step(KEY_DOWN)
	var left: bool = await _until(func() -> bool: return not bool(screen.get("_busy")))
	assert_bool(left).override_failure_message("the door did not finish opening").is_true()
	assert_str(String(screen.state.map)).override_failure_message("the door leads into town").is_equal(TOWN)
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("the player arrives at the town's start")
		. is_equal(_town_start())
	)
	var saved := OverworldStore.for_profile().load_state()
	assert_str(String(saved.get("map", ""))).override_failure_message("the town was not saved").is_equal(TOWN)
	assert_that(OverworldState.cell(saved)).override_failure_message("the town's start was not saved").is_equal(
		_town_start()
	)
	assert_bool(talk.busy).override_failure_message("arriving in town starts hotaru-town").is_true()
	var welcomed: bool = await _advance_until(func() -> bool: return not talk.busy)
	assert_bool(welcomed).override_failure_message("hotaru-town should end").is_true()
	# The town reads its own boots before any key is walked on, so the walk waits for it.
	var town_read: bool = await _until(func() -> bool: return _read_ready())
	assert_bool(town_read).override_failure_message("the town's boots were never read: %s" % _table_message()).is_true()

	# (g) Across the square to the noticeboard. The way is worked out from the town's own map: the shortest walk to
	# the cell below the sign, with the keys taught so far and never through a door. One press up then puts the player
	# beside the sign, facing up. Every press is checked to walk exactly one tile.
	var noticeboard := _noticeboard(_town)
	assert_bool(not noticeboard.is_empty()).override_failure_message("the town has a noticeboard").is_true()
	if noticeboard.is_empty():
		return
	var footprint := OverworldMap.cell_of(noticeboard.get("size", [1, 1]))
	var side := OverworldMap.cell_of(noticeboard.at) + Vector2i(0, footprint.y)
	var route := _route(_town, _town_start(), side + Vector2i(0, 1))
	(
		assert_bool(bool(route.found))
		. override_failure_message("no way to the noticeboard with the keys taught so far")
		. is_true()
	)
	if not bool(route.found):
		return
	for key: Key in route.keys:
		await _step(key)
	await _step(KEY_UP)
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("the player stands beside the noticeboard")
		. is_equal(side)
	)
	assert_str(String(screen.state.facing)).override_failure_message("the player faces up at the noticeboard").is_equal(
		"up"
	)

	# (h) The noticeboard is a four-line sign with no choices (ADR-0061). Space reads it through, and reading it sets
	# read-notices. Nothing hands over: the opening ends in town.
	_tap(KEY_SPACE)
	await _settle()
	assert_bool(talk.busy).override_failure_message("Space at the noticeboard opens its talk").is_true()
	var ended: bool = await _advance_until(func() -> bool: return not talk.busy or not _choices(talk).is_empty())
	(
		assert_bool(_choices(talk).is_empty())
		. override_failure_message("the sign offers no choice: %s" % [_choices(talk)])
		. is_true()
	)
	assert_bool(ended).override_failure_message("the sign's four lines should end the talk").is_true()
	(
		assert_bool(bool(screen.get("_busy")))
		. override_failure_message("the opening ends in town: nothing hands over")
		. is_false()
	)
	assert_str(String(screen.state.map)).override_failure_message("the player is still in town").is_equal(TOWN)
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("the player still stands beside the noticeboard")
		. is_equal(side)
	)

	# The ending is saved: the town, the cell and facing, the beats and read-notices, and the three rules taught.
	var board := OverworldStore.for_profile().load_state()
	assert_str(String(board.get("map", ""))).override_failure_message("the noticeboard's town is saved").is_equal(TOWN)
	assert_that(OverworldState.cell(board)).override_failure_message("the noticeboard's cell is saved").is_equal(side)
	assert_str(String(board.get("facing", ""))).override_failure_message("the facing is saved").is_equal("up")
	var flags: Dictionary = board.get("flags", {})
	for flag: String in ["woke", "first-step", "left-home", "read-notices"]:
		assert_bool(bool(flags.get(flag, false))).override_failure_message("the %s beat is saved" % flag).is_true()
	var blocks: Array = (board.get("boots", {}) as Dictionary).get("blocks", [])
	assert_int(blocks.size()).override_failure_message("the three rules taught are saved").is_equal(3)


## A new tinker's save (no look yet), and the overworld opened on it, once its first boots are read.
func _new_town() -> void:
	OverworldStore.for_profile().save_state(OverworldState.fresh(HOME, HOME_START, "down", BootsCode.PYTHON))
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await get_tree().process_frame
	var read: bool = await _until(func() -> bool: return _read_ready())
	assert_bool(read).override_failure_message("the first boots were never read: %s" % _table_message()).is_true()


## Whether the town has finished reading its boots, so that a key walks on the table it has just made.
func _read_ready() -> bool:
	return not bool(screen.get("_reading")) and BootsRules.ready(screen.table)


func _table_message() -> String:
	return String(screen.table.get("message", ""))


## Try them, as the player presses it: the town reads the boots in the sandbox, and this waits until the table is ready.
func _try_the_boots(boots: BootsEditor) -> void:
	_press_button(boots, "Try them")
	var read: bool = await _until(func() -> bool: return _read_ready())
	assert_bool(read).override_failure_message("the boots did not load: %s" % _table_message()).is_true()
	await _settle()


## Esc closes the boots editor, as the player does.
func _close_editor(boots: BootsEditor) -> void:
	_tap(KEY_ESCAPE)
	await _settle()
	assert_bool(boots.visible).override_failure_message("Esc closes the boots editor").is_false()


## One rule added the way the player adds it: "+ Add a rule", then its key, axis and amount pickers set to the move.
func _add_a_rule(boots: BootsEditor, key: String, axis: String, by: int) -> void:
	_press_button(boots, "+ Add a rule")
	await _settle()
	var rows := boots.get("_rows") as VBoxContainer
	var pickers := _pickers(rows.get_child(rows.get_child_count() - 1))
	assert_int(pickers.size()).override_failure_message("a rule row has a key, an axis and an amount").is_equal(3)
	if pickers.size() != 3:
		return
	_choose_in(pickers[0], BootsRules.KEYS.find(key))
	_choose_in(pickers[1], BootsCode.AXES.find(axis))
	_choose_in(pickers[2], BootsCode.AMOUNTS.find(by))
	await _settle()


## The player picks item `at` in a picker: the picker shows it, and the editor hears of it as it would from a click.
func _choose_in(picker: OptionButton, at: int) -> void:
	picker.select(at)
	picker.item_selected.emit(at)


## The pickers (OptionButtons) under `root`, in the order they sit on screen.
func _pickers(root: Node) -> Array[OptionButton]:
	var found: Array[OptionButton] = []
	for child: Node in root.get_children():
		if child is OptionButton:
			found.append(child as OptionButton)
		else:
			found.append_array(_pickers(child))
	return found


## Presses the button under `root` whose text starts with `prefix`, as a click would: its `pressed` signal goes out.
func _press_button(root: Node, prefix: String) -> void:
	var button := _button(root, prefix)
	assert_object(button).override_failure_message("no button starts with %s" % prefix).is_not_null()
	if button != null:
		button.pressed.emit()


func _button(root: Node, prefix: String) -> Button:
	for child: Node in root.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child as Button
		var inside := _button(child, prefix)
		if inside != null:
			return inside
	return null


## The texts of the choices Hotaru or a townsperson is offering right now.
func _choices(talk: DialogueBox) -> Array[String]:
	var texts: Array[String] = []
	var box := talk.get("_choices") as VBoxContainer
	for child: Node in box.get_children():
		if child is Button:
			texts.append((child as Button).text)
	return texts


## One press of `code`, held until the walk starts and then let go. The town walks one tile in that direction, and
## the cell it reaches is checked.
func _step(code: Key) -> void:
	var before := OverworldState.cell(screen.state)
	var player := screen.get("_player") as Walker
	_key(code, true)
	var started: bool = await _until(func() -> bool: return player.moving)
	_key(code, false)
	var ended: bool = await _until(func() -> bool: return not player.moving)
	assert_bool(started and ended).override_failure_message("the player did not walk for key %d" % code).is_true()
	var delta: Vector2i = DELTA[code]
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("one press walks one tile from %s" % [before])
		. is_equal(before + delta)
	)


## Presses Space, the talk's key, until `done` holds, at most PRESSES times. A set of choices takes the same key once
## its first button has the focus, which the settle before each press gives it.
func _advance_until(done: Callable) -> bool:
	for _i in PRESSES:
		if done.call():
			return true
		await _settle()
		_tap(KEY_SPACE)
	await _settle()
	return done.call()


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	get_tree().root.push_input(event)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)


## Two frames: enough for a key to be read, a deferred focus to land and a signal's handler to finish.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


## The town's start, read from its map: where the player stands on arriving from home.
func _town_start() -> Vector2i:
	return OverworldMap.cell_of(_town.start)


## The town's noticeboard: the thing whose art is `noticeboard` (ADR-0061), or {} when the town has none.
func _noticeboard(map: Dictionary) -> Dictionary:
	for thing: Dictionary in map.objects:
		if String(thing.get("art", "")) == "noticeboard":
			return thing
	return {}


## The cells the townspeople stand on, as OverworldMap.blocked takes them (cell -> who).
func _people_cells(map: Dictionary) -> Dictionary:
	var cells := {}
	for person: Dictionary in map.people:
		cells[OverworldMap.cell_of(person.at)] = person.id
	return cells


## The shortest walk from `from` to `to` that uses only WALK_KEYS, over cells a walk can enter: walkable, nobody
## standing there, never a door (a door takes the player inside). `found` is false when there is no such walk.
func _route(map: Dictionary, from: Vector2i, to: Vector2i) -> Dictionary:
	var people := _people_cells(map)
	var came := {from: KEY_NONE}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size() and not came.has(to):
		var here: Vector2i = queue[head]
		head += 1
		for key: Key in WALK_KEYS:
			var next: Vector2i = here + DELTA[key]
			if came.has(next) or OverworldMap.blocked(map, next, people):
				continue
			if not OverworldMap.warp_at(map, next).is_empty():
				continue
			came[next] = key
			queue.append(next)
	var keys: Array[Key] = []
	if not came.has(to):
		return {"found": false, "keys": keys}
	var back := to
	while back != from:
		var way: Key = came[back]
		keys.push_front(way)
		var step: Vector2i = DELTA[way]
		back -= step
	return {"found": true, "keys": keys}


## Waits, frame by frame, until `done` holds. Time, not frames: the sandbox and the walks take real time.
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
