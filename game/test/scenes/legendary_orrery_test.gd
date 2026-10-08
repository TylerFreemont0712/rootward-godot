extends GdUnitTestSuite
## The orrery (docs/LEGENDARY_LOOKS.md): it draws for one to six shards and for every role, it has one planet per shard
## carrying its card's role, its links join a planet only once that planet has arrived and flare, then settle to their
## steady light, and reduced motion draws no sweep, no flare and no arrival ring, and holds the orbits still.
## Its last planet is the bolts' origin: final_node is where draw puts that planet, and MagicCircle.final_node_global
## follows the orbit and the close's swell.


## Draws the orrery from its own _draw, as MagicCircle does, and keeps how many strokes that frame issued.
class OrreryHost:
	extends Node2D
	var circle: MagicCircle
	var commands := -1

	func _draw() -> void:
		var pen := LegendaryOrrery.Pen.new(self)
		LegendaryOrrery.paint(pen, circle, 110.0, 1.0)
		commands = pen.commands


## A Pen that also keeps the colour of every segment it strokes, in order (a link is two: its halo, then its core).
class SegmentPen:
	extends LegendaryOrrery.Pen
	var colours: Array[Color] = []

	func segment(start: Vector2, finish: Vector2, width: float, colour: Color) -> void:
		colours.append(colour)
		super.segment(start, finish, width, colour)


## Draws the orrery from its own _draw and keeps the colours of its segments.
class SegmentHost:
	extends Node2D
	var circle: MagicCircle
	var colours: Array[Color] = []

	func _draw() -> void:
		var pen := SegmentPen.new(self)
		LegendaryOrrery.paint(pen, circle, 110.0, 1.0)
		colours = pen.colours


## A Pen that keeps the centre of every disc it fills, in order: each planet's body is one of them.
class CentrePen:
	extends LegendaryOrrery.Pen
	var centres: Array[Vector2] = []

	func disc(at: Vector2, radius: float, colour: Color) -> void:
		centres.append(at)
		super.disc(at, radius, colour)


## Draws the orrery from its own _draw and keeps the centres of its discs.
class CentreHost:
	extends Node2D
	var circle: MagicCircle
	var centres: Array[Vector2] = []

	func _draw() -> void:
		var pen := CentrePen.new(self)
		LegendaryOrrery.paint(pen, circle, 110.0, 1.0)
		centres = pen.centres


var _saved_reduced := false


func before_test() -> void:
	_saved_reduced = Settings.reduced_motion


func after_test() -> void:
	Settings.reduced_motion = _saved_reduced


## The roles of a spell of `count` shards, cycling through the seven.
func _roles(count: int) -> Array[String]:
	var roles: Array[String] = []
	for index in count:
		roles.append(String(ProgramSchemas.ROLES[index % ProgramSchemas.ROLES.size()]))
	return roles


## A circle of the orrery style with one layer per role, each layer carrying its card's role. The layers come from
## CircleLayers.plan, so their kinds and roles are the real ones (nothing is copied in after it). Its clock is set by
## hand (the process is off).
func _circle(roles: Array[String], reduced := false) -> MagicCircle:
	Settings.reduced_motion = reduced
	var cards: Array[Dictionary] = []
	for index in roles.size():
		cards.append({"id": "card-%d" % index, "name": "Card %d" % index, "role": roles[index]})
	var circle: MagicCircle = auto_free(
		MagicCircle.cast(self, Vector2(400, 300), CircleLayers.tier_for(roles.size()), "none", 110.0, "", 1.0, true)
	)
	circle.style = "orrery"
	circle.external_construction = true
	circle.use_plan(CircleLayers.plan(cards))
	circle.set_process(false)
	return circle


## The first `count` shards arrive by the circle's own construction, a tenth of a second apart.
func _arrive(circle: MagicCircle, count: int) -> void:
	for index in count:
		circle.clock = 0.1 * (index + 1)
		circle.construct_shard(index)


## Shards arrive by their calls, as a program's walkthrough brings them: each with the share of its call run so far.
func _walk(circle: MagicCircle, shares: Array[float]) -> void:
	for index in shares.size():
		circle.clock = 0.1 * (index + 1)
		circle.trace_shard(index, shares[index])


func _host(circle: MagicCircle) -> OrreryHost:
	var host: OrreryHost = auto_free(OrreryHost.new())
	host.circle = circle
	add_child(host)
	host.queue_redraw()
	return host


