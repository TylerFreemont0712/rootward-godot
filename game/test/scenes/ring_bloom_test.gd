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


func test_the_style_worn_in_spells_wins_over_a_move_s_own() -> void:
	var loom := {"circle_style": "script-loom"}
	assert_str(CosmeticRules.construction_style(loom, "ring-bloom")).is_equal("ring-bloom")
	assert_str(CosmeticRules.construction_style({}, "ring-bloom")).is_equal("ring-bloom")
	assert_str(CosmeticRules.construction_style(loom, "script-loom")).is_equal("script-loom")
	assert_str(CosmeticRules.construction_style(loom, "codex")).is_equal("script-loom")
	assert_str(CosmeticRules.construction_style({}, "constellation")).is_equal("constellation")


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
	var one := stage.magic_circle(CircleLayers.demo_cards(1), "none", 1.0, true, "")
	var six := stage.magic_circle(CircleLayers.demo_cards(6), "none", 1.0, true, "script-loom")
	assert_str(one.style).is_equal("ring-bloom")
	assert_str(six.style).is_equal("ring-bloom")
	assert_float(one.radius).is_equal(six.radius)
	assert_float(six.radius).is_equal(stage.hero.circle_radius(3))
