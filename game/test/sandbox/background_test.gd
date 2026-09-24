extends GdUnitTestSuite


func test_runs_a_sandbox_job_off_the_main_thread_while_frames_go_on() -> void:
	var frames := [0]
	var count := func() -> void: frames[0] += 1
	var tree := Engine.get_main_loop() as SceneTree
	tree.process_frame.connect(count)
	var job := SandboxJob.of(SandboxJob.PYTHON, {"main.py": "print(sum(range(10)))"}, "main.py")
	var result: SandboxResult = await Background.run(func() -> SandboxResult: return Sandbox.run(job))
	tree.process_frame.disconnect(count)
	assert_str(result.stdout).is_equal("45\n")
	assert_int(frames[0]).is_greater(0)
