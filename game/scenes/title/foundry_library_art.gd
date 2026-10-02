class_name FoundryLibraryArt
extends RefCounted
## A bounded, room-local cache of canonical art. Only visible shelf entries request textures.

const CAPACITY := 32
const IN_FLIGHT := 2
var textures: Dictionary = {}
var _pending: Dictionary = {}
var _headless_loads := 0


func request(id: String) -> void:
	if textures.has(id) or _pending.has(id) or _pending.size() >= IN_FLIGHT:
		return
	# Godot's dummy renderer cannot initialize textures safely from a loading thread.
	if DisplayServer.get_name() == "headless":
		if _headless_loads == 0:
			_headless_loads += 1
			_remember(id, Art.texture(id))
		return
	for extension: String in [".webp", ".png", ".svg"]:
		var path := Art.ROOT + id + extension
		if ResourceLoader.exists(path):
			if ResourceLoader.load_threaded_request(path, "Texture2D") == OK:
				_pending[id] = path
			else:
				_remember(id, null)
			return
	# The existing atlas fallback applies only when individual artwork is absent.
	_remember(id, Art.texture(id))


func poll() -> void:
	_headless_loads = 0
	for id: String in _pending:
		var status := ResourceLoader.load_threaded_get_status(_pending[id])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		# LEARN: get() can block; only retrieve a completed threaded request, one texture per frame.
		var picture: Texture2D
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			picture = ResourceLoader.load_threaded_get(_pending[id]) as Texture2D
		_remember(id, picture)
		_pending.erase(id)
		return


func _remember(id: String, picture: Texture2D) -> void:
	if textures.size() >= CAPACITY:
		textures.erase(textures.keys()[0])
	textures[id] = picture


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Consume outstanding jobs when the title is disposed, so the loader retains no orphan resources.
		for path: String in _pending.values():
			ResourceLoader.load_threaded_get(path)
