class_name OverworldStore
extends RefCounted
## Lanternroot's characters on disk (ADR-0061): one file each in the profile's folder, `<profile>/overworld/<id>.json`,
## written whole after every change the way runs are (SaveStore, LanternStore). The character being played is
## `OverworldStore.current`, chosen on the character screen; load_state and save_state work on it. A save from before
## characters existed (`<profile>/overworld.json`) becomes the first character the first time the folder is read.

const FOLDER := "overworld"
const LEGACY := "overworld.json"
const FIRST := "c1"

## The character being played, chosen on the character screen. Empty means the first one (a test, a screenshot).
static var current := ""

var root: String


func _init(save_root: String) -> void:
	root = save_root


static func for_profile() -> OverworldStore:
	if Game.profiles != null and not Game.profile.is_empty():
		return OverworldStore.new(Game.profiles.run_root(String(Game.profile.id)))
	var override := OS.get_environment(Game.SAVES_ENV)
	return OverworldStore.new(override if override != "" else SaveStore.ROOT)


func folder() -> String:
	return root.path_join(FOLDER)


func path_of(id: String) -> String:
	return folder().path_join("%s.json" % id)


## The character the overworld plays now: `current`, or the first one.
static func playing() -> String:
	return current if current != "" else FIRST


## Every character, newest played first: [{id, state}].
func characters() -> Array[Dictionary]:
	_migrate()
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(folder()):
		return out
	for name in DirAccess.get_files_at(folder()):
		if not name.ends_with(".json"):
			continue
		var id := name.get_basename()
		var state := load_character(id)
		if not state.is_empty():
			out.append({"id": id, "state": state})
	out.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.state.get("saved_at", 0.0)) > float(b.state.get("saved_at", 0.0))
	)
	return out


## The saved character, or {} when there is none or it cannot be read.
func load_character(id: String) -> Dictionary:
	var path := path_of(id)
	if not FileAccess.file_exists(path):
		return {}
	var value: Variant = JsJson.parse(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}


func save_character(id: String, state: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(folder())
	var stamped := state.duplicate()
	stamped.saved_at = Time.get_unix_time_from_system()
	var temporary := path_of(id) + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JsJson.stringify(stamped))
	file.close()
	return DirAccess.rename_absolute(temporary, path_of(id))


func delete_character(id: String) -> void:
	if FileAccess.file_exists(path_of(id)):
		DirAccess.remove_absolute(path_of(id))


## An id no character has yet: c1, c2, ...
func new_id() -> String:
	_migrate()
	var n := 1
	while FileAccess.file_exists(path_of("c%d" % n)):
		n += 1
	return "c%d" % n


## The character being played, as the overworld reads and writes it.
func load_state() -> Dictionary:
	_migrate()
	return load_character(playing())


func save_state(state: Dictionary) -> Error:
	return save_character(playing(), state)


func delete_state() -> void:
	delete_character(playing())


func _migrate() -> void:
	var legacy := root.path_join(LEGACY)
	if not FileAccess.file_exists(legacy):
		return
	DirAccess.make_dir_recursive_absolute(folder())
	# Never over another character: the old save takes the first free slot.
	var n := 1
	while FileAccess.file_exists(path_of("c%d" % n)):
		n += 1
	DirAccess.rename_absolute(legacy, path_of("c%d" % n))
