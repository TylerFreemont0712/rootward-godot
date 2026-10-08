extends GdUnitTestSuite
## The constellation volley (docs/LEGENDARY_LOOKS.md, "The constellation bolt: a volley of riders"): each
## bolt lands once, the origin is read once a frame, each star flares once in flight, a convergence bloom
## comes once per target after its last bolt, the volley frees itself once it is closed and its riders are
## done, a bolt joins while the volley lives, the bolts of one cast fly different routes, the flight is clamped,
## and a diamond under half a pixel across is not drawn. Reduced motion draws no origin burst, spark, bloom, ignition
## ring or flare ring, keeps a flare's glint, and holds a prism bolt's palette still, counted through last_draw (the
## draw calls of a draw pass); a change made mid-cast takes effect at once. The volley draws above the black hole
## (z_index 2). The volley sits under
## a parent at an offset and takes global positions, so a missing conversion fails: the head ends on the global
## target, a moving parent still aims right, the head is hidden through the trace, and time_scale sets the clock's
## pace. Each test stops the volley's own clock (set_process(false)) and steps it by hand with a fixed delta through
## `advance`, which `_process` calls every frame; the time_scale tests call `_process` themselves.

const DT := 1.0 / 60.0
const ORIGIN := Vector2(300.0, 120.0)
const TARGET := Vector2(640.0, 420.0)
const OTHER := Vector2(860.0, 260.0)
## Where the volley's parent sits: an offset, so a point given in the wrong space fails a test.
const PARENT_AT := Vector2(220.0, 90.0)
const ELEMENT := Color("#88ccff")
## A volley is done within a few seconds, so a run still going at this point has failed.
const MAX_SECONDS := 6.0
const SLACK := Vector2(0.001, 0.001)
const TIME_SLACK := 0.0001

var _saved_reduced := false
var _origin_point := ORIGIN
var _origin_calls := 0
## Landings per bolt, by the index the bolt was added at.
var _arrivals := PackedInt32Array()
## Seconds the volley has been stepped by this test, counted from its first step.
var _clock := 0.0


func before_test() -> void:
	_saved_reduced = Settings.reduced_motion
	Settings.reduced_motion = false
	_origin_point = ORIGIN
	_origin_calls = 0
	_arrivals = PackedInt32Array()
	_clock = 0.0


func after_test() -> void:
	Settings.reduced_motion = _saved_reduced


## The stub origin: counts its calls and returns the point the test set.
func _stub_origin() -> Vector2:
	_origin_calls += 1
	return _origin_point


## The stub landing: counts the landings of the bolt added at this index.
func _on_arrive(index: int) -> void:
	_arrivals[index] += 1


## A volley under its own parent at PARENT_AT, with its clock stopped and the stub origin.
func _volley() -> ConstellationVolley:
	var parent: Node2D = auto_free(Node2D.new())
	parent.position = PARENT_AT
	add_child(parent)
	var volley := ConstellationVolley.start(parent, Callable(self, "_stub_origin"))
	volley.set_process(false)
	return volley


## Adds a strike bolt aimed at `target`, whose landing counts under `index`, the order it was added in.
func _add(
	volley: ConstellationVolley, target: Vector2, index: int, ms: float, card: String = "", power: float = 0.0
) -> void:
	_arrivals.resize(maxi(_arrivals.size(), index + 1))
	var look := {
		"role": "strike",
		"card": card,
		"index": index,
		"cast_serial": 7,
		"element_colour": ELEMENT,
		"power": power,
	}
	volley.add_rider(target, look, ms, Callable(self, "_on_arrive").bind(index))


## One frame of the volley's clock.
func _frame(volley: ConstellationVolley) -> void:
	volley.advance(DT)
	_clock += DT


## Steps the volley until its clock reads `seconds`, or it frees itself first.
func _step_to(volley: ConstellationVolley, seconds: float) -> void:
	while not volley.is_queued_for_deletion() and _clock < seconds - TIME_SLACK:
		_frame(volley)


