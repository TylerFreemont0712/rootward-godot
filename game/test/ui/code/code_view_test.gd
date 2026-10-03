extends GdUnitTestSuite
## Spellforge construction follows the function body, including repeated slots and skipped measured returns.


func _view(completed: int, failed := false) -> CodeView:
	var steps: Array[Dictionary] = []
	for index in completed:
		steps.append({"work": 1, "bolts": [], "outcome": {}})
	var run := {"base": {"bolts": []}, "steps": steps}
	if failed:
		run.misfire = {"shard": "fork", "reason": "failed", "line": 3}
	else:
		run.result = {}
	var view: CodeView = auto_free(
		CodeView.create(
			"python",
			{"name": "Trace", "shards": ["fork", "fork", "fork"]},
			ContentLoader.load_shardrun().catalog.shards,
			4,
			run,
			"explore",
			"fast"
		)
	)
	add_child(view)
	return view


func _circle(view: CodeView) -> MagicCircle:
	var circle: MagicCircle = auto_free(MagicCircle.cast(self, Vector2(100, 100), 1, "none", 60.0, "", 1.0, true))
	circle.external_construction = true
	circle.use_plan(CircleLayers.plan(CircleLayers.demo_cards(3)))
	circle.set_process(false)
	view.shard_progress.connect(circle.trace_shard)
	return circle


func test_a_body_line_constructs_a_partial_layer_before_the_return() -> void:
	var view := _view(3)
	var circle := _circle(view)
	var resolved: Array[int] = []
	view.shard_resolved.connect(func(index: int) -> void: resolved.append(index))
	for index in view.played.size():
		var frame := view.played[index]
		view._show(index)
		if int(frame.line) in (view.source.functions.fork.body as Array):
			break
	assert_int(circle._arrived).is_equal(1)
	assert_float(circle._layer_progress(0)).is_between(0.01, 0.99)
	assert_array(resolved).is_empty()
	var written := circle.construction_share()
	circle._process(20.0)
	assert_float(circle.construction_share()).is_equal(written)


func test_repeated_functions_get_distinct_layers_and_complete_in_source_order() -> void:
	var view := _view(3)
	var circle := _circle(view)
	var resolved: Array[int] = []
	view.shard_resolved.connect(func(index: int) -> void: resolved.append(index))
	for index in view.played.size():
		view._show(index)
	assert_array(resolved).is_equal([0, 1, 2])
	assert_int(circle._arrived).is_equal(3)
	assert_float(circle.construction_share()).is_equal(1.0)


func test_skip_completes_only_measured_layers_before_a_failure() -> void:
	var view := _view(1, true)
	var circle := _circle(view)
	view.mode = "cast"
	view.skip()
	view.skip()
	assert_int(circle._arrived).is_equal(1)
	assert_float(circle._layer_progress(0)).is_equal(1.0)
	assert_float(circle._layer_progress(1)).is_equal(0.0)
