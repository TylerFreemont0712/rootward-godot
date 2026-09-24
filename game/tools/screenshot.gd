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
	root.add_child(packed.instantiate())
	var frames := int(args[2]) if args.size() > 2 else DEFAULT_FRAMES
	_capture.call_deferred(args[1], frames)


func _capture(path: String, frames: int) -> void:
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
	quit(0)