## Steps the volley until it frees itself, or MAX_SECONDS pass. Returns the clock at the frame it freed.
func _run(volley: ConstellationVolley) -> float:
	while not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		_frame(volley)
	return _clock


func _landed() -> int:
	var total := 0
	for count: int in _arrivals:
		total += count
	return total


## How many of the bolts from index `first` on, `count` of them, have landed.
func _landed_from(first: int, count: int) -> int:
	var total := 0
	for index: int in range(first, first + count):
		total += _arrivals[index]
	return total


func _flared(volley: ConstellationVolley, index: int) -> int:
	var total := 0
	for count: int in volley.flare_counts(index):
		total += count
	return total


## A bolt's route in global points, which is how the contract passes positions. The volley's own route is local.
func _global_route(volley: ConstellationVolley, index: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point: Vector2 in volley.route_of(index):
		points.append(volley.to_global(point))
	return points


func test_each_bolt_lands_exactly_once() -> void:
	var volley := _volley()
	for k: int in 3:
		_add(volley, TARGET, k, 500.0 + 150.0 * k)
	volley.close()
	_run(volley)
	assert_bool(volley.is_queued_for_deletion()).is_true()
	assert_int(_landed()).is_equal(3)
	for k: int in 3:
		assert_int(_arrivals[k]).is_equal(1)


func test_the_origin_is_read_once_per_frame() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0)
	volley.close()
	var frames := 0
	while not volley.is_queued_for_deletion() and frames < 1000:
		var before := _origin_calls
		volley.advance(DT)
		frames += 1
		assert_int(_origin_calls - before).is_equal(1)
	assert_int(frames).is_greater(1)
	assert_int(_origin_calls).is_equal(frames)


func test_the_routes_turn_with_the_origin() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 900.0)
	volley.advance(DT)
	assert_vector(_global_route(volley, 0)[0]).is_equal_approx(ORIGIN, SLACK)
	_origin_point = Vector2(180.0, 300.0)
	volley.advance(DT)
	assert_vector(_global_route(volley, 0)[0]).is_equal_approx(Vector2(180.0, 300.0), SLACK)
	var route := _global_route(volley, 0)
	assert_vector(route[route.size() - 1]).is_equal_approx(TARGET, SLACK)


## A parent that moves during a flight still aims the bolt at the global target, because each frame converts it again.
func test_a_moving_parent_still_aims_at_the_global_target() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 900.0)
	volley.advance(DT)
	var parent := volley.get_parent() as Node2D
	parent.position = Vector2(-120.0, 260.0)
	volley.advance(DT)
	var route := _global_route(volley, 0)
	assert_vector(route[0]).is_equal_approx(ORIGIN, SLACK)
	assert_vector(route[route.size() - 1]).is_equal_approx(TARGET, SLACK)


## The head flies from the origin and ends on the target, a global point, under a parent at an offset.
func test_the_head_ends_on_the_global_target() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 400.0)
	# The offset is real: the target's point in the volley's own space is not the global one.
	assert_bool(volley.to_local(TARGET).is_equal_approx(TARGET)).is_false()
	_step_to(volley, volley.arrival_seconds(0) + 0.01)
	assert_int(_landed()).is_equal(1)
	assert_vector(volley.to_global(volley.head_point(0))).is_equal_approx(TARGET, SLACK)


