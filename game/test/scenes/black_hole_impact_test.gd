extends GdUnitTestSuite
## The black-hole impact (docs/LEGENDARY_LOOKS.md, "The black-hole impact"): the impact and finish signals, the landing
## that is released even when the node leaves first, the clock and its time_scale, the reduced timeline, the node
## keeping its global point under its parent, the quad's geometry, the screen copy, and the shader's uniforms matching
## LegendaryLook.impact_style.

const FULL := 1.2
const REDUCED := 0.6
const RADIUS := 120.0
const SHADER_PATH := "res://scenes/shardrun/fight/black_hole.gdshader"
## The looks the uniforms are checked against: each role, a signature card, and a role with a signature card.
const LOOKS: Array[Dictionary] = [
	{"role": "strike", "card": ""},
	{"role": "guard", "card": ""},
	{"role": "source", "card": ""},
	{"role": "shape", "card": ""},
	{"role": "order", "card": ""},
	{"role": "import", "card": ""},
	{"role": "", "card": "radix-sort"},
	{"role": "", "card": "quickselect"},
	{"role": "guard", "card": "memo-ward"},
]

var _saved_reduced := false


func before_test() -> void:
	_saved_reduced = Settings.reduced_motion
	Settings.reduced_motion = false


func after_test() -> void:
	Settings.reduced_motion = _saved_reduced


func _stage() -> Node2D:
	var stage: Node2D = auto_free(Node2D.new())
	add_child(stage)
	return stage


## A Control parent, as the fight's effects layer is.
func _layer() -> Control:
	var layer: Control = auto_free(Control.new())
	add_child(layer)
	return layer


## An impact played on a fresh stage, with its own clock stopped so a test steps it by hand.
func _play(look: Dictionary = {"role": "strike", "card": "radix-sort"}) -> BlackHoleImpact:
	var hole := BlackHoleImpact.play(_stage(), Vector2(400, 300), RADIUS, look)
	hole.set_process(false)
	return hole


func _child_of(node: Node, type: Variant) -> Node:
	for child: Node in node.get_children():
		if is_instance_of(child, type):
			return child
	return null


## The names of the shader's uniform declarations, read from its source (the second word of each `uniform` line).
func _declared_uniforms() -> Array[String]:
	var names: Array[String] = []
	for line: String in _shader_source().split("\n"):
		var words := line.strip_edges().split(" ", false)
		if words.size() >= 3 and words[0] == "uniform":
			names.append(words[2])
	return names


## Waits for a hole's landing as a caller does (`await hole.landed()`), and records that it was released.
func _wait_for_landing(hole: BlackHoleImpact, released: Array[int]) -> void:
	await hole.landed()
	released.append(1)


## Waits for a hole's landing, then adds a child to the stage, and records how many children the stage has then.
func _add_child_on_landing(hole: BlackHoleImpact, stage: Node2D, counts: Array[int]) -> void:
	await hole.landed()
	stage.add_child(Node.new())
	counts.append(stage.get_child_count())


## Awaits BlackHoleImpact.landed_of, and records that it returned.
func _run_landed_of(hole: BlackHoleImpact, done: Array[int]) -> void:
	await BlackHoleImpact.landed_of(hole)
	done.append(1)


## Awaits a hole's landing as a caller does (`await hole.landed()`), and records its progress then (-1 if it is gone).
func _record_landing(hole: BlackHoleImpact, landed_at: Array[float]) -> void:
	await hole.landed()
	landed_at.append(hole.progress if is_instance_valid(hole) else -1.0)


## The shader's source, read as text.
func _shader_source() -> String:
	# LEARN: a headless run has no GPU and draws nothing, so the shader is checked as text: its constants, and the one
	# place the shock ring is drawn. A pixel check would need a renderer that the test run does not have.
	return FileAccess.get_file_as_string(SHADER_PATH)


## A shader constant's value: the number on its `const float NAME = value;` line.
func _shader_constant(name: String) -> float:
	var declared := RegEx.new()
	declared.compile("const float %s = ([0-9.]+);" % name)
	var found := declared.search(_shader_source())
	return float(found.get_string(1)) if found != null else NAN


