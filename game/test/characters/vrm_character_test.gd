extends GdUnitTestSuite
## A VRM skin on the stage (ADR-0028): godot-vrm imports the model onto Godot's humanoid profile, and the shared move
## library (pipeline/blender/build_moves.py) plays on it, with its release timing and the palm's release point.

const CLIPS: Array[String] = [
	"idle-breathe", "cast-light", "cast-heavy", "cast-heavy-hold", "cast-heavy-end", "guard", "hurt", "death"
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
	assert_int(hero.player.get_animation("cast-heavy-hold").loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(hero.player.get_animation("cast-light").loop_mode).is_equal(Animation.LOOP_NONE)


func test_a_cast_is_timed_to_land_its_release_on_the_beat() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	add_child(hero)
	hero.play("cast-light")
	var release: float = hero.moves["cast-light"]["release"]
	# A cast without a charge window is sped up as a whole to land on a beat sooner than its own.
	hero.release_in(release / 2.0)
	assert_float(hero.player.speed_scale).is_equal_approx(2.0, 0.05)
	hero.play("cast-heavy")
	assert_float(hero.player.speed_scale).is_equal(1.0)
	# A clip without a release is never rescaled.
	hero.play("hurt")
	hero.release_in(0.2)
	assert_float(hero.player.speed_scale).is_equal(1.0)


func test_the_release_point_is_the_casting_palm() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	add_child(hero)
	# The snap: the hand raised beside her head, out to her left (toward the foes).
	hero.play("cast-light")
	var snap: Vector3 = hero.release_point()
	assert_float(snap.x).is_greater(0.15)
	assert_float(snap.y).is_between(1.1, 1.7)
	# The heavy push: the arm out in front of her and to her left (toward the foes once she stands turned on the
	# stage), at about shoulder height.
	hero.play("cast-heavy")
	var push: Vector3 = hero.release_point()
	assert_float(push.x).is_greater(0.15)
	assert_float(push.z).is_greater(0.3)
	assert_float(push.y).is_between(0.9, 1.5)
	hero.play("hurt")
	assert_object(hero.release_point()).is_null()


func test_planted_feet_follow_the_clip_on_leg_ik() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	add_child(hero)
	var iks := hero.skeleton.find_children("*", "TwoBoneIK3D", false, false)
	assert_int(iks.size()).is_equal(2)
	# A fall lets go of the floor once the body goes down.
	var facts: Dictionary = hero.moves["death"]
	hero._legs.update(facts, 0.2)
	assert_float((iks[0] as TwoBoneIK3D).influence).is_equal(1.0)
	hero._legs.update(facts, 1.5)
	assert_float((iks[0] as TwoBoneIK3D).influence).is_equal(0.0)


func test_playback_is_smooth_unless_limited_is_asked_for() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	add_child(hero)
	assert_float(hero.limited_fps()).is_equal(0.0)
	assert_int(hero.player.callback_mode_process).is_not_equal(AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)


func test_limited_animation_holds_the_pose_between_steps() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("shibu"))
	add_child(hero)
	hero.set_limited(StageCharacter.LIMITED_FPS)
	assert_int(hero.player.callback_mode_process).is_equal(AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
	hero.play("cast-light")
	var start := hero.player.current_animation_position
	hero._process(0.01)
	assert_float(hero.player.current_animation_position).is_equal(start)
	hero._process(1.0 / StageCharacter.LIMITED_FPS)
	assert_float(hero.player.current_animation_position).is_greater(start)


func test_a_snap_returns_to_the_idle_on_its_own() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("dummy"))
	add_child(hero)
	hero.play("cast-light")
	hero._hand_off("cast-light")
	assert_str(hero.current).is_equal(StageCharacter.IDLE)


func test_a_heavy_cast_holds_until_the_volley_ends() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("dummy"))
	add_child(hero)
	hero.play("cast-heavy")
	hero._hand_off("cast-heavy")
	assert_str(hero.current).is_equal("cast-heavy-hold")
	hero.end_cast()
	assert_str(hero.current).is_equal("cast-heavy-end")
	hero._hand_off("cast-heavy-end")
	assert_str(hero.current).is_equal(StageCharacter.IDLE)


func test_a_volley_over_before_the_push_lets_go_once_it_is_reached() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("dummy"))
	add_child(hero)
	hero.play("cast-heavy")
	hero.end_cast()
	assert_str(hero.current).is_equal("cast-heavy")
	hero._hand_off("cast-heavy")
	assert_str(hero.current).is_equal("cast-heavy-end")


func test_the_next_clip_fades_in_before_the_last_one_ends() -> void:
	# A fade begun after a clip has finished would rise out of the rest pose (the mixer has nothing to fade from).
	var hero: StageCharacter = auto_free(StageCharacter.create("dummy"))
	add_child(hero)
	hero.play("hurt")
	hero.player.seek(hero.player.current_animation_length - 0.1, true)
	hero._process(1.0 / 60.0)
	assert_str(hero.current).is_equal(StageCharacter.IDLE)


func test_a_long_circle_slows_only_the_charge_window() -> void:
	var hero: StageCharacter = auto_free(StageCharacter.create("dummy"))
	add_child(hero)
	hero.play("cast-heavy")
	var facts: Dictionary = hero.moves["cast-heavy"]
	var window := StageCharacter.charge_window(facts)
	var release := float(facts.release)
	var seconds := release + 0.4
	hero.release_in(seconds)
	# Before the window the gesture keeps its own speed; inside it, the window stretches to fill the wait.
	assert_float(hero.player.speed_scale).is_equal(1.0)
	var own := window.x + (release - window.y)
	assert_float(hero._charge_speed).is_equal_approx((window.y - window.x) / (seconds - own), 0.001)
	hero.player.seek(window.x + 0.05, true)
	hero._process(1.0 / 60.0)
	assert_float(hero.player.speed_scale).is_equal_approx(hero._charge_speed, 0.001)
