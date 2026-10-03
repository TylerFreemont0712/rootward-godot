extends GdUnitTestSuite
## Shard Weave must wait for the real walkthrough, even when it takes longer than a normal cast.


func _circle(count := 4) -> MagicCircle:
	var circle: MagicCircle = auto_free(
		MagicCircle.cast(self, Vector2(400, 300), CircleLayers.tier_for(count), "none", 100.0, "", 1.0, true)
	)
	circle.external_construction = true
	circle.use_plan(CircleLayers.plan(CircleLayers.demo_cards(count)))
	circle.set_process(false)
	return circle


func test_no_layer_or_frame_appears_before_a_shard_resolves() -> void:
	var circle := _circle()
	circle._process(5.0)
	assert_int(circle._arrived).is_equal(0)
	assert_float(circle.construction_share()).is_equal(0.0)
	assert_bool(circle.is_constructed()).is_false()
	assert_array(circle._motes).is_empty()


func test_each_callback_adds_one_layer_and_waiting_adds_nothing() -> void:
	var circle := _circle()
	var arrivals: Array[int] = []
	circle.layer_added.connect(func(index: int) -> void: arrivals.append(index))
	circle.construct_shard(0)
	circle._process(MagicCircle.SHARD_DRAW_SECONDS * 0.5)
	assert_float(circle._layer_progress(0)).is_between(0.4, 0.6)
	assert_float(circle._layer_progress(1)).is_equal(0.0)
	circle._process(10.0)
	assert_array(arrivals).is_equal([0])
	assert_float(circle.construction_share()).is_equal(0.25)
	assert_bool(circle.is_constructed()).is_false()
	circle.construct_shard(0)
	circle.construct_shard(3)
	assert_array(arrivals).is_equal([0])
	circle.construct_shard(1)
	circle._process(MagicCircle.SHARD_DRAW_SECONDS)
	assert_array(arrivals).is_equal([0, 1])
	assert_float(circle.construction_share()).is_between(0.4999, 0.5001)


func test_function_progress_draws_during_the_call_and_waiting_does_not_finish_it() -> void:
	var circle := _circle(2)
	var arrivals: Array[int] = []
	circle.layer_added.connect(func(index: int) -> void: arrivals.append(index))
	circle.trace_shard(0, 0.0)
	circle.trace_shard(0, 0.4)
	circle._process(20.0)
	assert_array(arrivals).is_equal([0])
	assert_float(circle._layer_progress(0)).is_equal(0.4)
	assert_float(circle.construction_share()).is_equal(0.2)
	circle.trace_shard(0, 0.1)
	circle.trace_shard(2, 1.0)
	assert_float(circle._layer_progress(0)).is_equal(0.4)
	circle.trace_shard(0, 1.0)
	circle.construct_shard(0)
	circle.trace_shard(1, 0.5)
	assert_array(arrivals).is_equal([0, 1])
	assert_float(circle.construction_share()).is_equal(0.75)
	circle.trace_shard(1, 1.0)
	circle.finish_construction()
	circle._process(0.0)
	assert_bool(circle.is_constructed()).is_true()
	assert_float(circle.construction_time_left()).is_equal(0.0)


func test_a_failed_function_keeps_its_partial_stroke_when_sealed() -> void:
	var circle := _circle(3)
	circle.trace_shard(0, 1.0)
	circle.trace_shard(1, 0.25)
	circle.finish_construction()
	circle._process(1.0)
	circle.trace_shard(1, 1.0)
	circle.trace_shard(2, 1.0)
	assert_int(circle._arrived).is_equal(2)
	assert_float(circle._layer_progress(1)).is_equal(0.25)
	assert_bool(circle.is_constructed()).is_true()


