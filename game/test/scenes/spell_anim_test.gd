extends GdUnitTestSuite
## The pipeline's spell animations (ADR-0014): every sheet loads with facts that fit its picture, and one plays to its
## blow and frees itself.

const ROOT := "res://assets/fx/spells/"


func _ids() -> Array[String]:
	var ids: Array[String] = []
	for name in DirAccess.get_files_at(ROOT):
		if name.ends_with(".json"):
			ids.append(name.get_basename())
	return ids


func test_every_sheet_fits_its_facts() -> void:
	var ids := _ids()
	assert_int(ids.size()).is_greater_equal(8)
	for id in ids:
		var facts := SpellAnim.facts_of(id)
		assert_bool(facts.is_empty()).override_failure_message("%s did not load" % id).is_false()
		var texture: Texture2D = facts.texture
		var rows := ceili(float(facts.frames) / float(facts.columns))
		assert_int(texture.get_width()).override_failure_message(id).is_equal(int(facts.columns) * int(facts.size[0]))
		assert_int(texture.get_height()).override_failure_message(id).is_equal(rows * int(facts.size[1]))


func test_a_blow_lands_and_the_animation_goes() -> void:
	var holder := auto_free(Node2D.new()) as Node2D
	add_child(holder)
	var anim := SpellAnim.play(holder, "hit-compile", Vector2(100, 100), "fire", 1.0)
	assert_object(anim).is_not_null()
	var landed := [false]
	anim.impact.connect(func() -> void: landed[0] = true)
	var steps := 0
	while is_instance_valid(anim) and steps < 400:
		anim._process(1.0 / 30.0)
		steps += 1
		await get_tree().process_frame
	assert_bool(landed[0]).is_true()
	assert_bool(is_instance_valid(anim)).is_false()


func test_a_missing_animation_is_null_not_an_error() -> void:
	var holder := auto_free(Node2D.new()) as Node2D
	assert_object(SpellAnim.play(holder, "no-such-spell", Vector2.ZERO)).is_null()
