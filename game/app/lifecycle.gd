class_name Lifecycle
extends Node
## Lives under the tree's root for the whole program (Game.boot adds it) and tidies up when the program ends: a spell
## still running in the sandbox is waited for, so no process or job folder is left behind, and the music is stopped.
## It also watches the window: fewer frames while the game is behind another window, and the frame-rate readout.

const FPS_EVERY := 0.5

var _fps: Label
var _since := 0.0


func _ready() -> void:
	# The window's close button asks first, so Game.quit can tidy up before the tree ends.
	get_tree().auto_accept_quit = false
	var layer := CanvasLayer.new()
	layer.layer = 128
	_fps = Label.new()
	_fps.visible = false
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.position = Vector2(12, 8)
	_fps.add_theme_font_size_override("font_size", 16)
	_fps.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps.add_theme_constant_override("outline_size", 5)
	layer.add_child(_fps)
	add_child(layer)
	var window := get_window()
	window.focus_exited.connect(_on_focus_out)
	window.focus_entered.connect(_on_focus_in)


func _process(delta: float) -> void:
	if _fps.visible != Settings.show_fps:
		_fps.visible = Settings.show_fps
		_since = FPS_EVERY
	if not _fps.visible:
		return
	_since += delta
	if _since >= FPS_EVERY:
		_since = 0.0
		_fps.text = "%d fps" % Engine.get_frames_per_second()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.quit()


func _exit_tree() -> void:
	Background.finish_all()
	Sound.silence()
	Engine.time_scale = 1.0


## A game behind another window draws a few frames a second, so it neither heats the machine nor fights for the GPU.
func _on_focus_out() -> void:
	if Settings.background_slowdown and DisplayServer.get_name() != "headless":
		Engine.max_fps = Graphics.BACKGROUND_FPS


func _on_focus_in() -> void:
	Graphics.apply_frame_cap()
