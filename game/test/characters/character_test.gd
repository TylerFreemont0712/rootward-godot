extends GdUnitTestSuite
## The character export (pipeline/blender/export_character.py) arrives in Godot whole, and a character without a model
## is simply empty.


func test_emberfox_imports_with_her_clips_bones_and_colour() -> void:
	var fox: StageCharacter = auto_free(StageCharacter.create("emberfox"))
	assert_bool(fox.has_model()).is_true()
	var clips := fox.player.get_animation_list()
	for clip: String in ["idle-breathe", "idle-fidget", "windup", "channel", "cast-light", "cast-sigil", "cast-heavy"]:
		assert_bool(clip in clips).override_failure_message("missing clip " + clip).is_true()
	for clip: String in ["guard", "hurt", "victory", "death"]:
		assert_bool(clip in clips).override_failure_message("missing clip " + clip).is_true()
	for bone: String in ["mixamorig_Hips", "mixamorig_RightHand", "Tail1", "Tail5", "LeftEar", "RightEar"]:
		assert_int(fox.skeleton.find_bone(bone)).override_failure_message("missing bone " + bone).is_greater_equal(0)
	assert_object(fox.skeleton.get_node_or_null("Springs")).is_not_null()
	assert_int(fox.materials.size()).is_greater(0)
	assert_object(fox.materials[0].get_shader_parameter("drawing")).is_not_null()
	var body := fox.model.find_child("Body", true, false) as MeshInstance3D
	var colours: PackedColorArray = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var masked := 0
	for colour in colours:
		if colour.a > 0.5:
			masked += 1
	# The drawing's mask (the face and front details) rides in the vertex colour's alpha.
	assert_int(masked).is_greater(1000)


func test_idle_loops_and_casts_do_not() -> void:
	var fox: StageCharacter = auto_free(StageCharacter.create("emberfox"))
	assert_int(fox.player.get_animation("idle-breathe").loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(fox.player.get_animation("cast-light").loop_mode).is_equal(Animation.LOOP_NONE)


func test_a_character_without_a_model_is_empty_but_safe() -> void:
	var nobody: StageCharacter = auto_free(StageCharacter.create("nobody"))
	assert_bool(nobody.has_model()).is_false()
	nobody.play("cast-light")
	nobody.set_flash(Color.WHITE)
