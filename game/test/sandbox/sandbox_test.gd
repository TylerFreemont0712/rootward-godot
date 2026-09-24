extends GdUnitTestSuite
## The sandbox runs real code, and contains it: time, memory, output, files and network.


func _run(language: String, source: String, stdin := "", time_ms := 2000) -> SandboxResult:
	var entry := "main.py" if language == SandboxJob.PYTHON else "main.js"
	var job := SandboxJob.of(language, {entry: source}, entry)
	job.stdin = stdin
	job.time_ms = time_ms
	return Sandbox.run(job)


func before() -> void:
	(
		assert_bool(Sandbox.is_available(SandboxJob.PYTHON))
		. override_failure_message("run scripts/fetch-sandbox.sh")
		. is_true()
	)
	assert_bool(Sandbox.is_available(SandboxJob.JAVASCRIPT)).is_true()


func test_python_reads_stdin_and_prints() -> void:
	var result := _run(SandboxJob.PYTHON, "import sys\nprint(sys.stdin.read().upper(), end='')\n", "hello")
	assert_str(result.status).is_equal(SandboxResult.OK)
	assert_str(result.stdout).is_equal("HELLO")


func test_javascript_reads_stdin_and_prints() -> void:
	var source := "const s = require('fs').readFileSync(0, 'utf8');\nconsole.log(s.toUpperCase(), [1, 2]);\n"
	var result := _run(SandboxJob.JAVASCRIPT, source, "hello")
	assert_str(result.status).is_equal(SandboxResult.OK)
	assert_str(result.stdout).is_equal("HELLO [1,2]\n")


func test_javascript_requires_its_own_files() -> void:
	var files: Dictionary[String, String] = {
		"main.js": "console.log(require('./lib/add').add(2, 3));",
		"lib/add.js": "exports.add = (a, b) => a + b;",
	}
	var result := Sandbox.run(SandboxJob.of(SandboxJob.JAVASCRIPT, files, "main.js"))
	assert_str(result.stdout).is_equal("5\n")


func test_python_error_names_the_line() -> void:
	var result := _run(SandboxJob.PYTHON, "x = 1\nraise ValueError('bad')\n")
	assert_str(result.status).is_equal(SandboxResult.RUNTIME_ERROR)
	assert_str(result.message).is_equal("ValueError: bad")
	assert_str(result.stderr).contains('File "main.py", line 2').not_contains("launch.py")


func test_javascript_error_names_the_file() -> void:
	var result := _run(SandboxJob.JAVASCRIPT, "let x = 1;\nnope();\n")
	assert_str(result.status).is_equal(SandboxResult.RUNTIME_ERROR)
	assert_str(result.stderr).contains("ReferenceError").contains("main.js:2")


func test_syntax_errors_are_compile_errors() -> void:
	assert_str(_run(SandboxJob.PYTHON, "def f(:\n").status).is_equal(SandboxResult.COMPILE_ERROR)
	assert_str(_run(SandboxJob.JAVASCRIPT, "let = = 2;").status).is_equal(SandboxResult.COMPILE_ERROR)


func test_exit_codes() -> void:
	assert_str(_run(SandboxJob.PYTHON, "import sys\nprint('a')\nsys.exit(0)\nprint('b')").stdout).is_equal("a\n")
	assert_str(_run(SandboxJob.PYTHON, "import sys\nsys.exit(3)").status).is_equal(SandboxResult.RUNTIME_ERROR)
	assert_str(_run(SandboxJob.JAVASCRIPT, "console.log('a'); process.exit(0); console.log('b');").stdout).is_equal(
		"a\n"
	)


func test_endless_loops_time_out() -> void:
	for language: String in SandboxJob.LANGUAGES:
		var source := "while True:\n    pass\n" if language == SandboxJob.PYTHON else "for (;;) {}"
		var result := _run(language, source, "", 300)
		assert_str(result.status).override_failure_message(str(result)).is_equal(SandboxResult.TIMEOUT)
		assert_int(result.wall_ms).is_less(3000)


func test_memory_bombs_hit_the_cap() -> void:
	var py := _run(SandboxJob.PYTHON, "x = [0] * (10 ** 9)\n")
	assert_str(py.status).override_failure_message(str(py)).is_equal(SandboxResult.OOM)
	var js := _run(SandboxJob.JAVASCRIPT, "const a = []; for (;;) a.push(new Array(100000).fill(1));")
	assert_str(js.status).override_failure_message(str(js)).is_equal(SandboxResult.OOM)


func test_output_is_capped() -> void:
	var result := _run(SandboxJob.PYTHON, "while True:\n    print('x' * 1000)\n")
	assert_str(result.status).is_equal(SandboxResult.RUNTIME_ERROR)
	assert_str(result.message).contains("printed more than")
	assert_int(result.stdout.length()).is_less_equal(256 * 1024)


func test_no_files_outside_the_job() -> void:
	var py := _run(SandboxJob.PYTHON, "open('/etc/passwd').read()\n")
	assert_str(py.status).is_equal(SandboxResult.RUNTIME_ERROR)
	var up := _run(SandboxJob.PYTHON, "open('/work/../../etc/passwd').read()\n")
	assert_str(up.status).is_equal(SandboxResult.RUNTIME_ERROR)
	var js := _run(SandboxJob.JAVASCRIPT, "require('fs').readFileSync('/etc/passwd')")
	assert_str(js.status).is_equal(SandboxResult.RUNTIME_ERROR)


func test_the_standard_library_cannot_be_changed() -> void:
	var source := "open('/lib/python3.14/json/__init__.py', 'a').write('# changed')\n"
	var result := _run(SandboxJob.PYTHON, source)
	assert_str(result.status).is_equal(SandboxResult.RUNTIME_ERROR)
	assert_str(result.message).contains("PermissionError")


func test_no_network() -> void:
	var source := "import socket\nsocket.create_connection(('1.1.1.1', 80), timeout=1)\n"
	var result := _run(SandboxJob.PYTHON, source)
	assert_str(result.status).is_equal(SandboxResult.RUNTIME_ERROR)


func test_a_symlink_left_behind_is_not_followed_on_cleanup() -> void:
	var outside := OS.get_user_data_dir().path_join("sandbox/outside-%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(outside)
	var keep := FileAccess.open(outside.path_join("keep.txt"), FileAccess.WRITE)
	keep.store_string("still here")
	keep.close()
	# WASI refuses an absolute target but creates a relative one that climbs out of the job (the guest itself cannot
	# follow it). Jobs live in sandbox/jobs/<id>, so this one points at sandbox/<outside>.
	var target := "../../" + outside.get_file()
	var source := "import os\nos.symlink(%s, '/work/escape')\n" % JSON.stringify(target)
	source += "print(os.path.islink('/work/escape'))\n"
	var result := _run(SandboxJob.PYTHON, source)
	# The link was really made (so the cleanup had one to meet), and what it points at survived.
	assert_str(result.stdout).is_equal("True\n")
	assert_bool(FileAccess.file_exists(outside.path_join("keep.txt"))).is_true()
	DirAccess.remove_absolute(outside.path_join("keep.txt"))
	DirAccess.remove_absolute(outside)


func test_job_folders_are_removed() -> void:
	_run(SandboxJob.PYTHON, "print(1)")
	var jobs := DirAccess.get_directories_at(OS.get_user_data_dir().path_join("sandbox/jobs"))
	assert_int(jobs.size()).is_equal(0)