## The head is hidden through the trace and waits at the origin: the pen ends the trace at the foe, but the head does
## not come out there, so the flight starts from the origin.
func test_the_head_is_hidden_during_the_trace_and_starts_at_the_origin() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0)
	for _tick: int in 19:
		_frame(volley)
		assert_bool(volley.head_shown(0)).is_false()
		assert_vector(volley.to_global(volley.head_point(0))).is_equal_approx(ORIGIN, SLACK)
	# Nineteen frames are 0.317 s, short of the 0.32 s trace. A millisecond past its end the flight has begun, and the head
	# is still near the origin, well short of the foe.
	volley.advance(ConstellationVolley.TRACE_SECONDS - 19.0 * DT + 0.001)
	assert_bool(volley.head_shown(0)).is_true()
	assert_float(volley.to_global(volley.head_point(0)).distance_to(ORIGIN)).is_less(ORIGIN.distance_to(TARGET) * 0.05)


func test_each_star_flares_once_during_the_flight() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 700.0, "radix-sort")
	volley.close()
	# A signature card hits five stars.
	assert_int(volley.flare_counts(0).size()).is_equal(5)
	while not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		_frame(volley)
		if _clock < ConstellationVolley.TRACE_SECONDS - 0.05:
			assert_int(_flared(volley, 0)).is_equal(0)
		for count: int in volley.flare_counts(0):
			assert_int(count).is_less_equal(1)
	for count: int in volley.flare_counts(0):
		assert_int(count).is_equal(1)


func test_one_convergence_bloom_per_target_after_its_last_bolt_lands() -> void:
	var volley := _volley()
	for k: int in 3:
		_add(volley, TARGET, k, 350.0 + 200.0 * k)
	volley.close()
	var blooms := 0
	while not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		var before := volley.bloom_targets().size()
		_frame(volley)
		if volley.bloom_targets().size() > before:
			blooms += 1
			# The bloom comes in the frame of the last landing, so all three have landed by then.
			assert_int(_landed()).is_equal(3)
	assert_int(blooms).is_equal(1)


func test_each_target_blooms_once_after_its_own_bolts_land() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	_add(volley, TARGET, 1, 600.0)
	_add(volley, OTHER, 2, 400.0)
	_add(volley, OTHER, 3, 900.0)
	_add(volley, OTHER, 4, 500.0)
	volley.close()
	var seen := 0
	while not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		var before := volley.bloom_targets().size()
		_frame(volley)
		var targets := volley.bloom_targets()
		for k: int in range(before, targets.size()):
			seen += 1
			# The target's own bolts have all landed when its bloom comes: two at TARGET, three at OTHER.
			if targets[k].is_equal_approx(TARGET):
				assert_int(_landed_from(0, 2)).is_equal(2)
			else:
				assert_int(_landed_from(2, 3)).is_equal(3)
	assert_int(seen).is_equal(2)


func test_bolts_aimed_a_few_pixels_apart_share_one_bloom() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	_add(volley, TARGET + Vector2(1.5, -1.0), 1, 350.0)
	volley.close()
	_run(volley)
	assert_int(volley.bloom_targets().size()).is_equal(1)


## The volley is closed only when the next cast starts, so once its only bolt is done it must still be there.
func test_an_open_volley_stays_up_once_its_riders_are_done() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	_step_to(volley, volley.done_seconds(0) + 1.0)
	assert_int(_arrivals[0]).is_equal(1)
	assert_bool(volley.is_queued_for_deletion()).is_false()
	volley.close()
	_frame(volley)
	assert_bool(volley.is_queued_for_deletion()).is_true()


func test_the_volley_frees_itself_once_closed_and_every_rider_is_done() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	_add(volley, OTHER, 1, 1200.0)
	volley.close()
	var latest := maxf(volley.done_seconds(0), volley.done_seconds(1))
	var freed_at := _run(volley)
	assert_bool(volley.is_queued_for_deletion()).is_true()
	assert_int(_arrivals[0]).is_equal(1)
	assert_int(_arrivals[1]).is_equal(1)
	# It frees on the first frame after the last rider is done: not before, and promptly after.
	assert_float(freed_at).is_greater_equal(latest - TIME_SLACK)
	assert_float(freed_at).is_less(latest + 2.0 * DT)


