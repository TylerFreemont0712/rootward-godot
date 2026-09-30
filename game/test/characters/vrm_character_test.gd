extends GdUnitTestSuite
## A VRM skin on the stage (ADR-0028): godot-vrm imports the model onto Godot's humanoid profile, and the shared move
## library (pipeline/blender/build_moves.py) plays on it, with its release timing and the palm's release point.

const CLIPS: Array[String] = [
	"idle-breathe", "cast-light", "cast-heavy", "channel", "windup", "guard", "hurt", "victory", "death"
]


func test_a_vrm_skin_has_every_clip_on_a_humanoid_skeleton() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	assert_bool(hero.has_model()).is_true()
	assert_bool(hero.is_vrm()).is_true()
	for clip in CLIPS:
		assert_bool(hero.player.has_animation(clip)).override_failure_message("missing clip " + clip).is_true()
	for bone: String in ["Hips", "LeftUpperArm", "LeftHand", "RightLowerLeg", "Head"]:
		assert_int(hero.skeleton.find_bone(bone)).override_failure_message("missing bone " + bone).is_greater_equal(0)
	# The face expressions come with the model, on its own player.
	for expression: String in ["happy", "angry", "sad", "blink"]:
		assert_bool(hero.face.has_animation(expression)).is_true()


func test_the_clips_drive_the_skeleton_bones() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	var clip := hero.player.get_animation("cast-heavy")
	var paths: Array[String] = []
	for track in clip.get_track_count():
		paths.append(String(clip.track_get_path(track)))
	assert_bool("%GeneralSkeleton:LeftUpperArm" in paths).is_true()
	assert_bool("%GeneralSkeleton:Hips" in paths).is_true()


func test_loops_follow_the_library() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	assert_int(hero.player.get_animation("idle-breathe").loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(hero.player.get_animation("channel").loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(hero.player.get_animation("cast-light").loop_mode).is_equal(Animation.LOOP_NONE)


func test_a_cast_is_timed_to_land_its_release_on_the_beat() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	add_child(hero)
	hero.play("cast-light")
	var release: float = hero.moves["cast-light"]["release"]
	hero.release_in(release / 2.0)
	assert_float(hero.player.speed_scale).is_equal_approx(2.0, 0.05)
	hero.play("cast-heavy")
	assert_float(hero.player.speed_scale).is_equal(1.0)
	# A clip without a release is never rescaled.
	hero.play("hurt")
	hero.release_in(0.2)
	assert_float(hero.player.speed_scale).is_equal(1.0)


func test_the_release_point_is_the_outstretched_palm() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	add_child(hero)
	hero.play("cast-light")
	var point: Vector3 = hero.release_point()
	# Out to her left (toward the foes), in front of her, about head height.
	assert_float(point.x).is_greater(0.3)
	assert_float(point.z).is_greater(0.05)
	assert_float(point.y).is_between(1.0, 1.7)
	hero.play("hurt")
	assert_object(hero.release_point()).is_null()