## True when the shock ring is drawn in one place only, inside `if (!reduced)`, so reduced motion draws none of it.
func _shader_gates_the_shock_ring() -> bool:
	var gated := RegEx.new()
	gated.compile("if \\(!reduced\\) \\{\\s*glow \\+= shock_light\\(r, ang, p\\) \\* fade;\\s*\\}")
	var source := _shader_source()
	return gated.search(source) != null and source.count("shock_light(r, ang, p)") == 1


## True when the inflow arms are drawn in one place only, inside `if (arms > 0 && !reduced)`, so reduced motion
## draws none of them.
func _shader_gates_the_arms() -> bool:
	var gated := RegEx.new()
	gated.compile("if \\(arms > 0 && !reduced\\) \\{\\s*glow \\+= arm_light\\(ta, r, p\\) \\* fade;\\s*\\}")
	var source := _shader_source()
	return gated.search(source) != null and source.count("arm_light(ta, r, p)") == 1


func test_impact_fires_once_at_a_quarter_of_the_timeline() -> void:
	var hole := _play()
	var fired: Array[float] = []
	hole.impact.connect(func() -> void: fired.append(hole.progress))
	# A quarter of the 1.2 s timeline is 0.3 s: just short of that nothing fires, just past it the blow lands, once.
	hole.advance(FULL * 0.25 - 0.01)
	assert_int(fired.size()).is_equal(0)
	hole.advance(0.02)
	assert_int(fired.size()).is_equal(1)
	assert_float(fired[0]).is_greater_equal(0.25)
	assert_float(fired[0]).is_less(0.26)
	hole.advance(FULL)
	assert_int(fired.size()).is_equal(1)


func test_finished_fires_once_at_the_end_and_the_node_frees_itself() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	hole.set_process(false)
	var finished_count: Array[int] = []
	hole.finished.connect(func() -> void: finished_count.append(1))
	hole.advance(FULL * 0.5)
	assert_int(finished_count.size()).is_equal(0)
	hole.advance(FULL)
	assert_int(finished_count.size()).is_equal(1)
	hole.advance(FULL)
	assert_int(finished_count.size()).is_equal(1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(hole)).is_false()
	assert_int(stage.get_child_count()).is_equal(0)


func test_the_reduced_timeline_is_six_tenths_of_a_second_and_the_blow_lands_at_0_15() -> void:
	Settings.reduced_motion = true
	var hole := _play()
	assert_float(hole.duration).is_equal_approx(REDUCED, 0.0001)
	var fired: Array[int] = []
	hole.impact.connect(func() -> void: fired.append(1))
	hole.advance(0.149)
	assert_int(fired.size()).is_equal(0)
	hole.advance(0.002)
	assert_int(fired.size()).is_equal(1)
	var done: Array[int] = []
	hole.finished.connect(func() -> void: done.append(1))
	hole.advance(0.44)
	assert_int(done.size()).is_equal(0)
	hole.advance(0.02)
	assert_int(done.size()).is_equal(1)
	assert_bool(hole.shader_material().get_shader_parameter("reduced")).is_true()
	var copy := _child_of(hole, BackBufferCopy) as BackBufferCopy
	assert_int(copy.copy_mode).is_equal(BackBufferCopy.COPY_MODE_DISABLED)


func test_the_full_timeline_is_one_point_two_seconds_and_reads_the_screen() -> void:
	Settings.reduced_motion = false
	var hole := _play()
	assert_float(hole.duration).is_equal_approx(FULL, 0.0001)
	assert_bool(hole.shader_material().get_shader_parameter("reduced")).is_false()
	var copy := _child_of(hole, BackBufferCopy) as BackBufferCopy
	assert_int(copy.copy_mode).is_equal(BackBufferCopy.COPY_MODE_RECT)


func test_progress_drives_the_shader_uniform() -> void:
	var hole := _play()
	hole.advance(FULL * 0.5)
	assert_float(hole.shader_material().get_shader_parameter("progress")).is_equal_approx(0.5, 0.0001)


func test_landed_is_released_at_the_impact_as_the_impact_signal_is() -> void:
	var hole := _play()
	var order: Array[String] = []
	hole.impact.connect(func() -> void: order.append("impact"))
	hole.landed().connect(func() -> void: order.append("landed"))
	hole.advance(FULL * 0.2)
	assert_array(order).is_empty()
	hole.advance(FULL * 0.1)
	assert_array(order).is_equal(["impact", "landed"])
	hole.advance(FULL)
	assert_array(order).is_equal(["impact", "landed"])


