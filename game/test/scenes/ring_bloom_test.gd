extends GdUnitTestSuite
## Ring Bloom (ADR-0043): a core and one whole ring more for every shard, up to six. A ring is never written; it stands
## whole when its function begins and only turns a little into its place.


func _circle(count := 6) -> MagicCircle:
	var circle: MagicCircle = auto_free(
		MagicCircle.cast(self, Vector2(400, 300), CircleLayers.tier_for(count), "none", 100.0, "", 1.0, true)
	)
	circle.style = "ring-bloom"
	circle.external_construction = true
	circle.use_plan(CircleLayers.plan(CircleLayers.demo_cards(count)))
	circle.set_process(false)
	return circle


func test_each_ring_stands_outside_the_last_from_the_core_to_the_rim() -> void:
	assert_float(RingBloom.outer_share(0)).is_equal(RingBloom.CORE)
	assert_float(RingBloom.outer_share(RingBloom.MAX_RINGS - 1)).is_equal(1.0)
	for index in range(1, RingBloom.MAX_RINGS):
		assert_float(RingBloom.outer_share(index)).is_greater(RingBloom.outer_share(index - 1))
	# A seventh would stand on the rim, not beyond it.
	assert_float(RingBloom.outer_share(9)).is_equal(1.0)


func test_a_ring_is_whole_almost_at_once_and_only_turns_a_little() -> void:
	assert_float(RingBloom.state(0.0, 1).alpha).is_equal(0.0)
	var early := RingBloom.state(0.05, 1)
	assert_float(early.alpha).is_greater(0.5)
	assert_float(RingBloom.state(RingBloom.APPEAR, 1).alpha).is_equal_approx(1.0, 0.0001)
	var turning := RingBloom.state(0.02, -1)
	assert_float(turning.turn).is_less(0.0)
	assert_float(absf(float(turning.turn))).is_less_equal(RingBloom.SET_TURN)
	assert_float(RingBloom.SET_TURN).is_less(0.8)
	var done := RingBloom.state(1.0, 1)
	assert_float(done.alpha).is_equal(1.0)
	assert_float(done.scale).is_equal(1.0)
	assert_float(done.turn).is_equal_approx(0.0, 0.0001)


func test_the_circle_grows_one_ring_per_shard_to_six() -> void:
	var circle := _circle()
	assert_int(circle.layers.size()).is_equal(6)
	for index in 6:
		circle.trace_shard(index, 0.05)
		assert_int(circle._arrived).is_equal(index + 1)
		assert_float(circle._layer_progress(index)).is_equal(0.05)
	circle.queue_redraw()
	assert_str(circle.style).is_equal("ring-bloom")


func test_it_draws_without_error_at_every_stage_and_in_reduced_motion() -> void:
	for reduced: bool in [false, true]:
		var circle := _circle()
		circle._reduced = reduced
		for index in 6:
			circle.trace_shard(index, 0.0)
			circle.trace_shard(index, 0.3)
			circle.queue_redraw()
			await get_tree().process_frame
			circle.trace_shard(index, 1.0)
			circle.queue_redraw()
			await get_tree().process_frame
		circle.finish_construction()
		circle._process(1.0)
		circle.queue_redraw()
		await get_tree().process_frame


func test_bolts_leave_from_its_centre() -> void:
	var circle := _circle(3)
	assert_vector(circle.launch_point()).is_equal(circle.position)


func test_spells_offers_script_loom_and_ring_bloom_and_the_catalogue_is_sound() -> void:
	assert_array(CosmeticRules.check(Cosmetics.catalog())).is_empty()
	for style: String in ["script-loom", "ring-bloom"]:
		var found := false
		for option in Cosmetics.options("circle"):
			found = found or option.style == style
		assert_bool(found).override_failure_message(style).is_true()
	assert_str(CosmeticRules.defaults(Cosmetics.catalog()).circle).is_equal("codex")


func test_a_stage_draws_the_worn_ring_bloom_at_the_grand_size() -> void:
	var stage: BattleStage = auto_free(BattleStage.new())
	stage.size = Vector2(1200, 700)
	stage.hero.set_preview_skin("vesper")
	stage.hero.preview_loadout = {"circle": "ring-bloom"}
	add_child(stage)
	var one := stage.magic_circle(CircleLayers.demo_cards(1), "none", 1.0, true)
	var six := stage.magic_circle(CircleLayers.demo_cards(6), "none", 1.0, true)
	assert_str(one.style).is_equal("ring-bloom")
	assert_str(six.style).is_equal("ring-bloom")
	assert_float(one.radius).is_equal(six.radius)
	assert_float(six.radius).is_equal(stage.hero.circle_radius(3))


func test_a_small_spell_pulses_small() -> void:
	var small := _circle(2)
	var grand := _circle(6)
	assert_float(small.reach()).is_less(grand.reach() * 0.5)
	assert_float(grand.reach()).is_equal(grand.radius)
	small.pulse()
	grand.pulse()
	var farthest := func(circle: MagicCircle) -> float:
		var most := 0.0
		for mote: Array in circle._motes:
			most = maxf(most, (mote[1] as Vector2).length())
		return most
	# The sparks leave the centre, at speeds that follow the circle's own size.
	for mote: Array in small._motes:
		assert_vector(mote[0]).is_equal(Vector2.ZERO)
	assert_float(farthest.call(small)).is_less(farthest.call(grand))


func test_every_style_pulses_in_proportion_to_its_circle() -> void:
	for style: String in ["codex", "script-loom", "ring-bloom"]:
		var small: MagicCircle = auto_free(MagicCircle.cast(self, Vector2.ZERO, 0, "none", 50.0, "", 1.0, true))
		var large: MagicCircle = auto_free(MagicCircle.cast(self, Vector2.ZERO, 0, "none", 200.0, "", 1.0, true))
		for circle: MagicCircle in [small, large]:
			circle.style = style
			circle.use_plan(CircleLayers.plan(CircleLayers.demo_cards(6)))
			circle.set_process(false)
			circle.pulse()
		var reach_of := func(circle: MagicCircle) -> float:
			var most := 0.0
			for mote: Array in circle._motes:
				most = maxf(most, (mote[1] as Vector2).length())
			return most
		assert_float(reach_of.call(large)).override_failure_message(style).is_greater(reach_of.call(small) * 2.0)
