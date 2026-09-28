extends SceneTree
## Runs the real boot scene and fails if its transition never reaches the title.


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	Game.reset("user://boot-check-saves")
	var error := change_scene_to_file("res://scenes/boot/boot.tscn")
	if error != OK:
		push_error("Cannot open boot scene: " + error_string(error))
		quit(1)
		return
	for frame in 480:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == Game.TITLE and not ScreenTransition.busy:
			print("Boot reached title on frame %d" % frame)
			Background.finish_all()
			Sound.silence()
			current_scene.queue_free()
			Game.reset()
			await create_timer(0.4).timeout
			quit(0)
			return
	push_error("Boot did not reach the title within 480 frames")
	quit(1)
