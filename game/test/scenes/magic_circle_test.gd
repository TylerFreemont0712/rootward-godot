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
