extends GdUnitTestSuite
## The per-cast decisions of a legendary cast (docs/LEGENDARY_LOOKS.md, "Fight wiring", LegendaryCast): one black hole
## per foe per cast, a critical or a ward never opening it, each foe's aim kept while the foe moves, the origin seeded
## from the orrery's final star and kept once its circle frees (the launch point with no orrery), a bolt whose circle
## frees during its wait rising from its final star, the serial coming from the stage, and a late bolt joining the
## volley of the cast it was launched in, a constellation ward's flight, and a foe's view freed mid-blow. The volley
## itself is tested in constellation_volley_test.gd.

const LAUNCH := Vector2(120.0, 480.0)
const TARGET := Vector2(640.0, 300.0)
const MOVED := Vector2(700.0, 180.0)
const SLACK := Vector2(0.001, 0.001)
const FLIGHT_MS := 300.0
## Where the test stage stands, away from the origin: a point in global coordinates then differs from the same point in
## the effects layer, so a missing conversion fails.
const STAGE_AT := Vector2(300.0, 200.0)

var _instant := false


func before_test() -> void:
	_instant = BattleStage.instant
	BattleStage.instant = false


func after_test() -> void:
	BattleStage.instant = _instant


## A landing hit on `foe`, with the fields a program bolt carries.
func _hit(foe: String) -> Dictionary:
	return {"kind": "hit", "foe": foe, "role": "strike", "card": "salvo", "element": "fire", "amount": 9}


## The origin of a bolt with no circle: the global launch point, as a cast's origin_of gives it.
func _launch_origin() -> Callable:
	return LegendaryCast.new(0).origin_of(null, LAUNCH)


## A stage held by the test and freed after it, under a holder placed at STAGE_AT: the stage's effects layer, where a
## cast's volley and black hole are parented, then stands away from the origin.
func _stage() -> BattleStage:
	var holder: Node2D = auto_free(Node2D.new())
	holder.position = STAGE_AT
	add_child(holder)
	var stage := BattleStage.new()
	holder.add_child(stage)
	return stage


## A stage that plays its casts at once, with the Maintainer's worn skin, as the playback tests set one up.
func _fast_stage() -> BattleStage:
	var stage := _stage()
	stage.size = Vector2(1200, 700)
	stage.hero.set_preview_skin("vesper")
	stage.fast = true
	return stage


## The Wisp every test here aims at: "foe-a", 20 health, weak to fire.
func _wisp() -> Dictionary:
	return {
		"id": "tally-wisp",
		"uid": "foe-a",
		"name": "Wisp",
		"sprite": "tally-wisp",
		"hp": 20,
		"max": 20,
		"shield": 0,
		"intent_index": 0,
		"intents": [],
		"weak": ["fire"],
		"resist": [],
	}


## A stage wearing the orrery and the constellation bolt, with one foe, "foe-a", for a bolt to aim at.
func _legendary_stage() -> BattleStage:
	var stage := _stage()
	stage.size = Vector2(1200, 700)
	stage.hero.set_preview_skin("vesper")
	stage.hero.preview_loadout = {"circle": "legendary-orrery", "bolt": "legendary-constellation"}
	stage.set_foes([_wisp()], ContentLoader.load_shardrun().catalog)
	return stage


## A stage wearing an ordinary bolt, named so a saved legendary one cannot make it constellation. Its bolts fly by
## BattleStage.fly, with the Wisp standing as "foe-a".
func _plain_stage() -> BattleStage:
	var stage := _stage()
	stage.size = Vector2(1200, 700)
	stage.hero.set_preview_skin("vesper")
	stage.hero.set_preview_loadout({"bolt": "arcane-lance"})
	stage.set_foes([_wisp()], ContentLoader.load_shardrun().catalog)
	return stage


## The hit points "foe-a" shows on the numbers the log player keeps.
func _shown_hp(player: LogPlayer) -> int:
	var foe: Dictionary = player.shown.foes.get("foe-a", {})
	return int(foe.get("hp", -1))