## The strokes one frame of a walked circle draws, counted from the orrery's own _draw.
func _draw_count(reduced: bool, shares: Array[float]) -> int:
	var circle := _circle(_roles(shares.size()), reduced)
	_walk(circle, shares)
	var host := _host(circle)
	await get_tree().process_frame
	await get_tree().process_frame
	return host.commands


func test_one_planet_per_shard_for_one_to_six_shards() -> void:
	for count in range(1, 7):
		var roles := _roles(count)
		var circle := _circle(roles)
		var planets := LegendaryOrrery.build_planets(circle)
		assert_int(planets.size()).is_equal(count)
		for index in count:
			assert_int(planets[index].index).is_equal(index)
			assert_str(planets[index].role).is_equal(roles[index])
			assert_float(planets[index].arrived_at).is_equal(-1.0)
		_arrive(circle, count)
		planets = LegendaryOrrery.build_planets(circle)
		assert_int(planets.size()).is_equal(count)
		for planet: LegendaryOrrery.Planet in planets:
			assert_float(planet.arrived_at).is_greater_equal(0.0)


func test_links_join_a_planet_only_once_it_has_arrived() -> void:
	var circle := _circle(_roles(4))
	assert_array(LegendaryOrrery.link_pairs(LegendaryOrrery.build_planets(circle))).is_empty()
	for index in 4:
		circle.clock = 0.1 * (index + 1)
		circle.construct_shard(index)
		var pairs := LegendaryOrrery.link_pairs(LegendaryOrrery.build_planets(circle))
		assert_int(pairs.size()).is_equal(index)
		for pair: Vector2i in pairs:
			assert_int(pair.x).is_equal(pair.y - 1)
			assert_int(pair.y).is_less_equal(index)


func test_a_call_in_progress_is_the_newest_calling_planet() -> void:
	var circle := _circle(_roles(3))
	var shares: Array[float] = [0.2, 1.0, 0.6]
	_walk(circle, shares)
	var planets := LegendaryOrrery.build_planets(circle)
	# An earlier shard, whether its walkthrough stopped short or finished, is not still calling: only the newest can be.
	assert_bool(planets[0].calling).is_false()
	assert_bool(planets[1].calling).is_false()
	assert_bool(planets[2].calling).is_true()


func test_a_running_call_sweeps_unless_reduced_motion_is_on() -> void:
	var shares: Array[float] = [1.0, 0.5]
	var calm := _circle(_roles(2), false)
	_walk(calm, shares)
	assert_bool(LegendaryOrrery.build_planets(calm)[1].calling).is_true()
	assert_float(LegendaryOrrery.sweep_angle(calm)).is_greater_equal(0.0)
	var still := _circle(_roles(2), true)
	_walk(still, shares)
	assert_bool(LegendaryOrrery.build_planets(still)[1].calling).is_true()
	assert_float(LegendaryOrrery.sweep_angle(still)).is_equal(-1.0)


func test_reduced_motion_draws_the_calling_glow_but_no_sweep() -> void:
	var calling: Array[float] = [1.0, 0.5]
	var done: Array[float] = [1.0, 1.0]
	var sweep_cost: int = (await _draw_count(false, calling)) - (await _draw_count(false, done))
	var still_cost: int = (await _draw_count(true, calling)) - (await _draw_count(true, done))
	# The calling planet's glow is drawn either way; the sweep's trail and ray are drawn only without reduced motion.
	assert_int(still_cost).is_equal(1)
	assert_int(sweep_cost).is_greater(still_cost)


func test_reduced_motion_holds_the_orbits_and_planets_still() -> void:
	var still := _circle(_roles(4), true)
	_arrive(still, 4)
	still.clock = 0.4
	var first := LegendaryOrrery.build_planets(still)
	still.clock = 9.0
	var later := LegendaryOrrery.build_planets(still)
	for index in 4:
		assert_vector(later[index].place).is_equal(first[index].place)
	var moving := _circle(_roles(4), false)
	_arrive(moving, 4)
	moving.clock = 0.4
	var start := LegendaryOrrery.build_planets(moving)[0].place
	moving.clock = 9.0
	assert_vector(LegendaryOrrery.build_planets(moving)[0].place).is_not_equal(start)


func test_draws_without_error_for_one_to_six_shards() -> void:
	for count in range(1, 7):
		var circle := _circle(_roles(count))
		_arrive(circle, count)
		var host := _host(circle)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_int(host.commands).is_greater(0)