## A rider is done once its longest fade has ended: the traced line 0.6 s after the head passes the target, or the
## last star 0.8 s after the head passes it, whichever is later.
func test_a_rider_is_done_after_its_longest_fade() -> void:
	var volley := _volley()
	# A 140 ms bolt flies 0.14 s (above the 0.12 s floor): its last star outlasts the traced line.
	_add(volley, TARGET, 0, 140.0)
	# A 1400 ms bolt: its traced line outlasts its last star.
	_add(volley, TARGET, 1, 1400.0)
	var stars := volley.flare_counts(0).size()
	var last_star := ConstellationVolley.TRACE_SECONDS + 0.14 * float(stars) / float(stars + 1)
	var star_done := last_star + ConstellationVolley.STAR_KEEP_SECONDS
	assert_float(volley.done_seconds(0)).is_equal_approx(star_done, TIME_SLACK)
	var line_done := volley.arrival_seconds(1) + ConstellationVolley.LINE_FADE_SECONDS
	assert_float(volley.done_seconds(1)).is_equal_approx(line_done, TIME_SLACK)


## A bolt added while the volley is open joins it, even after the bolts before it are done. The volley waits for it.
func test_a_late_rider_joins_an_open_volley() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	_step_to(volley, volley.done_seconds(0) + 0.5)
	assert_bool(volley.is_queued_for_deletion()).is_false()
	_add(volley, OTHER, 1, 900.0)
	# It flies rather than landing at once, and the open volley does not free itself.
	assert_int(_arrivals[1]).is_equal(0)
	volley.advance(DT)
	assert_int(volley.route_of(1).size()).is_greater(1)
	assert_bool(volley.is_queued_for_deletion()).is_false()
	volley.close()
	_run(volley)
	assert_bool(volley.is_queued_for_deletion()).is_true()
	assert_int(_arrivals[1]).is_equal(1)
	assert_int(_landed()).is_equal(2)


## A bolt added after close still joins while the volley is alive, so the volley waits for it.
func test_a_rider_added_after_close_joins_while_the_volley_is_live() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 1400.0)
	volley.close()
	_add(volley, OTHER, 1, 300.0)
	assert_int(_arrivals[1]).is_equal(0)
	var freed_at := _run(volley)
	assert_bool(volley.is_queued_for_deletion()).is_true()
	assert_int(_arrivals[0]).is_equal(1)
	assert_int(_arrivals[1]).is_equal(1)
	# The longer bolt decides when the volley frees: not before it is done.
	assert_float(freed_at).is_greater_equal(volley.done_seconds(0) - TIME_SLACK)


## A target blooms once per volley: a bolt that lands on it later, while the volley is open, does not bloom it again.
func test_a_late_bolt_at_a_bloomed_target_does_not_bloom_it_again() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	_step_to(volley, 1.0)
	assert_int(volley.bloom_targets().size()).is_equal(1)
	_add(volley, TARGET, 1, 350.0)
	_step_to(volley, 3.0)
	assert_int(_arrivals[1]).is_equal(1)
	assert_int(volley.bloom_targets().size()).is_equal(1)
	volley.close()
	_run(volley)
	assert_int(volley.bloom_targets().size()).is_equal(1)


func test_two_bolts_of_one_cast_fly_different_routes() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort")
	_add(volley, TARGET, 1, 600.0, "radix-sort")
	volley.advance(DT)
	assert_bool(volley.route_of(0) == volley.route_of(1)).is_false()
	for index: int in 2:
		var route := _global_route(volley, index)
		assert_vector(route[route.size() - 1]).is_equal_approx(TARGET, SLACK)


func test_every_bolt_of_a_cast_has_its_own_route() -> void:
	var volley := _volley()
	for k: int in 8:
		_add(volley, TARGET, k, 600.0)
	volley.advance(DT)
	for a: int in 8:
		for b: int in range(a + 1, 8):
			assert_bool(volley.route_of(a) == volley.route_of(b)).is_false()