func _cast_entry() -> Dictionary:
	return {"kind": "cast", "spell": "spell", "amount": 0}


func test_one_hole_opens_per_foe_per_cast() -> void:
	var cast := LegendaryCast.new(1)
	assert_bool(cast.opens_hole("foe-a", "hit", false)).is_true()
	assert_bool(cast.opens_hole("foe-a", "hit", false)).is_false()
	assert_bool(cast.opens_hole("foe-b", "hit", false)).is_true()
	assert_bool(cast.opens_hole("foe-b", "hit", false)).is_false()


func test_a_new_cast_opens_its_holes_again() -> void:
	var first := LegendaryCast.new(1)
	assert_bool(first.opens_hole("foe-a", "hit", false)).is_true()
	assert_bool(LegendaryCast.new(2).opens_hole("foe-a", "hit", false)).is_true()


func test_a_critical_does_not_open_the_hole_and_the_next_non_critical_does() -> void:
	var cast := LegendaryCast.new(1)
	assert_bool(cast.opens_hole("foe-a", "hit", true)).is_false()
	assert_bool(cast.opens_hole("foe-a", "hit", false)).is_true()
	assert_bool(cast.opens_hole("foe-a", "hit", false)).is_false()


func test_a_ward_never_opens_the_hole_and_does_not_use_up_the_foe() -> void:
	var cast := LegendaryCast.new(1)
	assert_bool(cast.opens_hole("foe-a", "ward", false)).is_false()
	assert_bool(cast.opens_hole("foe-a", "hit", false)).is_true()


func test_the_aim_holds_when_the_foe_moves() -> void:
	var cast := LegendaryCast.new(1)
	var spot := [TARGET]
	var reads := [0]
	var live := func() -> Vector2:
		reads[0] += 1
		return spot[0]
	assert_vector(cast.target_of("foe-a", live)).is_equal_approx(TARGET, SLACK)
	spot[0] = MOVED
	assert_vector(cast.target_of("foe-a", live)).is_equal_approx(TARGET, SLACK)
	# The foe's point was read once, at its first launch, and never again for this cast.
	assert_int(reads[0]).is_equal(1)
	assert_vector(cast.target_of("foe-b", live)).is_equal_approx(MOVED, SLACK)


func test_the_origin_falls_back_to_the_global_launch_point() -> void:
	var origin := LegendaryCast.new(1).origin_of(null, LAUNCH)
	assert_vector(origin.call()).is_equal_approx(LAUNCH, SLACK)
	assert_vector(origin.call()).is_equal_approx(LAUNCH, SLACK)


## A bolt waits behind a falling blow on its foe, and its circle frees itself during that wait. The bolt still rises
## from the orrery's final star it was launched from: that star is seeded at launch, and the freed circle is never read.
func test_a_bolt_whose_circle_frees_during_its_wait_rises_from_its_seeded_final_star() -> void:
	var stage := _legendary_stage()
	var circle := stage.magic_circle(CircleLayers.demo_cards(2), "fire")
	var player := LogPlayer.new(stage, {})
	player.set("_circle", circle)
	# No frame passes between this read and the launch, so the circle's clock is the same for both.
	var seeded := circle.final_node_global()
	# The seed is the orrery's last planet, not its centre: a planet orbits off the middle.
	assert_float(seeded.distance_to(circle.to_global(Vector2.ZERO))).is_greater(1.0)
	# The foe's falling blow is still playing, so the bolt waits for it, as a bolt behind a heavy cast's blow does.
	var falling: SpellAnim = stage.spell("hit-compile", Vector2.ZERO, "fire")
	var cast := player.get("_legendary") as LegendaryCast
	cast.crashed["foe-a"] = falling
	var hit := _hit("foe-a")
	player._launch(hit, FLIGHT_MS, [hit], 0)
	assert_bool(cast.volley == null).is_true()
	circle.queue_free()
	await stage.get_tree().process_frame
	assert_bool(is_instance_valid(circle)).is_false()
	var deadline := Time.get_ticks_msec() + 5000
	while cast.volley == null and Time.get_ticks_msec() < deadline:
		await stage.get_tree().process_frame
	var volley := cast.volley
	assert_object(volley).is_not_null()
	if volley == null:
		return
	volley.set_process(false)
	volley.advance(0.0)
	assert_vector(volley.to_global(volley.route_of(0)[0])).is_equal_approx(seeded, SLACK)