func test_draws_without_error_for_every_role_and_a_roleless_shard() -> void:
	for role: String in ProgramSchemas.ROLES:
		var same: Array[String] = [role, role, role]
		var circle := _circle(same)
		_arrive(circle, 3)
		var host := _host(circle)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_int(host.commands).is_greater(0)
	var roleless: Array[String] = ["", "", ""]
	var bare := _circle(roleless)
	_arrive(bare, 3)
	var bare_host := _host(bare)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(bare_host.commands).is_greater(0)


func test_the_circle_draws_the_orrery_style_itself() -> void:
	var circle := _circle(_roles(3))
	_arrive(circle, 3)
	circle.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(circle)).is_true()


func test_the_carousel_card_draws_the_orrery_centred_on_its_card() -> void:
	var option := {"id": "legendary-orrery", "style": "orrery", "name": "Orrery of the Codex"}
	var art: LookArt = auto_free(LookArt.make("circle", option))
	art.size = Vector2(180, 210)
	add_child(art)
	art.set_process(false)
	art.set_live(false)
	var circle := art._effect as MagicCircle
	assert_bool(is_instance_valid(circle)).is_true()
	assert_str(circle.style).is_equal("orrery")
	# The orrery has no stack in front of it to balance, so it stays on the card's middle line.
	assert_float(circle.position.x).is_equal(art.size.x * 0.5)


func test_draw_command_budget_for_six_shards() -> void:
	var one_calling: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 0.5]
	var calling_count: int = await _draw_count(false, one_calling)
	print("legendary orrery, six shards, one calling: %d draw commands a frame" % calling_count)
	assert_int(calling_count).is_between(1, 120)
	var all_done: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	var settled_count: int = await _draw_count(false, all_done)
	print("legendary orrery, six shards, all done: %d draw commands a frame" % settled_count)
	assert_int(settled_count).is_between(1, 120)


## The colours of the segments one frame of `circle` strokes, at the circle's clock `now`, in order.
func _segments_at(circle: MagicCircle, now: float) -> Array[Color]:
	circle.clock = now
	var host: SegmentHost = auto_free(SegmentHost.new())
	host.circle = circle
	add_child(host)
	await get_tree().process_frame
	await get_tree().process_frame
	return host.colours


## The strokes one frame of `circle` draws, at the circle's clock `now`.
func _strokes_at(circle: MagicCircle, now: float) -> int:
	circle.clock = now
	var host := _host(circle)
	await get_tree().process_frame
	await get_tree().process_frame
	return host.commands


func test_a_link_flares_on_arrival_and_settles_to_its_steady_light() -> void:
	var circle := _circle(_roles(2))
	# Both shards arrive at clock 1.0, each with its call done, so only the link's own light changes after that.
	var done: Array[float] = [1.0, 1.0]
	circle.clock = 1.0
	circle.trace_shard(0, done[0])
	circle.trace_shard(1, done[1])
	var arrival: Array[Color] = await _segments_at(circle, 1.0)
	var settled: Array[Color] = await _segments_at(circle, 4.0)
	# A link is two strokes, a halo then the bright core, which is 0.9 of the link's light: 1.0 (the flare) on arrival,
	# then 0.8, the steady light.
	assert_float(arrival[1].a).is_equal_approx(0.9, 0.001)
	assert_float(settled[1].a).is_equal_approx(0.72, 0.001)


func test_under_reduced_motion_a_link_is_at_its_steady_light_at_once() -> void:
	var circle := _circle(_roles(2), true)
	var done: Array[float] = [1.0, 1.0]
	circle.clock = 1.0
	circle.trace_shard(0, done[0])
	circle.trace_shard(1, done[1])
	var arrival: Array[Color] = await _segments_at(circle, 1.0)
	assert_float(arrival[1].a).is_equal_approx(0.72, 0.001)


func test_reduced_motion_drops_the_flare() -> void:
	var still := _circle(_roles(2), true)
	_arrive(still, 2)
	still.pulse()
	assert_float(LegendaryOrrery.frame_of(still, 110.0, 1.0).flare).is_equal(0.0)
	var moving := _circle(_roles(2), false)
	_arrive(moving, 2)
	moving.pulse()
	assert_float(LegendaryOrrery.frame_of(moving, 110.0, 1.0).flare).is_greater(0.0)


