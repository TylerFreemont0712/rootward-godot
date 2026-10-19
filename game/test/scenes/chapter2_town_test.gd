extends GdUnitTestSuite
## Chapter 2 in the town itself (Concept/v0.4/01, section 15): with parts built from the test fixtures' reference
## programs, the overworld picks an apple with the player's add() and marks it, gives three cabbages with their
## remove(), rolls the credits and remembers it, tints the town by their time_of_day(), and opens the bag on the key
## their shortcut() names.

const ROOT := "user://test-chapter2-town"
const TOWN := "lanternroot"
const LOOK := {
	"outfit": "outfit/tunic",
	"hair": "hair/short",
	"colours": {"skin": "skin_peach", "hair": "hair_brown", "main": "cloth_teal"},
}
const WAIT := 20.0
## The beats are done and Hotaru's notes about the parts are said, so nothing opens over the town.
const FLAGS := {
	"woke": true, "first-step": true, "left-home": true, "all-ways": true, "boots-hint-seen": true,
	"pocket-menu-told": true, "own-menu-told": true, "lamps-lit-told": true, "wink-told": true, "volume-told": true,
	"first-pick-told": true, "music-told": true, "map-told": true, "evening-told": true,
}

var screen: OverworldScreen
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
	Sound.silence()
	await get_tree().process_frame
	Background.finish_all()
	OverworldStore.for_profile().delete_state()
	ScreenTransition.busy = false
	Game.reset()


## The town with `parts` built (every stage), the bag and the clock as given.
func _open(parts: Array[String], bag: Array = [], clock := OverworldState.START_MINUTE) -> void:
	var state := OverworldState.fresh(TOWN, OverworldMap.cell_of(_town.start), "down", "python")
	state.look = LOOK.duplicate(true)
	state.name = "Kai"
	state.flags = FLAGS.duplicate(true)
	state.bag = bag.duplicate(true)
	state.clock = clock
	var catalog: Dictionary = OverworldContent.load_world().catalog
	for id in parts:
		var task: Dictionary = catalog.tasks[id]
		var record := Parts.passed_record({}, Tasks.stage_count(task) - 1, TaskCheck.reference_of(id, "python"), "python")
		state = Parts.with_record(state, id, record)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _until(func() -> bool: return not bool(screen.get("_reading")))
	var runtime := screen.get("_parts") as PartsRuntime
	for id in parts:
		await _until(func() -> bool: return runtime.has_tables(id))


func _until(done: Callable, seconds := WAIT) -> bool:
	var waited := 0.0
	while not done.call() and waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return bool(done.call())


func test_picking_an_apple_puts_it_in_the_bag_and_marks_it() -> void:
	await _open([Parts.BAG])
	var apples: Array = (OverworldContent.load_world().catalog.pickups.lanternroot as Array).filter(
		func(pickup: Dictionary) -> bool: return String(pickup.item) == "apple"
	)
	assert_array(apples).is_not_empty()
	await screen._pick(apples[0])
	assert_int(Bag.count(screen.state.bag, "apple")).is_equal(1)
	assert_bool(bool(screen.state.flags.get("picked-apple", false))).is_true()
	# Picked once, it has to grow back first.
	await screen._pick(apples[0])
	assert_int(Bag.count(screen.state.bag, "apple")).is_equal(1)


func test_giving_three_cabbages_takes_them_out_with_the_player_s_remove() -> void:
	await _open([Parts.BAG], [{"item": "cabbage", "count": 3}, {"item": "apple", "count": 1}])
	assert_bool(Talk.holds({"has": "cabbage", "at_least": 3}, Parts.facts(screen.state))).is_true()
	await screen._give("cabbage", 3)
	assert_int(Bag.count(screen.state.bag, "cabbage")).is_equal(0)
	assert_int(Bag.count(screen.state.bag, "apple")).is_equal(1)
	assert_bool(bool(screen.state.flags.get("gave-cabbage", false))).is_true()


func test_the_credits_roll_the_player_s_lines_and_are_remembered() -> void:
	await _open([Parts.CREDITS])
	var credits := screen.get("_credits") as CreditsRoll
	credits.card_time = 0.1
	await screen._roll_credits()
	assert_bool(credits.is_rolling()).is_true()
	credits.skip()
	var done: bool = await _until(func() -> bool: return bool(screen.state.flags.get("credits-rolled", false)), 10.0)
	assert_bool(done).override_failure_message("the credits finished and were remembered").is_true()


func test_the_evening_tints_the_town_by_the_player_s_time_of_day() -> void:
	await _open([Parts.CLOCK], [], 1200)
	screen._update_tint(0.0, true)
	var tint := screen.get("_tint") as CanvasModulate
	assert_object(tint.color).is_equal(OverworldScreen.TINTS["evening"])
	screen.state.clock = 700
	screen._update_tint(0.0, true)
	assert_object(tint.color).is_equal(OverworldScreen.TINTS["morning"])


func test_the_key_the_player_s_shortcut_names_opens_the_bag() -> void:
	await _open([Parts.SHORTCUTS, Parts.BAG])
	var event := InputEventKey.new()
	event.keycode = KEY_I
	event.physical_keycode = KEY_I
	event.pressed = true
	assert_str(screen._shortcut_of(event)).is_equal("bag")
	get_tree().root.push_input(event)
	await get_tree().process_frame
	var bag := screen.get("_bag_panel") as BagPanel
	assert_bool(bag.is_open()).override_failure_message("I opens the bag").is_true()