func test_reduced_motion_adds_no_sparks_and_no_bloom() -> void:
	Settings.reduced_motion = true
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 1, 600.0, "radix-sort", 12.0)
	volley.close()
	# The trace is the reduced 0.12 s; the flight and the landing stay.
	assert_float(volley.arrival_seconds(0)).is_equal_approx(ConstellationVolley.TRACE_REDUCED_SECONDS + 0.6, TIME_SLACK)
	while not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		_frame(volley)
		assert_int(volley.spark_count()).is_equal(0)
	assert_int(volley.bloom_targets().size()).is_equal(0)
	assert_int(_landed()).is_equal(2)


func test_full_motion_adds_sparks_and_one_bloom() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort")
	_add(volley, TARGET, 1, 600.0, "radix-sort")
	volley.close()
	var most_sparks := 0
	while not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		_frame(volley)
		most_sparks = maxi(most_sparks, volley.spark_count())
	assert_int(most_sparks).is_greater(0)
	assert_int(volley.bloom_targets().size()).is_equal(1)


## The flight is `ms / 1000` seconds, held between 0.12 and 1.4. The 140 ms bolt is above the floor, so it flies 0.14 s.
func test_the_flight_is_clamped_to_0_12_and_1_4_seconds() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 50.0)
	_add(volley, TARGET, 1, 140.0)
	_add(volley, TARGET, 2, 380.0)
	_add(volley, TARGET, 3, 2000.0)
	var trace := ConstellationVolley.TRACE_SECONDS
	assert_float(volley.arrival_seconds(0)).is_equal_approx(trace + 0.12, TIME_SLACK)
	assert_float(volley.arrival_seconds(1)).is_equal_approx(trace + 0.14, TIME_SLACK)
	assert_float(volley.arrival_seconds(2)).is_equal_approx(trace + 0.38, TIME_SLACK)
	assert_float(volley.arrival_seconds(3)).is_equal_approx(trace + 1.4, TIME_SLACK)


func test_the_glow_is_an_additive_material() -> void:
	var volley := _volley()
	var glow := volley.material as CanvasItemMaterial
	assert_object(glow).is_not_null()
	if glow != null:
		assert_int(glow.blend_mode).is_equal(CanvasItemMaterial.BLEND_MODE_ADD)


func test_a_bolt_added_after_the_volley_freed_itself_lands_at_once() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	volley.close()
	_run(volley)
	assert_bool(volley.is_queued_for_deletion()).is_true()
	_add(volley, TARGET, 1, 350.0)
	assert_int(_arrivals[1]).is_equal(1)


## A diamond under half a pixel across is not drawn: a near-zero polygon fails to triangulate.
func test_a_diamond_under_half_a_pixel_across_is_not_drawn() -> void:
	assert_bool(ConstellationVolley.diamond_is_drawn(0.0)).is_false()
	assert_bool(ConstellationVolley.diamond_is_drawn(0.1)).is_false()
	assert_bool(ConstellationVolley.diamond_is_drawn(0.2499)).is_false()
	assert_bool(ConstellationVolley.diamond_is_drawn(0.25)).is_true()
	assert_bool(ConstellationVolley.diamond_is_drawn(ConstellationVolley.STAR_RADIUS)).is_true()


## Just after a star ignites its diamond is near zero. The volley draws that frame without failing, and the star has
## not flared yet.
func test_a_star_drawn_just_after_it_ignites_is_drawn_without_error() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 700.0, "radix-sort")
	volley.close()
	# Star 1 of five ignites at trace / 6 (the pen reaches it at p = 1 / 6).
	volley.advance(ConstellationVolley.TRACE_SECONDS / 6.0 + 0.0005)
	await await_idle_frame()
	assert_bool(volley.is_queued_for_deletion()).is_false()
	assert_int(_flared(volley, 0)).is_equal(0)


