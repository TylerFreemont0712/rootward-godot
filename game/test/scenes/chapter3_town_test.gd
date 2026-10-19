extends GdUnitTestSuite
## Chapter 3 in the town itself (Concept/v0.4/05): with parts built from the test fixtures' reference programs, a talk's
## reward goes into the bag through the player's add(), Nym's shop sells and buys by their price() and can_buy(), Pip's
## board reads their count(), rain falls on their rain day, the townsfolk keep their hours, T tidies the bag by their
## tidy(), and Hotaru shines to their glow().

const ROOT := "user://test-chapter3-town"
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
	"first-pick-told": true, "music-told": true, "map-told": true, "evening-told": true, "glow-asked": true,
}

var screen: OverworldScreen
var _town: Dictionary = {}
var _catalog: Dictionary = {}


func before() -> void:
	_catalog = OverworldContent.load_world().catalog
	_town = _catalog.maps[TOWN]


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


## The town with `parts` built (every stage), the bag, the clock and the coins as given.
func _open(parts: Array[String], bag: Array = [], clock := OverworldState.START_MINUTE, coins := 0) -> void:
	var state := OverworldState.fresh(TOWN, OverworldMap.cell_of(_town.start), "down", "python")
	state.look = LOOK.duplicate(true)
	state.name = "Kai"
	state.flags = FLAGS.duplicate(true)
	state.bag = bag.duplicate(true)
	state.clock = clock
	state.coins = coins
	for id in parts:
		var task: Dictionary = _catalog.tasks[id]
		var record := Parts.passed_record({}, Tasks.stage_count(task) - 1, TaskCheck.reference_of(id, "python"), "python")
		state = Parts.with_record(state, id, record)
	OverworldStore.for_profile().save_state(state)
	screen = (load("res://scenes/overworld/overworld.tscn") as PackedScene).instantiate() as OverworldScreen
	add_child(screen)
	await _until(func() -> bool: return not bool(screen.get("_reading")))
	var runtime := screen.get("_parts") as PartsRuntime
	for id in parts:
		await _until(func() -> bool: return runtime.has_tables(id))
	await get_tree().process_frame


func _until(done: Callable, seconds := WAIT) -> bool:
	var waited := 0.0
	while not done.call() and waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return bool(done.call())


func _flag(flag: String) -> bool:
	return bool(screen.state.flags.get(flag, false))


func test_a_talk_s_reward_goes_into_the_bag_with_the_player_s_add() -> void:
	await _open([Parts.BAG])
	await screen._receive("pebble", 2)
	assert_int(Bag.count(screen.state.bag, "pebble")).is_equal(2)


func test_nym_buys_and_sells_by_the_player_s_price_and_can_buy() -> void:
	await _open([Parts.BAG, Parts.SHOP], [{"item": "apple", "count": 3}])
	screen._open_shop()
	await screen._on_shop_sell("apple", 2)
	var each := int(_catalog.shop.buys.apple)
	assert_int(int(screen.state.coins)).is_equal(each * 2)
	assert_int(Bag.count(screen.state.bag, "apple")).is_equal(1)
	assert_bool(_flag("shop-sold")).is_true()
	screen.state.coins = 20
	await screen._on_shop_buy("bread")
	assert_int(int(screen.state.coins)).is_equal(20 - int(_catalog.shop.sells.bread))
	assert_int(Bag.count(screen.state.bag, "bread")).is_equal(1)
	assert_bool(_flag("shop-bought")).is_true()
	# Not enough coins: the player's can_buy() says no, and nothing changes.
	screen.state.coins = 1
	await screen._on_shop_buy("gear")
	assert_int(int(screen.state.coins)).is_equal(1)
	assert_int(Bag.count(screen.state.bag, "gear")).is_equal(0)


func test_pip_s_board_reads_the_player_s_count() -> void:
	await _open([Parts.COUNT])
	await screen._read_tally()
	assert_bool(_flag("tally-read")).is_true()


func test_rain_falls_on_the_player_s_rain_day() -> void:
	await _open([Parts.CLOCK, Parts.WEATHER])
	var runtime := screen.get("_parts") as PartsRuntime
	var rainy := -1
	for day in Parts.WEATHER_DAYS:
		if runtime.weather_on(day) == "rain":
			rainy = day
			break
	assert_int(rainy).is_greater_equal(0)
	screen.state.day = rainy
	screen._apply_weather()
	assert_str((screen.get("_rain") as RainLayer).weather()).is_equal("rain")
	assert_bool(_flag("rain-seen")).is_true()


func test_no_weather_before_the_clock_gives_days() -> void:
	await _open([Parts.WEATHER])
	screen._apply_weather()
	assert_str((screen.get("_rain") as RainLayer).weather()).is_equal("")


func test_the_townsfolk_keep_the_player_s_hours() -> void:
	await _open([Parts.CLOCK, Parts.HOURS], [], 20 * 60)
	screen._move_people()
	var schedules: Dictionary = _catalog.schedules
	assert_bool(schedules.size() >= 6).is_true()
	var map_view := screen.get("_map") as TownMapView
	for person: String in schedules:
		if not map_view.people.has(person):
			continue
		var walker := map_view.people[person] as Walker
		assert_object(walker.cell).override_failure_message("%s is not at the inn" % person).is_equal(
			OverworldMap.cell_of(schedules[person].inn)
		)
	assert_bool(_flag("hours-seen")).is_true()


func test_t_tidies_the_bag_with_the_player_s_tidy() -> void:
	await _open([Parts.BAG, Parts.TIDY], [{"item": "pebble", "count": 2}, {"item": "apple", "count": 3}])
	await screen._on_bag_tidy()
	assert_str(String(screen.state.bag[0].item)).is_equal("apple")
	assert_str(String(screen.state.bag[1].item)).is_equal("pebble")
	assert_bool(_flag("bag-tidied")).is_true()


func test_hotaru_shines_to_the_player_s_glow() -> void:
	await _open([Parts.GLOW])
	screen._update_glow(1.0)
	assert_float(float(screen.get("_glow_now"))).is_between(0.0, 1.0)
