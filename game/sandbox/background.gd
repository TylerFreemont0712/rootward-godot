class_name Background
extends RefCounted
## Runs slow work (a sandbox job takes 10 to 100 ms or more) on a thread while the game keeps drawing frames.
##
##   var runs: Dictionary = await Background.run(func() -> Dictionary: return SpellHarness.run(...))
##
## LEARN: `await` on a function that itself awaits suspends the caller until it returns, frame by frame. The work must
## not touch nodes: everything in game/core and game/sandbox is plain data and files, so it is safe on a thread.


static func run(work: Callable) -> Variant:
	var thread := Thread.new()
	var error := thread.start(work)
	if error != OK:
		push_error("could not start a thread: %s" % error_string(error))
		return work.call()
	var tree := Engine.get_main_loop() as SceneTree
	while thread.is_alive():
		await tree.process_frame
	return thread.wait_to_finish()
