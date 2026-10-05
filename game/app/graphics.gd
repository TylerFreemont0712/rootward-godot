class_name Graphics
extends RefCounted
## What the Display and Graphics settings do to the window and the renderer: window mode, size and screen, vsync, the
## frame limit, the interface size, and which graphics device and renderer the game runs on. The choices themselves
## are `Settings`; this applies them. The pure parts (what a cap, a size or a relaunch comes to) are tested unwindowed.

## Meaning "decide for me" for a frame limit and a graphics device.
const AUTO := -1
## A frame limit of none.
const UNLIMITED := 0
## The most frames a second the automatic limit allows; see `frame_cap`.
const MAX_FPS := 90
## While the window is in the background (Settings.background_slowdown).
const BACKGROUND_FPS := 20
## Zero is "leave the window as it was launched".
const DEFAULT_WINDOW := Vector2i.ZERO
## The size a window gets coming out of fullscreen when it was never given one.
const FALLBACK_WINDOW := Vector2i(1600, 900)
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)
]
const FRAME_LIMITS: Array[int] = [AUTO, 30, 60, 90, 120, 144, UNLIMITED]
const UI_SCALES: Array[float] = [0.8, 0.88, 1.0]
const VSYNC_MODES: Array[String] = ["on", "adaptive", "off"]
const GPU_INDEXES: Array[int] = [AUTO, 0, 1, 2]
const RENDERERS: Array[String] = ["auto", "forward_plus", "mobile", "gl_compatibility"]
## Added to a relaunched game's arguments so that it never relaunches itself twice.
const RELAUNCHED := "--rootward-relaunched"
## A game started with any of these is a tool, a test or the editor's own run, and is never relaunched.
const NOT_RELAUNCHED: Array[String] = [
	"--headless", "-s", "--script", "--write-movie", "--quit-after", "--import", "-e", "--editor", "--remote-debug"
]

static var _before_fullscreen := Rect2i()


## Everything at once, at boot and when fullscreen is toggled.
static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	apply_window()
	apply_vsync()
	apply_frame_cap()
	apply_ui_scale()


## LEARN: "fullscreen" here is a borderless window the size of the screen, not the window manager's fullscreen state
## (DisplayServer.WINDOW_MODE_FULLSCREEN). That state lets the compositor hand the window straight to the display,
## which can misbehave on a laptop where one GPU draws for a screen another drives (ADR-0051). A borderless window
## stays under the compositor's control like any other.
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var wanted := Settings.screen
	if (
		wanted >= 0
		and wanted < DisplayServer.get_screen_count()
		and wanted != DisplayServer.window_get_current_screen()
	):
		DisplayServer.window_set_current_screen(wanted)
	var screen := DisplayServer.window_get_current_screen()
	var borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	if Settings.fullscreen:
		if not borderless:
			_before_fullscreen = Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
		DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	var room := DisplayServer.screen_get_usable_rect(screen)
	if Settings.window_size != DEFAULT_WINDOW:
		var size := fit_window(Settings.window_size, room.size)
		if borderless or DisplayServer.window_get_size() != size:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(room.position + (room.size - size) / 2)
	elif borderless:
		# Out of fullscreen with no size chosen: back where the window was, or a comfortable size in the middle.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if _before_fullscreen.has_area():
			DisplayServer.window_set_size(_before_fullscreen.size)
			DisplayServer.window_set_position(_before_fullscreen.position)
		else:
			var size := fit_window(FALLBACK_WINDOW, room.size)
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(room.position + (room.size - size) / 2)


static func apply_vsync() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(vsync_mode(Settings.vsync))


## The most frames a second to draw, for the screen the window is on (see `frame_cap`).
static func apply_frame_cap() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var refresh := DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
	Engine.max_fps = frame_cap(refresh, Settings.frame_limit)


## The interface's size: the root window's content scale, so every screen lays itself out in the smaller or larger room.
static func apply_ui_scale() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and DisplayServer.get_name() != "headless":
		tree.root.content_scale_factor = Settings.ui_scale


static func vsync_mode(id: String) -> DisplayServer.VSyncMode:
	match id:
		"adaptive":
			return DisplayServer.VSYNC_ADAPTIVE
		"off":
			return DisplayServer.VSYNC_DISABLED
	return DisplayServer.VSYNC_ENABLED


## LEARN: with vsync on, a cap that is not the refresh rate divided by a whole number makes some frames last one
## refresh and some two, which looks like judder. So the automatic cap is the refresh rate divided by the fewest whole
## parts that bring it to MAX_FPS or less (165 Hz -> 83, 144 -> 72, 60 -> 60), rounded up so the vsync wait, not the
## limiter, is what paces each frame. Every animation here runs on `delta`, so a lower rate changes smoothness, never
## speed. A limit the player chose is used as it is, and UNLIMITED is Godot's zero.
static func frame_cap(refresh: float, limit := AUTO) -> int:
	if limit != AUTO:
		return limit
	# A refresh rate the platform could not report may come back as 0, -1, NaN or infinity.
	if not (refresh > 0.0 and refresh < 1000.0):
		return MAX_FPS
	return ceili(refresh / ceilf(refresh / MAX_FPS))


