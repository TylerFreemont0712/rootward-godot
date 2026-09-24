extends SceneTree
## Loads a scene, lets it run for a number of frames, and saves the window to a PNG.
## Run through scripts/screenshot.sh, which supplies a display:
##   scripts/screenshot.sh res://scenes/boot/boot.tscn shots/boot.png [frames]
## Arguments after `--` reach this script as OS.get_cmdline_user_args().

const DEFAULT_FRAMES := 30


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <scene path> <output png> [frames]")
		quit(2)
		return
	var packed := load(args[0]) as PackedScene
	if packed == null:
		push_error("cannot load scene %s" % args[0])
		quit(2)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	var frames := int(args[2]) if args.size() > 2 else DEFAULT_FRAMES
	_capture.call_deferred(scene, args[1], frames)


## A scene that needs time to set itself up (a tool playing a run to a moment) says `shot_ready`; the frames are counted
## from then.
func _capture(scene: Node, path: String, frames: int) -> void:
	if scene.has_signal("shot_ready") and not scene.get_meta("shot_ready", false):
		await scene.shot_ready
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := image.save_png(path)
	if error != OK:
		push_error("could not write %s (%s)" % [path, error_string(error)])
		quit(1)
		return
	print("screenshot: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	Background.finish_all()
	quit(0)