## The drawing runs in the engine's draw pass, not in `advance`. This test lets a frame pass after each step, so the
## volley is drawn from its first frame to its last. A script error in the drawing would show in the log.
func test_the_volley_draws_through_its_whole_life() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 700.0, "radix-sort", 12.0)
	_add(volley, OTHER, 1, 500.0, "strike")
	volley.close()
	var frames := 0
	while is_instance_valid(volley) and not volley.is_queued_for_deletion() and frames < 400:
		volley.advance(DT)
		await await_idle_frame()
		frames += 1
	assert_int(frames).is_greater(10)
	assert_int(_landed()).is_equal(2)
	assert_int(_arrivals[1]).is_equal(1)


## At time_scale 0 the volley stands still: frames pass, and nothing lands, flares or frees itself. At 1 it flies on.
func test_time_scale_zero_freezes_the_volley() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 350.0)
	volley.close()
	volley.time_scale = 0.0
	for _tick: int in 600:
		volley._process(DT)
	assert_bool(volley.is_queued_for_deletion()).is_false()
	assert_int(_landed()).is_equal(0)
	assert_int(_flared(volley, 0)).is_equal(0)
	assert_bool(volley.head_shown(0)).is_false()
	volley.time_scale = 1.0
	for _tick: int in 600:
		volley._process(DT)
		if volley.is_queued_for_deletion():
			break
	assert_bool(volley.is_queued_for_deletion()).is_true()
	assert_int(_landed()).is_equal(1)


## The clock runs at time_scale: ten frames at 2 pass the 0.32 s trace, and ten frames at 1 do not.
func test_time_scale_multiplies_the_clock() -> void:
	var fast := _volley()
	fast.time_scale = 2.0
	_add(fast, TARGET, 0, 600.0)
	var normal := _volley()
	_add(normal, TARGET, 1, 600.0)
	for _tick: int in 10:
		fast._process(DT)
		normal._process(DT)
	assert_bool(fast.head_shown(0)).is_true()
	assert_bool(normal.head_shown(0)).is_false()


## Steps the volley one frame, lets its draw pass run, and adds the draw calls that pass made to `totals`. A kind that
## stays at zero in `totals` was never drawn over the volley's whole life.
func _drawn_frame(volley: ConstellationVolley, totals: Dictionary) -> void:
	_frame(volley)
	await await_idle_frame()
	if is_instance_valid(volley) and not volley.is_queued_for_deletion():
		var now := volley.last_draw()
		for kind: String in now:
			totals[kind] = int(totals.get(kind, 0)) + int(now[kind])


## The volley draws above the black hole: its z_index is 2, and the hole's is 1 (docs/LEGENDARY_LOOKS.md, Coordinates).
func test_the_volley_draws_above_the_black_hole() -> void:
	var volley := _volley()
	assert_int(volley.z_index).is_equal(2)
	assert_int(volley.z_index).is_equal(ConstellationVolley.Z_INDEX)
	assert_int(volley.z_index).is_greater(1)


## Under reduced motion a whole cast draws no origin burst, no spark and no bloom, even where a foe takes three bolts.
## The flights are still drawn, and so is each flare's glint. The rings are checked by the next test.
func test_reduced_motion_draws_no_origin_burst_spark_or_bloom() -> void:
	Settings.reduced_motion = true
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 1, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 2, 500.0, "strike", 12.0)
	volley.close()
	var totals := {}
	while is_instance_valid(volley) and not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		await _drawn_frame(volley, totals)
	for kind: String in ["origin ring", "origin spark", "bloom ring", "bloom spark", "flare spark"]:
		assert_int(int(totals.get(kind, 0))).is_equal(0)
	assert_int(int(totals.get("flare glint", 0))).is_greater(0)
	assert_int(int(totals.get("line", 0))).is_greater(0)
	assert_int(_landed()).is_equal(3)


