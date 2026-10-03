extends GdUnitTestSuite
## The cast's magic circle (ADR-0030): it completes on its tier's beat, bolts are born on its front circle, and it
## closes and goes when the volley is over.


func test_it_completes_on_its_tiers_beat() -> void:
	var circle: MagicCircle = auto_free(MagicCircle.cast(self, Vector2(400, 300), 2, "fire", 100.0))
	var completed: Array[bool] = [false]
	circle.formed.connect(func() -> void: completed[0] = true)
	circle._process(circle.form_time() - 0.05)
	assert_bool(completed[0]).is_false()
	circle._process(0.06)
	assert_bool(completed[0]).is_true()
	assert_float(circle.form_time()).is_equal(float(MagicCircle.TIERS[2].form))


func test_bolts_are_born_in_front_of_it_toward_the_foes() -> void:
	var circle: MagicCircle = auto_free(MagicCircle.cast(self, Vector2(400, 300), 3, "none", 100.0))
	for i in 20:
		var point := circle.launch_point()
		# The front circle stands toward the foes (to the right) and is narrowed: never behind the first circle.
		assert_float(point.x).is_greater(400.0)
		assert_float(absf(point.y - 300.0)).is_less(100.0)


func test_it_closes_and_goes() -> void:
	var circle := MagicCircle.cast(self, Vector2(400, 300), 0, "frost", 80.0)
	circle._process(circle.form_time() + 0.1)
	circle.close()
	circle._process(MagicCircle.CLOSE_SECONDS + 0.01)
	assert_bool(circle.is_queued_for_deletion()).is_true()
	circle.free()


func _cast_with(count: int, speed := 1.0) -> MagicCircle:
	var cards := CircleLayers.demo_cards(count)
	var circle := MagicCircle.cast(
		self, Vector2(400, 300), CircleLayers.tier_for(count), "fire", 100.0, CircleLayers.words(cards), speed, true
	)
	circle.use_plan(CircleLayers.plan(cards))
	return circle


func test_casting_n_shards_builds_n_layers_one_after_another() -> void:
	for count in range(1, 7):
		var circle: MagicCircle = auto_free(_cast_with(count))
		var arrived: Array[int] = []
		circle.layer_added.connect(func(index: int) -> void: arrived.append(index))
		assert_int(circle.layers.size()).is_equal(count)
		assert_int(circle.tier).is_equal(CircleLayers.tier_for(count))
		var seen := 0
		while circle.clock < circle.form_time() + 0.05:
			circle._process(1.0 / 60.0)
			# Never more layers than the time allows, and never out of order.
			assert_int(arrived.size()).is_greater_equal(seen)
			seen = arrived.size()
		var expected: Array[int] = []
		for index in count:
			expected.append(index)
		assert_array(arrived).is_equal(expected)
		for index in count:
			assert_float(circle._layer_progress(index)).is_equal(1.0)


func test_the_layers_stack_up_in_time_not_all_at_once() -> void:
	var circle: MagicCircle = auto_free(_cast_with(6))
	var counts: Array[int] = []
	for share: float in [0.15, 0.35, 0.55, 0.75, 0.95]:
		while circle.clock < share * circle.form_time():
			circle._process(1.0 / 60.0)
		counts.append(circle._arrived)
	for i in counts.size() - 1:
		assert_int(counts[i + 1]).is_greater_equal(counts[i])
	assert_int(counts[0]).is_less(counts[counts.size() - 1])
	assert_int(counts[counts.size() - 1]).is_equal(6)


func test_a_circle_with_no_layers_is_the_bare_frame() -> void:
	var circle: MagicCircle = auto_free(MagicCircle.cast(self, Vector2(400, 300), 0, "none", 80.0))
	circle._process(circle.form_time() + 0.1)
	assert_int(circle.layers.size()).is_equal(0)
	assert_int(circle._arrived).is_equal(0)


func test_the_last_layer_is_whole_when_the_circle_is_complete() -> void:
	var circle: MagicCircle = auto_free(_cast_with(6))
	var completed: Array[bool] = [false]
	circle.formed.connect(func() -> void: completed[0] = true)
	while not completed[0]:
		circle._process(1.0 / 60.0)
	assert_float(circle._layer_progress(5)).is_greater(0.98)


func test_layers_arrive_whole_in_reduced_motion() -> void:
	var before := Settings.reduced_motion
	Settings.reduced_motion = true
	var circle: MagicCircle = auto_free(_cast_with(3))
	Settings.reduced_motion = before
	assert_bool(circle._reduced).is_true()
	var arrived: Array[int] = []
	circle.layer_added.connect(func(index: int) -> void: arrived.append(index))
	circle._process(circle.form_time() + 0.05)
	assert_int(arrived.size()).is_equal(3)


func test_every_style_stacks_the_same_layers() -> void:
	for style: String in ["codex", "rootglass", "clockwork", "constellation"]:
		var circle: MagicCircle = auto_free(_cast_with(6))
		circle.style = style
		circle._process(circle.form_time() + 0.2)
		assert_int(circle._arrived).is_equal(6)
		circle.queue_redraw()


func test_every_kind_of_layer_draws_without_error() -> void:
	for kind in CircleLayers.KINDS:
		for style: String in ["codex", "rootglass", "clockwork", "constellation"]:
			var circle: MagicCircle = auto_free(
				MagicCircle.cast(self, Vector2(400, 300), 0, "none", 90.0, "", 1.0, true)
			)
			circle.style = style
			var spec := {"kind": kind, "word": "fork()", "seed": 7, "dir": 1}
			circle.use_plan([spec, spec.merged({"dir": -1})])
			circle._process(circle.form_time() + 0.1)
			await get_tree().process_frame
			assert_bool(circle.is_inside_tree()).is_true()


func test_a_stage_writes_the_circle_of_the_spells_shards() -> void:
	var stage: BattleStage = auto_free(BattleStage.new())
	stage.size = Vector2(1200, 700)
	add_child(stage)
	await get_tree().process_frame
	stage.hero.size = Vector2(500, 600)
	for count: int in [1, 2, 3, 4, 5, 6, 8]:
		var circle := stage.magic_circle(CircleLayers.demo_cards(mini(count, 6)), "fire")
		assert_object(circle).is_not_null()
		assert_int(circle.tier).is_equal(CircleLayers.tier_for(count))
		assert_int(circle.layers.size()).is_equal(mini(count, 6))
		circle.queue_free()
	# The bigger the spell, the bigger its circle.
	var small := stage.magic_circle(CircleLayers.demo_cards(1), "none")
	var grand := stage.magic_circle(CircleLayers.demo_cards(6), "none")
	assert_float(grand.radius).is_greater(small.radius)


func test_how_she_casts_never_changes_when_the_circle_is_complete() -> void:
	# Budget (ADR-0039): a heavy cast gathers at least a second; a snap hurries a bigger circle less but still
	# completes within its tier's own form time.
	for tier in MagicCircle.TIERS.size():
		var form := float(MagicCircle.TIERS[tier].form)
		assert_float(form / LogPlayer.gather_speed(tier)).is_greater_equal(LogPlayer.HEAVY_GATHER - 0.001)
		assert_float(LogPlayer.gather_speed(tier)).is_less_equal(1.0)
		assert_float(form / LogPlayer.snap_speed(tier)).is_less_equal(form)
		assert_float(form / LogPlayer.snap_speed(tier)).is_less(1.1)
	assert_float(LogPlayer.snap_speed(0)).is_equal(LogPlayer.SNAP_SPEED)
	assert_float(LogPlayer.snap_speed(3)).is_less(LogPlayer.snap_speed(0))
