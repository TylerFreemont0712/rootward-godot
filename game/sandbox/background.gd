class_name Background
extends RefCounted
## Runs slow work (a sandbox job takes 10 to 100 ms or more) on a thread while the game keeps drawing frames.
##
##   var runs: Dictionary = await Background.run(func() -> Dictionary: return SpellHarness.run(...))
##
## LEARN: `await` on a function that itself awaits suspends the caller until it returns, frame by frame. The work must
## not touch nodes: everything in game/core and game/sandbox is plain data and files, so it is safe on a thread.

## Threads still working, so quitting can wait for them (Background.finish_all), and what they returned if it did.
static var _running: Array[Thread] = []
static var _finished: Dictionary = {}


static func run(work: Callable) -> Variant:
	var thread := Thread.new()
	var error := thread.start(work)
	if error != OK:
		push_error("could not start a thread: %s" % error_string(error))
		return work.call()
	_running.append(thread)
	var tree := Engine.get_main_loop() as SceneTree
	while thread.is_alive():
		await tree.process_frame
	_running.erase(thread)
	if _finished.has(thread):
		var result: Variant = _finished[thread]
		_finished.erase(thread)
		return result
	return thread.wait_to_finish()


## Waits for every thread still working. Call it before quitting: a thread torn down in the middle of a sandbox job
## leaves its process and folder behind. A job is bounded by its wall-clock limit, so this never waits for long.
static func finish_all() -> void:
	for thread in _running:
		if thread.is_started():
			_finished[thread] = thread.wait_to_finish()
	_running.clear()
