extends GdUnitTestSuite
## The town's weather layer (Concept/v0.4/05, section 2.7): rain falls as streaks, a cloud veils the town, sun and no
## weather draw nothing, reduced motion gives fewer and slower drops, and the layer ignores the mouse.

var rain: RainLayer
var _saved_reduced := false


func before_test() -> void:
	_saved_reduced = Settings.reduced_motion
	Settings.reduced_motion = false
	rain = RainLayer.new()
	add_child(rain)
	rain.size = Vector2(1280, 720)
	await await_idle_frame()


func after_test() -> void:
	Settings.reduced_motion = _saved_reduced
	rain.free()


func test_rain_falls_as_160_streaks() -> void:
	rain.set_weather("rain")
	assert_str(rain.weather()).is_equal("rain")
	assert_int(rain.drop_count()).is_equal(160)
	assert_float(rain.speed()).is_equal(RainLayer.FALL)
	assert_float(rain.veil_alpha()).is_equal(0.0)


func test_the_drops_fall_each_frame_and_never_pass_the_bottom() -> void:
	rain.set_weather("rain")
	var before := rain.drops()
	for frame in 3:
		await await_idle_frame()
	var after := rain.drops()
	var fell := 0
	for index in before.size():
		if after[index].y > before[index].y:
			fell += 1
	assert_int(fell).is_greater(100)
	# A drop that reaches the bottom starts again above the top, so none is ever left below the layer.
	for point: Vector2 in after:
		assert_float(point.y).is_less_equal(720.0)


func test_cloud_veils_faintly_and_drops_nothing() -> void:
	rain.set_weather("cloud")
	assert_str(rain.weather()).is_equal("cloud")
	assert_int(rain.drop_count()).is_equal(0)
	assert_float(rain.veil_alpha()).is_equal_approx(0.08, 0.0001)


func test_sun_and_no_weather_draw_nothing() -> void:
	for kind: String in ["sun", ""]:
		rain.set_weather(kind)
		assert_str(rain.weather()).is_equal(kind)
		assert_int(rain.drop_count()).is_equal(0)
		assert_float(rain.veil_alpha()).is_equal(0.0)
		assert_bool(rain.is_processing()).is_false()


func test_an_unknown_kind_is_no_weather() -> void:
	rain.set_weather("snow")
	assert_str(rain.weather()).is_equal("")
	assert_int(rain.drop_count()).is_equal(0)


func test_reduced_motion_gives_fewer_and_slower_drops() -> void:
	Settings.reduced_motion = true
	rain.set_weather("rain")
	assert_int(rain.drop_count()).is_equal(40)
	assert_float(rain.speed()).is_equal(RainLayer.CALM_FALL)
	assert_float(rain.speed()).is_less(RainLayer.FALL)


func test_the_layer_ignores_the_mouse() -> void:
	assert_int(rain.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