## The orrery turns while the cast's volley reads its final star, so that star is the cast's last read. A bolt that
## waits behind a falling blow, and whose circle frees during that wait, rises from that last read, not from the seed.
func test_a_circle_that_frees_during_the_wait_leaves_the_bolt_rising_from_its_final_star() -> void:
	var stage := _legendary_stage()
	var circle := stage.magic_circle(CircleLayers.demo_cards(2), "fire")
	var player := LogPlayer.new(stage, {})
	player.set("_circle", circle)
	var cast := player.get("_legendary") as LegendaryCast
	var seeded := circle.final_node_global()
	# The first bolt flies at once, so the cast's volley exists and reads the orrery while the circle stands.
	var first := _hit("foe-a")
	player._launch(first, FLIGHT_MS, [first], 0)
	var volley := cast.volley
	assert_object(volley).is_not_null()
	if volley == null:
		return
	volley.set_process(false)
	# The orrery turns, and the volley reads its final star: that star is the last one the cast read.
	circle.clock = 1.5
	volley.advance(0.0)
	var read := volley.to_global(volley.route_of(0)[0])
	assert_float(read.distance_to(seeded)).is_greater(1.0)
	# A falling blow holds the second bolt back, and the circle frees itself during that wait.
	var falling: SpellAnim = stage.spell("hit-compile", Vector2.ZERO, "fire")
	assert_object(falling).is_not_null()
	cast.crashed["foe-a"] = falling
	var second := _hit("foe-a")
	player._launch(second, FLIGHT_MS, [first, second], 1)
	assert_int((volley.get("_riders") as Array).size()).is_equal(1)
	circle.queue_free()
	var deadline := Time.get_ticks_msec() + 5000
	while (volley.get("_riders") as Array).size() < 2 and Time.get_ticks_msec() < deadline:
		await stage.get_tree().process_frame
	assert_bool(is_instance_valid(circle)).is_false()
	assert_int((volley.get("_riders") as Array).size()).is_equal(2)
	# The freed circle is not read again: the second bolt rises from the star the cast last read while the circle stood.
	volley.advance(0.0)
	assert_vector(volley.to_global(volley.route_of(1)[0])).is_equal_approx(read, SLACK)


## The cast's first volley has freed (as a volley does once its riders are done). Then a bolt waits behind a falling
## blow while its circle frees, and rides a new volley, which rises from the star the cast last read, not the centre.
func test_a_new_volley_after_its_circle_frees_rises_from_the_casts_last_star() -> void:
	var stage := _legendary_stage()
	var circle := stage.magic_circle(CircleLayers.demo_cards(2), "fire")
	var player := LogPlayer.new(stage, {})
	player.set("_circle", circle)
	var cast := player.get("_legendary") as LegendaryCast
	var seeded := circle.final_node_global()
	var first := _hit("foe-a")
	player._launch(first, FLIGHT_MS, [first], 0)
	var first_volley := cast.volley
	assert_object(first_volley).is_not_null()
	if first_volley == null:
		return
	first_volley.set_process(false)
	circle.clock = 1.5
	first_volley.advance(0.0)
	var read := first_volley.to_global(first_volley.route_of(0)[0])
	assert_float(read.distance_to(seeded)).is_greater(1.0)
	# A volley frees itself once its riders are done; here it is freed directly, its rider still in flight.
	first_volley.queue_free()
	assert_bool(first_volley.is_queued_for_deletion()).is_true()
	await stage.get_tree().process_frame
	assert_bool(is_instance_valid(first_volley)).is_false()
	# A bolt waits behind a falling blow, and its circle frees during that wait. Then it rides a new volley.
	var falling: SpellAnim = stage.spell("hit-compile", Vector2.ZERO, "fire")
	assert_object(falling).is_not_null()
	cast.crashed["foe-a"] = falling
	var second := _hit("foe-a")
	player._launch(second, FLIGHT_MS, [first, second], 1)
	circle.queue_free()
	var deadline := Time.get_ticks_msec() + 5000
	while not is_instance_valid(cast.volley) and Time.get_ticks_msec() < deadline:
		await stage.get_tree().process_frame
	assert_bool(is_instance_valid(circle)).is_false()
	assert_bool(is_instance_valid(cast.volley)).is_true()
	if not is_instance_valid(cast.volley):
		return
	var volley := cast.volley
	volley.set_process(false)
	volley.advance(0.0)
	assert_vector(volley.to_global(volley.route_of(0)[0])).is_equal_approx(read, SLACK)