func test_sealing_waits_for_last_stroke_and_emits_once() -> void:
	var circle := _circle(2)
	var completions: Array[int] = []
	circle.formed.connect(func() -> void: completions.append(1))
	circle.construct_shard(0)
	circle._process(0.6)
	circle.construct_shard(1)
	circle.finish_construction()
	circle._process(0.1)
	assert_bool(circle.is_constructed()).is_false()
	circle._process(MagicCircle.SHARD_DRAW_SECONDS)
	assert_bool(circle.is_constructed()).is_true()
	assert_float(circle.construction_share()).is_equal(1.0)
	circle._process(1.0)
	assert_array(completions).is_equal([1])


func test_partial_program_never_invents_unvisited_layers() -> void:
	var circle := _circle()
	circle.construct_shard(0)
	circle.finish_construction()
	circle._process(1.0)
	circle.construct_shard(1)
	assert_bool(circle.is_constructed()).is_true()
	assert_int(circle._arrived).is_equal(1)
	assert_float(circle._layer_progress(1)).is_equal(0.0)
	assert_float(circle.construction_share()).is_equal(0.25)


func test_reduced_motion_still_waits_for_each_shard() -> void:
	var circle := _circle(2)
	circle._reduced = true
	circle.construct_shard(0)
	assert_float(circle._layer_progress(0)).is_equal(1.0)
	circle._process(5.0)
	assert_int(circle._arrived).is_equal(1)
	circle.construct_shard(1)
	circle.finish_construction()
	circle._process(0.01)
	assert_bool(circle.is_constructed()).is_true()


func test_construction_clock_obeys_pause_speed_and_close() -> void:
	var circle := _circle(1)
	circle.construct_shard(0)
	circle.time_scale = 0.0
	circle._process(1.0)
	assert_float(circle._layer_progress(0)).is_equal(0.0)
	circle.time_scale = 0.5
	circle._process(MagicCircle.SHARD_DRAW_SECONDS)
	assert_float(circle._layer_progress(0)).is_between(0.4, 0.6)
	circle.close()
	circle._process(MagicCircle.CLOSE_SECONDS * 2.0 + 0.01)
	assert_bool(circle.is_queued_for_deletion()).is_true()


func test_procedural_cast_is_available_on_skins_without_the_clip() -> void:
	for slot: String in ["cast_light", "cast_heavy"]:
		var option := CosmeticRules.find(Cosmetics.catalog(), slot, "shard-weave")
		assert_bool(CosmeticRules.playable(option, [])).is_true()
		# Construction is the default (ADR-0043): an unknown id reads as it.
		assert_str(CosmeticRules.option(Cosmetics.catalog(), slot, "unknown").id).is_equal("shard-weave")
	assert_array(CosmeticRules.check(Cosmetics.catalog())).is_empty()


func test_live_carousel_restarts_after_a_construction_preview_frees_itself() -> void:
	var art: LookArt = auto_free(
		LookArt.make("cast_light", CosmeticRules.find(Cosmetics.catalog(), "cast_light", "shard-weave"))
	)
	art.size = Vector2(180, 210)
	add_child(art)
	art.set_process(false)
	art.set_live(true)
	var first := art._effect
	first.queue_free()
	await get_tree().process_frame
	art._process(0.01)
	assert_bool(is_instance_valid(art._effect)).is_true()
	assert_bool((art._effect as MagicCircle).external_construction).is_true()
	assert_int((art._effect as MagicCircle)._arrived).is_equal(0)


func test_stage_anchor_is_identical_for_different_poses_and_skins() -> void:
	var stage: BattleStage = auto_free(BattleStage.new())
	stage.size = Vector2(1200, 700)
	add_child(stage)
	await get_tree().process_frame
	stage.hero.set_preview_skin("dummy")
	await get_tree().process_frame
	var cards := CircleLayers.demo_cards(4)
	stage.hero.play("cast-slam")
	var first := stage.magic_circle(cards, "fire", 1.0, true)
	stage.hero.set_preview_skin("vesper")
	await get_tree().process_frame
	var second := stage.magic_circle(cards, "fire", 1.0, true)
	assert_vector(second.position).is_equal(first.position)
	assert_float(second.radius).is_equal(first.radius)
	assert_bool(second.external_construction).is_true()