## Under reduced motion no ignition draws its ring, and no flare draws its ring or its sparks. The same cast still draws
## each star's white flash and each flare's glint, so the draw pass ran and the zeros are real.
func test_reduced_motion_draws_no_ignition_or_flare_ring_or_spark() -> void:
	Settings.reduced_motion = true
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 1, 600.0, "radix-sort", 12.0)
	volley.close()
	var totals := {}
	while is_instance_valid(volley) and not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		await _drawn_frame(volley, totals)
	for kind: String in ["ignite ring", "flare ring", "flare spark"]:
		assert_int(int(totals.get(kind, 0))).is_equal(0)
	assert_int(int(totals.get("ignite", 0))).is_greater(0)
	assert_int(int(totals.get("flare glint", 0))).is_greater(0)


## The same cast at full motion draws origin bursts with their sparks, and a bloom: the reduced counts above are real.
func test_full_motion_draws_origin_bursts_sparks_and_a_bloom() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 1, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 2, 500.0, "strike", 12.0)
	volley.close()
	var totals := {}
	while is_instance_valid(volley) and not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		await _drawn_frame(volley, totals)
	assert_int(int(totals.get("origin ring", 0))).is_greater(0)
	assert_int(int(totals.get("origin spark", 0))).is_greater(0)
	assert_int(int(totals.get("bloom ring", 0))).is_greater(0)
	assert_int(int(totals.get("bloom spark", 0))).is_greater(0)


## At full motion the same kind of cast draws each star's ignition ring, and each flare's ring and sparks.
func test_full_motion_draws_ignition_and_flare_rings_and_sparks() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 1, 600.0, "radix-sort", 12.0)
	volley.close()
	var totals := {}
	while is_instance_valid(volley) and not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		await _drawn_frame(volley, totals)
	for kind: String in ["ignite ring", "flare ring", "flare spark"]:
		assert_int(int(totals.get(kind, 0))).is_greater(0)


## Reduced motion turned on mid-cast takes effect at once: the origin bursts already drawn at full motion are not drawn
## again, and no spark, bloom or ring is drawn after the change, even though the bolts were added at full motion.
func test_turning_reduced_motion_on_mid_cast_stops_the_sparks_and_bloom() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 600.0, "radix-sort", 12.0)
	_add(volley, TARGET, 1, 600.0, "radix-sort", 12.0)
	volley.close()
	var before := {}
	await _drawn_frame(volley, before)
	await _drawn_frame(volley, before)
	assert_int(int(before.get("origin spark", 0))).is_greater(0)
	Settings.reduced_motion = true
	var after := {}
	while is_instance_valid(volley) and not volley.is_queued_for_deletion() and _clock < MAX_SECONDS:
		await _drawn_frame(volley, after)
	var gone: Array[String] = [
		"origin ring", "origin spark", "bloom ring", "bloom spark", "flare spark", "ignite ring", "flare ring"
	]
	for kind: String in gone:
		assert_int(int(after.get(kind, 0))).is_equal(0)
	assert_int(_landed()).is_equal(2)


## A prism bolt's palette turns with time at full motion.
func test_a_prism_bolt_cycles_its_palette_at_full_motion() -> void:
	var volley := _volley()
	_add(volley, TARGET, 0, 900.0, "radix-sort")
	var early := volley.rider_colour(0, 0.5)
	volley.advance(0.6)
	assert_bool(volley.rider_colour(0, 0.5).is_equal_approx(early)).is_false()


## Under reduced motion a prism bolt holds its palette still: its colours turn along the route, not with time.
func test_reduced_motion_holds_a_prism_bolt_still() -> void:
	Settings.reduced_motion = true
	var volley := _volley()
	_add(volley, TARGET, 0, 900.0, "radix-sort")
	var early := volley.rider_colour(0, 0.5)
	volley.advance(0.6)
	assert_bool(volley.rider_colour(0, 0.5).is_equal_approx(early)).is_true()