static func fit_window(wanted: Vector2i, room: Vector2i) -> Vector2i:
	return Vector2i(mini(wanted.x, room.x), mini(wanted.y, room.y))


static func size_text(size: Vector2i) -> String:
	return "%dx%d" % [size.x, size.y]


## A saved size, kept only when it is one the settings offer (or the default).
static func parse_size(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is String:
		for size in WINDOW_SIZES:
			if size_text(size) == value:
				return size
		if value == size_text(DEFAULT_WINDOW):
			return DEFAULT_WINDOW
	return fallback


## `value` if it is one of `allowed`, else `fallback`. A number read from JSON is a float, so numbers compare by value.
static func choose(value: Variant, allowed: Array, fallback: Variant) -> Variant:
	for option: Variant in allowed:
		if (value is float or value is int) and (option is float or option is int):
			if is_equal_approx(float(value), float(option)):
				return option
		elif value is String and option is String and value == option:
			return option
	return fallback


## The graphics device the command line asks for, or AUTO.
static func running_gpu(cmdline: PackedStringArray) -> int:
	var value := _flag(cmdline, "--gpu-index")
	return int(value) if value.is_valid_int() else AUTO


## The renderer the command line asks for, or "auto" (the project's own).
static func running_renderer(cmdline: PackedStringArray) -> String:
	var value := _flag(cmdline, "--rendering-method")
	return value if value in RENDERERS else "auto"


## True when the saved device or renderer is not the one this run was started with.
static func restart_pending(cmdline: PackedStringArray, gpu: int, renderer: String) -> bool:
	return running_gpu(cmdline) != gpu or running_renderer(cmdline) != renderer


## Whether to start again with the saved device and renderer: once only, and not for a tool, a test or the editor.
static func should_relaunch(cmdline: PackedStringArray, gpu: int, renderer: String) -> bool:
	if RELAUNCHED in cmdline:
		return false
	for arg in cmdline:
		if arg.begins_with("res://") or arg in NOT_RELAUNCHED:
			return false
	return restart_pending(cmdline, gpu, renderer)


## The command line of the same game asking for `gpu` and `renderer`; "auto" and AUTO ask for nothing.
static func relaunch_args(cmdline: PackedStringArray, gpu: int, renderer: String) -> PackedStringArray:
	var args := PackedStringArray()
	var skip := 0
	for arg in cmdline:
		if skip > 0:
			skip -= 1
		elif arg in ["--gpu-index", "--rendering-method", "--rendering-driver"]:
			skip = 1
		elif not (
			arg.begins_with("--gpu-index=")
			or arg.begins_with("--rendering-method=")
			or arg.begins_with("--rendering-driver=")
			or arg == RELAUNCHED
		):
			args.append(arg)
	if gpu != AUTO:
		args.append_array(["--gpu-index", str(gpu)])
	if renderer != "auto":
		args.append_array(["--rendering-method", renderer])
		if renderer == "gl_compatibility":
			args.append_array(["--rendering-driver", "opengl3"])
	args.append(RELAUNCHED)
	return args


## At boot: starts the game again with the saved device and renderer, and says whether it did (so the caller stops).
static func relaunch_if_needed() -> bool:
	if DisplayServer.get_name() == "headless" or EngineDebugger.is_active():
		return false
	if not should_relaunch(OS.get_cmdline_args(), Settings.gpu_index, Settings.renderer):
		return false
	return relaunch()


## Starts the same game again with the saved device and renderer, then ends this one. False if it could not start.
static func relaunch() -> bool:
	var args := relaunch_args(OS.get_cmdline_args(), Settings.gpu_index, Settings.renderer)
	if not "--path" in args:
		args = PackedStringArray(["--path", ProjectSettings.globalize_path("res://")]) + args
	if OS.create_process(OS.get_executable_path(), args) < 0:
		return false
	Game.quit()
	return true


## "AMD Radeon 680M · Forward+": what the game is drawing on right now.
static func running_description() -> String:
	var names := {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}
	var method := RenderingServer.get_current_rendering_method()
	return "%s · %s" % [RenderingServer.get_video_adapter_name(), names.get(method, method)]


static func _flag(cmdline: PackedStringArray, name: String) -> String:
	for index in cmdline.size():
		if cmdline[index] == name and index + 1 < cmdline.size():
			return cmdline[index + 1]
		if cmdline[index].begins_with(name + "="):
			return cmdline[index].trim_prefix(name + "=")
	return ""
