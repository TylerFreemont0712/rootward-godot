extends GdUnitTestSuite
## Run remakes without the GPU: a fake pipeline script stands in for scripts/world.sh, in a temporary folder with the
## queue, the log and the specs. The real pipeline and the player's user://studio/ are never touched.

const TEST_ROOT := "user://studio_test/remakes"
const FAKE := """#!/usr/bin/env bash
echo "blockout $2"
echo "restyle $2"
echo "cut $2"
exit $1
"""

var remakes: StudioRemakes
var _root := ""
var _made: Array[String] = []
var _failed: Array[String] = []
var _lines: Array[String] = []
var _done := false


func before_test() -> void:
	_root = TEST_ROOT.path_join(str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(_root)
	var script := FileAccess.open(_root.path_join("fake.sh"), FileAccess.WRITE)
	script.store_string(FAKE)
	script.close()
	remakes = auto_free(StudioRemakes.new()) as StudioRemakes
	remakes.queue_path = _root.path_join("remakes.json")
	remakes.log_path = _root.path_join("remakes.log")
	remakes.objects_dir = ProjectSettings.globalize_path(_root.path_join("objects"))
	_arguments("0")
	remakes.made_check = func(id: String) -> bool: return id == "barrel-2x1"
	remakes.finished.connect(func(made: Array[String], failed: Array[String]) -> void:
		_made = made
		_failed = failed
		_done = true
	)
	remakes.progress.connect(func(line: String) -> void: _lines.append(line))
	_made = []
	_failed = []
	_lines = []
	_done = false
	add_child(remakes)


func after_test() -> void:
	OS.move_to_trash(ProjectSettings.globalize_path(_root))


func _arguments(code: String) -> void:
	remakes.program = "bash"
	remakes.arguments = PackedStringArray([ProjectSettings.globalize_path(_root.path_join("fake.sh")), code])


func _wait() -> void:
	for frame: int in 600:
		if _done:
			return
		await get_tree().process_frame
		await get_tree().create_timer(0.01).timeout


func test_a_run_writes_the_specs_runs_the_pipeline_and_marks_what_it_made() -> void:
	remakes.request("barrel-2x1", "barrel", Vector2i(2, 1), "// spec\n{}\n")
	assert_array(remakes.waiting()).is_equal(["barrel-2x1"])
	assert_bool(remakes.run()).is_true()
	assert_str(StudioRemake.state_of(remakes.queue, "barrel-2x1")).is_equal(StudioRemake.RUNNING)
	await _wait()
	assert_bool(_done).is_true()
	assert_array(_made).is_equal(["barrel-2x1"])
	assert_array(_failed).is_empty()
	assert_array(_lines).contains(["blockout barrel-2x1", "cut barrel-2x1"])
	assert_str(StudioRemake.state_of(remakes.queue, "barrel-2x1")).is_equal(StudioRemake.DONE)
	assert_str(FileAccess.get_file_as_string(remakes.objects_dir.path_join("barrel-2x1.jsonc"))).is_equal("// spec\n{}\n")
	assert_array(remakes.waiting()).is_empty()
	# The queue was saved: a new runner reads it back.
	var again := auto_free(StudioRemakes.new()) as StudioRemakes
	again.queue_path = remakes.queue_path
	again.load_queue()
	assert_str(StudioRemake.state_of(again.queue, "barrel-2x1")).is_equal(StudioRemake.DONE)


func test_a_failed_run_keeps_the_remake_waiting_with_the_last_words() -> void:
	_arguments("3")
	remakes.request("bench-3x1", "bench", Vector2i(3, 1), "// spec\n{}\n")
	assert_bool(remakes.run()).is_true()
	await _wait()
	assert_array(_failed).is_equal(["bench-3x1"])
	assert_str(StudioRemake.state_of(remakes.queue, "bench-3x1")).is_equal(StudioRemake.FAILED)
	assert_str(String(remakes.queue[0].message)).is_equal("cut bench-3x1")
	assert_array(remakes.waiting()).is_equal(["bench-3x1"])


func test_someone_elses_spec_is_kept_and_that_remake_fails_at_once() -> void:
	DirAccess.make_dir_recursive_absolute(remakes.objects_dir)
	var mine := FileAccess.open(remakes.objects_dir.path_join("barrel-2x1.jsonc"), FileAccess.WRITE)
	mine.store_string("// hand-written\n{}\n")
	mine.close()
	remakes.request("barrel-2x1", "barrel", Vector2i(2, 1), "// spec\n{}\n")
	assert_bool(remakes.run()).is_false()
	assert_str(StudioRemake.state_of(remakes.queue, "barrel-2x1")).is_equal(StudioRemake.FAILED)
	assert_str(FileAccess.get_file_as_string(remakes.objects_dir.path_join("barrel-2x1.jsonc"))).is_equal("// hand-written\n{}\n")


func test_a_run_cut_short_by_quitting_waits_again() -> void:
	remakes.queue = [{"id": "crate-2x2", "source": "crate", "size": [2, 2], "state": "running", "message": "", "spec": "{}"}]
	remakes.save_queue()
	remakes.load_queue()
	assert_array(remakes.waiting()).is_equal(["crate-2x2"])
