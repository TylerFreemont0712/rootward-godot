extends GdUnitTestSuite
## Constellation geometry (docs/LEGENDARY_LOOKS.md, "Geometry"): the star places and offsets, the route through them,
## and the point a head reaches on it. Pure functions, so no scene is built.

const ORIGIN := Vector2(120.0, 80.0)
const TARGET := Vector2(520.0, 340.0)
## Places and offsets are 64-bit in the maths but stored 32-bit, so they are checked to this much.
const SLACK := 0.00001
## Points are 32-bit too, and a point near 500 px carries a few ten-thousandths of a pixel of rounding.
const SLACK_POINT := Vector2(0.001, 0.001)


func test_stars_gives_one_parameter_per_star() -> void:
	for count: int in [0, 1, 2, 4, 5, 9, 20]:
		assert_int(ConstellationPath.stars(3, count, 0.2).size()).is_equal(count)
	assert_int(ConstellationPath.stars(3, -2, 0.2).size()).is_equal(0)


func test_places_are_sorted_and_inside_the_range() -> void:
	for sample: int in range(200):
		var previous := 0.0
		for star: Vector2 in ConstellationPath.stars(sample, 5, 0.2):
			assert_float(star.x).is_greater_equal(0.12 - SLACK)
			assert_float(star.x).is_less_equal(0.88 + SLACK)
			assert_float(star.x).is_greater_equal(previous)
			previous = star.x


func test_neighbours_are_at_least_the_gap_apart_when_the_range_holds_them() -> void:
	for count: int in [4, 5]:
		for sample: int in range(200):
			var stars := ConstellationPath.stars(sample, count, 0.2)
			for k: int in range(1, count):
				assert_float(stars[k].x - stars[k - 1].x).is_greater_equal(0.06 - SLACK)


func test_places_are_evenly_spaced_when_the_gap_cannot_fit() -> void:
	# Twenty stars have nineteen gaps of 0.06, which is 1.14: more than the 0.76 that the range holds.
	var even := 0.76 / 19.0
	for sample: int in range(5):
		var stars := ConstellationPath.stars(sample, 20, 0.2)
		assert_float(stars[0].x).is_equal_approx(0.12, SLACK)
		assert_float(stars[19].x).is_equal_approx(0.88, SLACK)
		for k: int in range(1, 20):
			assert_float(stars[k].x - stars[k - 1].x).is_equal_approx(even, SLACK)


func test_the_same_seed_draws_the_same_stars() -> void:
	var first := ConstellationPath.stars(7, 5, 0.2)
	var other := ConstellationPath.stars(8, 5, 0.2)
	assert_bool(other == first).is_false()
	assert_bool(ConstellationPath.stars(7, 5, 0.2) == first).is_true()


func test_different_seeds_draw_different_stars() -> void:
	for a: int in range(50):
		for b: int in range(a + 1, 50):
			assert_bool(ConstellationPath.stars(a, 5, 0.2) == ConstellationPath.stars(b, 5, 0.2)).is_false()


func test_the_lateral_offset_shrinks_towards_the_target() -> void:
	var spread := 0.3
	# A star at t 0.85 may stray 0.3 * 0.49 = 0.147 of the line's length; one at t 0.2 may stray 0.3 * 0.88 = 0.264.
	assert_float(ConstellationPath.lateral_bound(0.85, spread)).is_equal_approx(0.147, SLACK)
	assert_float(ConstellationPath.lateral_bound(0.2, spread)).is_equal_approx(0.264, SLACK)
	var strayed_near_origin := false
	for sample: int in range(200):
		for star: Vector2 in ConstellationPath.stars(sample, 5, spread):
			var bound := ConstellationPath.lateral_bound(star.x, spread)
			assert_float(absf(star.y)).is_less_equal(bound + SLACK)
			if star.x < 0.3 and absf(star.y) > ConstellationPath.lateral_bound(0.85, spread):
				strayed_near_origin = true
	# The taper is doing work: stars near the origin do stray past the bound that a star at the target is held to.
	assert_bool(strayed_near_origin).is_true()