func test_a_bolt_runs_from_its_global_launch_point_to_its_global_target() -> void:
	var stage := _stage()
	var cast := LegendaryCast.new(1)
	cast.ride(stage, _launch_origin(), TARGET, _hit("foe-a"), 0, FLIGHT_MS, Callable())
	var volley := cast.volley
	volley.set_process(false)
	volley.advance(0.0)
	# The effects layer stands at STAGE_AT, so the route is in the volley's own points. Taken back to global points, its
	# first point must be the launch and its last the target.
	var route := volley.route_of(0)
	assert_vector(volley.to_global(route[0])).is_equal_approx(LAUNCH, SLACK)
	assert_vector(volley.to_global(route[route.size() - 1])).is_equal_approx(TARGET, SLACK)


func test_a_late_rider_joins_the_volley_of_the_cast_it_was_launched_in() -> void:
	var stage := _stage()
	var first := LegendaryCast.new(1)
	first.ride(stage, _launch_origin(), TARGET, _hit("foe-a"), 0, FLIGHT_MS, Callable())
	var first_volley := first.volley
	first_volley.set_process(false)
	var second := LegendaryCast.new(2)
	first.close()
	second.ride(stage, _launch_origin(), TARGET, _hit("foe-a"), 0, FLIGHT_MS, Callable())
	first.ride(stage, _launch_origin(), TARGET, _hit("foe-b"), 1, FLIGHT_MS, Callable())
	# A zero step builds every rider's route without moving anything: the second bolt of the first cast has one.
	first_volley.advance(0.0)
	assert_bool(first.volley == first_volley).is_true()
	assert_bool(first_volley.route_of(1).size() > 0).is_true()
	assert_bool(second.volley == first_volley).is_false()
	second.volley.advance(0.0)
	assert_bool(second.volley.route_of(0).size() > 0).is_true()


func test_a_late_bolt_of_a_closed_cast_gets_a_volley_that_frees_itself_when_it_lands() -> void:
	var stage := _stage()
	var cast := LegendaryCast.new(1)
	cast.ride(stage, _launch_origin(), TARGET, _hit("foe-a"), 0, FLIGHT_MS, Callable())
	var done_volley := cast.volley
	done_volley.set_process(false)
	cast.close()
	# Long enough for every rider to land and fade: the closed volley frees itself.
	done_volley.advance(10.0)
	assert_bool(done_volley.is_queued_for_deletion()).is_true()
	cast.ride(stage, _launch_origin(), TARGET, _hit("foe-a"), 1, FLIGHT_MS, Callable())
	var late_volley := cast.volley
	assert_bool(late_volley == done_volley).is_false()
	assert_bool(late_volley.is_queued_for_deletion()).is_false()
	late_volley.set_process(false)
	late_volley.advance(10.0)
	assert_bool(late_volley.is_queued_for_deletion()).is_true()


func test_the_serial_comes_from_the_stage_so_two_log_players_differ() -> void:
	var stage := _fast_stage()
	var first := LogPlayer.new(stage, {})
	var second := LogPlayer.new(stage, {})
	await first.play([_cast_entry()])
	await second.play([_cast_entry()])
	assert_int((first.get("_legendary") as LegendaryCast).serial).is_equal(1)
	assert_int((second.get("_legendary") as LegendaryCast).serial).is_equal(2)