func test_an_awaiter_is_released_when_the_node_leaves_before_its_impact() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	hole.set_process(false)
	var released: Array[int] = []
	_wait_for_landing(hole, released)
	hole.queue_free()
	# Two frames: the node leaves at the end of the first, and its release runs after that removal.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(released).is_equal([1])
	assert_int(stage.get_child_count()).is_equal(0)


func test_a_waiter_released_by_a_removal_may_add_a_child_to_the_parent() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	hole.set_process(false)
	var counts: Array[int] = []
	_add_child_on_landing(hole, stage, counts)
	# remove_child runs the hole's exit while the stage is busy with the removal: the release must wait for that to end.
	stage.remove_child(hole)
	hole.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(counts).is_equal([1])


func test_landed_of_waits_for_the_impact_and_returns_at_once_after_it() -> void:
	var hole := _play()
	var done: Array[int] = []
	_run_landed_of(hole, done)
	hole.advance(FULL * 0.2)
	assert_array(done).is_empty()
	hole.advance(FULL * 0.1)
	assert_array(done).is_equal([1])
	# The blow has landed, so a later caller is not made to wait for a release that has already been sent.
	_run_landed_of(hole, done)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(done).is_equal([1, 1])


func test_the_quad_is_5_0_radii_across_and_centred_on_the_point() -> void:
	var hole := _play({"role": "", "card": ""})
	assert_float(hole.position.x).is_equal_approx(400.0, 0.001)
	assert_float(hole.position.y).is_equal_approx(300.0, 0.001)
	var quad := _child_of(hole, ColorRect) as ColorRect
	assert_float(quad.size.x).is_equal_approx(5.0 * RADIUS, 0.001)
	assert_float(quad.size.y).is_equal_approx(5.0 * RADIUS, 0.001)
	assert_float(quad.position.x).is_equal_approx(-2.5 * RADIUS, 0.001)
	assert_float(quad.position.y).is_equal_approx(-2.5 * RADIUS, 0.001)
	assert_bool(quad.material == hole.shader_material()).is_true()


func test_the_hole_sits_on_its_global_point_under_an_offset_parent() -> void:
	var stage := _stage()
	stage.position = Vector2(100, 50)
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {})
	hole.set_process(false)
	# `at` is global: the node's position is that point less the parent's offset, and its global position is the point.
	assert_bool(hole.position.is_equal_approx(Vector2(300, 250))).is_true()
	assert_bool(hole.global_position.is_equal_approx(Vector2(400, 300))).is_true()


func test_the_hole_sits_on_its_global_point_under_a_scaled_control_parent() -> void:
	var layer := _layer()
	layer.position = Vector2(-40, 20)
	layer.scale = Vector2(2, 2)
	var hole := BlackHoleImpact.play(layer, Vector2(400, 300), RADIUS, {})
	hole.set_process(false)
	# The layer maps a local point p to (-40, 20) + 2 p, so the global (400, 300) is the local (220, 140).
	assert_bool(hole.position.is_equal_approx(Vector2(220, 140))).is_true()
	assert_bool(hole.global_position.is_equal_approx(Vector2(400, 300))).is_true()


func test_a_moving_parent_keeps_the_hole_on_its_point() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "guard", "card": ""})
	stage.position = Vector2(-30, 70)
	# Two frames: the node's _process runs in the first one, and moves it there before that frame draws.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(hole.global_position.is_equal_approx(Vector2(400, 300))).is_true()


func test_a_frozen_clock_still_follows_its_parent_and_refits_its_copy() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "guard", "card": ""})
	hole.set_process(false)
	# A still preview holds its frame with its clock stopped, and its card keeps running: it must follow and refit.
	hole.advance(FULL * 0.6)
	hole.time_scale = 0.0
	stage.position = Vector2(-30, 70)
	hole._process(1.0)
	var copy := _child_of(hole, BackBufferCopy) as BackBufferCopy
	var quad := _child_of(hole, ColorRect) as ColorRect
	assert_bool(hole.global_position.is_equal_approx(Vector2(400, 300))).is_true()
	assert_bool(copy.rect.is_equal_approx(quad.get_global_rect())).is_true()
	assert_float(hole.progress).is_equal_approx(0.6, 0.0001)