func test_the_route_has_count_plus_two_points_from_origin_to_target() -> void:
	for count: int in [0, 4, 5]:
		var route := ConstellationPath.route(ORIGIN, TARGET, ConstellationPath.stars(3, count, 0.2))
		assert_int(route.size()).is_equal(count + 2)
		assert_vector(route[0]).is_equal_approx(ORIGIN, SLACK_POINT)
		assert_vector(route[route.size() - 1]).is_equal_approx(TARGET, SLACK_POINT)


func test_each_star_sits_at_its_place_and_offset_on_the_line() -> void:
	var stars := ConstellationPath.stars(11, 5, 0.25)
	var route := ConstellationPath.route(ORIGIN, TARGET, stars)
	var direction := TARGET - ORIGIN
	var length := direction.length()
	var perpendicular := Vector2(-direction.y, direction.x)
	for k: int in stars.size():
		var offset: Vector2 = route[k + 1] - ORIGIN
		# Along the line a star sits at its place. Across it, the star sits at its offset as a fraction of the length.
		assert_float(offset.dot(direction) / (length * length)).is_equal_approx(stars[k].x, 0.0001)
		assert_float(offset.dot(perpendicular) / length).is_equal_approx(stars[k].y * length, 0.01)


func test_point_on_is_continuous_along_the_route() -> void:
	var route := ConstellationPath.route(ORIGIN, TARGET, ConstellationPath.stars(5, 5, 0.25))
	var segments := route.size() - 1
	var longest := 0.0
	for k: int in segments:
		longest = maxf(longest, route[k].distance_to(route[k + 1]))
	# A step of 1 / steps moves the head at most the longest segment times the segment count, times that step.
	var steps := 2000
	var previous := ConstellationPath.point_on(route, 0.0)
	for step: int in range(1, steps + 1):
		var point := ConstellationPath.point_on(route, float(step) / steps)
		assert_float(point.distance_to(previous)).is_less_equal(longest * segments / steps + 0.001)
		previous = point
	# Just either side of each star, the head is at that star.
	for k: int in range(1, segments):
		var at := float(k) / segments
		assert_vector(ConstellationPath.point_on(route, at - 0.000001)).is_equal_approx(route[k], Vector2(0.01, 0.01))
		assert_vector(ConstellationPath.point_on(route, at + 0.000001)).is_equal_approx(route[k], Vector2(0.01, 0.01))


func test_point_on_reaches_star_k_at_k_over_count_plus_one() -> void:
	for count: int in [4, 5]:
		var route := ConstellationPath.route(ORIGIN, TARGET, ConstellationPath.stars(21, count, 0.2))
		for k: int in range(1, count + 1):
			var reached := ConstellationPath.point_on(route, float(k) / (count + 1))
			assert_vector(reached).is_equal_approx(route[k], SLACK_POINT)
		assert_vector(ConstellationPath.point_on(route, 0.0)).is_equal_approx(ORIGIN, SLACK_POINT)
		assert_vector(ConstellationPath.point_on(route, 1.0)).is_equal_approx(TARGET, SLACK_POINT)
		# Outside 0..1 the head stays at the nearer end.
		assert_vector(ConstellationPath.point_on(route, -0.5)).is_equal_approx(ORIGIN, SLACK_POINT)
		assert_vector(ConstellationPath.point_on(route, 1.5)).is_equal_approx(TARGET, SLACK_POINT)


func test_a_zero_length_line_gives_finite_points() -> void:
	var route := ConstellationPath.route(ORIGIN, ORIGIN, ConstellationPath.stars(9, 5, 0.3))
	assert_int(route.size()).is_equal(7)
	for point: Vector2 in route:
		assert_bool(point.is_finite()).is_true()
		assert_vector(point).is_equal_approx(ORIGIN, SLACK_POINT)
	for p: float in [0.0, 0.3, 0.5, 1.0]:
		var point := ConstellationPath.point_on(route, p)
		assert_bool(point.is_finite()).is_true()
		assert_vector(point).is_equal_approx(ORIGIN, SLACK_POINT)


func test_point_on_gives_the_zero_vector_for_an_empty_route() -> void:
	assert_vector(ConstellationPath.point_on(PackedVector2Array(), 0.5)).is_equal(Vector2.ZERO)