func test_reduced_motion_draws_no_arrival_flourish() -> void:
	# An arrival's shock ring and flare are drawn in its first second; the same frame three seconds on has neither.
	var done: Array[float] = [1.0, 1.0]
	var calm := _circle(_roles(2))
	_walk(calm, done)
	var calm_fresh: int = await _strokes_at(calm, 0.2)
	var calm_settled: int = await _strokes_at(calm, 3.0)
	assert_int(calm_fresh).is_greater(calm_settled)
	var still := _circle(_roles(2), true)
	_walk(still, done)
	var still_fresh: int = await _strokes_at(still, 0.2)
	var still_settled: int = await _strokes_at(still, 3.0)
	assert_int(still_fresh).is_equal(still_settled)


## The centres of the discs one frame of `circle` draws, at its current clock.
func _centres_now(circle: MagicCircle) -> Array[Vector2]:
	var host: CentreHost = auto_free(CentreHost.new())
	host.circle = circle
	add_child(host)
	await get_tree().process_frame
	await get_tree().process_frame
	return host.centres


func _has_point(points: Array[Vector2], wanted: Vector2) -> bool:
	for point: Vector2 in points:
		if point.is_equal_approx(wanted):
			return true
	return false


func test_planet_positions_has_one_point_per_shard() -> void:
	for count: int in range(0, 7):
		assert_int(LegendaryOrrery.planet_positions(0.7, 110.0, count).size()).is_equal(count)


func test_final_node_is_the_last_planet_position() -> void:
	var times: Array[float] = [0.0, 1.3, 7.9]
	for count: int in range(1, 7):
		for time: float in times:
			var points := LegendaryOrrery.planet_positions(time, 110.0, count)
			var last := LegendaryOrrery.final_node(time, 110.0, count)
			assert_vector(last).is_equal_approx(points[count - 1], Vector2(0.001, 0.001))


func test_final_node_is_where_draw_puts_the_last_planet() -> void:
	# Every planet draw places is one planet_positions gives, and the final node is the last of them, moving or still.
	for reduced: bool in [false, true]:
		for count: int in range(1, 7):
			var circle := _circle(_roles(count), reduced)
			_arrive(circle, count)
			circle.clock = 2.3
			var centres: Array[Vector2] = await _centres_now(circle)
			var time := LegendaryOrrery.motion_clock(circle)
			for point: Vector2 in LegendaryOrrery.planet_positions(time, 110.0, count):
				assert_bool(_has_point(centres, point)).is_true()
			assert_bool(_has_point(centres, LegendaryOrrery.final_node(time, 110.0, count))).is_true()


func test_no_shards_gives_the_centre() -> void:
	assert_int(LegendaryOrrery.planet_positions(0.7, 110.0, 0).size()).is_equal(0)
	assert_vector(LegendaryOrrery.final_node(0.7, 110.0, 0)).is_equal(Vector2.ZERO)
	var bare := _circle(_roles(0))
	assert_vector(bare.final_node_global()).is_equal_approx(bare.global_position, Vector2(0.001, 0.001))


func test_final_node_global_follows_the_orbit() -> void:
	var circle := _circle(_roles(4))
	_arrive(circle, 4)
	circle.clock = 0.4
	var first := circle.final_node_global()
	circle.clock = 3.0
	assert_vector(circle.final_node_global()).is_not_equal(first)
	# Under reduced motion the orbits stand still, so the final node stays where it was.
	var still := _circle(_roles(4), true)
	_arrive(still, 4)
	still.clock = 0.4
	var still_first := still.final_node_global()
	still.clock = 3.0
	assert_vector(still.final_node_global()).is_equal_approx(still_first, Vector2(0.001, 0.001))


func test_final_node_global_is_the_final_node_in_global_space_with_the_swell() -> void:
	var circle := _circle(_roles(3))
	_arrive(circle, 3)
	circle.clock = 1.7
	var local := LegendaryOrrery.final_node(LegendaryOrrery.motion_clock(circle), circle.radius, 3)
	assert_vector(circle.final_node_global()).is_equal_approx(circle.to_global(local), Vector2(0.001, 0.001))
	# Halfway through its close the circle has swelled, and its final node swells with it, as _draw's does.
	circle.close()
	circle.clock += MagicCircle.CLOSE_SECONDS * 0.5
	var swollen := circle.radius * (1.0 + 0.5 * MagicCircle.CLOSE_SWELL)
	var closing_local := LegendaryOrrery.final_node(LegendaryOrrery.motion_clock(circle), swollen, 3)
	assert_vector(circle.final_node_global()).is_equal_approx(circle.to_global(closing_local), Vector2(0.001, 0.001))
