extends GdUnitTestSuite
## The window and renderer options: the pure parts (what a frame cap, a window size and a relaunch come to).


func test_the_frame_cap_is_a_whole_share_of_the_refresh_rate() -> void:
	# A cap that is not refresh / n makes vsync show some frames twice as long as others, which reads as judder.
	assert_int(Graphics.frame_cap(165.0)).is_equal(83)
	assert_int(Graphics.frame_cap(144.0)).is_equal(72)
	assert_int(Graphics.frame_cap(120.0)).is_equal(60)
	assert_int(Graphics.frame_cap(60.0)).is_equal(60)
	assert_int(Graphics.frame_cap(59.94)).is_equal(60)
	assert_int(Graphics.frame_cap(90.0)).is_equal(90)


func test_the_automatic_frame_cap_never_exceeds_the_ceiling() -> void:
	for refresh: float in [24.0, 50.0, 75.0, 100.0, 144.0, 165.0, 240.0, 360.0]:
		assert_int(Graphics.frame_cap(refresh)).is_less_equal(Graphics.MAX_FPS + 1)


func test_an_unknown_refresh_rate_gets_the_ceiling() -> void:
	for refresh: float in [-1.0, 0.0, NAN, INF]:
		assert_int(Graphics.frame_cap(refresh)).is_equal(Graphics.MAX_FPS)


func test_a_chosen_frame_limit_is_used_as_it_is_and_unlimited_is_zero() -> void:
	assert_int(Graphics.frame_cap(165.0, 60)).is_equal(60)
	assert_int(Graphics.frame_cap(60.0, 144)).is_equal(144)
	assert_int(Graphics.frame_cap(165.0, Graphics.UNLIMITED)).is_equal(0)


func test_a_window_is_fitted_to_the_room_it_has() -> void:
	assert_that(Graphics.fit_window(Vector2i(1920, 1080), Vector2i(2560, 1400))).is_equal(Vector2i(1920, 1080))
	assert_that(Graphics.fit_window(Vector2i(2560, 1440), Vector2i(1920, 1040))).is_equal(Vector2i(1920, 1040))


func test_only_the_offered_sizes_scales_and_limits_survive_loading() -> void:
	assert_that(Graphics.parse_size("1600x900", Graphics.DEFAULT_WINDOW)).is_equal(Vector2i(1600, 900))
	assert_that(Graphics.parse_size("1599x900", Graphics.DEFAULT_WINDOW)).is_equal(Graphics.DEFAULT_WINDOW)
	assert_that(Graphics.parse_size(12, Graphics.DEFAULT_WINDOW)).is_equal(Graphics.DEFAULT_WINDOW)
	assert_str(Graphics.size_text(Vector2i(1280, 720))).is_equal("1280x720")
	# JSON numbers come back as floats: 60.0 is the limit 60, and 0.88 the scale 0.88.
	assert_int(Graphics.choose(60.0, Graphics.FRAME_LIMITS, Graphics.AUTO)).is_equal(60)
	assert_int(Graphics.choose(61.0, Graphics.FRAME_LIMITS, Graphics.AUTO)).is_equal(Graphics.AUTO)
	assert_float(Graphics.choose(1.0, Graphics.UI_SCALES, 0.88)).is_equal(1.0)
	assert_float(Graphics.choose(3.0, Graphics.UI_SCALES, 0.88)).is_equal(0.88)
	assert_str(Graphics.choose("adaptive", Graphics.VSYNC_MODES, "on")).is_equal("adaptive")
	assert_str(Graphics.choose("hyper", Graphics.VSYNC_MODES, "on")).is_equal("on")
	assert_str(Graphics.choose(null, Graphics.RENDERERS, "auto")).is_equal("auto")


func test_a_relaunch_asks_for_the_chosen_device_and_renderer_and_drops_the_old_ones() -> void:
	var now := PackedStringArray(["--path", "game", "--gpu-index", "1", "--rendering-method", "mobile"])
	var args := Graphics.relaunch_args(now, 0, "gl_compatibility")
	assert_array(args).contains_exactly(
		[
			"--path",
			"game",
			"--gpu-index",
			"0",
			"--rendering-method",
			"gl_compatibility",
			"--rendering-driver",
			"opengl3",
			Graphics.RELAUNCHED
		]
	)


func test_automatic_choices_add_no_flags() -> void:
	var args := Graphics.relaunch_args(PackedStringArray(["--path", "game", "--gpu-index=1"]), Graphics.AUTO, "auto")
	assert_array(args).contains_exactly(["--path", "game", Graphics.RELAUNCHED])


func test_what_is_running_is_read_from_the_command_line() -> void:
	assert_int(Graphics.running_gpu(PackedStringArray(["--gpu-index", "2"]))).is_equal(2)
	assert_int(Graphics.running_gpu(PackedStringArray(["--gpu-index=1"]))).is_equal(1)
	assert_int(Graphics.running_gpu(PackedStringArray(["--path", "game"]))).is_equal(Graphics.AUTO)
	assert_str(Graphics.running_renderer(PackedStringArray(["--rendering-method", "mobile"]))).is_equal("mobile")
	assert_str(Graphics.running_renderer(PackedStringArray(["--path", "game"]))).is_equal("auto")


func test_a_restart_is_pending_only_when_the_choice_is_not_what_is_running() -> void:
	var plain := PackedStringArray(["--path", "game"])
	assert_bool(Graphics.restart_pending(plain, Graphics.AUTO, "auto")).is_false()
	assert_bool(Graphics.restart_pending(plain, 0, "auto")).is_true()
	assert_bool(Graphics.restart_pending(plain, Graphics.AUTO, "mobile")).is_true()
	assert_bool(Graphics.restart_pending(PackedStringArray(["--gpu-index", "0"]), 0, "auto")).is_false()


func test_the_game_relaunches_itself_once_and_only_from_its_own_front_door() -> void:
	var plain := PackedStringArray(["--path", "game"])
	assert_bool(Graphics.should_relaunch(plain, 0, "auto")).is_true()
	# Already relaunched: a choice that did not take effect must not loop.
	assert_bool(Graphics.should_relaunch(Graphics.relaunch_args(plain, 0, "auto"), 1, "auto")).is_false()
	# A tool or a test running a scene of its own is left alone.
	(
		assert_bool(Graphics.should_relaunch(PackedStringArray(["--path", "game", "res://tools/x.tscn"]), 0, "auto"))
		. is_false()
	)
	assert_bool(Graphics.should_relaunch(PackedStringArray(["--headless", "-s", "x.gd"]), 0, "auto")).is_false()
	assert_bool(Graphics.should_relaunch(plain, Graphics.AUTO, "auto")).is_false()