func test_time_scale_multiplies_the_frame_time_as_a_spell_anims_does() -> void:
	var hole := _play()
	assert_float(hole.time_scale).is_equal(1.0)
	var fired: Array[int] = []
	hole.impact.connect(func() -> void: fired.append(1))
	# Half speed: 0.4 s of frame time moves the clock 0.2 s, which is not yet a quarter of the 1.2 s timeline.
	hole.time_scale = 0.5
	hole._process(0.4)
	assert_float(hole.progress).is_equal_approx(0.2 / FULL, 0.0001)
	assert_int(fired.size()).is_equal(0)
	hole._process(0.4)
	assert_int(fired.size()).is_equal(1)
	# BattleStage._keep_time's by-hand step calls _process with seconds / tempo, so the clock moves by `seconds`.
	hole.time_scale = 0.25
	hole._process(0.4 / 0.25)
	assert_float(hole.progress).is_equal_approx(0.8 / FULL, 0.0001)
	# A frozen clock holds its frame however much frame time passes.
	hole.time_scale = 0.0
	hole._process(10.0)
	assert_float(hole.progress).is_equal_approx(0.8 / FULL, 0.0001)
	assert_int(fired.size()).is_equal(1)


func test_the_screen_copy_covers_the_quad_in_viewport_coordinates() -> void:
	var stage := _stage()
	stage.position = Vector2(100, 50)
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	hole.set_process(false)
	var copy := _child_of(hole, BackBufferCopy) as BackBufferCopy
	var quad := _child_of(hole, ColorRect) as ColorRect
	# The point is global, so in viewport coordinates it is (400, 300) itself, and the 600 px quad is centred on it.
	assert_float(copy.rect.position.x).is_equal_approx(400.0 - 300.0, 0.001)
	assert_float(copy.rect.position.y).is_equal_approx(300.0 - 300.0, 0.001)
	assert_float(copy.rect.size.x).is_equal_approx(600.0, 0.001)
	assert_float(copy.rect.size.y).is_equal_approx(600.0, 0.001)
	assert_bool(copy.rect.is_equal_approx(quad.get_global_rect())).is_true()


func test_the_screen_copy_follows_the_stage_when_it_moves() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	var copy := _child_of(hole, BackBufferCopy) as BackBufferCopy
	var quad := _child_of(hole, ColorRect) as ColorRect
	stage.position = Vector2(-30, 70)
	# Two frames: the node's _process runs in the first one, and refits the copy before that frame draws.
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(copy.rect.is_equal_approx(quad.get_global_rect())).is_true()


func test_the_uniforms_match_the_impact_style_for_every_look() -> void:
	for look: Dictionary in LOOKS:
		var hole := BlackHoleImpact.play(_stage(), Vector2.ZERO, RADIUS, look)
		hole.set_process(false)
		var style := LegendaryLook.impact_style(look["role"], look["card"])
		var mat := hole.shader_material()
		assert_int(style.size()).is_equal(BlackHoleImpact.STYLE_UNIFORMS.size())
		for key: String in style:
			var message := "%s for %s" % [key, str(look)]
			assert_that(mat.get_shader_parameter(key)).override_failure_message(message).is_equal(style[key])
		assert_float(mat.get_shader_parameter("radius_uv")).is_equal_approx(1.0 / 5.0, 0.0001)


func test_a_look_with_no_role_or_card_plays_the_base_impact() -> void:
	var hole := BlackHoleImpact.play(_stage(), Vector2.ZERO, RADIUS, {})
	hole.set_process(false)
	var style := LegendaryLook.impact_style("", "")
	assert_bool(hole.shader_material().get_shader_parameter("jets")).is_equal(style["jets"])
	assert_int(hole.shader_material().get_shader_parameter("rings")).is_equal(1)


func test_every_uniform_the_node_sets_is_declared_by_the_shader() -> void:
	var declared := _declared_uniforms()
	assert_bool(FileAccess.file_exists(SHADER_PATH)).is_true()
	for key: String in BlackHoleImpact.STYLE_UNIFORMS + ["progress", "radius_uv", "reduced", "screen_tex"]:
		assert_bool(declared.has(key)).override_failure_message("%s is not declared" % key).is_true()


