extends GdUnitTestSuite
## The overworld driven the way a player drives it (ADR-0061): real key events go to the screen, the player's boots
## run in the sandbox, and the town walks, bumps, says what it cannot do, takes a door and saves. Each case needs the
## sandbox runtime (scripts/fetch-sandbox.sh); without it the case is skipped, and gdUnit shows the reason.
## Driven as the repo's other screen tests are (lanternroot_screen_test, shardrun_screen_test): Game.reset into a
## temporary save folder, the screen added to the tree, and keys pushed to the root of the tree.

const ROOT := "user://test-overworld-flow"
const HOME := "home"
const TOWN := "lanternroot"
const HOME_START := Vector2i(2, 3)
const MAT := Vector2i(5, 7)
const TOWN_START := Vector2i(6, 23)
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
## Every beat has played: Hotaru has said her piece, so nothing opens over the walk.
const ALL_BEATS := {"woke": true, "first-step": true, "left-home": true, "all-ways": true}

var screen: OverworldScreen


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


## The overworld, opened on `map` at `cell` with these boots and flags, once the boots have been read (on a thread).
func _open(map: String, cell: Vector2i, flags: Dictionary, blocks: Array) -> void:
	var state := OverworldState.fresh(map, cell, "down", BootsCode.PYTHON)
	state.look = LOOK.duplicate(true)
	state.name = "Tinker"
	state.flags = flags.duplicate(true)
	state.boots.blocks = blocks.duplicate(true)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await get_tree().process_frame
	var read: bool = await _until(
		func() -> bool: return not bool(screen.get("_reading")) and BootsRules.ready(screen.table)
	)
	var reason := String(screen.table.get("message", "the boots were never read"))
	assert_bool(read).override_failure_message("the boots did not load: %s" % reason).is_true()


func _player() -> Walker:
	return screen.get("_player") as Walker


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	get_tree().root.push_input(event)


## One press is one step: the key goes down, the walk starts, and the key comes up before the walk ends, so the town
## never walks on after the player has let go.
func _walk(code: Key) -> void:
	_key(code, true)
	var started: bool = await _until(func() -> bool: return _player().moving)
	_key(code, false)
	var ended: bool = await _until(func() -> bool: return not _player().moving)
	assert_bool(started and ended).override_failure_message("the player did not walk for %s" % str(code)).is_true()


## A press that does not walk (a bump, a key with no rule): the key goes down, is held across at least one frame (the
## frame in which the screen reads it and takes the step), and only then comes up.
func _press(code: Key) -> void:
	_key(code, true)
	await get_tree().process_frame
	var read: bool = await _until(func() -> bool: return (screen.get("_held") as Array).is_empty())
	_key(code, false)
	assert_bool(read).override_failure_message("the screen never took the press of %s" % str(code)).is_true()
	await _wait(0.05)


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


## Whether Hotaru's bubble is up and says `words`. With no words given, only that the bubble is up is checked.
func _bubble_shows(words: String = "") -> bool:
	var bubble := screen.get("_bubble") as PanelContainer
	var text := (screen.get("_bubble_text") as Label).text
	return bubble.visible and text.contains(words)


func test_pressing_right_moves_the_player_one_cell(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(TOWN, TOWN_START, ALL_BEATS, [BootsCode.rule("right", "x", 1)])
	await _walk(KEY_RIGHT)
	await _wait(0.4)
	assert_str(String(screen.state.map)).is_equal(TOWN)
	assert_that(OverworldState.cell(screen.state)).override_failure_message("one press is one cell").is_equal(
		TOWN_START + Vector2i(1, 0)
	)


func test_pressing_into_the_bed_bumps_and_hotaru_says_so(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	# The bed is solid, as a wall is: the left rule presses the player into it from the start of the house.
	await _open(HOME, HOME_START, ALL_BEATS, [BootsCode.rule("left", "x", -1)])
	await _press(KEY_LEFT)
	(
		assert_that(OverworldState.cell(screen.state))
		. override_failure_message("a bump leaves the cell as it was")
		. is_equal(HOME_START)
	)
	(
		assert_bool(_bubble_shows("Bonk! Something is in the way."))
		. override_failure_message("Hotaru should say the bump in her bubble: Bonk! Something is in the way.")
		. is_true()
	)


func test_a_key_with_no_rule_stands_still_and_says_what_is_missing(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(TOWN, TOWN_START, ALL_BEATS, [BootsCode.rule("right", "x", 1)])
	await _press(KEY_DOWN)
	assert_that(OverworldState.cell(screen.state)).override_failure_message("no rule, no step").is_equal(TOWN_START)
	(
		assert_bool(_bubble_shows("Your boots don't know the down key yet"))
		. override_failure_message("Hotaru should say the boots do not know the down key")
		. is_true()
	)


func test_walking_onto_the_home_mat_takes_you_to_town_and_saves(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(HOME, MAT + Vector2i(0, -1), {"woke": true, "first-step": true}, [BootsCode.rule("down", "y", 1)])
	await _walk(KEY_DOWN)
	var left: bool = await _until(func() -> bool: return not bool(screen.get("_busy")))
	assert_bool(left).override_failure_message("the door did not finish opening").is_true()
	assert_str(String(screen.state.map)).is_equal(TOWN)
	assert_that(OverworldState.cell(screen.state)).is_equal(TOWN_START)
	var saved := OverworldStore.for_profile().load_state()
	assert_str(String(saved.get("map", ""))).override_failure_message("the town was not saved").is_equal(TOWN)
	assert_that(OverworldState.cell(saved)).is_equal(TOWN_START)


func test_the_first_step_in_town_starts_hotaru_talking(
	_do_skip := not Sandbox.is_available(SandboxJob.PYTHON),
	_skip_reason := "the sandbox runtime is not installed: run scripts/fetch-sandbox.sh to walk the boots' code",
) -> void:
	await _open(TOWN, TOWN_START, {"woke": true, "left-home": true}, [BootsCode.rule("right", "x", 1)])
	await _walk(KEY_RIGHT)
	var talk := screen.get("_talk") as DialogueBox
	assert_bool(talk.busy).override_failure_message("the first step should start hotaru-first-step").is_true()
	assert_bool(bool((screen.state.flags as Dictionary).get("first-step", false))).is_true()
	var saved := OverworldStore.for_profile().load_state()
	(
		assert_bool(bool((saved.get("flags", {}) as Dictionary).get("first-step", false)))
		. override_failure_message("the first step is saved")
		. is_true()
	)
