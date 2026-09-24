class_name Sandbox
extends RefCounted
## Runs player code (Python or JavaScript) as WebAssembly under wasmtime, in a process of its own (ADR-0002).
##
## A job's files go to a fresh folder that the program sees as /work, beside a launcher (sandbox/launch/) and its
## standard input. The program sees nothing else: no other files, no network (WASI preview 1 cannot open sockets),
## no environment. wasmtime enforces the time limit (epoch interruption) and the memory cap; this class adds a
## wall-clock backstop and an output cap, and turns the exit code into a status.
##
## `run` blocks until the program ends, so the game calls it from a thread (see SandboxWorker); tests call it directly.

const RUNTIME_ENV := "ROOTWARD_SANDBOX_RUNTIME"
const LAUNCHERS := {
	SandboxJob.PYTHON: "res://sandbox/launch/launch.py",
	SandboxJob.JAVASCRIPT: "res://sandbox/launch/launch.js",
}
const EXIT_RUNTIME_ERROR := 70
const EXIT_COMPILE_ERROR := 71
const EXIT_OUT_OF_MEMORY := 72
const POLL_MS := 2
## LEARN: QuickJS keeps its C stack inside the module's own memory, a region of about 2 MB fixed when qjs-wasi was
## built. QuickJS checks its depth against --stack-size and throws a catchable RangeError; set above that region, the
## check comes too late and the whole engine traps. 1792 KB sits just under it, which allows about 5000 nested calls
## (the old game's bar). The native Wasm stack gets 8 MB so it never runs out first.
const JS_STACK_KB := 1792
const WASM_STACK_BYTES := 8 * 1024 * 1024
const READ_CHUNK := 65536


## Where scripts/fetch-sandbox.sh installed wasmtime and the language modules.
static func runtime_dir() -> String:
	var override := OS.get_environment(RUNTIME_ENV)
	if override != "":
		return override
	return ProjectSettings.globalize_path("res://sandbox/runtime")


static func is_available(language: String) -> bool:
	if not FileAccess.file_exists(_wasmtime()):
		return false
	match language:
		SandboxJob.PYTHON:
			return FileAccess.file_exists(runtime_dir().path_join("python/python.cwasm"))
		SandboxJob.JAVASCRIPT:
			return FileAccess.file_exists(runtime_dir().path_join("js/qjs.cwasm"))
	return false


static func run(job: SandboxJob) -> SandboxResult:
	var result := SandboxResult.new()
	if not is_available(job.language):
		result.message = "no sandbox for %s (run scripts/fetch-sandbox.sh)" % job.language
		return result
	var dir := _make_job_dir()
	if dir == "":
		result.message = "could not create the job folder"
		return result
	var written := _write_job(job, dir)
	if written != "":
		result.message = written
		_remove_dir(dir)
		return result
	var started := Time.get_ticks_msec()
	var process := OS.execute_with_pipe(_wasmtime(), _arguments(job, dir), false)
	if process.is_empty():
		result.message = "could not start wasmtime"
		_remove_dir(dir)
		return result
	_collect(process, job, result, started)
	result.wall_ms = Time.get_ticks_msec() - started
	_remove_dir(dir)
	return result


static func _wasmtime() -> String:
	return runtime_dir().path_join("bin/wasmtime")


static func _arguments(job: SandboxJob, dir: String) -> PackedStringArray:
	var runtime := runtime_dir()
	var args := PackedStringArray(["run", "--allow-precompiled"])
	args.append_array(["-W", "timeout=%dms" % job.time_ms])
	args.append_array(["-W", "max-memory-size=%d" % (job.memory_mb * 1024 * 1024)])
	args.append_array(["-W", "max-wasm-stack=%d" % WASM_STACK_BYTES])
	args.append_array(["--dir", "%s::/work" % dir])
	match job.language:
		SandboxJob.PYTHON:
			args.append_array(["--dir", "%s::/lib" % runtime.path_join("python/lib")])
			args.append_array(["--env", "PYTHONHOME=/", "--env", "PYTHONDONTWRITEBYTECODE=1"])
			# LEARN: Python salts string hashes with a random seed per process, which changes the iteration order of a
			# set of strings from one run to the next. A preview and its cast must produce the same bolts, so the salt
			# is pinned.
			args.append_array(["--env", "PYTHONHASHSEED=0"])
			args.append_array([runtime.path_join("python/python.cwasm"), "/work/.rootward/launch.py", job.entry])
		SandboxJob.JAVASCRIPT:
			var memory_kb := job.memory_mb * 1024
			args.append_array([runtime.path_join("js/qjs.cwasm"), "--std", "--script"])
			args.append_array(["--memory-limit", str(memory_kb), "--stack-size", str(JS_STACK_KB)])
			args.append_array(["/work/.rootward/launch.js", job.entry])
	return args