func test_no_signal_is_emitted_before_the_node_is_in_the_tree() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.new()
	var emitted: Array[String] = []
	hole.impact.connect(func() -> void: emitted.append("impact"))
	hole.finished.connect(func() -> void: emitted.append("finished"))
	# Out of the tree the clock does not run, however far it is asked to go, so nothing is emitted.
	hole.advance(FULL * 2.0)
	assert_float(hole.progress).is_equal(0.0)
	assert_array(emitted).is_empty()
	# Entering the tree (add_child, then _ready) emits nothing either.
	stage.add_child(hole)
	assert_array(emitted).is_empty()
	hole.set_process(false)
	hole.advance(FULL * 0.3)
	assert_array(emitted).is_equal(["impact"])
	hole.advance(FULL)
	assert_array(emitted).is_equal(["impact", "finished"])


func test_play_returns_the_node_in_the_tree_before_any_of_its_timeline_runs() -> void:
	var hole := BlackHoleImpact.play(_stage(), Vector2(400, 300), RADIUS, {})
	assert_bool(hole.is_inside_tree()).is_true()
	# The timeline has not moved, so play() emitted nothing: a signal needs the clock to have advanced.
	assert_float(hole.progress).is_equal(0.0)
	hole.set_process(false)


func test_the_clock_plays_the_whole_timeline_in_real_time_and_frees_the_node() -> void:
	var hole := BlackHoleImpact.play(_stage(), Vector2(400, 300), RADIUS, {"role": "guard", "card": ""})
	var frame_at_play := Engine.get_process_frames()
	var impact_progress: Array[float] = []
	var impact_frames: Array[int] = []
	hole.impact.connect(func() -> void: impact_progress.append(hole.progress))
	hole.impact.connect(func() -> void: impact_frames.append(Engine.get_process_frames() - frame_at_play))
	await await_signal_on(hole, "finished", [], 4000)
	assert_int(impact_progress.size()).is_equal(1)
	assert_float(impact_progress[0]).is_greater_equal(0.25)
	# The blow comes from _process, so it lands at least one frame after play() returned.
	assert_int(impact_frames[0]).is_greater(0)


func test_the_hole_draws_at_z_index_1_from_its_creation() -> void:
	var bare: BlackHoleImpact = auto_free(BlackHoleImpact.new())
	assert_int(bare.z_index).is_equal(1)
	var hole := _play()
	assert_int(hole.z_index).is_equal(1)


func test_reduced_motion_sets_the_uniform_that_drops_the_shock_ring() -> void:
	Settings.reduced_motion = true
	var hole := _play()
	assert_bool(hole.shader_material().get_shader_parameter("reduced")).is_true()
	# The shader draws the ring in one place, inside `if (!reduced)`, so the uniform set above drops it.
	assert_bool(_shader_gates_the_shock_ring()).is_true()


func test_reduced_motion_zeroes_the_arms_uniform_and_the_shader_draws_no_arm_streak() -> void:
	Settings.reduced_motion = true
	# The source look has four arms, so the zero below is a change from impact_style.
	assert_int(LegendaryLook.impact_style("source", "")["arms"]).is_equal(4)
	for look: Dictionary in LOOKS:
		var hole := BlackHoleImpact.play(_stage(), Vector2.ZERO, RADIUS, look)
		hole.set_process(false)
		var arms: Variant = hole.shader_material().get_shader_parameter("arms")
		assert_int(arms).override_failure_message("arms for %s" % str(look)).is_equal(0)
	# What the shader does at arms = 0: its one arm draw sits behind `arms > 0 && !reduced`. That is false, so arm_light
	# is never evaluated and no streak is added to glow. A headless run draws nothing, so the shader is read as text.
	assert_bool(_shader_gates_the_arms()).is_true()


func test_full_motion_keeps_the_arms_uniform_from_impact_style() -> void:
	Settings.reduced_motion = false
	# impact_style gives the source look four arms and the import look two, and full motion keeps both.
	for role: String in ["source", "import"]:
		var hole := BlackHoleImpact.play(_stage(), Vector2.ZERO, RADIUS, {"role": role, "card": ""})
		hole.set_process(false)
		var style := LegendaryLook.impact_style(role, "")
		assert_int(style["arms"]).is_greater(0)
		var arms: Variant = hole.shader_material().get_shader_parameter("arms")
		assert_int(arms).override_failure_message(role).is_equal(style["arms"])
		assert_bool(hole.shader_material().get_shader_parameter("reduced")).is_false()