func test_a_point_converts_with_the_space_its_node_is_positioned_in() -> void:
	var space: Node2D = auto_free(Node2D.new())
	space.position = STAGE_AT
	add_child(space)
	var node := Node2D.new()
	node.position = Vector2(50.0, 0.0)
	space.add_child(node)
	# The point is in the node's parent's coordinates, so it converts with the parent's transform, not the node's own.
	var local := Vector2(10.0, 10.0)
	assert_vector(LegendaryCast.global_of(node, local)).is_equal_approx(STAGE_AT + local, SLACK)


func test_rider_look_carries_the_role_card_index_serial_and_power() -> void:
	var hit := {"kind": "hit", "role": "guard", "card": "memo-ward", "element": "frost", "amount": 4, "blocked": 2}
	var look := LegendaryCast.new(7).rider_look(hit, 3)
	assert_str(String(look.role)).is_equal("guard")
	assert_str(String(look.card)).is_equal("memo-ward")
	assert_int(int(look.index)).is_equal(3)
	assert_int(int(look.cast_serial)).is_equal(7)
	assert_float(float(look.power)).is_equal(6.0)


func test_power_is_damage_plus_the_shield_broken_plus_overkill() -> void:
	assert_float(LegendaryCast.power_of({"amount": 5, "blocked": 3, "overkill": 2})).is_equal(10.0)
	assert_float(LegendaryCast.power_of({})).is_equal(0.0)


func test_closing_a_cast_without_a_volley_does_nothing() -> void:
	var cast := LegendaryCast.new(1)
	cast.close()
	assert_bool(cast.volley == null).is_true()


## A constellation ward flies at 0.6 of the bolt's flight, as an ordinary ward does: 180 ms, not 300, so it lands
## 0.12 s before the bolt.
func test_a_constellation_ward_flies_at_six_tenths_of_the_bolts_flight() -> void:
	var stage := _legendary_stage()
	var player := LogPlayer.new(stage, {})
	var cast := player.get("_legendary") as LegendaryCast
	var ward := {"kind": "ward", "amount": 4, "role": "guard", "card": "memo-ward", "element": "frost"}
	var bolt := _hit("foe-a")
	player._launch(ward, FLIGHT_MS, [ward, bolt], 0)
	player._launch(bolt, FLIGHT_MS, [ward, bolt], 1)
	var volley := cast.volley
	assert_object(volley).is_not_null()
	if volley == null:
		return
	assert_float(volley.arrival_seconds(1) - volley.arrival_seconds(0)).is_equal_approx(0.12, 0.001)


## The foe's view frees while a falling blow holds its bolt back (a new fight frees every foe view). The bolt still
## lands its damage on the numbers, flying on the points it launched with; nothing reads the freed view.
func test_a_bolt_whose_foe_view_frees_during_a_falling_blow_still_lands() -> void:
	var stage := _plain_stage()
	var view: FoeView = stage.foes.get("foe-a")
	var state := {"integrity": 30, "integrity_max": 30, "battle": {"block": 0, "mana": 3, "foes": [_wisp()]}}
	var player := LogPlayer.new(stage, state)
	var cast := player.get("_legendary") as LegendaryCast
	var falling: SpellAnim = stage.spell("hit-compile", Vector2.ZERO, "fire")
	assert_object(falling).is_not_null()
	if falling == null:
		return
	cast.crashed["foe-a"] = falling
	var hit := _hit("foe-a")
	player._launch(hit, FLIGHT_MS, [hit], 0)
	stage.set_foes([], ContentLoader.load_shardrun().catalog)
	var deadline := Time.get_ticks_msec() + 5000
	while _shown_hp(player) == 20 and Time.get_ticks_msec() < deadline:
		await stage.get_tree().process_frame
	assert_bool(is_instance_valid(view)).is_false()
	assert_int(_shown_hp(player)).is_equal(11)