## Reads both pipes until the process ends, killing it at the wall-clock limit or when it prints too much.
static func _collect(process: Dictionary, job: SandboxJob, result: SandboxResult, started: int) -> void:
	var pid: int = process.pid
	var out_pipe: FileAccess = process.stdio
	var err_pipe: FileAccess = process.stderr
	var out := PackedByteArray()
	var err := PackedByteArray()
	var cap := job.output_kb * 1024
	var killed_for := ""
	while true:
		var running := OS.is_process_running(pid)
		# LEARN: both pipes are drained on every pass. A child blocks once a pipe's buffer (64 KB on Linux) is full, so
		# reading only stdout until the end could deadlock on a program that writes a lot to stderr.
		out.append_array(_drain(out_pipe))
		err.append_array(_drain(err_pipe))
		if not running:
			break
		if out.size() > cap or err.size() > cap:
			killed_for = "output"
			OS.kill(pid)
			break
		if Time.get_ticks_msec() - started > job.wall_ms:
			killed_for = "wall"
			OS.kill(pid)
			break
		OS.delay_msec(POLL_MS)
	out_pipe.close()
	err_pipe.close()
	result.stdout = out.slice(0, cap).get_string_from_utf8()
	result.stderr = err.slice(0, cap).get_string_from_utf8()
	result.exit_code = -1 if killed_for != "" else OS.get_process_exit_code(pid)
	_classify(result, killed_for, job)


static func _drain(pipe: FileAccess) -> PackedByteArray:
	var bytes := PackedByteArray()
	while true:
		var chunk := pipe.get_buffer(READ_CHUNK)
		if chunk.is_empty():
			break
		bytes.append_array(chunk)
	return bytes


static func _classify(result: SandboxResult, killed_for: String, job: SandboxJob) -> void:
	if killed_for == "output":
		result.status = SandboxResult.RUNTIME_ERROR
		result.message = "it printed more than %d KB" % job.output_kb
		return
	if killed_for == "wall":
		result.status = SandboxResult.TIMEOUT
		result.message = "it ran out of time (a loop that never ends?)"
		return
	match result.exit_code:
		0:
			result.status = SandboxResult.OK
		EXIT_RUNTIME_ERROR:
			result.status = SandboxResult.RUNTIME_ERROR
			result.message = _last_line(result.stderr, "it raised an error")
		EXIT_COMPILE_ERROR:
			result.status = SandboxResult.COMPILE_ERROR
			result.message = _last_line(result.stderr, "a syntax error")
		EXIT_OUT_OF_MEMORY:
			result.status = SandboxResult.OOM
			result.message = "it ran out of memory"
		_:
			_classify_trap(result)


## A run that ended in wasmtime rather than in the launcher: a timeout, memory the engine could not grow, or a fault.
static func _classify_trap(result: SandboxResult) -> void:
	var text := result.stderr
	if text.contains("wasm trap: interrupt"):
		result.status = SandboxResult.TIMEOUT
		result.message = "it ran out of time (a loop that never ends?)"
	elif text.contains("out of memory") or text.contains("MemoryError") or text.contains("memory allocation"):
		result.status = SandboxResult.OOM
		result.message = "it ran out of memory"
	elif text.contains("wasm trap"):
		# A stack overflow in the interpreter, for example from recursion with no base case.
		result.status = SandboxResult.RUNTIME_ERROR
		result.message = "it crashed the interpreter (recursion too deep?)"
	else:
		result.status = SandboxResult.SANDBOX_ERROR
		result.message = _last_line(text, "the sandbox failed (exit %d)" % result.exit_code)
	# wasmtime's own report is for us, not the player; keep only what the program printed before it.
	var cut := text.find("Error: failed to run main module")
	if cut != -1:
		result.stderr = text.substr(0, cut)


## The last line of a traceback or stack that names the error, not a frame.
static func _last_line(text: String, fallback: String) -> String:
	var lines := text.strip_edges().split("\n")
	for i in range(lines.size() - 1, -1, -1):
		var line := lines[i].strip_edges()
		if line != "" and not line.begins_with("at ") and not line.begins_with("File ") and not line.begins_with("^"):
			return line
	return fallback


static func _make_job_dir() -> String:
	var base := OS.get_user_data_dir().path_join("sandbox/jobs")
	var crypto := Crypto.new()
	var dir := base.path_join(crypto.generate_random_bytes(8).hex_encode())
	if DirAccess.make_dir_recursive_absolute(dir.path_join(".rootward")) != OK:
		return ""
	return dir


## Writes the job into `dir`; returns an error message, or "" when everything was written.
static func _write_job(job: SandboxJob, dir: String) -> String:
	for path: String in job.files:
		if path.is_absolute_path() or path.begins_with("..") or path.contains("/../") or path.begins_with(".rootward"):
			return "a job file has a path outside the job: %s" % path
		var full := dir.path_join(path)
		DirAccess.make_dir_recursive_absolute(full.get_base_dir())
		if not _write_text(full, job.files[path]):
			return "could not write %s" % path
	if not job.files.has(job.entry):
		return "the entry file %s is not among the job's files" % job.entry
	var launcher := FileAccess.get_file_as_string(LAUNCHERS[job.language])
	var launcher_name: String = (LAUNCHERS[job.language] as String).get_file()
	if launcher == "" or not _write_text(dir.path_join(".rootward").path_join(launcher_name), launcher):
		return "could not write the launcher"
	if not _write_text(dir.path_join(".rootward/stdin"), job.stdin):
		return "could not write standard input"
	return ""


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


static func _remove_dir(dir: String) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	access.include_hidden = true
	# LEARN: a program can leave symlinks in its folder. A link is removed as a link and never followed, or cleaning
	# up could delete whatever it points at outside the job.
	for name in access.get_directories():
		if access.is_link(name):
			access.remove(name)
		else:
			_remove_dir(dir.path_join(name))
	for name in access.get_files():
		access.remove(name)
	DirAccess.remove_absolute(dir)