func test_reduced_motion_changes_only_the_arms_and_keeps_the_other_style_uniforms() -> void:
	# The static features (digits, split, cells, scanlines) keep their impact_style values under reduced motion.
	Settings.reduced_motion = true
	for look: Dictionary in LOOKS:
		var hole := BlackHoleImpact.play(_stage(), Vector2.ZERO, RADIUS, look)
		hole.set_process(false)
		var style := LegendaryLook.impact_style(look["role"], look["card"])
		var mat := hole.shader_material()
		for key: String in BlackHoleImpact.STYLE_UNIFORMS:
			if key != "arms":
				var message := "%s for %s" % [key, str(look)]
				assert_that(mat.get_shader_parameter(key)).override_failure_message(message).is_equal(style[key])


func test_the_black_core_is_0_42_of_the_disc_and_the_ring_and_jets_reach_2_4_and_1_9() -> void:
	assert_float(_shader_constant("HORIZON")).is_equal_approx(0.42, 0.0001)
	assert_float(_shader_constant("SHOCK_REACH")).is_equal_approx(2.4, 0.0001)
	assert_float(_shader_constant("JET_REACH")).is_equal_approx(1.9, 0.0001)


func test_both_reaches_are_in_disc_radii_and_lie_inside_the_quad() -> void:
	var hole := _play({"role": "", "card": ""})
	# The shader measures q = (UV - 0.5) / radius_uv, so one unit of q is one disc radius; the quad is 5.0 of them.
	assert_bool(_shader_source().contains("vec2 q = (UV - 0.5) / radius_uv;")).is_true()
	var radius_uv := float(hole.shader_material().get_shader_parameter("radius_uv"))
	assert_float(radius_uv * BlackHoleImpact.QUAD_RADII).is_equal_approx(1.0, 0.0001)
	var edge := _shader_constant("QUAD_EDGE")
	assert_float(edge).is_equal_approx(BlackHoleImpact.QUAD_RADII * 0.5, 0.0001)
	assert_bool(_shader_constant("SHOCK_REACH") < edge).is_true()
	assert_bool(_shader_constant("JET_REACH") < edge).is_true()


func test_awaiting_landed_right_after_play_returns_at_the_impact() -> void:
	var hole := BlackHoleImpact.play(_stage(), Vector2(400, 300), RADIUS, {"role": "guard", "card": ""})
	var landed_at: Array[float] = []
	_record_landing(hole, landed_at)
	# The clock runs from _process in real time, and the blow lands at 0.3 s: a 4 s bound is far past it.
	var started := Time.get_ticks_msec()
	while landed_at.is_empty() and Time.get_ticks_msec() - started < 4000:
		await get_tree().process_frame
	assert_int(landed_at.size()).is_equal(1)
	assert_float(landed_at[0]).is_greater_equal(0.25)


func test_an_immediate_free_before_the_impact_still_releases_the_waiter() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	hole.set_process(false)
	var released: Array[int] = []
	_wait_for_landing(hole, released)
	stage.remove_child(hole)
	hole.free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(released).is_equal([1])


func test_landed_is_released_once_even_if_the_node_leaves_after_its_impact() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	hole.set_process(false)
	var released: Array[int] = []
	_wait_for_landing(hole, released)
	hole.advance(FULL * 0.3)
	assert_array(released).is_equal([1])
	stage.remove_child(hole)
	hole.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(released).is_equal([1])


func test_landed_of_returns_at_once_after_the_impact_without_waiting_a_frame() -> void:
	var hole := _play()
	hole.advance(FULL * 0.3)
	var frame := Engine.get_process_frames()
	var done: Array[int] = []
	_run_landed_of(hole, done)
	# Both hold: the caller ran on at once, and no frame went by while it did.
	assert_array(done).is_equal([1])
	assert_int(Engine.get_process_frames()).is_equal(frame)


func test_landed_of_returns_at_once_after_an_early_removal() -> void:
	var stage := _stage()
	var hole := BlackHoleImpact.play(stage, Vector2(400, 300), RADIUS, {"role": "", "card": ""})
	hole.set_process(false)
	stage.remove_child(hole)
	var done: Array[int] = []
	_run_landed_of(hole, done)
	assert_array(done).is_equal([1])
	auto_free(hole)
