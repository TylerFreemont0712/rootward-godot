class_name Lifecycle
extends Node
## Lives under the tree's root for the whole program (Game.boot adds it) and tidies up when the program ends: a spell
## still running in the sandbox is waited for, so no process or job folder is left behind, and the music is stopped.


func _ready() -> void:
	# The window's close button asks first, so Game.quit can tidy up before the tree ends.
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.quit()


func _exit_tree() -> void:
	Background.finish_all()
	Sound.silence()
	Engine.time_scale = 1.0
